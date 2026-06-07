import Testing
@testable import Ohana

struct GrowthUnlockPolicyTests {
    @Test func dailyCareIsOpenAtLevelOne() {
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureGroup(.dailyCare), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.food), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.potty), currentLevel: 1).isUnlocked)
    }

    @Test func householdAndRewardLayersRespectTreeLevel() {
        #expect(!GrowthUnlockPolicy.status(for: FMDest.featureGroup(.householdHub), currentLevel: 3).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureGroup(.householdHub), currentLevel: 4).isUnlocked)
        #expect(!GrowthUnlockPolicy.status(for: FMDest.gacha, currentLevel: 6).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.gacha, currentLevel: 7).isUnlocked)
    }

    @Test func currentAndNextStagesTrackLevelProgression() {
        #expect(GrowthUnlockPolicy.currentStep(currentLevel: 1).id == .dailyCare)
        #expect(GrowthUnlockPolicy.currentStep(currentLevel: 4).id == .household)
        #expect(GrowthUnlockPolicy.nextLockedStep(currentLevel: 4)?.id == .oasisPlants)
        #expect(GrowthUnlockPolicy.nextLockedStep(currentLevel: 10) == nil)
    }

    @Test func newlyUnlockedStagesOnlyReturnsCrossedThresholds() {
        #expect(GrowthUnlockPolicy.newlyUnlockedStages(from: 2, to: 2).isEmpty)

        let unlocked = GrowthUnlockPolicy.newlyUnlockedStages(from: 3, to: 6).map(\.id)
        #expect(unlocked == [.household, .oasisPlants, .rewards])
    }
}
