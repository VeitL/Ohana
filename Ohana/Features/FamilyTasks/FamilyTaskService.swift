//
//  FamilyTaskService.swift
//  Ohana
//
//  Canonical write path for family collaboration tasks.
//

import Foundation
import SwiftData

/// `ModelContext.rollback()` discards pending persistence work, but SwiftData
/// keeps already-mutated model instances alive for the current render pass.
/// Commands restore their occurrence object before rolling the context back so
/// a failed atomic write cannot leak a transient state into role capabilities
/// or the visible task detail.
struct FamilyTaskStateRollbackSnapshot {
    let title: String
    let note: String
    let kindRaw: String
    let statusRaw: String
    let subjectKindRaw: String
    let subjectId: String?
    let relatedPetId: String?
    let relatedEventId: String?
    let relatedReminderId: String?
    let planId: String?
    let occurrenceKey: String?
    let nominalAt: Date?
    let scheduleVersion: Int
    let createdById: String
    let createdByName: String
    let assignedToId: String?
    let assignedToName: String?
    let claimedById: String?
    let claimedByName: String?
    let completedById: String?
    let completedByName: String?
    let rewardCoconuts: Int
    let dueAt: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let emoji: String

    @MainActor
    init(task: FamilyCollaborationTask) {
        title = task.title
        note = task.note
        kindRaw = task.kindRaw
        statusRaw = task.statusRaw
        subjectKindRaw = task.subjectKindRaw
        subjectId = task.subjectId
        relatedPetId = task.relatedPetId
        relatedEventId = task.relatedEventId
        relatedReminderId = task.relatedReminderId
        planId = task.planId
        occurrenceKey = task.occurrenceKey
        nominalAt = task.nominalAt
        scheduleVersion = task.scheduleVersion
        createdById = task.createdById
        createdByName = task.createdByName
        assignedToId = task.assignedToId
        assignedToName = task.assignedToName
        claimedById = task.claimedById
        claimedByName = task.claimedByName
        completedById = task.completedById
        completedByName = task.completedByName
        rewardCoconuts = task.rewardCoconuts
        dueAt = task.dueAt
        completedAt = task.completedAt
        createdAt = task.createdAt
        updatedAt = task.updatedAt
        emoji = task.emoji
    }

    @MainActor
    func restore(_ task: FamilyCollaborationTask) {
        task.title = title
        task.note = note
        task.kindRaw = kindRaw
        task.statusRaw = statusRaw
        task.subjectKindRaw = subjectKindRaw
        task.subjectId = subjectId
        task.relatedPetId = relatedPetId
        task.relatedEventId = relatedEventId
        task.relatedReminderId = relatedReminderId
        task.planId = planId
        task.occurrenceKey = occurrenceKey
        task.nominalAt = nominalAt
        task.scheduleVersion = scheduleVersion
        task.createdById = createdById
        task.createdByName = createdByName
        task.assignedToId = assignedToId
        task.assignedToName = assignedToName
        task.claimedById = claimedById
        task.claimedByName = claimedByName
        task.completedById = completedById
        task.completedByName = completedByName
        task.rewardCoconuts = rewardCoconuts
        task.dueAt = dueAt
        task.completedAt = completedAt
        task.createdAt = createdAt
        task.updatedAt = updatedAt
        task.emoji = emoji
    }

    @MainActor
    func rollback(_ task: FamilyCollaborationTask, context: ModelContext) {
        restore(task)
        context.rollback()
    }
}

struct FamilyTaskScheduleRollbackSnapshot {
    private struct EventState {
        let event: Event
        let title: String
        let startDate: Date
        let endDate: Date?
        let isAllDay: Bool
        let eventType: String
        let relatedEntityType: String
        let relatedEntityId: String
        let recurrenceDays: Int
        let recurrenceEndDate: Date?
        let isCompleted: Bool
        let completedOccurrences: [String]
        let assigneeId: String?
        let taskCareKindRaw: String
        let familyTaskPlanId: String?
        let familyTaskOccurrenceKey: String?

        @MainActor
        init(event: Event) {
            self.event = event
            title = event.title
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            eventType = event.eventType
            relatedEntityType = event.relatedEntityType
            relatedEntityId = event.relatedEntityId
            recurrenceDays = event.recurrenceDays
            recurrenceEndDate = event.recurrenceEndDate
            isCompleted = event.isCompleted
            completedOccurrences = event.completedOccurrences
            assigneeId = event.assigneeId
            taskCareKindRaw = event.taskCareKindRaw
            familyTaskPlanId = event.familyTaskPlanId
            familyTaskOccurrenceKey = event.familyTaskOccurrenceKey
        }

        @MainActor
        func restore() {
            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = isAllDay
            event.eventType = eventType
            event.relatedEntityType = relatedEntityType
            event.relatedEntityId = relatedEntityId
            event.recurrenceDays = recurrenceDays
            event.recurrenceEndDate = recurrenceEndDate
            event.isCompleted = isCompleted
            event.completedOccurrences = completedOccurrences
            event.assigneeId = assigneeId
            event.taskCareKindRaw = taskCareKindRaw
            event.familyTaskPlanId = familyTaskPlanId
            event.familyTaskOccurrenceKey = familyTaskOccurrenceKey
        }
    }

    private struct ReminderState {
        let reminder: Reminder
        let occurrenceAt: Date?
        let scheduledAt: Date
        let status: String
        let completedAt: Date?
        let completedBy: String

        @MainActor
        init(reminder: Reminder) {
            self.reminder = reminder
            occurrenceAt = reminder.occurrenceAt
            scheduledAt = reminder.scheduledAt
            status = reminder.status
            completedAt = reminder.completedAt
            completedBy = reminder.completedBy
        }

        @MainActor
        func restore() {
            DomainScheduleWriter.restoreUncommittedReminder(
                reminder,
                occurrenceAt: occurrenceAt,
                scheduledAt: scheduledAt,
                status: status,
                completedAt: completedAt,
                completedBy: completedBy
            )
        }
    }

    private let eventState: EventState?
    private let reminderState: ReminderState?

    @MainActor
    init(reminder: Reminder?, event: Event?) {
        reminderState = reminder.map(ReminderState.init)
        eventState = (event ?? reminder?.event).map(EventState.init)
    }

    @MainActor
    func restore() {
        reminderState?.restore()
        eventState?.restore()
    }
}

struct FamilyTaskCommandRollbackSnapshot {
    private let taskState: FamilyTaskStateRollbackSnapshot
    private let scheduleState: FamilyTaskScheduleRollbackSnapshot

    @MainActor
    init(task: FamilyCollaborationTask, reminder: Reminder? = nil, event: Event? = nil) {
        taskState = FamilyTaskStateRollbackSnapshot(task: task)
        scheduleState = FamilyTaskScheduleRollbackSnapshot(reminder: reminder, event: event)
    }

    @MainActor
    func rollback(_ task: FamilyCollaborationTask, context: ModelContext) {
        taskState.restore(task)
        scheduleState.restore()
        context.rollback()
    }
}

private struct FamilyTaskRewardRollbackSnapshot {
    private struct HumanBalance {
        let human: Human
        let value: Int
    }

    private struct AccountBalance {
        let account: CoconutAccount
        let value: Int
        let updatedAt: Date
    }

    let task: FamilyTaskStateRollbackSnapshot
    private let schedule: FamilyTaskScheduleRollbackSnapshot
    private let humanBalances: [HumanBalance]
    private let accountBalances: [AccountBalance]

    @MainActor
    init(
        task: FamilyCollaborationTask,
        humans: [Human],
        reminder: Reminder?,
        event: Event?,
        context: ModelContext
    ) {
        self.task = FamilyTaskStateRollbackSnapshot(task: task)
        schedule = FamilyTaskScheduleRollbackSnapshot(reminder: reminder, event: event)

        var seenHumanIDs = Set<UUID>()
        let uniqueHumans = humans.filter { seenHumanIDs.insert($0.id).inserted }
        humanBalances = uniqueHumans.map { HumanBalance(human: $0, value: $0.coconutBalance) }

        var snapshots: [AccountBalance] = []
        for human in uniqueHumans {
            let accountKey = CoconutAccountKey.human(human.id)
            var descriptor = FetchDescriptor<CoconutAccount>(
                predicate: #Predicate<CoconutAccount> { account in
                    account.accountKey == accountKey
                }
            )
            descriptor.fetchLimit = 1
            if let account = try? context.fetch(descriptor).first {
                snapshots.append(
                    AccountBalance(
                        account: account,
                        value: account.balance,
                        updatedAt: account.updatedAt
                    )
                )
            }
        }
        accountBalances = snapshots
    }

    @MainActor
    func rollback(_ occurrence: FamilyCollaborationTask, context: ModelContext) {
        task.restore(occurrence)
        schedule.restore()
        CoconutWalletService.restoreUncommittedBalances(
            humans: humanBalances.map { ($0.human, $0.value) },
            accounts: accountBalances.map { ($0.account, $0.value, $0.updatedAt) }
        )
        context.rollback()
    }
}

enum FamilyTaskService {
    nonisolated static let rewardCap = FamilyTaskRewardPolicy.cap

    private struct AuthorizedReminderAssigneeUpdate {
        let event: Event
        let intent: DomainScheduleCreateIntent
        let mutation: AuthorizedDomainScheduleMutation
    }

    private struct PendingFamilyTaskReminderSchedule {
        let reminder: Reminder
        let careLedger: CareLedgerRecording
        let context: ModelContext

        @MainActor
        func run() {
            let reminderScheduling = ReminderSchedulingManager(careLedger: careLedger)
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
    }

    private struct FamilyTaskRewardTransferPreparation {
        let didPrepare: Bool
        let projectionEntries: [CoconutLedgerEntry]

        static let preparedWithoutProjection = FamilyTaskRewardTransferPreparation(
            didPrepare: true,
            projectionEntries: []
        )

        static let failed = FamilyTaskRewardTransferPreparation(
            didPrepare: false,
            projectionEntries: []
        )
    }

    private struct TaskUpdatePriorState {
        let updatedAt: Date
        let assigneeID: String?
        let claimedID: String?
        let status: FamilyCollaborationTaskStatus
        let dueAt: Date?

        @MainActor
        init(task: FamilyCollaborationTask) {
            updatedAt = task.updatedAt
            assigneeID = task.assignedToId
            claimedID = task.claimedById
            status = task.status
            dueAt = task.dueAt
        }
    }

    private struct TaskUpdateFollowUp {
        let isValid: Bool
        let pendingSchedule: PendingFamilyTaskReminderSchedule?
    }
}

extension FamilyTaskService {
    @MainActor
    static func persistMutation(
        context: ModelContext,
        onSuccess: () -> Void = {},
        onFailure: () -> Void = {}
    ) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            onFailure()
            return false
        }
        onSuccess()
        return true
    }

    private static func actorOverride(for human: Human?) -> EconomyRewardOwnerResolution? {
        guard let human else { return nil }
        let humanId = human.id.uuidString
        return EconomyRewardOwnerResolution(
            requestedExecutorId: humanId,
            effectiveExecutorId: humanId,
            rewardExecutorId: humanId,
            usedFallback: false
        )
    }

    @MainActor
    static func authorizedCollaborationWrite(
        subjectRequest: DomainSubjectResolutionRequest,
        actor: Human?,
        occurredAt: Date = Date(),
        context: ModelContext,
        logPrefix: String = "FamilyTaskService"
    ) -> AuthorizedDomainMemberFactWrite? {
        DomainMemberFactWriteAuthorizer.authorizeSubjectFact(
            subjectRequest: subjectRequest,
            occurredAt: occurredAt,
            writeKind: .collaboration,
            source: .domainService,
            executorId: actor?.id.uuidString,
            unresolvedAssigneePolicy: .drop,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actorOverride(for: actor)
        )
    }

    @MainActor
    static func assignReminder(
        _ reminder: Reminder,
        to human: Human,
        by creator: Human?,
        rewardCoconuts: Int,
        note: String = "",
        context: ModelContext
    ) -> FamilyCollaborationTask? {
        guard let funding = FamilyTaskFundingPolicy.resolve(
            createdById: creator?.id.uuidString,
            assignedTo: human,
            rewardCoconuts: rewardCoconuts,
            context: context
        ),
              reminderTargetsWritableMember(reminder, context: context) else {
            return nil
        }
        let assigneeUpdate: AuthorizedReminderAssigneeUpdate?
        if let event = reminder.event {
            guard let update = authorizedReminderAssigneeUpdate(
                event: event,
                assigneeId: human.id.uuidString,
                context: context
            ) else { return nil }
            assigneeUpdate = update
        } else {
            assigneeUpdate = nil
        }

        let existing = activeTask(forReminderId: reminder.id.uuidString, context: context)
        let subject = taskSubject(for: reminder, context: context)
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(
                for: reminder,
                assigneeId: human.id.uuidString,
                context: context
            ),
            actor: funding.creator,
            context: context
        ) else { return nil }
        let taskTitle = reminderTaskTitle(for: reminder)
        let reward = funding.reward
        let task: FamilyCollaborationTask
        if let existing {
            task = existing
            DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
                task.kind = reward > 0 ? .bounty : .careReminder
                task.title = taskTitle
                task.note = note
                task.status = .active
                task.setSubject(kind: subject.kind, id: subject.subjectId)
                task.relatedEventId = reminder.event?.id.uuidString
                task.relatedReminderId = reminder.id.uuidString
                task.createdById = funding.creator.id.uuidString
                task.createdByName = funding.creator.name
                task.assignedToId = human.id.uuidString
                task.assignedToName = human.name
                task.rewardCoconuts = reward
                task.dueAt = reminder.resolvedOccurrenceAt
                task.completedAt = nil
                task.completedById = nil
                task.completedByName = nil
                task.touch()
            }
        } else {
            task = DomainMemberFactWriter.createFamilyTask(
                plan: write,
                title: taskTitle,
                note: note,
                kind: reward > 0 ? .bounty : .careReminder,
                subjectKind: subject.kind,
                subjectId: subject.subjectId,
                relatedPetId: subject.relatedPetId,
                relatedEventId: reminder.event?.id.uuidString,
                relatedReminderId: reminder.id.uuidString,
                createdById: funding.creator.id.uuidString,
                createdByName: funding.creator.name,
                assignedToId: human.id.uuidString,
                assignedToName: human.name,
                rewardCoconuts: reward,
                dueAt: reminder.resolvedOccurrenceAt,
                emoji: reminder.event?.emoji ?? "🐾",
                context: context
            )
        }

        if let assigneeUpdate {
            guard DomainScheduleWriter.updateEvent(
                assigneeUpdate.event,
                intent: assigneeUpdate.intent,
                mutation: assigneeUpdate.mutation
            ) else {
                context.rollback()
                return nil
            }
        }
        guard FamilyTaskActivityService.stage(
            kind: .assigned,
            task: task,
            actor: funding.creator,
            recipientHumanID: human.id.uuidString,
            idempotencyKey: "family-task:\(task.id.uuidString):assigned:\(task.updatedAt.timeIntervalSinceReferenceDate.bitPattern)",
            context: context
        ) else {
            context.rollback()
            return nil
        }
        return persistMutation(context: context) ? task : nil
    }

    private static func authorizedReminderAssigneeUpdate(
        event: Event,
        assigneeId: String,
        context: ModelContext
    ) -> AuthorizedReminderAssigneeUpdate? {
        let intent = DomainScheduleCreateIntent(
            event: event,
            assigneeOverride: .set(assigneeId),
            writeKind: .collaboration,
            source: .domainService
        )
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
            event: event,
            intent: intent,
            writeKind: .collaboration,
            context: context
        ) else { return nil }
        return AuthorizedReminderAssigneeUpdate(
            event: event,
            intent: intent,
            mutation: mutation
        )
    }

    @MainActor
    private static func reminderTaskTitle(for reminder: Reminder) -> String {
        let l = L10n()
        guard let event = reminder.event else {
            return l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe")
        }
        return FeedRuleMetadata.localizedTitle(for: event, l: l)
    }

    @MainActor
    static func createHouseholdTask(
        title: String,
        note: String,
        assignedTo human: Human?,
        by creator: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    ) -> FamilyCollaborationTask? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty,
              let human,
              let funding = FamilyTaskFundingPolicy.resolve(
                  createdById: creator?.id.uuidString,
                  assignedTo: human,
                  rewardCoconuts: rewardCoconuts,
                  context: context
              ) else { return nil }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: householdTaskSubjectRequest(assigneeId: human.id.uuidString),
            actor: funding.creator,
            context: context
        ) else { return nil }

        let task = DomainMemberFactWriter.createFamilyTask(
            plan: write,
            title: normalizedTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: funding.reward > 0 ? .bounty : .householdTask,
            createdById: funding.creator.id.uuidString,
            createdByName: funding.creator.name,
            assignedToId: human.id.uuidString,
            assignedToName: human.name,
            rewardCoconuts: funding.reward,
            dueAt: dueAt,
            emoji: emoji,
            context: context
        )
        guard FamilyTaskActivityService.stage(
            kind: .assigned,
            task: task,
            actor: funding.creator,
            recipientHumanID: human.id.uuidString,
            idempotencyKey: "family-task:\(task.id.uuidString):assigned:\(task.createdAt.timeIntervalSinceReferenceDate.bitPattern)",
            context: context
        ) else {
            context.rollback()
            return nil
        }
        return persistMutation(context: context) ? task : nil
    }

    @MainActor
    @discardableResult
    static func updateTask(
        _ task: FamilyCollaborationTask,
        title: String,
        note: String,
        assignedTo human: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        by editor: Human?,
        context: ModelContext
    ) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let reward = cappedReward(rewardCoconuts)
        let prior = TaskUpdatePriorState(task: task)
        guard let write = authorizeTaskUpdate(
            task,
            normalizedTitle: normalizedTitle,
            assignee: human,
            reward: reward,
            editor: editor,
            context: context
        ) else { return false }
        let linkedReminder = reminder(for: task, context: context)
        let linkedEvent = linkedReminder?.event ?? linkedEvent(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedEvent
        )
        guard updateLinkedSchedule(
            for: task,
            title: normalizedTitle,
            assignee: human,
            dueAt: dueAt,
            priorDueAt: prior.dueAt,
            reminder: linkedReminder,
            event: linkedEvent,
            context: context
        ) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        applyTaskUpdate(
            task,
            write: write,
            title: normalizedTitle,
            note: note,
            assignee: human,
            reward: reward,
            dueAt: dueAt,
            emoji: emoji,
            context: context
        )
        let followUp = taskUpdateFollowUp(
            task: task,
            prior: prior,
            dueAt: dueAt,
            reminder: linkedReminder,
            editor: editor,
            write: write,
            context: context
        )
        guard followUp.isValid,
              stageTaskEditActivities(task, prior: prior, editor: editor, context: context) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }
        return persistMutation(
            context: context,
            onSuccess: { followUp.pendingSchedule?.run() },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @MainActor
    private static func authorizeTaskUpdate(
        _ task: FamilyCollaborationTask,
        normalizedTitle: String,
        assignee: Human?,
        reward: Int,
        editor: Human?,
        context: ModelContext
    ) -> AuthorizedDomainMemberFactWrite? {
        let hasValidFunding = if task.planId != nil {
            assignee != nil
        } else {
            FamilyTaskFundingPolicy.resolve(
                createdById: task.createdById,
                assignedTo: assignee,
                rewardCoconuts: reward,
                context: context
            ) != nil
        }
        guard !normalizedTitle.isEmpty,
              editor?.id.uuidString == task.createdById,
              hasValidFunding,
              canWriteCollaboration(for: assignee),
              canWriteSubject(for: task, context: context),
              canWriteCollaboration(forHumanId: task.createdById, context: context),
              canWriteCollaboration(forHumanId: task.claimedById, context: context) else {
            return nil
        }
        return authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(
                for: task,
                assigneeId: assignee?.id.uuidString,
                context: context
            ),
            actor: editor,
            context: context
        )
    }

    @MainActor
    private static func updateLinkedSchedule(
        for task: FamilyCollaborationTask,
        title: String,
        assignee: Human?,
        dueAt: Date?,
        priorDueAt: Date?,
        reminder: Reminder?,
        event: Event?,
        context: ModelContext
    ) -> Bool {
        if let event, task.planId != nil || event.recurrenceDays <= 0 {
            let intent = DomainScheduleCreateIntent(
                title: title,
                startDate: dueAt ?? event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                eventType: event.eventType,
                relatedEntityType: event.relatedEntityType,
                relatedEntityId: event.relatedEntityId,
                recurrenceDays: event.recurrenceDays,
                recurrenceEndDate: event.recurrenceEndDate,
                assigneeId: assignee?.id.uuidString,
                taskCareKindRaw: event.taskCareKindRaw,
                familyTaskPlanId: event.familyTaskPlanId,
                familyTaskOccurrenceKey: event.familyTaskOccurrenceKey,
                writeKind: .collaboration,
                source: .domainService
            )
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
                event: event,
                intent: intent,
                writeKind: .collaboration,
                source: .domainService,
                context: context
            ), DomainScheduleWriter.updateEvent(event, intent: intent, mutation: mutation) else {
                return false
            }
        }
        guard let reminder, let priorDueAt, let dueAt, priorDueAt != dueAt else { return true }
        let lead = max(0, priorDueAt.timeIntervalSince(reminder.scheduledAt))
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .collaboration,
            source: .domainService,
            context: context
        ) else { return false }
        return DomainScheduleWriter.rescheduleReminderDelivery(
            reminder,
            scheduledAt: dueAt.addingTimeInterval(-lead),
            mutation: mutation,
            modifiedAt: Date(),
            context: context
        )
    }

    @MainActor
    private static func applyTaskUpdate(
        _ task: FamilyCollaborationTask,
        write: AuthorizedDomainMemberFactWrite,
        title: String,
        note: String,
        assignee: Human?,
        reward: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    ) {
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            let assigneeChanged = task.assignedToId != assignee?.id.uuidString
            task.title = title
            task.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            task.assignedToId = assignee?.id.uuidString
            task.assignedToName = assignee?.name
            task.rewardCoconuts = reward
            task.kind = task.relatedReminderId == nil
                ? (reward > 0 ? .bounty : .householdTask)
                : (reward > 0 ? .bounty : .careReminder)
            task.dueAt = dueAt
            task.emoji = emoji
            if assigneeChanged {
                task.claimedById = nil
                task.claimedByName = nil
                task.status = .active
                task.completedAt = nil
                task.completedById = nil
                task.completedByName = nil
            } else if task.status == .pendingReview || task.status == .declined {
                task.status = task.claimedById == nil ? .active : .claimed
                task.completedAt = nil
                task.completedById = nil
                task.completedByName = nil
            }
            task.touch()
        }
    }

    @MainActor
    private static func taskUpdateFollowUp(
        task: FamilyCollaborationTask,
        prior: TaskUpdatePriorState,
        dueAt: Date?,
        reminder: Reminder?,
        editor: Human?,
        write: AuthorizedDomainMemberFactWrite,
        context: ModelContext
    ) -> TaskUpdateFollowUp {
        if prior.status == .pendingReview || prior.status == .declined {
            if let reminder, !reminder.isPending {
                return TaskUpdateFollowUp(
                    isValid: true,
                    pendingSchedule: reopenRelatedReminder(
                        reminder,
                        by: editor?.id.uuidString,
                        plan: write,
                        context: context,
                        careLedger: CareLedgerService()
                    )
                )
            }
            guard reminder != nil || setLinkedEventCompletion(
                for: task,
                isCompleted: false,
                modifiedAt: Date(),
                context: context
            ) else {
                return TaskUpdateFollowUp(isValid: false, pendingSchedule: nil)
            }
        } else if prior.dueAt != dueAt, let reminder {
            return TaskUpdateFollowUp(
                isValid: true,
                pendingSchedule: PendingFamilyTaskReminderSchedule(
                    reminder: reminder,
                    careLedger: CareLedgerService(),
                    context: context
                )
            )
        }
        return TaskUpdateFollowUp(isValid: true, pendingSchedule: nil)
    }

    @MainActor
    private static func stageTaskEditActivities(
        _ task: FamilyCollaborationTask,
        prior: TaskUpdatePriorState,
        editor: Human?,
        context: ModelContext
    ) -> Bool {
        let recipients = Set([prior.assigneeID, prior.claimedID, task.assignedToId].compactMap(\.self))
        for recipient in recipients where recipient != editor?.id.uuidString {
            guard FamilyTaskActivityService.stage(
                kind: .edited,
                task: task,
                actor: editor,
                recipientHumanID: recipient,
                idempotencyKey: "\(FamilyTaskActivityService.transitionKey(task: task, action: "edited", priorUpdatedAt: prior.updatedAt)):\(recipient)",
                context: context
            ) else { return false }
        }
        return true
    }

    @MainActor
    static func canClaim(
        _ task: FamilyCollaborationTask,
        by human: Human,
        context: ModelContext
    ) -> Bool {
        guard task.isOpen,
              canWriteCollaboration(for: human),
              canWriteSubject(for: task, context: context) else {
            return false
        }
        return authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(
                for: task,
                assigneeId: human.id.uuidString,
                context: context
            ),
            actor: human,
            context: context,
            logPrefix: "FamilyTask.claimPreflight"
        ) != nil
    }

    @MainActor
    @discardableResult
    static func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) -> Bool {
        guard canClaim(task, by: human, context: context) else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return false }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.claimedById = human.id.uuidString
            task.claimedByName = human.name
            task.status = .claimed
            task.touch()
        }
        return persistMutation(context: context)
    }

    /// Read-only guard for callers that must validate the collaboration half
    /// before recording an Event-backed care fact.
    @MainActor
    static func canComplete(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext
    ) -> Bool {
        if task.hasReward {
            return canSubmitForReview(task, by: human, context: context)
        }
        return passesCompletionPreflight(task, by: human, context: context)
    }

    /// Read-only counterpart of `submitForReview`; it never consumes an
    /// authorization or mutates task/reminder/ledger state.
    @MainActor
    static func canSubmitForReview(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext
    ) -> Bool {
        passesCompletionPreflight(task, by: human, context: context)
    }

    @MainActor
    private static func passesCompletionPreflight(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext
    ) -> Bool {
        guard !task.isFinished,
              canPerform(task, human: human),
              canWriteCollaboration(for: human),
              canWriteSubject(for: task, context: context) else {
            return false
        }
        return authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(
                for: task,
                assigneeId: human?.id.uuidString,
                context: context
            ),
            actor: human,
            context: context,
            logPrefix: "FamilyTask.preflight"
        ) != nil
    }

    @MainActor
    @discardableResult
    static func complete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) -> Bool {
        complete(
            task,
            by: human,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
    }

    @MainActor
    @discardableResult
    static func complete(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext,
        wallet _: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager _: QuestManager? = nil
    ) -> Bool {
        guard canWriteCollaboration(for: human),
              canComplete(task, by: human, context: context) else { return false }
        if task.hasReward {
            return submitForReview(task, by: human, context: context, careLedger: careLedger)
        }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human?.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return false }
        let linkedReminder = reminder(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedReminder?.event ?? linkedEvent(for: task, context: context)
        )
        let priorUpdatedAt = task.updatedAt
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .completed
            task.completedAt = Date()
            task.completedById = human?.id.uuidString
            task.completedByName = human?.name
            task.touch()
        }
        guard FamilyTaskActivityService.stage(
            kind: .completed,
            task: task,
            actor: human,
            recipientHumanID: task.createdById,
            idempotencyKey: FamilyTaskActivityService.transitionKey(
                task: task,
                action: "completed",
                priorUpdatedAt: priorUpdatedAt
            ),
            context: context
        ) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }

        var notificationIDToCancel: String?
        if let linkedReminder, !linkedReminder.isCompleted {
            notificationIDToCancel = markRelatedReminderCompleted(
                linkedReminder,
                by: human?.id.uuidString,
                actionType: "familyTaskCompleteReminder",
                plan: write,
                context: context,
                careLedger: careLedger
            )
        } else if linkedReminder == nil,
                  !setLinkedEventCompletion(
                      for: task,
                      isCompleted: true,
                      modifiedAt: task.completedAt ?? Date(),
                      context: context
                  ) {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }

        return persistMutation(
            context: context,
            onSuccess: {
                if let notificationIDToCancel {
                    OhanaNotifications.current.cancel(notificationId: notificationIDToCancel)
                }
            },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @MainActor
    @discardableResult
    static func submitForReview(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) -> Bool {
        submitForReview(task, by: human, context: context, careLedger: CareLedgerService())
    }

    @MainActor
    @discardableResult
    static func submitForReview(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) -> Bool {
        guard canWriteCollaboration(for: human),
              canSubmitForReview(task, by: human, context: context) else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human?.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return false }
        let linkedReminder = reminder(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedReminder?.event ?? linkedEvent(for: task, context: context)
        )
        let priorUpdatedAt = task.updatedAt
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .pendingReview
            task.completedAt = Date()
            task.completedById = human?.id.uuidString
            task.completedByName = human?.name
            task.touch()
        }
        guard FamilyTaskActivityService.stage(
            kind: .submittedForReview,
            task: task,
            actor: human,
            recipientHumanID: task.createdById,
            idempotencyKey: FamilyTaskActivityService.transitionKey(
                task: task,
                action: "submittedForReview",
                priorUpdatedAt: priorUpdatedAt
            ),
            context: context
        ) else {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }

        var notificationIDToCancel: String?
        if let linkedReminder, !linkedReminder.isCompleted {
            notificationIDToCancel = markRelatedReminderCompleted(
                linkedReminder,
                by: human?.id.uuidString,
                completedAt: task.completedAt ?? Date(),
                actionType: "submitReview",
                plan: write,
                context: context,
                careLedger: careLedger,
                recordsLedgerState: true
            )
        } else if linkedReminder == nil,
                  !setLinkedEventCompletion(
                      for: task,
                      isCompleted: true,
                      modifiedAt: task.completedAt ?? Date(),
                      context: context
                  ) {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }

        DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
            let subject = taskSubject(for: task, context: context)
            careLedger.record(
                occurredAt: Date(),
                actorKind: human == nil ? .unknown : .human,
                actorId: human?.id.uuidString,
                subjectKind: subject.ledgerSubjectKind,
                subjectId: subject.ledgerSubjectId,
                eventKind: .reminder,
                actionType: "familyTaskSubmitReview",
                amountValue: 0,
                amountUnit: "",
                note: task.title,
                source: .service,
                sourceEventId: nil,
                sourceReminderId: task.relatedReminderId,
                legacyModelName: nil,
                legacyModelId: nil,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "familyTaskReview:\(task.id.uuidString)",
                context: context,
                save: false
            )
        }
        return persistMutation(
            context: context,
            onSuccess: {
                if let notificationIDToCancel {
                    OhanaNotifications.current.cancel(notificationId: notificationIDToCancel)
                }
            },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @discardableResult
    @MainActor
    static func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) -> Bool {
        confirmCompletion(
            task,
            by: reviewer,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
    }

    @discardableResult
    @MainActor
    static func confirmCompletion(
        _ task: FamilyCollaborationTask,
        by reviewer: Human?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager? = nil
    ) -> Bool {
        guard task.status == .pendingReview,
              reviewer?.id.uuidString == task.createdById,
              canWriteCollaboration(for: reviewer),
              canWriteSubject(for: task, context: context) else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: reviewer?.id.uuidString, context: context),
            actor: reviewer,
            context: context
        ) else { return false }
        let rewardHumans = [
            reviewer,
            human(id: task.createdById, context: context),
            human(id: task.completedById, context: context)
        ].compactMap(\.self)
        let linkedReminder = reminder(for: task, context: context)
        let rollbackSnapshot = FamilyTaskRewardRollbackSnapshot(
            task: task,
            humans: rewardHumans,
            reminder: linkedReminder,
            event: linkedReminder?.event ?? linkedEvent(for: task, context: context),
            context: context
        )
        let priorUpdatedAt = task.updatedAt
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .completed
            if task.completedAt == nil { task.completedAt = Date() }
            task.touch()
        }

        var notificationIDToCancel: String?
        if let reminder = linkedReminder, !reminder.isCompleted {
            notificationIDToCancel = markRelatedReminderCompleted(
                reminder,
                by: task.completedById,
                completedAt: task.completedAt ?? Date(),
                actionType: "familyTaskConfirmReminder",
                plan: write,
                context: context,
                careLedger: careLedger,
                recordsLedgerState: false
            )
        }

        let rewardTransfer = transferRewardIfNeeded(
            task,
            write: write,
            reviewer: reviewer,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: projectionManager
        )
        guard rewardTransfer.didPrepare else {
            rollbackSnapshot.rollback(task, context: context)
            CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
            return false
        }
        let recipient = task.completedById ?? task.claimedById ?? task.assignedToId
        if let recipient,
           !FamilyTaskActivityService.stage(
               kind: task.rewardCoconuts > 0 ? .rewarded : .approved,
               task: task,
               actor: reviewer,
               recipientHumanID: recipient,
               idempotencyKey: FamilyTaskActivityService.transitionKey(
                   task: task,
                   action: task.rewardCoconuts > 0 ? "rewarded" : "approved",
                   priorUpdatedAt: priorUpdatedAt
               ),
               context: context
           ) {
            rollbackSnapshot.rollback(task, context: context)
            CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
            return false
        }
        return persistMutation(
            context: context,
            onSuccess: {
                if let notificationIDToCancel {
                    OhanaNotifications.current.cancel(notificationId: notificationIDToCancel)
                }
                projectionManager?.recordWalletProjection(
                    entries: rewardTransfer.projectionEntries,
                    postsRewardFeedback: true
                )
            },
            onFailure: {
                rollbackSnapshot.rollback(task, context: context)
                CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
            }
        )
    }

    @MainActor
    @discardableResult
    static func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) -> Bool {
        rejectCompletion(task, by: reviewer, context: context, careLedger: CareLedgerService())
    }

    @MainActor
    @discardableResult
    static func rejectCompletion(
        _ task: FamilyCollaborationTask,
        by reviewer: Human?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) -> Bool {
        guard task.status == .pendingReview,
              reviewer?.id.uuidString == task.createdById,
              canWriteCollaboration(for: reviewer),
              canWriteSubject(for: task, context: context) else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: reviewer?.id.uuidString, context: context),
            actor: reviewer,
            context: context
        ) else { return false }
        let linkedReminder = reminder(for: task, context: context)
        let rollbackSnapshot = FamilyTaskCommandRollbackSnapshot(
            task: task,
            reminder: linkedReminder,
            event: linkedReminder?.event ?? linkedEvent(for: task, context: context)
        )
        let priorUpdatedAt = task.updatedAt
        let recipient = task.completedById ?? task.claimedById ?? task.assignedToId
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = task.claimedById == nil ? .active : .claimed
            task.completedAt = nil
            task.completedById = nil
            task.completedByName = nil
            task.touch()
        }
        if let recipient,
           !FamilyTaskActivityService.stage(
               kind: .returnedForRedo,
               task: task,
               actor: reviewer,
               recipientHumanID: recipient,
               idempotencyKey: FamilyTaskActivityService.transitionKey(
                   task: task,
                   action: "returnedForRedo",
                   priorUpdatedAt: priorUpdatedAt
               ),
               context: context
           ) {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }

        var pendingSchedule: PendingFamilyTaskReminderSchedule?
        if let linkedReminder, linkedReminder.isCompleted {
            pendingSchedule = reopenRelatedReminder(
                linkedReminder,
                by: reviewer?.id.uuidString,
                plan: write,
                context: context,
                careLedger: careLedger
            )
        } else if linkedReminder == nil,
                  !setLinkedEventCompletion(
                      for: task,
                      isCompleted: false,
                      modifiedAt: Date(),
                      context: context
                  ) {
            rollbackSnapshot.rollback(task, context: context)
            return false
        }

        DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
            let subject = taskSubject(for: task, context: context)
            careLedger.record(
                occurredAt: Date(),
                actorKind: reviewer == nil ? .unknown : .human,
                actorId: reviewer?.id.uuidString,
                subjectKind: subject.ledgerSubjectKind,
                subjectId: subject.ledgerSubjectId,
                eventKind: .reminder,
                actionType: "familyTaskReviewRejected",
                amountValue: 0,
                amountUnit: "",
                note: task.title,
                source: .service,
                sourceEventId: nil,
                sourceReminderId: task.relatedReminderId,
                legacyModelName: nil,
                legacyModelId: nil,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "familyTaskReviewRejected:\(task.id.uuidString):\(Date().timeIntervalSince1970)",
                context: context,
                save: false
            )
        }
        return persistMutation(
            context: context,
            onSuccess: {
                pendingSchedule?.run()
            },
            onFailure: { rollbackSnapshot.rollback(task, context: context) }
        )
    }

    @MainActor
    @discardableResult
    static func cancel(_ task: FamilyCollaborationTask, context: ModelContext) -> Bool {
        guard task.status != .completed else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, context: context),
            actor: nil,
            context: context
        ) else { return false }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .cancelled
            task.touch()
        }
        return persistMutation(context: context)
    }

    @MainActor
    @discardableResult
    static func delete(_ task: FamilyCollaborationTask, by editor: Human?, context: ModelContext) -> Bool {
        guard editor?.id.uuidString == task.createdById,
              canWriteCollaboration(for: editor) else { return false }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, context: context),
            actor: editor,
            context: context
        ) else { return false }
        DomainMemberFactWriter.deleteFamilyTask(plan: write, task: task, context: context)
        return persistMutation(context: context)
    }

    @MainActor
    static func human(id: String?, context: ModelContext) -> Human? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch human for family task"
        ).first
    }

    @MainActor
    static func humanName(id: String?, context: ModelContext) -> String? {
        human(id: id, context: context)?.name
    }

    @MainActor
    private static func linkedEvent(
        for task: FamilyCollaborationTask,
        context: ModelContext
    ) -> Event? {
        guard let rawID = task.relatedEventId,
              let eventID = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.id == eventID }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch linked event for family task"
        ).first
    }

    @MainActor
    private static func setLinkedEventCompletion(
        for task: FamilyCollaborationTask,
        isCompleted: Bool,
        modifiedAt: Date,
        context: ModelContext
    ) -> Bool {
        guard let event = linkedEvent(for: task, context: context) else { return true }
        let occurrenceDate = task.dueAt ?? task.nominalAt ?? event.startDate
        guard event.isOccurrenceMarkedComplete(on: occurrenceDate) != isCompleted else { return true }
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .collaboration,
            source: .domainService,
            context: context
        ) else { return false }
        return DomainScheduleWriter.setEventOccurrenceCompletion(
            event,
            occurrenceDate: occurrenceDate,
            isCompleted: isCompleted,
            mutation: mutation,
            context: context,
            modifiedAt: modifiedAt
        )
    }

    @MainActor
    private static func transferRewardIfNeeded(
        _ task: FamilyCollaborationTask,
        write: AuthorizedDomainMemberFactWrite,
        reviewer: Human?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager?
    ) -> FamilyTaskRewardTransferPreparation {
        guard task.rewardCoconuts > 0 else { return .preparedWithoutProjection }
        guard let receiver = human(id: task.completedById, context: context),
              let payer = human(id: task.createdById, context: context),
              task.completedById == receiver.id.uuidString else {
            return .failed
        }
        guard payer.id != receiver.id else { return .preparedWithoutProjection }
        let marker = "familyTaskRewardTransfer:\(task.id.uuidString)"
        let payerTransactionKey = "\(marker):payer"
        let receiverTransactionKey = "\(marker):receiver"
        guard !hasWalletTransaction(payerTransactionKey, context: context),
              !hasWalletTransaction(receiverTransactionKey, context: context) else { return .preparedWithoutProjection }
        var transferError: Error?
        var projectionEntries: [CoconutLedgerEntry] = []
        let didWrite = DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
            let subject = taskSubject(for: task, context: context)
            let payerLedger = careLedger.record(
                occurredAt: Date(),
                actorKind: .human,
                actorId: payer.id.uuidString,
                subjectKind: .human,
                subjectId: receiver.id.uuidString,
                eventKind: .coconut,
                actionType: "familyTaskRewardPaid",
                amountValue: 0,
                amountUnit: "",
                note: "\(payer.name) → \(receiver.name) · \(task.title)",
                source: .service,
                sourceEventId: nil,
                sourceReminderId: task.relatedReminderId,
                legacyModelName: nil,
                legacyModelId: nil,
                coconutDelta: -task.rewardCoconuts,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "\(marker):payer",
                context: context,
                save: false
            )
            let confirmationNote = L10n.current.tr(
                zh: "\(reviewer?.name ?? payer.name) 确认 · \(task.title)",
                en: "\(reviewer?.name ?? payer.name) confirmed · \(task.title)",
                de: "\(reviewer?.name ?? payer.name) bestaetigt · \(task.title)"
            )
            let receiverLedger = careLedger.record(
                occurredAt: Date(),
                actorKind: .human,
                actorId: receiver.id.uuidString,
                subjectKind: subject.ledgerSubjectKind,
                subjectId: subject.ledgerSubjectId,
                eventKind: .coconut,
                actionType: "familyTaskRewardReceived",
                amountValue: 0,
                amountUnit: "",
                note: confirmationNote,
                source: .service,
                sourceEventId: nil,
                sourceReminderId: task.relatedReminderId,
                legacyModelName: nil,
                legacyModelId: nil,
                coconutDelta: task.rewardCoconuts,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "\(marker):receiver",
                context: context,
                save: false
            )
            do {
                projectionEntries = try CoconutWalletMutationWriter.applyHumanMutations(
                    [
                        CoconutHumanWalletMutation(
                            human: payer,
                            delta: -task.rewardCoconuts,
                            entryKind: .transferOut,
                            source: .familyTask,
                            title: DomainCareRewardGeneralTitle.familyTaskRewardPaid,
                            emoji: "🎯",
                            actorId: payer.id.uuidString,
                            actorName: payer.name,
                            subjectKind: .human,
                            subjectId: receiver.id.uuidString,
                            sourceModelName: "FamilyCollaborationTask",
                            sourceModelId: task.id.uuidString,
                            careLedgerEventId: payerLedger.id.uuidString,
                            metadataJSON: "\(marker):payer",
                            transactionKey: payerTransactionKey
                        ),
                        CoconutHumanWalletMutation(
                            human: receiver,
                            delta: task.rewardCoconuts,
                            entryKind: .transferIn,
                            source: .familyTask,
                            title: DomainCareRewardGeneralTitle.familyTaskRewardReceived,
                            emoji: "🎯",
                            actorId: receiver.id.uuidString,
                            actorName: receiver.name,
                            subjectKind: subject.ledgerSubjectKind,
                            subjectId: subject.ledgerSubjectId,
                            sourceModelName: "FamilyCollaborationTask",
                            sourceModelId: task.id.uuidString,
                            careLedgerEventId: receiverLedger.id.uuidString,
                            metadataJSON: "\(marker):receiver",
                            transactionKey: receiverTransactionKey
                        )
                    ],
                    wallet: wallet,
                    context: context,
                    save: false,
                    postsRewardFeedback: false,
                    updatesProjection: false,
                    projectionManager: projectionManager
                )
            } catch {
                transferError = error
            }
        }
        if let transferError {
            context.rollback()
            #if DEBUG
                OhanaLog.error("[FamilyTaskService] transfer wallet write failed: \(transferError.localizedDescription)", category: "FamilyTasks")
            #endif
            return .failed
        }
        return didWrite
            ? FamilyTaskRewardTransferPreparation(didPrepare: true, projectionEntries: projectionEntries)
            : .failed
    }

    @MainActor
    private static func hasWalletTransaction(_ transactionKey: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { entry in
                entry.transactionKey == transactionKey
            }
        )
        descriptor.fetchLimit = 1
        return !fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch wallet transaction for family task reward"
        ).isEmpty
    }

    @MainActor
    private static func markRelatedReminderCompleted(
        _ reminder: Reminder,
        by humanId: String?,
        completedAt: Date = Date(),
        actionType: String,
        plan: AuthorizedDomainMemberFactWrite,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        recordsLedgerState: Bool = true
    ) -> String? {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .collaboration,
            source: .domainService,
            context: context
        ),
            DomainScheduleWriter.completeReminder(
                reminder,
                mutation: mutation,
                completedBy: humanId,
                completedAt: completedAt,
                context: context
            )
        else {
            return nil
        }
        DomainMemberFactEffectsDispatcher.run(plan: plan) { _ in
            if recordsLedgerState {
                careLedger.recordReminderState(
                    reminder: reminder,
                    actionType: actionType,
                    actorId: humanId,
                    source: .service,
                    context: context,
                    save: false
                )
            }
        }
        let notificationId = reminder.notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
        return notificationId.isEmpty ? nil : notificationId
    }

    @MainActor
    private static func reopenRelatedReminder(
        _ reminder: Reminder,
        by humanId: String?,
        plan: AuthorizedDomainMemberFactWrite,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) -> PendingFamilyTaskReminderSchedule? {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .collaboration,
            source: .domainService,
            context: context
        ),
            DomainScheduleWriter.reopenReminder(
                reminder,
                mutation: mutation,
                reopenedBy: humanId,
                reopenedAt: Date(),
                context: context
            )
        else {
            return nil
        }
        DomainMemberFactEffectsDispatcher.run(plan: plan) { _ in
            careLedger.recordReminderState(
                reminder: reminder,
                actionType: "familyTaskReopenReminder",
                actorId: humanId,
                source: .service,
                context: context,
                save: false
            )
        }
        return PendingFamilyTaskReminderSchedule(reminder: reminder, careLedger: careLedger, context: context)
    }
}
