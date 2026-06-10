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

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV59.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
