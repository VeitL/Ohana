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
    case humanMedication(UUID)
    case humanWeight(UUID)
    case humanWorkout(UUID)
    case humanExpense(UUID)
    case humanNote(UUID)

    var id: String {
        switch self {
        case let .petAllFeatures(id): return "pet-all-\(id.uuidString)"
        case let .humanAllFeatures(id): return "human-all-\(id.uuidString)"
        case let .petBasicInfo(id): return "pet-basic-\(id.uuidString)"
        case let .humanBasicInfo(id): return "human-basic-\(id.uuidString)"
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
        case let .humanMedication(id): return "human-medication-\(id.uuidString)"
        case let .humanWeight(id): return "human-weight-\(id.uuidString)"
        case let .humanWorkout(id): return "human-workout-\(id.uuidString)"
        case let .humanExpense(id): return "human-expense-\(id.uuidString)"
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
    case crewRoster(CrewRosterMode)
    case accountSwitcher
    case calendar(entityID: String?, humanID: String?)

    var id: String {
        switch self {
        case let .functionMenu(destination):
            return "function-menu-\(String(describing: destination))"
        case .streakDetail:
            return "streak-detail"
        case let .addEntity(type):
            return "add-entity-\(type.id)"
        case let .crewRoster(mode):
            return "crew-roster-\(mode.rawValue)"
        case .accountSwitcher:
            return "account-switcher"
        case let .calendar(entityID, humanID):
            return "calendar-\(entityID ?? "all")-\(humanID ?? "all")"
        }
    }
}

enum HomeFullScreenRoute: Identifiable {
    case settings
    case walk(UUID)
    case oasisReward
    case coconutLog(CoconutLogSubject)

    var id: String {
        switch self {
        case .settings:
            return "settings"
        case let .walk(id):
            return "walk-\(id.uuidString)"
        case .oasisReward:
            return "oasis-reward"
        case let .coconutLog(subject):
            return "coconut-log-\(subject.id)"
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

@MainActor
final class HomeRouteCoordinator: ObservableObject {
    @Published var modal: HomeModalRoute?
    @Published var fullScreen: HomeFullScreenRoute?
    @Published var overlay: HomeOverlayRoute?
    @Published var alert: HomeAlertRoute?
    @Published var sheet: HomeSheetRoute?
    @Published var settingsPresented = false

    var pendingRepeatAction: (() -> Void)?

    func openModal(_ route: HomeModalRoute) {
        modal = route
    }

    func dismissModal() {
        modal = nil
    }

    func openFunctionMenu(destination: FMDest?) {
        modal = .functionMenu(destination: destination)
    }

    func openStreakDetail() {
        modal = .streakDetail
    }

    func openAddEntity(_ type: EntityType) {
        modal = .addEntity(type)
    }

    func openCrewRoster(mode: CrewRosterMode = .members) {
        modal = .crewRoster(mode)
    }

    func openAccountSwitcher() {
        modal = .accountSwitcher
    }

    func openCalendar(entityID: String? = nil, humanID: String? = nil) {
        modal = .calendar(entityID: entityID, humanID: humanID)
    }

    func openFullScreen(_ route: HomeFullScreenRoute) {
        fullScreen = route
    }

    func dismissFullScreen() {
        fullScreen = nil
    }

    func openSettings() {
        settingsPresented = true
    }

    func dismissSettings() {
        settingsPresented = false
    }

    func openWalk(_ pet: Pet) {
        fullScreen = .walk(pet.id)
    }

    func openOasisReward() {
        fullScreen = .oasisReward
    }

    func openCoconutLog(_ subject: CoconutLogSubject) {
        fullScreen = .coconutLog(subject)
    }

    func openQuickMoment(_ pet: Pet) {
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
    var isHumanRoute: Bool {
        switch self {
        case .humanAllFeatures,
             .humanBasicInfo,
             .humanMedication,
             .humanWeight,
             .humanWorkout,
             .humanExpense,
             .humanNote:
            return true
        case .petAllFeatures,
             .petBasicInfo,
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
             .petMomentHistory:
            return false
        }
    }
}
