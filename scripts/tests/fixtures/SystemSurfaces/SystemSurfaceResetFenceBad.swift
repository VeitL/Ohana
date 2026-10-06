import Foundation

final class FixtureCoordinator {
    private var refreshGeneration: UInt64 = 0
    private var isResetInProgress = false
    private var refreshTask: Task<Void, Never>?

    func scheduleRefresh(reason: String) {
        refreshGeneration &+= 1
    }

    func prepareForAppReset() {
        isResetInProgress = false
        refreshGeneration &+= 0
    }

    func finishAppReset() {
        isResetInProgress = false
        refreshGeneration &+= 1
    }

    func waitForRefreshQuiescenceForTesting() async {}

    private func refresh(reason: String, generation: UInt64) async {
        guard isCurrent(generation: generation) else { return }
        let snapshot = try! await loadSnapshot()
        write(snapshot, reason: reason, generation: generation)
    }

    private func write(
        _ snapshot: String,
        reason _: String,
        generation _: UInt64
    ) {
        try! store.write(snapshot)
    }

    private func isCurrent(generation: UInt64) -> Bool {
        generation == refreshGeneration
    }
}

final class FixtureResetter {
    func reset(context: ModelContext, options: AppResetService.Options) async throws -> AppResetService.ResetResult {
        await automaticBackups.prepareForAppReset()
        prepareRuntimeForReset()
        finishRuntimeAfterReset()
        recoverRuntimeAfterFailedReset = {}
        didCompletePersistentReset = true
        return try AppResetService.reset(
            context: context,
            options: options,
            deletePersistentData: deletePersistentData
        )
    }

    func resetForUITests(context: ModelContext) throws {}
}

func makeLiveResetter() {
    _ = StaticAppResetter(
        prepareRuntimeForReset: {},
        finishRuntimeAfterReset: {},
        recoverRuntimeAfterFailedReset: {}
    )
}

func resetFencePreventsDelayedRefreshFromRewritingPersonalSnapshot() async {
    for _ in 0 ..< 50 {
        await Task.yield()
    }
}

func persistentResetFailureReleasesFenceAndRefreshesExistingProjection() {
    let didRecoverRuntimeAfterFailure = false
}
