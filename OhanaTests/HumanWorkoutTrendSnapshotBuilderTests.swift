//
//  HumanWorkoutTrendSnapshotBuilderTests.swift
//  OhanaTests
//

import Foundation
import Testing
@testable import Ohana

struct HumanWorkoutTrendSnapshotBuilderTests {
    @Test func periodStartIncludesTodayAndRequestedNumberOfCalendarDays() throws {
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 15)))

        let start = HumanWorkoutHistoryPeriod.sevenDays.startDate(containing: now, calendar: calendar)

        #expect(start == calendar.date(from: DateComponents(year: 2026, month: 7, day: 27)))
        #expect(HumanWorkoutHistoryPeriod.ninetyDays.queryLimit <= 512)
        #expect(HumanWorkoutHistoryPeriod.ninetyDays.healthKitQueryLimit <= 256)
    }

    @Test func snapshotFiltersPeriodAndKeepsSourceCountsDistinct() throws {
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)))
        let samples = [
            sample("local", date: date(2026, 1, 5, calendar: calendar), minutes: 300, distance: 3, source: .ohanaLocal),
            sample("walk", date: date(2026, 1, 20, calendar: calendar), minutes: 600, distance: 4, source: .petWalk),
            sample("live", date: date(2026, 1, 25, calendar: calendar), minutes: 900, distance: 5, source: .liveAppleHealth),
            sample("old", date: date(2025, 12, 1, calendar: calendar), minutes: 99, distance: 9, source: .ohanaLocal),
            sample("future", date: date(2026, 2, 1, calendar: calendar), minutes: 99, distance: 9, source: .ohanaLocal)
        ]

        let snapshot = HumanWorkoutTrendSnapshotBuilder.make(
            samples: samples,
            period: .thirtyDays,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.visibleSampleCount == 3)
        #expect(snapshot.totalDurationMinutes == 1800)
        #expect(snapshot.totalDistanceKm == 12)
        #expect(snapshot.activeDayCount == 3)
        #expect(snapshot.durableRecordCount == 2)
        #expect(snapshot.petWalkCount == 1)
        #expect(snapshot.liveAppleHealthCount == 1)
        #expect(snapshot.durationTrend.direction == .rising)
        #expect(snapshot.durationTrend.changePercent == 100)
    }

    @Test func matchedWalkIsOneVisibleActivityButCountsBothSources() throws {
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 15)))

        let snapshot = HumanWorkoutTrendSnapshotBuilder.make(
            samples: [
                sample(
                    "matched",
                    date: date(2026, 8, 1, calendar: calendar),
                    minutes: 30,
                    distance: 2.4,
                    source: .matchedPetWalkAndAppleHealth
                )
            ],
            period: .sevenDays,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.visibleSampleCount == 1)
        #expect(snapshot.durableRecordCount == 1)
        #expect(snapshot.petWalkCount == 1)
        #expect(snapshot.liveAppleHealthCount == 1)
    }

    @Test func liveOnlyRowsDoNotInventALocalTrend() throws {
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 15)))

        let snapshot = HumanWorkoutTrendSnapshotBuilder.make(
            samples: [
                sample(
                    "live",
                    date: date(2026, 8, 1, calendar: calendar),
                    minutes: 45,
                    distance: 5,
                    source: .liveAppleHealth
                )
            ],
            period: .sevenDays,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.visibleSampleCount == 1)
        #expect(snapshot.durationTrend == .unavailable)
    }

    @Test func trendNormalizesUnevenSevenDayHalves() throws {
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 15)))
        let snapshot = HumanWorkoutTrendSnapshotBuilder.make(
            samples: [
                sample("earlier", date: date(2026, 7, 27, calendar: calendar), minutes: 30, source: .ohanaLocal),
                sample("recent", date: date(2026, 7, 30, calendar: calendar), minutes: 40, source: .ohanaLocal)
            ],
            period: .sevenDays,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.durationTrend.direction == .steady)
        #expect(snapshot.durationTrend.changePercent == 0)
    }

    @Test func incompleteCoverageMakesTotalsMinimumsAndSuppressesTrend() throws {
        let calendar = utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 15)))
        let coverage = HumanWorkoutHistoryCoverage(
            local: .truncated,
            petWalk: .complete,
            healthKit: .unavailable
        )

        let snapshot = HumanWorkoutTrendSnapshotBuilder.make(
            samples: [
                sample("earlier", date: date(2026, 7, 27, calendar: calendar), minutes: 10, source: .ohanaLocal),
                sample("recent", date: date(2026, 8, 1, calendar: calendar), minutes: 100, source: .ohanaLocal)
            ],
            period: .sevenDays,
            now: now,
            coverage: coverage,
            calendar: calendar
        )

        #expect(!snapshot.coverage.isComplete)
        #expect(!snapshot.coverage.isLoading)
        #expect(snapshot.totalDurationMinutes == 110)
        #expect(snapshot.durationTrend == .unavailable)
    }

    private func sample(
        _ id: String,
        date: Date,
        minutes: Int,
        distance: Double = 0,
        source: HumanWorkoutHistorySource
    ) -> HumanWorkoutTrendSample {
        HumanWorkoutTrendSample(
            id: id,
            date: date,
            durationMinutes: minutes,
            distanceKm: distance,
            source: source
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

struct HumanWorkoutPetWalkDeduplicationPolicyTests {
    @Test func sharedSessionProducesOneOutingAndRetainsEverySourceID() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = HumanWorkoutPetWalkDeduplicationPolicy.makeSnapshots(
            candidates: [
                candidate("walk-a", session: " SESSION-1 ", pet: "Mochi", date: now, minutes: 20, distance: 1.2),
                candidate("walk-b", session: "session-1", pet: "Nori", date: now, minutes: 21, distance: 1.3),
                candidate("walk-c", session: "", pet: "Solo", date: now.addingTimeInterval(-60), minutes: 10, distance: 0.4)
            ],
            limit: 10
        )

        #expect(result.snapshots.count == 2)
        #expect(!result.wasTruncated)
        #expect(result.snapshots[0].sourcePetWalkLogIDs == ["walk-a", "walk-b"])
        #expect(result.snapshots[0].petNames == ["Mochi", "Nori"])
        #expect(result.snapshots[0].durationMinutes == 21)
        #expect(result.snapshots[0].distanceKm == 1.3)
    }

    @Test func deduplicatedOutingLimitReportsTruncation() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = HumanWorkoutPetWalkDeduplicationPolicy.makeSnapshots(
            candidates: [
                candidate("walk-a", session: "session-1", pet: nil, date: now, minutes: 20, distance: 1),
                candidate("walk-b", session: "session-2", pet: nil, date: now, minutes: 20, distance: 1)
            ],
            limit: 1
        )

        #expect(result.snapshots.count == 1)
        #expect(result.wasTruncated)
    }

    private func candidate(
        _ id: String,
        session: String,
        pet: String?,
        date: Date,
        minutes: Int,
        distance: Double
    ) -> HumanWorkoutPetWalkCandidate {
        HumanWorkoutPetWalkCandidate(
            sourceID: id,
            sharedSessionID: session,
            startDate: date,
            durationMinutes: minutes,
            distanceKm: distance,
            petName: pet
        )
    }
}

struct HumanWorkoutHistoryQueryTests {
    @Test func summaryUsesOwnerScopedBoundedWorkoutFetch() throws {
        let summarySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryView.swift")
        let routeDataSource = try source("Ohana/Features/Workouts/HumanWorkoutSummaryRouteData.swift")
        let historyPresentationSource = try source(
            "Ohana/Features/Workouts/Views/HumanWorkoutHistoryPresentationViews.swift"
        )

        #expect(!summarySource.contains("human.workoutLogs.sorted"))
        #expect(!summarySource.contains("modelContext.fetch"))
        #expect(summarySource.contains("HumanWorkoutHistoryOverviewCard("))
        #expect(summarySource.contains("HumanWorkoutSummaryRouteData.localWorkoutHistory("))
        #expect(summarySource.contains("HumanWorkoutSummaryRouteData.boundHumanProfile("))
        #expect(routeDataSource.contains("FetchDescriptor<HumanWorkoutLog>"))
        #expect(routeDataSource.contains("log.human?.id == humanID"))
        #expect(routeDataSource.contains("descriptor.fetchLimit = queryLimit + 1"))
        #expect(routeDataSource.contains("descriptor.fetchLimit = 1"))
        #expect(summarySource.contains("healthManager.loadRecentWorkouts("))
        #expect(summarySource.contains("healthManager.recentWorkoutsWereTruncated ? .truncated : .complete"))
        #expect(historyPresentationSource.contains("human-workout-history-coverage-status"))
        #expect(summarySource.contains("human-workout-confirm-delete-action"))

        let petWalkSource = try source("Ohana/Features/Workouts/HumanWorkoutPetWalkSnapshotBuilder.swift")
        #expect(petWalkSource.contains("descriptor.fetchLimit = rawLimit + 1"))
        #expect(petWalkSource.contains("sharedSessionID"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
