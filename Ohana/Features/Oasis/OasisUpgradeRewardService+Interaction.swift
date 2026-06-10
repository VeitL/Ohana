//
//  OasisUpgradeRewardService+Interaction.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    @discardableResult
    static func interact(
        with critter: OasisElectronicPet,
        action: OasisCritterAction,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet: CoconutWalletManaging? = nil,
        questManager: QuestManager? = nil
    ) throws -> Bool {
        try interactWithOutcome(
            with: critter,
            action: action,
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        ).success
    }

    @discardableResult
    static func interactWithOutcome(
        with critter: OasisElectronicPet,
        action: OasisCritterAction,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> OasisCritterInteractionOutcome {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        normalizeLifecycle(for: critter, context: context)
        if critter.lifeState == .dead {
            return deadInteractionOutcome(for: critter, action: action)
        }
        let wish = dailyWish(for: critter, context: context)
        let wasWishCompleted = isDailyWishCompleted(for: critter, wish: wish, context: context)
        var interactionOverride: OasisCritterInteractionOutcome?

        switch action {
        case .feed:
            let feedCount = dailyActionCount(for: action, critter: critter, context: context)
            let effect = feedEffect(for: critter, dailyFeedCount: feedCount)
            let cost = interactionCost(for: critter, action: action, context: context)
            guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
                cost,
                emoji: "🍽️",
                title: "喂养电子宠物",
                context: context,
                activeHumanSelection: activeHumanSelection,
                wallet: wallet,
                questManager: questManager
            ) else {
                return failedInteraction(action: action, wish: wish)
            }
            critter.hunger = clampedPercent(critter.hunger + effect.hungerDelta)
            critter.mood = clampedPercent(critter.mood + effect.moodDelta)
            critter.health = clampedPercent(critter.health + effect.healthDelta)
            critter.bond = min(999, critter.bond + effect.bondDelta)
            let xpDelta = addXP(effect.xp, to: critter)
            context.insert(OasisCritterActionLog(
                critterId: critter.id,
                critterCatalogId: critter.catalogId,
                action: action,
                coconutDelta: -cost,
                xpDelta: xpDelta,
                sourceLevel: critter.sourceLevel,
                noteZh: effect.messageZh,
                noteEn: effect.messageEn,
                noteDe: effect.messageDe
            ))
            interactionOverride = OasisCritterInteractionOutcome(
                success: true,
                action: action,
                completedDailyWish: false,
                wish: wish,
                messageZh: effect.messageZh,
                messageEn: effect.messageEn,
                messageDe: effect.messageDe,
                rewardXP: xpDelta,
                rewardBond: effect.bondDelta,
                rewardFragments: 0,
                rewardCoconuts: 0
            )
        case .play:
            let cost = interactionCost(for: critter, action: action, context: context)
            guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
                cost,
                emoji: "🪀",
                title: "陪电子宠物玩耍",
                context: context,
                activeHumanSelection: activeHumanSelection,
                wallet: wallet,
                questManager: questManager
            ) else {
                return failedInteraction(action: action, wish: wish)
            }
            critter.hunger = max(0, critter.hunger - 5)
            critter.mood = min(100, critter.mood + 18)
            critter.health = min(100, critter.health + 4)
            critter.bond = min(999, critter.bond + 5)
            let xpDelta = addXP(5, to: critter)
            context.insert(actionLog(for: critter, action: action, coconutDelta: -cost, xpDelta: xpDelta))
        case .rest:
            let cost = interactionCost(for: critter, action: action, context: context)
            guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
                cost,
                emoji: "🌙",
                title: "电子宠物休息",
                context: context,
                activeHumanSelection: activeHumanSelection,
                wallet: wallet,
                questManager: questManager
            ) else {
                return failedInteraction(action: action, wish: wish)
            }
            critter.hunger = max(0, critter.hunger - 2)
            critter.mood = min(100, critter.mood + 8)
            critter.health = min(100, critter.health + 10)
            critter.bond = min(999, critter.bond + 1)
            let xpDelta = addXP(2, to: critter)
            context.insert(actionLog(for: critter, action: action, coconutDelta: -cost, xpDelta: xpDelta))
        case .rescue, .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            return failedInteraction(action: action, wish: wish)
        }

        let completedWish = action == wish.action && !wasWishCompleted
        if completedWish {
            let wishXPDelta = addXP(wish.rewardXP, to: critter)
            critter.bond = min(999, critter.bond + wish.rewardBond)
            addFragments(critterId: critter.catalogId, amount: wish.rewardFragments, context: context)
            guard OasisCritterEconomyService.awardCurrentHumanCoconuts(
                wish.rewardCoconuts,
                emoji: "💌",
                title: "电子宠物小愿望",
                context: context,
                activeHumanSelection: activeHumanSelection,
                wallet: wallet,
                questManager: questManager
            ) else {
                context.rollback()
                wallet.refreshQuestProjection(context: context, manager: questManager)
                throw OasisRewardWriteError.coconutAwardFailed
            }
            context.insert(OasisCritterActionLog(
                critterId: critter.id,
                critterCatalogId: critter.catalogId,
                action: .careEcho,
                coconutDelta: wish.rewardCoconuts,
                fragmentDelta: wish.rewardFragments,
                xpDelta: wishXPDelta,
                sourceLevel: critter.sourceLevel,
                noteZh: "完成今日小愿望",
                noteEn: "Completed today's tiny wish.",
                noteDe: "Heutigen kleinen Wunsch erfüllt."
            ))
        }

        critter.xp = critter.level >= maxCritterLevel ? 0 : max(0, min(critterXPPerLevel, critter.xp))
        critter.appearanceStage = appearanceStage(forLevel: critter.level)
        critter.lastInteractionAt = Date()
        critter.lastStateRefreshAt = Date()
        refreshLifecycleState(for: critter, now: Date())
        do {
            try context.save()
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            throw error
        }
        if !completedWish, let interactionOverride {
            return interactionOverride
        }
        return interactionOutcome(action: action, wish: wish, completedWish: completedWish)
    }

    static func canInteract(
        with critter: OasisElectronicPet,
        action: OasisCritterAction,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        questManager providedQuestManager: QuestManager? = nil
    ) -> Bool {
        let questManager = providedQuestManager ?? QuestManager()
        guard critter.lifeState != .dead else { return false }
        switch action {
        case .feed:
            return OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                interactionCost(for: critter, action: action, context: context),
                context: context,
                activeHumanSelection: activeHumanSelection,
                questManager: questManager
            )
        case .play:
            return OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                interactionCost(for: critter, action: action, context: context),
                context: context,
                activeHumanSelection: activeHumanSelection,
                questManager: questManager
            )
        case .rest:
            return OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                interactionCost(for: critter, action: action, context: context),
                context: context,
                activeHumanSelection: activeHumanSelection,
                questManager: questManager
            )
        case .rescue, .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            return false
        }
    }

    static func todayInteractionCount(for critter: OasisElectronicPet, context: ModelContext) -> Int {
        let activeActions: Set<OasisCritterAction> = [.feed, .play, .rest]
        return actionLogs(for: critter, context: context).count(where: { activeActions.contains($0.action) })
    }
}
