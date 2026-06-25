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
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: [PlantDuplicateScanSnapshot](),
            loadDelayMilliseconds: 48,
            shouldLoad: { $0.isEmpty },
            load: { Self.loadSnapshots(from: modelContext) }
        ) { snapshots in
            AddPlantView(
                onComplete: onComplete,
                existingPlantSnapshots: snapshots
            )
        }
    }

    private static func loadSnapshots(from context: ModelContext) -> [PlantDuplicateScanSnapshot] {
        do {
            let descriptor = FetchDescriptor<Plant>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let plants = try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
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
            return []
        }
    }
}
