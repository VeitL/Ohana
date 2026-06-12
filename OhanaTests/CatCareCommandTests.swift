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
                executorId: "human-1"
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
        context.insert(pet)
        try context.save()

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Feed",
                emoji: "F",
                recordsHygiene: false,
                occurredAt: Date(timeIntervalSince1970: 1_780_000_300),
                executorId: "human-1"
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

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
