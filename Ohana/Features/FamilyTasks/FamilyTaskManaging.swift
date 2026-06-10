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
    func updateTask(
        _ task: FamilyCollaborationTask,
        title: String,
        note: String,
        assignedTo human: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    )
    func delete(_ task: FamilyCollaborationTask, context: ModelContext)
    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext)
    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext)
    func complete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext)
    func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext)
    func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext)
    func syncReopenedReminder(_ reminder: Reminder, context: ModelContext)
}

@MainActor
final class StaticFamilyTaskManager: FamilyTaskManaging {
    private let wallet: CoconutWalletManaging
    private let careLedger: CareLedgerRecording
    private let questManager: QuestManager

    convenience init() {
        self.init(
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            questManager: QuestManager()
        )
    }

    init(wallet: CoconutWalletManaging, careLedger: CareLedgerRecording, questManager: QuestManager) {
        self.wallet = wallet
        self.careLedger = careLedger
        self.questManager = questManager
    }

    func migrateLegacyBountiesIfNeeded(context: ModelContext) {
        FamilyTaskService.migrateLegacyBountiesIfNeeded(context: context)
    }

    func assignReminder(
        _ reminder: Reminder,
        to human: Human,
        by creator: Human?,
        rewardCoconuts: Int,
        note: String,
        context: ModelContext
    ) -> FamilyCollaborationTask? {
        FamilyTaskService.assignReminder(
            reminder,
            to: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            note: note,
            context: context
        )
    }

    func createHouseholdTask(
        title: String,
        note: String,
        assignedTo human: Human?,
        by creator: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    ) -> FamilyCollaborationTask? {
        FamilyTaskService.createHouseholdTask(
            title: title,
            note: note,
            assignedTo: human,
            by: creator,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: context
        )
    }

    func updateTask(
        _ task: FamilyCollaborationTask,
        title: String,
        note: String,
        assignedTo human: Human?,
        rewardCoconuts: Int,
        dueAt: Date?,
        emoji: String,
        context: ModelContext
    ) {
        FamilyTaskService.updateTask(
            task,
            title: title,
            note: note,
            assignedTo: human,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            context: context
        )
    }

    func delete(_ task: FamilyCollaborationTask, context: ModelContext) {
        FamilyTaskService.delete(task, context: context)
    }

    func rejectCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) {
        FamilyTaskService.rejectCompletion(task, by: reviewer, context: context, careLedger: careLedger)
    }

    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) {
        FamilyTaskService.confirmCompletion(
            task,
            by: reviewer,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
    }

    func complete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) {
        FamilyTaskService.complete(
            task,
            by: human,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
    }

    func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) {
        FamilyTaskService.claim(task, by: human, context: context)
    }

    func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext) {
        FamilyTaskService.syncCompletedReminder(
            reminder,
            completedBy: humanId,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            projectionManager: questManager
        )
    }

    func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) {
        FamilyTaskService.syncReopenedReminder(reminder, context: context)
    }
}
