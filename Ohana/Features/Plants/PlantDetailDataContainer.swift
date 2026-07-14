import SwiftData
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant
    let initialFeatureDestination: PlantFeatureDestination?
    let onCreateCareTask: ((TaskCreationPreset) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    init(
        plant: Plant,
        initialFeatureDestination: PlantFeatureDestination? = nil,
        onCreateCareTask: ((TaskCreationPreset) -> Void)? = nil
    ) {
        self.plant = plant
        self.initialFeatureDestination = initialFeatureDestination
        self.onCreateCareTask = onCreateCareTask
    }

    var body: some View {
        PlantDetailContentView(
            plant: plant,
            households: households,
            initialFeatureDestination: initialFeatureDestination,
            onCreateCareTask: onCreateCareTask,
            batchQuickRecordTargetLoader: loadBatchQuickRecordTargets
        )
    }

    private func loadBatchQuickRecordTargets() async throws -> [PlantBatchQuickRecordTargetSnapshot] {
        let actor = PlantDetailBatchQuickRecordTargetActor(modelContainer: modelContext.container)
        return try await actor.loadTargets(limit: 256)
    }
}

@ModelActor
private actor PlantDetailBatchQuickRecordTargetActor {
    func loadTargets(limit: Int) throws -> [PlantBatchQuickRecordTargetSnapshot] {
        try Task.checkCancellation()
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { !$0.isArchived },
            sortBy: [SortDescriptor(\Plant.name)]
        )
        descriptor.fetchLimit = limit
        let plants = try modelContext.fetch(descriptor)
        try Task.checkCancellation()
        return plants.map {
            PlantBatchQuickRecordTargetSnapshot(
                id: $0.id,
                plantModelID: $0.persistentModelID,
                name: $0.name,
                roomName: $0.roomName,
                avatarSignature: $0.avatarThumbnailSignature,
                tintHex: $0.themeColorHex
            )
        }
    }
}
