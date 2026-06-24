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
        compactDueText(l: .current)
    }

    func compactDueText(l: L10n = .current) -> String {
        if daysUntilDue > 0 {
            return l.tr(zh: "\(daysUntilDue)天", en: "\(daysUntilDue)d", de: "\(daysUntilDue) T.")
        }
        if daysUntilDue == 0 {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        return l.tr(zh: "逾期\(overdueDays)天", en: "\(overdueDays)d overdue", de: "\(overdueDays) T. überfällig")
    }
}

nonisolated struct WaterCareCycleLogSnapshot: Equatable {
    let latestWaterChangeDate: Date?
    let latestFilterCleanDate: Date?

    static let empty = WaterCareCycleLogSnapshot(
        latestWaterChangeDate: nil,
        latestFilterCleanDate: nil
    )
}

nonisolated enum WaterCareCycleStatusCalculator {
    static func waterChangeStatus(
        for pet: Pet,
        now: Date = Date(),
        calendar: Calendar = .current,
        logSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let settings = WaterCareSettingsStore.snapshot(petKey: key, now: now, calendar: calendar)
        let anchorDate = settings.createdWaterChangeAnchor ? nil : settings.waterChangeAnchorDate
        let latestLogDate = if let logSnapshot {
            logSnapshot.latestWaterChangeDate
        } else {
            latestCareLogDate(for: pet, type: .waterChange)
        }

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
        calendar: Calendar = .current,
        logSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let latestLogDate = if let logSnapshot {
            logSnapshot.latestFilterCleanDate
        } else {
            latestCareLogDate(for: pet, type: .filterClean)
        }
        guard let latestLogDate else {
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
        calendar: Calendar = .current,
        logSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> WaterCareCycleStatus? {
        let key = pet.id.uuidString
        let latestLogDate = if let logSnapshot {
            logSnapshot.latestFilterCleanDate
        } else {
            latestCareLogDate(for: pet, type: .filterClean)
        }
        guard let latestLogDate else {
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
        calendar: Calendar = .current,
        logSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> (title: String, status: WaterCareCycleStatus)? {
        let warnings: [(String, WaterCareCycleStatus)] = [
            waterChangeStatus(for: pet, now: now, calendar: calendar, logSnapshot: logSnapshot).map { ("换水", $0) },
            filterCleanStatus(for: pet, now: now, calendar: calendar, logSnapshot: logSnapshot).map { ("滤芯", $0) },
            filterReplaceStatus(for: pet, now: now, calendar: calendar, logSnapshot: logSnapshot).map { ("更换", $0) }
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
