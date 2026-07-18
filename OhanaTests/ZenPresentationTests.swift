import Foundation
import Testing
@testable import Ohana

struct ZenPresentationTests {
    @Test func shellHasExactlyTheThreeMinimalTabs() {
        #expect(ZenTab.allCases == [.home, .streak, .oasis])
    }

    @Test func ownerStaysFirstThenSubjectsUseKindAndStableOrder() {
        let subjects = [
            subject(id: "plant", kind: .plant, name: "Fern", sortIndex: 0),
            subject(id: "pet-later", kind: .pet, name: "Zora", sortIndex: 2),
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, sortIndex: 5),
            subject(id: "human", kind: .human, name: "Alex", sortIndex: 0),
            subject(id: "pet-first", kind: .pet, name: "Milo", sortIndex: 1)
        ]

        #expect(ZenPresencePresentation.orderedSubjects(subjects).map(\.id) == [
            "owner",
            "human",
            "pet-first",
            "pet-later",
            "plant"
        ])
    }

    @Test func allCheckedPresentationDoesNotTreatAnEmptyHouseholdAsComplete() {
        #expect(!ZenPresencePresentation.allChecked([]))
        #expect(!ZenPresencePresentation.allChecked([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true)
        ]))
        #expect(ZenPresencePresentation.allChecked([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, checkedToday: true)
        ]))
        #expect(!ZenPresencePresentation.canEarnAllCheckedReward([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, checkedToday: true)
        ]))
        #expect(ZenPresencePresentation.canEarnAllCheckedReward([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, checkedToday: true),
            subject(id: "pet", kind: .pet, name: "Milo", checkedToday: true)
        ]))
    }

    @Test func monthLayoutUsesTheConfiguredFirstWeekdayAndFullWeeks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2
        let month = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))

        let slots = ZenCalendarLayout.slots(for: month, calendar: calendar)

        #expect(slots.count == 35)
        #expect(slots[0].date == nil)
        #expect(slots[1].date == nil)
        #expect(calendar.component(.day, from: try #require(slots[2].date)) == 1)
        #expect(calendar.component(.day, from: try #require(slots[32].date)) == 31)
        #expect(slots[33].date == nil)
        #expect(slots[34].date == nil)
    }

    @Test func missingHistoricalDayMeansNotParticipatingNotMissed() {
        #expect(ZenCalendarPresentation.participation(for: nil) == .notParticipating)

        let missedParticipatingDay = ZenPresenceDayDTO(
            subjectID: "owner",
            dayKey: "2026-07-17",
            checkedIn: false,
            participation: .participating
        )
        #expect(ZenCalendarPresentation.participation(for: missedParticipatingDay) == .participating)
    }

    @Test func personalAnalyticsExcludeStandardModeDaysFromCompletionDenominators() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let subject = subject(id: "owner", kind: .human, name: "Me", isOwner: true)
        let days = [
            analyticsDay(
                subjectID: subject.id,
                dayKey: "2026-07-13",
                checkedIn: true,
                participation: .participating
            ),
            analyticsDay(
                subjectID: subject.id,
                dayKey: "2026-07-14",
                checkedIn: false,
                participation: .participating
            ),
            analyticsDay(
                subjectID: subject.id,
                dayKey: "2026-07-15",
                checkedIn: false,
                participation: .notParticipating
            )
        ]
        let projection = ZenAnalyticsProjection(
            subjects: [subject],
            days: days,
            calendar: calendar
        )

        #expect(projection.participatingDays.count == 2)
        #expect(projection.checkedCount == 1)
        #expect(projection.completionRate == 50)
        #expect(projection.weeklyBins.count == 1)
        #expect(projection.weeklyBins.first?.participatingCount == 2)
        #expect(projection.weeklyBins.first?.rate == 50)
        #expect(projection.comparisonRows.first?.participatingCount == 2)
        #expect(projection.comparisonRows.first?.rate == 50)
    }

    @Test func personalAnalyticsCSVPreservesNotParticipatingSemantics() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let owner = subject(id: "owner", kind: .human, name: "Doe, \"Jo\"", isOwner: true)
        let day = analyticsDay(
            subjectID: owner.id,
            dayKey: "2026-07-15",
            checkedIn: false,
            participation: .notParticipating
        )

        let csv = ZenAnalyticsProjection(
            subjects: [owner],
            days: [day],
            calendar: calendar
        ).csvExport

        #expect(csv.hasPrefix("subject,date,participation,checked,status\n"))
        #expect(csv.contains("\"Doe, \"\"Jo\"\"\",2026-07-15,notParticipating,false,"))
    }

    @Test func personalAnalyticsRangesAreInclusiveAndStable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 16)))

        let days90 = try #require(ZenAnalyticsRange.days90.cutoffDayKey(calendar: calendar, now: now))
        let year = try #require(ZenAnalyticsRange.year.cutoffDayKey(calendar: calendar, now: now))

        #expect(days90 == "2026-04-20")
        #expect(year == "2025-07-18")
        #expect(ZenAnalyticsRange.all.cutoffDayKey(calendar: calendar, now: now) == nil)
    }

    @Test func dateOnlyKeysStayOnTheSameCivilDayAcrossTimeZones() throws {
        for identifier in ["America/Los_Angeles", "Pacific/Kiritimati"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: identifier))

            let materialized = try #require(ZenDayKey.date("2026-01-01", calendar: calendar))

            #expect(ZenDayKey.key(for: materialized, calendar: calendar) == "2026-01-01")
            #expect(calendar.component(.day, from: materialized) == 1)
        }
    }

    @Test func oasisSnapshotClampsUntrustedDisplayValues() {
        let snapshot = ZenOasisSnapshot(
            isReady: true,
            level: 99,
            progressToNextLevel: .infinity,
            totalEnergy: -4,
            nextLevelThreshold: -1,
            coconutBalance: -20,
            canInjectEnergy: true
        )

        #expect(snapshot.level == 10)
        #expect(snapshot.progressToNextLevel == 0)
        #expect(snapshot.totalEnergy == 0)
        #expect(snapshot.nextLevelThreshold == 0)
        #expect(snapshot.coconutBalance == 0)
    }

    @Test func zenSurfacesExposeStableAccessibilityRootsAndAvoidHeavyHomeMounts() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shell = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenShell.swift"),
            encoding: .utf8
        )
        let home = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenHomeView.swift"),
            encoding: .utf8
        )
        let streak = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenStreakView.swift"),
            encoding: .utf8
        )
        let oasis = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenOasisView.swift"),
            encoding: .utf8
        )
        let analytics = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenPersonalAnalyticsView.swift"),
            encoding: .utf8
        )

        #expect(shell.contains("zen-native-tab-view"))
        #expect(home.contains("zen-home-screen"))
        #expect(streak.contains("zen-streak-screen"))
        #expect(streak.contains("day?.status?.icon"))
        #expect(oasis.contains("zen-oasis-screen"))
        #expect(analytics.contains("zen-personal-analytics-screen"))
        #expect(analytics.contains("ShareLink(item: analytics.csvExport)"))
        #expect(analytics.contains("Chart(analytics.weeklyBins)"))
        #expect(!home.contains("@Query"))
        #expect(!home.contains("VerticalSolidHomeView"))
        #expect(!home.contains("TaskCenter"))
        #expect(!home.contains("QuickCare"))
    }

    private func subject(
        id: String,
        kind: ZenPresenceSubjectKind,
        name: String,
        isOwner: Bool = false,
        sortIndex: Int = 0,
        checkedToday: Bool = false
    ) -> ZenPresenceSubjectDTO {
        ZenPresenceSubjectDTO(
            id: id,
            kind: kind,
            name: name,
            isOwner: isOwner,
            sortIndex: sortIndex,
            checkedToday: checkedToday
        )
    }

    private func analyticsDay(
        subjectID: String,
        dayKey: String,
        checkedIn: Bool,
        participation: ZenParticipationState
    ) -> ZenPresenceDayDTO {
        ZenPresenceDayDTO(
            subjectID: subjectID,
            dayKey: dayKey,
            checkedIn: checkedIn,
            participation: participation
        )
    }
}
