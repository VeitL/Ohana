//
//  HumanHealthKitManagerLoadingTests.swift
//  OhanaTests
//

import Foundation
import Testing
@testable import Ohana

struct HumanHealthKitManagerLoadingTests {
    @Test func todayComponentAvailabilityKeepsFailedQueriesUnavailable() {
        let availability = HumanHealthTodayComponentAvailabilityResolver.resolve(
            hasReadableActivitySummary: false,
            stepsReadSucceeded: false,
            distanceReadSucceeded: true,
            activeEnergyReadSucceeded: false,
            exerciseReadSucceeded: true,
            standReadSucceeded: false
        )

        #expect(availability.steps == .unavailable)
        #expect(availability.distance == .available)
        #expect(availability.move == .unavailable)
        #expect(availability.exercise == .available)
        #expect(availability.stand == .unavailable)
        #expect(availability.hasUnavailableComponent)
    }

    @Test func readableActivitySummaryCanSupplyRingComponents() {
        let availability = HumanHealthTodayComponentAvailabilityResolver.resolve(
            hasReadableActivitySummary: true,
            stepsReadSucceeded: false,
            distanceReadSucceeded: false,
            activeEnergyReadSucceeded: false,
            exerciseReadSucceeded: false,
            standReadSucceeded: false
        )

        #expect(availability.steps == .unavailable)
        #expect(availability.distance == .unavailable)
        #expect(availability.move == .available)
        #expect(availability.exercise == .available)
        #expect(availability.stand == .available)
    }

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
        let summarySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryView.swift")
        let historySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutHistoryPresentationViews.swift")
        let presentationSource = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryPresentationViews.swift")

        #expect(managerSource.contains("case accessRequested"))
        #expect(managerSource.contains("var activitySummaryStatus"))
        #expect(managerSource.contains("var recentWorkoutsStatus"))
        #expect(managerSource.contains("recentWorkoutsStatus = visibleWorkouts.isEmpty ? .noData : .available"))
        #expect(managerSource.contains("var recentWorkouts: [HumanHealthKitWorkoutSnapshot]"))
        #expect(managerSource.contains("recentWorkoutsLoadGeneration &+= 1"))
        #expect(managerSource.contains("guard loadGeneration == recentWorkoutsLoadGeneration"))
        #expect(managerSource.contains("limit: safeLimit + 1"))
        #expect(managerSource.contains("recentWorkoutsWereTruncated = workouts.count > safeLimit"))
        #expect(managerSource.contains("componentAvailability: componentAvailability"))
        #expect(managerSource.contains("summary.activityMoveMode == .appleMoveTime"))
        #expect(summarySource.contains("healthManager.recentWorkouts"))
        #expect(summarySource.contains("Automatically combined with the matching Apple Health workout."))
        #expect(historySource.contains("if let log = row.log, !row.isHealthKit, !row.isPetWalk"))
        #expect(presentationSource.contains("let progress: Double?"))
        #expect(presentationSource.contains("human-workout-activity-rings"))
        #expect(presentationSource.contains("human-workout-activity-goal-status"))
        #expect(historySource.contains("human-workout-recent-status"))
        #expect(presentationSource.contains("human-workout-today-component-status"))
        #expect(presentationSource.contains("state == .available ? value : \"—\""))
        #expect(summarySource.contains("requestedPeriod == selectedPeriod"))
        let workoutSources = summarySource + historySource + presentationSource
        #expect(!workoutSources.contains("importCandidate("))
        #expect(!workoutSources.contains("human-workout-import-"))
        #expect(!workoutSources.contains("snapshot.hasCompleteActivityGoals"))
    }

    @Test func everyManualWorkoutDeletionSurfaceRequiresConfirmation() throws {
        let summarySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutSummaryView.swift")
        let historySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutHistoryPresentationViews.swift")
        let legacySource = try source("Ohana/Features/Workouts/Views/HumanWorkoutCard.swift")

        #expect(summarySource.contains("onDelete: { pendingWorkoutDeletion = $0 }"))
        #expect(historySource.contains("onDelete(log)"))
        #expect(summarySource.contains("isPresented: workoutDeletionConfirmationIsPresented"))
        #expect(summarySource.contains("role: .destructive"))
        #expect(summarySource.contains("human-workout-confirm-delete-action"))
        #expect(legacySource.contains("pendingDeletionLog = log"))
        #expect(legacySource.contains("deletionConfirmationIsPresented"))
        #expect(legacySource.contains("human-workout-confirm-delete-action"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
