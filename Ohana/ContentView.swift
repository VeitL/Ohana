//
//  ContentView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @StateObject private var appRoutes = AppRouteCoordinator()
    @State private var createdEntitySignal: HomeCreatedEntitySignal?
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @Namespace private var heroNS
    
    var body: some View {
        ZStack {
            if !hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            NavigationStack(path: $appRoutes.path) {
                selectedHomeView
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestination(route: route)
                        .navigationTransition(.zoom(sourceID: route.sourceID, in: heroNS))
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            dismissKeyboard()
                        } label: {
                            Label("隐藏键盘", systemImage: "keyboard.chevron.compact.down")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                    }
                }
            }
            .id(appRoutes.rootIdentity)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if hasOnboarded && !appRoutes.suppressesGlobalWalkBanner {
                GlobalWalkBanner()
                    .zIndex(80)
            }

            CoconutRewardFeedbackOverlay()
                .zIndex(120)
        }
        .onAppear {
            AppLifecycleCoordinator.shared.handle(.rootAppeared(scenePhase: scenePhase))
            reconcileHumanProfileRequirement()
        }
        .onChange(of: hasOnboarded) { _, _ in
            reconcileHumanProfileRequirement()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReturnHomeAfterHumanDeletion)) { notification in
            let outcome = appRoutes.handleNotificationEvent(
                .humanDeleted(
                    requiresReplacementHuman: (notification.userInfo?["requiresReplacementHuman"] as? Bool) == true,
                    requiresAccountSwitch: (notification.userInfo?["requiresAccountSwitch"] as? Bool) == true
                )
            )
            handleRouteNotificationOutcome(outcome)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReminderRouteRequested)) { _ in
            handleRouteNotificationOutcome(
                appRoutes.handleNotificationEvent(.reminderRouteRequested)
            )
        }
        .appRoutePresentationHost(
            coordinator: appRoutes,
            onRequiredHumanSaved: { activateRequiredHuman($0) },
            onPetSavedFromAddEntity: { pet in
                createdEntitySignal = HomeCreatedEntitySignal(entityID: pet.id)
            },
            onHumanSavedFromAddEntity: { human in
                currentActiveHumanId = human.id.uuidString
                createdEntitySignal = HomeCreatedEntitySignal(entityID: human.id)
            }
        )
        .onChange(of: currentActiveHumanId) { _, newValue in
            if !newValue.isEmpty {
                appRoutes.dismissSheet(.requiredAccountSwitch)
                reconcileHumanProfileRequirement()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            AppLifecycleCoordinator.shared.handle(.scenePhaseChanged(newPhase))
            if newPhase == .active {
                reconcileHumanProfileRequirement()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var selectedHomeView: some View {
        VerticalSolidHomeDataContainer(
            onOpenPet: { id, tab in
                appRoutes.openPet(id, initialTab: tab)
            },
            onOpenHuman: { id in
                appRoutes.openHuman(id)
            },
            onOpenPlant: { id in
                appRoutes.openPlant(id)
            },
            createdEntitySignal: createdEntitySignal,
            onPresentAccountSwitcher: {
                appRoutes.presentAccountSwitcher()
            },
            onPresentAddEntity: { type in
                appRoutes.presentAddEntity(type)
            },
            onPresentAppSheet: { route in
                appRoutes.presentSheet(route)
            },
            onPresentCoconutLog: { subject in
                appRoutes.presentCoconutLog(subject)
            },
            onPresentCrewRoster: { mode in
                appRoutes.presentCrewRoster(mode: mode)
            },
            onPresentFunctionMenu: { destination in
                appRoutes.presentFunctionMenu(destination: destination)
            },
            onPresentOasisReward: {
                appRoutes.presentOasisReward()
            },
            onPresentQuickMoment: { petID in
                appRoutes.presentQuickMoment(petID: petID)
            },
            onPresentSettings: {
                appRoutes.presentSettings()
            },
            onPresentStreakDetail: {
                appRoutes.presentStreakDetail()
            },
            onPresentWalk: { petID in
                appRoutes.presentWalk(petID: petID)
            }
        )
    }

    private func reconcileHumanProfileRequirement() {
        let resolution = HumanRequirementCoordinator.resolve(
            hasOnboarded: hasOnboarded,
            currentActiveHumanId: currentActiveHumanId,
            isAccountSwitchPresented: appRoutes.sheet == .requiredAccountSwitch,
            context: modelContext
        )

        switch resolution {
        case .notOnboarded:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        case .needsRequiredProfile:
            appRoutes.presentRequiredHumanProfile()
        case .preserveAccountSwitch:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        case let .activateHuman(id):
            currentActiveHumanId = id
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        case .ready:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        }
    }

    private func activateRequiredHuman(_ human: Human) {
        currentActiveHumanId = human.id.uuidString
    }

    private func handleRouteNotificationOutcome(_ outcome: AppRouteNotificationOutcome) {
        switch outcome {
        case .none:
            break
        case .clearActiveHuman:
            currentActiveHumanId = ""
        case .reconcileHumanRequirement:
            reconcileHumanProfileRequirement()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}

extension Notification.Name {
    static let ohanaReturnHomeAfterHumanDeletion = Notification.Name("ohanaReturnHomeAfterHumanDeletion")
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.make())
}
