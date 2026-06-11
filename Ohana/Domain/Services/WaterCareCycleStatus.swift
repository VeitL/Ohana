//
//  WaterCareCycleStatus.swift
//  Ohana
//
//  Shared due/overdue calculation for water-change and filter cycles.
//

import Foundation

nonisolated struct WaterCareCycleStatus {
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

nonisolated enum WaterCareCycleStatusCalculator {
    static func waterChangeStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let settings = WaterCareSettingsStore.snapshot(petKey: key, now: now, calendar: calendar)
        let anchorDate = settings.createdWaterChangeAnchor ? nil : settings.waterChangeAnchorDate
        let latestLogDate = latestCareLogDate(for: pet, type: .waterChange)

        guard let baseDate = latestLogDate ?? anchorDate else {
            return nil
        }

        return WaterCareCycleStatus(
            elapsedDays: elapsedDays(from: baseDate, to: now, calendar: calendar),
            intervalDays: settings.waterIntervalDays
        )
    }

    static func filterCleanStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        guard let latestLogDate = latestCareLogDate(for: pet, type: .filterClean) else {
            return nil
        }

        return WaterCareCycleStatus(
            elapsedDays: elapsedDays(from: latestLogDate, to: now, calendar: calendar),
            intervalDays: WaterCareSettingsStore.filterCleanIntervalDays(petKey: key)
        )
    }

    static func filterReplaceStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        guard let latestLogDate = latestCareLogDate(for: pet, type: .filterClean) else {
            return nil
        }

        return WaterCareCycleStatus(
            elapsedDays: elapsedDays(from: latestLogDate, to: now, calendar: calendar),
            intervalDays: WaterCareSettingsStore.filterReplaceIntervalDays(petKey: key)
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
        ].compactMap(\.self)
            .filter(\.1.isOverdue)

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
