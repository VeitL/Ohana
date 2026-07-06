//
//  FocusHomeVerticalSolidScenePolicies.swift
//  Ohana
//
//  Pure policy helpers for the vertical solid home card scene.
//

import SwiftUI

struct FocusHomeVerticalSolidHeroSnapshot {
    let card: FocusCard
    let index: Int
    let avatarSource: FocusHomeFrozenAvatarSource
    let collapsedFrame: CGRect?
    let collapsedRotation: Double?
    let inactiveCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry]

    init(
        card: FocusCard,
        index: Int,
        avatarSource: FocusHomeFrozenAvatarSource,
        collapsedFrame: CGRect? = nil,
        collapsedRotation: Double? = nil,
        inactiveCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = [:]
    ) {
        self.card = card
        self.index = index
        self.avatarSource = avatarSource
        self.collapsedFrame = collapsedFrame
        self.collapsedRotation = collapsedRotation
        self.inactiveCollapsedGeometry = inactiveCollapsedGeometry
    }

    func freezingCollapsedGeometry(
        frame: CGRect,
        rotation: Double,
        inactiveCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = [:]
    ) -> FocusHomeVerticalSolidHeroSnapshot {
        FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: avatarSource,
            collapsedFrame: frame,
            collapsedRotation: rotation,
            inactiveCollapsedGeometry: inactiveCollapsedGeometry
        )
    }

    func preservingCollapsedGeometry(from snapshot: FocusHomeVerticalSolidHeroSnapshot?) -> FocusHomeVerticalSolidHeroSnapshot {
        let preservedInactiveGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = if let inactiveGeometry = snapshot?.inactiveCollapsedGeometry, !inactiveGeometry.isEmpty {
            inactiveGeometry
        } else {
            inactiveCollapsedGeometry
        }

        return FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: avatarSource,
            collapsedFrame: snapshot?.collapsedFrame ?? collapsedFrame,
            collapsedRotation: snapshot?.collapsedRotation ?? collapsedRotation,
            inactiveCollapsedGeometry: preservedInactiveGeometry
        )
    }

    func updatingCard(_ nextCard: FocusCard) -> FocusHomeVerticalSolidHeroSnapshot {
        FocusHomeVerticalSolidHeroSnapshot(
            card: nextCard,
            index: index,
            avatarSource: avatarSource,
            collapsedFrame: collapsedFrame,
            collapsedRotation: collapsedRotation,
            inactiveCollapsedGeometry: inactiveCollapsedGeometry
        )
    }
}

struct FocusHomeInactiveHeroCollapsedGeometry: Equatable {
    let frame: CGRect
    let rotation: Double

    nonisolated static func == (
        lhs: FocusHomeInactiveHeroCollapsedGeometry,
        rhs: FocusHomeInactiveHeroCollapsedGeometry
    ) -> Bool {
        lhs.frame == rhs.frame && lhs.rotation == rhs.rotation
    }
}

nonisolated enum FocusHomeVerticalSolidCollapsedLayoutMode {
    case balanced
    case scrollExtended
}

nonisolated enum FocusHomeVerticalSolidExpandedVerticalPlacement {
    case sceneCenter
    case collapsedCardCenter
    case viewportTop(topInset: CGFloat, scrollOffsetY: CGFloat)
}

nonisolated enum FocusHomeVerticalSolidCollapsedLayoutPolicy {
    static let defaultVerticalBias: CGFloat = 0
    static let bottomExtendedVerticalBias: CGFloat = 0.12
    static let cardAspectRatio: CGFloat = 1.58
    static let scrollExtendedCardWidthEstimate: CGFloat = 144
    static let scrollExtendedVerticalPadding: CGFloat = 64

    static func clampedVerticalBias(_ value: CGFloat) -> CGFloat {
        min(max(value, -0.16), 0.16)
    }

    static func offsets(
        count: Int,
        mode: FocusHomeVerticalSolidCollapsedLayoutMode = .balanced
    ) -> [CGSize] {
        let safeCount = max(count, 1)
        if mode == .scrollExtended, safeCount >= 8 {
            return scrollExtendedOffsets(count: safeCount)
        }

        if safeCount <= 4 {
            return compactOffsets(count: safeCount)
        }

        return balancedScatteredOffsets(count: safeCount)
    }

    static func scrollExtendedMinimumSceneHeight(cardCount: Int) -> CGFloat {
        guard cardCount > 0 else { return 0 }
        guard cardCount >= 8 else { return 0 }
        let offsets = offsets(count: cardCount, mode: .scrollExtended)
        let yValues = offsets.map(\.height)
        let ySpan = (yValues.max() ?? 0) - (yValues.min() ?? 0)
        return ceil((ySpan + cardAspectRatio) * scrollExtendedCardWidthEstimate + scrollExtendedVerticalPadding)
    }

    private static func scrollExtendedOffsets(count: Int) -> [CGSize] {
        let columns = 2
        let rows = Int(ceil(Double(count) / Double(columns)))
        let yCenter = CGFloat(rows - 1) / 2
        let xStep: CGFloat = 1.34
        let yStep: CGFloat = 1.38

        return (0 ..< count).map { index in
            let row = index / columns
            let pairColumn = index % columns
            let isLastSingle = count.isMultiple(of: columns) == false && index == count - 1
            let wovenColumn = row.isMultiple(of: 2) ? pairColumn : columns - 1 - pairColumn
            let baseX: CGFloat = if isLastSingle {
                0
            } else {
                (CGFloat(wovenColumn) - 0.5) * xStep
            }
            let xJitter = (stableUnitValue(index: index, salt: count * 83 + 19) - 0.5) * 0.20
            let yJitter = (stableUnitValue(index: index, salt: count * 89 + 23) - 0.5) * 0.16
            return CGSize(
                width: baseX + xJitter,
                height: (CGFloat(row) - yCenter) * yStep + yJitter
            )
        }
    }

    private static func balancedScatteredOffsets(count: Int) -> [CGSize] {
        if let slots = balancedScatteredSlots(count: count) {
            return slots
        }

        let columns = count <= 10 ? 3 : 4
        let rows = Int(ceil(Double(count) / Double(columns)))
        let xStep: CGFloat = columns == 3 ? 0.92 : 0.78
        let yStep: CGFloat = rows <= 3 ? 0.92 : 0.82
        let xCenter = CGFloat(columns - 1) / 2
        let yCenter = CGFloat(rows - 1) / 2

        return (0 ..< count).map { index in
            let row = index / columns
            let column = index % columns
            let stagger = row.isMultiple(of: 2) ? 0 : 0.36
            let xJitter = (stableUnitValue(index: index, salt: count * 43 + 7) - 0.5) * 0.22
            let yJitter = (stableUnitValue(index: index, salt: count * 47 + 13) - 0.5) * 0.18
            return CGSize(
                width: (CGFloat(column) - xCenter) * xStep + stagger + xJitter,
                height: (CGFloat(row) - yCenter) * yStep + yJitter
            )
        }
    }

    private static func balancedScatteredSlots(count: Int) -> [CGSize]? {
        switch count {
        case 5:
            [
                CGSize(width: -0.78, height: -1.03),
                CGSize(width: 0.76, height: -0.88),
                CGSize(width: -0.86, height: 0.10),
                CGSize(width: 0.88, height: 0.36),
                CGSize(width: -0.12, height: 1.08)
            ]
        case 6:
            [
                CGSize(width: -0.78, height: -1.13),
                CGSize(width: 0.74, height: -1.03),
                CGSize(width: -0.90, height: -0.15),
                CGSize(width: 0.86, height: 0.14),
                CGSize(width: -0.34, height: 0.98),
                CGSize(width: 0.70, height: 1.09)
            ]
        case 7:
            [
                CGSize(width: -0.78, height: -1.18),
                CGSize(width: 0.76, height: -1.08),
                CGSize(width: -0.92, height: -0.22),
                CGSize(width: 0.88, height: 0.02),
                CGSize(width: -0.10, height: 0.58),
                CGSize(width: -0.78, height: 1.22),
                CGSize(width: 0.74, height: 1.18)
            ]
        default:
            nil
        }
    }

    private static func compactOffsets(count: Int) -> [CGSize] {
        switch count {
        case 1:
            [CGSize(width: 0, height: 0)]
        case 2:
            [
                CGSize(width: -0.58, height: -0.05),
                CGSize(width: 0.58, height: 0.05)
            ]
        case 3:
            [
                CGSize(width: -0.62, height: -0.58),
                CGSize(width: 0.62, height: -0.54),
                CGSize(width: 0, height: 0.62)
            ]
        default:
            [
                CGSize(width: -0.62, height: -0.62),
                CGSize(width: 0.62, height: -0.62),
                CGSize(width: -0.62, height: 0.62),
                CGSize(width: 0.62, height: 0.62)
            ]
        }
    }

    private static func stableUnitValue(index: Int, salt: Int) -> CGFloat {
        let raw = (index + 1) * 1_103_515_245 + (salt + 31) * 12345
        let bucket = abs(raw % 10000)
        return CGFloat(bucket) / 9999
    }
}

nonisolated enum FocusHomeInactiveHeroGeometryPolicy {
    static func collapsedFrame(
        stableFrame: CGRect,
        preparedFrame: CGRect?,
        frozenFrame: CGRect?,
        freezesInactiveGeometry: Bool,
        selectedCardId: UUID?,
        cardId: UUID
    ) -> CGRect {
        guard selectedCardId != nil else { return stableFrame }
        guard selectedCardId != cardId else { return preparedFrame ?? stableFrame }
        if freezesInactiveGeometry, let frozenFrame {
            return frozenFrame
        }
        return preparedFrame ?? stableFrame
    }
}

nonisolated enum FocusHomeInactiveHeroRotationPolicy {
    static func rotation(
        stableRotation: Double,
        frozenRotation: Double?,
        freezesInactiveGeometry: Bool,
        selectedCardId: UUID?,
        cardId: UUID
    ) -> Double {
        guard selectedCardId != nil else { return stableRotation }
        guard selectedCardId != cardId else { return stableRotation }
        if freezesInactiveGeometry, let frozenRotation {
            return frozenRotation
        }
        return stableRotation
    }
}

nonisolated enum FocusHomeInactiveHeroGeometrySourcePolicy {
    static func geometry(
        cardId: UUID,
        selectedCardId: UUID?,
        local: [UUID: FocusHomeInactiveHeroCollapsedGeometry],
        localSelectionId: UUID?,
        external: [UUID: FocusHomeInactiveHeroCollapsedGeometry],
        externalSelectionId: UUID?,
        freezesInactiveGeometry: Bool
    ) -> FocusHomeInactiveHeroCollapsedGeometry? {
        guard freezesInactiveGeometry,
              let selectedCardId else {
            return nil
        }
        if externalSelectionId == selectedCardId,
           let externalGeometry = external[cardId] {
            return externalGeometry
        }
        if localSelectionId == selectedCardId {
            return local[cardId]
        }
        return nil
    }
}

nonisolated enum FocusHomeInactiveHeroVisualPolicy {
    static func scale(
        selectedCardId: UUID?,
        cardId: UUID,
        progress: CGFloat,
        reduceMotion: Bool,
        freezesInactiveGeometry: Bool
    ) -> CGFloat {
        guard selectedCardId != nil, cardId != selectedCardId else { return 1 }
        guard !reduceMotion else { return 1 }
        guard !freezesInactiveGeometry else { return 1 }
        return 1 - smooth(progress, 0, 0.16) * 0.08
    }

    private static func smooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        let x = min(max((value - start) / (end - start), 0), 1)
        return x * x * (3 - 2 * x)
    }
}

nonisolated enum FocusHomeInactiveHeroLayerPolicy {
    static func disablesImplicitAnimations(
        selectedCardId: UUID?,
        cardId: UUID,
        freezesInactiveGeometry: Bool
    ) -> Bool {
        guard freezesInactiveGeometry, let selectedCardId else { return false }
        return selectedCardId != cardId
    }
}

enum FocusHomeEmbeddedQuickActionThawPolicy {
    static func isMounted(isExpandedInteractionMounted: Bool) -> Bool {
        isExpandedInteractionMounted
    }

    static func reveal(isMounted: Bool, postHeroReveal: CGFloat) -> CGFloat {
        guard isMounted else { return 0 }
        return min(max(postHeroReveal, 0), 1)
    }
}

enum FocusHomeEmbeddedQuickActionPresentationPolicy {
    static func isVisible(
        embedsQuickActionsInCard: Bool,
        isExpandedSurface: Bool,
        hasWalkTrackingCard: Bool,
        isMounted: Bool
    ) -> Bool {
        embedsQuickActionsInCard
            && isExpandedSurface
            && !hasWalkTrackingCard
            && isMounted
    }

    static func isInteractive(
        isExpandedInteractionMounted: Bool,
        reveal: CGFloat
    ) -> Bool {
        isExpandedInteractionMounted && reveal >= FocusHomeExpandedInteractionPolicy.visibleControlInteractionProgress
    }
}

enum FocusHomeExpandedInteractionPolicy {
    static let expandedControlReadyProgress: CGFloat = 0.18
    static let visibleControlInteractionProgress: CGFloat = 0.18

    static func isExpandedControlReady(
        selectedCardId: UUID?,
        heroDirection: Int,
        progress: CGFloat
    ) -> Bool {
        guard selectedCardId != nil, heroDirection >= 0 else { return false }
        return progress >= expandedControlReadyProgress
    }

    static func isExpandedCollapseReady(
        selectedCardId: UUID?,
        progress: CGFloat
    ) -> Bool {
        guard selectedCardId != nil else { return false }
        return progress >= expandedControlReadyProgress
    }

    static func canHitCollapsedCards(
        selectedCardId: UUID?,
        heroDirection: Int,
        progress: CGFloat
    ) -> Bool {
        true
    }

    static func isDetailButtonInteractive(
        isExpandedInteractionMounted: Bool,
        reveal: CGFloat
    ) -> Bool {
        isExpandedInteractionMounted && reveal >= visibleControlInteractionProgress
    }
}

enum FocusHomeCollapsedHitLayerPolicy {
    static func zIndex(selectedCardId: UUID?) -> Double {
        selectedCardId == nil ? 80 : 23
    }

    static func includes(cardId: UUID, selectedCardId: UUID?) -> Bool {
        selectedCardId != cardId
    }
}

enum FocusHomePostHeroControlRevealPolicy {
    static let animationDuration: TimeInterval = 0.18
    static let detailButtonOffset: CGFloat = 8
    static let fullMotionPreloadDelayMilliseconds: UInt64 = 220
    static let reducedMotionPreloadDelayMilliseconds: UInt64 = 36

    static var animation: Animation {
        .easeOut(duration: animationDuration)
    }

    static func preloadDelayMilliseconds(reduceMotion: Bool) -> UInt64 {
        reduceMotion ? reducedMotionPreloadDelayMilliseconds : fullMotionPreloadDelayMilliseconds
    }
}

enum FocusHomeEmbeddedCardCollapseHitPolicy {
    static let quickActionDockProtectionPadding: CGFloat = 42

    static func isMounted(isExpandedSurface: Bool, hasWalkTrackingCard: Bool) -> Bool {
        isExpandedSurface && !hasWalkTrackingCard
    }

    static func protectsQuickActionDock(quickActionsAreVisible: Bool) -> Bool {
        quickActionsAreVisible
    }

    static func hitHeight(
        frameHeight: CGFloat,
        quickActionDockHeight: CGFloat,
        protectsQuickActionDock: Bool
    ) -> CGFloat {
        guard protectsQuickActionDock else { return max(44, frameHeight) }
        return max(44, frameHeight - (quickActionDockHeight + quickActionDockProtectionPadding))
    }
}

enum FocusHomeWalkCardIdentityPolicy {
    static func phaseKey(_ phase: WalkPhase) -> String {
        switch phase {
        case .idle:
            "idle"
        case .running, .paused:
            "active"
        case .finished:
            "finished"
        }
    }

    static func identity(
        cardID: UUID,
        walkPetID: UUID?,
        phase: WalkPhase,
        presentationRevision: Int
    ) -> String {
        guard let walkPetID else { return cardID.uuidString }
        return [
            cardID.uuidString,
            walkPetID.uuidString,
            phaseKey(phase),
            "\(presentationRevision)"
        ].joined(separator: "#")
    }
}

enum FocusHomeAmbientFloatPolicy {
    static let cycleDuration: TimeInterval = 8.7
    static let phaseDuration: TimeInterval = cycleDuration / 2
    static let phaseDurationNanoseconds = UInt64(phaseDuration * 1_000_000_000)
    static let resumeDuration: TimeInterval = 0.30
    static let yAmplitude: CGFloat = 2.8
    static var phaseAnimation: Animation { .easeInOut(duration: phaseDuration) }
    static var resumeAnimation: Animation { .easeOut(duration: resumeDuration) }

    static func isSurfaceVisibleForAmbient(
        isVisible: Bool,
        selectedCardId: UUID?,
        progress: CGFloat
    ) -> Bool {
        isVisible && selectedCardId == nil && progress <= 0.001
    }

    static func isSurfaceCovered(
        selectedCardId: UUID?,
        progress: CGFloat
    ) -> Bool {
        selectedCardId != nil || progress > 0.001
    }

    static func allowsAmbientOptIn(
        isEnabled: Bool,
        reduceMotion: Bool
    ) -> Bool {
        isEnabled && !reduceMotion
    }

    static func wave(index: Int, isRaisedPhase: Bool) -> Double {
        sin((isRaisedPhase ? Double.pi : 0) + Double(index) * 1.27)
    }
}
