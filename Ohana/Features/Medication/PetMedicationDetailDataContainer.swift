import SwiftData
import SwiftUI

struct PetMedicationDetailSheet: View {
    let pet: Pet
    let medication: PetMedication
    var onDataChanged: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var doseEvents: [Event] = []
    @State private var hasLoaded = false
    @State private var dataLoadTask: Task<Void, Never>?

    var body: some View {
        PetMedicationDetailContentSheet(
            pet: pet,
            medication: medication,
            doseEvents: doseEvents,
            onDataChanged: {
                onDataChanged?()
                scheduleDoseEventLoad(delayMilliseconds: 24, force: true)
            }
        )
        .onAppear {
            scheduleDoseEventLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleDoseEventLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleDoseEventLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        let medicationID = medication.id
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            doseEvents = PetMedicationRouteData.loadDoseEvents(medicationID: medicationID, from: modelContext)
            hasLoaded = true
            dataLoadTask = nil
        }
    }
}
