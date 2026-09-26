import Foundation
import Testing
@testable import Ohana

@MainActor
struct CalendarFamilyTaskProjectionTests {
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    @Test func occurrenceBeyondRollingWindowRemainsVisibleInsideCalendarWindow() throws {
        let calendar = utcCalendar()
        let now = date(calendar, year: 2026, month: 7, day: 1, hour: 9)
        let materializedThrough = try #require(calendar.date(byAdding: .day, value: 15, to: now))
        let plan = projectionPlan(
            anchorAt: now,
            endsAt: date(calendar, year: 2026, month: 11, day: 1),
            materializedThroughAt: materializedThrough
        )

        let occurrences = CalendarFamilyTaskProjectionBuilder.occurrences(
            plans: [plan],
            existingOccurrenceKeys: [],
            now: now,
            calendar: calendar
        )
        let dayTwenty = try #require(calendar.date(byAdding: .day, value: 20, to: now))

        let projected = try #require(
            occurrences.first { calendar.isDate($0.nominalAt, inSameDayAs: dayTwenty) }
        )
        let event = projected.makeReadOnlyEvent()
        let snapshot = CalendarSnapshotBuilder.mergingFamilyTaskProjectionEvents(
            [event],
            into: .empty,
            allEvents: [],
            pets: [],
            selectedDate: dayTwenty,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.events(for: dayTwenty).map(\.title) == [plan.title])
        #expect(!CalendarEventInteractionPolicy.allowsDirectMutation(for: event))
    }

    @Test func persistedOccurrenceKeyIsNotProjectedAgain() throws {
        let calendar = utcCalendar()
        let now = date(calendar, year: 2026, month: 7, day: 1, hour: 9)
        let plan = projectionPlan(anchorAt: now, endsAt: date(calendar, year: 2026, month: 9, day: 1))
        let persistedDate = try #require(calendar.date(byAdding: .day, value: 30, to: now))
        let persistedKey = FamilyTaskRecurrenceGenerator.occurrenceKey(
            planID: plan.id,
            scheduleVersion: plan.scheduleVersion,
            nominalAt: persistedDate,
            timeZone: plan.timeZone
        )

        let occurrences = CalendarFamilyTaskProjectionBuilder.occurrences(
            plans: [plan],
            existingOccurrenceKeys: [persistedKey],
            now: now,
            calendar: calendar
        )

        #expect(!occurrences.contains { $0.occurrenceKey == persistedKey })
        #expect(Set(occurrences.map(\.occurrenceKey)).count == occurrences.count)
    }

    @Test func occurrencesBeyondThreeMonthCalendarWindowAreExcluded() throws {
        let calendar = utcCalendar()
        let now = date(calendar, year: 2026, month: 7, day: 1, hour: 9)
        let plan = projectionPlan(anchorAt: now, endsAt: date(calendar, year: 2026, month: 12, day: 1))
        let outsideDate = try #require(calendar.date(byAdding: .month, value: 4, to: now))
        let outsideKey = FamilyTaskRecurrenceGenerator.occurrenceKey(
            planID: plan.id,
            scheduleVersion: plan.scheduleVersion,
            nominalAt: outsideDate,
            timeZone: plan.timeZone
        )
        let window = CalendarTimelineWindowPolicy.bounds(around: now, calendar: calendar)

        let occurrences = CalendarFamilyTaskProjectionBuilder.occurrences(
            plans: [plan],
            existingOccurrenceKeys: [],
            now: now,
            calendar: calendar
        )

        #expect(!occurrences.contains { $0.occurrenceKey == outsideKey })
        #expect(occurrences.allSatisfy { $0.nominalAt <= window.end })
    }

    private func projectionPlan(
        anchorAt: Date,
        endsAt: Date,
        materializedThroughAt: Date? = nil
    ) -> CalendarFamilyTaskPlanProjection {
        CalendarFamilyTaskPlanProjection(
            id: UUID(),
            title: "Weekly kitchen duty",
            isAllDay: false,
            eventTypeRaw: EventType.chore.rawValue,
            relatedEntityType: "",
            relatedEntityID: "",
            assignedToID: UUID().uuidString,
            taskCareKindRaw: "",
            recurrenceRule: .everyNDays(1),
            anchorAt: anchorAt,
            startsAt: nil,
            endsAt: endsAt,
            timeZone: timeZone,
            scheduleVersion: 1,
            materializedThroughAt: materializedThroughAt,
            createdAt: anchorAt
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func date(
        _ calendar: Calendar,
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        ) ?? Date()
    }
}
