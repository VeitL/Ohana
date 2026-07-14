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
        let taskID = task.id
        guard familyTasks.delete(task, by: editor, context: modelContext) else { return false }
        publish(.delete(taskID: taskID))
        return true
    }

    @discardableResult
    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) -> Bool {
        guard familyTasks.rejectCompletion(task, by: reviewer, context: modelContext) else { return false }
        publish(.reject(taskID: task.id, reviewerID: reviewer?.id))
        return true
    }

    @discardableResult
    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) -> Bool {
        guard familyTasks.confirmCompletion(task, by: reviewer, context: modelContext) else { return false }
        publish(.confirm(taskID: task.id, reviewerID: reviewer?.id))
        return true
    }

    @discardableResult
    func complete(_ task: FamilyCollaborationTask, by human: Human?) -> Bool {
        guard familyTasks.complete(task, by: human, context: modelContext) else { return false }
        publish(.complete(taskID: task.id, humanID: human?.id))
        return true
    }

    @discardableResult
    func claim(_ task: FamilyCollaborationTask, by human: Human) -> Bool {
        guard familyTasks.claim(task, by: human, context: modelContext) else { return false }
        publish(.claim(taskID: task.id, humanID: human.id))
        return true
    }

    private func publish(_ command: FamilyTaskCommand, wroteBusinessFact: Bool = true) {
        revisions.publishFamilyTask(command, wroteBusinessFact: wroteBusinessFact)
    }
}
