import Foundation
@testable import Ohana
import Testing

@MainActor
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
}
