//
//  VerticalSolidHomeView+Utilities.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension VerticalSolidHomeView {
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

    func refreshHeaderStreak() {
        headerStreak = appServices.todayFocus.currentStreak(activeHumanId: activeHumanIdRaw)
    }

    static func todayFocusVisualProgress(cardHeroProgress: CGFloat) -> CGFloat {
        let visible = min(max(1 - cardHeroProgress, 0), 1)
        return visible * visible * (3 - 2 * visible)
    }

    static func growthLoopPendingCount(from snapshot: TodayFocusSnapshot) -> Int {
        let pendingQuests = snapshot.refreshedQuests.filter { !$0.isCompleted }.count
        return pendingQuests
            + snapshot.assignedFamilyTasks.count
            + snapshot.pendingExchangeRequests.count
            + snapshot.negativeSignals.count
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
