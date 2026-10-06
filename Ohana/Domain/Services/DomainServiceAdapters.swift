import Foundation
import SwiftData

@MainActor
protocol WalkCareEventManaging {
    @discardableResult
    func recordSharedWalk(
        sourcePet: Pet,
        targets: [Pet],
        distanceMeters: Double,
        endDate: Date?,
        context: ModelContext,
        executorId: String?,
        executorIds: [String],
        startDate: Date
    ) -> SharedPetActionResult
}

@MainActor
protocol MedicationReminderManaging {
    func dosesTakenToday(for medicationId: UUID) -> Int
    func recordDose(for medicationId: UUID)
    func undoDose(for medicationId: UUID)
    func scheduleMedicationReminders(for pet: Pet, context: ModelContext?)
    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication], context: ModelContext?)
    func invalidateNotificationMutations()
    func refreshScheduledMedicationReminders(
        context: ModelContext,
        hidingDetails: Bool
    ) async -> MedicationNotificationPrivacyRefreshResult
    func recoverMedicationNotificationPrivacyIfNeeded(
        context: ModelContext
    ) async -> MedicationNotificationPrivacyRefreshResult
    func reconcileHumanMedicationRollingWindow(
        context: ModelContext,
        budget: OhanaBackgroundWorkBudget,
        now: Date
    ) async -> HumanMedicationReminderRollingRefreshResult
}

extension MedicationReminderManaging {
    func invalidateNotificationMutations() {}

    func recoverMedicationNotificationPrivacyIfNeeded(
        context: ModelContext
    ) async -> MedicationNotificationPrivacyRefreshResult {
        await refreshScheduledMedicationReminders(
            context: context,
            hidingDetails: MedicationNotificationPrivacyStore.hidesMedicationDetails()
        )
    }

    func reconcileHumanMedicationRollingWindow(
        context _: ModelContext,
        budget _: OhanaBackgroundWorkBudget,
        now _: Date
    ) async -> HumanMedicationReminderRollingRefreshResult {
        .deferred
    }
}

@MainActor
protocol ReminderSchedulingManaging {
    @discardableResult
    func scheduleIfNeeded(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource,
        existingNotificationIds: Set<String>?,
        operation: String,
        saveLedger: Bool
    ) async -> ReminderNotificationScheduleResult

    func scheduleManyIfNeeded(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource
    ) async

    func cancelAndReschedule(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource
    ) async

    func refillMissingPendingNotifications(
        reminders: [Reminder],
        context: ModelContext
    ) async

    func compensate(reminders: [Reminder], context: ModelContext)
}
