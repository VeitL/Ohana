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
    @State private var onboardingJourneyEvaluationTask: Task<Void, Never>?
    @State private var coconutWalletBootstrapTask: Task<Void, Never>?
    @State private var onboardingJourneyPhase: OnboardingJourneyPhase = .preOnboarding
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.code
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
                    AppDeferredRouteContent(
                        routeID: route.id,
                        policy: AppPresentationPolicyProvider.policy(for: route)
                    ) {
                        AppRouteDestination(
                            route: route,
                            onPresentCoconutLog: { subject in
                                appRoutes.presentCoconutLog(subject)
                            }
                        )
                    }
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: heroNS))
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            dismissKeyboard()
                        } label: {
                            Label("隐藏键盘", systemImage: "keyboard.chevron.compact.down")
                                .font(OhanaFont.callout(.semibold))
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

            if let starterGiftAmount {
                StarterGiftCeremonyOverlay(
                    appLanguage: appLanguage,
                    amount: starterGiftAmount,
                    onFinish: completeStarterGiftCeremony
                )
                .zIndex(140)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(GoMotion.sheetEnter, value: onboardingJourneyPhase)
        .onAppear {
            AppLifecycleCoordinator.shared.handle(.rootAppeared(scenePhase: scenePhase))
            scheduleCoconutWalletBootstrap()
            reconcileHumanProfileRequirement()
            scheduleOnboardingJourneyEvaluation()
        }
        .onChange(of: hasOnboarded) { _, _ in
            reconcileHumanProfileRequirement()
            scheduleOnboardingJourneyEvaluation()
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
                scheduleOnboardingJourneyEvaluation()
            },
            onHumanSavedFromAddEntity: { human in
                currentActiveHumanId = human.id.uuidString
                createdEntitySignal = HomeCreatedEntitySignal(entityID: human.id)
                scheduleOnboardingJourneyEvaluation()
            },
            onFirstSuccessMomentCompleted: { _ in
                OnboardingJourneyCoordinator.markFirstCareCompleted()
                scheduleOnboardingJourneyEvaluation()
            },
            onHumanDoseTaken: { _ in
                OnboardingJourneyCoordinator.markFirstCareCompleted()
                scheduleOnboardingJourneyEvaluation()
            }
        )
        .onChange(of: currentActiveHumanId) { _, newValue in
            if !newValue.isEmpty {
                appRoutes.dismissSheet(.requiredAccountSwitch)
                reconcileHumanProfileRequirement()
                scheduleOnboardingJourneyEvaluation()
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

    private var starterGiftAmount: Int? {
        guard hasOnboarded,
              case let .starterGiftReadyForCeremony(amount) = onboardingJourneyPhase else {
            return nil
        }
        return amount
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

    private func scheduleCoconutWalletBootstrap() {
        guard coconutWalletBootstrapTask == nil else { return }
        coconutWalletBootstrapTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
            defer { coconutWalletBootstrapTask = nil }
            do {
                try CoconutEconomyBootstrapService.bootstrapIfNeeded(context: modelContext)
            } catch {
                #if DEBUG
                print("❌ [ContentView] coconut wallet bootstrap failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func activateRequiredHuman(_ human: Human) {
        currentActiveHumanId = human.id.uuidString
        scheduleOnboardingJourneyEvaluation()
    }

    private func scheduleOnboardingJourneyEvaluation() {
        onboardingJourneyEvaluationTask?.cancel()
        onboardingJourneyEvaluationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 480) {
            let evaluation = OnboardingJourneyCoordinator.evaluate(
                hasOnboarded: hasOnboarded,
                activeHumanID: currentActiveHumanId.isEmpty ? nil : currentActiveHumanId,
                context: modelContext
            )
            onboardingJourneyPhase = evaluation.phase
            onboardingJourneyEvaluationTask = nil
        }
    }

    private func completeStarterGiftCeremony() {
        OnboardingJourneyCoordinator.markStarterCeremonySeen()
        withAnimation(GoMotion.sheetEnter) {
            onboardingJourneyPhase = .complete
        }
        scheduleOnboardingJourneyEvaluation()
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
