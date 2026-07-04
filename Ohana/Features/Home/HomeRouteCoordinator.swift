//
//  HomeRouteCoordinator.swift
//  Ohana
//
//  Route state for home sheets and inline popups.
//

import Combine
import Foundation

enum HomeSheetRoute: Identifiable {
    case petAllFeatures(UUID)
    case humanAllFeatures(UUID)
    case petBasicInfo(UUID)
    case humanBasicInfo(UUID)
    case petFood(UUID)
    case petWeightQuick(UUID)
    case petWeight(UUID)
    case petExpenseQuick(UUID)
    case petExpense(UUID)
    case petFeed(UUID, opensManualSheet: Bool)
    case petWater(UUID)
    case petPotty(UUID)
    case petLitter(UUID)
    case petPlay(UUID)
    case petHygiene(UUID)
    case petWalkSummary(UUID)
    case petHealth(UUID, initialSection: PetHealthInitialSection?)
    case petMedication(UUID)
    case petMomentHistory(UUID)
    case petDocuments(UUID)
    case petAchievements(UUID)
    case petRetention(UUID)
    case petBondVault(UUID)
    case humanMedication(UUID)
    case humanMedicationQuick(UUID)
    case humanWeightQuick(UUID)
    case humanWeight(UUID)
    case humanWorkoutQuick(UUID)
    case humanWorkout(UUID)
    case humanWorkoutDashboard(UUID)
    case humanMetrics(UUID)
    case humanReport(UUID)
    case humanExpenseQuick(UUID)
    case humanExpense(UUID)
    case humanWishlist(UUID)
    case humanNoteQuick(UUID)
    case humanNote(UUID)
    case plantCareLog(UUID, initialCareType: PlantCareType)

    var id: String {
        switch self {
        case let .petAllFeatures(id): "pet-all-\(id.uuidString)"
        case let .humanAllFeatures(id): "human-all-\(id.uuidString)"
        case let .petBasicInfo(id): "pet-basic-\(id.uuidString)"
        case let .humanBasicInfo(id): "human-basic-\(id.uuidString)"
        case let .petFood(id): "pet-food-\(id.uuidString)"
        case let .petWeightQuick(id): "pet-weight-quick-\(id.uuidString)"
        case let .petWeight(id): "pet-weight-\(id.uuidString)"
        case let .petExpenseQuick(id): "pet-expense-quick-\(id.uuidString)"
        case let .petExpense(id): "pet-expense-\(id.uuidString)"
        case let .petFeed(id, opensManualSheet): "pet-feed-\(id.uuidString)-manual-\(opensManualSheet)"
        case let .petWater(id): "pet-water-\(id.uuidString)"
        case let .petPotty(id): "pet-potty-\(id.uuidString)"
        case let .petLitter(id): "pet-litter-\(id.uuidString)"
        case let .petPlay(id): "pet-play-\(id.uuidString)"
        case let .petHygiene(id): "pet-hygiene-\(id.uuidString)"
        case let .petWalkSummary(id): "pet-walk-\(id.uuidString)"
        case let .petHealth(id, section): "pet-health-\(id.uuidString)-\(section?.idValue ?? "default")"
        case let .petMedication(id): "pet-medication-\(id.uuidString)"
        case let .petMomentHistory(id): "pet-moment-history-\(id.uuidString)"
        case let .petDocuments(id): "pet-documents-\(id.uuidString)"
        case let .petAchievements(id): "pet-achievements-\(id.uuidString)"
        case let .petRetention(id): "pet-retention-\(id.uuidString)"
        case let .petBondVault(id): "pet-bond-vault-\(id.uuidString)"
        case let .humanMedication(id): "human-medication-\(id.uuidString)"
        case let .humanMedicationQuick(id): "human-medication-quick-\(id.uuidString)"
        case let .humanWeightQuick(id): "human-weight-quick-\(id.uuidString)"
        case let .humanWeight(id): "human-weight-\(id.uuidString)"
        case let .humanWorkoutQuick(id): "human-workout-quick-\(id.uuidString)"
        case let .humanWorkout(id): "human-workout-\(id.uuidString)"
        case let .humanWorkoutDashboard(id): "human-workout-dashboard-\(id.uuidString)"
        case let .humanMetrics(id): "human-metrics-\(id.uuidString)"
        case let .humanReport(id): "human-report-\(id.uuidString)"
        case let .humanExpenseQuick(id): "human-expense-quick-\(id.uuidString)"
        case let .humanExpense(id): "human-expense-\(id.uuidString)"
        case let .humanWishlist(id): "human-wishlist-\(id.uuidString)"
        case let .humanNoteQuick(id): "human-note-quick-\(id.uuidString)"
        case let .humanNote(id): "human-note-\(id.uuidString)"
        case let .plantCareLog(id, type): "plant-care-log-\(id.uuidString)-\(type.rawValue)"
        }
    }
}

private extension PetHealthInitialSection {
    var idValue: String {
        switch self {
        case .preventive: "preventive"
        case .medication: "medication"
        case .symptomVisit: "symptomVisit"
        }
    }
}

enum HomeModalRoute: Identifiable {
    case functionMenu(destination: FMDest?)
    case streakDetail
    case addEntity(EntityType)
    case coconutLog(CoconutLogSubject?)
    case crewRoster(CrewRosterMode)
    case accountSwitcher
    case calendar(entityID: String?, humanID: String?, plantID: String?)
    case settings

    var id: String {
        switch self {
        case let .functionMenu(destination):
            "function-menu-\(String(describing: destination))"
        case .streakDetail:
            "streak-detail"
        case let .addEntity(type):
            "add-entity-\(type.id)"
        case let .coconutLog(subject):
            "coconut-log-\(subject?.id ?? "all")"
        case let .crewRoster(mode):
            "crew-roster-\(mode.rawValue)"
        case .accountSwitcher:
            "account-switcher"
        case let .calendar(entityID, humanID, plantID):
            "calendar-\(entityID ?? "all")-\(humanID ?? "all")-\(plantID ?? "all")"
        case .settings:
            "settings"
        }
    }
}

enum HomeFullScreenRoute: Identifiable {
    case walk(UUID)
    case oasisReward

    var id: String {
        switch self {
        case let .walk(id):
            "walk-\(id.uuidString)"
        case .oasisReward:
            "oasis-reward"
        }
    }
}

enum HomeOverlayRoute: Identifiable {
    case quickMoment(routeID: UUID = UUID(), petID: UUID)
    case petWeightQuick(routeID: UUID = UUID(), petID: UUID)
    case petExpenseQuick(routeID: UUID = UUID(), petID: UUID)
    case humanMedicationQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanWeightQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanWorkoutQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanExpenseQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanNoteQuick(routeID: UUID = UUID(), humanID: UUID)

    var id: UUID {
        switch self {
        case let .quickMoment(routeID, _):
            routeID
        case let .petWeightQuick(routeID, _):
            routeID
        case let .petExpenseQuick(routeID, _):
            routeID
        case let .humanMedicationQuick(routeID, _):
            routeID
        case let .humanWeightQuick(routeID, _):
            routeID
        case let .humanWorkoutQuick(routeID, _):
            routeID
        case let .humanExpenseQuick(routeID, _):
            routeID
        case let .humanNoteQuick(routeID, _):
            routeID
        }
    }

    var petID: UUID? {
        switch self {
        case let .quickMoment(_, petID),
             let .petWeightQuick(_, petID),
             let .petExpenseQuick(_, petID):
            petID
        case .humanMedicationQuick,
             .humanWeightQuick,
             .humanWorkoutQuick,
             .humanExpenseQuick,
             .humanNoteQuick:
            nil
        }
    }
}

enum HomeAlertRoute: Identifiable {
    case antiRepeat(routeID: UUID = UUID(), title: String, message: String)
    case singleUseNotice(routeID: UUID = UUID(), title: String, message: String)
    case quickActionLimit(routeID: UUID = UUID())
    case humanPrivacy(routeID: UUID = UUID())

    var id: UUID {
        switch self {
        case let .antiRepeat(routeID, _, _),
             let .singleUseNotice(routeID, _, _),
             let .quickActionLimit(routeID),
             let .humanPrivacy(routeID):
            routeID
        }
    }
}

enum HomeAppRoute: Equatable {
    case petProfile(id: UUID, initialTab: PetDetailTab)
    case humanProfile(id: UUID)
}

enum HomeAppSheetRoute: Equatable {
    case accountSwitcher
    case addEntity(EntityType)
    case appSheet(AppSheetRoute)
    case functionMenu(destination: FMDest?)
    case streakDetail
}

enum HomeAppFullScreenRoute: Equatable {
    case oasisReward
    case walk(petID: UUID)
}

enum HomeAppOverlayRoute: Equatable {
    case quickMoment(petID: UUID)
    case petWeightQuick(petID: UUID)
    case petExpenseQuick(petID: UUID)
    case humanMedicationQuick(humanID: UUID)
    case humanWeightQuick(humanID: UUID)
    case humanWorkoutQuick(humanID: UUID)
    case humanExpenseQuick(humanID: UUID)
    case humanNoteQuick(humanID: UUID)
}

@MainActor
final class HomeRouteCoordinator: ObservableObject {
    @Published var modal: HomeModalRoute?
    @Published var fullScreen: HomeFullScreenRoute?
    @Published var overlay: HomeOverlayRoute?
    @Published var alert: HomeAlertRoute?
    @Published var sheet: HomeSheetRoute?
    @Published var settingsPresented = false

    var pendingRepeatAction: (() -> Void)?
    private var appRouteSink: ((HomeAppRoute) -> Void)?
    private var appSheetRouteSink: ((HomeAppSheetRoute) -> Void)?
    private var appFullScreenRouteSink: ((HomeAppFullScreenRoute) -> Void)?
    private var appOverlayRouteSink: ((HomeAppOverlayRoute) -> Void)?

    func bindAppRouteSink(_ sink: @escaping (HomeAppRoute) -> Void) {
        appRouteSink = sink
    }

    func bindAppSheetRouteSink(_ sink: @escaping (HomeAppSheetRoute) -> Void) {
        appSheetRouteSink = sink
    }

    func bindAppFullScreenRouteSink(_ sink: @escaping (HomeAppFullScreenRoute) -> Void) {
        appFullScreenRouteSink = sink
    }

    func bindAppOverlayRouteSink(_ sink: @escaping (HomeAppOverlayRoute) -> Void) {
        appOverlayRouteSink = sink
    }

    func openModal(_ route: HomeModalRoute) {
        modal = route
    }

    func dismissModal() {
        modal = nil
    }

    func openFunctionMenu(destination: FMDest?, currentLevel: Int) {
        let routedDestination: FMDest?
        switch AppFeatureRouteGuard.functionDestinationDecision(
            destination,
            currentLevel: currentLevel
        ) {
        case .rootMenu:
            routedDestination = nil
        case let .allow(destination):
            routedDestination = destination
        case let .redirectToRoadmap(note):
            AppFeatureRouteGuard.recordIntercept(note)
            routedDestination = .growthRoadmap
        case let .suppress(note):
            AppFeatureRouteGuard.recordIntercept(note)
            routedDestination = nil
        }
        if let appSheetRouteSink {
            appSheetRouteSink(.functionMenu(destination: routedDestination))
            modal = nil
            return
        }
        modal = .functionMenu(destination: routedDestination)
    }

    func openStreakDetail() {
        if let appSheetRouteSink {
            appSheetRouteSink(.streakDetail)
            modal = nil
            return
        }
        modal = .streakDetail
    }

    func openAddEntity(_ type: EntityType, currentLevel: Int = AppFeatureRouteGuard.currentFeatureLevel) {
        guard AppFeatureRouteGuard.allowsAddEntity(type, currentLevel: currentLevel) else {
            AppFeatureRouteGuard.recordIntercept("homeAddEntity:\(type.rawValue)")
            if let appSheetRouteSink {
                appSheetRouteSink(.functionMenu(destination: .growthRoadmap))
            } else {
                modal = .functionMenu(destination: .growthRoadmap)
            }
            return
        }
        if let appSheetRouteSink {
            appSheetRouteSink(.addEntity(type))
            modal = nil
            return
        }
        modal = .addEntity(type)
    }

    func openCrewRoster(mode: CrewRosterMode = .members) {
        let resolvedMode: CrewRosterMode
        if mode == .collaboration, !OnlineFeatureGate.allows(.onlineCollaboration) {
            AppFeatureRouteGuard.recordIntercept("homeCrewRoster:onlineGate")
            resolvedMode = .members
        } else {
            resolvedMode = mode
        }
        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(.crewRoster(resolvedMode)))
            modal = nil
            fullScreen = nil
            return
        }
        modal = .crewRoster(resolvedMode)
    }

    func openAccountSwitcher() {
        if let appSheetRouteSink {
            appSheetRouteSink(.accountSwitcher)
            modal = nil
            return
        }
        modal = .accountSwitcher
    }

    func openCalendar(entityID: String? = nil, humanID: String? = nil, plantID _: String? = nil) {
        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(.calendar(entityID: entityID, humanID: humanID, plantID: nil)))
            modal = nil
            return
        }
        modal = .calendar(entityID: entityID, humanID: humanID, plantID: nil)
    }

    func openFullScreen(_ route: HomeFullScreenRoute) {
        if let appFullScreenRoute = route.appFullScreenRoute,
           let appFullScreenRouteSink {
            appFullScreenRouteSink(appFullScreenRoute)
            fullScreen = nil
            return
        }
        fullScreen = route
    }

    func dismissFullScreen() {
        fullScreen = nil
    }

    func openSettings() {
        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(.settings))
            modal = nil
            settingsPresented = false
            return
        }
        modal = .settings
    }

    func dismissSettings() {
        settingsPresented = false
    }

    func openWalk(_ pet: Pet) {
        openFullScreen(.walk(pet.id))
    }

    func openWalk(_ petID: UUID) {
        openFullScreen(.walk(petID))
    }

    func openOasisReward() {
        openFullScreen(.oasisReward)
    }

    func openCoconutLog(_ subject: CoconutLogSubject?) {
        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(.coconutLog(subject)))
            fullScreen = nil
            modal = nil
            return
        }
        fullScreen = nil
        modal = .coconutLog(subject)
    }

    func openCoconutShop(_ category: ShopItem.ShopCategory, currentLevel: Int) {
        let route = AppSheetRoute.coconutShop(category)
        guard AppFeatureRouteGuard.allowsSheetRoute(route, currentLevel: currentLevel) else {
            AppFeatureRouteGuard.recordIntercept(
                AppFeatureRouteGuard.lockedRouteNote(for: route, currentLevel: currentLevel)
            )
            if let appSheetRouteSink {
                appSheetRouteSink(.functionMenu(destination: .growthRoadmap))
                fullScreen = nil
                modal = nil
                return
            }
            fullScreen = nil
            modal = .functionMenu(destination: .growthRoadmap)
            return
        }

        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(route))
            fullScreen = nil
            modal = nil
            return
        }
        fullScreen = nil
        modal = .functionMenu(destination: .coconutShop)
    }

    func openQuickMoment(_ petID: UUID) {
        if let appOverlayRouteSink {
            appOverlayRouteSink(.quickMoment(petID: petID))
            overlay = nil
            return
        }
        overlay = .quickMoment(petID: petID)
    }

    func openQuickMoment(_ pet: Pet) {
        openQuickMoment(pet.id)
    }

    func openPetWeightQuick(_ petID: UUID) {
        if let appOverlayRouteSink {
            appOverlayRouteSink(.petWeightQuick(petID: petID))
            overlay = nil
            return
        }
        overlay = .petWeightQuick(petID: petID)
    }

    func openHumanWeightQuick(_ humanID: UUID) {
        if let appOverlayRouteSink {
            appOverlayRouteSink(.humanWeightQuick(humanID: humanID))
            overlay = nil
            return
        }
        overlay = .humanWeightQuick(humanID: humanID)
    }

    func dismissOverlay(routeID: UUID) {
        guard overlay?.id == routeID else { return }
        overlay = nil
    }

    func showAntiRepeat(title: String, message: String, pendingAction: @escaping () -> Void) {
        pendingRepeatAction = pendingAction
        alert = .antiRepeat(title: title, message: message)
    }

    func confirmAntiRepeatAction() {
        let action = pendingRepeatAction
        pendingRepeatAction = nil
        alert = nil
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 35) {
            action?()
        }
    }

    func showSingleUseNotice(title: String, message: String) {
        alert = .singleUseNotice(title: title, message: message)
    }

    func showQuickActionLimit() {
        alert = .quickActionLimit()
    }

    func showHumanPrivacy() {
        alert = .humanPrivacy()
    }

    func dismissAlert() {
        pendingRepeatAction = nil
        alert = nil
    }

    func openSheet(_ route: HomeSheetRoute) {
        if let appRoute = route.appRoute {
            appRouteSink?(appRoute)
            if appRouteSink != nil {
                sheet = nil
                return
            }
        }
        if let appOverlayRoute = route.appOverlayRoute,
           let homeOverlayRoute = route.homeOverlayRoute {
            if let appOverlayRouteSink {
                appOverlayRouteSink(appOverlayRoute)
                overlay = nil
                sheet = nil
                return
            }
            overlay = homeOverlayRoute
            sheet = nil
            return
        }
        if let appSheetRoute = route.appSheetRoute,
           let appSheetRouteSink {
            appSheetRouteSink(.appSheet(appSheetRoute))
            sheet = nil
            return
        }
        sheet = route
    }

    func dismissSheet() {
        sheet = nil
    }

    func resetAllRoutes() {
        modal = nil
        fullScreen = nil
        overlay = nil
        alert = nil
        pendingRepeatAction = nil
        sheet = nil
        settingsPresented = false
    }

    func resetHumanRoutes() {
        if let sheet, sheet.isHumanRoute {
            self.sheet = nil
        }
    }
}

private extension HomeSheetRoute {
    var appOverlayRoute: HomeAppOverlayRoute? {
        switch self {
        case let .petWeightQuick(id):
            .petWeightQuick(petID: id)
        case let .petExpenseQuick(id):
            .petExpenseQuick(petID: id)
        case let .humanMedicationQuick(id):
            .humanMedicationQuick(humanID: id)
        case let .humanWeightQuick(id):
            .humanWeightQuick(humanID: id)
        case let .humanWorkoutQuick(id):
            .humanWorkoutQuick(humanID: id)
        case let .humanExpenseQuick(id):
            .humanExpenseQuick(humanID: id)
        case let .humanNoteQuick(id):
            .humanNoteQuick(humanID: id)
        case .petAllFeatures,
             .petBasicInfo,
             .petFood,
             .petWeight,
             .petExpense,
             .petFeed,
             .petWater,
             .petPotty,
             .petLitter,
             .petPlay,
             .petHygiene,
             .petWalkSummary,
             .petHealth,
             .petMedication,
             .petMomentHistory,
             .petDocuments,
             .petAchievements,
             .petRetention,
             .petBondVault,
             .humanAllFeatures,
             .humanBasicInfo,
             .humanMedication,
             .humanWeight,
             .humanWorkout,
             .humanWorkoutDashboard,
             .humanMetrics,
             .humanReport,
             .humanExpense,
             .humanWishlist,
             .humanNote,
             .plantCareLog:
            nil
        }
    }

    var homeOverlayRoute: HomeOverlayRoute? {
        switch self {
        case let .petWeightQuick(id):
            .petWeightQuick(petID: id)
        case let .petExpenseQuick(id):
            .petExpenseQuick(petID: id)
        case let .humanMedicationQuick(id):
            .humanMedicationQuick(humanID: id)
        case let .humanWeightQuick(id):
            .humanWeightQuick(humanID: id)
        case let .humanWorkoutQuick(id):
            .humanWorkoutQuick(humanID: id)
        case let .humanExpenseQuick(id):
            .humanExpenseQuick(humanID: id)
        case let .humanNoteQuick(id):
            .humanNoteQuick(humanID: id)
        case .petAllFeatures,
             .petBasicInfo,
             .petFood,
             .petWeight,
             .petExpense,
             .petFeed,
             .petWater,
             .petPotty,
             .petLitter,
             .petPlay,
             .petHygiene,
             .petWalkSummary,
             .petHealth,
             .petMedication,
             .petMomentHistory,
             .petDocuments,
             .petAchievements,
             .petRetention,
             .petBondVault,
             .humanAllFeatures,
             .humanBasicInfo,
             .humanMedication,
             .humanWeight,
             .humanWorkout,
             .humanWorkoutDashboard,
             .humanMetrics,
             .humanReport,
             .humanExpense,
             .humanWishlist,
             .humanNote,
             .plantCareLog:
            nil
        }
    }

    var appRoute: HomeAppRoute? {
        switch self {
        case let .petBasicInfo(id):
            .petProfile(id: id, initialTab: .overview)
        case let .humanBasicInfo(id):
            .humanProfile(id: id)
        case .petAllFeatures,
             .petFood,
             .petWeightQuick,
             .petWeight,
             .petExpenseQuick,
             .petExpense,
             .petFeed,
             .petWater,
             .petPotty,
             .petLitter,
             .petPlay,
             .petHygiene,
             .petWalkSummary,
             .petHealth,
             .petMedication,
             .petMomentHistory,
             .petDocuments,
             .petAchievements,
             .petRetention,
             .petBondVault,
             .humanAllFeatures,
             .humanMedicationQuick,
             .humanMedication,
             .humanWeightQuick,
             .humanWeight,
             .humanWorkoutQuick,
             .humanWorkout,
             .humanWorkoutDashboard,
             .humanMetrics,
             .humanReport,
             .humanExpenseQuick,
             .humanExpense,
             .humanWishlist,
             .humanNoteQuick,
             .humanNote,
             .plantCareLog:
            nil
        }
    }

    var isHumanRoute: Bool {
        switch self {
        case .humanAllFeatures,
             .humanBasicInfo,
             .humanMedicationQuick,
             .humanMedication,
             .humanWeightQuick,
             .humanWeight,
             .humanWorkoutQuick,
             .humanWorkout,
             .humanWorkoutDashboard,
             .humanMetrics,
             .humanReport,
             .humanExpenseQuick,
             .humanExpense,
             .humanWishlist,
             .humanNoteQuick,
             .humanNote:
            true
        case .petAllFeatures,
             .petBasicInfo,
             .petFood,
             .petWeightQuick,
             .petWeight,
             .petExpenseQuick,
             .petExpense,
             .petFeed,
             .petWater,
             .petPotty,
             .petLitter,
             .petPlay,
             .petHygiene,
             .petWalkSummary,
             .petHealth,
             .petMedication,
             .petMomentHistory,
             .petDocuments,
             .petAchievements,
             .petRetention,
             .petBondVault,
             .plantCareLog:
            false
        }
    }

    var appSheetRoute: AppSheetRoute? {
        switch self {
        case let .petAllFeatures(id):
            .petAllFeatures(id)
        case let .petFood(id):
            .petFood(id)
        case .petWeightQuick:
            nil
        case let .petWeight(id):
            .petWeight(id)
        case .petExpenseQuick:
            nil
        case let .petExpense(id):
            .petExpense(id)
        case let .petFeed(id, opensManualSheet):
            .petFeed(id, opensManualSheet: opensManualSheet)
        case let .petWater(id):
            .petWater(id)
        case let .petPotty(id):
            .petPotty(id)
        case let .petLitter(id):
            .petLitter(id)
        case let .petPlay(id):
            .petPlay(id)
        case let .petHygiene(id):
            .petHygiene(id)
        case let .petWalkSummary(id):
            .petWalkSummary(id)
        case let .petHealth(id, initialSection):
            .petHealth(id, initialSection: initialSection)
        case let .petMedication(id):
            .petMedication(id)
        case let .petMomentHistory(id):
            .petMomentHistory(id)
        case let .petDocuments(id):
            .petDocuments(id)
        case let .petAchievements(id):
            .petAchievements(id)
        case let .petRetention(id):
            .petRetention(id)
        case let .petBondVault(id):
            .petBondVault(id)
        case let .humanAllFeatures(id):
            .humanAllFeatures(id)
        case let .humanMedicationQuick(id):
            .humanMedicationQuick(id)
        case let .humanMedication(id):
            .humanMedication(id)
        case .humanWeightQuick:
            nil
        case let .humanWeight(id):
            .humanWeight(id)
        case let .humanWorkoutQuick(id):
            .humanWorkoutQuick(id)
        case let .humanWorkout(id):
            .humanWorkout(id)
        case let .humanWorkoutDashboard(id):
            .humanWorkoutDashboard(id)
        case let .humanMetrics(id):
            .humanMetrics(id)
        case let .humanReport(id):
            .humanReport(id)
        case .humanExpenseQuick:
            nil
        case let .humanExpense(id):
            .humanExpense(id)
        case let .humanWishlist(id):
            .humanWishlist(id)
        case let .humanNoteQuick(id):
            .humanNoteQuick(id)
        case let .humanNote(id):
            .humanNote(id)
        case .petBasicInfo,
             .humanBasicInfo,
             .plantCareLog:
            nil
        }
    }
}

private extension HomeFullScreenRoute {
    var appFullScreenRoute: HomeAppFullScreenRoute? {
        switch self {
        case let .walk(id):
            .walk(petID: id)
        case .oasisReward:
            .oasisReward
        }
    }
}
