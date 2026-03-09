//
//  OasisTreeManager.swift
//  Ohana
//
//  生命之树状态引擎：繁荣度 + 树等级（10级）+ 注入能量 + 升级奖励
//

import SwiftUI
import SwiftData
import Observation

// MARK: - Tree Level（10 级系统）

/// 椰子树等级，rawValue 对应 1-10 级（显示级别）
enum TreeLevel: Int, CaseIterable, Comparable {
    static func < (lhs: TreeLevel, rhs: TreeLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    case lv1  = 1   // 希望之种   0–49
    case lv2  = 2   // 破土嫩芽  50–149
    case lv3  = 3   // 茁壮成长 150–299
    case lv4  = 4   // 初现树形 300–499
    case lv5  = 5   // 椰影婆娑 500–799
    case lv6  = 6   // 果实初挂 800–1199
    case lv7  = 7   // 硕果累累1200–1799
    case lv8  = 8   // 参天古木1800–2599
    case lv9  = 9   // 灵树觉醒2600–3599
    case lv10 = 10  // 生命之树3600+

    var displayName: String {
        switch self {
        case .lv1:  return "希望之种"
        case .lv2:  return "破土嫩芽"
        case .lv3:  return "茁壮成长"
        case .lv4:  return "初现树形"
        case .lv5:  return "椰影婆娑"
        case .lv6:  return "果实初挂"
        case .lv7:  return "硕果累累"
        case .lv8:  return "参天古木"
        case .lv9:  return "灵树觉醒"
        case .lv10: return "生命之树"
        }
    }

    /// 升级奖励椰子数（升到该级时获得）
    var levelUpReward: Int {
        switch self {
        case .lv1:  return 0
        case .lv2:  return 5
        case .lv3:  return 10
        case .lv4:  return 15
        case .lv5:  return 25
        case .lv6:  return 35
        case .lv7:  return 50
        case .lv8:  return 75
        case .lv9:  return 100
        case .lv10: return 200
        }
    }

    var glowColor: Color {
        switch self {
        case .lv1, .lv2:         return Color.goYellow
        case .lv3, .lv4:         return Color(hex: "A3E635")
        case .lv5, .lv6:         return Color.goLime
        case .lv7, .lv8:         return Color.goTeal
        case .lv9:               return Color.goPrimary
        case .lv10:              return Color(hex: "00FFD1")
        }
    }

    var glowRadius: CGFloat {
        CGFloat(10 + rawValue * 6)
    }

    /// 0.0 ~ 1.0，用于树的视觉生长进度
    var growthProgress: Double {
        Double(rawValue - 1) / 9.0
    }
}

// MARK: - 能量阈值表
private let energyThresholds: [Int] = [0, 50, 150, 300, 500, 800, 1200, 1800, 2600, 3600, Int.max]

// MARK: - OasisTreeManager

@Observable
final class OasisTreeManager {
    static let shared = OasisTreeManager()

    // 基础繁荣度（来自数据库活动）
    var islandEnergy: Int = 0
    // 额外注入经验（消耗椰子所得）
    var injectedEnergy: Int = 0 {
        didSet { UserDefaults.standard.set(injectedEnergy, forKey: "oasis_injectedEnergy") }
    }

    var totalEnergy: Int { islandEnergy + injectedEnergy }

    var treeLevel: TreeLevel {
        for lv in TreeLevel.allCases.reversed() {
            if totalEnergy >= energyThresholds[lv.rawValue - 1] { return lv }
        }
        return .lv1
    }

    /// 当前级别起始能量
    private var currentLevelStart: Int { energyThresholds[treeLevel.rawValue - 1] }
    /// 下一级所需总能量（满级时返回当前阈值）
    var nextLevelThreshold: Int { energyThresholds[min(treeLevel.rawValue, 9)] }

    var progressToNextLevel: Double {
        guard treeLevel < .lv10 else { return 1.0 }
        let span = nextLevelThreshold - currentLevelStart
        guard span > 0 else { return 1.0 }
        return min(1.0, Double(totalEnergy - currentLevelStart) / Double(span))
    }

    // MARK: - 升级追踪（防止重复奖励）
    private var lastRewardedLevel: Int {
        get { UserDefaults.standard.integer(forKey: "oasis_lastRewardedLevel") }
        set { UserDefaults.standard.set(newValue, forKey: "oasis_lastRewardedLevel") }
    }

    /// 检查是否刚升级并发放奖励，返回新等级（有升级）或 nil
    @discardableResult
    func checkAndRewardLevelUp() -> TreeLevel? {
        let current = treeLevel.rawValue
        guard current > lastRewardedLevel else { return nil }
        let reward = treeLevel.levelUpReward
        lastRewardedLevel = current
        if reward > 0 {
            QuestManager.shared.addCoconuts(reward, emoji: "🌴", title: "升级奖励：\(treeLevel.displayName) Lv.\(current)")
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        return treeLevel
    }

    // MARK: - Passive Income（被动收益，Lv5 及以上）
    static let passiveIncomeKey = "lastTreeHarvestDate"

    var passiveIncomeAmount: Int {
        switch treeLevel {
        case .lv5, .lv6:   return 3
        case .lv7, .lv8:   return 5
        case .lv9:          return 8
        case .lv10:         return 15
        default:            return 0
        }
    }

    var canHarvestToday: Bool {
        guard treeLevel >= .lv5 else { return false }
        guard let last = UserDefaults.standard.object(forKey: Self.passiveIncomeKey) as? Date else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    @discardableResult
    func harvestDailyPassiveIncome() -> Bool {
        guard canHarvestToday else { return false }
        UserDefaults.standard.set(Date(), forKey: Self.passiveIncomeKey)
        QuestManager.shared.addCoconuts(passiveIncomeAmount, emoji: "🌳", title: "生命之树的馈赠 +\(passiveIncomeAmount)🥥")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    private init() {
        injectedEnergy = UserDefaults.standard.integer(forKey: "oasis_injectedEnergy")
        if lastRewardedLevel == 0 { lastRewardedLevel = 1 }
    }

    // MARK: - Load Energy from ModelContext

    func refreshEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human]) {
        var total = 0
        for pet in pets {
            total += pet.careLogs.count
            total += pet.walkLogs.count
            total += pet.hygieneLogs.count
            total += pet.pottyLogs.count
        }
        for human in humans {
            total += human.workoutLogs.count
        }
        islandEnergy = total
        checkAndRewardLevelUp()
    }

    // MARK: - Inject Energy（消耗椰子，增加树经验）

    @discardableResult
    func injectEnergy(cost: Int = 10) -> Bool {
        guard QuestManager.shared.coconutCount >= cost else { return false }
        QuestManager.shared.addCoconuts(-cost, emoji: "✨", title: "注入生命之树能量")
        injectedEnergy += cost
        
        // 检查是否升级，只有升级时才奖励椰子
        if let newLevel = checkAndRewardLevelUp() {
            // 升级成功，已在 checkAndRewardLevelUp 中发放椰子奖励
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            // 普通注入，无奖励
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        return true
    }
}
