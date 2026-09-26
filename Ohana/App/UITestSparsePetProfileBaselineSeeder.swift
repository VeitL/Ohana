//
//  UITestSparsePetProfileBaselineSeeder.swift
//  Ohana
//
//  DEBUG-only sparse existing-user fixture for Pet profile journey UI tests.
//

import Foundation
import SwiftData

#if DEBUG
@MainActor
enum UITestSparsePetProfileBaselineSeeder {
    private static let petName = "Codex Sparse Pet Profile"

    static func seedIfRequested(modelContainer: ModelContainer, services: AppServices) {
        guard OhanaUITestLaunchOptions.requestsSparsePetProfileBaseline else { return }
        let context = modelContainer.mainContext

        do {
            let fixtureName = petName
            var fixtureDescriptor = FetchDescriptor<Pet>(
                predicate: #Predicate<Pet> { pet in
                    pet.name == fixtureName
                }
            )
            fixtureDescriptor.fetchLimit = 1
            guard try context.fetch(fixtureDescriptor).isEmpty else { return }

            // This fixture models an older, imported, or intentionally sparse
            // existing profile. The normal creation flow requires a binary sex
            // choice and may apply a free avatar, which would pre-complete the
            // body and appearance questions this fixture exists to exercise.
            guard try context.fetch(FetchDescriptor<Pet>()).isEmpty else {
                OhanaLog.warning(
                    "Sparse Pet profile UI-test baseline requires an empty Pet store.",
                    category: "Startup"
                )
                return
            }

            let pet = Pet(name: petName, species: "dog")
            context.insert(pet)
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return
            }
            services.domainRevisions.publishMemberCreation(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                note: "startup.pet.uiTestSparseProfileBaseline"
            )
        } catch {
            context.rollback()
            OhanaLog.warning(
                "Sparse Pet profile UI-test baseline failed: \(error.localizedDescription)",
                category: "Startup"
            )
        }
    }
}
#endif
