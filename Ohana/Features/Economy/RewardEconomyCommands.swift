//
//  RewardEconomyCommands.swift
//  Ohana
//
//  Domain write boundaries for reward economy commands.
//

import Foundation
import SwiftData

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
}

enum Avatar2DUpgradeFailure: Equatable {
    case missingProfile
    case noPass
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

        for claim in claimable {
            claimedIDs.insert(claim.rewardKey)
        }

        let totalAmount = claimable.count * amountPerBadge
        let questManager = providedQuestManager ?? QuestManager()
        let walletDeltas: [CoconutWalletDelta] = claimable.map { claim in
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
        do {
            try wallet.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: questManager
            )
            try context.save()
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
    case missingActiveHuman
    case insufficientBalance(missing: Int)
    case walletFrozen
    case persistenceFailed
}

struct ShopPurchaseCommandResult: Equatable {
    let humanID: UUID?
    let itemID: String
    let cost: Int
    let didPurchase: Bool
    let failure: ShopPurchaseFailure?
    let ledgerEventID: UUID?
    let transactionKey: String?
    let fundingContributions: [ShopPurchaseFundingContribution]
}

struct ShopPurchaseFundingContribution: Equatable {
    let humanID: UUID
    let amount: Int
}

enum ShopPurchaseCommandService {
    @discardableResult
    @MainActor
    static func purchase(
        item: ShopItem,
        buyer: Human?,
        itemName: String,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording
    ) -> ShopPurchaseCommandResult {
        guard item.cost > 0 else {
            return ShopPurchaseCommandResult(
                humanID: buyer?.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: true,
                failure: nil,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            )
        }
        guard let buyer else {
            return ShopPurchaseCommandResult(
                humanID: nil,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .missingActiveHuman,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            )
        }
        guard EconomyWalletWritePolicy.canWrite(buyer) else {
            return ShopPurchaseCommandResult(
                humanID: buyer.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .walletFrozen,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            )
        }
        if !item.isConsumable {
            do {
                if try ShopPurchaseRecordStore.isOwned(itemID: item.id, context: context) {
                    return ShopPurchaseCommandResult(
                        humanID: buyer.id,
                        itemID: item.id,
                        cost: item.cost,
                        didPurchase: true,
                        failure: nil,
                        ledgerEventID: nil,
                        transactionKey: nil,
                        fundingContributions: []
                    )
                }
            } catch {
                return ShopPurchaseCommandResult(
                    humanID: buyer.id,
                    itemID: item.id,
                    cost: item.cost,
                    didPurchase: false,
                    failure: .persistenceFailed,
                    ledgerEventID: nil,
                    transactionKey: nil,
                    fundingContributions: []
                )
            }
        }
        let fundingPlan = CoconutWalletFundingPlanner.humanCofundingPlan(
            cost: item.cost,
            primaryHuman: buyer,
            context: context,
            logPrefix: "ShopPurchaseCommandService"
        )
        guard fundingPlan.missing == 0 else {
            return ShopPurchaseCommandResult(
                humanID: buyer.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: .insufficientBalance(missing: fundingPlan.missing),
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            )
        }

        let purchaseID = UUID()
        let transactionKey = item.isConsumable
            ? "shop:\(item.id):\(buyer.id.uuidString):\(purchaseID.uuidString)"
            : "shop:\(item.id):\(buyer.id.uuidString)"
        let cofundingMetadata = fundingPlan.contributions.count > 1
            ? ",\"cofunded\":true,\"fundingSourceCount\":\(fundingPlan.contributions.count)"
            : ""
        let metadataJSON = item.isConsumable
            ? "{\"shopItemId\":\"\(item.id)\",\"purchaseId\":\"\(purchaseID.uuidString)\",\"consumable\":true\(cofundingMetadata)}"
            : "{\"shopItemId\":\"\(item.id)\"\(cofundingMetadata)}"
        let ledger = careLedger.record(
            occurredAt: Date(),
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
                title: isBuyer ? itemName : "合资补差：\(itemName)",
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
        do {
            try CoconutWalletMutationWriter.applyHumanMutations(
                walletMutations,
                wallet: wallet,
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: providedQuestManager ?? QuestManager()
            )
            try ShopPurchaseRecordStore.insertOwnershipRecordIfNeeded(
                item: item,
                buyer: buyer,
                transactionKey: transactionKey,
                context: context
            )
            try context.save()
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
            return ShopPurchaseCommandResult(
                humanID: buyer.id,
                itemID: item.id,
                cost: item.cost,
                didPurchase: false,
                failure: failure,
                ledgerEventID: nil,
                transactionKey: nil,
                fundingContributions: []
            )
        }

        return ShopPurchaseCommandResult(
            humanID: buyer.id,
            itemID: item.id,
            cost: item.cost,
            didPurchase: true,
            failure: nil,
            ledgerEventID: ledger.id,
            transactionKey: transactionKey,
            fundingContributions: fundingPlan.contributions.map {
                ShopPurchaseFundingContribution(humanID: $0.human.id, amount: $0.amount)
            }
        )
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
            try context.save()
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
        pet.cardPopoutImageData = imageData
        pet.cardPopoutSourceRaw = sourceRaw
        pet.cardStyleRaw = "popout"
        context.safeSave()
        return PetCardAppearanceCommandResult(petID: pet.id, action: "enablePopout")
    }

    @discardableResult
    @MainActor
    static func restoreClassic(
        pet: Pet,
        context: ModelContext
    ) -> PetCardAppearanceCommandResult {
        pet.cardStyleRaw = "classic"
        context.safeSave()
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
        guard Avatar2DAccess.consumeExtraPass() else {
            return Avatar2DUpgradeCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                didUpgrade: false,
                failure: .noPass
            )
        }

        human.avatarImageData = data
        human.avatarEmoji = HumanGenderIdentity.fallbackAvatarEmoji(for: avatarGender)
        context.safeSave()
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
        guard let data = PetAvatarAssetCatalog.avatarData(
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            coatColor: pet.coatColor,
            eyeColor: pet.eyeColor
        ) else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .missingProfile
            )
        }
        guard Avatar2DAccess.consumeExtraPass() else {
            return Avatar2DUpgradeCommandResult(
                entityID: pet.id,
                kind: EntityKind.pet.rawValue,
                didUpgrade: false,
                failure: .noPass
            )
        }

        pet.avatarImageData = data
        context.safeSave()
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
