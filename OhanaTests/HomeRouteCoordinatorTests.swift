import Foundation
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
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

    @Test func appSheetSinkInterceptsLongDetailSheets() {
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

        coordinator.openFunctionMenu(destination: .featureGroup(.dailyCare), currentLevel: 1)

        #expect(appSheets == [.functionMenu(destination: .featureGroup(.dailyCare))])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkRedirectsPlantFunctionMenuBeforeLevelFour() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openFunctionMenu(destination: .plantsDashboard, currentLevel: 1)

        #expect(appSheets == [.functionMenu(destination: .growthRoadmap)])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkAllowsPlantFunctionMenuAtLevelFour() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openFunctionMenu(destination: .plantsDashboard, currentLevel: 4)

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

        #expect(appSheets == [.appSheet(.calendar(entityID: petID, humanID: nil, plantID: nil))])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkIgnoresLegacyPlantCalendarSlot() {
        let plantID = UUID().uuidString
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openCalendar(plantID: plantID)

        #expect(appSheets == [.appSheet(.calendar(entityID: nil, humanID: nil, plantID: nil))])
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

    @Test func appSheetSinkRedirectsPlantAddEntityBeforeLevelFour() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openAddEntity(.plant, currentLevel: 3)

        #expect(appSheets == [.functionMenu(destination: .growthRoadmap)])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkInterceptsPlantAddEntityAtLevelFour() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openAddEntity(.plant, currentLevel: 4)

        #expect(appSheets == [.addEntity(.plant)])
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

    @Test func expandedFabRouterKeepsQuickWalkOnCardAndDetailWalkInSummary() {
        let pet = Pet(name: "Lilo", species: "Dog")
        let card = FocusCard.from(pet)
        var quickWalkIDs: [UUID] = []
        var summaryWalkIDs: [UUID] = []
        let interaction = HomeInteractionSnapshot(
            activeHuman: nil,
            islandCoconutBalance: 0,
            petsByID: [
                pet.id: HomePetInteractionSnapshot(
                    id: pet.id,
                    species: pet.species,
                    hasPassedAway: pet.hasPassedAway
                )
            ],
            humansByID: [:],
            plantIDs: [],
            firstActivePetID: pet.id,
            petMedicationTargetsByMedicationID: [:],
            eventRoutesByEventID: [:],
            expandedActionsByCardID: [:]
        )

        let actions = FocusHomeExpandedFabRouter.Actions(
            showPetAllFeatures: { _ in },
            showHumanAllFeatures: { _ in },
            openFeed: { _ in },
            openWater: { _ in },
            openWalk: { quickWalkIDs.append($0) },
            openWalkSummary: { summaryWalkIDs.append($0) },
            openPotty: { _ in },
            openPlay: { _ in },
            openMedication: { _ in },
            openHygiene: { _ in },
            openMoment: { _ in },
            openHealth: { _ in },
            openWeight: { _ in },
            openExpense: { _ in },
            showHumanWeight: { _ in },
            showHumanWorkout: { _ in },
            showHumanMedication: { _ in },
            showHumanNote: { _ in },
            quickHumanExpense: { _ in },
            showPrivacyAlert: {}
        )

        FocusHomeExpandedFabRouter.open(
            ExpandedCardFabShortcut(label: "Walk", icon: "figure.walk", action: .quick("walk")),
            card: card,
            interaction: interaction,
            actions: actions
        )
        FocusHomeExpandedFabRouter.open(
            ExpandedCardFabShortcut(label: "Walks", icon: "figure.walk", action: .detail(.walks)),
            card: card,
            interaction: interaction,
            actions: actions
        )

        #expect(quickWalkIDs == [pet.id])
        #expect(summaryWalkIDs == [pet.id])
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

        coordinator.openFunctionMenu(destination: .featureGroup(.dailyCare), currentLevel: 1)

        guard case let .functionMenu(destination) = coordinator.modal else {
            Issue.record("Expected function menu to remain local without app sheet sink")
            return
        }
        #expect(destination == .featureGroup(.dailyCare))
    }

    @Test func addPlantRedirectsToLocalRoadmapBeforeLevelFourWithoutAppSheetSink() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let coordinator = HomeRouteCoordinator()

        coordinator.openAddEntity(.plant, currentLevel: 3)

        guard case let .functionMenu(destination) = coordinator.modal else {
            Issue.record("Expected plant add route to redirect locally")
            return
        }
        #expect(destination == .growthRoadmap)
    }

    @Test func addPlantOpensLocalModalAtLevelFourWithoutAppSheetSink() {
        PlantUnlockPolicy.clearExistingPlantData()
        defer { PlantUnlockPolicy.clearExistingPlantData() }

        let coordinator = HomeRouteCoordinator()

        coordinator.openAddEntity(.plant, currentLevel: 4)

        guard case let .addEntity(type) = coordinator.modal else {
            Issue.record("Expected plant add route to open locally")
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

    @Test func appSheetSinkInterceptsCrewRoster() {
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openCrewRoster(mode: .collaboration)

        #expect(appSheets == [.appSheet(.crewRoster(.members))])
        #expect(coordinator.modal == nil)
    }

    @Test func appSheetSinkInterceptsCoconutLog() {
        let humanID = UUID()
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openCoconutLog(.human(humanID))

        #expect(appSheets == [.appSheet(.coconutLog(.human(humanID)))])
        #expect(coordinator.fullScreen == nil)

        coordinator.openCoconutLog(nil)
        #expect(appSheets.last == .appSheet(.coconutLog(nil)))
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

    @Test func appOverlaySinkInterceptsQuickEntryPopups() {
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()
        var appOverlays: [HomeAppOverlayRoute] = []

        coordinator.bindAppOverlayRouteSink { route in
            appOverlays.append(route)
        }

        coordinator.openPetWeightQuick(pet.id)
        coordinator.openSheet(.petExpenseQuick(pet.id))
        coordinator.openSheet(.humanMedicationQuick(human.id))
        coordinator.openHumanWeightQuick(human.id)
        coordinator.openSheet(.humanWorkoutQuick(human.id))
        coordinator.openSheet(.humanExpenseQuick(human.id))
        coordinator.openSheet(.humanNoteQuick(human.id))

        #expect(appOverlays == [
            .petWeightQuick(petID: pet.id),
            .petExpenseQuick(petID: pet.id),
            .humanMedicationQuick(humanID: human.id),
            .humanWeightQuick(humanID: human.id),
            .humanWorkoutQuick(humanID: human.id),
            .humanExpenseQuick(humanID: human.id),
            .humanNoteQuick(humanID: human.id)
        ])
        #expect(coordinator.overlay == nil)
        #expect(coordinator.sheet == nil)
    }

    @Test func localHumanQuickPreferenceKeepsHumanQuickPopupsInHomeOverlay() {
        let pet = Pet(name: "Momo", species: "猫")
        let human = Human(name: "Guan")
        let coordinator = HomeRouteCoordinator()
        var appOverlays: [HomeAppOverlayRoute] = []

        coordinator.bindAppOverlayRouteSink { route in
            appOverlays.append(route)
        }
        coordinator.preferLocalHumanQuickOverlays()

        coordinator.openPetWeightQuick(pet.id)
        #expect(appOverlays == [.petWeightQuick(petID: pet.id)])
        #expect(coordinator.overlay == nil)

        coordinator.openSheet(.humanMedicationQuick(human.id))
        guard case let .humanMedicationQuick(_, medicationHumanID) = coordinator.overlay else {
            Issue.record("Expected human medication quick to stay in the Home overlay")
            return
        }
        #expect(medicationHumanID == human.id)

        coordinator.openHumanWeightQuick(human.id)
        guard case let .humanWeightQuick(_, weightHumanID) = coordinator.overlay else {
            Issue.record("Expected human weight quick to stay in the Home overlay")
            return
        }
        #expect(weightHumanID == human.id)

        coordinator.openSheet(.humanWorkoutQuick(human.id))
        guard case let .humanWorkoutQuick(_, workoutHumanID) = coordinator.overlay else {
            Issue.record("Expected human workout quick to stay in the Home overlay")
            return
        }
        #expect(workoutHumanID == human.id)

        coordinator.openSheet(.humanExpenseQuick(human.id))
        guard case let .humanExpenseQuick(_, expenseHumanID) = coordinator.overlay else {
            Issue.record("Expected human expense quick to stay in the Home overlay")
            return
        }
        #expect(expenseHumanID == human.id)

        coordinator.openSheet(.humanNoteQuick(human.id))
        guard case let .humanNoteQuick(_, noteHumanID) = coordinator.overlay else {
            Issue.record("Expected human note quick to stay in the Home overlay")
            return
        }
        #expect(noteHumanID == human.id)
        #expect(appOverlays == [.petWeightQuick(petID: pet.id)])
        #expect(coordinator.sheet == nil)
    }

    @Test func appSheetSinkInterceptsSettings() {
        let coordinator = HomeRouteCoordinator()
        var appSheets: [HomeAppSheetRoute] = []

        coordinator.bindAppSheetRouteSink { route in
            appSheets.append(route)
        }

        coordinator.openSettings()

        #expect(appSheets == [.appSheet(.settings)])
        #expect(!coordinator.settingsPresented)
    }

    @Test func crewRosterFallsBackToLocalModalWithoutAppSheetSink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openCrewRoster(mode: .members)

        guard case let .crewRoster(mode) = coordinator.modal else {
            Issue.record("Expected crew roster to remain local without app overlay sink")
            return
        }
        #expect(mode == .members)
    }

    @Test func coconutLogFallsBackToLocalModalWithoutAppSheetSink() {
        let petID = UUID()
        let coordinator = HomeRouteCoordinator()

        coordinator.openCoconutLog(.pet(petID))

        guard case let .coconutLog(subject) = coordinator.modal else {
            Issue.record("Expected coconut log to remain local without app sheet sink")
            return
        }
        #expect(subject == .pet(petID))

        coordinator.openCoconutLog(nil)
        #expect(coordinator.modal?.id == "coconut-log-all")
    }

    @Test func settingsFallsBackToLocalModalWithoutAppSheetSink() {
        let coordinator = HomeRouteCoordinator()

        coordinator.openSettings()

        guard case .settings = coordinator.modal else {
            Issue.record("Expected settings to remain local without app sheet sink")
            return
        }
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

        guard case let .calendar(entityID, humanID, plantID) = coordinator.modal else {
            Issue.record("Expected calendar modal route")
            return
        }
        #expect(entityID == pet.id.uuidString)
        #expect(humanID == nil)
        #expect(plantID == nil)

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

        coordinator.openPetWeightQuick(pet.id)

        guard case let .petWeightQuick(_, weightPetID) = coordinator.overlay else {
            Issue.record("Expected pet weight quick overlay route")
            return
        }
        #expect(weightPetID == pet.id)
    }

    @Test func antiRepeatAlertOwnsPendingActionUntilConfirmedOrDismissed() async {
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

        #expect(!didRun)
        #expect(coordinator.alert == nil)
        #expect(coordinator.pendingRepeatAction == nil)

        for _ in 0 ..< 8 where !didRun {
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 30)
        }
        #expect(didRun)
    }
}
