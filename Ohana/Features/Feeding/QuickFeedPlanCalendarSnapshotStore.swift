//
//  QuickFeedPlanCalendarSnapshotStore.swift
//  Ohana
//
//  Cached read model for feeding plan calendar surfaces.
//

import Combine
import Foundation

struct QuickFeedPlanCalendarSnapshot {
    let activeMode: FeedOperatingMode
    let month: Date
    let selectedDate: Date
    let monthKey: String
    let daySummaries: [FeedPlanCalendarDaySummary]
    let selectedDateOccurrences: [FeedPlanCalendarOccurrence]
    let historyReminders: [Reminder]
    let allReminders: [Reminder]

    static func build(
        manualEvents: [Event],
        autoEvents: [Event],
        feedingLedgerEvents: [CareLedgerEvent],
        activeMode: FeedOperatingMode,
        month: Date,
        selectedDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> QuickFeedPlanCalendarSnapshot {
        let displayedMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let monthKeyComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        let monthKey = "\(monthKeyComponents.year ?? 0)-\(monthKeyComponents.month ?? 0)"
        let allReminders = manualEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let events = calendarEvents(
            manualEvents: manualEvents,
            autoEvents: autoEvents,
            activeMode: activeMode
        )
        let autoLedgerEventsByKey = Dictionary(
            grouping: feedingLedgerEvents.compactMap { event -> (String, CareLedgerEvent)? in
                guard let key = autoLedgerKey(for: event) else { return nil }
                return (key, event)
            },
            by: \.0
        ).compactMapValues { values in
            values.map(\.1).max { $0.occurredAt < $1.occurredAt }
        }
        let reminderByKey = Dictionary(
            grouping: allReminders,
            by: { reminderKey(eventId: $0.event?.id, scheduledAt: $0.scheduledAt) }
        ).compactMapValues { $0.first }

        let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth)
        let monthSummaries: [FeedPlanCalendarDaySummary] = if let monthInterval {
            makeMonthSummaries(
                monthInterval: monthInterval,
                events: events,
                activeMode: activeMode,
                now: now,
                remindersByKey: reminderByKey,
                autoLedgerEventsByKey: autoLedgerEventsByKey,
                calendar: calendar
            )
        } else {
            []
        }

        let selectedStart = calendar.startOfDay(for: selectedDate)
        let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart) ?? selectedStart.addingTimeInterval(86400)
        let selectedOccurrences = occurrences(
            events: events,
            activeMode: activeMode,
            start: selectedStart,
            end: selectedEnd,
            remindersByKey: reminderByKey,
            autoLedgerEventsByKey: autoLedgerEventsByKey,
            calendar: calendar
        )
        .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
        .sorted { $0.date < $1.date }

        return QuickFeedPlanCalendarSnapshot(
            activeMode: activeMode,
            month: displayedMonth,
            selectedDate: selectedDate,
            monthKey: monthKey,
            daySummaries: monthSummaries,
            selectedDateOccurrences: selectedOccurrences,
            historyReminders: allReminders
                .filter { $0.scheduledAt < now }
                .sorted { $0.scheduledAt > $1.scheduledAt },
            allReminders: allReminders
        )
    }

    private static func makeMonthSummaries(
        monthInterval: DateInterval,
        events: [Event],
        activeMode: FeedOperatingMode,
        now: Date,
        remindersByKey: [String: Reminder],
        autoLedgerEventsByKey: [String: CareLedgerEvent],
        calendar: Calendar
    ) -> [FeedPlanCalendarDaySummary] {
        let monthStart = monthInterval.start
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayFirstLeadingDays = (weekday + 5) % 7
        let monthEnd = calendar.date(byAdding: .second, value: -1, to: monthInterval.end) ?? monthInterval.end
        let monthOccurrences = occurrences(
            events: events,
            activeMode: activeMode,
            start: monthStart,
            end: monthEnd,
            remindersByKey: remindersByKey,
            autoLedgerEventsByKey: autoLedgerEventsByKey,
            calendar: calendar
        )
        let occurrencesByDay = Dictionary(grouping: monthOccurrences) {
            calendar.startOfDay(for: $0.date)
        }
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1 ..< 1
        let leadingPlaceholders: [FeedPlanCalendarDaySummary] = (0 ..< mondayFirstLeadingDays).compactMap { offset in
            let day = calendar.date(byAdding: .day, value: offset - mondayFirstLeadingDays, to: monthStart) ?? monthStart
            return FeedPlanCalendarDaySummary(
                date: day,
                dayNumber: 0,
                isInDisplayedMonth: false,
                isToday: false,
                markers: []
            )
        }

        let currentMonthDays: [FeedPlanCalendarDaySummary] = dayRange.compactMap { dayNumber in
            guard let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) else { return nil }
            let markers = (occurrencesByDay[calendar.startOfDay(for: day)] ?? []).map { occurrence in
                FeedPlanCalendarMarker(status: markerStatus(for: occurrence, activeMode: activeMode, now: now, calendar: calendar))
            }
            return FeedPlanCalendarDaySummary(
                date: day,
                dayNumber: dayNumber,
                isInDisplayedMonth: true,
                isToday: calendar.isDateInToday(day),
                markers: markers
            )
        }

        return leadingPlaceholders + currentMonthDays
    }

    private static func occurrences(
        events: [Event],
        activeMode: FeedOperatingMode,
        start: Date,
        end: Date,
        remindersByKey: [String: Reminder],
        autoLedgerEventsByKey: [String: CareLedgerEvent],
        calendar: Calendar
    ) -> [FeedPlanCalendarOccurrence] {
        events.flatMap { event in
            occurrenceDates(for: event, from: start, through: end, calendar: calendar).map { date in
                let reminder = activeMode == .manualReminder
                    ? remindersByKey[reminderKey(eventId: event.id, scheduledAt: date)]
                    : nil
                let autoLedgerEvent = activeMode == .autoFeeder
                    ? autoLedgerEventsByKey[FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: date)]
                    : nil
                return FeedPlanCalendarOccurrence(date: date, event: event, reminder: reminder, autoLedgerEvent: autoLedgerEvent)
            }
        }
    }

    private static func calendarEvents(
        manualEvents: [Event],
        autoEvents: [Event],
        activeMode: FeedOperatingMode
    ) -> [Event] {
        switch activeMode {
        case .manual:
            []
        case .manualReminder:
            manualEvents
        case .autoFeeder:
            autoEvents
        }
    }

    private static func markerStatus(
        for occurrence: FeedPlanCalendarOccurrence,
        activeMode: FeedOperatingMode,
        now: Date,
        calendar: Calendar
    ) -> FeedPlanCalendarMarker.Status {
        if occurrence.isCompleted { return .completed }
        if activeMode == .autoFeeder {
            if !calendar.isDateInToday(occurrence.date) { return .planned }
            return .pending
        }
        if occurrence.date < now { return .missed }
        if !calendar.isDateInToday(occurrence.date) { return .planned }
        return .pending
    }

    private static func occurrenceDates(
        for event: Event,
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> [Date] {
        let intervalDays = max(event.recurrenceDays, 1)
        let limitedEnd = min(event.recurrenceEndDate ?? end, end)
        guard event.startDate <= limitedEnd else { return [] }

        var cursor = event.startDate
        if cursor < start {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: event.startDate),
                to: calendar.startOfDay(for: start)
            ).day ?? 0
            let steps = max(0, days / intervalDays)
            cursor = calendar.date(byAdding: .day, value: steps * intervalDays, to: event.startDate) ?? event.startDate
            while cursor < start {
                guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
                cursor = next
            }
        }

        var dates: [Date] = []
        var guardCount = 0
        while cursor <= limitedEnd, guardCount < 500 {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return dates
    }

    private static func reminderKey(eventId: UUID?, scheduledAt: Date) -> String {
        "\(eventId?.uuidString ?? ""):\(Int(scheduledAt.timeIntervalSince1970 / 60))"
    }

    private static func autoLedgerKey(for event: CareLedgerEvent) -> String? {
        guard event.eventKindEnum == .care,
              event.actionType == CareType.feeding.rawValue
        else { return nil }
        if let key = FeedLogMetadata.autoDedupKey(from: event.note) {
            return key
        }
        guard event.sourceEnum == .service,
              event.sourceReminderId == nil,
              let sourceEventId = event.sourceEventId,
              let eventId = UUID(uuidString: sourceEventId)
        else { return nil }
        return FeedLogMetadata.autoDedupKey(eventId: eventId, scheduledAt: event.occurredAt)
    }
}

struct QuickFeedPlanCalendarSnapshotRevision: Equatable {
    let manualEventRevision: Int
    let autoEventRevision: Int
    let feedingLedgerRevision: Int
    let activeModeRawValue: String
    let monthRevision: Int
    let selectedDayRevision: Int
    let timeRevision: Int

    static func make(
        manualEvents: [Event],
        autoEvents: [Event],
        feedingLedgerEvents: [CareLedgerEvent],
        activeMode: FeedOperatingMode,
        month: Date,
        selectedDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> QuickFeedPlanCalendarSnapshotRevision {
        let monthStart = calendar.dateInterval(of: .month, for: month)?.start ?? month
        return QuickFeedPlanCalendarSnapshotRevision(
            manualEventRevision: eventRevision(manualEvents),
            autoEventRevision: eventRevision(autoEvents),
            feedingLedgerRevision: revisionHash(feedingLedgerEvents.prefix(360)) { hasher, event in
                hasher.combine(event.id)
                hasher.combine(event.occurredAt.timeIntervalSince1970)
                hasher.combine(event.subjectId)
                hasher.combine(event.actionType)
                hasher.combine(event.note)
                hasher.combine(event.source)
                hasher.combine(event.sourceEventId)
                hasher.combine(event.sourceReminderId)
            },
            activeModeRawValue: activeMode.rawValue,
            monthRevision: Int(monthStart.timeIntervalSince1970 / 86400),
            selectedDayRevision: Int(calendar.startOfDay(for: selectedDate).timeIntervalSince1970 / 86400),
            timeRevision: Int(now.timeIntervalSince1970 / 60)
        )
    }

    private static func eventRevision(_ events: [Event]) -> Int {
        revisionHash(events.prefix(30)) { hasher, event in
            hasher.combine(event.id)
            hasher.combine(event.startDate.timeIntervalSince1970)
            hasher.combine(event.recurrenceDays)
            hasher.combine(event.recurrenceEndDate?.timeIntervalSince1970 ?? 0)
            hasher.combine(event.feedAmountGrams)
            hasher.combine(event.foodKindRaw)
            hasher.combine(event.reminders.count)
            for reminder in event.reminders.prefix(60) {
                hasher.combine(reminder.id)
                hasher.combine(reminder.scheduledAt.timeIntervalSince1970)
                hasher.combine(reminder.status)
                hasher.combine(reminder.completedAt?.timeIntervalSince1970 ?? 0)
            }
        }
    }

    private static func revisionHash<Element>(
        _ values: some Sequence<Element>,
        combine: (inout Hasher, Element) -> Void
    ) -> Int {
        var hasher = Hasher()
        var count = 0
        for value in values {
            combine(&hasher, value)
            count += 1
        }
        hasher.combine(count)
        return hasher.finalize()
    }
}

@MainActor
final class QuickFeedPlanCalendarSnapshotStore: ObservableObject {
    @Published private(set) var snapshot: QuickFeedPlanCalendarSnapshot
    private var revision: QuickFeedPlanCalendarSnapshotRevision?

    init(initial: QuickFeedPlanCalendarSnapshot) {
        snapshot = initial
    }

    func rebuild(
        manualEvents: [Event],
        autoEvents: [Event],
        feedingLedgerEvents: [CareLedgerEvent],
        activeMode: FeedOperatingMode,
        month: Date,
        selectedDate: Date,
        now: Date,
        force: Bool = false
    ) {
        let nextRevision = QuickFeedPlanCalendarSnapshotRevision.make(
            manualEvents: manualEvents,
            autoEvents: autoEvents,
            feedingLedgerEvents: feedingLedgerEvents,
            activeMode: activeMode,
            month: month,
            selectedDate: selectedDate,
            now: now
        )
        guard force || nextRevision != revision else { return }
        snapshot = QuickFeedPlanCalendarSnapshot.build(
            manualEvents: manualEvents,
            autoEvents: autoEvents,
            feedingLedgerEvents: feedingLedgerEvents,
            activeMode: activeMode,
            month: month,
            selectedDate: selectedDate,
            now: now
        )
        revision = nextRevision
    }
}
