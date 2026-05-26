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

    func migrateLegacyBountiesIfNeeded() {
        FamilyTaskService.migrateLegacyBountiesIfNeeded(context: modelContext)
    }

    func assignReminder(_ reminder: Reminder, to human: Human, by creator: Human?, rewardCoconuts: Int, note: String) {
        _ = FamilyTaskService.assignReminder(
            reminder,
            to: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            note: note,
            context: modelContext
        )
    }

    func createTask(title: String, note: String, assignedTo human: Human?, by creator: Human?, rewardCoconuts: Int, dueAt: Date?, emoji: String) {
        _ = FamilyTaskService.createHouseholdTask(
            title: title,
            note: note,
            assignedTo: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: modelContext
        )
    }

    func updateTask(_ task: FamilyCollaborationTask, title: String, note: String, assignedTo human: Human?, rewardCoconuts: Int, dueAt: Date?, emoji: String) {
        FamilyTaskService.updateTask(
            task,
            title: title,
            note: note,
            assignedTo: human,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: modelContext
        )
    }

    func deleteTask(_ task: FamilyCollaborationTask) {
        FamilyTaskService.delete(task, context: modelContext)
    }

    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) {
        FamilyTaskService.rejectCompletion(task, by: reviewer, context: modelContext)
    }

    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?) {
        FamilyTaskService.confirmCompletion(task, by: reviewer, context: modelContext)
    }

    func complete(_ task: FamilyCollaborationTask, by human: Human?) {
        FamilyTaskService.complete(task, by: human, context: modelContext)
    }

    func claim(_ task: FamilyCollaborationTask, by human: Human) {
        FamilyTaskService.claim(task, by: human, context: modelContext)
    }
}
