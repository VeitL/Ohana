import Foundation
import Testing
@testable import Ohana

@Suite(.serialized)
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

    @Test func plantGateOwnsBuildScopeAndGrowthUnlockTreatsPlantsAsHousehold() {
        PlantUnlockPolicy.clearExistingPlantData()
        PlantLockedPreviewPolicy.clearOnboardingPlantInterest()
        defer { PlantUnlockPolicy.clearExistingPlantData() }
        defer { PlantLockedPreviewPolicy.clearOnboardingPlantInterest() }

        #expect(PlantFeatureGate.allows(.plants))
        #expect(!GrowthUnlockPolicy.availability(for: FMDest.plantsDashboard, currentLevel: 3).isVisibleInApp)
        #expect(!GrowthUnlockPolicy.availability(for: FeatureGroup.plants, currentLevel: 3).isVisibleInApp)
        #expect(GrowthUnlockPolicy.availability(for: FMDest.plantsDashboard, currentLevel: 4).isVisibleInApp)
        #expect(GrowthUnlockPolicy.availability(for: FeatureGroup.plants, currentLevel: 4).isVisibleInApp)

        if case .redirectToRoadmap = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 3) {
            #expect(Bool(true))
        } else {
            Issue.record("Expected plant dashboard destination to redirect before Lv4")
        }
        #expect(!AppFeatureRouteGuard.availability(for: FMDest.plantsDashboard, currentLevel: 3).isVisibleInApp)
        #expect(!AppFeatureRouteGuard.availability(for: FeatureGroup.plants, currentLevel: 3).isVisibleInApp)
        #expect(AppFeatureRouteGuard.availability(for: FMDest.plantsDashboard, currentLevel: 4).isVisibleInApp)
        #expect(AppFeatureRouteGuard.availability(for: FeatureGroup.plants, currentLevel: 4).isVisibleInApp)
    }

    @Test func plantLockedPreviewSetsExpectationWithoutUnlockingCare() {
        PlantUnlockPolicy.clearExistingPlantData()
        PlantLockedPreviewPolicy.clearOnboardingPlantInterest()
        defer { PlantUnlockPolicy.clearExistingPlantData() }
        defer { PlantLockedPreviewPolicy.clearOnboardingPlantInterest() }

        #expect(!PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: 3))

        PlantLockedPreviewPolicy.noteOnboardingPlantInterest()

        #expect(PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: 3))
        #expect(!PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: 4))
        #expect(PlantLockedPreviewPolicy.levelsRemaining(currentLevel: 2) == 2)
        #expect(PlantLockedPreviewPolicy.energyRemainingForUnlock(currentEnergy: 300) == 200)
        #expect(!AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
        #expect(!AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 3).contains(.plants))

        if case .redirectToRoadmap = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 3) {
        } else {
            Issue.record("Expected locked preview to keep plant dashboard behind Growth Roadmap before Lv4")
        }
    }

    @Test func existingPlantDataSuppressesLockedPreviewBeforeLevelFour() {
        let suiteName = "GrowthUnlockPolicyTests.existingPlantDataSuppressesLockedPreviewBeforeLevelFour.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        PlantLockedPreviewPolicy.noteOnboardingPlantInterest(defaults: defaults)
        #expect(PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: 3, defaults: defaults))

        PlantUnlockPolicy.noteExistingPlantData(defaults: defaults)
        #expect(!PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: 3, defaults: defaults))
    }

    @Test func growthRoadmapIsAlwaysVisible() {
        #expect(GrowthUnlockPolicy.availability(for: FMDest.growthRoadmap, currentLevel: 0).isVisibleInApp)
        #expect(GrowthUnlockPolicy.availability(for: FMDest.growthRoadmap, currentLevel: 10).isVisibleInApp)
    }

    @Test func featureRouteGuardRedirectsLockedAndSuppressesGatedDestinations() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        if case .redirectToRoadmap = AppFeatureRouteGuard.functionDestinationDecision(.gacha, currentLevel: 3) {
        } else {
            Issue.record("Expected locked gacha destination to redirect to the growth roadmap")
        }
        if case .redirectToRoadmap = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 3) {
        } else {
            Issue.record("Expected plant dashboard destination to redirect before Lv4")
        }
        if case .allow(.plantsDashboard) = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 4) {
        } else {
            Issue.record("Expected plant dashboard destination to be allowed at Lv4")
        }
        #expect(AppFeatureRouteGuard.isVisibleFunctionDestination(.featureGroup(.dailyCare), currentLevel: 1))
        #expect(!AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
        #expect(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 4))
        #expect(!AppFeatureRouteGuard.allowsSheetRoute(.coconutShop(.boost), currentLevel: 5))
        #expect(AppFeatureRouteGuard.allowsSheetRoute(.coconutShop(.boost), currentLevel: 6))
        #expect(!AppFeatureRouteGuard.allowsOasisSheetRoute(.gacha, currentLevel: 6))
        #expect(AppFeatureRouteGuard.allowsOasisSheetRoute(.gacha, currentLevel: 7))
    }

    @Test func featureRouteGuardOwnsGlobalVisibilityDecisions() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let suiteName = "GrowthUnlockPolicyTests.featureRouteGuardOwnsGlobalVisibilityDecisions.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)

        #expect(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 1, starterGiftDefaults: defaults) == [.home, .calendar, .oasis])
        #expect(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 4, starterGiftDefaults: defaults) == [.home, .calendar, .oasis, .plants])
        #expect(AppFeatureRouteGuard.shouldLoadPlantData)

        let levelOneGroups = AppFeatureRouteGuard.visibleFeatureGroups(
            from: [.dailyCare, .healthBody, .archiveMemory, .householdHub, .plants],
            currentLevel: 1
        )
        #expect(levelOneGroups == [.dailyCare])

        let levelFourGroups = AppFeatureRouteGuard.visibleFeatureGroups(
            from: [.dailyCare, .healthBody, .archiveMemory, .householdHub, .plants],
            currentLevel: 4
        )
        #expect(levelFourGroups == [.dailyCare, .healthBody, .archiveMemory, .householdHub, .plants])

        let oasisStep = GrowthUnlockPolicy.status(for: GrowthUnlockStageID.oasisPlants, currentLevel: 5).step
        if case .wealthDashboard = AppFeatureRouteGuard.recommendedDestination(for: oasisStep, currentLevel: 5) {
        } else {
            Issue.record("Expected Oasis stage to recommend the wealth dashboard")
        }
    }

    @Test func existingPlantDataGrandfathersPlantAccessBeforeLevelFour() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        #expect(!AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))

        PlantUnlockPolicy.noteExistingPlantData()

        #expect(AppFeatureRouteGuard.allowsAddEntity(.plant, currentLevel: 3))
        #expect(AppFeatureRouteGuard.visibleHomeTabs(currentLevel: 3).contains(.plants))
        if case .allow(.plantsDashboard) = AppFeatureRouteGuard.functionDestinationDecision(.plantsDashboard, currentLevel: 3) {
        } else {
            Issue.record("Expected existing plant data to keep the plant dashboard reachable")
        }
    }

    @Test func visibleHomeTabsOnlyAppendWhenOasisUnlocksBeforeGrandfatheredPlants() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let suiteName = "GrowthUnlockPolicyTests.visibleHomeTabsOnlyAppendWhenOasisUnlocksBeforeGrandfatheredPlants.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        PlantUnlockPolicy.noteExistingPlantData()
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(false, forKey: StarterGiftStorageKey.ceremonySeen)

        #expect(AppFeatureRouteGuard.allowsHomeTab(.plants, currentLevel: 3, starterGiftDefaults: defaults))
        let beforeOasisUnlock = AppFeatureRouteGuard.visibleHomeTabs(
            currentLevel: 3,
            starterGiftDefaults: defaults
        )
        #expect(beforeOasisUnlock == [.home, .calendar])

        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)

        let afterOasisUnlock = AppFeatureRouteGuard.visibleHomeTabs(
            currentLevel: 3,
            starterGiftDefaults: defaults
        )
        #expect(afterOasisUnlock == [.home, .calendar, .oasis, .plants])
        #expect(Array(afterOasisUnlock.prefix(beforeOasisUnlock.count)) == beforeOasisUnlock)
    }
}
