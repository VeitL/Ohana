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
final class StaticWalkCareEventManager: WalkCareEventManaging {
    private let dependencies: CareEventServiceDependencies?

    init(dependencies: CareEventServiceDependencies? = nil) {
        self.dependencies = dependencies
    }

    func recordSharedWalk(
        sourcePet: Pet,
        targets: [Pet],
        distanceMeters: Double,
        endDate: Date?,
        context: ModelContext,
        executorId: String?,
        executorIds: [String],
        startDate: Date
    ) -> SharedPetActionResult {
        CareEventService.recordSharedWalk(
            sourcePet: sourcePet,
            targets: targets,
            distanceMeters: distanceMeters,
            endDate: endDate,
            context: context,
            executorId: executorId,
            executorIds: executorIds,
            startDate: startDate,
            dependencies: dependencies
        )
    }
}

@MainActor
protocol MedicationReminderManaging {
    func dosesTakenToday(for medicationId: UUID) -> Int
    func recordDose(for medicationId: UUID)
    func undoDose(for medicationId: UUID)
    func scheduleMedicationReminders(for pet: Pet, context: ModelContext?)
    func scheduleHumanMedicationReminders(for human: Human, meds: [HumanMedication], context: ModelContext?)
}

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

@MainActor
final class ReminderSchedulingManager: ReminderSchedulingManaging {
    private let careLedger: CareLedgerRecording

    init(careLedger: CareLedgerRecording = CareLedgerService()) {
        self.careLedger = careLedger
    }

    @discardableResult
    func scheduleIfNeeded(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource = .service,
        existingNotificationIds: Set<String>? = nil,
        operation: String = "schedule",
        saveLedger: Bool = true
    ) async -> ReminderNotificationScheduleResult {
        await ReminderSchedulingService.scheduleIfNeeded(
            reminder: reminder,
            context: context,
            source: source,
            existingNotificationIds: existingNotificationIds,
            operation: operation,
            saveLedger: saveLedger,
            careLedger: careLedger
        )
    }

    func scheduleManyIfNeeded(
        reminders: [Reminder],
        context: ModelContext,
        source: CareLedgerSource = .service
    ) async {
        await ReminderSchedulingService.scheduleManyIfNeeded(
            reminders: reminders,
            context: context,
            source: source,
            careLedger: careLedger
        )
    }

    func cancelAndReschedule(
        reminder: Reminder,
        context: ModelContext,
        source: CareLedgerSource = .service
    ) async {
        await ReminderSchedulingService.cancelAndReschedule(
            reminder: reminder,
            context: context,
            source: source,
            careLedger: careLedger
        )
    }

    func refillMissingPendingNotifications(
        reminders: [Reminder],
        context: ModelContext
    ) async {
        await ReminderSchedulingService.refillMissingPendingNotifications(
            reminders: reminders,
            context: context,
            careLedger: careLedger
        )
    }

    func compensate(reminders: [Reminder], context: ModelContext) {
        ReminderSchedulingService.compensate(reminders: reminders, context: context, careLedger: careLedger)
    }
}
