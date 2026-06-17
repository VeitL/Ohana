import Foundation
import Testing
@testable import Ohana

struct GrowthUnlockPolicyTests {
    @Test func dailyCareIsOpenAtLevelOne() {
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureGroup(.dailyCare), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.food), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.potty), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.health), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.medications), currentLevel: 1).isUnlocked)
        #expect(GrowthUnlockPolicy.status(for: FMDest.featureAggregate(.expense), currentLevel: 1).isUnlocked)
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

    @Test func lockedFeaturesAreHiddenInNormalAppButRemainInRoadmap() {
        let availability = GrowthUnlockPolicy.availability(for: FMDest.gacha, currentLevel: 3)

        #expect(!availability.isVisibleInApp)
        #expect(availability.status?.step.id == .advancedPlay)
        #expect(GrowthUnlockPolicy.roadmapStages().map(\.id).contains(.advancedPlay))
    }

    @Test func plantGateOwnsCurrentScopeWhileGrowthUnlockKeepsFutureSemantics() {
        #expect(!PlantFeatureGate.allows(.plants))
        #expect(GrowthUnlockPolicy.availability(for: FMDest.plantsDashboard, currentLevel: 10).isVisibleInApp)
        #expect(GrowthUnlockPolicy.availability(for: FeatureGroup.plants, currentLevel: 10).isVisibleInApp)

        if case .suppress = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 10) {
            #expect(Bool(true))
        } else {
            Issue.record("Expected plant dashboard destination to be suppressed by PlantFeatureGate")
        }
        #expect(!AppFeatureRouteGuard.availability(for: FMDest.plantsDashboard, currentLevel: 10).isVisibleInApp)
        #expect(!AppFeatureRouteGuard.availability(for: FeatureGroup.plants, currentLevel: 10).isVisibleInApp)
    }

    @Test func growthRoadmapIsAlwaysVisible() {
        #expect(GrowthUnlockPolicy.availability(for: FMDest.growthRoadmap, currentLevel: 0).isVisibleInApp)
        #expect(GrowthUnlockPolicy.availability(for: FMDest.growthRoadmap, currentLevel: 10).isVisibleInApp)
    }

    @Test func featureRouteGuardRedirectsLockedAndSuppressesGatedDestinations() {
        if case .redirectToRoadmap = AppFeatureRouteGuard.functionDestinationDecision(.gacha, currentLevel: 3) {
        } else {
            Issue.record("Expected locked gacha destination to redirect to the growth roadmap")
        }
        if case .suppress = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 10) {
        } else {
            Issue.record("Expected plant dashboard destination to be suppressed")
        }
        #expect(AppFeatureRouteGuard.isVisibleFunctionDestination(.featureGroup(.dailyCare), currentLevel: 1))
        #expect(!AppFeatureRouteGuard.allowsAddEntity(.plant))
        #expect(!AppFeatureRouteGuard.allowsSheetRoute(.coconutShop(.boost), currentLevel: 5))
        #expect(AppFeatureRouteGuard.allowsSheetRoute(.coconutShop(.boost), currentLevel: 6))
        #expect(!AppFeatureRouteGuard.allowsOasisSheetRoute(.gacha, currentLevel: 6))
        #expect(AppFeatureRouteGuard.allowsOasisSheetRoute(.gacha, currentLevel: 7))
    }

    @Test func featureRouteGuardOwnsGlobalVisibilityDecisions() {
        let suiteName = "GrowthUnlockPolicyTests.featureRouteGuardOwnsGlobalVisibilityDecisions.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: StarterGiftService.Key.claimed)
        defaults.set(true, forKey: StarterGiftService.Key.ceremonySeen)

        #expect(AppFeatureRouteGuard.visibleHomeTabs(starterGiftDefaults: defaults) == [.home, .calendar, .oasis])
        #expect(!AppFeatureRouteGuard.shouldLoadPlantData)

        let levelOneGroups = AppFeatureRouteGuard.visibleFeatureGroups(
            from: [.dailyCare, .healthBody, .archiveMemory, .householdHub, .plants],
            currentLevel: 1
        )
        #expect(levelOneGroups == [.dailyCare])

        let levelFourGroups = AppFeatureRouteGuard.visibleFeatureGroups(
            from: [.dailyCare, .healthBody, .archiveMemory, .householdHub, .plants],
            currentLevel: 4
        )
        #expect(levelFourGroups == [.dailyCare, .healthBody, .archiveMemory, .householdHub])

        let oasisStep = GrowthUnlockPolicy.status(for: GrowthUnlockStageID.oasisPlants, currentLevel: 5).step
        if case .wealthDashboard = AppFeatureRouteGuard.recommendedDestination(for: oasisStep, currentLevel: 5) {
        } else {
            Issue.record("Expected Oasis stage to recommend the wealth dashboard")
        }
    }
}
