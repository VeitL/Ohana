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
    let humans: [Human]
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

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
            if AppFeatureRouteGuard.allowsOasisSheetRoute(route, currentLevel: currentFeatureLevel) {
                NavigationStack {
                    AchievementUnifiedWallView(pets: pets, humans: humans)
                        .navigationTitle(L10n(appLanguage).tr(zh: "成就", en: "Achievements", de: "Erfolge"))
                        .navigationBarTitleDisplayMode(.inline)
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long achievement overview
            } else {
                lockedOasisRoute(route)
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
                onPresentCoconutLog: { subject in
                    dismissCheckInDetailThen {
                        onPresentCoconutLog?(subject)
                    }
                },
                onPresentCoconutShop: { category in
                    dismissCheckInDetailThen {
                        presentOasisSheet(.coconutShop(category))
                    }
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

    private var emptyOasisRoute: some View {
        Color.clear
            .onAppear {
                sheetRoute = nil
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

    private func dismissCheckInDetailThen(_ action: @escaping @MainActor () -> Void) {
        sheetRoute = nil
        OhanaFrameScheduler.runAfterNextFrame(action)
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
