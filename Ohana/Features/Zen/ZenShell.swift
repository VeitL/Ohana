//
//  ZenShell.swift
//  Ohana
//
//  A separate three-tab product shell. It deliberately does not mount the
//  standard Home, Task Center, or plant-room view hierarchy.
//

import SwiftUI

@MainActor
struct ZenShell: View {
    @Binding var snapshot: ZenPresenceSnapshot
    @Binding var oasisSnapshot: ZenOasisSnapshot
    let actions: ZenShellActions

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: ZenTab = .home

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(ZenTab.allCases) { tab in
                Tab(value: tab) {
                    NavigationStack {
                        page(for: tab)
                    }
                } label: {
                    Label(tab.title(l), systemImage: tab.icon)
                }
                .accessibilityIdentifier("zen-tab-\(tab.rawValue)")
                .accessibilityLabel(tab.title(l))
            }
        }
        .tint(Color.goPrimary)
        .tabBarMinimizeBehavior(.onScrollDown)
        .accessibilityIdentifier("zen-native-tab-view")
        .task(id: ownerAutoCheckInKey) {
            await autoCheckInOwnerIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await autoCheckInOwnerIfNeeded() }
        }
    }

    private var ownerAutoCheckInKey: String {
        "\(snapshot.dayKey):\(snapshot.ownerID ?? "none"):\(snapshot.isReady)"
    }

    @ViewBuilder
    private func page(for tab: ZenTab) -> some View {
        switch tab {
        case .home:
            ZenHomeView(
                snapshot: $snapshot,
                actions: actions,
                onOpenOasis: { selectedTab = .oasis }
            )
        case .streak:
            ZenStreakView(
                snapshot: snapshot,
                actions: actions
            )
        case .oasis:
            ZenOasisView(
                snapshot: oasisSnapshot,
                actions: actions
            )
        }
    }

    private func autoCheckInOwnerIfNeeded() async {
        guard scenePhase == .active,
              snapshot.isReady,
              let ownerID = snapshot.ownerID,
              let index = snapshot.subjects.firstIndex(where: {
                  $0.id == ownerID && $0.isOwner
              }),
              !snapshot.subjects[index].checkedToday
        else { return }

        snapshot.subjects[index].checkedToday = true
        snapshot.subjects[index].checkedAt = Date()
        await actions.onAutoCheckInOwner()
    }
}

#if DEBUG
    private extension ZenPresenceSnapshot {
        static let zenPreview = ZenPresenceSnapshot(
            isReady: true,
            subjects: [
                ZenPresenceSubjectDTO(
                    id: "preview-owner",
                    kind: .human,
                    name: "Alex",
                    isOwner: true,
                    checkedToday: true,
                    status: .great,
                    checkedAt: Date(timeIntervalSince1970: 1_752_844_400)
                ),
                ZenPresenceSubjectDTO(
                    id: "preview-pet",
                    kind: .pet,
                    name: "Milo",
                    sortIndex: 1
                ),
                ZenPresenceSubjectDTO(
                    id: "preview-plant",
                    kind: .plant,
                    name: "Monstera",
                    sortIndex: 2,
                    checkedToday: true,
                    status: .okay
                )
            ],
            ownerID: "preview-owner",
            dayKey: "2026-07-18",
            currentStreak: 7,
            longestStreak: 18,
            days: [],
            coconutBalance: 86,
            personalAccessLevel: .personal
        )
    }

    private extension ZenOasisSnapshot {
        static let zenPreview = ZenOasisSnapshot(
            isReady: true,
            level: 4,
            progressToNextLevel: 0.62,
            totalEnergy: 624,
            nextLevelThreshold: 800,
            coconutBalance: 86,
            canInjectEnergy: true,
            starterGiftState: .claimable
        )
    }

    #Preview("Zen · Loaded") {
        ZenShell(
            snapshot: .constant(.zenPreview),
            oasisSnapshot: .constant(.zenPreview),
            actions: .noop
        )
        .ohanaLocalizedEnvironment("zh")
    }

    #Preview("Zen · Loading") {
        ZenShell(
            snapshot: .constant(.empty),
            oasisSnapshot: .constant(.empty),
            actions: .noop
        )
        .ohanaLocalizedEnvironment("de")
    }
#endif
