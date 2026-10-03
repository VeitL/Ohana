//
//  AchievementCommandActor.swift
//  Ohana
//
//  Atomic reward boundary for unlock receipts, coconuts, and companion stardust.
//

import Foundation
import SwiftData

nonisolated enum AchievementClaimFailure: Equatable, Sendable {
    case missingRecipient
    case inactiveRecipient
    case locked([String])
    case alreadyClaimed
    case persistenceBusy
    case persistenceFailed(String)
}

nonisolated struct AchievementClaimResult: Equatable, Sendable {
    let claimedKeys: [String]
    let recipientID: UUID?
    let coconutAmount: Int
    let stardustAmount: Int
    let failure: AchievementClaimFailure?

    var didClaim: Bool { failure == nil && !claimedKeys.isEmpty }
}

/// Main-actor command object because the canonical coconut wallet chokepoint is
/// main-actor isolated. It never exposes live SwiftData models to callers.
@MainActor
final class AchievementCommandActor {
    private let context: ModelContext
    private let wallet: CoconutWalletManaging
    private weak var projectionManager: CoconutProjectionManaging?

    init(
        modelContainer: ModelContainer,
        wallet: CoconutWalletManaging? = nil,
        projectionManager: CoconutProjectionManaging? = nil
    ) {
        context = ModelContext(modelContainer)
        self.wallet = wallet ?? SwiftDataCoconutWalletManager()
        self.projectionManager = projectionManager
    }

    init(
        context: ModelContext,
        wallet: CoconutWalletManaging? = nil,
        projectionManager: CoconutProjectionManaging? = nil
    ) {
        self.context = context
        self.wallet = wallet ?? SwiftDataCoconutWalletManager()
        self.projectionManager = projectionManager
    }

    func claim(keys: [String], recipientID: UUID?) -> AchievementClaimResult {
        guard let recipientID else {
            return failure(.missingRecipient, keys: keys, recipientID: nil)
        }
        let uniqueKeys = Array(Set(keys)).sorted()
        guard !uniqueKeys.isEmpty else {
            return failure(.alreadyClaimed, keys: [], recipientID: recipientID)
        }
        do {
            return try ShopPurchaseBackupFence.withExclusiveAccess(
                context: context,
                unavailable: {
                    self.failure(.persistenceBusy, keys: uniqueKeys, recipientID: recipientID)
                },
                operation: {
                    try self.claimWhileFenced(keys: uniqueKeys, recipientID: recipientID)
                }
            )
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: projectionManager)
            return failure(
                .persistenceFailed(error.localizedDescription),
                keys: uniqueKeys,
                recipientID: recipientID
            )
        }
    }

    private func claimWhileFenced(keys: [String], recipientID: UUID) throws -> AchievementClaimResult {
        guard let recipient = try fetchActiveHuman(id: recipientID) else {
            return failure(.inactiveRecipient, keys: keys, recipientID: recipientID)
        }
        let unlockByKey = try fetchUnlocksByRequestedKey(keys: keys)
        let lockedKeys = keys.filter { unlockByKey[$0] == nil }
        guard lockedKeys.isEmpty else {
            return failure(.locked(lockedKeys), keys: keys, recipientID: recipientID)
        }
        let existingReceiptKeys = try fetchClaimedRequestedKeys(keys: keys)
        let claimable = keys.filter { !existingReceiptKeys.contains($0) }
        guard !claimable.isEmpty else {
            return failure(.alreadyClaimed, keys: keys, recipientID: recipientID)
        }

        let definitions = claimable.compactMap { key -> (String, AchievementUnlock, AchievementDefinition)? in
            guard let unlock = unlockByKey[key],
                  let definition = AchievementDefinitionCatalog.definition(id: unlock.achievementID) else {
                return nil
            }
            return (key, unlock, definition)
        }
        let validKeys = Set(definitions.map(\.0))
        let missingDefinitions = claimable.filter { !validKeys.contains($0) }
        guard missingDefinitions.isEmpty else {
            return failure(.locked(missingDefinitions), keys: keys, recipientID: recipientID)
        }
        let now = Date()
        let walletDeltas = definitions.compactMap { key, _, definition -> CoconutWalletDelta? in
            guard definition.reward.coconuts > 0 else { return nil }
            return .human(
                recipient,
                delta: definition.reward.coconuts,
                entryKind: .reward,
                source: .service,
                title: "Achievement reward",
                emoji: definition.emoji,
                actorId: recipient.id.uuidString,
                actorName: recipient.name,
                subjectKind: definition.scope == .island ? .household : .human,
                subjectId: definition.scope == .island ? AchievementScopeReference.islandID : recipient.id.uuidString,
                sourceModelName: "AchievementRewardReceipt",
                sourceModelId: key,
                metadataJSON: "{\"achievementID\":\"\(definition.id)\"}",
                occurredAt: now,
                transactionKey: "achievement:\(key)"
            )
        }
        _ = try wallet.apply(
            deltas: walletDeltas,
            context: context,
            save: false,
            postsRewardFeedback: false,
            updatesProjection: false,
            projectionManager: nil
        )

        let stardustAmount = definitions.reduce(0) { $0 + $1.2.reward.stardust }
        if stardustAmount > 0 {
            let balance = try fetchOrCreateStardustBalance(now: now)
            balance.amount += stardustAmount
            balance.updatedAt = now
        }
        for (key, unlock, definition) in definitions {
            context.insert(
                AchievementRewardReceipt(
                    receiptKey: "achievement-reward:\(key)",
                    achievementKey: key,
                    achievementID: definition.id,
                    scopeKindRaw: unlock.scopeKindRaw,
                    scopeIDRaw: unlock.scopeIDRaw,
                    recipientHumanIDRaw: recipient.id.uuidString,
                    claimedAt: now,
                    awardedCoconutAmount: definition.reward.coconuts,
                    awardedStardustAmount: definition.reward.stardust,
                    walletTransactionKey: "achievement:\(key)",
                    createdAt: now
                )
            )
        }
        let save = context.safeSaveResult(publishFailureEvent: true)
        guard save.didSave else {
            context.rollback()
            throw AchievementCommandPersistenceError.saveFailed(
                save.errorDescription ?? "Unable to save achievement rewards."
            )
        }
        wallet.refreshQuestProjection(context: context, manager: projectionManager)
        return AchievementClaimResult(
            claimedKeys: definitions.map(\.0).sorted(),
            recipientID: recipient.id,
            coconutAmount: definitions.reduce(0) { $0 + $1.2.reward.coconuts },
            stardustAmount: stardustAmount,
            failure: nil
        )
    }

    private func fetchActiveHuman(id: UUID) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate { $0.id == id && $0.passedAwayDate == nil }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchUnlocksByRequestedKey(keys: [String]) throws -> [String: AchievementUnlock] {
        var result: [String: AchievementUnlock] = [:]
        for key in keys {
            var descriptor = FetchDescriptor<AchievementUnlock>(
                predicate: #Predicate { $0.achievementKey == key }
            )
            descriptor.fetchLimit = 1
            if let exact = try context.fetch(descriptor).first {
                result[key] = exact
                continue
            }
            guard let achievementID = globalAchievementID(for: key) else { continue }
            var legacyDescriptor = FetchDescriptor<AchievementUnlock>(
                predicate: #Predicate { $0.achievementID == achievementID }
            )
            legacyDescriptor.fetchLimit = 1
            if let legacy = try context.fetch(legacyDescriptor).first {
                result[key] = legacy
            }
        }
        return result
    }

    private func fetchClaimedRequestedKeys(keys: [String]) throws -> Set<String> {
        var result = Set<String>()
        for key in keys {
            var descriptor = FetchDescriptor<AchievementRewardReceipt>(
                predicate: #Predicate { $0.achievementKey == key }
            )
            descriptor.fetchLimit = 1
            if !(try context.fetch(descriptor)).isEmpty {
                result.insert(key)
                continue
            }
            guard let achievementID = globalAchievementID(for: key) else { continue }
            var legacyDescriptor = FetchDescriptor<AchievementRewardReceipt>(
                predicate: #Predicate { $0.achievementID == achievementID }
            )
            legacyDescriptor.fetchLimit = 1
            if !(try context.fetch(legacyDescriptor)).isEmpty {
                result.insert(key)
            }
        }
        return result
    }

    private func globalAchievementID(for key: String) -> String? {
        let prefix = "global::"
        guard key.hasPrefix(prefix) else { return nil }
        let achievementID = String(key.dropFirst(prefix.count))
        guard AchievementDefinitionCatalog.definition(id: achievementID)?.scope == .island else { return nil }
        return achievementID
    }

    private func fetchOrCreateStardustBalance(now: Date) throws -> OasisCritterFragmentBalance {
        let catalogID = OasisCompanionCurrency.stardustCatalogID
        var descriptor = FetchDescriptor<OasisCritterFragmentBalance>(
            predicate: #Predicate { $0.catalogId == catalogID }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let created = OasisCritterFragmentBalance(catalogId: catalogID, updatedAt: now)
        context.insert(created)
        return created
    }

    private func failure(
        _ reason: AchievementClaimFailure,
        keys: [String],
        recipientID: UUID?
    ) -> AchievementClaimResult {
        AchievementClaimResult(
            claimedKeys: [],
            recipientID: recipientID,
            coconutAmount: 0,
            stardustAmount: 0,
            failure: reason
        )
    }
}

private enum AchievementCommandPersistenceError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case let .saveFailed(message): message
        }
    }
}
