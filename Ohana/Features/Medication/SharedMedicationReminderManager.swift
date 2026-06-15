import Foundation
import SwiftData

@MainActor
final class SharedMedicationReminderManager: MedicationReminderManaging {
    private let service: MedicationReminderService

    init(careLedger: CareLedgerRecording = CareLedgerService()) {
        service = MedicationReminderService(careLedger: careLedger)
    }

    func dosesTakenToday(for medicationId: UUID) -> Int {
        MedicationReminderService.dosesTakenToday(for: medicationId)
    }

    func recordDose(for medicationId: UUID) {
        MedicationReminderService.recordDose(for: medicationId)
    }

    func undoDose(for medicationId: UUID) {
        MedicationReminderService.undoDose(for: medicationId)
    }

    func scheduleMedicationReminders(for pet: Pet, context: ModelContext?) {
        service.scheduleMedicationReminders(for: pet, context: context)
    }

    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication], context: ModelContext?) {
        service.scheduleHumanMedicationReminders(for: human, meds: meds, context: context)
    }
}
