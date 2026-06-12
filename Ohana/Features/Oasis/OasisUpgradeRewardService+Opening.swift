//
//  OasisUpgradeRewardService+Opening.swift
//  Ohana
//

import Foundation
import SwiftData

extension OasisUpgradeRewardService {
    @discardableResult
    static func ensureUpgradeCoconuts(from firstLevel: Int, through lastLevel: Int, context: ModelContext) throws -> Int {
        let startLevel = max(2, firstLevel)
        guard lastLevel >= startLevel else { return 0 }
        let descriptor = FetchDescriptor<OasisUpgradeCoconut>(
            predicate: #Predicate<OasisUpgradeCoconut> { coconut in
                coconut.level >= startLevel && coconut.level <= lastLevel
            }
        )
        let existing: [OasisUpgradeCoconut]
        do {
            existing = try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[OasisUpgradeRewardService] failed to fetch existing upgrade coconuts from level \(startLevel) through \(lastLevel): \(error.localizedDescription)",
                category: "Oasis"
            )
            throw error
        }
        let existingLevels = Set(existing.map(\.level))
        var inserted = 0
        var insertedCoconuts: [OasisUpgradeCoconut] = []

        for level in startLevel ... lastLevel where !existingLevels.contains(level) {
            let coconut = OasisUpgradeRewardCatalog.rule(for: level).makeCoconut()
            context.insert(coconut)
            insertedCoconuts.append(coconut)
            inserted += 1
        }

        if inserted > 0 {
            do {
                try context.save()
            } catch {
                insertedCoconuts.forEach { context.delete($0) }
                throw error
            }
        }
        return inserted
    }

    static func open(
        _ coconut: OasisUpgradeCoconut,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> OasisOpenedUpgradeReward {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        guard !coconut.isOpened else {
            return openedResult(for: coconut, duplicate: false)
        }

        var duplicateCritter = false
        let treeManager = OasisTreeManagerRegistry.current
        let previousInjectedEnergy = treeManager.injectedEnergy

        if coconut.rewardKind == .electronicPet,
           let critterId = coconut.guaranteedCritterId,
           let entry = OasisUpgradeRewardCatalog.critter(id: critterId),
           coconut.level < entry.sourceLevel {
            coconut.rewardKind = .fragments
            coconut.rewardCatalogId = "level_\(coconut.level)_critter_fragments"
            coconut.fragmentAmount = max(coconut.fragmentAmount, 60)
            coconut.decorUnlockId = nil
            coconut.titleZh = "电子宠物碎片"
            coconut.titleEn = "Critter Fragments"
            coconut.titleDe = "Critter-Fragmente"
            coconut.descriptionZh = "电子宠物将在生命树 Lv.\(entry.sourceLevel) 保底唤醒。"
            coconut.descriptionEn = "This critter is guaranteed at Life Tree Lv.\(entry.sourceLevel)."
            coconut.descriptionDe = "Dieser Begleiter ist bei Lebensbaum Lv.\(entry.sourceLevel) garantiert."
        }

        guard OasisCritterEconomyService.awardCurrentHumanCoconuts(
            coconut.coconutAmount,
            emoji: "🥥",
            title: "升级椰子 Lv.\(coconut.level)",
            context: context,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager
        ) else {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            throw OasisRewardWriteError.coconutAwardFailed
        }

        coconut.openedAt = Date()

        if coconut.treeEnergyAmount > 0 {
            treeManager.injectedEnergy += coconut.treeEnergyAmount
        }

        if coconut.fragmentAmount > 0 {
            let critterId = coconut.guaranteedCritterId ?? OasisUpgradeRewardCatalog.firstCritterId
            addFragments(critterId: critterId, amount: coconut.fragmentAmount, context: context)
        }

        if let decorUnlockId = coconut.decorUnlockId {
            unlock(id: decorUnlockId, kind: .decoration, sourceLevel: coconut.level, context: context)
        }

        if let styleUnlockId = coconut.storyStyleUnlockId {
            unlock(id: styleUnlockId, kind: .storyStyle, sourceLevel: coconut.level, context: context)
        }

        if let effectId = coconut.temporaryEffectId {
            unlock(id: effectId, kind: .temporaryEffect, sourceLevel: coconut.level, context: context)
        }

        if coconut.rewardKind == .electronicPet, let critterId = coconut.guaranteedCritterId {
            if ownsCritter(critterId, context: context) {
                duplicateCritter = true
                addFragments(critterId: critterId, amount: max(coconut.fragmentAmount, 120), context: context)
                unlock(id: "\(critterId)_duplicate_memorial", kind: .decoration, sourceLevel: coconut.level, context: context)
            } else if let entry = OasisUpgradeRewardCatalog.critter(id: critterId) {
                let hasFeatured = hasFeaturedCritter(context: context)
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
                    sourceLevel: coconut.level
                )
                context.insert(critter)
                context.insert(OasisCritterActionLog(
                    critterId: critter.id,
                    critterCatalogId: critter.catalogId,
                    action: .unlock,
                    coconutDelta: coconut.coconutAmount,
                    fragmentDelta: coconut.fragmentAmount,
                    sourceLevel: coconut.level,
                    noteZh: "Lv.\(coconut.level) 升级椰子唤醒伙伴",
                    noteEn: "Level \(coconut.level) upgrade coconut awakened a companion.",
                    noteDe: "Upgrade-Kokosnuss auf Level \(coconut.level) hat einen Begleiter geweckt."
                ))
            }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            treeManager.injectedEnergy = previousInjectedEnergy
            wallet.refreshQuestProjection(context: context, manager: questManager)
            throw error
        }

        if coconut.treeEnergyAmount > 0 {
            _ = treeManager.checkAndRewardLevelUp(modelContext: context)
        }
        return openedResult(for: coconut, duplicate: duplicateCritter)
    }
}
