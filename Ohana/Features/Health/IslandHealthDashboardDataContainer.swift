import SwiftData
import SwiftUI

struct IslandHealthDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = IslandHealthRouteData()
    @State private var routeDataLoadTask: Task<Void, Never>?

    var body: some View {
        IslandHealthDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: routeData.pets,
            healthLogsByPetID: routeData.healthLogsByPetID
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            routeDataLoadTask?.cancel()
            routeDataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard routeDataLoadTask == nil else { return }
        routeDataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = IslandHealthRouteData.load(from: modelContext)
            routeDataLoadTask = nil
        }
    }
}
