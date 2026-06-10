//
//  ReminderCompletionService.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
protocol ReminderCompleting {
    func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext)
    func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext)
    func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool)
    func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool)
}

@MainActor
final class ReminderCompletionService: ReminderCompleting {
    private let careLedger: CareLedgerRecording
    private let familyTasks: FamilyTaskManaging
    private let reminderScheduling: ReminderSchedulingManaging

    init(
        careLedger: CareLedgerRecording = CareLedgerService(),
        familyTasks providedFamilyTasks: FamilyTaskManaging? = nil,
        reminderScheduling: ReminderSchedulingManaging? = nil
    ) {
        self.careLedger = careLedger
        self.familyTasks = providedFamilyTasks ?? StaticFamilyTaskManager()
        self.reminderScheduling = reminderScheduling ?? ReminderSchedulingManager(careLedger: careLedger)
    }

    func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        Self.complete(reminder, by: humanId, context: context, careLedger: careLedger, familyTasks: familyTasks)
    }

    func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        Self.skip(reminder, by: humanId, context: context, careLedger: careLedger)
    }

    func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        Self.reopen(
            reminder,
            by: humanId,
            context: context,
            reschedule: reschedule,
            careLedger: careLedger,
            familyTasks: familyTasks,
            reminderScheduling: reminderScheduling
        )
    }

    func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        Self.snoozeOneDay(
            reminder,
            by: humanId,
            context: context,
            reschedule: reschedule,
            careLedger: careLedger,
            reminderScheduling: reminderScheduling
        )
    }

    @MainActor
    static func complete(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording = CareLedgerService(),
        familyTasks providedFamilyTasks: FamilyTaskManaging? = nil
    ) {
        let familyTasks = providedFamilyTasks ?? StaticFamilyTaskManager()
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        reminder.completedBy = humanId ?? ""
        reminder.event?.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        careLedger.recordReminderState(reminder: reminder, actionType: "complete", actorId: humanId, source: .service, context: context, save: true)
        familyTasks.syncCompletedReminder(reminder, completedBy: humanId, context: context)
    }

    @MainActor
    static func skip(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording = CareLedgerService()
    ) {
        reminder.statusEnum = .skipped
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        careLedger.recordReminderState(reminder: reminder, actionType: "skip", actorId: humanId, source: .service, context: context, save: true)
    }

    @MainActor
    static func reopen(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        reschedule: Bool = true,
        careLedger: CareLedgerRecording = CareLedgerService(),
        familyTasks providedFamilyTasks: FamilyTaskManaging? = nil,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) {
        let familyTasks = providedFamilyTasks ?? StaticFamilyTaskManager()
        let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager(careLedger: careLedger)
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.event?.setOccurrenceMarkedComplete(false, on: reminder.scheduledAt)
        if reschedule {
            Task { @MainActor in
                await reminderScheduling.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: .service,
                    existingNotificationIds: nil,
                    operation: "schedule",
                    saveLedger: true
                )
            }
        }
        context.safeSave()
        careLedger.recordReminderState(reminder: reminder, actionType: "reopen", actorId: humanId, source: .service, context: context, save: true)
        familyTasks.syncReopenedReminder(reminder, context: context)
    }

    @MainActor
    static func snoozeOneDay(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        reschedule: Bool = true,
        careLedger: CareLedgerRecording = CareLedgerService(),
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) {
        let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager(careLedger: careLedger)
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.scheduledAt = Calendar.current.date(byAdding: .day, value: 1, to: reminder.scheduledAt)
            ?? Date().addingTimeInterval(86_400)
        if reschedule {
            Task { @MainActor in
                await reminderScheduling.cancelAndReschedule(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        careLedger.recordReminderState(reminder: reminder, actionType: "snoozeOneDay", actorId: humanId, source: .service, context: context, save: true)
    }
}
