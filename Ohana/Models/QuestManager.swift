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

    init(emoji: String, title: String, amount: Int, date: Date = Date(),
         actorId: String? = nil, actorName: String? = nil) {
        self.id = UUID()
        self.emoji = emoji
        self.title = title
        self.amount = amount
        self.date = date
        self.actorId = actorId
        self.actorName = actorName
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

@Observable
final class QuestManager {

    // MARK: - Singleton
    static let shared = QuestManager()

    // MARK: - Persisted State（存储属性，@Observable 可追踪）
    // 不再使用 didSet 自动写入 UserDefaults，改为显式 flushToDefaults() 保证原子性
    var coconutCount: Int = 0

    // 椰子收支明细（最近 200 条）
    var coconutLogs: [CoconutLogEntry] = []

    var isPetWizardCompleted: Bool = false
    var isFirstMealRecorded: Bool = false
    var isThemeColorSet: Bool = false

    // MARK: - Flush（原子写入 UserDefaults）
    /// 将内存状态一次性写入 UserDefaults，确保和 SwiftData save 同步
    func flushToDefaults() {
        Self.defaults.set(coconutCount, forKey: Keys.coconut)
        Self.defaults.set(isPetWizardCompleted, forKey: Keys.petWizard)
        Self.defaults.set(isFirstMealRecorded, forKey: Keys.firstMeal)
        Self.defaults.set(isThemeColorSet, forKey: Keys.themeColor)
        if let data = try? JSONEncoder().encode(coconutLogs) {
            Self.defaults.set(data, forKey: Keys.coconutLogs)
        }
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
        case general(humanReward: Int, petReward: Int, emoji: String, title: String)

        /// 基础奖励（未暴击时）
        var baseRewards: (human: Int, pet: Int) {
            switch self {
            case .walk(let d):
                let v = max(1, Int(d / 100))
                return (v, v)
            case .potty(let isLitter):
                return isLitter ? (5, 8) : (2, 5)
            case .feed:
                return (2, 3)
            case .water:
                return (2, 3)
            case .care(let t):
                switch t {
                case .bath:     return (15, 10)
                case .teeth:    return (8, 5)
                case .nails:    return (8, 5)
                case .brushing: return (5, 4)
                case .ears:     return (6, 5)
                }
            case .health:
                return (20, 20)
            case .expense:
                return (10, 0)
            case .weight:
                return (5, 5)
            case .milestone:
                return (50, 50)
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
            case .general(_, _, let e, _): return e
            }
        }

        func title(pet: Pet?) -> String {
            let n = pet?.name ?? ""
            switch self {
            case .walk:    return "\(n) 遛狗奖励"
            case .potty(let l): return "\(n) \(l ? "铲猫砂奖励" : "便便打卡")"
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

    // MARK: - 暴击引擎（内部）
    private struct CritResult {
        let multiplier: Int   // 1 / 2 / 5
        let isCrit: Bool
        let title: String
    }

    private func rollCrit() -> CritResult {
        let roll = Int.random(in: 1...100)
        switch roll {
        case 99...100:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            return CritResult(multiplier: 5, isCrit: true, title: "👑 奇迹发生！主子赏的大红包！")
        case 90...98:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return CritResult(multiplier: 2, isCrit: true, title: "🎉 触发幸运暴击！")
        default:
            return CritResult(multiplier: 1, isCrit: false, title: "")
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
        context: ModelContext
    ) -> (humanGot: Int, petGot: Int) {
        // ── 冷却检查：冷却期内返回 (0,0)，数据层已在上层写入
        if isOnCooldown(petId: pet?.id, type: type) {
            return (0, 0)
        }

        let base = type.baseRewards
        let crit = rollCrit()

        let finalHuman = base.human * crit.multiplier
        let finalPet   = base.pet   * crit.multiplier

        // ── 1. 宠物账户
        if finalPet > 0 { pet?.coconutBalance += finalPet }

        // ── 2. 人类账户（从 context fetch，安全降级）
        var human: Human? = nil
        let humanIdStr = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        if let hid = humanIdStr {
            let desc = FetchDescriptor<Human>()
            human = (try? context.fetch(desc))?.first(where: { $0.id.uuidString == hid })
            if human == nil {
                print("⚠️ [QuestManager] humanId=\(hid) 在 context 中找不到，跳过人类分润")
            }
        }
        if finalHuman > 0 { human?.coconutBalance += finalHuman }

        // ── 3. 全岛总库 = pet 到账 + human 到账（严格一致）
        let islandDelta = (finalPet > 0 && pet != nil ? finalPet : 0)
                        + (finalHuman > 0 && human != nil ? finalHuman : 0)
        if islandDelta > 0 { coconutCount += islandDelta }

        // ── 4. 日志（拆分：宠物和人类各生成独立条目）
        let logEmoji = crit.isCrit && crit.multiplier == 5 ? "🎁" : type.emoji
        let baseTitle = crit.isCrit ? crit.title : type.title(pet: pet)

        if let p = pet, finalPet > 0 {
            appendLog(CoconutLogEntry(
                emoji: logEmoji,
                title: baseTitle,
                amount: finalPet,
                actorId: p.id.uuidString,
                actorName: p.name
            ))
        }
        if let h = human, finalHuman > 0 {
            appendLog(CoconutLogEntry(
                emoji: "🥥",
                title: crit.isCrit ? crit.title : "协助奖励",
                amount: finalHuman,
                actorId: h.id.uuidString,
                actorName: h.name
            ))
        }
        // 无实体的全局奖励（如仅 expense 且无 pet）写入 system 桶
        if pet == nil && human == nil && (finalPet + finalHuman) > 0 {
            appendLog(CoconutLogEntry(
                emoji: logEmoji,
                title: baseTitle,
                amount: finalPet + finalHuman,
                actorId: "system",
                actorName: "岛屿奖励"
            ))
        }

        // ── 5. 持久化（先存 SwiftData，成功后再 flush UserDefaults）
        do {
            try context.save()
            flushToDefaults()
            // 记录冷却时间戳（持久化成功后才记录）
            recordCooldown(petId: pet?.id, type: type)
            // TASK C: 检查 Streak 里程碑奖励
            if let pet { StreakRewardManager.shared.checkAndAward(pet: pet) }
        } catch {
            // SwiftData 保存失败 → 回滚内存状态防止坏账
            if finalPet > 0 { pet?.coconutBalance -= finalPet }
            if finalHuman > 0 { human?.coconutBalance -= finalHuman }
            coconutCount -= islandDelta
            // 移除刚插入的日志
            if !coconutLogs.isEmpty { coconutLogs.removeFirst() }
            #if DEBUG
            print("❌ [QuestManager] SwiftData save 失败，已回滚: \(error.localizedDescription)")
            #endif
        }
        return (finalHuman, finalPet)
    }

    // MARK: - 旧版兼容方法（addCoconuts / awardAction with allHumans）
    // 这些方法仍保留，内部调用不再触发个人账户分润，仅用于无上下文场景（如首日登录奖励）

    /// 仅更新全岛总库（用于无实体关联的全局奖励）
    func addCoconuts(_ amount: Int, emoji: String = "🥥", title: String = "打卡奖励", reason: String? = nil,
                      actorId: String? = nil, actorName: String? = nil) {
        guard amount > 0 else {
            coconutCount += amount
            appendLog(CoconutLogEntry(emoji: emoji, title: reason ?? title, amount: amount,
                                      actorId: actorId, actorName: actorName))
            flushToDefaults()
            return
        }
        let crit = rollCrit()
        var finalAmount = amount * crit.multiplier
        var finalTitle  = crit.isCrit ? crit.title : (reason ?? title)
        var finalEmoji  = crit.isCrit && crit.multiplier == 5 ? "🎁" : emoji
        // boost_double: 双倍椰子券激活时额外 ×2，消耗一次
        if UserDefaults.standard.bool(forKey: "shop_boostDoubleActive") {
            finalAmount *= 2
            finalTitle   = "⚡️双倍券激活！" + finalTitle
            finalEmoji   = "⚡️"
            UserDefaults.standard.removeObject(forKey: "shop_boostDoubleActive")
        }
        coconutCount += finalAmount
        appendLog(CoconutLogEntry(emoji: finalEmoji, title: finalTitle, amount: finalAmount,
                                  actorId: actorId, actorName: actorName))
        flushToDefaults()
    }

    /// 旧版签名兼容（OverviewView 等已用 allHumans 的调用点）—— 内部映射到新规则
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

        if petGet > 0   { pet?.coconutBalance += petGet }
        if humanGet > 0 { human?.coconutBalance += humanGet }
        let islandDelta = (petGet > 0 && pet != nil ? petGet : 0)
                        + (humanGet > 0 && human != nil ? humanGet : 0)
        let fallback    = (islandDelta == 0) ? amount : 0  // potty/general 无实体时保底给全岛
        coconutCount += islandDelta + fallback

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
        appendLog(CoconutLogEntry(emoji: emojiStr, title: titleStr, amount: islandDelta + fallback,
                                  actorId: aId, actorName: aName))
        flushToDefaults()
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

        let base = type.baseRewards
        let crit = rollCrit()
        let finalHuman = base.human * crit.multiplier   // 人只发一次
        let finalPetEach = base.pet * crit.multiplier   // 每只宠物各发一次

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
                let log = PetCareLog(type: ct, pet: pet)
                context.insert(log)
            } else if case .potty = type {
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet)
                context.insert(log)
            }
            // 更新宠物椰子账户
            pet.coconutBalance += finalPetEach
        }

        // ── 2. 人类账户（只发一次，不乘以宠物数量）
        var human: Human? = nil
        let humanIdStr = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        if let hid = humanIdStr {
            human = (try? context.fetch(FetchDescriptor<Human>()))?.first(where: { $0.id.uuidString == hid })
        }
        if finalHuman > 0 { human?.coconutBalance += finalHuman }

        // ── 3. 全岛总库
        let petTotal = finalPetEach * livePets.count
        let islandDelta = petTotal + (human != nil ? finalHuman : 0)
        if islandDelta > 0 { coconutCount += islandDelta }

        // ── 4. 一条合并日志
        let logEmoji = crit.isCrit && crit.multiplier == 5 ? "🎁" : type.emoji
        let petNames = livePets.prefix(3).map(\.name).joined(separator: "、")
            + (livePets.count > 3 ? " 等\(livePets.count)只" : "")
        let baseTitle = crit.isCrit ? crit.title : "一键全家\(type.emoji) · \(petNames)"
        appendLog(CoconutLogEntry(
            emoji: logEmoji,
            title: baseTitle,
            amount: islandDelta,
            actorId: human?.id.uuidString ?? "batch",
            actorName: human?.name ?? "全家打卡"
        ))

        // ── 5. 持久化
        do {
            try context.save()
            flushToDefaults()
        } catch {
            // 回滚
            livePets.forEach { $0.coconutBalance -= finalPetEach }
            human?.coconutBalance -= finalHuman
            coconutCount -= islandDelta
            if !coconutLogs.isEmpty { coconutLogs.removeFirst() }
            #if DEBUG
            print("❌ [batchAward] save 失败: \(error)")
            #endif
        }

        // 震动反馈
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return (finalHuman, petTotal)
    }

    private func appendLog(_ entry: CoconutLogEntry) {
        coconutLogs.insert(entry, at: 0)
        if coconutLogs.count > 200 { coconutLogs = Array(coconutLogs.prefix(200)) }
        // 日志写入延迟到 flushToDefaults() 中一并执行
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
                  event.relatedEntityType == "pet" else { continue }
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
