//
//  HumanHealthActivityResolverTests.swift
//  OhanaTests
//

import Testing
@testable import Ohana

struct HumanHealthActivityResolverTests {
    @Test func directExerciseAndStandFillMissingActivitySummary() {
        let resolved = HumanHealthActivityResolver.resolve(
            summary: nil,
            fallbackActiveEnergyKcal: 432.4,
            fallbackExerciseMinutes: 28.6,
            fallbackStandHours: 7
        )

        #expect(resolved.activeEnergyKcal == 432)
        #expect(resolved.moveMode == .activeEnergy)
        #expect(resolved.moveMinutes == 0)
        #expect(resolved.exerciseMinutes == 29)
        #expect(resolved.standHours == 7)
        #expect(resolved.moveGoalKcal == 0)
        #expect(resolved.moveGoalMinutes == 0)
        #expect(resolved.exerciseGoalMinutes == 0)
        #expect(resolved.standGoalHours == 0)
    }

    @Test func directValuesBackfillPartialSummaryWithoutInventingGoals() {
        let resolved = HumanHealthActivityResolver.resolve(
            summary: HumanHealthActivityValues(
                activeEnergyKcal: 410,
                moveMode: .activeEnergy,
                moveMinutes: 0,
                exerciseMinutes: 0,
                standHours: 0,
                moveGoalKcal: 600,
                moveGoalMinutes: 0,
                exerciseGoalMinutes: 30,
                standGoalHours: 12
            ),
            fallbackActiveEnergyKcal: 400,
            fallbackExerciseMinutes: 16,
            fallbackStandHours: 5
        )

        #expect(resolved.activeEnergyKcal == 410)
        #expect(resolved.exerciseMinutes == 16)
        #expect(resolved.standHours == 5)
        #expect(resolved.moveGoalKcal == 600)
        #expect(resolved.exerciseGoalMinutes == 30)
        #expect(resolved.standGoalHours == 12)
    }

    @Test func moveTimeSummaryUsesMinutesInsteadOfCalorieGoal() {
        let resolved = HumanHealthActivityResolver.resolve(
            summary: HumanHealthActivityValues(
                activeEnergyKcal: 120,
                moveMode: .moveTime,
                moveMinutes: 42,
                exerciseMinutes: 18,
                standHours: 6,
                moveGoalKcal: 0,
                moveGoalMinutes: 60,
                exerciseGoalMinutes: 30,
                standGoalHours: 12
            ),
            fallbackActiveEnergyKcal: 110,
            fallbackExerciseMinutes: 17,
            fallbackStandHours: 5
        )

        #expect(resolved.moveMode == .moveTime)
        #expect(resolved.moveMinutes == 42)
        #expect(resolved.moveGoalMinutes == 60)
    }

    @Test func goalAvailabilityDoesNotHideValidIndividualGoals() {
        var snapshot = HumanWorkoutHealthSnapshot.empty

        #expect(snapshot.activityGoalAvailability == .unavailable)
        snapshot.moveGoalKcal = 500
        #expect(snapshot.activityGoalAvailability == .partial)
        snapshot.exerciseGoalMinutes = 30
        #expect(snapshot.activityGoalAvailability == .partial)
        snapshot.standGoalHours = 12
        #expect(snapshot.activityGoalAvailability == .complete)
    }
}
