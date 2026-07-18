//
//  PresenceReminderConfiguration.swift
//  Ohana
//
//  Device-local Zen reminder settings. These values are deliberately excluded
//  from backup and CloudSync.
//

import Foundation

nonisolated enum PresenceReminderWeekday: Int, Codable, CaseIterable, Hashable, Sendable {
    /// Calendar weekday values: Sunday = 1 ... Saturday = 7.
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

nonisolated struct PresenceReminderSchedule: Codable, Equatable, Hashable, Sendable {
    /// `nil` means every day. Personal schedules may target one weekday.
    let weekday: PresenceReminderWeekday?
    let hour: Int
    let minute: Int

    init(weekday: PresenceReminderWeekday? = nil, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    static let suggestedDailyDeadline = PresenceReminderSchedule(hour: 20, minute: 0)
}

nonisolated struct PresenceReminderConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var schedules: [PresenceReminderSchedule]
    var gracePeriodMinutes: Int?
    var sendsSecondLocalReminder: Bool
    var messageTemplate: String

    static let fixedMessageTemplate = "未收到今天的打卡，请主动确认。"

    static let initial = PresenceReminderConfiguration(
        isEnabled: false,
        schedules: [.suggestedDailyDeadline],
        gracePeriodMinutes: nil,
        sendsSecondLocalReminder: false,
        messageTemplate: fixedMessageTemplate
    )
}

nonisolated enum PresenceReminderConfigurationDenial: Equatable, Sendable {
    case tooManySchedules(limit: Int)
    case weekdaySchedulesRequirePersonal
    case gracePeriodRequiresPersonal
    case invalidGracePeriod(allowed: ClosedRange<Int>)
    case secondReminderRequiresPersonal
    case editableTemplateRequiresPersonal
}

nonisolated enum PresenceReminderConfigurationPolicy {
    /// Validates a newly proposed configuration. Existing over-limit settings
    /// are not deleted on downgrade; callers keep scheduling the stored value
    /// and invoke this policy only before accepting a user edit that adds paid
    /// configuration.
    static func denial(
        for proposed: PresenceReminderConfiguration,
        capabilities: OhanaPlanCapabilities
    ) -> PresenceReminderConfigurationDenial? {
        if proposed.schedules.count > capabilities.reminders.maximumScheduleCount {
            return .tooManySchedules(limit: capabilities.reminders.maximumScheduleCount)
        }
        if proposed.schedules.contains(where: { $0.weekday != nil }),
           !capabilities.reminders.allowsWeekdaySchedules {
            return .weekdaySchedulesRequirePersonal
        }
        if let grace = proposed.gracePeriodMinutes {
            guard capabilities.reminders.allowsGracePeriod else {
                return .gracePeriodRequiresPersonal
            }
            guard PresenceReminderCapabilities.gracePeriodMinutes.contains(grace) else {
                return .invalidGracePeriod(allowed: PresenceReminderCapabilities.gracePeriodMinutes)
            }
        }
        if proposed.sendsSecondLocalReminder,
           !capabilities.reminders.allowsSecondLocalReminder {
            return .secondReminderRequiresPersonal
        }
        if proposed.messageTemplate != PresenceReminderConfiguration.fixedMessageTemplate,
           !capabilities.contacts.allowsEditableMessageTemplate {
            return .editableTemplateRequiresPersonal
        }
        return nil
    }
}

protocol PresenceReminderConfigurationStoring: Sendable {
    func load() -> PresenceReminderConfiguration
    func save(_ configuration: PresenceReminderConfiguration)
    func clear()
}

/// UserDefaults is appropriate here because reminder choices are explicitly
/// per-device and must not be treated as household facts.
final class PresenceReminderConfigurationStore: PresenceReminderConfigurationStoring, @unchecked Sendable {
    static let storageKey = "presence.reminder.configuration.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PresenceReminderConfiguration {
        lock.withLock {
            guard let data = defaults.data(forKey: Self.storageKey),
                  let value = try? JSONDecoder().decode(PresenceReminderConfiguration.self, from: data) else {
                return .initial
            }
            return value
        }
    }

    func save(_ configuration: PresenceReminderConfiguration) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(configuration) else { return }
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func clear() {
        lock.withLock {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }
}

nonisolated struct PresenceSafetyMessageDraft: Equatable, Sendable {
    let recipients: [String]
    let body: String

    init(recipients: [String], configuredTemplate: String?) {
        self.recipients = recipients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidate = configuredTemplate?.trimmingCharacters(in: .whitespacesAndNewlines)
        body = candidate?.isEmpty == false
            ? candidate!
            : PresenceReminderConfiguration.fixedMessageTemplate
    }
}

nonisolated enum FamilyPresenceGuardianEscalationAvailability: Equatable, Sendable {
    case unavailableInShippingProfile
    case readyForAcceptedMembers
}

protocol FamilyPresenceGuardianEscalating: Sendable {
    var availability: FamilyPresenceGuardianEscalationAvailability { get }
}

/// The current Solo target must remain fail-closed without APNs or a backend.
nonisolated struct DisabledFamilyPresenceGuardianEscalator: FamilyPresenceGuardianEscalating {
    let availability: FamilyPresenceGuardianEscalationAvailability = .unavailableInShippingProfile
}
