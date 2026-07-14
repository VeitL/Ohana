//
//  FamilyTaskService.swift
//  Ohana
//
//  Canonical write path for family collaboration tasks.
//

import Foundation
import SwiftData

enum FamilyTaskService {
    nonisolated static let rewardCap = 500

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
        guard !normalizedTitle.isEmpty,
              editor?.id.uuidString == task.createdById,
              FamilyTaskFundingPolicy.resolve(
                  createdById: task.createdById,
                  assignedTo: human,
                  rewardCoconuts: reward,
                  context: context
              ) != nil,
              canWriteCollaboration(for: human),
              canWriteSubject(for: task, context: context),
              canWriteCollaboration(forHumanId: task.createdById, context: context),
              canWriteCollaboration(forHumanId: task.claimedById, context: context) else {
            return false
        }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human?.id.uuidString, context: context),
            actor: editor,
            context: context
        ) else { return false }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.title = normalizedTitle
            task.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            task.assignedToId = human?.id.uuidString
            task.assignedToName = human?.name
            task.rewardCoconuts = reward
            task.kind = task.relatedReminderId == nil
                ? (reward > 0 ? .bounty : .householdTask)
                : (reward > 0 ? .bounty : .careReminder)
            task.dueAt = dueAt
            task.emoji = emoji
            if task.status == .pendingReview {
                task.status = task.claimedById == nil ? .active : .claimed
                task.completedAt = nil
                task.completedById = nil
                task.completedByName = nil
            }
            task.touch()
        }
        return persistMutation(context: context)
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
            logPrefix: "FamilyTaskService.claimPreflight"
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
            logPrefix: "FamilyTaskService.preflight"
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
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .completed
            task.completedAt = Date()
            task.completedById = human?.id.uuidString
            task.completedByName = human?.name
            task.touch()
        }

        var notificationIDToCancel: String?
        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            notificationIDToCancel = markRelatedReminderCompleted(
                reminder,
                by: human?.id.uuidString,
                actionType: "familyTaskCompleteReminder",
                plan: write,
                context: context,
                careLedger: careLedger
            )
        }

        return persistMutation(
            context: context,
            onSuccess: {
                if let notificationIDToCancel {
                    OhanaNotifications.current.cancel(notificationId: notificationIDToCancel)
                }
            }
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
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .pendingReview
            task.completedAt = Date()
            task.completedById = human?.id.uuidString
            task.completedByName = human?.name
            task.touch()
        }

        var notificationIDToCancel: String?
        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            notificationIDToCancel = markRelatedReminderCompleted(
                reminder,
                by: human?.id.uuidString,
                completedAt: task.completedAt ?? Date(),
                actionType: "submitReview",
                plan: write,
                context: context,
                careLedger: careLedger,
                recordsLedgerState: true
            )
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
            }
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
        let originalStatus = task.status
        let originalCompletedAt = task.completedAt
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .completed
            if task.completedAt == nil { task.completedAt = Date() }
            task.touch()
        }

        var notificationIDToCancel: String?
        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
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
            DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
                task.status = originalStatus
                task.completedAt = originalCompletedAt
            }
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
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = task.claimedById == nil ? .active : .claimed
            task.completedAt = nil
            task.completedById = nil
            task.completedByName = nil
            task.touch()
        }

        var pendingSchedule: PendingFamilyTaskReminderSchedule?
        if let reminder = reminder(for: task, context: context), reminder.isCompleted {
            pendingSchedule = reopenRelatedReminder(
                reminder,
                by: reviewer?.id.uuidString,
                plan: write,
                context: context,
                careLedger: careLedger
            )
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
            }
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
