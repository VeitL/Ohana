//
//  PetInsuranceRouteContainer.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct PetInsuranceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    let pet: Pet
    var embedded: Bool = false

    init(pet: Pet, embedded: Bool = false) {
        self.pet = pet
        self.embedded = embedded
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: PetInsuranceRouteData(),
            refreshToken: appServices.domainRevisions.homeRevision,
            loadDelayMilliseconds: 48,
            reloadDelayMilliseconds: 96,
            shouldLoad: { !$0.hasLoaded },
            load: { PetInsuranceRouteData.load(petID: pet.id, from: modelContext) }
        ) { data in
            PetInsuranceContentView(
                pet: pet,
                embedded: embedded,
                routeInsurances: data.insurances
            )
        }
    }
}

private struct PetInsuranceRouteData {
    var insurances: [PetInsurance] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> PetInsuranceRouteData {
        PetInsuranceRouteData(
            insurances: fetch(
                FetchDescriptor<PetInsurance>(
                    predicate: #Predicate<PetInsurance> { insurance in
                        insurance.pet?.id == petID
                    }
                ),
                context: context,
                name: "PetInsurance"
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
                "Pet insurance route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Insurance"
            )
            return []
        }
    }
}
