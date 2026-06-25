//
//  WaterCareCycleStatus.swift
//  Ohana
//
//  Shared due/overdue calculation for water-change and filter cycles.
//

import Foundation

nonisolated struct WaterCareCycleStatus: Equatable {
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

nonisolated enum WaterCareCycleWarningKind: String, Equatable {
    case waterChange
    case filterClean
    case filterReplace

    func localizedTitle(l: L10n = .current) -> String {
        switch self {
        case .waterChange:
            l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterClean:
            l.tr(zh: "滤芯", en: "Filter", de: "Filter")
        case .filterReplace:
            l.tr(zh: "更换", en: "Replacement", de: "Wechsel")
        }
    }
}

nonisolated struct WaterCareCycleWarning: Equatable {
    let kind: WaterCareCycleWarningKind
    let status: WaterCareCycleStatus

    func localizedTitle(l: L10n = .current) -> String {
        kind.localizedTitle(l: l)
    }
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
        let latestLogDate = (logSnapshot ?? .empty).latestWaterChangeDate

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
        let latestLogDate = (logSnapshot ?? .empty).latestFilterCleanDate
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
        let latestLogDate = (logSnapshot ?? .empty).latestFilterCleanDate
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
    ) -> WaterCareCycleWarning? {
        let warnings: [WaterCareCycleWarning] = [
            waterChangeStatus(for: pet, now: now, calendar: calendar, logSnapshot: logSnapshot)
                .map { WaterCareCycleWarning(kind: .waterChange, status: $0) },
            filterCleanStatus(for: pet, now: now, calendar: calendar, logSnapshot: logSnapshot)
                .map { WaterCareCycleWarning(kind: .filterClean, status: $0) },
            filterReplaceStatus(for: pet, now: now, calendar: calendar, logSnapshot: logSnapshot)
                .map { WaterCareCycleWarning(kind: .filterReplace, status: $0) }
        ].compactMap(\.self)
            .filter(\.status.isOverdue)

        return warnings.sorted { $0.status.daysUntilDue < $1.status.daysUntilDue }.first
    }

    private static func elapsedDays(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
    }
}
