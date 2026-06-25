import SwiftData
import SwiftUI

struct IslandMedicationDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = IslandMedicationRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        IslandMedicationDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: routeData.pets,
            medicationsByPetID: routeData.medicationsByPetID,
            onMedicationDataChanged: {
                scheduleRouteDataLoad(delayMilliseconds: 24, force: true)
            }
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
            routeData = IslandMedicationRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}
