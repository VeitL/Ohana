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
        switch self {
        case .pet: "宠物"
        case .human: "家人"
        case .plant: "植物"
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
