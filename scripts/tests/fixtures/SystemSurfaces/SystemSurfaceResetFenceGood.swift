import Foundation

final class FixtureCoordinator {
    private var refreshGeneration: UInt64 = 0
    private var isResetInProgress = false
    private var refreshTask: Task<Void, Never>?

    func scheduleRefresh(reason: String) {
        guard !isResetInProgress else { return }
        refreshGeneration &+= 1
    }

    func prepareForAppReset() {
        isResetInProgress = true
        refreshGeneration &+= 1
        refreshTask?.cancel()
    }

    func finishAppReset() {
        refreshGeneration &+= 1
        isResetInProgress = false
    }

    func waitForRefreshQuiescenceForTesting() async {}

    private func refresh(reason: String, generation: UInt64) async {
        let snapshot = try await loadSnapshot()
        guard isCurrent(generation: generation) else { return }
        write(snapshot, reason: reason, generation: generation)
    }

    private func write(
        _ snapshot: String,
        reason _: String,
        generation: UInt64
    ) {
        guard isCurrent(generation: generation) else { return }
        try store.write(snapshot)
    }

    private func isCurrent(generation: UInt64) -> Bool {
        !isResetInProgress && generation == refreshGeneration
    }
}

final class FixtureResetter {
    func reset(context: ModelContext, options: AppResetService.Options) async throws -> AppResetService.ResetResult {
        var didCompletePersistentReset = false
        prepareRuntimeForReset()
        defer {
            finishRuntimeAfterReset()
            if !didCompletePersistentReset {
                recoverRuntimeAfterFailedReset()
            }
        }
        await automaticBackups.prepareForAppReset()
        let result = try AppResetService.reset(
            context: context,
            options: options,
            deletePersistentData: deletePersistentData
        )
        didCompletePersistentReset = true
        return result
    }

    func resetForUITests(context: ModelContext) throws {}
}

func makeLiveResetter() {
    _ = StaticAppResetter(
        prepareRuntimeForReset: {
            graph.systemSurfaces.prepareForAppReset()
        },
        finishRuntimeAfterReset: {
            graph.systemSurfaces.finishAppReset()
        },
        recoverRuntimeAfterFailedReset: {
            graph.systemSurfaces.scheduleRefresh(reason: "appReset.failed")
        }
    )
}

func resetFencePreventsDelayedRefreshFromRewritingPersonalSnapshot() async {
    await loader.waitUntilStarted()
}

final class DelayedLoader {
    func waitUntilStarted() async {}
}

func persistentResetFailureReleasesFenceAndRefreshesExistingProjection() {
    #expect(didRecoverRuntimeAfterFailure)
}
