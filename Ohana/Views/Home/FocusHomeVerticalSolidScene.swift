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

    init(
        card: FocusCard,
        index: Int,
        avatarSource: FocusHomeFrozenAvatarSource,
        collapsedFrame: CGRect? = nil,
        collapsedRotation: Double? = nil
    ) {
        self.card = card
        self.index = index
        self.avatarSource = avatarSource
        self.collapsedFrame = collapsedFrame
        self.collapsedRotation = collapsedRotation
    }

    func freezingCollapsedGeometry(frame: CGRect, rotation: Double) -> FocusHomeVerticalSolidHeroSnapshot {
        FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: avatarSource,
            collapsedFrame: frame,
            collapsedRotation: rotation
        )
    }

    func preservingCollapsedGeometry(from snapshot: FocusHomeVerticalSolidHeroSnapshot?) -> FocusHomeVerticalSolidHeroSnapshot {
        FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: avatarSource,
            collapsedFrame: snapshot?.collapsedFrame ?? collapsedFrame,
            collapsedRotation: snapshot?.collapsedRotation ?? collapsedRotation
        )
    }

    func updatingCard(_ nextCard: FocusCard) -> FocusHomeVerticalSolidHeroSnapshot {
        FocusHomeVerticalSolidHeroSnapshot(
            card: nextCard,
            index: index,
            avatarSource: avatarSource,
            collapsedFrame: collapsedFrame,
            collapsedRotation: collapsedRotation
        )
    }
}

enum FocusHomeEmbeddedQuickActionThawPolicy {
    static let openingMountProgress: CGFloat = 0.985
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
        return WalletHeroTimeline.smooth(progress, openingMountProgress, 1)
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

struct FocusHomeVerticalSolidScene<QuickActions: View, ContextMenuContent: View>: View {
    let cards: [FocusCard]
    let pets: [Pet]
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let selectedCardId: UUID?
    var preparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    var heroSnapshot: FocusHomeVerticalSolidHeroSnapshot? = nil
    let progress: CGFloat
    var heroDirection: Int = 0
    var arrivingCardId: UUID? = nil
    let reduceMotion: Bool
    let localization: L10n
    let allowsAmbientFloat: Bool
    var isVisible: Bool = true
    var embedsQuickActionsInCard: Bool = false
    var collapsedTopInset: CGFloat = 0
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusHomeVerticalSolidHeroSnapshot) -> Void
    let onCollapse: () -> Void
    let onLongPress: (FocusCard) -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var floatingResumeStartTime: TimeInterval?
    @State private var animatedArrivalCardId: UUID?
    @State private var arrivalProgress: CGFloat = 1
    @State private var arrivalCleanupTask: Task<Void, Never>?
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
           heroSnapshot.card.id == selectedCardId
        {
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
            }
            .onChange(of: selectedCardId) { _, newValue in
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
            isVisible ? "visible" : "hidden",
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

    private func arrivalTransform(for card: FocusCard) -> (scale: CGFloat, rotation: Double, flip: Double, y: CGFloat, opacity: Double) {
        guard card.id == animatedArrivalCardId, selectedCardId == nil, !reduceMotion else {
            return (1, 0, 0, 0, 1)
        }
        let p = eased(arrivalProgress)
        return (
            scale: lerp(0.64, 1, p),
            rotation: Double(lerp(7, 0, p)),
            flip: Double(lerp(-76, 0, p)),
            y: lerp(42, 0, p),
            opacity: Double(lerp(0.18, 1, p))
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
        let floating = floatingTransform(index: renderIndex, isSelected: isSelected, time: time)
        let rotation = rotation(for: renderIndex, snapshot: motionSnapshot, isSelected: isExpandedSurface) + floating.rotation + arrival.rotation
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
        let showsEmbeddedQuickActions = embedsQuickActionsInCard
            && isExpandedSurface
            && walkTrackingPet == nil
            && embeddedQuickActionsMounted
            && embeddedQuickActionReveal > 0.001

        return FocusHomeWalkCardFlip(
            walkPet: walkTrackingPet,
            reduceMotion: reduceMotion,
            walkCardPadding: 10,
            retainsWalkPetDuringClose: isExpandedInteractionReady
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

                if embedsQuickActionsInCard && isExpandedSurface && isExpandedCollapseReady && walkTrackingPet == nil {
                    embeddedCardCollapseHitLayer(for: renderCard, frame: frame)
                        .zIndex(10)
                }

                if showsEmbeddedQuickActions {
                    embeddedQuickActionLayer(for: renderCard, frame: frame, reveal: embeddedQuickActionReveal)
                }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(rotation))
        .rotation3DEffect(.degrees(arrival.flip), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
        .scaleEffect(scale)
        .opacity(opacity)
        .position(x: frame.midX + floating.x, y: frame.midY + dragY + floating.y + arrival.y)
        .zIndex(zIndex)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contextMenu { contextMenu(renderCard) }
        .onTapGesture {
            guard !embedsQuickActionsInCard else { return }
            guard walkTrackingPet == nil else { return }
            handleCardTap(isSelected: isExpandedSurface)
        }
        .onLongPressGesture {
            handleCardLongPress(renderCard, isSelected: isExpandedSurface)
        }
        .simultaneousGesture(collapseDragGesture(isEnabled: isExpandedSurface && isExpandedCollapseReady && walkTrackingPet == nil))
        .allowsHitTesting(isExpandedSurface)
    }

    private func walkTrackingPet(for card: FocusCard, isSelected: Bool) -> Pet? {
        FocusHomeWalletCardContent.walkTrackingPet(for: card, isHero: isSelected, pets: pets)
    }

    private func handleCardTap(isSelected: Bool) {
        guard isSelected else { return }
        onCollapse()
    }

    private func handleCardLongPress(_ card: FocusCard, isSelected: Bool) {
        guard isSelected else { return }
        onLongPress(card)
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

    private func embeddedQuickActionLayer(for card: FocusCard, frame: CGRect, reveal: CGFloat) -> some View {
        let dockWidth = max(0, frame.width - 18)
        let dockHeight = embeddedQuickActionDockHeight(for: frame)
        return FocusHomeVerticalSolidQuickActionLayer(
            content: quickActions(card),
            width: dockWidth,
            height: dockHeight,
            reveal: reveal,
            isReady: isExpandedInteractionReady
        )
        .padding(.horizontal, 11)
        .padding(.bottom, 8)
        .offset(y: (1 - reveal) * 18)
        .zIndex(12)
    }

    private func embeddedCardCollapseHitLayer(for card: FocusCard, frame: CGRect) -> some View {
        let protectedBottomHeight = embeddedQuickActionDockHeight(for: frame) + 42
        let hitHeight = max(44, frame.height - protectedBottomHeight)

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible expanded card collapse hit zone
                .contentShape(Rectangle())
                .frame(width: frame.width, height: hitHeight)
                .onTapGesture {
                    OhanaFeedback.light()
                    onCollapse()
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    OhanaFeedback.medium()
                    onLongPress(card)
                }
                .accessibilityLabel(card.name)
                .accessibilityHint(l.tr(
                    zh: "点击返回首页",
                    en: "Tap to return home",
                    de: "Tippen, um zur Startseite zurückzukehren"
                ))
                .accessibilityAddTraits(.isButton)

            Spacer(minLength: 0)
        }
        .frame(width: frame.width, height: frame.height, alignment: .top)
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
                                onSelect(
                                    preparedHeroSnapshot(for: card, index: index)
                                        .freezingCollapsedGeometry(
                                            frame: frame.offsetBy(dx: floating.x, dy: floating.y),
                                            rotation: collapsedRotation(index: index) + floating.rotation
                                        )
                                )
                            }
                    )
                    .accessibilityLabel(card.name)
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
        guard card.id == selectedCardId else {
            return stableCollapsed
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
        return snapshot?.collapsedFrame ?? stableFrame
    }

    private func zIndex(for index: Int, isSelected: Bool) -> Double {
        guard isSelected else {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if progress <= 0.001 {
            return collapsedZIndex(index: index, count: cards.count)
        }

        if heroDirection < 0, progress < 0.035 {
            return collapsedZIndex(index: index, count: cards.count)
        }

        return 24
    }

    private func rotation(
        for index: Int,
        snapshot: FocusHomeVerticalSolidHeroSnapshot?,
        isSelected: Bool
    ) -> Double {
        let stableCollapsed = collapsedRotation(index: index)
        guard isSelected, selectedCardId != nil else {
            return stableCollapsed
        }

        let collapsed = heroDirection > 0 ? (snapshot?.collapsedRotation ?? stableCollapsed) : stableCollapsed
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
        let center = CGPoint(x: size.width / 2, y: collapsedTopInset + availableHeight / 2)
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
            return [CGSize(width: 0, height: 0)]
        case 2:
            return [
                CGSize(width: -0.58, height: -0.05),
                CGSize(width: 0.58, height: 0.05),
            ]
        case 3:
            return [
                CGSize(width: -0.62, height: -0.58),
                CGSize(width: 0.62, height: -0.54),
                CGSize(width: 0, height: 0.62),
            ]
        case 4:
            return [
                CGSize(width: -0.62, height: -0.62),
                CGSize(width: 0.62, height: -0.62),
                CGSize(width: -0.62, height: 0.62),
                CGSize(width: 0.62, height: 0.62),
            ]
        case 5:
            return [
                CGSize(width: -0.84, height: -0.98),
                CGSize(width: 0.78, height: -0.86),
                CGSize(width: -0.88, height: 0.34),
                CGSize(width: 0.88, height: 0.42),
                CGSize(width: -0.06, height: 1.02),
            ]
        default:
            return [
                CGSize(width: -0.92, height: -1.12),
                CGSize(width: 0.72, height: -0.88),
                CGSize(width: -1.03, height: -0.02),
                CGSize(width: 0.92, height: 0.28),
                CGSize(width: -0.54, height: 1.18),
                CGSize(width: 0.98, height: 0.92),
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
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        return reduceMotion ? 1 : 1 - smooth(progress, 0, 0.16) * 0.08
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

private struct FocusHomeVerticalSolidQuickActionLayer<Content: View>: View {
    let content: Content
    let width: CGFloat
    let height: CGFloat
    let reveal: CGFloat
    let isReady: Bool

    var body: some View {
        let base = content
            .transaction { transaction in
                transaction.animation = nil
            }
            .frame(width: width, alignment: .top)
            .frame(height: height, alignment: .top)
            .opacity(isReady ? 1 : Double(reveal))
            .allowsHitTesting(isReady)

        if isReady {
            base
        } else {
            base.clipShape(WalletHeroRevealShape(reveal: reveal))
        }
    }
}

struct FocusHomeFrozenAvatarSource {
    let image: UIImage?
    let isTransparent: Bool

    static let placeholder = FocusHomeFrozenAvatarSource(image: nil, isTransparent: true)

    @MainActor
    static func cached(for card: FocusCard) -> FocusHomeFrozenAvatarSource? {
        guard let entry = FocusWalletAvatarCache.cachedEntry(for: card.id, signature: card.avatarImageSignature),
              entry.image != nil else {
            return nil
        }
        return FocusHomeFrozenAvatarSource(image: entry.image, isTransparent: entry.isTransparent)
    }

    @MainActor
    static func live(for card: FocusCard) -> FocusHomeFrozenAvatarSource {
        cached(for: card) ?? .placeholder
    }
}

private struct FocusHomeVerticalSolidCardSurface: View {
    let card: FocusCard
    let progress: CGFloat
    let reduceMotion: Bool
    let localization: L10n
    let frozenAvatarSource: FocusHomeFrozenAvatarSource?
    var allowsLiveAvatarFallback: Bool = true

    private var accent: Color {
        return card.themeColorHex.isEmpty ? card.color : Color(hex: card.themeColorHex)
    }

    private var visualProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var l: L10n {
        localization
    }

    private var cornerRadius: CGFloat {
        lerp(30, 44, visualProgress)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let p = visualProgress
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let avatarSource = frozenAvatarSource
                ?? (allowsLiveAvatarFallback ? FocusHomeFrozenAvatarSource.live(for: card) : .placeholder)
            let usesFullWidthPhoto = avatarSource.image != nil && !avatarSource.isTransparent

            ZStack(alignment: .topLeading) {
                shape
                    .fill(cardGradient)
                    .overlay {
                        shape
                            .strokeBorder(borderGradient, lineWidth: lerp(1, 1.25, p))
                    }

                if let image = avatarSource.image, usesFullWidthPhoto {
                    WalletCardVerticalPhotoBlendLayer(
                        image: image,
                        width: w,
                        height: h,
                        themeColorHex: card.themeColorHex,
                        shadowDepth: lerp(0.90, 1.08, p)
                    )
                    .zIndex(1)
                }

                bottomQuickActionGradient(height: h, progress: p)
                    .zIndex(2)

                VStack(alignment: .leading, spacing: 0) {
                    header(progress: p)
                        .padding(.top, lerp(16, 24, p))
                        .padding(.horizontal, lerp(15, 22, p))

                    Spacer(minLength: 0)

                    avatar(image: avatarSource.image, transparent: avatarSource.isTransparent, width: w, height: h)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(x: avatarHorizontalOffset(width: w, progress: p))
                        .frame(height: h * lerp(0.42, 0.36, p))
                        .padding(.leading, lerp(10, 18, p))
                        .padding(.trailing, lerp(10, 18, p))

                    bottomInfo(progress: p)
                        .padding(.horizontal, lerp(15, 18, p))
                        .padding(.bottom, lerp(16, 236, p))
                }
                .zIndex(4)

                rightInfoColumn(width: w, height: h, progress: p)
                    .zIndex(5)
            }
            .clipShape(shape)
            .saturation(card.hasPassedAway ? 0 : 1)
            .shadow(color: Color.arkInk.opacity(lerp(0.20, 0.28, p)), radius: lerp(15, 24, p), x: 0, y: lerp(10, 18, p)) // ui-v4: allow intentional home card depth
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name), \(card.kind)")
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.mix(with: .white, by: lerp(0.10, 0.12, visualProgress)),
                accent,
                accent.mix(with: .black, by: lerp(0.30, 0.34, visualProgress)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.goCardWhite.opacity(lerp(0.20, 0.28, visualProgress)),
                accent.mix(with: .white, by: 0.12).opacity(lerp(0.42, 0.58, visualProgress)),
                Color.arkInk.opacity(lerp(0.12, 0.18, visualProgress)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func header(progress p: CGFloat) -> some View {
        let reveal = expandedContentProgress(p)
        let compactHeaderOpacity = Double(1 - reveal)
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: lerp(3, 4, p)) {
                Text(card.name)
                    .font(.system(size: lerp(17, 28, p), weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .shadow(color: Color.arkInk.opacity(0.58), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text

                Text(card.kind)
                    .font(.system(size: lerp(9, 12, p), weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .shadow(color: Color.arkInk.opacity(0.46), radius: 4, x: 0, y: 1) // ui-v4: allow requested legibility shadow on card text
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(compactHeaderOpacity)

            Spacer(minLength: 0)

            Text(statusBadge)
                .font(.system(size: lerp(10, 12, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, lerp(9, 12, p))
                .padding(.vertical, lerp(5, 7, p))
                .background(statusBadgeBackground, in: Capsule())
                .shadow(color: Color.arkInk.opacity(0.58), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
        }
    }

    @ViewBuilder
    private func avatar(image: UIImage?, transparent: Bool, width: CGFloat, height: CGFloat) -> some View {
        let avatarWidth = width * (card.isHuman ? lerp(0.56, 0.66, visualProgress) : lerp(0.68, 0.88, visualProgress))
        let avatarHeight = height * (card.isHuman ? lerp(0.42, 0.46, visualProgress) : lerp(0.48, 0.58, visualProgress))
        if image != nil, !transparent {
            Color.clear
                .frame(
                    width: avatarWidth,
                    height: avatarHeight,
                    alignment: .bottom
                )
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(
                    width: avatarWidth,
                    height: avatarHeight,
                    alignment: .bottom
                )
                .offset(y: card.isHuman ? lerp(0, -20, visualProgress) : lerp(0, -34, visualProgress))
                .shadow(color: Color.goCardWhite.opacity(transparent ? 0.20 : 0.08), radius: 3, y: 0) // ui-v4: allow intentional avatar cutout crispness
                .shadow(color: Color.arkInk.opacity(transparent ? 0.28 : 0.16), radius: 18, y: 12) // ui-v4: allow intentional avatar depth
        } else {
            Image(systemName: avatarSymbol)
                .font(.system(size: width * lerp(0.43, 0.47, visualProgress), weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.92))
                .frame(width: width * 0.78, height: height * 0.36)
        }
    }

    private func avatarHorizontalOffset(width: CGFloat, progress p: CGFloat) -> CGFloat {
        let leadingPadding = lerp(CGFloat(10), CGFloat(18), p)
        let trailingPadding = lerp(CGFloat(10), CGFloat(18), p)
        let baseCenterOffset = (trailingPadding - leadingPadding) / 2
        let expandedShift = card.isHuman ? CGFloat(0) : -width * (card.isElectronicPet ? 0.045 : 0.085)
        return baseCenterOffset + lerp(0, expandedShift, p)
    }

    private func rightInfoColumn(width: CGFloat, height: CGFloat, progress p: CGFloat) -> some View {
        let reveal = smooth(p, 0.30, 0.64)
        let sideWidth = max(128, width * 0.46)
        return VStack(alignment: .trailing, spacing: lerp(3, 5, p)) {
            Spacer(minLength: 0)
            if card.isHuman {
                humanInfoStack(progress: p)
            } else if card.isElectronicPet {
                electronicPetInfoStack(progress: p)
            } else {
                petInfoStack(progress: p)
            }
        }
        .padding(.trailing, 18)
        .padding(.bottom, lerp(22, 250, p))
        .frame(width: sideWidth, height: height, alignment: .bottomTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(Double(reveal))
        .scaleEffect(lerp(0.985, 1, reveal), anchor: .bottomTrailing)
        .offset(y: lerp(8, 0, reveal))
        .allowsHitTesting(false)
    }

    private func humanInfoStack(progress p: CGFloat) -> some View {
        let details = [card.zodiacText, card.mbtiText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return VStack(alignment: .trailing, spacing: lerp(3, 5, p)) {
            Text(details.first ?? "OHANA MEMBER")
                .font(.system(size: lerp(15, 20, p), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text

            if details.count > 1 {
                Text(details.dropFirst().joined(separator: " · "))
                    .font(.system(size: lerp(9, 11, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }
        }
    }

    private func petInfoStack(progress p: CGFloat) -> some View {
        let meta = [card.humanEquivalentAgeText, card.zodiacText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "未知" }
        return VStack(alignment: .trailing, spacing: lerp(4, 7, p)) {
            petAgeMetric(progress: p)

            Text(petTogetherHeadline)
                .font(.system(size: lerp(15, 20, p), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty
            {
                Text(hint)
                    .font(.system(size: lerp(8.5, 10.5, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.82))
                    .lineLimit(p > 0.72 ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }

            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(.system(size: lerp(8.5, 10, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.76))
                    .lineLimit(p > 0.72 ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }
        }
    }

    @ViewBuilder
    private func petAgeMetric(progress p: CGFloat) -> some View {
        if let age = expandedAgeParts {
            HStack(alignment: .firstTextBaseline, spacing: lerp(3, 5, p)) {
                Text(age.number)
                    .font(.system(size: lerp(26, 52, p), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())

                Text(age.unit)
                    .font(.system(size: lerp(10, 16, p), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(cardPrimaryText)
            .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text
        }
    }

    private var expandedAgeParts: (number: String, unit: String)? {
        guard let rawAge = card.ageText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawAge.isEmpty
        else {
            return nil
        }
        let numberPrefix = rawAge.prefix { character in
            character.isNumber || character == "." || character == ","
        }
        guard !numberPrefix.isEmpty else {
            return nil
        }
        let unit = rawAge
            .dropFirst(numberPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            number: String(numberPrefix),
            unit: unit.isEmpty ? l.tr(zh: "岁", en: "year", de: "Jahr") : unit
        )
    }

    private func electronicPetInfoStack(progress p: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: lerp(3, 5, p)) {
            Text(l.tr(zh: "电子宠物", en: "Critter", de: "Critter"))
                .font(.system(size: lerp(15, 20, p), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText)
                .lineLimit(1)
                .shadow(color: Color.arkInk.opacity(0.55), radius: 5, x: 0, y: 2) // ui-v4: allow readability shadow on image card text

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty
            {
                Text(hint)
                    .font(.system(size: lerp(8.5, 10.5, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }

            if let ageText = card.ageText {
                Text(ageText)
                    .font(.system(size: lerp(8.5, 10, p), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(opacity: 0.76))
                    .lineLimit(1)
                    .shadow(color: Color.arkInk.opacity(0.42), radius: 4, x: 0, y: 1) // ui-v4: allow readability shadow on image card text
            }
        }
    }

    @ViewBuilder
    private func bottomInfo(progress p: CGFloat) -> some View {
        let reveal = expandedContentProgress(p)
        compactFooter(progress: p)
            .opacity(Double(1 - reveal))
    }

    private func compactFooter(progress p: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(primaryMetric)
                .font(.system(size: lerp(31, 36, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
                .shadow(color: Color.arkInk.opacity(0.60), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
            Text(metricUnit)
                .font(.system(size: lerp(11, 15, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .shadow(color: Color.arkInk.opacity(0.46), radius: 4, x: 0, y: 1) // ui-v4: allow requested legibility shadow on card text
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedContentProgress(_ progress: CGFloat) -> CGFloat {
        smooth(progress, 0.18, 0.58)
    }

    private func bottomQuickActionGradient(height: CGFloat, progress p: CGFloat) -> some View {
        let reveal = smooth(p, 0.36, 0.72)
        return LinearGradient(
            colors: [
                Color.arkInk.opacity(0),
                Color.arkInk.opacity(0.36 * Double(reveal)),
                Color.arkInk.opacity(0.78 * Double(reveal)),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height * lerp(0.34, 0.48, reveal))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var petTogetherHeadline: String {
        if let snapshotText = card.togetherHeadlineText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !snapshotText.isEmpty {
            return snapshotText
        }
        guard card.daysTogetherText != nil else {
            return l.tr(zh: "新成员", en: "New Family", de: "Neue Familie")
        }
        if card.daysTogether < 0 {
            let days = abs(card.daysTogether)
            return l.tr(zh: "\(days) 天后到家", en: "\(days) Days Until Home", de: "\(days) Tage bis Zuhause")
        }
        return l.tr(zh: "相伴 \(card.daysTogether) 天", en: "\(card.daysTogether) Days Together", de: "\(card.daysTogether) Tage zusammen")
    }

    private var cardPrimaryText: Color {
        WalletPetCardTheme.prefersDarkForeground(for: card.themeColorHex) ? Color.arkInk : Color.goCardWhite
    }

    private func cardSecondaryText(opacity: Double) -> Color {
        cardPrimaryText.opacity(opacity)
    }

    private var statusBadge: String {
        if let statusBadgeText = card.statusBadgeText {
            return statusBadgeText
        }
        if card.isHuman { return "🥥" }
        if card.streak > 0 { return "\(card.streak)" }
        return "OK"
    }

    private var statusBadgeBackground: Color {
        card.statusBadgeIsWarning ? Color.goRed : accent
    }

    private var primaryMetric: String {
        card.homePrimaryMetricValue
    }

    private var metricUnit: String {
        card.homePrimaryMetricUnit
    }

    private var avatarSymbol: String {
        if card.isElectronicPet { return "leaf.fill" }
        if card.isHuman { return "person.fill" }
        let species = (card.petSpecies ?? card.kind).lowercased()
        if species.contains("dog") || species.contains("狗") { return "dog.fill" }
        if species.contains("cat") || species.contains("猫") { return "cat.fill" }
        if species.contains("bird") || species.contains("鸟") { return "bird.fill" }
        if species.contains("fish") || species.contains("鱼") { return "fish.fill" }
        return "pawprint.fill"
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: CGFloat) -> Double {
        a + (b - a) * Double(min(max(t, 0), 1))
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
