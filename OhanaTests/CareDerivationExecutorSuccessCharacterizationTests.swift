import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct CareDerivationExecutorSuccessCharacterizationTests {
    @Test func quickPottySuccessWritesFactLedgerRewardAndRevision() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Caretaker")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let economyState = resetEconomyState(context: context, memberID: human.id, petIDs: [pet.id])
        defer { restoreEconomyState(economyState) }
        let result = try #require(QuickPottyCommandExecutor(context: context, revisionCenter: center).record(
            petID: pet.id,
            selectedType: .perfectPoop,
            isLitter: false,
            executorId: human.id.uuidString,
            date: fixedDate(hour: 8)
        ))

        #expect(result.pottyLogID != nil)
        #expect(result.targetCount == 1)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains { $0.eventKind == CareLedgerEventKind.potty.rawValue })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
        #expect(center.homeRevision.value == 1)
    }

    @Test func manualFeedSuccessWritesFactRewardStockReminderAndDefaults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Caretaker")
        pet.mainFoodKind = .wet
        pet.dailyPortionGrams = 20
        pet.foodTrackingMode = .precise
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 1
        let foodRecord = PetFoodRecord(
            brand: "Daily",
            dailyGrams: 40,
            totalGrams: 4000,
            foodKind: .dry,
            startDate: fixedDate(hour: 6),
            pet: pet
        )
        context.insert(pet)
        context.insert(human)
        context.insert(foodRecord)
        try context.save()

        let economyState = resetEconomyState(context: context, memberID: human.id, petIDs: [pet.id])
        defer { restoreEconomyState(economyState) }
        let result = ManualFeedCommand.recordManual(
            pet: pet,
            targets: [pet],
            grams: 40,
            foodKind: .dry,
            saveAsDefault: true,
            foodRecords: [foodRecord],
            allEvents: [],
            context: context,
            executorId: human.id.uuidString,
            date: fixedDate(hour: 9)
        )

        #expect(result.didRecord)
        #expect(result.allowsDerivedEffects)
        #expect(result.targetCount == 1)
        #expect(pet.mainFoodKind == .dry)
        #expect(pet.dailyPortionGrams == 40)
        #expect(!result.stockReminders.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).contains { $0.careType == .feeding })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
    }

    @Test func calendarPetTaskSuccessWritesHistoricalFactLedgerRewardAndCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Caretaker")
        pet.dailyPortionGrams = 45
        let occurrenceDate = fixedDate(hour: 7)
        let event = Event(
            title: "Feed 45g",
            startDate: occurrenceDate,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.feedAmountGrams = 45
        context.insert(pet)
        context.insert(human)
        context.insert(event)
        try context.save()

        let economyState = resetEconomyState(context: context, memberID: human.id, petIDs: [pet.id])
        defer { restoreEconomyState(economyState) }
        let result = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: [pet],
            context: context,
            executorId: human.id.uuidString,
            now: fixedDate(hour: 18)
        )

        #expect(result.didChange)
        #expect(event.isOccurrenceMarkedComplete(on: occurrenceDate))
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).contains { $0.careType == .feeding && $0.amountGrams == 45 })
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains { $0.source == CareLedgerSource.calendar.rawValue })
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
    }

    @Test func sharedWaterSuccessWritesFactsForAllTargetsAndOneRevision() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let source = Pet(name: "Momo", species: "cat")
        let second = Pet(name: "Luna", species: "cat")
        let human = Human(name: "Caretaker")
        context.insert(source)
        context.insert(second)
        context.insert(human)
        try context.save()

        let economyState = resetEconomyState(context: context, memberID: human.id, petIDs: [source.id, second.id])
        defer { restoreEconomyState(economyState) }
        let result = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        ).recordWater(
            pet: source,
            targets: [source, second],
            amountMl: 120,
            executorId: human.id.uuidString
        )

        #expect(result.didRecord)
        #expect(result.allowsDerivedEffects)
        #expect(result.targetCount == 2)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains { $0.eventKind == CareLedgerEventKind.care.rawValue && $0.actionType == CareType.watering.rawValue })
        #expect(center.homeRevision.value == 1)
    }

    @Test func healthWeightAndCatCareSuccessPathsProduceTheirFactsAndDerivedRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Caretaker")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let economyState = resetEconomyState(context: context, memberID: human.id, petIDs: [pet.id])
        defer { restoreEconomyState(economyState) }
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let health = try #require(PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .vaccine,
                date: fixedDate(hour: 10),
                name: "Rabies",
                note: "Annual",
                vetName: "Clinic",
                cost: 12,
                expirationDate: fixedDate(day: 2, hour: 10),
                nextCheckupDate: nil,
                executorId: human.id.uuidString,
                source: .detail,
                includesNameInNote: true,
                expirationReminderLeadDays: 1
            ),
            context: context,
            questManager: questManager
        ))
        let weight = try WeightCommandService.recordPetWeight(
            pet: pet,
            weight: 4.2,
            date: fixedDate(hour: 11),
            context: context,
            executorId: human.id.uuidString,
            awardsReward: true,
            ledgerSource: .detail,
            questManager: questManager
        )
        let catCare = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "brush",
                emoji: "*",
                recordsHygiene: true,
                occurredAt: fixedDate(hour: 12),
                executorId: human.id.uuidString
            ),
            context: context
        )

        #expect(health.expenseLogID != nil)
        #expect(health.eventID != nil)
        #expect(weight.didRecord)
        #expect(weight.allowsDerivedEffects)
        #expect(weight.ledgerEventID != nil)
        #expect(catCare.didRecord)
        #expect(catCare.hygieneLogID != nil)
        let catCareHygieneLogID = try #require(catCare.hygieneLogID)
        #expect(try context.fetch(FetchDescriptor<PetHealthLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetWeightLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).contains {
            $0.legacyModelName == "PetHygieneLog" && $0.legacyModelId == catCareHygieneLogID.uuidString
        })
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func fixedDate(day: Int = 1, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
    }

    private func resetEconomyState(context: ModelContext, memberID: UUID, petIDs: [UUID]) -> (activeHumanID: Any?, cooldownLogs: Any?) {
        let defaults = UserDefaults.standard
        let state = (
            activeHumanID: defaults.object(forKey: "currentActiveHumanId"),
            cooldownLogs: defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        )
        defaults.set(memberID.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: memberID.uuidString,
            careObjectKeys: petIDs.map(\.uuidString)
        )
        return state
    }

    private func restoreEconomyState(_ state: (activeHumanID: Any?, cooldownLogs: Any?)) {
        let defaults = UserDefaults.standard
        if let activeHumanID = state.activeHumanID {
            defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        } else {
            defaults.removeObject(forKey: "currentActiveHumanId")
        }
        if let cooldownLogs = state.cooldownLogs {
            defaults.set(cooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
        } else {
            defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        }
    }
}
