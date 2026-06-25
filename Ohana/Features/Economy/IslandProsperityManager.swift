//
//  IslandProsperityManager.swift
//  Ohana
//
//  岛屿繁荣度：根据全局记录总量计算等级，驱动背景/粒子视觉进化

import SwiftUI

enum IslandLevel: Int, CaseIterable {
    case seedling = 1 // 萌芽岛  0-49 条记录
    case blooming = 2 // 繁花岛  50-199 条记录
    case paradise = 3 // 极乐岛  200+ 条记录

    var displayName: String {
        switch self {
        case .seedling: "萌芽岛"
        case .blooming: "繁花岛"
        case .paradise: "极乐岛"
        }
    }

    var emoji: String {
        switch self {
        case .seedling: "🌱"
        case .blooming: "🌺"
        case .paradise: "✨"
        }
    }

    // 距离下一级还需要多少条记录（最高级返回 nil）
    var nextLevelThreshold: Int? {
        switch self {
        case .seedling: 50
        case .blooming: 200
        case .paradise: nil
        }
    }

    // 背景渐变色（Dark Mode）
    var backgroundColors: [Color] {
        switch self {
        case .seedling:
            [Color.goPrimaryLight, Color.goPrimary, Color.goPrimaryDark]
        case .blooming:
            [Color(hex: "3B2FB5"), Color.goPrimary, Color(hex: "0D2A8A")]
        case .paradise:
            [Color(hex: "4B1FA8"), Color(hex: "2C3AB8"), Color(hex: "081E6B")]
        }
    }

    // 背景渐变色（Light Mode）
    var backgroundColorsLight: [Color] {
        switch self {
        case .seedling:
            [Color(hex: "E8F0FE"), Color(hex: "D2E3FC"), Color(hex: "AECBFA")]
        case .blooming:
            [Color(hex: "E0F7FA"), Color(hex: "B2EBF2"), Color(hex: "80DEEA")]
        case .paradise:
            [Color(hex: "F3E8FF"), Color(hex: "E9D5FF"), Color(hex: "D8B4FE")]
        }
    }

    // 极光叠加层是否显示
    var showAurora: Bool { self == .paradise }

    // 繁花层是否显示（level 2+）
    var showBlossoms: Bool { self.rawValue >= 2 }
}

enum IslandProsperityManager {
    /// 根据已投影的记录总条数计算当前等级。
    static func level(totalLogCount total: Int) -> IslandLevel {
        switch total {
        case ..<50: .seedling
        case 50 ..< 200: .blooming
        default: .paradise
        }
    }

    static func level(events: [CareLedgerEvent], petIDs: Set<String>? = nil) -> IslandLevel {
        level(totalLogCount: totalLogCount(events: events, petIDs: petIDs))
    }

    static func totalLogCount(events: [CareLedgerEvent], petIDs: Set<String>? = nil) -> Int {
        events.count { event in
            guard event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  petIDs.map({ ids in event.subjectId.map { ids.contains($0) } == true }) ?? true
            else {
                return false
            }
            switch event.eventKindEnum {
            case .care, .potty, .walk, .hygiene, .health, .weight, .expense, .medication:
                return true
            case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
                return false
            }
        }
    }

    /// 当前等级进度（0~1），用于进度条展示
    static func progress(totalLogCount total: Int) -> Double {
        let lv = level(totalLogCount: total)
        switch lv {
        case .seedling: return min(Double(total) / 50.0, 1.0)
        case .blooming: return min(Double(total - 50) / 150.0, 1.0)
        case .paradise: return 1.0
        }
    }

    static func progress(events: [CareLedgerEvent], petIDs: Set<String>? = nil) -> Double {
        progress(totalLogCount: totalLogCount(events: events, petIDs: petIDs))
    }
}
