//
//  ContentView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    var showsEmbeddedOnboarding = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @StateObject private var appRoutes = AppRouteCoordinator()
    @State private var createdEntitySignal: HomeCreatedEntitySignal?
    @State private var rootAppearHandoffTask: Task<Void, Never>?
    @State private var onboardingJourneyEvaluationTask: Task<Void, Never>?
    @State private var coconutWalletBootstrapTask: Task<Void, Never>?
    @State private var onboardingJourneyPhase: OnboardingJourneyPhase = .preOnboarding
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.code
    @Namespace private var heroNS

    var body: some View {
        ZStack {
            if showsEmbeddedOnboarding, !hasOnboarded {
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
                                Label(
                                    l.tr(zh: "隐藏键盘", en: "Hide keyboard", de: "Tastatur ausblenden"),
                                    systemImage: "keyboard.chevron.compact.down"
                                )
                                .font(OhanaFont.callout(.semibold))
                            }
                        }
                    }
            }
            .id(appRoutes.rootIdentity)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if hasOnboarded, !appRoutes.suppressesGlobalWalkBanner {
                GlobalWalkBanner()
                    .zIndex(80)
            }

            if !Self.isRunningTests {
                CoconutRewardFeedbackOverlay()
                    .zIndex(120)
            }

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
            scheduleRootAppearHandoff()
        }
        .onDisappear {
            rootAppearHandoffTask?.cancel()
            rootAppearHandoffTask = nil
        }
        .onChange(of: hasOnboarded) { _, hasOnboarded in
            guard hasOnboarded else { return }
            scheduleRootAppearHandoff()
        }
        .onReceive(appServices.notificationRoutes.routeEvents) { published in
            handleRouteNotificationOutcome(
                appRoutes.handleNotificationEvent(published.event)
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
                appServices.onboardingJourney.markFirstCareCompleted()
                scheduleOnboardingJourneyEvaluation()
            },
            onHumanDoseTaken: { _ in
                appServices.onboardingJourney.markFirstCareCompleted()
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
            appServices.lifecycle.handle(.scenePhaseChanged(newPhase))
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

    private var l: L10n {
        L10n(appLanguage)
    }

    private func scheduleRootAppearHandoff() {
        rootAppearHandoffTask?.cancel()
        guard hasOnboarded else {
            rootAppearHandoffTask = nil
            return
        }
        let bootstrapDelay = OnboardingHomeJoinHandoffGate.remainingRootBootstrapDelayMilliseconds()
        rootAppearHandoffTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: bootstrapDelay) {
            appServices.lifecycle.handle(.rootAppeared(scenePhase: scenePhase))
            appServices.cloudSync.startAfterFirstRender(modelContainer: modelContext.container)
            scheduleCoconutWalletBootstrap()
            reconcileHumanProfileRequirement()
            scheduleOnboardingJourneyEvaluation()
            OnboardingHomeJoinHandoffGate.consume()
            rootAppearHandoffTask = nil
        }
    }

    private func reconcileHumanProfileRequirement() {
        let resolution = appServices.humanRequirements.resolve(
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
                try appServices.coconutWallet.bootstrapIfNeeded(
                    context: modelContext,
                    projectionManager: appServices.questManager
                )
                EconomyDailyBudgetStore.pruneOldUsageEvents(context: modelContext)
            } catch {
                #if DEBUG
                    OhanaLog.error("[ContentView] coconut wallet bootstrap failed: \(error.localizedDescription)", category: "Startup")
                #endif
            }
        }
    }

    private func activateRequiredHuman(_ human: Human) {
        currentActiveHumanId = human.id.uuidString
        createdEntitySignal = HomeCreatedEntitySignal(entityID: human.id)
        scheduleOnboardingJourneyEvaluation()
    }

    private func scheduleOnboardingJourneyEvaluation() {
        onboardingJourneyEvaluationTask?.cancel()
        onboardingJourneyEvaluationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 480) {
            let evaluation = appServices.onboardingJourney.evaluate(
                hasOnboarded: hasOnboarded,
                activeHumanID: currentActiveHumanId.isEmpty ? nil : currentActiveHumanId,
                context: modelContext,
                projectionManager: appServices.questManager
            )
            onboardingJourneyPhase = evaluation.phase
            onboardingJourneyEvaluationTask = nil
        }
    }

    private func completeStarterGiftCeremony() {
        appServices.onboardingJourney.markStarterCeremonySeen()
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

private extension ContentView {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.make())
}
