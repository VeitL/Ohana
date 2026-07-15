//
//  PetMedicationActionHumanConfirmationSheetDataContainer.swift
//  Ohana
//
//  Bounded Human snapshots for medication attribution confirmation.
//

import SwiftData
import SwiftUI

struct PetMedicationActionHumanConfirmationSheetDataContainer: View {
    let draft: PetMedicationDoseActorDraft
    let onConfirm: (UUID?) -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: PetMedicationActionHumanRouteData(),
            loadDelayMilliseconds: 24,
            shouldLoad: { !$0.hasLoaded },
            load: {
                PetMedicationActionHumanRouteData(
                    humans: ActionHumanOptionLoader.load(context: modelContext),
                    hasLoaded: true
                )
            }
        ) { data in
            if data.hasLoaded {
                PetMedicationActionHumanConfirmationSheet(
                    draft: draft,
                    actionHumans: data.humans,
                    onConfirm: onConfirm
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
}

private struct PetMedicationActionHumanRouteData {
    var humans: [ActionHumanOption] = []
    var hasLoaded = false
}
