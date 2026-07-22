import Foundation
import Testing
@testable import Ohana

struct HumanAllFeaturesRouteSummaryTests {
    @MainActor
    @Test func humanAllFeaturesSummaryUsesRouteScopedRows() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = date(year: 2026, month: 7, day: 7, hour: 12)
        let human = Human(name: "Lin")
        let olderWeight = HumanWeightLog(
            date: date(year: 2026, month: 7, day: 1),
            weight: 66,
            human: human
        )
        let latestWeight = HumanWeightLog(
            date: date(year: 2026, month: 7, day: 6),
            weight: 67.2,
            human: human
        )
        let olderWorkout = HumanWorkoutLog(
            date: date(year: 2026, month: 6, day: 29),
            durationMinutes: 30,
            human: human
        )
        let latestWorkout = HumanWorkoutLog(
            date: date(year: 2026, month: 7, day: 6),
            durationMinutes: 45,
            human: human
        )
        let metric = HumanHealthMetricLog(
            metricKey: "hba1c",
            unitCode: "percent",
            value: 5.4,
            date: date(year: 2026, month: 7, day: 5),
            human: human
        )

        let summary = HumanAllFeaturesActivitySummary.load(
            human: human,
            allMeds: [],
            allReports: [],
            allExpenses: [],
            weightLogs: [olderWeight, latestWeight],
            workoutLogs: [olderWorkout, latestWorkout],
            healthMetricLogs: [metric],
            now: now,
            calendar: calendar
        )

        #expect(summary.latestWeightKg == 67.2)
        #expect(summary.latestWeightDate == latestWeight.date)
        #expect(summary.monthlyWorkoutCount == 1)
        #expect(summary.latestWorkoutDate == latestWorkout.date)
        #expect(summary.trackedHealthMetricCount == 1)
        #expect(summary.latestHealthMetricKey == "hba1c")
        #expect(summary.latestHealthMetricUnitCode == "percent")
        #expect(summary.latestHealthMetricValue == 5.4)
        #expect(summary.weightChartPoints.map(\.value) == [66, 67.2])
        #expect(summary.workoutChartPoints.reduce(0) { $0 + $1.value } == 45)
        #expect(summary.metricsChartPoints.reduce(0) { $0 + $1.value } == 1)
    }

    @MainActor
    @Test func humanAllFeaturesSummaryUsesCanonicalProfileCompletionPolicy() {
        let human = Human(name: "Defaults do not count")

        let emptySummary = HumanAllFeaturesActivitySummary.load(
            human: human,
            allMeds: [],
            allReports: [],
            allExpenses: []
        )
        #expect(emptySummary.profileChartPoints.first?.value == 0)

        human.avatarEmoji = "🧑‍🚀"
        human.birthday = Date(timeIntervalSince1970: 1_000_000)
        let resolvedSummary = HumanAllFeaturesActivitySummary.load(
            human: human,
            allMeds: [],
            allReports: [],
            allExpenses: [],
            explicitlyResolvedProfileCategories: [.humanBodyProfile]
        )

        #expect(resolvedSummary.profileChartPoints.first?.value == 3)
        #expect(MemberProfileCompletenessPolicy.human(
            human,
            explicitlyResolvedCategories: [.humanBodyProfile]
        ).completionPercent == 75)
    }

    @Test func humanAllFeaturesSheetDoesNotReadRelationshipLogs() throws {
        let sheetSource = try source(
            "Ohana/Features/Members/Views/HumanAllFeaturesSheet.swift",
            rootURL: repositoryRootURL()
        )
        let routeSource = try source(
            "Ohana/Features/Members/HumanDetailSheetRouteContainer.swift",
            rootURL: repositoryRootURL()
        )

        #expect(!sheetSource.contains("human.weightLogs"))
        #expect(!sheetSource.contains("human.workoutLogs"))
        #expect(!sheetSource.contains("human.healthMetricLogs"))
        #expect(sheetSource.contains("summary.latestWeightKg"))
        #expect(sheetSource.contains("summary.monthlyWorkoutCount"))
        #expect(sheetSource.contains("summary.trackedHealthMetricCount"))
        #expect(routeSource.contains("FetchDescriptor<HumanWeightLog>"))
        #expect(routeSource.contains("FetchDescriptor<HumanWorkoutLog>"))
        #expect(routeSource.contains("FetchDescriptor<HumanHealthMetricLog>"))
        #expect(routeSource.contains("weightLogs: weightLogs"))
        #expect(routeSource.contains("workoutLogs: workoutLogs"))
        #expect(routeSource.contains("healthMetricLogs: healthMetricLogs"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}
