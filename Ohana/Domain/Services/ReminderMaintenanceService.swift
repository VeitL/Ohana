//
//  ReminderMaintenanceService.swift
//  Ohana
//
//  Shared pending-only reminder maintenance for startup and background refresh.
//

import Foundation
import SwiftData

struct ReminderMaintenanceRunResult: Equatable {
    let pendingCount: Int
    let completed: Bool
}

enum ReminderMaintenanceService {
    @MainActor
    static func pendingReminders(context: ModelContext) -> [Reminder] {
        let pendingStatus = ReminderStatus.pending.rawValue
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus
            },
            sortBy: [SortDescriptor(\Reminder.scheduledAt, order: .forward)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "ReminderMaintenanceService failed to fetch pending reminders: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    static func runPendingReminderMaintenance(
        context: ModelContext,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) async -> ReminderMaintenanceRunResult {
        let reminderScheduling = providedReminderScheduling ?? DomainServiceDependencyRegistry.reminderScheduling(careLedger: CareLedgerService())
        let reminders = pendingReminders(context: context)
        guard !Task.isCancelled else {
            return ReminderMaintenanceRunResult(pendingCount: reminders.count, completed: false)
        }

        await reminderScheduling.refillMissingPendingNotifications(
            reminders: reminders,
            context: context
        )
        guard !Task.isCancelled else {
            return ReminderMaintenanceRunResult(pendingCount: reminders.count, completed: false)
        }

        reminderScheduling.compensate(reminders: reminders, context: context)
        try? context.save()
        return ReminderMaintenanceRunResult(pendingCount: reminders.count, completed: true)
    }
}
