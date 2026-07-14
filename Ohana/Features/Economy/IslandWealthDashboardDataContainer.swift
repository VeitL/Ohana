//
//  IslandWealthDashboardDataContainer.swift
//  Ohana
//
//  Screen-level wallet query container for the wealth dashboard.
//

import SwiftData
import SwiftUI

enum IslandWealthDashboardPresentation: Equatable {
    case standalone
    case embedded
}

struct IslandWealthDashboardView: View {
    let presentation: IslandWealthDashboardPresentation

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = IslandWealthDashboardRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    init(presentation: IslandWealthDashboardPresentation = .standalone) {
        self.presentation = presentation
    }

    var body: some View {
        IslandWealthDashboardContentView(
            pets: routeData.pets,
            humans: routeData.humans,
            walletAccounts: routeData.walletAccounts,
            walletLedgerEntries: routeData.walletLedgerEntries,
            presentation: presentation
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
            routeData = IslandWealthDashboardRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct IslandWealthDashboardRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var walletAccounts: [CoconutAccount] = []
    var walletLedgerEntries: [CoconutLedgerEntry] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> IslandWealthDashboardRouteData {
        IslandWealthDashboardRouteData(
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]),
                context: context,
                name: "Pet"
            ),
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.name)]),
                context: context,
                name: "Human"
            ),
            walletAccounts: fetch(
                FetchDescriptor<CoconutAccount>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]),
                context: context,
                name: "CoconutAccount"
            ),
            walletLedgerEntries: fetch(
                FetchDescriptor<CoconutLedgerEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]),
                context: context,
                name: "CoconutLedgerEntry"
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
                "Wealth dashboard route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Economy"
            )
            return []
        }
    }
}
