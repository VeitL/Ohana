//
//  IslandProsperityManager.swift
//  Ohana
//
//  岛屿繁荣度：根据全局记录总量计算等级，驱动背景/粒子视觉进化

import SwiftUI

enum IslandLevel: Int, CaseIterable {
    case seedling = 1  // 萌芽岛  0-49 条记录
    case blooming = 2  // 繁花岛  50-199 条记录
    case paradise = 3  // 极乐岛  200+ 条记录

    var displayName: String {
        switch self {
        case .seedling: return "萌芽岛"
        case .blooming: return "繁花岛"
        case .paradise: return "极乐岛"
        }
    }

    var emoji: String {
        switch self {
        case .seedling: return "🌱"
        case .blooming: return "🌺"
        case .paradise: return "✨"
        }
    }

    // 距离下一级还需要多少条记录（最高级返回 nil）
    var nextLevelThreshold: Int? {
        switch self {
        case .seedling: return 50
        case .blooming: return 200
        case .paradise: return nil
        }
    }

    // 背景渐变色（Dark Mode）
    var backgroundColors: [Color] {
        switch self {
        case .seedling:
            return [Color.goPrimaryLight, Color.goPrimary, Color.goPrimaryDark]
        case .blooming:
            return [Color(hex: "3B2FB5"), Color.goPrimary, Color(hex: "0D2A8A")]
        case .paradise:
            return [Color(hex: "4B1FA8"), Color(hex: "2C3AB8"), Color(hex: "081E6B")]
        }
    }

    // 背景渐变色（Light Mode）
    var backgroundColorsLight: [Color] {
        switch self {
        case .seedling:
            return [Color(hex: "E8F0FE"), Color(hex: "D2E3FC"), Color(hex: "AECBFA")]
        case .blooming:
            return [Color(hex: "E0F7FA"), Color(hex: "B2EBF2"), Color(hex: "80DEEA")]
        case .paradise:
            return [Color(hex: "F3E8FF"), Color(hex: "E9D5FF"), Color(hex: "D8B4FE")]
        }
    }

    // 极光叠加层是否显示
    var showAurora: Bool { self == .paradise }

    // 繁花层是否显示（level 2+）
    var showBlossoms: Bool { self.rawValue >= 2 }
}

struct IslandProsperityManager {
    /// 根据 SwiftData 中所有记录的总条数计算当前等级
    static func level(pets: [Pet]) -> IslandLevel {
        let total = totalLogCount(pets: pets)
        switch total {
        case ..<50:   return .seedling
        case 50..<200: return .blooming
        default:       return .paradise
        }
    }

    static func totalLogCount(pets: [Pet]) -> Int {
        pets.reduce(0) { acc, pet in
            acc
            + pet.walkLogs.count
            + pet.pottyLogs.count
            + pet.hygieneLogs.count
            + pet.healthLogs.count
            + pet.weightLogs.count
            + pet.foodRecords.count
            + pet.milestones.count
        }
    }

    /// 当前等级进度（0~1），用于进度条展示
    static func progress(pets: [Pet]) -> Double {
        let total = totalLogCount(pets: pets)
        let lv = level(pets: pets)
        switch lv {
        case .seedling:  return min(Double(total) / 50.0, 1.0)
        case .blooming:  return min(Double(total - 50) / 150.0, 1.0)
        case .paradise:  return 1.0
        }
    }
}
