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
    let profileTransitionNamespace: Namespace.ID

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: ZenTab = .home
    @State private var requestedAutoCheckInToastSubjectID: String?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(ZenTab.allCases) { tab in
                Tab(value: tab) {
                    NavigationStack {
                        page(for: tab)
                            .toolbar { zenToolbar }
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
                requestedAutoCheckInToastSubjectID: $requestedAutoCheckInToastSubjectID,
                actions: actions,
                profileTransitionNamespace: profileTransitionNamespace
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

    @ToolbarContentBuilder
    private var zenToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            CoconutBalanceCapsule(
                balance: snapshot.coconutBalance,
                showsDeltaAnimation: true,
                deltaAnimationContext: "zen-\(selectedTab.rawValue)",
                onTap: actions.onOpenCoconutLog
            )
            .accessibilityLabel(l.tr(
                zh: "椰子余额 \(snapshot.coconutBalance)，打开椰子记录",
                en: "Coconut balance \(snapshot.coconutBalance), open coconut history",
                de: "Kokosnuss-Guthaben \(snapshot.coconutBalance), Verlauf öffnen",
                es: "Saldo de cocos \(snapshot.coconutBalance), abrir historial",
                pt: "Saldo de cocos \(snapshot.coconutBalance), abrir histórico",
                fr: "Solde de noix de coco : \(snapshot.coconutBalance), ouvrir l’historique",
                ja: "ココナッツ残高 \(snapshot.coconutBalance)、履歴を開く",
                ko: "코코넛 잔액 \(snapshot.coconutBalance), 기록 열기",
                it: "Saldo noci di cocco \(snapshot.coconutBalance), apri la cronologia"
            ))
            .accessibilityIdentifier("zen-toolbar-coconut-log")

            Button(action: actions.onOpenMembers) {
                Image(systemName: "person.2.fill").accessibilityHidden(true)
            }
            .accessibilityLabel(l.tr(
                zh: "成员",
                en: "Members",
                de: "Mitglieder",
                es: "Miembros",
                pt: "Membros",
                fr: "Membres",
                ja: "メンバー",
                ko: "구성원",
                it: "Membri"
            ))
            .accessibilityIdentifier("zen-toolbar-members")

            Button(action: actions.onOpenSettings) {
                Image(systemName: "gearshape.fill").accessibilityHidden(true)
            }
            .accessibilityLabel(l.tr(
                zh: "设置",
                en: "Settings",
                de: "Einstellungen",
                es: "Ajustes",
                pt: "Ajustes",
                fr: "Réglages",
                ja: "設定",
                ko: "설정",
                it: "Impostazioni"
            ))
            .accessibilityIdentifier("zen-toolbar-settings")
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
        let didCreateCheckIn = await actions.onAutoCheckInOwner()
        guard didCreateCheckIn else { return }
        selectedTab = .home
        requestedAutoCheckInToastSubjectID = ownerID
    }
}

#if DEBUG
    private extension ZenPresenceSnapshot {
        static let zenPreview = ZenPresenceSnapshot(
            isReady: true,
            subjects: [
                ZenPresenceSubjectDTO(
                    id: "00000000-0000-0000-0000-000000000001",
                    kind: .human,
                    name: "Alex",
                    isOwner: true,
                    checkedToday: true,
                    status: .great,
                    checkedAt: Date(timeIntervalSince1970: 1_752_844_400)
                ),
                ZenPresenceSubjectDTO(
                    id: "00000000-0000-0000-0000-000000000002",
                    kind: .pet,
                    name: "Milo",
                    sortIndex: 1
                ),
                ZenPresenceSubjectDTO(
                    id: "00000000-0000-0000-0000-000000000003",
                    kind: .plant,
                    name: "Monstera",
                    sortIndex: 2,
                    checkedToday: true,
                    status: .okay
                )
            ],
            ownerID: "00000000-0000-0000-0000-000000000001",
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

    private struct ZenShellPreviewHost: View {
        let snapshot: ZenPresenceSnapshot
        let oasisSnapshot: ZenOasisSnapshot
        let languageCode: String
        @Namespace private var profileTransitionNamespace

        var body: some View {
            ZenShell(
                snapshot: .constant(snapshot),
                oasisSnapshot: .constant(oasisSnapshot),
                actions: .noop,
                profileTransitionNamespace: profileTransitionNamespace
            )
            .ohanaLocalizedEnvironment(languageCode)
        }
    }

    #Preview("Zen · Loaded") {
        ZenShellPreviewHost(
            snapshot: .zenPreview,
            oasisSnapshot: .zenPreview,
            languageCode: "zh"
        )
    }

    #Preview("Zen · Loading") {
        ZenShellPreviewHost(
            snapshot: .empty,
            oasisSnapshot: .empty,
            languageCode: "de"
        )
    }
#endif
