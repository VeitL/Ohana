//
//  OhanaPlanCapabilities.swift
//  Ohana
//
//  Semantic Free / Personal / future Family capability matrix.
//

import Foundation

/// Product tiers stay orthogonal to the selected app experience mode.
///
/// `family` is intentionally a domain value only in the Solo build. No current
/// StoreKit product maps to it and no network runtime is enabled by this type.
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
                    maximumLocalContacts: 1,
                    allowsEditableMessageTemplate: false,
                    allowsAcceptedFamilyGuardians: false,
                    allowsAutomaticExternalMessaging: false
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
                    maximumLocalContacts: 3,
                    allowsEditableMessageTemplate: true,
                    allowsAcceptedFamilyGuardians: false,
                    allowsAutomaticExternalMessaging: false
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
                    maximumLocalContacts: 3,
                    allowsEditableMessageTemplate: true,
                    allowsAcceptedFamilyGuardians: true,
                    allowsAutomaticExternalMessaging: false
                )
            )
        }
    }
}

extension CommerceEntitlementService {
    /// Shipping builds currently map only existing Free and Personal products.
    /// A future Family entitlement resolver can compose this value without
    /// changing presence-domain decisions.
    var ohanaPlanLevel: OhanaPlanLevel {
        hasPersonalEntitlement ? .personal : .free
    }

    var ohanaPlanCapabilities: OhanaPlanCapabilities {
        .make(for: ohanaPlanLevel)
    }
}
