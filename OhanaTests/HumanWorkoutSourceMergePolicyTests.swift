//
//  HumanWorkoutSourceMergePolicyTests.swift
//  OhanaTests
//

import Testing
@testable import Ohana

struct HumanWorkoutSourceMergePolicyTests {
    @Test func manualLocalWorkoutRemainsVisible() {
        #expect(HumanWorkoutSourceMergePolicy.shouldShowLocalLog(
            healthKitWorkoutUUID: "",
            sourcePetWalkLogID: "",
            liveHealthKitIDs: ["health-1"],
            livePetWalkIDs: ["walk-1"]
        ))
    }

    @Test func liveHealthKitWorkoutSuppressesLegacyLocalCopy() {
        #expect(!HumanWorkoutSourceMergePolicy.shouldShowLocalLog(
            healthKitWorkoutUUID: "health-1",
            sourcePetWalkLogID: "",
            liveHealthKitIDs: ["health-1"],
            livePetWalkIDs: []
        ))
    }

    @Test func livePetWalkSuppressesLegacyLocalCopy() {
        #expect(!HumanWorkoutSourceMergePolicy.shouldShowLocalLog(
            healthKitWorkoutUUID: "",
            sourcePetWalkLogID: "walk-1",
            liveHealthKitIDs: [],
            livePetWalkIDs: ["walk-1"]
        ))
    }

    @Test func externalLocalCopyRemainsWhenLiveSourceIsUnavailable() {
        #expect(HumanWorkoutSourceMergePolicy.shouldShowLocalLog(
            healthKitWorkoutUUID: "health-1",
            sourcePetWalkLogID: "walk-1",
            liveHealthKitIDs: [],
            livePetWalkIDs: []
        ))
    }
}
