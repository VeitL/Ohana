//
//  OasisTreeManager.swift
//  Ohana
//
//  生命之树状态引擎：繁荣度 + 树等级（10级）+ 注入能量 + 升级奖励
//

import Observation
import SwiftData
import SwiftUI

// MARK: - Tree Level（Lv0 + 10 级系统）

nonisolated enum OasisTreeEnergyInjectionPolicy {
    static let starterPackageCost = 10
    static let starterPackageXP = 10
    static let largePackageCost = 220
    static let largePackageXP = 60
}

/// 椰子树等级，rawValue 对应显示级别；首装无能量时保持 Lv0。
enum TreeLevel: Int, CaseIterable, Comparable {
    static func < (lhs: TreeLevel, rhs: TreeLevel) -> Bool { lhs.rawValue < rhs.rawValue }
    static var maxSupportedLevel: Int { allCases.map(\.rawValue).max() ?? 10 }

    case lv0 = 0 // 未唤醒种子 0–49
    case lv1 = 1 // 希望之种   50–149
    case lv2 = 2 // 破土嫩芽  150–299
    case lv3 = 3 // 茁壮成长 300–499
    case lv4 = 4 // 初现树形 500–799
    case lv5 = 5 // 椰影婆娑 800–1199
    case lv6 = 6 // 果实初挂 1200–1799
    case lv7 = 7 // 硕果累累1800–2599
    case lv8 = 8 // 参天古木2600–3199
    case lv9 = 9 // 灵树觉醒3200–3599
    case lv10 = 10 // 生命之树3600+

    var displayName: String {
        switch self {
        case .lv0: "未唤醒种子"
        case .lv1: "希望之种"
        case .lv2: "破土嫩芽"
        case .lv3: "茁壮成长"
        case .lv4: "初现树形"
        case .lv5: "椰影婆娑"
        case .lv6: "果实初挂"
        case .lv7: "硕果累累"
        case .lv8: "参天古木"
        case .lv9: "灵树觉醒"
        case .lv10: "生命之树"
        }
    }

    /// 升级奖励椰子数（升到该级时获得）
    var levelUpReward: Int {
        guard rawValue >= 2 else { return 0 }
        return OasisUpgradeRewardCatalog.rule(for: rawValue).coconutAmount
    }

    var glowColor: Color {
        switch self {
        case .lv0: Color.ohanaSecondaryText
        case .lv1, .lv2: Color.goYellow
        case .lv3, .lv4: Color(hex: "A3E635")
        case .lv5, .lv6: Color(hex: "84CC16")
        case .lv7, .lv8: Color.goTeal
        case .lv9: Color.goOrange
        case .lv10: Color(hex: "00FFD1")
        }
    }

    var glowRadius: CGFloat {
        CGFloat(10 + rawValue * 6)
    }

    /// 0.0 ~ 1.0，用于树的视觉生长进度
    var growthProgress: Double {
        Double(rawValue) / 10.0
    }
}

// MARK: - 能量阈值表
private nonisolated let energyThresholds: [Int] = [0, 50, 150, 300, 500, 800, 1200, 1800, 2600, 3200, 3600]
private let legacyEnergyThresholds: [Int] = [0, 0, 50, 150, 300, 500, 800, 1200, 1800, 2600, 3600]

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
    // 树的等级 = 照护养分 + 注入养分。照护是主升级路径(自然养大一棵树),
    // 注入(消耗椰子)是可选加速器。照护养分的每日增量已由预算递减防刷。
    private(set) var islandEnergy: Int = 0
    // 照护养分累计能量(照护打卡自然获得,迁移基线之后的新增计入)
    private(set) var careGrowthEnergy: Int = 0 {
        didSet { OasisTreePreferenceStore.careGrowthEnergy = careGrowthEnergy }
    }
    // 额外注入经验（消耗椰子所得）
    private(set) var injectedEnergy: Int = 0 {
        didSet {
            guard persistsInjectedEnergyChanges else { return }
            OasisTreePreferenceStore.injectedEnergy = injectedEnergy
        }
    }
    private var persistsInjectedEnergyChanges = true

    var totalEnergy: Int { careGrowthEnergy + injectedEnergy }
    private let questManager: QuestManager
    private let careLedger: CareLedgerRecording
    private let oasisRewards: OasisRewardManaging

    var treeLevel: TreeLevel {
        Self.treeLevel(forTotalEnergy: totalEnergy)
    }

    /// 当前级别起始能量
    private var currentLevelStart: Int { Self.levelStartThreshold(for: treeLevel) }
    /// 下一级所需总能量（满级时返回当前阈值）
    var nextLevelThreshold: Int { Self.nextThreshold(after: treeLevel) }

    var progressToNextLevel: Double {
        Self.progressToNextLevel(forTotalEnergy: totalEnergy)
    }

    nonisolated static func levelRawValue(forTotalEnergy totalEnergy: Int) -> Int {
        let safeEnergy = max(0, totalEnergy)
        for rawLevel in energyThresholds.indices.reversed() where safeEnergy >= energyThresholds[rawLevel] {
            return rawLevel
        }
        return 0
    }

    static func treeLevel(forTotalEnergy totalEnergy: Int) -> TreeLevel {
        let safeEnergy = max(0, totalEnergy)
        for lv in TreeLevel.allCases.reversed() {
            if safeEnergy >= levelStartThreshold(for: lv) { return lv }
        }
        return .lv0
    }

    static func legacyCompatibleXP(forLegacyTreeEnergy legacyEnergy: Int) -> Int {
        let safeEnergy = max(0, legacyEnergy)
        guard safeEnergy > 0 else { return 0 }
        let oldLevelRaw = (1 ... TreeLevel.lv10.rawValue)
            .reversed()
            .first { safeEnergy >= legacyEnergyThresholds[$0] } ?? TreeLevel.lv1.rawValue
        let oldStart = legacyEnergyThresholds[oldLevelRaw]
        let oldNext = legacyEnergyThresholds[min(oldLevelRaw + 1, TreeLevel.lv10.rawValue)]
        let newStart = energyThresholds[oldLevelRaw]
        let newNext = energyThresholds[min(oldLevelRaw + 1, TreeLevel.lv10.rawValue)]
        guard oldNext > oldStart, newNext > newStart else {
            return max(safeEnergy, newStart)
        }
        let progress = Double(safeEnergy - oldStart) / Double(oldNext - oldStart)
        return newStart + Int((Double(newNext - newStart) * progress).rounded(.down))
    }

    static func nextLevelThreshold(forTotalEnergy totalEnergy: Int) -> Int {
        let level = treeLevel(forTotalEnergy: totalEnergy)
        return nextThreshold(after: level)
    }

    static func progressToNextLevel(forTotalEnergy totalEnergy: Int) -> Double {
        let level = treeLevel(forTotalEnergy: totalEnergy)
        guard level < .lv10 else { return 1.0 }
        let currentStart = levelStartThreshold(for: level)
        let nextThreshold = nextThreshold(after: level)
        let span = nextThreshold - currentStart
        guard span > 0 else { return 1.0 }
        return min(1.0, Double(max(0, totalEnergy) - currentStart) / Double(span))
    }

    nonisolated static func levelStartThreshold(forRawLevel rawLevel: Int) -> Int {
        energyThresholds[min(max(rawLevel, 0), energyThresholds.count - 1)]
    }

    private static func levelStartThreshold(for level: TreeLevel) -> Int {
        energyThresholds[min(max(level.rawValue, 0), TreeLevel.lv10.rawValue)]
    }

    private static func nextThreshold(after level: TreeLevel) -> Int {
        guard level < .lv10 else { return levelStartThreshold(for: .lv10) }
        return energyThresholds[min(level.rawValue + 1, TreeLevel.lv10.rawValue)]
    }

    // MARK: - 升级追踪（防止重复奖励）
    private var lastRewardedLevel: Int {
        get { OasisTreePreferenceStore.lastRewardedLevel }
        set { OasisTreePreferenceStore.lastRewardedLevel = newValue }
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
                try oasisRewards.ensureUpgradeCoconuts(
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
    static let passiveIncomeKey = OasisTreePreferenceStore.passiveIncomeKey

    var passiveIncomeAmount: Int {
        switch treeLevel {
        case .lv5: 3
        case .lv6: 4
        case .lv7: 6
        case .lv8: 8
        case .lv9: 10
        case .lv10: 15
        default: 0
        }
    }

    var canHarvestToday: Bool {
        guard treeLevel >= .lv5 else { return false }
        guard let last = OasisTreePreferenceStore.lastPassiveIncomeDate() else { return true }
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
    @MainActor
    func harvestDailyPassiveIncome(
        modelContext: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) -> Bool {
        guard canHarvestToday else { return false }
        let wallet = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        let harvestDate = Date()
        guard OasisCritterEconomyService.awardBudgetedCurrentHumanCoconuts(
            passiveIncomeAmount,
            emoji: "🌳",
            title: DomainCareRewardGeneralTitle.counted(DomainCareRewardGeneralTitle.oasisTreeGift, count: passiveIncomeAmount),
            context: modelContext,
            postsRewardFeedback: true,
            activeHumanSelection: activeHumanSelection,
            wallet: wallet,
            questManager: questManager,
            date: harvestDate
        ) != nil else {
            modelContext.rollback()
            wallet.refreshQuestProjection(context: modelContext, manager: questManager)
            return false
        }
        markDailyPassiveIncomeHarvested(date: harvestDate)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    @available(*, unavailable, message: "Use harvestDailyPassiveIncome(modelContext:) so rewards write to the wallet account in the caller transaction.")
    func harvestDailyPassiveIncome() -> Bool {
        false
    }

    func markDailyPassiveIncomeHarvested(date: Date) {
        OasisTreePreferenceStore.markPassiveIncomeHarvested(date)
    }

    init(
        questManager: QuestManager = QuestManager(),
        careLedger: CareLedgerRecording = CareLedgerService(),
        oasisRewards providedOasisRewards: OasisRewardManaging? = nil
    ) {
        self.questManager = questManager
        self.careLedger = careLedger
        self.oasisRewards = providedOasisRewards ?? StaticOasisRewardManager(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        )
        injectedEnergy = OasisTreePreferenceStore.injectedEnergy
        careGrowthEnergy = OasisTreePreferenceStore.careGrowthEnergy
    }

    private static func dailyTreeCoconutSnapshot(
        maxCoconutCount: Int,
        date: Date
    ) -> OasisDailyTreeCoconutSnapshot {
        let dayKey = localDayKey(for: date)
        let storedState = OasisTreePreferenceStore.dailyTreeCoconutState()
        let storedDay = storedState.dayKey
        var storedCount = storedState.coconutCount
        var harvested = storedState.harvestedIndices
        let maxCount = max(0, maxCoconutCount)

        guard maxCount > 0 else {
            if storedDay != dayKey || storedCount != 0 || !harvested.isEmpty {
                storeDailyTreeCoconutState(dayKey: dayKey, coconutCount: 0, harvestedIndices: [])
            }
            return OasisDailyTreeCoconutSnapshot(dayKey: dayKey, coconutCount: 0, harvestedIndices: [])
        }

        if storedDay != dayKey || storedCount <= 0 {
            storedCount = Int.random(in: 1 ... maxCount)
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
        OasisTreePreferenceStore.storeDailyTreeCoconutState(
            dayKey: dayKey,
            coconutCount: coconutCount,
            harvestedIndices: harvestedIndices
        )
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
        let snapshot = Self.ledgerEnergySnapshot(
            modelContext: modelContext,
            pets: pets,
            humans: humans
        )
        islandEnergy = 0
        refreshInjectedEnergy(ledgerInjectedXP: snapshot.injectedXP)
        refreshCareGrowthEnergy(ledgerGrowthXP: snapshot.growthXP, legacyXP: snapshot.legacyXP)
    }

    func refreshEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant] = []) {
        _ = plants
        let snapshot = Self.ledgerEnergySnapshot(
            modelContext: modelContext,
            pets: pets,
            humans: humans
        )
        islandEnergy = 0
        refreshInjectedEnergy(ledgerInjectedXP: snapshot.injectedXP)
        refreshCareGrowthEnergy(ledgerGrowthXP: snapshot.growthXP, legacyXP: snapshot.legacyXP)
        checkAndRewardLevelUp(modelContext: modelContext)
    }

    @discardableResult
    @MainActor
    func refreshLedgerEnergy(modelContext: ModelContext) -> TreeLevel {
        let snapshot = Self.ledgerEnergySnapshot(
            modelContext: modelContext,
            pets: [],
            humans: []
        )
        islandEnergy = 0
        refreshInjectedEnergy(ledgerInjectedXP: snapshot.injectedXP)
        refreshCareGrowthEnergy(ledgerGrowthXP: snapshot.growthXP, legacyXP: snapshot.legacyXP)
        checkAndRewardLevelUp(modelContext: modelContext)
        return treeLevel
    }

    private struct LedgerEventCursor: Equatable {
        let eventId: String
        let occurredAt: Date
    }

    private struct LedgerEnergySnapshot {
        let growthXP: Int
        let injectedXP: Int
        let legacyXP: Int
    }

    private static func ledgerEnergySnapshot(
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human]
    ) -> LedgerEnergySnapshot {
        let eventCount = ledgerEventCount(modelContext: modelContext)
        guard eventCount > 0 else {
            return rebuildLedgerEnergySnapshot(modelContext: modelContext, pets: pets, humans: humans, latestCursor: nil)
        }
        let latestCursor = latestLedgerCursor(modelContext: modelContext)
        if let cached = cachedLedgerEnergySnapshot(
            modelContext: modelContext,
            eventCount: eventCount,
            latestCursor: latestCursor
        ) {
            return cached
        }
        return rebuildLedgerEnergySnapshot(modelContext: modelContext, pets: pets, humans: humans, latestCursor: latestCursor)
    }

    private static func cachedLedgerEnergySnapshot(
        modelContext: ModelContext,
        eventCount: Int,
        latestCursor: LedgerEventCursor?
    ) -> LedgerEnergySnapshot? {
        guard let cache = OasisTreePreferenceStore.ledgerEnergyCache(),
              let legacyXP = OasisTreePreferenceStore.legacyBaselineXP(),
              cache.processedEventCount >= 0 else {
            return nil
        }
        if cache.processedEventCount == eventCount {
            guard cacheMatchesLatestCursor(cache, latestCursor: latestCursor) else { return nil }
            return LedgerEnergySnapshot(growthXP: cache.growthXP, injectedXP: cache.injectedXP, legacyXP: legacyXP)
        }
        guard cache.processedEventCount < eventCount,
              let cursorDate = cache.latestOccurredAt else {
            return nil
        }
        let newEvents = ledgerEvents(after: cursorDate, modelContext: modelContext)
        guard cache.processedEventCount + newEvents.count == eventCount else {
            return nil
        }
        let delta = ledgerEnergyDelta(from: newEvents)
        let updatedCache = OasisLedgerEnergyCache(
            processedEventCount: eventCount,
            latestEventId: latestCursor?.eventId,
            latestOccurredAt: latestCursor?.occurredAt,
            growthXP: cache.growthXP + delta.growthXP,
            injectedXP: cache.injectedXP + delta.injectedXP
        )
        guard cacheMatchesLatestCursor(updatedCache, latestCursor: latestCursor) else { return nil }
        OasisTreePreferenceStore.storeLedgerEnergyCache(updatedCache)
        return LedgerEnergySnapshot(
            growthXP: updatedCache.growthXP,
            injectedXP: updatedCache.injectedXP,
            legacyXP: legacyXP
        )
    }

    private static func rebuildLedgerEnergySnapshot(
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human],
        latestCursor: LedgerEventCursor?
    ) -> LedgerEnergySnapshot {
        let ledgerEvents = allLedgerEvents(modelContext: modelContext)
        let delta = ledgerEnergyDelta(from: ledgerEvents)
        let legacyXP = legacyCompatibilityXP(
            ledgerEvents: ledgerEvents,
            modelContext: modelContext,
            pets: pets,
            humans: humans
        )
        OasisTreePreferenceStore.storeLedgerEnergyCache(
            OasisLedgerEnergyCache(
                processedEventCount: ledgerEvents.count,
                latestEventId: latestCursor?.eventId,
                latestOccurredAt: latestCursor?.occurredAt,
                growthXP: delta.growthXP,
                injectedXP: delta.injectedXP
            )
        )
        return LedgerEnergySnapshot(growthXP: delta.growthXP, injectedXP: delta.injectedXP, legacyXP: legacyXP)
    }

    private static func ledgerEventCount(modelContext: ModelContext) -> Int {
        do {
            return try modelContext.fetchCount(FetchDescriptor<CareLedgerEvent>())
        } catch {
            OhanaLog.warning(
                "[OasisTreeManager] failed to fetch ledger event count: \(error.localizedDescription)",
                category: "Oasis"
            )
            return 0
        }
    }

    private static func latestLedgerCursor(modelContext: ModelContext) -> LedgerEventCursor? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first.map(cursor)
        } catch {
            OhanaLog.warning(
                "[OasisTreeManager] failed to fetch latest ledger cursor: \(error.localizedDescription)",
                category: "Oasis"
            )
            return nil
        }
    }

    private static func ledgerEvents(after cursorDate: Date, modelContext: ModelContext) -> [CareLedgerEvent] {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt > cursorDate
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        descriptor.fetchLimit = 256
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[OasisTreeManager] failed to fetch ledger events after cursor=\(cursorDate): \(error.localizedDescription)",
                category: "Oasis"
            )
            return []
        }
    }

    private static func allLedgerEvents(modelContext: ModelContext) -> [CareLedgerEvent] {
        do {
            return try modelContext.fetch(FetchDescriptor<CareLedgerEvent>())
        } catch {
            OhanaLog.warning(
                "[OasisTreeManager] failed to fetch all ledger events: \(error.localizedDescription)",
                category: "Oasis"
            )
            return []
        }
    }

    private static func shopInjectionLedgerEvent(
        purchaseID: String,
        modelContext: ModelContext
    ) -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.sourceEventId == purchaseID
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "[OasisTreeManager] failed to resolve shop injection purchase=\(purchaseID): \(error.localizedDescription)",
                category: "Oasis"
            )
            return nil
        }
    }

    private static func cacheMatchesLatestCursor(
        _ cache: OasisLedgerEnergyCache,
        latestCursor: LedgerEventCursor?
    ) -> Bool {
        cache.latestEventId == latestCursor?.eventId && cache.latestOccurredAt == latestCursor?.occurredAt
    }

    private nonisolated static func cursor(for event: CareLedgerEvent) -> LedgerEventCursor {
        LedgerEventCursor(eventId: event.id.uuidString, occurredAt: event.occurredAt)
    }

    private static func ledgerEnergyDelta(from events: [CareLedgerEvent]) -> (growthXP: Int, injectedXP: Int) {
        events.reduce(into: (growthXP: 0, injectedXP: 0)) { partial, event in
            partial.growthXP += CoconutEconomyPolicyV2.metadataValue(named: "growthXP", in: event.metadataJSON)
            guard isManualTreeInjectionLedger(event) else { return }
            partial.injectedXP += CoconutEconomyPolicyV2.metadataValue(named: "injectedXP", in: event.metadataJSON)
        }
    }

    private static func isManualTreeInjectionLedger(_ event: CareLedgerEvent) -> Bool {
        guard event.eventKindEnum == .coconut else { return false }
        guard event.actionType == "treeInjection" || event.actionType == "treeInjectionLarge" else { return false }
        return event.metadataJSON.contains("\"reason\":\"treeInjection\"")
    }

    private func refreshInjectedEnergy(ledgerInjectedXP: Int) {
        let recoveredXP = max(0, ledgerInjectedXP)
        if injectedEnergy != recoveredXP {
            injectedEnergy = recoveredXP
        }
    }

    private func refreshCareGrowthEnergy(ledgerGrowthXP: Int, legacyXP: Int) {
        let historicalTotal = max(0, ledgerGrowthXP) + max(0, legacyXP)
        let baseline: Int
        if let stored = OasisTreePreferenceStore.careGrowthBaseline() {
            baseline = stored
        } else {
            // 首次接入"照护养树":以当前历史养分为基线,只有之后的新增计入树,
            // 避免既有存档因历史照护一次性爆级(新用户此值为 0,照护全额计入)。
            baseline = historicalTotal
            OasisTreePreferenceStore.storeCareGrowthBaseline(baseline)
        }
        let recovered = max(0, historicalTotal - baseline)
        if careGrowthEnergy != recovered {
            careGrowthEnergy = recovered
        }
    }

    // MARK: - Inject Energy（消耗椰子，增加树经验）

    func canUseInjectionPackage(
        cost: Int = OasisTreeEnergyInjectionPolicy.starterPackageCost,
        date: Date = Date()
    ) -> Bool {
        let package = Self.injectionPackage(forRequestedCost: cost, currentLevel: treeLevel)
        guard package.isAvailable else { return false }
        return Self.canUseInjectionPackage(package, date: date)
    }

    @discardableResult
    @MainActor
    func injectEnergy(
        cost: Int = OasisTreeEnergyInjectionPolicy.starterPackageCost,
        modelContext: ModelContext
    ) -> Bool {
        let package = Self.injectionPackage(forRequestedCost: cost, currentLevel: treeLevel)
        guard package.isAvailable else { return false }
        guard Self.canUseInjectionPackage(package) else { return false }
        guard OasisCritterEconomyService.spendAvailableCoconuts(
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

    /// Replays a shop-funded injection using its durable purchase marker. Tree
    /// energy is not evidence that this specific purchase was applied: another
    /// purchase may have advanced the same aggregate in the meantime.
    @discardableResult
    @MainActor
    func applyPurchasedEnergyBoost(
        cost: Int,
        injectedXP: Int,
        purchaseID: UUID,
        modelContext: ModelContext
    ) -> Bool {
        let purchaseKey = purchaseID.uuidString
        let package = Self.injectionPackage(forRequestedCost: cost, currentLevel: treeLevel)
        guard injectedXP == package.xp else { return false }
        let existingEvent = Self.shopInjectionLedgerEvent(
            purchaseID: purchaseKey,
            modelContext: modelContext
        )
        let hasDurableMarker = OasisTreePreferenceStore.hasAppliedShopEnergyPurchase(purchaseID)
        if existingEvent == nil, !hasDurableMarker {
            guard package.isAvailable else { return false }
            guard Self.canUseInjectionPackage(package) else { return false }
        }

        let previousInjectedEnergy = injectedEnergy
        let durableWrite = if hasDurableMarker || existingEvent != nil {
            OasisTreePreferenceStore.checkpointShopEnergyPurchase(
                purchaseID,
                currentInjectedEnergy: previousInjectedEnergy
            )
        } else {
            OasisTreePreferenceStore.applyShopEnergyPurchase(
                purchaseID,
                xp: package.xp,
                currentInjectedEnergy: previousInjectedEnergy
            )
        }
        if injectedEnergy != durableWrite.injectedEnergy {
            persistsInjectedEnergyChanges = false
            injectedEnergy = durableWrite.injectedEnergy
            persistsInjectedEnergyChanges = true
        }
        Self.markInjectionPackageUsed(package)

        if existingEvent == nil {
            recordShopInjectionLedgerEvent(
                package: package,
                purchaseKey: purchaseKey,
                modelContext: modelContext
            )
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                // The durable energy-plus-marker record is already committed.
                // Reinsert the checkpoint so the caller's final attempt save
                // can persist both facts together; a later recovery remains
                // safe if that save also fails.
                recordShopInjectionLedgerEvent(
                    package: package,
                    purchaseKey: purchaseKey,
                    modelContext: modelContext
                )
                return true
            }
        }
        OasisTreePreferenceStore.clearShopEnergyPurchaseMarker(purchaseID)

        guard durableWrite.didApplyEnergy else { return true }
        if checkAndRewardLevelUp(modelContext: modelContext) != nil {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        return true
    }

    @MainActor
    func finalizePurchasedEnergyBoost(
        purchaseID: UUID,
        modelContext: ModelContext
    ) {
        guard Self.shopInjectionLedgerEvent(
            purchaseID: purchaseID.uuidString,
            modelContext: modelContext
        ) != nil else { return }
        OasisTreePreferenceStore.clearShopEnergyPurchaseMarker(purchaseID)
    }

    @MainActor
    func reconcilePurchasedEnergyBoostMarkers(modelContext: ModelContext) {
        for purchaseID in OasisTreePreferenceStore.pendingShopEnergyPurchaseIDs() {
            finalizePurchasedEnergyBoost(
                purchaseID: purchaseID,
                modelContext: modelContext
            )
        }
    }

    @MainActor
    private func recordShopInjectionLedgerEvent(
        package: InjectionPackage,
        purchaseKey: String,
        modelContext: ModelContext
    ) {
        let activeHumanID = UserDefaultsActiveHumanSelection().currentHumanId
        careLedger.record(
            occurredAt: Date(),
            actorKind: activeHumanID == nil ? .system : .human,
            actorId: activeHumanID,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: package.actionType,
            amountValue: 0,
            amountUnit: "",
            note: package.title,
            source: .economy,
            sourceEventId: purchaseKey,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\"economyVersion\":3,\"walletScope\":\"islandTotal\",\"injectedXP\":\(package.xp),\"coconutCost\":\(package.cost),\"budgetMultiplier\":1.0,\"reason\":\"treeInjection\",\"shopPurchaseId\":\"\(purchaseKey)\"}",
            context: modelContext,
            save: false
        )
    }

    #if DEBUG
        @MainActor
        func setEnergyForTesting(islandEnergy: Int? = nil, injectedEnergy: Int? = nil) {
            if let islandEnergy {
                self.islandEnergy = max(0, islandEnergy)
            }
            if let injectedEnergy {
                self.injectedEnergy = max(0, injectedEnergy)
            }
        }
    #endif

    @discardableResult
    @MainActor
    private func applyEnergyPackage(_ package: InjectionPackage, recordsCost: Bool, modelContext: ModelContext) -> Bool {
        let previousInjectedEnergy = injectedEnergy
        let activeHumanID = UserDefaultsActiveHumanSelection().currentHumanId
        let previousUsedPeriod = package.enforcesPeriodLimit
            ? OasisTreePreferenceStore.injectionUsedPeriod(for: package.limitKey)
            : nil
        injectedEnergy += package.xp
        Self.markInjectionPackageUsed(package)
        careLedger.record(
            occurredAt: Date(),
            actorKind: activeHumanID == nil ? .system : .human,
            actorId: activeHumanID,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: package.actionType,
            amountValue: 0,
            amountUnit: "",
            note: package.title,
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: recordsCost ? -package.cost : 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\"economyVersion\":3,\"walletScope\":\"islandTotal\",\"injectedXP\":\(package.xp),\"coconutCost\":\(package.cost),\"budgetMultiplier\":1.0,\"reason\":\"treeInjection\"}",
            context: modelContext,
            save: false
        )

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            injectedEnergy = previousInjectedEnergy
            if package.enforcesPeriodLimit {
                OasisTreePreferenceStore.restoreInjectionUsed(limitKey: package.limitKey, previousPeriodKey: previousUsedPeriod)
            }
            oasisRewards.refreshCoconutProjection(context: modelContext)
            return false
        }

        // 检查是否升级；升级奖励会以“升级椰子”形式等待用户敲开。
        if checkAndRewardLevelUp(modelContext: modelContext) != nil {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            // 普通注入，无奖励
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        return true
    }

    private static func legacyCompatibilityXP(
        ledgerEvents: [CareLedgerEvent],
        modelContext: ModelContext,
        pets: [Pet],
        humans: [Human]
    ) -> Int {
        let includesPlantCare = PlantUnlockPolicy.hasExistingPlantData()
        if includesPlantCare, let legacyBaseline = OasisTreePreferenceStore.legacyBaselineXPRecord() {
            let compatibleBaseline = legacyBaseline.isCurrentScale
                ? legacyBaseline.xp
                : Self.legacyCompatibleXP(forLegacyTreeEnergy: legacyBaseline.xp)
            if !legacyBaseline.isCurrentScale {
                OasisTreePreferenceStore.storeLegacyBaselineXP(compatibleBaseline)
            }
            return compatibleBaseline
        }

        guard !ledgerEvents.contains(where: { $0.metadataJSON.contains("\"economyVersion\":2") }) else {
            OasisTreePreferenceStore.storeLegacyBaselineXP(0)
            return 0
        }

        let legacyLedgerCount = ledgerEvents.count(where: {
            !$0.metadataJSON.contains("\"economyVersion\":2") &&
                ($0.eventKindEnum != .plantCare || includesPlantCare) &&
                [.care, .potty, .walk, .hygiene, .health, .weight, .medication, .workout, .plantCare, .milestone].contains($0.eventKindEnum)
        })
        let fallbackCount = legacyLedgerCount > 0
            ? legacyLedgerCount
            : legacyActivityCount(modelContext: modelContext, pets: pets, humans: humans)
        let baseline = Self.legacyCompatibleXP(forLegacyTreeEnergy: min(1200, fallbackCount * 4))
        OasisTreePreferenceStore.storeLegacyBaselineXP(baseline)
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
        let plantEventCount: Int
        if PlantUnlockPolicy.hasExistingPlantData() {
            do {
                let events = try modelContext.fetch(FetchDescriptor<Event>())
                plantEventCount = events.count {
                    DomainEntityLinkRegistry.role(for: $0).isPlantScoped
                }
            } catch {
                OhanaLog.warning(
                    "[OasisTreeManager] failed to fetch legacy plant event count: \(error.localizedDescription)",
                    category: "Oasis"
                )
                plantEventCount = 0
            }
        } else {
            plantEventCount = 0
        }
        return total + plantEventCount
    }

    private struct InjectionPackage {
        let cost: Int
        let xp: Int
        let actionType: String
        let title: String
        let limitKey: String
        let isAvailable: Bool
        let enforcesPeriodLimit: Bool
    }

    private static func injectionPackage(forRequestedCost cost: Int, currentLevel: TreeLevel) -> InjectionPackage {
        if cost >= OasisTreeEnergyInjectionPolicy.largePackageCost {
            return InjectionPackage(
                cost: OasisTreeEnergyInjectionPolicy.largePackageCost,
                xp: OasisTreeEnergyInjectionPolicy.largePackageXP,
                actionType: "treeInjectionLarge",
                title: DomainCareRewardGeneralTitle.counted(
                    DomainCareRewardGeneralTitle.oasisTreeEnergyLarge,
                    count: OasisTreeEnergyInjectionPolicy.largePackageXP
                ),
                limitKey: OasisTreePreferenceStore.weeklyInjectionWeekKey,
                isAvailable: currentLevel >= .lv5,
                // 注入不限次:经济自限(花椰子换养分比照护更亏),硬性限购是多余摩擦。
                enforcesPeriodLimit: false
            )
        }
        return InjectionPackage(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            xp: OasisTreeEnergyInjectionPolicy.starterPackageXP,
            actionType: "treeInjection",
            title: DomainCareRewardGeneralTitle.counted(
                DomainCareRewardGeneralTitle.oasisTreeEnergyStarter,
                count: OasisTreeEnergyInjectionPolicy.starterPackageXP
            ),
            limitKey: OasisTreePreferenceStore.dailyInjectionDayKey,
            isAvailable: true,
            // 注入不限次:经济自限(花椰子换养分比照护更亏),硬性限购是多余摩擦。
            enforcesPeriodLimit: false
        )
    }

    private static func canUseInjectionPackage(_ package: InjectionPackage, date: Date = Date()) -> Bool {
        guard package.enforcesPeriodLimit else { return true }
        let usedKey = OasisTreePreferenceStore.injectionUsedPeriod(for: package.limitKey)
        return usedKey != injectionPeriodKey(for: package, date: date)
    }

    private static func markInjectionPackageUsed(_ package: InjectionPackage, date: Date = Date()) {
        guard package.enforcesPeriodLimit else { return }
        OasisTreePreferenceStore.markInjectionUsed(
            limitKey: package.limitKey,
            periodKey: injectionPeriodKey(for: package, date: date)
        )
    }

    private static func injectionPeriodKey(for package: InjectionPackage, date: Date) -> String {
        if package.limitKey == OasisTreePreferenceStore.weeklyInjectionWeekKey {
            let components = Calendar(identifier: .gregorian).dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
        }
        return EconomyDailyBudgetStore.dayKey(for: date)
    }
}

enum OasisTreeManagerRegistry {
    private static var currentManager = OasisTreeManager()

    static var current: OasisTreeManager {
        get { currentManager }
        set { currentManager = newValue }
    }
}
