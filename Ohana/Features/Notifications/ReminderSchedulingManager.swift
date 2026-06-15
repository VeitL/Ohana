import Foundation
import SwiftData

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
