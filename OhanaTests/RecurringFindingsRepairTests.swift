import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct RecurringFindingsRepairTests {
    @Test func explicitExecutorRewardEntrypointsCreditExecutorWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Executor")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        try context.save()

        let questManager = makeQuestManager()
        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: activeHuman.id.uuidString,
            questManager: questManager,
            memberIDs: [activeHuman.id.uuidString, executor.id.uuidString],
            petID: pet.id
        )

        _ = WeightCommandService.recordPetWeight(
            pet: pet,
            weight: 4.2,
            date: Date(timeIntervalSince1970: 1_800_000_001),
            context: context,
            executorId: executor.id.uuidString,
            awardsReward: true,
            ledgerSource: .detail,
            questManager: questManager
        )
        _ = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 12,
            date: Date(timeIntervalSince1970: 1_800_000_002),
            category: .medical,
            note: "clinic",
            context: context,
            executorId: executor.id.uuidString,
            questManager: questManager
        )
        _ = try #require(PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .checkup,
                date: Date(timeIntervalSince1970: 1_800_000_003),
                name: "Checkup",
                note: "",
                vetName: "",
                cost: 0,
                expirationDate: nil,
                nextCheckupDate: nil,
                executorId: executor.id.uuidString,
                source: .detail,
                includesNameInNote: true
            ),
            context: context,
            questManager: questManager
        ))

        #expect(activeHuman.coconutBalance == 0)
        #expect(executor.coconutBalance > 0)
        let humanRewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.ownerKindRaw == CoconutWalletOwnerKind.human.rawValue && $0.delta > 0 }
        #expect(humanRewardEntries.isEmpty == false)
        #expect(humanRewardEntries.allSatisfy { $0.ownerId == executor.id.uuidString })
    }

    @Test func backdateRewardUsesProvidedActiveHumanSelectionForOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let selectedHuman = Human(name: "Selected")
        let pet = Pet(name: "Momo", species: "dog")
        context.insert(activeHuman)
        context.insert(selectedHuman)
        context.insert(pet)
        try context.save()

        let questManager = makeQuestManager()
        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: activeHuman.id.uuidString,
            questManager: questManager,
            memberIDs: [activeHuman.id.uuidString, selectedHuman.id.uuidString],
            petID: pet.id
        )

        let result = BackdateCheckInCommandService.award(
            action: .general(humanReward: 4, petReward: 0, emoji: "B", title: "Backdate"),
            actionKey: "backdate",
            pet: pet,
            context: context,
            questManager: questManager,
            activeHumanSelection: FixedActiveHumanSelection(id: selectedHuman.id.uuidString)
        )

        #expect(result.humanID == selectedHuman.id)
        #expect(activeHuman.coconutBalance == 0)
        #expect(selectedHuman.coconutBalance == result.humanGot)
        #expect(result.humanGot > 0)
    }

    @Test func manualMilestoneRewardAndLedgerUseCurrentActiveHuman() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "dog")
        context.insert(activeHuman)
        context.insert(pet)
        try context.save()

        let questManager = makeQuestManager()
        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: activeHuman.id.uuidString,
            questManager: questManager,
            memberIDs: [activeHuman.id.uuidString],
            petID: pet.id
        )

        let result = PetMilestoneCommandService.createMilestone(
            input: PetMilestoneCommandInput(
                date: Date(timeIntervalSince1970: 1_800_000_004),
                title: "First beach day",
                emoji: "",
                notes: "",
                photoData: nil,
                location: ""
            ),
            pet: pet,
            context: context,
            questManager: questManager
        )

        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "PetMilestone" && $0.legacyModelId == result.milestoneIDs.first?.uuidString
        })
        #expect(result.coconutDelta > 0)
        #expect(activeHuman.coconutBalance > 0)
        #expect(ledger.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(ledger.actorId == activeHuman.id.uuidString)
    }

    @Test func calendarWholeEventDeleteTombstonesEventAndCascadeReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = Event(
            title: "Vet",
            startDate: Date(timeIntervalSince1970: 1_800_000_005),
            eventType: EventType.medication.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: UUID().uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        _ = CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: event.startDate,
            scope: CalendarEventDeletionScope.wholeEvent,
            context: context
        )

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: event.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Reminder.self), id: reminder.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func factDeleteCommandsTombstoneAssociatedCareLedgerEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let careLog = PetCareLog(type: .feeding, pet: pet)
        let pottyLog = PetPottyLog(date: Date(timeIntervalSince1970: 1_800_000_006), type: .pee, pet: pet)
        let hygieneLog = PetHygieneLog(date: Date(timeIntervalSince1970: 1_800_000_007), type: .bath, pet: pet)
        let expenseLog = PetExpenseLog(date: Date(timeIntervalSince1970: 1_800_000_008), amount: 9, category: .medical, note: "", pet: pet)
        let weightLog = PetWeightLog(date: Date(timeIntervalSince1970: 1_800_000_009), weight: 4.3, pet: pet)
        let careLedger = ledgerEvent(model: "PetCareLog", id: careLog.id)
        let pottyLedger = ledgerEvent(model: "PetPottyLog", id: pottyLog.id)
        let hygieneLedger = ledgerEvent(model: "PetHygieneLog", id: hygieneLog.id)
        let expenseLedger = ledgerEvent(model: "PetExpenseLog", id: expenseLog.id)
        let weightLedger = ledgerEvent(model: "PetWeightLog", id: weightLog.id)
        context.insert(pet)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(expenseLog)
        context.insert(weightLog)
        context.insert(careLedger)
        context.insert(pottyLedger)
        context.insert(hygieneLedger)
        context.insert(expenseLedger)
        context.insert(weightLedger)
        try context.save()

        _ = PetCareTrackingCommandService.deleteCareLog(careLog, pet: pet, context: context)
        _ = PetPottyCommandService.deletePottyLog(pottyLog, pet: pet, context: context)
        _ = PetHygieneCommandService.delete(hygieneLog, pet: pet, context: context)
        _ = DashboardRecordCommandService.deletePetExpense(expenseLog, pet: pet, context: context)
        _ = DashboardRecordCommandService.deletePetWeight(weightLog, pet: pet, context: context)

        for ledger in [careLedger, pottyLedger, hygieneLedger, expenseLedger, weightLedger] {
            #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: ledger.id, context: context)?.isDeletionTombstone == true)
        }
    }

    @Test func catCareUndoTombstonesRemovedEventAndHygieneLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        try context.save()

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Scoop",
                emoji: "S",
                recordsHygiene: true,
                occurredAt: Date(timeIntervalSince1970: 1_800_000_010),
                executorId: "human-1"
            ),
            context: context
        )
        let hygieneLogID = try #require(recorded.hygieneLogID)

        _ = CatCareCommandService.undo(
            pet: pet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: recorded.eventID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetHygieneLog.self), id: hygieneLogID, context: context)?.isDeletionTombstone == true)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeQuestManager() -> QuestManager {
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager())
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        return questManager
    }

    private func prepareEconomyDefaults(
        activeHumanID: String,
        questManager: QuestManager,
        memberIDs: [String],
        petID: UUID
    ) {
        UserDefaults.standard.set(activeHumanID, forKey: "currentActiveHumanId")
        UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        UserDefaults.standard.removeObject(forKey: "shop_boostDoubleActive")
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        let objectKeys = ["pet.\(petID.uuidString)"]
        for memberID in memberIDs {
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
                memberKey: memberID,
                careObjectKeys: objectKeys
            )
        }
    }

    private func ledgerEvent(model: String, id: UUID) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 1_800_000_011),
            subjectKind: .pet,
            subjectId: UUID().uuidString,
            eventKind: .unknown,
            actionType: "delete-test",
            legacyModelName: model,
            legacyModelId: id.uuidString
        )
    }

    private func cloudSyncState(entityName: String, id: UUID, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == entityName && $0.localRecordId == id.uuidString.lowercased()
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
