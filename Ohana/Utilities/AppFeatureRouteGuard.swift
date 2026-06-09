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
                return nil
            case let .allow(destination):
                return destination
            case .redirectToRoadmap:
                return .growthRoadmap
            }
        }
    }

    static func functionDestinationDecision(
        _ destination: FMDest?,
        currentLevel: Int
    ) -> FunctionDestinationDecision {
        guard let destination else { return .rootMenu }

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
        GrowthUnlockPolicy.availability(for: destination, currentLevel: currentLevel)
    }

    static func availability(for group: FeatureGroup, currentLevel: Int) -> AppFeatureAvailability {
        GrowthUnlockPolicy.availability(for: group, currentLevel: currentLevel)
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
        type.isAvailable
    }

    static func addEntityFallbackDestination(for type: EntityType) -> FMDest? {
        allowsAddEntity(type) ? nil : .growthRoadmap
    }

    static func allowsAppRoute(_ route: AppRoute) -> Bool {
        switch route {
        case .plantProfile:
            return false
        case .petProfile, .humanProfile:
            return true
        }
    }

    static func allowsHomeTab(_ tab: VerticalSolidHomeTab) -> Bool {
        switch tab {
        case .plants:
            return false
        case .home, .calendar, .oasis:
            return true
        }
    }

    static var visibleHomeTabs: [VerticalSolidHomeTab] {
        [.home, .calendar, .oasis]
    }

    static var shouldLoadPlantData: Bool {
        !GrowthUnlockPolicy.isOutOfScope(.plantsDashboard)
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

    static func recordIntercept(_ note: String) {
        AppPerformanceMonitor.shared.record("hidden_route_intercepted", valueMS: 0, note: note)
    }
}
