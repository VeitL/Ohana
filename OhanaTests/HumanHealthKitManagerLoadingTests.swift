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
        #expect(source.contains("let activity = resolvedHealthValue"))
        #expect(source.contains("errorMessage = firstError.localizedDescription"))

        let rawContinuationCount = source.components(separatedBy: "withCheckedThrowingContinuation").count - 1
        #expect(rawContinuationCount == 1)
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
