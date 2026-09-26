import Foundation
import Testing
@testable import Ohana

struct OnboardingHandoffResponsivenessTests {
    @Test func freshFirstPetTriggersDeferredStarterJourneyEvaluation() throws {
        let source = try source(
            "Ohana/App/ContentView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("applyOnboardingFirstPetIDIfNeeded()"))
        #expect(source.contains("handledOnboardingFirstPetID"))
        #expect(source.contains("onboardingJourneyNeedsObservation"))
        #expect(source.contains("OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds"))
        #expect(source.contains("scheduleOnboardingJourneyEvaluation(delayMilliseconds: handoffDelay)"))
        #expect(source.contains("prepareStarterGiftHomeHandoffIfNeeded(id)"))
        #expect(source.contains("scheduleOnboardingCreatedEntitySignal(id, destinationTab: .home)"))
        #expect(!source.contains("destinationTab: isStarterGiftHandoff ? .calendar : nil"))
        #expect(source.contains("finishStarterGiftCeremonyIfProjectionIsReady()"))
        #expect(!source.contains("appRoutes.presentSheet(.petWeightQuick(petID))"))
        #expect(!source.contains("appRoutes.presentSheet(.petWeight(petID))"))
        #expect(!source.contains("onboardingPrimaryHumanID"))
    }

    @Test func homeRefreshStateWritesAreDeduplicated() throws {
        let source = try source(
            "Ohana/Features/Home/VerticalSolidHomeDataContainer.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("guard currentDayToken != token else { return }"))
        #expect(source.contains("guard observedHomeInvalidation != invalidation else { return }"))
        #expect(source.contains("pendingHomeInvalidation"))
        #expect(source.contains("pendingDayTokenRefresh"))
        #expect(source.contains("pendingForcedRefresh"))
        #expect(source.contains("consumePendingForcedRefreshIfPossible"))
        #expect(source.contains("homeSurfaceInvalidationUpdates"))
        #expect(source.contains("readModelStore.cancel()"))
        #expect(source.contains("scheduleRefreshKeyStateSync"))
    }

    @Test func frameSchedulerLeavesCurrentMainQueueTurnBeforeMutation() throws {
        let source = try source(
            "Ohana/App/AppRuntimePolicy.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("DispatchQueue.main.async"))
        #expect(source.contains("await withCheckedContinuation"))
    }

    @Test func homeReadModelPublishesOnlyPayloadForSingleFrameCommit() throws {
        let source = try source(
            "Ohana/Features/Home/HomeReadModelStore.swift",
            rootURL: repositoryRootURL()
        )

        #expect(!source.contains("@Published private(set) var snapshot"))
        #expect(!source.contains("@Published private(set) var revision"))
        #expect(!source.contains("@Published private(set) var preparedTabs"))
        #expect(source.contains("@Published private(set) var payload"))
    }

    @Test func appRouteCoordinatorGuardsNoopPresentationWrites() throws {
        let source = try source(
            "Ohana/App/AppRouteCoordinator.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("guard sheet != route || fullScreen != nil || overlay != nil else { return }"))
        #expect(source.contains("guard fullScreen != route || sheet != nil || overlay != nil else { return }"))
        #expect(source.contains("guard path.last != route else { return }"))
        #expect(source.contains("guard sheet != nil else { return }"))
    }

    @Test func onboardingHomePreflightMountsHomeBehindTheBlockingOnboardingLayer() throws {
        let source = try source(
            "Ohana/App/RootView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("private func beginOnboardingHomePreflight()"))
        #expect(source.contains(
            "hasOnboarded || (experienceController.mode == .standard && isOnboardingHomePreflightMounted)"
        ))
        #expect(source.contains("case .standard:"))
        #expect(source.contains("ContentView("))
        #expect(source.contains("case .zen:"))
        #expect(source.contains("zenExperienceShell(experienceController)"))
        #expect(source.contains(".allowsHitTesting(hasOnboarded)"))
        #expect(source.contains(".accessibilityHidden(!hasOnboarded)"))
        #expect(source.contains("onCompletionRequested: requestOnboardingCompletion"))
        #expect(source.contains("onRequiredPetHomeSnapshotReady: markOnboardingPetHomeSnapshotReady"))
        #expect(source.contains("scheduleOnboardingHomeSnapshotRecovery"))
        #expect(source.contains("onRetryHomePreparation: retryOnboardingHomePreparation"))
        #expect(source.contains("resumeOnboardingHomeSnapshotRecoveryIfNeeded()"))
    }

    @Test func petSnapshotHandoffIsOrderIndependentAndIDScoped() {
        let petID = UUID()
        var requestFirst = OnboardingPetSnapshotHandoffState()
        requestFirst.requestCompletion(for: petID)
        #expect(requestFirst.completedPetID == nil)
        requestFirst.markHomeSnapshotReady(for: petID)
        #expect(requestFirst.completedPetID == petID)

        var snapshotFirst = OnboardingPetSnapshotHandoffState()
        snapshotFirst.stage(petID)
        snapshotFirst.markHomeSnapshotReady(for: petID)
        #expect(snapshotFirst.completedPetID == nil)
        snapshotFirst.requestCompletion(for: petID)
        #expect(snapshotFirst.completedPetID == petID)

        var mismatched = OnboardingPetSnapshotHandoffState()
        mismatched.requestCompletion(for: petID)
        mismatched.markHomeSnapshotReady(for: UUID())
        #expect(mismatched.completedPetID == nil)
    }

    @Test func zenSnapshotHandoffWaitsForRequestAndUsesReadyOrFallback() {
        var snapshotFirst = OnboardingZenSnapshotHandoffState()
        snapshotFirst.stageShell()
        snapshotFirst.markHomeSnapshotReady()
        #expect(snapshotFirst.isShellMounted)
        #expect(!snapshotFirst.isReadyToComplete)
        snapshotFirst.requestCompletion()
        #expect(snapshotFirst.isReadyToComplete)

        var requestFirst = OnboardingZenSnapshotHandoffState()
        requestFirst.requestCompletion()
        #expect(requestFirst.isShellMounted)
        #expect(!requestFirst.isReadyToComplete)
        requestFirst.markHomeSnapshotReady()
        #expect(requestFirst.isReadyToComplete)

        var fallback = OnboardingZenSnapshotHandoffState()
        fallback.markFallbackElapsed()
        #expect(!fallback.isReadyToComplete)
        fallback.requestCompletion()
        fallback.markFallbackElapsed()
        #expect(fallback.isReadyToComplete)
        #expect(OnboardingZenSnapshotHandoffGate.fallbackDelayMilliseconds == 1200)
    }

    @Test func zenOnboardingPremountsAnInertShellUntilItsFirstSnapshotIsReady() throws {
        let rootSource = try source(
            "Ohana/App/RootView.swift",
            rootURL: repositoryRootURL()
        )
        let onboardingSource = try source(
            "Ohana/Features/Onboarding/Views/OnboardingView.swift",
            rootURL: repositoryRootURL()
        )
        let zenContainerSource = try source(
            "Ohana/Features/Zen/ZenExperienceContainer.swift",
            rootURL: repositoryRootURL()
        )
        let zenPreparationSource = zenContainerSource
            .components(separatedBy: "private func prepareExperience").last?
            .components(separatedBy: "private func runPresenceCommand").first ?? ""

        #expect(rootSource.contains(
            "experienceController.mode == .zen && onboardingZenSnapshotHandoff.isShellMounted"
        ))
        #expect(rootSource.contains(".allowsHitTesting(hasOnboarded)"))
        #expect(rootSource.contains(".accessibilityHidden(!hasOnboarded)"))
        #expect(rootSource.contains("onZenCompletionRequested: requestOnboardingZenCompletion"))
        #expect(rootSource.contains("beginOnboardingZenPreflight()"))
        #expect(rootSource.contains(
            "onInitialHomeSnapshotReady: markOnboardingZenHomeSnapshotReady"
        ))
        #expect(rootSource.contains(
            "milliseconds: OnboardingZenSnapshotHandoffGate.fallbackDelayMilliseconds"
        ))
        #expect(rootSource.contains(
            "withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.page)"
        ))
        #expect(rootSource.contains(".transition(.opacity)"))
        #expect(onboardingSource.contains("var onZenCompletionRequested: (() -> Void)?"))
        #expect(onboardingSource.contains("requestZenOnboardingCompletion()"))
        #expect(zenPreparationSource.contains("allowsBootstrapPendingHomeRead: true"))
        #expect(!zenPreparationSource.contains("guard persistentBootstrapReady"))
        #expect(zenContainerSource.contains(
            "guard persistentBootstrapReady || allowsBootstrapPendingHomeRead else { return }"
        ))
        #expect(zenContainerSource.contains("let loadsPersistentProjections = persistentBootstrapReady"))
        #expect(zenContainerSource.contains("reportInitialHomeSnapshotReadyIfNeeded()"))
        #expect(zenContainerSource.contains("onInitialHomeSnapshotReady()"))
    }

    @Test func onboardingCompletionFallsBackOnlyWhenNoExternalGateExists() throws {
        let onboardingSource = try source(
            "Ohana/Features/Onboarding/Views/OnboardingView.swift",
            rootURL: repositoryRootURL()
        )
        let contentSource = try source(
            "Ohana/App/ContentView.swift",
            rootURL: repositoryRootURL()
        )
        let feedbackSource = try source(
            "Ohana/Features/GrowthUnlock/Views/GrowthUnlockFeedbackViews.swift",
            rootURL: repositoryRootURL()
        )

        #expect(onboardingSource.contains("var onCompletionRequested: ((UUID) -> Void)?"))
        #expect(onboardingSource.contains("requestPetOnboardingCompletion()"))
        #expect(onboardingSource.contains("guard let onCompletionRequested else"))
        #expect(onboardingSource.contains(".accessibilityHidden(externallyRequestedCompletionPetID != nil)"))
        #expect(contentSource.contains("onRequiredPetHomeSnapshotReady?(requiredReadyEntityID)"))
        #expect(contentSource.contains("prepareRequiredHomeSnapshot(for: id)"))
        #expect(contentSource.contains("requestStarterGiftHomeProjectionRefresh()"))
        #expect(contentSource.contains("if case .starterGiftReady = evaluation.phase"))
        #expect(contentSource.contains("scheduleStarterGiftHomePreparationRecoveryIfNeeded"))
        #expect(feedbackSource.contains("starter-gift-home-preparation-retry"))
        #expect(onboardingSource.contains("onboarding-home-preparation-retry"))
    }

    @Test func onboardingHomeWorkloadHasPostJoinBreathingRoom() throws {
        let source = try source(
            "Ohana/App/AppRuntimePolicy.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("private static let homeReadModelDelayMilliseconds: UInt64 = 240"))
        #expect(source.contains("private static let homeAppearDelayMilliseconds: UInt64 = 180"))
        #expect(!source.contains("private static let homeReadModelDelayMilliseconds: UInt64 = 0"))
        #expect(!source.contains("private static let homeAppearDelayMilliseconds: UInt64 = 0"))
    }

    @Test func appBootstrapDefersSwiftDataContainerUntilAfterFirstShell() throws {
        let source = try source(
            "Ohana/App/OhanaApp.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("OhanaBootstrapShell("))
        #expect(source.contains("Deferred after first shell"))
        #expect(source.contains("openModelContainerOffMain"))
        #expect(source.contains("DispatchQueue.global(qos: .userInitiated).async"))
        #expect(source.contains("scheduleBootstrapWatchdog"))
        #expect(source.contains("OhanaStartupProbe.mark"))
        #expect(source.contains("ohana-startup-probe.log"))
        #expect(source.contains("AppBackgroundStyle.goIsland.gradientColors(for: .dark)"))
        #expect(!source.contains("OhanaAppBackground()"))
        #expect(!source.contains("Eager before RootView"))
        #expect(!source.contains("private let modelContainer: ModelContainer"))
    }

    @Test func appBootstrapUsesOneShortInterruptibleOverlayHandoff() throws {
        let source = try source(
            "Ohana/App/OhanaApp.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains(".opacity(1 - launchRevealProgress)"))
        #expect(source.contains(".scaleEffect(reduceMotion ? 1 : 1 + (launchRevealProgress * 0.006))"))
        #expect(source.contains("let animation = reduceMotion ? GoMotion.reduced : GoMotion.quick"))
        #expect(source.contains("reduceMotion ? 120_000_000 : 180_000_000"))
        #expect(source.contains("await OhanaFrameScheduler.waitAfterNextFrame()"))
        #expect(!source.contains("OhanaLaunchCircularDismissMask"))
        #expect(!source.contains("waitAfterNextFrame(milliseconds: 16)"))
        #expect(!source.contains("duration: 0.48"))
    }

    @Test func memberCreationUsesNativeDismissOutsideOnboardingAndOneCompletionTurn() throws {
        let saveSource = try source(
            "Ohana/Features/Members/Views/MemberCardCreationContentView+MediaAndSave.swift",
            rootURL: repositoryRootURL()
        )
        let viewSource = try source(
            "Ohana/Features/Members/Views/MemberCardCreationView.swift",
            rootURL: repositoryRootURL()
        )
        let completionSource = saveSource
            .components(separatedBy: "func completeSuccessfulMemberCreation").last?
            .components(separatedBy: "func notifySavedMembers").first ?? ""

        #expect(viewSource.contains("presentationStyle == .onboarding"))
        #expect(!viewSource.contains("didShowSuccess"))
        #expect(saveSource.contains("joinSaveTask = OhanaFrameScheduler.runAfterNextFrame"))
        #expect(saveSource.contains("completeSuccessfulMemberCreation(pet: result.pet, human: result.human)"))
        #expect(saveSource.contains("notifySavedMembers(pet: pet, human: human)\n        onComplete()"))
        #expect(!completionSource.contains("runAfterNextFrame"))
        #expect(saveSource.contains("reduceMotion ? GoMotion.reduced : GoMotion.quick"))
        #expect(!saveSource.contains("standardSaveSuccessDelayMilliseconds"))
        #expect(!saveSource.contains("GoMotion.zStackHero"))
    }

    @Test func memberJoinHandoffIsRestrainedAndReduceMotionRemovesSpatialTransforms() throws {
        let motionSource = try source(
            "Ohana/Shared/Design/GoMotion.swift",
            rootURL: repositoryRootURL()
        )
        let componentSource = try source(
            "Ohana/Features/Members/Views/MemberCardCreationComponents.swift",
            rootURL: repositoryRootURL()
        )
        let modifierSource = componentSource
            .components(separatedBy: "struct MemberCreationJoinHandoffModifier").last?
            .components(separatedBy: "struct MemberCreationJoinHandoffCard").first ?? ""

        #expect(motionSource.contains("static let scale: CGFloat = 0.985"))
        #expect(motionSource.contains("static let rotation: CGFloat = 0"))
        #expect(motionSource.contains("static let flip: CGFloat = 0"))
        #expect(motionSource.contains("static let y: CGFloat = 6"))
        #expect(modifierSource.contains("let scale = reduceMotion ? 1"))
        #expect(modifierSource.contains("let y = reduceMotion ? 0"))
        #expect(!modifierSource.contains("rotationEffect"))
        #expect(!modifierSource.contains("rotation3DEffect"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
