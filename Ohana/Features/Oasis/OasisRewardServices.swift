//
//  OasisRewardServices.swift
//  Ohana
//
//  Instance-facing Oasis reward dependencies for feature command executors.
//

import Foundation
import SwiftData

nonisolated enum OasisCritterPresentationRules {
    static let maxAppearanceStage = 5

    static func appearanceStage(forLevel level: Int) -> Int {
        switch max(1, min(12, level)) {
        case 1 ... 2:
            1
        case 3 ... 5:
            2
        case 6 ... 8:
            3
        case 9 ... 11:
            4
        default:
            maxAppearanceStage
        }
    }

    static func awakeningCost(for rarity: OasisElectronicPetRarity) -> (fragments: Int, coconuts: Int) {
        switch rarity {
        case .common: (120, 80)
        case .rare: (180, 120)
        case .epic: (300, 220)
        case .legendary: (520, 420)
        }
    }
}

@MainActor
protocol OasisRewardManaging {
    var maxCritterLevel: Int { get }
    var critterXPPerLevel: Int { get }

    func currentHumanBalance(context: ModelContext) -> Int
    func canSpendCurrentHumanCoconuts(_ amount: Int, context: ModelContext) -> Bool
    @discardableResult
    func awardBudgetedCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool,
        date: Date
    ) -> Int?
    @discardableResult
    func awardSpecialCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        sourceModelName: String,
        sourceModelId: String,
        transactionKey: String,
        metadataJSON: String,
        context: ModelContext,
        postsRewardFeedback: Bool,
        occurredAt: Date
    ) -> Int?
    func refreshCoconutProjection(context: ModelContext)

    func lifecycleSnapshot(for critter: OasisElectronicPet, context: ModelContext) -> OasisCritterLifecycleSnapshot
    func displayDailyWish(for critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot) -> OasisCritterDailyWish
    func starUpgradeCost(for critter: OasisElectronicPet) -> (fragments: Int, coconuts: Int)
    func interactionCost(for critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) -> Int
    func xpProgress(for critter: OasisElectronicPet) -> Int
    func isDailyWishCompleted(
        for critter: OasisElectronicPet,
        wish: OasisCritterDailyWish,
        context: ModelContext
    ) -> Bool
    func appearanceStage(forLevel level: Int) -> Int
    func bondLevel(for critter: OasisElectronicPet) -> Int
    func bondProgress(for critter: OasisElectronicPet) -> Int
    func gentlePrompt(for critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot, l: L10n) -> String
    func todayInteractionCount(for critter: OasisElectronicPet, context: ModelContext) -> Int
    func canUpgradeLevel(for critter: OasisElectronicPet) -> Bool

    func open(_ coconut: OasisUpgradeCoconut, context: ModelContext) throws -> OasisOpenedUpgradeReward
    func interactWithOutcome(
        with critter: OasisElectronicPet,
        action: OasisCritterAction,
        context: ModelContext
    ) throws -> OasisCritterInteractionOutcome
    func rescueIfNeeded(for critter: OasisElectronicPet, context: ModelContext) throws -> OasisCritterInteractionOutcome
    func upgradeStar(for critter: OasisElectronicPet, context: ModelContext) throws -> Bool
    func upgradeLevel(for critter: OasisElectronicPet, context: ModelContext) throws -> Bool
    func awakenWithFragments(catalogId: String, context: ModelContext) throws -> OasisElectronicPet?
    func setFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws
    func clearFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws
    func normalizeLifecycle(for critter: OasisElectronicPet, context: ModelContext)
    func rewardFeaturedCritterFromCare(type: QuestManager.OhanaActionType, context: ModelContext)
    func rewardFeaturedCritterFromCare(
        type: QuestManager.OhanaActionType,
        context: ModelContext,
        idempotencyID: UUID
    ) -> Bool
    func ensureUpgradeCoconuts(from startLevel: Int, through endLevel: Int, context: ModelContext) throws
}

extension OasisRewardManaging {
    func rewardFeaturedCritterFromCare(
        type: QuestManager.OhanaActionType,
        context: ModelContext,
        idempotencyID _: UUID
    ) -> Bool {
        rewardFeaturedCritterFromCare(type: type, context: context)
        return true
    }
}

@MainActor
final class StaticOasisRewardManager: OasisRewardManaging {
    private let activeHumanSelection: ActiveHumanSelecting
    private let wallet: CoconutWalletManaging
    private let questManager: QuestManager

    init(
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager
    ) {
        self.activeHumanSelection = activeHumanSelection
        self.wallet = wallet
        self.questManager = questManager
    }

    var maxCritterLevel: Int { OasisUpgradeRewardService.maxCritterLevel }
    var critterXPPerLevel: Int { OasisUpgradeRewardService.critterXPPerLevel }

    func currentHumanBalance(context: ModelContext) -> Int {
        OasisCritterEconomyService.currentHumanBalance(
            context: context,
            activeHumanSelection: activeHumanSelection,
            questManager: questManager
        )
    }

    func canSpendCurrentHumanCoconuts(_ amount: Int, context: ModelContext) -> Bool {
        OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
            amount,
            context: context,
            activeHumanSelection: activeHumanSelection,
            questManager: questManager
        )
    }

    @discardableResult
    func awardBudgetedCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool,
        date: Date = Date()
    ) -> Int? {
        OasisCritterEconomyService.awardBudgetedCurrentHumanCoconuts(
            amount,
            emoji: emoji,
            title: title,
            context: context,
            postsRewardFeedback: postsRewardFeedback,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager,
            date: date
        )
    }

    @discardableResult
    func awardSpecialCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        sourceModelName: String,
        sourceModelId: String,
        transactionKey: String,
        metadataJSON: String,
        context: ModelContext,
        postsRewardFeedback: Bool,
        occurredAt: Date = Date()
    ) -> Int? {
        OasisCritterEconomyService.awardSpecialCurrentHumanCoconuts(
            amount,
            emoji: emoji,
            title: title,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            transactionKey: transactionKey,
            metadataJSON: metadataJSON,
            context: context,
            postsRewardFeedback: postsRewardFeedback,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager,
            occurredAt: occurredAt
        )
    }

    func refreshCoconutProjection(context: ModelContext) {
        wallet.refreshQuestProjection(context: context, manager: questManager)
    }

    func lifecycleSnapshot(for critter: OasisElectronicPet, context: ModelContext) -> OasisCritterLifecycleSnapshot {
        OasisUpgradeRewardService.lifecycleSnapshot(for: critter, context: context)
    }

    func displayDailyWish(for critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot) -> OasisCritterDailyWish {
        OasisUpgradeRewardService.displayDailyWish(for: critter, snapshot: snapshot)
    }

    func starUpgradeCost(for critter: OasisElectronicPet) -> (fragments: Int, coconuts: Int) {
        OasisUpgradeRewardService.starUpgradeCost(for: critter)
    }

    func interactionCost(for critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) -> Int {
        OasisUpgradeRewardService.interactionCost(for: critter, action: action, context: context)
    }

    func xpProgress(for critter: OasisElectronicPet) -> Int {
        OasisUpgradeRewardService.xpProgress(for: critter)
    }

    func isDailyWishCompleted(
        for critter: OasisElectronicPet,
        wish: OasisCritterDailyWish,
        context: ModelContext
    ) -> Bool {
        OasisUpgradeRewardService.isDailyWishCompleted(for: critter, wish: wish, context: context)
    }

    func appearanceStage(forLevel level: Int) -> Int {
        OasisUpgradeRewardService.appearanceStage(forLevel: level)
    }

    func bondLevel(for critter: OasisElectronicPet) -> Int {
        OasisUpgradeRewardService.bondLevel(for: critter)
    }

    func bondProgress(for critter: OasisElectronicPet) -> Int {
        OasisUpgradeRewardService.bondProgress(for: critter)
    }

    func gentlePrompt(for critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot, l: L10n) -> String {
        OasisUpgradeRewardService.gentlePrompt(for: critter, snapshot: snapshot, l: l)
    }

    func todayInteractionCount(for critter: OasisElectronicPet, context: ModelContext) -> Int {
        OasisUpgradeRewardService.todayInteractionCount(for: critter, context: context)
    }

    func canUpgradeLevel(for critter: OasisElectronicPet) -> Bool {
        OasisUpgradeRewardService.canUpgradeLevel(for: critter)
    }

    func open(_ coconut: OasisUpgradeCoconut, context: ModelContext) throws -> OasisOpenedUpgradeReward {
        try OasisUpgradeRewardService.open(
            coconut,
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        )
    }

    func interactWithOutcome(
        with critter: OasisElectronicPet,
        action: OasisCritterAction,
        context: ModelContext
    ) throws -> OasisCritterInteractionOutcome {
        try OasisUpgradeRewardService.interactWithOutcome(
            with: critter,
            action: action,
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        )
    }

    func rescueIfNeeded(for critter: OasisElectronicPet, context: ModelContext) throws -> OasisCritterInteractionOutcome {
        try OasisUpgradeRewardService.rescueIfNeeded(for: critter, context: context)
    }

    func upgradeStar(for critter: OasisElectronicPet, context: ModelContext) throws -> Bool {
        try OasisUpgradeRewardService.upgradeStar(
            for: critter,
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        )
    }

    func upgradeLevel(for critter: OasisElectronicPet, context: ModelContext) throws -> Bool {
        try OasisUpgradeRewardService.upgradeLevel(for: critter, context: context)
    }

    func awakenWithFragments(catalogId: String, context: ModelContext) throws -> OasisElectronicPet? {
        try OasisUpgradeRewardService.awakenWithFragments(
            catalogId: catalogId,
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        )
    }

    func setFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws {
        try OasisUpgradeRewardService.setFeatured(critter, context: context)
    }

    func clearFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws {
        try OasisUpgradeRewardService.clearFeatured(critter, context: context)
    }

    func normalizeLifecycle(for critter: OasisElectronicPet, context: ModelContext) {
        OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: context)
    }

    func rewardFeaturedCritterFromCare(type: QuestManager.OhanaActionType, context: ModelContext) {
        OasisUpgradeRewardService.rewardFeaturedCritterFromCare(type: type, context: context)
    }

    func rewardFeaturedCritterFromCare(
        type: QuestManager.OhanaActionType,
        context: ModelContext,
        idempotencyID: UUID
    ) -> Bool {
        OasisUpgradeRewardService.rewardFeaturedCritterFromCare(
            type: type,
            context: context,
            idempotencyID: idempotencyID
        )
    }

    func ensureUpgradeCoconuts(from startLevel: Int, through endLevel: Int, context: ModelContext) throws {
        try OasisUpgradeRewardService.ensureUpgradeCoconuts(
            from: startLevel,
            through: endLevel,
            context: context
        )
    }
}
