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

// MARK: - CoconutLogEntry
struct CoconutLogEntry: Codable, Identifiable {
    let id: UUID
    let emoji: String
    let title: String
    let amount: Int // 正数=获取，负数=消耗
    let date: Date
    var actorId: String? // N10: Human.id.uuidString 或 Pet.id.uuidString
    var actorName: String? // N10: 显示名
    var growthXP: Int?
    var economyReason: String?
    var budgetStage: String?
    var feedbackMessage: String?

    init(id: UUID = UUID(), emoji: String, title: String, amount: Int, date: Date = Date(),
         actorId: String? = nil, actorName: String? = nil,
         growthXP: Int? = nil, economyReason: String? = nil,
         budgetStage: String? = nil, feedbackMessage: String? = nil) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.amount = amount
        self.date = date
        self.actorId = actorId
        self.actorName = actorName
        self.growthXP = growthXP
        self.economyReason = economyReason
        self.budgetStage = budgetStage
        self.feedbackMessage = feedbackMessage
    }

    var timeAgoString: String {
        timeAgoString(l: .current)
    }

    func timeAgoString(l: L10n) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return l.tr(zh: "刚刚", en: "Just now", de: "Gerade eben")
        }
        if seconds < 3600 {
            let minutes = seconds / 60
            return l.tr(zh: "\(minutes) 分钟前", en: "\(minutes)m ago", de: "vor \(minutes) Min.")
        }
        if seconds < 86400 {
            let hours = seconds / 3600
            return l.tr(zh: "\(hours) 小时前", en: "\(hours)h ago", de: "vor \(hours) Std.")
        }
        if seconds < 86400 * 2 {
            return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern")
        }
        let days = seconds / 86400
        if days < 30 {
            return l.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) Tagen")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.option(for: l.languageCode).localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}

struct CoconutLedgerAudit: Equatable {
    let islandCount: Int
    let rollingLogDelta: Int
    let petAccountTotal: Int
    let humanAccountTotal: Int
    let rollingLogReconciles: Bool?
    let hasNegativeAccount: Bool

    var isHealthy: Bool {
        islandCount >= 0 && !hasNegativeAccount && (rollingLogReconciles ?? true)
    }

    static func evaluate(
        islandCount: Int,
        logs: [CoconutLogEntry],
        petBalances: [Int],
        humanBalances: [Int],
        maxRollingLogCount: Int = 200
    ) -> CoconutLedgerAudit {
        let logDelta = logs.reduce(0) { $0 + $1.amount }
        let canUseRollingLogs = logs.count < maxRollingLogCount
        return CoconutLedgerAudit(
            islandCount: islandCount,
            rollingLogDelta: logDelta,
            petAccountTotal: petBalances.reduce(0, +),
            humanAccountTotal: humanBalances.reduce(0, +),
            rollingLogReconciles: canUseRollingLogs ? logDelta == islandCount : nil,
            hasNegativeAccount: petBalances.contains(where: { $0 < 0 }) || humanBalances.contains(where: { $0 < 0 })
        )
    }
}

@Observable
final class QuestManager {

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
        publishCoconutProjectionRevision(note: "questManager.coconutProjection.replace")
    }

    func recordWalletProjection(entries: [CoconutLedgerEntry], postsRewardFeedback: Bool) {
        guard !entries.isEmpty else { return }
        let totalDelta = entries
            .filter { $0.affectsBalance && $0.ownerKind != .system }
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
        publishCoconutProjectionRevision(note: "questManager.walletProjection")
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
        let key = cooldownKey(petId: petId, type: type)
        var dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs) ?? [:]
        dict[key] = Date().timeIntervalSince1970
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

    func currentActiveHuman(context: ModelContext) -> Human? {
        guard let humanId = activeHumanSelection.currentHumanId else { return nil }
        guard let id = UUID(uuidString: humanId) else {
            OhanaLog.warning("[QuestManager] active humanId=\(humanId) is invalid; skipping human share", category: "Economy")
            return nil
        }
        let desc = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        let human: Human?
        do {
            human = try context.fetch(desc).first
        } catch {
            OhanaLog.warning("[QuestManager] failed to fetch active humanId=\(humanId): \(error.localizedDescription)", category: "Economy")
            return nil
        }
        if human == nil {
            OhanaLog.warning("[QuestManager] humanId=\(humanId) not found in context; skipping human share", category: "Economy")
        } else if let human, !EconomyWalletWritePolicy.canWrite(human) {
            OhanaLog.warning("[QuestManager] active humanId=\(humanId) wallet is frozen; skipping human share", category: "Economy")
            return nil
        }
        return human
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

    var totalQuestCount: Int { 3 }

    // MARK: - OhanaActionType（差异化双边分润规则）
    enum OhanaActionType {
        case walk(distanceMeters: Double)
        case potty(isLitter: Bool)
        case feed
        case water
        case care(type: HygieneType)
        case health
        case expense
        case milestone
        case weight
        case dailyFocusCompletion
        case general(humanReward: Int, petReward: Int, emoji: String, title: String)

        /// V2 基础椰子奖励预估（真实发放由 CoconutEconomyPolicyV2 统一计算）。
        var baseRewards: (human: Int, pet: Int) {
            switch self {
            case let .walk(d):
                let total = CoconutWalkRewardPolicy.baseCoconuts(for: d)
                return CoconutWalkRewardPolicy.splitCoconuts(total: total)
            case let .potty(isLitter):
                return isLitter ? (2, 1) : (1, 1)
            case .feed:
                return (2, 1)
            case .water:
                return (2, 1)
            case let .care(t):
                switch t {
                case .bath: return (6, 2)
                case .teeth: return (4, 2)
                case .nails: return (4, 2)
                case .brushing: return (3, 2)
                case .ears: return (4, 2)
                }
            case .health:
                return (8, 2)
            case .expense:
                return (2, 0)
            case .weight:
                return (3, 1)
            case .milestone:
                return (2, 1)
            case .dailyFocusCompletion:
                return (8, 0)
            case let .general(h, p, _, _):
                return (h, p)
            }
        }

        var emoji: String {
            switch self {
            case .walk: "🦮"
            case let .potty(l): l ? "🧹" : "💩"
            case .feed: "🍗"
            case .water: "💧"
            case let .care(t):
                switch t {
                case .bath: "🛁"
                case .teeth: "🦷"
                case .nails: "✂️"
                case .brushing: "🪮"
                case .ears: "👂"
                }
            case .health: "💉"
            case .expense: "💰"
            case .weight: "⚖️"
            case .milestone: "🏆"
            case .dailyFocusCompletion: "🎯"
            case let .general(_, _, e, _): e
            }
        }

        func title(pet: Pet?) -> String {
            let n = pet?.name ?? ""
            switch self {
            case .walk: return "\(n) 遛狗奖励"
            case let .potty(isLitter):
                return isLitter
                    ? L10n().tr(zh: "\(n) 铲砂奖励", en: "\(n) scoop reward", de: "\(n) Klo-Bonus")
                    : L10n().tr(zh: "\(n) 噗噗打卡", en: "\(n) poop check-in", de: "\(n) Häufchen-Check-in")
            case .feed: return "\(n) 喂食奖励"
            case .water: return "\(n) 喂水奖励"
            case let .care(t):
                let label = switch t {
                case .bath: "洗澡"
                case .teeth: "刷牙"
                case .nails: "剪甲"
                case .brushing: "梳毛"
                case .ears: "清耳"
                }
                return "\(n) \(label)奖励"
            case .health: return "\(n) 健康打卡奖励"
            case .expense: return "记账奖励"
            case .weight: return "\(n) 体重记录奖励"
            case .milestone: return "\(n) 里程碑达成"
            case .dailyFocusCompletion: return "Today Focus 全完成"
            case let .general(_, _, _, t): return t
            }
        }
    }

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

    // MARK: - 质量加成（精准模式、拍照、备注等越完整，成长 XP 越高）
    /// V2 中质量主要增加成长 XP；椰子最多额外 +1，避免用照片/备注放大软货币通胀。
    enum QualityBonus {
        case none // XP ×1.0
        case precise // XP ×1.1 精准录入（如准确克数、GPS、重量）
        case withNote // XP ×1.1 填写了备注
        case withPhoto // XP ×1.1 附带照片
        case preciseAndNote // XP ×1.2
        case preciseAndPhoto // XP ×1.2
        case preciseNotePhoto // XP ×1.3 三项全齐

        var multiplier: Double {
            switch self {
            case .none: 1.0
            case .precise: 1.1
            case .withNote: 1.1
            case .withPhoto: 1.1
            case .preciseAndNote: 1.2
            case .preciseAndPhoto: 1.2
            case .preciseNotePhoto: 1.3
            }
        }

        var badgeLabel: String? {
            switch self {
            case .none: nil
            case .precise: "🎯 精准XP+10%"
            case .withNote: "📝 备注XP+10%"
            case .withPhoto: "📷 照片XP+10%"
            case .preciseAndNote: "🎯📝 XP+20%"
            case .preciseAndPhoto: "🎯📷 XP+20%"
            case .preciseNotePhoto: "✨ 完整记录XP+30%"
            }
        }

        /// 根据 3 个维度布尔值智能组合
        static func compose(precise: Bool, hasNote: Bool, hasPhoto: Bool) -> QualityBonus {
            switch (precise, hasNote, hasPhoto) {
            case (true, true, true): .preciseNotePhoto
            case (true, false, true): .preciseAndPhoto
            case (true, true, false): .preciseAndNote
            case (false, false, true): .withPhoto
            case (false, true, false): .withNote
            case (true, false, false): .precise
            default: .none
            }
        }
    }
}
