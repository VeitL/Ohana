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
    var onboardingPrimaryHumanID: String?
    var routeLanguageCode: String = AppLanguage.code

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @StateObject private var appRoutes = AppRouteCoordinator()
    @State private var createdEntitySignal: HomeCreatedEntitySignal?
    @State private var rootAppearHandoffTask: Task<Void, Never>?
    @State private var onboardingJourneyEvaluationTask: Task<Void, Never>?
    @State private var coconutWalletBootstrapTask: Task<Void, Never>?
    @State private var activeHumanReactionTask: Task<Void, Never>?
    @State private var onboardingCreatedEntitySignalTask: Task<Void, Never>?
    @State private var uiTestRouteTask: Task<Void, Never>?
    @State private var uiTestEconomyStateSeedTask: Task<Void, Never>?
    @State private var onboardingJourneyPhase: OnboardingJourneyPhase = .preOnboarding
    @State private var handledOnboardingPrimaryHumanID: String?
    @State private var signaledOnboardingPrimaryHumanID: String?
    @State private var handledUITestHumanProfileRouteName: String?
    @State private var homeCardStateResetToken = UUID()
    @State private var homeSurfaceLanguage = AppLanguage.code
    @State private var homeSurfaceLanguageThawTask: Task<Void, Never>?
    @State private var routeSurfaceLanguage = AppLanguage.code
    @State private var routeSurfaceLanguageThawTask: Task<Void, Never>?
    @State private var autoPresentedFirstCarePetID: UUID?
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
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
            }
            .id(appRoutes.rootIdentity)
            .homeSurfaceLanguage(homeSurfaceLanguage)
            .accessibilityHidden(appRoutes.sheet != nil || appRoutes.fullScreen != nil || appRoutes.overlay != nil)

            if hasOnboarded, !appRoutes.suppressesGlobalWalkBanner {
                GlobalWalkBanner()
                    .homeSurfaceLanguage(homeSurfaceLanguage)
                    .accessibilityHidden(appRoutes.sheet != nil || appRoutes.fullScreen != nil || appRoutes.overlay != nil)
                    .zIndex(80)
            }

            GlobalCoconutRewardFeedbackLayer()
                .zIndex(120)

            if let starterGiftAmount {
                StarterGiftCeremonyOverlay(
                    appLanguage: routeLanguageCode,
                    amount: starterGiftAmount,
                    onFinish: completeStarterGiftCeremony
                )
                .zIndex(140)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(GoMotion.sheetEnter, value: onboardingJourneyPhase)
        .onAppear {
            synchronizeHomeSurfaceLanguageIfAllowed(routeLanguageCode)
            synchronizeRouteSurfaceLanguageIfAllowed(routeLanguageCode)
            scheduleRootAppearHandoff()
            applyOnboardingPrimaryHumanIDIfNeeded()
            scheduleUITestHumanProfileRouteIfNeeded()
        }
        .onDisappear {
            rootAppearHandoffTask?.cancel()
            rootAppearHandoffTask = nil
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
        }
        .onChange(of: hasOnboarded) { _, hasOnboarded in
            guard hasOnboarded else { return }
            scheduleRootAppearHandoff()
            applyOnboardingPrimaryHumanIDIfNeeded()
            scheduleUITestHumanProfileRouteIfNeeded()
            scheduleUITestEconomyStateSeedIfNeeded()
        }
        .onChange(of: onboardingPrimaryHumanID) { _, _ in
            applyOnboardingPrimaryHumanIDIfNeeded()
        }
        .onReceive(appServices.notificationRoutes.routeEvents) { published in
            scheduleHomeCardStateResetIfNeeded(for: published.event)
            handleRouteNotificationOutcome(
                appRoutes.handleNotificationEvent(published.event)
            )
        }
        .appRoutePresentationHost(
            coordinator: appRoutes,
            onRequiredHumanSaved: { activateRequiredHuman($0) },
            onPetSavedFromAddEntity: { pet in
                scheduleCreatedEntitySignalAfterHomeHandoff(pet.id)
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
            onFirstSuccessMomentCompleted: { _ in
                completeFirstCareAfterHomeHandoff()
            },
            onHumanDoseTaken: { _ in
                completeFirstCareAfterHomeHandoff()
            },
            routeLanguageCode: routeSurfaceLanguage
        )
        .onChange(of: currentActiveHumanId) { _, newValue in
            scheduleActiveHumanReaction(newValue)
        }
        .onChange(of: scenePhase) { _, newPhase in
            appServices.lifecycle.handle(.scenePhaseChanged(newPhase))
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
            isHomeSurfaceVisible: isHomeSurfaceVisible
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
              case let .starterGiftReadyForCeremony(amount) = onboardingJourneyPhase else {
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
            appServices.lifecycle.handle(.rootAppeared(scenePhase: scenePhase))
            appServices.cloudSync.startAfterFirstRender(modelContainer: modelContext.container)
            scheduleCoconutWalletBootstrap()
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
        advanceFirstDayFunnelIfNeeded(phase: evaluation.phase)
    }

    private func advanceFirstDayFunnelIfNeeded(phase: OnboardingJourneyPhase) {
        guard hasOnboarded,
              appRoutes.sheet == nil,
              appRoutes.fullScreen == nil,
              appRoutes.overlay == nil
        else { return }

        switch phase {
        case .needsFirstPet:
            break
        case .firstCarePending:
            guard let petID = firstActivePetNeedingStarterWeightID(),
                  autoPresentedFirstCarePetID != petID else { return }
            autoPresentedFirstCarePetID = petID
            appRoutes.presentSheet(.petWeight(petID))
        case .preOnboarding,
             .needsPrimaryHuman,
             .starterGiftPending,
             .starterGiftReadyForCeremony,
             .roadmapPromptPending,
             .complete,
             .existingUser:
            break
        }
    }

    private func firstActivePetNeedingStarterWeightID() -> UUID? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.passedAwayDate == nil
            },
            sortBy: [SortDescriptor(\Pet.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 8
        let pets = fetchModelsOrLog(descriptor, operation: "fetch first-day pet needing weight")
        return pets.first { $0.weightLogs.isEmpty }?.id ?? pets.first?.id
    }

    private func resolvedOnboardingEvaluationActiveHumanID(override: String?) -> String? {
        if let override, !override.isEmpty {
            return override
        }
        if !currentActiveHumanId.isEmpty {
            return currentActiveHumanId
        }
        if let onboardingPrimaryHumanID, !onboardingPrimaryHumanID.isEmpty {
            return onboardingPrimaryHumanID
        }
        return appServices.onboardingJourney.interruptedOnboardingPrimaryHumanID(context: modelContext)
    }

    private func scheduleOnboardingJourneyEvaluationForActiveHumanChange(_ humanID: String) {
        guard hasOnboarded else { return }
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds(
            defaultDelayMilliseconds: 480
        )
        if onboardingPrimaryHumanID == humanID || handoffDelay > 480 {
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

    private func applyOnboardingPrimaryHumanIDIfNeeded() {
        guard let humanID = onboardingPrimaryHumanID, !humanID.isEmpty else { return }
        if currentActiveHumanId != humanID {
            currentActiveHumanId = humanID
        }
        if let id = UUID(uuidString: humanID),
           signaledOnboardingPrimaryHumanID != humanID {
            signaledOnboardingPrimaryHumanID = humanID
            scheduleOnboardingCreatedEntitySignal(id)
        }
        guard hasOnboarded, handledOnboardingPrimaryHumanID != humanID else { return }
        handledOnboardingPrimaryHumanID = humanID
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds(
            defaultDelayMilliseconds: 480
        )
        scheduleOnboardingJourneyEvaluation(delayMilliseconds: handoffDelay, activeHumanIDOverride: humanID)
    }

    private func scheduleOnboardingJourneyEvaluationAfterHomeHandoff(activeHumanIDOverride: String? = nil) {
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds(
            defaultDelayMilliseconds: 480
        )
        scheduleOnboardingJourneyEvaluation(delayMilliseconds: handoffDelay, activeHumanIDOverride: activeHumanIDOverride)
    }

    private func completeFirstCareAfterHomeHandoff() {
        OnboardingHomeJoinHandoffGate.markCompleted()
        appServices.onboardingJourney.markFirstCareCompleted()
        scheduleOnboardingJourneyEvaluationAfterHomeHandoff()
    }

    private func scheduleCreatedEntitySignalAfterHomeHandoff(
        _ id: UUID,
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
                createdEntitySignal = HomeCreatedEntitySignal(entityID: id)
            }
            onboardingCreatedEntitySignalTask = nil
        }
    }

    private func scheduleOnboardingCreatedEntitySignal(_ id: UUID) {
        scheduleCreatedEntitySignalAfterHomeHandoff(id, defaultDelayMilliseconds: 240)
    }

    private func scheduleUITestEconomyStateSeedIfNeeded(delayMilliseconds: UInt64 = 180) {
        #if DEBUG
            guard OhanaUITestLaunchOptions.requestedCoconutBalanceSeedAmount != nil
                || OhanaUITestLaunchOptions.requestsRewardTierUnlock
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
                if currentActiveHumanId.isEmpty, let activeHumanID {
                    currentActiveHumanId = activeHumanID.uuidString
                }
                uiTestEconomyStateSeedTask = nil
            }
        #endif
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
    ContentView()
        .modelContainer(SharedModelContainer.make())
}
