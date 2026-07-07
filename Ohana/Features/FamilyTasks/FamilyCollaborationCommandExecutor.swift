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

    func assignReminder(_ reminder: Reminder, to human: Human, by creator: Human?, rewardCoconuts: Int, note: String) {
        guard let task = familyTasks.assignReminder(
            reminder,
            to: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            note: note,
            context: modelContext
        ) else { return }
        publish(.assignReminder(taskID: task.id, reminderID: reminder.id))
    }

    func createTask(title: String, note: String, assignedTo human: Human?, by creator: Human?, rewardCoconuts: Int, dueAt: Date?, emoji: String) {
        guard let task = familyTasks.createHouseholdTask(
            title: title,
            note: note,
            assignedTo: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: modelContext
        ) else { return }
        publish(.create(taskID: task.id))
    }

    func updateTask(_ task: FamilyCollaborationTask, title: String, note: String, assignedTo human: Human?, rewardCoconuts: Int, dueAt: Date?, emoji: String) {
        guard familyTasks.updateTask(
            task,
            title: title,
            note: note,
            assignedTo: human,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: modelContext
        ) else { return }
        publish(.update(taskID: task.id))
    }

    func deleteTask(_ task: FamilyCollaborationTask) {
        let taskID = task.id
        guard familyTasks.delete(task, context: modelContext) else { return }
        publish(.delete(taskID: taskID))
    }

    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) {
        guard familyTasks.rejectCompletion(task, by: reviewer, context: modelContext) else { return }
        publish(.reject(taskID: task.id, reviewerID: reviewer?.id))
    }

    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) {
        guard familyTasks.confirmCompletion(task, by: reviewer, context: modelContext) else { return }
        publish(.confirm(taskID: task.id, reviewerID: reviewer?.id))
    }

    func complete(_ task: FamilyCollaborationTask, by human: Human?) {
        guard familyTasks.complete(task, by: human, context: modelContext) else { return }
        publish(.complete(taskID: task.id, humanID: human?.id))
    }

    func claim(_ task: FamilyCollaborationTask, by human: Human) {
        guard familyTasks.claim(task, by: human, context: modelContext) else { return }
        publish(.claim(taskID: task.id, humanID: human.id))
    }

    private func publish(_ command: FamilyTaskCommand, wroteBusinessFact: Bool = true) {
        revisions.publishFamilyTask(command, wroteBusinessFact: wroteBusinessFact)
    }
}
