//
//  FamilyWeeklyReportDataContainer.swift
//  Ohana
//
//  Screen-level query container for the weekly family report.
//

import SwiftData
import SwiftUI

struct FamilyWeeklyReportDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var routeData = FamilyWeeklyReportRouteSnapshot.empty
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        FamilyWeeklyReportDashboardContentView(
            snapshot: routeData
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onChange(of: appLanguage) { _, _ in
            scheduleRouteDataLoad(force: true)
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
        let container = modelContext.container
        let languageCode = appLanguage
        let now = Date()
        dataLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                dataLoadTask = nil
                return
            }
            let actor = FamilyWeeklyReportRouteDataActor(modelContainer: container)
            do {
                routeData = try await actor.load(languageCode: languageCode, now: now)
            } catch is CancellationError {
                // Route disappeared or a newer load superseded this one.
            } catch {
                OhanaLog.warning(
                    "Family weekly report route snapshot load failed: \(error.localizedDescription)",
                    category: "FamilyReports"
                )
            }
            dataLoadTask = nil
        }
    }
}
