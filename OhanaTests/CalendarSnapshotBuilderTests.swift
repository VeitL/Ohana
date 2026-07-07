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

    private func makeDate(
        _ calendar: Calendar,
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day)) ?? Date()
    }
}
