import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanMedicationDosePresentationTests {
    @Test func persistedTakenDoseClearsPendingAndRequestsTakenNotification() {
        let itemID = "scheduled-dose"
        let humanID = UUID()
        let medicationID = UUID()
        var state = HumanMedicationPresentationState()
        state.begin(itemID: itemID, status: .taken)

        let completion = state.complete(
            itemID: itemID,
            result: HumanMedicationDoseCommandResult(
                subjectID: humanID,
                medicationID: medicationID,
                logID: UUID(),
                status: .taken,
                didChange: true,
                recordedLedgerEvent: true,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        )

        #expect(state.pendingStatus(for: itemID) == nil)
        #expect(state.effectiveStatus(for: itemID, persistedStatus: .taken) == .taken)
        #expect(completion == .persisted(shouldNotifyDoseTaken: true))
    }

    @Test func failedDoseClearsPendingAndRestoresPersistedStatus() {
        let itemID = "failed-dose"
        var state = HumanMedicationPresentationState()
        state.begin(itemID: itemID, status: .taken)
        #expect(state.effectiveStatus(for: itemID, persistedStatus: .pending) == .taken)

        let completion = state.complete(
            itemID: itemID,
            result: HumanMedicationDoseCommandResult(
                subjectID: UUID(),
                medicationID: UUID(),
                logID: nil,
                status: .taken,
                didChange: false,
                recordedLedgerEvent: false,
                didPersist: false,
                persistenceErrorDescription: "Injected save failure"
            )
        )

        #expect(state.pendingStatus(for: itemID) == nil)
        #expect(state.effectiveStatus(for: itemID, persistedStatus: .pending) == .pending)
        #expect(completion == .failed)
    }

    @Test func memorialDoseRejectionCannotProducePersistedPresentation() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let scheduledTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let human = Human(name: "Memory")
        human.passedAwayDate = scheduledTime.addingTimeInterval(-86400)
        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: "Medication",
            frequency: .daily,
            startDate: scheduledTime
        )
        context.insert(human)
        context.insert(medication)
        try context.save()

        let itemID = "memorial-dose"
        var state = HumanMedicationPresentationState()
        state.begin(itemID: itemID, status: .taken)
        let result = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: medication.id,
            scheduledTime: scheduledTime,
            status: .taken,
            context: context,
            now: scheduledTime
        )
        let completion = state.complete(itemID: itemID, result: result)

        #expect(!result.didPersist)
        #expect(!result.didChange)
        #expect(state.pendingStatus(for: itemID) == nil)
        #expect(completion == .failed)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
    }

    @Test func failedPlanActivationClearsPendingAndRestoresPersistedState() {
        let medicationID = UUID()
        var state = HumanMedicationPresentationState()
        state.beginPlanActivation(medicationID: medicationID, isActive: false)
        #expect(!state.effectivePlanActive(medicationID: medicationID, persistedIsActive: true))

        let completion = state.completePlanActivation(
            medicationID: medicationID,
            result: HumanMedicationPlanActivationCommandResult(
                subjectID: UUID(),
                medicationID: medicationID,
                isActive: true,
                didChange: false,
                calendarEventIDs: [],
                removedCalendarEventIDs: [],
                scheduledReminderSync: false,
                didPersist: false,
                persistenceErrorDescription: "Injected save failure"
            )
        )

        #expect(!state.isPlanActivationPending(medicationID: medicationID))
        #expect(state.effectivePlanActive(medicationID: medicationID, persistedIsActive: true))
        #expect(completion == .failed)
    }

    @Test func persistedPlanActivationClearsPendingAndProducesSuccessPresentation() {
        let medicationID = UUID()
        var state = HumanMedicationPresentationState()
        state.beginPlanActivation(medicationID: medicationID, isActive: false)

        let completion = state.completePlanActivation(
            medicationID: medicationID,
            result: HumanMedicationPlanActivationCommandResult(
                subjectID: UUID(),
                medicationID: medicationID,
                isActive: false,
                didChange: true,
                calendarEventIDs: [],
                removedCalendarEventIDs: [],
                scheduledReminderSync: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        )

        #expect(!state.isPlanActivationPending(medicationID: medicationID))
        #expect(completion == .persisted(isActive: false))
    }

    @Test func memorialPlanActivationRejectionCannotProducePersistedPresentation() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let human = Human(name: "Memory")
        human.passedAwayDate = Date().addingTimeInterval(-86400)
        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: "Medication",
            frequency: .daily,
            startDate: Date().addingTimeInterval(-604_800)
        )
        context.insert(human)
        context.insert(medication)
        try context.save()

        var state = HumanMedicationPresentationState()
        state.beginPlanActivation(medicationID: medication.id, isActive: false)
        let result = HumanMedicationPlanCommandService.setPlanActive(
            human: human,
            medication: medication,
            isActive: false,
            appLanguage: "en",
            context: context,
            scheduleReminders: false
        )
        let completion = state.completePlanActivation(
            medicationID: medication.id,
            result: result
        )

        #expect(!result.didPersist)
        #expect(!result.didChange)
        #expect(medication.isActive)
        #expect(!state.isPlanActivationPending(medicationID: medication.id))
        #expect(completion == .failed)
    }
}
