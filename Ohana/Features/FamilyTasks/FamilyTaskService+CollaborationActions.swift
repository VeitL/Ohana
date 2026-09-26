//
//  FamilyTaskService+CollaborationActions.swift
//  Ohana
//
//  Role capabilities and occurrence-scoped collaboration commands.
//

import Foundation
import SwiftData

nonisolated struct FamilyTaskCapabilities: Equatable, Sendable {
    let canEdit: Bool
    let canCancel: Bool
    let canDecline: Bool
    let canComplete: Bool
    let canPostpone: Bool
    let canComment: Bool
    let canApprove: Bool
    let canReturnForRedo: Bool

    static let readOnly = FamilyTaskCapabilities(
        canEdit: false,
        canCancel: false,
        canDecline: false,
        canComplete: false,
        canPostpone: false,
        canComment: false,
        canApprove: false,
        canReturnForRedo: false
    )

    static func resolve(task: FamilyCollaborationTask, currentHumanID: UUID?) -> FamilyTaskCapabilities {
        guard let currentHumanID else { return .readOnly }
        let humanID = currentHumanID.uuidString
        let isCreator = task.createdById == humanID
        let isPerformer = task.claimedById == humanID ||
            (task.claimedById == nil && task.assignedToId == humanID)
        let isFinal = task.status == .completed || task.status == .cancelled
        guard !isFinal else { return .readOnly }

        let isActionable = task.status == .active || task.status == .claimed
        return FamilyTaskCapabilities(
            canEdit: isCreator,
            canCancel: isCreator,
            canDecline: isPerformer && isActionable,
            canComplete: isPerformer && isActionable,
            canPostpone: isPerformer && isActionable && task.dueAt != nil,
            canComment: isPerformer && (isActionable || task.status == .pendingReview),
            canApprove: isCreator && task.status == .pendingReview,
            canReturnForRedo: isCreator && task.status == .pendingReview
        )
    }
}

extension FamilyTaskService {
    @MainActor
    @discardableResult
    static func declineAssignment(
        _ task: FamilyCollaborationTask,
        by human: Human,
        reason: String,
        context: ModelContext
    ) -> Bool {
        let capabilities = FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id)
        guard capabilities.canDecline,
              canWriteCollaboration(for: human),
              canWriteSubject(for: task, context: context),
              let write = authorizedCollaborationWrite(
                  subjectRequest: taskSubjectRequest(for: task, assigneeId: human.id.uuidString, context: context),
                  actor: human,
                  context: context
              ) else { return false }

        let linkedReminder = reminder(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedReminder?.event ?? event(for: task, context: context)
        )
        let priorUpdatedAt = task.updatedAt
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .declined
            task.completedAt = nil
            task.completedById = nil
            task.completedByName = nil
            task.touch()
        }
        let reminderSkip = skipPendingReminder(for: task, by: human.id.uuidString, context: context)
        guard reminderSkip.didSucceed else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        guard FamilyTaskActivityService.stage(
            kind: .declined,
            task: task,
            actor: human,
            recipientHumanID: task.createdById,
            body: reason,
            idempotencyKey: FamilyTaskActivityService.transitionKey(
                task: task,
                action: "declined",
                priorUpdatedAt: priorUpdatedAt
            ),
            context: context
        ) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        return persistMutation(
            context: context,
            onSuccess: {
                if let notificationID = reminderSkip.notificationID {
                    OhanaNotifications.current.cancel(notificationId: notificationID)
                }
            },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @MainActor
    @discardableResult
    static func postponeOccurrence(
        _ task: FamilyCollaborationTask,
        to newDueAt: Date,
        by human: Human,
        context: ModelContext,
        now: Date = Date()
    ) -> Bool {
        let capabilities = FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id)
        guard capabilities.canPostpone,
              let oldDueAt = task.dueAt,
              newDueAt > max(oldDueAt, now),
              canWriteCollaboration(for: human),
              canWriteSubject(for: task, context: context),
              let write = authorizedCollaborationWrite(
                  subjectRequest: taskSubjectRequest(for: task, assigneeId: human.id.uuidString, context: context),
                  actor: human,
                  context: context
              ) else { return false }

        let linkedReminder = reminder(for: task, context: context)
        let linkedEvent = linkedReminder?.event ?? event(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedEvent
        )
        if let linkedEvent, linkedEvent.recurrenceDays <= 0 {
            let intent = DomainScheduleCreateIntent(
                event: linkedEvent,
                startDate: newDueAt,
                writeKind: .collaboration,
                source: .domainService
            )
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
                event: linkedEvent,
                intent: intent,
                writeKind: .collaboration,
                source: .domainService,
                context: context
            ), DomainScheduleWriter.updateEvent(linkedEvent, intent: intent, mutation: mutation) else {
                rollbackSnapshot.rollback(task, context: context)
                return false
            }
        }

        if let linkedReminder {
            let lead = max(0, oldDueAt.timeIntervalSince(linkedReminder.scheduledAt))
            let deliveryAt = newDueAt.addingTimeInterval(-lead)
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                reminder: linkedReminder,
                writeKind: .collaboration,
                source: .domainService,
                context: context
            ), DomainScheduleWriter.rescheduleReminderDelivery(
                linkedReminder,
                scheduledAt: deliveryAt,
                mutation: mutation,
                modifiedAt: now,
                context: context
            ) else {
                rollbackSnapshot.rollback(task, context: context)
                return false
            }
        }

        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.dueAt = newDueAt
            task.touch()
        }
        guard FamilyTaskActivityService.stage(
            kind: .postponed,
            task: task,
            actor: human,
            recipientHumanID: task.createdById,
            oldDueAt: oldDueAt,
            newDueAt: newDueAt,
            idempotencyKey: "family-task:\(task.id.uuidString):postponed:\(oldDueAt.timeIntervalSinceReferenceDate.bitPattern):\(newDueAt.timeIntervalSinceReferenceDate.bitPattern)",
            createdAt: now,
            context: context
        ) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        return persistMutation(
            context: context,
            onSuccess: {
                guard let linkedReminder else { return }
                Task { @MainActor in
                    let reminderScheduling = ReminderSchedulingManager()
                    await reminderScheduling.cancelAndReschedule(
                        reminder: linkedReminder,
                        context: context,
                        source: .service
                    )
                }
            },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @MainActor
    @discardableResult
    static func addComment(
        _ task: FamilyCollaborationTask,
        body: String,
        by human: Human,
        idempotencyKey: String,
        context: ModelContext
    ) -> Bool {
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let capabilities = FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id)
        guard !normalizedBody.isEmpty,
              capabilities.canComment,
              canWriteCollaboration(for: human),
              canWriteSubject(for: task, context: context),
              let write = authorizedCollaborationWrite(
                  subjectRequest: taskSubjectRequest(for: task, assigneeId: human.id.uuidString, context: context),
                  actor: human,
                  context: context
              ) else { return false }

        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(task: task)
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { $0.touch() }
        guard FamilyTaskActivityService.stage(
            kind: .commented,
            task: task,
            actor: human,
            recipientHumanID: task.createdById,
            body: normalizedBody,
            idempotencyKey: idempotencyKey,
            context: context
        ) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        return persistMutation(
            context: context,
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @MainActor
    @discardableResult
    static func cancelByCreator(
        _ task: FamilyCollaborationTask,
        by creator: Human,
        context: ModelContext
    ) -> Bool {
        let capabilities = FamilyTaskCapabilities.resolve(task: task, currentHumanID: creator.id)
        guard capabilities.canCancel,
              canWriteCollaboration(for: creator),
              canWriteSubject(for: task, context: context),
              let write = authorizedCollaborationWrite(
                  subjectRequest: taskSubjectRequest(for: task, context: context),
                  actor: creator,
                  context: context
              ) else { return false }

        let linkedReminder = reminder(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedReminder?.event ?? event(for: task, context: context)
        )
        let priorUpdatedAt = task.updatedAt
        let recipient = task.completedById ?? task.claimedById ?? task.assignedToId
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .cancelled
            task.touch()
        }
        let reminderSkip = skipPendingReminder(for: task, by: creator.id.uuidString, context: context)
        guard reminderSkip.didSucceed else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        if let recipient,
           !FamilyTaskActivityService.stage(
               kind: .cancelled,
               task: task,
               actor: creator,
               recipientHumanID: recipient,
               idempotencyKey: FamilyTaskActivityService.transitionKey(
                   task: task,
                   action: "cancelled",
                   priorUpdatedAt: priorUpdatedAt
               ),
               context: context
           ) {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        return persistMutation(
            context: context,
            onSuccess: {
                if let notificationID = reminderSkip.notificationID {
                    OhanaNotifications.current.cancel(notificationId: notificationID)
                }
            },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    private struct PendingReminderSkipResult {
        let didSucceed: Bool
        let notificationID: String?

        static let notNeeded = PendingReminderSkipResult(didSucceed: true, notificationID: nil)
        static let failed = PendingReminderSkipResult(didSucceed: false, notificationID: nil)

        static func staged(notificationID: String?) -> PendingReminderSkipResult {
            PendingReminderSkipResult(didSucceed: true, notificationID: notificationID)
        }
    }

    @MainActor
    private static func skipPendingReminder(
        for task: FamilyCollaborationTask,
        by humanID: String,
        context: ModelContext
    ) -> PendingReminderSkipResult {
        guard let reminder = reminder(for: task, context: context), reminder.isPending else {
            return .notNeeded
        }
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                  reminder: reminder,
                  writeKind: .collaboration,
                  source: .domainService,
                  context: context
              ), DomainScheduleWriter.skipReminder(
                  reminder,
                  mutation: mutation,
                  skippedBy: humanID,
                  skippedAt: Date(),
                  context: context
              ) else { return .failed }
        return .staged(
            notificationID: reminder.notificationId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        )
    }

    @MainActor
    private static func event(for task: FamilyCollaborationTask, context: ModelContext) -> Event? {
        guard let eventID = task.relatedEventId.flatMap(UUID.init(uuidString:)) else { return nil }
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == eventID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
