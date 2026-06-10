//
//  FamilyTaskService.swift
//  Ohana
//
//  Canonical write path for family collaboration tasks.
//

import Foundation
import SwiftData

enum FamilyTaskService {
    static let rewardCap = 500

    static func cappedReward(_ value: Int) -> Int {
        min(rewardCap, max(0, value))
    }

    private struct LegacyBountyTask: Codable {
        var id: UUID
        var title: String
        var description: String
        var reward: Int
        var creatorId: String
        var creatorName: String
        var creatorEmoji: String
        var assigneeId: String?
        var assigneeName: String?
        var assignedToId: String?
        var assignedToName: String?
        var assignedToEmoji: String?
        var isCompleted: Bool
        var createdAt: Date
        var completedAt: Date?
        var emoji: String
    }

    @MainActor
    static func migrateLegacyBountiesIfNeeded(context: ModelContext) {
        syncLegacyBounties(context: context)
    }

    @MainActor
    static func syncLegacyBounties(context: ModelContext) {
        guard let raw = LegacyBountyTaskPreferenceStore.rawTasks(),
              let data = raw.data(using: .utf8),
              let legacy = try? JSONDecoder().decode([LegacyBountyTask].self, from: data),
              !legacy.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<FamilyCollaborationTask>())) ?? []
        var existingById: [UUID: FamilyCollaborationTask] = [:]
        for task in existing {
            existingById[task.id] = task
        }
        var changed = false

        for item in legacy {
            if let task = existingById[item.id] {
                changed = syncLegacyBounty(item, into: task) || changed
                continue
            }
            let task = makeTask(from: item)
            context.insert(task)
            changed = true
        }
        if changed {
            context.safeSave()
        }
    }

    private static func makeTask(from item: LegacyBountyTask) -> FamilyCollaborationTask {
        let task = FamilyCollaborationTask(
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
            createdAt: item.createdAt
        )
        task.claimedById = item.assigneeId
        task.claimedByName = item.assigneeName
        task.completedById = item.assigneeId
        task.completedByName = item.assigneeName
        task.completedAt = item.completedAt
        return task
    }

    private static func syncLegacyBounty(_ item: LegacyBountyTask, into task: FamilyCollaborationTask) -> Bool {
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

    @MainActor
    static func assignReminder(
        _ reminder: Reminder,
        to human: Human,
        by creator: Human?,
        rewardCoconuts: Int,
        note: String = "",
        context: ModelContext
    ) -> FamilyCollaborationTask? {
        if let creator, creator.id == human.id {
            return nil
        }

        let existing = activeTask(forReminderId: reminder.id.uuidString, context: context)
        let task = existing
            ?? FamilyCollaborationTask(
                title: reminder.event?.title ?? "照护任务",
                note: note,
                kind: .careReminder,
                relatedPetId: reminder.event?.relatedEntityId,
                relatedEventId: reminder.event?.id.uuidString,
                relatedReminderId: reminder.id.uuidString,
                createdById: creator?.id.uuidString ?? human.id.uuidString,
                createdByName: creator?.name ?? human.name,
                assignedToId: human.id.uuidString,
                assignedToName: human.name,
                rewardCoconuts: cappedReward(rewardCoconuts),
                dueAt: reminder.scheduledAt,
                emoji: reminder.event?.emoji ?? "🐾"
            )

        if existing == nil {
            context.insert(task)
        }
        let reward = cappedReward(rewardCoconuts)
        task.kind = reward > 0 ? .bounty : .careReminder
        task.title = reminder.event?.title ?? task.title
        task.note = note
        task.status = .active
        task.relatedPetId = reminder.event?.relatedEntityId
        task.relatedEventId = reminder.event?.id.uuidString
        task.relatedReminderId = reminder.id.uuidString
        task.assignedToId = human.id.uuidString
        task.assignedToName = human.name
        task.rewardCoconuts = reward
        task.dueAt = reminder.scheduledAt
        task.completedAt = nil
        task.completedById = nil
        task.completedByName = nil
        task.touch()

        reminder.event?.assigneeId = human.id.uuidString
        context.safeSave()
        return task
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
        guard let human else { return nil }
        if let creator, creator.id == human.id {
            return nil
        }

        let task = FamilyCollaborationTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: cappedReward(rewardCoconuts) > 0 ? .bounty : .householdTask,
            createdById: creator?.id.uuidString ?? "",
            createdByName: creator?.name ?? "Ohana",
            assignedToId: human.id.uuidString,
            assignedToName: human.name,
            rewardCoconuts: cappedReward(rewardCoconuts),
            dueAt: dueAt,
            emoji: emoji
        )
        context.insert(task)
        context.safeSave()
        return task
    }

    @MainActor
    static func updateTask(
        _ task: FamilyCollaborationTask,
        title: String,
        note: String,
        assignedTo human: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    ) {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        task.assignedToId = human?.id.uuidString
        task.assignedToName = human?.name
        let reward = cappedReward(rewardCoconuts)
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
        context.safeSave()
    }

    @MainActor
    static func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) {
        guard !task.isFinished else { return }
        task.claimedById = human.id.uuidString
        task.claimedByName = human.name
        task.status = .claimed
        task.touch()
        context.safeSave()
    }

    @MainActor
    static func complete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) {
        complete(
            task,
            by: human,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
    }

    @MainActor
    static func complete(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager? = nil
    ) {
        guard !task.isFinished else { return }
        if task.hasReward {
            submitForReview(task, by: human, context: context, careLedger: careLedger)
            return
        }
        task.status = .completed
        task.completedAt = Date()
        task.completedById = human?.id.uuidString
        task.completedByName = human?.name
        task.touch()

        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            markRelatedReminderCompleted(
                reminder,
                by: human?.id.uuidString,
                actionType: "familyTaskCompleteReminder",
                context: context,
                careLedger: careLedger
            )
        }

        awardRewardIfNeeded(
            task,
            human: human,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: projectionManager
        )
        context.safeSave()
    }

    @MainActor
    static func submitForReview(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) {
        submitForReview(task, by: human, context: context, careLedger: CareLedgerService())
    }

    @MainActor
    static func submitForReview(
        _ task: FamilyCollaborationTask,
        by human: Human?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        guard !task.isFinished else { return }
        task.status = .pendingReview
        task.completedAt = Date()
        task.completedById = human?.id.uuidString
        task.completedByName = human?.name
        task.touch()

        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            reminder.statusEnum = .completed
            reminder.completedAt = task.completedAt
            reminder.completedBy = human?.id.uuidString ?? ""
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            careLedger.recordReminderState(
                reminder: reminder,
                actionType: "submitReview",
                actorId: human?.id.uuidString,
                source: .service,
                context: context,
                save: true
            )
        }

        careLedger.record(
            occurredAt: Date(),
            actorKind: human == nil ? .unknown : .human,
            actorId: human?.id.uuidString,
            subjectKind: task.relatedPetId == nil ? .household : .pet,
            subjectId: task.relatedPetId,
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
        context.safeSave()
    }

    @MainActor
    static func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) {
        confirmCompletion(
            task,
            by: reviewer,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
    }

    @MainActor
    static func confirmCompletion(
        _ task: FamilyCollaborationTask,
        by reviewer: Human?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager? = nil
    ) {
        guard task.status == .pendingReview,
              reviewer?.id.uuidString == task.createdById else { return }
        task.status = .completed
        if task.completedAt == nil { task.completedAt = Date() }
        task.touch()

        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            reminder.statusEnum = .completed
            reminder.completedAt = task.completedAt
            reminder.completedBy = task.completedById ?? ""
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        }

        transferRewardIfNeeded(
            task,
            reviewer: reviewer,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: projectionManager
        )
        context.safeSave()
    }

    @MainActor
    static func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) {
        rejectCompletion(task, by: reviewer, context: context, careLedger: CareLedgerService())
    }

    @MainActor
    static func rejectCompletion(
        _ task: FamilyCollaborationTask,
        by reviewer: Human?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        guard task.status == .pendingReview,
              reviewer?.id.uuidString == task.createdById else { return }
        task.status = task.claimedById == nil ? .active : .claimed
        task.completedAt = nil
        task.completedById = nil
        task.completedByName = nil
        task.touch()

        if let reminder = reminder(for: task, context: context), reminder.isCompleted {
            reopenRelatedReminder(
                reminder,
                by: reviewer?.id.uuidString,
                context: context,
                careLedger: careLedger
            )
        }

        careLedger.record(
            occurredAt: Date(),
            actorKind: reviewer == nil ? .unknown : .human,
            actorId: reviewer?.id.uuidString,
            subjectKind: task.relatedPetId == nil ? .household : .pet,
            subjectId: task.relatedPetId,
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
        context.safeSave()
    }

    @MainActor
    static func cancel(_ task: FamilyCollaborationTask, context: ModelContext) {
        guard task.status != .completed else { return }
        task.status = .cancelled
        task.touch()
        context.safeSave()
    }

    @MainActor
    static func delete(_ task: FamilyCollaborationTask, context: ModelContext) {
        context.delete(task)
        context.safeSave()
    }

    @MainActor
    static func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext) {
        syncCompletedReminder(
            reminder,
            completedBy: humanId,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
    }

    @MainActor
    static func syncCompletedReminder(
        _ reminder: Reminder,
        completedBy humanId: String?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager? = nil
    ) {
        guard let task = activeTask(forReminderId: reminder.id.uuidString, context: context),
              task.status != .completed else { return }
        task.completedAt = reminder.completedAt ?? Date()
        task.completedById = humanId
        task.completedByName = humanName(id: humanId, context: context)
        task.status = task.hasReward ? .pendingReview : .completed
        task.touch()

        let human = human(id: humanId, context: context)
        if !task.hasReward {
            awardRewardIfNeeded(
                task,
                human: human,
                context: context,
                wallet: wallet,
                careLedger: careLedger,
                projectionManager: projectionManager
            )
        }
        context.safeSave()
    }

    @MainActor
    static func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) {
        guard let task = activeOrCompletedTask(forReminderId: reminder.id.uuidString, context: context),
              task.status == .completed else { return }
        task.status = .active
        task.completedAt = nil
        task.completedById = nil
        task.completedByName = nil
        task.touch()
        context.safeSave()
    }

    @MainActor
    static func activeTask(forReminderId reminderId: String, context: ModelContext) -> FamilyCollaborationTask? {
        let active = FamilyCollaborationTaskStatus.active.rawValue
        let claimed = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReview = FamilyCollaborationTaskStatus.pendingReview.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.relatedReminderId == reminderId && (task.statusRaw == active || task.statusRaw == claimed || task.statusRaw == pendingReview)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
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
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func reminder(for task: FamilyCollaborationTask, context: ModelContext) -> Reminder? {
        guard let id = task.relatedReminderId, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func human(id: String?, context: ModelContext) -> Human? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func humanName(id: String?, context: ModelContext) -> String? {
        human(id: id, context: context)?.name
    }

    @MainActor
    private static func awardRewardIfNeeded(
        _ task: FamilyCollaborationTask,
        human: Human?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager?
    ) {
        guard task.rewardCoconuts > 0,
              let human,
              task.completedById == human.id.uuidString else { return }
        let marker = "familyTaskReward:\(task.id.uuidString)"
        let existing = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        guard !existing.contains(where: { $0.metadataJSON == marker }) else { return }

        let ledger = careLedger.record(
            occurredAt: Date(),
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: task.relatedPetId == nil ? .household : .pet,
            subjectId: task.relatedPetId,
            eventKind: .coconut,
            actionType: "familyTaskReward",
            amountValue: 0,
            amountUnit: "",
            note: "\(human.name) · \(task.title)",
            source: .service,
            sourceEventId: nil,
            sourceReminderId: task.relatedReminderId,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: task.rewardCoconuts,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: marker,
            context: context,
            save: false
        )
        do {
            try wallet.apply(
                deltas: [
                    .human(
                        human,
                        delta: task.rewardCoconuts,
                        entryKind: .reward,
                        source: .familyTask,
                        title: "完成家庭任务",
                        emoji: "🎯",
                        actorId: human.id.uuidString,
                        actorName: human.name,
                        subjectKind: task.relatedPetId == nil ? .household : .pet,
                        subjectId: task.relatedPetId,
                        sourceModelName: "FamilyCollaborationTask",
                        sourceModelId: task.id.uuidString,
                        careLedgerEventId: ledger.id.uuidString,
                        metadataJSON: marker
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: projectionManager
            )
            context.safeSave()
        } catch {
            context.rollback()
            #if DEBUG
            print("❌ [FamilyTaskService] reward wallet write failed: \(error.localizedDescription)")
            #endif
        }
    }

    @MainActor
    private static func transferRewardIfNeeded(
        _ task: FamilyCollaborationTask,
        reviewer: Human?,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager: QuestManager?
    ) {
        guard task.rewardCoconuts > 0,
              let receiver = human(id: task.completedById, context: context),
              let payer = human(id: task.createdById, context: context),
              task.completedById == receiver.id.uuidString,
              payer.id != receiver.id else { return }
        let marker = "familyTaskRewardTransfer:\(task.id.uuidString)"
        let existing = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        guard !existing.contains(where: { $0.metadataJSON.hasPrefix(marker) }) else { return }

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
        let receiverLedger = careLedger.record(
            occurredAt: Date(),
            actorKind: .human,
            actorId: receiver.id.uuidString,
            subjectKind: task.relatedPetId == nil ? .household : .pet,
            subjectId: task.relatedPetId,
            eventKind: .coconut,
            actionType: "familyTaskRewardReceived",
            amountValue: 0,
            amountUnit: "",
            note: "\(reviewer?.name ?? payer.name) 确认 · \(task.title)",
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
            try wallet.apply(
                deltas: [
                    .human(
                        payer,
                        delta: -task.rewardCoconuts,
                        entryKind: .transferOut,
                        source: .familyTask,
                        title: "家庭任务悬赏支付",
                        emoji: "🎯",
                        actorId: payer.id.uuidString,
                        actorName: payer.name,
                        subjectKind: .human,
                        subjectId: receiver.id.uuidString,
                        sourceModelName: "FamilyCollaborationTask",
                        sourceModelId: task.id.uuidString,
                        careLedgerEventId: payerLedger.id.uuidString,
                        metadataJSON: "\(marker):payer",
                        transactionKey: "\(marker):payer"
                    ),
                    .human(
                        receiver,
                        delta: task.rewardCoconuts,
                        entryKind: .transferIn,
                        source: .familyTask,
                        title: "家庭任务悬赏收入",
                        emoji: "🎯",
                        actorId: receiver.id.uuidString,
                        actorName: receiver.name,
                        subjectKind: task.relatedPetId == nil ? .household : .pet,
                        subjectId: task.relatedPetId,
                        sourceModelName: "FamilyCollaborationTask",
                        sourceModelId: task.id.uuidString,
                        careLedgerEventId: receiverLedger.id.uuidString,
                        metadataJSON: "\(marker):receiver",
                        transactionKey: "\(marker):receiver"
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: projectionManager
            )
        } catch {
            context.rollback()
            #if DEBUG
            print("❌ [FamilyTaskService] transfer wallet write failed: \(error.localizedDescription)")
            #endif
        }
    }

    @MainActor
    private static func markRelatedReminderCompleted(
        _ reminder: Reminder,
        by humanId: String?,
        actionType: String,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        reminder.completedBy = humanId ?? ""
        reminder.event?.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        careLedger.recordReminderState(
            reminder: reminder,
            actionType: actionType,
            actorId: humanId,
            source: .service,
            context: context,
            save: false
        )
    }

    @MainActor
    private static func reopenRelatedReminder(
        _ reminder: Reminder,
        by humanId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.event?.setOccurrenceMarkedComplete(false, on: reminder.scheduledAt)
        careLedger.recordReminderState(
            reminder: reminder,
            actionType: "familyTaskReopenReminder",
            actorId: humanId,
            source: .service,
            context: context,
            save: false
        )
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
