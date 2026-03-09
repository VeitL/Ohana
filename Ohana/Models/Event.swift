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

    // 判断该事件是否是需要用户去"完成"的行动任务
    // 生日、纪念日属于信息事件，永不显示为逾期，也不出现在待办列表
    var isActionableTask: Bool {
        let informationalTypes: [String] = [
            EventType.birthday.rawValue,
            EventType.anniversary.rawValue
        ]
        return !informationalTypes.contains(eventType)
    }
}
