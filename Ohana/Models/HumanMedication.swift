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

    nonisolated var isManualEntry: Bool {
        self == .asNeeded || self == .custom
    }

    nonisolated var emoji: String {
        switch self {
        case .daily: return "☀️"
        case .twiceDaily: return "🌅"
        case .threeTimesDaily: return "🕐"
        case .weekly: return "📅"
        case .asNeeded: return "⚡"
        case .custom: return "⚙️"
        }
    }

    nonisolated func displayTitle(l: L10n) -> String {
        switch self {
        case .daily:
            return l.tr(zh: "每天", en: "Daily", de: "Täglich")
        case .twiceDaily:
            return l.tr(zh: "每天两次", en: "Twice daily", de: "Zweimal täglich")
        case .threeTimesDaily:
            return l.tr(zh: "每天三次", en: "Three times daily", de: "Dreimal täglich")
        case .weekly:
            return l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
        case .asNeeded:
            return l.tr(zh: "按需", en: "As needed", de: "Nach Bedarf")
        case .custom:
            return l.tr(zh: "自定义", en: "Custom", de: "Benutzerdefiniert")
        }
    }
}

nonisolated struct HumanMedicationScheduleMetadata: Hashable {
    static let markerPrefix = "[[ohana-human-medication-schedule:"
    static let markerSuffix = "]]"

    var doseMinutes: [Int]
    var weeklyWeekday: Int?

    init(doseMinutes: [Int], weeklyWeekday: Int? = nil) {
        self.doseMinutes = Self.normalizedDoseMinutes(doseMinutes)
        self.weeklyWeekday = weeklyWeekday.flatMap { (1...7).contains($0) ? $0 : nil }
    }

    static func normalizedDoseMinutes(_ values: [Int]) -> [Int] {
        Array(Set(values.map { (($0 % 1440) + 1440) % 1440 })).sorted()
    }

    static func visibleNotes(from notes: String) -> String {
        notes
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(markerPrefix) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func composeNotes(visibleNotes: String, metadata: HumanMedicationScheduleMetadata?) -> String {
        let visible = Self.visibleNotes(from: visibleNotes)
        guard let metadata, !metadata.doseMinutes.isEmpty else { return visible }
        let hidden = metadata.hiddenLine
        if visible.isEmpty { return hidden }
        return visible + "\n" + hidden
    }

    static func parse(from notes: String) -> HumanMedicationScheduleMetadata? {
        for rawLine in notes.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(markerPrefix), line.hasSuffix(markerSuffix) else { continue }
            let start = line.index(line.startIndex, offsetBy: markerPrefix.count)
            let end = line.index(line.endIndex, offsetBy: -markerSuffix.count)
            guard start <= end else { continue }
            let payload = String(line[start..<end])
            return Self.parsePayload(payload)
        }
        return nil
    }

    private static func parsePayload(_ payload: String) -> HumanMedicationScheduleMetadata? {
        var minutes: [Int] = []
        var weekday: Int?
        for part in payload.split(separator: ";").map(String.init) {
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { continue }
            switch pieces[0] {
            case "times":
                minutes = pieces[1]
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            case "weekday":
                weekday = Int(pieces[1].trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                continue
            }
        }
        guard !minutes.isEmpty else { return nil }
        return HumanMedicationScheduleMetadata(doseMinutes: minutes, weeklyWeekday: weekday)
    }

    private var hiddenLine: String {
        var payload = "times=" + doseMinutes.map(String.init).joined(separator: ",")
        if let weeklyWeekday {
            payload += ";weekday=\(weeklyWeekday)"
        }
        return Self.markerPrefix + payload + Self.markerSuffix
    }
}

nonisolated enum HumanMedicationDisplayGroup: String {
    case current
    case notStarted
    case ended
    case stopped
    case manual
}

nonisolated struct HumanMedicationScheduleDose: Identifiable, Hashable {
    let medication: HumanMedication
    let scheduledTime: Date
    let doseIndex: Int

    var id: String {
        let minuteKey = Int(scheduledTime.timeIntervalSince1970 / 60)
        return "\(medication.id.uuidString)-\(minuteKey)-\(doseIndex)"
    }
}

nonisolated enum HumanMedicationSchedulePlan {
    static func minuteOfDay(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func date(on day: Date, minuteOfDay: Int, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minuteOfDay, to: start)
    }

    static func defaultDoseMinutes(for frequency: MedicationFrequency) -> [Int] {
        switch frequency {
        case .daily, .weekly:
            return [8 * 60]
        case .twiceDaily:
            return [8 * 60, 20 * 60]
        case .threeTimesDaily:
            return [8 * 60, 14 * 60, 20 * 60]
        case .asNeeded, .custom:
            return []
        }
    }

    static func legacyDoseMinutes(for medication: HumanMedication, calendar: Calendar = .current) -> [Int] {
        let dosesPerDay = medication.frequency.dosesPerDay
        guard dosesPerDay > 0 else { return [] }
        let firstMinute = minuteOfDay(from: medication.firstDoseTime, calendar: calendar)
        let interval = 1440 / dosesPerDay
        return HumanMedicationScheduleMetadata.normalizedDoseMinutes((0..<dosesPerDay).map { firstMinute + $0 * interval })
    }

    static func doseMinutes(for medication: HumanMedication, calendar: Calendar = .current) -> [Int] {
        if let metadata = HumanMedicationScheduleMetadata.parse(from: medication.notes),
           !metadata.doseMinutes.isEmpty {
            return metadata.doseMinutes
        }
        return legacyDoseMinutes(for: medication, calendar: calendar)
    }

    static func doses(on day: Date, for medication: HumanMedication, calendar: Calendar = .current) -> [HumanMedicationScheduleDose] {
        guard medication.isActive, !medication.frequency.isManualEntry else { return [] }

        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: medication.startDate)
        guard dayStart >= start else { return [] }
        if let endDate = medication.endDate, dayStart > calendar.startOfDay(for: endDate) {
            return []
        }

        if medication.frequency == .weekly {
            let weekday = calendar.component(.weekday, from: dayStart)
            if let metadataWeekday = HumanMedicationScheduleMetadata.parse(from: medication.notes)?.weeklyWeekday {
                guard weekday == metadataWeekday else { return [] }
            } else {
                let daysSinceStart = calendar.dateComponents([.day], from: start, to: dayStart).day ?? 0
                guard daysSinceStart % 7 == 0 else { return [] }
            }
        }

        return doseMinutes(for: medication, calendar: calendar).enumerated().compactMap { index, minute in
            guard let scheduled = date(on: dayStart, minuteOfDay: minute, calendar: calendar) else { return nil }
            return HumanMedicationScheduleDose(medication: medication, scheduledTime: scheduled, doseIndex: index)
        }
    }

    static func doses(on day: Date, medications: [HumanMedication], calendar: Calendar = .current) -> [HumanMedicationScheduleDose] {
        medications
            .flatMap { doses(on: day, for: $0, calendar: calendar) }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    static func futureDoses(for medication: HumanMedication, from now: Date = Date(), days: Int = 14, calendar: Calendar = .current) -> [HumanMedicationScheduleDose] {
        guard days > 0 else { return [] }
        let start = calendar.startOfDay(for: now)
        return (0..<days).flatMap { offset -> [HumanMedicationScheduleDose] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return [] }
            return doses(on: day, for: medication, calendar: calendar)
        }
        .filter { $0.scheduledTime > now }
        .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    static func plannedDoseCount(on day: Date, medications: [HumanMedication], calendar: Calendar = .current) -> Int {
        doses(on: day, medications: medications, calendar: calendar).count
    }

    static func displayGroup(for medication: HumanMedication, now: Date = Date(), calendar: Calendar = .current) -> HumanMedicationDisplayGroup {
        if !medication.isActive { return .stopped }
        let today = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: medication.startDate) { return .notStarted }
        if let endDate = medication.endDate, today > calendar.startOfDay(for: endDate) { return .ended }
        if medication.frequency.isManualEntry { return .manual }
        return .current
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
