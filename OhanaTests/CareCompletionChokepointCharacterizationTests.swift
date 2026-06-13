import Foundation
import MapKit
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct CareCompletionChokepointCharacterizationTests {
    @Test func medicationDoseWritesFactRewardLedgerBudgetAndReminderForExecutor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Executor")
        let pet = Pet(name: "Momo", species: "cat")
        let medication = PetMedication(name: "Antibiotic", dosage: "1 pill", frequency: .daily, pet: pet)
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        context.insert(medication)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, executor], pets: [pet])
        let questManager = makeQuestManager()
        let medicationReminders = MedicationReminderManagerSpy()

        let event = PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: context,
            awardCoconut: true,
            questManager: questManager,
            activeHumanSelection: FixedActiveHumanSelection(id: executor.id.uuidString),
            medicationReminders: medicationReminders
        )

        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "Event" && $0.legacyModelId == event.id.uuidString
        })
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(event.eventType == EventType.petMedicationDose.rawValue)
        #expect(event.assigneeId == executor.id.uuidString)
        #expect(ledger.eventKind == CareLedgerEventKind.medication.rawValue)
        #expect(ledger.actorId == executor.id.uuidString)
        #expect(ledger.coconutDelta > 0)
        #expect(walletEntries.contains { $0.ownerId == executor.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != activeHuman.id.uuidString })
        #expect(budgetEvents.contains { $0.memberKey == executor.id.uuidString })
        #expect(medicationReminders.recordedMedicationIDs == [medication.id])
    }

    @Test func singleWalkPersistsWalkFactBeforeWalletRewardAndLinksPottyMarkers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Walker")
        let pet = Pet(name: "Piper", species: "dog")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])
        let wallet = WalkFactOrderAssertingWallet()
        let questManager = QuestManager(wallet: wallet, revisions: SharedDomainRevisionPublisher())
        let location = FakeWalkLocationManager()
        location.totalDistance = 900
        let manager = PetWalkingManager(locationManager: location, questManager: questManager)

        manager.start(pet: pet)
        manager.addPoop(type: .perfectPoop)
        manager.stop(modelContext: context)

        let walkLog = try #require(try context.fetch(FetchDescriptor<PetWalkLog>()).first)
        let pottyLog = try #require(try context.fetch(FetchDescriptor<PetPottyLog>()).first)
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(wallet.factCountSeenDuringReward > 0)
        #expect(walkLog.distanceMeters == 900)
        #expect(walkLog.coconutsEarned > 0)
        #expect(pottyLog.walkLogId == walkLog.id.uuidString)
        #expect(ledgers.contains { $0.eventKind == CareLedgerEventKind.potty.rawValue && $0.legacyModelId == pottyLog.id.uuidString })
        #expect(budgetEvents.contains { $0.actionKey == "walk" })
        #expect(budgetEvents.contains { $0.actionKey == "potty" })
    }

    @Test func sharedWalkWritesSessionChildFactsLedgerRewardAndBudgetOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Walker")
        let first = Pet(name: "Piper", species: "dog")
        let second = Pet(name: "Rex", species: "dog")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [first, second])

        let result = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 900,
            endDate: Date(timeIntervalSince1970: 2000),
            context: context,
            executorId: human.id.uuidString,
            startDate: Date(timeIntervalSince1970: 1800)
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(result.walkLogIDs.count == 2)
        #expect(session.actionKind == .walk)
        #expect(Set(walkLogs.map(\.sharedSessionId)) == Set([session.id.uuidString]))
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.walk.rawValue } == 2)
        #expect(ledgers.count { $0.coconutDelta > 0 } == 1)
        #expect(walletEntries.contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.contains { $0.ownerId == first.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.contains { $0.ownerId == second.id.uuidString && $0.delta > 0 })
        #expect(budgetEvents.count { $0.actionKey == "walk" && $0.scopeRaw == EconomyBudgetUsageScope.household.rawValue } == 1)
        #expect(budgetEvents.count { $0.actionKey == "walk" && $0.scopeRaw == EconomyBudgetUsageScope.member.rawValue } == 1)
        #expect(budgetEvents.count { $0.actionKey == "walk" && $0.scopeRaw == EconomyBudgetUsageScope.careObject.rawValue } == 2)
    }

    @Test func familyTwoPetAndHumanExpensesKeepExpenseFactsLedgerAndRewardDiscipline() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])
        let questManager = makeQuestManager()

        _ = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 42,
            date: Date(timeIntervalSince1970: 2100),
            category: .medical,
            note: "clinic",
            context: context,
            executorId: human.id.uuidString,
            questManager: questManager
        )
        UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        _ = ExpenseCommandService.recordHumanExpense(
            human: human,
            amount: 12,
            date: Date(timeIntervalSince1970: 2200),
            note: "medicine",
            context: context,
            category: .medical,
            questManager: questManager
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(expenses.count == 2)
        #expect(expenses.contains { $0.pet?.id == pet.id && $0.amount == 42 })
        #expect(expenses.contains { $0.pet == nil && $0.executorId == human.id.uuidString && $0.amount == 12 })
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.expense.rawValue } == 2)
        #expect(ledgers.allSatisfy { $0.legacyModelName == "PetExpenseLog" })
        #expect(walletEntries.contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
        #expect(budgetEvents.count { $0.actionKey == "expense" && $0.scopeRaw == EconomyBudgetUsageScope.household.rawValue } == 2)
        #expect(budgetEvents.count { $0.actionKey == "expense" && $0.scopeRaw == EconomyBudgetUsageScope.member.rawValue } == 2)
        #expect(budgetEvents.count { $0.actionKey == "expense" && $0.scopeRaw == EconomyBudgetUsageScope.careObject.rawValue } == 1)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
    }

    @Test func familyTwoMomentKeepsPhotoFactLedgerAndRewardOutsideCareFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])

        let result = MomentCommandService.recordMoment(
            pet: pet,
            note: "sunny nap",
            photoData: [Data([1, 2, 3])],
            locationLatitude: 0,
            locationLongitude: 0,
            locationPlacename: "",
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2300),
            questManager: makeQuestManager()
        )

        let photo = try #require(try context.fetch(FetchDescriptor<PetPhotoLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())

        #expect(result.savedLogIDs == [photo.id])
        #expect(result.coconutDelta > 0)
        #expect(ledger.eventKind == CareLedgerEventKind.milestone.rawValue)
        #expect(ledger.legacyModelName == "PetPhotoLog")
        #expect(ledger.legacyModelId == photo.id.uuidString)
        #expect(walletEntries.contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
    }

    @Test func frozenPetExpenseKeepsFactAndLedgerButDoesNotWriteWalletReward() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])

        let result = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 18,
            date: Date(timeIntervalSince1970: 2400),
            category: .medical,
            note: "memorial archive",
            context: context,
            executorId: human.id.uuidString,
            questManager: makeQuestManager()
        )

        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)

        #expect(result.coconutDelta == 0)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).count == 1)
        #expect(ledger.eventKind == CareLedgerEventKind.expense.rawValue)
        #expect(ledger.coconutDelta == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeQuestManager() -> QuestManager {
        makeQuestManager(wallet: SwiftDataCoconutWalletManager())
    }

    private func makeQuestManager(wallet: CoconutWalletManaging) -> QuestManager {
        let questManager = QuestManager(wallet: wallet, revisions: SharedDomainRevisionPublisher())
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        return questManager
    }

    private func resetEconomy(activeHumanID: String, humans: [Human], pets: [Pet]) {
        let defaults = UserDefaults.standard
        defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        EconomyDailyBudgetStore.resetAll()
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey()
        let careObjectKeys = pets.map { "pet.\($0.id.uuidString)" }
        for human in humans {
            EconomyDailyBudgetStore.reset(
                householdKey: householdKey,
                memberKey: human.id.uuidString,
                careObjectKeys: careObjectKeys
            )
        }
    }
}

private struct EconomyDefaultsState {
    let activeHumanID: Any?
    let cooldownLogs: Any?
    let boostDouble: Any?

    static func capture() -> EconomyDefaultsState {
        let defaults = UserDefaults.standard
        return EconomyDefaultsState(
            activeHumanID: defaults.object(forKey: "currentActiveHumanId"),
            cooldownLogs: defaults.object(forKey: QuestManager.Keys.cooldownLogs),
            boostDouble: defaults.object(forKey: "shop_boostDoubleActive")
        )
    }

    func restore() {
        restore(activeHumanID, key: "currentActiveHumanId")
        restore(cooldownLogs, key: QuestManager.Keys.cooldownLogs)
        restore(boostDouble, key: "shop_boostDoubleActive")
        EconomyDailyBudgetStore.resetAll()
    }

    private func restore(_ value: Any?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private struct FixedActiveHumanSelection: ActiveHumanSelecting {
    let id: String?
    var currentHumanId: String? { id }
    var currentHumanIdRaw: String { id ?? "" }
}

private final class MedicationReminderManagerSpy: MedicationReminderManaging {
    private(set) var recordedMedicationIDs: [UUID] = []

    func dosesTakenToday(for _: UUID) -> Int { 0 }
    func recordDose(for medicationId: UUID) { recordedMedicationIDs.append(medicationId) }
    func undoDose(for _: UUID) {}
    func scheduleMedicationReminders(for _: Pet, context _: ModelContext?) {}
    func scheduleHumanMedicationReminders(for _: Human, meds _: [HumanMedication], context _: ModelContext?) {}
}

private final class FakeWalkLocationManager: WalkLocationManaging {
    var currentLocation: CLLocation?
    var collectedLocations: [CLLocation] = []
    var totalDistance: Double = 0

    func startWalkSession() {}
    func stopWalkSession() {}
    func pauseWalkSession() {}
    func resumeWalkSession() {}
    func stopAllLocationActivity() {}
    func promoteActiveWalkToBackgroundDelivery() {}
    func returnActiveWalkToForegroundDelivery() {}
    func enforceNoLocationUnlessRunningWalk(_: Bool, reason _: String) {}
    func routeLocationsForPersistence(maxCount _: Int) -> [CLLocation] { collectedLocations }
}

@MainActor
private final class WalkFactOrderAssertingWallet: CoconutWalletManaging {
    private let base = SwiftDataCoconutWalletManager()
    private(set) var factCountSeenDuringReward = 0

    func apply(
        deltas: [CoconutWalletDelta],
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        updatesProjection: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry] {
        factCountSeenDuringReward = try context.fetch(FetchDescriptor<PetWalkLog>()).count
        return try base.apply(
            deltas: deltas,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            updatesProjection: updatesProjection,
            projectionManager: projectionManager
        )
    }

    func applyActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry] {
        try base.applyActorDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            actorId: actorId,
            actorName: actorName,
            entryKind: entryKind,
            source: source,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            projectionManager: projectionManager
        )
    }

    func totalBalance(context: ModelContext) -> Int { base.totalBalance(context: context) }
    func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int { base.balance(accountKey: accountKey, context: context, fallback: fallback) }
    func balance(for human: Human, context: ModelContext) -> Int { base.balance(for: human, context: context) }
    func balance(for pet: Pet, context: ModelContext) -> Int { base.balance(for: pet, context: context) }
    func legacySystemBalance(context: ModelContext, fallback: Int) -> Int { base.legacySystemBalance(context: context, fallback: fallback) }
    func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext) {
        base.setDeveloperOverrideBalance(amount: amount, for: human, displayName: displayName, context: context)
    }
    func refreshQuestProjection(context: ModelContext, manager: QuestManager?) {
        base.refreshQuestProjection(context: context, manager: manager)
    }
    func bootstrapIfNeeded(context: ModelContext, projectionManager: QuestManager?) throws {
        try base.bootstrapIfNeeded(context: context, projectionManager: projectionManager)
    }
}
