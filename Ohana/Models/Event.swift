//
//  Event.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Event Types
enum EventType: String, Codable, CaseIterable, Identifiable {
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
    // 人类专用
    case medication = "吃药"
    /// 宠物用药单次打卡（关联 `relatedEntityType == "pet_medication"` + medication UUID）
    case petMedicationDose = "宠物喂药打卡"
    /// 保险缴费提醒（关联 `relatedEntityType == "pet_insurance"` + insurance UUID）
    case insurancePremium = "保险缴费"

    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .birthday: return "🎂"
        case .anniversary: return "💝"
        case .daily: return "📋"
        case .health: return "❤️"
        case .task: return "✅"
        case .shoppingList: return "🛒"
        case .chore: return "🏠"
        case .vaccine: return "💉"
        case .externalDeworming: return "🛡️"
        case .internalDeworming: return "💊"
        case .grooming: return "🛁"
        case .vetVisit: return "🏥"
        case .foodChange: return "🍽️"
        case .litterBox: return "🧹"
        case .watering: return "💧"
        case .fertilizing: return "🌿"
        case .medication: return "💊"
        case .petMedicationDose: return "💊"
        case .insurancePremium: return "🛡️"
        }
    }

    /// 日历周条 / 事件行：纯色剪影 SF Symbol
    var silhouetteSymbol: String {
        switch self {
        case .birthday: return "gift.fill"
        case .anniversary: return "heart.fill"
        case .daily: return "calendar"
        case .health: return "heart.text.square.fill"
        case .task: return "checkmark.circle.fill"
        case .shoppingList: return "cart.fill"
        case .chore: return "house.fill"
        case .vaccine: return "syringe.fill"
        case .externalDeworming, .internalDeworming: return "pills.fill"
        case .grooming: return "shower.fill"
        case .vetVisit: return "cross.case.fill"
        case .foodChange: return "fork.knife"
        case .litterBox: return "trash.fill"
        case .watering: return "drop.fill"
        case .fertilizing: return "leaf.fill"
        case .medication, .petMedicationDose: return "pill.fill"
        case .insurancePremium: return "shield.fill"
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
    var assigneeId: String?        // 模块4：指派给谁 (Human.id.uuidString)

    @Relationship(deleteRule: .cascade) var reminders: [Reminder]
    
    init(
        title: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        isAllDay: Bool = false,
        eventType: String = EventType.daily.rawValue,
        relatedEntityType: String = "",
        relatedEntityId: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.eventType = eventType
        self.relatedEntityType = relatedEntityType
        self.relatedEntityId = relatedEntityId
        self.recurrenceDays = 0
        self.recurrenceEndDate = nil
        self.isCompleted = false
        self.completedOccurrences = []
        self.createdAt = Date()
        self.assigneeId = nil
        self.reminders = []
    }
    
    var eventTypeEnum: EventType? {
        EventType(rawValue: eventType)
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
