//
//  ExpandedHumanFeaturesDataContainer.swift
//  Ohana
//
//  Screen-level human feature sheet query container.
//

import SwiftData
import SwiftUI

struct ExpandedHumanFeaturesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = ExpandedHumanFeaturesRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let human: Human

    var body: some View {
        ExpandedHumanFeaturesContentSheet(
            human: human,
            allPets: routeData.allPets,
            allHumans: routeData.allHumans,
            allPendingReminders: routeData.allPendingReminders,
            allMeds: routeData.allMeds,
            allReports: routeData.allReports
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = ExpandedHumanFeaturesRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct ExpandedHumanFeaturesRouteData {
    var allPets: [Pet] = []
    var allHumans: [Human] = []
    var allPendingReminders: [Reminder] = []
    var allMeds: [HumanMedication] = []
    var allReports: [HumanHealthReport] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> ExpandedHumanFeaturesRouteData {
        ExpandedHumanFeaturesRouteData(
            allPets: fetch(
                FetchDescriptor<Pet>(),
                context: context,
                name: "Pet"
            ),
            allHumans: fetch(
                FetchDescriptor<Human>(),
                context: context,
                name: "Human"
            ),
            allPendingReminders: fetch(
                FetchDescriptor<Reminder>(
                    predicate: #Predicate<Reminder> { $0.status == "pending" },
                    sortBy: [SortDescriptor(\.scheduledAt)]
                ),
                context: context,
                name: "Reminder"
            ),
            allMeds: fetch(
                FetchDescriptor<HumanMedication>(),
                context: context,
                name: "HumanMedication"
            ),
            allReports: fetch(
                FetchDescriptor<HumanHealthReport>(),
                context: context,
                name: "HumanHealthReport"
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
                "Expanded human features route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }
}
