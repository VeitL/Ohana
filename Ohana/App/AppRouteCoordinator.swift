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

    var taskCenterContext: TaskCenterRouteContext {
        switch self {
        case let .petProfile(id, _):
            TaskCenterRouteContext(scope: .pet(id), focusedFamilyTaskID: nil)
        case let .humanProfile(id):
            .human(id)
        case let .plantProfile(id):
            TaskCenterRouteContext(scope: .plant(id), focusedFamilyTaskID: nil)
        }
    }
}

enum AppSheetRoute: Hashable, Identifiable {
    case accountSwitcher
    case addEntity(EntityType)
    case calendar(entityID: String?, humanID: String?, plantID: String?)
    case taskCenter(TaskCenterRouteContext)
    case coconutLog(CoconutLogSubject?)
    case coconutShop(ShopItem.ShopCategory)
    case crewRoster(CrewRosterMode)
    case functionMenu(destination: FMDest?)
    case petAllFeatures(UUID)
    case petBasicInfo(UUID)
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
    case petMomentQuick(UUID)
    case petMomentHistory(UUID)
    case petDocuments(UUID)
    case petAchievements(UUID)
    case petRetention(UUID)
    case petBondVault(UUID)
    case humanAllFeatures(UUID)
    case humanBasicInfo(UUID)
    case humanMedicationQuick(UUID)
    case humanMedication(UUID)
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
    case guardianSafety(invitationCode: String?, incidentID: String?)
    case requiredAccountSwitch
    case settings
    case streakDetail

    var id: String {
        switch self {
        case .accountSwitcher:
            "account-switcher"
        case let .addEntity(type):
            "add-entity-\(type.id)"
        case let .calendar(entityID, humanID, plantID):
            "calendar-\(entityID ?? "all")-\(humanID ?? "all")-\(plantID ?? "all")"
        case let .taskCenter(context):
            "task-center-\(context.scope.routeID)-\(context.focusedItemID ?? context.focusedFamilyTaskID?.uuidString ?? context.creationPreset?.requestID.uuidString ?? "all")"
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
        case let .petWeightQuick(id):
            "pet-weight-quick-\(id.uuidString)"
        case let .petWeight(id):
            "pet-weight-\(id.uuidString)"
        case let .petExpenseQuick(id):
            "pet-expense-quick-\(id.uuidString)"
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
        case let .petMomentQuick(id):
            "pet-moment-quick-\(id.uuidString)"
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
        case let .humanMedicationQuick(id):
            "human-medication-quick-\(id.uuidString)"
        case let .humanMedication(id):
            "human-medication-\(id.uuidString)"
        case let .humanWeightQuick(id):
            "human-weight-quick-\(id.uuidString)"
        case let .humanWeight(id):
            "human-weight-\(id.uuidString)"
        case let .humanWorkoutQuick(id):
            "human-workout-quick-\(id.uuidString)"
        case let .humanWorkout(id):
            "human-workout-\(id.uuidString)"
        case let .humanWorkoutDashboard(id):
            "human-workout-dashboard-\(id.uuidString)"
        case let .humanMetrics(id):
            "human-metrics-\(id.uuidString)"
        case let .humanReport(id):
            "human-report-\(id.uuidString)"
        case let .humanExpenseQuick(id):
            "human-expense-quick-\(id.uuidString)"
        case let .humanExpense(id):
            "human-expense-\(id.uuidString)"
        case let .humanWishlist(id):
            "human-wishlist-\(id.uuidString)"
        case let .humanNoteQuick(id):
            "human-note-quick-\(id.uuidString)"
        case let .humanNote(id):
            "human-note-\(id.uuidString)"
        case let .guardianSafety(invitationCode, incidentID):
            "guardian-safety-\(invitationCode ?? "none")-\(incidentID ?? "none")"
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
    case petWeightQuick(routeID: UUID = UUID(), petID: UUID)
    case petExpenseQuick(routeID: UUID = UUID(), petID: UUID)
    case humanMedicationQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanWeightQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanWorkoutQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanExpenseQuick(routeID: UUID = UUID(), humanID: UUID)
    case humanNoteQuick(routeID: UUID = UUID(), humanID: UUID)

    var id: String {
        switch self {
        case let .quickMoment(routeID, _):
            "quick-moment-\(routeID.uuidString)"
        case let .petWeightQuick(routeID, _):
            "pet-weight-quick-\(routeID.uuidString)"
        case let .petExpenseQuick(routeID, _):
            "pet-expense-quick-\(routeID.uuidString)"
        case let .humanMedicationQuick(routeID, _):
            "human-medication-quick-\(routeID.uuidString)"
        case let .humanWeightQuick(routeID, _):
            "human-weight-quick-\(routeID.uuidString)"
        case let .humanWorkoutQuick(routeID, _):
            "human-workout-quick-\(routeID.uuidString)"
        case let .humanExpenseQuick(routeID, _):
            "human-expense-quick-\(routeID.uuidString)"
        case let .humanNoteQuick(routeID, _):
            "human-note-quick-\(routeID.uuidString)"
        }
    }
}

enum AppRouteNotificationEvent: Equatable {
    case humanDeleted(requiresReplacementHuman: Bool, requiresAccountSwitch: Bool)
    case reminderRouteRequested
    case familyWeeklyReportRouteRequested
    case plantBatchCareRouteRequested(careType: PlantCareType?)
    case guardianSafetyRouteRequested(invitationCode: String?, incidentID: String?)
    case guardianIncidentAcknowledgementRequested(incidentID: String)
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

enum AppRoutePresentationDecision<Route: Equatable>: Equatable {
    case allowed(Route)
    case redirected(from: Route?, to: Route, reason: String)
    case suppressed(reason: String)

    var presentedRoute: Route? {
        switch self {
        case let .allowed(route),
             let .redirected(_, route, _):
            route
        case .suppressed:
            nil
        }
    }
}

@MainActor
final class AppRouteCoordinator: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var sheet: AppSheetRoute?
    @Published var fullScreen: AppFullScreenRoute?
    @Published var overlay: AppOverlayRoute?
    @Published private(set) var rootIdentity = UUID()

    var suppressesGlobalWalkBanner: Bool {
        fullScreen != nil || overlay != nil || sheet?.suppressesGlobalWalkBanner == true
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

    func functionMenuPresentationDecision(
        destination: FMDest? = nil,
        currentLevel: Int? = nil,
        plan: OhanaPlanLevel = .free
    ) -> AppRoutePresentationDecision<AppSheetRoute> {
        let requestedRoute = AppSheetRoute.functionMenu(destination: destination)
        switch AppFeatureRouteGuard.functionDestinationDecision(
            destination,
            currentLevel: currentLevel ?? self.currentFeatureLevel,
            plan: plan
        ) {
        case .rootMenu:
            return .allowed(.functionMenu(destination: nil))
        case let .allow(destination):
            return .allowed(.functionMenu(destination: destination))
        case let .redirectToRoadmap(note):
            return .redirected(
                from: requestedRoute,
                to: .functionMenu(destination: .growthRoadmap),
                reason: note
            )
        case let .suppress(note):
            return .redirected(
                from: requestedRoute,
                to: .functionMenu(destination: nil),
                reason: note
            )
        }
    }

    func sheetPresentationDecision(
        for route: AppSheetRoute,
        currentLevel: Int? = nil
    ) -> AppRoutePresentationDecision<AppSheetRoute> {
        let level = currentLevel ?? self.currentFeatureLevel
        guard AppFeatureRouteGuard.allowsSheetRoute(route, currentLevel: level) else {
            return .redirected(
                from: route,
                to: .functionMenu(destination: .growthRoadmap),
                reason: AppFeatureRouteGuard.lockedRouteNote(for: route, currentLevel: level)
            )
        }
        return .allowed(route)
    }

    func addEntityPresentationDecision(_ type: EntityType) -> AppRoutePresentationDecision<AppSheetRoute> {
        let route = AppSheetRoute.addEntity(type)
        guard AppFeatureRouteGuard.allowsAddEntity(type, currentLevel: currentFeatureLevel) else {
            if type == .plant {
                return .redirected(
                    from: route,
                    to: .functionMenu(destination: .growthRoadmap),
                    reason: "addEntity:\(type.rawValue)"
                )
            }
            return .suppressed(reason: "addEntity:\(type.rawValue)")
        }
        return .allowed(route)
    }

    func presentFunctionMenu(
        destination: FMDest? = nil,
        plan: OhanaPlanLevel = .free
    ) {
        applySheetDecision(functionMenuPresentationDecision(destination: destination, plan: plan))
    }

    func presentCalendar(entityID: String? = nil, humanID: String? = nil, plantID _: String? = nil) {
        presentSheet(.calendar(entityID: entityID, humanID: humanID, plantID: nil))
    }

    func presentTaskCenter(context: TaskCenterRouteContext = .all) {
        presentSheet(.taskCenter(context))
    }

    func presentCoconutShop(category: ShopItem.ShopCategory = .appIcon) {
        applySheetDecision(sheetPresentationDecision(for: .coconutShop(category)))
    }

    func presentAddEntity(_ type: EntityType) {
        applySheetDecision(addEntityPresentationDecision(type))
    }

    func presentSheet(_ route: AppSheetRoute) {
        applySheetDecision(sheetPresentationDecision(for: route))
    }

    func presentCrewRoster(mode: CrewRosterMode = .members) {
        presentSheet(.crewRoster(mode))
    }

    func presentCoconutLog(_ subject: CoconutLogSubject?) {
        presentSheet(.coconutLog(subject))
    }

    func presentQuickMoment(petID: UUID) {
        presentSheet(.petMomentQuick(petID))
    }

    func presentPetWeightQuick(petID: UUID) {
        presentSheet(.petWeightQuick(petID))
    }

    func presentHumanWeightQuick(humanID: UUID) {
        presentSheet(.humanWeightQuick(humanID))
    }

    func presentSettings() {
        presentSheet(.settings)
    }

    func presentStreakDetail() {
        presentSheet(.streakDetail)
    }

    func presentOasisReward() {
        setFullScreen(.oasisReward)
    }

    func presentRequiredHumanProfile() {
        setFullScreen(.requiredHumanProfile)
    }

    func presentWalk(petID: UUID) {
        setFullScreen(.walk(petID: petID))
    }

    func presentRequiredAccountSwitch() {
        setSheet(.requiredAccountSwitch)
    }

    func push(_ route: AppRoute) {
        guard AppFeatureRouteGuard.allowsAppRoute(route, currentLevel: currentFeatureLevel) else {
            AppFeatureRouteGuard.recordIntercept(route.id)
            if case .plantProfile = route {
                sheet = .functionMenu(destination: .growthRoadmap)
            }
            return
        }
        guard path.last != route else { return }
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func dismissSheet(_ route: AppSheetRoute? = nil) {
        guard route == nil || sheet == route else { return }
        guard sheet != nil else { return }
        sheet = nil
    }

    func dismissFullScreen(_ route: AppFullScreenRoute? = nil) {
        guard route == nil || fullScreen == route else { return }
        guard fullScreen != nil else { return }
        fullScreen = nil
    }

    func dismissOverlay(_ route: AppOverlayRoute? = nil) {
        guard route == nil || overlay == route else { return }
        guard overlay != nil else { return }
        overlay = nil
    }

    func handleNotificationEvent(
        _ event: AppRouteNotificationEvent,
        plan: OhanaPlanLevel = .free
    ) -> AppRouteNotificationOutcome {
        switch event {
        case let .humanDeleted(requiresReplacementHuman, requiresAccountSwitch):
            // The deletion command dismisses its member route before publishing.
            // Clearing the route state is enough to release that destination;
            // re-identifying the whole root can trap the native TabView in a
            // continuous tab rebuild while Home refreshes after the deletion.
            resetToHome()
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
        case .familyWeeklyReportRouteRequested:
            resetToHome()
            presentFunctionMenu(destination: .familyWeeklyReport, plan: plan)
            return .none
        case let .plantBatchCareRouteRequested(careType):
            resetToHome()
            if let careType {
                presentFunctionMenu(destination: .plantsBatchCareFiltered(careType))
            } else {
                presentFunctionMenu(destination: .plantsBatchCare)
            }
            return .none
        case let .guardianSafetyRouteRequested(invitationCode, incidentID):
            resetToHome()
            presentSheet(.guardianSafety(invitationCode: invitationCode, incidentID: incidentID))
            return .none
        case .guardianIncidentAcknowledgementRequested:
            return .none
        }
    }

    @discardableResult
    func handleExternalURL(_ url: URL) -> Bool {
        guard let route = OhanaExternalRoute.parse(url) else { return false }
        handleExternalRoute(route)
        return true
    }

    func handleExternalRoute(_ route: OhanaExternalRoute) {
        resetToHome()
        switch route {
        case let .taskCenter(focusedItemID):
            presentTaskCenter(
                context: TaskCenterRouteContext(
                    scope: .all,
                    focusedItemID: focusedItemID,
                    focusRequestID: focusedItemID == nil ? nil : UUID()
                )
            )
        case let .activeWalk(petID):
            presentWalk(petID: petID)
        case .settings:
            presentSettings()
        case let .guardianInvite(code):
            presentSheet(.guardianSafety(invitationCode: code, incidentID: nil))
        case let .guardianIncident(id):
            presentSheet(.guardianSafety(invitationCode: nil, incidentID: id))
        }
    }

    func resetToHome(rebuildRoot: Bool = false) {
        if !path.isEmpty {
            path.removeAll()
        }
        if sheet != nil {
            sheet = nil
        }
        if fullScreen != nil {
            fullScreen = nil
        }
        if overlay != nil {
            overlay = nil
        }
        if rebuildRoot {
            rootIdentity = UUID()
        }
    }
}

private extension AppRouteCoordinator {
    func applySheetDecision(_ decision: AppRoutePresentationDecision<AppSheetRoute>) {
        switch decision {
        case let .allowed(route):
            setSheet(route)
        case let .redirected(_, route, reason):
            AppFeatureRouteGuard.recordIntercept(reason)
            setSheet(route)
        case let .suppressed(reason):
            AppFeatureRouteGuard.recordIntercept(reason)
        }
    }

    func setSheet(_ route: AppSheetRoute) {
        guard sheet != route || fullScreen != nil || overlay != nil else { return }
        if fullScreen != nil {
            fullScreen = nil
        }
        if overlay != nil {
            overlay = nil
        }
        if sheet != route {
            sheet = route
        }
    }

    func setOverlay(_ route: AppOverlayRoute) {
        guard overlay != route || sheet != nil || fullScreen != nil else { return }
        if sheet != nil {
            sheet = nil
        }
        if fullScreen != nil {
            fullScreen = nil
        }
        if overlay != route {
            overlay = route
        }
    }

    func setFullScreen(_ route: AppFullScreenRoute) {
        guard fullScreen != route || sheet != nil || overlay != nil else { return }
        if sheet != nil {
            sheet = nil
        }
        if overlay != nil {
            overlay = nil
        }
        if fullScreen != route {
            fullScreen = route
        }
    }

    var currentFeatureLevel: Int {
        OasisTreeManagerRegistry.current.treeLevel.rawValue
    }
}

private extension AppSheetRoute {
    var suppressesGlobalWalkBanner: Bool {
        switch self {
        case .petMomentQuick,
             .petWeightQuick,
             .petExpenseQuick,
             .humanMedicationQuick,
             .humanWeightQuick,
             .humanWorkoutQuick,
             .humanExpenseQuick,
             .humanNoteQuick:
            true
        default:
            false
        }
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
