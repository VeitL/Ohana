//
//  FocusHomeReorderController.swift
//  Ohana
//
//  Owns the home wallet-card reorder gesture state.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class FocusHomeReorderController: ObservableObject {
    @Published var dragId: UUID?
    @Published var dragOffset: CGFloat = 0
    @Published var cards: [FocusCard]?
    @Published var pressCandidateId: UUID?
    @Published var suppressNextTap = false
    @Published var isEnabled = false
    @Published var isModeActive = false

    private var startOffsetY: CGFloat = 0
    private var didMove = false
    private var session = 0

    var hasActiveInteraction: Bool {
        dragId != nil || cards != nil || isModeActive
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func displayCards(from source: [FocusCard]) -> [FocusCard] {
        guard dragId != nil else { return source }
        return FocusHomeCardDataSource.displayCards(from: source, reorderingCards: cards)
    }

    func update(
        cardId: UUID,
        sourceCards: [FocusCard],
        dragTranslationY: CGFloat,
        collapsedBottomY: CGFloat,
        animation: Animation
    ) {
        guard let update = FocusHomeReorderPolicy.update(
            cardId: cardId,
            sourceCards: sourceCards,
            currentCards: cards,
            startOffsetY: startOffsetY,
            dragTranslationY: dragTranslationY,
            collapsedBottomY: collapsedBottomY
        ) else { return }

        if update.didMove {
            withAnimation(animation) {
                cards = update.cards
            }
            didMove = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        var dragTransaction = Transaction(animation: .linear(duration: 0.045))
        dragTransaction.disablesAnimations = false
        withTransaction(dragTransaction) {
            dragOffset = update.dragOffset
        }
    }

    func updateWithSlotTops(
        cardId: UUID,
        sourceCards: [FocusCard],
        dragTranslationY: CGFloat,
        slotTopY: (_ index: Int, _ count: Int) -> CGFloat,
        animation: Animation
    ) {
        guard let update = FocusHomeReorderPolicy.update(
            cardId: cardId,
            sourceCards: sourceCards,
            currentCards: cards,
            startOffsetY: startOffsetY,
            dragTranslationY: dragTranslationY,
            slotTopY: slotTopY
        ) else { return }

        if update.didMove {
            withAnimation(animation) {
                cards = update.cards
            }
            didMove = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        var dragTransaction = Transaction(animation: .linear(duration: 0.045))
        dragTransaction.disablesAnimations = false
        withTransaction(dragTransaction) {
            dragOffset = update.dragOffset
        }
    }

    func reorderedCardsForCommit() -> [FocusCard]? {
        cards
    }

    func reset() {
        let didReorder = didMove
        session += 1
        pressCandidateId = nil
        dragId = nil
        dragOffset = 0
        startOffsetY = 0
        cards = nil
        didMove = false
        isModeActive = false
        suppressNextTap = false
        if didReorder {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    @discardableResult
    func enterMode(
        isExpanded: Bool,
        visibleCount: Int,
        animation: Animation,
        onEntered: () -> Void
    ) -> Bool {
        guard isEnabled, !isExpanded, visibleCount > 1 else { return false }
        guard !isModeActive else { return false }
        withAnimation(animation) {
            isModeActive = true
            onEntered()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    func beginPressCandidate(
        card: FocusCard,
        cards sourceCards: [FocusCard],
        currentOffsetY: CGFloat,
        isExpanded: @escaping @MainActor () -> Bool,
        begin: @escaping @MainActor () -> Void
    ) {
        guard sourceCards.count > 1 else { return }
        session += 1
        let capturedSession = session
        pressCandidateId = card.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self,
                  self.session == capturedSession,
                  self.pressCandidateId == card.id,
                  self.dragId == nil,
                  !isExpanded()
            else { return }
            self.pressCandidateId = nil
            begin()
        }
    }

    func cancelPressCandidate() {
        guard pressCandidateId != nil else { return }
        session += 1
        pressCandidateId = nil
    }

    func beginReorder(
        card: FocusCard,
        cards sourceCards: [FocusCard],
        currentOffsetY: CGFloat,
        animation: Animation
    ) {
        guard dragId == nil else { return }
        dragId = card.id
        startOffsetY = currentOffsetY
        cards = sourceCards
        didMove = false
        session += 1
        let capturedSession = session
        withAnimation(animation) {
            dragOffset = FocusHomeReorderPolicy.liftY
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scheduleWatchdog(cardId: card.id, session: capturedSession)
    }

    func startFromLongPress(
        card: FocusCard,
        cards sourceCards: [FocusCard],
        currentOffsetY: CGFloat,
        isExpanded: Bool,
        visibleCount: Int,
        modeAnimation: Animation,
        liftAnimation: Animation,
        onEntered: () -> Void
    ) {
        guard isEnabled, !isExpanded, sourceCards.count > 1 else { return }
        guard dragId == nil, !isModeActive else { return }
        suppressNextTap = true
        _ = enterMode(isExpanded: isExpanded, visibleCount: visibleCount, animation: modeAnimation, onEntered: onEntered)
        beginReorder(card: card, cards: sourceCards, currentOffsetY: currentOffsetY, animation: liftAnimation)
    }

    private func scheduleWatchdog(cardId: UUID, session capturedSession: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self,
                  self.session == capturedSession,
                  self.dragId == cardId
            else { return }
            self.reset()
        }
    }
}
