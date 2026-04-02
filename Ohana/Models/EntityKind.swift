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
        case .pet: return "🐾"
        case .human: return "👤"
        case .plant: return "🌱"
        }
    }

    var displayName: String {
        switch self {
        case .pet: return "宠物"
        case .human: return "家人"
        case .plant: return "植物"
        }
    }

    var displayNameEn: String {
        switch self {
        case .pet: return "Pet"
        case .human: return "Human"
        case .plant: return "Plant"
        }
    }
}
