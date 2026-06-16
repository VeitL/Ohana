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

    private struct FamilyTaskSubject {
        let relatedPetId: String?
        let ledgerSubjectKind: CareLedgerSubjectKind
        let ledgerSubjectId: String?

        static let household = FamilyTaskSubject(
            relatedPetId: nil,
            ledgerSubjectKind: .household,
            ledgerSubjectId: nil
        )
    }

    private struct AuthorizedReminderAssigneeUpdate {
        let event: Event
        let intent: DomainScheduleCreateIntent
        let mutation: AuthorizedDomainScheduleMutation
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

    static func householdTaskSubjectRequest(assigneeId: String?) -> DomainSubjectResolutionRequest {
        DomainSubjectResolutionRequest(assigneeId: assigneeId)
    }

    @MainActor
    private static func taskSubjectRequest(
        for reminder: Reminder,
        assigneeId: String?,
        context _: ModelContext
    ) -> DomainSubjectResolutionRequest {
        guard let event = reminder.event else {
            return householdTaskSubjectRequest(assigneeId: assigneeId)
        }
        return DomainSubjectResolutionRequest(
            link: DomainEntityLink(event: event),
            assigneeId: assigneeId
        )
    }

    @MainActor
    private static func taskSubjectRequest(
        for task: FamilyCollaborationTask,
        assigneeId: String? = nil,
        context: ModelContext
    ) -> DomainSubjectResolutionRequest {
        if let reminder = reminder(for: task, context: context) {
            return taskSubjectRequest(
                for: reminder,
                assigneeId: assigneeId ?? task.assignedToId ?? task.claimedById ?? task.createdById,
                context: context
            )
        }
        if let relatedPetId = normalizedPetId(task.relatedPetId) {
            return DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: relatedPetId,
                assigneeId: assigneeId ?? task.assignedToId ?? task.claimedById
            )
        }
        return householdTaskSubjectRequest(
            assigneeId: assigneeId ?? task.assignedToId ?? task.claimedById ?? task.createdById
        )
    }

    static func cappedReward(_ value: Int) -> Int {
        min(rewardCap, max(0, value))
    }

    @MainActor
    static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "FamilyTaskService failed to \(operation): \(error.localizedDescription)",
                category: "FamilyTasks"
            )
            return []
        }
    }

    private static func canWriteCollaboration(for human: Human?) -> Bool {
        guard let human else { return true }
        return MemberLifecycleGate.disposition(human: human, writeKind: .collaboration).allowsDerivedEffects
    }

    @MainActor
    private static func canWriteCollaboration(forHumanId humanId: String?, context: ModelContext) -> Bool {
        guard let humanId, !humanId.isEmpty else { return true }
        guard let uuid = UUID(uuidString: humanId),
              let human = humans(context: context).first(where: { $0.id == uuid }) else {
            return false
        }
        return canWriteCollaboration(for: human)
    }

    private static func canWriteCollaboration(for pet: Pet) -> Bool {
        MemberLifecycleGate.disposition(pet: pet, writeKind: .collaboration).allowsDerivedEffects
    }

    @MainActor
    private static func canWriteRelatedPet(for task: FamilyCollaborationTask, context: ModelContext) -> Bool {
        guard let relatedPetId = taskSubject(for: task, context: context).relatedPetId else { return true }
        guard let pet = pet(idRaw: relatedPetId, context: context) else { return false }
        return canWriteCollaboration(for: pet)
    }

    @MainActor
    private static func reminderTargetsWritableMember(_ reminder: Reminder, context: ModelContext) -> Bool {
        let activePets = pets(context: context).filter(canWriteCollaboration)
        let activeHumans = humans(context: context).filter(canWriteCollaboration)
        let humanMedications = humanMedications(context: context)
        return MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(
            reminder,
            activePets: activePets,
            activeHumans: activeHumans,
            humanMedications: humanMedications
        )
    }

    @MainActor
    private static func pets(context: ModelContext) -> [Pet] {
        fetchOrLog(FetchDescriptor<Pet>(), context: context, operation: "fetch pets for family task lifecycle gate")
    }

    @MainActor
    private static func humans(context: ModelContext) -> [Human] {
        fetchOrLog(FetchDescriptor<Human>(), context: context, operation: "fetch humans for family task lifecycle gate")
    }

    @MainActor
    private static func humanMedications(context: ModelContext) -> [HumanMedication] {
        fetchOrLog(FetchDescriptor<HumanMedication>(), context: context, operation: "fetch human medications for family task lifecycle gate")
    }

    @MainActor
    private static func pet(idRaw: String, context: ModelContext) -> Pet? {
        let petIdRaw = idRaw.split(separator: ":").first.map(String.init) ?? idRaw
        guard let uuid = UUID(uuidString: petIdRaw) else { return nil }
        return pets(context: context).first { $0.id == uuid }
    }

    @MainActor
    private static func taskSubject(for reminder: Reminder, context: ModelContext) -> FamilyTaskSubject {
        guard let event = reminder.event else { return .household }
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        )
        return taskSubject(from: resolution)
    }

    @MainActor
    private static func taskSubject(for task: FamilyCollaborationTask, context: ModelContext) -> FamilyTaskSubject {
        if let reminder = reminder(for: task, context: context) {
            return taskSubject(for: reminder, context: context)
        }
        guard let relatedPetId = normalizedPetId(task.relatedPetId) else { return .household }
        return FamilyTaskSubject(
            relatedPetId: relatedPetId,
            ledgerSubjectKind: .pet,
            ledgerSubjectId: relatedPetId
        )
    }

    private static func taskSubject(from resolution: DomainSubjectResolution) -> FamilyTaskSubject {
        switch resolution.owner {
        case let .pet(petId):
            FamilyTaskSubject(
                relatedPetId: petId.uuidString,
                ledgerSubjectKind: .pet,
                ledgerSubjectId: petId.uuidString
            )
        case let .human(humanId):
            FamilyTaskSubject(
                relatedPetId: nil,
                ledgerSubjectKind: .human,
                ledgerSubjectId: humanId.uuidString
            )
        case nil where resolution.role.isPlantScoped:
            FamilyTaskSubject(
                relatedPetId: nil,
                ledgerSubjectKind: .plant,
                ledgerSubjectId: normalizedUUIDString(resolution.link.trimmedId)
            )
        case nil:
            .household
        }
    }

    private static func normalizedPetId(_ raw: String?) -> String? {
        guard let raw,
              let petId = DomainEntityLinkRegistry.petIdFromCompoundStockId(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return petId.uuidString
    }

    private static func normalizedUUIDString(_ raw: String) -> String? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))?.uuidString
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
        guard canWriteCollaboration(for: human),
              canWriteCollaboration(for: creator),
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
            actor: creator ?? human,
            context: context
        ) else { return nil }
        let taskTitle = reminderTaskTitle(for: reminder)
        let reward = cappedReward(rewardCoconuts)
        let task: FamilyCollaborationTask
        if let existing {
            task = existing
            DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
                task.kind = reward > 0 ? .bounty : .careReminder
                task.title = taskTitle
                task.note = note
                task.status = .active
                task.relatedPetId = subject.relatedPetId
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
            }
        } else {
            task = DomainMemberFactWriter.createFamilyTask(
                plan: write,
                title: taskTitle,
                note: note,
                kind: reward > 0 ? .bounty : .careReminder,
                relatedPetId: subject.relatedPetId,
                relatedEventId: reminder.event?.id.uuidString,
                relatedReminderId: reminder.id.uuidString,
                createdById: creator?.id.uuidString ?? human.id.uuidString,
                createdByName: creator?.name ?? human.name,
                assignedToId: human.id.uuidString,
                assignedToName: human.name,
                rewardCoconuts: reward,
                dueAt: reminder.scheduledAt,
                emoji: reminder.event?.emoji ?? "🐾",
                context: context
            )
        }

        if let assigneeUpdate {
            guard DomainScheduleWriter.updateEvent(
                assigneeUpdate.event,
                intent: assigneeUpdate.intent,
                mutation: assigneeUpdate.mutation
            ) else { return nil }
        }
        context.safeSave()
        return task
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
        guard let human else { return nil }
        if let creator, creator.id == human.id {
            return nil
        }
        guard canWriteCollaboration(for: human),
              canWriteCollaboration(for: creator) else {
            return nil
        }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: householdTaskSubjectRequest(assigneeId: human.id.uuidString),
            actor: creator ?? human,
            context: context
        ) else { return nil }

        let task = DomainMemberFactWriter.createFamilyTask(
            plan: write,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: cappedReward(rewardCoconuts) > 0 ? .bounty : .householdTask,
            createdById: creator?.id.uuidString ?? "",
            createdByName: creator?.name ?? "Ohana",
            assignedToId: human.id.uuidString,
            assignedToName: human.name,
            rewardCoconuts: cappedReward(rewardCoconuts),
            dueAt: dueAt,
            emoji: emoji,
            context: context
        )
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
        guard canWriteCollaboration(for: human),
              canWriteRelatedPet(for: task, context: context),
              canWriteCollaboration(forHumanId: task.createdById, context: context),
              canWriteCollaboration(forHumanId: task.claimedById, context: context) else {
            return
        }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human?.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
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
        }
        context.safeSave()
    }

    @MainActor
    static func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) {
        guard !task.isFinished,
              canWriteCollaboration(for: human),
              canWriteRelatedPet(for: task, context: context) else { return }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.claimedById = human.id.uuidString
            task.claimedByName = human.name
            task.status = .claimed
            task.touch()
        }
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
        wallet _: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        projectionManager _: QuestManager? = nil
    ) {
        guard !task.isFinished,
              canWriteCollaboration(for: human),
              canWriteRelatedPet(for: task, context: context) else { return }
        if task.hasReward {
            submitForReview(task, by: human, context: context, careLedger: careLedger)
            return
        }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human?.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .completed
            task.completedAt = Date()
            task.completedById = human?.id.uuidString
            task.completedByName = human?.name
            task.touch()
        }

        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            markRelatedReminderCompleted(
                reminder,
                by: human?.id.uuidString,
                actionType: "familyTaskCompleteReminder",
                plan: write,
                context: context,
                careLedger: careLedger
            )
        }

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
        guard !task.isFinished,
              canWriteCollaboration(for: human),
              canWriteRelatedPet(for: task, context: context) else { return }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: human?.id.uuidString, context: context),
            actor: human,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .pendingReview
            task.completedAt = Date()
            task.completedById = human?.id.uuidString
            task.completedByName = human?.name
            task.touch()
        }

        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            markRelatedReminderCompleted(
                reminder,
                by: human?.id.uuidString,
                completedAt: task.completedAt ?? Date(),
                actionType: "submitReview",
                plan: write,
                context: context,
                careLedger: careLedger,
                saveLedger: true
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
        context.safeSave()
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
              canWriteRelatedPet(for: task, context: context) else { return false }
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

        if let reminder = reminder(for: task, context: context), !reminder.isCompleted {
            markRelatedReminderCompleted(
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

        guard transferRewardIfNeeded(
            task,
            write: write,
            reviewer: reviewer,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: projectionManager
        ) else {
            DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
                task.status = originalStatus
                task.completedAt = originalCompletedAt
            }
            return false
        }
        context.safeSave()
        return true
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
              reviewer?.id.uuidString == task.createdById,
              canWriteCollaboration(for: reviewer),
              canWriteRelatedPet(for: task, context: context) else { return }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, assigneeId: reviewer?.id.uuidString, context: context),
            actor: reviewer,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = task.claimedById == nil ? .active : .claimed
            task.completedAt = nil
            task.completedById = nil
            task.completedByName = nil
            task.touch()
        }

        if let reminder = reminder(for: task, context: context), reminder.isCompleted {
            reopenRelatedReminder(
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
        context.safeSave()
    }

    @MainActor
    static func cancel(_ task: FamilyCollaborationTask, context: ModelContext) {
        guard task.status != .completed else { return }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, context: context),
            actor: nil,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .cancelled
            task.touch()
        }
        context.safeSave()
    }

    @MainActor
    static func delete(_ task: FamilyCollaborationTask, context: ModelContext) {
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: task, context: context),
            actor: nil,
            context: context
        ) else { return }
        DomainMemberFactWriter.deleteFamilyTask(plan: write, task: task, context: context)
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
        wallet _: CoconutWalletManaging,
        careLedger _: CareLedgerRecording,
        projectionManager _: QuestManager? = nil
    ) {
        guard let task = activeTask(forReminderId: reminder.id.uuidString, context: context),
              task.status != .completed else { return }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: reminder, assigneeId: humanId, context: context),
            actor: human(id: humanId, context: context),
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.completedAt = reminder.completedAt ?? Date()
            task.completedById = humanId
            task.completedByName = humanName(id: humanId, context: context)
            task.status = task.hasReward ? .pendingReview : .completed
            task.touch()
        }

        context.safeSave()
    }

    @MainActor
    static func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) {
        guard let task = activeOrCompletedTask(forReminderId: reminder.id.uuidString, context: context),
              task.status == .completed else { return }
        guard let write = authorizedCollaborationWrite(
            subjectRequest: taskSubjectRequest(for: reminder, assigneeId: task.assignedToId, context: context),
            actor: nil,
            context: context
        ) else { return }
        DomainMemberFactWriter.mutateFamilyTask(plan: write, task: task, context: context) { task in
            task.status = .active
            task.completedAt = nil
            task.completedById = nil
            task.completedByName = nil
            task.touch()
        }
        context.safeSave()
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

    private static func isReminderSyncActiveTask(_ task: FamilyCollaborationTask) -> Bool {
        switch task.status {
        case .active, .claimed, .pendingReview:
            true
        case .completed, .cancelled:
            false
        }
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

    @MainActor
    private static func reminder(for task: FamilyCollaborationTask, context: ModelContext) -> Reminder? {
        guard let id = task.relatedReminderId, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch related reminder for family task"
        ).first
    }

    @MainActor
    private static func human(id: String?, context: ModelContext) -> Human? {
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
    private static func humanName(id: String?, context: ModelContext) -> String? {
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
    ) -> Bool {
        guard task.rewardCoconuts > 0 else { return true }
        guard let receiver = human(id: task.completedById, context: context),
              let payer = human(id: task.createdById, context: context),
              task.completedById == receiver.id.uuidString else {
            return false
        }
        guard payer.id != receiver.id else { return true }
        let marker = "familyTaskRewardTransfer:\(task.id.uuidString)"
        let payerTransactionKey = "\(marker):payer"
        let receiverTransactionKey = "\(marker):receiver"
        guard !hasWalletTransaction(payerTransactionKey, context: context),
              !hasWalletTransaction(receiverTransactionKey, context: context) else { return true }
        var transferError: Error?
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
                try CoconutWalletMutationWriter.applyHumanMutations(
                    [
                        CoconutHumanWalletMutation(
                            human: payer,
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
                            transactionKey: payerTransactionKey
                        ),
                        CoconutHumanWalletMutation(
                            human: receiver,
                            delta: task.rewardCoconuts,
                            entryKind: .transferIn,
                            source: .familyTask,
                            title: "家庭任务悬赏收入",
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
                    postsRewardFeedback: true,
                    updatesProjection: true,
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
            return false
        }
        return didWrite
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
        recordsLedgerState: Bool = true,
        saveLedger: Bool = false
    ) {
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
            return
        }
        DomainMemberFactEffectsDispatcher.run(plan: plan) { _ in
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            if recordsLedgerState {
                careLedger.recordReminderState(
                    reminder: reminder,
                    actionType: actionType,
                    actorId: humanId,
                    source: .service,
                    context: context,
                    save: saveLedger
                )
            }
        }
    }

    @MainActor
    private static func reopenRelatedReminder(
        _ reminder: Reminder,
        by humanId: String?,
        plan: AuthorizedDomainMemberFactWrite,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
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
            return
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
}
