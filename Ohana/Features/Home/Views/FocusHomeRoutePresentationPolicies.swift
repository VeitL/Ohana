//
//  FocusHomeRoutePresentationPolicies.swift
//  Ohana
//
//  Presentation policy mapping for home routes.
//

import SwiftUI

extension AppPresentationPolicyProvider {
    static func policy(for route: HomeModalRoute) -> AppPresentationPolicy {
        switch route {
        case .accountSwitcher:
            return AppPresentationPolicy(
                surface: .compactSheet,
                loading: .shellFirst(delayMS: 64),
                instrumentationName: "home.accountSwitcher",
                detents: [.medium, .large],
                cornerRadius: 32
            )
        case .functionMenu:
            return homeSheetPagePolicy("home.functionMenu")
        case .streakDetail:
            return homeSheetPagePolicy("home.streakDetail")
        case .addEntity:
            return homeSheetPagePolicy("home.addEntity")
        case .coconutLog:
            return homeSheetPagePolicy("home.coconutLog")
        case .crewRoster:
            return homeSheetPagePolicy("home.crewRoster")
        case .calendar:
            return homeSheetPagePolicy("home.calendar")
        case .settings:
            return homeSheetPagePolicy("home.settings")
        }
    }

    static func policy(for route: HomeSheetRoute) -> AppPresentationPolicy {
        homeSheetPagePolicy("home.\(route.presentationName)")
    }

    static func policy(for route: HomeFullScreenRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .fullScreen,
            loading: .shellFirst(delayMS: 64),
            instrumentationName: "home.\(route.presentationName)"
        )
    }

    static func policy(for route: HomeOverlayRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .inlineOverlay,
            loading: .immediate,
            instrumentationName: "home.\(route.presentationName)"
        )
    }

    static func policyForHomeCoconutLog() -> AppPresentationPolicy {
        homeSheetPagePolicy("home.coconutLog")
    }

    static func policyForHomeCrewRoster() -> AppPresentationPolicy {
        homeSheetPagePolicy("home.crewRoster")
    }

    static func policyForHomeSettings() -> AppPresentationPolicy {
        homeSheetPagePolicy("home.settings")
    }

    private static func homeSheetPagePolicy(_ name: String) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .sheetPage,
            loading: .shellFirst(delayMS: 80),
            instrumentationName: name,
            detents: [.large],
            cornerRadius: 36
        )
    }
}

private extension HomeSheetRoute {
    var presentationName: String {
        switch self {
        case .petAllFeatures:
            return "petAllFeatures"
        case .humanAllFeatures:
            return "humanAllFeatures"
        case .petBasicInfo:
            return "petBasicInfo"
        case .humanBasicInfo:
            return "humanBasicInfo"
        case .petFood:
            return "petFood"
        case .petWeight:
            return "petWeight"
        case .petExpense:
            return "petExpense"
        case .petFeed:
            return "petFeed"
        case .petWater:
            return "petWater"
        case .petPotty:
            return "petPotty"
        case .petLitter:
            return "petLitter"
        case .petPlay:
            return "petPlay"
        case .petHygiene:
            return "petHygiene"
        case .petWalkSummary:
            return "petWalkSummary"
        case .petHealth:
            return "petHealth"
        case .petMedication:
            return "petMedication"
        case .petMomentHistory:
            return "petMomentHistory"
        case .petDocuments:
            return "petDocuments"
        case .petAchievements:
            return "petAchievements"
        case .petRetention:
            return "petRetention"
        case .petBondVault:
            return "petBondVault"
        case .humanMedication:
            return "humanMedication"
        case .humanWeight:
            return "humanWeight"
        case .humanWorkout:
            return "humanWorkout"
        case .humanWorkoutDashboard:
            return "humanWorkoutDashboard"
        case .humanMetrics:
            return "humanMetrics"
        case .humanReport:
            return "humanReport"
        case .humanExpense:
            return "humanExpense"
        case .humanWishlist:
            return "humanWishlist"
        case .humanNote:
            return "humanNote"
        }
    }
}

private extension HomeFullScreenRoute {
    var presentationName: String {
        switch self {
        case .walk:
            return "walk"
        case .oasisReward:
            return "oasisReward"
        }
    }
}

private extension HomeOverlayRoute {
    var presentationName: String {
        switch self {
        case .quickMoment:
            return "quickMoment"
        }
    }
}

