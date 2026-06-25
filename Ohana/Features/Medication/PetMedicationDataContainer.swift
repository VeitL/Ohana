import SwiftData
import SwiftUI

struct PetMedicationView: View {
    let pet: Pet
    var onDataChanged: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = PetMedicationRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        PetMedicationContentView(
            pet: pet,
            medications: routeData.medications,
            doseEvents: routeData.doseEvents,
            onDataChanged: {
                onDataChanged?()
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
        let petID = pet.id
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = PetMedicationRouteData.load(petID: petID, from: modelContext)
            dataLoadTask = nil
        }
    }
}
