//
//  FamilyTaskRecurrenceRule.swift
//  Ohana
//
//  Pure recurrence values and occurrence generation for family task plans.
//

import Foundation

nonisolated enum FamilyTaskRecurrenceKind: String, Codable, CaseIterable, Sendable {
    case once
    case everyNDays
    case weekly
    case monthlyDay
    case monthlyLastDay
}

/// Calendar weekday values intentionally match `Calendar.Component.weekday`.
nonisolated enum FamilyTaskWeekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    fileprivate var mask: Int {
        1 << (rawValue - 1)
    }
}

nonisolated enum FamilyTaskRecurrenceRule: Codable, Equatable, Hashable, Sendable {
    case once
    case everyNDays(Int)
    case weekly(Set<FamilyTaskWeekday>)
    /// A civil day of month. Months without that day are skipped.
    case monthlyDay(Int)
    case monthlyLastDay

    var kind: FamilyTaskRecurrenceKind {
        switch self {
        case .once:
            .once
        case .everyNDays:
            .everyNDays
        case .weekly:
            .weekly
        case .monthlyDay:
            .monthlyDay
        case .monthlyLastDay:
            .monthlyLastDay
        }
    }

    var isValid: Bool {
        switch self {
        case .once:
            true
        case let .everyNDays(days):
            (1 ... 365).contains(days)
        case let .weekly(weekdays):
            !weekdays.isEmpty
        case let .monthlyDay(day):
            (1 ... 31).contains(day)
        case .monthlyLastDay:
            true
        }
    }

    var intervalDays: Int {
        guard case let .everyNDays(days) = self else { return 1 }
        return days
    }

    var weekdays: Set<FamilyTaskWeekday> {
        guard case let .weekly(weekdays) = self else { return [] }
        return weekdays
    }

    var weekdayMask: Int {
        weekdays.reduce(into: 0) { result, weekday in
            result |= weekday.mask
        }
    }

    var monthDay: Int {
        guard case let .monthlyDay(day) = self else { return 0 }
        return day
    }

    static func weekly(weekdayMask: Int) -> Self {
        .weekly(Set(FamilyTaskWeekday.allCases.filter { weekdayMask & $0.mask != 0 }))
    }
}

nonisolated struct FamilyTaskRecurrenceOccurrence: Equatable, Hashable, Sendable {
    let nominalAt: Date
    let occurrenceKey: String
}

/// Generates civil-date occurrences. Start and end bounds are inclusive by local
/// calendar day, while `anchorAt` supplies both the recurrence phase and time.
nonisolated enum FamilyTaskRecurrenceGenerator {
    static func occurrences(
        planID: UUID,
        scheduleVersion: Int,
        rule: FamilyTaskRecurrenceRule,
        anchorAt: Date,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        from windowStart: Date,
        through windowEnd: Date,
        timeZone: TimeZone,
        limit: Int = 512
    ) -> [FamilyTaskRecurrenceOccurrence] {
        guard rule.isValid, windowStart <= windowEnd, limit > 0 else { return [] }

        let calendar = gregorianCalendar(timeZone: timeZone)
        let anchorDay = calendar.startOfDay(for: anchorAt)
        var lowerDay = max(calendar.startOfDay(for: windowStart), anchorDay)
        if let startsAt {
            lowerDay = max(lowerDay, calendar.startOfDay(for: startsAt))
        }

        var upperDay = calendar.startOfDay(for: windowEnd)
        if let endsAt {
            upperDay = min(upperDay, calendar.startOfDay(for: endsAt))
        }
        guard lowerDay <= upperDay else { return [] }

        let anchorTime = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: anchorAt)
        var day = lowerDay
        var result: [FamilyTaskRecurrenceOccurrence] = []

        while day <= upperDay, result.count < limit {
            if matches(rule: rule, day: day, anchorDay: anchorDay, calendar: calendar),
               let nominalAt = combining(day: day, time: anchorTime, calendar: calendar) {
                result.append(
                    FamilyTaskRecurrenceOccurrence(
                        nominalAt: nominalAt,
                        occurrenceKey: occurrenceKey(
                            planID: planID,
                            scheduleVersion: scheduleVersion,
                            nominalAt: nominalAt,
                            timeZone: timeZone
                        )
                    )
                )
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day), nextDay > day else {
                break
            }
            day = nextDay
        }

        return result
    }

    static func occurrenceKey(
        planID: UUID,
        scheduleVersion: Int,
        nominalAt: Date,
        timeZone: TimeZone
    ) -> String {
        let calendar = gregorianCalendar(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: nominalAt)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let civilDate = String(format: "%04d-%02d-%02d", year, month, day)
        return "family-task:\(planID.uuidString.lowercased()):v\(max(scheduleVersion, 1)):\(civilDate)"
    }

    private static func matches(
        rule: FamilyTaskRecurrenceRule,
        day: Date,
        anchorDay: Date,
        calendar: Calendar
    ) -> Bool {
        switch rule {
        case .once:
            return calendar.isDate(day, inSameDayAs: anchorDay)

        case let .everyNDays(interval):
            guard let elapsedDays = calendar.dateComponents([.day], from: anchorDay, to: day).day else {
                return false
            }
            return elapsedDays >= 0 && elapsedDays.isMultiple(of: interval)

        case let .weekly(weekdays):
            guard let weekday = FamilyTaskWeekday(rawValue: calendar.component(.weekday, from: day)) else {
                return false
            }
            return weekdays.contains(weekday)

        case let .monthlyDay(monthDay):
            return calendar.component(.day, from: day) == monthDay

        case .monthlyLastDay:
            guard let days = calendar.range(of: .day, in: .month, for: day) else { return false }
            return calendar.component(.day, from: day) == days.count
        }
    }

    private static func combining(
        day: Date,
        time: DateComponents,
        calendar: Calendar
    ) -> Date? {
        var requestedTime = DateComponents()
        requestedTime.hour = time.hour
        requestedTime.minute = time.minute
        requestedTime.second = time.second
        requestedTime.nanosecond = time.nanosecond
        let searchStart = calendar.startOfDay(for: day).addingTimeInterval(-1)
        guard let result = calendar.nextDate(
            after: searchStart,
            matching: requestedTime,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ), calendar.isDate(result, inSameDayAs: day) else {
            return nil
        }
        return result
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
