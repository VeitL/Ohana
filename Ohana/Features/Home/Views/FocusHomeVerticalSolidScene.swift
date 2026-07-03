//
//  FocusHomeVerticalSolidScene.swift
//  Ohana
//
//  Real-data portrait solid card scene for the selectable home style.
//

import SwiftUI
import UIKit

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
    static let openingMountProgress: CGFloat = 0.36
    static let openingFullyVisibleProgress: CGFloat = 0.74
    static let reducedMotionMountProgress: CGFloat = 0.5
    static let closingKeepAliveProgress: CGFloat = 0.82

    static func isMounted(progress: CGFloat, heroDirection: Int, reduceMotion: Bool) -> Bool {
        let p = min(max(progress, 0), 1)
        if heroDirection < 0 {
            return p > closingKeepAliveProgress
        }
        return p >= (reduceMotion ? reducedMotionMountProgress : openingMountProgress)
    }

    static func reveal(progress: CGFloat, heroDirection: Int, reduceMotion: Bool) -> CGFloat {
        guard isMounted(progress: progress, heroDirection: heroDirection, reduceMotion: reduceMotion) else {
            return 0
        }
        if reduceMotion { return 1 }
        if heroDirection < 0 {
            return WalletHeroTimeline.smooth(progress, closingKeepAliveProgress, 0.92)
        }
        return WalletHeroTimeline.smooth(progress, openingMountProgress, openingFullyVisibleProgress)
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
        isExpandedInteractionReady: Bool,
        reveal: CGFloat
    ) -> Bool {
        isExpandedInteractionReady && reveal > 0.98
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
}

enum FocusHomeAmbientFloatPolicy {
    static let timelineMinimumInterval: TimeInterval = 1.0 / 15.0

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
}

enum FocusHomeVerticalSolidCollapsedLayoutPolicy {
    static let defaultVerticalBias: CGFloat = 0
    static let bottomExtendedVerticalBias: CGFloat = 0.12

    static func clampedVerticalBias(_ value: CGFloat) -> CGFloat {
        min(max(value, -0.16), 0.16)
    }
}

struct FocusHomeVerticalSolidScene<QuickActions: View, ContextMenuContent: View>: View {
    let cards: [FocusCard]
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let selectedCardId: UUID?
    var preparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    var heroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    let progress: CGFloat
    var heroDirection: Int = 0
    var arrivingCardId: UUID?
    let reduceMotion: Bool
    let localization: L10n
    let allowsAmbientFloat: Bool
    var isVisible: Bool = true
    var walkPresentationRevision: Int = 0
    var embedsQuickActionsInCard: Bool = false
    var freezesInactiveCollapsedGeometryDuringHero: Bool = false
    var externalInactiveCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = [:]
    var externalInactiveCollapsedGeometrySelectionId: UUID?
    var collapsedTopInset: CGFloat = 0
    var collapsedVerticalBias: CGFloat = FocusHomeVerticalSolidCollapsedLayoutPolicy.defaultVerticalBias
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusHomeVerticalSolidHeroSnapshot) -> Void
    let onCollapse: () -> Void
    var onInactiveCollapsedGeometryFrozen: ([UUID: FocusHomeInactiveHeroCollapsedGeometry], UUID) -> Void = { _, _ in }
    let onWalkCardMinimizeToFloatingControl: () -> Void
    let onOpenDetails: (FocusCard) -> Void

    @Environment(AppServices.self) private var appServices
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var floatingResumeStartTime: TimeInterval?
    @State private var animatedArrivalCardId: UUID?
    @State private var arrivalProgress: CGFloat = 1
    @State private var arrivalCleanupTask: Task<Void, Never>?
    @State private var inactiveHeroCollapsedGeometry: [UUID: FocusHomeInactiveHeroCollapsedGeometry] = [:]
    @State private var inactiveHeroCollapsedGeometrySelectionId: UUID?
    @GestureState private var expandedDragY: CGFloat = 0

    private var l: L10n { localization }

    private var selectedCard: FocusCard? {
        if let activeHeroSnapshot {
            return activeHeroSnapshot.card
        }

        return selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    private var activeHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot? {
        guard let selectedCardId else {
            return nil
        }

        if let heroSnapshot,
           heroSnapshot.card.id == selectedCardId {
            return heroSnapshot
        }

        if let prepared = preparedHeroSnapshots[selectedCardId] {
            return prepared
        }

        guard let index = cards.firstIndex(where: { $0.id == selectedCardId }) else {
            return nil
        }

        let card = cards[index]
        return FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private var isExpandedInteractionReady: Bool {
        selectedCardId != nil && heroDirection == 0 && progress > 0.985
    }

    private var isExpandedCollapseReady: Bool {
        selectedCardId != nil && progress > 0.92
    }

    private var canHitCollapsedCards: Bool {
        selectedCardId == nil || (heroDirection <= 0 && progress <= 0.06)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if canFloatCards {
                    TimelineView(.animation(minimumInterval: FocusHomeAmbientFloatPolicy.timelineMinimumInterval)) { timeline in // smoothness: allow visible-card ambient float gated by FocusHomeAmbientFloatPolicy and disabled during hero work.
                        sceneContent(in: geo, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    sceneContent(in: geo, time: 0)
                }
            }
            .onAppear {
                primeFloatingMotionIfVisible()
                prepareArrivalIfNeeded()
                updateInactiveHeroCollapsedGeometry(
                    size: geo.size,
                    selectedCardId: selectedCardId
                )
            }
            .onChange(of: selectedCardId) { _, newValue in
                updateInactiveHeroCollapsedGeometry(
                    size: geo.size,
                    selectedCardId: newValue
                )
                if newValue == nil {
                    primeFloatingMotionIfVisible()
                } else {
                    floatingResumeStartTime = nil
                }
            }
            .onChange(of: isVisible) { _, _ in
                primeFloatingMotionIfVisible()
            }
            .onChange(of: arrivalKey) { _, _ in
                prepareArrivalIfNeeded()
            }
            .onDisappear {
                arrivalCleanupTask?.cancel()
                arrivalCleanupTask = nil
                animatedArrivalCardId = nil
                arrivalProgress = 1
            }
        }
    }

    private func sceneContent(in geo: GeometryProxy, time: TimeInterval) -> some View {
        let visibleCenterX = visibleCenterX(in: geo)
        return ZStack {
            if canHitCollapsedCards {
                collapsedHitLayer(in: geo.size, time: time)
                    .zIndex(80)
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onCollapse() }
                    .zIndex(1)
            }

            if let selectedCard, !embedsQuickActionsInCard {
                if walkTrackingPet(for: selectedCard, isSelected: true) == nil {
                    quickActionLayer(for: selectedCard, in: geo.size, visibleCenterX: visibleCenterX)
                        .zIndex(32)
                }
            }

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cardLayer(for: card, index: index, in: geo.size, visibleCenterX: visibleCenterX, time: time)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private var arrivalKey: String {
        [
            arrivingCardId?.uuidString ?? "",
            cards.map(\.id.uuidString).joined(separator: "|"),
            isVisible ? "visible" : "hidden"
        ].joined(separator: "#")
    }

    private func prepareArrivalIfNeeded() {
        guard isVisible,
              selectedCardId == nil,
              let arrivingCardId,
              cards.contains(where: { $0.id == arrivingCardId }),
              animatedArrivalCardId != arrivingCardId else { return }
        arrivalCleanupTask?.cancel()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedArrivalCardId = arrivingCardId
            arrivalProgress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 40) {
            guard animatedArrivalCardId == arrivingCardId else { return }
            withAnimation(reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero) {
                arrivalProgress = 1
            }
        }
        arrivalCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 980) {
            guard animatedArrivalCardId == arrivingCardId else { return }
            animatedArrivalCardId = nil
            arrivalProgress = 1
            arrivalCleanupTask = nil
        }
    }

    private func updateInactiveHeroCollapsedGeometry(
        size: CGSize,
        selectedCardId: UUID?
    ) {
        guard freezesInactiveCollapsedGeometryDuringHero else { return }
        guard let selectedCardId else {
            setInactiveHeroCollapsedGeometry([:], selectionId: nil)
            return
        }
        guard inactiveHeroCollapsedGeometrySelectionId != selectedCardId
                || inactiveHeroCollapsedGeometry.isEmpty else { return }

        setInactiveHeroCollapsedGeometry(
            inactiveCollapsedGeometry(size: size, selectedCardId: selectedCardId, time: nil),
            selectionId: selectedCardId
        )
    }

    private func inactiveCollapsedGeometry(
        size: CGSize,
        selectedCardId: UUID,
        time: TimeInterval?
    ) -> [UUID: FocusHomeInactiveHeroCollapsedGeometry] {
        Dictionary(
            uniqueKeysWithValues: cards.enumerated()
                .filter { _, card in card.id != selectedCardId }
                .map { index, card in
                    let frame = collapsedFrame(index: index, count: cards.count, in: size)
                    let floating = time.map {
                        floatingTransform(index: index, isSelected: false, time: $0)
                    } ?? (x: 0, y: 0, rotation: 0)
                    return (
                        card.id,
                        FocusHomeInactiveHeroCollapsedGeometry(
                            frame: frame.offsetBy(dx: floating.x, dy: floating.y),
                            rotation: collapsedRotation(index: index) + floating.rotation
                        )
                    )
                }
        )
    }

    private func setInactiveHeroCollapsedGeometry(
        _ next: [UUID: FocusHomeInactiveHeroCollapsedGeometry],
        selectionId: UUID?
    ) {
        guard inactiveHeroCollapsedGeometry != next
                || inactiveHeroCollapsedGeometrySelectionId != selectionId else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            inactiveHeroCollapsedGeometry = next
            inactiveHeroCollapsedGeometrySelectionId = selectionId
        }
        if let selectionId {
            onInactiveCollapsedGeometryFrozen(next, selectionId)
        }
    }

    private func inactiveHeroCollapsedGeometry(for cardId: UUID) -> FocusHomeInactiveHeroCollapsedGeometry? {
        FocusHomeInactiveHeroGeometrySourcePolicy.geometry(
            cardId: cardId,
            selectedCardId: selectedCardId,
            local: inactiveHeroCollapsedGeometry,
            localSelectionId: inactiveHeroCollapsedGeometrySelectionId,
            external: externalInactiveCollapsedGeometry,
            externalSelectionId: externalInactiveCollapsedGeometrySelectionId,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero
        )
    }

    private func arrivalTransform(for card: FocusCard) -> (scale: CGFloat, rotation: Double, flip: Double, y: CGFloat, opacity: Double) {
        guard card.id == animatedArrivalCardId, selectedCardId == nil, !reduceMotion else {
            return (1, 0, 0, 0, 1)
        }
        let p = eased(arrivalProgress)
        return (
            scale: lerp(HomeJoinHandoffMotion.scale, 1, p),
            rotation: Double(lerp(HomeJoinHandoffMotion.rotation, 0, p)),
            flip: Double(lerp(HomeJoinHandoffMotion.flip, 0, p)),
            y: lerp(HomeJoinHandoffMotion.y, 0, p),
            opacity: Double(lerp(HomeJoinHandoffMotion.opacity, 1, p))
        )
    }

    private func visibleCenterX(in geo: GeometryProxy) -> CGFloat {
        geo.size.width / 2
    }

    private func cardLayer(for card: FocusCard, index: Int, in size: CGSize, visibleCenterX: CGFloat, time: TimeInterval) -> some View {
        let isSelected = card.id == selectedCardId
        let motionSnapshot = isSelected ? activeHeroSnapshot : nil
        let renderCard = motionSnapshot?.card ?? card
        let renderIndex = motionSnapshot?.index ?? index
        let isExpandedSurface = isSelected
        let frame = frame(
            for: renderCard,
            index: renderIndex,
            snapshot: motionSnapshot,
            in: size,
            visibleCenterX: visibleCenterX
        )
        let arrival = arrivalTransform(for: renderCard)
        let dragY = isExpandedSurface ? max(0, expandedDragY) : 0
        let frozenInactiveGeometry = isExpandedSurface ? nil : inactiveHeroCollapsedGeometry(for: renderCard.id)
        let freezesInactiveLayer = FocusHomeInactiveHeroLayerPolicy.disablesImplicitAnimations(
            selectedCardId: selectedCardId,
            cardId: renderCard.id,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero
        )
        let floating = frozenInactiveGeometry == nil
            ? floatingTransform(index: renderIndex, isSelected: isSelected, time: time)
            : (x: 0, y: 0, rotation: 0)
        let rotation = rotation(
            for: renderCard,
            index: renderIndex,
            snapshot: motionSnapshot,
            isSelected: isExpandedSurface
        ) + floating.rotation + arrival.rotation
        let scale = (isExpandedSurface ? max(0.94, 1 - dragY / 1400) : inactiveScale(for: renderCard)) * arrival.scale
        let opacity = inactiveOpacity(for: renderCard) * arrival.opacity
        let zIndex = zIndex(for: renderIndex, isSelected: isSelected)
        let visualProgress = isExpandedSurface ? progress : 0
        let cornerRadius = lerp(30, 42, eased(visualProgress))
        let frozenAvatarSource = motionSnapshot?.avatarSource ?? preparedHeroSnapshots[card.id]?.avatarSource
            ?? (selectedCardId == nil ? nil : FocusHomeFrozenAvatarSource.cached(for: renderCard))
        let walkTrackingPet = isExpandedInteractionReady ? walkTrackingPet(for: renderCard, isSelected: isExpandedSurface) : nil
        let embeddedQuickActionsMounted = FocusHomeEmbeddedQuickActionThawPolicy.isMounted(
            progress: visualProgress,
            heroDirection: heroDirection,
            reduceMotion: reduceMotion
        )
        let embeddedQuickActionReveal = FocusHomeEmbeddedQuickActionThawPolicy.reveal(
            progress: visualProgress,
            heroDirection: heroDirection,
            reduceMotion: reduceMotion
        )
        let embeddedQuickActionsReady = FocusHomeEmbeddedQuickActionPresentationPolicy.isInteractive(
            isExpandedInteractionReady: isExpandedInteractionReady,
            reveal: embeddedQuickActionReveal
        )
        let showsEmbeddedQuickActions = FocusHomeEmbeddedQuickActionPresentationPolicy.isVisible(
            embedsQuickActionsInCard: embedsQuickActionsInCard,
            isExpandedSurface: isExpandedSurface,
            hasWalkTrackingCard: walkTrackingPet != nil,
            isMounted: embeddedQuickActionsMounted
        )

        return cardTapLayer(
            FocusHomeWalkCardFlip(
                walkPet: walkTrackingPet,
                reduceMotion: reduceMotion,
                walkCardPadding: 10,
                retainsWalkPetDuringClose: isExpandedInteractionReady,
                onMinimizeToFloatingWalkControl: onWalkCardMinimizeToFloatingControl
            ) {
                ZStack(alignment: .bottom) {
                    FocusHomeVerticalSolidCardSurface(
                        card: renderCard,
                        progress: visualProgress,
                        reduceMotion: reduceMotion,
                        localization: localization,
                        frozenAvatarSource: frozenAvatarSource,
                        allowsLiveAvatarFallback: selectedCardId == nil && motionSnapshot == nil
                    )

                    if embedsQuickActionsInCard,
                       FocusHomeEmbeddedCardCollapseHitPolicy.isMounted(
                           isExpandedSurface: isExpandedSurface,
                           hasWalkTrackingCard: walkTrackingPet != nil
                       ) {
                        embeddedCardCollapseHitLayer(
                            for: renderCard,
                            frame: frame,
                            protectsQuickActionDock: FocusHomeEmbeddedCardCollapseHitPolicy.protectsQuickActionDock(
                                quickActionsAreVisible: showsEmbeddedQuickActions
                            )
                        )
                            .zIndex(10)
                    }

                    if showsEmbeddedQuickActions {
                        embeddedQuickActionLayer(
                            for: renderCard,
                            frame: frame,
                            reveal: embeddedQuickActionReveal,
                            isReady: embeddedQuickActionsReady
                        )
                        .zIndex(24)
                    }

                    if showsDetailButton(for: renderCard, isExpandedSurface: isExpandedSurface, walkTrackingPet: walkTrackingPet) {
                        expandedDetailButton(for: renderCard, frame: frame)
                            .zIndex(16)
                    }
                }
            }
            .id(walkTrackingIdentity(for: renderCard, walkPet: walkTrackingPet))
            .frame(width: frame.width, height: frame.height)
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(.degrees(arrival.flip), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: frame.midX + floating.x, y: frame.midY + dragY + floating.y + arrival.y)
            .zIndex(zIndex)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contextMenu { contextMenu(renderCard) },
            isExpandedSurface: isExpandedSurface,
            walkTrackingPet: walkTrackingPet
        )
        .simultaneousGesture(collapseDragGesture(isEnabled: isExpandedSurface && isExpandedCollapseReady && walkTrackingPet == nil))
        .allowsHitTesting(isExpandedSurface)
        .accessibilityHidden(selectedCardId != nil && !isExpandedSurface)
        .transaction { transaction in
            guard freezesInactiveLayer else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    @ViewBuilder
    private func cardTapLayer(
        _ content: some View,
        isExpandedSurface: Bool,
        walkTrackingPet: Pet?
    ) -> some View {
        if embedsQuickActionsInCard {
            content
        } else {
            content
                .onTapGesture {
                    guard walkTrackingPet == nil else { return }
                    handleCardTap(isSelected: isExpandedSurface)
                }
        }
    }

    private func walkTrackingPet(for card: FocusCard, isSelected: Bool) -> Pet? {
        guard isSelected,
              !card.isHuman,
              appServices.walking.isWalkCardExpandedSurfaceVisible,
              let walkingPet = appServices.walking.currentPet,
              walkingPet.id == card.id,
              !walkingPet.hasPassedAway else {
            return nil
        }

        switch appServices.walking.phase {
        case .running, .paused, .finished:
            return walkingPet
        case .idle:
            return nil
        }
    }

    private func walkTrackingIdentity(for card: FocusCard, walkPet: Pet?) -> String {
        [
            card.id.uuidString,
            walkPet?.id.uuidString ?? "none",
            FocusHomeWalkCardIdentityPolicy.phaseKey(appServices.walking.phase),
            "\(walkPresentationRevision)",
            "\(appServices.walkingPresentationRevision)"
        ].joined(separator: "#")
    }

    private func handleCardTap(isSelected: Bool) {
        guard isSelected else { return }
        onCollapse()
    }

    private var canFloatCards: Bool {
        surfaceGate.allowsAmbientMotion
    }

    private var surfaceGate: SurfaceActivityGate {
        workloadPolicy.surfaceGate(
            isVisible: FocusHomeAmbientFloatPolicy.isSurfaceVisibleForAmbient(
                isVisible: isVisible,
                selectedCardId: selectedCardId,
                progress: progress
            ),
            isCovered: FocusHomeAmbientFloatPolicy.isSurfaceCovered(
                selectedCardId: selectedCardId,
                progress: progress
            ),
            isLive: isVisible,
            allowsAmbientOptIn: FocusHomeAmbientFloatPolicy.allowsAmbientOptIn(
                isEnabled: allowsAmbientFloat,
                reduceMotion: reduceMotion
            )
        )
    }

    private func primeFloatingMotionIfVisible() {
        guard canFloatCards else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            floatingResumeStartTime = Date().timeIntervalSinceReferenceDate
        }
    }

    private func quickActionLayer(for card: FocusCard, in size: CGSize, visibleCenterX: CGFloat) -> some View {
        let frame = expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX)
        let reveal = reduceMotion ? 1 : smooth(progress, 0.42, 0.72)
        let quickHeight = CGFloat(132)
        let width = min(size.width - 18, 380)
        let y = min(size.height - safeBottom - 122, frame.maxY + 92)
        return FocusHomeVerticalSolidQuickActionLayer(
            content: quickActions(card),
            width: width,
            height: quickHeight,
            reveal: reveal,
            isReady: isExpandedInteractionReady
        )
        .position(x: frame.midX, y: y)
    }

    private func embeddedQuickActionLayer(
        for card: FocusCard,
        frame: CGRect,
        reveal: CGFloat,
        isReady: Bool
    ) -> some View {
        let dockWidth = max(0, frame.width - 18)
        let dockHeight = embeddedQuickActionDockHeight(for: frame)
        return FocusHomeVerticalSolidQuickActionLayer(
            content: quickActions(card),
            width: dockWidth,
            height: dockHeight,
            reveal: reveal,
            isReady: isReady
        )
        .padding(.horizontal, 11)
        .padding(.bottom, 8)
        .offset(y: (1 - reveal) * 18)
        .zIndex(12)
    }

    private func embeddedCardCollapseHitLayer(
        for card: FocusCard,
        frame: CGRect,
        protectsQuickActionDock: Bool
    ) -> some View {
        let hitHeight = FocusHomeEmbeddedCardCollapseHitPolicy.hitHeight(
            frameHeight: frame.height,
            quickActionDockHeight: embeddedQuickActionDockHeight(for: frame),
            protectsQuickActionDock: protectsQuickActionDock
        )

        return Rectangle()
            .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible expanded card collapse hit zone without covering embedded actions
            .contentShape(Rectangle())
            .frame(width: frame.width, height: hitHeight)
            .offset(y: -(frame.height - hitHeight))
            .onTapGesture {
                OhanaFeedback.light()
                onCollapse()
            }
            .accessibilityLabel(card.name)
            .accessibilityIdentifier(expandedCollapseAccessibilityIdentifier(for: card))
            .accessibilityHint(l.tr(
                zh: "点击返回首页",
                en: "Tap to return home",
                de: "Tippen, um zur Startseite zurückzukehren"
            ))
            .accessibilityAddTraits(.isButton)
    }

    private func showsDetailButton(
        for card: FocusCard,
        isExpandedSurface: Bool,
        walkTrackingPet: Pet?
    ) -> Bool {
        let isMounted = reduceMotion ? progress > 0.5 : progress > 0.58
        return isExpandedSurface
            && isMounted
            && walkTrackingPet == nil
            && !card.isElectronicPet
    }

    private func expandedDetailButton(for card: FocusCard, frame: CGRect) -> some View {
        let reveal = reduceMotion ? 1 : smooth(progress, 0.58, 0.78)
        return VStack {
            HStack {
                Spacer(minLength: 0)
                Button {
                    OhanaFeedback.light()
                    onOpenDetails(card)
                } label: {
                    Image(systemName: detailButtonIcon(for: card))
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.arkInk.opacity(0.42))
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.goCardWhite.opacity(0.28), lineWidth: 1)
                                }
                        )
                        .shadow(color: Color.arkInk.opacity(0.24), radius: 10, x: 0, y: 6) // ui-v4: allow floating detail button depth over saturated member card
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(detailButtonAccessibilityLabel(for: card))
                .accessibilityIdentifier(expandedDetailAccessibilityIdentifier(for: card))
                .accessibilityHint(l.tr(
                    zh: "打开这张卡片的资料页",
                    en: "Open this card's detail page",
                    de: "Detailseite dieser Karte öffnen"
                ))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
        .padding(.trailing, 14)
        .frame(width: frame.width, height: frame.height, alignment: .topTrailing)
        .opacity(Double(reveal))
        .allowsHitTesting(isExpandedCollapseReady)
    }

    private func detailButtonIcon(for card: FocusCard) -> String {
        if card.isPlant { return "leaf.circle.fill" }
        return card.isHuman ? "person.crop.circle.fill" : "pawprint.circle.fill"
    }

    private func detailButtonAccessibilityLabel(for card: FocusCard) -> String {
        if card.isPlant {
            return l.tr(zh: "打开植物详情", en: "Open plant details", de: "Pflanzendetails öffnen")
        }
        if card.isHuman {
            return l.tr(zh: "打开人类详情", en: "Open human details", de: "Menschendetails öffnen")
        }
        return l.tr(zh: "打开宠物详情", en: "Open pet details", de: "Haustierdetails öffnen")
    }

    private func expandedDetailAccessibilityIdentifier(for card: FocusCard) -> String {
        if card.isPlant { return "home-expanded-detail-plant" }
        return card.isHuman ? "home-expanded-detail-human" : "home-expanded-detail-pet"
    }

    private func expandedCollapseAccessibilityIdentifier(for card: FocusCard) -> String {
        if card.isPlant { return "home-expanded-collapse-plant" }
        return card.isHuman ? "home-expanded-collapse-human" : "home-expanded-collapse-pet"
    }

    private func cardAccessibilityIdentifier(for card: FocusCard) -> String {
        let kind = if card.isPlant {
            "plant"
        } else if card.isHuman {
            "human"
        } else {
            "pet"
        }
        return "home-card-\(kind)-\(card.name)"
    }

    private func embeddedQuickActionDockHeight(for frame: CGRect) -> CGFloat {
        min(max(frame.height * 0.34, 188), 224)
    }

    private func collapsedHitLayer(in size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let frame = collapsedFrame(index: index, count: cards.count, in: size)
                let floating = floatingTransform(index: index, isSelected: false, time: time)
                let cornerRadius = CGFloat(30)
                let inactiveGeometry = freezesInactiveCollapsedGeometryDuringHero
                    ? inactiveCollapsedGeometry(
                        size: size,
                        selectedCardId: card.id,
                        time: time
                    )
                    : [:]

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible vertical home card hit zone
                    .frame(width: frame.width, height: frame.height)
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .rotationEffect(.degrees(collapsedRotation(index: index) + floating.rotation))
                    .position(x: frame.midX + floating.x, y: frame.midY + floating.y)
                    .zIndex(100 + collapsedZIndex(index: index, count: cards.count))
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                if freezesInactiveCollapsedGeometryDuringHero {
                                    setInactiveHeroCollapsedGeometry(inactiveGeometry, selectionId: card.id)
                                }
                                onSelect(
                                    preparedHeroSnapshot(for: card, index: index)
                                        .freezingCollapsedGeometry(
                                            frame: frame.offsetBy(dx: floating.x, dy: floating.y),
                                            rotation: collapsedRotation(index: index) + floating.rotation,
                                            inactiveCollapsedGeometry: inactiveGeometry
                                        )
                                )
                            }
                    )
                    .accessibilityLabel(card.name)
                    .accessibilityIdentifier(cardAccessibilityIdentifier(for: card))
                    .accessibilityHint(l.tr(
                        zh: "点击放大卡片",
                        en: "Tap to expand card",
                        de: "Tippen, um die Karte zu vergrößern"
                    ))
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func frame(
        for card: FocusCard,
        index: Int,
        snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        in size: CGSize,
        visibleCenterX: CGFloat
    ) -> CGRect {
        let stableCollapsed = collapsedFrame(index: index, count: cards.count, in: size)
        let preparedCollapsed = FocusHomeInactiveHeroGeometryPolicy.collapsedFrame(
            stableFrame: stableCollapsed,
            preparedFrame: preparedHeroSnapshots[card.id]?.collapsedFrame,
            frozenFrame: inactiveHeroCollapsedGeometry(for: card.id)?.frame,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero,
            selectedCardId: selectedCardId,
            cardId: card.id
        )
        guard card.id == selectedCardId else {
            return selectedCardId == nil ? stableCollapsed : preparedCollapsed
        }

        let collapsed = collapsedFrame(for: snapshot, stableFrame: stableCollapsed)
        if reduceMotion {
            return progress > 0.5 ? expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX) : collapsed
        }

        let expanded = expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX)
        return WalletHeroTimeline.activeFrame(from: collapsed, to: expanded, progress: progress)
    }

    private func collapsedFrame(
        for snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        stableFrame: CGRect
    ) -> CGRect {
        snapshot?.collapsedFrame ?? stableFrame
    }

    private func zIndex(for index: Int, isSelected: Bool) -> Double {
        guard isSelected else {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if embedsQuickActionsInCard, heroDirection > 0 {
            return expandedCardZIndex()
        }

        if progress <= 0.001 {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if heroDirection < 0, progress < 0.035 {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if embedsQuickActionsInCard {
            return expandedCardZIndex()
        }

        return 24
    }

    private func expandedCardZIndex() -> Double {
        let inactiveMax = (0 ..< cards.count)
            .map { collapsedZIndex(index: $0, count: cards.count) }
            .max() ?? 0
        return max(24, inactiveMax + 40)
    }

    private func rotation(
        for card: FocusCard,
        index: Int,
        snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        isSelected: Bool
    ) -> Double {
        let stableCollapsed = collapsedRotation(index: index)
        guard isSelected, selectedCardId != nil else {
            return FocusHomeInactiveHeroRotationPolicy.rotation(
                stableRotation: stableCollapsed,
                frozenRotation: inactiveHeroCollapsedGeometry(for: card.id)?.rotation,
                freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero,
                selectedCardId: selectedCardId,
                cardId: card.id
            )
        }

        let collapsed = snapshot?.collapsedRotation ?? stableCollapsed
        if reduceMotion {
            return progress > 0.5 ? 0 : collapsed
        }

        return collapsed * Double(1 - eased(progress))
    }

    private func preparedHeroSnapshot(for card: FocusCard, index: Int) -> FocusHomeVerticalSolidHeroSnapshot {
        preparedHeroSnapshots[card.id] ?? FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private func collapsedFrame(index: Int, count: Int, in size: CGSize) -> CGRect {
        let availableHeight = max(260, size.height - collapsedTopInset)
        let offsets = collapsedOffsets(count: count)
        let safeIndex = min(max(index, 0), max(offsets.count - 1, 0))
        let offset = offsets[safeIndex]
        let xValues = offsets.map(\.width)
        let yValues = offsets.map(\.height)
        let horizontalSpan = max(1.0, (xValues.max() ?? 0) - (xValues.min() ?? 0) + 1.0)
        let verticalSpan = max(1.58, (yValues.max() ?? 0) - (yValues.min() ?? 0) + 1.58)
        let preferredWidth = min(max(size.width * (count <= 1 ? 0.43 : 0.37), 112), count >= 5 ? 144 : 166)
        let width = max(
            104,
            min(
                preferredWidth,
                max(104, (size.width - 24) / horizontalSpan),
                max(104, (availableHeight - 18) / verticalSpan)
            )
        )
        let height = width * 1.58
        let verticalBias = availableHeight * FocusHomeVerticalSolidCollapsedLayoutPolicy.clampedVerticalBias(collapsedVerticalBias)
        let center = CGPoint(
            x: size.width / 2,
            y: collapsedTopInset + availableHeight / 2 + verticalBias
        )
        let x = center.x + offset.width * width
        let y = center.y + offset.height * width
        return CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }

    private func expandedFrame(for _: FocusCard?, in size: CGSize, visibleCenterX: CGFloat) -> CGRect {
        let aspectRatio: CGFloat = 1.58
        let maxWidth: CGFloat = embedsQuickActionsInCard ? 386 : 390
        let horizontalInset: CGFloat = embedsQuickActionsInCard ? 18 : 22
        let topInset = safeTop
        let bottomInset = embedsQuickActionsInCard ? CGFloat(0) : safeBottom + 28
        let availableWidth = max(220, size.width - horizontalInset)
        let availableHeight = max(320, size.height - topInset - bottomInset)
        let width = min(availableWidth, maxWidth, availableHeight / aspectRatio)
        let height = width * aspectRatio
        let targetY = topInset + availableHeight / 2 - (embedsQuickActionsInCard ? 2 : 0)
        return CGRect(
            x: visibleCenterX - width / 2,
            y: targetY - height / 2,
            width: width,
            height: height
        )
    }

    private func collapsedOffsets(count: Int) -> [CGSize] {
        switch min(max(count, 1), 6) {
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
        case 4:
            [
                CGSize(width: -0.62, height: -0.62),
                CGSize(width: 0.62, height: -0.62),
                CGSize(width: -0.62, height: 0.62),
                CGSize(width: 0.62, height: 0.62)
            ]
        case 5:
            [
                CGSize(width: -0.84, height: -0.98),
                CGSize(width: 0.78, height: -0.86),
                CGSize(width: -0.88, height: 0.34),
                CGSize(width: 0.88, height: 0.42),
                CGSize(width: -0.06, height: 1.02)
            ]
        default:
            [
                CGSize(width: -0.92, height: -1.12),
                CGSize(width: 0.72, height: -0.88),
                CGSize(width: -1.03, height: -0.02),
                CGSize(width: 0.92, height: 0.28),
                CGSize(width: -0.54, height: 1.18),
                CGSize(width: 0.98, height: 0.92)
            ]
        }
    }

    private func collapsedRotation(index: Int) -> Double {
        let rotations: [Double] = [-10.5, 6.8, -3.2, 9.6, 4.8, -7.4]
        return rotations[index % rotations.count]
    }

    private func collapsedZIndex(index: Int, count: Int) -> Double {
        if count >= 5 {
            let offsets = collapsedOffsets(count: count)
            let safeIndex = min(max(index, 0), max(offsets.count - 1, 0))
            return Double(offsets[safeIndex].height * 100) + Double(safeIndex) * 0.01
        }

        let depths: [Double] = [6, 5, 4, 3, 2, 1]
        return depths[index % depths.count]
    }

    private func floatingTransform(index: Int, isSelected: Bool, time: TimeInterval) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        guard canFloatCards, !isSelected else { return (0, 0, 0) }
        let resume = floatingResumeProgress(at: time)
        let wave = sin(time * 0.72 + Double(index) * 1.27)
        return (0, CGFloat(wave) * 2.8 * resume, 0)
    }

    private func floatingResumeProgress(at time: TimeInterval) -> CGFloat {
        guard let start = floatingResumeStartTime else { return 1 }
        let progress = CGFloat((time - start) / 0.30)
        return eased(progress)
    }

    private func inactiveOpacity(for card: FocusCard) -> Double {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        return reduceMotion ? 0 : Double(1 - smooth(progress, 0, 0.16))
    }

    private func inactiveScale(for card: FocusCard) -> CGFloat {
        FocusHomeInactiveHeroVisualPolicy.scale(
            selectedCardId: selectedCardId,
            cardId: card.id,
            progress: progress,
            reduceMotion: reduceMotion,
            freezesInactiveGeometry: freezesInactiveCollapsedGeometryDuringHero
        )
    }

    private func collapseDragGesture(isEnabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($expandedDragY) { value, state, _ in
                guard isEnabled, value.translation.height > 0 else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard isEnabled else { return }
                if value.translation.height > 84 || value.predictedEndTranslation.height > 150 {
                    onCollapse()
                }
            }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func eased(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private func smooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return eased((value - start) / (end - start))
    }
}
