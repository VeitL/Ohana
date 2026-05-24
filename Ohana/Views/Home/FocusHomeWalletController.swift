//
//  FocusHomeWalletController.swift
//  Ohana
//
//  Lightweight state holder for the home wallet card stack.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class FocusHomeWalletController: ObservableObject {
    @Published var isExpanded = false
    @Published var activeCardId: UUID?
    @Published var transitionCardId: UUID?
    @Published var heroProgress: CGFloat = 0
    @Published var heroDirection: Int = 0

    private var transitionSession = 0
    private var pendingTap: PendingTap?
    private var lastExpandStartedAt: CFAbsoluteTime?

    private struct PendingTap {
        let startedAt: CFAbsoluteTime
        let cardName: String
        let action: String
    }

    func nextTransitionSession() -> Int {
        transitionSession += 1
        return transitionSession
    }

    func isCurrentTransition(_ session: Int) -> Bool {
        transitionSession == session
    }

    func selectActiveCardWithoutAnimation(_ id: UUID?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeCardId = id
        }
    }

    func prepareTapFeedback() {
        OhanaFeedback.prepareInteraction()
    }

    func triggerTapFeedback() {
        OhanaFeedback.medium()
    }

    func expandToCard(
        id: UUID,
        animation: Animation,
        shouldReduceWork: Bool,
        cancelAvatarLoad: () -> Void,
        resetSurfaces: () -> Void
    ) {
        cancelAvatarLoad()
        resetSurfaces()

        let session = nextTransitionSession()
        transitionCardId = id
        heroDirection = 1
        selectActiveCardWithoutAnimation(id)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            heroProgress = 0
        }
        let pending = consumePendingTap(action: "expand")
        if let pending {
            lastExpandStartedAt = pending.startedAt
            AppPerformanceMonitor.shared.record("home.cardExpandStateSubmitted", startedAt: pending.startedAt, note: pending.cardName)
        } else {
            lastExpandStartedAt = CFAbsoluteTimeGetCurrent()
        }

        withAnimation(animation) {
            isExpanded = true
            heroProgress = 1
        }

        if let pending {
            Task { @MainActor in
                await OhanaFrameScheduler.waitAfterNextFrame()
                guard isCurrentTransition(session) else { return }
                AppPerformanceMonitor.shared.record("home.cardExpandFirstFrame", startedAt: pending.startedAt, note: pending.cardName)
            }
        }

        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: shouldReduceWork ? 180 : 660)
            guard isCurrentTransition(session) else { return }
            transitionCardId = nil
            heroDirection = 0
        }
    }

    func handleCardTap(
        card: FocusCard,
        visibleCount: Int,
        isHero: Bool,
        hasActiveReorderInteraction: () -> Bool,
        consumeSuppressedTap: () -> Bool,
        resetReorder: () -> Void,
        expand: (UUID) -> Void,
        collapse: () -> Void,
        recordLatency: (_ startedAt: CFAbsoluteTime, _ cardName: String) -> Void
    ) {
        let tapStartedAt = CFAbsoluteTimeGetCurrent()

        if hasActiveReorderInteraction() {
            resetReorder()
            return
        }

        if consumeSuppressedTap() {
            return
        }

        triggerTapFeedback()

        let action = (isHero || isExpanded) ? "collapse" : "expand"
        pendingTap = PendingTap(startedAt: tapStartedAt, cardName: card.name, action: action)
        AppPerformanceMonitor.shared.record("home.cardTapAccepted", valueMS: 0, note: "\(action):\(card.name)")

        if visibleCount <= 1 {
            isExpanded ? collapse() : expand(card.id)
            recordLatency(tapStartedAt, card.name)
            return
        }

        if isHero || isExpanded {
            collapse()
        } else {
            expand(card.id)
        }
        recordLatency(tapStartedAt, card.name)
    }

    func collapseToHome(
        animation: Animation,
        shouldReduceWork: Bool,
        returningPreviewId: UUID?,
        visibleCards: @escaping @MainActor () -> [FocusCard],
        resetSurfaces: () -> Void,
        clearRosterPreview: @escaping @MainActor () -> Void
    ) {
        let session = nextTransitionSession()
        transitionCardId = activeCardId
        heroDirection = -1
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            heroProgress = 1
        }
        let pending = consumePendingTap(action: "collapse")
        if let pending {
            AppPerformanceMonitor.shared.record("home.cardCollapseStateSubmitted", startedAt: pending.startedAt, note: pending.cardName)
        }

        withAnimation(animation) {
            isExpanded = false
            heroProgress = 0
            resetSurfaces()
        }

        if let pending {
            Task { @MainActor in
                await OhanaFrameScheduler.waitAfterNextFrame()
                guard isCurrentTransition(session) else { return }
                AppPerformanceMonitor.shared.record("home.cardCollapseFirstFrame", startedAt: pending.startedAt, note: pending.cardName)
            }
        }

        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: shouldReduceWork ? 180 : 560)
            guard isCurrentTransition(session) else { return }
            transitionCardId = nil
            heroDirection = 0

            if let returningPreviewId {
                selectActiveCardWithoutAnimation(visibleCards().first { $0.id != returningPreviewId }?.id)
                clearRosterPreview()
            } else {
                clearRosterPreview()
            }
        }
    }

    private func consumePendingTap(action: String) -> PendingTap? {
        guard pendingTap?.action == action else { return nil }
        defer { pendingTap = nil }
        return pendingTap
    }
}
