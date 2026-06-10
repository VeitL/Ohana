//
//  FocusHomeRouteInlineHosts.swift
//  Ohana
//
//  Inline route hosts used by FocusHomeRouteSheetModifier.
//

import SwiftUI

struct HomeSettingsInlineHost: View {
    let homePets: [Pet]
    let homeHumans: [Human]
    let homeElectronicPets: [OasisElectronicPet]
    let onClose: () -> Void

    var body: some View {
        OhanaInlinePageRouteHost(routeID: "home-settings", onClose: onClose) { requestClose in
            SettingsView(
                homePets: homePets,
                homeHumans: homeHumans,
                homeElectronicPets: homeElectronicPets,
                onClose: requestClose
            )
        }
    }
}

struct HomeCrewRosterInlineHost: View {
    let initialMode: CrewRosterMode
    let onClose: () -> Void
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onPresentCoconutLog: (CoconutLogSubject?) -> Void = { _ in }

    var body: some View {
        OhanaInlinePageRouteHost(routeID: "home-crew-roster-\(initialMode.rawValue)", onClose: onClose) { requestClose in
            HomeCrewRosterInlineContent(
                initialMode: initialMode,
                onClose: requestClose,
                onSelectPet: onSelectPet,
                onSelectHuman: onSelectHuman,
                onPresentCoconutLog: onPresentCoconutLog
            )
        }
    }
}

private struct HomeCrewRosterInlineContent: View {
    let initialMode: CrewRosterMode
    let onClose: () -> Void
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @Environment(\.ohanaInlinePageSafeAreaInsets) private var inlineSafeAreaInsets

    var body: some View {
        CrewRosterOverlayRouteContainer(
            initialMode: initialMode,
            onSelectPet: onSelectPet,
            onSelectHuman: onSelectHuman,
            onClose: onClose,
            safeTopInset: inlineSafeAreaInsets.top,
            safeBottomInset: inlineSafeAreaInsets.bottom,
            onPresentCoconutLog: onPresentCoconutLog
        )
    }
}

struct HomeCoconutLogInlineHost: View {
    let subject: CoconutLogSubject?
    let onClose: () -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    var body: some View {
        OhanaInlinePageRouteHost(routeID: "home-coconut-log-\(subject?.id ?? "all")", onClose: onClose) { requestClose in
            HomeCoconutLogInlineContent(
                subject: subject,
                onClose: requestClose,
                historyContentDelayMilliseconds: historyContentDelayMilliseconds
            )
        }
    }

    private var allowsMotion: Bool {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion
    }

    private var historyContentDelayMilliseconds: UInt64 {
        allowsMotion ? 220 : 0
    }
}

private struct HomeCoconutLogInlineContent: View {
    let subject: CoconutLogSubject?
    let onClose: () -> Void
    let historyContentDelayMilliseconds: UInt64
    @Environment(\.ohanaInlinePageSafeAreaInsets) private var inlineSafeAreaInsets

    var body: some View {
        CoconutLogView(
            subject: subject,
            onClose: onClose,
            safeTopInset: inlineSafeAreaInsets.top,
            safeBottomInset: inlineSafeAreaInsets.bottom,
            historyContentDelayMilliseconds: historyContentDelayMilliseconds
        )
    }
}

