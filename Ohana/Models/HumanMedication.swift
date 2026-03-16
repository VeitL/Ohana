//
//  HumanMedication.swift
//  Ohana
//

import SwiftUI
import SwiftData
import Foundation

/// 服药频率
enum MedicationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "每天"
    case twiceDaily = "每天两次"
    case threeTimesDaily = "每天三次"
    case weekly = "每周"
    case asNeeded = "按需"
    case custom = "自定义"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .daily: return "☀️"
        case .twiceDaily: return "🌅"
        case .threeTimesDaily: return "🕐"
        case .weekly: return "📅"
        case .asNeeded: return "⚡"
        case .custom: return "⚙️"
        }
    }
}

/// 人类吃药提醒模型
@Model
final class HumanMedication {
    var id: UUID
    /// 所属的 Human
    var humanId: String
    /// 药品名称
    var name: String
    /// 剂量描述，如 "1 片"、"5mg"
    var dosage: String
    /// 频率 rawValue
    var frequencyRaw: String
    /// 自定义频率说明（频率为 .custom 时使用）
    var customFrequencyNote: String
    /// 第一次服药时间（用于确定每天的服药时刻）
    var firstDoseTime: Date
    /// 开始日期
    var startDate: Date
    /// 结束日期（nil 表示长期）
    var endDate: Date?
    /// 颜色标签（hex string）
    var colorHex: String
    /// 备注
    var notes: String
    /// 是否激活提醒
    var isActive: Bool
    var createdAt: Date

    init(
        humanId: String,
        name: String = "",
        dosage: String = "",
        frequency: MedicationFrequency = .daily,
        firstDoseTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        colorHex: String = "FF4757",
        notes: String = ""
    ) {
        self.id = UUID()
        self.humanId = humanId
        self.name = name
        self.dosage = dosage
        self.frequencyRaw = frequency.rawValue
        self.customFrequencyNote = ""
        self.firstDoseTime = firstDoseTime
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.notes = notes
        self.isActive = true
        self.createdAt = Date()
    }

    var frequency: MedicationFrequency {
        get { MedicationFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    /// 今天是否在服药周期内
    var isActiveToday: Bool {
        guard isActive else { return false }
        let now = Date()
        if now < startDate { return false }
        if let end = endDate, now > end { return false }
        return true
    }

    /// 距结束还有几天（nil 表示长期）
    var daysRemaining: Int? {
        guard let end = endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: end).day
    }
}
