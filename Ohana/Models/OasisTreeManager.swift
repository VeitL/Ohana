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
    static var maxSupportedLevel: Int { allCases.map(\.rawValue).max() ?? 10 }

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
        guard self != .lv1 else { return 0 }
        return OasisUpgradeRewardCatalog.rule(for: rawValue).coconutAmount
    }

    var glowColor: Color {
        switch self {
        case .lv1, .lv2:         return Color.goYellow
        case .lv3, .lv4:         return Color(hex: "A3E635")
        case .lv5, .lv6:         return Color(hex: "84CC16")
        case .lv7, .lv8:         return Color.goTeal
        case .lv9:               return Color.goOrange
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

struct OasisDailyTreeCoconutSnapshot: Equatable {
    let dayKey: String
    let coconutCount: Int
    let harvestedIndices: Set<Int>

    var isFullyHarvested: Bool {
        coconutCount > 0 && harvestedIndices.count >= coconutCount
    }
}

@Observable
final class OasisTreeManager {
    static let shared = OasisTreeManager()
    private static let dailyTreeCoconutDayKey = "oasis_dailyTreeCoconutDay"
    private static let dailyTreeCoconutCountKey = "oasis_dailyTreeCoconutCount"
    private static let dailyTreeCoconutHarvestedKey = "oasis_dailyTreeCoconutHarvestedIndices"
    private static let v2LegacyBaselineXPKey = "oasis_v2LegacyBaselineXP"
    private static let dailyInjectionDayKey = "oasis_v2DailyTreeInjectionDay"
    private static let weeklyInjectionWeekKey = "oasis_v2WeeklyTreeInjectionWeek"

    // 基础繁荣度（来自数据库活动）
    var islandEnergy: Int = 0
    // 额外注入经验（消耗椰子所得）
    var injectedEnergy: Int = 0 {
        didSet { UserDefaults.standard.set(injectedEnergy, forKey: "oasis_injectedEnergy") }
    }

    var totalEnergy: Int { islandEnergy + injectedEnergy }

    var treeLevel: TreeLevel {
        Self.treeLevel(forTotalEnergy: totalEnergy)
    }

    /// 当前级别起始能量
    private var currentLevelStart: Int { energyThresholds[treeLevel.rawValue - 1] }
    /// 下一级所需总能量（满级时返回当前阈值）
    var nextLevelThreshold: Int { energyThresholds[min(treeLevel.rawValue, 9)] }

    var progressToNextLevel: Double {
        Self.progressToNextLevel(forTotalEnergy: totalEnergy)
    }

    static func treeLevel(forTotalEnergy totalEnergy: Int) -> TreeLevel {
        for lv in TreeLevel.allCases.reversed() {
            if totalEnergy >= energyThresholds[lv.rawValue - 1] { return lv }
        }
        return .lv1
    }

    static func nextLevelThreshold(forTotalEnergy totalEnergy: Int) -> Int {
        let level = treeLevel(forTotalEnergy: totalEnergy)
        return energyThresholds[min(level.rawValue, 9)]
    }

    static func progressToNextLevel(forTotalEnergy totalEnergy: Int) -> Double {
        let level = treeLevel(forTotalEnergy: totalEnergy)
        guard level < .lv10 else { return 1.0 }
        let currentStart = energyThresholds[level.rawValue - 1]
        let nextThreshold = energyThresholds[min(level.rawValue, 9)]
        let span = nextThreshold - currentStart
        guard span > 0 else { return 1.0 }
        return min(1.0, Double(totalEnergy - currentStart) / Double(span))
    }

    // MARK: - 升级追踪（防止重复奖励）
    private var lastRewardedLevel: Int {
        get { UserDefaults.standard.integer(forKey: "oasis_lastRewardedLevel") }
        set { UserDefaults.standard.set(newValue, forKey: "oasis_lastRewardedLevel") }
    }

    /// 检查是否刚升级并生成待开启的升级椰子，返回新等级（有升级）或 nil
    @discardableResult
    @MainActor
    func checkAndRewardLevelUp(modelContext: ModelContext) -> TreeLevel? {
        let current = treeLevel.rawValue
        guard current > lastRewardedLevel else { return nil }
        let firstRewardLevel = max(2, lastRewardedLevel + 1)
        if firstRewardLevel <= current {
            do {
                try OasisUpgradeRewardService.ensureUpgradeCoconuts(
                    from: firstRewardLevel,
                    through: current,
                    context: modelContext
                )
            } catch {
                AppPerformanceMonitor.shared.record(
                    "oasis_upgrade_reward_failed",
                    valueMS: 0,
                    note: "\(firstRewardLevel)-\(current):\(error.localizedDescription)"
                )
                return nil
            }
        }
        lastRewardedLevel = current
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        return treeLevel
    }

    // MARK: - Passive Income（被动收益，Lv5 及以上）
    static let passiveIncomeKey = "lastTreeHarvestDate"

    var passiveIncomeAmount: Int {
        switch treeLevel {
        case .lv5:          return 3
        case .lv6:          return 4
        case .lv7:          return 6
        case .lv8:          return 8
        case .lv9:          return 10
        case .lv10:         return 15
        default:            return 0
        }
    }

    var canHarvestToday: Bool {
        guard treeLevel >= .lv5 else { return false }
        guard let last = UserDefaults.standard.object(forKey: Self.passiveIncomeKey) as? Date else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    func dailyTreeCoconutSnapshot(maxCoconutCount: Int, date: Date = Date()) -> OasisDailyTreeCoconutSnapshot {
        Self.dailyTreeCoconutSnapshot(maxCoconutCount: maxCoconutCount, date: date)
    }

    @discardableResult
    func markDailyTreeCoconutHarvested(
        _ index: Int,
        maxCoconutCount: Int,
        date: Date = Date()
    ) -> OasisDailyTreeCoconutSnapshot {
        var snapshot = dailyTreeCoconutSnapshot(maxCoconutCount: maxCoconutCount, date: date)
        guard index >= 0, index < snapshot.coconutCount else { return snapshot }
        var harvested = snapshot.harvestedIndices
        harvested.insert(index)
        Self.storeDailyTreeCoconutState(
            dayKey: snapshot.dayKey,
            coconutCount: snapshot.coconutCount,
            harvestedIndices: harvested
        )
        snapshot = OasisDailyTreeCoconutSnapshot(
            dayKey: snapshot.dayKey,
            coconutCount: snapshot.coconutCount,
            harvestedIndices: harvested
        )
        return snapshot
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

    private static func dailyTreeCoconutSnapshot(
        maxCoconutCount: Int,
        date: Date
    ) -> OasisDailyTreeCoconutSnapshot {
        let dayKey = localDayKey(for: date)
        let defaults = UserDefaults.standard
        let storedDay = defaults.string(forKey: dailyTreeCoconutDayKey)
        var storedCount = defaults.integer(forKey: dailyTreeCoconutCountKey)
        var harvested = Set((defaults.array(forKey: dailyTreeCoconutHarvestedKey) as? [Int]) ?? [])
        let maxCount = max(0, maxCoconutCount)

        guard maxCount > 0 else {
            if storedDay != dayKey || storedCount != 0 || !harvested.isEmpty {
                storeDailyTreeCoconutState(dayKey: dayKey, coconutCount: 0, harvestedIndices: [])
            }
            return OasisDailyTreeCoconutSnapshot(dayKey: dayKey, coconutCount: 0, harvestedIndices: [])
        }

        if storedDay != dayKey || storedCount <= 0 {
            storedCount = Int.random(in: 1...maxCount)
            harvested = []
            storeDailyTreeCoconutState(
                dayKey: dayKey,
                coconutCount: storedCount,
                harvestedIndices: harvested
            )
        } else if storedCount > maxCount || harvested.contains(where: { $0 >= storedCount }) {
            storedCount = min(storedCount, maxCount)
            harvested = harvested.filter { $0 >= 0 && $0 < storedCount }
            storeDailyTreeCoconutState(
                dayKey: dayKey,
                coconutCount: storedCount,
                harvestedIndices: harvested
            )
        }

        return OasisDailyTreeCoconutSnapshot(
            dayKey: dayKey,
            coconutCount: storedCount,
            harvestedIndices: harvested
        )
    }

    private static func storeDailyTreeCoconutState(
        dayKey: String,
        coconutCount: Int,
        harvestedIndices: Set<Int>
    ) {
        UserDefaults.standard.set(dayKey, forKey: dailyTreeCoconutDayKey)
        UserDefaults.standard.set(coconutCount, forKey: dailyTreeCoconutCountKey)
        UserDefaults.standard.set(harvestedIndices.sorted(), forKey: dailyTreeCoconutHarvestedKey)
    }

    private static func localDayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    // MARK: - Load Energy from ModelContext

    func refreshPreviewEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant] = []) {
        _ = plants
        islandEnergy = Self.calculatedIslandEnergy(
            modelContext: modelContext,
            pets: pets,
            humans: humans
        )
    }

    func refreshEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant] = []) {
        _ = plants
        islandEnergy = Self.calculatedIslandEnergy(
            modelContext: modelContext,
            pets: pets,
            humans: humans
        )
        checkAndRewardLevelUp(modelContext: modelContext)
    }

    @discardableResult
    @MainActor
    func refreshLedgerEnergy(modelContext: ModelContext) -> TreeLevel {
        islandEnergy = Self.calculatedLedgerEnergy(modelContext: modelContext)
        checkAndRewardLevelUp(modelContext: modelContext)
        return treeLevel
    }

    private static func calculatedIslandEnergy(
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human]
    ) -> Int {
        let ledgerEvents = (try? modelContext.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return calculatedIslandEnergy(
            ledgerEvents: ledgerEvents,
            modelContext: modelContext,
            pets: pets,
            humans: humans
        )
    }

    private static func calculatedLedgerEnergy(modelContext: ModelContext) -> Int {
        let ledgerEvents = (try? modelContext.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return calculatedIslandEnergy(
            ledgerEvents: ledgerEvents,
            modelContext: modelContext,
            pets: [],
            humans: []
        )
    }

    private static func calculatedIslandEnergy(
        ledgerEvents: [CareLedgerEvent],
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human]
    ) -> Int {
        let v2GrowthXP = ledgerEvents.reduce(0) { partial, event in
            partial + CoconutEconomyPolicyV2.metadataValue(named: "growthXP", in: event.metadataJSON)
        }
        return legacyCompatibilityXP(
            ledgerEvents: ledgerEvents,
            modelContext: modelContext,
            pets: pets,
            humans: humans
        ) + v2GrowthXP
    }

    // MARK: - Inject Energy（消耗椰子，增加树经验）

    @discardableResult
    @MainActor
    func injectEnergy(cost: Int = 80, modelContext: ModelContext) -> Bool {
        let package = Self.injectionPackage(forRequestedCost: cost, currentLevel: treeLevel)
        guard package.isAvailable else { return false }
        guard Self.canUseInjectionPackage(package) else { return false }
        guard OasisCritterEconomyService.spendCurrentHumanCoconuts(
            package.cost,
            emoji: "✨",
            title: package.title,
            context: modelContext
        ) else { return false }
        return applyEnergyPackage(package, recordsCost: true, modelContext: modelContext)
    }

    @discardableResult
    @MainActor
    func applyPurchasedEnergyBoost(cost: Int, modelContext: ModelContext) -> Bool {
        let package = Self.injectionPackage(forRequestedCost: cost, currentLevel: treeLevel)
        guard package.isAvailable else { return false }
        guard Self.canUseInjectionPackage(package) else { return false }
        return applyEnergyPackage(package, recordsCost: false, modelContext: modelContext)
    }

    @discardableResult
    @MainActor
    private func applyEnergyPackage(_ package: InjectionPackage, recordsCost: Bool, modelContext: ModelContext) -> Bool {
        injectedEnergy += package.xp
        Self.markInjectionPackageUsed(package)
        CareLedgerService.record(
            actorKind: .human,
            actorId: UserDefaults.standard.string(forKey: "currentActiveHumanId"),
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: package.actionType,
            note: package.title,
            source: .economy,
            coconutDelta: recordsCost ? -package.cost : 0,
            metadataJSON: "{\"economyVersion\":2,\"injectedXP\":\(package.xp),\"coconutCost\":\(package.cost),\"budgetMultiplier\":1.0,\"reason\":\"treeInjection\"}",
            context: modelContext,
            save: false
        )

        // 检查是否升级；升级奖励会以“升级椰子”形式等待用户敲开。
        if checkAndRewardLevelUp(modelContext: modelContext) != nil {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            // 普通注入，无奖励
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        modelContext.safeSave()
        return true
    }

    private static func legacyCompatibilityXP(
        ledgerEvents: [CareLedgerEvent],
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human]
    ) -> Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: v2LegacyBaselineXPKey) != nil {
            return defaults.integer(forKey: v2LegacyBaselineXPKey)
        }

        let legacyLedgerCount = ledgerEvents.filter {
            !$0.metadataJSON.contains("\"economyVersion\":2") &&
            [.care, .potty, .walk, .hygiene, .health, .weight, .medication, .workout, .plantCare, .milestone].contains($0.eventKindEnum)
        }.count
        let fallbackCount = legacyLedgerCount > 0
            ? legacyLedgerCount
            : legacyActivityCount(modelContext: modelContext, pets: pets, humans: humans)
        let baseline = min(1_200, fallbackCount * 4)
        defaults.set(baseline, forKey: v2LegacyBaselineXPKey)
        return baseline
    }

    private static func legacyActivityCount(
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human]
    ) -> Int {
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
        let plantEventCount = (try? modelContext.fetchCount(
            FetchDescriptor<Event>(predicate: #Predicate { $0.relatedEntityType == "Plant" })
        )) ?? 0
        return total + plantEventCount
    }

    private struct InjectionPackage {
        let cost: Int
        let xp: Int
        let actionType: String
        let title: String
        let limitKey: String
        let isAvailable: Bool
    }

    private static func injectionPackage(forRequestedCost cost: Int, currentLevel: TreeLevel) -> InjectionPackage {
        if cost >= 220 {
            return InjectionPackage(
                cost: 220,
                xp: 60,
                actionType: "weeklyTreeInjection",
                title: "生命之树周能量包 +60XP",
                limitKey: weeklyInjectionWeekKey,
                isAvailable: currentLevel >= .lv5
            )
        }
        return InjectionPackage(
            cost: 80,
            xp: 20,
            actionType: "dailyTreeInjection",
            title: "注入生命之树能量 +20XP",
            limitKey: dailyInjectionDayKey,
            isAvailable: true
        )
    }

    private static func canUseInjectionPackage(_ package: InjectionPackage, date: Date = Date()) -> Bool {
        let usedKey = UserDefaults.standard.string(forKey: package.limitKey)
        return usedKey != injectionPeriodKey(for: package, date: date)
    }

    private static func markInjectionPackageUsed(_ package: InjectionPackage, date: Date = Date()) {
        UserDefaults.standard.set(injectionPeriodKey(for: package, date: date), forKey: package.limitKey)
    }

    private static func injectionPeriodKey(for package: InjectionPackage, date: Date) -> String {
        if package.limitKey == weeklyInjectionWeekKey {
            let components = Calendar(identifier: .gregorian).dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
        }
        return EconomyDailyBudgetStore.dayKey(for: date)
    }
}
