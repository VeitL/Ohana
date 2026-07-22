//
//  OhanaPlanCapabilities.swift
//  Ohana
//
//  Semantic Free / Personal / future Family capability matrix.
//

import Foundation

/// Product tiers stay orthogonal to the selected app experience mode.
///
/// Online guardian runtime remains independently feature-flagged. Owning a
/// Family product never turns network work on by itself.
nonisolated enum OhanaPlanLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case personal
    case family

    var hasPersonal: Bool {
        self == .personal || self == .family
    }

    var hasFamily: Bool {
        self == .family
    }
}

nonisolated enum PresenceAnalyticsAccess: Equatable, Sendable {
    /// Raw monthly calendar, selected subject, current/longest streak and
    /// accessible status labels are available without a subscription.
    case rawCalendar
    /// Adds 90-day, one-year and all-time trends, distributions, completion,
    /// comparison and export.
    case longRange
    /// Reserved for future operator attribution and audit views.
    case familyAudit
}

nonisolated struct PresenceReminderCapabilities: Equatable, Sendable {
    let maximumScheduleCount: Int
    let allowsWeekdaySchedules: Bool
    let allowsGracePeriod: Bool
    let allowsSecondLocalReminder: Bool
    let allowsServerGuardianEscalation: Bool

    /// The accepted product range for Personal/Family grace periods.
    static let gracePeriodMinutes = 15 ... 180
}

nonisolated struct PresenceContactCapabilities: Equatable, Sendable {
    let maximumLocalContacts: Int
    let allowsEditableMessageTemplate: Bool
    let allowsAcceptedFamilyGuardians: Bool
    let allowsAutomaticExternalMessaging: Bool
    let maximumAcceptedGuardians: Int
}

nonisolated struct OhanaPlanCapabilities: Equatable, Sendable {
    let plan: OhanaPlanLevel
    let analytics: PresenceAnalyticsAccess
    let reminders: PresenceReminderCapabilities
    let contacts: PresenceContactCapabilities

    /// Rewards, Oasis access and gacha odds deliberately do not appear here:
    /// all plans use the same economy and the same base Oasis features.
    static func make(for plan: OhanaPlanLevel) -> Self {
        switch plan {
        case .free:
            OhanaPlanCapabilities(
                plan: plan,
                analytics: .rawCalendar,
                reminders: PresenceReminderCapabilities(
                    maximumScheduleCount: 1,
                    allowsWeekdaySchedules: false,
                    allowsGracePeriod: false,
                    allowsSecondLocalReminder: false,
                    allowsServerGuardianEscalation: false
                ),
                contacts: PresenceContactCapabilities(
                    maximumLocalContacts: 0,
                    allowsEditableMessageTemplate: false,
                    allowsAcceptedFamilyGuardians: false,
                    allowsAutomaticExternalMessaging: false,
                    maximumAcceptedGuardians: 0
                )
            )
        case .personal:
            OhanaPlanCapabilities(
                plan: plan,
                analytics: .longRange,
                reminders: PresenceReminderCapabilities(
                    maximumScheduleCount: 7,
                    allowsWeekdaySchedules: true,
                    allowsGracePeriod: true,
                    allowsSecondLocalReminder: true,
                    allowsServerGuardianEscalation: false
                ),
                contacts: PresenceContactCapabilities(
                    maximumLocalContacts: 0,
                    allowsEditableMessageTemplate: false,
                    allowsAcceptedFamilyGuardians: false,
                    allowsAutomaticExternalMessaging: false,
                    maximumAcceptedGuardians: 0
                )
            )
        case .family:
            OhanaPlanCapabilities(
                plan: plan,
                analytics: .familyAudit,
                reminders: PresenceReminderCapabilities(
                    maximumScheduleCount: 7,
                    allowsWeekdaySchedules: true,
                    allowsGracePeriod: true,
                    allowsSecondLocalReminder: true,
                    allowsServerGuardianEscalation: true
                ),
                contacts: PresenceContactCapabilities(
                    maximumLocalContacts: 0,
                    allowsEditableMessageTemplate: false,
                    allowsAcceptedFamilyGuardians: true,
                    allowsAutomaticExternalMessaging: false,
                    maximumAcceptedGuardians: 3
                )
            )
        }
    }
}

extension CommerceEntitlementService {
    var ohanaPlanLevel: OhanaPlanLevel {
        if hasFamilyEntitlement { return .family }
        return hasPersonalEntitlement ? .personal : .free
    }

    var ohanaPlanCapabilities: OhanaPlanCapabilities {
        .make(for: ohanaPlanLevel)
    }
}
