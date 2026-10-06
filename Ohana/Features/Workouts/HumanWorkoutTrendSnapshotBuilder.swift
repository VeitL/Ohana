//
//  HumanWorkoutTrendSnapshotBuilder.swift
//  Ohana
//
//  Pure value policy for bounded Human workout history and trends.
//

import Foundation

nonisolated enum HumanWorkoutHistoryPeriod: Int, CaseIterable, Hashable, Identifiable, Sendable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90

    var id: Int { rawValue }
    var dayCount: Int { rawValue }

    var queryLimit: Int {
        switch self {
        case .sevenDays: 96
        case .thirtyDays: 256
        case .ninetyDays: 512
        }
    }

    var healthKitQueryLimit: Int {
        switch self {
        case .sevenDays: 64
        case .thirtyDays: 128
        case .ninetyDays: 256
        }
    }

    func startDate(containing now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
    }
}

nonisolated enum HumanWorkoutHistorySource: Equatable, Sendable {
    case ohanaLocal
    case storedAppleHealth
    case petWalk
    case liveAppleHealth
    case matchedPetWalkAndAppleHealth

    var isDurableOhanaHistory: Bool {
        switch self {
        case .ohanaLocal, .storedAppleHealth, .petWalk, .matchedPetWalkAndAppleHealth:
            true
        case .liveAppleHealth:
            false
        }
    }

    var includesPetWalk: Bool {
        self == .petWalk || self == .matchedPetWalkAndAppleHealth
    }

    var includesLiveAppleHealth: Bool {
        self == .liveAppleHealth || self == .matchedPetWalkAndAppleHealth
    }
}

nonisolated enum HumanWorkoutHistoryReadState: Equatable, Sendable {
    case loading
    case complete
    case truncated
    case unavailable
    case notIncluded

    var isComplete: Bool {
        self == .complete || self == .notIncluded
    }

    var isLoading: Bool {
        self == .loading
    }
}

nonisolated struct HumanWorkoutHistoryCoverage: Equatable, Sendable {
    let local: HumanWorkoutHistoryReadState
    let petWalk: HumanWorkoutHistoryReadState
    let healthKit: HumanWorkoutHistoryReadState

    static let complete = HumanWorkoutHistoryCoverage(
        local: .complete,
        petWalk: .complete,
        healthKit: .complete
    )

    var isComplete: Bool {
        local.isComplete && petWalk.isComplete && healthKit.isComplete
    }

    var isLoading: Bool {
        local.isLoading || petWalk.isLoading || healthKit.isLoading
    }
}

nonisolated struct HumanWorkoutTrendSample: Equatable, Identifiable, Sendable {
    let id: String
    let date: Date
    let durationMinutes: Int
    let distanceKm: Double
    let source: HumanWorkoutHistorySource
}

nonisolated enum HumanWorkoutTrendDirection: Equatable, Sendable {
    case unavailable
    case rising
    case steady
    case falling
}

nonisolated struct HumanWorkoutDurationTrend: Equatable, Sendable {
    let direction: HumanWorkoutTrendDirection
    let changePercent: Int?

    static let unavailable = HumanWorkoutDurationTrend(direction: .unavailable, changePercent: nil)
}

nonisolated struct HumanWorkoutTrendSnapshot: Equatable, Sendable {
    let coverage: HumanWorkoutHistoryCoverage
    let visibleSampleCount: Int
    let totalDurationMinutes: Int
    let totalDistanceKm: Double
    let activeDayCount: Int
    let durableRecordCount: Int
    let petWalkCount: Int
    let liveAppleHealthCount: Int
    let durationTrend: HumanWorkoutDurationTrend

    var averageMinutesPerActiveDay: Int {
        guard activeDayCount > 0 else { return 0 }
        return Int((Double(totalDurationMinutes) / Double(activeDayCount)).rounded())
    }
}

nonisolated enum HumanWorkoutTrendSnapshotBuilder {
    static func make(
        samples: [HumanWorkoutTrendSample],
        period: HumanWorkoutHistoryPeriod,
        now: Date,
        coverage: HumanWorkoutHistoryCoverage = .complete,
        calendar: Calendar = .current
    ) -> HumanWorkoutTrendSnapshot {
        let start = period.startDate(containing: now, calendar: calendar)
        let visible = samples.filter { $0.date >= start && $0.date <= now }
        let durable = visible.filter(\.source.isDurableOhanaHistory)
        let activeDays = Set(visible.map { calendar.startOfDay(for: $0.date) }).count

        return HumanWorkoutTrendSnapshot(
            coverage: coverage,
            visibleSampleCount: visible.count,
            totalDurationMinutes: visible.reduce(0) { $0 + max(0, $1.durationMinutes) },
            totalDistanceKm: visible.reduce(0) { $0 + max(0, $1.distanceKm) },
            activeDayCount: activeDays,
            durableRecordCount: durable.count,
            petWalkCount: visible.count(where: \.source.includesPetWalk),
            liveAppleHealthCount: visible.count(where: \.source.includesLiveAppleHealth),
            durationTrend: coverage.isComplete
                ? durationTrend(
                    durableSamples: durable,
                    period: period,
                    start: start,
                    now: now,
                    calendar: calendar
                )
                : .unavailable
        )
    }

    private static func durationTrend(
        durableSamples: [HumanWorkoutTrendSample],
        period: HumanWorkoutHistoryPeriod,
        start: Date,
        now: Date,
        calendar: Calendar
    ) -> HumanWorkoutDurationTrend {
        guard !durableSamples.isEmpty else { return .unavailable }

        let earlierDayCount = max(1, period.dayCount / 2)
        let recentDayCount = max(1, period.dayCount - earlierDayCount)
        let recentStart = calendar.date(byAdding: .day, value: earlierDayCount, to: start) ?? start
        let earlierMinutes = durableSamples
            .filter { $0.date < recentStart }
            .reduce(0) { $0 + max(0, $1.durationMinutes) }
        let recentMinutes = durableSamples
            .filter { $0.date >= recentStart && $0.date <= now }
            .reduce(0) { $0 + max(0, $1.durationMinutes) }
        let earlierDailyAverage = Double(earlierMinutes) / Double(earlierDayCount)
        let recentDailyAverage = Double(recentMinutes) / Double(recentDayCount)

        guard earlierDailyAverage > 0 else {
            return recentDailyAverage > 0
                ? HumanWorkoutDurationTrend(direction: .rising, changePercent: nil)
                : .unavailable
        }

        let percent = Int((((recentDailyAverage / earlierDailyAverage) - 1) * 100).rounded())
        let direction: HumanWorkoutTrendDirection = switch percent {
        case 5...: .rising
        case ...(-5): .falling
        default: .steady
        }
        return HumanWorkoutDurationTrend(direction: direction, changePercent: percent)
    }
}
