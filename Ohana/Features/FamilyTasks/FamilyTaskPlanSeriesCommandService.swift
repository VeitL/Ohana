//
//  FamilyTaskPlanSeriesCommandService.swift
//  Ohana
//
//  Publisher-only "this and future" edits and soft cancellation.
//

import Foundation
import SwiftData

nonisolated struct FamilyTaskSeriesMutationResult: Equatable, Sendable {
    let planID: UUID
    let cancelledOccurrenceCount: Int
    let insertedOccurrenceCount: Int
    let reminderIDsToSchedule: [UUID]
    let notificationIDsToCancel: [String]
}

extension FamilyTaskPlanMaterializationActor {
    func updateThisAndFuture(
        planID: UUID,
        from nominalAt: Date,
        draft: FamilyTaskPlanDraft,
        editorID: UUID,
        now: Date = Date()
    ) throws -> FamilyTaskSeriesMutationResult {
        try Task.checkCancellation()
        guard let plan = try seriesPlan(id: planID), plan.status == .active else {
            throw FamilyTaskPlanCommandError.planUnavailable
        }
        guard plan.createdById == editorID.uuidString,
              draft.creatorID == editorID else {
            throw FamilyTaskPlanCommandError.unauthorized
        }
        guard draft.expectedScheduleVersion == plan.scheduleVersion else {
            throw FamilyTaskPlanCommandError.staleScheduleVersion
        }
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { throw FamilyTaskPlanCommandError.invalidTitle }
        guard draft.recurrenceRule.isValid else { throw FamilyTaskPlanCommandError.invalidRecurrence }
        guard let timeZone = TimeZone(identifier: draft.timeZoneIdentifier) else {
            throw FamilyTaskPlanCommandError.invalidTimeZone
        }
        guard draft.endsAt == nil || draft.endsAt! >= nominalAt else {
            throw FamilyTaskPlanCommandError.invalidDateRange
        }
        guard let assignee = try seriesHuman(id: draft.assigneeID),
              !assignee.hasPassedAway,
              assignee.id != editorID else {
            throw FamilyTaskPlanCommandError.invalidParticipants
        }
        guard try subjectIsAvailable(kind: draft.subjectKind, id: draft.subjectID) else {
            throw FamilyTaskPlanCommandError.invalidSubject
        }
        let reward = FamilyTaskRewardPolicy.capped(draft.rewardCoconuts)
        guard reward == draft.rewardCoconuts else { throw FamilyTaskPlanCommandError.invalidReward }

        let oldAssigneeID = plan.assignedToId
        let cancellation = try softCancelOpenOccurrences(
            planID: planID,
            from: nominalAt,
            cancelledByID: editorID.uuidString,
            now: now
        )
        plan.title = normalizedTitle
        plan.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.emoji = draft.emoji
        plan.kind = reward > 0 ? .bounty : .householdTask
        plan.subjectKind = draft.subjectKind
        plan.subjectId = draft.subjectID?.uuidString
        plan.subjectName = draft.subjectName
        plan.assignedToId = assignee.id.uuidString
        plan.assignedToName = assignee.name
        plan.rewardCoconuts = reward
        plan.recurrenceRule = draft.recurrenceRule
        plan.anchorAt = draft.anchorAt
        plan.startsAt = max(draft.startsAt ?? nominalAt, nominalAt)
        plan.endsAt = draft.endsAt
        plan.timeZoneIdentifier = timeZone.identifier
        plan.scheduleVersion += 1
        plan.isAllDay = draft.isAllDay
        plan.reminderLeadMinutes = draft.reminderLeadMinutes.map { max(0, $0) }
        plan.eventTypeRaw = draft.eventTypeRaw
        plan.taskCareKindRaw = draft.taskCareKindRaw
        plan.materializedThroughAt = nil
        plan.updatedAt = now

        let materialized = try materialize(plan: plan, now: now)
        modelContext.insert(
            FamilyTaskActivity(
                planId: plan.id.uuidString,
                kind: .edited,
                actorHumanId: editorID.uuidString,
                actorHumanName: plan.createdByName,
                recipientHumanId: plan.assignedToId,
                taskTitleSnapshot: plan.title,
                idempotencyKey: "family-task-plan:\(plan.id.uuidString):edited:v\(plan.scheduleVersion)",
                createdAt: now
            )
        )
        if oldAssigneeID != plan.assignedToId, !oldAssigneeID.isEmpty {
            modelContext.insert(
                FamilyTaskActivity(
                    planId: plan.id.uuidString,
                    kind: .cancelled,
                    actorHumanId: editorID.uuidString,
                    actorHumanName: plan.createdByName,
                    recipientHumanId: oldAssigneeID,
                    taskTitleSnapshot: plan.title,
                    idempotencyKey: "family-task-plan:\(plan.id.uuidString):reassigned:v\(plan.scheduleVersion):old",
                    createdAt: now
                )
            )
        }
        try persistSeriesMutation()
        return FamilyTaskSeriesMutationResult(
            planID: plan.id,
            cancelledOccurrenceCount: cancellation.cancelledCount,
            insertedOccurrenceCount: materialized.insertedOccurrenceCount,
            reminderIDsToSchedule: materialized.reminderIDs,
            notificationIDsToCancel: cancellation.notificationIDs
        )
    }

    func cancelThisAndFuture(
        planID: UUID,
        from nominalAt: Date,
        editorID: UUID,
        now: Date = Date()
    ) throws -> FamilyTaskSeriesMutationResult {
        try Task.checkCancellation()
        guard let plan = try seriesPlan(id: planID), plan.status == .active else {
            throw FamilyTaskPlanCommandError.planUnavailable
        }
        guard plan.createdById == editorID.uuidString else {
            throw FamilyTaskPlanCommandError.unauthorized
        }
        let cancellation = try softCancelOpenOccurrences(
            planID: planID,
            from: nominalAt,
            cancelledByID: editorID.uuidString,
            now: now
        )
        plan.status = .cancelled
        plan.cancelledAt = now
        plan.updatedAt = now
        modelContext.insert(
            FamilyTaskActivity(
                planId: plan.id.uuidString,
                kind: .cancelled,
                actorHumanId: editorID.uuidString,
                actorHumanName: plan.createdByName,
                recipientHumanId: plan.assignedToId,
                taskTitleSnapshot: plan.title,
                countValue: cancellation.cancelledCount,
                idempotencyKey: "family-task-plan:\(plan.id.uuidString):cancelled:v\(plan.scheduleVersion)",
                createdAt: now
            )
        )
        try persistSeriesMutation()
        return FamilyTaskSeriesMutationResult(
            planID: plan.id,
            cancelledOccurrenceCount: cancellation.cancelledCount,
            insertedOccurrenceCount: 0,
            reminderIDsToSchedule: [],
            notificationIDsToCancel: cancellation.notificationIDs
        )
    }

    private func softCancelOpenOccurrences(
        planID: UUID,
        from cutoff: Date,
        cancelledByID: String,
        now: Date
    ) throws -> (cancelledCount: Int, notificationIDs: [String]) {
        let rawPlanID = planID.uuidString
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.planId == rawPlanID && task.nominalAt != nil
            },
            sortBy: [SortDescriptor(\.nominalAt)]
        )
        descriptor.fetchLimit = 2000
        let tasks = try modelContext.fetch(descriptor).filter { task in
            guard let nominalAt = task.nominalAt, nominalAt >= cutoff else { return false }
            return task.status != .completed && task.status != .cancelled
        }
        var notificationIDs: [String] = []
        for task in tasks {
            task.status = .cancelled
            task.touch()
            if let reminder = try seriesReminder(id: task.relatedReminderId), reminder.isPending {
                guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                    reminder: reminder,
                    writeKind: .collaboration,
                    source: .domainService,
                    context: modelContext
                ), DomainScheduleWriter.skipReminder(
                    reminder,
                    mutation: mutation,
                    skippedBy: cancelledByID,
                    skippedAt: now,
                    terminalAt: now,
                    context: modelContext
                ) else {
                    throw FamilyTaskPlanCommandError.unauthorized
                }
                let notificationID = reminder.notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notificationID.isEmpty { notificationIDs.append(notificationID) }
            }
            if let event = try seriesEvent(id: task.relatedEventId) {
                event.isCompleted = true
            }
        }
        return (tasks.count, notificationIDs)
    }

    private func seriesPlan(id: UUID) throws -> FamilyTaskPlan? {
        var descriptor = FetchDescriptor<FamilyTaskPlan>(predicate: #Predicate<FamilyTaskPlan> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func seriesHuman(id: UUID) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func seriesEvent(id rawID: String?) throws -> Event? {
        guard let rawID, let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func seriesReminder(id rawID: String?) throws -> Reminder? {
        guard let rawID, let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate<Reminder> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func persistSeriesMutation() throws {
        let result = modelContext.safeSaveResult(publishFailureEvent: true)
        guard result.didSave else {
            modelContext.rollback()
            throw FamilyTaskPlanCommandError.persistenceFailed(result.errorDescription ?? "series mutation failed")
        }
    }
}
