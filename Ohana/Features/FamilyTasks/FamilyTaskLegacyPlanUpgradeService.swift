//
//  FamilyTaskLegacyPlanUpgradeService.swift
//  Ohana
//
//  Conservative, idempotent adoption of legacy recurring Event-backed tasks.
//

import Foundation
import SwiftData

nonisolated struct FamilyTaskLegacyPlanUpgradeResult: Equatable, Sendable {
    let upgradedPlanCount: Int
    let adoptedTaskCount: Int
    let retainedLegacyGroupCount: Int
    let notificationIDsToCancel: [String]
    let hasMoreWork: Bool
}

private struct FamilyTaskLegacyGroupAdoptionResult {
    let adoptedTaskCount: Int
    let notificationIDsToCancel: [String]
}

extension FamilyTaskPlanMaterializationActor {
    func upgradeLegacyRecurringTasks(
        maximumPlanCount: Int = 24,
        now: Date = Date()
    ) throws -> FamilyTaskLegacyPlanUpgradeResult {
        try Task.checkCancellation()
        let legacyTasks = try modelContext.fetch(
            FetchDescriptor<FamilyCollaborationTask>(
                predicate: #Predicate<FamilyCollaborationTask> { task in
                    task.planId == nil && task.relatedEventId != nil
                },
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]
            )
        )
        let groups = Dictionary(grouping: legacyTasks) { $0.relatedEventId ?? "" }
            .filter { !$0.key.isEmpty }
            .sorted { $0.key < $1.key }
        let limit = max(1, maximumPlanCount)
        var upgradedPlanCount = 0
        var adoptedTaskCount = 0
        var retainedLegacyGroupCount = 0
        var notificationIDsToCancel: [String] = []

        for (eventID, tasks) in groups {
            try Task.checkCancellation()
            if upgradedPlanCount >= limit { break }
            guard let event = try legacyEvent(id: eventID),
                  (1 ... 365).contains(event.recurrenceDays),
                  let first = tasks.first,
                  canAdopt(tasks: tasks, exemplar: first) else {
                retainedLegacyGroupCount += 1
                continue
            }
            guard let adoption = try adoptLegacyGroup(
                tasks: tasks,
                event: event,
                first: first,
                now: now
            ) else {
                retainedLegacyGroupCount += 1
                continue
            }
            adoptedTaskCount += adoption.adoptedTaskCount
            notificationIDsToCancel.append(contentsOf: adoption.notificationIDsToCancel)
            upgradedPlanCount += 1
        }

        if modelContext.hasChanges {
            let save = modelContext.safeSaveResult(publishFailureEvent: true)
            guard save.didSave else {
                modelContext.rollback()
                throw FamilyTaskPlanCommandError.persistenceFailed(save.errorDescription ?? "legacy upgrade failed")
            }
        }
        return FamilyTaskLegacyPlanUpgradeResult(
            upgradedPlanCount: upgradedPlanCount,
            adoptedTaskCount: adoptedTaskCount,
            retainedLegacyGroupCount: retainedLegacyGroupCount,
            notificationIDsToCancel: notificationIDsToCancel,
            hasMoreWork: groups.count > upgradedPlanCount + retainedLegacyGroupCount
        )
    }

    private func adoptLegacyGroup(
        tasks: [FamilyCollaborationTask],
        event: Event,
        first: FamilyCollaborationTask,
        now: Date
    ) throws -> FamilyTaskLegacyGroupAdoptionResult? {
        let reminders = event.reminders
        let remindersByID = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id.uuidString, $0) })
        let timeZone = TimeZone.current
        guard let creatorID = UUID(uuidString: first.createdById),
              let assigneeID = first.assignedToId.flatMap(UUID.init(uuidString:)),
              let creator = try human(id: creatorID),
              let assignee = try human(id: assigneeID),
              !creator.hasPassedAway,
              !assignee.hasPassedAway,
              creator.id != assignee.id else {
            return nil
        }
        let nominalDates = tasks.map { task in
            task.relatedReminderId.flatMap { remindersByID[$0] }?.resolvedOccurrenceAt
                ?? task.dueAt
                ?? event.startDate
        }
        guard hasUniqueCivilDays(nominalDates, timeZone: timeZone) else { return nil }
        let leadMinutes = tasks.lazy.compactMap { task -> Int? in
            guard let reminderID = task.relatedReminderId,
                  let reminder = remindersByID[reminderID] else { return nil }
            let seconds = reminder.resolvedOccurrenceAt.timeIntervalSince(reminder.scheduledAt)
            return max(0, Int(seconds / 60))
        }.first
        let plan = makeLegacyPlan(
            first: first,
            event: event,
            creator: creator,
            assignee: assignee,
            timeZone: timeZone,
            leadMinutes: leadMinutes
        )
        modelContext.insert(plan)
        let adoptedReminderIDs = adoptLegacyTasks(
            tasks,
            into: plan,
            event: event,
            remindersByID: remindersByID,
            timeZone: timeZone
        )
        event.familyTaskPlanId = plan.id.uuidString
        event.familyTaskOccurrenceKey = tasks.first?.occurrenceKey
        event.recurrenceDays = 0
        event.recurrenceEndDate = nil
        let notificationIDs = try retireLegacyReminders(
            reminders,
            excluding: adoptedReminderIDs,
            plan: plan,
            now: now
        )
        return FamilyTaskLegacyGroupAdoptionResult(
            adoptedTaskCount: tasks.count,
            notificationIDsToCancel: notificationIDs
        )
    }

    private func makeLegacyPlan(
        first: FamilyCollaborationTask,
        event: Event,
        creator: Human,
        assignee: Human,
        timeZone: TimeZone,
        leadMinutes: Int?
    ) -> FamilyTaskPlan {
        FamilyTaskPlan(
            title: first.title,
            note: first.note,
            emoji: first.emoji,
            kind: first.kind,
            subjectKind: first.subjectKind,
            subjectId: first.resolvedSubjectId,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: first.rewardCoconuts,
            // Deliberately preserve 30 as every 30 civil days.
            recurrenceRule: .everyNDays(event.recurrenceDays),
            anchorAt: event.startDate,
            startsAt: event.startDate,
            endsAt: event.recurrenceEndDate,
            timeZoneIdentifier: timeZone.identifier,
            isAllDay: event.isAllDay,
            reminderLeadMinutes: leadMinutes,
            eventTypeRaw: event.eventType,
            taskCareKindRaw: event.taskCareKindRaw,
            sourceEventId: event.id.uuidString,
            createdAt: min(first.createdAt, event.createdAt)
        )
    }

    private func adoptLegacyTasks(
        _ tasks: [FamilyCollaborationTask],
        into plan: FamilyTaskPlan,
        event: Event,
        remindersByID: [String: Reminder],
        timeZone: TimeZone
    ) -> Set<String> {
        var adoptedReminderIDs = Set<String>()
        for task in tasks {
            let reminder = task.relatedReminderId.flatMap { remindersByID[$0] }
            let nominalAt = reminder?.resolvedOccurrenceAt ?? task.dueAt ?? event.startDate
            task.planId = plan.id.uuidString
            task.scheduleVersion = plan.scheduleVersion
            task.nominalAt = nominalAt
            task.dueAt = task.dueAt ?? nominalAt
            task.occurrenceKey = FamilyTaskRecurrenceGenerator.occurrenceKey(
                planID: plan.id,
                scheduleVersion: plan.scheduleVersion,
                nominalAt: nominalAt,
                timeZone: timeZone
            )
            task.touch()
            if let reminderID = task.relatedReminderId {
                adoptedReminderIDs.insert(reminderID)
            }
        }
        return adoptedReminderIDs
    }

    private func retireLegacyReminders(
        _ reminders: [Reminder],
        excluding adoptedReminderIDs: Set<String>,
        plan: FamilyTaskPlan,
        now: Date
    ) throws -> [String] {
        var notificationIDs: [String] = []
        for reminder in reminders where reminder.isPending && !adoptedReminderIDs.contains(reminder.id.uuidString) {
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                reminder: reminder,
                writeKind: .collaboration,
                source: .domainService,
                context: modelContext
            ), DomainScheduleWriter.skipReminder(
                reminder,
                mutation: mutation,
                skippedBy: plan.createdById,
                skippedAt: now,
                terminalAt: now,
                context: modelContext
            ) else {
                throw FamilyTaskPlanCommandError.unauthorized
            }
            let notificationID = reminder.notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notificationID.isEmpty {
                notificationIDs.append(notificationID)
            }
        }
        return notificationIDs
    }

    private func hasUniqueCivilDays(_ dates: [Date], timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let civilDays = Set(dates.map { date in
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        })
        return civilDays.count == dates.count
    }

    private func legacyEvent(id rawID: String) throws -> Event? {
        guard let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func canAdopt(
        tasks: [FamilyCollaborationTask],
        exemplar: FamilyCollaborationTask
    ) -> Bool {
        guard !exemplar.createdById.isEmpty,
              let assigneeID = exemplar.assignedToId,
              !assigneeID.isEmpty else { return false }
        return tasks.allSatisfy { task in
            task.createdById == exemplar.createdById &&
                task.assignedToId == assigneeID &&
                task.title == exemplar.title &&
                task.note == exemplar.note &&
                task.rewardCoconuts == exemplar.rewardCoconuts &&
                task.subjectKind == exemplar.subjectKind &&
                task.resolvedSubjectId == exemplar.resolvedSubjectId
        }
    }
}
