import Foundation
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct AppRouteCoordinatorTests {
    @Test func profileRoutesCarryOnlyStableIdentifiers() {
        let coordinator = AppRouteCoordinator()
        let petID = UUID()
        let humanID = UUID()

        coordinator.openPet(petID, initialTab: .health)
        coordinator.openHuman(humanID)

        #expect(coordinator.path.count == 2)
        #expect(coordinator.path[0] == .petProfile(id: petID, initialTab: .health))
        #expect(coordinator.path[1] == .humanProfile(id: humanID))
    }

    @Test func requiredPresentationRoutesAreMutuallyExclusive() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentRequiredHumanProfile()

        #expect(coordinator.fullScreen == .requiredHumanProfile)
        #expect(coordinator.sheet == nil)

        coordinator.presentRequiredAccountSwitch()

        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .requiredAccountSwitch)
    }

    @Test func globalPresentationPolicyOwnsOpenAndLoadingStyle() {
        let petID = UUID()
        let pushPolicy = AppPresentationPolicyProvider.policy(
            for: AppRoute.petProfile(id: petID, initialTab: .overview)
        )
        let menuPolicy = AppPresentationPolicyProvider.policy(
            for: AppSheetRoute.functionMenu(destination: .growthRoadmap)
        )
        let accountPolicy = AppPresentationPolicyProvider.policy(
            for: AppSheetRoute.requiredAccountSwitch
        )
        let fullScreenPolicy = AppPresentationPolicyProvider.policy(
            for: AppFullScreenRoute.walk(petID: petID)
        )
        let overlayPolicy = AppPresentationPolicyProvider.policy(
            for: AppOverlayRoute.quickMoment(petID: petID)
        )

        #expect(pushPolicy.surface == .navigationPush)
        #expect(pushPolicy.loading == .shellFirst(delayMS: 48))
        #expect(menuPolicy.surface == .sheetPage)
        #expect(menuPolicy.loading == .shellFirst(delayMS: 80))
        #expect(accountPolicy.surface == .compactSheet)
        #expect(accountPolicy.loading == .shellFirst(delayMS: 64))
        #expect(fullScreenPolicy.surface == .fullScreen)
        #expect(fullScreenPolicy.loading == .shellFirst(delayMS: 64))
        #expect(overlayPolicy.surface == .inlineOverlay)
        #expect(overlayPolicy.loading == .immediate)
    }

    @Test func accountSwitcherUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentRequiredHumanProfile()
        coordinator.presentAccountSwitcher()

        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .accountSwitcher)
    }

    @Test func functionMenuUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentSettings()
        coordinator.presentFunctionMenu(destination: .featureGroup(.dailyCare))

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .functionMenu(destination: .featureGroup(.dailyCare)))
    }

    @Test func calendarUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()
        let petID = UUID().uuidString

        coordinator.presentSettings()
        coordinator.presentCalendar(entityID: petID)

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .calendar(entityID: petID, humanID: nil))
    }

    @Test func coconutShopUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()
        let treeManager = TestOasisTreeManagerProjection.manager
        let oldTreeManager = OasisTreeManagerRegistry.current
        let oldIslandEnergy = treeManager.islandEnergy
        let oldInjectedEnergy = treeManager.injectedEnergy
        OasisTreeManagerRegistry.current = treeManager
        defer {
            treeManager.islandEnergy = oldIslandEnergy
            treeManager.injectedEnergy = oldInjectedEnergy
            OasisTreeManagerRegistry.current = oldTreeManager
        }
        treeManager.islandEnergy = 0
        treeManager.injectedEnergy = 800

        coordinator.presentSettings()
        coordinator.presentCoconutShop(category: .boost)

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .coconutShop(.boost))
        #expect(coordinator.sheet?.id == "coconut-shop-boost")
    }

    @Test func lockedCoconutShopRedirectsToGrowthRoadmap() {
        let coordinator = AppRouteCoordinator()
        let treeManager = TestOasisTreeManagerProjection.manager
        let oldTreeManager = OasisTreeManagerRegistry.current
        let oldIslandEnergy = treeManager.islandEnergy
        let oldInjectedEnergy = treeManager.injectedEnergy
        OasisTreeManagerRegistry.current = treeManager
        defer {
            treeManager.islandEnergy = oldIslandEnergy
            treeManager.injectedEnergy = oldInjectedEnergy
            OasisTreeManagerRegistry.current = oldTreeManager
        }
        treeManager.islandEnergy = 0
        treeManager.injectedEnergy = 0

        coordinator.presentSettings()
        coordinator.presentCoconutShop(category: .boost)

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .functionMenu(destination: .growthRoadmap))
    }

    @Test func addEntityUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentSettings()
        coordinator.presentAddEntity(.pet)

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .addEntity(.pet))
    }

    @Test func plantRoutesAreSuppressedWhilePlantsAreOutOfScope() {
        let coordinator = AppRouteCoordinator()
        let plantID = UUID()

        coordinator.openPlant(plantID)
        #expect(coordinator.path.isEmpty)

        coordinator.push(.plantProfile(id: plantID))
        #expect(coordinator.path.isEmpty)

        coordinator.presentSettings()
        coordinator.presentFunctionMenu(destination: .plantsDashboard)

        #expect(coordinator.overlay == nil)
        #expect(coordinator.sheet == .functionMenu(destination: nil))
        #expect(coordinator.fullScreen == nil)

        coordinator.presentSettings()
        coordinator.presentAddEntity(.plant)

        #expect(coordinator.overlay == nil)
        #expect(coordinator.sheet == .settings)
        #expect(coordinator.fullScreen == nil)
    }

    @Test func detailSheetUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()
        let petID = UUID()
        let humanID = UUID()

        coordinator.presentSettings()
        coordinator.presentSheet(.petAllFeatures(petID))

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .petAllFeatures(petID))

        coordinator.presentSheet(.petFood(petID))
        #expect(coordinator.sheet == .petFood(petID))

        coordinator.presentSheet(.petBasicInfo(petID))
        #expect(coordinator.sheet == .petBasicInfo(petID))

        coordinator.presentSheet(.petHealth(petID, initialSection: .preventive))
        #expect(coordinator.sheet == .petHealth(petID, initialSection: .preventive))

        coordinator.presentSheet(.petFeed(petID, opensManualSheet: true))
        #expect(coordinator.sheet == .petFeed(petID, opensManualSheet: true))

        coordinator.presentSheet(.petDocuments(petID))
        #expect(coordinator.sheet == .petDocuments(petID))

        coordinator.presentSheet(.petAchievements(petID))
        #expect(coordinator.sheet == .petAchievements(petID))

        coordinator.presentSheet(.petRetention(petID))
        #expect(coordinator.sheet == .petRetention(petID))

        coordinator.presentSheet(.petBondVault(petID))
        #expect(coordinator.sheet == .petBondVault(petID))

        coordinator.presentSheet(.humanAllFeatures(humanID))
        #expect(coordinator.sheet == .humanAllFeatures(humanID))

        coordinator.presentSheet(.humanBasicInfo(humanID))
        #expect(coordinator.sheet == .humanBasicInfo(humanID))

        coordinator.presentSheet(.humanMedication(humanID))
        #expect(coordinator.sheet == .humanMedication(humanID))

        coordinator.presentSheet(.humanWorkoutDashboard(humanID))
        #expect(coordinator.sheet == .humanWorkoutDashboard(humanID))

        coordinator.presentSheet(.humanMetrics(humanID))
        #expect(coordinator.sheet == .humanMetrics(humanID))

        coordinator.presentSheet(.humanReport(humanID))
        #expect(coordinator.sheet == .humanReport(humanID))

        coordinator.presentSheet(.humanWishlist(humanID))
        #expect(coordinator.sheet == .humanWishlist(humanID))
    }

    @Test func walkUsesGlobalFullScreenRoute() {
        let coordinator = AppRouteCoordinator()
        let petID = UUID()

        coordinator.presentFunctionMenu(destination: .plantsDashboard)
        coordinator.presentWalk(petID: petID)

        #expect(coordinator.sheet == nil)
        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == .walk(petID: petID))
        #expect(coordinator.suppressesGlobalWalkBanner)
    }

    @Test func oasisRewardUsesGlobalFullScreenRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentFunctionMenu(destination: .plantsDashboard)
        coordinator.presentOasisReward()

        #expect(coordinator.sheet == nil)
        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == .oasisReward)
        #expect(coordinator.suppressesGlobalWalkBanner)
    }

    @Test func crewRosterUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentRequiredAccountSwitch()
        coordinator.presentCrewRoster(mode: .collaboration)

        #expect(coordinator.sheet == .crewRoster(.collaboration))
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.overlay == nil)
        #expect(!coordinator.suppressesGlobalWalkBanner)

        coordinator.dismissSheet(.crewRoster(.members))
        #expect(coordinator.sheet == .crewRoster(.collaboration))

        coordinator.dismissSheet(.crewRoster(.collaboration))
        #expect(coordinator.sheet == nil)
    }

    @Test func coconutLogUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()
        let humanID = UUID()

        coordinator.presentRequiredAccountSwitch()
        coordinator.presentCoconutLog(.human(humanID))

        #expect(coordinator.sheet == .coconutLog(.human(humanID)))
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.overlay == nil)
        #expect(!coordinator.suppressesGlobalWalkBanner)

        coordinator.presentCoconutLog(nil)
        #expect(coordinator.sheet == .coconutLog(nil))
        #expect(coordinator.sheet?.id == "coconut-log-all")
    }

    @Test func coconutLogClearsCoconutShopSheet() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentCoconutShop(category: .boost)
        coordinator.presentCoconutLog(nil)

        #expect(coordinator.sheet == .coconutLog(nil))
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.overlay == nil)
    }

    @Test func quickMomentUsesGlobalOverlayRoute() {
        let coordinator = AppRouteCoordinator()
        let petID = UUID()

        coordinator.presentFunctionMenu(destination: .plantsDashboard)
        coordinator.presentQuickMoment(petID: petID)

        #expect(coordinator.sheet == nil)
        #expect(coordinator.fullScreen == nil)
        guard case let .quickMoment(_, routedPetID) = coordinator.overlay else {
            Issue.record("Expected quick moment overlay route")
            return
        }
        #expect(routedPetID == petID)
        #expect(coordinator.suppressesGlobalWalkBanner)
    }

    @Test func settingsUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentRequiredAccountSwitch()
        coordinator.presentSettings()

        #expect(coordinator.sheet == .settings)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.overlay == nil)
        #expect(!coordinator.suppressesGlobalWalkBanner)
    }

    @Test func streakDetailUsesGlobalSheetRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentCrewRoster(mode: .members)
        coordinator.presentStreakDetail()

        #expect(coordinator.overlay == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .streakDetail)
    }

    @Test func dismissOnlyClearsMatchingPresentationRoute() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentRequiredHumanProfile()
        coordinator.dismissSheet(.requiredAccountSwitch)
        #expect(coordinator.fullScreen == .requiredHumanProfile)

        coordinator.dismissFullScreen()
        #expect(coordinator.fullScreen == nil)

        coordinator.presentRequiredAccountSwitch()
        coordinator.dismissFullScreen(.requiredHumanProfile)
        #expect(coordinator.sheet == .requiredAccountSwitch)

        coordinator.dismissSheet(.requiredAccountSwitch)
        #expect(coordinator.sheet == nil)
    }

    @Test func resetToHomeClearsNavigationAndPresentations() {
        let coordinator = AppRouteCoordinator()

        coordinator.openPlant(UUID())
        coordinator.presentRequiredAccountSwitch()

        coordinator.resetToHome()

        #expect(coordinator.path.isEmpty)
        #expect(coordinator.sheet == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.overlay == nil)
    }

    @Test func rootIdentityRebuildsOnlyWhenRequested() {
        let coordinator = AppRouteCoordinator()
        let initialRoot = coordinator.rootIdentity

        coordinator.resetToHome()

        #expect(coordinator.rootIdentity == initialRoot)

        coordinator.resetToHome(rebuildRoot: true)

        #expect(coordinator.rootIdentity != initialRoot)
    }

    @Test func humanDeletionNotificationRoutesThroughCoordinator() {
        let coordinator = AppRouteCoordinator()
        let initialRoot = coordinator.rootIdentity

        coordinator.openPet(UUID())
        let outcome = coordinator.handleNotificationEvent(
            .humanDeleted(requiresReplacementHuman: true, requiresAccountSwitch: false)
        )

        #expect(outcome == .clearActiveHuman)
        #expect(coordinator.path.isEmpty)
        #expect(coordinator.rootIdentity != initialRoot)
        #expect(coordinator.fullScreen == .requiredHumanProfile)
        #expect(coordinator.sheet == nil)
    }

    @Test func accountSwitchNotificationRoutesThroughCoordinator() {
        let coordinator = AppRouteCoordinator()

        let outcome = coordinator.handleNotificationEvent(
            .humanDeleted(requiresReplacementHuman: false, requiresAccountSwitch: true)
        )

        #expect(outcome == .clearActiveHuman)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == .requiredAccountSwitch)
    }

    @Test func plainHumanDeletionRequestsRequirementReconciliation() {
        let coordinator = AppRouteCoordinator()

        let outcome = coordinator.handleNotificationEvent(
            .humanDeleted(requiresReplacementHuman: false, requiresAccountSwitch: false)
        )

        #expect(outcome == .reconcileHumanRequirement)
        #expect(coordinator.path.isEmpty)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.sheet == nil)
    }

    @Test func reminderNotificationOnlyResetsToHome() {
        let coordinator = AppRouteCoordinator()
        let initialRoot = coordinator.rootIdentity

        coordinator.openHuman(UUID())
        coordinator.presentRequiredAccountSwitch()
        let outcome = coordinator.handleNotificationEvent(.reminderRouteRequested)

        #expect(outcome == .none)
        #expect(coordinator.path.isEmpty)
        #expect(coordinator.sheet == nil)
        #expect(coordinator.rootIdentity == initialRoot)
    }
}
