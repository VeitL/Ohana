//
//  FamilyCollaborationCommandExecutor.swift
//  Ohana
//
//  Thin command adapter from the collaboration UI into domain services.
//

import Foundation
import SwiftData

@MainActor
struct FamilyCollaborationCommandExecutor {
    let modelContext: ModelContext
    let familyTasks: FamilyTaskManaging
    let revisions: DomainRevisionPublishing

    init(modelContext: ModelContext) {
        self.init(
            modelContext: modelContext,
            familyTasks: StaticFamilyTaskManager(),
            revisions: SharedDomainRevisionPublisher()
        )
    }

    init(
        modelContext: ModelContext,
        familyTasks: FamilyTaskManaging,
        revisions: DomainRevisionPublishing
    ) {
        self.modelContext = modelContext
        self.familyTasks = familyTasks
        self.revisions = revisions
    }

    func occurrenceTimeline(
        taskID: UUID,
        limit: Int = 100
    ) -> [FamilyTaskActivitySnapshot] {
        familyTasks.occurrenceTimeline(
            taskID: taskID,
            limit: limit,
            context: modelContext
        )
    }

    func migrateLegacyBountiesIfNeeded() {
        familyTasks.migrateLegacyBountiesIfNeeded(context: modelContext)
        publish(.migrateLegacyBounties, wroteBusinessFact: false)
    }

    @discardableResult
    func assignReminder(_ reminder: Reminder, to human: Human, by creator: Human?, rewardCoconuts: Int, note: String) -> Bool {
        guard let task = familyTasks.assignReminder(
            reminder,
            to: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            note: note,
            context: modelContext
        ) else { return false }
        publish(.assignReminder(taskID: task.id, reminderID: reminder.id))
        return true
    }

    @discardableResult
    func createTask(title: String, note: String, assignedTo human: Human?, by creator: Human?, rewardCoconuts: Int, dueAt: Date?, emoji: String) -> Bool {
        guard let task = familyTasks.createHouseholdTask(
            title: title,
            note: note,
            assignedTo: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: modelContext
        ) else { return false }
        publish(.create(taskID: task.id))
        return true
    }

    @discardableResult
    func createPlan(_ draft: FamilyTaskPlanDraft) async -> Bool {
        do {
            let actor = FamilyTaskPlanMaterializationActor(modelContainer: modelContext.container)
            let result = try await actor.createPlan(draft)
            guard let planID = result.planID else { return false }
            publish(.createPlan(planID: planID))
            await scheduleMaterializedReminders(ids: result.reminderIDs)
            return true
        } catch {
            revisions.publishFailure(command: .command("familyTasks", "createPlan"), error: error)
            return false
        }
    }

    @discardableResult
    func updateThisAndFuture(
        planID: UUID,
        from nominalAt: Date,
        draft: FamilyTaskPlanDraft,
        by editor: Human
    ) async -> Bool {
        guard MemberLifecycleGate.disposition(
            human: editor,
            writeKind: .collaboration
        ).allowsDerivedEffects else { return false }
        do {
            let actor = FamilyTaskPlanMaterializationActor(modelContainer: modelContext.container)
            let result = try await actor.updateThisAndFuture(
                planID: planID,
                from: nominalAt,
                draft: draft,
                editorID: editor.id
            )
            for notificationID in result.notificationIDsToCancel {
                OhanaNotifications.current.cancel(notificationId: notificationID)
            }
            await scheduleMaterializedReminders(ids: result.reminderIDsToSchedule)
            revisions.publish(
                DomainMutationResult(
                    command: .command("familyTasks", "updateThisAndFuture"),
                    affectedEntityIDs: [result.planID],
                    note: "cancelled=\(result.cancelledOccurrenceCount), inserted=\(result.insertedOccurrenceCount)"
                )
            )
            return true
        } catch {
            revisions.publishFailure(command: .command("familyTasks", "updateThisAndFuture"), error: error)
            return false
        }
    }

    @discardableResult
    func cancelThisAndFuture(
        planID: UUID,
        from nominalAt: Date,
        by editor: Human
    ) async -> Bool {
        guard MemberLifecycleGate.disposition(
            human: editor,
            writeKind: .collaboration
        ).allowsDerivedEffects else { return false }
        do {
            let actor = FamilyTaskPlanMaterializationActor(modelContainer: modelContext.container)
            let result = try await actor.cancelThisAndFuture(
                planID: planID,
                from: nominalAt,
                editorID: editor.id
            )
            for notificationID in result.notificationIDsToCancel {
                OhanaNotifications.current.cancel(notificationId: notificationID)
            }
            revisions.publish(
                DomainMutationResult(
                    command: .command("familyTasks", "cancelThisAndFuture"),
                    affectedEntityIDs: [result.planID],
                    note: "cancelled=\(result.cancelledOccurrenceCount)"
                )
            )
            return true
        } catch {
            revisions.publishFailure(command: .command("familyTasks", "cancelThisAndFuture"), error: error)
            return false
        }
    }

    @discardableResult
    func updateTask(_ task: FamilyCollaborationTask, title: String, note: String, assignedTo human: Human?, rewardCoconuts: Int, dueAt: Date?, emoji: String, by editor: Human?) -> Bool {
        guard familyTasks.updateTask(
            task,
            title: title,
            note: note,
            assignedTo: human,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            by: editor,
            context: modelContext
        ) else { return false }
        publish(.update(taskID: task.id))
        return true
    }

    @discardableResult
    func deleteTask(_ task: FamilyCollaborationTask, by editor: Human?) -> Bool {
        guard let editor,
              familyTasks.cancelByCreator(task, by: editor, context: modelContext) else { return false }
        publish(.cancel(taskID: task.id, creatorID: editor.id))
        return true
    }

    @discardableResult
    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) -> Bool {
        guard familyTasks.rejectCompletion(task, by: reviewer, context: modelContext) else { return false }
        publish(.returnForRedo(taskID: task.id, reviewerID: reviewer?.id))
        materializeNextOccurrencesIfNeeded(for: task)
        return true
    }

    @discardableResult
    func declineAssignment(_ task: FamilyCollaborationTask, by human: Human, reason: String) -> Bool {
        guard familyTasks.declineAssignment(
            task,
            by: human,
            reason: reason,
            context: modelContext
        ) else { return false }
        publish(.decline(taskID: task.id, humanID: human.id))
        materializeNextOccurrencesIfNeeded(for: task)
        return true
    }

    @discardableResult
    func postponeOccurrence(_ task: FamilyCollaborationTask, to dueAt: Date, by human: Human) -> Bool {
        guard familyTasks.postponeOccurrence(task, to: dueAt, by: human, context: modelContext) else { return false }
        publish(.postpone(taskID: task.id, humanID: human.id))
        materializeNextOccurrencesIfNeeded(for: task)
        return true
    }

    @discardableResult
    func addComment(_ task: FamilyCollaborationTask, body: String, by human: Human, idempotencyKey: String) -> Bool {
        guard familyTasks.addComment(
            task,
            body: body,
            by: human,
            idempotencyKey: idempotencyKey,
            context: modelContext
        ) else { return false }
        publish(.comment(taskID: task.id, humanID: human.id))
        return true
    }

    @discardableResult
    func cancelTask(_ task: FamilyCollaborationTask, by creator: Human) -> Bool {
        guard familyTasks.cancelByCreator(task, by: creator, context: modelContext) else { return false }
        publish(.cancel(taskID: task.id, creatorID: creator.id))
        return true
    }

    @discardableResult
    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) -> Bool {
        guard familyTasks.confirmCompletion(task, by: reviewer, context: modelContext) else { return false }
        publish(.confirm(taskID: task.id, reviewerID: reviewer?.id))
        materializeNextOccurrencesIfNeeded(for: task)
        return true
    }

    @discardableResult
    func complete(_ task: FamilyCollaborationTask, by human: Human?) -> Bool {
        guard familyTasks.complete(task, by: human, context: modelContext) else { return false }
        publish(.complete(taskID: task.id, humanID: human?.id))
        materializeNextOccurrencesIfNeeded(for: task)
        return true
    }

    @discardableResult
    func claim(_ task: FamilyCollaborationTask, by human: Human) -> Bool {
        guard familyTasks.claim(task, by: human, context: modelContext) else { return false }
        publish(.claim(taskID: task.id, humanID: human.id))
        materializeNextOccurrencesIfNeeded(for: task)
        return true
    }

    private func materializeNextOccurrencesIfNeeded(for task: FamilyCollaborationTask) {
        guard let rawPlanID = task.planId, let planID = UUID(uuidString: rawPlanID) else { return }
        let container = modelContext.container
        Task { @MainActor in
            do {
                let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
                let result = try await actor.materialize(planID: planID)
                guard result.insertedOccurrenceCount > 0 else { return }
                await scheduleMaterializedReminders(ids: result.reminderIDs)
                revisions.publish(
                    DomainMutationResult(
                        command: .command("familyTasks", "materializeAfterAction"),
                        affectedEntityIDs: [planID],
                        note: "inserted=\(result.insertedOccurrenceCount)"
                    )
                )
            } catch {
                OhanaLog.warning(
                    "Family task post-action materialization deferred: \(error.localizedDescription)",
                    category: "FamilyTasks"
                )
            }
        }
    }

    private func scheduleMaterializedReminders(ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        let scheduling = ReminderSchedulingManager(careLedger: CareLedgerService())
        for id in ids {
            var descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { $0.id == id }
            )
            descriptor.fetchLimit = 1
            guard let reminder = try? modelContext.fetch(descriptor).first else { continue }
            await scheduling.scheduleIfNeeded(
                reminder: reminder,
                context: modelContext,
                source: .service,
                existingNotificationIds: nil,
                operation: "familyTaskPlanCreate",
                saveLedger: true
            )
        }
    }

    private func publish(_ command: FamilyTaskCommand, wroteBusinessFact: Bool = true) {
        revisions.publishFamilyTask(command, wroteBusinessFact: wroteBusinessFact)
    }
}
