import Foundation
import Testing
@testable import Ohana

@MainActor
struct TaskCenterSnapshotBuilderTests {
    @Test func groupsOnlyActionablePendingEventsAndUsesRedForOverdueMedication() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)

        let overdue = Event(
            title: "Water fern",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 12, hour: 10),
            eventType: EventType.watering.rawValue
        )
        let medication = Event(
            title: "Morning medication",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 9),
            eventType: EventType.medication.rawValue
        )
        let today = Event(
            title: "Evening walk",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 18),
            eventType: EventType.daily.rawValue
        )
        let upcoming = Event(
            title: "Vet follow-up",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 14, hour: 11),
            eventType: EventType.vetVisit.rawValue
        )
        let birthday = Event(
            title: "Birthday",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 8),
            eventType: EventType.birthday.rawValue
        )
        let completed = Event(
            title: "Completed task",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 10),
            eventType: EventType.task.rawValue
        )
        completed.isCompleted = true
        let events = [overdue, medication, today, upcoming, birthday, completed]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [],
            humans: [],
            plants: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.overdue.map(\.title) == ["Water fern", "Morning medication"])
        #expect(snapshot.overdue.map(\.urgency) == [.overdue, .critical])
        #expect(snapshot.today.map(\.title) == ["Evening walk"])
        #expect(snapshot.upcoming.map(\.title) == ["Vet follow-up"])
        #expect(snapshot.pendingCount == 4)
        #expect(snapshot.criticalCount == 1)
        #expect(snapshot.todayCompletedCount == 1)
        #expect(snapshot.todayTotalCount == 3)
        #expect(!snapshot.overdue.contains { $0.title == "Birthday" })
    }

    @Test func recurringScheduleExposesOneCurrentOccurrenceWithinBoundedLookback() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let recurring = Event(
            title: "Daily care",
            startDate: makeDate(calendar, year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue
        )
        recurring.recurrenceDays = 1
        recurring.recurrenceEndDate = makeDate(calendar, year: 2026, month: 7, day: 20, hour: 8)

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [recurring],
            allEvents: [recurring],
            pets: [],
            humans: [],
            plants: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.pendingCount == 1)
        #expect(snapshot.overdue.count == 1)
        #expect(calendar.isDate(
            snapshot.overdue[0].occurrenceDate,
            inSameDayAs: makeDate(calendar, year: 2026, month: 6, day: 29)
        ))
        #expect(snapshot.overdue[0].isRecurring)
    }

    @Test func ordinaryHealthEventsRemainOrangeWhileFutureMedicationIsStandard() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let overdueHealth = Event(
            title: "Health check",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 12, hour: 9),
            eventType: EventType.health.rawValue
        )
        let futureMedication = Event(
            title: "Evening medication",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 19),
            eventType: EventType.medication.rawValue
        )
        let events = [overdueHealth, futureMedication]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [],
            humans: [],
            plants: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.overdue.first?.urgency == .overdue)
        #expect(snapshot.today.first?.urgency == .standard)
        #expect(snapshot.criticalCount == 0)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(
        _ calendar: Calendar,
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )) ?? Date()
    }
}
