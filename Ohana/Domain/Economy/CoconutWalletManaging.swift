import SwiftData

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

    @discardableResult
    func applyActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry]

    func totalBalance(context: ModelContext) -> Int
    func refreshQuestProjection(context: ModelContext, manager: QuestManager?)
    func bootstrapIfNeeded(context: ModelContext, projectionManager: QuestManager?) throws
}

extension CoconutWalletManaging {
    @discardableResult
    func applyActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool = true
    ) throws -> [CoconutLedgerEntry] {
        try applyActorDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            actorId: actorId,
            actorName: actorName,
            entryKind: entryKind,
            source: source,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            projectionManager: nil
        )
    }

    func refreshQuestProjection(context: ModelContext) {
        refreshQuestProjection(context: context, manager: nil)
    }

    func bootstrapIfNeeded(context: ModelContext) throws {
        try bootstrapIfNeeded(context: context, projectionManager: nil)
    }
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

    func applyActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry] {
        try CoconutWalletService.applyActorDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            actorId: actorId,
            actorName: actorName,
            entryKind: entryKind,
            source: source,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            projectionManager: projectionManager
        )
    }

    func totalBalance(context: ModelContext) -> Int {
        CoconutWalletService.totalBalance(context: context)
    }

    func refreshQuestProjection(context: ModelContext, manager: QuestManager?) {
        CoconutWalletService.refreshQuestProjection(context: context, manager: manager)
    }

    func bootstrapIfNeeded(context: ModelContext, projectionManager: QuestManager?) throws {
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            projectionManager: projectionManager
        )
    }
}
