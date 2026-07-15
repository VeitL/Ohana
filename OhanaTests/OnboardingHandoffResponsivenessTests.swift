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
        #expect(source.contains("scheduleOnboardingCreatedEntitySignal(id, destinationTab: .calendar)"))
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
        #expect(source.contains("if hasOnboarded || isOnboardingHomePreflightMounted"))
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

    @Test func memberCreationSaveHandoffDoesNotWaitForFullAnimationTail() throws {
        let source = try source(
            "Ohana/Features/Members/Views/MemberCardCreationContentView+MediaAndSave.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("var standardSaveSuccessDelayMilliseconds"))
        #expect(source.contains("reduceMotion ? 70 : 140"))
        #expect(!source.contains("reduceMotion ? 140 : 820"))
        #expect(!source.contains("milliseconds: 780"))
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
