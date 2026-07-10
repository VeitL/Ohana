import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct CareLedgerBackfillActorTests {
    @Test func backfillCreatesLedgerEventAndIsIdempotent() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let log = PetCareLog(type: .feeding, amountGrams: 42, pet: pet, executorId: "human-1")
        context.insert(pet)
        context.insert(log)
        try context.save()

        // Runs on a dedicated background SwiftData context, separate from the
        // main context above.
        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()

        let firstPass = try ModelContext(container)
            .fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.legacyModelName == "PetCareLog" }
        #expect(firstPass.count == 1)
        #expect(firstPass.first?.legacyModelId == log.id.uuidString)

        // Running again must not duplicate the ledger event (idempotent backfill).
        try await actor.run()
        let secondPass = try ModelContext(container)
            .fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.legacyModelName == "PetCareLog" }
        #expect(secondPass.count == 1)
    }

    @Test func backfillResumesAfterPartialLedgerWriteWithoutDuplicatingExistingKeys() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let existingLog = PetCareLog(
            date: Date(timeIntervalSince1970: 100),
            type: .feeding,
            amountGrams: 24,
            pet: pet,
            executorId: "human-1"
        )
        let missingLog = PetCareLog(
            date: Date(timeIntervalSince1970: 200),
            type: .watering,
            amountMl: 180,
            note: "recovered water",
            pet: pet,
            executorId: "human-2"
        )
        context.insert(pet)
        context.insert(existingLog)
        context.insert(missingLog)
        CareLedgerService.record(
            occurredAt: existingLog.date,
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: existingLog.careType.rawValue,
            amountValue: existingLog.amountGrams,
            amountUnit: "g",
            source: .backfill,
            legacyModelName: "PetCareLog",
            legacyModelId: existingLog.id.uuidString,
            context: context,
            save: false
        )
        let unrelatedSameModelLedger = CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 300),
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .backfill,
            legacyModelName: "PetCareLog",
            legacyModelId: "unrelated-care-log"
        )
        let sameIDDifferentModelLedger = CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 400),
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: "supplies",
            source: .backfill,
            legacyModelName: "PetExpenseLog",
            legacyModelId: missingLog.id.uuidString
        )
        context.insert(unrelatedSameModelLedger)
        context.insert(sameIDDifferentModelLedger)
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()

        let ledger = try fetchLedgerEvents(in: container, legacyModelName: "PetCareLog")
        let existingEvents = ledger.filter { $0.legacyModelId == existingLog.id.uuidString }
        let recovered = try #require(ledger.first { $0.legacyModelId == missingLog.id.uuidString })
        let allLedger = try ModelContext(container).fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 3)
        #expect(existingEvents.count == 1)
        #expect(ledger.contains { $0.id == unrelatedSameModelLedger.id })
        #expect(allLedger.contains { $0.id == sameIDDifferentModelLedger.id })
        #expect(recovered.eventKind == CareLedgerEventKind.care.rawValue)
        #expect(recovered.actionType == CareType.watering.rawValue)
        #expect(recovered.amountValue == 180)
        #expect(recovered.amountUnit == "ml")
        #expect(recovered.note == "recovered water")
    }

    @Test func backfillKeepsOrphanLegacyPetLogsWithNilSubjectId() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let orphan = PetCareLog(
            date: Date(timeIntervalSince1970: 300),
            type: .watering,
            amountMl: 250,
            note: "orphan water",
            pet: nil,
            executorId: "human-orphan"
        )
        context.insert(orphan)
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()

        let ledger = try fetchLedgerEvents(in: container, legacyModelName: "PetCareLog")
        let event = try #require(ledger.first { $0.legacyModelId == orphan.id.uuidString })
        #expect(ledger.count == 1)
        #expect(event.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(event.actorId == "human-orphan")
        #expect(event.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(event.subjectId == nil)
        #expect(event.eventKind == CareLedgerEventKind.care.rawValue)
        #expect(event.actionType == CareType.watering.rawValue)
        #expect(event.amountValue == 250)
        #expect(event.amountUnit == "ml")
        #expect(event.note == "orphan water")
    }

    @Test func backfillCreatesPetWeightLedgerEventsInKilograms() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let log = PetWeightLog(
            date: Date(timeIntervalSince1970: 500),
            weight: 4800,
            weightUnit: "g",
            bcsScore: 5,
            pet: pet,
            executorId: "human-weight"
        )
        context.insert(pet)
        context.insert(log)
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()
        try await actor.run()

        let ledger = try fetchLedgerEvents(in: container, legacyModelName: "PetWeightLog")
        let event = try #require(ledger.first { $0.legacyModelId == log.id.uuidString })
        #expect(ledger.count == 1)
        #expect(event.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(event.actorId == "human-weight")
        #expect(event.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(event.subjectId == pet.id.uuidString)
        #expect(event.eventKind == CareLedgerEventKind.weight.rawValue)
        #expect(event.actionType == "petWeight")
        #expect(event.amountValue == 4.8)
        #expect(event.amountUnit == "kg")
    }

    @Test func backfillCreatesPetHygieneLedgerEvents() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let log = PetHygieneLog(
            date: Date(timeIntervalSince1970: 700),
            type: .brushing,
            pet: pet,
            executorId: "human-hygiene"
        )
        context.insert(pet)
        context.insert(log)
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()
        try await actor.run()

        let ledger = try fetchLedgerEvents(in: container, legacyModelName: "PetHygieneLog")
        let event = try #require(ledger.first { $0.legacyModelId == log.id.uuidString })
        #expect(ledger.count == 1)
        #expect(event.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(event.actorId == "human-hygiene")
        #expect(event.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(event.subjectId == pet.id.uuidString)
        #expect(event.eventKind == CareLedgerEventKind.hygiene.rawValue)
        #expect(event.actionType == HygieneType.brushing.rawValue)
    }

    @Test func backfillSkipsWalkRecoveryCheckpoints() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Piper", species: "狗")
        let authoritativeWalk = PetWalkLog(
            startDate: Date(timeIntervalSince1970: 900),
            pet: pet,
            executorId: "human-walk"
        )
        authoritativeWalk.distanceMeters = 800
        let checkpoint = PetWalkLog(
            startDate: Date(timeIntervalSince1970: 950),
            pet: pet,
            executorId: "human-walk",
            sharedSessionId: WalkRecoveryCheckpoint.makeSharedSessionID()
        )
        checkpoint.distanceMeters = 400
        context.insert(pet)
        context.insert(authoritativeWalk)
        context.insert(checkpoint)
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()

        let ledger = try fetchLedgerEvents(in: container, legacyModelName: "PetWalkLog")
        #expect(ledger.count == 1)
        #expect(ledger.first?.legacyModelId == authoritativeWalk.id.uuidString)
        #expect(!ledger.contains { $0.legacyModelId == checkpoint.id.uuidString })
    }

    @Test func backfillProcessesPetCareLogsAcrossSourceBatches() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let count = CareLedgerBackfillService.sourceFetchBatchSize + 3
        var logs: [PetCareLog] = []
        context.insert(pet)
        for index in 0 ..< count {
            let log = PetCareLog(
                date: Date(timeIntervalSince1970: Double(index)),
                type: .feeding,
                amountGrams: Double(index + 1),
                pet: pet,
                executorId: "human-\(index % 3)"
            )
            logs.append(log)
            context.insert(log)
        }
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        try await actor.run()

        let ledger = try fetchLedgerEvents(in: container, legacyModelName: "PetCareLog")
        let ledgerIds = Set(ledger.compactMap(\.legacyModelId))
        #expect(ledger.count == count)
        #expect(logs.allSatisfy { ledgerIds.contains($0.id.uuidString) })
        #expect(ledger.contains { $0.amountValue == 1 && $0.actorId == "human-0" })
        #expect(ledger.contains { $0.amountValue == Double(count) && $0.actorId == "human-\((count - 1) % 3)" })
    }

    @Test func backfillBatchPersistsCursorBeforeMarkingMigrationComplete() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        for index in 0 ..< 3 {
            context.insert(
                PetCareLog(
                    date: Date(timeIntervalSince1970: Double(index)),
                    type: .feeding,
                    amountGrams: Double(index + 1),
                    pet: pet,
                    executorId: "human-\(index)"
                )
            )
        }
        try context.save()

        let actor = CareLedgerBackfillActor(modelContainer: container)
        let first = try await actor.runBatch(
            cursor: .initial,
            maximumSourceRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(!first.didComplete)
        #expect(first.processedSourceRecordCount == 2)
        #expect(first.nextCursor.sourceIndex == 0)
        #expect(first.nextCursor.sourceOffset == 2)

        let second = try await actor.runBatch(
            cursor: first.nextCursor,
            maximumSourceRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(second.didComplete)
        #expect(try fetchLedgerEvents(in: container, legacyModelName: "PetCareLog").count == 3)
    }

    private func fetchLedgerEvents(in container: ModelContainer, legacyModelName: String) throws -> [CareLedgerEvent] {
        try ModelContext(container)
            .fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.legacyModelName == legacyModelName }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV67.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
