import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct EconomyBackdateSettlementTests {
    @MainActor
    @Test func backdatedCareRecordUsesOperationDayForBudget() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let operationBefore = Date()
        let historicalDate = Calendar.current.date(byAdding: .day, value: -30, to: operationBefore)!
        let historicalDayKey = EconomyDailyBudgetStore.dayKey(for: historicalDate)
        let objectKeys = ["pet.\(pet.id.uuidString)"]
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        let oldBoostDouble = defaults.object(forKey: "shop_boostDoubleActive")
        let setup = makeDependencies()
        let dependencies = setup.dependencies
        let questManager = setup.questManager
        let oldFirstMeal = questManager.isFirstMealRecorded
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        let oldLastReward = questManager.lastEconomyRewardResult
        defer {
            restoreDefaults(
                activeHumanID: oldActiveHumanID,
                cooldownLogs: oldCooldownLogs,
                boostDouble: oldBoostDouble
            )
            questManager.isFirstMealRecorded = oldFirstMeal
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.lastEconomyRewardResult = oldLastReward
            questManager.persistQuestFlags()
            resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: operationBefore)
            resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: historicalDate)
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        questManager.isFirstMealRecorded = true
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        questManager.persistQuestFlags()
        resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: operationBefore)
        resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: historicalDate)
        fillBudgetToRecordOnly(
            memberKey: human.id.uuidString,
            careObjectKeys: objectKeys,
            date: historicalDate,
            context: context
        )
        let historicalUsageCountBefore = usageEvents(
            context: context,
            dayKey: historicalDayKey,
            actionKey: "feed"
        ).count

        let record = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 80,
            context: context,
            executorId: human.id.uuidString,
            date: historicalDate,
            dependencies: dependencies
        )
        let operationAfter = Date()
        let operationDayKeys = Set([
            EconomyDailyBudgetStore.dayKey(for: operationBefore),
            EconomyDailyBudgetStore.dayKey(for: operationAfter)
        ])

        #expect(record.log.date == historicalDate)
        #expect(record.reward.humanGot + record.reward.petGot > 0)
        #expect(questManager.lastEconomyRewardResult?.budgetStage != .recordOnly)
        #expect(usageEvents(context: context, dayKey: historicalDayKey, actionKey: "feed").count == historicalUsageCountBefore)
        #expect(usageEvents(context: context, dayKeys: operationDayKeys, actionKey: "feed").isEmpty == false)

        let careLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.legacyModelId == record.log.id.uuidString }
        #expect(careLedgerEvents.map(\.occurredAt) == [historicalDate])

        let rewardLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .careEvent }
        #expect(rewardLedgerEntries.isEmpty == false)
        #expect(rewardLedgerEntries.allSatisfy { operationDayKeys.contains(EconomyDailyBudgetStore.dayKey(for: $0.occurredAt)) })
    }

    @MainActor
    @Test func backdatedCareRecordUsesOperationTimeForCooldown() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let operationDate = Date()
        let firstHistoricalDate = Calendar.current.date(byAdding: .day, value: -20, to: operationDate)!
        let secondHistoricalDate = Calendar.current.date(byAdding: .day, value: -19, to: operationDate)!
        let objectKeys = ["pet.\(pet.id.uuidString)"]
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        let oldBoostDouble = defaults.object(forKey: "shop_boostDoubleActive")
        let setup = makeDependencies()
        let dependencies = setup.dependencies
        let questManager = setup.questManager
        let oldFirstMeal = questManager.isFirstMealRecorded
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        let oldLastReward = questManager.lastEconomyRewardResult
        defer {
            restoreDefaults(
                activeHumanID: oldActiveHumanID,
                cooldownLogs: oldCooldownLogs,
                boostDouble: oldBoostDouble
            )
            questManager.isFirstMealRecorded = oldFirstMeal
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
            questManager.lastEconomyRewardResult = oldLastReward
            questManager.persistQuestFlags()
            resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: operationDate)
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        questManager.isFirstMealRecorded = true
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        questManager.persistQuestFlags()
        resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: operationDate)

        let first = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 80,
            context: context,
            executorId: human.id.uuidString,
            date: firstHistoricalDate,
            dependencies: dependencies
        )
        let firstReward = questManager.lastEconomyRewardResult
        let second = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 90,
            context: context,
            executorId: human.id.uuidString,
            date: secondHistoricalDate,
            dependencies: dependencies
        )
        let secondReward = questManager.lastEconomyRewardResult

        #expect(first.reward.humanGot + first.reward.petGot > 0)
        #expect(firstReward?.isOnCooldown == false)
        #expect(second.reward.humanGot + second.reward.petGot == 0)
        #expect(secondReward?.isOnCooldown == true)
        #expect(secondReward?.budgetStage == .cooldown)

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(careLogs.map(\.date).sorted() == [firstHistoricalDate, secondHistoricalDate].sorted())
    }

    @MainActor
    @Test func calendarHistoricalOccurrenceUsesOperationDayForBudget() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let operationDate = Date(timeIntervalSince1970: 1_800_000_000)
        let historicalDate = Calendar.current.date(byAdding: .day, value: -30, to: operationDate)!
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        let event = Event(
            title: "Feed Momo 80g",
            startDate: historicalDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        try context.save()

        let objectKeys = ["pet.\(pet.id.uuidString)"]
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        let oldBoostDouble = defaults.object(forKey: "shop_boostDoubleActive")
        let dependencies = makeDependencies().dependencies
        defer {
            restoreDefaults(
                activeHumanID: oldActiveHumanID,
                cooldownLogs: oldCooldownLogs,
                boostDouble: oldBoostDouble
            )
            resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: operationDate)
            resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: historicalDate)
        }
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: operationDate)
        resetBudget(memberKey: human.id.uuidString, careObjectKeys: objectKeys, date: historicalDate)

        let historicalDayKey = EconomyDailyBudgetStore.dayKey(for: historicalDate)
        let operationDayKey = EconomyDailyBudgetStore.dayKey(for: operationDate)
        let historicalUsageCountBefore = usageEvents(
            context: context,
            dayKey: historicalDayKey,
            actionKey: "feed"
        ).count

        let completed = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: historicalDate,
            pets: [pet],
            context: context,
            executorId: human.id.uuidString,
            now: operationDate,
            options: CalendarEventCompletionOptions(economy: dependencies.economy)
        )

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        let operationUsageEvents = usageEvents(context: context, dayKey: operationDayKey, actionKey: "feed")
        let rewardLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .careEvent && $0.delta > 0 }

        #expect(completed.isCompleted)
        #expect(Calendar.current.isDate(careLog.date, inSameDayAs: historicalDate))
        #expect(Calendar.current.isDate(ledger.occurredAt, inSameDayAs: historicalDate))
        #expect(usageEvents(context: context, dayKey: historicalDayKey, actionKey: "feed").count == historicalUsageCountBefore)
        #expect(operationUsageEvents.isEmpty == false)
        #expect(rewardLedgerEntries.isEmpty == false)
        #expect(rewardLedgerEntries.allSatisfy { EconomyDailyBudgetStore.dayKey(for: $0.occurredAt) != historicalDayKey })
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDependencies() -> (dependencies: CareEventServiceDependencies, questManager: QuestManager) {
        let wallet = SwiftDataCoconutWalletManager()
        let revisions = SharedDomainRevisionPublisher()
        let questManager = QuestManager(wallet: wallet, revisions: revisions)
        let careLedger = CareLedgerService()
        let familyTasks = StaticFamilyTaskManager(wallet: wallet, careLedger: careLedger, questManager: questManager)
        let reminderCompletion = ReminderCompletionService(careLedger: careLedger, familyTasks: familyTasks)
        let dependencies = CareEventServiceDependencies(
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion),
            familyTasks: familyTasks,
            revisions: revisions
        )
        return (dependencies, questManager)
    }

    private func fillBudgetToRecordOnly(
        memberKey: String,
        careObjectKeys: [String],
        date: Date,
        context: ModelContext
    ) {
        for _ in 0 ..< 40 {
            let result = CoconutEconomyPolicyV2.reward(
                for: .feed,
                quality: .none,
                isOnCooldown: false,
                userKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: memberKey,
                careObjectKeys: careObjectKeys,
                careObjectCount: 1,
                hasHumanAccount: true,
                hasPetAccount: true,
                date: date,
                forcedLuck: EconomyLuckTier.none,
                context: context
            )
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: memberKey,
                careObjectKeys: careObjectKeys,
                date: date,
                context: context,
                save: true
            )
        }
    }

    private func usageEvents(
        context: ModelContext,
        dayKey: String,
        actionKey: String
    ) -> [EconomyBudgetUsageEvent] {
        usageEvents(context: context, dayKeys: [dayKey], actionKey: actionKey)
    }

    private func usageEvents(
        context: ModelContext,
        dayKeys: Set<String>,
        actionKey: String
    ) -> [EconomyBudgetUsageEvent] {
        let events = (try? context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())) ?? []
        return events.filter { dayKeys.contains($0.dayKey) && $0.actionKey == actionKey }
    }

    private func resetBudget(memberKey: String, careObjectKeys: [String], date: Date) {
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
            memberKey: memberKey,
            careObjectKeys: careObjectKeys,
            date: date
        )
    }

    private func restoreDefaults(activeHumanID: Any?, cooldownLogs: Any?, boostDouble: Any?) {
        restoreDefault(activeHumanID, key: "currentActiveHumanId")
        restoreDefault(cooldownLogs, key: QuestManager.Keys.cooldownLogs)
        restoreDefault(boostDouble, key: "shop_boostDoubleActive")
    }

    private func restoreDefault(_ value: Any?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
