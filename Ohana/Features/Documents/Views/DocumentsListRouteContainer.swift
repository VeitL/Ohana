//
//  DocumentsListRouteContainer.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct DocumentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    let pet: Pet
    var showsCloseButton: Bool = true

    init(pet: Pet, showsCloseButton: Bool = true) {
        self.pet = pet
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: DocumentsListRouteData(),
            refreshToken: appServices.domainRevisions.homeRevision,
            loadDelayMilliseconds: 48,
            reloadDelayMilliseconds: 96,
            shouldLoad: { !$0.hasLoaded },
            load: { DocumentsListRouteData.load(petID: pet.id, from: modelContext) }
        ) { data in
            DocumentsListContentView(
                pet: pet,
                showsCloseButton: showsCloseButton,
                routeDocuments: data.documents,
                routeInsurances: data.insurances
            )
        }
    }
}

private struct DocumentsListRouteData {
    var documents: [PetDocument] = []
    var insurances: [PetInsurance] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> DocumentsListRouteData {
        DocumentsListRouteData(
            documents: fetch(
                FetchDescriptor<PetDocument>(
                    predicate: #Predicate<PetDocument> { document in
                        document.pet?.id == petID
                    }
                ),
                context: context,
                name: "PetDocument"
            ),
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
                "Documents route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Documents"
            )
            return []
        }
    }
}
