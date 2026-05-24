//
//  WaterCareCycleStatus.swift
//  Ohana
//
//  Shared due/overdue calculation for water-change and filter cycles.
//

import Foundation

struct WaterCareCycleStatus {
    let elapsedDays: Int
    let intervalDays: Int

    var daysUntilDue: Int {
        intervalDays - elapsedDays
    }

    var isDueToday: Bool {
        daysUntilDue == 0
    }

    var isOverdue: Bool {
        daysUntilDue < 0
    }

    var overdueDays: Int {
        max(0, -daysUntilDue)
    }

    var compactDueText: String {
        if daysUntilDue > 0 { return "\(daysUntilDue)天" }
        if daysUntilDue == 0 { return "今天" }
        return "逾期\(overdueDays)天"
    }
}

enum WaterCareCycleStatusCalculator {
    static func waterChangeStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let defaults = UserDefaults.standard
        let interval = max(defaults.integer(forKey: "waterInterval_\(key)") == 0 ? 3 : defaults.integer(forKey: "waterInterval_\(key)"), 1)
        let anchorTimestamp = defaults.double(forKey: "waterChangeCycleAnchor_\(key)")
        let anchorDate = anchorTimestamp > 0 ? Date(timeIntervalSince1970: anchorTimestamp) : nil
        let latestLogDate = latestCareLogDate(for: pet, type: .waterChange)

        guard let baseDate = latestLogDate ?? anchorDate else {
            return nil
        }

        return WaterCareCycleStatus(
            elapsedDays: elapsedDays(from: baseDate, to: now, calendar: calendar),
            intervalDays: interval
        )
    }

    static func filterCleanStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let defaults = UserDefaults.standard
        let interval = max(defaults.integer(forKey: "filterCleanInterval_\(key)") == 0 ? 14 : defaults.integer(forKey: "filterCleanInterval_\(key)"), 1)
        guard let latestLogDate = latestCareLogDate(for: pet, type: .filterClean) else {
            return nil
        }

        return WaterCareCycleStatus(
            elapsedDays: elapsedDays(from: latestLogDate, to: now, calendar: calendar),
            intervalDays: interval
        )
    }

    static func filterReplaceStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let defaults = UserDefaults.standard
        let interval = max(defaults.integer(forKey: "filterReplaceInterval_\(key)") == 0 ? 90 : defaults.integer(forKey: "filterReplaceInterval_\(key)"), 1)
        guard let latestLogDate = latestCareLogDate(for: pet, type: .filterClean) else {
            return nil
        }

        return WaterCareCycleStatus(
            elapsedDays: elapsedDays(from: latestLogDate, to: now, calendar: calendar),
            intervalDays: interval
        )
    }

    static func mostUrgentWaterWarning(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (title: String, status: WaterCareCycleStatus)? {
        let warnings: [(String, WaterCareCycleStatus)] = [
            waterChangeStatus(for: pet, now: now, calendar: calendar).map { ("换水", $0) },
            filterCleanStatus(for: pet, now: now, calendar: calendar).map { ("滤芯", $0) },
            filterReplaceStatus(for: pet, now: now, calendar: calendar).map { ("更换", $0) }
        ].compactMap { $0 }
            .filter { $0.1.isOverdue }

        return warnings.sorted { $0.1.daysUntilDue < $1.1.daysUntilDue }.first
    }

    private static func latestCareLogDate(for pet: Pet, type: CareType) -> Date? {
        pet.careLogs
            .filter { $0.type == type.rawValue }
            .max(by: { $0.date < $1.date })?
            .date
    }

    private static func elapsedDays(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
    }
}
