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

    @Test func appRouteSinkInterceptsBasicProfileSheets() {
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()
        var appRoutes: [HomeAppRoute] = []

        coordinator.bindAppRouteSink { route in
            appRoutes.append(route)
        }

        coordinator.openSheet(.petBasicInfo(pet.id))
        coordinator.openSheet(.humanBasicInfo(human.id))

        #expect(appRoutes == [
            .petProfile(id: pet.id, initialTab: .overview),
            .humanProfile(id: human.id)
        ])
        #expect(coordinator.sheet == nil)
    }

    @Test func appRouteSinkLeavesFeatureSheetsLocal() {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()
        var appRoutes: [HomeAppRoute] = []

        coordinator.bindAppRouteSink { route in
            appRoutes.append(route)
        }

        coordinator.openSheet(.petWater(pet.id))

        #expect(appRoutes.isEmpty)
        guard case let .petWater(petID) = coordinator.sheet else {
            Issue.record("Expected pet water sheet route to remain local")
            return
        }
        #expect(petID == pet.id)
    }

    @Test func appSheetSinkInterceptsDetailSheets() {
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openSheet(.petAllFeatures(pet.id))
        coordinator.openSheet(.petFood(pet.id))
        coordinator.openSheet(.petFeed(pet.id, opensManualSheet: true))
        coordinator.openSheet(.petWater(pet.id))
        coordinator.openSheet(.petHealth(pet.id, initialSection: .preventive))
        coordinator.openSheet(.petDocuments(pet.id))
        coordinator.openSheet(.petAchievements(pet.id))
        coordinator.openSheet(.petRetention(pet.id))
        coordinator.openSheet(.petBondVault(pet.id))
        coordinator.openSheet(.humanAllFeatures(human.id))
        coordinator.openSheet(.humanMedication(human.id))
        coordinator.openSheet(.humanWeight(human.id))
        coordinator.openSheet(.humanWorkoutDashboard(human.id))
        coordinator.openSheet(.humanMetrics(human.id))
        coordinator.openSheet(.humanReport(human.id))
        coordinator.openSheet(.humanWishlist(human.id))

        let expectedRoutes: [HomeAppSheetRoute] = [
            .appSheet(.petAllFeatures(pet.id)),
            .appSheet(.petFood(pet.id)),
            .appSheet(.petFeed(pet.id, opensManualSheet: true)),
            .appSheet(.petWater(pet.id)),
            .appSheet(.petHealth(pet.id, initialSection: .preventive)),
            .appSheet(.petDocuments(pet.id)),
            .appSheet(.petAchievements(pet.id)),
            .appSheet(.petRetention(pet.id)),
            .appSheet(.petBondVault(pet.id)),
            .appSheet(.humanAllFeatures(human.id)),
            .appSheet(.humanMedication(human.id)),
            .appSheet(.humanWeight(human.id)),
            .appSheet(.humanWorkoutDashboard(human.id)),
            .appSheet(.humanMetrics(human.id)),
            .appSheet(.humanReport(human.id)),
            .appSheet(.humanWishlist(human.id))
        ]
        #expect(appSheets.count == expectedRoutes.count)
        for index in expectedRoutes.indices {
            #expect(appSheets[index] == expectedRoutes[index])
        }
        #expect(coordinator.sheet == nil)
    }

    @Test func appSheetSinkInterceptsAccountSwitcher() {
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openAccountSwitcher()

        #expect(appSheets == [.accountSwitcher])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkInterceptsFunctionMenu() {
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openFunctionMenu(destination: .plantsDashboard)

        #expect(appSheets == [.functionMenu(destination: .plantsDashboard)])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkInterceptsCalendar() {
        let petID = UUID().uuidString
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openCalendar(entityID: petID)

        #expect(appSheets == [.appSheet(.calendar(entityID: petID, humanID: nil))])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkInterceptsAddEntity() {
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openAddEntity(.pet)

        #expect(appSheets == [.addEntity(.pet)])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkInterceptsStreakDetail() {
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openStreakDetail()

        #expect(appSheets == [.streakDetail])
        #expect(coordinator.modal == nil)
    }

    @Test func appFullScreenSinkInterceptsWalkAndOasisReward() {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()
        var appFullScreens: [HomeAppFullScreenRoute] = []

        coordinator.bindAppFullScreenRouteSink { route in
            appFullScreens.append(route)
        }

        coordinator.openWalk(pet)
        coordinator.openOasisReward()

        #expect(appFullScreens == [.walk(petID: pet.id), .oasisReward])
        #expect(coordinator.fullScreen == nil)
    }

    @Test func accountSwitcherFallsBackToLocalModalWithoutAppSheetSink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openAccountSwitcher()

        guard case .accountSwitcher = coordinator.modal else {
            Issue.record("Expected account switcher to remain local without app sheet sink")
            return
        }
    }

    @Test func functionMenuFallsBackToLocalModalWithoutAppSheetSink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openFunctionMenu(destination: .plantsDashboard)

        guard case let .functionMenu(destination) = coordinator.modal else {
            Issue.record("Expected function menu to remain local without app sheet sink")
            return
        }
        #expect(destination == .plantsDashboard)
    }

    @Test func addEntityFallsBackToLocalModalWithoutAppSheetSink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openAddEntity(.plant)

        guard case let .addEntity(type) = coordinator.modal else {
            Issue.record("Expected add entity to remain local without app sheet sink")
            return
        }
        #expect(type == .plant)
    }

    @Test func streakDetailFallsBackToLocalModalWithoutAppSheetSink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openStreakDetail()

        guard case .streakDetail = coordinator.modal else {
            Issue.record("Expected streak detail to remain local without app sheet sink")
            return
        }
    }

    @Test func appOverlaySinkInterceptsCrewRoster() {
        let coordinator = HomeRouteCoordinator()
        var appOverlays: [HomeAppOverlayRoute] = []

        coordinator.bindAppOverlayRouteSink { route in
            appOverlays.append(route)
        }

        coordinator.openCrewRoster(mode: .collaboration)

        #expect(appOverlays == [.crewRoster(.collaboration)])
        #expect(coordinator.modal == nil)
    }

    @Test func appOverlaySinkInterceptsCoconutLog() {
        let humanID = UUID()
        let coordinator = HomeRouteCoordinator()
        var appOverlays: [HomeAppOverlayRoute] = []

        coordinator.bindAppOverlayRouteSink { route in
            appOverlays.append(route)
        }

        coordinator.openCoconutLog(.human(humanID))

        #expect(appOverlays == [.coconutLog(.human(humanID))])
        #expect(coordinator.fullScreen == nil)
    }

    @Test func appOverlaySinkInterceptsQuickMoment() {
        let pet = Pet(name: "Momo", species: "猫")
        let coordinator = HomeRouteCoordinator()
        var appOverlays: [HomeAppOverlayRoute] = []

        coordinator.bindAppOverlayRouteSink { route in
            appOverlays.append(route)
        }

        coordinator.openQuickMoment(pet)

        #expect(appOverlays == [.quickMoment(petID: pet.id)])
        #expect(coordinator.overlay == nil)
    }

    @Test func appOverlaySinkInterceptsSettings() {
        let coordinator = HomeRouteCoordinator()
        var appOverlays: [HomeAppOverlayRoute] = []

        coordinator.bindAppOverlayRouteSink { route in
            appOverlays.append(route)
        }

        coordinator.openSettings()

        #expect(appOverlays == [.settings])
        #expect(!coordinator.settingsPresented)
    }

    @Test func crewRosterFallsBackToLocalModalWithoutAppOverlaySink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openCrewRoster(mode: .members)

        guard case let .crewRoster(mode) = coordinator.modal else {
            Issue.record("Expected crew roster to remain local without app overlay sink")
            return
        }
        #expect(mode == .members)
    }

    @Test func coconutLogFallsBackToLocalFullScreenWithoutAppOverlaySink() {
        let petID = UUID()
        let coordinator = HomeRouteCoordinator()

        coordinator.openCoconutLog(.pet(petID))

        guard case let .coconutLog(subject) = coordinator.fullScreen else {
            Issue.record("Expected coconut log to remain local without app overlay sink")
            return
        }
        #expect(subject == .pet(petID))
    }

    @Test func settingsFallsBackToLocalInlinePresentationWithoutAppOverlaySink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openSettings()

        #expect(coordinator.settingsPresented)
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

        coordinator.openSheet(.humanWishlist(human.id))
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
