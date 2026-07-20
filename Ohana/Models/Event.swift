//
//  Event.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

// MARK: - Event Types
enum EventType: String, Codable, CaseIterable, Identifiable, Sendable {
    // 通用
    case birthday = "生日"
    case anniversary = "纪念日"
    case daily = "日常"
    case health = "健康"
    case task = "任务"
    case shoppingList = "购物清单"
    case chore = "家务分配"
    // 宠物
    case vaccine = "疫苗"
    case externalDeworming = "体外驱虫"
    case internalDeworming = "体内驱虫"
    case grooming = "洗澡美容"
    case vetVisit = "就医"
    case foodChange = "换粮"
    case litterBox = "铲猫砂"
    // 植物
    case watering = "浇水"
    case fertilizing = "施肥"
    case plantRepotting = "植物换盆"
    case plantPruning = "植物修剪"
    case plantMisting = "植物喷雾"
    case plantRotation = "植物转盆"
    case plantLeafCleaning = "清洁叶片"
    case plantPestCheck = "病虫害检查"
    case plantHealthCheck = "植物状态记录"
    // 人类专用
    case medication = "吃药"
    /// 宠物用药计划（关联类型由 `DomainEntityLinkRegistry` 统一注册）
    case petMedication = "宠物用药"
    /// 宠物用药单次打卡（关联类型由 `DomainEntityLinkRegistry` 统一注册）
    case petMedicationDose = "宠物喂药打卡"
    /// 保险缴费提醒（关联类型由 `DomainEntityLinkRegistry` 统一注册）
    case insurancePremium = "保险缴费"

    var id: String { rawValue }

    nonisolated var emoji: String {
        switch self {
        case .birthday: "🎂"
        case .anniversary: "💝"
        case .daily: "📋"
        case .health: "❤️"
        case .task: "✅"
        case .shoppingList: "🛒"
        case .chore: "🏠"
        case .vaccine: "💉"
        case .externalDeworming: "🛡️"
        case .internalDeworming: "💊"
        case .grooming: "🛁"
        case .vetVisit: "🏥"
        case .foodChange: "🍽️"
        case .litterBox: "🧹"
        case .watering: "💧"
        case .fertilizing: "🌿"
        case .plantRepotting: "🪴"
        case .plantPruning: "✂️"
        case .plantMisting: "💦"
        case .plantRotation: "🔄"
        case .plantLeafCleaning: "🍃"
        case .plantPestCheck: "🔎"
        case .plantHealthCheck: "📝"
        case .medication: "💊"
        case .petMedication: "💊"
        case .petMedicationDose: "💊"
        case .insurancePremium: "🛡️"
        }
    }

    /// 日历周条 / 事件行：纯色剪影 SF Symbol
    nonisolated var silhouetteSymbol: String {
        switch self {
        case .birthday: "gift.fill"
        case .anniversary: "heart.fill"
        case .daily: "calendar"
        case .health: "heart.text.square.fill"
        case .task: "checkmark.circle.fill"
        case .shoppingList: "cart.fill"
        case .chore: "house.fill"
        case .vaccine: "syringe.fill"
        case .externalDeworming, .internalDeworming: "pills.fill"
        case .grooming: "shower.fill"
        case .vetVisit: "cross.case.fill"
        case .foodChange: "fork.knife"
        case .litterBox: "trash.fill"
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .plantRepotting: "tree.fill"
        case .plantPruning: "scissors"
        case .plantMisting: "humidity.fill"
        case .plantRotation: "arrow.triangle.2.circlepath"
        case .plantLeafCleaning: "leaf.fill"
        case .plantPestCheck: "magnifyingglass"
        case .plantHealthCheck: "note.text"
        case .medication, .petMedication, .petMedicationDose: "pill.fill"
        case .insurancePremium: "shield.fill"
        }
    }

    nonisolated func localizedLabel(_ l: L10n) -> String {
        switch self {
        case .birthday:
            l.tr(zh: "生日", en: "Birthday", de: "Geburtstag")
        case .anniversary:
            l.tr(zh: "纪念日", en: "Anniversary", de: "Jahrestag")
        case .daily:
            l.tr(zh: "日常", en: "Daily", de: "Alltag")
        case .health:
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .task:
            l.tr(zh: "任务", en: "Task", de: "Aufgabe")
        case .shoppingList:
            l.tr(zh: "购物清单", en: "Shopping list", de: "Einkaufsliste")
        case .chore:
            l.tr(zh: "家务分配", en: "Chore", de: "Haushalt")
        case .vaccine:
            l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung")
        case .externalDeworming:
            l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .internalDeworming:
            l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .grooming:
            l.tr(zh: "洗澡美容", en: "Grooming", de: "Pflege")
        case .vetVisit:
            l.tr(zh: "就医", en: "Vet visit", de: "Tierarzt")
        case .foodChange:
            l.tr(zh: "换粮", en: "Food change", de: "Futterwechsel")
        case .litterBox:
            l.tr(zh: "铲猫砂", en: "Litter box", de: "Katzenklo")
        case .watering:
            l.tr(zh: "浇水", en: "Watering", de: "Gießen")
        case .fertilizing:
            l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen")
        case .plantRepotting:
            l.tr(zh: "植物换盆", en: "Repotting", de: "Umtopfen")
        case .plantPruning:
            l.tr(zh: "植物修剪", en: "Pruning", de: "Schneiden")
        case .plantMisting:
            l.tr(zh: "植物喷雾", en: "Misting", de: "Besprühen")
        case .plantRotation:
            l.tr(zh: "植物转盆", en: "Rotate plant", de: "Pflanze drehen")
        case .plantLeafCleaning:
            l.tr(zh: "清洁叶片", en: "Leaf cleaning", de: "Blätter reinigen")
        case .plantPestCheck:
            l.tr(zh: "病虫害检查", en: "Pest check", de: "Schädlingscheck")
        case .plantHealthCheck:
            l.tr(zh: "植物状态记录", en: "Plant status", de: "Pflanzenstatus")
        case .medication:
            l.tr(zh: "吃药", en: "Medication", de: "Medikament")
        case .petMedication:
            l.tr(zh: "宠物用药", en: "Pet medication", de: "Tiermedikation")
        case .petMedicationDose:
            l.tr(zh: "宠物喂药打卡", en: "Pet medication dose", de: "Tiermedikation erfasst")
        case .insurancePremium:
            l.tr(zh: "保险缴费", en: "Insurance premium", de: "Versicherungsbeitrag")
        }
    }
}

@Model
final class Event {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var isAllDay: Bool
    var eventType: String
    var relatedEntityType: String
    var relatedEntityId: String
    var recurrenceDays: Int
    var recurrenceEndDate: Date?
    var isCompleted: Bool
    var completedOccurrences: [String]
    var createdAt: Date
    var assigneeId: String? // 模块4：指派给谁 (Human.id.uuidString)
    var taskCareKindRaw: String = ""
    var feedRuleKindRaw: String = ""
    var foodKindRaw: String = FeedFoodKind.dry.rawValue
    var feedAmountGrams: Double = 0
    var feedPlanGroupId: String = ""
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    @Relationship(deleteRule: .cascade) var reminders: [Reminder]

    init(
        title: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        isAllDay: Bool = false,
        eventType: String = EventType.daily.rawValue,
        relatedEntityType: String = "",
        relatedEntityId: String = "",
        taskCareKindRaw: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.eventType = eventType
        self.relatedEntityType = relatedEntityType
        self.relatedEntityId = relatedEntityId
        self.taskCareKindRaw = taskCareKindRaw
        self.recurrenceDays = 0
        self.recurrenceEndDate = nil
        self.isCompleted = false
        self.completedOccurrences = []
        self.createdAt = Date()
        self.assigneeId = nil
        self.feedRuleKindRaw = ""
        self.foodKindRaw = FeedFoodKind.dry.rawValue
        self.feedAmountGrams = 0
        self.feedPlanGroupId = ""
        self.reminders = []
    }

    var eventTypeEnum: EventType? {
        EventType(rawValue: eventType)
    }

    var feedRuleKind: FeedRuleKind? {
        FeedRuleKind(rawValue: feedRuleKindRaw)
    }

    var foodKind: FeedFoodKind {
        FeedFoodKind(rawValue: foodKindRaw) ?? .dry
    }

    var emoji: String {
        eventTypeEnum?.emoji ?? "📌"
    }

    /// 列表 / 周条图标：关键词优先，否则按事件类型剪影
    var silhouetteListSymbol: String {
        let t = title.lowercased()
        if t.contains("喂") || t.contains("feed") || t.contains("吃") { return "fork.knife" }
        if t.contains("遛") || t.contains("walk") || t.contains("巡岛") { return "figure.walk" }
        if t.contains("便") || t.contains("铲") || t.contains("potty") { return "drop.fill" }
        if t.contains("疫苗") || t.contains("医") || t.contains("health") { return "cross.case.fill" }
        if t.contains("洗") || t.contains("澡") || t.contains("bath") { return "shower.fill" }
        if t.contains("梳") || t.contains("剪") || t.contains("groom") { return "scissors" }
        if t.contains("生日") || t.contains("周年") || t.contains("纪念") { return "gift.fill" }
        if t.contains("水") || t.contains("喝") { return "drop.fill" }
        return eventTypeEnum?.silhouetteSymbol ?? "calendar"
    }

    // 判断该事件是否是需要用户去"完成"的行动任务
    // 生日、纪念日属于信息事件，永不显示为逾期，也不出现在待办列表
    var isActionableTask: Bool {
        let informationalTypes: [String] = [
            EventType.birthday.rawValue,
            EventType.anniversary.rawValue
        ]
        return !informationalTypes.contains(eventType)
    }

    // MARK: - 重复序列：按「发生日」完成 / 逾期（completedOccurrences 存 startOfDay 的 timeInterval1970 字符串）

    static func occurrenceStorageKey(for day: Date) -> String {
        String(Int(Calendar.current.startOfDay(for: day).timeIntervalSince1970))
    }

    func isOccurrenceMarkedComplete(on occurrenceDay: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: occurrenceDay)
        if recurrenceDays > 0 {
            return completedOccurrences.contains(Self.occurrenceStorageKey(for: day))
        }
        return isCompleted
    }

    func setOccurrenceMarkedComplete(_ complete: Bool, on occurrenceDay: Date) {
        let day = Calendar.current.startOfDay(for: occurrenceDay)
        if recurrenceDays > 0 {
            let key = Self.occurrenceStorageKey(for: day)
            if complete {
                if !completedOccurrences.contains(key) { completedOccurrences.append(key) }
            } else {
                completedOccurrences.removeAll { $0 == key }
            }
        } else {
            isCompleted = complete
        }
    }

    func toggleOccurrenceComplete(on occurrenceDay: Date) {
        setOccurrenceMarkedComplete(!isOccurrenceMarkedComplete(on: occurrenceDay), on: occurrenceDay)
    }

    /// 将 `source` 的时/分/秒合并到「发生日」当天（用于重复日程在某一日的具体时刻）
    static func dateMergingTime(from source: Date, ontoOccurrenceDay occurrenceDay: Date) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: occurrenceDay)
        let p = cal.dateComponents([.hour, .minute, .second], from: source)
        return cal.date(bySettingHour: p.hour ?? 0, minute: p.minute ?? 0, second: p.second ?? 0, of: base) ?? base
    }

    /// 当前这条「发生」是否已逾期（仅行动类事件；单次与重复均按 occurrenceDay 语义）
    func isOverdue(on occurrenceDay: Date, now: Date = Date()) -> Bool {
        guard isActionableTask else { return false }
        let cal = Calendar.current

        if recurrenceDays <= 0 {
            if isAllDay {
                let lastDay = endDate.map { cal.startOfDay(for: $0) } ?? cal.startOfDay(for: startDate)
                return lastDay < cal.startOfDay(for: now)
            }
            if let end = endDate { return end < now }
            return startDate < now
        }

        if isAllDay {
            return cal.startOfDay(for: occurrenceDay) < cal.startOfDay(for: now)
        }

        let occStart = Self.dateMergingTime(from: startDate, ontoOccurrenceDay: occurrenceDay)
        if let end = endDate, cal.isDate(startDate, inSameDayAs: end) {
            let occEnd = Self.dateMergingTime(from: end, ontoOccurrenceDay: occurrenceDay)
            return occEnd < now
        }
        return occStart < now
    }
}
