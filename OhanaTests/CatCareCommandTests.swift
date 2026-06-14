import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
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

        let wrongPetUndo = CatCareCommandService.undo(
            pet: otherPet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )

        #expect(wrongPetUndo.petID == otherPet.id)
        #expect(try context.fetch(FetchDescriptor<Event>()).map(\.id) == [recorded.eventID])
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).map(\.id) == [hygieneLogID])

        _ = CatCareCommandService.undo(
            pet: pet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
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
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
    }

    @Test func recordNoopsForDeceasedExecutorBeforeEventAndHygieneFact() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let executor = Human(name: "Former caretaker")
        executor.passedAwayDate = Date(timeIntervalSince1970: 100)
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(executor)
        context.insert(pet)
        try context.save()

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

        #expect(recorded.didRecord == false)
        #expect(recorded.hygieneLogID == nil)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
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
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
