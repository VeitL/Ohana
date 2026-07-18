//
//  ContentView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Combine
import SwiftData
import SwiftUI

struct ContentView: View {
    var showsEmbeddedOnboarding = true
    var onboardingFirstPetID: String?
    var routeLanguageCode: String = AppLanguage.code
    var requiredPetHomeSnapshotRefreshRequest = 0
    var onRequiredPetHomeSnapshotReady: ((UUID) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @StateObject private var appRoutes = AppRouteCoordinator()
    @State private var createdEntitySignal: HomeCreatedEntitySignal?
    @State private var rootAppearHandoffTask: Task<Void, Never>?
    @State private var onboardingJourneyEvaluationTask: Task<Void, Never>?
    @State private var activeHumanReactionTask: Task<Void, Never>?
    @State private var onboardingCreatedEntitySignalTask: Task<Void, Never>?
    @State private var uiTestRouteTask: Task<Void, Never>?
    @State private var uiTestEconomyStateSeedTask: Task<Void, Never>?
    @State private var onboardingJourneyPhase: OnboardingJourneyPhase = .preOnboarding
    @State private var embeddedOnboardingFirstPetID: String?
    @State private var handledOnboardingFirstPetID: String?
    @State private var signaledOnboardingFirstPetID: String?
    @State private var handledUITestHumanProfileRouteName: String?
    @State private var homeCardStateResetToken = UUID()
    @State private var homeSurfaceLanguage = AppLanguage.code
    @State private var homeSurfaceLanguageThawTask: Task<Void, Never>?
    @State private var routeSurfaceLanguage = AppLanguage.code
    @State private var routeSurfaceLanguageThawTask: Task<Void, Never>?
    @State private var pendingStarterGiftHomeEntityID: UUID?
    @State private var isStarterGiftHomeSnapshotReady = false
    @State private var homeSnapshotCoconutBalance: Int?
    @State private var pendingStarterGiftExpectedCoconutBalance: Int?
    @State private var isClaimingStarterGift = false
    @State private var starterGiftClaimErrorMessage: String?
    @State private var homeProjectionRefreshGeneration = 0
    @State private var starterGiftHomePreparationRecoveryTask: Task<Void, Never>?
    @State private var starterGiftHomePreparationErrorMessage: String?
    @State private var starterGiftProjectionRecoveryTask: Task<Void, Never>?
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage(StarterGiftStorageKey.ceremonyRequested) private var starterGiftCeremonyRequested = false
    @Namespace private var heroNS

    var body: some View {
        ZStack {
            if showsEmbeddedOnboarding, !hasOnboarded {
                OnboardingView(
                    onFirstHumanSaved: { humanID in
                        currentActiveHumanId = humanID.uuidString
                        appServices.onboardingJourney.markFirstHumanCreated(humanID)
                        scheduleCreatedEntitySignalAfterHomeHandoff(humanID)
                    },
                    onPetDeferred: {
                        appServices.onboardingJourney.markPetDeferred()
                    },
                    onPetCreationStarted: {
                        appServices.onboardingJourney.markPetCreationStarted()
                    },
                    onFirstPetRecovered: { petID in
                        onboardingFirstPetDidPersist(petID)
                    },
                    onFirstPetSaved: { pet in
                        onboardingFirstPetDidPersist(pet.id)
                    }
                )
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
                                },
                                onPresentTaskCenter: { context in
                                    appRoutes.presentTaskCenter(context: context)
                                }
                            )
                            .globalTaskCenterToolbar {
                                appRoutes.presentTaskCenter(context: route.taskCenterContext)
                            }
                        }
                        .navigationTransition(.zoom(sourceID: route.sourceID, in: heroNS))
                    }
            }
            .id(appRoutes.rootIdentity)
            .homeSurfaceLanguage(homeSurfaceLanguage)
            .accessibilityHidden(
                appRoutes.sheet != nil ||
                    appRoutes.fullScreen != nil ||
                    appRoutes.overlay != nil ||
                    starterGiftHomePreparationErrorMessage != nil ||
                    starterGiftAmount != nil
            )

            if hasOnboarded, !appRoutes.suppressesGlobalWalkBanner {
                GlobalWalkBanner()
                    .homeSurfaceLanguage(homeSurfaceLanguage)
                    .accessibilityHidden(
                        appRoutes.sheet != nil ||
                        appRoutes.fullScreen != nil ||
                        appRoutes.overlay != nil ||
                        starterGiftHomePreparationErrorMessage != nil ||
                        starterGiftAmount != nil
                    )
                    .zIndex(80)
            }

            GlobalCoconutRewardFeedbackLayer()
                .accessibilityHidden(
                    starterGiftHomePreparationErrorMessage != nil || starterGiftAmount != nil
                )
                .zIndex(120)

            if let starterGiftHomePreparationErrorMessage,
               pendingStarterGiftHomeEntityID != nil {
                StarterGiftHomePreparationRecoveryOverlay(
                    appLanguage: routeLanguageCode,
                    message: starterGiftHomePreparationErrorMessage,
                    onRetry: retryStarterGiftHomePreparation
                )
                .zIndex(135)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if let starterGiftAmount {
                StarterGiftCeremonyOverlay(
                    appLanguage: routeLanguageCode,
                    amount: starterGiftAmount,
                    isClaiming: isClaimingStarterGift,
                    isClaimCommitted: pendingStarterGiftExpectedCoconutBalance != nil,
                    errorMessage: starterGiftClaimErrorMessage,
                    onFinish: completeStarterGiftCeremony
                )
                .zIndex(140)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(GoMotion.sheetEnter, value: onboardingJourneyPhase)
        .onAppear {
            restoreLegacyStarterGiftCeremonyRequestIfNeeded()
            synchronizeHomeSurfaceLanguageIfAllowed(routeLanguageCode)
            synchronizeRouteSurfaceLanguageIfAllowed(routeLanguageCode)
            scheduleRootAppearHandoff()
            applyOnboardingFirstPetIDIfNeeded()
            scheduleUITestHumanProfileRouteIfNeeded()
            resumeStarterGiftHomePreparationRecoveryIfNeeded()
        }
        .onDisappear {
            rootAppearHandoffTask?.cancel()
            rootAppearHandoffTask = nil
            onboardingJourneyEvaluationTask?.cancel()
            onboardingJourneyEvaluationTask = nil
            activeHumanReactionTask?.cancel()
            activeHumanReactionTask = nil
            onboardingCreatedEntitySignalTask?.cancel()
            onboardingCreatedEntitySignalTask = nil
            uiTestRouteTask?.cancel()
            uiTestRouteTask = nil
            uiTestEconomyStateSeedTask?.cancel()
            uiTestEconomyStateSeedTask = nil
            homeSurfaceLanguageThawTask?.cancel()
            homeSurfaceLanguageThawTask = nil
            routeSurfaceLanguageThawTask?.cancel()
            routeSurfaceLanguageThawTask = nil
            starterGiftProjectionRecoveryTask?.cancel()
            starterGiftProjectionRecoveryTask = nil
            starterGiftHomePreparationRecoveryTask?.cancel()
            starterGiftHomePreparationRecoveryTask = nil
            if isClaimingStarterGift, pendingStarterGiftExpectedCoconutBalance != nil {
                isClaimingStarterGift = false
                starterGiftClaimErrorMessage = starterGiftProjectionRefreshErrorMessage
            }
        }
        .onChange(of: routeLanguageCode) { _, newValue in
            synchronizeHomeSurfaceLanguageIfAllowed(newValue)
            synchronizeRouteSurfaceLanguageIfAllowed(newValue)
        }
        .onChange(of: appRoutes.sheet) { _, newValue in
            guard newValue != .settings else {
                homeSurfaceLanguageThawTask?.cancel()
                homeSurfaceLanguageThawTask = nil
                routeSurfaceLanguageThawTask?.cancel()
                routeSurfaceLanguageThawTask = nil
                return
            }
            thawHomeSurfaceLanguageAfterSheetDismissal()
            thawRouteSurfaceLanguageAfterSheetDismissal()
            if newValue == nil {
                scheduleOnboardingJourneyEvaluation(delayMilliseconds: 180)
            }
        }
        .onChange(of: hasOnboarded) { _, hasOnboarded in
            guard hasOnboarded else { return }
            scheduleRootAppearHandoff()
            applyOnboardingFirstPetIDIfNeeded()
            scheduleUITestHumanProfileRouteIfNeeded()
            scheduleUITestEconomyStateSeedIfNeeded()
        }
        .onChange(of: onboardingFirstPetID) { _, _ in
            applyOnboardingFirstPetIDIfNeeded()
        }
        .onChange(of: requiredPetHomeSnapshotRefreshRequest) { previous, current in
            guard previous != current else { return }
            requestStarterGiftHomeProjectionRefresh()
        }
        .onChange(of: embeddedOnboardingFirstPetID) { _, _ in
            applyOnboardingFirstPetIDIfNeeded()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            guard hasOnboarded, onboardingJourneyNeedsObservation else { return }
            scheduleOnboardingJourneyEvaluation(delayMilliseconds: 180)
        }
        .onReceive(appServices.notificationRoutes.routeEvents) { published in
            appServices.notificationRoutes.acknowledgeRouteEvent(id: published.id)
            scheduleHomeCardStateResetIfNeeded(for: published.event)
            handleRouteNotificationOutcome(
                appRoutes.handleNotificationEvent(published.event)
            )
        }
        .appRoutePresentationHost(
            coordinator: appRoutes,
            onRequiredHumanSaved: { activateRequiredHuman($0) },
            onPetSavedFromAddEntity: { pet in
                _ = prepareStarterGiftHomeHandoffIfNeeded(pet.id)
                scheduleCreatedEntitySignalAfterHomeHandoff(
                    pet.id,
                    destinationTab: .home
                )
                scheduleUITestEconomyStateSeedIfNeeded()
                scheduleOnboardingJourneyEvaluationAfterHomeHandoff()
            },
            onHumanSavedFromAddEntity: { human in
                currentActiveHumanId = ActiveHumanSelectionPolicy.activeHumanIdAfterCreatingHuman(
                    currentHumanIdRaw: currentActiveHumanId,
                    createdHumanId: human.id
                )
                scheduleCreatedEntitySignalAfterHomeHandoff(human.id)
                scheduleUITestEconomyStateSeedIfNeeded()
                scheduleOnboardingJourneyEvaluationAfterHomeHandoff(activeHumanIDOverride: human.id.uuidString)
            },
            onRequestStarterGiftClaim: requestStarterGiftClaimFromTaskCenter,
            onFirstSuccessMomentCompleted: { _ in },
            onHumanDoseTaken: { _ in },
            routeLanguageCode: routeSurfaceLanguage
        )
        .onChange(of: currentActiveHumanId) { _, newValue in
            scheduleActiveHumanReaction(newValue)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reconcileHumanProfileRequirement()
            }
        }
    }

    private var isSettingsSheetPresented: Bool {
        appRoutes.sheet == .settings
    }

    private func synchronizeHomeSurfaceLanguageIfAllowed(_ rawLanguage: String) {
        guard !isSettingsSheetPresented else { return }
        setHomeSurfaceLanguage(rawLanguage)
    }

    private func synchronizeRouteSurfaceLanguageIfAllowed(_ rawLanguage: String) {
        guard !isSettingsSheetPresented else { return }
        setRouteSurfaceLanguage(rawLanguage)
    }

    private func thawHomeSurfaceLanguageAfterSheetDismissal() {
        homeSurfaceLanguageThawTask?.cancel()
        let language = routeLanguageCode
        guard AppLanguage.normalize(homeSurfaceLanguage) != AppLanguage.normalize(language) else {
            homeSurfaceLanguageThawTask = nil
            return
        }
        homeSurfaceLanguageThawTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
            setHomeSurfaceLanguage(language)
            homeSurfaceLanguageThawTask = nil
        }
    }

    private func thawRouteSurfaceLanguageAfterSheetDismissal() {
        routeSurfaceLanguageThawTask?.cancel()
        let language = routeLanguageCode
        guard AppLanguage.normalize(routeSurfaceLanguage) != AppLanguage.normalize(language) else {
            routeSurfaceLanguageThawTask = nil
            return
        }
        routeSurfaceLanguageThawTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
            setRouteSurfaceLanguage(language)
            routeSurfaceLanguageThawTask = nil
        }
    }

    private func setHomeSurfaceLanguage(_ rawLanguage: String) {
        let normalized = AppLanguage.normalize(rawLanguage)
        guard homeSurfaceLanguage != normalized else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            homeSurfaceLanguage = normalized
        }
    }

    private func setRouteSurfaceLanguage(_ rawLanguage: String) {
        let normalized = AppLanguage.normalize(rawLanguage)
        guard routeSurfaceLanguage != normalized else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            routeSurfaceLanguage = normalized
        }
    }

    @ViewBuilder
    private var selectedHomeView: some View {
        let requiredReadyEntityID = pendingStarterGiftHomeEntityID
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
            onCreatedEntitySignalHandled: { handledSignal in
                guard createdEntitySignal == handledSignal else { return }
                createdEntitySignal = nil
            },
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
            onPresentHumanWeightQuick: { humanID in
                appRoutes.presentHumanWeightQuick(humanID: humanID)
            },
            onPresentOasisReward: {
                appRoutes.presentOasisReward()
            },
            onPresentPetWeightQuick: { petID in
                appRoutes.presentPetWeightQuick(petID: petID)
            },
            onPresentQuickMoment: { petID in
                appRoutes.presentQuickMoment(petID: petID)
            },
            onRequestStarterGiftClaim: requestStarterGiftClaimFromTaskCenter,
            onPresentSettings: {
                appRoutes.presentSettings()
            },
            onPresentStreakDetail: {
                appRoutes.presentStreakDetail()
            },
            onPresentWalk: { petID in
                appRoutes.presentWalk(petID: petID)
            },
            cardStateResetToken: homeCardStateResetToken,
            isHomeSurfaceVisible: isHomeSurfaceVisible,
            requiredReadyEntityID: requiredReadyEntityID,
            forcedRefreshGeneration: homeProjectionRefreshGeneration,
            onHomeSnapshotReadinessChange: { isReady in
                if pendingStarterGiftHomeEntityID == requiredReadyEntityID {
                    isStarterGiftHomeSnapshotReady = isReady
                    if isReady {
                        starterGiftHomePreparationRecoveryTask?.cancel()
                        starterGiftHomePreparationRecoveryTask = nil
                        starterGiftHomePreparationErrorMessage = nil
                    }
                }
                if isReady, let requiredReadyEntityID {
                    onRequiredPetHomeSnapshotReady?(requiredReadyEntityID)
                }
            },
            onHomeCoconutBalanceChange: { balance in
                homeSnapshotCoconutBalance = balance
                finishStarterGiftCeremonyIfProjectionIsReady()
            }
        )
    }

    /// Home remains mounted behind global presentations. Pass the actual route
    /// visibility down so its read-model work is suspended instead of merely
    /// hiding the resulting updates behind a sheet.
    private var isHomeSurfaceVisible: Bool {
        (!showsEmbeddedOnboarding || hasOnboarded) &&
            appRoutes.path.isEmpty &&
            appRoutes.sheet == nil &&
            appRoutes.fullScreen == nil &&
            appRoutes.overlay == nil
    }

    private var starterGiftAmount: Int? {
        guard hasOnboarded,
              starterGiftCeremonyRequested,
              isStarterGiftHomeSnapshotReady,
              case let .starterGiftReady(amount) = onboardingJourneyPhase else {
            return nil
        }
        return amount
    }

    private func scheduleRootAppearHandoff() {
        rootAppearHandoffTask?.cancel()
        guard hasOnboarded else {
            rootAppearHandoffTask = nil
            return
        }
        let bootstrapDelay = OnboardingHomeJoinHandoffGate.remainingRootBootstrapDelayMilliseconds()
        rootAppearHandoffTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: bootstrapDelay) {
            scheduleUITestEconomyStateSeedIfNeeded(delayMilliseconds: 120)
            reconcileHumanProfileRequirement()
            scheduleOnboardingJourneyEvaluationAfterHomeHandoff()
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
        case .readyWithoutHuman, .ready:
            appRoutes.dismissFullScreen(.requiredHumanProfile)
        }
    }

    private func activateRequiredHuman(_ human: Human) {
        currentActiveHumanId = human.id.uuidString
        scheduleCreatedEntitySignalAfterHomeHandoff(human.id)
        scheduleUITestEconomyStateSeedIfNeeded()
        scheduleOnboardingJourneyEvaluationAfterHomeHandoff(activeHumanIDOverride: human.id.uuidString)
    }

    private func scheduleOnboardingJourneyEvaluation(
        delayMilliseconds: UInt64 = 480,
        activeHumanIDOverride: String? = nil
    ) {
        onboardingJourneyEvaluationTask?.cancel()
        onboardingJourneyEvaluationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            let activeHumanID = resolvedOnboardingEvaluationActiveHumanID(override: activeHumanIDOverride)
            if currentActiveHumanId.isEmpty, let activeHumanID {
                currentActiveHumanId = activeHumanID
            }
            let evaluation = appServices.onboardingJourney.evaluate(
                hasOnboarded: hasOnboarded,
                activeHumanID: activeHumanID,
                context: modelContext,
                projectionManager: appServices.questManager
            )
            applyOnboardingJourneyEvaluation(evaluation)
            onboardingJourneyEvaluationTask = nil
        }
    }

    private func applyOnboardingJourneyEvaluation(_ evaluation: OnboardingJourneyEvaluation) {
        onboardingJourneyPhase = evaluation.phase
        if case .starterGiftReady = evaluation.phase,
           pendingStarterGiftHomeEntityID == nil,
           let firstPetIDRaw = appServices.onboardingJourney.interruptedOnboardingFirstPetID(context: modelContext),
           let firstPetID = UUID(uuidString: firstPetIDRaw) {
            prepareRequiredHomeSnapshot(for: firstPetID)
        }
    }

    private func resolvedOnboardingEvaluationActiveHumanID(override: String?) -> String? {
        if let override, !override.isEmpty {
            return override
        }
        if !currentActiveHumanId.isEmpty {
            return currentActiveHumanId
        }
        guard appRoutes.sheet != .requiredAccountSwitch else { return nil }
        return appServices.onboardingJourney.interruptedOnboardingPrimaryHumanID(context: modelContext)
    }

    private func scheduleOnboardingJourneyEvaluationForActiveHumanChange(_ humanID: String) {
        guard hasOnboarded else { return }
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds(
            defaultDelayMilliseconds: 480
        )
        if handoffDelay > 480 {
            scheduleOnboardingJourneyEvaluation(delayMilliseconds: handoffDelay, activeHumanIDOverride: humanID)
        } else {
            scheduleOnboardingJourneyEvaluation()
        }
    }

    private func scheduleActiveHumanReaction(_ humanID: String) {
        activeHumanReactionTask?.cancel()
        guard !humanID.isEmpty else {
            activeHumanReactionTask = nil
            return
        }
        activeHumanReactionTask = OhanaFrameScheduler.runAfterNextFrame {
            guard currentActiveHumanId == humanID else { return }
            appRoutes.dismissSheet(.requiredAccountSwitch)
            reconcileHumanProfileRequirement()
            scheduleOnboardingJourneyEvaluationForActiveHumanChange(humanID)
            scheduleUITestEconomyStateSeedIfNeeded()
            activeHumanReactionTask = nil
        }
    }

    private func applyOnboardingFirstPetIDIfNeeded() {
        guard let petID = onboardingFirstPetID ?? embeddedOnboardingFirstPetID,
              !petID.isEmpty else { return }
        if let id = UUID(uuidString: petID),
           signaledOnboardingFirstPetID != petID {
            signaledOnboardingFirstPetID = petID
            prepareRequiredHomeSnapshot(for: id)
            _ = prepareStarterGiftHomeHandoffIfNeeded(id)
            scheduleOnboardingCreatedEntitySignal(id, destinationTab: .home)
        }
        guard hasOnboarded, handledOnboardingFirstPetID != petID else { return }
        handledOnboardingFirstPetID = petID
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds(
            defaultDelayMilliseconds: 480
        )
        scheduleOnboardingJourneyEvaluation(delayMilliseconds: handoffDelay)
    }

    private func onboardingFirstPetDidPersist(_ petID: UUID) {
        embeddedOnboardingFirstPetID = petID.uuidString
        applyOnboardingFirstPetIDIfNeeded()
    }

    private var onboardingJourneyNeedsObservation: Bool {
        switch onboardingJourneyPhase {
        case .preOnboarding, .needsHumanName, .petChoice, .petCreation, .awaitingPet:
            true
        case .starterGiftReady, .complete, .existingUser:
            false
        }
    }

    private func scheduleOnboardingJourneyEvaluationAfterHomeHandoff(activeHumanIDOverride: String? = nil) {
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds(
            defaultDelayMilliseconds: 480
        )
        scheduleOnboardingJourneyEvaluation(delayMilliseconds: handoffDelay, activeHumanIDOverride: activeHumanIDOverride)
    }

    private func scheduleCreatedEntitySignalAfterHomeHandoff(
        _ id: UUID,
        destinationTab: VerticalSolidHomeTab? = nil,
        defaultDelayMilliseconds: UInt64 = 0
    ) {
        onboardingCreatedEntitySignalTask?.cancel()
        let delay = OnboardingHomeJoinHandoffGate.remainingHomeVisualEffectDelayMilliseconds(
            defaultDelayMilliseconds: defaultDelayMilliseconds
        )
        onboardingCreatedEntitySignalTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delay) {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                createdEntitySignal = HomeCreatedEntitySignal(
                    entityID: id,
                    destinationTab: destinationTab
                )
            }
            onboardingCreatedEntitySignalTask = nil
        }
    }

    private func scheduleOnboardingCreatedEntitySignal(
        _ id: UUID,
        destinationTab: VerticalSolidHomeTab? = nil
    ) {
        scheduleCreatedEntitySignalAfterHomeHandoff(
            id,
            destinationTab: destinationTab,
            defaultDelayMilliseconds: 240
        )
    }

    private func scheduleUITestEconomyStateSeedIfNeeded(delayMilliseconds: UInt64 = 180) {
        #if DEBUG
            guard OhanaUITestLaunchOptions.requestedCoconutBalanceSeedAmount != nil
                || OhanaUITestLaunchOptions.requestsRewardTierUnlock
                || OhanaUITestLaunchOptions.requestsGrowthLoopUnlock
                || OhanaUITestLaunchOptions.requestsEconomyBudgetReset else {
                return
            }
            uiTestEconomyStateSeedTask?.cancel()
            uiTestEconomyStateSeedTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
                let activeHumanID = UITestEconomyStateSeeder.applyIfRequested(
                    modelContext: modelContext,
                    services: appServices,
                    currentActiveHumanId: currentActiveHumanId,
                    revisionNote: "content.uiTestEconomySeed"
                )
                if currentActiveHumanId.isEmpty,
                   appRoutes.sheet != .requiredAccountSwitch,
                   let activeHumanID {
                    currentActiveHumanId = activeHumanID.uuidString
                }
                uiTestEconomyStateSeedTask = nil
            }
        #endif
    }
}

private extension ContentView {
    private func restoreLegacyStarterGiftCeremonyRequestIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: StarterGiftStorageKey.ceremonyRequested) == nil,
              defaults.bool(forKey: StarterGiftStorageKey.claimed),
              !defaults.bool(forKey: StarterGiftStorageKey.ceremonySeen) else { return }
        starterGiftCeremonyRequested = true
    }

    private func requestStarterGiftClaimFromTaskCenter() {
        let evaluation = appServices.onboardingJourney.evaluate(
            hasOnboarded: hasOnboarded,
            activeHumanID: resolvedOnboardingEvaluationActiveHumanID(override: nil),
            context: modelContext,
            projectionManager: appServices.questManager
        )
        guard case .starterGiftReady = evaluation.phase else { return }

        starterGiftClaimErrorMessage = nil
        starterGiftCeremonyRequested = true
        applyOnboardingJourneyEvaluation(evaluation)

        if pendingStarterGiftHomeEntityID == nil,
           let petIDRaw = appServices.onboardingJourney.interruptedOnboardingFirstPetID(context: modelContext),
           let petID = UUID(uuidString: petIDRaw) {
            prepareRequiredHomeSnapshot(for: petID)
        }
    }

    private func completeStarterGiftCeremony() {
        guard !isClaimingStarterGift else { return }
        isClaimingStarterGift = true
        starterGiftClaimErrorMessage = nil

        if pendingStarterGiftExpectedCoconutBalance != nil {
            requestStarterGiftHomeProjectionRefresh()
            finishStarterGiftCeremonyIfProjectionIsReady()
            if isClaimingStarterGift {
                scheduleStarterGiftProjectionRecovery()
            }
            return
        }

        let visibleBalanceBeforeRequest = homeSnapshotCoconutBalance ?? 0
        let result = appServices.onboardingJourney.claimStarterGift(
            activeHumanID: resolvedOnboardingEvaluationActiveHumanID(override: nil),
            context: modelContext,
            projectionManager: appServices.questManager
        )

        guard result.completesClaimRequest else {
            isClaimingStarterGift = false
            starterGiftClaimErrorMessage = L10n(routeLanguageCode).tr(
                zh: "领取失败，请重试。你的宠物和进度都已保存。",
                en: "Couldn’t claim the gift. Try again; your pet and progress are saved.",
                de: "Geschenk konnte nicht abgeholt werden. Versuche es erneut; Tier und Fortschritt sind gespeichert."
            )
            return
        }

        pendingStarterGiftExpectedCoconutBalance = StarterGiftHomeProjectionPolicy.expectedVisibleBalance(
            after: result,
            visibleBalanceBeforeRequest: visibleBalanceBeforeRequest,
            existingExpectation: pendingStarterGiftExpectedCoconutBalance
        )
        requestStarterGiftHomeProjectionRefresh()
        finishStarterGiftCeremonyIfProjectionIsReady()
        if isClaimingStarterGift {
            scheduleStarterGiftProjectionRecovery()
        }
    }

    private func finishStarterGiftCeremonyIfProjectionIsReady() {
        guard isClaimingStarterGift,
              let expectedBalance = pendingStarterGiftExpectedCoconutBalance,
              let homeSnapshotCoconutBalance,
              homeSnapshotCoconutBalance >= expectedBalance else { return }

        starterGiftProjectionRecoveryTask?.cancel()
        starterGiftProjectionRecoveryTask = nil
        appServices.onboardingJourney.markStarterCeremonySeen()
        starterGiftCeremonyRequested = false
        pendingStarterGiftHomeEntityID = nil
        pendingStarterGiftExpectedCoconutBalance = nil
        isClaimingStarterGift = false
        starterGiftClaimErrorMessage = nil
        withAnimation(GoMotion.sheetEnter) {
            onboardingJourneyPhase = .complete
        }
        scheduleOnboardingJourneyEvaluation()
    }

    private func requestStarterGiftHomeProjectionRefresh() {
        homeProjectionRefreshGeneration &+= 1
    }

    private func scheduleStarterGiftProjectionRecovery() {
        starterGiftProjectionRecoveryTask?.cancel()
        starterGiftProjectionRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1200) {
            guard isClaimingStarterGift else {
                starterGiftProjectionRecoveryTask = nil
                return
            }
            requestStarterGiftHomeProjectionRefresh()
            starterGiftProjectionRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 2400) {
                guard isClaimingStarterGift else {
                    starterGiftProjectionRecoveryTask = nil
                    return
                }
                isClaimingStarterGift = false
                starterGiftClaimErrorMessage = starterGiftProjectionRefreshErrorMessage
                starterGiftProjectionRecoveryTask = nil
            }
        }
    }

    private var starterGiftProjectionRefreshErrorMessage: String {
        L10n(routeLanguageCode).tr(
            zh: "奖励已领取，但首页暂未刷新。请点按重试。",
            en: "The gift was claimed, but Home hasn’t refreshed yet. Try again.",
            de: "Das Geschenk wurde abgeholt, aber Home ist noch nicht aktualisiert. Versuche es erneut."
        )
    }

    @discardableResult
    private func prepareStarterGiftHomeHandoffIfNeeded(_ entityID: UUID) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: StarterGiftStorageKey.pending),
              !defaults.bool(forKey: StarterGiftStorageKey.claimed) else { return false }
        prepareRequiredHomeSnapshot(for: entityID)
        pendingStarterGiftExpectedCoconutBalance = nil
        return true
    }

    private func prepareRequiredHomeSnapshot(for entityID: UUID) {
        guard pendingStarterGiftHomeEntityID != entityID else {
            scheduleStarterGiftHomePreparationRecoveryIfNeeded(for: entityID)
            return
        }
        pendingStarterGiftHomeEntityID = entityID
        isStarterGiftHomeSnapshotReady = false
        starterGiftHomePreparationErrorMessage = nil
        // The new entity is not part of the currently visible-ID invalidation
        // set yet, so a scoped domain revision can be intentionally ignored by
        // the existing Home snapshot. Force the join read instead of waiting
        // for an unrelated future refresh.
        requestStarterGiftHomeProjectionRefresh()
        scheduleStarterGiftHomePreparationRecoveryIfNeeded(for: entityID)
    }

    private func resumeStarterGiftHomePreparationRecoveryIfNeeded() {
        guard let entityID = pendingStarterGiftHomeEntityID else { return }
        scheduleStarterGiftHomePreparationRecoveryIfNeeded(for: entityID)
    }

    private func scheduleStarterGiftHomePreparationRecoveryIfNeeded(for entityID: UUID) {
        starterGiftHomePreparationRecoveryTask?.cancel()
        guard hasOnboarded,
              isStarterGiftHomePreparationPending(for: entityID) else {
            starterGiftHomePreparationRecoveryTask = nil
            return
        }
        starterGiftHomePreparationErrorMessage = nil
        starterGiftHomePreparationRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: OnboardingHomeJoinHandoffGate.homeSnapshotRecoveryInitialDelayMilliseconds
        ) {
            guard isStarterGiftHomePreparationPending(for: entityID) else {
                starterGiftHomePreparationRecoveryTask = nil
                return
            }
            requestStarterGiftHomeProjectionRefresh()
            starterGiftHomePreparationRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(
                milliseconds: OnboardingHomeJoinHandoffGate.homeSnapshotRecoveryRetryDelayMilliseconds
            ) {
                guard isStarterGiftHomePreparationPending(for: entityID) else {
                    starterGiftHomePreparationRecoveryTask = nil
                    return
                }
                requestStarterGiftHomeProjectionRefresh()
                starterGiftHomePreparationRecoveryTask = OhanaFrameScheduler.runAfterNextFrame(
                    milliseconds: OnboardingHomeJoinHandoffGate.homeSnapshotRecoveryFailureDelayMilliseconds
                ) {
                    guard isStarterGiftHomePreparationPending(for: entityID) else {
                        starterGiftHomePreparationRecoveryTask = nil
                        return
                    }
                    starterGiftHomePreparationErrorMessage = L10n(routeLanguageCode).tr(
                        zh: "宠物已经保存，但首页暂未刷新。请重试。",
                        en: "Your pet is saved, but Home hasn’t refreshed yet. Try again.",
                        de: "Dein Tier ist gespeichert, aber Home wurde noch nicht aktualisiert. Versuche es erneut."
                    )
                    starterGiftHomePreparationRecoveryTask = nil
                }
            }
        }
    }

    private func retryStarterGiftHomePreparation() {
        guard let entityID = pendingStarterGiftHomeEntityID,
              isStarterGiftHomePreparationPending(for: entityID) else { return }
        starterGiftHomePreparationErrorMessage = nil
        requestStarterGiftHomeProjectionRefresh()
        scheduleStarterGiftHomePreparationRecoveryIfNeeded(for: entityID)
    }

    private func isStarterGiftHomePreparationPending(for entityID: UUID) -> Bool {
        pendingStarterGiftHomeEntityID == entityID && !isStarterGiftHomeSnapshotReady
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

    private func scheduleHomeCardStateResetIfNeeded(for event: AppRouteNotificationEvent) {
        switch event {
        case .humanDeleted:
            homeCardStateResetToken = UUID()
        case .reminderRouteRequested, .plantBatchCareRouteRequested:
            break
        }
    }

    private func fetchModelsOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        operation: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "ContentView failed to \(operation): \(error.localizedDescription)",
                category: "Onboarding"
            )
            return []
        }
    }

    private func scheduleUITestHumanProfileRouteIfNeeded() {
        guard hasOnboarded,
              let humanName = Self.uiTestHumanProfileRouteName,
              handledUITestHumanProfileRouteName != humanName else { return }
        uiTestRouteTask?.cancel()
        uiTestRouteTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 520) {
            defer { uiTestRouteTask = nil }
            guard Self.uiTestHumanProfileRouteName == humanName,
                  let human = fetchModelsOrLog(
                    FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                    operation: "fetch humans for UI-test human profile route"
                  )
                  .first(where: { $0.name == humanName }) else { return }
            handledUITestHumanProfileRouteName = humanName
            appRoutes.openHuman(human.id)
        }
    }
}

private extension ContentView {
    static var uiTestHumanProfileRouteName: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isRunningTests,
              let flagIndex = arguments.firstIndex(of: "-OHANA_UI_TEST_OPEN_HUMAN_PROFILE_NAME") else {
            return nil
        }
        let nameIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(nameIndex) else { return nil }
        let name = arguments[nameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || arguments.contains("-OHANA_UI_TESTS")
    }
}

private extension View {
    func homeSurfaceLanguage(_ rawLanguage: String) -> some View {
        ohanaLocalizedEnvironment(rawLanguage)
    }
}

#Preview {
    if let modelContainer = try? SharedModelContainer.makePreview() {
        ContentView()
            .modelContainer(modelContainer)
    }
}
