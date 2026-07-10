import Foundation
import Testing

struct OnboardingHandoffResponsivenessTests {
    @Test func freshPrimaryHumanTriggersImmediateStarterGiftEvaluation() throws {
        let source = try source(
            "Ohana/App/ContentView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("scheduleActiveHumanReaction(newValue)"))
        #expect(source.contains("guard hasOnboarded else { return }"))
        #expect(source.contains("if onboardingPrimaryHumanID == humanID"))
        #expect(source.contains("OnboardingHomeJoinHandoffGate.remainingPostHomeEffectDelayMilliseconds"))
        #expect(source.contains("activeHumanReactionTask = OhanaFrameScheduler.runAfterNextFrame"))
        #expect(!source.contains("scheduleOnboardingJourneyEvaluation(delayMilliseconds: 120, activeHumanIDOverride: humanID)"))
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

    @Test func onboardingHomePreflightDoesNotMountFullHomeBeforeCommit() throws {
        let source = try source(
            "Ohana/App/RootView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("private func beginOnboardingHomePreflight()"))
        #expect(source.contains("if hasOnboarded {"))
        #expect(source.contains("Mounting the full Home stack before"))
        #expect(!source.contains("hasOnboarded || isOnboardingHomePreflightActive"))
        #expect(!source.contains("isOnboardingHomePreflightActive"))
        #expect(!source.contains("onboardingHomePreflightTask"))
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
