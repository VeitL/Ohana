//
//  PetMilestoneListRouteContainer.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct PetMilestoneListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    let pet: Pet

    init(pet: Pet) {
        self.pet = pet
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: PetMilestoneListRouteData(),
            refreshToken: appServices.domainRevisions.homeRevision,
            loadDelayMilliseconds: 48,
            reloadDelayMilliseconds: 96,
            shouldLoad: { !$0.hasLoaded },
            load: { PetMilestoneListRouteData.load(petID: pet.id, from: modelContext) }
        ) { data in
            PetMilestoneListContentView(
                pet: pet,
                routeMilestones: data.milestones
            )
        }
    }
}

private struct PetMilestoneListRouteData {
    var milestones: [PetMilestone] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> PetMilestoneListRouteData {
        PetMilestoneListRouteData(
            milestones: fetch(
                FetchDescriptor<PetMilestone>(
                    predicate: #Predicate<PetMilestone> { milestone in
                        milestone.pet?.id == petID
                    }
                ),
                context: context,
                name: "PetMilestone"
            ),
            hasLoaded: true
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Pet milestone route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Milestones"
            )
            return []
        }
    }
}
