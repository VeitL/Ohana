//
//  FeedingPlanWriter.swift
//  Ohana
//

import Foundation
import SwiftData

struct FeedingPlanWriteResult {
    let events: [Event]
    let reminders: [Reminder]
}

enum FeedingPlanWriter {
    nonisolated static let stockReminderEntityType = "pet_food_stock"
    private static let manualReminderWindowDays = 14

    @MainActor
    @discardableResult
    static func replacePlan(
        pet: Pet,
        draft: FeedPlanDraft,
        allEvents: [Event],
        context: ModelContext,
        feedPlanGroupId: String = "",
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FeedingPlanWriteResult {
        CarePlanCalendarSync.suppressDefaultPlan(kind: "feed", pet: pet, context: context)
        deletePlan(pet: pet, kind: draft.kind, allEvents: allEvents, context: context, save: false)

        let meals = FeedPlanDraft.normalizedMeals(draft.meals, count: draft.dailyCount, now: now, calendar: calendar)
        var createdEvents: [Event] = []
        var createdReminders: [Reminder] = []

        for meal in meals {
            let startDate = nextOccurrenceDate(forTimeOfDay: meal.time, after: now, calendar: calendar)
            let event = Event(
                title: FeedRuleMetadata.title(kind: draft.kind, date: startDate, amountGrams: meal.grams, foodKind: meal.foodKind),
                startDate: startDate,
                eventType: EventType.foodChange.rawValue,
                relatedEntityType: draft.kind == .autoFeeder ? FeedRuleMetadata.autoFeederEntityType : EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            )
            event.recurrenceDays = 1
            event.feedRuleKindRaw = draft.kind.rawValue
            event.foodKindRaw = meal.foodKind.rawValue
            event.feedAmountGrams = meal.grams
            event.feedPlanGroupId = feedPlanGroupId
            context.insert(event)
            createdEvents.append(event)

            if draft.kind == .manualReminder {
                createdReminders.append(contentsOf: createUpcomingManualReminders(for: event, context: context, now: now, calendar: calendar))
            }
        }

        if let firstAmount = meals.first(where: { $0.grams > 0 })?.grams {
            pet.dailyPortionGrams = firstAmount
        }

        context.safeSave()
        return FeedingPlanWriteResult(events: createdEvents, reminders: createdReminders)
    }

    @MainActor
    static func deletePlan(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event],
        context: ModelContext,
        save: Bool = true
    ) {
        var didDelete = false
        for event in planEvents(pet: pet, kind: kind, allEvents: allEvents) {
            deleteEvent(event, context: context)
            didDelete = true
        }
        if save, didDelete {
            context.safeSave()
        }
    }

    @MainActor
    static func deactivateManualReminderOperations(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date()
    ) {
        var didChange = false
        for event in planEvents(pet: pet, kind: .manualReminder, allEvents: allEvents) {
            let pendingReminders = event.reminders.filter(\.isPending)
            for reminder in pendingReminders {
                OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
                if reminder.scheduledAt > now {
                    context.delete(reminder)
                    didChange = true
                }
            }
        }
        if didChange {
            context.safeSave()
        }
    }

    @MainActor
    static func clearFeedModePlans(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) {
        CarePlanCalendarSync.suppressDefaultPlan(kind: "feed", pet: pet, context: context)
        deletePlan(pet: pet, kind: .manualReminder, allEvents: allEvents, context: context)
        deletePlan(pet: pet, kind: .autoFeeder, allEvents: allEvents, context: context)
    }

    @MainActor
    @discardableResult
    static func ensureUpcomingManualReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        var created: [Reminder] = []
        for event in planEvents(pet: pet, kind: .manualReminder, allEvents: allEvents) {
            created.append(contentsOf: createUpcomingManualReminders(for: event, context: context, now: now, calendar: calendar))
        }
        if !created.isEmpty {
            context.safeSave()
        }
        return created
    }

    static func planEvents(pet: Pet, kind: FeedRuleKind, allEvents: [Event]) -> [Event] {
        allEvents
            .filter {
                switch kind {
                case .manualReminder:
                    FeedRuleMetadata.isManualReminderEvent($0, pet: pet)
                case .autoFeeder:
                    FeedRuleMetadata.isAutoFeederEvent($0, pet: pet)
                }
            }
            .sorted { $0.startDate < $1.startDate }
    }

    @MainActor
    @discardableResult
    static func saveFoodPurchase(
        pet: Pet,
        brand: String,
        totalGrams: Double,
        purchaseDate: Date?,
        openDate: Date? = nil,
        dailyGrams: Double?,
        foodKind: FeedFoodKind = .dry,
        calculationMode: FeedStockCalculationMode = .manualOrPlan,
        reminderEnabled: Bool,
        reminderAdvanceDays: Int,
        executorId: String?,
        allEvents: [Event],
        context: ModelContext,
        recordToUpdate: PetFoodRecord? = nil,
        now: Date = Date(),
        calendar: Calendar = .current,
        rebuildReminder: Bool = true
    ) -> PetFoodRecord {
        let sanitizedTotal = max(0, totalGrams)
        let sanitizedDaily = max(0, dailyGrams ?? pet.dailyPortionGrams)
        let finalBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPurchaseDate = purchaseDate.map { calendar.startOfDay(for: $0) }
        let openSourceDate = openDate ?? purchaseDate ?? now
        let openDay = calendar.startOfDay(for: openSourceDate)
        let finalOpenDate = calendar.isDate(openDay, inSameDayAs: now) ? now : openDay

        pet.foodTrackingMode = .precise
        if foodKind == .dry {
            pet.restockDate = finalOpenDate
            pet.casualOpenDate = finalOpenDate
            pet.restockWeight = sanitizedTotal / 1000
        }
        pet.foodReminderEnabled = reminderEnabled
        pet.foodReminderAdvanceDays = reminderAdvanceDays
        if !finalBrand.isEmpty { pet.foodBrand = finalBrand }

        let record = recordToUpdate ?? PetFoodRecord(pet: pet, executorId: executorId)
        record.brand = finalBrand.isEmpty ? pet.foodBrand : finalBrand
        record.dailyGrams = sanitizedDaily
        record.totalGrams = sanitizedTotal
        record.foodKindRaw = foodKind.rawValue
        record.purchaseDate = finalPurchaseDate
        record.startDate = finalOpenDate
        record.pet = pet
        record.executorId = executorId
        if recordToUpdate != nil {
            record.remainingCorrectionGrams = nil
            record.remainingCorrectionDate = nil
        }
        record.calculationModeRaw = calculationMode.rawValue
        record.notes = FeedStockRecordMetadata.notesScrubbingLegacyCalculationMode(
            stockRecordNote(foodKind: foodKind, totalGrams: sanitizedTotal)
        )
        if recordToUpdate == nil {
            context.insert(record)
        }
        context.safeSave()

        if rebuildReminder {
            _ = rebuildFoodStockReminder(
                pet: pet,
                allEvents: allEvents,
                context: context,
                now: now,
                calendar: calendar
            )
        }
        return record
    }

    private static func stockRecordNote(foodKind: FeedFoodKind, totalGrams: Double, l: L10n = L10n()) -> String {
        let grams = Int(totalGrams.rounded())
        let kindTitle = foodKind.title(l)
        return l.tr(
            zh: "\(kindTitle)补粮 · \(grams)g",
            en: "\(kindTitle) refill · \(grams)g",
            de: "\(kindTitle) aufgefüllt · \(grams)g"
        )
    }

    @MainActor
    @discardableResult
    static func correctFoodStock(
        record: PetFoodRecord,
        remainingGrams: Double,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        rebuildReminder: Bool = true
    ) -> Reminder? {
        record.remainingCorrectionGrams = max(0, remainingGrams)
        record.remainingCorrectionDate = now
        context.safeSave()
        guard let pet = record.pet else { return nil }
        guard rebuildReminder else { return nil }
        return rebuildFoodStockReminder(pet: pet, allEvents: allEvents, context: context, now: now, calendar: calendar)
    }

    @MainActor
    @discardableResult
    static func rebuildFoodStockReminder(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Reminder? {
        rebuildFoodStockReminders(pet: pet, allEvents: allEvents, context: context, now: now, calendar: calendar).first
    }

    @MainActor
    @discardableResult
    static func rebuildFoodStockReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        for event in currentStockReminderEvents(pet: pet, allEvents: allEvents, context: context) {
            deleteEvent(event, context: context)
        }

        guard pet.foodReminderEnabled else {
            context.safeSave()
            return []
        }

        var reminders: [Reminder] = []
        for foodKind in FeedFoodKind.allCases {
            let snapshot = FeedStockCalculator.snapshot(for: pet, foodKind: foodKind, events: allEvents, now: now, calendar: calendar)
            guard snapshot.totalGrams > 0,
                  let reminderDate = foodReminderDate(pet: pet, snapshot: snapshot, calendar: calendar),
                  reminderDate > now else { continue }
            let event = Event(
                title: stockReminderTitle(pet: pet, foodKind: foodKind),
                startDate: reminderDate,
                eventType: EventType.shoppingList.rawValue,
                relatedEntityType: stockReminderEntityType,
                relatedEntityId: stockReminderEntityId(pet: pet, foodKind: foodKind)
            )
            event.foodKindRaw = foodKind.rawValue
            let reminder = Reminder(event: event, scheduledAt: reminderDate)
            context.insert(event)
            context.insert(reminder)
            reminders.append(reminder)
        }
        context.safeSave()
        return reminders
    }

    private static func stockReminderTitle(pet: Pet, foodKind: FeedFoodKind, l: L10n = L10n()) -> String {
        let kindTitle = foodKind.title(l)
        return l.tr(
            zh: "\(pet.name) \(kindTitle)快要断粮了，记得补充粮仓",
            en: "\(pet.name)'s \(kindTitle) is almost out. Refill the food stock.",
            de: "\(pet.name): \(kindTitle) ist bald leer. Bitte Vorrat auffuellen."
        )
    }

    static func stockReminderEvents(pet: Pet, allEvents: [Event]) -> [Event] {
        allEvents.filter {
            $0.relatedEntityType == stockReminderEntityType &&
                ($0.relatedEntityId == pet.id.uuidString || $0.relatedEntityId.hasPrefix("\(pet.id.uuidString):"))
        }
    }

    static func stockReminderEntityId(pet: Pet, foodKind: FeedFoodKind) -> String {
        "\(pet.id.uuidString):\(foodKind.rawValue)"
    }

    @MainActor
    private static func currentStockReminderEvents(pet: Pet, allEvents: [Event], context: ModelContext) -> [Event] {
        var eventsById: [UUID: Event] = [:]
        for event in stockReminderEvents(pet: pet, allEvents: allEvents) {
            eventsById[event.id] = event
        }

        let stockType = stockReminderEntityType
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == stockType
            }
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        for event in stockReminderEvents(pet: pet, allEvents: fetched) {
            eventsById[event.id] = event
        }
        return eventsById.values.sorted { $0.startDate < $1.startDate }
    }

    static func foodReminderDate(
        pet: Pet,
        snapshot: FeedStockSnapshot,
        calendar: Calendar = .current
    ) -> Date? {
        guard let runOut = snapshot.runOutDate else { return nil }
        let raw = calendar.date(byAdding: .day, value: -pet.foodReminderAdvanceDays, to: runOut) ?? runOut
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: raw) ?? raw
    }

    @MainActor
    private static func deleteEvent(_ event: Event, context: ModelContext) {
        for reminder in event.reminders {
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            context.delete(reminder)
        }
        context.delete(event)
    }

    @MainActor
    private static func createUpcomingManualReminders(
        for event: Event,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Reminder] {
        let existingKeys = Set(event.reminders.map { reminderKey(eventId: event.id, scheduledAt: $0.scheduledAt) })
        var created: [Reminder] = []

        for occurrence in upcomingOccurrences(for: event, now: now, daysAhead: manualReminderWindowDays, calendar: calendar) {
            let key = reminderKey(eventId: event.id, scheduledAt: occurrence)
            guard !existingKeys.contains(key) else { continue }
            let reminder = Reminder(event: event, scheduledAt: occurrence)
            context.insert(reminder)
            created.append(reminder)
        }
        return created
    }

    private static func upcomingOccurrences(
        for event: Event,
        now: Date,
        daysAhead: Int,
        calendar: Calendar
    ) -> [Date] {
        let intervalDays = max(event.recurrenceDays, 1)
        let end = calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now.addingTimeInterval(Double(daysAhead) * 86400)
        var cursor = event.startDate
        var guardCount = 0

        while cursor < now, guardCount < 500 {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }

        var occurrences: [Date] = []
        while cursor <= end, guardCount < 1000 {
            occurrences.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return occurrences
    }

    private static func nextOccurrenceDate(forTimeOfDay time: Date, after now: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var candidate = calendar.date(
            bySettingHour: components.hour ?? 8,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86400)
        }
        return candidate
    }

    private static func reminderKey(eventId: UUID, scheduledAt: Date) -> String {
        "\(eventId.uuidString):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }
}
