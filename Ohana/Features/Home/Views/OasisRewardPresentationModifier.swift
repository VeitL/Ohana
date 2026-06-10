//
//  OasisRewardPresentationModifier.swift
//  Ohana
//
//  Typed presentation host for Oasis sheets and full-screen routes.
//

import SwiftUI

struct OasisRewardPresentationModifier: ViewModifier {
    @Binding var sheetRoute: OasisSheetRoute?
    @Binding var fullScreenRoute: OasisFullScreenRoute?
    let pets: [Pet]
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $fullScreenRoute) { route in
                fullScreenDestination(route)
            }
            .sheet(item: $sheetRoute) { route in
                sheetDestination(route)
            }
    }

    @ViewBuilder
    private func fullScreenDestination(_ route: OasisFullScreenRoute) -> some View {
        switch route {
        case .coconutLog:
            Color.clear
                .onAppear {
                    onPresentCoconutLog?(nil)
                    fullScreenRoute = nil
                }
        }
    }

    @ViewBuilder
    private func sheetDestination(_ route: OasisSheetRoute) -> some View {
        switch route {
        case .coconutRules:
            CoconutRulesSheet()
                .ohanaSheetPagePresentation() // ui-v4: allow rules reference sheet
        case .growthRoadmap:
            GrowthUnlockRoadmapView(
                currentLevel: currentFeatureLevel,
                progressToNextLevel: appServices.oasisTree.progressToNextLevel,
                appLanguage: appLanguage,
                onClose: { sheetRoute = nil }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow long growth roadmap overview
        case .achievements:
            if let pet = pets.first {
                AchievementWallView(
                    pet: pet,
                    allPets: pets,
                    onPresentCoconutLog: onPresentCoconutLog
                )
                .ohanaSheetPagePresentation() // ui-v4: allow long achievement overview
            }
        case .inventory:
            InventoryView()
                .ohanaSheetPagePresentation() // ui-v4: allow long inventory overview
        case let .coconutShop(category):
            if AppFeatureRouteGuard.allowsOasisSheetRoute(route, currentLevel: currentFeatureLevel) {
                CoconutShopRouteContainer(initialCategory: category)
                    .ohanaSheetPagePresentation() // ui-v4: allow long shop overview
            } else {
                lockedOasisRoute(route)
            }
        case .gacha:
            if AppFeatureRouteGuard.allowsOasisSheetRoute(route, currentLevel: currentFeatureLevel) {
                GachaRouteContainer(onPresentCoconutLog: onPresentCoconutLog)
                    .ohanaSheetPagePresentation() // ui-v4: allow long blind-box overview
            } else {
                lockedOasisRoute(route)
            }
        case .checkInDetail:
            DailyStreakDetailRouteContainer(
                onClose: { sheetRoute = nil },
                onPresentCoconutLog: onPresentCoconutLog,
                onPresentCoconutShop: { category in
                    presentOasisSheet(.coconutShop(category))
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow long streak overview
        case .critterCodex:
            if AppFeatureRouteGuard.allowsOasisSheetRoute(route, currentLevel: currentFeatureLevel) {
                OasisCritterCodexRouteContainer(
                    mode: .codex,
                    onPresentCoconutLog: onPresentCoconutLog ?? { _ in }
                )
                .ohanaSheetPagePresentation() // ui-v4: allow long critter codex overview
            } else {
                lockedOasisRoute(route)
            }
        }
    }

    private var currentFeatureLevel: Int {
        appServices.oasisTree.treeLevel.rawValue
    }

    private func presentOasisSheet(_ route: OasisSheetRoute) {
        guard AppFeatureRouteGuard.allowsOasisSheetRoute(route, currentLevel: currentFeatureLevel) else {
            AppFeatureRouteGuard.recordIntercept(
                AppFeatureRouteGuard.lockedRouteNote(for: route, currentLevel: currentFeatureLevel)
            )
            return
        }
        sheetRoute = route
    }

    private func lockedOasisRoute(_ route: OasisSheetRoute) -> some View {
        Color.clear
            .onAppear {
                AppFeatureRouteGuard.recordIntercept(
                    AppFeatureRouteGuard.lockedRouteNote(for: route, currentLevel: currentFeatureLevel)
                )
                sheetRoute = nil
            }
    }
}
