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
            return "pet-profile-\(id.uuidString)-\(tab.rawValue)"
        case let .humanProfile(id):
            return "human-profile-\(id.uuidString)"
        case let .plantProfile(id):
            return "plant-profile-\(id.uuidString)"
        }
    }

    var sourceID: UUID {
        switch self {
        case let .petProfile(id, _),
             let .humanProfile(id),
             let .plantProfile(id):
            return id
        }
    }
}

enum AppSheetRoute: Hashable, Identifiable {
    case accountSwitcher
    case addEntity(EntityType)
    case calendar(entityID: String?, humanID: String?)
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
    case streakDetail

    var id: String {
        switch self {
        case .accountSwitcher:
            return "account-switcher"
        case let .addEntity(type):
            return "add-entity-\(type.id)"
        case let .calendar(entityID, humanID):
            return "calendar-\(entityID ?? "all")-\(humanID ?? "all")"
        case let .functionMenu(destination):
            return "function-menu-\(String(describing: destination))"
        case let .petAllFeatures(id):
            return "pet-all-\(id.uuidString)"
        case let .petBasicInfo(id):
            return "pet-basic-\(id.uuidString)"
        case let .petFood(id):
            return "pet-food-\(id.uuidString)"
        case let .petWeight(id):
            return "pet-weight-\(id.uuidString)"
        case let .petExpense(id):
            return "pet-expense-\(id.uuidString)"
        case let .petFeed(id, opensManualSheet):
            return "pet-feed-\(id.uuidString)-manual-\(opensManualSheet)"
        case let .petWater(id):
            return "pet-water-\(id.uuidString)"
        case let .petPotty(id):
            return "pet-potty-\(id.uuidString)"
        case let .petLitter(id):
            return "pet-litter-\(id.uuidString)"
        case let .petPlay(id):
            return "pet-play-\(id.uuidString)"
        case let .petHygiene(id):
            return "pet-hygiene-\(id.uuidString)"
        case let .petWalkSummary(id):
            return "pet-walk-\(id.uuidString)"
        case let .petHealth(id, section):
            return "pet-health-\(id.uuidString)-\(section?.appRouteIDValue ?? "default")"
        case let .petMedication(id):
            return "pet-medication-\(id.uuidString)"
        case let .petMomentHistory(id):
            return "pet-moment-history-\(id.uuidString)"
        case let .petDocuments(id):
            return "pet-documents-\(id.uuidString)"
        case let .petAchievements(id):
            return "pet-achievements-\(id.uuidString)"
        case let .petRetention(id):
            return "pet-retention-\(id.uuidString)"
        case let .petBondVault(id):
            return "pet-bond-vault-\(id.uuidString)"
        case let .humanAllFeatures(id):
            return "human-all-\(id.uuidString)"
        case let .humanBasicInfo(id):
            return "human-basic-\(id.uuidString)"
        case let .humanMedication(id):
            return "human-medication-\(id.uuidString)"
        case let .humanWeight(id):
            return "human-weight-\(id.uuidString)"
        case let .humanWorkout(id):
            return "human-workout-\(id.uuidString)"
        case let .humanWorkoutDashboard(id):
            return "human-workout-dashboard-\(id.uuidString)"
        case let .humanMetrics(id):
            return "human-metrics-\(id.uuidString)"
        case let .humanReport(id):
            return "human-report-\(id.uuidString)"
        case let .humanExpense(id):
            return "human-expense-\(id.uuidString)"
        case let .humanWishlist(id):
            return "human-wishlist-\(id.uuidString)"
        case let .humanNote(id):
            return "human-note-\(id.uuidString)"
        case .requiredAccountSwitch:
            return "required-account-switch"
        case .streakDetail:
            return "streak-detail"
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
            return "oasis-reward"
        case .requiredHumanProfile:
            return "required-human-profile"
        case let .walk(petID):
            return "walk-\(petID.uuidString)"
        }
    }
}

enum AppOverlayRoute: Hashable, Identifiable {
    case coconutLog(CoconutLogSubject)
    case crewRoster(CrewRosterMode)
    case quickMoment(routeID: UUID = UUID(), petID: UUID)
    case settings

    var id: String {
        switch self {
        case let .coconutLog(subject):
            return "coconut-log-\(subject.id)"
        case let .crewRoster(mode):
            return "crew-roster-\(mode.rawValue)"
        case let .quickMoment(routeID, _):
            return "quick-moment-\(routeID.uuidString)"
        case .settings:
            return "settings"
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

    func openPlant(_ id: UUID) {
        push(.plantProfile(id: id))
    }

    func presentAccountSwitcher() {
        presentSheet(.accountSwitcher)
    }

    func presentFunctionMenu(destination: FMDest? = nil) {
        presentSheet(.functionMenu(destination: destination))
    }

    func presentCalendar(entityID: String? = nil, humanID: String? = nil) {
        presentSheet(.calendar(entityID: entityID, humanID: humanID))
    }

    func presentAddEntity(_ type: EntityType) {
        presentSheet(.addEntity(type))
    }

    func presentSheet(_ route: AppSheetRoute) {
        fullScreen = nil
        overlay = nil
        sheet = route
    }

    func presentCrewRoster(mode: CrewRosterMode = .members) {
        sheet = nil
        fullScreen = nil
        overlay = .crewRoster(mode)
    }

    func presentCoconutLog(_ subject: CoconutLogSubject) {
        sheet = nil
        fullScreen = nil
        overlay = .coconutLog(subject)
    }

    func presentQuickMoment(petID: UUID) {
        sheet = nil
        fullScreen = nil
        overlay = .quickMoment(petID: petID)
    }

    func presentSettings() {
        sheet = nil
        fullScreen = nil
        overlay = .settings
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

private extension PetHealthInitialSection {
    var appRouteIDValue: String {
        switch self {
        case .preventive: return "preventive"
        case .medication: return "medication"
        case .symptomVisit: return "symptomVisit"
        }
    }
}
