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
            refreshHeaderStreak()
            controller.startWarmup()
            scheduleGrowthOnboardingIfNeeded()
            scheduleGrowthUnlockFeedbackIfNeeded()
            homeAppearHandoffTask = nil
        }
    }

    func closeVerticalFabMenu(immediate: Bool) {
        guard fabExpanded || fabMenuItemsVisible else { return }
        if immediate || !canAnimate {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                fabMenuItemsVisible = false
                fabExpanded = false
            }
            return
        }

        withAnimation(HeroAnim.fabSpring) {
            fabMenuItemsVisible = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            guard !fabMenuItemsVisible else { return }
            withAnimation(HeroAnim.fabSpring) {
                fabExpanded = false
            }
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

    func refreshHeaderStreak() {
        headerStreak = appServices.todayFocus.currentStreak(activeHumanId: activeHumanIdRaw)
    }

    static func todayFocusVisualProgress(cardHeroProgress: CGFloat) -> CGFloat {
        let visible = min(max(1 - cardHeroProgress, 0), 1)
        return visible * visible * (3 - 2 * visible)
    }

    func preloadFirstScreenAvatars() async {
        let payloads = avatarPreloadPayloads()
        let popoutPayloads = popoutPreloadPayloads()
        guard !payloads.isEmpty || !popoutPayloads.isEmpty else { return }
        if avatarPipeline.seedPreviewEntries(payloads) {
            bumpAvatarCacheRevision()
        }
        avatarPipeline.preload(
            payloads: payloads,
            popoutPayloads: popoutPayloads,
            key: avatarPreloadSignature
        )
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
