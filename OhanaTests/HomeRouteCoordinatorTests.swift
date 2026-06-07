import Foundation
@testable import Ohana
import Testing

@MainActor
struct HomeRouteCoordinatorTests {
    @Test func quickPetActionMapsToSheetRouteAndDismisses() throws {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()

        coordinator.openSheet(.petWeight(pet.id))

        guard case let .petWeight(petID) = coordinator.sheet else {
            Issue.record("Expected pet weight sheet route")
            return
        }
        #expect(petID == pet.id)
        #expect(coordinator.alert == nil)
        #expect(coordinator.overlay == nil)

        coordinator.dismissSheet()
        #expect(coordinator.sheet == nil)
    }

    @Test func humanRoutesCarryOnlyIdAndActionKeyThenReset() throws {
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()

        coordinator.openSheet(.humanMedication(human.id))

        guard case let .humanMedication(humanID) = coordinator.sheet else {
            Issue.record("Expected human medication sheet route")
            return
        }
        #expect(humanID == human.id)

        coordinator.resetHumanRoutes()

        #expect(coordinator.sheet == nil)
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
        #expect(coordinator.alert == nil)
        #expect(coordinator.overlay == nil)

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
        coordinator.openSheet(.petExpense(pet.id))
        coordinator.openCalendar(entityID: pet.id.uuidString)
        coordinator.openOasisReward()
        coordinator.openQuickMoment(pet)
        coordinator.showQuickActionLimit()
        coordinator.resetAllRoutes()

        #expect(coordinator.sheet == nil)
        #expect(coordinator.modal == nil)
        #expect(coordinator.fullScreen == nil)
        #expect(coordinator.overlay == nil)
        #expect(coordinator.alert == nil)
    }

    @Test func homePresentationRoutesCarryLightweightValues() {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()

        coordinator.openCalendar(entityID: pet.id.uuidString, humanID: nil)

        guard case let .calendar(entityID, humanID) = coordinator.modal else {
            Issue.record("Expected calendar modal route")
            return
        }
        #expect(entityID == pet.id.uuidString)
        #expect(humanID == nil)

        coordinator.openWalk(pet)

        guard case let .walk(petID) = coordinator.fullScreen else {
            Issue.record("Expected walk full-screen route")
            return
        }
        #expect(petID == pet.id)

        coordinator.openQuickMoment(pet)

        guard case let .quickMoment(_, petID) = coordinator.overlay else {
            Issue.record("Expected quick moment overlay route")
            return
        }
        #expect(petID == pet.id)
    }

    @Test func antiRepeatAlertOwnsPendingActionUntilConfirmedOrDismissed() {
        let coordinator = HomeRouteCoordinator()
        var didRun = false

        coordinator.showAntiRepeat(title: "Again?", message: "Confirm") {
            didRun = true
        }

        guard case let .antiRepeat(_, title, message) = coordinator.alert else {
            Issue.record("Expected anti-repeat alert")
            return
        }
        #expect(title == "Again?")
        #expect(message == "Confirm")
        #expect(!didRun)

        coordinator.confirmAntiRepeatAction()

        #expect(didRun)
        #expect(coordinator.alert == nil)
        #expect(coordinator.pendingRepeatAction == nil)
    }
}
