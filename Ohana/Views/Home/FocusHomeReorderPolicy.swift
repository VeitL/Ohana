//
//  FocusHomeReorderPolicy.swift
//  Ohana
//
//  Pure reorder math for the home wallet stack.
//

import SwiftUI

struct FocusHomeReorderUpdate {
    let cards: [FocusCard]
    let dragOffset: CGFloat
    let didMove: Bool
}

enum FocusHomeReorderPolicy {
    static let liftY: CGFloat = -10

    static func update(
        cardId: UUID,
        sourceCards: [FocusCard],
        currentCards: [FocusCard]?,
        startOffsetY: CGFloat,
        dragTranslationY: CGFloat,
        collapsedBottomY: CGFloat
    ) -> FocusHomeReorderUpdate? {
        var workingCards = currentCards ?? sourceCards
        guard let currentIndex = workingCards.firstIndex(where: { $0.id == cardId }) else {
            return nil
        }

        let draggedTopY = startOffsetY + liftY + dragTranslationY
        var targetIndex = currentIndex

        while targetIndex > 0 {
            let previousTopY = slotTopY(
                index: targetIndex - 1,
                cards: workingCards,
                collapsedBottomY: collapsedBottomY
            )
            guard draggedTopY < previousTopY else { break }
            targetIndex -= 1
        }

        while targetIndex < workingCards.count - 1 {
            let nextTopY = slotTopY(
                index: targetIndex + 1,
                cards: workingCards,
                collapsedBottomY: collapsedBottomY
            )
            guard draggedTopY > nextTopY else { break }
            targetIndex += 1
        }

        let didMove = targetIndex != currentIndex
        if didMove {
            let movedCard = workingCards.remove(at: currentIndex)
            workingCards.insert(movedCard, at: targetIndex)
        }

        let currentSlotTopY = slotTopY(
            index: targetIndex,
            cards: workingCards,
            collapsedBottomY: collapsedBottomY
        )

        return FocusHomeReorderUpdate(
            cards: workingCards,
            dragOffset: draggedTopY - currentSlotTopY,
            didMove: didMove
        )
    }

    private static func slotTopY(index: Int, cards: [FocusCard], collapsedBottomY: CGFloat) -> CGFloat {
        FocusWalletLayout.offsetY(
            idx: index,
            n: cards.count,
            bottomY: collapsedBottomY,
            heroId: nil,
            heroTopY: 0,
            cards: cards,
            isExpanded: false
        )
    }
}
