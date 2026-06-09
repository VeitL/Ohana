//
//  QuestManager.swift
//  Ohana
//
//  欧哈纳岛屿拓荒指南 — 新手任务状态机
//  @Observable 单例，存储属性 + UserDefaults 双写，保证 SwiftUI 能正确观察变化
//

import SwiftUI
import Observation
import SwiftData

// MARK: - CoconutLogEntry
struct CoconutLogEntry: Codable, Identifiable {
    let id: UUID
    let emoji: String
    let title: String
    let amount: Int      // 正数=获取，负数=消耗
    let date: Date
    var actorId:   String?  // N10: Human.id.uuidString 或 Pet.id.uuidString
    var actorName: String?  // N10: 显示名
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
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86400 { return "\(seconds / 3600) 小时前" }
        if seconds < 86400 * 2 { return "昨天" }
        let days = seconds / 86400
        if days < 30 { return "\(days)天前" }
        return date.formatted(.dateTime.month().day())
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

    // MARK: - Singleton
    static let shared = QuestManager()

    // MARK: - Persisted State（存储属性，@Observable 可追踪）
    // 不再使用 didSet 自动写入 UserDefaults，改为显式 flushToDefaults() 保证原子性
    var coconutCount: Int = 0

    // 椰子收支明细（最近 200 条）
    var coconutLogs: [CoconutLogEntry] = []
    var lastEconomyRewardResult: EconomyRewardResult?

    var isPetWizardCompleted: Bool = false
    var isFirstMealRecorded: Bool = false
    var isThemeColorSet: Bool = false

    // MARK: - Flush（原子写入 UserDefaults）
    /// Persists quest flags only. Coconut balance and history are SwiftData-backed in V58.
    func flushToDefaults() {
        Self.defaults.set(isPetWizardCompleted, forKey: Keys.petWizard)
        Self.defaults.set(isFirstMealRecorded, forKey: Keys.firstMeal)
        Self.defaults.set(isThemeColorSet, forKey: Keys.themeColor)
    }

    func replaceCoconutProjection(count: Int, logs: [CoconutLogEntry]) {
        coconutCount = max(0, count)
        coconutLogs = Array(logs.prefix(200))
        NotificationCenter.default.post(name: NSNotification.Name("coconutCountChanged"), object: nil)
    }

    func recordWalletProjection(entries: [CoconutLedgerEntry], postsRewardFeedback: Bool) {
        guard !entries.isEmpty else { return }
        let totalDelta = entries
            .filter(\.affectsBalance)
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
                NotificationCenter.default.post(
                    name: .ohanaCoconutRewardEvent,
                    object: OhanaCoconutRewardEvent(entry: entry)
                )
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name("coconutCountChanged"), object: nil)
    }

    // MARK: - Constants
    private static let defaults = UserDefaults.standard
    private enum Keys {
        static let coconut        = "quest_coconutCount"
        static let petWizard      = "quest_isPetWizardCompleted"
        static let firstMeal      = "quest_isFirstMealRecorded"
        static let themeColor     = "quest_isThemeColorSet"
        static let stepRewardDate = "quest_stepRewardLastDate"
        static let bondedDate     = "quest_bondedWalkLastDate"
        static let coconutLogs    = "quest_coconutLogs"
        static let cooldownLogs   = "quest_cooldownLogs"
    }

    // MARK: - 冷却规则

    /// 返回该动作的冷却秒数（nil = 无冷却）
    static func cooldownDuration(for type: OhanaActionType) -> TimeInterval? {
        switch type {
        case .feed:              return 4 * 3600
        case .water:             return 4 * 3600
        case .potty:             return 2 * 3600
        case .care(let t):
            switch t {
            case .bath, .teeth, .nails, .brushing, .ears: return 24 * 3600
            }
        case .walk:              return nil   // GPS 距离门槛控制
        case .health:            return nil
        case .expense:           return nil
        case .weight:            return nil
        case .milestone:         return nil
        case .dailyFocusCompletion: return nil
        case .general:           return 2 * 3600
        }
    }

    /// 冷却 key："petId_actionKey"
    private func cooldownKey(petId: UUID?, type: OhanaActionType) -> String {
        let pid = petId?.uuidString ?? "global"
        let aKey: String
        switch type {
        case .feed:              aKey = "feed"
        case .water:             aKey = "water"
        case .potty(let l):      aKey = l ? "litter" : "potty"
        case .care(let t):       aKey = "care_\(t)"
        case .walk:              aKey = "walk"
        case .health:            aKey = "health"
        case .expense:           aKey = "expense"
        case .weight:            aKey = "weight"
        case .milestone:         aKey = "milestone"
        case .dailyFocusCompletion: aKey = "dailyFocusCompletion"
        case .general(_, _, _, let t): aKey = "general_\(t.prefix(10))"
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
    private func recordCooldown(petId: UUID?, type: OhanaActionType) {
        let key = cooldownKey(petId: petId, type: type)
        var dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs) ?? [:]
        dict[key] = Date().timeIntervalSince1970
        Self.defaults.set(dict, forKey: Keys.cooldownLogs)
    }

    private func walkDailyRewardKey(humanId: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return "quest_walkReward_\(humanId)_\(formatter.string(from: date))"
    }

    private func remainingWalkRewardToday(for humanId: String) -> Int {
        max(0, 40 - Self.defaults.integer(forKey: walkDailyRewardKey(humanId: humanId)))
    }

    private func recordWalkRewardToday(_ amount: Int, humanId: String) {
        guard amount > 0 else { return }
        let key = walkDailyRewardKey(humanId: humanId)
        Self.defaults.set(Self.defaults.integer(forKey: key) + amount, forKey: key)
    }

    private func economyBudgetKeys(for human: Human?, context: ModelContext) -> (household: String, member: String) {
        (
            CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            human?.id.uuidString ?? CoconutEconomyPolicyV2.currentUserKey()
        )
    }

    private func careObjectKeys(for pets: [Pet]) -> [String] {
        pets
            .filter { !$0.hasPassedAway }
            .map { "pet.\($0.id.uuidString)" }
    }

    private func careObjectKeys(for pet: Pet?) -> [String] {
        pet.map { careObjectKeys(for: [$0]) } ?? []
    }

    /// 清空某宠物的任务冷却 key，并从椰子流水中移除该 `actorId` 的条目（与 `Pet.clearAllActivityRecords` 配套）。
    func clearPerPetAuxiliaryState(forPetId petId: UUID) {
        let pid = petId.uuidString
        if var dict = Self.defaults.dictionary(forKey: Keys.cooldownLogs) {
            dict = dict.filter { key, _ in
                !key.hasPrefix("\(pid)_")
            }
            Self.defaults.set(dict, forKey: Keys.cooldownLogs)
        }
        coconutLogs.removeAll { $0.actorId == pid }
        flushToDefaults()
    }

    private init() {
        self.coconutCount = Self.defaults.integer(forKey: Keys.coconut)
        self.isPetWizardCompleted = Self.defaults.bool(forKey: Keys.petWizard)
        self.isFirstMealRecorded = Self.defaults.bool(forKey: Keys.firstMeal)
        self.isThemeColorSet = Self.defaults.bool(forKey: Keys.themeColor)
        if let data = Self.defaults.data(forKey: Keys.coconutLogs),
           let logs = try? JSONDecoder().decode([CoconutLogEntry].self, from: data) {
            self.coconutLogs = logs
        }
    }

    // MARK: - Computed
    var isAllWelcomeQuestsCompleted: Bool {
        isPetWizardCompleted && isFirstMealRecorded && isThemeColorSet
    }

    var completedCount: Int {
        [isPetWizardCompleted, isFirstMealRecorded, isThemeColorSet].filter { $0 }.count
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
            case .walk(let d):
                let total = min(14, max(5, Int(d / 350)))
                let pet = max(1, total / 3)
                return (total - pet, pet)
            case .potty(let isLitter):
                return isLitter ? (2, 1) : (1, 1)
            case .feed:
                return (2, 1)
            case .water:
                return (2, 1)
            case .care(let t):
                switch t {
                case .bath:     return (6, 2)
                case .teeth:    return (4, 2)
                case .nails:    return (4, 2)
                case .brushing: return (3, 2)
                case .ears:     return (4, 2)
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
            case .general(let h, let p, _, _):
                return (h, p)
            }
        }

        var emoji: String {
            switch self {
            case .walk:    return "🦮"
            case .potty(let l): return l ? "🧹" : "💩"
            case .feed:    return "🍗"
            case .water:   return "💧"
            case .care(let t):
                switch t {
                case .bath:     return "🛁"
                case .teeth:    return "🦷"
                case .nails:    return "✂️"
                case .brushing: return "🪮"
                case .ears:     return "👂"
                }
            case .health:  return "💉"
            case .expense: return "💰"
            case .weight:  return "⚖️"
            case .milestone: return "🏆"
            case .dailyFocusCompletion: return "🎯"
            case .general(_, _, let e, _): return e
            }
        }

        func title(pet: Pet?) -> String {
            let n = pet?.name ?? ""
            switch self {
            case .walk:    return "\(n) 遛狗奖励"
            case .potty(let isLitter):
                return isLitter
                    ? L10n().tr(zh: "\(n) 铲砂奖励", en: "\(n) scoop reward", de: "\(n) Klo-Bonus")
                    : L10n().tr(zh: "\(n) 噗噗打卡", en: "\(n) poop check-in", de: "\(n) Häufchen-Check-in")
            case .feed:    return "\(n) 喂食奖励"
            case .water:   return "\(n) 喂水奖励"
            case .care(let t):
                let label: String
                switch t {
                case .bath:     label = "洗澡"
                case .teeth:    label = "刷牙"
                case .nails:    label = "剪甲"
                case .brushing: label = "梳毛"
                case .ears:     label = "清耳"
                }
                return "\(n) \(label)奖励"
            case .health:  return "\(n) 健康打卡奖励"
            case .expense: return "记账奖励"
            case .weight:  return "\(n) 体重记录奖励"
            case .milestone: return "\(n) 里程碑达成"
            case .dailyFocusCompletion: return "Today Focus 全完成"
            case .general(_, _, _, let t): return t
            }
        }
    }

    // MARK: - 旧版 ActionType（兼容旧调用，内部映射到 OhanaActionType）
    enum ActionType {
        case walk, feed, litter, potty, water, general
        var emoji: String {
            switch self {
            case .walk:    return "🦮"
            case .feed:    return "🍗"
            case .litter:  return "🧹"
            case .potty:   return "�"
            case .water:   return "💧"
            case .general: return "🥥"
            }
        }
    }

    // MARK: - 质量加成（精准模式、拍照、备注等越完整，成长 XP 越高）
    /// V2 中质量主要增加成长 XP；椰子最多额外 +1，避免用照片/备注放大软货币通胀。
    enum QualityBonus {
        case none                  // XP ×1.0
        case precise               // XP ×1.1 精准录入（如准确克数、GPS、重量）
        case withNote              // XP ×1.1 填写了备注
        case withPhoto             // XP ×1.1 附带照片
        case preciseAndNote        // XP ×1.2
        case preciseAndPhoto       // XP ×1.2
        case preciseNotePhoto      // XP ×1.3 三项全齐

        var multiplier: Double {
            switch self {
            case .none:              return 1.0
            case .precise:           return 1.1
            case .withNote:          return 1.1
            case .withPhoto:         return 1.1
            case .preciseAndNote:    return 1.2
            case .preciseAndPhoto:   return 1.2
            case .preciseNotePhoto:  return 1.3
            }
        }

        var badgeLabel: String? {
            switch self {
            case .none:              return nil
            case .precise:           return "🎯 精准XP+10%"
            case .withNote:          return "📝 备注XP+10%"
            case .withPhoto:         return "📷 照片XP+10%"
            case .preciseAndNote:    return "🎯📝 XP+20%"
            case .preciseAndPhoto:   return "🎯📷 XP+20%"
            case .preciseNotePhoto:  return "✨ 完整记录XP+30%"
            }
        }

        /// 根据 3 个维度布尔值智能组合
        static func compose(precise: Bool, hasNote: Bool, hasPhoto: Bool) -> QualityBonus {
            switch (precise, hasNote, hasPhoto) {
            case (true,  true,  true):  return .preciseNotePhoto
            case (true,  false, true):  return .preciseAndPhoto
            case (true,  true,  false): return .preciseAndNote
            case (false, false, true):  return .withPhoto
            case (false, true,  false): return .withNote
            case (true,  false, false): return .precise
            default:                    return .none
            }
        }
    }

    // MARK: - 核心分发方法（新版，接受 OhanaActionType）
    /// - Parameters:
    ///   - type: OhanaActionType，携带奖励规则
    ///   - pet: 关联宠物（可空）
    ///   - context: ModelContext，用于 fetch Human 并 save
    @discardableResult
    func awardAction(
        type: OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QualityBonus = .none
    ) -> (humanGot: Int, petGot: Int) {
        if pet?.hasPassedAway == true {
            lastEconomyRewardResult = .empty
            return (0, 0)
        }

        // ── 1. 人类账户（从 context fetch，安全降级）
        var human: Human? = nil
        let humanIdStr = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        if let hid = humanIdStr {
            let desc = FetchDescriptor<Human>()
            human = (try? context.fetch(desc))?.first(where: { $0.id.uuidString == hid })
            if human == nil {
                print("⚠️ [QuestManager] humanId=\(hid) 在 context 中找不到，跳过人类分润")
            }
        }

        let consumesBoost = UserDefaults.standard.bool(forKey: "shop_boostDoubleActive")
        let isCoolingDown = isOnCooldown(petId: pet?.id, type: type)
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: pet)
        let result = CoconutEconomyPolicyV2.reward(
            for: type,
            quality: quality,
            isOnCooldown: isCoolingDown,
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            hasPetAccount: pet != nil,
            forcedLuck: consumesBoost ? .golden : nil
        )
        lastEconomyRewardResult = result

        let finalHuman = result.humanCoconuts
        let finalPet = result.petCoconuts
        // ── 2. 钱包流水（拆分：宠物和人类各生成独立条目）
        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        var baseTitle = type.title(pet: pet)
        if let badge = quality.badgeLabel {
            baseTitle += " · \(badge)"
        }
        if result.luck != .none {
            baseTitle += result.luck == .golden ? " · 金色幸运" : " · 小幸运"
        }

        var walletDeltas: [CoconutWalletDelta] = []
        if let p = pet, finalPet > 0 {
            walletDeltas.append(.pet(
                p,
                delta: finalPet,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: logEmoji,
                actorId: p.id.uuidString,
                actorName: p.name,
                subjectKind: .pet,
                subjectId: p.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }
        if let h = human, finalHuman > 0 {
            walletDeltas.append(.human(
                h,
                delta: finalHuman,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: "🥥",
                actorId: h.id.uuidString,
                actorName: h.name,
                subjectKind: .human,
                subjectId: h.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

        // ── 3. 持久化（同一个 ModelContext 事务）
        do {
            try CoconutWalletService.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: false
            )
            try context.save()
            if consumesBoost {
                UserDefaults.standard.removeObject(forKey: "shop_boostDoubleActive")
            }
            EconomyDailyBudgetStore.commit(result, householdKey: budgetKeys.household, memberKey: budgetKeys.member, careObjectKeys: objectKeys)
            flushToDefaults()
            postEconomyFeedback(result, type: type, title: baseTitle, actorId: pet?.id.uuidString ?? human?.id.uuidString, actorName: pet?.name ?? human?.name)
            if case .walk = type, let humanId = human?.id.uuidString {
                recordWalkRewardToday(finalHuman, humanId: humanId)
            }
            // 记录冷却时间戳（持久化成功后才记录；冷却内补记不延长窗口）
            if !isCoolingDown {
                recordCooldown(petId: pet?.id, type: type)
            }
            // TASK C: 检查 Streak 里程碑奖励
            if let pet { StreakRewardManager.shared.checkAndAward(pet: pet) }
        } catch {
            context.rollback()
            CoconutWalletService.refreshQuestProjection(context: context)
            #if DEBUG
            print("❌ [QuestManager] SwiftData save 失败，已回滚: \(error.localizedDescription)")
            #endif
        }
        return (finalHuman, finalPet)
    }

    /// 多宠共同照护奖励：人类奖励只发一次，每只在世目标宠物各自获得成长椰子。
    @MainActor
    @discardableResult
    func awardSharedCareAction(
        type: OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QualityBonus = .none,
        title: String? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let livePets = pets.filter { !$0.hasPassedAway }
        guard !livePets.isEmpty else { return (0, 0) }

        var human: Human?
        let humanIdStr = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        if let hid = humanIdStr {
            human = (try? context.fetch(FetchDescriptor<Human>()))?.first { $0.id.uuidString == hid }
        }

        let consumesBoost = UserDefaults.standard.bool(forKey: "shop_boostDoubleActive")
        let isCoolingDown = livePets.allSatisfy { isOnCooldown(petId: $0.id, type: type) }
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: livePets)
        let result = CoconutEconomyPolicyV2.sharedReward(
            for: type,
            targetCount: livePets.count,
            quality: quality,
            isOnCooldown: isCoolingDown,
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            forcedLuck: consumesBoost ? .golden : nil
        )
        lastEconomyRewardResult = result

        let petAwards = Self.distribute(result.petCoconuts, count: livePets.count)

        let petTotal = petAwards.reduce(0, +)
        let humanTotal = human == nil ? 0 : result.humanCoconuts

        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        let petNames = livePets.prefix(3).map(\.name).joined(separator: "、") + (livePets.count > 3 ? " 等\(livePets.count)只" : "")
        var sharedTitle = title ?? "共同照护 · \(petNames)"
        if result.luck != .none {
            sharedTitle += result.luck == .golden ? " · 金色幸运" : " · 小幸运"
        }

        var walletDeltas: [CoconutWalletDelta] = []
        for (index, pet) in livePets.enumerated() where petAwards[index] > 0 {
            walletDeltas.append(.pet(
                pet,
                delta: petAwards[index],
                entryKind: .reward,
                source: .careEvent,
                title: sharedTitle,
                emoji: logEmoji,
                actorId: pet.id.uuidString,
                actorName: pet.name,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }
        if let human, humanTotal > 0 {
            walletDeltas.append(.human(
                human,
                delta: humanTotal,
                entryKind: .reward,
                source: .careEvent,
                title: result.luck == .golden ? "金色幸运共同照护奖励" : "共同照护奖励",
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

        do {
            try CoconutWalletService.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: false
            )
            try context.save()
            if consumesBoost {
                UserDefaults.standard.removeObject(forKey: "shop_boostDoubleActive")
            }
            EconomyDailyBudgetStore.commit(result, householdKey: budgetKeys.household, memberKey: budgetKeys.member, careObjectKeys: objectKeys)
            flushToDefaults()
            postEconomyFeedback(
                result,
                type: type,
                title: sharedTitle,
                actorId: human?.id.uuidString ?? livePets.first?.id.uuidString,
                actorName: human?.name ?? livePets.first?.name
            )
            livePets.forEach { pet in
                if !isOnCooldown(petId: pet.id, type: type) {
                    recordCooldown(petId: pet.id, type: type)
                }
                StreakRewardManager.shared.checkAndAward(pet: pet)
            }
        } catch {
            context.rollback()
            CoconutWalletService.refreshQuestProjection(context: context)
            #if DEBUG
            print("❌ [QuestManager] shared care save failed: \(error.localizedDescription)")
            #endif
        }

        return (humanTotal, petTotal)
    }

    // MARK: - 旧版兼容方法（addCoconuts / awardAction with allHumans）
    // 这些方法仍保留，内部调用不再触发个人账户分润，仅用于无上下文场景（如首日登录奖励）

    /// 仅更新全岛总库（用于无实体关联的全局奖励）
    func addCoconuts(_ amount: Int, emoji: String = "🥥", title: String = "打卡奖励", reason: String? = nil,
                      actorId: String? = nil, actorName: String? = nil) {
        lastEconomyRewardResult = nil
        let finalTitle = reason ?? title
        guard amount != 0 else { return }
        let context = ModelContext(SharedModelContainer.make())
        do {
            try CoconutWalletService.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: finalTitle,
                actorId: actorId,
                actorName: actorName,
                entryKind: amount > 0 ? .reward : .spend,
                source: .service,
                context: context,
                save: true
            )
        } catch {
            appendLog(CoconutLogEntry(emoji: emoji, title: finalTitle, amount: amount,
                                      actorId: actorId, actorName: actorName))
            coconutCount = max(0, coconutCount + amount)
            #if DEBUG
            print("❌ [QuestManager] coconut wallet add failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// 记录确定金额的椰子变动，不触发暴击、双倍券或质量加成。用于商店消费、兑换退款等经济账。
    func recordCoconutDelta(
        _ amount: Int,
        emoji: String = "🥥",
        title: String,
        actorId: String? = nil,
        actorName: String? = nil,
        postsRewardFeedback: Bool = true
    ) {
        guard amount != 0 else { return }
        let context = ModelContext(SharedModelContainer.make())
        do {
            try CoconutWalletService.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
                entryKind: amount > 0 ? .refund : .spend,
                source: .service,
                context: context,
                save: true,
                postsRewardFeedback: postsRewardFeedback
            )
        } catch {
            coconutCount = max(0, coconutCount + amount)
            appendLog(
                CoconutLogEntry(
                    emoji: emoji,
                    title: title,
                    amount: amount,
                    actorId: actorId,
                    actorName: actorName
                ),
                postsRewardFeedback: postsRewardFeedback
            )
            #if DEBUG
            print("❌ [QuestManager] coconut wallet delta failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// 旧版签名兼容；内部映射到新规则。
    func awardAction(
        type: ActionType,
        amount: Int,
        pet: Pet? = nil,
        humanId: String? = nil,
        allHumans: [Human] = []
    ) {
        let human: Human? = humanId.flatMap { hid in allHumans.first { $0.id.uuidString == hid } }
        let aId   = human?.id.uuidString ?? pet?.id.uuidString
        let aName = human?.name ?? pet?.name

        // 映射旧规则：全岛总库只加「实际到账」部分
        let humanGet: Int
        let petGet: Int
        switch type {
        case .walk, .feed, .water:
            humanGet = amount; petGet = amount
        case .litter:
            humanGet = amount; petGet = 0
        case .potty, .general:
            humanGet = 0; petGet = 0
        }

        let islandDelta = (petGet > 0 && pet != nil ? petGet : 0)
                        + (humanGet > 0 && human != nil ? humanGet : 0)
        let fallback    = (islandDelta == 0) ? amount : 0  // potty/general 无实体时保底给全岛

        let titleStr: String
        let emojiStr = type.emoji
        switch type {
        case .walk:    titleStr = "\(pet?.name ?? "") 遛狗奖励"
        case .feed:    titleStr = "\(pet?.name ?? "") 喂食奖励"
        case .litter:  titleStr = "\(pet?.name ?? "") 铲屎奖励"
        case .potty:   titleStr = "\(pet?.name ?? "") 便便打卡"
        case .water:   titleStr = "\(pet?.name ?? "") 喂水奖励"
        case .general: titleStr = "打卡奖励"
        }
        let context = ModelContext(SharedModelContainer.make())
        do {
            if let pet, petGet > 0 {
                try CoconutWalletService.applyActorDelta(
                    amount: petGet,
                    emoji: emojiStr,
                    title: titleStr,
                    actorId: pet.id.uuidString,
                    actorName: pet.name,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false
                )
            }
            if let human, humanGet > 0 {
                try CoconutWalletService.applyActorDelta(
                    amount: humanGet,
                    emoji: emojiStr,
                    title: titleStr,
                    actorId: human.id.uuidString,
                    actorName: human.name,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false
                )
            }
            if fallback != 0 {
                try CoconutWalletService.applyActorDelta(
                    amount: fallback,
                    emoji: emojiStr,
                    title: titleStr,
                    actorId: aId,
                    actorName: aName,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false
                )
            }
            try context.save()
            if petGet > 0 { pet?.coconutBalance += petGet }
            if humanGet > 0 { human?.coconutBalance += humanGet }
        } catch {
            context.rollback()
            CoconutWalletService.refreshQuestProjection(context: context)
            appendLog(CoconutLogEntry(emoji: emojiStr, title: titleStr, amount: islandDelta + fallback,
                                      actorId: aId, actorName: aName))
            coconutCount = max(0, coconutCount + islandDelta + fallback)
            #if DEBUG
            print("❌ [QuestManager] legacy award wallet write failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - 批量打卡（任务三）

    /// 对多只宠物执行同一类型的打卡，合并计算椰子奖励，统一写一次 CoconutLogEntry
    /// - Parameters:
    ///   - type:    打卡类型（如 .feed / .water / .potty(isLitter:false) 等）
    ///   - pets:    目标宠物数组（跳过已离世的宠物）
    ///   - context: ModelContext，用于写 PetCareLog 和 save
    /// - Returns:   (totalHuman, totalPet) 合并后的总发放椰子数
    @MainActor
    @discardableResult
    func batchAward(
        type: OhanaActionType,
        pets: [Pet],
        context: ModelContext
    ) -> (totalHuman: Int, totalPet: Int) {
        guard !pets.isEmpty else { return (0, 0) }

        let livePets = pets.filter { !$0.hasPassedAway }
        guard !livePets.isEmpty else { return (0, 0) }

        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        var human: Human? = nil
        if let executorId {
            human = (try? context.fetch(FetchDescriptor<Human>()))?.first(where: { $0.id.uuidString == executorId })
        }
        let consumesBoost = UserDefaults.standard.bool(forKey: "shop_boostDoubleActive")
        let isCoolingDown = livePets.allSatisfy { isOnCooldown(petId: $0.id, type: type) }
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: livePets)
        let result = CoconutEconomyPolicyV2.sharedReward(
            for: type,
            targetCount: livePets.count,
            quality: .none,
            isOnCooldown: isCoolingDown,
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            forcedLuck: consumesBoost ? .golden : nil
        )
        lastEconomyRewardResult = result
        let petAwards = Self.distribute(result.petCoconuts, count: livePets.count)
        let humanTotal = human == nil ? 0 : result.humanCoconuts

        // ── 1. 写 PetCareLog（每只宠物独立一条）
        let careTypeEnum: CareType?
        switch type {
        case .feed:   careTypeEnum = .feeding
        case .water:  careTypeEnum = .watering
        case .general(_, _, _, let t) where t.contains("铲砂") || t.contains("铲屎"):
            careTypeEnum = .litter
        case .general(_, _, _, let t) where t.contains("陪玩") || t.contains("逗玩"):
            careTypeEnum = .play
        default:      careTypeEnum = nil
        }

        for pet in livePets {
            if let ct = careTypeEnum {
                let log = PetCareLog(type: ct, pet: pet, executorId: executorId)
                context.insert(log)
            } else if case .potty = type {
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: executorId)
                context.insert(log)
            }
        }

        // ── 2. 钱包账户（人类只发一次，不乘以宠物数量）
        let petTotal = petAwards.reduce(0, +)

        // ── 3. 钱包流水
        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        let petNames = livePets.prefix(3).map(\.name).joined(separator: "、")
            + (livePets.count > 3 ? " 等\(livePets.count)只" : "")
        var baseTitle = "一键全家\(type.emoji) · \(petNames)"
        if result.luck != .none {
            baseTitle += result.luck == .golden ? " · 金色幸运" : " · 小幸运"
        }
        var walletDeltas: [CoconutWalletDelta] = []
        for (index, pet) in livePets.enumerated() where petAwards[index] > 0 {
            walletDeltas.append(.pet(
                pet,
                delta: petAwards[index],
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: logEmoji,
                actorId: pet.id.uuidString,
                actorName: pet.name,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }
        if let human, humanTotal > 0 {
            walletDeltas.append(.human(
                human,
                delta: humanTotal,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

        // ── 4. 持久化
        do {
            try CoconutWalletService.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: false
            )
            try context.save()
            if consumesBoost {
                UserDefaults.standard.removeObject(forKey: "shop_boostDoubleActive")
            }
            EconomyDailyBudgetStore.commit(result, householdKey: budgetKeys.household, memberKey: budgetKeys.member, careObjectKeys: objectKeys)
            livePets.forEach { pet in
                if !isOnCooldown(petId: pet.id, type: type) {
                    recordCooldown(petId: pet.id, type: type)
                }
                StreakRewardManager.shared.checkAndAward(pet: pet)
            }
            flushToDefaults()
            postEconomyFeedback(
                result,
                type: type,
                title: baseTitle,
                actorId: human?.id.uuidString ?? "batch",
                actorName: human?.name ?? "全家打卡"
            )
        } catch {
            context.rollback()
            CoconutWalletService.refreshQuestProjection(context: context)
            #if DEBUG
            print("❌ [batchAward] save 失败: \(error)")
            #endif
        }

        // 震动反馈
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return (humanTotal, petTotal)
    }

    private func postEconomyFeedback(
        _ result: EconomyRewardResult,
        type: OhanaActionType,
        title: String,
        actorId: String?,
        actorName: String?
    ) {
        guard result.growthXP > 0 || result.totalCoconuts > 0 else { return }
        let entry = CoconutLogEntry(
            emoji: result.luck == .golden ? "🎁" : type.emoji,
            title: result.feedbackMessage.isEmpty ? title : result.feedbackMessage,
            amount: result.totalCoconuts,
            actorId: actorId,
            actorName: actorName,
            growthXP: result.growthXP,
            economyReason: result.reason,
            budgetStage: result.budgetStage.rawValue,
            feedbackMessage: result.feedbackMessage
        )
        NotificationCenter.default.post(
            name: .ohanaCoconutRewardEvent,
            object: OhanaCoconutRewardEvent(entry: entry)
        )
    }

    private func appendLog(_ entry: CoconutLogEntry, postsRewardFeedback: Bool = true) {
        coconutLogs.insert(entry, at: 0)
        if coconutLogs.count > 200 { coconutLogs = Array(coconutLogs.prefix(200)) }
        if (entry.amount > 0 || (entry.growthXP ?? 0) > 0), postsRewardFeedback {
            NotificationCenter.default.post(
                name: .ohanaCoconutRewardEvent,
                object: OhanaCoconutRewardEvent(entry: entry)
            )
        }
        NotificationCenter.default.post(name: NSNotification.Name("coconutCountChanged"), object: nil)
        // 日志写入延迟到 flushToDefaults() 中一并执行
    }

    private static func distribute(_ total: Int, count: Int) -> [Int] {
        guard total > 0, count > 0 else { return Array(repeating: 0, count: max(0, count)) }
        let base = total / count
        let remainder = total % count
        return (0..<count).map { index in
            base + (index < remainder ? 1 : 0)
        }
    }

    func makeLedgerAudit(pets: [Pet], humans: [Human]) -> CoconutLedgerAudit {
        CoconutLedgerAudit.evaluate(
            islandCount: coconutCount,
            logs: coconutLogs,
            petBalances: pets.map(\.coconutBalance),
            humanBalances: humans.map(\.coconutBalance)
        )
    }

    /// 完成喂食任务时调用（第一次记录喂食）
    func recordFirstMeal() {
        guard !isFirstMealRecorded else { return }
        isFirstMealRecorded = true
        addCoconuts(15, emoji: "🍖", title: "首次喜食打卡奖励")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 完成主题颜色设置任务时调用
    func recordThemeColorSet() {
        guard !isThemeColorSet else { return }
        isThemeColorSet = true
        addCoconuts(10, emoji: "🎨", title: "设置家人主题色")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - 人宠联动奖励

    /// 主人每日步数达标奖励（≥8000步 → +10椰子）
    /// 幂等：同一天只发放一次
    /// 返回值：是否成功发放（true 表示本次触发了奖励）
    @discardableResult
    func recordDailyStepGoal(steps: Int, goal: Int = 8000) -> Bool {
        guard steps >= goal else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = Self.defaults.object(forKey: Keys.stepRewardDate) as? Date
        if let last = lastDate, Calendar.current.isDate(last, inSameDayAs: today) {
            return false // 今天已发放
        }
        Self.defaults.set(today, forKey: Keys.stepRewardDate)
        addCoconuts(10, emoji: "🚶", title: "今日步数达标奖励")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    /// 人宠同步行走联动奖励（主人步数距离 ≥ 宠物当日遛狗距离，解锁「同甘共苦」）
    /// 幂等：同一天只发放一次
    /// - Parameter humanDistanceKm: 主人今日 HealthKit 步行距离
    /// - Parameter petWalkDistanceKm: 宠物今日遛狗距离之和
    /// 返回值：是否成功触发联动
    @discardableResult
    func recordBondedWalk(humanDistanceKm: Double, petWalkDistanceKm: Double) -> Bool {
        guard petWalkDistanceKm > 0.1, humanDistanceKm >= petWalkDistanceKm else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = Self.defaults.object(forKey: Keys.bondedDate) as? Date
        if let last = lastDate, Calendar.current.isDate(last, inSameDayAs: today) {
            return false // 今天已触发
        }
        Self.defaults.set(today, forKey: Keys.bondedDate)
        addCoconuts(5, emoji: "🐾", title: "人宠同行奖励")
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        return true
    }

    // MARK: - task38: 打卡 → 自动完成今日同类型 Reminder（不重复发椰子）

    /// 打卡后调用：在 modelContext 里查找今日该宠物匹配类型的 pending Reminder，标记为 completed
    /// - Parameters:
    ///   - petId: 宠物 UUID
    ///   - careType: 打卡类型关键词（如 "喂食" "喂水" "铲屎" "遛"）
    ///   - context: SwiftData ModelContext
    func autoCompleteReminders(petId: UUID, careKeyword: String, context: ModelContext) {
        let petIdStr = petId.uuidString
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        // 查找今日所有 Reminder
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { r in
                r.status == "pending" &&
                r.scheduledAt >= today &&
                r.scheduledAt < tomorrow
            }
        )
        guard let reminders = try? context.fetch(descriptor) else { return }
        // 找到关联该宠物且标题包含关键词的 Event -> Reminder
        for reminder in reminders {
            guard let event = reminder.event,
                  event.relatedEntityId == petIdStr,
                  (event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet") else { continue }
            let title = event.title
            let keyword = careKeyword
            guard title.contains(keyword) else { continue }
            reminder.statusEnum = .completed
            reminder.completedAt = Date()
        }
        try? context.save()
    }

    /// 查询今日步数奖励是否已领取
    var hasReceivedStepRewardToday: Bool {
        guard let lastDate = Self.defaults.object(forKey: Keys.stepRewardDate) as? Date else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// 查询今日人宠联动奖励是否已领取
    var hasReceivedBondedRewardToday: Bool {
        guard let lastDate = Self.defaults.object(forKey: Keys.bondedDate) as? Date else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }
}
