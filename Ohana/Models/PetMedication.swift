//
//  PetMedication.swift
//  Ohana
//
//  ArkSchemaV24：宠物用药计划模型
//  参考 HumanMedication.swift 设计，去除 humanId，关联 Pet
//

import Foundation
import SwiftData
import SwiftUI

/// 宠物用药频率
enum PetMedicationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "每天"
    case twiceDaily = "每天两次"
    case threeTimesDaily = "每天三次"
    case everyOtherDay = "隔天"
    case weekly = "每周"
    case asNeeded = "按需"
    case custom = "自定义"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .daily: "☀️"
        case .twiceDaily: "🌅"
        case .threeTimesDaily: "🕐"
        case .everyOtherDay: "📆"
        case .weekly: "📅"
        case .asNeeded: "⚡"
        case .custom: "⚙️"
        }
    }
}

enum PetMedicationSchedulePlan {
    private static let doseMinutesPrefix = "doseMinutes="

    static func dosesPerDay(for frequency: PetMedicationFrequency) -> Int {
        switch frequency {
        case .daily, .everyOtherDay, .weekly:
            1
        case .twiceDaily:
            2
        case .threeTimesDaily:
            3
        case .asNeeded, .custom:
            0
        }
    }

    static func defaultDoseMinutes(for frequency: PetMedicationFrequency) -> [Int] {
        switch frequency {
        case .daily, .everyOtherDay, .weekly:
            [8 * 60]
        case .twiceDaily:
            [8 * 60, 20 * 60]
        case .threeTimesDaily:
            [8 * 60, 14 * 60, 20 * 60]
        case .asNeeded, .custom:
            []
        }
    }

    static func encodeDoseMinutes(_ minutes: [Int]) -> String {
        let normalized = minutes
            .map { min(max($0, 0), 23 * 60 + 59) }
            .sorted()
        guard !normalized.isEmpty else { return "" }
        return doseMinutesPrefix + normalized.map(String.init).joined(separator: ",")
    }

    static func decodeDoseMinutes(from note: String) -> [Int] {
        guard let range = note.range(of: doseMinutesPrefix) else { return [] }
        let raw = note[range.upperBound...]
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first ?? ""
        return raw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .map { min(max($0, 0), 23 * 60 + 59) }
            .sorted()
    }

    static func doseMinutes(for medication: PetMedication, required: Int? = nil) -> [Int] {
        let targetCount = required ?? dosesPerDay(for: medication.frequency)
        guard targetCount > 0 else { return [] }

        let saved = decodeDoseMinutes(from: medication.customFrequencyNote)
        let base = saved.isEmpty ? defaultDoseMinutes(for: medication.frequency) : saved
        return normalizedDoseMinutes(base, count: targetCount, frequency: medication.frequency)
    }

    static func normalizedDoseMinutes(_ minutes: [Int], count: Int, frequency: PetMedicationFrequency) -> [Int] {
        guard count > 0 else { return [] }
        var result = minutes
            .map { min(max($0, 0), 23 * 60 + 59) }
            .sorted()
        let defaults = defaultDoseMinutes(for: frequency)
        while result.count < count {
            let fallback = defaults.indices.contains(result.count) ? defaults[result.count] : (8 * 60 + result.count * 360)
            result.append(min(fallback, 23 * 60 + 59))
        }
        if result.count > count {
            result = Array(result.prefix(count))
        }
        return result.sorted()
    }
}

@Model
final class PetMedication {
    var id: UUID
    var name: String // 药品名称，如"阿莫西林"
    var dosage: String // 剂量，如"1 片"、"5ml"
    var frequencyRaw: String // PetMedicationFrequency.rawValue
    var customFrequencyNote: String // 自定义频率说明
    var startDate: Date
    var endDate: Date? // nil = 长期服药
    var colorHex: String // 卡片颜色标签
    var notes: String
    var isActive: Bool
    var remainingAmount: Double = 0
    var createdAt: Date
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    @Relationship(inverse: \Pet.medications) var pet: Pet?

    init(
        name: String = "",
        dosage: String = "",
        frequency: PetMedicationFrequency = .daily,
        startDate: Date = Date(),
        endDate: Date? = nil,
        colorHex: String = "4ECDC4",
        notes: String = "",
        remainingAmount: Double = 0,
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
        self.remainingAmount = max(0, remainingAmount)
        self.createdAt = Date()
        self.pet = pet
    }

    var frequency: PetMedicationFrequency {
        get { PetMedicationFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    func isActive(on date: Date) -> Bool {
        guard isActive else { return false }
        if date < startDate { return false }
        if let end = endDate, date > end { return false }
        return true
    }

    var isActiveToday: Bool {
        isActive(on: Date())
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
