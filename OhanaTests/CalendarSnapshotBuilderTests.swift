import Foundation
import Testing
@testable import Ohana

@MainActor
struct CalendarSnapshotBuilderTests {
    @Test func preparedSnapshotIndexesRecurringAndMultiDayOccurrencesByDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = makeDate(calendar, year: 2026, month: 7, day: 1)
        let days = (0 ..< 6).compactMap {
            calendar.date(byAdding: .day, value: $0, to: now)
        }
        let everyOther = Event(
            title: "Every other",
            startDate: now,
            eventType: EventType.daily.rawValue
        )
        everyOther.recurrenceDays = 2
        everyOther.recurrenceEndDate = makeDate(calendar, year: 2026, month: 7, day: 5)

        let multiDay = Event(
            title: "Multi day",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 2),
            endDate: makeDate(calendar, year: 2026, month: 7, day: 4),
            eventType: EventType.daily.rawValue
        )

        let snapshot = CalendarSnapshotBuilder.preparedSnapshot(
            filteredEvents: [everyOther, multiDay],
            allEvents: [everyOther, multiDay],
            pets: [],
            weekDays: days,
            monthDays: days,
            now: now,
            calendar: calendar
        )

        let july3ID = CalendarSnapshotBuilder.timelineDateID(makeDate(calendar, year: 2026, month: 7, day: 3))
        let july4ID = CalendarSnapshotBuilder.timelineDateID(makeDate(calendar, year: 2026, month: 7, day: 4))
        let july5ID = CalendarSnapshotBuilder.timelineDateID(makeDate(calendar, year: 2026, month: 7, day: 5))

        #expect(snapshot.events(forDayID: july3ID).map(\.title) == ["Every other", "Multi day"])
        #expect(snapshot.weekEventsByDay[july4ID]?.map(\.title) == ["Multi day"])
        #expect(snapshot.events(forDayID: july5ID).map(\.title) == ["Every other"])
        #expect(snapshot.monthEventDayIDs.contains(july3ID))
        #expect(snapshot.monthEventDayIDs.contains(july4ID))
        #expect(snapshot.monthEventDayIDs.contains(july5ID))
    }

    @Test func preparedSnapshotIndexesFullWindowBeyondVisibleMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = makeDate(calendar, year: 2026, month: 7, day: 1)
        let julyDays = (0 ..< 31).compactMap {
            calendar.date(byAdding: .day, value: $0, to: now)
        }
        let august15 = makeDate(calendar, year: 2026, month: 8, day: 15)
        let augustCare = Event(
            title: "August care",
            startDate: august15,
            eventType: EventType.daily.rawValue
        )

        let snapshot = CalendarSnapshotBuilder.preparedSnapshot(
            filteredEvents: [augustCare],
            allEvents: [augustCare],
            pets: [],
            weekDays: Array(julyDays.prefix(7)),
            monthDays: julyDays,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.events(for: august15).map(\.title) == ["August care"])
        #expect(snapshot.eventDayIDs(for: [august15]) == [CalendarSnapshotBuilder.timelineDateID(august15)])
        #expect(!snapshot.monthEventDayIDs.contains(CalendarSnapshotBuilder.timelineDateID(august15)))
    }

    private func makeDate(
        _ calendar: Calendar,
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day)) ?? Date()
    }
}
