//
//  NotificationDeliveryPolicy.swift
//  Ohana
//
//  GAP-6 notification classification, daily budget, merge, and quiet-hours policy.
//

import Foundation

enum NotificationDeliveryTier: String, Equatable {
    case healthCritical
    case routine
    case ambient
}

enum NotificationDeliveryCategory: String, Equatable {
    case medication
    case health
    case foodStock
    case feeding
    case hydration
    case hygiene
    case plantCare
    case insurance
    case calendar
    case weeklyReport
}

nonisolated enum NotificationPreferenceGroup: String, CaseIterable, Equatable {
    case medication
    case feeding
    case hygiene
    case checkIn

    var storageKey: String {
        switch self {
        case .medication: "notif_medication_enabled"
        case .feeding: "notif_feeding_enabled"
        case .hygiene: "notif_hygiene_enabled"
        case .checkIn: "notif_checkin_enabled"
        }
    }

    static func groups(for category: NotificationDeliveryCategory) -> [NotificationPreferenceGroup] {
        switch category {
        case .medication:
            [.medication]
        case .feeding, .foodStock:
            [.feeding]
        case .hygiene:
            [.hygiene]
        case .calendar, .weeklyReport:
            [.checkIn]
        case .health, .hydration, .plantCare, .insurance:
            []
        }
    }
}

nonisolated enum NotificationPreferenceStore {
    static func isEnabled(_ group: NotificationPreferenceGroup, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: group.storageKey) == nil ? true : defaults.bool(forKey: group.storageKey)
    }

    static func set(_ value: Bool, for group: NotificationPreferenceGroup, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: group.storageKey)
    }

    static func isCategoryEnabled(_ category: NotificationDeliveryCategory, defaults: UserDefaults = .standard) -> Bool {
        NotificationPreferenceGroup.groups(for: category).allSatisfy { isEnabled($0, defaults: defaults) }
    }
}

struct NotificationDeliveryClassification: Equatable {
    let tier: NotificationDeliveryTier
    let category: NotificationDeliveryCategory
    let mergeAllowed: Bool
}

enum NotificationDeliveryDecision: Equatable {
    case deliver(deliveryDate: Date, classification: NotificationDeliveryClassification, deferred: Bool)
    case skippedBudget(classification: NotificationDeliveryClassification, scheduledAt: Date)
    case merged(classification: NotificationDeliveryClassification, scheduledAt: Date, mergedInto: UUID)
    case skippedUserDisabled(classification: NotificationDeliveryClassification, scheduledAt: Date)

    var classification: NotificationDeliveryClassification {
        switch self {
        case let .deliver(_, classification, _),
             let .skippedBudget(classification, _),
             let .merged(classification, _, _),
             let .skippedUserDisabled(classification, _):
            classification
        }
    }

    var deliveryDate: Date? {
        guard case let .deliver(deliveryDate, _, _) = self else { return nil }
        return deliveryDate
    }

    var isDeferred: Bool {
        guard case let .deliver(_, _, deferred) = self else { return false }
        return deferred
    }

    var metadataJSON: String {
        let tier = classification.tier.rawValue
        let category = classification.category.rawValue
        switch self {
        case let .deliver(deliveryDate, _, deferred):
            return "{\"tier\":\"\(tier)\",\"category\":\"\(category)\",\"deliveryAt\":\(deliveryDate.timeIntervalSince1970),\"deferred\":\(deferred)}"
        case let .skippedBudget(_, scheduledAt):
            return "{\"tier\":\"\(tier)\",\"category\":\"\(category)\",\"scheduledAt\":\(scheduledAt.timeIntervalSince1970),\"reason\":\"budget\"}"
        case let .merged(_, scheduledAt, mergedInto):
            return "{\"tier\":\"\(tier)\",\"category\":\"\(category)\",\"scheduledAt\":\(scheduledAt.timeIntervalSince1970),\"reason\":\"merged\",\"mergedInto\":\"\(mergedInto.uuidString)\"}"
        case let .skippedUserDisabled(_, scheduledAt):
            return "{\"tier\":\"\(tier)\",\"category\":\"\(category)\",\"scheduledAt\":\(scheduledAt.timeIntervalSince1970),\"reason\":\"userDisabled\"}"
        }
    }
}

nonisolated enum NotificationDeliveryPolicy {
    static let routineDailyLimit = 4
    static let ambientDailyLimit = 1
    static let nonCriticalDailyLimit = 5

    static func classification(for event: Event) -> NotificationDeliveryClassification {
        if event.eventType == EventType.petMedication.rawValue ||
            event.eventType == EventType.petMedicationDose.rawValue ||
            event.eventType == EventType.medication.rawValue {
            return NotificationDeliveryClassification(tier: .healthCritical, category: .medication, mergeAllowed: false)
        }

        if event.eventType == EventType.vaccine.rawValue ||
            event.eventType == EventType.externalDeworming.rawValue ||
            event.eventType == EventType.internalDeworming.rawValue ||
            event.eventType == EventType.vetVisit.rawValue ||
            event.eventType == EventType.health.rawValue {
            return NotificationDeliveryClassification(tier: .healthCritical, category: .health, mergeAllowed: false)
        }

        if event.relatedEntityType == "pet_food_stock" {
            return NotificationDeliveryClassification(tier: .healthCritical, category: .foodStock, mergeAllowed: false)
        }

        if event.eventType == EventType.foodChange.rawValue {
            return NotificationDeliveryClassification(tier: .routine, category: .feeding, mergeAllowed: true)
        }

        if event.eventType == EventType.watering.rawValue {
            return NotificationDeliveryClassification(tier: .routine, category: .hydration, mergeAllowed: true)
        }

        if event.eventType == EventType.litterBox.rawValue ||
            event.eventType == EventType.grooming.rawValue {
            return NotificationDeliveryClassification(tier: .routine, category: .hygiene, mergeAllowed: true)
        }

        if event.eventType == EventType.fertilizing.rawValue {
            return NotificationDeliveryClassification(tier: .routine, category: .plantCare, mergeAllowed: true)
        }

        if event.eventType == EventType.insurancePremium.rawValue {
            return NotificationDeliveryClassification(tier: .routine, category: .insurance, mergeAllowed: true)
        }

        if event.eventType == EventType.birthday.rawValue ||
            event.eventType == EventType.anniversary.rawValue {
            return NotificationDeliveryClassification(tier: .ambient, category: .calendar, mergeAllowed: true)
        }

        return NotificationDeliveryClassification(tier: .routine, category: .calendar, mergeAllowed: true)
    }

    static func weeklyReportClassification() -> NotificationDeliveryClassification {
        NotificationDeliveryClassification(tier: .ambient, category: .weeklyReport, mergeAllowed: true)
    }

    static func plan(reminders: [Reminder], calendar: Calendar = .current) -> [UUID: NotificationDeliveryDecision] {
        var decisions: [UUID: NotificationDeliveryDecision] = [:]
        var routineCountByDay: [String: Int] = [:]
        var ambientCountByDay: [String: Int] = [:]
        var nonCriticalCountByDay: [String: Int] = [:]
        var mergeBuckets: [String: UUID] = [:]

        for reminder in reminders.sorted(by: reminderSort) {
            guard let event = reminder.event else { continue }
            let classification = classification(for: event)
            guard NotificationPreferenceStore.isCategoryEnabled(classification.category) else {
                decisions[reminder.id] = .skippedUserDisabled(
                    classification: classification,
                    scheduledAt: reminder.scheduledAt
                )
                continue
            }
            let delivery = deliveryDate(for: reminder.scheduledAt, classification: classification, calendar: calendar)
            let deferred = delivery != reminder.scheduledAt
            let dayKey = dayKey(for: delivery, calendar: calendar)

            if classification.mergeAllowed {
                let key = mergeKey(for: event, classification: classification, deliveryDate: delivery, calendar: calendar)
                if let existing = mergeBuckets[key] {
                    decisions[reminder.id] = .merged(
                        classification: classification,
                        scheduledAt: reminder.scheduledAt,
                        mergedInto: existing
                    )
                    continue
                }
            }

            if classification.tier != .healthCritical {
                let routineCount = routineCountByDay[dayKey, default: 0]
                let ambientCount = ambientCountByDay[dayKey, default: 0]
                let nonCriticalCount = nonCriticalCountByDay[dayKey, default: 0]
                let exceedsTierLimit =
                    (classification.tier == .routine && routineCount >= routineDailyLimit) ||
                    (classification.tier == .ambient && ambientCount >= ambientDailyLimit)
                if exceedsTierLimit || nonCriticalCount >= nonCriticalDailyLimit {
                    decisions[reminder.id] = .skippedBudget(
                        classification: classification,
                        scheduledAt: reminder.scheduledAt
                    )
                    continue
                }
                nonCriticalCountByDay[dayKey] = nonCriticalCount + 1
                if classification.tier == .routine {
                    routineCountByDay[dayKey] = routineCount + 1
                } else {
                    ambientCountByDay[dayKey] = ambientCount + 1
                }
            }

            decisions[reminder.id] = .deliver(
                deliveryDate: delivery,
                classification: classification,
                deferred: deferred
            )
            if classification.mergeAllowed {
                let key = mergeKey(for: event, classification: classification, deliveryDate: delivery, calendar: calendar)
                mergeBuckets[key] = reminder.id
            }
        }

        return decisions
    }

    static func deliveryDate(
        for scheduledAt: Date,
        classification: NotificationDeliveryClassification,
        calendar: Calendar = .current
    ) -> Date {
        guard classification.tier != .healthCritical else { return scheduledAt }
        let hour = calendar.component(.hour, from: scheduledAt)
        if hour >= 22 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: scheduledAt) ?? scheduledAt.addingTimeInterval(86400)
            return calendar.date(bySettingHour: 8, minute: 30, second: 0, of: nextDay) ?? nextDay
        }
        if hour < 8 {
            return calendar.date(bySettingHour: 8, minute: 30, second: 0, of: scheduledAt) ?? scheduledAt
        }
        return scheduledAt
    }

    static func userInfo(for classification: NotificationDeliveryClassification) -> [AnyHashable: Any] {
        [
            "notificationTier": classification.tier.rawValue,
            "notificationCategory": classification.category.rawValue
        ]
    }

    private static func reminderSort(_ left: Reminder, _ right: Reminder) -> Bool {
        if left.scheduledAt != right.scheduledAt {
            return left.scheduledAt < right.scheduledAt
        }
        return left.createdAt < right.createdAt
    }

    private static func mergeKey(
        for event: Event,
        classification: NotificationDeliveryClassification,
        deliveryDate: Date,
        calendar: Calendar
    ) -> String {
        [
            dayKey(for: deliveryDate, calendar: calendar),
            classification.tier.rawValue,
            classification.category.rawValue,
            subjectKey(for: event)
        ].joined(separator: "|")
    }

    private static func subjectKey(for event: Event) -> String {
        let rawId = event.relatedEntityId
        let normalizedId = rawId.split(separator: ":", maxSplits: 1).first.map(String.init) ?? rawId
        return "\(event.relatedEntityType):\(normalizedId)"
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
