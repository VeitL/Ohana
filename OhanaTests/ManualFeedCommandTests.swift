import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct ManualFeedCommandTests {
    @Test func quickFeedExecutorReadHelpersUseFetchedStoreRowsBeforeFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let otherPet = Pet(name: "Luna", species: "猫")
        let oldLog = PetCareLog(
            date: date(year: 2026, month: 6, day: 1, hour: 8),
            type: .feeding,
            pet: pet,
            executorId: "human-1"
        )
        let newLog = PetCareLog(
            date: date(year: 2026, month: 6, day: 1, hour: 12),
            type: .feeding,
            pet: pet,
            executorId: "human-1"
        )
        let fallbackLog = PetCareLog(
            date: date(year: 2026, month: 6, day: 1, hour: 6),
            type: .feeding,
            pet: otherPet,
            executorId: "fallback"
        )
        let oldRecord = PetFoodRecord(
            brand: "Old",
            dailyGrams: 40,
            totalGrams: 400,
            foodKind: .dry,
            startDate: date(year: 2026, month: 6, day: 1, hour: 8),
            pet: pet
        )
        let newRecord = PetFoodRecord(
            brand: "New",
            dailyGrams: 50,
            totalGrams: 500,
            foodKind: .dry,
            startDate: date(year: 2026, month: 6, day: 1, hour: 12),
            pet: pet
        )
        let otherRecord = PetFoodRecord(
            brand: "Other",
            dailyGrams: 60,
            totalGrams: 600,
            foodKind: .dry,
            startDate: date(year: 2026, month: 6, day: 1, hour: 13),
            pet: otherPet
        )
        let fallbackRecord = PetFoodRecord(
            brand: "Fallback",
            dailyGrams: 10,
            totalGrams: 100,
            foodKind: .dry,
            startDate: date(year: 2026, month: 6, day: 1, hour: 6),
            pet: otherPet
        )
        let laterEvent = Event(
            title: "Later",
            startDate: date(year: 2026, month: 6, day: 1, hour: 12),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let earlierEvent = Event(
            title: "Earlier",
            startDate: date(year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let fallbackEvent = Event(
            title: "Fallback",
            startDate: date(year: 2026, month: 6, day: 1, hour: 6),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(otherPet)
        context.insert(oldLog)
        context.insert(newLog)
        context.insert(oldRecord)
        context.insert(newRecord)
        context.insert(otherRecord)
        context.insert(laterEvent)
        context.insert(earlierEvent)
        try context.save()

        let executor = QuickFeedCommandExecutor(context: context)

        #expect(
            executor.fullCareLogs(
                petID: pet.id,
                feedingType: CareType.feeding.rawValue,
                fallback: [fallbackLog]
            ).map(\.id) == [newLog.id, oldLog.id]
        )
        #expect(executor.fullFoodRecords(petID: pet.id, fallback: [fallbackRecord]).map(\.id) == [newRecord.id, oldRecord.id])
        #expect(FeedCommandFetch.foodRecords(petID: pet.id, context: context, fallback: [fallbackRecord]).map(\.id) == [newRecord.id, oldRecord.id])
        #expect(executor.latestAllEvents(fallback: [fallbackEvent]).map(\.id) == [earlierEvent.id, laterEvent.id])
        #expect(FeedCommandFetch.latestEvents(context: context, fallback: [fallbackEvent]).map(\.id) == [earlierEvent.id, laterEvent.id])
    }

    @Test func manualFeedCommandDoesNotDuplicateFoodStockReminderEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 9)
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
            startDate: now,
            pet: pet
        )
        context.insert(pet)
        context.insert(foodRecord)
        try context.save()

        let careEvents = CareEventService()
        _ = ManualFeedCommand.recordManual(
            pet: pet,
            targets: [pet],
            grams: 50,
            foodKind: pet.mainFoodKind,
            saveAsDefault: false,
            foodRecords: [foodRecord],
            allEvents: [],
            context: context,
            executorId: nil,
            careEvents: careEvents,
            date: now
        )
        #expect(stockReminderEvents(for: pet, context: context).count == 1)

        _ = ManualFeedCommand.recordManual(
            pet: pet,
            targets: [pet],
            grams: 50,
            foodKind: pet.mainFoodKind,
            saveAsDefault: false,
            foodRecords: [foodRecord],
            allEvents: stockReminderEvents(for: pet, context: context),
            context: context,
            executorId: nil,
            careEvents: careEvents,
            date: now.addingTimeInterval(60)
        )
        #expect(stockReminderEvents(for: pet, context: context).count == 1)
    }

    @Test func quickFeedExecutorManualRecordUsesSelectedBackdate() throws {
        let revisionCenter = ReadModelRevisionCenter()
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let selectedDate = date(year: 2026, month: 4, day: 18, hour: 7)
        let beforeRevision = revisionCenter.homeRevision.value
        let executor = QuickFeedCommandExecutor(context: context, revisionCenter: revisionCenter)
        let result = executor.recordManual(
            pet: pet,
            targets: [pet],
            grams: 42,
            foodKind: .wet,
            saveAsDefault: false,
            foodRecords: [],
            allEvents: [],
            executorId: human.id.uuidString,
            date: selectedDate
        )

        let log = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(result.didRecord)
        #expect(log.date == selectedDate)
        #expect(log.foodKind == .wet)
        #expect(ledger.occurredAt == selectedDate)
        #expect(ledger.legacyModelId == log.id.uuidString)
        #expect(revisionCenter.homeRevision.value == beforeRevision + 1)
        #expect(revisionCenter.lastMutation?.command == .feedLog(petID: pet.id, source: "manual"))
    }

    @Test func quickFeedManualRecordAppearsInWeeklyReportEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let feedAt = date(year: 2026, month: 6, day: 30, hour: 8)
        let executor = QuickFeedCommandExecutor(context: context)
        let result = executor.recordManual(
            pet: pet,
            targets: [pet],
            grams: 42,
            foodKind: .wet,
            saveAsDefault: false,
            foodRecords: [],
            allEvents: [],
            executorId: human.id.uuidString,
            date: feedAt
        )

        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let entries = CareLedgerStatsService().reportEntries(
            events: ledgerEvents,
            pets: [pet],
            humans: [human],
            interval: DateInterval(
                start: feedAt.addingTimeInterval(-60),
                end: feedAt.addingTimeInterval(60)
            ),
            l: L10n("en")
        )
        let entry = try #require(entries.first)

        #expect(result.didRecord)
        #expect(entries.count == 1)
        #expect(entry.actorId == human.id.uuidString)
        #expect(entry.actorName == "Guan")
        #expect(entry.petName == "Momo")
        #expect(entry.title == "Feeding")
    }

    @Test func manualFeedCommandDeletesExistingStockReminderWhenCallerHasNoEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 9)
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

        _ = ManualFeedCommand.recordManual(
            pet: pet,
            targets: [pet],
            grams: 50,
            foodKind: pet.mainFoodKind,
            saveAsDefault: false,
            foodRecords: [foodRecord],
            allEvents: [],
            context: context,
            executorId: nil
        )
        let reminders = stockReminderEvents(for: pet, context: context)

        #expect(reminders.count == 1)
        #expect(reminders.first?.id != staleEvent.id)
    }

    @Test func manualFeedCommandWritesFactDefaultsAndStockForDeceasedExecutor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 25
        pet.mainFoodKind = .wet
        pet.foodTrackingMode = .precise
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2
        let executorHuman = Human(name: "Former caretaker")
        executorHuman.passedAwayDate = now
        let foodRecord = PetFoodRecord(
            brand: "Test",
            dailyGrams: 50,
            totalGrams: 10000,
            foodKind: .dry,
            startDate: now,
            pet: pet
        )
        context.insert(pet)
        context.insert(executorHuman)
        context.insert(foodRecord)
        try context.save()

        let result = ManualFeedCommand.recordManual(
            pet: pet,
            targets: [pet],
            grams: 50,
            foodKind: .dry,
            saveAsDefault: true,
            foodRecords: [foodRecord],
            allEvents: [],
            context: context,
            executorId: executorHuman.id.uuidString,
            date: now
        )

        #expect(result.didRecord)
        #expect(result.targetCount == 1)
        #expect(result.stockReminders.count == 1)
        #expect(result.coconutDelta == 0)
        #expect(pet.mainFoodKind == .dry)
        #expect(pet.dailyPortionGrams == 50)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func feedingCareLedgerWritesStructuredKindMetadata() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()
        let dependencies = CareEventServiceDependencies.live()

        _ = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 42,
            context: context,
            date: date(year: 2026, month: 5, day: 1, hour: 9),
            foodKind: .wet,
            dependencies: dependencies
        )
        _ = CareEventService.recordTreatFeedFact(
            pet: pet,
            amountGrams: 8,
            context: context,
            date: date(year: 2026, month: 5, day: 1, hour: 10),
            treatKind: .freezeDried,
            dependencies: dependencies
        )

        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>(
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
        let manual = try #require(ledgers.first)
        let treat = try #require(ledgers.last)
        #expect(CareLedgerMetadata.stringValue(named: CareLedgerMetadata.feedFoodKind, in: manual.metadataJSON) == FeedFoodKind.wet.rawValue)
        #expect(CareLedgerMetadata.stringValue(named: CareLedgerMetadata.feedTreatKind, in: manual.metadataJSON) == nil)
        #expect(CareLedgerMetadata.stringValue(named: CareLedgerMetadata.feedFoodKind, in: treat.metadataJSON) == FeedFoodKind.dry.rawValue)
        #expect(CareLedgerMetadata.stringValue(named: CareLedgerMetadata.feedTreatKind, in: treat.metadataJSON) == FeedTreatKind.freezeDried.rawValue)
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

        let result = try SaveFoodStockCommand.run(
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
        let record = try #require(result.record)

        #expect(record.calculationModeRaw == FeedStockCalculationMode.autoFeeder.rawValue)
        #expect(FeedStockRecordMetadata.calculationMode(for: record) == .autoFeeder)
        #expect(record.expenseId != nil)
        #expect(FeedStockExpenseLink.expenseId(for: record) == record.expenseId)
        #expect(!record.notes.contains("stockCalculationMode:"))
        #expect(!record.notes.contains("stockExpense:"))

        let expenseId = try #require(record.expenseId)
        let recordState = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: PetFoodRecord.self),
            localRecordId: record.id,
            context: context
        ))
        let expenseState = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: PetExpenseLog.self),
            localRecordId: expenseId,
            context: context
        ))
        let petState = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            context: context
        ))
        #expect(recordState.hasPendingLocalChanges)
        #expect(expenseState.hasPendingLocalChanges)
        #expect(petState.hasPendingLocalChanges)
    }

    @Test func foodStockExpenseUpdateKeepsCareLedgerInSync() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let payer = Human(name: "Guan")
        context.insert(pet)
        context.insert(payer)
        try context.save()

        let created = try SaveFoodStockCommand.run(
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
        let createdRecord = try #require(created.record)
        let expenseId = try #require(createdRecord.expenseId)

        _ = try SaveFoodStockCommand.run(
            pet: pet,
            brand: "Test Plus",
            totalGrams: 1500,
            purchaseDate: nil,
            openDate: date(year: 2026, month: 5, day: 2),
            dailyGrams: 75,
            foodKind: .dry,
            calculationMode: .autoFeeder,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: nil,
            allEvents: [],
            context: context,
            recordToUpdate: createdRecord,
            previousExpenseId: expenseId,
            expenseAmount: 27.25,
            expensePayerId: payer.id.uuidString,
            expenseDate: date(year: 2026, month: 5, day: 2),
            expenseNote: "food stock update"
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let expense = try #require(expenses.first { $0.id == expenseId })
        let ledger = try #require(ledgers.first {
            $0.legacyModelName == "PetExpenseLog" && $0.legacyModelId == expenseId.uuidString
        })

        #expect(expenses.count == 1)
        #expect(ledgers.count == 1)
        #expect(expense.amount == 27.25)
        #expect(expense.note == "food stock update")
        #expect(expense.executorId == payer.id.uuidString)
        #expect(ledger.amountValue == expense.amount)
        #expect(ledger.note == expense.note)
        #expect(ledger.actorId == payer.id.uuidString)
        #expect(ledger.occurredAt == expense.date)
    }

    @Test func foodStockExpenseUsesEffectiveActorForDeceasedPayer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let activeHuman = Human(name: "Guan")
        let deceasedPayer = Human(name: "Old payer")
        deceasedPayer.passedAwayDate = date(year: 2026, month: 5, day: 1)
        context.insert(pet)
        context.insert(activeHuman)
        context.insert(deceasedPayer)
        try context.save()

        _ = try SaveFoodStockCommand.run(
            pet: pet,
            brand: "Test",
            totalGrams: 1200,
            purchaseDate: nil,
            openDate: date(year: 2026, month: 5, day: 2),
            dailyGrams: 60,
            foodKind: .dry,
            calculationMode: .manualOrPlan,
            reminderEnabled: false,
            reminderAdvanceDays: 7,
            executorId: activeHuman.id.uuidString,
            allEvents: [],
            context: context,
            recordToUpdate: nil,
            previousExpenseId: nil,
            expenseAmount: 27.25,
            expensePayerId: deceasedPayer.id.uuidString,
            expenseDate: date(year: 2026, month: 5, day: 2),
            expenseNote: "food stock"
        )

        let expense = try #require(try context.fetch(FetchDescriptor<PetExpenseLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)

        #expect(expense.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(ledger.actorKind == CareLedgerActorKind.human.rawValue)
    }

    @Test func saveFoodStockNoopsForDeceasedPetBeforeFactReminderExpenseLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.passedAwayDate = date(year: 2026, month: 5, day: 1)
        pet.foodTrackingMode = .casual
        pet.foodReminderEnabled = false
        pet.foodReminderAdvanceDays = 3
        context.insert(pet)
        try context.save()

        let result = try SaveFoodStockCommand.run(
            pet: pet,
            brand: "Test",
            totalGrams: 1200,
            purchaseDate: nil,
            openDate: date(year: 2026, month: 5, day: 2),
            dailyGrams: 60,
            foodKind: .dry,
            calculationMode: .manualOrPlan,
            reminderEnabled: true,
            reminderAdvanceDays: 1,
            executorId: nil,
            allEvents: [],
            context: context,
            recordToUpdate: nil,
            previousExpenseId: nil,
            expenseAmount: 27.25,
            expensePayerId: nil,
            expenseDate: date(year: 2026, month: 5, day: 2),
            expenseNote: "food stock"
        )

        #expect(result.stockReminders.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetFoodRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(pet.foodTrackingMode == .casual)
        #expect(pet.foodReminderEnabled == false)
        #expect(pet.foodReminderAdvanceDays == 3)
    }

    @Test func feedPlanAndStockCommandsNoopForDeceasedPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 7)
        let pet = Pet(name: "Momo", species: "猫")
        pet.foodReminderEnabled = false
        pet.foodReminderAdvanceDays = 4
        pet.mainFoodKind = .dry
        let record = PetFoodRecord(
            brand: "Test",
            dailyGrams: 60,
            totalGrams: 1200,
            foodKind: .dry,
            startDate: now,
            pet: pet
        )
        context.insert(pet)
        context.insert(record)
        try context.save()

        let manualDraft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 8), foodKind: .dry, grams: 45)],
            now: now
        )
        _ = try FeedingPlanWriter.replacePlan(pet: pet, draft: manualDraft, allEvents: [], context: context, now: now)
        var events = try context.fetch(FetchDescriptor<Event>())
        let autoDraft = FeedPlanDraft(
            kind: .autoFeeder,
            meals: [FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 18), foodKind: .wet, grams: 30)],
            now: now
        )
        _ = try FeedingPlanWriter.replacePlan(pet: pet, draft: autoDraft, allEvents: events, context: context, now: now)
        events = try context.fetch(FetchDescriptor<Event>())
        FeedOperatingMode.set(pet.id, mode: .autoFeeder)
        pet.passedAwayDate = date(year: 2026, month: 5, day: 2)
        try context.save()

        let beforeEventIds = Set(events.map(\.id))
        let beforeReminderIds = Set((try context.fetch(FetchDescriptor<Reminder>())).map(\.id))

        let stockSettings = try StockReminderSettingsCommand.run(
            pet: pet,
            enabled: true,
            advanceDays: 1,
            allEvents: events,
            context: context
        )
        let correction = try CorrectStockCommand.run(
            pet: pet,
            record: record,
            remainingGrams: 100,
            allEvents: events,
            context: context
        )
        let deletion = try DeleteFeedPlanCommand.run(
            pet: pet,
            kind: .autoFeeder,
            activeMode: .autoFeeder,
            allEvents: events,
            context: context
        )
        try SetMainFoodKindCommand.run(pet: pet, foodKind: .wet, context: context)
        let directModeChanged = SetFeedModeCommand.run(.manual, pet: pet)
        let ensuredReminders = try FeedMaintenanceCommand.ensureUpcomingPlanReminders(
            pet: pet,
            allEvents: events,
            context: context,
            now: now
        )
        try SwitchFeedModeCommand.switchToManual(pet: pet, allEvents: events, context: context)
        let switchResult = try SwitchFeedModeCommand.activateExistingRule(
            pet: pet,
            kind: .manualReminder,
            allEvents: events,
            context: context
        )

        #expect(stockSettings.stockReminders.isEmpty)
        #expect(correction.stockReminders.isEmpty)
        #expect(deletion.stockReminders.isEmpty)
        #expect(!deletion.shouldSwitchToManual)
        #expect(!directModeChanged)
        #expect(ensuredReminders.isEmpty)
        if case .switched = switchResult {
            Issue.record("Deceased pet feed mode switch should no-op.")
        }
        let afterEvents = try context.fetch(FetchDescriptor<Event>())
        let afterReminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(Set(afterEvents.map(\.id)) == beforeEventIds)
        #expect(Set(afterReminders.map(\.id)) == beforeReminderIds)
        #expect(record.remainingCorrectionGrams == nil)
        #expect(pet.foodReminderEnabled == false)
        #expect(pet.foodReminderAdvanceDays == 4)
        #expect(pet.mainFoodKind == .dry)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: afterEvents, now: now) == .autoFeeder)
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
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(ledger.sourceEventId == event.id.uuidString)
        #expect(CareLedgerMetadata.stringValue(named: CareLedgerMetadata.autoFeedDedupKey, in: ledger.metadataJSON) == log.autoFeedDedupKey)
        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: PetCareLog.self),
            localRecordId: log.id,
            context: context
        ))
        #expect(state.hasPendingLocalChanges)
    }

    @Test func autoFeedMaterializerUsesLedgerKeysInsteadOfPetCareLogRelationship() throws {
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
        let legacyRelationshipLog = PetCareLog(
            date: event.startDate,
            type: .feeding,
            amountGrams: 35,
            autoFeedDedupKey: FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: event.startDate),
            pet: pet
        )
        context.insert(pet)
        context.insert(event)
        context.insert(legacyRelationshipLog)
        try context.save()
        FeedOperatingMode.set(pet.id, mode: .autoFeeder)

        let inserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(inserted == 1)
        #expect(logs.count == 2)
        #expect(ledgerEvents.count == 1)
        #expect(ledgerEvents.first?.sourceEventId == event.id.uuidString)
    }

    @Test func careLedgerBackfillPreservesStructuredAutoFeedDedupKey() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let eventId = UUID()
        let scheduledAt = date(year: 2026, month: 5, day: 2, hour: 8)
        let key = FeedLogMetadata.autoDedupKey(eventId: eventId, scheduledAt: scheduledAt)
        let legacyLog = PetCareLog(
            date: scheduledAt,
            type: .feeding,
            amountGrams: 35,
            autoFeedDedupKey: key,
            pet: pet
        )
        context.insert(pet)
        context.insert(legacyLog)
        try context.save()

        try CareLedgerBackfillService.backfill(context: context)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)

        #expect(ledger.source == CareLedgerSource.backfill.rawValue)
        #expect(ledger.sourceEventId == eventId.uuidString)
        #expect(CareLedgerMetadata.stringValue(named: CareLedgerMetadata.autoFeedDedupKey, in: ledger.metadataJSON) == key)
    }

    @Test func autoFeedMaterializerNoopsForDeceasedPetBeforeFactAndLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 2, hour: 10)
        let pet = Pet(name: "Momo", species: "猫")
        pet.passedAwayDate = now
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

        let inserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )

        #expect(inserted == 0)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func autoFeedMaterializerDoesNotWriteHistoricalFactForDeceasedPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 2, hour: 10)
        let pet = Pet(name: "Momo", species: "猫")
        pet.passedAwayDate = date(year: 2026, month: 5, day: 2, hour: 12)
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

        let inserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(inserted == 0)
        #expect(logs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
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
        let petB = Pet(name: "Nori", species: "cat")
        let petC = Pet(name: "Biscuit", species: "狗")
        context.insert(petA)
        context.insert(petB)
        context.insert(petC)
        try context.save()

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 8), foodKind: .dry, grams: 45),
                FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 18), foodKind: .wet, grams: 30)
            ],
            now: now
        )
        let result = try SaveFeedPlanCommand.run(
            pet: petA,
            targets: [petB],
            kind: .manualReminder,
            draft: draft,
            allEvents: [],
            context: context
        )
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []

        #expect(result.mode == .manualReminder)
        #expect(result.targetCount == 2)
        #expect(result.affectedPetIDs == [petA.id, petB.id])
        #expect(result.planReminders.isEmpty == false)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petA) }) == 2)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petB) }) == 2)
        #expect(events.contains { FeedRuleMetadata.isManualReminderEvent($0, pet: petC) } == false)
        #expect(Set(events.map(\.feedPlanGroupId)).count == 1)
        #expect(events.allSatisfy { !$0.feedPlanGroupId.isEmpty })
        #expect(FeedOperatingMode.resolved(pet: petA, allEvents: events, now: now) == .manualReminder)
        #expect(FeedOperatingMode.resolved(pet: petB, allEvents: events, now: now) == .manualReminder)

        let feedEvents = events.filter {
            FeedRuleMetadata.isManualReminderEvent($0, pet: petA) ||
                FeedRuleMetadata.isManualReminderEvent($0, pet: petB)
        }
        for event in feedEvents {
            let state = try #require(try CloudSyncMetadataService.state(
                entityName: String(describing: Event.self),
                localRecordId: event.id,
                context: context
            ))
            #expect(state.hasPendingLocalChanges)
        }
    }

    @Test func saveFeedPlanFailureRollsBackAllPetsWithoutCancellingNotifications() throws {
        struct InjectedPersistenceFailure: Error {}

        let container = try makeContainer()
        let context = container.mainContext
        let petA = Pet(name: "Momo", species: "猫")
        let petB = Pet(name: "Nori", species: "cat")
        let oldPlanA = makeManualPlanEvent(petID: petA.id, grams: 30)
        let oldPlanB = makeManualPlanEvent(petID: petB.id, grams: 35)
        let oldReminderA = Reminder(event: oldPlanA, scheduledAt: Date().addingTimeInterval(3600))
        let oldReminderB = Reminder(event: oldPlanB, scheduledAt: Date().addingTimeInterval(7200))
        oldReminderA.notificationId = "old-plan-a"
        oldReminderB.notificationId = "old-plan-b"

        let defaultEvent = Event(
            title: "Default feed",
            startDate: Date().addingTimeInterval(10800),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petA.id.uuidString
        )
        let defaultReminder = Reminder(event: defaultEvent, scheduledAt: defaultEvent.startDate)
        defaultReminder.notificationId = "default-plan-a"
        let defaultEventKey = "careCalendarEventId_default_feed_\(petA.id.uuidString)"
        let suppressionKey = "careCalendarDefaultSuppressed_feed_\(petA.id.uuidString)"
        let notifications = FeedNotificationSpy()
        let previousNotifications = ReminderNotificationSchedulerRegistry.current
        ReminderNotificationSchedulerRegistry.current = notifications
        UserDefaults.standard.set(defaultEvent.id.uuidString, forKey: defaultEventKey)
        UserDefaults.standard.removeObject(forKey: suppressionKey)
        defer {
            ReminderNotificationSchedulerRegistry.current = previousNotifications
            UserDefaults.standard.removeObject(forKey: defaultEventKey)
            UserDefaults.standard.removeObject(forKey: suppressionKey)
        }

        context.insert(petA)
        context.insert(petB)
        context.insert(oldPlanA)
        context.insert(oldPlanB)
        context.insert(oldReminderA)
        context.insert(oldReminderB)
        context.insert(defaultEvent)
        context.insert(defaultReminder)
        try context.save()

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(
                    time: Date().addingTimeInterval(14400),
                    foodKind: .dry,
                    grams: 45
                )
            ]
        )

        #expect(throws: InjectedPersistenceFailure.self) {
            _ = try SaveFeedPlanCommand.run(
                pet: petA,
                targets: [petB],
                kind: .manualReminder,
                draft: draft,
                allEvents: [oldPlanA, oldPlanB, defaultEvent],
                context: context,
                notifications: notifications,
                persist: { _ in throw InjectedPersistenceFailure() }
            )
        }

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(notifications.cancelledIDs.isEmpty)
        #expect(Set(events.map(\.id)).isSuperset(of: [oldPlanA.id, oldPlanB.id, defaultEvent.id]))
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petA) }) == 1)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petB) }) == 1)
        #expect(Set(reminders.map(\.notificationId)).isSuperset(of: ["old-plan-a", "old-plan-b", "default-plan-a"]))
        #expect(UserDefaults.standard.string(forKey: defaultEventKey) == defaultEvent.id.uuidString)
        #expect(!UserDefaults.standard.bool(forKey: suppressionKey))
    }

    @Test func saveFeedPlanFlushesNotificationCancellationsAfterPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let oldPlan = makeManualPlanEvent(petID: pet.id, grams: 30)
        let oldReminder = Reminder(event: oldPlan, scheduledAt: Date().addingTimeInterval(3600))
        oldReminder.notificationId = "old-plan"
        context.insert(pet)
        context.insert(oldPlan)
        context.insert(oldReminder)
        try context.save()

        var operationOrder: [String] = []
        let notifications = FeedNotificationSpy {
            operationOrder.append("cancel")
        }
        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(
                    time: Date().addingTimeInterval(14400),
                    foodKind: .dry,
                    grams: 45
                )
            ]
        )

        _ = try SaveFeedPlanCommand.run(
            pet: pet,
            targets: [pet],
            kind: .manualReminder,
            draft: draft,
            allEvents: [oldPlan],
            context: context,
            notifications: notifications,
            persist: { context in
                operationOrder.append("persist")
                _ = try FeedCommandPersistence.save(context: context)
            }
        )

        #expect(operationOrder.first == "persist")
        #expect(operationOrder.dropFirst().allSatisfy { $0 == "cancel" })
        #expect(notifications.cancelledIDs == ["old-plan"])
    }

    @Test func multiPetStockReminderRebuildNeverReusesAnInvalidatedEvent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let petA = Pet(name: "Momo", species: "猫")
        let petB = Pet(name: "Nori", species: "cat")
        petA.foodReminderEnabled = false
        petB.foodReminderEnabled = false

        func stockEvent(for pet: Pet) -> Event {
            Event(
                title: "Stock reminder",
                startDate: Date().addingTimeInterval(86400),
                eventType: EventType.shoppingList.rawValue,
                relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
                relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
            )
        }

        let stockA = stockEvent(for: petA)
        let stockB = stockEvent(for: petB)
        context.insert(petA)
        context.insert(petB)
        context.insert(stockA)
        context.insert(stockB)
        try context.save()

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(
                    time: Date().addingTimeInterval(14400),
                    foodKind: .dry,
                    grams: 45
                )
            ]
        )
        let result = try SaveFeedPlanCommand.run(
            pet: petA,
            targets: [petB],
            kind: .manualReminder,
            draft: draft,
            allEvents: [stockA, stockB],
            context: context
        )
        let events = try context.fetch(FetchDescriptor<Event>())

        #expect(result.targetCount == 2)
        #expect(FeedingPlanWriter.stockReminderEvents(pet: petA, allEvents: events).isEmpty)
        #expect(FeedingPlanWriter.stockReminderEvents(pet: petB, allEvents: events).isEmpty)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petA) }) == 1)
        #expect(events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: petB) }) == 1)
    }

    @Test func savedPlanResultCarriesFreshEventsBeforeRouteQueryCatchesUp() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 5, day: 1, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()

        let draft = FeedPlanDraft(
            kind: .manualReminder,
            meals: [
                FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 8), foodKind: .dry, grams: 45),
                FeedPlanMealDraft(time: date(year: 2026, month: 5, day: 1, hour: 18), foodKind: .wet, grams: 30)
            ],
            now: now
        )

        let staleRouteEvents: [Event] = []
        let result = try SaveFeedPlanCommand.run(
            pet: pet,
            targets: [pet],
            kind: .manualReminder,
            draft: draft,
            allEvents: staleRouteEvents,
            context: context
        )

        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: staleRouteEvents, now: now) == .manual)
        #expect(FeedOperatingMode.resolved(pet: pet, allEvents: result.events, now: now) == .manualReminder)
        #expect(result.affectedPetIDs == [pet.id])
        #expect(result.events.count(where: { FeedRuleMetadata.isManualReminderEvent($0, pet: pet) }) == 2)
    }

    @Test func savedPlanEventsRemainAuthoritativeUntilRouteSnapshotCatchesUp() {
        let petID = UUID()
        let savedPlanEvent = makeManualPlanEvent(petID: petID, grams: 45)
        let staleRouteEvent = makeManualPlanEvent(
            petID: petID,
            id: savedPlanEvent.id,
            createdAt: savedPlanEvent.createdAt,
            grams: 20
        )
        let unrelatedEvent = Event(title: "Unrelated calendar event")
        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [savedPlanEvent],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        let merged = runtimeState.ruleSnapshotsMergingPendingWrite(with: [staleRouteEvent, unrelatedEvent])
        #expect(merged.first(where: { $0.id == savedPlanEvent.id })?.feedAmountGrams == 45)
        #expect(!runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [staleRouteEvent, unrelatedEvent]))
        #expect(runtimeState.hasPendingRuleWrite)

        #expect(runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [savedPlanEvent, unrelatedEvent]))
        #expect(!runtimeState.hasPendingRuleWrite)
    }

    @Test func invalidatedRouteEventsAreExcludedBeforeSignatureOrReceiptReads() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let petID = UUID()
        let invalidatedRouteEvent = makeManualPlanEvent(petID: petID, grams: 20)
        invalidatedRouteEvent.completedOccurrences = ["2026-08-03"]
        context.insert(invalidatedRouteEvent)
        try context.save()
        context.delete(invalidatedRouteEvent)
        try context.save()

        let savedPlanEvent = makeManualPlanEvent(petID: petID, grams: 45)
        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [savedPlanEvent],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        #expect(invalidatedRouteEvent.modelContext == nil)
        #expect(QuickFeedRouteRevision(events: [invalidatedRouteEvent]).events.isEmpty)
        #expect(QuickFeedRouteRevision(events: [savedPlanEvent]).events.count == 1)
        #expect(runtimeState.ruleSnapshotsMergingPendingWrite(with: [invalidatedRouteEvent]).map(\.id) == [savedPlanEvent.id])
        #expect(!runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [invalidatedRouteEvent]))
        #expect(runtimeState.hasPendingRuleWrite)
    }

    @Test func feedHomeRenderStateKeepsOnlyValuesAfterItsPlanEventIsInvalidated() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 8, day: 3, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 30
        let storedPlan = makeManualPlanEvent(petID: pet.id, grams: 45)
        storedPlan.feedAmountGrams = 0
        storedPlan.startDate = date(year: 2026, month: 8, day: 3, hour: 18)
        storedPlan.recurrenceDays = 2
        storedPlan.recurrenceEndDate = date(year: 2026, month: 9, day: 3, hour: 18)
        let storedPlanID = storedPlan.id
        context.insert(pet)
        context.insert(storedPlan)
        try context.save()

        let snapshot = FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: [storedPlan],
            careLogs: [],
            foodRecords: [],
            now: now,
            todayLabel: "Today"
        ))
        let viewState = FeedHomeViewState.make(
            mode: .manualReminder,
            snapshot: snapshot,
            pet: pet,
            isRefreshing: false
        )

        context.delete(storedPlan)
        try context.save()

        #expect(storedPlan.modelContext == nil)
        let frozenPlan = try #require(viewState.task.manualPlanEvents.first)
        #expect(frozenPlan.id == storedPlanID)
        #expect(frozenPlan.startDate == date(year: 2026, month: 8, day: 3, hour: 18))
        #expect(frozenPlan.recurrenceDays == 2)
        #expect(frozenPlan.recurrenceEndDate == date(year: 2026, month: 9, day: 3, hour: 18))
        #expect(frozenPlan.foodKind == .dry)
        #expect(frozenPlan.amountGrams == 45)
        #expect(viewState.replacingMode(.autoFeeder, pet: pet).task.manualPlanEvents == [frozenPlan])
    }

    @Test func quickFeedSheetSanitizesInvalidatedEventsBeforeViewInitialization() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let invalidatedRouteEvent = makeManualPlanEvent(petID: pet.id, grams: 20)
        invalidatedRouteEvent.completedOccurrences = ["2026-08-03"]
        context.insert(pet)
        context.insert(invalidatedRouteEvent)
        try context.save()
        context.delete(invalidatedRouteEvent)
        try context.save()

        let sheet = QuickFeedDetailSheet(
            pet: pet,
            onRemove: {},
            allEvents: [invalidatedRouteEvent],
            eventRevision: QuickFeedRouteRevision(events: [])
        )

        #expect(invalidatedRouteEvent.modelContext == nil)
        #expect(sheet.allEvents.isEmpty)
    }

    @Test func feedRouteRevisionIgnoresUnrelatedCalendarChangesButTracksReminderStatus() {
        let petID = UUID()
        let feedRule = makeManualPlanEvent(petID: petID, grams: 45, reminderID: UUID())
        let unrelatedEvent = Event(title: "Unrelated calendar event")
        let initialRevision = QuickFeedRouteRevision(events: [feedRule, unrelatedEvent])

        unrelatedEvent.completedOccurrences = ["2026-08-03"]
        let unrelatedChangeRevision = QuickFeedRouteRevision(events: [feedRule, unrelatedEvent])
        #expect(unrelatedChangeRevision == initialRevision)

        feedRule.reminders[0].status = ReminderStatus.completed.rawValue
        let reminderChangeRevision = QuickFeedRouteRevision(events: [feedRule, unrelatedEvent])
        #expect(reminderChangeRevision != initialRevision)
    }

    @Test func feedRuleSignatureSharesTheLegacyRuleClassifier() {
        let petID = UUID()
        let ordinaryFoodChange = Event(
            title: "Diet transition",
            startDate: Date(timeIntervalSince1970: 3600),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petID.uuidString
        )
        let legacyFeedRule = Event(
            title: "早餐 干粮 45g",
            startDate: Date(timeIntervalSince1970: 7200),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petID.uuidString
        )

        #expect(!FeedRuleMetadata.isFeedRuleEvent(ordinaryFoodChange))
        #expect(QuickFeedRouteEventSignature(ordinaryFoodChange).ruleKind == nil)
        #expect(FeedRuleMetadata.isFeedRuleEvent(legacyFeedRule))
        #expect(QuickFeedRouteEventSignature(legacyFeedRule).ruleKind == .manualReminder)
    }

    @Test func consecutiveRuleWritesNeverReadThePreviousInvalidatedAuthoritativeModel() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let petID = UUID()
        let firstStoredRule = makeManualPlanEvent(petID: petID, grams: 20)
        context.insert(firstStoredRule)
        try context.save()

        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [firstStoredRule],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        context.delete(firstStoredRule)
        try context.save()
        let secondStoredRule = makeManualPlanEvent(petID: petID, grams: 45)
        context.insert(secondStoredRule)
        try context.save()

        runtimeState.installSuccessfulRuleWrite(
            events: [secondStoredRule],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        #expect(firstStoredRule.modelContext == nil)
        let merged = runtimeState.ruleSnapshotsMergingPendingWrite(with: [firstStoredRule])
        #expect(merged.map(\.id) == [secondStoredRule.id])
        #expect(merged.first?.feedAmountGrams == 45)
    }

    @Test func cancellingFeedTasksPreservesSavedPlanReceiptUntilRouteSnapshotCatchesUp() {
        let petID = UUID()
        let savedPlanEvent = makeManualPlanEvent(petID: petID, grams: 45)
        let staleRouteEvent = makeManualPlanEvent(
            petID: petID,
            id: savedPlanEvent.id,
            createdAt: savedPlanEvent.createdAt,
            grams: 20
        )
        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [savedPlanEvent],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        runtimeState.cancelTasks()

        #expect(runtimeState.hasPendingRuleWrite)
        #expect(!runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [staleRouteEvent]))
        #expect(runtimeState.expectedModeDuringPendingRuleWrite(for: petID) == .manualReminder)
        #expect(runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [savedPlanEvent]))
        #expect(!runtimeState.hasPendingRuleWrite)
    }

    @Test func savedPlanReceiptIgnoresMutableReminderDeliveryState() {
        let petID = UUID()
        let reminderID = UUID()
        let savedPlanEvent = makeManualPlanEvent(
            petID: petID,
            grams: 45,
            reminderID: reminderID
        )
        let routeEvent = makeManualPlanEvent(
            petID: petID,
            id: savedPlanEvent.id,
            createdAt: savedPlanEvent.createdAt,
            grams: 45,
            reminderID: reminderID
        )
        routeEvent.reminders[0].status = ReminderStatus.completed.rawValue
        routeEvent.reminders[0].completedAt = Date()
        routeEvent.reminders[0].notificationId = "delivered-notification"
        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [savedPlanEvent],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        #expect(runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [routeEvent]))
        #expect(!runtimeState.hasPendingRuleWrite)
    }

    @Test func savedPlanReceiptRejectsAnOppositeModeRuleStillInTheRoute() {
        let petID = UUID()
        let manualEvent = makeManualPlanEvent(petID: petID, grams: 45)
        let staleAutoEvent = makeAutoPlanEvent(petID: petID, grams: 45)
        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [manualEvent],
            affectedPetIDs: [petID],
            mode: .manualReminder
        )

        #expect(!runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [manualEvent, staleAutoEvent]))
        #expect(runtimeState.hasPendingRuleWrite)
    }

    @Test func consecutiveSavedPlanReceiptsPreserveEveryPendingPetScope() {
        let firstPetID = UUID()
        let secondPetID = UUID()
        let firstEvent = makeManualPlanEvent(petID: firstPetID, grams: 35)
        let secondEvent = makeManualPlanEvent(petID: secondPetID, grams: 55)
        let runtimeState = QuickFeedRuntimeState()
        runtimeState.installSuccessfulRuleWrite(
            events: [firstEvent],
            affectedPetIDs: [firstPetID],
            mode: .manualReminder
        )
        runtimeState.installSuccessfulRuleWrite(
            events: [secondEvent],
            affectedPetIDs: [secondPetID],
            mode: .manualReminder
        )

        #expect(runtimeState.pendingRuleWritePetIDs == [firstPetID, secondPetID])
        #expect(!runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [secondEvent]))
        #expect(runtimeState.acknowledgePendingRuleWriteIfRouteCaughtUp(with: [firstEvent, secondEvent]))
    }

    @Test func resettingPendingFeedRefreshCancelsTheStaleRenderTask() async {
        let runtimeState = QuickFeedRuntimeState()
        var didRunStaleRefresh = false
        runtimeState.pendingFeedRefreshRequest = [.reloadSnapshots, .syncDisplayedMode, .forceDisplayedMode]
        runtimeState.feedRefreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            didRunStaleRefresh = true
        }

        runtimeState.resetPendingFeedRefresh()
        try? await Task.sleep(nanoseconds: 120_000_000)

        #expect(runtimeState.feedRefreshTask == nil)
        #expect(runtimeState.pendingFeedRefreshRequest.isEmpty)
        #expect(!didRunStaleRefresh)
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

        let result = try SwitchFeedModeCommand.activateExistingRule(
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

    private func makeManualPlanEvent(
        petID: UUID,
        id: UUID = UUID(),
        createdAt: Date = Date(timeIntervalSince1970: 1),
        grams: Double,
        reminderID: UUID? = nil
    ) -> Event {
        let event = Event(
            title: "Breakfast dry food \(Int(grams))g",
            startDate: Date(timeIntervalSince1970: 3600),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petID.uuidString
        )
        event.id = id
        event.createdAt = createdAt
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        event.foodKindRaw = FeedFoodKind.dry.rawValue
        event.feedAmountGrams = grams
        if let reminderID {
            let reminder = Reminder(event: event, scheduledAt: event.startDate)
            reminder.id = reminderID
            event.reminders = [reminder]
        }
        return event
    }

    private func makeAutoPlanEvent(petID: UUID, grams: Double) -> Event {
        let event = Event(
            title: "Auto feeder dry food \(Int(grams))g",
            startDate: Date(timeIntervalSince1970: 7200),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: petID.uuidString
        )
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        event.foodKindRaw = FeedFoodKind.dry.rawValue
        event.feedAmountGrams = grams
        return event
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private final class FeedNotificationSpy: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledIDs: [String] = []
        private let onCancel: () -> Void

        init(onCancel: @escaping () -> Void = {}) {
            self.onCancel = onCancel
        }

        func schedule(reminder _: Reminder) {}
        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion _: ((ReminderNotificationScheduleResult) -> Void)?
        ) {}
        func schedule(
            reminder _: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion _: ((ReminderNotificationScheduleResult) -> Void)?
        ) {}
        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) {
            cancelledIDs.append(notificationId)
            onCancel()
        }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
