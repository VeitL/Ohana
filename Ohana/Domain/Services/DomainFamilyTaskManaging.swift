import Foundation
import SwiftData

nonisolated struct FamilyTaskActivitySnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let planID: UUID?
    let taskID: UUID?
    let occurrenceKey: String?
    let kind: FamilyTaskActivityKind
    let actorHumanID: UUID?
    let actorHumanName: String
    let recipientHumanID: UUID?
    let taskTitle: String
    let body: String
    let oldDueAt: Date?
    let newDueAt: Date?
    let countValue: Int
    let createdAt: Date
    let readAt: Date?

    var isUnread: Bool { readAt == nil }
}

nonisolated enum FamilyTaskReminderCompletionPreparation: Equatable, Sendable {
    case notLinked
    case prepared
    case rejected
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
    func declineAssignment(_ task: FamilyCollaborationTask, by human: Human, reason: String, context: ModelContext) -> Bool
    @discardableResult
    func postponeOccurrence(_ task: FamilyCollaborationTask, to dueAt: Date, by human: Human, context: ModelContext) -> Bool
    @discardableResult
    func addComment(_ task: FamilyCollaborationTask, body: String, by human: Human, idempotencyKey: String, context: ModelContext) -> Bool
    @discardableResult
    func cancelByCreator(_ task: FamilyCollaborationTask, by creator: Human, context: ModelContext) -> Bool
    func canClaim(_ task: FamilyCollaborationTask, by human: Human, context: ModelContext) -> Bool
    func canComplete(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) -> Bool
    func canSubmitForReview(_ task: FamilyCollaborationTask, by human: Human?, context: ModelContext) -> Bool
    func occurrenceTimeline(
        taskID: UUID,
        limit: Int,
        context: ModelContext
    ) -> [FamilyTaskActivitySnapshot]
    func prepareCompletedReminder(
        _ reminder: Reminder,
        completedBy humanId: String?,
        context: ModelContext
    ) -> FamilyTaskReminderCompletionPreparation
    func authorizeCollaborationWrite(
        subjectRequest: DomainSubjectResolutionRequest,
        actor: Human?,
        occurredAt: Date,
        context: ModelContext,
        logPrefix: String
    ) -> AuthorizedDomainMemberFactWrite?
    @discardableResult
    func syncCompletedReminder(_ reminder: Reminder, completedBy humanId: String?, context: ModelContext) -> Bool
    @discardableResult
    func syncReopenedReminder(_ reminder: Reminder, context: ModelContext) -> Bool
}

extension FamilyTaskManaging {
    func declineAssignment(_: FamilyCollaborationTask, by _: Human, reason _: String, context _: ModelContext) -> Bool { false }
    func postponeOccurrence(_: FamilyCollaborationTask, to _: Date, by _: Human, context _: ModelContext) -> Bool { false }
    func addComment(_: FamilyCollaborationTask, body _: String, by _: Human, idempotencyKey _: String, context _: ModelContext) -> Bool { false }
    func cancelByCreator(_: FamilyCollaborationTask, by _: Human, context _: ModelContext) -> Bool { false }
    func occurrenceTimeline(
        taskID _: UUID,
        limit _: Int = 100,
        context _: ModelContext
    ) -> [FamilyTaskActivitySnapshot] { [] }
}
