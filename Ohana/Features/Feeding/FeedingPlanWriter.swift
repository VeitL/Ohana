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
    nonisolated static let stockReminderEntityType = DomainEntityLinkRegistry.petFoodStock
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
        guard canWriteActiveFeedData(for: pet) else {
            return FeedingPlanWriteResult(events: [], reminders: [])
        }
        CarePlanCalendarSync.suppressDefaultPlan(kind: "feed", pet: pet, context: context)
        deletePlan(pet: pet, kind: draft.kind, allEvents: allEvents, context: context, save: false)

        let meals = FeedPlanDraft.normalizedMeals(draft.meals, count: draft.dailyCount, now: now, calendar: calendar)
        var createdEvents: [Event] = []
        var createdReminders: [Reminder] = []

        for meal in meals {
            let startDate = nextOccurrenceDate(forTimeOfDay: meal.time, after: now, calendar: calendar)
            let relatedEntityType = draft.kind == .autoFeeder ? FeedRuleMetadata.autoFeederEntityType : EntityKind.pet.rawValue
            let intent = DomainScheduleCreateIntent(
                title: FeedRuleMetadata.title(kind: draft.kind, date: startDate, amountGrams: meal.grams, foodKind: meal.foodKind),
                startDate: startDate,
                eventType: EventType.foodChange.rawValue,
                relatedEntityType: relatedEntityType,
                relatedEntityId: pet.id.uuidString,
                recurrenceDays: 1,
                writeKind: .care,
                source: .domainService
            )
            guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
                continue
            }
            let event = DomainScheduleWriter.createEvent(plan: plan, context: context).event
            event.feedRuleKindRaw = draft.kind.rawValue
            event.foodKindRaw = meal.foodKind.rawValue
            event.feedAmountGrams = meal.grams
            event.feedPlanGroupId = feedPlanGroupId
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: startDate)
            createdEvents.append(event)

            if draft.kind == .manualReminder {
                createdReminders.append(contentsOf: createUpcomingManualReminders(for: event, context: context, now: now, calendar: calendar))
            }
        }

        if let firstAmount = meals.first(where: { $0.grams > 0 })?.grams {
            pet.dailyPortionGrams = firstAmount
            CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: now)
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
        guard canWriteActiveFeedData(for: pet) else { return }
        var didDelete = false
        for event in planEvents(pet: pet, kind: kind, allEvents: allEvents) {
            if deleteEvent(event, context: context).didDelete {
                didDelete = true
            }
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
        guard canWriteActiveFeedData(for: pet) else { return }
        var didChange = false
        for event in planEvents(pet: pet, kind: .manualReminder, allEvents: allEvents) {
            let pendingReminders = event.reminders.filter(\.isPending)
            for reminder in pendingReminders {
                if reminder.scheduledAt > now {
                    guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                        reminder: reminder,
                        writeKind: .care,
                        source: .domainService,
                        context: context
                    ) else { continue }
                    let result = DomainScheduleWriter.deleteReminder(reminder, mutation: mutation, context: context)
                    DomainScheduleEffectsDispatcher.dispatch(delete: result)
                    didChange = result.didDelete || didChange
                } else {
                    OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
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
        guard canWriteActiveFeedData(for: pet) else { return }
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
        guard canWriteActiveFeedData(for: pet) else { return [] }
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
        guard canWriteActiveFeedData(for: pet) else {
            return recordToUpdate ?? PetFoodRecord(executorId: executorId)
        }
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
        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: now)
        CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: finalOpenDate)
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
        guard let pet = record.pet, canWriteActiveFeedData(for: pet) else { return nil }
        record.remainingCorrectionGrams = max(0, remainingGrams)
        record.remainingCorrectionDate = now
        CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: now)
        context.safeSave()
        guard rebuildReminder else { return nil }
        return rebuildFoodStockReminder(pet: pet, allEvents: allEvents, context: context, now: now, calendar: calendar)
    }

    @discardableResult
    nonisolated static func rebuildFoodStockReminder(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Reminder? {
        guard canWriteActiveFeedData(for: pet) else { return nil }
        return rebuildFoodStockReminders(pet: pet, allEvents: allEvents, context: context, now: now, calendar: calendar).first
    }

    @discardableResult
    nonisolated static func rebuildFoodStockReminders(
        pets: [Pet],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        guard !pets.isEmpty else { return [] }
        let allEvents = allEventsForStockReminderRebuild(context: context)
        var seen = Set<UUID>()
        var reminders: [Reminder] = []
        for pet in pets where seen.insert(pet.id).inserted && canWriteActiveFeedData(for: pet) {
            reminders.append(contentsOf: rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context,
                now: now,
                calendar: calendar
            ))
        }
        return reminders
    }

    @discardableResult
    nonisolated static func rebuildFoodStockReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        guard canWriteActiveFeedData(for: pet) else { return [] }
        for event in currentStockReminderEvents(pet: pet, allEvents: allEvents, context: context) {
            _ = deleteEvent(event, context: context)
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
            let intent = DomainScheduleCreateIntent(
                title: stockReminderTitle(pet: pet, foodKind: foodKind),
                startDate: reminderDate,
                eventType: EventType.shoppingList.rawValue,
                relatedEntityType: stockReminderEntityType,
                relatedEntityId: stockReminderEntityId(pet: pet, foodKind: foodKind),
                reminderDates: [reminderDate],
                writeKind: .care,
                source: .domainService
            )
            guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
                continue
            }
            let result = DomainScheduleWriter.createEvent(plan: plan, context: context)
            let event = result.event
            event.foodKindRaw = foodKind.rawValue
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: reminderDate)
            for reminder in result.reminders {
                CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: reminderDate)
                reminders.append(reminder)
            }
        }
        context.safeSave()
        return reminders
    }

    private nonisolated static func stockReminderTitle(pet: Pet, foodKind: FeedFoodKind, l: L10n = L10n()) -> String {
        let kindTitle = foodKind.title(l)
        return l.tr(
            zh: "\(pet.name) \(kindTitle)快要断粮了，记得补充粮仓",
            en: "\(pet.name)'s \(kindTitle) is almost out. Refill the food stock.",
            de: "\(pet.name): \(kindTitle) ist bald leer. Bitte Vorrat auffuellen."
        )
    }

    nonisolated static func stockReminderEvents(pet: Pet, allEvents: [Event]) -> [Event] {
        allEvents.filter {
            DomainEntityLinkRegistry.role(for: $0) == .petFoodStock &&
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet($0, petId: pet.id.uuidString)
        }
    }

    nonisolated static func stockReminderEntityId(pet: Pet, foodKind: FeedFoodKind) -> String {
        "\(pet.id.uuidString):\(foodKind.rawValue)"
    }

    private nonisolated static func currentStockReminderEvents(pet: Pet, allEvents: [Event], context: ModelContext) -> [Event] {
        var eventsById: [UUID: Event] = [:]
        for event in stockReminderEvents(pet: pet, allEvents: allEvents) {
            eventsById[event.id] = event
        }

        let descriptor = FetchDescriptor<Event>()
        do {
            let fetched = try context.fetch(descriptor)
            for event in stockReminderEvents(pet: pet, allEvents: fetched) {
                eventsById[event.id] = event
            }
        } catch {
            OhanaLog.warning(
                "FeedingPlanWriter failed to fetch stock reminder events: \(error.localizedDescription)",
                category: "Care"
            )
        }
        return eventsById.values.sorted { $0.startDate < $1.startDate }
    }

    private nonisolated static func canWriteActiveFeedData(for pet: Pet) -> Bool {
        MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsDerivedEffects
    }

    nonisolated static func foodReminderDate(
        pet: Pet,
        snapshot: FeedStockSnapshot,
        calendar: Calendar = .current
    ) -> Date? {
        guard let runOut = snapshot.runOutDate else { return nil }
        let raw = calendar.date(byAdding: .day, value: -pet.foodReminderAdvanceDays, to: runOut) ?? runOut
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: raw) ?? raw
    }

    private nonisolated static func deleteEvent(_ event: Event, context: ModelContext) -> DomainScheduleDeleteResult {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .care,
            source: .domainService,
            context: context
        ) else { return .notDeleted }
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
        DomainScheduleEffectsDispatcher.dispatch(delete: result)
        return result
    }

    private nonisolated static func allEventsForStockReminderRebuild(context: ModelContext) -> [Event] {
        do {
            return try context.fetch(FetchDescriptor<Event>())
        } catch {
            OhanaLog.warning(
                "FeedingPlanWriter failed to fetch events for stock reminder rebuild: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    private static func createUpcomingManualReminders(
        for event: Event,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [Reminder] {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .care,
            context: context
        ) else { return [] }
        let existingKeys = Set(event.reminders.map { reminderKey(eventId: event.id, scheduledAt: $0.scheduledAt) })
        var created: [Reminder] = []

        for occurrence in upcomingOccurrences(for: event, now: now, daysAhead: manualReminderWindowDays, calendar: calendar) {
            let key = reminderKey(eventId: event.id, scheduledAt: occurrence)
            guard !existingKeys.contains(key) else { continue }
            if let reminder = DomainScheduleWriter.createReminder(
                for: event,
                scheduledAt: occurrence,
                mutation: mutation,
                context: context
            ) {
                created.append(reminder)
            }
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
