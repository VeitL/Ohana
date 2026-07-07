//
//  FamilyTaskService+ReminderSync.swift
//  Ohana
//
//  Keeps reminder-driven task synchronization out of the main collaboration
//  task writer so the canonical service remains below the oversized ratchet.
//

import Foundation
import SwiftData

extension FamilyTaskService {
    @MainActor
    @discardableResult
    static func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext) -> Bool {
        syncCompletedReminder(
            reminder,
            completedBy: humanId,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
    }

    @MainActor
    @discardableResult
    static func syncCompletedReminder(
        _ reminder: Reminder,
        completedBy humanId: String?,
        context: ModelContext,
        wallet _: CoconutWalletManaging,
        careLedger _: CareLedgerRecording,
        projectionManager _: QuestManager? = nil
    ) -> Bool {
        guard let task = activeTask(forReminderId: reminder.id.uuidString, context: context),
              task.status != .completed else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: reminder, assigneeId: humanId, context: context),
            actor: human(id: humanId, context: context),
            context: context
        ) else { return false }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.completedAt = reminder.completedAt ?? Date()
            task.completedById = humanId
            task.completedByName = humanName(id: humanId, context: context)
            task.status = task.hasReward ? .pendingReview : .completed
            task.touch()
        }

        return persistMutation(context: context)
    }

    @MainActor
    @discardableResult
    static func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) -> Bool {
        guard let task = activeOrCompletedTask(forReminderId: reminder.id.uuidString, context: context),
              task.status == .completed else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: reminder, assigneeId: task.assignedToId, context: context),
            actor: nil,
            context: context
        ) else { return false }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .active
            task.completedAt = nil
            task.completedById = nil
            task.completedByName = nil
            task.touch()
        }
        return persistMutation(context: context)
    }

    @MainActor
    static func activeTask(forReminderId reminderId: String, context: ModelContext) -> FamilyCollaborationTask? {
        let activeStatus = FamilyCollaborationTaskStatus.active.rawValue
        let claimedStatus = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReviewStatus = FamilyCollaborationTaskStatus.pendingReview.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.relatedReminderId == reminderId &&
                    (task.statusRaw == activeStatus ||
                        task.statusRaw == claimedStatus ||
                        task.statusRaw == pendingReviewStatus)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch active task for reminder"
        ).first
    }

    @MainActor
    private static func activeOrCompletedTask(forReminderId reminderId: String, context: ModelContext) -> FamilyCollaborationTask? {
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.relatedReminderId == reminderId
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch active or completed task for reminder"
        ).first
    }
}
