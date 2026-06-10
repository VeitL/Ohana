//
//  OasisUpgradeRewardModels.swift
//  Ohana
//
//  Reward, critter, and lifecycle value types for Oasis upgrades.
//

import Foundation

enum OasisUpgradeRewardKind: String, Codable, CaseIterable, Identifiable {
    case coconuts
    case treeEnergy
    case decoration
    case fragments
    case storyStyle
    case temporaryEffect
    case electronicPet

    var id: String { rawValue }
}

enum OasisElectronicPetRarity: String, Codable, CaseIterable, Identifiable {
    case common
    case rare
    case epic
    case legendary

    var id: String { rawValue }

    var zh: String {
        switch self {
        case .common: "普通"
        case .rare: "稀有"
        case .epic: "史诗"
        case .legendary: "传说"
        }
    }

    var en: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    var de: String {
        switch self {
        case .common: "Gewohnlich"
        case .rare: "Selten"
        case .epic: "Episch"
        case .legendary: "Legendär"
        }
    }
}

enum OasisCritterLifeState: String, Codable, CaseIterable, Identifiable {
    case healthy
    case needsCare
    case atRisk
    case sick
    case critical
    case dead

    var id: String { rawValue }

    func name(_ l: L10n) -> String {
        switch self {
        case .healthy:
            l.tr(zh: "安稳", en: "Settled", de: "Ruhig")
        case .needsCare:
            l.tr(zh: "想被照顾", en: "Needs a little care", de: "Braucht etwas Pflege")
        case .atRisk:
            l.tr(zh: "需要你一下", en: "Needs you soon", de: "Braucht dich bald")
        case .sick:
            l.tr(zh: "有点不舒服", en: "A little unwell", de: "Etwas unwohl")
        case .critical:
            l.tr(zh: "需要救回", en: "Needs rescue", de: "Braucht Rettung")
        case .dead:
            l.tr(zh: "纪念中", en: "Remembered", de: "In Erinnerung")
        }
    }
}

enum OasisCritterDeathReason: String, Codable, CaseIterable, Identifiable {
    case hungry
    case sick
    case bored
    case oldAge

    var id: String { rawValue }

    func name(_ l: L10n) -> String {
        switch self {
        case .hungry:
            l.tr(zh: "太久没有吃东西", en: "too long without food", de: "zu lange ohne Futter")
        case .sick:
            l.tr(zh: "久病没有恢复", en: "illness that was not healed", de: "Krankheit ohne Erholung")
        case .bored:
            l.tr(zh: "太久没有陪伴", en: "too long without company", de: "zu lange ohne Gesellschaft")
        case .oldAge:
            l.tr(zh: "自然老去", en: "old age", de: "Alter")
        }
    }
}

struct OasisCritterLifecycleSnapshot: Equatable {
    let state: OasisCritterLifeState
    let deathReason: OasisCritterDeathReason?
    let recommendedAction: OasisCritterAction?
    let isRescuable: Bool
    let hoursUntilDeath: Int?
    let ageDays: Int
    let urgencyScore: Int
}

// MARK: - Persistence models
// The SwiftData @Model classes (OasisUpgradeCoconut, OasisElectronicPet,
// OasisCritterFragmentBalance, OasisCritterActionLog, OasisUnlock) live in
// OasisUpgradeModels.swift.

struct OasisElectronicPetCatalogEntry: Identifiable, Equatable {
    let id: String
    let emoji: String
    let rarity: OasisElectronicPetRarity
    var sourceLevel: Int = 0
    var assetName: String = ""
    var unlockHintZh: String = ""
    var unlockHintEn: String = ""
    var unlockHintDe: String = ""
    var personalityRaw: String = "gentle"
    var preferredItemId: String = ""
    let nameZh: String
    let nameEn: String
    let nameDe: String
    let taglineZh: String
    let taglineEn: String
    let taglineDe: String

    func name(_ l: L10n) -> String {
        l.tr(zh: nameZh, en: nameEn, de: nameDe)
    }

    func tagline(_ l: L10n) -> String {
        l.tr(zh: taglineZh, en: taglineEn, de: taglineDe)
    }

    func unlockHint(_ l: L10n) -> String {
        if unlockHintZh.isEmpty, unlockHintEn.isEmpty, unlockHintDe.isEmpty {
            return sourceLevel > 0
                ? l.tr(zh: "生命之树 Lv.\(sourceLevel)", en: "Life Tree Lv.\(sourceLevel)", de: "Lebensbaum Lv.\(sourceLevel)")
                : l.tr(zh: "碎片唤醒", en: "Fragment awakening", de: "Fragment-Weckung")
        }
        return l.tr(zh: unlockHintZh, en: unlockHintEn, de: unlockHintDe)
    }
}

struct OasisUpgradeRewardRule {
    let level: Int
    let rewardKind: OasisUpgradeRewardKind
    let rewardCatalogId: String
    let guaranteedCritterId: String?
    let coconutAmount: Int
    let treeEnergyAmount: Int
    let fragmentAmount: Int
    let decorUnlockId: String?
    let storyStyleUnlockId: String?
    let temporaryEffectId: String?
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let descriptionZh: String
    let descriptionEn: String
    let descriptionDe: String

    func makeCoconut() -> OasisUpgradeCoconut {
        OasisUpgradeCoconut(
            level: level,
            rewardKind: rewardKind,
            rewardCatalogId: rewardCatalogId,
            guaranteedCritterId: guaranteedCritterId,
            coconutAmount: coconutAmount,
            treeEnergyAmount: treeEnergyAmount,
            fragmentAmount: fragmentAmount,
            decorUnlockId: decorUnlockId,
            storyStyleUnlockId: storyStyleUnlockId,
            temporaryEffectId: temporaryEffectId,
            titleZh: titleZh,
            titleEn: titleEn,
            titleDe: titleDe,
            descriptionZh: descriptionZh,
            descriptionEn: descriptionEn,
            descriptionDe: descriptionDe
        )
    }
}

struct OasisOpenedUpgradeReward: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let kind: OasisUpgradeRewardKind
    let critterCatalogId: String?
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let detailZh: String
    let detailEn: String
    let detailDe: String
    let emoji: String
    let isMilestoneCritter: Bool

    func title(_ l: L10n) -> String {
        l.tr(zh: titleZh, en: titleEn, de: titleDe)
    }

    func detail(_ l: L10n) -> String {
        l.tr(zh: detailZh, en: detailEn, de: detailDe)
    }
}

struct OasisCritterDailyWish: Identifiable, Equatable {
    let id: String
    let action: OasisCritterAction
    let icon: String
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let detailZh: String
    let detailEn: String
    let detailDe: String
    let rewardXP: Int
    let rewardBond: Int
    let rewardFragments: Int
    let rewardCoconuts: Int

    func title(_ l: L10n) -> String {
        l.tr(zh: titleZh, en: titleEn, de: titleDe)
    }

    func detail(_ l: L10n) -> String {
        l.tr(zh: detailZh, en: detailEn, de: detailDe)
    }

    func rewardText(_ l: L10n) -> String {
        "+\(rewardXP)XP +\(rewardBond)\(l.tr(zh: "羁绊", en: "bond", de: "Bindung")) +\(rewardFragments)◇ +\(rewardCoconuts)🥥"
    }
}

struct OasisCritterInteractionOutcome: Equatable {
    let success: Bool
    let action: OasisCritterAction
    let completedDailyWish: Bool
    let wish: OasisCritterDailyWish?
    let messageZh: String
    let messageEn: String
    let messageDe: String
    let rewardXP: Int
    let rewardBond: Int
    let rewardFragments: Int
    let rewardCoconuts: Int

    func message(_ l: L10n) -> String {
        l.tr(zh: messageZh, en: messageEn, de: messageDe)
    }

    func rewardText(_ l: L10n) -> String {
        guard rewardXP != 0 || rewardBond != 0 || rewardFragments != 0 || rewardCoconuts != 0 else { return "" }
        var parts: [String] = []
        if rewardXP != 0 { parts.append("+\(rewardXP)XP") }
        if rewardBond != 0 { parts.append("+\(rewardBond)\(l.tr(zh: "羁绊", en: "bond", de: "Bindung"))") }
        if rewardFragments != 0 { parts.append("+\(rewardFragments)◇") }
        if rewardCoconuts != 0 { parts.append("+\(rewardCoconuts)🥥") }
        return parts.joined(separator: " ")
    }
}

enum OasisCritterAction: String, CaseIterable, Identifiable {
    case feed
    case play
    case rest
    case rescue
    case levelUpgrade
    case starUpgrade
    case unlock
    case fragmentAwaken
    case feature
    case careEcho
    case death

    var id: String { rawValue }
}
