//
//  OasisUpgradeRewardService+Upgrades.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    @discardableResult
    static func upgradeStar(
        for critter: OasisElectronicPet,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> Bool {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        normalizeLifecycle(for: critter, context: context)
        guard critter.lifeState != .dead else { return false }
        let cost = starUpgradeCost(for: critter)
        guard let balance = fragmentBalance(critterId: critter.catalogId, context: context),
              balance.amount >= cost.fragments,
              OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                  cost.coconuts,
                  context: context,
                  activeHumanSelection: activeHumanSelection,
                  questManager: questManager
              ) else {
            return false
        }

        balance.amount -= cost.fragments
        balance.updatedAt = Date()
        guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
            cost.coconuts,
            emoji: "⭐️",
            title: "电子宠物升星",
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        ) else {
            balance.amount += cost.fragments
            balance.updatedAt = Date()
            return false
        }
        critter.starLevel += 1
        critter.bond = min(999, critter.bond + 20)
        critter.mood = min(100, critter.mood + 16)
        critter.appearanceStage = min(maxCritterAppearanceStage, max(appearanceStage(forLevel: critter.level), critter.starLevel))
        critter.lastInteractionAt = Date()
        critter.lastStateRefreshAt = Date()
        context.insert(actionLog(
            for: critter,
            action: .starUpgrade,
            coconutDelta: -cost.coconuts,
            fragmentDelta: -cost.fragments,
            xpDelta: 0
        ))
        try context.save()
        return true
    }

    @discardableResult
    static func awakenWithFragments(
        catalogId: String,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> OasisElectronicPet? {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        guard !ownsCritter(catalogId, context: context),
              let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) else {
            return nil
        }
        guard OasisTreeManagerRegistry.current.treeLevel.rawValue >= entry.sourceLevel else {
            return nil
        }
        let cost = awakeningCost(for: entry.rarity)
        guard let balance = fragmentBalance(critterId: catalogId, context: context),
              balance.amount >= cost.fragments,
              OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                  cost.coconuts,
                  context: context,
                  activeHumanSelection: activeHumanSelection,
                  questManager: questManager
              ) else {
            return nil
        }

        balance.amount -= cost.fragments
        balance.updatedAt = Date()
        guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
            cost.coconuts,
            emoji: "🐾",
            title: "碎片唤醒电子宠物",
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        ) else {
            balance.amount += cost.fragments
            balance.updatedAt = Date()
            return nil
        }

        let hasFeatured = ((try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
            .contains { $0.isFeaturedOnOasis && !$0.isArchived }
        let critter = OasisElectronicPet(
            catalogId: entry.id,
            nameZh: entry.nameZh,
            nameEn: entry.nameEn,
            nameDe: entry.nameDe,
            emoji: entry.emoji,
            rarity: entry.rarity,
            isFeaturedOnOasis: !hasFeatured,
            habitatSlot: hasFeatured ? 1 : 0,
            favoriteItemId: entry.preferredItemId,
            personalityRaw: entry.personalityRaw,
            sourceLevel: entry.sourceLevel
        )
        context.insert(critter)
        context.insert(OasisCritterActionLog(
            critterId: critter.id,
            critterCatalogId: critter.catalogId,
            action: .fragmentAwaken,
            coconutDelta: -cost.coconuts,
            fragmentDelta: -cost.fragments,
            noteZh: "用碎片唤醒伙伴",
            noteEn: "Awakened a companion with fragments.",
            noteDe: "Begleiter mit Fragmenten geweckt."
        ))
        try context.save()
        return critter
    }

    static func setFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws {
        normalizeLifecycle(for: critter, context: context)
        guard critter.lifeState != .dead else { return }
        let all = (try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        for item in all {
            item.isFeaturedOnOasis = item.id == critter.id
            if item.id == critter.id {
                item.habitatSlot = 0
            } else if item.habitatSlot == 0 {
                item.habitatSlot = 1
            }
        }
        context.insert(actionLog(for: critter, action: .feature))
        try context.save()
    }

    static func clearFeatured(_ critter: OasisElectronicPet, context: ModelContext) throws {
        normalizeLifecycle(for: critter, context: context)
        guard critter.lifeState != .dead else { return }
        critter.isFeaturedOnOasis = false
        context.insert(actionLog(for: critter, action: .feature))
        try context.save()
    }

    static func rewardFeaturedCritterFromCare(type: QuestManager.OhanaActionType, context: ModelContext) {
        let candidates = ((try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
            .filter { !$0.isArchived }
            .sorted(by: {
                if $0.isFeaturedOnOasis != $1.isFeaturedOnOasis { return $0.isFeaturedOnOasis && !$1.isFeaturedOnOasis }
                if $0.habitatSlot != $1.habitatSlot { return $0.habitatSlot < $1.habitatSlot }
                return $0.obtainedAt < $1.obtainedAt
            })
        guard let critter = candidates.first(where: {
            normalizeLifecycle(for: $0, context: context)
            return $0.lifeState != .dead
        }) else { return }

        let gain = careEchoGain(for: type)
        let xpDelta = addXP(gain.xp, to: critter)
        critter.bond = min(999, critter.bond + gain.bond)
        critter.mood = min(100, critter.mood + gain.mood)
        critter.health = min(100, critter.health + gain.health)
        switch type {
        case .feed, .water:
            critter.hunger = min(100, critter.hunger + 6)
        default:
            break
        }
        critter.xp = critter.level >= maxCritterLevel ? 0 : max(0, min(critterXPPerLevel, critter.xp))
        critter.appearanceStage = appearanceStage(forLevel: critter.level)
        critter.lastStateRefreshAt = Date()
        refreshLifecycleState(for: critter, now: Date())
        context.insert(actionLog(
            for: critter,
            action: .careEcho,
            xpDelta: xpDelta
        ))
        try? context.save()
    }

    static func careEchoGain(for type: QuestManager.OhanaActionType) -> (xp: Int, bond: Int, mood: Int, health: Int) {
        switch type {
        case .walk:
            (2, 3, 3, 4)
        case .health, .care:
            (2, 3, 2, 8)
        case .feed, .water:
            (1, 2, 2, 4)
        case .potty, .weight:
            (1, 1, 1, 3)
        case .expense:
            (0, 1, 0, 1)
        case .milestone:
            (3, 5, 4, 6)
        case .dailyFocusCompletion, .general:
            (1, 2, 1, 2)
        }
    }

    static func interactionCost(for critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) -> Int {
        switch action {
        case .feed:
            dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 5
        case .play:
            dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 3
        case .rest:
            dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 2
        case .rescue, .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            0
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

    static func starUpgradeCost(for critter: OasisElectronicPet) -> (fragments: Int, coconuts: Int) {
        (critter.starLevel * 40, critter.starLevel * 80)
    }
}
