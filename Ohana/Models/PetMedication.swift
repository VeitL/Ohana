//
//  PetMedication.swift
//  Ohana
//
//  ArkSchemaV24：宠物用药计划模型
//  参考 HumanMedication.swift 设计，去除 humanId，关联 Pet
//

import SwiftUI
import SwiftData
import Foundation

/// 宠物用药频率
enum PetMedicationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily          = "每天"
    case twiceDaily     = "每天两次"
    case threeTimesDaily = "每天三次"
    case everyOtherDay  = "隔天"
    case weekly         = "每周"
    case asNeeded       = "按需"
    case custom         = "自定义"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .daily:             return "☀️"
        case .twiceDaily:        return "🌅"
        case .threeTimesDaily:   return "🕐"
        case .everyOtherDay:     return "📆"
        case .weekly:            return "📅"
        case .asNeeded:          return "⚡"
        case .custom:            return "⚙️"
        }
    }
}

@Model
final class PetMedication {
    var id: UUID
    var name: String            // 药品名称，如"阿莫西林"
    var dosage: String          // 剂量，如"1 片"、"5ml"
    var frequencyRaw: String    // PetMedicationFrequency.rawValue
    var customFrequencyNote: String  // 自定义频率说明
    var startDate: Date
    var endDate: Date?          // nil = 长期服药
    var colorHex: String        // 卡片颜色标签
    var notes: String
    var isActive: Bool
    var createdAt: Date

    @Relationship(inverse: \Pet.medications) var pet: Pet?

    init(
        name: String = "",
        dosage: String = "",
        frequency: PetMedicationFrequency = .daily,
        startDate: Date = Date(),
        endDate: Date? = nil,
        colorHex: String = "4ECDC4",
        notes: String = "",
        pet: Pet? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.frequencyRaw = frequency.rawValue
        self.customFrequencyNote = ""
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.notes = notes
        self.isActive = true
        self.createdAt = Date()
        self.pet = pet
    }

    var frequency: PetMedicationFrequency {
        get { PetMedicationFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var isActiveToday: Bool {
        guard isActive else { return false }
        let now = Date()
        if now < startDate { return false }
        if let end = endDate, now > end { return false }
        return true
    }

    var daysRemaining: Int? {
        guard let end = endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: end).day
    }

    var statusLabel: String {
        if !isActive { return "已停用" }
        if !isActiveToday { return "未开始" }
        if let days = daysRemaining {
            return "剩 \(days) 天"
        }
        return "长期用药"
    }
}
