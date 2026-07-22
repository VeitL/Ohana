import Foundation
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
        projectionManager: CoconutProjectionManaging?
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
        projectionManager: CoconutProjectionManaging?
    ) throws -> [CoconutLedgerEntry]

    func totalBalance(context: ModelContext) -> Int
    func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int
    func balance(for human: Human, context: ModelContext) -> Int
    func balance(for pet: Pet, context: ModelContext) -> Int
    func legacySystemBalance(context: ModelContext, fallback: Int) -> Int
    func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext)
    func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging?)
    func bootstrapIfNeeded(context: ModelContext, projectionManager: CoconutProjectionManaging?) throws
    func stageLegacyBootstrapIfNeeded(context: ModelContext) throws
    func restoreCachedHumanBalances(_ balances: [UUID: Int], context: ModelContext)
}

extension CoconutWalletManaging {
    func balance(accountKey: String, context: ModelContext) -> Int {
        balance(accountKey: accountKey, context: context, fallback: 0)
    }

    func legacySystemBalance(context: ModelContext) -> Int {
        legacySystemBalance(context: context, fallback: 0)
    }

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

    /// Test doubles and non-SwiftData wallets have no legacy projection to
    /// stage. The production wallet overrides this so a command can include
    /// compatibility opening entries in its own transaction.
    func stageLegacyBootstrapIfNeeded(context _: ModelContext) throws {}

    func restoreCachedHumanBalances(_ balances: [UUID: Int], context: ModelContext) {
        CoconutWalletService.restoreCachedHumanBalances(balances, context: context)
    }
}

@MainActor
final class SwiftDataCoconutWalletManager: CoconutWalletManaging {
    private let legacyDefaults: UserDefaults

    init(legacyDefaults: UserDefaults = .standard) {
        self.legacyDefaults = legacyDefaults
    }

    func apply(
        deltas: [CoconutWalletDelta],
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        updatesProjection: Bool,
        projectionManager: CoconutProjectionManaging?
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
        projectionManager: CoconutProjectionManaging?
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

    func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int {
        CoconutWalletService.balance(accountKey: accountKey, context: context, fallback: fallback)
    }

    func balance(for human: Human, context: ModelContext) -> Int {
        CoconutWalletService.balance(for: human, context: context)
    }

    func balance(for pet: Pet, context: ModelContext) -> Int {
        CoconutWalletService.balance(for: pet, context: context)
    }

    func legacySystemBalance(context: ModelContext, fallback: Int) -> Int {
        CoconutWalletService.legacySystemBalance(context: context, fallback: fallback)
    }

    func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext) {
        CoconutWalletService.setDeveloperOverrideBalance(
            amount: amount,
            for: human,
            displayName: displayName,
            context: context
        )
    }

    func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging?) {
        CoconutWalletService.refreshQuestProjection(context: context, manager: manager)
    }

    func bootstrapIfNeeded(context: ModelContext, projectionManager: CoconutProjectionManaging?) throws {
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            defaults: legacyDefaults,
            projectionManager: projectionManager
        )
    }

    func stageLegacyBootstrapIfNeeded(context: ModelContext) throws {
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            defaults: legacyDefaults,
            projectionManager: nil,
            saveChanges: false,
            updatesProjection: false
        )
    }
}
