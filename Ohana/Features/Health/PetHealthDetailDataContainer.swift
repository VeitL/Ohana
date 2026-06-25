import SwiftData
import SwiftUI

struct PetHealthDetailView: View {
    let pet: Pet
    var isModal: Bool = false
    var initialSection: PetHealthInitialSection?
    var onFullDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var medicationRouteData = PetMedicationRouteData()
    @State private var healthRouteData = PetHealthRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        PetHealthDetailContentView(
            pet: pet,
            healthLogs: healthRouteData.healthLogs,
            symptomLogs: healthRouteData.symptomLogs,
            heatCycleLogs: healthRouteData.heatCycleLogs,
            healthAlertSource: healthRouteData.alertSource,
            medications: medicationRouteData.medications,
            medicationDoseEvents: medicationRouteData.doseEvents,
            isModal: isModal,
            initialSection: initialSection,
            onFullDismiss: onFullDismiss,
            onHealthDataChanged: {
                scheduleRouteDataLoad(delayMilliseconds: 24, force: true)
            },
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
        guard force || !medicationRouteData.hasLoaded || !healthRouteData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        let petID = pet.id
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            healthRouteData = PetHealthRouteData.load(petID: petID, from: modelContext)
            medicationRouteData = PetMedicationRouteData.load(petID: petID, from: modelContext)
            dataLoadTask = nil
        }
    }
}
