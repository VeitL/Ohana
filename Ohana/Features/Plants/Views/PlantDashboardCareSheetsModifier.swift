//
//  PlantDashboardCareSheetsModifier.swift
//  Ohana
//
//  Care-related sheet presentation kept outside the already dense dashboard.
//

import SwiftData
import SwiftUI

struct PlantDashboardCareSheetsModifier: ViewModifier {
    @Binding var showingBatchQuickRecordSheet: Bool
    @Binding var quickCareActorDraft: PlantQuickCareActorDraft?
    @Binding var careLogDraft: PlantDashboardCareLogDraft?
    @Binding var careAggregateDraft: PlantDashboardCareAggregateDraft?

    let plants: [Plant]
    let initialBatchCareType: PlantCareType?
    let imageDataProvider: @Sendable (PersistentIdentifier) async -> Data?
    let onRecordBatchCare: @MainActor ([PlantBatchCareSelection], UUID?) async -> Bool
    let onConfirmQuickCare: (PlantQuickCareActorDraft, UUID?) -> Void
    let onSaveCareLog: (Plant, PlantCareType, String, Data?, PlantHealthStatus, UUID?) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingBatchQuickRecordSheet) {
                PlantBatchQuickRecordSheet(
                    plants: plants,
                    initialCareType: initialBatchCareType,
                    imageDataProvider: imageDataProvider,
                    onRecord: onRecordBatchCare
                )
            }
            .sheet(item: $quickCareActorDraft) { draft in
                PlantQuickCareActorConfirmationSheet(draft: draft) { executorID in
                    onConfirmQuickCare(draft, executorID)
                }
            }
            .sheet(item: $careLogDraft) { draft in
                PlantCareLogSheet(
                    plant: draft.plant,
                    initialCareType: draft.careType,
                    currentHealthStatus: draft.plant.healthStatus
                ) { type, careNote, healthStatus, photoData, executorID in
                    onSaveCareLog(draft.plant, type, careNote, photoData, healthStatus, executorID)
                }
            }
            .sheet(item: $careAggregateDraft) { draft in
                PlantCareFeatureDetailView(
                    plants: plants,
                    feature: draft.feature,
                    focusedPlantID: nil,
                    focusedCareType: draft.focusedCareType
                )
            }
    }
}
