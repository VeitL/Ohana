import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct CatCareCommandTests {
    @Test func undoIgnoresArtifactsWhenPetDoesNotMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "cat")
        let executor = Human(name: "Executor")
        context.insert(executor)
        context.insert(pet)
        context.insert(otherPet)
        try context.save()
        let cleanup = isolateEconomy(activeHumanID: executor.id.uuidString)
        defer { cleanup() }

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Scoop litter",
                emoji: "L",
                recordsHygiene: true,
                occurredAt: Date(timeIntervalSince1970: 1_780_000_000),
                executorId: executor.id.uuidString
            ),
            context: context
        )
        let hygieneLogID = try #require(recorded.hygieneLogID)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "PetHygieneLog" && $0.legacyModelId == hygieneLogID.uuidString
        })

        let wrongPetUndo = CatCareCommandService.undo(
            pet: otherPet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )

        #expect(wrongPetUndo.petID == otherPet.id)
        #expect(wrongPetUndo.didDelete == false)
        #expect(wrongPetUndo.removedLedgerEventIDs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).map(\.id) == [recorded.eventID])
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).map(\.id) == [hygieneLogID])
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.id) == [ledger.id])

        let correctUndo = CatCareCommandService.undo(
            pet: pet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )

        #expect(correctUndo.didDelete)
        #expect(correctUndo.removedLedgerEventIDs == [ledger.id])
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: recorded.eventID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetHygieneLog.self), id: hygieneLogID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: ledger.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func recordWithoutHygieneCreatesOnlyCatCareEvent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let executor = Human(name: "Executor")
        context.insert(executor)
        context.insert(pet)
        try context.save()

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Feed",
                emoji: "F",
                recordsHygiene: false,
                occurredAt: Date(timeIntervalSince1970: 1_780_000_300),
                executorId: executor.id.uuidString
            ),
            context: context
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(recorded.hygieneLogID == nil)
        #expect(events.map(\.id) == [recorded.eventID])
        #expect(events.first?.relatedEntityId == pet.id.uuidString)
        #expect(events.first?.eventType == EventType.litterBox.rawValue)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: recorded.eventID, context: context)?.hasPendingLocalChanges == true)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
    }

    @Test func recordWithHygieneWritesLedgerDirtyStateAndFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active caretaker")
        let deceasedExecutor = Human(name: "Former caretaker")
        deceasedExecutor.passedAwayDate = Date(timeIntervalSince1970: 100)
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(activeHuman)
        context.insert(deceasedExecutor)
        context.insert(pet)
        try context.save()
        let cleanup = isolateEconomy(activeHumanID: activeHuman.id.uuidString)
        defer { cleanup() }

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Scoop litter",
                emoji: "L",
                recordsHygiene: true,
                occurredAt: Date(timeIntervalSince1970: 1_780_000_000),
                executorId: deceasedExecutor.id.uuidString
            ),
            context: context
        )

        let hygieneLogID = try #require(recorded.hygieneLogID)
        let hygieneLog = try #require(try context.fetch(FetchDescriptor<PetHygieneLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "PetHygieneLog" && $0.legacyModelId == hygieneLogID.uuidString
        })

        #expect(recorded.didRecord)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(hygieneLog.id == hygieneLogID)
        #expect(hygieneLog.executorId == activeHuman.id.uuidString)
        #expect(hygieneLog.executorId != deceasedExecutor.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(ledger.eventKind == CareLedgerEventKind.hygiene.rawValue)
        #expect(ledger.actionType == HygieneType.bath.rawValue)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: recorded.eventID, context: context)?.hasPendingLocalChanges == true)
        #expect(try cloudSyncState(entityName: String(describing: PetHygieneLog.self), id: hygieneLogID, context: context)?.hasPendingLocalChanges == true)
        #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: ledger.id, context: context)?.hasPendingLocalChanges == true)
    }

    @Test func recordNoopsForDeceasedPetWithoutHistoricalFact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_780_000_100)
        context.insert(pet)
        try context.save()

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Scoop litter",
                emoji: "L",
                recordsHygiene: true,
                occurredAt: Date(timeIntervalSince1970: 1_780_000_000),
                executorId: nil
            ),
            context: context
        )

        #expect(recorded.didRecord == false)
        #expect(recorded.hygieneLogID == nil)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CloudSyncRecordState>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func cloudSyncState(entityName: String, id: UUID, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == entityName && $0.localRecordId == CloudSyncRecordState.normalizedRecordId(id)
        }
    }

    private func isolateEconomy(activeHumanID: String?) -> () -> Void {
        let defaults = UserDefaults.standard
        let oldActiveHuman = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldown = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        let oldBoost = defaults.object(forKey: "shop_boostDoubleActive")
        let oldEconomyValues = defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("economyV2.dailyBudget.") }

        EconomyDailyBudgetStore.resetAll()
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        if let activeHumanID {
            defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        } else {
            defaults.removeObject(forKey: "currentActiveHumanId")
        }

        return {
            EconomyDailyBudgetStore.resetAll()
            for (key, value) in oldEconomyValues {
                defaults.set(value, forKey: key)
            }
            if let oldActiveHuman {
                defaults.set(oldActiveHuman, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let oldCooldown {
                defaults.set(oldCooldown, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            if let oldBoost {
                defaults.set(oldBoost, forKey: "shop_boostDoubleActive")
            } else {
                defaults.removeObject(forKey: "shop_boostDoubleActive")
            }
        }
    }
}
