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

    @Test func liveWorkoutRowsAndPerRingGoalStatesRemainVisible() throws {
        let managerSource = try source("Ohana/Features/Workouts/HumanHealthKitManager.swift")
        let source = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryView.swift")

        #expect(managerSource.contains("case accessRequested"))
        #expect(managerSource.contains("var activitySummaryStatus"))
        #expect(managerSource.contains("var recentWorkoutsStatus"))
        #expect(managerSource.contains("recentWorkoutsStatus = workouts.isEmpty ? .noData : .available"))
        #expect(managerSource.contains("var recentWorkouts: [HumanHealthKitWorkoutSnapshot]"))
        #expect(managerSource.contains("summary.activityMoveMode == .appleMoveTime"))
        #expect(source.contains("healthManager.recentWorkouts"))
        #expect(source.contains("Automatically combined with the matching Apple Health workout."))
        #expect(source.contains("if let log = row.log, !row.isHealthKit, !row.isPetWalk"))
        #expect(source.contains("let progress: Double?"))
        #expect(source.contains("human-workout-activity-rings"))
        #expect(source.contains("human-workout-activity-goal-status"))
        #expect(source.contains("human-workout-recent-status"))
        #expect(!source.contains("importCandidate("))
        #expect(!source.contains("human-workout-import-"))
        #expect(!source.contains("snapshot.hasCompleteActivityGoals"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
