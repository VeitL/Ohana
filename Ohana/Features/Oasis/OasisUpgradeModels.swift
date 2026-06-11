//
//  OasisUpgradeModels.swift
//  Ohana
//
//  SwiftData persistence models for the Life Tree upgrade reward layer:
//  upgrade coconuts, electronic pets (critters), fragment balances, action
//  logs, and unlocks. Extracted from OasisUpgradeRewards.swift to separate the
//  persistence layer from catalog data and service logic. These types remain in
//  the same target, so the SwiftData schema (which references the types, not
//  their file) is unaffected.
//

import Foundation
import SwiftData

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

    nonisolated var lifeState: OasisCritterLifeState {
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

    nonisolated func displayName(_ l: L10n) -> String {
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
