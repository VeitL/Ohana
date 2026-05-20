//
//  OasisUpgradeRewards.swift
//  Ohana
//
//  Persistent reward layer for Life Tree upgrade coconuts and rare
//  electronic pet milestones.
//

import Foundation
import SwiftData

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
        case .common: return "普通"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    var en: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var de: String {
        switch self {
        case .common: return "Gewohnlich"
        case .rare: return "Selten"
        case .epic: return "Episch"
        case .legendary: return "Legendär"
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
            return l.tr(zh: "安稳", en: "Settled", de: "Ruhig")
        case .needsCare:
            return l.tr(zh: "想被照顾", en: "Needs a little care", de: "Braucht etwas Pflege")
        case .atRisk:
            return l.tr(zh: "需要你一下", en: "Needs you soon", de: "Braucht dich bald")
        case .sick:
            return l.tr(zh: "有点不舒服", en: "A little unwell", de: "Etwas unwohl")
        case .critical:
            return l.tr(zh: "需要救回", en: "Needs rescue", de: "Braucht Rettung")
        case .dead:
            return l.tr(zh: "纪念中", en: "Remembered", de: "In Erinnerung")
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
            return l.tr(zh: "太久没有吃东西", en: "too long without food", de: "zu lange ohne Futter")
        case .sick:
            return l.tr(zh: "久病没有恢复", en: "illness that was not healed", de: "Krankheit ohne Erholung")
        case .bored:
            return l.tr(zh: "太久没有陪伴", en: "too long without company", de: "zu lange ohne Gesellschaft")
        case .oldAge:
            return l.tr(zh: "自然老去", en: "old age", de: "Alter")
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

@Model
final class OasisUpgradeCoconut {
    #Index<OasisUpgradeCoconut>([\.level], [\.openedAt], [\.createdAt])

    var id: UUID
    var level: Int
    var createdAt: Date
    var openedAt: Date?
    var rewardKindRaw: String
    var rewardCatalogId: String
    var guaranteedCritterId: String?
    var coconutAmount: Int
    var treeEnergyAmount: Int
    var fragmentAmount: Int
    var decorUnlockId: String?
    var storyStyleUnlockId: String?
    var temporaryEffectId: String?
    var titleZh: String
    var titleEn: String
    var titleDe: String
    var descriptionZh: String
    var descriptionEn: String
    var descriptionDe: String

    init(
        id: UUID = UUID(),
        level: Int,
        createdAt: Date = Date(),
        openedAt: Date? = nil,
        rewardKind: OasisUpgradeRewardKind,
        rewardCatalogId: String,
        guaranteedCritterId: String? = nil,
        coconutAmount: Int = 0,
        treeEnergyAmount: Int = 0,
        fragmentAmount: Int = 0,
        decorUnlockId: String? = nil,
        storyStyleUnlockId: String? = nil,
        temporaryEffectId: String? = nil,
        titleZh: String,
        titleEn: String,
        titleDe: String,
        descriptionZh: String,
        descriptionEn: String,
        descriptionDe: String
    ) {
        self.id = id
        self.level = level
        self.createdAt = createdAt
        self.openedAt = openedAt
        self.rewardKindRaw = rewardKind.rawValue
        self.rewardCatalogId = rewardCatalogId
        self.guaranteedCritterId = guaranteedCritterId
        self.coconutAmount = coconutAmount
        self.treeEnergyAmount = treeEnergyAmount
        self.fragmentAmount = fragmentAmount
        self.decorUnlockId = decorUnlockId
        self.storyStyleUnlockId = storyStyleUnlockId
        self.temporaryEffectId = temporaryEffectId
        self.titleZh = titleZh
        self.titleEn = titleEn
        self.titleDe = titleDe
        self.descriptionZh = descriptionZh
        self.descriptionEn = descriptionEn
        self.descriptionDe = descriptionDe
    }

    var rewardKind: OasisUpgradeRewardKind {
        get { OasisUpgradeRewardKind(rawValue: rewardKindRaw) ?? .coconuts }
        set { rewardKindRaw = newValue.rawValue }
    }

    var isOpened: Bool { openedAt != nil }

    func title(_ l: L10n) -> String {
        l.tr(zh: titleZh, en: titleEn, de: titleDe)
    }

    func description(_ l: L10n) -> String {
        l.tr(zh: descriptionZh, en: descriptionEn, de: descriptionDe)
    }
}

@Model
final class OasisElectronicPet {
    #Index<OasisElectronicPet>([\.catalogId], [\.rarityRaw], [\.obtainedAt])

    var id: UUID
    var catalogId: String
    var nameZh: String
    var nameEn: String
    var nameDe: String
    var emoji: String
    var rarityRaw: String
    var nickname: String
    var level: Int
    var starLevel: Int
    var xp: Int
    var hunger: Int
    var mood: Int
    var health: Int = 100
    var bond: Int
    var appearanceStage: Int
    var isFeaturedOnOasis: Bool
    var habitatSlot: Int
    var equippedDecorId: String
    var favoriteItemId: String = ""
    var personalityRaw: String = "gentle"
    var featuredPoseRaw: String = "idle"
    var sourceLevel: Int
    var obtainedAt: Date
    var lastInteractionAt: Date
    var lastStateRefreshAt: Date = Date()
    var lifeStateRaw: String = OasisCritterLifeState.healthy.rawValue
    var deathReasonRaw: String = ""
    var riskStartedAt: Date?
    var criticalStartedAt: Date?
    var diedAt: Date?
    var lastGentlePromptAt: Date?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        catalogId: String,
        nameZh: String,
        nameEn: String,
        nameDe: String,
        emoji: String,
        rarity: OasisElectronicPetRarity,
        nickname: String = "",
        level: Int = 1,
        starLevel: Int = 1,
        xp: Int = 0,
        hunger: Int = 80,
        mood: Int = 82,
        health: Int = 100,
        bond: Int = 0,
        appearanceStage: Int = 1,
        isFeaturedOnOasis: Bool = false,
        habitatSlot: Int = 0,
        equippedDecorId: String = "",
        favoriteItemId: String = "",
        personalityRaw: String = "gentle",
        featuredPoseRaw: String = "idle",
        sourceLevel: Int,
        obtainedAt: Date = Date(),
        lastInteractionAt: Date = Date(),
        lastStateRefreshAt: Date = Date(),
        lifeStateRaw: String = OasisCritterLifeState.healthy.rawValue,
        deathReasonRaw: String = "",
        riskStartedAt: Date? = nil,
        criticalStartedAt: Date? = nil,
        diedAt: Date? = nil,
        lastGentlePromptAt: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.catalogId = catalogId
        self.nameZh = nameZh
        self.nameEn = nameEn
        self.nameDe = nameDe
        self.emoji = emoji
        self.rarityRaw = rarity.rawValue
        self.nickname = nickname
        self.level = level
        self.starLevel = starLevel
        self.xp = xp
        self.hunger = hunger
        self.mood = mood
        self.health = health
        self.bond = bond
        self.appearanceStage = appearanceStage
        self.isFeaturedOnOasis = isFeaturedOnOasis
        self.habitatSlot = habitatSlot
        self.equippedDecorId = equippedDecorId
        self.favoriteItemId = favoriteItemId
        self.personalityRaw = personalityRaw
        self.featuredPoseRaw = featuredPoseRaw
        self.sourceLevel = sourceLevel
        self.obtainedAt = obtainedAt
        self.lastInteractionAt = lastInteractionAt
        self.lastStateRefreshAt = lastStateRefreshAt
        self.lifeStateRaw = lifeStateRaw
        self.deathReasonRaw = deathReasonRaw
        self.riskStartedAt = riskStartedAt
        self.criticalStartedAt = criticalStartedAt
        self.diedAt = diedAt
        self.lastGentlePromptAt = lastGentlePromptAt
        self.isArchived = isArchived
    }

    var rarity: OasisElectronicPetRarity {
        get { OasisElectronicPetRarity(rawValue: rarityRaw) ?? .common }
        set { rarityRaw = newValue.rawValue }
    }

    var lifeState: OasisCritterLifeState {
        get { OasisCritterLifeState(rawValue: lifeStateRaw) ?? .healthy }
        set { lifeStateRaw = newValue.rawValue }
    }

    var deathReason: OasisCritterDeathReason? {
        get {
            guard !deathReasonRaw.isEmpty else { return nil }
            return OasisCritterDeathReason(rawValue: deathReasonRaw)
        }
        set { deathReasonRaw = newValue?.rawValue ?? "" }
    }

    func displayName(_ l: L10n) -> String {
        if !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nickname
        }
        if let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) {
            return entry.name(l)
        }
        return l.tr(zh: nameZh, en: nameEn, de: nameDe)
    }
}

@Model
final class OasisCritterFragmentBalance {
    #Index<OasisCritterFragmentBalance>([\.catalogId], [\.updatedAt])

    var id: UUID
    var catalogId: String
    var amount: Int
    var updatedAt: Date

    init(id: UUID = UUID(), catalogId: String, amount: Int = 0, updatedAt: Date = Date()) {
        self.id = id
        self.catalogId = catalogId
        self.amount = amount
        self.updatedAt = updatedAt
    }
}

@Model
final class OasisCritterActionLog {
    #Index<OasisCritterActionLog>([\.critterCatalogId], [\.actionRaw], [\.createdAt])

    var id: UUID
    var critterId: UUID?
    var critterCatalogId: String
    var actionRaw: String
    var createdAt: Date
    var coconutDelta: Int
    var fragmentDelta: Int
    var xpDelta: Int
    var sourceLevel: Int
    var noteZh: String
    var noteEn: String
    var noteDe: String

    init(
        id: UUID = UUID(),
        critterId: UUID? = nil,
        critterCatalogId: String,
        action: OasisCritterAction,
        createdAt: Date = Date(),
        coconutDelta: Int = 0,
        fragmentDelta: Int = 0,
        xpDelta: Int = 0,
        sourceLevel: Int = 0,
        noteZh: String,
        noteEn: String,
        noteDe: String
    ) {
        self.id = id
        self.critterId = critterId
        self.critterCatalogId = critterCatalogId
        self.actionRaw = action.rawValue
        self.createdAt = createdAt
        self.coconutDelta = coconutDelta
        self.fragmentDelta = fragmentDelta
        self.xpDelta = xpDelta
        self.sourceLevel = sourceLevel
        self.noteZh = noteZh
        self.noteEn = noteEn
        self.noteDe = noteDe
    }

    var action: OasisCritterAction {
        get { OasisCritterAction(rawValue: actionRaw) ?? .rest }
        set { actionRaw = newValue.rawValue }
    }

    func note(_ l: L10n) -> String {
        l.tr(zh: noteZh, en: noteEn, de: noteDe)
    }
}

@Model
final class OasisUnlock {
    #Index<OasisUnlock>([\.unlockId], [\.unlockKindRaw], [\.createdAt])

    var id: UUID
    var unlockId: String
    var unlockKindRaw: String
    var sourceLevel: Int
    var createdAt: Date
    var metadataJSON: String

    init(
        id: UUID = UUID(),
        unlockId: String,
        unlockKind: OasisUpgradeRewardKind,
        sourceLevel: Int,
        createdAt: Date = Date(),
        metadataJSON: String = "{}"
    ) {
        self.id = id
        self.unlockId = unlockId
        self.unlockKindRaw = unlockKind.rawValue
        self.sourceLevel = sourceLevel
        self.createdAt = createdAt
        self.metadataJSON = metadataJSON
    }

    var unlockKind: OasisUpgradeRewardKind {
        get { OasisUpgradeRewardKind(rawValue: unlockKindRaw) ?? .decoration }
        set { unlockKindRaw = newValue.rawValue }
    }
}

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
        if unlockHintZh.isEmpty && unlockHintEn.isEmpty && unlockHintDe.isEmpty {
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

enum OasisUpgradeRewardCatalog {
    static let firstCritterId = "sprout_mochi"
    static let legendaryCritterId = "aurora_luma"
    static let mossBunId = "moss_bun"
    static let pebblePopId = "pebble_pop"
    static let emberPipId = "ember_pip"
    static let moonJellyId = "moon_jelly"

    static let critters: [OasisElectronicPetCatalogEntry] = [
        .init(
            id: firstCritterId,
            emoji: "🥥",
            rarity: .rare,
            sourceLevel: 5,
            assetName: "CritterLumo",
            unlockHintZh: "生命树 Lv.5 保底",
            unlockHintEn: "Guaranteed at Tree Lv.5",
            unlockHintDe: "Garantiert bei Baum Lv.5",
            personalityRaw: "mischievous",
            preferredItemId: "coconut_milk",
            nameZh: "Lumo",
            nameEn: "Lumo",
            nameDe: "Lumo",
            taglineZh: "长耳毛绒帽里藏着小坏笑的俏皮伙伴",
            taglineEn: "A quietly mischievous plush companion with tall ears and a tiny smirk.",
            taglineDe: "Ein still schelmischer Plüschbegleiter mit langen Ohren und kleinem Grinsen."
        ),
        .init(
            id: legendaryCritterId,
            emoji: "✨",
            rarity: .legendary,
            sourceLevel: 10,
            assetName: "CritterAuroraLuma",
            unlockHintZh: "生命树 Lv.10 保底",
            unlockHintEn: "Guaranteed at Tree Lv.10",
            unlockHintDe: "Garantiert bei Baum Lv.10",
            personalityRaw: "mystic",
            preferredItemId: "aurora_crystal",
            nameZh: "极光灵",
            nameEn: "Aurora Luma",
            nameDe: "Aurora Luma",
            taglineZh: "生命之树满级时出现的传说伙伴",
            taglineEn: "A legendary companion born at the tree's peak.",
            taglineDe: "Ein legendärer Begleiter vom Gipfel des Lebensbaums."
        ),
        .init(
            id: "moss_bun",
            emoji: "🍃",
            rarity: .common,
            sourceLevel: 3,
            assetName: "CritterMossBun",
            unlockHintZh: "碎片唤醒 · Lv.3 后更容易获得",
            unlockHintEn: "Fragment awakening · easier after Lv.3",
            unlockHintDe: "Fragmente · leichter ab Lv.3",
            personalityRaw: "sleepy",
            preferredItemId: "moss_cookie",
            nameZh: "苔团",
            nameEn: "Moss Bun",
            nameDe: "Moosknopf",
            taglineZh: "喜欢靠在树根旁打盹的小团子",
            taglineEn: "A sleepy little bun that naps by the roots.",
            taglineDe: "Ein schläfriger kleiner Knopf an den Wurzeln."
        ),
        .init(
            id: "pebble_pop",
            emoji: "🫧",
            rarity: .common,
            sourceLevel: 4,
            assetName: "CritterPebblePop",
            unlockHintZh: "碎片唤醒 · Oasis 装饰奖励池",
            unlockHintEn: "Fragment awakening · Oasis decor pool",
            unlockHintDe: "Fragmente · Oasis-Deko-Pool",
            personalityRaw: "playful",
            preferredItemId: "bubble_pebble",
            nameZh: "泡泡石",
            nameEn: "Pebble Pop",
            nameDe: "Kieselplopp",
            taglineZh: "会把小石子吹成泡泡的调皮伙伴",
            taglineEn: "A playful pal that turns pebbles into bubbles.",
            taglineDe: "Ein verspielter Freund mit Kieselblasen."
        ),
        .init(
            id: "ember_pip",
            emoji: "🔥",
            rarity: .epic,
            sourceLevel: 8,
            assetName: "CritterEmberPip",
            unlockHintZh: "碎片唤醒 · 高级升级椰子",
            unlockHintEn: "Fragment awakening · high-level coconuts",
            unlockHintDe: "Fragmente · höhere Upgrade-Kokosnüsse",
            personalityRaw: "brave",
            preferredItemId: "warm_coal",
            nameZh: "烬豆",
            nameEn: "Ember Pip",
            nameDe: "Glutkern",
            taglineZh: "在夜晚给小窝点亮微光的勇敢伙伴",
            taglineEn: "A brave spark that warms the nest at night.",
            taglineDe: "Ein mutiger Funke für warme Nächte."
        ),
        .init(
            id: "moon_jelly",
            emoji: "🌙",
            rarity: .epic,
            sourceLevel: 9,
            assetName: "CritterMoonJelly",
            unlockHintZh: "活动/碎片预留",
            unlockHintEn: "Event or fragment reserve",
            unlockHintDe: "Event- oder Fragmentreserve",
            personalityRaw: "calm",
            preferredItemId: "moon_drop",
            nameZh: "月冻",
            nameEn: "Moon Jelly",
            nameDe: "Mondgelee",
            taglineZh: "像月光一样安静漂浮的梦境伙伴",
            taglineEn: "A calm dream companion drifting like moonlight.",
            taglineDe: "Ein ruhiger Traumfreund wie Mondlicht."
        )
    ]

    static func critter(id: String) -> OasisElectronicPetCatalogEntry? {
        critters.first { $0.id == id }
    }

    static func rule(for level: Int) -> OasisUpgradeRewardRule {
        switch level {
        case 5:
            return .init(
                level: level,
                rewardKind: .electronicPet,
                rewardCatalogId: "level_5_first_critter",
                guaranteedCritterId: firstCritterId,
                coconutAmount: 50,
                treeEnergyAmount: 0,
                fragmentAmount: 60,
                decorUnlockId: "oasis_first_nest",
                storyStyleUnlockId: nil,
                temporaryEffectId: nil,
                titleZh: "第一只电子宠物",
                titleEn: "First Critter",
                titleDe: "Erstes Critter",
                descriptionZh: "保底唤醒稀有伙伴 Lumo。",
                descriptionEn: "Guaranteed rare companion: Lumo.",
                descriptionDe: "Garantierter seltener Begleiter: Lumo."
            )
        case 10:
            return .init(
                level: level,
                rewardKind: .electronicPet,
                rewardCatalogId: "level_10_legendary_critter",
                guaranteedCritterId: legendaryCritterId,
                coconutAmount: 120,
                treeEnergyAmount: 0,
                fragmentAmount: 160,
                decorUnlockId: "legendary_tree_frame",
                storyStyleUnlockId: nil,
                temporaryEffectId: nil,
                titleZh: "传说电子宠物",
                titleEn: "Legendary Critter",
                titleDe: "Legendäres Critter",
                descriptionZh: "满级纪念，保底唤醒极光灵。",
                descriptionEn: "Peak milestone reward: Aurora Luma.",
                descriptionDe: "Gipfel-Meilenstein: Aurora Luma."
            )
        case 3, 6, 9:
            let amount = level == 3 ? 12 : (level == 6 ? 24 : 48)
            return .init(
                level: level,
                rewardKind: .fragments,
                rewardCatalogId: "level_\(level)_critter_fragments",
                guaranteedCritterId: fragmentTargetCritterId(for: level),
                coconutAmount: level * 6,
                treeEnergyAmount: 0,
                fragmentAmount: amount,
                decorUnlockId: nil,
                storyStyleUnlockId: nil,
                temporaryEffectId: nil,
                titleZh: "电子宠物碎片",
                titleEn: "Critter Fragments",
                titleDe: "Critter-Fragmente",
                descriptionZh: "积攒碎片，用于升星或兑换伙伴。",
                descriptionEn: "Save fragments for stars or future companions.",
                descriptionDe: "Sammle Fragmente für Sterne oder neue Begleiter."
            )
        case 4, 7:
            return .init(
                level: level,
                rewardKind: .decoration,
                rewardCatalogId: "level_\(level)_oasis_decor",
                guaranteedCritterId: level == 4 ? pebblePopId : emberPipId,
                coconutAmount: level * 5,
                treeEnergyAmount: 0,
                fragmentAmount: level == 7 ? 18 : 8,
                decorUnlockId: level == 4 ? "mossy_coconut_stone" : "glow_leaf_lamp",
                storyStyleUnlockId: nil,
                temporaryEffectId: nil,
                titleZh: "Oasis 装饰",
                titleEn: "Oasis Decor",
                titleDe: "Oasis-Deko",
                descriptionZh: "解锁一个生命之树周边装饰。",
                descriptionEn: "Unlock a small decor piece for the Oasis.",
                descriptionDe: "Schalte eine kleine Deko für die Oasis frei."
            )
        case 8:
            return .init(
                level: level,
                rewardKind: .storyStyle,
                rewardCatalogId: "level_8_story_style",
                guaranteedCritterId: moonJellyId,
                coconutAmount: 45,
                treeEnergyAmount: 0,
                fragmentAmount: 30,
                decorUnlockId: nil,
                storyStyleUnlockId: "leaf_story_reveal",
                temporaryEffectId: nil,
                titleZh: "故事样式",
                titleEn: "Story Style",
                titleDe: "Story-Stil",
                descriptionZh: "解锁一款叶影故事卡样式。",
                descriptionEn: "Unlock a leafy story card style.",
                descriptionDe: "Schalte einen Blatt-Storykartenstil frei."
            )
        case 2:
            return .init(
                level: level,
                rewardKind: .coconuts,
                rewardCatalogId: "level_2_seed_pack",
                guaranteedCritterId: fragmentTargetCritterId(for: level),
                coconutAmount: 20,
                treeEnergyAmount: 0,
                fragmentAmount: 0,
                decorUnlockId: nil,
                storyStyleUnlockId: nil,
                temporaryEffectId: nil,
                titleZh: "小椰子补给",
                titleEn: "Coconut Supply",
                titleDe: "Kokos-Vorrat",
                descriptionZh: "升级第一份奖励，给岛屿一点启动资金。",
                descriptionEn: "A first upgrade reward for your island.",
                descriptionDe: "Die erste Upgrade-Belohnung für deine Insel."
            )
        default:
            return .init(
                level: level,
                rewardKind: .treeEnergy,
                rewardCatalogId: "level_\(level)_tree_spark",
                guaranteedCritterId: nil,
                coconutAmount: max(10, level * 5),
                treeEnergyAmount: max(20, level * 10),
                fragmentAmount: 6,
                decorUnlockId: nil,
                storyStyleUnlockId: nil,
                temporaryEffectId: "tree_spark_\(level)",
                titleZh: "树能量火花",
                titleEn: "Tree Spark",
                titleDe: "Baumfunke",
                descriptionZh: "补充树能量，并留下一点电子宠物碎片。",
                descriptionEn: "Adds tree energy and a few critter fragments.",
                descriptionDe: "Gibt Baumenergie und ein paar Critter-Fragmente."
            )
        }
    }

    static func fragmentTargetCritterId(for level: Int) -> String {
        if level >= 9 { return legendaryCritterId }
        switch level % 5 {
        case 0: return firstCritterId
        case 1: return emberPipId
        case 2: return pebblePopId
        case 3: return mossBunId
        default: return moonJellyId
        }
    }
}

@MainActor
enum OasisCritterEconomyService {
    static func currentHuman(context: ModelContext) -> Human? {
        guard let id = UserDefaults.standard.string(forKey: "currentActiveHumanId"),
              !id.isEmpty else { return nil }
        return (try? context.fetch(FetchDescriptor<Human>()))?.first { $0.id.uuidString == id }
    }

    static func currentHumanBalance(context: ModelContext) -> Int {
        currentHuman(context: context)?.coconutBalance ?? QuestManager.shared.coconutCount
    }

    static func canSpendCurrentHumanCoconuts(_ amount: Int, context: ModelContext) -> Bool {
        guard amount > 0 else { return true }
        if let human = currentHuman(context: context) {
            return human.coconutBalance >= amount
        }
        return QuestManager.shared.coconutCount >= amount
    }

    @discardableResult
    static func spendCurrentHumanCoconuts(_ amount: Int, emoji: String, title: String, context: ModelContext) -> Bool {
        guard amount > 0 else { return true }
        if let human = currentHuman(context: context) {
            guard human.coconutBalance >= amount else { return false }
            human.coconutBalance -= amount
            QuestManager.shared.recordCoconutDelta(
                -amount,
                emoji: emoji,
                title: title,
                actorId: human.id.uuidString,
                actorName: human.name
            )
            return true
        }
        guard QuestManager.shared.coconutCount >= amount else { return false }
        QuestManager.shared.recordCoconutDelta(-amount, emoji: emoji, title: title, actorId: "system", actorName: "Oasis")
        return true
    }

    static func awardCurrentHumanCoconuts(_ amount: Int, emoji: String, title: String, context: ModelContext) {
        guard amount > 0 else { return }
        if let human = currentHuman(context: context) {
            human.coconutBalance += amount
            QuestManager.shared.recordCoconutDelta(
                amount,
                emoji: emoji,
                title: title,
                actorId: human.id.uuidString,
                actorName: human.name
            )
        } else {
            QuestManager.shared.recordCoconutDelta(amount, emoji: emoji, title: title, actorId: "system", actorName: "Oasis")
        }
    }
}

@MainActor
enum OasisUpgradeRewardService {
    private static let lifecycleDay: TimeInterval = 86_400
    private static let needsCareThreshold = 45
    private static let atRiskThreshold = 20
    private static let sickHealthThreshold = 45
    private static let elderWarningDays = 180
    private static let oldAgeDeathDays = 210
    private static let riskToCriticalHours = 72
    private static let criticalToDeathHours = 72

    @discardableResult
    static func ensureUpgradeCoconuts(from firstLevel: Int, through lastLevel: Int, context: ModelContext) -> Int {
        guard lastLevel >= max(2, firstLevel) else { return 0 }
        let existing = (try? context.fetch(FetchDescriptor<OasisUpgradeCoconut>())) ?? []
        let existingLevels = Set(existing.map(\.level))
        var inserted = 0

        for level in max(2, firstLevel)...lastLevel where !existingLevels.contains(level) {
            context.insert(OasisUpgradeRewardCatalog.rule(for: level).makeCoconut())
            inserted += 1
        }

        if inserted > 0 {
            try? context.save()
        }
        return inserted
    }

    static func open(_ coconut: OasisUpgradeCoconut, context: ModelContext) throws -> OasisOpenedUpgradeReward {
        guard !coconut.isOpened else {
            return openedResult(for: coconut, duplicate: false)
        }

        var duplicateCritter = false
        coconut.openedAt = Date()

        OasisCritterEconomyService.awardCurrentHumanCoconuts(
            coconut.coconutAmount,
            emoji: "🥥",
            title: "升级椰子 Lv.\(coconut.level)",
            context: context
        )

        if coconut.treeEnergyAmount > 0 {
            OasisTreeManager.shared.injectedEnergy += coconut.treeEnergyAmount
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
                let hasFeatured = ((try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? [])
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

        if coconut.treeEnergyAmount > 0 {
            _ = OasisTreeManager.shared.checkAndRewardLevelUp(modelContext: context)
        }

        try context.save()
        return openedResult(for: coconut, duplicate: duplicateCritter)
    }

    static func dailyWish(for critter: OasisElectronicPet, context: ModelContext, now: Date = Date()) -> OasisCritterDailyWish {
        normalizeLifecycle(for: critter, context: context, now: now)
        let snapshot = lifecycleSnapshot(for: critter, context: context, now: now)
        return displayDailyWish(for: critter, snapshot: snapshot, now: now)
    }

    static func displayDailyWish(
        for critter: OasisElectronicPet,
        snapshot: OasisCritterLifecycleSnapshot,
        now: Date = Date()
    ) -> OasisCritterDailyWish {
        if snapshot.state == .dead {
            return dailyWish(for: .rest)
        }
        if snapshot.state == .atRisk || snapshot.state == .sick || snapshot.state == .critical {
            return dailyWish(for: .rescue)
        }

        let action: OasisCritterAction
        if critter.hunger < 45 {
            action = .feed
        } else if critter.health < 70 {
            action = .rest
        } else if critter.mood < 45 {
            action = .play
        } else {
            let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? Int(now.timeIntervalSince1970 / 86_400)
            let catalogScore = critter.catalogId.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            let index = abs(day + catalogScore + critter.level * 17 + critter.starLevel * 31) % 3
            action = [.feed, .play, .rest][index]
        }
        return dailyWish(for: action)
    }

    static func isDailyWishCompleted(for critter: OasisElectronicPet, wish: OasisCritterDailyWish, context: ModelContext) -> Bool {
        actionLogs(for: critter, context: context).contains { $0.action == wish.action }
    }

    static func bondLevel(for critter: OasisElectronicPet) -> Int {
        min(10, max(1, critter.bond / 100 + 1))
    }

    static func bondProgress(for critter: OasisElectronicPet) -> Int {
        max(0, min(100, critter.bond % 100))
    }

    @discardableResult
    static func interact(with critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) throws -> Bool {
        try interactWithOutcome(with: critter, action: action, context: context).success
    }

    @discardableResult
    static func interactWithOutcome(with critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) throws -> OasisCritterInteractionOutcome {
        normalizeLifecycle(for: critter, context: context)
        if critter.lifeState == .dead {
            return deadInteractionOutcome(for: critter, action: action)
        }
        let wish = dailyWish(for: critter, context: context)
        let wasWishCompleted = isDailyWishCompleted(for: critter, wish: wish, context: context)

        switch action {
        case .feed:
            let cost = interactionCost(for: critter, action: action, context: context)
            guard OasisCritterEconomyService.spendCurrentHumanCoconuts(cost, emoji: "🍽️", title: "喂养电子宠物", context: context) else {
                return failedInteraction(action: action, wish: wish)
            }
            critter.hunger = min(100, critter.hunger + 24)
            critter.mood = min(100, critter.mood + 6)
            critter.health = min(100, critter.health + 8)
            critter.bond = min(999, critter.bond + 3)
            critter.xp += 10
            context.insert(actionLog(for: critter, action: action, coconutDelta: -cost, xpDelta: 10))
        case .play:
            let cost = interactionCost(for: critter, action: action, context: context)
            guard OasisCritterEconomyService.spendCurrentHumanCoconuts(cost, emoji: "🪀", title: "陪电子宠物玩耍", context: context) else {
                return failedInteraction(action: action, wish: wish)
            }
            critter.hunger = max(0, critter.hunger - 5)
            critter.mood = min(100, critter.mood + 18)
            critter.health = min(100, critter.health + 4)
            critter.bond = min(999, critter.bond + 5)
            critter.xp += 12
            context.insert(actionLog(for: critter, action: action, coconutDelta: -cost, xpDelta: 12))
        case .rest:
            guard dailyActionCount(for: action, critter: critter, context: context) < 3 else {
                return failedInteraction(action: action, wish: wish)
            }
            critter.hunger = max(0, critter.hunger - 2)
            critter.mood = min(100, critter.mood + 8)
            critter.health = min(100, critter.health + 10)
            critter.bond = min(999, critter.bond + 1)
            critter.xp += 4
            context.insert(actionLog(for: critter, action: action, xpDelta: 4))
        case .rescue, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            return failedInteraction(action: action, wish: wish)
        }

        let completedWish = action == wish.action && !wasWishCompleted
        if completedWish {
            critter.xp += wish.rewardXP
            critter.bond = min(999, critter.bond + wish.rewardBond)
            addFragments(critterId: critter.catalogId, amount: wish.rewardFragments, context: context)
            OasisCritterEconomyService.awardCurrentHumanCoconuts(
                wish.rewardCoconuts,
                emoji: "💌",
                title: "电子宠物小愿望",
                context: context
            )
            context.insert(OasisCritterActionLog(
                critterId: critter.id,
                critterCatalogId: critter.catalogId,
                action: .careEcho,
                coconutDelta: wish.rewardCoconuts,
                fragmentDelta: wish.rewardFragments,
                xpDelta: wish.rewardXP,
                sourceLevel: critter.sourceLevel,
                noteZh: "完成今日小愿望",
                noteEn: "Completed today's tiny wish.",
                noteDe: "Heutigen kleinen Wunsch erfüllt."
            ))
        }

        while critter.xp >= 100 {
            critter.xp -= 100
            critter.level += 1
            if critter.level % 3 == 0 {
                critter.appearanceStage = min(4, critter.appearanceStage + 1)
            }
        }
        critter.lastInteractionAt = Date()
        critter.lastStateRefreshAt = Date()
        refreshLifecycleState(for: critter, now: Date())
        try context.save()
        return interactionOutcome(action: action, wish: wish, completedWish: completedWish)
    }

    static func canInteract(with critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) -> Bool {
        guard critter.lifeState != .dead else { return false }
        switch action {
        case .feed:
            return OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                interactionCost(for: critter, action: action, context: context),
                context: context
            )
        case .play:
            return OasisCritterEconomyService.canSpendCurrentHumanCoconuts(
                interactionCost(for: critter, action: action, context: context),
                context: context
            )
        case .rest:
            return dailyActionCount(for: action, critter: critter, context: context) < 3
        case .rescue, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            return false
        }
    }

    static func todayInteractionCount(for critter: OasisElectronicPet, context: ModelContext) -> Int {
        let activeActions: Set<OasisCritterAction> = [.feed, .play, .rest]
        return actionLogs(for: critter, context: context).filter { activeActions.contains($0.action) }.count
    }

    @discardableResult
    static func upgradeStar(for critter: OasisElectronicPet, context: ModelContext) throws -> Bool {
        normalizeLifecycle(for: critter, context: context)
        guard critter.lifeState != .dead else { return false }
        let cost = starUpgradeCost(for: critter)
        guard let balance = fragmentBalance(critterId: critter.catalogId, context: context),
              balance.amount >= cost.fragments,
              OasisCritterEconomyService.canSpendCurrentHumanCoconuts(cost.coconuts, context: context) else {
            return false
        }

        balance.amount -= cost.fragments
        balance.updatedAt = Date()
        guard OasisCritterEconomyService.spendCurrentHumanCoconuts(cost.coconuts, emoji: "⭐️", title: "电子宠物升星", context: context) else {
            balance.amount += cost.fragments
            balance.updatedAt = Date()
            return false
        }
        critter.starLevel += 1
        critter.bond = min(999, critter.bond + 20)
        critter.mood = min(100, critter.mood + 16)
        critter.appearanceStage = min(4, max(critter.appearanceStage, critter.starLevel))
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
    static func awakenWithFragments(catalogId: String, context: ModelContext) throws -> OasisElectronicPet? {
        guard !ownsCritter(catalogId, context: context),
              let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) else {
            return nil
        }
        let cost = awakeningCost(for: entry.rarity)
        guard let balance = fragmentBalance(critterId: catalogId, context: context),
              balance.amount >= cost.fragments,
              OasisCritterEconomyService.canSpendCurrentHumanCoconuts(cost.coconuts, context: context) else {
            return nil
        }

        balance.amount -= cost.fragments
        balance.updatedAt = Date()
        guard OasisCritterEconomyService.spendCurrentHumanCoconuts(cost.coconuts, emoji: "🐾", title: "碎片唤醒电子宠物", context: context) else {
            balance.amount += cost.fragments
            balance.updatedAt = Date()
            return nil
        }

        let hasFeatured = ((try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? [])
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
            sourceLevel: 0
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
        let all = (try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? []
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

    static func rewardFeaturedCritterFromCare(type: QuestManager.OhanaActionType, context: ModelContext) {
        let candidates = ((try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? [])
            .filter({ !$0.isArchived })
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
        critter.xp += gain.xp
        critter.bond = min(999, critter.bond + gain.bond)
        critter.mood = min(100, critter.mood + gain.mood)
        critter.health = min(100, critter.health + gain.health)
        switch type {
        case .feed, .water:
            critter.hunger = min(100, critter.hunger + 6)
        default:
            break
        }
        while critter.xp >= 100 {
            critter.xp -= 100
            critter.level += 1
            if critter.level % 3 == 0 {
                critter.appearanceStage = min(4, critter.appearanceStage + 1)
            }
        }
        critter.lastStateRefreshAt = Date()
        refreshLifecycleState(for: critter, now: Date())
        context.insert(actionLog(
            for: critter,
            action: .careEcho,
            xpDelta: gain.xp
        ))
        try? context.save()
    }

    private static func careEchoGain(for type: QuestManager.OhanaActionType) -> (xp: Int, bond: Int, mood: Int, health: Int) {
        switch type {
        case .walk:
            return (8, 3, 3, 4)
        case .health, .care:
            return (7, 3, 2, 8)
        case .feed, .water:
            return (4, 2, 2, 4)
        case .potty, .weight:
            return (3, 1, 1, 3)
        case .expense:
            return (2, 1, 0, 1)
        case .milestone:
            return (12, 5, 4, 6)
        case .general:
            return (4, 2, 1, 2)
        }
    }

    static func interactionCost(for critter: OasisElectronicPet, action: OasisCritterAction, context: ModelContext) -> Int {
        switch action {
        case .feed:
            return dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 5
        case .play:
            return dailyActionCount(for: action, critter: critter, context: context) == 0 ? 0 : 3
        case .rest:
            return 0
        case .rescue, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            return 0
        }
    }

    static func awakeningCost(for rarity: OasisElectronicPetRarity) -> (fragments: Int, coconuts: Int) {
        switch rarity {
        case .common: return (120, 80)
        case .rare: return (180, 120)
        case .epic: return (300, 220)
        case .legendary: return (520, 420)
        }
    }

    static func starUpgradeCost(for critter: OasisElectronicPet) -> (fragments: Int, coconuts: Int) {
        (critter.starLevel * 40, critter.starLevel * 80)
    }

    static func normalizeDecay(for critter: OasisElectronicPet) {
        normalizeLifecycle(for: critter)
    }

    static func normalizeLifecycle(for critter: OasisElectronicPet, context: ModelContext? = nil, now: Date = Date()) {
        let before = lifecycleFingerprint(for: critter)
        let wasDead = critter.lifeState == .dead
        guard !wasDead else { return }

        settleElapsedNeeds(for: critter, now: now)
        refreshLifecycleState(for: critter, now: now)

        if critter.lifeState == .dead, before.lifeState != OasisCritterLifeState.dead.rawValue {
            critter.isFeaturedOnOasis = false
            if let context {
                context.insert(deathLog(for: critter, now: now))
            }
        }

        if lifecycleFingerprint(for: critter) != before, let context {
            try? context.save()
        }
    }

    static func lifecycleSnapshot(
        for critter: OasisElectronicPet,
        context: ModelContext? = nil,
        now: Date = Date()
    ) -> OasisCritterLifecycleSnapshot {
        _ = context
        let state = critter.lifeState
        let remainingHours: Int?
        if state == .critical, let criticalStartedAt = critter.criticalStartedAt {
            remainingHours = max(0, criticalToDeathHours - hoursBetween(criticalStartedAt, now))
        } else {
            remainingHours = nil
        }
        let urgency: Int
        switch state {
        case .healthy: urgency = 0
        case .needsCare: urgency = 1
        case .atRisk: urgency = 2
        case .sick: urgency = 3
        case .critical: urgency = 4
        case .dead: urgency = 5
        }
        return OasisCritterLifecycleSnapshot(
            state: state,
            deathReason: critter.deathReason,
            recommendedAction: recommendedCareAction(for: critter),
            isRescuable: state == .atRisk || state == .sick || state == .critical,
            hoursUntilDeath: remainingHours,
            ageDays: ageDays(for: critter, now: now),
            urgencyScore: urgency
        )
    }

    static func gentlePrompt(for critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot, l: L10n) -> String {
        let name = critter.displayName(l)
        switch snapshot.state {
        case .healthy:
            return l.tr(
                zh: "\(name) 今天很安稳，像一团小小的云贴在你身边。",
                en: "\(name) feels settled today, soft and close by.",
                de: "\(name) fühlt sich heute ruhig an, weich und nah bei dir."
            )
        case .needsCare:
            if snapshot.ageDays >= elderWarningDays {
                return l.tr(
                    zh: "\(name) 最近动作慢了一点，想被轻轻陪一会儿。",
                    en: "\(name) moves a little slower lately and wants gentle company.",
                    de: "\(name) bewegt sich langsam und möchte sanfte Nähe."
                )
            }
            return l.tr(
                zh: "\(name) 轻轻碰了碰椰壳，像是在说想你了。",
                en: "\(name) taps the coconut shell softly, as if missing you.",
                de: "\(name) stupst die Kokosschale leise an, als würde es dich vermissen."
            )
        case .atRisk:
            return l.tr(
                zh: "\(name) 缩进椰壳里等一会儿，照顾一下就会缓过来。",
                en: "\(name) is curled in the coconut shell. A little care will help.",
                de: "\(name) kuschelt in der Kokosschale. Ein wenig Pflege hilft."
            )
        case .sick:
            return l.tr(
                zh: "\(name) 有点没精神，还来得及温柔地救回来。",
                en: "\(name) is low on energy, but you can still gently bring it back.",
                de: "\(name) hat wenig Energie, aber du kannst es sanft zurückholen."
            )
        case .critical:
            let hours = snapshot.hoursUntilDeath ?? criticalToDeathHours
            return l.tr(
                zh: "\(name) 真的需要你一下，约 \(hours) 小时内照顾都能救回来。",
                en: "\(name) really needs you. Care within about \(hours)h can still rescue it.",
                de: "\(name) braucht dich wirklich. Pflege innerhalb von etwa \(hours) Std. kann es retten."
            )
        case .dead:
            let reason = snapshot.deathReason?.name(l) ?? l.tr(zh: "生命结束", en: "life ended", de: "das Leben endete")
            return l.tr(
                zh: "\(name) 已经安静地回到纪念册里，原因是\(reason)。",
                en: "\(name) is resting in the memorial album because of \(reason).",
                de: "\(name) ruht im Erinnerungsalbum wegen \(reason)."
            )
        }
    }

    @discardableResult
    static func rescueIfNeeded(for critter: OasisElectronicPet, context: ModelContext, now: Date = Date()) throws -> OasisCritterInteractionOutcome {
        normalizeLifecycle(for: critter, context: context, now: now)
        let snapshot = lifecycleSnapshot(for: critter, context: context, now: now)
        let wish = dailyWish(for: .rescue)
        guard critter.lifeState != .dead else {
            return deadInteractionOutcome(for: critter, action: .rescue)
        }
        guard snapshot.isRescuable else {
            return OasisCritterInteractionOutcome(
                success: false,
                action: .rescue,
                completedDailyWish: false,
                wish: wish,
                messageZh: "现在不用急，它只是想被轻轻陪一下。",
                messageEn: "No rush right now. It only wants gentle company.",
                messageDe: "Kein Stress gerade. Es möchte nur sanfte Nähe.",
                rewardXP: 0,
                rewardBond: 0,
                rewardFragments: 0,
                rewardCoconuts: 0
            )
        }

        critter.hunger = max(critter.hunger, 58)
        critter.mood = max(critter.mood, 58)
        critter.health = max(critter.health, 74)
        critter.bond = min(999, critter.bond + 4)
        critter.xp += 8
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.lifeState = .healthy
        critter.deathReason = nil
        critter.lastInteractionAt = now
        critter.lastStateRefreshAt = now
        critter.lastGentlePromptAt = now
        context.insert(actionLog(for: critter, action: .rescue, xpDelta: 8))
        try context.save()
        return OasisCritterInteractionOutcome(
            success: true,
            action: .rescue,
            completedDailyWish: false,
            wish: wish,
            messageZh: "你轻轻照顾了一下，它慢慢从椰壳里探出头。",
            messageEn: "You gave gentle care, and it slowly peeks out of the coconut shell.",
            messageDe: "Du hast sanft geholfen, und es schaut langsam aus der Kokosschale.",
            rewardXP: 8,
            rewardBond: 4,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    private struct LifecycleFingerprint: Equatable {
        var hunger: Int
        var mood: Int
        var health: Int
        var lifeState: String
        var deathReason: String
        var riskStartedAt: Date?
        var criticalStartedAt: Date?
        var diedAt: Date?
        var lastStateRefreshAt: Date
        var isFeaturedOnOasis: Bool
    }

    private static func lifecycleFingerprint(for critter: OasisElectronicPet) -> LifecycleFingerprint {
        LifecycleFingerprint(
            hunger: critter.hunger,
            mood: critter.mood,
            health: critter.health,
            lifeState: critter.lifeStateRaw,
            deathReason: critter.deathReasonRaw,
            riskStartedAt: critter.riskStartedAt,
            criticalStartedAt: critter.criticalStartedAt,
            diedAt: critter.diedAt,
            lastStateRefreshAt: critter.lastStateRefreshAt,
            isFeaturedOnOasis: critter.isFeaturedOnOasis
        )
    }

    private static func settleElapsedNeeds(for critter: OasisElectronicPet, now: Date) {
        let elapsed = max(0, now.timeIntervalSince(critter.lastStateRefreshAt))
        let days = Int(elapsed / lifecycleDay)
        guard days > 0 else { return }
        let wasLow = isLowCondition(critter)
        critter.hunger = max(0, critter.hunger - days * 14)
        critter.mood = max(0, critter.mood - days * 10)
        if wasLow || isLowCondition(critter) {
            critter.health = max(0, critter.health - days * 8)
        } else {
            critter.health = min(100, critter.health + days * 2)
        }
        critter.lastStateRefreshAt = now
    }

    private static func refreshLifecycleState(for critter: OasisElectronicPet, now: Date) {
        guard critter.lifeState != .dead else { return }
        let age = ageDays(for: critter, now: now)
        if age >= oldAgeDeathDays {
            markDead(critter, reason: .oldAge, now: now)
            return
        }

        if isLowCondition(critter) {
            if critter.riskStartedAt == nil {
                critter.riskStartedAt = now
            }
            let riskHours = hoursBetween(critter.riskStartedAt ?? now, now)
            if riskHours >= riskToCriticalHours {
                if critter.criticalStartedAt == nil {
                    critter.criticalStartedAt = now
                }
                if hoursBetween(critter.criticalStartedAt ?? now, now) >= criticalToDeathHours {
                    markDead(critter, reason: deathReason(for: critter), now: now)
                    return
                }
                critter.lifeState = .critical
            } else if critter.health < sickHealthThreshold || riskHours >= 48 {
                critter.lifeState = .sick
            } else {
                critter.lifeState = .atRisk
            }
            return
        }

        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        if critter.hunger < needsCareThreshold ||
            critter.mood < needsCareThreshold ||
            critter.health < 70 ||
            age >= elderWarningDays {
            critter.lifeState = .needsCare
        } else {
            critter.lifeState = .healthy
        }
        critter.deathReason = nil
        critter.diedAt = nil
    }

    private static func isLowCondition(_ critter: OasisElectronicPet) -> Bool {
        critter.hunger < atRiskThreshold ||
            critter.mood < atRiskThreshold ||
            critter.health < sickHealthThreshold
    }

    private static func recommendedCareAction(for critter: OasisElectronicPet) -> OasisCritterAction? {
        guard critter.lifeState != .dead else { return nil }
        if critter.health < 70 { return .rest }
        if critter.hunger < needsCareThreshold && critter.hunger <= critter.mood { return .feed }
        if critter.mood < needsCareThreshold { return .play }
        if critter.hunger < needsCareThreshold { return .feed }
        return nil
    }

    private static func deathReason(for critter: OasisElectronicPet) -> OasisCritterDeathReason {
        if critter.health <= 0 || (critter.health < sickHealthThreshold && critter.hunger < atRiskThreshold && critter.mood < atRiskThreshold) {
            return .sick
        }
        if critter.hunger < atRiskThreshold && critter.hunger <= critter.mood {
            return .hungry
        }
        if critter.mood < atRiskThreshold {
            return .bored
        }
        return .sick
    }

    private static func markDead(_ critter: OasisElectronicPet, reason: OasisCritterDeathReason, now: Date) {
        critter.lifeState = .dead
        critter.deathReason = reason
        critter.diedAt = critter.diedAt ?? now
        critter.riskStartedAt = nil
        critter.criticalStartedAt = nil
        critter.isFeaturedOnOasis = false
    }

    private static func ageDays(for critter: OasisElectronicPet, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(critter.obtainedAt) / lifecycleDay))
    }

    private static func hoursBetween(_ start: Date, _ end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 3600))
    }

    private static func dailyActionCount(for action: OasisCritterAction, critter: OasisElectronicPet, context: ModelContext) -> Int {
        actionLogs(for: critter, context: context).filter { $0.action == action }.count
    }

    private static func actionLogs(for critter: OasisElectronicPet, context: ModelContext) -> [OasisCritterActionLog] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let logs = (try? context.fetch(FetchDescriptor<OasisCritterActionLog>())) ?? []
        return logs.filter {
            $0.critterId == critter.id &&
            $0.createdAt >= startOfDay
        }
    }

    private static func ownsCritter(_ catalogId: String, context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<OasisElectronicPet>())) ?? []
        return all.contains { $0.catalogId == catalogId && !$0.isArchived }
    }

    private static func addFragments(critterId: String, amount: Int, context: ModelContext) {
        guard amount > 0 else { return }
        let balances = (try? context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())) ?? []
        if let balance = balances.first(where: { $0.catalogId == critterId }) {
            balance.amount += amount
            balance.updatedAt = Date()
        } else {
            context.insert(OasisCritterFragmentBalance(catalogId: critterId, amount: amount))
        }
    }

    private static func fragmentBalance(critterId: String, context: ModelContext) -> OasisCritterFragmentBalance? {
        let balances = (try? context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())) ?? []
        return balances.first { $0.catalogId == critterId }
    }

    private static func unlock(id: String, kind: OasisUpgradeRewardKind, sourceLevel: Int, context: ModelContext) {
        let unlocks = (try? context.fetch(FetchDescriptor<OasisUnlock>())) ?? []
        guard !unlocks.contains(where: { $0.unlockId == id && $0.unlockKindRaw == kind.rawValue }) else { return }
        context.insert(OasisUnlock(unlockId: id, unlockKind: kind, sourceLevel: sourceLevel))
    }

    private static func dailyWish(for action: OasisCritterAction) -> OasisCritterDailyWish {
        switch action {
        case .feed:
            return OasisCritterDailyWish(
                id: "daily_feed",
                action: .feed,
                icon: "fork.knife",
                titleZh: "想喝一点椰奶",
                titleEn: "Wants coconut milk",
                titleDe: "Möchte Kokosmilch",
                detailZh: "喂养一次，把今天的小肚子填得软软的。",
                detailEn: "Feed once and fill today's tiny belly.",
                detailDe: "Einmal füttern und den kleinen Bauch füllen.",
                rewardXP: 14,
                rewardBond: 6,
                rewardFragments: 1,
                rewardCoconuts: 3
            )
        case .play:
            return OasisCritterDailyWish(
                id: "daily_play",
                action: .play,
                icon: "sparkles",
                titleZh: "想玩星星捉迷藏",
                titleEn: "Wants star hide-and-seek",
                titleDe: "Möchte Stern-Verstecken",
                detailZh: "陪它玩一次，心情会亮起来。",
                detailEn: "Play once and brighten its mood.",
                detailDe: "Einmal spielen und die Stimmung aufhellen.",
                rewardXP: 14,
                rewardBond: 6,
                rewardFragments: 1,
                rewardCoconuts: 3
            )
        case .rest:
            return OasisCritterDailyWish(
                id: "daily_rest",
                action: .rest,
                icon: "moon.fill",
                titleZh: "想窝进椰壳午睡",
                titleEn: "Wants a coconut-shell nap",
                titleDe: "Möchte Kokosschalen-Schlaf",
                detailZh: "让它休息一次，醒来会更黏人。",
                detailEn: "Let it rest once and wake up closer.",
                detailDe: "Einmal ruhen lassen, danach ist es anhänglicher.",
                rewardXP: 14,
                rewardBond: 6,
                rewardFragments: 1,
                rewardCoconuts: 3
            )
        case .rescue:
            return OasisCritterDailyWish(
                id: "daily_rescue",
                action: .rescue,
                icon: "cross.case.fill",
                titleZh: "想被轻轻照顾一下",
                titleEn: "Wants gentle care",
                titleDe: "Möchte sanfte Pflege",
                detailZh: "点一键照顾，把它从椰壳里温柔地带回来。",
                detailEn: "Use one-tap care and gently bring it back from the coconut shell.",
                detailDe: "Nutze Ein-Klick-Pflege und hol es sanft aus der Kokosschale.",
                rewardXP: 8,
                rewardBond: 4,
                rewardFragments: 0,
                rewardCoconuts: 0
            )
        case .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            return dailyWish(for: .play)
        }
    }

    private static func failedInteraction(action: OasisCritterAction, wish: OasisCritterDailyWish) -> OasisCritterInteractionOutcome {
        OasisCritterInteractionOutcome(
            success: false,
            action: action,
            completedDailyWish: false,
            wish: wish,
            messageZh: "现在还不能这样互动。",
            messageEn: "This interaction is not available right now.",
            messageDe: "Diese Interaktion ist gerade nicht verfügbar.",
            rewardXP: 0,
            rewardBond: 0,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    private static func deadInteractionOutcome(for critter: OasisElectronicPet, action: OasisCritterAction) -> OasisCritterInteractionOutcome {
        let reason = critter.deathReasonRaw
        let reasonZh: String
        let reasonEn: String
        let reasonDe: String
        switch OasisCritterDeathReason(rawValue: reason) {
        case .hungry:
            reasonZh = "太久没有吃东西"
            reasonEn = "too long without food"
            reasonDe = "zu lange ohne Futter"
        case .sick:
            reasonZh = "久病没有恢复"
            reasonEn = "illness that was not healed"
            reasonDe = "Krankheit ohne Erholung"
        case .bored:
            reasonZh = "太久没有陪伴"
            reasonEn = "too long without company"
            reasonDe = "zu lange ohne Gesellschaft"
        case .oldAge:
            reasonZh = "自然老去"
            reasonEn = "old age"
            reasonDe = "Alter"
        case .none:
            reasonZh = "生命已经结束"
            reasonEn = "life has ended"
            reasonDe = "das Leben ist zu Ende"
        }
        return OasisCritterInteractionOutcome(
            success: false,
            action: action,
            completedDailyWish: false,
            wish: nil,
            messageZh: "它已经进入纪念册，原因是\(reasonZh)。",
            messageEn: "It is now in the memorial album because of \(reasonEn).",
            messageDe: "Es ist jetzt im Erinnerungsalbum wegen \(reasonDe).",
            rewardXP: 0,
            rewardBond: 0,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    private static func interactionOutcome(action: OasisCritterAction, wish: OasisCritterDailyWish, completedWish: Bool) -> OasisCritterInteractionOutcome {
        if completedWish {
            return OasisCritterInteractionOutcome(
                success: true,
                action: action,
                completedDailyWish: true,
                wish: wish,
                messageZh: "完成今日小愿望，它更信任你了。",
                messageEn: "Tiny wish complete. It trusts you a little more.",
                messageDe: "Kleiner Wunsch erfüllt. Es vertraut dir etwas mehr.",
                rewardXP: wish.rewardXP,
                rewardBond: wish.rewardBond,
                rewardFragments: wish.rewardFragments,
                rewardCoconuts: wish.rewardCoconuts
            )
        }

        let message: (zh: String, en: String, de: String)
        switch action {
        case .feed:
            message = ("它抱着小碗眯起眼，精神多了一点。", "It hugs the little bowl and perks up.", "Es umarmt die kleine Schale und wirkt munterer.")
        case .play:
            message = ("它追着小星星转了一圈，心情亮起来。", "It chases a tiny star and brightens up.", "Es jagt einen kleinen Stern und strahlt mehr.")
        case .rest:
            message = ("它缩进小窝，睡出一朵软软的梦。", "It curls into the nest and dreams softly.", "Es rollt sich im Nest ein und träumt sanft.")
        case .rescue:
            message = ("你轻轻照顾了一下，它从椰壳里探出头。", "You gave gentle care, and it peeks out.", "Du hast sanft geholfen, und es schaut heraus.")
        case .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
            message = ("互动完成。", "Interaction complete.", "Interaktion abgeschlossen.")
        }
        return OasisCritterInteractionOutcome(
            success: true,
            action: action,
            completedDailyWish: false,
            wish: wish,
            messageZh: message.zh,
            messageEn: message.en,
            messageDe: message.de,
            rewardXP: 0,
            rewardBond: 0,
            rewardFragments: 0,
            rewardCoconuts: 0
        )
    }

    private static func openedResult(for coconut: OasisUpgradeCoconut, duplicate: Bool) -> OasisOpenedUpgradeReward {
        if duplicate, let critterId = coconut.guaranteedCritterId,
           let entry = OasisUpgradeRewardCatalog.critter(id: critterId) {
            return OasisOpenedUpgradeReward(
                level: coconut.level,
                kind: .fragments,
                critterCatalogId: nil,
                titleZh: "重复伙伴转为碎片",
                titleEn: "Duplicate Became Fragments",
                titleDe: "Duplikat wurde Fragmente",
                detailZh: "\(entry.nameZh) 已拥有，已转为碎片与纪念装饰。",
                detailEn: "\(entry.nameEn) is owned, so you received fragments and decor.",
                detailDe: "\(entry.nameDe) ist schon da, daher gab es Fragmente und Deko.",
                emoji: "✨",
                isMilestoneCritter: false
            )
        }

        let emoji: String
        switch coconut.rewardKind {
        case .electronicPet: emoji = OasisUpgradeRewardCatalog.critter(id: coconut.guaranteedCritterId ?? "")?.emoji ?? "✨"
        case .decoration: emoji = "🪴"
        case .fragments: emoji = "◇"
        case .storyStyle: emoji = "📖"
        case .treeEnergy: emoji = "⚡"
        case .temporaryEffect: emoji = "✦"
        case .coconuts: emoji = "🥥"
        }
        return OasisOpenedUpgradeReward(
            level: coconut.level,
            kind: coconut.rewardKind,
            critterCatalogId: coconut.rewardKind == .electronicPet ? coconut.guaranteedCritterId : nil,
            titleZh: coconut.titleZh,
            titleEn: coconut.titleEn,
            titleDe: coconut.titleDe,
            detailZh: coconut.descriptionZh,
            detailEn: coconut.descriptionEn,
            detailDe: coconut.descriptionDe,
            emoji: emoji,
            isMilestoneCritter: coconut.rewardKind == .electronicPet
        )
    }

    private static func actionLog(
        for critter: OasisElectronicPet,
        action: OasisCritterAction,
        coconutDelta: Int = 0,
        fragmentDelta: Int = 0,
        xpDelta: Int = 0
    ) -> OasisCritterActionLog {
        let note: (zh: String, en: String, de: String)
        switch action {
        case .feed:
            note = ("喂养伙伴", "Fed companion", "Begleiter gefüttert")
        case .play:
            note = ("陪伙伴玩耍", "Played with companion", "Mit Begleiter gespielt")
        case .rest:
            note = ("伙伴休息", "Companion rested", "Begleiter hat geruht")
        case .rescue:
            note = ("温柔救回伙伴", "Gently rescued companion", "Begleiter sanft gerettet")
        case .starUpgrade:
            note = ("伙伴升星", "Companion star upgrade", "Begleiter-Sternupgrade")
        case .unlock:
            note = ("伙伴解锁", "Companion unlocked", "Begleiter freigeschaltet")
        case .fragmentAwaken:
            note = ("碎片唤醒", "Fragment awakening", "Fragment-Weckung")
        case .feature:
            note = ("设为小窝展示", "Featured in nest", "Im Nest gezeigt")
        case .careEcho:
            note = ("照护共鸣", "Care echo", "Pflege-Echo")
        case .death:
            note = ("伙伴进入纪念册", "Companion entered the memorial album", "Begleiter kam ins Erinnerungsalbum")
        }
        return OasisCritterActionLog(
            critterId: critter.id,
            critterCatalogId: critter.catalogId,
            action: action,
            coconutDelta: coconutDelta,
            fragmentDelta: fragmentDelta,
            xpDelta: xpDelta,
            sourceLevel: critter.sourceLevel,
            noteZh: note.zh,
            noteEn: note.en,
            noteDe: note.de
        )
    }

    private static func deathLog(for critter: OasisElectronicPet, now: Date) -> OasisCritterActionLog {
        let reason = critter.deathReason
        let reasonZh: String
        let reasonEn: String
        let reasonDe: String
        switch reason {
        case .hungry:
            reasonZh = "太久没有吃东西"
            reasonEn = "too long without food"
            reasonDe = "zu lange ohne Futter"
        case .sick:
            reasonZh = "久病没有恢复"
            reasonEn = "illness that was not healed"
            reasonDe = "Krankheit ohne Erholung"
        case .bored:
            reasonZh = "太久没有陪伴"
            reasonEn = "too long without company"
            reasonDe = "zu lange ohne Gesellschaft"
        case .oldAge:
            reasonZh = "自然老去"
            reasonEn = "old age"
            reasonDe = "Alter"
        case .none:
            reasonZh = "生命结束"
            reasonEn = "life ended"
            reasonDe = "das Leben endete"
        }
        return OasisCritterActionLog(
            critterId: critter.id,
            critterCatalogId: critter.catalogId,
            action: .death,
            createdAt: now,
            sourceLevel: critter.sourceLevel,
            noteZh: "伙伴进入纪念册：\(reasonZh)",
            noteEn: "Companion entered the memorial album: \(reasonEn).",
            noteDe: "Begleiter kam ins Erinnerungsalbum: \(reasonDe)."
        )
    }
}

enum OasisCritterAction: String, CaseIterable, Identifiable {
    case feed
    case play
    case rest
    case rescue
    case starUpgrade
    case unlock
    case fragmentAwaken
    case feature
    case careEcho
    case death

    var id: String { rawValue }
}
