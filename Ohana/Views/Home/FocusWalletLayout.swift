//
//  FocusWalletLayout.swift
//  Ohana
//
//  Pure geometry for the home wallet stack.
//

import SwiftUI

enum FocusWalletLayout {
    static func collapsedStackBottomY(containerHeight: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let localBottomY = containerHeight - bottomInset - K.collapsedStackBottomGap
        return max(K.cardH, localBottomY)
    }

    static func expandedStackBottomY(containerHeight: CGFloat) -> CGFloat {
        let localBottomY = containerHeight + K.cardH - K.expandedInactiveFrontPeekH
        return max(K.stackPeekH, localBottomY)
    }

    static func expandedOffsetY(
        idx: Int,
        n: Int,
        bottomY: CGFloat,
        heroId: UUID?,
        heroTopY: CGFloat,
        cards: [FocusCard]
    ) -> CGFloat {
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        if idx == heroIdx { return heroTopY }
        let cr = idx < heroIdx ? idx : idx - 1
        let inactiveCount = max(1, n - 1)
        return bottomY - K.cardH - CGFloat(inactiveCount - 1 - cr) * K.expandedInactiveStackPeekH
    }

    static func offsetY(
        idx: Int,
        n: Int,
        bottomY: CGFloat,
        heroId: UUID?,
        heroTopY: CGFloat,
        cards: [FocusCard],
        isExpanded: Bool
    ) -> CGFloat {
        if !isExpanded {
            return bottomY - K.cardH - CGFloat(n - 1 - idx) * collapsedStackPeek(n: n)
        }
        return expandedOffsetY(
            idx: idx,
            n: n,
            bottomY: bottomY,
            heroId: heroId,
            heroTopY: heroTopY,
            cards: cards
        )
    }

    static func zIndex(
        idx: Int,
        n: Int,
        isHero: Bool,
        heroId: UUID?,
        cards: [FocusCard],
        isExpanded: Bool
    ) -> Double {
        if isHero { return Double(n + 100) }
        if !isExpanded { return Double(idx) }
        let heroIdx = cards.firstIndex(where: { $0.id == heroId }) ?? 0
        let compressedRank = idx < heroIdx ? idx : idx - 1
        return Double(compressedRank)
    }

    private static func collapsedStackPeek(n: Int) -> CGFloat {
        guard n > 1 else { return 0 }
        return K.collapsedStackPeekH
    }
}
