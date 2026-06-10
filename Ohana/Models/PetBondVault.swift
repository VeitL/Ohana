//
//  PetBondVault.swift
//  Ohana
//
//  Pet-only growth coconut unlocks. This is intentionally UserDefaults-backed
//  until the collection surface grows enough to justify a SwiftData model.
//

import Foundation
import SwiftUI

enum PetBondVaultItemKind: String, CaseIterable, Hashable {
    case cardBorder = "card_border"
    case nameplate = "nameplate"
    case storyStyle = "story_style"
    case oasisNest = "oasis_nest"
    case memorialFrame = "memorial_frame"
}

enum PetBondVaultPreviewKind: String, Hashable {
    case cardBorder
    case nameplate
    case storyStyleAnimation
    case oasisNest
    case memorialFrame
}

struct PetBondVaultItem: Identifiable, Hashable {
    let kind: PetBondVaultItemKind
    let title: AppLocalizedText
    let subtitle: AppLocalizedText
    let cost: Int
    let icon: String
    let tintHex: String

    var id: String { kind.rawValue }
    var previewKind: PetBondVaultPreviewKind {
        switch kind {
        case .cardBorder: return .cardBorder
        case .nameplate: return .nameplate
        case .storyStyle: return .storyStyleAnimation
        case .oasisNest: return .oasisNest
        case .memorialFrame: return .memorialFrame
        }
    }
}

enum PetBondVaultCatalog {
    static let items: [PetBondVaultItem] = [
        PetBondVaultItem(
            kind: .cardBorder,
            title: AppLocalizedText(zh: "宠物卡片边框", en: "Pet Card Border", de: "Kartenrahmen"),
            subtitle: AppLocalizedText(zh: "让首页卡片有专属成长光边", en: "Adds a bond glow to this pet card", de: "Gibt der Haustierkarte einen Bindungsrand"),
            cost: 80,
            icon: "sparkles",
            tintHex: "F59E0B"
        ),
        PetBondVaultItem(
            kind: .nameplate,
            title: AppLocalizedText(zh: "名字铭牌", en: "Nameplate", de: "Namensschild"),
            subtitle: AppLocalizedText(zh: "在卡片上显示专属羁绊铭牌", en: "Shows a tiny bond nameplate", de: "Zeigt ein kleines Bindungsschild"),
            cost: 120,
            icon: "tag.fill",
            tintHex: "8B5CF6"
        ),
        PetBondVaultItem(
            kind: .storyStyle,
            title: AppLocalizedText(zh: "相册故事样式", en: "Story Style", de: "Story-Stil"),
            subtitle: AppLocalizedText(zh: "给记录中心的回忆卡解锁故事感", en: "Unlocks a richer diary-card look", de: "Schaltet schönere Tagebuchkarten frei"),
            cost: 160,
            icon: "photo.on.rectangle.angled",
            tintHex: "EC4899"
        ),
        PetBondVaultItem(
            kind: .oasisNest,
            title: AppLocalizedText(zh: "Oasis 小窝装饰", en: "Oasis Nest Decor", de: "Oase-Nestdeko"),
            subtitle: AppLocalizedText(zh: "为小窝预留的宠物专属装饰", en: "Pet-only decor for the Oasis nest", de: "Haustierdeko für das Oase-Nest"),
            cost: 220,
            icon: "house.and.flag.fill",
            tintHex: "14B8A6"
        ),
        PetBondVaultItem(
            kind: .memorialFrame,
            title: AppLocalizedText(zh: "纪念相框", en: "Memorial Frame", de: "Erinnerungsrahmen"),
            subtitle: AppLocalizedText(zh: "保留给彩虹桥纪念模式的相框", en: "A quiet frame for memorial mode", de: "Ein ruhiger Rahmen für den Erinnerungsmodus"),
            cost: 260,
            icon: "rainbow",
            tintHex: "A78BFA"
        )
    ]
}

enum PetBondVaultStore {
    static let revisionKey = PetBondVaultPreferenceStore.revisionKey

    static func unlockedIDs(for petId: UUID) -> Set<String> {
        PetBondVaultPreferenceStore.unlockedIDs(for: petId)
    }

    static func isUnlocked(_ kind: PetBondVaultItemKind, for petId: UUID) -> Bool {
        unlockedIDs(for: petId).contains(kind.rawValue)
    }

    static func unlock(_ kind: PetBondVaultItemKind, for petId: UUID) {
        PetBondVaultPreferenceStore.unlock(kind, for: petId)
    }
}
