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
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

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
            CoconutShopRouteContainer(initialCategory: category)
                .ohanaSheetPagePresentation() // ui-v4: allow long shop overview
        case .gacha:
            GachaRouteContainer(onPresentCoconutLog: onPresentCoconutLog)
                .ohanaSheetPagePresentation() // ui-v4: allow long blind-box overview
        case .checkInDetail:
            DailyStreakDetailRouteContainer(
                onClose: { sheetRoute = nil },
                onPresentCoconutLog: onPresentCoconutLog,
                onPresentCoconutShop: { category in
                    sheetRoute = .coconutShop(category)
                }
            )
                .ohanaSheetPagePresentation() // ui-v4: allow long streak overview
        case .critterCodex:
            OasisCritterCodexRouteContainer(
                mode: .codex,
                onPresentCoconutLog: onPresentCoconutLog ?? { _ in }
            )
                .ohanaSheetPagePresentation() // ui-v4: allow long critter codex overview
        }
    }
}
