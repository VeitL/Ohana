import Foundation
@testable import Ohana
import Testing

@MainActor
struct HomeRouteCoordinatorTests {
    @Test func quickPetActionMapsToSinglePopupRouteAndDismissesById() throws {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()

        coordinator.openPetWeight(pet)

        guard case let .petWeight(_, petID) = coordinator.popup else {
            Issue.record("Expected pet weight popup route")
            return
        }
        #expect(petID == pet.id)
        #expect(coordinator.hasActiveOverlay)

        coordinator.dismissPopup(routeID: UUID())
        #expect(coordinator.popup != nil)

        let routeID = try #require(coordinator.popup?.id)
        coordinator.dismissPopup(routeID: routeID)

        #expect(coordinator.popup == nil)
        #expect(!coordinator.hasActiveOverlay)
    }

    @Test func humanRoutesCarryOnlyIdAndActionKeyThenReset() throws {
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()

        coordinator.openHumanMedication(human)

        guard case let .humanMedication(_, humanID, actionType) = coordinator.popup else {
            Issue.record("Expected human medication popup route")
            return
        }
        #expect(humanID == human.id)
        #expect(actionType == "humanMedication")
        #expect(coordinator.popup?.humanActionKey == "\(human.id.uuidString):humanMedication")

        coordinator.resetHumanRoutes()

        #expect(coordinator.popup == nil)
    }

    @Test func longDetailSheetRoutesCarryOnlyIdAndDismiss() {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()

        coordinator.openSheet(.petFeed(pet.id, opensManualSheet: true))

        guard case let .petFeed(petID, opensManualSheet) = coordinator.sheet else {
            Issue.record("Expected pet feed sheet route")
            return
        }
        #expect(petID == pet.id)
        #expect(opensManualSheet)
        #expect(!coordinator.hasActiveOverlay)

        coordinator.dismissSheet()

        #expect(coordinator.sheet == nil)
    }

    @Test func resetHumanRoutesClearsHumanSheetButKeepsPetSheet() {
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()

        coordinator.openSheet(.humanNote(human.id))
        coordinator.resetHumanRoutes()

        #expect(coordinator.sheet == nil)

        coordinator.openSheet(.petWater(pet.id))
        coordinator.resetHumanRoutes()

        guard case let .petWater(petID) = coordinator.sheet else {
            Issue.record("Expected pet water sheet route to remain active")
            return
        }
        #expect(petID == pet.id)
    }

    @Test func resetAllRoutesClearsSheetAndPopup() {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()

        coordinator.openSheet(.petWater(pet.id))
        coordinator.openPetExpense(pet)
        coordinator.resetAllRoutes()

        #expect(coordinator.sheet == nil)
        #expect(coordinator.popup == nil)
    }
}
