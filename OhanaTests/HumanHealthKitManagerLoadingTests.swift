//
//  HumanHealthKitManagerLoadingTests.swift
//  OhanaTests
//

import Foundation
import Testing
@testable import Ohana

struct HumanHealthKitManagerLoadingTests {
    @Test func healthKitReadsHaveTimeoutAndPartialSummaryFallback() throws {
        let source = try source("Ohana/Features/Workouts/HumanHealthKitManager.swift")

        #expect(source.contains("HumanHealthKitReadError.timedOut"))
        #expect(source.contains("HumanHealthKitQueryContinuation"))
        #expect(source.contains("HumanHealthKitRunningQuery"))
        #expect(source.contains("healthStore.stop(query)"))
        #expect(source.contains("async let hourlyStepsResult"))
        #expect(source.contains("fallback: HumanWorkoutHealthSnapshot.empty.hourlySteps"))
        #expect(source.contains("fallback: HumanWorkoutHealthSnapshot.empty.hourlyDistanceKm"))
        #expect(source.contains("let activeEnergy = resolvedHealthValue"))
        #expect(source.contains("async let exerciseResult"))
        #expect(source.contains("async let standHoursResult"))
        #expect(source.contains(".appleExerciseTime"))
        #expect(source.contains(".appleStandHour"))
        #expect(source.contains("try await appleStandHours("))
        #expect(source.contains("HumanHealthActivityResolver.resolve("))
        #expect(source.contains("let activity = resolvedHealthValue"))
        #expect(source.contains("errorMessage = firstError.localizedDescription"))
        #expect(source.contains("var components = calendar.dateComponents([.era, .year, .month, .day], from: date)"))
        #expect(source.contains("components.calendar = calendar"))
        #expect(source.contains("components.timeZone = calendar.timeZone"))

        let rawContinuationCount = source.components(separatedBy: "withCheckedThrowingContinuation").count - 1
        #expect(rawContinuationCount == 1)
    }

    @Test func workoutImportAndUnavailableGoalsHaveVisibleStatus() throws {
        let source = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryView.swift")

        #expect(source.contains("presentWorkoutImportResult(result)"))
        #expect(source.contains("运动已导入"))
        #expect(source.contains("Import failed. Try again."))
        #expect(source.contains("appServices.islandToasts.show(message)"))
        #expect(source.contains("UIAccessibility.post(notification: .announcement"))
        #expect(source.contains(".islandToastOverlay()"))
        #expect(source.contains("snapshot.hasCompleteActivityGoals"))
        #expect(source.contains("human-workout-activity-goals-unavailable"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
