//
//  AppServices.swift
//  Ohana
//
//  Instance-based dependency container for gradually retiring static services.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppServices {
    let careEvents: CareEventRecording
    let coconutWallet: CoconutWalletManaging
    let familyTasks: FamilyTaskManaging
    let domainRevisions: DomainRevisionPublishing

    convenience init() {
        self.init(
            careEvents: StaticCareEventRecorder(),
            coconutWallet: SwiftDataCoconutWalletManager(),
            familyTasks: StaticFamilyTaskManager(),
            domainRevisions: SharedDomainRevisionPublisher()
        )
    }

    init(
        careEvents: CareEventRecording,
        coconutWallet: CoconutWalletManaging,
        familyTasks: FamilyTaskManaging,
        domainRevisions: DomainRevisionPublishing
    ) {
        self.careEvents = careEvents
        self.coconutWallet = coconutWallet
        self.familyTasks = familyTasks
        self.domainRevisions = domainRevisions
    }
}

@MainActor
protocol CareEventRecording {
    @discardableResult
    func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
        date: Date,
        foodKind: FeedFoodKind
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)?

    @discardableResult
    func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)?

    @discardableResult
    func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordPotty(
        pet: Pet,
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordHygiene(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func recordHealth(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)
}

@MainActor
final class StaticCareEventRecorder: CareEventRecording {
    func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String?,
        quality: QuestManager.QualityBonus,
        date: Date,
        foodKind: FeedFoodKind
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordManualFeed(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            foodKind: foodKind
        )
    }

    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int)? {
        CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: context,
            quality: quality,
            executorId: executorId,
            date: date
        )
    }

    func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)? {
        CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: amountMl,
            context: context,
            executorId: executorId
        )
    }

    func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        context: ModelContext,
        executorId: String?,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordCare(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: quality,
            date: date
        )
    }

    func recordPotty(
        pet: Pet,
        type: PottyType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordPotty(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
    }

    func recordHygiene(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordHygiene(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
    }

    func recordHealth(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String?,
        date: Date
    ) -> (humanGot: Int, petGot: Int) {
        CareEventService.recordHealth(
            pet: pet,
            type: type,
            note: note,
            context: context,
            executorId: executorId,
            date: date
        )
    }
}

@MainActor
protocol CoconutWalletManaging {
    @discardableResult
    func apply(
        deltas: [CoconutWalletDelta],
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        updatesProjection: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry]
}

@MainActor
final class SwiftDataCoconutWalletManager: CoconutWalletManaging {
    func apply(
        deltas: [CoconutWalletDelta],
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        updatesProjection: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry] {
        try CoconutWalletService.apply(
            deltas: deltas,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            updatesProjection: updatesProjection,
            projectionManager: projectionManager
        )
    }
}

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
        FamilyTaskService.rejectCompletion(task, by: reviewer, context: context)
    }

    func confirmCompletion(_ task: FamilyCollaborationTask, by reviewer: Human?, context: ModelContext) {
        FamilyTaskService.confirmCompletion(task, by: reviewer, context: context)
    }

    func complete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) {
        FamilyTaskService.complete(task, by: human, context: context)
    }

    func claim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) {
        FamilyTaskService.claim(task, by: human, context: context)
    }

    func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext) {
        FamilyTaskService.syncCompletedReminder(reminder, completedBy: humanId, context: context)
    }

    func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) {
        FamilyTaskService.syncReopenedReminder(reminder, context: context)
    }
}

@MainActor
protocol DomainRevisionPublishing {
    func publish(_ result: DomainMutationResult)
    func publishFailure(command: DomainCommand, error: Error)
}

@MainActor
final class SharedDomainRevisionPublisher: DomainRevisionPublishing {
    func publish(_ result: DomainMutationResult) {
        ReadModelRevisionCenter.shared.publish(result)
    }

    func publishFailure(command: DomainCommand, error: Error) {
        ReadModelRevisionCenter.shared.publishFailure(command: command, error: error)
    }
}
