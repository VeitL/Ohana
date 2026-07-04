//
//  AddPlantDataContainer.swift
//  Ohana
//
//  Route-scoped data container for the plant creation flow.
//

import SwiftData
import SwiftUI

struct AddPlantDataContainer: View {
    let onComplete: () -> Void
    var onPlantSaved: ((UUID) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var existingPlantSnapshots: [PlantDuplicateScanSnapshot] = []
    @State private var snapshotLoadTask: Task<Void, Never>?
    @State private var didLoadSnapshots = false

    var body: some View {
        AddPlantView(
            onComplete: onComplete,
            onPlantSaved: onPlantSaved,
            existingPlantSnapshots: existingPlantSnapshots
        )
        .onAppear {
            scheduleSnapshotLoad()
        }
        .onDisappear {
            snapshotLoadTask?.cancel()
            snapshotLoadTask = nil
        }
    }

    private func scheduleSnapshotLoad() {
        guard !didLoadSnapshots, snapshotLoadTask == nil else { return }
        let container = modelContext.container
        snapshotLoadTask = Task { @MainActor in
            defer { snapshotLoadTask = nil }
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 240)
            guard !Task.isCancelled else { return }
            let actor = AddPlantDuplicateSnapshotActor(modelContainer: container)
            do {
                let snapshots = try await actor.loadSnapshots()
                guard !Task.isCancelled else { return }
                existingPlantSnapshots = snapshots
                didLoadSnapshots = true
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Add plant duplicate snapshot actor load failed: \(error.localizedDescription)",
                    category: "Plants"
                )
            }
        }
    }
}

@ModelActor
private actor AddPlantDuplicateSnapshotActor {
    func loadSnapshots() throws -> [PlantDuplicateScanSnapshot] {
        try Task.checkCancellation()
        do {
            let descriptor = FetchDescriptor<Plant>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let plants = try modelContext.fetch(descriptor)
            try Task.checkCancellation()
            return plants.map {
                PlantDuplicateScanSnapshot(
                    id: $0.id,
                    name: $0.name,
                    species: $0.species,
                    roomName: $0.roomNameRaw,
                    location: $0.location,
                    catalogSpeciesId: $0.catalogSpeciesId
                )
            }
        } catch {
            OhanaLog.warning(
                "Add plant duplicate snapshot fetch failed: \(error.localizedDescription)",
                category: "Plants"
            )
            throw error
        }
    }
}
