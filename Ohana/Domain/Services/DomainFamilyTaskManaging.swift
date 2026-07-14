import Foundation
import SwiftData

@MainActor
protocol FamilyTaskManaging {
    func migrateLegacyBountiesIfNeeded(context: ModelContext)
    func assignReminder(
        _ reminder: Reminder,
        to human: Human,
        by creator: Human?,
        rewardCoconuts: Int,
        note: String,
        context: ModelContext
    ) -> FamilyCollaborationTask?
    func createHouseholdTask(
        title: String,
        note: String,
        assignedTo human: Human?,
        by creator: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    ) -> FamilyCollaborationTask?
    @discardableResult
    func updateTask(
        _ task: FamilyCollaborationTask,
        title: String,
        note: String,
        assignedTo human: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        by editor: Human?,
        context: ModelContext
    ) -> Bool
    @discardableResult
    func delete(_ task: FamilyCollaborationTask, by editor: Human?, context: ModelContext) -> Bool
    @discardableResult
    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) -> Bool
    @discardableResult
    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) -> Bool
    @discardableResult
    func complete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) -> Bool
    @discardableResult
    func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) -> Bool
    @discardableResult
    func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext) -> Bool
    @discardableResult
    func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) -> Bool
}
