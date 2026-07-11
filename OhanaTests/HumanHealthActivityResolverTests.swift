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
        #expect(resolved.exerciseMinutes == 29)
        #expect(resolved.standHours == 7)
        #expect(resolved.moveGoalKcal == 0)
        #expect(resolved.exerciseGoalMinutes == 0)
        #expect(resolved.standGoalHours == 0)
    }

    @Test func directValuesBackfillPartialSummaryWithoutInventingGoals() {
        let resolved = HumanHealthActivityResolver.resolve(
            summary: HumanHealthActivityValues(
                activeEnergyKcal: 410,
                exerciseMinutes: 0,
                standHours: 0,
                moveGoalKcal: 600,
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
}
