//
//  FamilyTaskPlanMaterializationService.swift
//  Ohana
//
//  The single rolling materializer for recurring family-task occurrences.
//  It owns Event, Reminder, and FamilyCollaborationTask projection writes.
//

import Foundation
import SwiftData

nonisolated struct FamilyTaskPlanDraft: Equatable, Sendable {
    let title: String
    let note: String
    let emoji: String
    let subjectKind: FamilyCollaborationTaskSubjectKind
    let subjectID: UUID?
    let subjectName: String
    let creatorID: UUID
    let assigneeID: UUID
    let rewardCoconuts: Int
    let recurrenceRule: FamilyTaskRecurrenceRule
    let anchorAt: Date
    let startsAt: Date?
    let endsAt: Date?
    let timeZoneIdentifier: String
    let isAllDay: Bool
    let reminderLeadMinutes: Int?
    let eventTypeRaw: String
    let taskCareKindRaw: String
    /// Optimistic concurrency token for publisher edits. Creation drafts leave it nil.
    let expectedScheduleVersion: Int?

    init(
        title: String,
        note: String = "",
        emoji: String = "🎯",
        subjectKind: FamilyCollaborationTaskSubjectKind = .household,
        subjectID: UUID? = nil,
        subjectName: String = "",
        creatorID: UUID,
        assigneeID: UUID,
        rewardCoconuts: Int = 0,
        recurrenceRule: FamilyTaskRecurrenceRule,
        anchorAt: Date,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        isAllDay: Bool = true,
        reminderLeadMinutes: Int? = nil,
        eventTypeRaw: String = EventType.task.rawValue,
        taskCareKindRaw: String = "",
        expectedScheduleVersion: Int? = nil
    ) {
        self.title = title
        self.note = note
        self.emoji = emoji
        self.subjectKind = subjectKind
        self.subjectID = subjectID
        self.subjectName = subjectName
        self.creatorID = creatorID
        self.assigneeID = assigneeID
        self.rewardCoconuts = rewardCoconuts
        self.recurrenceRule = recurrenceRule
        self.anchorAt = anchorAt
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isAllDay = isAllDay
        self.reminderLeadMinutes = reminderLeadMinutes
        self.eventTypeRaw = eventTypeRaw
        self.taskCareKindRaw = taskCareKindRaw
        self.expectedScheduleVersion = expectedScheduleVersion
    }
}

nonisolated struct FamilyTaskMaterializationResult: Equatable, Sendable {
    let planID: UUID?
    let insertedOccurrenceCount: Int
    let skippedExistingCount: Int
    let summarizedMissedCount: Int
    let reminderIDs: [UUID]
}

nonisolated enum FamilyTaskPlanCommandError: LocalizedError, Equatable, Sendable {
    case invalidTitle
    case invalidRecurrence
    case invalidDateRange
    case invalidTimeZone
    case invalidParticipants
    case invalidSubject
    case invalidReward
    case planUnavailable
    case unauthorized
    case staleScheduleVersion
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidTitle: "A task title is required."
        case .invalidRecurrence: "The repeat rule is not valid."
        case .invalidDateRange: "The task schedule dates are not valid."
        case .invalidTimeZone: "The task time zone is not valid."
        case .invalidParticipants: "The publisher and assignee must be active, different household members."
        case .invalidSubject: "The task subject is not available."
        case .invalidReward: "The coconut reward is not valid."
        case .planUnavailable: "The recurring task plan is unavailable."
        case .unauthorized: "The current household member cannot change this plan."
        case .staleScheduleVersion: "The recurring task changed before this edit was saved."
        case let .persistenceFailed(reason): "The recurring task could not be saved: \(reason)"
        }
    }
}

/// A model actor is the sole rolling occurrence projector. Public methods
/// return value DTOs only; live SwiftData models never cross this boundary.
@ModelActor
actor FamilyTaskPlanMaterializationActor {
    nonisolated static let recentDayCount = 14
    nonisolated static let futureDayCount = 14
    nonisolated static let maximumOccurrencesPerPlan = 32
    private static let nextOccurrenceSearchDayCount = 400

    func createPlan(
        _ draft: FamilyTaskPlanDraft,
        now: Date = Date()
    ) throws -> FamilyTaskMaterializationResult {
        try Task.checkCancellation()
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { throw FamilyTaskPlanCommandError.invalidTitle }
        guard draft.recurrenceRule.isValid else { throw FamilyTaskPlanCommandError.invalidRecurrence }
        guard let timeZone = TimeZone(identifier: draft.timeZoneIdentifier) else {
            throw FamilyTaskPlanCommandError.invalidTimeZone
        }
        guard draft.endsAt == nil || draft.startsAt == nil || draft.endsAt! >= draft.startsAt! else {
            throw FamilyTaskPlanCommandError.invalidDateRange
        }
        guard let creator = try human(id: draft.creatorID),
              let assignee = try human(id: draft.assigneeID),
              creator.id != assignee.id,
              !creator.hasPassedAway,
              !assignee.hasPassedAway else {
            throw FamilyTaskPlanCommandError.invalidParticipants
        }
        let reward = FamilyTaskRewardPolicy.capped(draft.rewardCoconuts)
        guard reward == draft.rewardCoconuts else {
            throw FamilyTaskPlanCommandError.invalidReward
        }
        guard try subjectIsAvailable(kind: draft.subjectKind, id: draft.subjectID) else {
            throw FamilyTaskPlanCommandError.invalidSubject
        }

        let plan = FamilyTaskPlan(
            title: normalizedTitle,
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: draft.emoji,
            kind: reward > 0 ? .bounty : .householdTask,
            subjectKind: draft.subjectKind,
            subjectId: draft.subjectID?.uuidString,
            subjectName: draft.subjectName,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: reward,
            recurrenceRule: draft.recurrenceRule,
            anchorAt: draft.anchorAt,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            timeZoneIdentifier: timeZone.identifier,
            isAllDay: draft.isAllDay,
            reminderLeadMinutes: draft.reminderLeadMinutes,
            eventTypeRaw: draft.eventTypeRaw,
            taskCareKindRaw: draft.taskCareKindRaw,
            createdAt: now
        )
        modelContext.insert(plan)

        var result = try materialize(plan: plan, now: now)
        let firstTask = try firstTask(planID: plan.id)
        let activity = FamilyTaskActivity(
            planId: plan.id.uuidString,
            taskId: firstTask?.id.uuidString,
            occurrenceKey: firstTask?.occurrenceKey,
            kind: .assigned,
            actorHumanId: creator.id.uuidString,
            actorHumanName: creator.name,
            recipientHumanId: assignee.id.uuidString,
            taskTitleSnapshot: plan.title,
            idempotencyKey: "family-task-plan:\(plan.id.uuidString):assigned",
            createdAt: now
        )
        modelContext.insert(activity)

        try persistOrRollback()
        result = FamilyTaskMaterializationResult(
            planID: plan.id,
            insertedOccurrenceCount: result.insertedOccurrenceCount,
            skippedExistingCount: result.skippedExistingCount,
            summarizedMissedCount: result.summarizedMissedCount,
            reminderIDs: result.reminderIDs
        )
        return result
    }

    func materializeAll(
        now: Date = Date(),
        maximumPlanCount: Int = 200
    ) throws -> FamilyTaskMaterializationResult {
        try Task.checkCancellation()
        let active = FamilyTaskPlanStatus.active.rawValue
        var descriptor = FetchDescriptor<FamilyTaskPlan>(
            predicate: #Predicate<FamilyTaskPlan> { $0.statusRaw == active },
            sortBy: [SortDescriptor(\.updatedAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = min(200, max(1, maximumPlanCount))
        let plans = try modelContext.fetch(descriptor)
        var inserted = 0
        var skipped = 0
        var summarized = 0
        var reminderIDs: [UUID] = []

        for plan in plans {
            try Task.checkCancellation()
            let result = try materialize(plan: plan, now: now)
            inserted += result.insertedOccurrenceCount
            skipped += result.skippedExistingCount
            summarized += result.summarizedMissedCount
            reminderIDs.append(contentsOf: result.reminderIDs)
        }
        if modelContext.hasChanges {
            try persistOrRollback()
        }
        return FamilyTaskMaterializationResult(
            planID: nil,
            insertedOccurrenceCount: inserted,
            skippedExistingCount: skipped,
            summarizedMissedCount: summarized,
            reminderIDs: reminderIDs
        )
    }

    func materialize(
        planID: UUID,
        now: Date = Date()
    ) throws -> FamilyTaskMaterializationResult {
        guard let plan = try plan(id: planID), plan.status == .active else {
            throw FamilyTaskPlanCommandError.planUnavailable
        }
        let result = try materialize(plan: plan, now: now)
        if modelContext.hasChanges {
            try persistOrRollback()
        }
        return result
    }

    func materialize(
        plan: FamilyTaskPlan,
        now: Date
    ) throws -> FamilyTaskMaterializationResult {
        let calendar = Self.calendar(timeZone: plan.timeZone)
        let recentStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -Self.recentDayCount, to: now) ?? now
        )
        let futureEnd = calendar.date(byAdding: .day, value: Self.futureDayCount, to: now) ?? now
        let previouslyMaterializedThrough = plan.materializedThroughAt
        let effectiveLowerBound = max(
            recentStart,
            plan.startsAt ?? plan.createdAt
        )

        var occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: plan.id,
            scheduleVersion: plan.scheduleVersion,
            rule: plan.recurrenceRule,
            anchorAt: plan.anchorAt,
            startsAt: plan.startsAt,
            endsAt: plan.endsAt,
            from: effectiveLowerBound,
            through: futureEnd,
            timeZone: plan.timeZone,
            limit: Self.maximumOccurrencesPerPlan
        )
        if plan.startsAt == nil, plan.recurrenceRule != .once {
            occurrences.removeAll { $0.nominalAt < plan.createdAt }
        }

        if occurrences.count < Self.maximumOccurrencesPerPlan,
           let defaultSearchEnd = calendar.date(
               byAdding: .day,
               value: Self.nextOccurrenceSearchDayCount,
               to: futureEnd
           ), let afterWindow = calendar.date(byAdding: .day, value: 1, to: futureEnd) {
            var searchEnd = defaultSearchEnd
            if let startsAt = plan.startsAt,
               let afterStart = calendar.date(
                   byAdding: .day,
                   value: Self.nextOccurrenceSearchDayCount,
                   to: startsAt
               ) {
                searchEnd = max(searchEnd, afterStart)
            }
            if plan.recurrenceRule == .once {
                searchEnd = max(searchEnd, plan.anchorAt)
            }
            let next = FamilyTaskRecurrenceGenerator.occurrences(
                planID: plan.id,
                scheduleVersion: plan.scheduleVersion,
                rule: plan.recurrenceRule,
                anchorAt: plan.anchorAt,
                startsAt: plan.startsAt,
                endsAt: plan.endsAt,
                from: afterWindow,
                through: searchEnd,
                timeZone: plan.timeZone,
                limit: 1
            )
            occurrences.append(contentsOf: next)
        }

        let planID = plan.id.uuidString
        var existingDescriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { $0.planId == planID }
        )
        existingDescriptor.fetchLimit = 2000
        let existingTasks = try modelContext.fetch(existingDescriptor)
        var existingKeys = Set(existingTasks.compactMap(\.occurrenceKey))
        var inserted = 0
        var skipped = 0
        var reminderIDs: [UUID] = []

        for occurrence in occurrences.prefix(Self.maximumOccurrencesPerPlan) {
            try Task.checkCancellation()
            guard existingKeys.insert(occurrence.occurrenceKey).inserted else {
                skipped += 1
                continue
            }
            let reminderID = try materializeOccurrence(occurrence, plan: plan, now: now)
            if let reminderID { reminderIDs.append(reminderID) }
            inserted += 1
        }

        let summarized = try summarizeMissedOccurrences(
            plan: plan,
            existingTasks: existingTasks,
            existingOccurrenceKeys: existingKeys,
            previouslyMaterializedThrough: previouslyMaterializedThrough,
            before: recentStart,
            now: now
        )
        if let last = occurrences.last?.nominalAt {
            plan.materializedThroughAt = max(plan.materializedThroughAt ?? last, last)
        }
        if inserted > 0 || summarized > 0 {
            plan.updatedAt = now
        }
        return FamilyTaskMaterializationResult(
            planID: plan.id,
            insertedOccurrenceCount: inserted,
            skippedExistingCount: skipped,
            summarizedMissedCount: summarized,
            reminderIDs: reminderIDs
        )
    }

    private func materializeOccurrence(
        _ occurrence: FamilyTaskRecurrenceOccurrence,
        plan: FamilyTaskPlan,
        now: Date
    ) throws -> UUID? {
        let link = Self.subjectLink(kind: plan.subjectKind, id: plan.subjectId)
        let intent = DomainScheduleCreateIntent(
            title: plan.title,
            startDate: occurrence.nominalAt,
            endDate: nil,
            isAllDay: plan.isAllDay,
            eventType: plan.eventTypeRaw,
            relatedEntityType: link.rawType,
            relatedEntityId: link.rawId,
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: plan.reminderLeadMinutes,
            assigneeId: plan.assignedToId,
            taskCareKindRaw: plan.taskCareKindRaw,
            familyTaskPlanId: plan.id.uuidString,
            familyTaskOccurrenceKey: occurrence.occurrenceKey,
            writeKind: .collaboration,
            source: .domainService
        )
        guard let scheduleWrite = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: intent,
            context: modelContext
        ) else {
            throw FamilyTaskPlanCommandError.unauthorized
        }
        let schedule = DomainScheduleWriter.createEvent(
            plan: scheduleWrite,
            context: modelContext,
            calendar: Self.calendar(timeZone: plan.timeZone),
            maxReminderOccurrences: 1
        )
        let reminder = schedule.reminders.first
        let task = FamilyCollaborationTask(
            title: plan.title,
            note: plan.note,
            kind: plan.kind,
            subjectKind: plan.subjectKind,
            subjectId: plan.subjectId,
            relatedPetId: plan.subjectKind == .pet ? plan.subjectId : nil,
            relatedEventId: schedule.event.id.uuidString,
            relatedReminderId: reminder?.id.uuidString,
            planId: plan.id.uuidString,
            occurrenceKey: occurrence.occurrenceKey,
            nominalAt: occurrence.nominalAt,
            scheduleVersion: plan.scheduleVersion,
            createdById: plan.createdById,
            createdByName: plan.createdByName,
            assignedToId: plan.assignedToId,
            assignedToName: plan.assignedToName,
            rewardCoconuts: plan.rewardCoconuts,
            dueAt: occurrence.nominalAt,
            emoji: plan.emoji,
            createdAt: now
        )
        modelContext.insert(task)
        return reminder?.id
    }

    private func summarizeMissedOccurrences(
        plan: FamilyTaskPlan,
        existingTasks: [FamilyCollaborationTask],
        existingOccurrenceKeys: Set<String>,
        previouslyMaterializedThrough: Date?,
        before cutoff: Date,
        now: Date
    ) throws -> Int {
        let missed = existingTasks.filter { task in
            guard let nominalAt = task.nominalAt, nominalAt < cutoff else { return false }
            return task.status == .active || task.status == .claimed
        }
        for task in missed {
            task.status = .cancelled
            task.touch()
            if let reminder = try reminder(id: task.relatedReminderId), reminder.isPending {
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
            }
            if let event = try event(id: task.relatedEventId) {
                event.isCompleted = true
            }
        }
        let calendar = Self.calendar(timeZone: plan.timeZone)
        let virtualStart: Date = {
            guard let previouslyMaterializedThrough,
                  let nextDay = calendar.date(
                      byAdding: .day,
                      value: 1,
                      to: calendar.startOfDay(for: previouslyMaterializedThrough)
                  ) else {
                return plan.startsAt ?? plan.createdAt
            }
            return max(nextDay, plan.startsAt ?? plan.createdAt)
        }()
        let virtualEnd = calendar.date(byAdding: .day, value: -1, to: cutoff) ?? cutoff
        let virtualMissed: [FamilyTaskRecurrenceOccurrence] = if virtualStart <= virtualEnd {
            FamilyTaskRecurrenceGenerator.occurrences(
                planID: plan.id,
                scheduleVersion: plan.scheduleVersion,
                rule: plan.recurrenceRule,
                anchorAt: plan.anchorAt,
                startsAt: plan.startsAt,
                endsAt: plan.endsAt,
                from: virtualStart,
                through: virtualEnd,
                timeZone: plan.timeZone,
                limit: 20000
            ).filter { !existingOccurrenceKeys.contains($0.occurrenceKey) }
        } else {
            []
        }
        let missedCount = missed.count + virtualMissed.count
        guard missedCount > 0 else { return 0 }
        let latestNominal = max(
            missed.compactMap(\.nominalAt).max() ?? .distantPast,
            virtualMissed.last?.nominalAt ?? .distantPast
        )
        let key = FamilyTaskRecurrenceGenerator.occurrenceKey(
            planID: plan.id,
            scheduleVersion: plan.scheduleVersion,
            nominalAt: latestNominal,
            timeZone: plan.timeZone
        )
        let idempotencyKey = "family-task-plan:\(plan.id.uuidString):missed-summary:\(key)"
        if try !activityExists(idempotencyKey: idempotencyKey) {
            modelContext.insert(
                FamilyTaskActivity(
                    planId: plan.id.uuidString,
                    kind: .missedSummary,
                    actorHumanId: "",
                    actorHumanName: "",
                    recipientHumanId: plan.createdById,
                    taskTitleSnapshot: plan.title,
                    countValue: missedCount,
                    idempotencyKey: idempotencyKey,
                    createdAt: now
                )
            )
        }
        return missedCount
    }

    func human(id: UUID) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func plan(id: UUID) throws -> FamilyTaskPlan? {
        var descriptor = FetchDescriptor<FamilyTaskPlan>(predicate: #Predicate<FamilyTaskPlan> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func firstTask(planID: UUID) throws -> FamilyCollaborationTask? {
        let rawID = planID.uuidString
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { $0.planId == rawID },
            sortBy: [SortDescriptor(\.nominalAt)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func event(id rawID: String?) throws -> Event? {
        guard let rawID, let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func reminder(id rawID: String?) throws -> Reminder? {
        guard let rawID, let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate<Reminder> { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func activityExists(idempotencyKey: String) throws -> Bool {
        var descriptor = FetchDescriptor<FamilyTaskActivity>(
            predicate: #Predicate<FamilyTaskActivity> { $0.idempotencyKey == idempotencyKey }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    func subjectIsAvailable(
        kind: FamilyCollaborationTaskSubjectKind,
        id: UUID?
    ) throws -> Bool {
        switch kind {
        case .household:
            return id == nil
        case .human:
            guard let id, let human = try human(id: id) else { return false }
            return !human.hasPassedAway
        case .pet:
            guard let id else { return false }
            var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == id })
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first.map { !$0.hasPassedAway } ?? false
        case .plant:
            guard let id else { return false }
            var descriptor = FetchDescriptor<Plant>(predicate: #Predicate<Plant> { $0.id == id })
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first.map { !$0.isArchived } ?? false
        }
    }

    private func persistOrRollback() throws {
        let result = modelContext.safeSaveResult(publishFailureEvent: true)
        guard result.didSave else {
            modelContext.rollback()
            throw FamilyTaskPlanCommandError.persistenceFailed(result.errorDescription ?? "unknown error")
        }
    }

    private nonisolated static func subjectLink(
        kind: FamilyCollaborationTaskSubjectKind,
        id: String?
    ) -> DomainEntityLink {
        switch kind {
        case .household:
            DomainEntityLink(rawType: "", rawId: "")
        case .human:
            DomainEntityLink(rawType: EntityKind.human.rawValue, rawId: id ?? "")
        case .pet:
            DomainEntityLink(rawType: EntityKind.pet.rawValue, rawId: id ?? "")
        case .plant:
            DomainEntityLink(rawType: EntityKind.plant.rawValue, rawId: id ?? "")
        }
    }

    private nonisolated static func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
