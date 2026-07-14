//
//  TaskCareAssignmentCommands.swift
//  Ohana
//
//  Atomic creation boundary for a typed care schedule and its optional
//  household assignment projection.
//

import Foundation
import SwiftData

nonisolated struct TaskCareAssignmentCommand: Equatable, Sendable {
    let preset: TaskCreationPreset
    let title: String
    let startDate: Date
    let isAllDay: Bool
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let notificationLeadMinutes: Int?
    let creatorHumanID: UUID?
    let assigneeHumanID: UUID?
    let rewardCoconuts: Int

    init(
        preset: TaskCreationPreset,
        title: String,
        startDate: Date,
        isAllDay: Bool,
        recurrenceDays: Int = 0,
        recurrenceEndDate: Date? = nil,
        notificationLeadMinutes: Int? = nil,
        creatorHumanID: UUID? = nil,
        assigneeHumanID: UUID? = nil,
        rewardCoconuts: Int = 0
    ) {
        self.preset = preset
        self.title = title
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.recurrenceDays = max(0, recurrenceDays)
        self.recurrenceEndDate = recurrenceDays > 0 ? recurrenceEndDate : nil
        self.notificationLeadMinutes = notificationLeadMinutes.map { max(0, $0) }
        self.creatorHumanID = creatorHumanID
        self.assigneeHumanID = assigneeHumanID
        self.rewardCoconuts = FamilyTaskRewardPolicy.capped(rewardCoconuts)
    }

    var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct TaskCareAssignmentResult: Equatable, Sendable {
    let eventID: UUID
    let reminderIDs: [UUID]
    let familyTaskIDs: [UUID]
    let affectedSubjectID: UUID
    let scheduledNotifications: Bool
}

nonisolated enum TaskCareAssignmentError: LocalizedError, Equatable, Sendable {
    case invalidInput
    case unavailableSubject
    case unavailableAssignee
    case unauthorized
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            "照顾待办信息不完整。"
        case .unavailableSubject:
            "关联对象已不可用，请刷新后重试。"
        case .unavailableAssignee:
            "当前成员或执行人不可用。"
        case .unauthorized:
            "无法创建这项家庭分工。"
        case let .persistenceFailed(reason):
            reason.map { "保存照顾待办失败：\($0)" } ?? "保存照顾待办失败，请稍后重试。"
        }
    }
}

@MainActor
struct TaskCareAssignmentCommandExecutor {
    private static let maxOccurrences = 500

    let modelContext: ModelContext
    let services: AppServices

    func execute(
        _ command: TaskCareAssignmentCommand,
        scheduleNotifications: Bool
    ) throws -> TaskCareAssignmentResult {
        guard !command.cleanTitle.isEmpty,
              occurrenceDates(for: command).isEmpty == false else {
            throw TaskCareAssignmentError.invalidInput
        }
        guard subjectIsAvailable(command.preset) else {
            throw TaskCareAssignmentError.unavailableSubject
        }

        let collaboration = try collaborationMembers(for: command)
        let occurrenceDates = occurrenceDates(for: command)
        let reminderDates = occurrenceDates.map { occurrenceDate in
            Calendar.current.date(
                byAdding: .minute,
                value: -(command.notificationLeadMinutes ?? 0),
                to: occurrenceDate
            ) ?? occurrenceDate
        }
        let schedulePlan = try makeSchedulePlan(
            command,
            reminderDates: reminderDates,
            assignee: collaboration.assignee
        )
        let scheduleWrite = DomainScheduleWriter.createEvent(
            plan: schedulePlan,
            context: modelContext,
            maxReminderOccurrences: Self.maxOccurrences
        )
        guard scheduleWrite.reminders.count == occurrenceDates.count else {
            modelContext.rollback()
            throw TaskCareAssignmentError.persistenceFailed("reminder occurrence mismatch")
        }
        for (reminder, occurrenceDate) in zip(scheduleWrite.reminders, occurrenceDates) {
            reminder.occurrenceAt = occurrenceDate
        }
        let familyTasks: [FamilyCollaborationTask]
        do {
            familyTasks = try makeFamilyTasks(
                command,
                scheduleWrite: scheduleWrite,
                occurrenceDates: occurrenceDates,
                collaboration: collaboration
            )
        } catch {
            modelContext.rollback()
            throw error
        }

        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            modelContext.rollback()
            throw TaskCareAssignmentError.persistenceFailed(saveResult.errorDescription)
        }

        let shouldSchedule = scheduleNotifications && !scheduleWrite.reminders.isEmpty
        if shouldSchedule {
            Task { @MainActor in
                await services.reminderScheduling.scheduleManyIfNeeded(
                    reminders: scheduleWrite.reminders,
                    context: modelContext,
                    source: .calendar
                )
            }
        }
        publishCreated(
            scheduleWrite: scheduleWrite,
            familyTasks: familyTasks,
            subjectID: command.preset.subjectID,
            scheduledNotifications: shouldSchedule
        )
        return TaskCareAssignmentResult(
            eventID: scheduleWrite.event.id,
            reminderIDs: scheduleWrite.reminders.map(\.id),
            familyTaskIDs: familyTasks.map(\.id),
            affectedSubjectID: command.preset.subjectID,
            scheduledNotifications: shouldSchedule
        )
    }

    private func occurrenceDates(for command: TaskCareAssignmentCommand) -> [Date] {
        guard command.recurrenceDays > 0,
              let recurrenceEndDate = command.recurrenceEndDate else {
            return [command.startDate]
        }
        var dates: [Date] = []
        var cursor = command.startDate
        while cursor <= recurrenceEndDate, dates.count < Self.maxOccurrences {
            dates.append(cursor)
            guard let next = Calendar.current.date(
                byAdding: .day,
                value: command.recurrenceDays,
                to: cursor
            ), next > cursor else { break }
            cursor = next
        }
        return dates
    }

    private func makeSchedulePlan(
        _ command: TaskCareAssignmentCommand,
        reminderDates: [Date],
        assignee: Human?
    ) throws -> AuthorizedDomainScheduleWrite {
        let intent = DomainScheduleCreateIntent(
            title: command.cleanTitle,
            startDate: command.startDate,
            isAllDay: command.isAllDay,
            eventType: command.preset.careKind.eventType.rawValue,
            relatedEntityType: relatedEntityType(for: command.preset.subjectKind),
            relatedEntityId: command.preset.subjectID.uuidString,
            recurrenceDays: command.recurrenceDays,
            recurrenceEndDate: command.recurrenceEndDate,
            reminderDates: reminderDates,
            assigneeId: assignee?.id.uuidString,
            taskCareKindRaw: command.preset.careKind.rawValue,
            writeKind: .care,
            source: .userCommand
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: intent,
            context: modelContext
        ) else {
            throw TaskCareAssignmentError.unauthorized
        }
        return plan
    }

    private func makeFamilyTasks(
        _ command: TaskCareAssignmentCommand,
        scheduleWrite: DomainScheduleWriteResult,
        occurrenceDates: [Date],
        collaboration: CollaborationMembers
    ) throws -> [FamilyCollaborationTask] {
        guard let creator = collaboration.creator,
              let assignee = collaboration.assignee,
              creator.id != assignee.id else {
            return []
        }
        guard let funding = FamilyTaskFundingPolicy.resolve(
            createdById: creator.id.uuidString,
            assignedTo: assignee,
            rewardCoconuts: command.rewardCoconuts,
            context: modelContext
        ) else {
            throw TaskCareAssignmentError.unavailableAssignee
        }
        let totalReward = funding.reward.multipliedReportingOverflow(by: occurrenceDates.count)
        guard !totalReward.overflow,
              totalReward.partialValue == 0 ||
              CoconutWalletService.balance(for: funding.creator, context: modelContext) >= totalReward.partialValue else {
            throw TaskCareAssignmentError.unavailableAssignee
        }
        return try zip(scheduleWrite.reminders, occurrenceDates).map { pair in
            try makeFamilyTask(
                command,
                event: scheduleWrite.event,
                reminder: pair.0,
                dueAt: pair.1,
                creator: creator,
                assignee: assignee
            )
        }
    }

    private func makeFamilyTask(
        _ command: TaskCareAssignmentCommand,
        event: Event,
        reminder: Reminder,
        dueAt: Date,
        creator: Human,
        assignee: Human
    ) throws -> FamilyCollaborationTask {
        let request = DomainSubjectResolutionRequest(
            relatedEntityType: relatedEntityType(for: command.preset.subjectKind),
            relatedEntityId: command.preset.subjectID.uuidString,
            assigneeId: assignee.id.uuidString
        )
        guard let plan = services.familyTasks.authorizeCollaborationWrite(
            subjectRequest: request,
            actor: creator,
            occurredAt: Date(),
            context: modelContext,
            logPrefix: "TaskCareAssignmentCommandExecutor"
        ) else {
            throw TaskCareAssignmentError.unauthorized
        }
        let subjectKind: FamilyCollaborationTaskSubjectKind = switch command.preset.subjectKind {
        case .pet: .pet
        case .plant: .plant
        }
        return DomainMemberFactWriter.createFamilyTask(
            plan: plan,
            title: command.cleanTitle,
            kind: command.rewardCoconuts > 0 ? .bounty : .careReminder,
            subjectKind: subjectKind,
            subjectId: command.preset.subjectID.uuidString,
            relatedPetId: subjectKind == .pet ? command.preset.subjectID.uuidString : nil,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: command.rewardCoconuts,
            dueAt: dueAt,
            emoji: command.preset.careKind.defaultEmoji,
            context: modelContext
        )
    }

    private func collaborationMembers(for command: TaskCareAssignmentCommand) throws -> CollaborationMembers {
        let creator = command.creatorHumanID.flatMap(fetchActiveHuman)
        let assignee = command.assigneeHumanID.flatMap(fetchActiveHuman)
        if command.creatorHumanID != nil, creator == nil {
            throw TaskCareAssignmentError.unavailableAssignee
        }
        if command.assigneeHumanID != nil, assignee == nil {
            throw TaskCareAssignmentError.unavailableAssignee
        }
        if command.rewardCoconuts > 0,
           creator?.id == assignee?.id || creator == nil || assignee == nil {
            throw TaskCareAssignmentError.unavailableAssignee
        }
        return CollaborationMembers(creator: creator, assignee: assignee)
    }

    private func fetchActiveHuman(id: UUID) -> Human? {
        let humanID = id
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in human.id == humanID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first(where: { !$0.hasPassedAway })
    }

    private func subjectIsAvailable(_ preset: TaskCreationPreset) -> Bool {
        switch preset.subjectKind {
        case .pet:
            let subjectID = preset.subjectID
            var descriptor = FetchDescriptor<Pet>(
                predicate: #Predicate<Pet> { pet in pet.id == subjectID }
            )
            descriptor.fetchLimit = 1
            return (try? modelContext.fetch(descriptor).first(where: { !$0.hasPassedAway })) != nil
        case .plant:
            guard PlantFeatureGate.allows(.plants) else { return false }
            let subjectID = preset.subjectID
            var descriptor = FetchDescriptor<Plant>(
                predicate: #Predicate<Plant> { plant in plant.id == subjectID }
            )
            descriptor.fetchLimit = 1
            return (try? modelContext.fetch(descriptor).first(where: { !$0.isArchived })) != nil
        }
    }

    private func relatedEntityType(for subjectKind: TaskCreationSubjectKind) -> String {
        switch subjectKind {
        case .pet: EntityKind.pet.rawValue
        case .plant: EntityKind.plant.rawValue
        }
    }

    private func publishCreated(
        scheduleWrite: DomainScheduleWriteResult,
        familyTasks: [FamilyCollaborationTask],
        subjectID: UUID,
        scheduledNotifications: Bool
    ) {
        services.domainRevisions.publishCalendarEventPlan(
            CalendarEventPlanCommandResult(
                eventID: scheduleWrite.event.id,
                reminderIDs: scheduleWrite.reminders.map(\.id),
                affectedSubjectIDs: [subjectID],
                scheduledReminderSync: scheduledNotifications
            ),
            note: "task.care_assignment.created"
        )
        for task in familyTasks {
            services.domainRevisions.publishFamilyTask(.create(taskID: task.id), wroteBusinessFact: true)
        }
    }

    private struct CollaborationMembers {
        let creator: Human?
        let assignee: Human?
    }
}
