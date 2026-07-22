import Foundation
import Testing
@testable import Ohana

struct FamilyTaskRecurrenceRuleTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func onceRuleEmitsOnlyAnchorWhenBoundsIncludeItsCivilDay() {
        let included = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .once,
            anchorAt: date(2026, 2, 12, 14),
            startsAt: date(2026, 2, 12),
            endsAt: date(2026, 2, 12, 23),
            from: date(2026, 1, 1),
            through: date(2026, 12, 31),
            timeZone: utc
        )
        let excluded = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .once,
            anchorAt: date(2026, 2, 12, 14),
            startsAt: date(2026, 2, 13),
            from: date(2026, 1, 1),
            through: date(2026, 12, 31),
            timeZone: utc
        )

        #expect(included.count == 1)
        #expect(days(included) == [12])
        #expect(excluded.isEmpty)
    }

    @Test func everyNDaysHonorsInclusiveOptionalStartAndEndDays() {
        let occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            scheduleVersion: 1,
            rule: .everyNDays(3),
            anchorAt: date(2026, 1, 1, 9, 30),
            startsAt: date(2026, 1, 3),
            endsAt: date(2026, 1, 8),
            from: date(2026, 1, 1),
            through: date(2026, 1, 31),
            timeZone: utc
        )

        #expect(days(occurrences) == [4, 7])
        #expect(hours(occurrences) == [9, 9])
    }

    @Test func weeklyRuleSupportsMultipleSelectedWeekdays() {
        let occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .weekly([.monday, .thursday]),
            anchorAt: date(2026, 1, 1, 18),
            from: date(2026, 1, 4),
            through: date(2026, 1, 11),
            timeZone: utc
        )

        #expect(days(occurrences) == [5, 8])
        #expect(hours(occurrences) == [18, 18])
    }

    @Test func monthlySpecificDaySkipsMonthsWithoutThatDay() {
        let occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .monthlyDay(31),
            anchorAt: date(2026, 1, 1, 8),
            from: date(2026, 1, 1),
            through: date(2026, 4, 30),
            timeZone: utc
        )

        #expect(monthDays(occurrences) == ["01-31", "03-31"])
    }

    @Test func monthlyLastDayIncludesLeapDay() {
        let occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .monthlyLastDay,
            anchorAt: date(2028, 1, 1, 8),
            from: date(2028, 1, 1),
            through: date(2028, 3, 31),
            timeZone: utc
        )

        #expect(monthDays(occurrences) == ["01-31", "02-29", "03-31"])
    }

    @Test func nilStartBeginsAtAnchorAndNilEndUsesWindow() {
        let occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .everyNDays(2),
            anchorAt: date(2026, 6, 10, 7),
            from: date(2026, 6, 1),
            through: date(2026, 6, 15),
            timeZone: utc
        )

        #expect(days(occurrences) == [10, 12, 14])
    }

    @Test func occurrenceKeyIsStableAcrossOverlappingQueries() {
        let planID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let first = FamilyTaskRecurrenceGenerator.occurrences(
            planID: planID,
            scheduleVersion: 3,
            rule: .everyNDays(1),
            anchorAt: date(2026, 3, 1, 10),
            from: date(2026, 3, 1),
            through: date(2026, 3, 4),
            timeZone: utc
        )
        let second = FamilyTaskRecurrenceGenerator.occurrences(
            planID: planID,
            scheduleVersion: 3,
            rule: .everyNDays(1),
            anchorAt: date(2026, 3, 1, 10),
            from: date(2026, 3, 3),
            through: date(2026, 3, 8),
            timeZone: utc
        )

        let firstKey = first.first { day(of: $0.nominalAt) == 3 }?.occurrenceKey
        let secondKey = second.first { day(of: $0.nominalAt) == 3 }?.occurrenceKey
        #expect(firstKey == secondKey)
        #expect(firstKey == "family-task:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:v3:2026-03-03")
    }

    @Test func invalidRulesGenerateNoOccurrences() {
        let common: (FamilyTaskRecurrenceRule) -> [FamilyTaskRecurrenceOccurrence] = { rule in
            FamilyTaskRecurrenceGenerator.occurrences(
                planID: UUID(),
                scheduleVersion: 1,
                rule: rule,
                anchorAt: date(2026, 1, 1),
                from: date(2026, 1, 1),
                through: date(2026, 1, 31),
                timeZone: utc
            )
        }

        #expect(common(.everyNDays(0)).isEmpty)
        #expect(common(.everyNDays(366)).isEmpty)
        #expect(common(.weekly([])).isEmpty)
        #expect(common(.monthlyDay(32)).isEmpty)
    }

    @Test func nonexistentDSTTimeMovesToFirstValidLocalTime() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let anchor = zonedDate(2026, 1, 25, 2, 30, timeZone: berlin)
        let occurrences = FamilyTaskRecurrenceGenerator.occurrences(
            planID: UUID(),
            scheduleVersion: 1,
            rule: .weekly([.sunday]),
            anchorAt: anchor,
            from: zonedDate(2026, 3, 29, 0, 0, timeZone: berlin),
            through: zonedDate(2026, 3, 29, 23, 59, timeZone: berlin),
            timeZone: berlin
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin

        #expect(occurrences.count == 1)
        #expect(calendar.component(.hour, from: occurrences[0].nominalAt) == 3)
        #expect(calendar.component(.minute, from: occurrences[0].nominalAt) == 0)
    }

    @Test func weeklyMaskRoundTripsSelectedDays() {
        let original = FamilyTaskRecurrenceRule.weekly([.sunday, .wednesday, .saturday])
        let restored = FamilyTaskRecurrenceRule.weekly(weekdayMask: original.weekdayMask)

        #expect(restored == original)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        zonedDate(year, month, day, hour, minute, timeZone: utc)
    }

    private func zonedDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private func days(_ occurrences: [FamilyTaskRecurrenceOccurrence]) -> [Int] {
        occurrences.map { day(of: $0.nominalAt) }
    }

    private func hours(_ occurrences: [FamilyTaskRecurrenceOccurrence]) -> [Int] {
        occurrences.map { component(.hour, from: $0.nominalAt) }
    }

    private func monthDays(_ occurrences: [FamilyTaskRecurrenceOccurrence]) -> [String] {
        occurrences.map { occurrence in
            String(
                format: "%02d-%02d",
                component(.month, from: occurrence.nominalAt),
                component(.day, from: occurrence.nominalAt)
            )
        }
    }

    private func day(of date: Date) -> Int {
        component(.day, from: date)
    }

    private func component(_ component: Calendar.Component, from date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.component(component, from: date)
    }
}
