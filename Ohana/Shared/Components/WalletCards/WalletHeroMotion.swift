//
//  WalletHeroMotion.swift
//  Ohana
//
//  Shared Apple Wallet style hero motion engine.
//

import SwiftUI

enum WalletHeroTimeline {
    static func smooth(_ value: CGFloat, _ start: CGFloat = 0, _ end: CGFloat = 1) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        let x = min(max((value - start) / (end - start), 0), 1)
        return x * x * (3 - 2 * x)
    }

    static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * min(max(progress, 0), 1)
    }

    static func activeFrame(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
        let p = smooth(progress)
        return CGRect(
            x: lerp(from.minX, to.minX, p),
            y: lerp(from.minY, to.minY, p),
            width: lerp(from.width, to.width, p),
            height: lerp(from.height, to.height, p)
        )
    }

    static func inactiveFrame(
        from: CGRect,
        index: Int,
        selectedIndex: Int?,
        progress: CGFloat,
        layout: WalletHeroLayout,
        direction: Int
    ) -> CGRect {
        guard let selectedIndex, direction < 0 else {
            let p = smooth(progress, 0, 0.16)
            let targetY = layout.collapsedBaseY + 96
            return CGRect(
                x: from.minX,
                y: lerp(from.minY, targetY, p),
                width: from.width,
                height: from.height
            )
        }

        if index < selectedIndex {
            let selectedCollapsed = layout.collapsedFrame(index: selectedIndex, count: layout.cardCount)
            let selectedMoving = activeFrame(from: selectedCollapsed, to: layout.expandedFrame, progress: progress)
            let depth = CGFloat(selectedIndex - index)
            let followerStart = selectedMoving.offsetBy(dx: 0, dy: depth * 13)
            let followerProgress = 1 - smooth(progress, 0.12, 0.94)
            return interpolate(from: followerStart, to: from, progress: followerProgress)
        }

        let frontProgress = 1 - smooth(progress, 0.02, 0.30)
        let underDeck = CGRect(
            x: from.minX,
            y: layout.collapsedBaseY + 112 + CGFloat(index - selectedIndex) * 14,
            width: from.width,
            height: from.height
        )
        return interpolate(from: underDeck, to: from, progress: frontProgress)
    }

    static func inactiveOffsetY(
        collapsedY: CGFloat,
        selectedCollapsedY: CGFloat?,
        activeCurrentY: CGFloat,
        index: Int,
        selectedIndex: Int?,
        progress: CGFloat,
        direction: Int,
        collapsedBottomY: CGFloat
    ) -> CGFloat {
        guard let selectedIndex, let selectedCollapsedY else {
            return collapsedY
        }

        let belowDeckY = collapsedBottomY + 112

        if direction >= 0 {
            let exitProgress = smooth(progress, 0, 0.16)
            return lerp(collapsedY, belowDeckY, exitProgress)
        }

        if index < selectedIndex {
            let depth = CGFloat(selectedIndex - index)
            let followStartY = activeCurrentY + depth * 13
            let followProgress = 1 - smooth(progress, 0.12, 0.94)
            return lerp(followStartY, collapsedY, followProgress)
        }

        if index > selectedIndex {
            let depth = CGFloat(index - selectedIndex)
            let underDeckY = belowDeckY + depth * 14
            let returnProgress = 1 - smooth(progress, 0.02, 0.30)
            return lerp(underDeckY, collapsedY, returnProgress)
        }

        return selectedCollapsedY
    }

    static func interpolate(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
        let p = min(max(progress, 0), 1)
        return CGRect(
            x: lerp(from.minX, to.minX, p),
            y: lerp(from.minY, to.minY, p),
            width: lerp(from.width, to.width, p),
            height: lerp(from.height, to.height, p)
        )
    }

    static func inactiveOpacity(index: Int, selectedIndex: Int?, progress: CGFloat, direction: Int) -> Double {
        guard let selectedIndex, direction < 0 else {
            return Double(1 - smooth(progress, 0, 0.12))
        }
        if index < selectedIndex {
            return Double(1 - smooth(progress, 0.82, 0.98))
        }
        return Double(1 - smooth(progress, 0.08, 0.32))
    }

    static func inactiveScale(index: Int, selectedIndex: Int?, progress: CGFloat, direction: Int) -> CGFloat {
        guard let selectedIndex, direction < 0 else {
            return lerp(1, 0.955, smooth(progress, 0, 0.16))
        }
        if index < selectedIndex {
            return lerp(0.98, 1, 1 - smooth(progress, 0.12, 0.94))
        }
        return lerp(0.955, 1, 1 - smooth(progress, 0.02, 0.30))
    }

    static func quickReveal(progress: CGFloat) -> CGFloat {
        smooth(progress, 0.38, 0.58)
    }

    static func avatarProgress(progress: CGFloat) -> CGFloat {
        smooth(progress, 0.08, 0.88)
    }

    static func cornerRadius(progress: CGFloat) -> CGFloat {
        lerp(24, 36, smooth(progress))
    }
}

struct WalletHeroLayout {
    let size: CGSize
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let cardCount: Int
    let horizontalInset: CGFloat
    let collapsedPeek: CGFloat
    let collapsedBottomGap: CGFloat
    let expandedTopOffset: CGFloat
    let expandedHeightRatio: CGFloat
    let expandedMinHeight: CGFloat
    let expandedMaxHeight: CGFloat
    let quickGap: CGFloat
    let quickHeight: CGFloat

    init(
        size: CGSize,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        cardCount: Int,
        horizontalInset: CGFloat = 7,
        collapsedPeek: CGFloat = 44,
        collapsedBottomGap: CGFloat = 30,
        expandedTopOffset: CGFloat = 64,
        expandedHeightRatio: CGFloat = 0.43,
        expandedMinHeight: CGFloat = 330,
        expandedMaxHeight: CGFloat = 390,
        quickGap: CGFloat = 20,
        quickHeight: CGFloat = 92
    ) {
        self.size = size
        self.safeTop = safeTop
        self.safeBottom = safeBottom
        self.cardCount = cardCount
        self.horizontalInset = horizontalInset
        self.collapsedPeek = collapsedPeek
        self.collapsedBottomGap = collapsedBottomGap
        self.expandedTopOffset = expandedTopOffset
        self.expandedHeightRatio = expandedHeightRatio
        self.expandedMinHeight = expandedMinHeight
        self.expandedMaxHeight = expandedMaxHeight
        self.quickGap = quickGap
        self.quickHeight = quickHeight
    }

    var centerX: CGFloat { size.width / 2 }
    var cardWidth: CGFloat { max(260, min(size.width - horizontalInset * 2, 430)) }
    var collapsedHeight: CGFloat { cardWidth / 1.586 }
    var expandedHeight: CGFloat { min(max(expandedMinHeight, size.height * expandedHeightRatio), expandedMaxHeight) }
    var expandedTop: CGFloat { max(72, safeTop + expandedTopOffset) }
    var collapsedBaseY: CGFloat { size.height - safeBottom - collapsedBottomGap }

    var expandedFrame: CGRect {
        CGRect(
            x: centerX - cardWidth / 2,
            y: expandedTop,
            width: cardWidth,
            height: expandedHeight
        )
    }

    var quickFrame: CGRect {
        CGRect(
            x: centerX - cardWidth / 2,
            y: expandedFrame.maxY + quickGap,
            width: cardWidth,
            height: quickHeight
        )
    }

    func collapsedFrame(index: Int, count: Int) -> CGRect {
        let visibleIndex = CGFloat(max(count - 1 - index, 0))
        let y = collapsedBaseY - visibleIndex * collapsedPeek
        return CGRect(
            x: centerX - cardWidth / 2,
            y: y - collapsedHeight,
            width: cardWidth,
            height: collapsedHeight
        )
    }

    func collapsedHitFrame(index: Int, count: Int) -> CGRect {
        let frame = collapsedFrame(index: index, count: count)
        guard index < count - 1 else {
            return frame
        }
        let nextFrame = collapsedFrame(index: index + 1, count: count)
        let visibleHeight = max(34, nextFrame.minY - frame.minY)
        return CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: visibleHeight
        )
    }
}

struct WalletHeroRevealShape: Shape {
    var reveal: CGFloat

    var animatableData: CGFloat {
        get { reveal }
        set { reveal = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * min(max(reveal, 0), 1)))
    }
}
