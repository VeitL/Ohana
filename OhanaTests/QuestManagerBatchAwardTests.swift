import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct QuestManagerBatchAwardTests {
    @Test func batchAwardNoopsForDeceasedExecutorBeforeFactsLedgerAndRewards() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Archived")
        executor.passedAwayDate = Date()
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(executor)
        context.insert(pet)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            restoreDefault(oldActiveHumanID, key: "currentActiveHumanId")
            restoreDefault(oldCooldownLogs, key: QuestManager.Keys.cooldownLogs)
        }
        defaults.set(executor.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let result = questManager.batchAward(type: .feed, pets: [pet], context: context)

        #expect(result.totalHuman == 0)
        #expect(result.totalPet == 0)
        #expect(executor.coconutBalance == 0)
        #expect(pet.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func batchAwardFiltersTargetsThroughDispositionAndWritesLedgerViaCareChokepoint() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Momo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        let passedAway = Pet(name: "Past", species: "猫")
        passedAway.passedAwayDate = Date(timeIntervalSince1970: 1)
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        context.insert(passedAway)
        try context.save()

        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            restoreDefault(oldActiveHumanID, key: "currentActiveHumanId")
            restoreDefault(oldCooldownLogs, key: QuestManager.Keys.cooldownLogs)
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
                memberKey: executor.id.uuidString,
                careObjectKeys: [first.id.uuidString, second.id.uuidString]
            )
        }
        defaults.set(executor.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: executor.id.uuidString,
            careObjectKeys: [first.id.uuidString, second.id.uuidString]
        )

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let result = questManager.batchAward(type: .feed, pets: [first, second, passedAway], context: context)

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let careLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let logPetIDs = Set(careLogs.compactMap { $0.pet?.id })
        let walletOwnerIDs = Set(walletEntries.map(\.ownerId))

        #expect(result.totalHuman > 0)
        #expect(result.totalPet > 0)
        #expect(careLogs.count == 2)
        #expect(logPetIDs == Set([first.id, second.id]))
        #expect(sessions.count == 1)
        #expect(Set(sessions[0].targetPetIds) == Set([first.id.uuidString, second.id.uuidString]))
        #expect(careLedgerEvents.count == 2)
        #expect(walletOwnerIDs.contains(executor.id.uuidString))
        #expect(walletOwnerIDs.contains(first.id.uuidString))
        #expect(walletOwnerIDs.contains(second.id.uuidString))
        #expect(!walletOwnerIDs.contains(passedAway.id.uuidString))
    }

    @Test func batchAwardNonLitterPottyWritesPerPetFactsButOnlyOneSharedReward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Piper", species: "狗")
        let second = Pet(name: "Rex", species: "狗")
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let result = questManager.batchAward(type: .potty(isLitter: false), pets: [first, second], context: context)

        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        let humanEntries = walletEntries.filter { $0.ownerId == executor.id.uuidString && $0.delta > 0 }
        let session = try #require(sessions.first)

        #expect(result.totalHuman > 0)
        #expect(result.totalPet > 0)
        #expect(sessions.count == 1)
        #expect(session.actionKind == .potty)
        #expect(Set(session.targetPetIds) == Set([first.id.uuidString, second.id.uuidString]))
        #expect(session.primaryLegacyModelName == String(describing: PetPottyLog.self))
        #expect(pottyLogs.count == 2)
        #expect(Set(pottyLogs.compactMap { $0.pet?.id }) == Set([first.id, second.id]))
        #expect(pottyLogs.allSatisfy { $0.sharedSessionId == session.id.uuidString })
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.potty.rawValue } == 2)
        #expect(ledgers.count { $0.coconutDelta > 0 } == 1)
        #expect(humanEntries.count == 1)
        #expect(humanEntries.map(\.delta).reduce(0, +) == result.totalHuman)
        #expect(budgetEvents.count { $0.actionKey == "potty" && $0.scopeRaw == EconomyBudgetUsageScope.member.rawValue } == 1)
        #expect(budgetEvents.count { $0.actionKey == "potty" && $0.scopeRaw == EconomyBudgetUsageScope.careObject.rawValue } == 2)
    }

    @Test func batchAwardHygieneWritesPerPetFactsButOnlyOneSharedReward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Piper", species: "狗")
        let second = Pet(name: "Rex", species: "狗")
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let result = questManager.batchAward(type: .care(type: .bath), pets: [first, second], context: context)

        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        let humanEntries = walletEntries.filter { $0.ownerId == executor.id.uuidString && $0.delta > 0 }
        let session = try #require(sessions.first)

        #expect(result.totalHuman > 0)
        #expect(result.totalPet > 0)
        #expect(sessions.count == 1)
        #expect(session.actionKind == .hygiene)
        #expect(Set(session.targetPetIds) == Set([first.id.uuidString, second.id.uuidString]))
        #expect(session.primaryLegacyModelName == String(describing: PetHygieneLog.self))
        #expect(Set(hygieneLogs.map(\.id.uuidString)).contains(session.primaryLegacyModelId))
        #expect(hygieneLogs.count == 2)
        #expect(Set(hygieneLogs.compactMap { $0.pet?.id }) == Set([first.id, second.id]))
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.hygiene.rawValue } == 2)
        #expect(ledgers.count { $0.coconutDelta > 0 } == 1)
        #expect(humanEntries.count == 1)
        #expect(humanEntries.map(\.delta).reduce(0, +) == result.totalHuman)
        #expect(budgetEvents.count { $0.actionKey == "bath" && $0.scopeRaw == EconomyBudgetUsageScope.member.rawValue } == 1)
        #expect(budgetEvents.count { $0.actionKey == "bath" && $0.scopeRaw == EconomyBudgetUsageScope.careObject.rawValue } == 2)
    }

    @Test func sharedCareNoopsWhenSourceCannotWriteEvenWithExplicitTargets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let activeTarget = Pet(name: "Rex", species: "狗")
        let deceasedFeedSource = Pet(name: "Memorial feed", species: "狗")
        let deceasedWaterSource = Pet(name: "Memorial water", species: "狗")
        let deceasedLitterSource = Pet(name: "Memorial litter", species: "狗")
        let deceasedPlaySource = Pet(name: "Memorial play", species: "狗")
        let deceasedWalkSource = Pet(name: "Memorial walk", species: "狗")
        let deceasedPottySource = Pet(name: "Memorial potty", species: "狗")
        deceasedFeedSource.passedAwayDate = Date(timeIntervalSince1970: 1000)
        deceasedWaterSource.passedAwayDate = Date(timeIntervalSince1970: 1001)
        deceasedLitterSource.passedAwayDate = Date(timeIntervalSince1970: 1002)
        deceasedPlaySource.passedAwayDate = Date(timeIntervalSince1970: 1003)
        deceasedWalkSource.passedAwayDate = Date(timeIntervalSince1970: 1004)
        deceasedPottySource.passedAwayDate = Date(timeIntervalSince1970: 1005)
        context.insert(executor)
        context.insert(activeTarget)
        context.insert(deceasedFeedSource)
        context.insert(deceasedWaterSource)
        context.insert(deceasedLitterSource)
        context.insert(deceasedPlaySource)
        context.insert(deceasedWalkSource)
        context.insert(deceasedPottySource)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let feed = CareEventService.recordSharedManualFeedFact(
            sourcePet: deceasedFeedSource,
            targets: [activeTarget],
            totalGrams: 80,
            foodKind: .dry,
            context: context,
            executorId: executor.id.uuidString,
            date: Date(timeIntervalSince1970: 2000)
        )
        let water = CareEventService.recordSharedWateringFact(
            sourcePet: deceasedWaterSource,
            targets: [activeTarget],
            totalMl: 250,
            context: context,
            executorId: executor.id.uuidString,
            date: Date(timeIntervalSince1970: 2001)
        )
        let litter = CareEventService.recordSharedLitterCareFact(
            sourcePet: deceasedLitterSource,
            targets: [activeTarget],
            context: context,
            executorId: executor.id.uuidString,
            date: Date(timeIntervalSince1970: 2002)
        )
        let play = CareEventService.recordSharedCareFact(
            sourcePet: deceasedPlaySource,
            targets: [activeTarget],
            type: .play,
            actionKind: .play,
            context: context,
            executorId: executor.id.uuidString,
            reward: .general(humanReward: 3, petReward: 2, emoji: CareType.play.emoji, title: "Shared play"),
            date: Date(timeIntervalSince1970: 2003)
        )
        let walk = CareEventService.recordSharedWalk(
            sourcePet: deceasedWalkSource,
            targets: [activeTarget],
            distanceMeters: 1200,
            endDate: Date(timeIntervalSince1970: 2100),
            context: context,
            executorId: executor.id.uuidString,
            startDate: Date(timeIntervalSince1970: 2004)
        )
        _ = CareEventService.recordUnknownSharedPotty(
            sourcePet: deceasedPottySource,
            targets: [activeTarget],
            type: .perfectPoop,
            context: context,
            executorId: executor.id.uuidString,
            date: Date(timeIntervalSince1970: 2005)
        )

        #expect(feed.didWriteFact == false)
        #expect(water.didWriteFact == false)
        #expect(litter.didWriteFact == false)
        #expect(play.didWriteFact == false)
        #expect(walk.didWriteFact == false)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func batchAwardHygieneSessionReconcileKeepsHygieneFacts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Piper", species: "狗")
        let second = Pet(name: "Rex", species: "狗")
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        _ = questManager.batchAward(type: .care(type: .bath), pets: [first, second], context: context)

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        SharedCareSessionMaintenance.reconcile(
            session,
            context: context,
            reconciledAt: Date(timeIntervalSince1970: 3000)
        )

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(sessions.count == 1)
        #expect(Set(sessions.first?.targetPetIds ?? []) == Set([first.id.uuidString, second.id.uuidString]))
        #expect(sessions.first?.primaryLegacyModelName == String(describing: PetHygieneLog.self))
        #expect(Set(hygieneLogs.map(\.id.uuidString)).contains(sessions.first?.primaryLegacyModelId ?? ""))
        #expect(hygieneLogs.count == 2)
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.hygiene.rawValue } == 2)
    }

    @Test func deleteCascadeRemovesSharedHygieneFactsAndLedger() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Piper", species: "狗")
        let second = Pet(name: "Rex", species: "狗")
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        _ = questManager.batchAward(type: .care(type: .bath), pets: [first, second], context: context)

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let result = SharedCareSessionMaintenance.deleteCascade(
            session,
            context: context,
            deletedByHumanId: executor.id.uuidString,
            deletedAt: Date(timeIntervalSince1970: 3100)
        )

        #expect(result.hygieneLogIDs.count == 2)
        #expect(result.deletedChildCount == 2)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter { $0.eventKind == CareLedgerEventKind.hygiene.rawValue }.isEmpty)
    }

    @Test func deletingPrimarySharedHygieneFactReconcilesSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Piper", species: "狗")
        let second = Pet(name: "Rex", species: "狗")
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        _ = questManager.batchAward(type: .care(type: .bath), pets: [first, second], context: context)

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let primaryLog = try #require(hygieneLogs.first { $0.id.uuidString == session.primaryLegacyModelId })
        let remainingLog = try #require(hygieneLogs.first { $0.id != primaryLog.id })
        let remainingPet = try #require(remainingLog.pet)

        let deleteResult = PetHygieneCommandService.delete(
            primaryLog,
            pet: try #require(primaryLog.pet),
            context: context
        )

        let updatedSession = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let remainingHygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let hygieneLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.eventKind == CareLedgerEventKind.hygiene.rawValue }

        #expect(deleteResult.removedLedgerEventIDs.count == 1)
        #expect(remainingHygieneLogs.map(\.id) == [remainingLog.id])
        #expect(updatedSession.primaryLegacyModelName == String(describing: PetHygieneLog.self))
        #expect(updatedSession.primaryLegacyModelId == remainingLog.id.uuidString)
        #expect(updatedSession.targetPetIds == [remainingPet.id.uuidString])
        #expect(hygieneLedgers.count == 1)
        #expect(hygieneLedgers.first?.legacyModelId == remainingLog.id.uuidString)
    }

    @Test func batchAwardGeneralLitterKeepsCustomRewardTypeThroughSharedCareChokepoint() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let executor = Human(name: "Guan")
        let first = Pet(name: "Momo", species: "猫")
        let second = Pet(name: "Luna", species: "猫")
        context.insert(executor)
        context.insert(first)
        context.insert(second)
        try context.save()

        let snapshot = prepareEconomy(activeHumanID: executor.id.uuidString)
        defer { restoreEconomy(snapshot) }

        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager(), revisions: SharedDomainRevisionPublisher())
        let result = questManager.batchAward(
            type: .general(humanReward: 5, petReward: 8, emoji: "🧹", title: "铲砂打卡"),
            pets: [first, second],
            context: context
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let totalWalletDelta = walletEntries.map(\.delta).reduce(0, +)

        #expect(result.totalHuman + result.totalPet >= 20)
        #expect(careLogs.count == 2)
        #expect(careLogs.allSatisfy { $0.careType == .litter })
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.care.rawValue && $0.actionType == CareType.litter.rawValue } == 2)
        #expect(ledgers.count { $0.coconutDelta > 0 } == 1)
        #expect(walletEntries.count { $0.ownerId == executor.id.uuidString && $0.delta > 0 } == 1)
        #expect(totalWalletDelta == result.totalHuman + result.totalPet)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func prepareEconomy(activeHumanID: String) -> (activeHumanID: Any?, cooldownLogs: Any?) {
        let defaults = UserDefaults.standard
        let snapshot = (
            activeHumanID: defaults.object(forKey: "currentActiveHumanId"),
            cooldownLogs: defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        )
        defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.resetAll()
        return snapshot
    }

    private func restoreEconomy(_ snapshot: (activeHumanID: Any?, cooldownLogs: Any?)) {
        restoreDefault(snapshot.activeHumanID, key: "currentActiveHumanId")
        restoreDefault(snapshot.cooldownLogs, key: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.resetAll()
    }

    private func restoreDefault(_ value: Any?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
