//
//  OasisUpgradeRewardCatalog.swift
//  Ohana
//
//  Static Oasis upgrade reward and critter catalog.
//

import Foundation

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
            sourceLevel: 10,
            assetName: "CritterLumo",
            unlockHintZh: "生命树 Lv.10 保底",
            unlockHintEn: "Guaranteed at Tree Lv.10",
            unlockHintDe: "Garantiert bei Baum Lv.10",
            personalityRaw: "mischievous",
            preferredItemId: "coconut_milk",
            nameZh: "Lumo",
            nameEn: "Lumo",
            nameDe: "Lumo",
            taglineZh: "会从小毛团进化成云尾守护者的俏皮伙伴",
            taglineEn: "A playful little fluff that evolves into a cloud-tailed guardian.",
            taglineDe: "Ein verspielter kleiner Flausch, der zum Wolkenschweif-Hüter wird."
        ),
        .init(
            id: legendaryCritterId,
            emoji: "✨",
            rarity: .legendary,
            sourceLevel: 10,
            assetName: "CritterAuroraLuma",
            unlockHintZh: "生命树 Lv.10 后碎片唤醒",
            unlockHintEn: "Awaken with fragments after Tree Lv.10",
            unlockHintDe: "Ab Baum Lv.10 mit Fragmenten erwecken",
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
            sourceLevel: 10,
            assetName: "CritterMossBun",
            unlockHintZh: "生命树 Lv.10 后碎片唤醒",
            unlockHintEn: "Awaken with fragments after Tree Lv.10",
            unlockHintDe: "Ab Baum Lv.10 mit Fragmenten erwecken",
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
            sourceLevel: 10,
            assetName: "CritterPebblePop",
            unlockHintZh: "生命树 Lv.10 后碎片唤醒",
            unlockHintEn: "Awaken with fragments after Tree Lv.10",
            unlockHintDe: "Ab Baum Lv.10 mit Fragmenten erwecken",
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
            sourceLevel: 10,
            assetName: "CritterEmberPip",
            unlockHintZh: "生命树 Lv.10 后碎片唤醒",
            unlockHintEn: "Awaken with fragments after Tree Lv.10",
            unlockHintDe: "Ab Baum Lv.10 mit Fragmenten erwecken",
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
            sourceLevel: 10,
            assetName: "CritterMoonJelly",
            unlockHintZh: "生命树 Lv.10 后碎片唤醒",
            unlockHintEn: "Awaken with fragments after Tree Lv.10",
            unlockHintDe: "Ab Baum Lv.10 mit Fragmenten erwecken",
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
        if level % 10 == 0,
           let entry = critters.first(where: { $0.sourceLevel == level }) {
            return .init(
                level: level,
                rewardKind: .electronicPet,
                rewardCatalogId: "level_\(level)_critter_\(entry.id)",
                guaranteedCritterId: entry.id,
                coconutAmount: max(50, level * 5),
                treeEnergyAmount: 0,
                fragmentAmount: max(60, level * 6),
                decorUnlockId: entry.id == firstCritterId ? "oasis_first_nest" : nil,
                storyStyleUnlockId: nil,
                temporaryEffectId: nil,
                titleZh: level == 10 ? "第一只电子宠物" : "新的电子宠物",
                titleEn: level == 10 ? "First Critter" : "New Critter",
                titleDe: level == 10 ? "Erstes Critter" : "Neues Critter",
                descriptionZh: "保底唤醒伙伴 \(entry.nameZh)。",
                descriptionEn: "Guaranteed companion: \(entry.nameEn).",
                descriptionDe: "Garantierter Begleiter: \(entry.nameDe)."
            )
        }
        switch level {
        case 3, 6, 9:
            let amount = level == 3 ? 12 : (level == 6 ? 24 : 48)
            return .init(
                level: level,
                rewardKind: .fragments,
                rewardCatalogId: "level_\(level)_critter_fragments",
                guaranteedCritterId: fragmentTargetCritterId(for: level),
                coconutAmount: level == 3 ? 22 : level * 6,
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
        if let next = critters
            .sorted(by: { $0.sourceLevel < $1.sourceLevel })
            .first(where: { level <= $0.sourceLevel }) {
            return next.id
        }
        switch level % 5 {
        case 0: return firstCritterId
        case 1: return emberPipId
        case 2: return pebblePopId
        case 3: return mossBunId
        default: return moonJellyId
        }
    }
}
