//
//  RewardEconomyCommands.swift
//  Ohana
//
//  Domain write boundaries for reward economy commands.
//

import Foundation
import SwiftData

private enum RewardEconomyPersistenceError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case let .saveFailed(message):
            String(
                localized: "reward.economy.persistence.failed",
                defaultValue: "Unable to save reward economy changes: \(message)"
            )
        }
    }
}

private func saveRewardEconomyChanges(context: ModelContext) throws {
    let saveResult = context.safeSaveResult(publishFailureEvent: true)
    guard saveResult.didSave else {
        context.rollback()
        throw RewardEconomyPersistenceError.saveFailed(saveResult.errorDescription ?? "Unknown save failure")
    }
}

private func saveRewardEconomyChangesIfNeeded(context: ModelContext) -> Bool {
    let saveResult = context.safeSaveResult(publishFailureEvent: true)
    guard saveResult.didSave else {
        context.rollback()
        return false
    }
    return true
}

enum PetBondVaultUnlockFailure: Equatable {
    case alreadyUnlocked
    case insufficientBalance
    case walletFrozen
    case persistenceFailed
}

struct PetBondVaultUnlockCommandResult: Equatable {
    let petID: UUID
    let itemID: String
    let cost: Int
    let didUnlock: Bool
    let failure: PetBondVaultUnlockFailure?
    let ledgerEventID: UUID?
}

struct PetCardAppearanceCommandResult: Equatable {
    let petID: UUID
    let action: String
    let didApply: Bool

    init(petID: UUID, action: String, didApply: Bool = true) {
        self.petID = petID
        self.action = action
        self.didApply = didApply
    }
}

enum Avatar2DUpgradeFailure: Equatable {
    case missingProfile
    case noPass
    case memberInactive
    case persistenceFailed
}

struct Avatar2DUpgradeCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let didUpgrade: Bool
    let failure: Avatar2DUpgradeFailure?
}

struct AchievementRewardClaim: Equatable {
    let badgeID: String
    let rewardKey: String
    let emoji: String
    let logTitle: String
    let isUnlocked: Bool
}

struct AchievementRewardCommandResult: Equatable {
    let entityID: UUID
    let entityKind: String
    let badgeIDs: [String]
    let totalAmount: Int
    let updatedClaimedRewardRaw: String
    let didClaim: Bool
}

enum AchievementRewardCommandService {
    @discardableResult
    @MainActor
    static func claimRewards(
        _ claims: [AchievementRewardClaim],
        claimedRewardRaw: String,
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet: CoconutWalletManaging
    ) -> AchievementRewardCommandResult {
        let entityID = human?.id ?? pet.id
        let entityKind = human == nil ? EntityKind.pet.rawValue : EntityKind.human.rawValue
        return PersistenceWriteFence.withExclusiveAccess(
            context: context,
            unavailable: {
                AchievementRewardCommandResult(
                    entityID: entityID,
                    entityKind: entityKind,
                    badgeIDs: claims.map(\.badgeID),
                    totalAmount: 0,
                    updatedClaimedRewardRaw: claimedRewardRaw,
                    didClaim: false
                )
            },
            operation: {
                claimRewardsWhileFenced(
                    claims,
                    claimedRewardRaw: claimedRewardRaw,
                    amountPerBadge: amountPerBadge,
                    human: human,
                    pet: pet,
                    context: context,
                    questManager: providedQuestManager,
                    wallet: wallet
                )
            }
        )
    }

    @MainActor
    private static func claimRewardsWhileFenced(
        _ claims: [AchievementRewardClaim],
        claimedRewardRaw: String,
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet: CoconutWalletManaging
    ) -> AchievementRewardCommandResult {
        let entityID = human?.id ?? pet.id
        let entityKind = human == nil ? EntityKind.pet.rawValue : EntityKind.human.rawValue
        let canWriteWallet = if let human {
            EconomyWalletWritePolicy.canWrite(human)
        } else {
            EconomyWalletWritePolicy.canWrite(pet)
        }
        guard canWriteWallet else {
            return AchievementRewardCommandResult(
                entityID: entityID,
                entityKind: entityKind,
                badgeIDs: claims.map(\.badgeID),
                totalAmount: 0,
                updatedClaimedRewardRaw: claimedRewardRaw,
                didClaim: false
            )
        }
        var claimedIDs = Set(claimedRewardRaw.split(separator: ",").map(String.init))
        let durableReceipts = (try? context.fetch(FetchDescriptor<AchievementRewardReceipt>())) ?? []
        var durableReceiptKeys = Set(durableReceipts.map(\.achievementKey))
        durableReceiptKeys.formUnion(
            durableReceipts
                .filter { $0.achievementID.hasPrefix("global_") }
                .map { AchievementScopeReference.island.achievementKey(for: $0.achievementID) }
        )
        claimedIDs.formUnion(durableReceiptKeys)
        let claimable = claims.filter { claim in
            claim.isUnlocked && !claimedIDs.contains(claim.rewardKey)
        }
        guard amountPerBadge > 0, !claimable.isEmpty else {
            return AchievementRewardCommandResult(
                entityID: entityID,
                entityKind: entityKind,
                badgeIDs: claims.map(\.badgeID),
                totalAmount: 0,
                updatedClaimedRewardRaw: claimedRewardRaw,
                didClaim: false
            )
        }

        // Global facts belong to the island but their coconut reward must have
        // an explicit active Human recipient. Never fall back to a Pet wallet
        // or partially claim a mixed batch.
        guard human != nil || !claimable.contains(where: { $0.badgeID.hasPrefix("global_") }) else {
            return AchievementRewardCommandResult(
                entityID: entityID,
                entityKind: entityKind,
                badgeIDs: claims.map(\.badgeID),
                totalAmount: 0,
                updatedClaimedRewardRaw: claimedIDs.sorted().joined(separator: ","),
                didClaim: false
            )
        }

        for claim in claimable {
            claimedIDs.insert(claim.rewardKey)
        }

        let totalAmount = claimable.count * amountPerBadge
        let questManager = providedQuestManager ?? QuestManager()
        let walletDeltas = achievementWalletDeltas(
            claimable,
            amountPerBadge: amountPerBadge,
            human: human,
            pet: pet,
            entityKind: entityKind
        )
        do {
            try wallet.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: questManager
            )
            try persistAchievementFacts(
                claimable,
                amountPerBadge: amountPerBadge,
                human: human,
                pet: pet,
                context: context
            )
            try saveRewardEconomyChanges(context: context)
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            #if DEBUG
                OhanaLog.error("[AchievementRewardCommandService] wallet write failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return AchievementRewardCommandResult(
                entityID: entityID,
                entityKind: entityKind,
                badgeIDs: claims.map(\.badgeID),
                totalAmount: 0,
                updatedClaimedRewardRaw: claimedRewardRaw,
                didClaim: false
            )
        }
        let updatedRaw = claimedIDs.sorted().joined(separator: ",")
        UserDefaults.standard.set(updatedRaw, forKey: "achievement_claimedRewardIDs")

        return AchievementRewardCommandResult(
            entityID: entityID,
            entityKind: entityKind,
            badgeIDs: claimable.map(\.badgeID),
            totalAmount: totalAmount,
            updatedClaimedRewardRaw: updatedRaw,
            didClaim: true
        )
    }

    private static func achievementWalletDeltas(
        _ claims: [AchievementRewardClaim],
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        entityKind: String
    ) -> [CoconutWalletDelta] {
        claims.map { claim in
            if let human {
                return .human(
                    human,
                    delta: amountPerBadge,
                    entryKind: .reward,
                    source: .service,
                    title: claim.logTitle,
                    emoji: claim.emoji,
                    actorId: human.id.uuidString,
                    actorName: human.name,
                    subjectKind: .human,
                    subjectId: human.id.uuidString,
                    sourceModelName: "AchievementReward",
                    sourceModelId: claim.rewardKey,
                    metadataJSON: "{\"badgeId\":\"\(claim.badgeID)\",\"entityKind\":\"\(entityKind)\"}",
                    transactionKey: "achievement:\(claim.rewardKey)"
                )
            }
            return .pet(
                pet,
                delta: amountPerBadge,
                entryKind: .reward,
                source: .service,
                title: claim.logTitle,
                emoji: claim.emoji,
                actorId: pet.id.uuidString,
                actorName: pet.name,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                sourceModelName: "AchievementReward",
                sourceModelId: claim.rewardKey,
                metadataJSON: "{\"badgeId\":\"\(claim.badgeID)\",\"entityKind\":\"\(entityKind)\"}",
                transactionKey: "achievement:\(claim.rewardKey)"
            )
        }
    }

    private static func persistAchievementFacts(
        _ claims: [AchievementRewardClaim],
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        context: ModelContext
    ) throws {
        let now = Date()
        let stardustAmount = claims.reduce(0) { total, claim in
                total + (AchievementDefinitionCatalog.definition(id: claim.badgeID)?.reward.stardust ?? 0)
            }
        if stardustAmount > 0 {
            let catalogID = OasisCompanionCurrency.stardustCatalogID
            var descriptor = FetchDescriptor<OasisCritterFragmentBalance>(
                predicate: #Predicate { $0.catalogId == catalogID }
            )
            descriptor.fetchLimit = 1
            let balance: OasisCritterFragmentBalance
            if let existing = try context.fetch(descriptor).first {
                balance = existing
            } else {
                balance = OasisCritterFragmentBalance(catalogId: catalogID, updatedAt: now)
                context.insert(balance)
            }
            balance.amount += stardustAmount
            balance.updatedAt = now
        }
        for claim in claims {
                let rewardKey = claim.rewardKey
                let scopeKind: AchievementScopeKind
                let scopeID: String
                if claim.badgeID.hasPrefix("global_") {
                    scopeKind = .island
                    scopeID = AchievementScopeReference.islandID
                } else if let human {
                    scopeKind = .human
                    scopeID = human.id.uuidString
                } else {
                    scopeKind = .pet
                    scopeID = pet.id.uuidString
                }
                var unlockDescriptor = FetchDescriptor<AchievementUnlock>(
                    predicate: #Predicate { $0.achievementKey == rewardKey }
                )
                unlockDescriptor.fetchLimit = 1
                if try context.fetch(unlockDescriptor).isEmpty {
                    context.insert(
                        AchievementUnlock(
                            achievementKey: rewardKey,
                            achievementID: claim.badgeID,
                            scopeKindRaw: scopeKind.rawValue,
                            scopeIDRaw: scopeID,
                            unlockedAt: now,
                            createdAt: now
                        )
                    )
                }
                let definition = AchievementDefinitionCatalog.definition(id: claim.badgeID)
                context.insert(
                    AchievementRewardReceipt(
                        receiptKey: "achievement-reward:\(rewardKey)",
                        achievementKey: rewardKey,
                        achievementID: claim.badgeID,
                        scopeKindRaw: scopeKind.rawValue,
                        scopeIDRaw: scopeID,
                        recipientHumanIDRaw: human?.id.uuidString ?? "",
                        claimedAt: now,
                        awardedCoconutAmount: amountPerBadge,
                        awardedStardustAmount: definition?.reward.stardust ?? 0,
                        walletTransactionKey: "achievement:\(rewardKey)",
                        createdAt: now
                    )
                )
        }
    }
}

struct BackdateCheckInCommandResult: Equatable {
    let petID: UUID
    let humanID: UUID?
    let actionKey: String
    let humanGot: Int
    let petGot: Int

    var totalCoconuts: Int { humanGot + petGot }
    var didAward: Bool { totalCoconuts > 0 }
}
enum BackdateCheckInCommandService {
    @discardableResult
    @MainActor
    static func award(
        action: QuestManager.OhanaActionType,
        actionKey: String,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()
    ) -> BackdateCheckInCommandResult {
        let human = currentActiveHuman(context: context, activeHumanSelection: activeHumanSelection)
        let questManager = providedQuestManager ?? QuestManager()
        let reward = EconomyRewardDiscipline.awardNonCareReward(
            type: action,
            pet: pet,
            context: context,
            executorId: human?.id.uuidString,
            questManager: questManager
        )
        return BackdateCheckInCommandResult(
            petID: pet.id,
            humanID: human?.id,
            actionKey: actionKey,
            humanGot: reward.humanGot,
            petGot: reward.petGot
        )
    }

    @MainActor
    private static func currentActiveHuman(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting
    ) -> Human? {
        guard let activeID = activeHumanSelection.currentHumanId else { return nil }
        guard let id = UUID(uuidString: activeID) else {
            OhanaLog.warning(
                "[BackdateCheckInCommandService] active humanId=\(activeID) is invalid",
                category: "Economy"
            )
            return nil
        }
        let descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "[BackdateCheckInCommandService] failed to fetch active humanId=\(activeID): \(error.localizedDescription)",
                category: "Economy"
            )
            return nil
        }
    }
}

enum ShopPurchaseFailure: Equatable {
    case invalidItem
    case missingActiveHuman
    case insufficientBalance(missing: Int)
    case walletFrozen
    case backupOrRestoreInProgress
    case persistenceFailed
}

struct ShopPurchaseCommandResult: Equatable {
    let attemptID: UUID?
    let humanID: UUID?
    let itemID: String
    let cost: Int
    let didPurchase: Bool
    let failure: ShopPurchaseFailure?
    let ledgerEventID: UUID?
    let transactionKey: String?
    let fundingContributions: [ShopPurchaseFundingContribution]
}

nonisolated struct ShopPurchaseFundingContribution: Codable, Equatable, Sendable {
    let humanID: UUID
    let amount: Int
}

nonisolated enum ShopPurchaseFundingSnapshotValidator {
    static func isValid(
        _ contributions: [ShopPurchaseFundingContribution],
        expectedTotal: Int
    ) -> Bool {
        guard expectedTotal >= 0 else { return false }
        guard expectedTotal > 0 else { return contributions.isEmpty }
        guard !contributions.isEmpty else { return false }

        var seenHumanIDs = Set<UUID>()
        var total = 0
        for contribution in contributions {
            guard contribution.amount > 0,
                  seenHumanIDs.insert(contribution.humanID).inserted else {
                return false
            }
            let addition = total.addingReportingOverflow(contribution.amount)
            guard !addition.overflow else { return false }
            total = addition.partialValue
        }
        return total == expectedTotal
    }
}

nonisolated struct ShopPurchaseFulfillmentPayload: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let version: Int
    let purchasedAt: Date
    var treeEnergyXP: Int?

    init(purchasedAt: Date, treeEnergyXP: Int? = nil) {
        version = Self.currentVersion
        self.purchasedAt = purchasedAt
        self.treeEnergyXP = treeEnergyXP
    }
}

enum ShopPurchaseCommandService {
    private enum PurchasePreflight {
        case ready(ShopItem, Human)
        case finished(ShopPurchaseCommandResult)
    }

    private struct PurchasePreparation {
        let transactionKey: String
        let purchasedAt: Date
        let ledger: CareLedgerEvent
        let walletMutations: [CoconutHumanWalletMutation]
        let contributionSnapshots: [ShopPurchaseFundingContribution]
        let attempt: ShopPurchaseAttempt?
    }

    @discardableResult
    @MainActor
    static func purchase(
        item submittedItem: ShopItem,
        buyer: Human?,
        itemName: String,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording
    ) -> ShopPurchaseCommandResult {
        ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: {
                ShopPurchaseCommandResult(
                    attemptID: nil,
                    humanID: buyer?.id,
                    itemID: submittedItem.id,
                    cost: submittedItem.cost,
                    didPurchase: false,
                    failure: .backupOrRestoreInProgress,
                    ledgerEventID: nil,
                    transactionKey: nil,
                    fundingContributions: []
                )
            },
            operation: {
                purchaseWhileFenced(
                    item: submittedItem,
                    buyer: buyer,
                    itemName: itemName,
                    context: context,
                    questManager: providedQuestManager,
                    wallet: wallet,
                    careLedger: careLedger
                )
            }
        )
    }

    @MainActor
    private static func purchaseWhileFenced(
        item submittedItem: ShopItem,
        buyer: Human?,
        itemName: String,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording
    ) -> ShopPurchaseCommandResult {
        let item: ShopItem
        let readyBuyer: Human
        switch purchasePreflight(item: submittedItem, buyer: buyer, context: context) {
        case let .ready(readyItem, resolvedBuyer):
            item = readyItem
            readyBuyer = resolvedBuyer
        case let .finished(result):
            return result
        }
        let buyer = readyBuyer
        let fundingPlan = CoconutWalletFundingPlanner.humanCofundingPlan(
            cost: item.cost,
            primaryHuman: buyer,
            context: context,
            logPrefix: "ShopPurchaseCommandService"
        )
        guard fundingPlan.missing == 0 else {
            return purchaseFailure(
                item: item,
                humanID: buyer.id,
                failure: .insufficientBalance(missing: fundingPlan.missing)
            )
        }

        let preparation = preparePurchase(
            item: item,
            buyer: buyer,
            itemName: itemName,
            fundingPlan: fundingPlan,
            careLedger: careLedger,
            context: context
        )
        do {
            try CoconutWalletMutationWriter.applyHumanMutations(
                preparation.walletMutations,
                wallet: wallet,
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: providedQuestManager ?? QuestManager()
            )
            if let attempt = preparation.attempt {
                context.insert(attempt)
            } else {
                try ShopPurchaseRecordStore.insertOwnershipRecordIfNeeded(
                    item: item,
                    buyer: buyer,
                    transactionKey: preparation.transactionKey,
                    context: context,
                    purchasedAt: preparation.purchasedAt
                )
            }
            try saveRewardEconomyChanges(context: context)
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: providedQuestManager)
            let failure: ShopPurchaseFailure = if let walletError = error as? CoconutWalletError,
                                                  case let .insufficientBalance(_, missing) = walletError {
                .insufficientBalance(missing: missing)
            } else if let walletError = error as? CoconutWalletError,
                      case .walletFrozen = walletError {
                .walletFrozen
            } else {
                .persistenceFailed
            }
            return purchaseFailure(item: item, humanID: buyer.id, failure: failure)
        }

        return ShopPurchaseCommandResult(
            attemptID: preparation.attempt?.id,
            humanID: buyer.id,
            itemID: item.id,
            cost: item.cost,
            didPurchase: true,
            failure: nil,
            ledgerEventID: preparation.ledger.id,
            transactionKey: preparation.transactionKey,
            fundingContributions: preparation.contributionSnapshots
        )
    }

    private static func purchasePreflight(
        item submittedItem: ShopItem,
        buyer: Human?,
        context: ModelContext
    ) -> PurchasePreflight {
        guard let item = ShopCatalog.item(id: submittedItem.id),
              submittedItem.emoji == item.emoji,
              submittedItem.nameText == item.nameText,
              submittedItem.descriptionText == item.descriptionText,
              submittedItem.cost == item.cost,
              submittedItem.category == item.category,
              submittedItem.isConsumable == item.isConsumable,
              submittedItem.appIcon == item.appIcon else {
            return .finished(ShopPurchaseCommandResult(
                attemptID: nil,
                humanID: buyer?.id,
                itemID: submittedItem.id,
                cost: submittedItem.cost,
                didPurchase: false,
                failure: .invalidItem,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            ))
        }
        guard item.cost > 0 else {
            return .finished(ShopPurchaseCommandResult(
                attemptID: nil,
                humanID: buyer?.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: true,
                failure: nil,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            ))
        }
        guard let buyer else {
            return .finished(ShopPurchaseCommandResult(
                attemptID: nil,
                humanID: nil,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .missingActiveHuman,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            ))
        }
        guard EconomyWalletWritePolicy.canWrite(buyer) else {
            return .finished(ShopPurchaseCommandResult(
                attemptID: nil,
                humanID: buyer.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .walletFrozen,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            ))
        }
        if !item.isConsumable {
            do {
                if try ShopPurchaseRecordStore.isOwned(itemID: item.id, context: context) {
                    return .finished(ShopPurchaseCommandResult(
                        attemptID: nil,
                        humanID: buyer.id,
                        itemID: item.id,
                        cost: item.cost,
                        didPurchase: true,
                        failure: nil,
                        ledgerEventID: nil,
                        transactionKey: nil,
                        fundingContributions: []
                    ))
                }
                if item.appIcon != nil,
                   let pending = try pendingAttempt(itemID: item.id, context: context) {
                    return .finished(pendingResult(for: pending))
                }
            } catch {
                return .finished(ShopPurchaseCommandResult(
                    attemptID: nil,
                    humanID: buyer.id,
                    itemID: item.id,
                    cost: item.cost,
                    didPurchase: false,
                    failure: .persistenceFailed,
                    ledgerEventID: nil,
                    transactionKey: nil,
                    fundingContributions: []
                ))
            }
        }
        if item.isConsumable {
            do {
                if let pending = try pendingAttempt(itemID: item.id, context: context) {
                    return .finished(pendingResult(for: pending))
                }
            } catch {
                return .finished(ShopPurchaseCommandResult(
                    attemptID: nil,
                    humanID: buyer.id,
                    itemID: item.id,
                    cost: item.cost,
                    didPurchase: false,
                    failure: .persistenceFailed,
                    ledgerEventID: nil,
                    transactionKey: nil,
                    fundingContributions: []
                ))
            }
        }
        return .ready(item, buyer)
    }

    private static func preparePurchase(
        item: ShopItem,
        buyer: Human,
        itemName: String,
        fundingPlan: CoconutWalletFundingPlan,
        careLedger: CareLedgerRecording,
        context: ModelContext
    ) -> PurchasePreparation {
        let purchaseID = UUID()
        let purchasedAt = Date()
        let transactionKey = "shop:\(item.id):\(buyer.id.uuidString):\(purchaseID.uuidString)"
        let cofundingMetadata = fundingPlan.contributions.count > 1
            ? ",\"cofunded\":true,\"fundingSourceCount\":\(fundingPlan.contributions.count)"
            : ""
        let metadataJSON = "{\"shopItemId\":\"\(item.id)\",\"purchaseId\":\"\(purchaseID.uuidString)\",\"consumable\":\(item.isConsumable)\(cofundingMetadata)}"
        let ledger = careLedger.record(
            occurredAt: purchasedAt,
            actorKind: .human,
            actorId: buyer.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "shopPurchase",
            amountValue: 0,
            amountUnit: "",
            note: itemName,
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: -item.cost,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: false
        )
        let walletMutations = fundingPlan.contributions.map { contribution in
            let isBuyer = contribution.human.id == buyer.id
            return CoconutHumanWalletMutation(
                human: contribution.human,
                delta: -contribution.amount,
                entryKind: isBuyer ? .spend : .transferOut,
                source: .shop,
                title: itemName,
                emoji: item.emoji,
                actorId: contribution.human.id.uuidString,
                actorName: contribution.human.name,
                subjectKind: isBuyer ? .system : .human,
                subjectId: isBuyer ? nil : buyer.id.uuidString,
                sourceModelName: "ShopCatalog",
                sourceModelId: item.id,
                careLedgerEventId: ledger.id.uuidString,
                metadataJSON: metadataJSON,
                transactionKey: fundingPlan.contributions.count == 1
                    ? transactionKey
                    : "\(transactionKey):\(contribution.human.id.uuidString)"
            )
        }
        let contributionSnapshots = fundingPlan.contributions.map {
            ShopPurchaseFundingContribution(humanID: $0.human.id, amount: $0.amount)
        }
        let needsDeferredFulfillment = item.isConsumable || item.appIcon != nil
        let attempt: ShopPurchaseAttempt? = if needsDeferredFulfillment {
            ShopPurchaseAttempt(
                id: purchaseID,
                transactionKey: transactionKey,
                itemId: item.id,
                buyerHumanId: buyer.id.uuidString,
                price: item.cost,
                state: .purchased,
                purchaseLedgerEventId: ledger.id,
                fundingContributionsJSON: encode(contributionSnapshots),
                fulfillmentPayloadJSON: encode(ShopPurchaseFulfillmentPayload(purchasedAt: purchasedAt)),
                nextRetryAt: item.appIcon == nil ? nil : purchasedAt.addingTimeInterval(60),
                createdAt: purchasedAt,
                updatedAt: purchasedAt
            )
        } else {
            nil
        }
        return PurchasePreparation(
            transactionKey: transactionKey,
            purchasedAt: purchasedAt,
            ledger: ledger,
            walletMutations: walletMutations,
            contributionSnapshots: contributionSnapshots,
            attempt: attempt
        )
    }

    private static func purchaseFailure(
        item: ShopItem,
        humanID: UUID?,
        failure: ShopPurchaseFailure
    ) -> ShopPurchaseCommandResult {
        ShopPurchaseCommandResult(
            attemptID: nil,
            humanID: humanID,
            itemID: item.id,
            cost: item.cost,
            didPurchase: false,
            failure: failure,
            ledgerEventID: nil,
            transactionKey: nil,
            fundingContributions: []
        )
    }

    private static func pendingAttempt(
        itemID: String,
        context: ModelContext
    ) throws -> ShopPurchaseAttempt? {
        let fulfilled = ShopPurchaseAttemptState.fulfilled.rawValue
        let refunded = ShopPurchaseAttemptState.refunded.rawValue
        var descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.itemId == itemID &&
                    attempt.stateRaw != fulfilled &&
                    attempt.stateRaw != refunded
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func pendingResult(for attempt: ShopPurchaseAttempt) -> ShopPurchaseCommandResult {
        let contributions = decode(
            [ShopPurchaseFundingContribution].self,
            from: attempt.fundingContributionsJSON
        ) ?? []
        let remainsFulfillable = attempt.state == .purchased || attempt.state == .fulfilling
        return ShopPurchaseCommandResult(
            attemptID: attempt.id,
            humanID: UUID(uuidString: attempt.buyerHumanId),
            itemID: attempt.itemId,
            cost: attempt.price,
            didPurchase: remainsFulfillable,
            failure: remainsFulfillable ? nil : .persistenceFailed,
            ledgerEventID: attempt.purchaseLedgerEventId,
            transactionKey: attempt.transactionKey,
            fundingContributions: contributions
        )
    }

    private static func encode(_ value: some Encodable) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    private static func decode<Value: Decodable>(_: Value.Type, from raw: String) -> Value? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }
}

enum PetBondVaultUnlockCommandService {
    @discardableResult
    @MainActor
    static func unlock(
        item: PetBondVaultItem,
        pet: Pet,
        title: String,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording
    ) -> PetBondVaultUnlockCommandResult {
        guard EconomyWalletWritePolicy.canWrite(pet) else {
            return PetBondVaultUnlockCommandResult(
                petID: pet.id,
                itemID: item.id,
                cost: item.cost,
                didUnlock: false,
                failure: .walletFrozen,
                ledgerEventID: nil
            )
        }
        guard item.isRepeatable || !PetBondVaultStore.isUnlocked(item.kind, for: pet.id) else {
            return PetBondVaultUnlockCommandResult(
                petID: pet.id,
                itemID: item.id,
                cost: item.cost,
                didUnlock: false,
                failure: .alreadyUnlocked,
                ledgerEventID: nil
            )
        }
        let petBalance = CoconutWalletService.balance(for: pet, context: context)
        guard petBalance >= item.cost else {
            return PetBondVaultUnlockCommandResult(
                petID: pet.id,
                itemID: item.id,
                cost: item.cost,
                didUnlock: false,
                failure: .insufficientBalance,
                ledgerEventID: nil
            )
        }

        let actionType = item.isRepeatable ? "petBondVaultConsume" : "petBondVaultUnlock"
        let metadataJSON = "{\"itemId\":\"\(item.id)\",\"economy\":\"petBondVault\",\"repeatable\":\(item.isRepeatable)}"
        let transactionKey = item.isRepeatable
            ? "petBondVault:consume:\(item.id):\(pet.id.uuidString):\(UUID().uuidString)"
            : "petBondVault:\(item.id):\(pet.id.uuidString)"
        let ledger = careLedger.record(
            occurredAt: Date(),
            actorKind: .pet,
            actorId: pet.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .coconut,
            actionType: actionType,
            amountValue: 0,
            amountUnit: "",
            note: title,
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: -item.cost,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: false
        )
        do {
            try wallet.apply(
                deltas: [
                    .pet(
                        pet,
                        delta: -item.cost,
                        entryKind: .spend,
                        source: .shop,
                        title: title,
                        emoji: "🐾",
                        actorId: pet.id.uuidString,
                        actorName: pet.name,
                        subjectKind: .pet,
                        subjectId: pet.id.uuidString,
                        sourceModelName: "PetBondVaultItem",
                        sourceModelId: item.id,
                        careLedgerEventId: ledger.id.uuidString,
                        metadataJSON: metadataJSON,
                        transactionKey: transactionKey
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: providedQuestManager ?? QuestManager()
            )
            try saveRewardEconomyChanges(context: context)
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: providedQuestManager)
            let failure: PetBondVaultUnlockFailure = if let walletError = error as? CoconutWalletError,
                                                        case .insufficientBalance = walletError {
                .insufficientBalance
            } else if let walletError = error as? CoconutWalletError,
                      case .walletFrozen = walletError {
                .walletFrozen
            } else {
                .persistenceFailed
            }
            return PetBondVaultUnlockCommandResult(
                petID: pet.id,
                itemID: item.id,
                cost: item.cost,
                didUnlock: false,
                failure: failure,
                ledgerEventID: nil
            )
        }
        if item.isRepeatable {
            PetBondVaultStore.consume(item.kind, for: pet.id)
        } else {
            PetBondVaultStore.unlock(item.kind, for: pet.id)
        }

        return PetBondVaultUnlockCommandResult(
            petID: pet.id,
            itemID: item.id,
            cost: item.cost,
            didUnlock: true,
            failure: nil,
            ledgerEventID: ledger.id
        )
    }
}

enum PetCardAppearanceCommandService {
    @discardableResult
    @MainActor
    static func enablePopout(
        pet: Pet,
        imageData: Data,
        sourceRaw: String,
        context: ModelContext
    ) -> PetCardAppearanceCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .presentationPreference).writesContent else {
            return PetCardAppearanceCommandResult(petID: pet.id, action: "enablePopout", didApply: false)
        }
        pet.updateCardPopoutImageData(imageData)
        pet.cardPopoutSourceRaw = sourceRaw
        pet.cardStyleRaw = "popout"
        guard saveRewardEconomyChangesIfNeeded(context: context) else {
            return PetCardAppearanceCommandResult(petID: pet.id, action: "enablePopout", didApply: false)
        }
        return PetCardAppearanceCommandResult(petID: pet.id, action: "enablePopout")
    }

    @discardableResult
    @MainActor
    static func restoreClassic(
        pet: Pet,
        context: ModelContext
    ) -> PetCardAppearanceCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .presentationPreference).writesContent else {
            return PetCardAppearanceCommandResult(petID: pet.id, action: "restoreClassic", didApply: false)
        }
        pet.cardStyleRaw = "classic"
        guard saveRewardEconomyChangesIfNeeded(context: context) else {
            return PetCardAppearanceCommandResult(petID: pet.id, action: "restoreClassic", didApply: false)
        }
        return PetCardAppearanceCommandResult(petID: pet.id, action: "restoreClassic")
    }
}

enum Avatar2DUpgradeCommandService {
    @discardableResult
    @MainActor
    static func upgradeHuman(
        _ human: Human,
        context: ModelContext
    ) -> Avatar2DUpgradeCommandResult {
        ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: {
                Avatar2DUpgradeCommandResult(
                    entityID: human.id,
                    kind: EntityKind.human.rawValue,
                    didUpgrade: false,
                    failure: .persistenceFailed
                )
            },
            operation: {
                upgradeHumanWhileFenced(human, context: context)
            }
        )
    }

    @MainActor
    private static func upgradeHumanWhileFenced(
        _ human: Human,
        context: ModelContext
    ) -> Avatar2DUpgradeCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .presentationPreference).writesContent else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .memberInactive
            )
        }
        let rawGender = HumanProfileOptions.normalizedGender(human.genderRaw)
        let avatarGender: String = switch rawGender {
        case "男", "女", "非二元":
            rawGender
        default:
            "非二元"
        }

        guard let data = HumanAvatarAssetCatalog.avatarData(gender: avatarGender, birthday: human.birthday) else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .missingProfile
            )
        }
        guard Avatar2DAccess.extraPassCount > 0 else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .noPass
            )
        }

        human.updateAvatarImageData(data)
        human.avatarEmoji = HumanGenderIdentity.fallbackAvatarEmoji(for: avatarGender)
        guard saveRewardEconomyChangesIfNeeded(context: context) else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .persistenceFailed
            )
        }
        Avatar2DAccess.consumeExtraPass()
        return Avatar2DUpgradeCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            didUpgrade: true,
            failure: nil
        )
    }

    @discardableResult
    @MainActor
    static func upgradePet(
        _ pet: Pet,
        context: ModelContext
    ) -> Avatar2DUpgradeCommandResult {
        ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: {
                Avatar2DUpgradeCommandResult(
                    entityID: pet.id,
                    kind: EntityKind.pet.rawValue,
                    didUpgrade: false,
                    failure: .persistenceFailed
                )
            },
            operation: {
                upgradePetWhileFenced(pet, context: context)
            }
        )
    }

    @MainActor
    private static func upgradePetWhileFenced(
        _ pet: Pet,
        context: ModelContext
    ) -> Avatar2DUpgradeCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .presentationPreference).writesContent else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .memberInactive
            )
        }
        guard let data = PetAvatarAssetCatalog.avatarData(
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            coatColor: pet.coatColor
        ) else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .missingProfile
            )
        }
        guard Avatar2DAccess.extraPassCount > 0 else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .noPass
            )
        }

        pet.updateAvatarImageData(data)
        guard saveRewardEconomyChangesIfNeeded(context: context) else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .persistenceFailed
            )
        }
        Avatar2DAccess.consumeExtraPass()
        return Avatar2DUpgradeCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            didUpgrade: true,
            failure: nil
        )
    }
}

@MainActor
struct RewardEconomyCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let wallet: CoconutWalletManaging
    let careLedger: CareLedgerRecording
    let activeHumanSelection: ActiveHumanSelecting

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            activeHumanSelection: UserDefaultsActiveHumanSelection()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            activeHumanSelection: UserDefaultsActiveHumanSelection()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            wallet: services.coconutWallet,
            careLedger: services.careLedger,
            activeHumanSelection: services.activeHumanSelection
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        activeHumanSelection: ActiveHumanSelecting
    ) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
        self.wallet = wallet
        self.careLedger = careLedger
        self.activeHumanSelection = activeHumanSelection
    }

    @discardableResult
    func purchase(
        item: ShopItem,
        buyer: Human?,
        itemName: String,
        note: String
    ) -> ShopPurchaseCommandResult {
        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: itemName,
            context: context,
            questManager: questManager,
            wallet: wallet,
            careLedger: careLedger
        )
        revisions.publishShopPurchase(result, note: note)
        return result
    }

    @discardableResult
    func claimAchievementRewards(
        _ claims: [AchievementRewardClaim],
        claimedRewardRaw: String,
        amountPerBadge: Int,
        human: Human?,
        pet: Pet,
        questManager: QuestManager? = nil,
        note: String
    ) -> AchievementRewardCommandResult {
        let result = AchievementRewardCommandService.claimRewards(
            claims,
            claimedRewardRaw: claimedRewardRaw,
            amountPerBadge: amountPerBadge,
            human: human,
            pet: pet,
            context: context,
            questManager: questManager ?? self.questManager,
            wallet: wallet
        )
        revisions.publishAchievementReward(result, note: note)
        return result
    }
    @discardableResult
    func awardBackdateCheckIn(
        action: QuestManager.OhanaActionType,
        actionKey: String,
        pet: Pet,
        questManager: QuestManager? = nil,
        note: String
    ) -> BackdateCheckInCommandResult {
        let result = BackdateCheckInCommandService.award(
            action: action,
            actionKey: actionKey,
            pet: pet,
            context: context,
            questManager: questManager ?? self.questManager,
            activeHumanSelection: activeHumanSelection
        )
        revisions.publishBackdateCheckIn(result, note: note)
        return result
    }
    @discardableResult
    func awardBackdateCheckIn(
        actionKey: String,
        pet: Pet,
        questManager: QuestManager? = nil,
        note: String
    ) -> BackdateCheckInCommandResult {
        awardBackdateCheckIn(
            action: backdateActionType(for: actionKey),
            actionKey: actionKey,
            pet: pet,
            questManager: questManager,
            note: note
        )
    }

    private func backdateActionType(for actionKey: String) -> QuestManager.OhanaActionType {
        switch actionKey {
        case "feed":
            .feed
        case "water":
            .water
        case "potty":
            .potty(isLitter: false)
        case "walk":
            .walk(distanceMeters: 300)
        default:
            .general(
                humanReward: 1,
                petReward: 0,
                emoji: "📅",
                title: "Backdate check-in"
            )
        }
    }

    @discardableResult
    func unlockBondVaultItem(
        _ item: PetBondVaultItem,
        pet: Pet,
        title: String,
        note: String
    ) -> PetBondVaultUnlockCommandResult {
        let result = PetBondVaultUnlockCommandService.unlock(
            item: item,
            pet: pet,
            title: title,
            context: context,
            questManager: questManager,
            wallet: wallet,
            careLedger: careLedger
        )
        revisions.publishPetBondVaultUnlock(result, note: note)
        return result
    }

    @discardableResult
    func enablePetPopoutCard(
        pet: Pet,
        imageData: Data,
        sourceRaw: String,
        note: String
    ) -> PetCardAppearanceCommandResult {
        let result = PetCardAppearanceCommandService.enablePopout(
            pet: pet,
            imageData: imageData,
            sourceRaw: sourceRaw,
            context: context
        )
        revisions.publishPetCardAppearance(result, note: note)
        return result
    }

    @discardableResult
    func restoreClassicPetCard(
        pet: Pet,
        note: String
    ) -> PetCardAppearanceCommandResult {
        let result = PetCardAppearanceCommandService.restoreClassic(pet: pet, context: context)
        revisions.publishPetCardAppearance(result, note: note)
        return result
    }

    @discardableResult
    func upgradeHumanTo2DAvatar(
        _ human: Human,
        note: String
    ) -> Avatar2DUpgradeCommandResult {
        let result = Avatar2DUpgradeCommandService.upgradeHuman(human, context: context)
        revisions.publishAvatar2DUpgrade(result, note: note)
        return result
    }

    @discardableResult
    func upgradePetTo2DAvatar(
        _ pet: Pet,
        note: String
    ) -> Avatar2DUpgradeCommandResult {
        let result = Avatar2DUpgradeCommandService.upgradePet(pet, context: context)
        revisions.publishAvatar2DUpgrade(result, note: note)
        return result
    }
}
