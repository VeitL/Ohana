//
//  AppFeatureRouteGuard.swift
//  Ohana
//
//  Central guard for feature visibility and route fallbacks.
//

import Foundation

enum AppFeatureRouteGuard {
    enum FunctionDestinationDecision: Equatable {
        case rootMenu
        case allow(FMDest)
        case redirectToRoadmap(note: String)
        case suppress(note: String)

        var directDestination: FMDest? {
            switch self {
            case .rootMenu, .suppress:
                nil
            case let .allow(destination):
                destination
            case .redirectToRoadmap:
                .growthRoadmap
            }
        }
    }

    static func functionDestinationDecision(
        _ destination: FMDest?,
        currentLevel: Int
    ) -> FunctionDestinationDecision {
        guard let destination else { return .rootMenu }
        guard allowsOnlineDestination(destination) else {
            return .suppress(note: "onlineGate:\(destination)")
        }
        guard allowsPlantDestination(destination) else {
            return .suppress(note: "plantGate:\(destination)")
        }

        switch GrowthUnlockPolicy.availability(for: destination, currentLevel: currentLevel) {
        case .visible:
            return .allow(destination)
        case .hiddenLocked:
            return .redirectToRoadmap(note: "locked:\(destination)")
        case .outOfScope:
            return .suppress(note: "outOfScope:\(destination)")
        }
    }

    static func availability(for destination: FMDest, currentLevel: Int) -> AppFeatureAvailability {
        guard allowsPlantDestination(destination) else { return .outOfScope }
        return GrowthUnlockPolicy.availability(for: destination, currentLevel: currentLevel)
    }

    static func availability(for group: FeatureGroup, currentLevel: Int) -> AppFeatureAvailability {
        guard allowsPlantGroup(group) else { return .outOfScope }
        return GrowthUnlockPolicy.availability(for: group, currentLevel: currentLevel)
    }

    static func visibleFeatureGroups(
        from groups: [FeatureGroup],
        currentLevel: Int
    ) -> [FeatureGroup] {
        groups.filter { availability(for: $0, currentLevel: currentLevel).isVisibleInApp }
    }

    static func visibleFunctionDestination(
        _ destination: FMDest?,
        currentLevel: Int
    ) -> FMDest? {
        functionDestinationDecision(destination, currentLevel: currentLevel).directDestination
    }

    static func isVisibleFunctionDestination(
        _ destination: FMDest,
        currentLevel: Int
    ) -> Bool {
        if case .allow = functionDestinationDecision(destination, currentLevel: currentLevel) {
            return true
        }
        return false
    }

    static func allowsAddEntity(_ type: EntityType) -> Bool {
        if type == .plant {
            return PlantFeatureGate.allows(.plants)
        }
        return type.isAvailable
    }

    static func addEntityFallbackDestination(for type: EntityType) -> FMDest? {
        allowsAddEntity(type) ? nil : .growthRoadmap
    }

    static func allowsAppRoute(_ route: AppRoute) -> Bool {
        switch route {
        case .plantProfile:
            PlantFeatureGate.allows(.plants)
        case .petProfile, .humanProfile:
            true
        }
    }

    static func allowsHomeTab(
        _ tab: VerticalSolidHomeTab,
        starterGiftDefaults: UserDefaults = .standard
    ) -> Bool {
        switch tab {
        case .plants:
            PlantFeatureGate.allows(.plants)
        case .oasis:
            StarterGiftService.isOasisHomeTabUnlocked(defaults: starterGiftDefaults)
        case .home, .calendar:
            true
        }
    }

    static func visibleHomeTabs(starterGiftDefaults: UserDefaults = .standard) -> [VerticalSolidHomeTab] {
        VerticalSolidHomeTab.allCases.filter { allowsHomeTab($0, starterGiftDefaults: starterGiftDefaults) }
    }

    static var visibleHomeTabs: [VerticalSolidHomeTab] {
        visibleHomeTabs()
    }

    static var shouldLoadPlantData: Bool {
        PlantFeatureGate.allows(.plants)
    }

    static func currentGrowthStep(currentLevel: Int) -> GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
    }

    static func newlyUnlockedStages(from previousLevel: Int, to currentLevel: Int) -> [GrowthUnlockStep] {
        GrowthUnlockPolicy.newlyUnlockedStages(from: previousLevel, to: currentLevel)
    }

    static func recommendedDestination(for step: GrowthUnlockStep, currentLevel: Int) -> FMDest {
        let destination = GrowthUnlockPolicy.primaryDestination(for: step)
        return visibleFunctionDestination(destination, currentLevel: currentLevel) ?? .growthRoadmap
    }

    static func requiredLevel(for sheetRoute: AppSheetRoute) -> Int? {
        switch sheetRoute {
        case .coconutShop:
            GrowthUnlockPolicy.status(for: FMDest.coconutShop, currentLevel: 0).step.requiredLevel
        default:
            nil
        }
    }

    static func requiredLevel(for oasisRoute: OasisSheetRoute) -> Int? {
        switch oasisRoute {
        case .coconutShop:
            GrowthUnlockPolicy.status(for: FMDest.coconutShop, currentLevel: 0).step.requiredLevel
        case .achievements:
            GrowthUnlockPolicy.status(for: PetFeature.achievements, currentLevel: 0).step.requiredLevel
        case .gacha:
            GrowthUnlockPolicy.status(for: FMDest.gacha, currentLevel: 0).step.requiredLevel
        case .critterCodex:
            critterCodexUnlockLevel
        case .coconutRules, .growthRoadmap, .inventory, .checkInDetail:
            nil
        }
    }

    static func allowsSheetRoute(_ route: AppSheetRoute, currentLevel: Int) -> Bool {
        guard allowsOnlineSheetRoute(route) else { return false }
        guard let requiredLevel = requiredLevel(for: route) else { return true }
        return currentLevel >= requiredLevel
    }

    static func allowsOasisSheetRoute(_ route: OasisSheetRoute, currentLevel: Int) -> Bool {
        guard let requiredLevel = requiredLevel(for: route) else { return true }
        return currentLevel >= requiredLevel
    }

    static func lockedRouteNote(for route: AppSheetRoute, currentLevel: Int) -> String {
        if !allowsOnlineSheetRoute(route) {
            return "onlineGateSheet:\(route.id)"
        }
        if let requiredLevel = requiredLevel(for: route) {
            return "lockedSheet:\(route.id):lv\(currentLevel):requires\(requiredLevel)"
        }
        return "lockedSheet:\(route.id):lv\(currentLevel)"
    }

    static func lockedRouteNote(for route: OasisSheetRoute, currentLevel: Int) -> String {
        if let requiredLevel = requiredLevel(for: route) {
            return "lockedOasisSheet:\(route.id):lv\(currentLevel):requires\(requiredLevel)"
        }
        return "lockedOasisSheet:\(route.id):lv\(currentLevel)"
    }

    static func recordIntercept(_ note: String) {
        AppPerformanceMonitor.shared.record("hidden_route_intercepted", valueMS: 0, note: note)
    }

    private static var critterCodexUnlockLevel: Int {
        OasisUpgradeRewardCatalog.critter(id: OasisUpgradeRewardCatalog.firstCritterId)?.sourceLevel ?? 10
    }

    private static func allowsOnlineDestination(_ destination: FMDest) -> Bool {
        !requiresOnlineCollaboration(destination) || OnlineFeatureGate.allows(.onlineCollaboration)
    }

    private static func requiresOnlineCollaboration(_ destination: FMDest) -> Bool {
        switch destination {
        case .bountyBoard:
            true
        default:
            false
        }
    }

    private static func allowsOnlineSheetRoute(_ route: AppSheetRoute) -> Bool {
        !requiresOnlineCollaboration(route) || OnlineFeatureGate.allows(.onlineCollaboration)
    }

    private static func requiresOnlineCollaboration(_ route: AppSheetRoute) -> Bool {
        switch route {
        case .crewRoster(.collaboration):
            true
        default:
            false
        }
    }

    private static func allowsPlantDestination(_ destination: FMDest) -> Bool {
        !requiresPlantFeature(destination) || PlantFeatureGate.allows(.plants)
    }

    private static func requiresPlantFeature(_ destination: FMDest) -> Bool {
        switch destination {
        case .plantsDashboard, .plantDetail:
            true
        case .featureGroup(.plants):
            true
        default:
            false
        }
    }

    private static func allowsPlantGroup(_ group: FeatureGroup) -> Bool {
        !requiresPlantFeature(group) || PlantFeatureGate.allows(.plants)
    }

    private static func requiresPlantFeature(_ group: FeatureGroup) -> Bool {
        group == .plants
    }
}
