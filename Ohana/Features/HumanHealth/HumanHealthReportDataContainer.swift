import SwiftData
import SwiftUI

struct HumanHealthReportView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = HumanHealthReportRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        HumanHealthReportContentView(
            human: human,
            myReports: routeData.reports
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
        let humanID = human.id.uuidString
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = HumanHealthReportRouteData.load(humanID: humanID, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct HumanHealthReportRouteData {
    var reports: [HumanHealthReport] = []
    var hasLoaded = false

    static func load(humanID: String, from context: ModelContext) -> HumanHealthReportRouteData {
        let descriptor = FetchDescriptor<HumanHealthReport>(
            predicate: #Predicate<HumanHealthReport> { $0.humanId == humanID },
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        do {
            return HumanHealthReportRouteData(
                reports: try context.fetch(descriptor), // route-first-frame: allow deferred-fetch
                hasLoaded: true
            )
        } catch {
            OhanaLog.warning(
                "Human health report route data fetch failed: \(error.localizedDescription)",
                category: "HumanHealth"
            )
            return HumanHealthReportRouteData(hasLoaded: true)
        }
    }
}
