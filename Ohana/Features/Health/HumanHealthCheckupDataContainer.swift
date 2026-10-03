//
//  HumanHealthCheckupDataContainer.swift
//  Ohana
//
//  Deferred, bounded route data for the Human checkup metric catalog.
//

import Combine
import SwiftData
import SwiftUI

struct HumanHealthCheckupDataContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    let human: Human
    @State private var routeRevision = HomeRevision()

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: HumanHealthCheckupRouteData(),
            refreshToken: routeRevision,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 24,
            shouldLoad: { !$0.hasLoaded },
            load: {
                HumanHealthCheckupRouteData.load(
                    humanID: human.id,
                    context: modelContext
                )
            }
        ) { routeData in
            HumanHealthCheckupContentView(
                human: human,
                metricLogs: routeData.metricLogs
            )
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates.dropFirst()) { revision in
            guard routeRevision != revision else { return }
            routeRevision = revision
        }
    }
}

@MainActor
struct HumanHealthCheckupRouteData {
    var metricLogs: [HumanHealthMetricLog] = []
    var hasLoaded = false

    static func load(
        humanID: UUID,
        context: ModelContext
    ) -> HumanHealthCheckupRouteData {
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { log in
                log.human?.id == humanID
            },
            sortBy: [
                SortDescriptor(\HumanHealthMetricLog.date, order: .reverse),
                SortDescriptor(\HumanHealthMetricLog.createdAt, order: .reverse),
                SortDescriptor(\HumanHealthMetricLog.id, order: .reverse)
            ]
        )
        descriptor.fetchLimit = HumanHealthMetricReadPolicy.checkupProbeLimit

        do {
            return HumanHealthCheckupRouteData(
                metricLogs: try context.fetch(descriptor), // route-first-frame: allow deferred-fetch
                hasLoaded: true
            )
        } catch {
            OhanaLog.warning(
                "Human health checkup metric query failed.",
                category: "Health"
            )
            return HumanHealthCheckupRouteData(hasLoaded: true)
        }
    }
}
