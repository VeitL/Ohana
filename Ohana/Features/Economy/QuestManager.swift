//
//  QuestManager.swift
//  Ohana
//
//  欧哈纳岛屿拓荒指南 — 新手任务状态机
//  @Observable compatibility projection for quest flags and wallet feedback.
//

import Observation
import SwiftData
import SwiftUI

@Observable
final class QuestManager: CoconutProjectionManaging {

    // MARK: - Wallet Projection / Quest Flags
    /// SwiftData wallet projection cache. Source of truth is CoconutAccount/CoconutLedgerEntry.
    var coconutCount: Int = 0

    /// Recent wallet ledger projection for legacy UI compatibility.
    var coconutLogs: [CoconutLogEntry] = []
    var lastEconomyRewardResult: EconomyRewardResult?

    var isPetWizardCompleted: Bool = false
    var isFirstMealRecorded: Bool = false
    var isThemeColorSet: Bool = false

    let streakRewards = StreakRewardManager()
    let activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()
    let shopInventory: ShopInventoryManaging = UserDefaultsShopInventoryManager()
    @ObservationIgnored let wallet: CoconutWalletManaging
    @ObservationIgnored let revisions: DomainRevisionPublishing

    // MARK: - Quest Flag Persistence
    /// Persists quest flags only. Coconut balance and history are SwiftData-backed in V58.
    func persistQuestFlags() {
        Self.defaults.set(isPetWizardCompleted, forKey: Keys.petWizard)
        Self.defaults.set(isFirstMealRecorded, forKey: Keys.firstMeal)
        Self.defaults.set(isThemeColorSet, forKey: Keys.themeColor)
    }

    func replaceCoconutProjection(count: Int, logs: [CoconutLogEntry]) {
        coconutCount = max(0, count)
        coconutLogs = Array(logs.prefix(200))
        publishCoconutProjectionRevision(
            note: "questManager.coconutProjection.replace",
            affectedEntityIDs: []
        )
    }

    func recordWalletProjection(entries: [CoconutLedgerEntry], postsRewardFeedback: Bool) {
        guard !entries.isEmpty else { return }
        let totalDelta = entries
            .filter {
                $0.affectsBalance &&
                    ($0.ownerKind != .system || $0.accountKey == CoconutAccountKey.islandReserve)
            }
            .reduce(0) { $0 + $1.delta }
        coconutCount = max(0, coconutCount + totalDelta)

        let projectedLogs = entries
            .filter { $0.delta != 0 }
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { $0.asCoconutLogEntry() }
        if !projectedLogs.isEmpty {
            coconutLogs.insert(contentsOf: projectedLogs, at: 0)
            if coconutLogs.count > 200 {
                coconutLogs = Array(coconutLogs.prefix(200))
            }
        }

        if postsRewardFeedback {
            for entry in projectedLogs where entry.amount > 0 || (entry.growthXP ?? 0) > 0 {
                publishCoconutRewardFeedback(for: entry)
            }
        }
        publishCoconutProjectionRevision(
            note: "questManager.walletProjection",
            affectedEntityIDs: affectedWalletEntityIDs(from: entries)
        )
    }

    // MARK: - Constants
    static let defaults = UserDefaults.standard
    enum Keys {
        static let petWizard = "quest_isPetWizardCompleted"
        static let firstMeal = "quest_isFirstMealRecorded"
        static let themeColor = "quest_isThemeColorSet"
        static let stepRewardDate = "quest_stepRewardLastDate"
        static let bondedDate = "quest_bondedWalkLastDate"
        static let cooldownLogs = "quest_cooldownLogs"
    }

    // MARK: - 冷却规则

    /// 返回该动作的冷却秒数（nil = 无冷却）
    static func cooldownDuration(for type: OhanaActionType) -> TimeInterval? {
        switch type {
        case .feed: 4 * 3600
        case .water: 4 * 3600
        case .potty: 2 * 3600
        case let .care(t):
            switch t {
            case .bath, .teeth, .nails, .brushing, .ears: 24 * 3600
            }
        case .walk: nil // GPS 距离门槛控制
        case .health: nil
        case .expense: nil
        case .weight: nil
        case .milestone: nil
        case .dailyFocusCompletion: nil
        case .plantWatering, .plantFertilizing: 4 * 3600
        case .general: 2 * 3600
        }
    }

    /// 冷却 key："petId_actionKey"
    func cooldownKey(petId: UUID?, type: OhanaActionType) -> String {
        let pid = petId?.uuidString ?? "global"
        let aKey: String = switch type {
        case .feed: "feed"
        case .water: "water"
        case let .potty(l): l ? "litter" : "potty"
        case let .care(t): "care_\(t)"
        case .walk: "walk"
        case .health: "health"
        case .expense: "expense"
        case .weight: "weight"
        case .milestone: "milestone"
        case .dailyFocusCompletion: "dailyFocusCompletion"
        case .plantWatering: "plant_water"
        case .plantFertilizing: "plant_fertilize"
        case let .general(_, _, _, t): "general_\(t.prefix(10))"
        }
        return "\(pid)_\(aKey)"
    }

    /// 是否在冷却期内
    func isOnCooldown(petId: UUID?, type: OhanaActionType) -> Bool {
        guard let duration = Self.cooldownDuration(for: type) else { return false }
        let key = cooldownKey(petId: petId, type: type)
        guard let dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs),
              let ts = dict[key] as? Double else { return false }
        return Date().timeIntervalSince1970 - ts < duration
    }

    /// 冷却剩余秒数（0 = 已结束）
    func cooldownRemaining(petId: UUID?, type: OhanaActionType) -> TimeInterval {
        guard let duration = Self.cooldownDuration(for: type) else { return 0 }
        let key = cooldownKey(petId: petId, type: type)
        guard let dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs),
              let ts = dict[key] as? Double else { return 0 }
        return max(0, duration - (Date().timeIntervalSince1970 - ts))
    }

    /// 记录本次奖励时间戳
    func recordCooldown(petId: UUID?, type: OhanaActionType) {
        recordCooldown(petId: petId, type: type, occurredAt: Date())
    }

    func recordCooldown(petId: UUID?, type: OhanaActionType, occurredAt: Date) {
        let key = cooldownKey(petId: petId, type: type)
        var dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs) ?? [:]
        dict[key] = occurredAt.timeIntervalSince1970
        Self.defaults.set(dict, forKey: Keys.cooldownLogs)
    }

    func clearCooldown(petId: UUID?, type: OhanaActionType) {
        let key = cooldownKey(petId: petId, type: type)
        var dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs) ?? [:]
        dict.removeValue(forKey: key)
        Self.defaults.set(dict, forKey: Keys.cooldownLogs)
    }

    func walkDailyRewardKey(humanId: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return "quest_walkReward_\(humanId)_\(formatter.string(from: date))"
    }

    func remainingWalkRewardToday(for humanId: String) -> Int {
        max(0, 40 - Self.defaults.integer(forKey: walkDailyRewardKey(humanId: humanId)))
    }

    func recordWalkRewardToday(_ amount: Int, humanId: String) {
        guard amount > 0 else { return }
        let key = walkDailyRewardKey(humanId: humanId)
        Self.defaults.set(Self.defaults.integer(forKey: key) + amount, forKey: key)
    }

    func economyBudgetKeys(for human: Human?, context: ModelContext) -> (household: String, member: String) {
        (
            CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            human?.id.uuidString ?? CoconutEconomyPolicyV2.currentUserKey()
        )
    }

    func careObjectKeys(for pets: [Pet]) -> [String] {
        pets
            .filter { EconomyWalletWritePolicy.canWrite($0) }
            .map { "pet.\($0.id.uuidString)" }
    }

    func careObjectKeys(for pet: Pet?) -> [String] {
        pet.map { careObjectKeys(for: [$0]) } ?? []
    }

    func careObjectKeys(forPlantId plantId: UUID?) -> [String] {
        plantId.map { ["plant.\($0.uuidString)"] } ?? []
    }

    func currentActiveHuman(context: ModelContext) -> Human? {
        EconomyRewardOwnerResolver.activeHuman(
            selection: activeHumanSelection,
            context: context,
            logPrefix: "QuestManager"
        )
    }

    func isDoubleRewardBoostActive() -> Bool {
        shopInventory.isDoubleRewardBoostActive()
    }

    func clearDoubleRewardBoost() {
        shopInventory.clearDoubleRewardBoost()
    }

    /// 清空某宠物的任务冷却 key，并从椰子流水中移除该 `actorId` 的条目（与宠物活动清理服务配套）。
    func clearPerPetAuxiliaryState(forPetId petId: UUID) {
        let pid = petId.uuidString
        if var dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs) {
            dict = dict.filter { key, _ in
                !key.hasPrefix("\(pid)_")
            }
            Self.defaults.set(dict, forKey: Keys.cooldownLogs)
        }
        coconutLogs.removeAll { $0.actorId == pid }
    }

    convenience init() {
        self.init(wallet: SwiftDataCoconutWalletManager())
    }

    convenience init(wallet: CoconutWalletManaging) {
        self.init(wallet: wallet, revisions: SharedDomainRevisionPublisher())
    }

    init(wallet: CoconutWalletManaging, revisions: DomainRevisionPublishing) {
        self.wallet = wallet
        self.revisions = revisions
        self.isPetWizardCompleted = Self.defaults.bool(forKey: Keys.petWizard)
        self.isFirstMealRecorded = Self.defaults.bool(forKey: Keys.firstMeal)
        self.isThemeColorSet = Self.defaults.bool(forKey: Keys.themeColor)
    }

    // MARK: - Computed
    var isAllWelcomeQuestsCompleted: Bool {
        isPetWizardCompleted && isFirstMealRecorded && isThemeColorSet
    }

    var completedCount: Int {
        [isPetWizardCompleted, isFirstMealRecorded, isThemeColorSet].count(where: { $0 })
    }

    private func affectedWalletEntityIDs(from entries: [CoconutLedgerEntry]) -> Set<UUID> {
        Set(entries.compactMap { UUID(uuidString: $0.ownerId) })
    }

    var totalQuestCount: Int { 3 }

    // MARK: - Domain reward payload compatibility aliases
    typealias OhanaActionType = DomainCareRewardAction

    // MARK: - 旧版 ActionType（兼容旧调用，内部映射到 OhanaActionType）
    enum ActionType {
        case walk, feed, litter, potty, water, general
        var emoji: String {
            switch self {
            case .walk: "🦮"
            case .feed: "🍗"
            case .litter: "🧹"
            case .potty: "�"
            case .water: "💧"
            case .general: "🥥"
            }
        }
    }

    typealias QualityBonus = DomainCareRewardQuality
}
