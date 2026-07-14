//
//  VerticalSolidHomeView+Utilities.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension VerticalSolidHomeView {
    func scheduleHomeAppearHandoff() {
        homeAppearHandoffTask?.cancel()
        let handoffDelay = OnboardingHomeJoinHandoffGate.remainingHomeAppearDelayMilliseconds()
        homeAppearHandoffTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: handoffDelay) {
            bindHomeAppRouteSink()
            controller.applySnapshot(makeSnapshot(), signature: dataSignature, force: !controller.snapshot.isReady)
            AppPerformanceMonitor.shared.record("home_first_render", valueMS: 0)
            controller.startWarmup()
            scheduleGrowthOnboardingIfNeeded()
            scheduleGrowthUnlockFeedbackIfNeeded()
            homeAppearHandoffTask = nil
        }
    }

    func scheduleMemberMediaAttachmentIndexRepair() {
        memberMediaAttachmentIndexRepairTask?.cancel()
        memberMediaAttachmentIndexRepairTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
            let repaired = MemberMediaAttachmentIndexRepair.repair(
                modelContext: modelContext,
                maxBlobReads: 24
            )
            if repaired {
                requestHomeSnapshotRefresh()
                bumpAvatarCacheRevision()
            }
            memberMediaAttachmentIndexRepairTask = nil
        }
    }

    func injectEmbeddedOasisEnergy() {
        pendingOasisEnergyInjectionCount = min(pendingOasisEnergyInjectionCount + 1, 10)
        schedulePendingEmbeddedOasisEnergyInjection()
    }

    private func schedulePendingEmbeddedOasisEnergyInjection() {
        guard oasisEnergyInjectionTask == nil, pendingOasisEnergyInjectionCount > 0 else { return }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.oasisOpen,
            note: ["source": "home_tab_fab_inject"]
        )
        oasisEnergyInjectionTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 40) {
            pendingOasisEnergyInjectionCount = max(0, pendingOasisEnergyInjectionCount - 1)
            defer {
                oasisEnergyInjectionTask = nil
                schedulePendingEmbeddedOasisEnergyInjection()
            }
            let previousLevel = treeManager.treeLevel.rawValue
            guard treeManager.injectEnergy(
                cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
                modelContext: modelContext
            ) else {
                pendingOasisEnergyInjectionCount = 0
                AppFlowPerformance.mark(
                    AppPerformanceFlows.oasisOpen,
                    AppPerformancePhases.writeFailure,
                    startedAt: startedAt,
                    note: [
                        "action": "injectEnergy",
                        "source": "home_tab"
                    ]
                )
                OhanaFeedback.error()
                return
            }

            oasisInjectEnergyTrigger += 1
            AppFlowPerformance.mark(
                AppPerformanceFlows.oasisOpen,
                AppPerformancePhases.writeSuccess,
                startedAt: startedAt,
                note: [
                    "action": "injectEnergy",
                    "source": "home_tab"
                ]
            )
            requestHomeSnapshotRefresh()
            if treeManager.treeLevel.rawValue > previousLevel {
                scheduleGrowthUnlockFeedbackIfNeeded()
            }
        }
    }

    static func todayFocusVisualProgress(cardHeroProgress: CGFloat) -> CGFloat {
        let visible = min(max(1 - cardHeroProgress, 0), 1)
        return visible * visible * (3 - 2 * visible)
    }

    func preloadFirstScreenAvatars() async {
        let requests = payload.mediaPreloadRequests
        let legacyPayloads = avatarPreloadPayloads()
        let legacyPopoutPayloads = popoutPreloadPayloads()
        guard !requests.isEmpty || !legacyPayloads.isEmpty || !legacyPopoutPayloads.isEmpty else { return }

        if !legacyPayloads.isEmpty || !legacyPopoutPayloads.isEmpty {
            if await FocusWalletAvatarCache.seedPreviewEntries(payloads: legacyPayloads) {
                bumpAvatarCacheRevision()
            }
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 72)
            guard !Task.isCancelled else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            let avatarDidRefresh = await FocusWalletAvatarCache.preload(payloads: legacyPayloads)
            guard !Task.isCancelled else { return }
            let popoutDidRefresh = await FocusPopoutImageCache.preload(payloads: legacyPopoutPayloads)
            guard !Task.isCancelled else { return }
            if avatarDidRefresh || popoutDidRefresh {
                bumpAvatarCacheRevision()
            }
            AppPerformanceMonitor.shared.record(
                "home_avatar_preload_decode",
                startedAt: startedAt,
                note: "\(legacyPayloads.count) avatars, \(legacyPopoutPayloads.count) popouts"
            )
        }

        guard !requests.isEmpty else { return }
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 72)
        guard !Task.isCancelled else { return }

        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        var avatarPayloads: [FocusWalletAvatarCache.Payload] = []
        var popoutPayloads: [FocusWalletAvatarCache.Payload] = []

        for request in requests {
            guard !Task.isCancelled else { return }
            let avatarData: Data? = if request.wantsAvatar {
                await mediaAvatarData(for: request, loader: loader)
            } else {
                nil
            }

            if request.wantsAvatar {
                avatarPayloads.append(FocusWalletAvatarCache.Payload(id: request.id, data: avatarData))
            }

            if request.wantsPopout {
                let popoutData = await mediaPopoutData(for: request, avatarData: avatarData, loader: loader)
                popoutPayloads.append(FocusWalletAvatarCache.Payload(id: request.id, data: popoutData))
            }

            await Task.yield()
        }

        let avatarDidRefresh = await FocusWalletAvatarCache.preload(payloads: avatarPayloads)
        guard !Task.isCancelled else { return }
        let popoutDidRefresh = await FocusPopoutImageCache.preload(payloads: popoutPayloads)
        guard !Task.isCancelled else { return }
        if avatarDidRefresh || popoutDidRefresh {
            bumpAvatarCacheRevision()
        }
    }

    func bumpAvatarCacheRevision() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            avatarCacheRevision += 1
        }
    }

    func avatarPreloadPayloads() -> [FocusWalletAvatarCache.Payload] {
        payload.avatarPreloadPayloads
    }

    func popoutPreloadPayloads() -> [FocusWalletAvatarCache.Payload] {
        payload.popoutPreloadPayloads
    }

    func mediaAvatarData(
        for request: VerticalSolidHomeMediaPreloadRequest,
        loader: SwiftDataMediaBlobLoader
    ) async -> Data? {
        switch request.source {
        case .pet:
            await loader.petAvatarImageData(modelID: request.modelID)
        case .human:
            await loader.humanAvatarImageData(modelID: request.modelID)
        }
    }

    func mediaPopoutData(
        for request: VerticalSolidHomeMediaPreloadRequest,
        avatarData: Data?,
        loader: SwiftDataMediaBlobLoader
    ) async -> Data? {
        guard request.source == .pet else { return nil }
        if let data = await loader.petCardPopoutImageData(modelID: request.modelID) {
            return data
        }
        guard request.popoutSignature == request.avatarSignature else { return nil }
        return avatarData
    }

    func enqueueHomeCommand(
        _ command: DomainCommand,
        operation: @escaping @MainActor () -> Void
    ) {
        commandQueue.enqueue(command) {
            let previousMutationID = appServices.domainRevisions.lastMutation?.id
            operation()
            guard let mutation = appServices.domainRevisions.lastMutation,
                  mutation.id != previousMutationID,
                  mutation.wroteBusinessFact else {
                return
            }
            scheduleGrowthLoopSync(after: mutation)
        }
    }
}
