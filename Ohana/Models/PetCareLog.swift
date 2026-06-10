//
//  PetCareLog.swift
//  Ohana
//
//  喂食 / 喂水 / 铲屎 追踪记录（V7 新增）
//

import Foundation
import SwiftData

// MARK: - Care Type
enum CareType: String, CaseIterable, Codable {
    // 基础
    case feeding = "喂食"
    case watering = "喂水"
    case litter = "铲屎"
    // 鱼类
    case waterChange = "换水"
    case filterClean = "清理滤材"
    // 鸟类
    case cageCleaning = "清理鸟笼"
    case freeFlight = "放飞互动"
    // 爬宠/其他
    case misting = "喷水保湿"
    case substrateChange = "换垫材"
    // 通用互动
    case play = "逗玩"

    var emoji: String {
        switch self {
        case .feeding: "🍽️"
        case .watering: "💧"
        case .litter: "🧹"
        case .waterChange: "🪣"
        case .filterClean: "🔧"
        case .cageCleaning: "🧺"
        case .freeFlight: "🕊️"
        case .misting: "💦"
        case .substrateChange: "🪵"
        case .play: "🎾"
        }
    }

    var systemIconName: String {
        switch self {
        case .feeding: "fork.knife"
        case .watering: "drop.fill"
        case .litter: "trash.fill"
        case .waterChange: "arrow.2.circlepath"
        case .filterClean: "sparkles"
        case .cageCleaning: "house.fill"
        case .freeFlight: "bird.fill"
        case .misting: "humidity.fill"
        case .substrateChange: "leaf.fill"
        case .play: "gamecontroller.fill"
        }
    }

    var accentColorHex: String {
        switch self {
        case .feeding: "FF8C00"
        case .watering: "00D4AA"
        case .litter: "FFF44F"
        case .waterChange: "4ECDC4"
        case .filterClean: "A78BFA"
        case .cageCleaning: "80FFEA"
        case .freeFlight: "F59E0B"
        case .misting: "00D4FF"
        case .substrateChange: "D4A574"
        case .play: "FF6B6B"
        }
    }

    var label: String { rawValue }
}

// MARK: - Model
@Model
final class PetCareLog {
    #Index<PetCareLog>([\.date])
    var id: UUID
    var date: Date
    var type: String // CareType.rawValue
    var amountGrams: Double // 仅 feeding 用（喂食克数）
    var amountMl: Double // 仅 watering 用（喂水毫升）
    var note: String
    var foodKindRaw: String = FeedFoodKind.dry.rawValue
    var treatKindRaw: String = ""
    var sharedSessionId: String = ""
    var executorId: String? // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var pet: Pet?

    init(
        date: Date = Date(),
        type: CareType = .feeding,
        amountGrams: Double = 0,
        amountMl: Double = 0,
        note: String = "",
        foodKind: FeedFoodKind = .dry,
        treatKind: FeedTreatKind? = nil,
        sharedSessionId: String = "",
        pet: Pet? = nil,
        executorId: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.type = type.rawValue
        self.amountGrams = amountGrams
        self.amountMl = amountMl
        self.note = note
        self.foodKindRaw = foodKind.rawValue
        self.treatKindRaw = treatKind?.rawValue ?? ""
        self.sharedSessionId = sharedSessionId
        self.executorId = executorId
        self.pet = pet
    }

    var careType: CareType { CareType(rawValue: type) ?? .feeding }
    var foodKind: FeedFoodKind { FeedFoodKind(rawValue: foodKindRaw) ?? .dry }
    var treatKind: FeedTreatKind? { FeedTreatKind(rawValue: treatKindRaw) }

    // MARK: - 喂食来源（手动 vs 按计划，互斥展示用）
    /// 首页/详情「按计划」打卡写入 `ohana_plan_feed:` + eventId
    static let plannedFeedNotePrefix = "ohana_plan_feed:"
    /// 首页/详情「按计划」喂水写入 `ohana_plan_water:` + eventId
    static let plannedWaterNotePrefix = "ohana_plan_water:"
    /// 首页/详情「手动记录」打卡写入
    static let manualFeedNoteMarker = "ohana_manual_feed"

    /// 是否为「按计划」产生的喂食记录
    var isPlannedFeedLogEntry: Bool {
        careType == .feeding && note.hasPrefix(Self.plannedFeedNotePrefix)
    }

    /// 是否为「自动喂食器」产生的喂食记录
    var isAutoFeedLogEntry: Bool {
        careType == .feeding && note.hasPrefix(FeedLogMetadata.autoFeedNotePrefix)
    }

    /// 是否为零食记录；零食进入摄入统计，但不扣主粮库存
    var isTreatFeedLogEntry: Bool {
        careType == .feeding && note.hasPrefix(FeedLogMetadata.treatFeedNoteMarker)
    }

    /// 是否为「手动记录」喂食（含旧数据 note 为空）
    var isManualFeedLogEntry: Bool {
        careType == .feeding && !isPlannedFeedLogEntry && !isAutoFeedLogEntry && !isTreatFeedLogEntry
    }
}

// MARK: - 首页喂食模式（与 QuickFeedDetailSheet 分段控件同步）
enum HomeFeedRecordMode: String {
    case manual
    case planned

    static func storedRaw(for petId: UUID) -> String {
        HomeFeedRecordModePreferenceStore.storedRaw(for: petId, fallback: manual.rawValue)
    }

    static func isPlanned(for petId: UUID) -> Bool {
        storedRaw(for: petId) == planned.rawValue
    }

    static func set(_ petId: UUID, mode: HomeFeedRecordMode) {
        HomeFeedRecordModePreferenceStore.set(petId, rawValue: mode.rawValue)
    }
}

// MARK: - Feed Today State
struct FeedTodayState {
    let pet: Pet
    let allEvents: [Event]
    let manualGoalCount: Int
    let careLogs: [PetCareLog]?
    let now: Date
    let calendar: Calendar

    init(
        pet: Pet,
        allEvents: [Event],
        manualGoalCount: Int,
        careLogs: [PetCareLog]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.pet = pet
        self.allEvents = allEvents
        self.manualGoalCount = max(manualGoalCount, 1)
        self.careLogs = careLogs
        self.now = now
        self.calendar = calendar
    }

    private var observedCareLogs: [PetCareLog] {
        careLogs ?? pet.careLogs
    }

    func isPlanReminderSatisfied(_ reminder: Reminder) -> Bool {
        reminder.isCompleted
    }

    var feedScheduleEvents: [Event] {
        FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).manualReminderEvents
    }

    var autoFeederEvents: [Event] {
        FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).autoFeederEvents
    }

    var todayPlanReminders: [Reminder] {
        allPlanReminders
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var allPlanReminders: [Reminder] {
        feedScheduleEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var pendingTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { ($0.isPending || $0.isFailed) && !isPlanReminderSatisfied($0) }
    }

    var missedTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { !isPlanReminderSatisfied($0) && ($0.isFailed || ($0.isPending && $0.scheduledAt < now)) }
    }

    var missedPlanReminders: [Reminder] {
        allPlanReminders.filter { !isPlanReminderSatisfied($0) && ($0.isPending || $0.isFailed) && $0.scheduledAt <= now }
    }

    var catchUpPlanReminders: [Reminder] {
        allPlanReminders.filter { FeedPlanCatchUpPolicy.isCatchUpEligible($0, now: now) }
    }

    var expiredMissedPlanReminders: [Reminder] {
        allPlanReminders.filter { FeedPlanCatchUpPolicy.isExpiredMiss($0, now: now) }
    }

    var lastExpiredPlanReminderDate: Date? {
        expiredMissedPlanReminders.map(\.scheduledAt).max()
    }

    var completedTodayPlanReminders: [Reminder] {
        todayPlanReminders.filter { isPlanReminderSatisfied($0) }
    }

    var nextPendingReminder: Reminder? {
        guard expiredMissedPlanReminders.isEmpty else { return nil }
        return catchUpPlanReminders.first ?? pendingTodayPlanReminders.first
    }

    var hasTodayPlan: Bool {
        !todayPlanReminders.isEmpty
    }

    var manualTodayLogs: [PetCareLog] {
        observedCareLogs
            .filter {
                (careLogs == nil || $0.pet?.id == pet.id) &&
                    $0.careType == .feeding &&
                    $0.isManualFeedLogEntry &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
    }

    var plannedTodayLogs: [PetCareLog] {
        observedCareLogs
            .filter {
                (careLogs == nil || $0.pet?.id == pet.id) &&
                    $0.careType == .feeding &&
                    $0.isPlannedFeedLogEntry &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
    }

    var allTodayLogs: [PetCareLog] {
        observedCareLogs
            .filter {
                (careLogs == nil || $0.pet?.id == pet.id) &&
                    $0.careType == .feeding &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
    }

    var mainFoodTodayLogs: [PetCareLog] {
        allTodayLogs.filter { FeedLogMetadata.isMainFoodLog($0) }
    }

    var treatTodayLogs: [PetCareLog] {
        allTodayLogs.filter { FeedLogMetadata.isTreatLog($0) }
    }

    var completedCount: Int {
        hasTodayPlan ? completedTodayPlanReminders.count : mainFoodTodayLogs.count
    }

    var targetCount: Int {
        hasTodayPlan ? max(todayPlanReminders.count, 1) : manualGoalCount
    }

    var progress: Double {
        min(1, Double(completedCount) / Double(targetCount))
    }

    var isComplete: Bool {
        completedCount >= targetCount
    }

    var hasOverduePlan: Bool {
        !missedPlanReminders.isEmpty
    }

    var todayFeedGrams: Double {
        allTodayLogs.reduce(0) { total, log in
            total + (log.amountGrams > 0 ? log.amountGrams : pet.dailyPortionGrams)
        }
    }

    var todayMainFoodGrams: Double {
        mainFoodTodayLogs.reduce(0) { total, log in
            total + FeedStockCalculator.effectiveMainFoodAmount(for: log, pet: pet)
        }
    }

    var todayTreatGrams: Double {
        treatTodayLogs.reduce(0) { total, log in
            total + max(0, log.amountGrams)
        }
    }
}
