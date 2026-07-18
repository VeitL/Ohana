//
//  CalendarEventCompletionCommands.swift
//  Ohana
//
//  Event completion orchestration for calendar-backed care tasks.
//

import Foundation
import SwiftData

extension CalendarEventCommandService {
    private struct PetTaskCompletionPreparation {
        let syncResult: CalendarTaskCompletionSyncService.PetTaskSyncResult?
        let blockedResult: CalendarEventCompletionResult?
    }

    private struct PlantCareCompletionPreparation {
        let syncResult: PlantCareScheduleSyncResult?
        let blockedResult: CalendarEventCompletionResult?
    }

    @discardableResult
    @MainActor
    static func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        options: CalendarEventCompletionOptions = CalendarEventCompletionOptions()
    ) throws -> CalendarEventCompletionResult {
        let reminderCompletion = options.reminderCompletion ?? ReminderCompletionService()
        let shouldComplete = !event.isOccurrenceMarkedComplete(on: occurrenceDate)
        let affectedSubjectIDs = affectedSubjectIDs(for: event, context: context)
        if !shouldComplete,
           try PersonalUsageSnapshotReader.isOrdinaryUserPlanCandidate(event, context: context, now: now),
           try !PersonalUsageSnapshotReader.countsAsOrdinaryActiveUserPlan(event, context: context, now: now) {
            try PersonalPlanQuotaCommandGate.requirePlanChange(
                context: context,
                personalAccessLevel: options.personalAccessLevel,
                addingActivePlanCount: 1,
                now: now
            )
        }
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: writeKind(for: event),
            source: .userCommand,
            context: context
        ) else {
            return unchangedCompletionResult(
                event: event,
                occurrenceDate: occurrenceDate,
                affectedSubjectIDs: affectedSubjectIDs,
                now: now
            )
        }
        let petPreparation = preparePetTaskCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            shouldComplete: shouldComplete,
            pets: pets,
            context: context,
            executorID: executorId,
            now: now,
            economy: options.economy,
            affectedSubjectIDs: affectedSubjectIDs
        )
        if let blockedResult = petPreparation.blockedResult { return blockedResult }
        let petTaskSyncResult = petPreparation.syncResult
        let remindersToSync = remindersForCompletionSync(
            event: event,
            occurrenceDate: occurrenceDate
        )
        let plantPreparation = preparePlantCareCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            shouldComplete: shouldComplete,
            reminders: remindersToSync,
            context: context,
            executorID: executorId,
            now: now,
            scheduleNotifications: options.schedulePlantCareNotifications,
            affectedSubjectIDs: affectedSubjectIDs
        )
        if let blockedResult = plantPreparation.blockedResult { return blockedResult }
        let plantCareSyncResult = plantPreparation.syncResult
        guard DomainScheduleWriter.setEventOccurrenceCompletion(
            event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            mutation: mutation,
            context: context,
            modifiedAt: now
        ) else {
            return unchangedCompletionResult(
                event: event,
                occurrenceDate: occurrenceDate,
                affectedSubjectIDs: affectedSubjectIDs,
                now: now
            )
        }

        guard syncReminders(
            remindersToSync,
            shouldComplete: shouldComplete,
            occurrenceDate: occurrenceDate,
            executorID: executorId,
            context: context,
            reminderCompletion: reminderCompletion
        ) else {
            context.rollback()
            return unchangedCompletionResult(
                event: event,
                occurrenceDate: occurrenceDate,
                affectedSubjectIDs: affectedSubjectIDs,
                now: now,
                didWriteFact: petTaskSyncResult?.didWriteFact ?? plantCareSyncResult?.didWriteCareFact ?? false,
                allowsDerivedEffects: false,
                factDate: occurrenceDate
            )
        }
        if remindersToSync.isEmpty {
            try CalendarEventPlanCommandService.saveCalendarChanges(context: context)
            if let plantCareSyncResult {
                PlantCareScheduleSyncService.syncPlanAfterCompletion(
                    plantCareSyncResult,
                    context: context,
                    now: now,
                    scheduleNotifications: options.schedulePlantCareNotifications
                )
            }
        }

        return CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: shouldComplete,
            syncedReminderCount: remindersToSync.count,
            affectedSubjectIDs: affectedSubjectIDs,
            didChange: true,
            didWriteFact: petTaskSyncResult?.didWriteFact ?? plantCareSyncResult?.didWriteCareFact ?? true,
            allowsDerivedEffects: petTaskSyncResult?.allowsDerivedEffects ?? plantCareSyncResult?.allowsScheduleCompletion ?? true,
            factDate: occurrenceDate,
            operationDate: now
        )
    }

    private static func preparePetTaskCompletion(
        event: Event,
        occurrenceDate: Date,
        shouldComplete: Bool,
        pets: [Pet],
        context: ModelContext,
        executorID: String?,
        now: Date,
        economy: CareEventEconomyAwarding?,
        affectedSubjectIDs: Set<UUID>
    ) -> PetTaskCompletionPreparation {
        guard CalendarTaskCompletionSyncService.isPetTask(event: event) else {
            return PetTaskCompletionPreparation(syncResult: nil, blockedResult: nil)
        }
        let syncResult = CalendarTaskCompletionSyncService.syncPetTask(
            event: event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            pets: pets,
            context: context,
            executorId: executorID,
            operationDate: now,
            economy: economy
        )
        if !syncResult.didPersist || (!shouldComplete && syncResult == .noOp) {
            return PetTaskCompletionPreparation(
                syncResult: syncResult,
                blockedResult: unchangedCompletionResult(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    affectedSubjectIDs: affectedSubjectIDs,
                    now: now
                )
            )
        }
        if shouldComplete && !syncResult.shouldCompleteOccurrence {
            return PetTaskCompletionPreparation(
                syncResult: syncResult,
                blockedResult: unchangedCompletionResult(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    affectedSubjectIDs: affectedSubjectIDs,
                    now: now,
                    didWriteFact: syncResult.didWriteFact,
                    allowsDerivedEffects: syncResult.allowsDerivedEffects,
                    factDate: occurrenceDate
                )
            )
        }
        return PetTaskCompletionPreparation(syncResult: syncResult, blockedResult: nil)
    }

    private static func preparePlantCareCompletion(
        event: Event,
        occurrenceDate: Date,
        shouldComplete: Bool,
        reminders: [Reminder],
        context: ModelContext,
        executorID: String?,
        now: Date,
        scheduleNotifications: Bool,
        affectedSubjectIDs: Set<UUID>
    ) -> PlantCareCompletionPreparation {
        guard shouldComplete, PlantCareScheduleSyncService.isPlantCareEvent(event) else {
            return PlantCareCompletionPreparation(syncResult: nil, blockedResult: nil)
        }
        let sourceReminder = reminders.first
        let syncResult = PlantCareScheduleSyncService.syncCompletedEvent(
            event,
            occurrenceDate: occurrenceDate,
            executorId: executorID,
            context: context,
            source: sourceReminder == nil ? .calendar : .reminder,
            sourceReminderId: sourceReminder?.id,
            now: now,
            scheduleNotifications: scheduleNotifications,
            syncPlanSchedule: false
        )
        let blockedResult = syncResult.allowsScheduleCompletion ? nil : unchangedCompletionResult(
            event: event,
            occurrenceDate: occurrenceDate,
            affectedSubjectIDs: affectedSubjectIDs,
            now: now
        )
        return PlantCareCompletionPreparation(syncResult: syncResult, blockedResult: blockedResult)
    }

    private static func syncReminders(
        _ reminders: [Reminder],
        shouldComplete: Bool,
        occurrenceDate: Date,
        executorID: String?,
        context: ModelContext,
        reminderCompletion: ReminderCompleting
    ) -> Bool {
        for reminder in reminders {
            let didSync = shouldComplete
                ? reminderCompletion.complete(
                    reminder,
                    by: executorID,
                    occurrenceDate: occurrenceDate,
                    context: context
                )
                : reminderCompletion.reopen(
                    reminder,
                    by: executorID,
                    context: context,
                    reschedule: true
                )
            guard didSync else { return false }
        }
        return true
    }

    private static func unchangedCompletionResult(
        event: Event,
        occurrenceDate: Date,
        affectedSubjectIDs: Set<UUID>,
        now: Date,
        didWriteFact: Bool = false,
        allowsDerivedEffects: Bool = false,
        factDate: Date? = nil
    ) -> CalendarEventCompletionResult {
        CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
            syncedReminderCount: 0,
            affectedSubjectIDs: affectedSubjectIDs,
            didChange: false,
            didWriteFact: didWriteFact,
            allowsDerivedEffects: allowsDerivedEffects,
            factDate: factDate,
            operationDate: now
        )
    }

    private static func remindersForCompletionSync(event: Event, occurrenceDate: Date) -> [Reminder] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: occurrenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? occurrenceDate
        let sameDay = event.reminders.filter { reminder in
            reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow
        }
        if !sameDay.isEmpty { return sameDay }
        return event.reminders
            .filter { $0.isPending && $0.scheduledAt < tomorrow }
            .sorted { $0.scheduledAt > $1.scheduledAt }
            .prefix(1)
            .map(\.self)
    }

    private static func affectedSubjectIDs(for event: Event, context: ModelContext) -> Set<UUID> {
        DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        ).affectedEntityIDs
    }
}
