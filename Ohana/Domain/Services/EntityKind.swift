//
//  EntityKind.swift
//  Ohana
//
//  统一实体类型枚举，替代散落的硬编码字符串 ("Pet" / "pet" / "Human" / "Plant")
//

import Foundation

enum EntityKind: String, Codable, CaseIterable, Identifiable {
    case pet = "Pet"
    case human = "Human"
    case plant = "Plant"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .pet: "🐾"
        case .human: "👤"
        case .plant: "🌱"
        }
    }

    var displayName: String {
        displayName(l: .current)
    }

    func displayName(l: L10n = .current) -> String {
        switch self {
        case .pet:
            l.tr(zh: "宠物", en: "Pet", de: "Haustier")
        case .human:
            l.tr(zh: "家人", en: "Human", de: "Mensch")
        case .plant:
            l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        }
    }

    var displayNameEn: String {
        switch self {
        case .pet: "Pet"
        case .human: "Human"
        case .plant: "Plant"
        }
    }
}
