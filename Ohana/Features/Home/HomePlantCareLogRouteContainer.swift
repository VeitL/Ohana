//
//  HomePlantCareLogRouteContainer.swift
//  Ohana
//
//  Route-scoped plant quick-log sheet for Home wallet quick actions.
//

import SwiftData
import SwiftUI

struct HomePlantCareLogRouteContainer: View {
    let id: UUID
    let initialCareType: PlantCareType
    let onMissing: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""

    init(
        id: UUID,
        initialCareType: PlantCareType,
        onMissing: @escaping () -> Void
    ) {
        self.id = id
        self.initialCareType = initialCareType
        self.onMissing = onMissing
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: HomePlantCareLogRouteData.loading,
            loadDelayMilliseconds: 48,
            shouldLoad: { !$0.hasLoaded },
            load: { Self.loadPlant(id: id, from: modelContext) }
        ) { data in
            if let plant = data.plant {
                PlantCareLogSheet(
                    plant: plant,
                    initialCareType: initialCareType,
                    currentHealthStatus: plant.healthStatus,
                    onSave: { type, careNote, healthStatus, photoData in
                        saveCareLog(
                            type,
                            plant: plant,
                            careNote: careNote,
                            healthStatus: healthStatus,
                            photoData: photoData
                        )
                    }
                )
            } else if data.hasLoaded {
                Color.clear
                    .accessibilityIdentifier("home-plant-care-log-missing")
                    .onAppear(perform: onMissing)
            } else {
                HomePlantCareLogLoadingView()
            }
        }
    }

    private static func loadPlant(id: UUID, from context: ModelContext) -> HomePlantCareLogRouteData {
        do {
            var descriptor = FetchDescriptor<Plant>(
                predicate: #Predicate<Plant> { plant in
                    plant.id == id
                }
            )
            descriptor.fetchLimit = 1
            let plant = try context.fetch(descriptor).first // route-first-frame: allow deferred-fetch
            return HomePlantCareLogRouteData(plant: plant, hasLoaded: true)
        } catch {
            OhanaLog.warning(
                "Home plant care log fetch failed: \(error.localizedDescription)",
                category: "Plants"
            )
            return HomePlantCareLogRouteData(plant: nil, hasLoaded: true)
        }
    }

    private func saveCareLog(
        _ type: PlantCareType,
        plant: Plant,
        careNote: String,
        healthStatus: PlantHealthStatus,
        photoData: Data?
    ) {
        HomeCommandExecutor(modelContext: modelContext, services: appServices).recordPlantCare(
            type,
            plant: plant,
            executorId: activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus
        )
    }
}

private struct HomePlantCareLogRouteData {
    let plant: Plant?
    let hasLoaded: Bool

    static let loading = HomePlantCareLogRouteData(plant: nil, hasLoaded: false)
}

private struct HomePlantCareLogLoadingView: View {
    private var l: L10n { .current }

    var body: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, minHeight: 180)
            .accessibilityLabel(l.tr(zh: "正在打开植物记录", en: "Opening plant log", de: "Pflanzeneintrag wird geöffnet"))
            .accessibilityIdentifier("home-plant-care-log-loading")
    }
}
