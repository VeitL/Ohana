import Foundation
import SwiftData
import Testing
@testable import Ohana

struct HomeCommandExecutorTests {
    @MainActor
    @Test func quickCareByIdWritesOneWaterFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let executor = HomeCommandExecutor(modelContext: context)
        var feedbacks: [ExpandedQuickActionExecutor.Feedback] = []
        var openedWaterRoute = false

        executor.performActionType(
            "water",
            petID: pet.id,
            executorId: "human-1",
            now: Date(timeIntervalSince1970: 1_800_000_000),
            antiRepeatTitle: "Already logged",
            antiRepeatMessage: { "\($0.executorName) \($0.minutesAgo)" },
            openFeedDetail: { _, _ in },
            showAntiRepeat: { _, _, pendingAction in pendingAction() },
            startWalk: { _ in },
            openWaterManagement: { _ in openedWaterRoute = true },
            openMedication: { _ in },
            feedback: { feedbacks.append($0) }
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
        #expect(logs.first?.careType == .watering)
        #expect(feedbacks.map(\.cardId) == [pet.id])
        #expect(openedWaterRoute == false)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV56.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
