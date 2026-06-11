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
            AppPresentationPolicy(
                surface: .compactSheet,
                loading: .shellFirst(delayMS: 64),
                instrumentationName: "home.accountSwitcher",
                detents: [.medium, .large],
                cornerRadius: OhanaRadius.sheetCompact
            )
        case .functionMenu:
            homeSheetPagePolicy("home.functionMenu")
        case .streakDetail:
            homeSheetPagePolicy("home.streakDetail")
        case .addEntity:
            homeSheetPagePolicy("home.addEntity")
        case .coconutLog:
            homeSheetPagePolicy("home.coconutLog")
        case .crewRoster:
            homeSheetPagePolicy("home.crewRoster")
        case .calendar:
            homeSheetPagePolicy("home.calendar")
        case .settings:
            homeSheetPagePolicy("home.settings")
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
            cornerRadius: OhanaRadius.sheetPage
        )
    }
}

private extension HomeSheetRoute {
    var presentationName: String {
        switch self {
        case .petAllFeatures:
            "petAllFeatures"
        case .humanAllFeatures:
            "humanAllFeatures"
        case .petBasicInfo:
            "petBasicInfo"
        case .humanBasicInfo:
            "humanBasicInfo"
        case .petFood:
            "petFood"
        case .petWeightQuick:
            "petWeightQuick"
        case .petWeight:
            "petWeight"
        case .petExpenseQuick:
            "petExpenseQuick"
        case .petExpense:
            "petExpense"
        case .petFeed:
            "petFeed"
        case .petWater:
            "petWater"
        case .petPotty:
            "petPotty"
        case .petLitter:
            "petLitter"
        case .petPlay:
            "petPlay"
        case .petHygiene:
            "petHygiene"
        case .petWalkSummary:
            "petWalkSummary"
        case .petHealth:
            "petHealth"
        case .petMedication:
            "petMedication"
        case .petMomentHistory:
            "petMomentHistory"
        case .petDocuments:
            "petDocuments"
        case .petAchievements:
            "petAchievements"
        case .petRetention:
            "petRetention"
        case .petBondVault:
            "petBondVault"
        case .humanMedicationQuick:
            "humanMedicationQuick"
        case .humanMedication:
            "humanMedication"
        case .humanWeightQuick:
            "humanWeightQuick"
        case .humanWeight:
            "humanWeight"
        case .humanWorkoutQuick:
            "humanWorkoutQuick"
        case .humanWorkout:
            "humanWorkout"
        case .humanWorkoutDashboard:
            "humanWorkoutDashboard"
        case .humanMetrics:
            "humanMetrics"
        case .humanReport:
            "humanReport"
        case .humanExpenseQuick:
            "humanExpenseQuick"
        case .humanExpense:
            "humanExpense"
        case .humanWishlist:
            "humanWishlist"
        case .humanNoteQuick:
            "humanNoteQuick"
        case .humanNote:
            "humanNote"
        }
    }
}

private extension HomeFullScreenRoute {
    var presentationName: String {
        switch self {
        case .walk:
            "walk"
        case .oasisReward:
            "oasisReward"
        }
    }
}

private extension HomeOverlayRoute {
    var presentationName: String {
        switch self {
        case .quickMoment:
            "quickMoment"
        }
    }
}
