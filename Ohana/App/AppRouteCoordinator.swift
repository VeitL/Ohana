//
//  AppRouteCoordinator.swift
//  Ohana
//
//  Global typed route source of truth. Routes carry stable identifiers and
//  lightweight parameters; destination containers perform their own fetches.
//

import Combine
import Foundation
import SwiftUI

enum AppRoute: Hashable, Identifiable {
    case petProfile(id: UUID, initialTab: PetDetailTab)
    case humanProfile(id: UUID)
    case plantProfile(id: UUID)

    var id: String {
        switch self {
        case let .petProfile(id, tab):
            "pet-profile-\(id.uuidString)-\(tab.rawValue)"
        case let .humanProfile(id):
            "human-profile-\(id.uuidString)"
        case let .plantProfile(id):
            "plant-profile-\(id.uuidString)"
        }
    }

    var sourceID: UUID {
        switch self {
        case let .petProfile(id, _),
             let .humanProfile(id),
             let .plantProfile(id):
            id
        }
    }
}

enum AppSheetRoute: Hashable, Identifiable {
    case accountSwitcher
    case addEntity(EntityType)
    case calendar(entityID: String?, humanID: String?)
    case coconutLog(CoconutLogSubject?)
    case coconutShop(ShopItem.ShopCategory)
    case crewRoster(CrewRosterMode)
    case functionMenu(destination: FMDest?)
    case petAllFeatures(UUID)
    case petBasicInfo(UUID)
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
    case humanAllFeatures(UUID)
    case humanBasicInfo(UUID)
    case humanMedication(UUID)
    case humanWeight(UUID)
    case humanWorkout(UUID)
    case humanWorkoutDashboard(UUID)
    case humanMetrics(UUID)
    case humanReport(UUID)
    case humanExpense(UUID)
    case humanWishlist(UUID)
    case humanNote(UUID)
    case requiredAccountSwitch
    case settings
    case streakDetail

    var id: String {
        switch self {
        case .accountSwitcher:
            "account-switcher"
        case let .addEntity(type):
            "add-entity-\(type.id)"
        case let .calendar(entityID, humanID):
            "calendar-\(entityID ?? "all")-\(humanID ?? "all")"
        case let .coconutLog(subject):
            "coconut-log-\(subject?.id ?? "all")"
        case let .coconutShop(category):
            "coconut-shop-\(category.rawValue)"
        case let .crewRoster(mode):
            "crew-roster-\(mode.rawValue)"
        case let .functionMenu(destination):
            "function-menu-\(String(describing: destination))"
        case let .petAllFeatures(id):
            "pet-all-\(id.uuidString)"
        case let .petBasicInfo(id):
            "pet-basic-\(id.uuidString)"
        case let .petFood(id):
            "pet-food-\(id.uuidString)"
        case let .petWeight(id):
            "pet-weight-\(id.uuidString)"
        case let .petExpense(id):
            "pet-expense-\(id.uuidString)"
        case let .petFeed(id, opensManualSheet):
            "pet-feed-\(id.uuidString)-manual-\(opensManualSheet)"
        case let .petWater(id):
            "pet-water-\(id.uuidString)"
        case let .petPotty(id):
            "pet-potty-\(id.uuidString)"
        case let .petLitter(id):
            "pet-litter-\(id.uuidString)"
        case let .petPlay(id):
            "pet-play-\(id.uuidString)"
        case let .petHygiene(id):
            "pet-hygiene-\(id.uuidString)"
        case let .petWalkSummary(id):
            "pet-walk-\(id.uuidString)"
        case let .petHealth(id, section):
            "pet-health-\(id.uuidString)-\(section?.appRouteIDValue ?? "default")"
        case let .petMedication(id):
            "pet-medication-\(id.uuidString)"
        case let .petMomentHistory(id):
            "pet-moment-history-\(id.uuidString)"
        case let .petDocuments(id):
            "pet-documents-\(id.uuidString)"
        case let .petAchievements(id):
            "pet-achievements-\(id.uuidString)"
        case let .petRetention(id):
            "pet-retention-\(id.uuidString)"
        case let .petBondVault(id):
            "pet-bond-vault-\(id.uuidString)"
        case let .humanAllFeatures(id):
            "human-all-\(id.uuidString)"
        case let .humanBasicInfo(id):
            "human-basic-\(id.uuidString)"
        case let .humanMedication(id):
            "human-medication-\(id.uuidString)"
        case let .humanWeight(id):
            "human-weight-\(id.uuidString)"
        case let .humanWorkout(id):
            "human-workout-\(id.uuidString)"
        case let .humanWorkoutDashboard(id):
            "human-workout-dashboard-\(id.uuidString)"
        case let .humanMetrics(id):
            "human-metrics-\(id.uuidString)"
        case let .humanReport(id):
            "human-report-\(id.uuidString)"
        case let .humanExpense(id):
            "human-expense-\(id.uuidString)"
        case let .humanWishlist(id):
            "human-wishlist-\(id.uuidString)"
        case let .humanNote(id):
            "human-note-\(id.uuidString)"
        case .requiredAccountSwitch:
            "required-account-switch"
        case .settings:
            "settings"
        case .streakDetail:
            "streak-detail"
        }
    }
}

enum AppFullScreenRoute: Hashable, Identifiable {
    case oasisReward
    case requiredHumanProfile
    case walk(petID: UUID)

    var id: String {
        switch self {
        case .oasisReward:
            "oasis-reward"
        case .requiredHumanProfile:
            "required-human-profile"
        case let .walk(petID):
            "walk-\(petID.uuidString)"
        }
    }
}

enum AppOverlayRoute: Hashable, Identifiable {
    case quickMoment(routeID: UUID = UUID(), petID: UUID)

    var id: String {
        switch self {
        case let .quickMoment(routeID, _):
            "quick-moment-\(routeID.uuidString)"
        }
    }
}

enum AppRouteNotificationEvent: Equatable {
    case humanDeleted(requiresReplacementHuman: Bool, requiresAccountSwitch: Bool)
    case reminderRouteRequested
}

enum AppRouteNotificationOutcome: Equatable {
    case none
    case clearActiveHuman
    case reconcileHumanRequirement
}

struct AppRoutePublishedEvent: Identifiable, Equatable {
    let id = UUID()
    let event: AppRouteNotificationEvent
}

@MainActor
final class AppRouteCoordinator: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var sheet: AppSheetRoute?
    @Published var fullScreen: AppFullScreenRoute?
    @Published var overlay: AppOverlayRoute?
    @Published private(set) var rootIdentity = UUID()

    var suppressesGlobalWalkBanner: Bool {
        fullScreen != nil || overlay != nil
    }

    func openPet(_ id: UUID, initialTab: PetDetailTab = .overview) {
        push(.petProfile(id: id, initialTab: initialTab))
    }

    func openHuman(_ id: UUID) {
        push(.humanProfile(id: id))
    }

    func openPlant(_: UUID) {
        AppFeatureRouteGuard.recordIntercept("plantProfile")
    }

    func presentAccountSwitcher() {
        presentSheet(.accountSwitcher)
    }

    func presentFunctionMenu(destination: FMDest? = nil) {
        switch AppFeatureRouteGuard.functionDestinationDecision(destination, currentLevel: currentFeatureLevel) {
        case .rootMenu:
            presentSheet(.functionMenu(destination: nil))
        case let .allow(destination):
            presentSheet(.functionMenu(destination: destination))
        case let .redirectToRoadmap(note):
            AppFeatureRouteGuard.recordIntercept(note)
            presentSheet(.functionMenu(destination: .growthRoadmap))
        case let .suppress(note):
            AppFeatureRouteGuard.recordIntercept(note)
            presentSheet(.functionMenu(destination: nil))
        }
    }

    func presentCalendar(entityID: String? = nil, humanID: String? = nil) {
        presentSheet(.calendar(entityID: entityID, humanID: humanID))
    }

    func presentCoconutShop(category: ShopItem.ShopCategory = .appIcon) {
        guard AppFeatureRouteGuard.allowsSheetRoute(.coconutShop(category), currentLevel: currentFeatureLevel) else {
            AppFeatureRouteGuard.recordIntercept(
                AppFeatureRouteGuard.lockedRouteNote(
                    for: AppSheetRoute.coconutShop(category),
                    currentLevel: currentFeatureLevel
                )
            )
            presentFunctionMenu(destination: .growthRoadmap)
            return
        }
        presentSheet(.coconutShop(category))
    }

    func presentAddEntity(_ type: EntityType) {
        guard AppFeatureRouteGuard.allowsAddEntity(type) else {
            AppFeatureRouteGuard.recordIntercept("addEntity:\(type.rawValue)")
            return
        }
        presentSheet(.addEntity(type))
    }

    func presentSheet(_ route: AppSheetRoute) {
        guard AppFeatureRouteGuard.allowsSheetRoute(route, currentLevel: currentFeatureLevel) else {
            AppFeatureRouteGuard.recordIntercept(
                AppFeatureRouteGuard.lockedRouteNote(for: route, currentLevel: currentFeatureLevel)
            )
            fullScreen = nil
            overlay = nil
            sheet = .functionMenu(destination: .growthRoadmap)
            return
        }
        fullScreen = nil
        overlay = nil
        sheet = route
    }

    func presentCrewRoster(mode: CrewRosterMode = .members) {
        presentSheet(.crewRoster(mode))
    }

    func presentCoconutLog(_ subject: CoconutLogSubject?) {
        presentSheet(.coconutLog(subject))
    }

    func presentQuickMoment(petID: UUID) {
        sheet = nil
        fullScreen = nil
        overlay = .quickMoment(petID: petID)
    }

    func presentSettings() {
        presentSheet(.settings)
    }

    func presentStreakDetail() {
        presentSheet(.streakDetail)
    }

    func presentOasisReward() {
        sheet = nil
        overlay = nil
        fullScreen = .oasisReward
    }

    func presentRequiredHumanProfile() {
        sheet = nil
        overlay = nil
        fullScreen = .requiredHumanProfile
    }

    func presentWalk(petID: UUID) {
        sheet = nil
        overlay = nil
        fullScreen = .walk(petID: petID)
    }

    func presentRequiredAccountSwitch() {
        fullScreen = nil
        overlay = nil
        sheet = .requiredAccountSwitch
    }

    func push(_ route: AppRoute) {
        guard AppFeatureRouteGuard.allowsAppRoute(route) else {
            AppFeatureRouteGuard.recordIntercept(route.id)
            return
        }
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func dismissSheet(_ route: AppSheetRoute? = nil) {
        guard route == nil || sheet == route else { return }
        sheet = nil
    }

    func dismissFullScreen(_ route: AppFullScreenRoute? = nil) {
        guard route == nil || fullScreen == route else { return }
        fullScreen = nil
    }

    func dismissOverlay(_ route: AppOverlayRoute? = nil) {
        guard route == nil || overlay == route else { return }
        overlay = nil
    }

    func handleNotificationEvent(_ event: AppRouteNotificationEvent) -> AppRouteNotificationOutcome {
        switch event {
        case let .humanDeleted(requiresReplacementHuman, requiresAccountSwitch):
            resetToHome(rebuildRoot: true)
            if requiresReplacementHuman {
                presentRequiredHumanProfile()
                return .clearActiveHuman
            }
            if requiresAccountSwitch {
                presentRequiredAccountSwitch()
                return .clearActiveHuman
            }
            return .reconcileHumanRequirement
        case .reminderRouteRequested:
            resetToHome()
            return .none
        }
    }

    func resetToHome(rebuildRoot: Bool = false) {
        path.removeAll()
        sheet = nil
        fullScreen = nil
        overlay = nil
        if rebuildRoot {
            rootIdentity = UUID()
        }
    }
}

private extension AppRouteCoordinator {
    var currentFeatureLevel: Int {
        OasisTreeManagerRegistry.current.treeLevel.rawValue
    }
}

private extension PetHealthInitialSection {
    var appRouteIDValue: String {
        switch self {
        case .preventive: "preventive"
        case .medication: "medication"
        case .symptomVisit: "symptomVisit"
        }
    }
}
