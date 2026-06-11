import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct OverviewQuickCareCommandExecutorTests {
    @Test func quickFeedDoesNotDuplicateFoodStockReminderEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 50
        pet.mainFoodKind = .dry
        pet.foodTrackingMode = .precise
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2

        let foodRecord = PetFoodRecord(
            brand: "Test",
            dailyGrams: 50,
            totalGrams: 10000,
            foodKind: .dry,
            startDate: Date(),
            pet: pet
        )
        context.insert(pet)
        context.insert(foodRecord)
        try context.save()

        let executor = OverviewQuickCareCommandExecutor(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher()
        )

        executor.record(
            pet: pet,
            actionType: "feed",
            amount: 50,
            saveAsDefault: false,
            executorId: nil
        )
        #expect(stockReminderEvents(for: pet, context: context).count == 1)

        executor.record(
            pet: pet,
            actionType: "feed",
            amount: 50,
            saveAsDefault: false,
            executorId: nil
        )
        #expect(stockReminderEvents(for: pet, context: context).count == 1)
    }

    @Test func rebuildFoodStockRemindersDeletesContextEventsWhenCallerHasNoEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 100
        pet.foodTrackingMode = .precise
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2
        let foodRecord = PetFoodRecord(
            brand: "Test",
            dailyGrams: 100,
            totalGrams: 1000,
            foodKind: .dry,
            startDate: now,
            pet: pet
        )
        let staleEvent = Event(
            title: "旧断粮提醒",
            startDate: date(year: 2026, month: 5, day: 5, hour: 9),
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        let staleReminder = Reminder(event: staleEvent, scheduledAt: staleEvent.startDate)
        context.insert(pet)
        context.insert(foodRecord)
        context.insert(staleEvent)
        context.insert(staleReminder)
        try context.save()

        _ = FeedingPlanWriter.rebuildFoodStockReminders(
            pet: pet,
            allEvents: [],
            context: context,
            now: now
        )
        let reminders = stockReminderEvents(for: pet, context: context)

        #expect(reminders.count == 1)
        #expect(reminders.first?.id != staleEvent.id)
    }

    @Test func foodStockMetadataWritesStructuredFieldsInsteadOfNotesPrefixes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let result = SaveFoodStockCommand.run(
            pet: pet,
            brand: "Test",
            totalGrams: 1200,
            purchaseDate: nil,
            openDate: date(year: 2026, month: 5, day: 1),
            dailyGrams: 60,
            foodKind: .dry,
            calculationMode: .autoFeeder,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            recordToUpdate: nil,
            previousExpenseId: nil,
            expenseAmount: 19.5,
            expensePayerId: nil,
            expenseDate: date(year: 2026, month: 5, day: 1),
            expenseNote: "food stock"
        )
        let record = result.record

        #expect(record.calculationModeRaw == FeedStockCalculationMode.autoFeeder.rawValue)
        #expect(FeedStockRecordMetadata.calculationMode(for: record) == .autoFeeder)
        #expect(record.expenseId != nil)
        #expect(FeedStockExpenseLink.expenseId(for: record) == record.expenseId)
        #expect(!record.notes.contains("stockCalculationMode:"))
        #expect(!record.notes.contains("stockExpense:"))
    }

    @Test func legacyFoodStockMetadataStillReadsFromNotes() throws {
        let record = PetFoodRecord()
        let expenseId = UUID()
        record.calculationModeRaw = ""
        record.notes = """
        visible note
        stockCalculationMode:autoFeeder
        stockExpense:\(expenseId.uuidString)
        """

        #expect(FeedStockRecordMetadata.calculationMode(for: record) == .autoFeeder)
        #expect(FeedStockExpenseLink.expenseId(for: record) == expenseId)
    }

    @Test func autoFeedDedupKeyWritesStructuredFieldInsteadOfNotePrefix() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 2, hour: 10)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "自动喂食器 干粮 35g",
            startDate: date(year: 2026, month: 5, day: 2, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        event.feedAmountGrams = 35
        event.foodKindRaw = FeedFoodKind.dry.rawValue
        context.insert(pet)
        context.insert(event)
        try context.save()
        FeedOperatingMode.set(pet.id, mode: .autoFeeder)

        let firstInserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )
        let secondInserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )
        let logs = (try? context.fetch(FetchDescriptor<PetCareLog>())) ?? []
        let log = try #require(logs.first)

        #expect(firstInserted == 1)
        #expect(secondInserted == 0)
        #expect(log.autoFeedDedupKey == FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: event.startDate))
        #expect(log.isAutoFeedLogEntry)
        #expect(!log.note.contains(FeedLogMetadata.autoFeedNotePrefix))
    }

    @Test func legacyAutoFeedDedupKeyStillReadsFromNote() throws {
        let eventId = UUID()
        let scheduledAt = date(year: 2026, month: 5, day: 2, hour: 8)
        let log = PetCareLog(
            type: .feeding,
            note: FeedLogMetadata.autoNote(eventId: eventId, scheduledAt: scheduledAt)
        )

        #expect(FeedLogMetadata.autoDedupKey(for: log) == FeedLogMetadata.autoDedupKey(eventId: eventId, scheduledAt: scheduledAt))
        #expect(log.isAutoFeedLogEntry)
    }

    @Test func saveFeedPlanWritesManualRulesForAllTargets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 7)
        let petA = Pet(name: "Momo", species: "猫")
        let petB = Pet(name: "Nori", species: "狗")
        context.insert(petA)
        context.insert(petB)
        try context.save()

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 8), foodKind: .dry, grams: 45),
                FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 18), foodKind: .wet, grams: 30)
            ],
            now: now
        )
        let result = SaveFeedPlanCommand.run(
            pet: petA,
            targets: [petA, petB],
            kind: .manualReminder,
            draft: draft,
            allEvents: [],
            context: context
        )
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []

        #expect(result.mode == .manualReminder)
        #expect(result.targetCount == 2)
        #expect(result.planReminders.isEmpty == false)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petA) }) == 2)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petB) }) == 2)
        #expect(FeedOperatingMode.resolved(pet: petA, allEvents: events, now: now) == .manualReminder)
        #expect(FeedOperatingMode.resolved(pet: petB, allEvents: events, now: now) == .manualReminder)
    }

    @Test func switchFeedModeToAutoFeederDeactivatesManualReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let future = Date().addingTimeInterval(2 * 24 * 60 * 60)
        let manualEvent = Event(
            title: "早餐 干粮 50g",
            startDate: future,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        manualEvent.recurrenceDays = 1
        manualEvent.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        manualEvent.feedAmountGrams = 50
        let manualReminder = Reminder(event: manualEvent, scheduledAt: future)
        let autoEvent = Event(
            title: "自动喂食器 干粮 50g",
            startDate: future,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        autoEvent.recurrenceDays = 1
        autoEvent.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        autoEvent.feedAmountGrams = 50
        context.insert(pet)
        context.insert(manualEvent)
        context.insert(manualReminder)
        context.insert(autoEvent)
        try context.save()

        let result = SwitchFeedModeCommand.activateExistingRule(
            pet: pet,
            kind: .autoFeeder,
            allEvents: [manualEvent, autoEvent],
            context: context
        )
        let storedReminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []

        if case let .switched(remindersToSchedule) = result {
            #expect(remindersToSchedule.isEmpty)
        } else {
            Issue.record("Expected switch command to activate the existing auto-feeder rule.")
        }
        #expect(storedReminders.isEmpty)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: [manualEvent, autoEvent]) == .autoFeeder)
    }

    private func stockReminderEvents(for pet: Pet, context: ModelContext) -> [Event] {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return FeedingPlanWriter.stockReminderEvents(pet: pet, allEvents: events)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV63.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
