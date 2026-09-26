//
//  FamilyTaskActivityService.swift
//  Ohana
//
//  Occurrence-scoped collaboration activity and the local per-Human inbox.
//

import Foundation
import SwiftData

@MainActor
enum FamilyTaskActivityService {
    nonisolated static let defaultInboxLimit = 100
    nonisolated static let defaultOccurrenceTimelineLimit = 100

    @discardableResult
    static func stage(
        kind: FamilyTaskActivityKind,
        task: FamilyCollaborationTask,
        actor: Human?,
        recipientHumanID: String?,
        body: String = "",
        oldDueAt: Date? = nil,
        newDueAt: Date? = nil,
        countValue: Int = 0,
        idempotencyKey: String,
        createdAt: Date = Date(),
        context: ModelContext
    ) -> Bool {
        stage(
            kind: kind,
            planID: task.planId,
            taskID: task.id.uuidString,
            occurrenceKey: task.occurrenceKey,
            actorHumanID: actor?.id.uuidString ?? "",
            actorHumanName: actor?.name ?? "",
            recipientHumanID: recipientHumanID,
            taskTitle: task.title,
            body: body,
            oldDueAt: oldDueAt,
            newDueAt: newDueAt,
            countValue: countValue,
            idempotencyKey: idempotencyKey,
            createdAt: createdAt,
            context: context
        )
    }

    @discardableResult
    static func stage(
        kind: FamilyTaskActivityKind,
        planID: String? = nil,
        taskID: String? = nil,
        occurrenceKey: String? = nil,
        actorHumanID: String = "",
        actorHumanName: String = "",
        recipientHumanID: String?,
        taskTitle: String,
        body: String = "",
        oldDueAt: Date? = nil,
        newDueAt: Date? = nil,
        countValue: Int = 0,
        idempotencyKey: String,
        createdAt: Date = Date(),
        context: ModelContext
    ) -> Bool {
        let normalizedKey = idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty,
              let recipientHumanID = normalizedUUIDString(recipientHumanID) else {
            return false
        }
        var descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { activity in
                activity.idempotencyKey == normalizedKey
            }
        )
        descriptor.fetchLimit = 1
        guard let existingActivities = try? context.fetch(descriptor),
              existingActivities.isEmpty else { return false }

        let activity = FamilyTaskActivity(
            planId: normalizedUUIDString(planID),
            taskId: normalizedUUIDString(taskID),
            occurrenceKey: normalizedNonempty(occurrenceKey),
            kind: kind,
            actorHumanId: normalizedUUIDString(actorHumanID) ?? "",
            actorHumanName: actorHumanName.trimmingCharacters(in: .whitespacesAndNewlines),
            recipientHumanId: recipientHumanID,
            taskTitleSnapshot: taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            oldDueAt: oldDueAt,
            newDueAt: newDueAt,
            countValue: max(0, countValue),
            idempotencyKey: normalizedKey,
            createdAt: createdAt
        )
        context.insert(activity)
        return true
    }

    static func inbox(
        recipientHumanID: UUID,
        limit: Int = defaultInboxLimit,
        context: ModelContext
    ) -> [FamilyTaskActivitySnapshot] {
        let recipient = recipientHumanID.uuidString
        var descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { activity in
                activity.recipientHumanId == recipient
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = min(250, max(1, limit))
        let activities = (try? context.fetch(descriptor)) ?? []
        return activities.map(snapshot)
    }

    static func occurrenceTimeline(
        taskID: UUID,
        limit: Int = defaultOccurrenceTimelineLimit,
        context: ModelContext
    ) -> [FamilyTaskActivitySnapshot] {
        let rawTaskID = taskID.uuidString
        var descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { activity in
                activity.taskId == rawTaskID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = min(defaultOccurrenceTimelineLimit, max(1, limit))
        return ((try? context.fetch(descriptor)) ?? []).map(snapshot)
    }

    static func unreadCount(
        recipientHumanID: UUID,
        context: ModelContext
    ) -> Int {
        let recipient = recipientHumanID.uuidString
        let descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { activity in
                activity.recipientHumanId == recipient && activity.readAt == nil
            }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    @discardableResult
    static func markRead(
        activityID: UUID,
        recipientHumanID: UUID,
        context: ModelContext,
        now: Date = Date()
    ) -> Bool {
        let recipient = recipientHumanID.uuidString
        var descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { activity in
                activity.id == activityID && activity.recipientHumanId == recipient
            }
        )
        descriptor.fetchLimit = 1
        guard let activity = try? context.fetch(descriptor).first else { return false }
        if activity.readAt != nil { return true }
        activity.readAt = now
        return persistMutation(context: context)
    }

    @discardableResult
    static func markAllRead(
        recipientHumanID: UUID,
        context: ModelContext,
        now: Date = Date()
    ) -> Int {
        let recipient = recipientHumanID.uuidString
        var descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { activity in
                activity.recipientHumanId == recipient && activity.readAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        guard let activities = try? context.fetch(descriptor), !activities.isEmpty else { return 0 }
        for activity in activities {
            activity.readAt = now
        }
        return persistMutation(context: context) ? activities.count : 0
    }

    static func transitionKey(
        task: FamilyCollaborationTask,
        action: String,
        priorUpdatedAt: Date
    ) -> String {
        "family-task:\(task.id.uuidString):\(action):\(priorUpdatedAt.timeIntervalSinceReferenceDate.bitPattern)"
    }

    private static func snapshot(_ activity: FamilyTaskActivity) -> FamilyTaskActivitySnapshot {
        FamilyTaskActivitySnapshot(
            id: activity.id,
            planID: UUID(uuidString: activity.planId ?? ""),
            taskID: UUID(uuidString: activity.taskId ?? ""),
            occurrenceKey: normalizedNonempty(activity.occurrenceKey),
            kind: activity.kind,
            actorHumanID: UUID(uuidString: activity.actorHumanId),
            actorHumanName: activity.actorHumanName,
            recipientHumanID: UUID(uuidString: activity.recipientHumanId),
            taskTitle: activity.taskTitleSnapshot,
            body: activity.body,
            oldDueAt: activity.oldDueAt,
            newDueAt: activity.newDueAt,
            countValue: activity.countValue,
            createdAt: activity.createdAt,
            readAt: activity.readAt
        )
    }

    private static func normalizedUUIDString(_ raw: String?) -> String? {
        guard let raw = normalizedNonempty(raw), let id = UUID(uuidString: raw) else { return nil }
        return id.uuidString
    }

    private static func normalizedNonempty(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func persistMutation(context: ModelContext) -> Bool {
        let result = context.safeSaveResult(publishFailureEvent: true)
        guard result.didSave else {
            context.rollback()
            return false
        }
        return true
    }
}
