//
//  ReminderCompletionService.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
protocol ReminderCompleting {
    @discardableResult
    func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext) -> Bool
    @discardableResult
    func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext) -> Bool
    @discardableResult
    func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool) -> Bool
    @discardableResult
    func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool) -> Bool
}

@MainActor
final class ReminderCompletionService: ReminderCompleting {
    private let careLedger: CareLedgerRecording
    private let familyTasks: FamilyTaskManaging
    private let reminderScheduling: ReminderSchedulingManaging
    private let notifications: ReminderNotificationScheduling

    init(
        careLedger: CareLedgerRecording = CareLedgerService(),
        familyTasks providedFamilyTasks: FamilyTaskManaging? = nil,
        reminderScheduling: ReminderSchedulingManaging? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) {
        self.careLedger = careLedger
        self.familyTasks = providedFamilyTasks ?? DomainServiceDependencyRegistry.familyTasks()
        self.reminderScheduling = reminderScheduling ?? DomainServiceDependencyRegistry.reminderScheduling(careLedger: careLedger)
        self.notifications = notifications
    }

    @discardableResult
    func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext) -> Bool {
        Self.complete(
            reminder,
            by: humanId,
            context: context,
            careLedger: careLedger,
            familyTasks: familyTasks,
            notifications: notifications
        )
    }

    @discardableResult
    func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext) -> Bool {
        Self.skip(reminder, by: humanId, context: context, careLedger: careLedger, notifications: notifications)
    }

    @discardableResult
    func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) -> Bool {
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

    @discardableResult
    func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) -> Bool {
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
    @discardableResult
    static func complete(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording = CareLedgerService(),
        familyTasks providedFamilyTasks: FamilyTaskManaging? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        schedulePlantCareNotifications: Bool = true
    ) -> Bool {
        let familyTasks = providedFamilyTasks ?? DomainServiceDependencyRegistry.familyTasks()
        let now = Date()
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ),
            DomainScheduleWriter.completeReminder(
                reminder,
                mutation: mutation,
                completedBy: humanId,
                completedAt: now,
                context: context
            )
        else {
            return false
        }
        context.safeSave()
        PlantCareScheduleSyncService.syncCompletedReminder(
            reminder,
            executorId: humanId,
            context: context,
            now: now,
            careLedger: careLedger,
            scheduleNotifications: schedulePlantCareNotifications
        )
        cancelNotification(for: reminder, notifications: notifications)
        runReminderEffects(
            reminder,
            actionType: "complete",
            actorId: humanId,
            occurredAt: now,
            context: context,
            careLedger: careLedger
        ) {
            familyTasks.syncCompletedReminder(reminder, completedBy: humanId, context: context)
        }
        return true
    }

    @MainActor
    @discardableResult
    static func skip(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording = CareLedgerService(),
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> Bool {
        let now = Date()
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ),
            DomainScheduleWriter.skipReminder(
                reminder,
                mutation: mutation,
                skippedBy: humanId,
                skippedAt: now,
                context: context
            )
        else {
            return false
        }
        context.safeSave()
        cancelNotification(for: reminder, notifications: notifications)
        runReminderEffects(
            reminder,
            actionType: "skip",
            actorId: humanId,
            occurredAt: now,
            context: context,
            careLedger: careLedger
        ) {}
        return true
    }

    @MainActor
    @discardableResult
    static func reopen(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        reschedule: Bool = true,
        careLedger: CareLedgerRecording = CareLedgerService(),
        familyTasks providedFamilyTasks: FamilyTaskManaging? = nil,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> Bool {
        let familyTasks = providedFamilyTasks ?? DomainServiceDependencyRegistry.familyTasks()
        let reminderScheduling = providedReminderScheduling ?? DomainServiceDependencyRegistry.reminderScheduling(careLedger: careLedger)
        let now = Date()
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ),
            DomainScheduleWriter.reopenReminder(
                reminder,
                mutation: mutation,
                reopenedBy: humanId,
                reopenedAt: now,
                context: context
            )
        else {
            return false
        }
        context.safeSave()
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
        runReminderEffects(
            reminder,
            actionType: "reopen",
            actorId: humanId,
            occurredAt: now,
            context: context,
            careLedger: careLedger
        ) {
            familyTasks.syncReopenedReminder(reminder, context: context)
        }
        return true
    }

    @MainActor
    @discardableResult
    static func snoozeOneDay(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        reschedule: Bool = true,
        careLedger: CareLedgerRecording = CareLedgerService(),
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> Bool {
        let reminderScheduling = providedReminderScheduling ?? DomainServiceDependencyRegistry.reminderScheduling(careLedger: careLedger)
        let now = Date()
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ),
            DomainScheduleWriter.snoozeReminderOneDay(
                reminder,
                mutation: mutation,
                snoozedBy: humanId,
                snoozedAt: now,
                context: context
            )
        else {
            return false
        }
        context.safeSave()
        if reschedule {
            Task { @MainActor in
                await reminderScheduling.cancelAndReschedule(reminder: reminder, context: context, source: .service)
            }
        }
        runReminderEffects(
            reminder,
            actionType: "snoozeOneDay",
            actorId: humanId,
            occurredAt: now,
            context: context,
            careLedger: careLedger
        ) {}
        return true
    }

    private static func cancelNotification(for reminder: Reminder, notifications: ReminderNotificationScheduling) {
        let notificationId = reminder.notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notificationId.isEmpty else { return }
        notifications.cancel(notificationId: notificationId)
    }

    private static func runReminderEffects(
        _ reminder: Reminder,
        actionType: String,
        actorId: String?,
        occurredAt: Date,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        effects: () -> Void
    ) {
        guard let event = reminder.event,
              let plan = DomainEffectWriteAuthorizer.authorizeSubjectEffect(
                  subjectRequest: DomainSubjectResolutionRequest(event: event),
                  occurredAt: occurredAt,
                  writeKind: .care,
                  source: .domainService,
                  executorId: actorId,
                  unresolvedAssigneePolicy: .drop,
                  context: context,
                  logPrefix: "ReminderCompletion:\(actionType)"
              ) else {
            return
        }
        DomainEffectDispatcher.run(plan: plan) { _ in
            effects()
            careLedger.recordReminderState(
                reminder: reminder,
                actionType: actionType,
                actorId: actorId,
                source: .service,
                context: context,
                save: true
            )
        }
    }
}
