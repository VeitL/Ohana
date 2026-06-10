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
    case petWeight(UUID)
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
    case humanWeight(UUID)
    case humanWorkout(UUID)
    case humanWorkoutDashboard(UUID)
    case humanMetrics(UUID)
    case humanReport(UUID)
    case humanExpense(UUID)
    case humanWishlist(UUID)
    case humanNote(UUID)

    var id: String {
        switch self {
        case let .petAllFeatures(id): return "pet-all-\(id.uuidString)"
        case let .humanAllFeatures(id): return "human-all-\(id.uuidString)"
        case let .petBasicInfo(id): return "pet-basic-\(id.uuidString)"
        case let .humanBasicInfo(id): return "human-basic-\(id.uuidString)"
        case let .petFood(id): return "pet-food-\(id.uuidString)"
        case let .petWeight(id): return "pet-weight-\(id.uuidString)"
        case let .petExpense(id): return "pet-expense-\(id.uuidString)"
        case let .petFeed(id, opensManualSheet): return "pet-feed-\(id.uuidString)-manual-\(opensManualSheet)"
        case let .petWater(id): return "pet-water-\(id.uuidString)"
        case let .petPotty(id): return "pet-potty-\(id.uuidString)"
        case let .petLitter(id): return "pet-litter-\(id.uuidString)"
        case let .petPlay(id): return "pet-play-\(id.uuidString)"
        case let .petHygiene(id): return "pet-hygiene-\(id.uuidString)"
        case let .petWalkSummary(id): return "pet-walk-\(id.uuidString)"
        case let .petHealth(id, section): return "pet-health-\(id.uuidString)-\(section?.idValue ?? "default")"
        case let .petMedication(id): return "pet-medication-\(id.uuidString)"
        case let .petMomentHistory(id): return "pet-moment-history-\(id.uuidString)"
        case let .petDocuments(id): return "pet-documents-\(id.uuidString)"
        case let .petAchievements(id): return "pet-achievements-\(id.uuidString)"
        case let .petRetention(id): return "pet-retention-\(id.uuidString)"
        case let .petBondVault(id): return "pet-bond-vault-\(id.uuidString)"
        case let .humanMedication(id): return "human-medication-\(id.uuidString)"
        case let .humanWeight(id): return "human-weight-\(id.uuidString)"
        case let .humanWorkout(id): return "human-workout-\(id.uuidString)"
        case let .humanWorkoutDashboard(id): return "human-workout-dashboard-\(id.uuidString)"
        case let .humanMetrics(id): return "human-metrics-\(id.uuidString)"
        case let .humanReport(id): return "human-report-\(id.uuidString)"
        case let .humanExpense(id): return "human-expense-\(id.uuidString)"
        case let .humanWishlist(id): return "human-wishlist-\(id.uuidString)"
        case let .humanNote(id): return "human-note-\(id.uuidString)"
        }
    }
}

private extension PetHealthInitialSection {
    var idValue: String {
        switch self {
        case .preventive: return "preventive"
        case .medication: return "medication"
        case .symptomVisit: return "symptomVisit"
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
    case calendar(entityID: String?, humanID: String?)
    case settings

    var id: String {
        switch self {
        case let .functionMenu(destination):
            return "function-menu-\(String(describing: destination))"
        case .streakDetail:
            return "streak-detail"
        case let .addEntity(type):
            return "add-entity-\(type.id)"
        case let .coconutLog(subject):
            return "coconut-log-\(subject?.id ?? "all")"
        case let .crewRoster(mode):
            return "crew-roster-\(mode.rawValue)"
        case .accountSwitcher:
            return "account-switcher"
        case let .calendar(entityID, humanID):
            return "calendar-\(entityID ?? "all")-\(humanID ?? "all")"
        case .settings:
            return "settings"
        }
    }
}

enum HomeFullScreenRoute: Identifiable {
    case walk(UUID)
    case oasisReward

    var id: String {
        switch self {
        case let .walk(id):
            return "walk-\(id.uuidString)"
        case .oasisReward:
            return "oasis-reward"
        }
    }
}

enum HomeOverlayRoute: Identifiable {
    case quickMoment(routeID: UUID = UUID(), petID: UUID)

    var id: UUID {
        switch self {
        case let .quickMoment(routeID, _):
            return routeID
        }
    }

    var petID: UUID? {
        switch self {
        case let .quickMoment(_, petID):
            return petID
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
            return routeID
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

    func openAddEntity(_ type: EntityType) {
        guard AppFeatureRouteGuard.allowsAddEntity(type) else {
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
        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(.crewRoster(mode)))
            modal = nil
            fullScreen = nil
            return
        }
        modal = .crewRoster(mode)
    }

    func openAccountSwitcher() {
        if let appSheetRouteSink {
            appSheetRouteSink(.accountSwitcher)
            modal = nil
            return
        }
        modal = .accountSwitcher
    }

    func openCalendar(entityID: String? = nil, humanID: String? = nil) {
        if let appSheetRouteSink {
            appSheetRouteSink(.appSheet(.calendar(entityID: entityID, humanID: humanID)))
            modal = nil
            return
        }
        modal = .calendar(entityID: entityID, humanID: humanID)
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

    func openQuickMoment(_ pet: Pet) {
        if let appOverlayRouteSink {
            appOverlayRouteSink(.quickMoment(petID: pet.id))
            overlay = nil
            return
        }
        overlay = .quickMoment(petID: pet.id)
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
        action?()
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
    var appRoute: HomeAppRoute? {
        switch self {
        case let .petBasicInfo(id):
            return .petProfile(id: id, initialTab: .overview)
        case let .humanBasicInfo(id):
            return .humanProfile(id: id)
        case .petAllFeatures,
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
             .humanMedication,
             .humanWeight,
             .humanWorkout,
             .humanWorkoutDashboard,
             .humanMetrics,
             .humanReport,
             .humanExpense,
             .humanWishlist,
             .humanNote:
            return nil
        }
    }

    var isHumanRoute: Bool {
        switch self {
        case .humanAllFeatures,
             .humanBasicInfo,
             .humanMedication,
             .humanWeight,
             .humanWorkout,
             .humanWorkoutDashboard,
             .humanMetrics,
             .humanReport,
             .humanExpense,
             .humanWishlist,
             .humanNote:
            return true
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
             .petBondVault:
            return false
        }
    }

    var appSheetRoute: AppSheetRoute? {
        switch self {
        case let .petAllFeatures(id):
            return .petAllFeatures(id)
        case let .petFood(id):
            return .petFood(id)
        case let .petWeight(id):
            return .petWeight(id)
        case let .petExpense(id):
            return .petExpense(id)
        case let .petFeed(id, opensManualSheet):
            return .petFeed(id, opensManualSheet: opensManualSheet)
        case let .petWater(id):
            return .petWater(id)
        case let .petPotty(id):
            return .petPotty(id)
        case let .petLitter(id):
            return .petLitter(id)
        case let .petPlay(id):
            return .petPlay(id)
        case let .petHygiene(id):
            return .petHygiene(id)
        case let .petWalkSummary(id):
            return .petWalkSummary(id)
        case let .petHealth(id, initialSection):
            return .petHealth(id, initialSection: initialSection)
        case let .petMedication(id):
            return .petMedication(id)
        case let .petMomentHistory(id):
            return .petMomentHistory(id)
        case let .petDocuments(id):
            return .petDocuments(id)
        case let .petAchievements(id):
            return .petAchievements(id)
        case let .petRetention(id):
            return .petRetention(id)
        case let .petBondVault(id):
            return .petBondVault(id)
        case let .humanAllFeatures(id):
            return .humanAllFeatures(id)
        case let .humanMedication(id):
            return .humanMedication(id)
        case let .humanWeight(id):
            return .humanWeight(id)
        case let .humanWorkout(id):
            return .humanWorkout(id)
        case let .humanWorkoutDashboard(id):
            return .humanWorkoutDashboard(id)
        case let .humanMetrics(id):
            return .humanMetrics(id)
        case let .humanReport(id):
            return .humanReport(id)
        case let .humanExpense(id):
            return .humanExpense(id)
        case let .humanWishlist(id):
            return .humanWishlist(id)
        case let .humanNote(id):
            return .humanNote(id)
        case .petBasicInfo,
             .humanBasicInfo:
            return nil
        }
    }
}

private extension HomeFullScreenRoute {
    var appFullScreenRoute: HomeAppFullScreenRoute? {
        switch self {
        case let .walk(id):
            return .walk(petID: id)
        case .oasisReward:
            return .oasisReward
        }
    }
}
