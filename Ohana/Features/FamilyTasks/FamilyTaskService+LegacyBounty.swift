//
//  FamilyTaskService+LegacyBounty.swift
//  Ohana
//
//  Legacy local bounty migration through the authorized task writer.
//

import Foundation
import SwiftData

extension FamilyTaskService {
    @MainActor
    static func migrateLegacyBountiesIfNeeded(context: ModelContext) {
        syncLegacyBounties(context: context)
    }

    @MainActor
    static func syncLegacyBounties(context: ModelContext) {
        guard let raw = LegacyBountyTaskPreferenceStore.rawTasks(),
              let data = raw.data(using: .utf8),
              let legacy = try? JSONDecoder().decode([BountyTask].self, from: data),
              !legacy.isEmpty else {
            return
        }

        let existing = fetchOrLog(
            FetchDescriptor<FamilyCollaborationTask>(),
            context: context,
            operation: "fetch family tasks for legacy bounty sync"
        )
        var existingById: [UUID: FamilyCollaborationTask] = [:]
        for task in existing {
            existingById[task.id] = task
        }

        var changed = false
        for item in legacy {
            let subjectRequest = householdTaskSubjectRequest(
                assigneeId: item.assignedToId ?? item.assigneeId ?? item.creatorId
            )
            guard let write = authorizedCollaborationWrite(
                subjectRequest: subjectRequest,
                actor: nil,
                occurredAt: item.createdAt,
                context: context,
                logPrefix: "family-task.legacyBounty"
            ) else {
                continue
            }

            if let task = existingById[item.id] {
                var didChange = false
                DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
                    didChange = syncLegacyBounty(item, into: task)
                }
                changed = didChange || changed
                continue
            }

            let task = DomainMemberFactWriter.createFamilyTask(
                plan: write,
                id: item.id,
                title: item.title,
                note: item.description,
                kind: .bounty,
                status: item.isCompleted ? .completed : .active,
                createdById: item.creatorId,
                createdByName: item.creatorName,
                assignedToId: item.assignedToId,
                assignedToName: item.assignedToName,
                rewardCoconuts: cappedReward(item.reward),
                dueAt: nil,
                emoji: item.emoji,
                createdAt: item.createdAt,
                context: context
            )
            task.claimedById = item.assigneeId
            task.claimedByName = item.assigneeName
            task.completedById = item.isCompleted ? item.assigneeId : nil
            task.completedByName = item.isCompleted ? item.assigneeName : nil
            task.completedAt = item.isCompleted ? item.completedAt : nil
            changed = true
        }

        if changed {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            if !saveResult.didSave {
                context.rollback()
            }
        }
    }

    private static func syncLegacyBounty(_ item: BountyTask, into task: FamilyCollaborationTask) -> Bool {
        var changed = false
        func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<FamilyCollaborationTask, Value>, _ value: Value) {
            if task[keyPath: keyPath] != value {
                task[keyPath: keyPath] = value
                changed = true
            }
        }

        set(\.title, item.title)
        set(\.note, item.description)
        set(\.kindRaw, FamilyCollaborationTaskKind.bounty.rawValue)
        set(\.assignedToId, item.assignedToId)
        set(\.assignedToName, item.assignedToName)
        set(\.claimedById, item.assigneeId)
        set(\.claimedByName, item.assigneeName)
        set(\.rewardCoconuts, cappedReward(item.reward))
        set(\.emoji, item.emoji)

        let legacyStatus: FamilyCollaborationTaskStatus = item.isCompleted ? .completed : .active
        set(\.statusRaw, legacyStatus.rawValue)
        set(\.completedById, item.isCompleted ? item.assigneeId : nil)
        set(\.completedByName, item.isCompleted ? item.assigneeName : nil)
        set(\.completedAt, item.isCompleted ? item.completedAt : nil)
        if changed {
            task.touch()
        }
        return changed
    }
}
