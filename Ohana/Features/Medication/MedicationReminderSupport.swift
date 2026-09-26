//
//  MedicationReminderSupport.swift
//  Ohana
//
//  Shared policies and value types used by medication reminder scheduling.
//

import Foundation
import UserNotifications

nonisolated enum MedicationDoseProgressStore {
    static func dosesTakenToday(for medicationId: UUID) -> Int {
        let today = dayKey(for: Date())
        return UserDefaults.standard.integer(forKey: "med_doses_\(today)_\(medicationId.uuidString)")
    }

    private static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

nonisolated enum MedicationNotificationPrivacyStore {
    /// Keep the shipped raw key so existing preferences remain intact.
    static let hideDetailsKey = "privacy_hide_pet_medication_notification_details"
    static let hidePetDetailsKey = hideDetailsKey

    static func hidesMedicationDetails(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: hideDetailsKey)
    }

    static func hidesPetMedicationDetails(defaults: UserDefaults = .standard) -> Bool {
        hidesMedicationDetails(defaults: defaults)
    }
}

nonisolated enum MedicationNotificationContentPolicy {
    static func hidesHumanDetails(
        globalPreference: Bool,
        memberMedicationIsPrivate: Bool
    ) -> Bool {
        globalPreference || memberMedicationIsPrivate
    }

    static func body(hidesDetails: Bool, generic: String, detailed: String) -> String {
        hidesDetails ? generic : detailed
    }
}

/// Versioned metadata lets launch/foreground maintenance distinguish a
/// privacy-safe notification body from a legacy or interrupted replacement.
/// Identifiers alone are intentionally insufficient because privacy changes do
/// not change the dose schedule.
enum MedicationNotificationPrivacyMarker {
    static let versionKey = "ohanaMedicationPrivacyVersion"
    static let modeKey = "ohanaMedicationPrivacyMode"
    static let currentVersion = 1

    private static let hiddenMode = "hidden"
    private static let detailedMode = "detailed"

    static func userInfo(hidesDetails: Bool) -> [AnyHashable: Any] {
        [
            versionKey: currentVersion,
            modeKey: hidesDetails ? hiddenMode : detailedMode
        ]
    }

    static func isCurrent(_ content: UNNotificationContent, hidesDetails: Bool) -> Bool {
        let version = (content.userInfo[versionKey] as? NSNumber)?.intValue
            ?? content.userInfo[versionKey] as? Int
        let expectedMode = hidesDetails ? hiddenMode : detailedMode
        return version == currentVersion && content.userInfo[modeKey] as? String == expectedMode
    }

    static func matches(_ content: UNNotificationContent, desired: UNNotificationContent) -> Bool {
        let desiredMode = desired.userInfo[modeKey] as? String
        guard desiredMode == hiddenMode || desiredMode == detailedMode else { return false }
        return isCurrent(content, hidesDetails: desiredMode == hiddenMode)
    }
}

nonisolated struct MedicationNotificationRefreshPlan: Equatable, Sendable {
    let notificationIDs: Set<String>
    let petIDs: Set<UUID>
    let humanIDs: Set<UUID>
    let unresolvedNotificationIDs: Set<String>
}

nonisolated struct MedicationNotificationRefreshScope: Codable, Equatable, Sendable {
    let petIDs: Set<UUID>
    let humanIDs: Set<UUID>
}

nonisolated enum MedicationNotificationRefreshScopeStore {
    static let key = "medication_notification_privacy_refresh_scope_v1"

    static func load(defaults: UserDefaults = .standard) -> MedicationNotificationRefreshScope? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MedicationNotificationRefreshScope.self, from: data)
    }

    static func save(
        petIDs: Set<UUID>,
        humanIDs: Set<UUID>,
        defaults: UserDefaults = .standard
    ) {
        let scope = MedicationNotificationRefreshScope(petIDs: petIDs, humanIDs: humanIDs)
        guard !scope.petIDs.isEmpty || !scope.humanIDs.isEmpty,
              let data = try? JSONEncoder().encode(scope) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

nonisolated enum MedicationNotificationIdentifierPolicy {
    private static let petDosePrefix = "medreminder_"
    private static let petEndPrefix = "medend_"
    private static let humanDosePrefix = "humanmedreminder_"

    static func petReminderPrefixes(for petID: UUID) -> [String] {
        [petDosePrefix + petID.uuidString, petEndPrefix + petID.uuidString]
    }

    static func humanReminderPrefix(for humanID: UUID) -> String {
        humanDosePrefix + humanID.uuidString
    }

    static func isHumanReminder(_ identifier: String) -> Bool {
        identifier.hasPrefix(humanDosePrefix)
    }

    static func humanReminderOwnerID(in identifier: String) -> UUID? {
        guard isHumanReminder(identifier) else { return nil }
        return subjectID(in: identifier, after: humanDosePrefix)
    }

    static func humanReminderMedicationID(in identifier: String) -> UUID? {
        guard isHumanReminder(identifier) else { return nil }
        let suffix = identifier.dropFirst(humanDosePrefix.count)
        let components = suffix.split(separator: "_", maxSplits: 2)
        guard components.count >= 2 else { return nil }
        return UUID(uuidString: String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func refreshPlan(pendingNotificationIDs: Set<String>) -> MedicationNotificationRefreshPlan {
        var notificationIDs: Set<String> = []
        var petIDs: Set<UUID> = []
        var humanIDs: Set<UUID> = []
        var unresolvedNotificationIDs: Set<String> = []

        for identifier in pendingNotificationIDs {
            let subject: (prefix: String, isHuman: Bool)? = if identifier.hasPrefix(petDosePrefix) {
                (petDosePrefix, false)
            } else if identifier.hasPrefix(petEndPrefix) {
                (petEndPrefix, false)
            } else if identifier.hasPrefix(humanDosePrefix) {
                (humanDosePrefix, true)
            } else {
                nil
            }
            guard let subject else { continue }

            notificationIDs.insert(identifier)
            guard let subjectID = subjectID(in: identifier, after: subject.prefix) else {
                unresolvedNotificationIDs.insert(identifier)
                continue
            }
            if subject.isHuman {
                humanIDs.insert(subjectID)
            } else {
                petIDs.insert(subjectID)
            }
        }

        return MedicationNotificationRefreshPlan(
            notificationIDs: notificationIDs,
            petIDs: petIDs,
            humanIDs: humanIDs,
            unresolvedNotificationIDs: unresolvedNotificationIDs
        )
    }

    static func medicationNotificationIDs(in identifiers: Set<String>) -> Set<String> {
        refreshPlan(pendingNotificationIDs: identifiers).notificationIDs
    }

    private static func subjectID(in identifier: String, after prefix: String) -> UUID? {
        let suffix = identifier.dropFirst(prefix.count)
        let rawID = suffix.split(separator: "_", maxSplits: 1).first.map(String.init) ?? ""
        return UUID(uuidString: rawID.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

nonisolated struct HumanMedicationReminderRollingRefreshResult: Equatable, Sendable {
    let removedNotificationCount: Int
    let scheduledNotificationCount: Int
    let hasMoreWork: Bool
    let wasDeferred: Bool
    let failureDescriptions: [String]

    var didSucceed: Bool { !wasDeferred && failureDescriptions.isEmpty }

    static let deferred = HumanMedicationReminderRollingRefreshResult(
        removedNotificationCount: 0,
        scheduledNotificationCount: 0,
        hasMoreWork: true,
        wasDeferred: true,
        failureDescriptions: []
    )
}

nonisolated enum HumanMedicationReminderRollingCursorStore {
    static let offsetKey = "ohana_human_medication_reminder_rolling_offset_v1"
    static let retryKey = "ohana_human_medication_reminder_rolling_retry_v1"

    static func offset(defaults: UserDefaults = .standard) -> Int {
        max(0, defaults.integer(forKey: offsetKey))
    }

    static func hasContinuation(defaults: UserDefaults = .standard) -> Bool {
        offset(defaults: defaults) > 0 || defaults.bool(forKey: retryKey)
    }

    static func record(
        nextOffset: Int?,
        needsRetry: Bool,
        defaults: UserDefaults = .standard
    ) {
        if let nextOffset, nextOffset > 0 {
            defaults.set(nextOffset, forKey: offsetKey)
        } else {
            defaults.removeObject(forKey: offsetKey)
        }
        defaults.set(needsRetry, forKey: retryKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: offsetKey)
        defaults.removeObject(forKey: retryKey)
    }
}

@MainActor
enum MedicationNotificationMutationFence {
    private static var deletedHumanIDs: Set<UUID> = []

    static func invalidateHuman(_ humanID: UUID) {
        deletedHumanIDs.insert(humanID)
    }

    static func allowsHuman(_ humanID: UUID?) -> Bool {
        guard let humanID else { return true }
        return !deletedHumanIDs.contains(humanID)
    }
}

nonisolated struct MedicationNotificationPrivacyRefreshResult: Equatable, Sendable {
    let replacedNotificationCount: Int
    let scheduledNotificationCount: Int
    let didFailSafeCancel: Bool
    let failureDescriptions: [String]

    var didSucceed: Bool { failureDescriptions.isEmpty }

    static let unavailable = MedicationNotificationPrivacyRefreshResult(
        replacedNotificationCount: 0,
        scheduledNotificationCount: 0,
        didFailSafeCancel: false,
        failureDescriptions: ["Medication notification refresh service is unavailable."]
    )
}

nonisolated enum MedicationNotificationBudget {
    @discardableResult
    static func reserve(
        notificationId: String,
        existingNotificationIds: inout Set<String>
    ) -> ReminderNotificationScheduleResult {
        guard !existingNotificationIds.contains(notificationId) else {
            return .skippedDuplicate
        }
        guard NotificationPendingBudget.hasCapacity(existingPendingCount: existingNotificationIds.count) else {
            return .skippedBudget(
                NotificationPendingBudget.skippedBudgetMetadataJSON(existingPendingCount: existingNotificationIds.count)
            )
        }
        existingNotificationIds.insert(notificationId)
        return .scheduled
    }

    static func metadataJSON(
        for result: ReminderNotificationScheduleResult,
        notificationId: String,
        scheduledAt: Date
    ) -> String {
        let base = "\"notificationId\":\"\(notificationId)\",\"scheduledAt\":\(scheduledAt.timeIntervalSince1970)"
        switch result {
        case .scheduled:
            return "{\(base)}"
        case .skippedDuplicate:
            return "{\(base),\"reason\":\"duplicate\"}"
        case let .skippedBudget(metadata):
            return "{\(base),\"reason\":\"budget\",\"budget\":\(metadata)}"
        case .skippedPastDue:
            return "{\(base),\"reason\":\"pastDue\"}"
        case .skippedInactiveMember:
            return "{\(base),\"reason\":\"inactiveMember\"}"
        case .missingEvent:
            return "{\(base),\"reason\":\"missingEvent\"}"
        case let .failed(message):
            return "{\(base),\"error\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        case let .deferred(metadata),
             let .skippedMerged(metadata),
             let .skippedUserDisabled(metadata):
            return "{\(base),\"policy\":\(metadata)}"
        }
    }

    static func skippedActionType(
        for result: ReminderNotificationScheduleResult,
        scheduledActionType: String
    ) -> String {
        switch result {
        case .skippedDuplicate:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Duplicate")
        case .skippedBudget:
            scheduledActionType.replacingOccurrences(of: "Success", with: "SkippedBudget")
        case .skippedPastDue:
            scheduledActionType.replacingOccurrences(of: "Success", with: "SkippedPastDue")
        case .skippedInactiveMember:
            scheduledActionType.replacingOccurrences(of: "Success", with: "SkippedInactiveMember")
        case .missingEvent:
            scheduledActionType.replacingOccurrences(of: "Success", with: "MissingEvent")
        case .failed:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Failed")
        case .deferred:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Deferred")
        case .skippedMerged:
            scheduledActionType.replacingOccurrences(of: "Success", with: "Merged")
        case .skippedUserDisabled:
            scheduledActionType.replacingOccurrences(of: "Success", with: "UserDisabled")
        case .scheduled:
            scheduledActionType
        }
    }
}

// MARK: - 频次 → 每日次数

extension PetMedicationFrequency {
    /// 每日应服次数（asNeeded / custom = 0 表示按需，不自动调度）
    nonisolated var dosesPerDay: Int {
        switch self {
        case .daily: 1
        case .twiceDaily: 2
        case .threeTimesDaily: 3
        case .everyOtherDay: 1 // 隔天算作1次
        case .weekly: 1 // 每周
        case .asNeeded: 0
        case .custom: 0
        }
    }
}

extension MedicationFrequency {
    nonisolated var dosesPerDay: Int {
        switch self {
        case .daily: 1
        case .twiceDaily: 2
        case .threeTimesDaily: 3
        case .weekly: 1
        case .asNeeded: 0
        case .custom: 0
        }
    }
}
