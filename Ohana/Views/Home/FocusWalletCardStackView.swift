//
//  FocusWalletCardStackView.swift
//  Ohana
//
//  Isolated wallet-card stack renderer. It receives lightweight snapshots and
//  callbacks so expanded quick actions can update without bloating the home
//  view's top-level body.
//

import SwiftUI

struct FocusWalletCardStackView<QuickModules: View, ContextMenuContent: View>: View {
    let cards: [FocusCard]
    let pets: [Pet]
    let isExpanded: Bool
    let activeCardId: UUID?
    let heroProgress: CGFloat
    let heroDirection: Int
    let namespace: Namespace.ID
    let heroNamespace: Namespace.ID
    let expandedId: UUID?
    let avatarCacheRevision: Int
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat
    let walletAnimation: Animation

    let reorderDragId: UUID?
    let reorderDragOffset: CGFloat
    let isReorderModeActive: Bool
    let isReorderEnabled: Bool
    let transitionCardId: UUID?
    let actionPulseCardId: UUID?
    let walkTransformBurstCardId: UUID?

    let quickModuleHeight: (FocusCard) -> CGFloat
    let quickModules: (FocusCard) -> QuickModules
    let contextMenuContent: (FocusCard) -> ContextMenuContent
    let onTapCard: (FocusCard, Int, Bool) -> Void
    let onCollapsedLongPress: (FocusCard, [FocusCard], CGFloat) -> Void
    let onCollapsedDragChanged: (FocusCard, [FocusCard], CGFloat, CGFloat) -> Void
    let onCollapsedDragEnded: (FocusCard, [FocusCard], CGFloat, CGFloat) -> Void
    let onHeroLongPress: (FocusCard) -> Void
    let onSwipeDownToCollapse: () -> Void
    let onInitialActiveCardNeeded: (UUID?) -> Void
    let onCardsChanged: ([UUID]) -> Void

    var body: some View {
        let n = cards.count
        let progress = HomeHeroTransitionProgress(value: heroProgress).clamped
        let isHeroActive = isExpanded || transitionCardId != nil || progress > 0.001
        let heroId = activeCardId ?? transitionCardId ?? cards.first?.id
        let heroIndex = heroId.flatMap { id in cards.firstIndex(where: { $0.id == id }) }

        GeometryReader { geo in
            let collapsedBottomY = FocusWalletLayout.collapsedStackBottomY(
                containerHeight: geo.size.height,
                bottomInset: safeAreaBottom
            )
            let heroTopY = safeAreaTop + K.expandedCardGlobalTopOffset - geo.frame(in: .global).minY
            let heroCollapsedOffsetY = heroIndex.map { idx in
                FocusWalletLayout.offsetY(
                    idx: idx,
                    n: n,
                    bottomY: collapsedBottomY,
                    heroId: heroId,
                    heroTopY: heroTopY,
                    cards: cards,
                    isExpanded: false
                )
            }
            let activeTimelineOffsetY = OhanaHeroGeometry.lerp(
                heroCollapsedOffsetY ?? heroTopY,
                heroTopY,
                progress: progress
            )

            ZStack(alignment: .topLeading) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    let isHero = isHeroActive && card.id == heroId
                    let visibleHeight = isHero
                        ? OhanaHeroGeometry.lerp(K.cardH, K.expandedCardH, progress: progress)
                        : K.cardH
                    let collapsedOffsetY = FocusWalletLayout.offsetY(
                        idx: idx,
                        n: n,
                        bottomY: collapsedBottomY,
                        heroId: heroId,
                        heroTopY: heroTopY,
                            cards: cards,
                            isExpanded: false
                    )
                    let offsetY = isHero
                        ? activeTimelineOffsetY
                        : HomeWalletHeroTimeline.inactiveOffsetY(
                            collapsedY: collapsedOffsetY,
                            selectedCollapsedY: heroCollapsedOffsetY,
                            activeCurrentY: activeTimelineOffsetY,
                            index: idx,
                            selectedIndex: heroIndex,
                            progress: progress,
                            direction: heroDirection,
                            collapsedBottomY: collapsedBottomY
                        )
                    let visualOpacity = isHero
                        ? 1.0
                        : HomeWalletHeroTimeline.inactiveOpacity(
                            index: idx,
                            selectedIndex: heroIndex,
                            progress: progress,
                            direction: heroDirection
                        )

                    stackItem(
                        card: card,
                        index: idx,
                        count: n,
                        isHero: isHero,
                        visibleHeight: visibleHeight,
                        offsetY: offsetY,
                        collapsedBottomY: collapsedBottomY,
                        heroId: heroId,
                        heroDirection: heroDirection,
                        heroIndex: heroIndex,
                        heroProgress: progress,
                        visualOpacity: visualOpacity
                    )
                }

                EmptyView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .animation(walletAnimation, value: isExpanded)
            .animation(walletAnimation, value: activeCardId)
            .animation(walletAnimation, value: heroProgress)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        guard isExpanded, value.translation.height > 80 else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSwipeDownToCollapse()
                    }
            )
            .onAppear {
                guard activeCardId == nil || !cards.contains(where: { $0.id == activeCardId }) else { return }
                onInitialActiveCardNeeded(cards.first?.id)
            }
            .onChange(of: cards.map(\.id)) { _, ids in
                onCardsChanged(ids)
            }
        }
    }

    private func stackItem(
        card: FocusCard,
        index: Int,
        count: Int,
        isHero: Bool,
        visibleHeight: CGFloat,
        offsetY: CGFloat,
        collapsedBottomY: CGFloat,
        heroId: UUID?,
        heroDirection: Int,
        heroIndex: Int?,
        heroProgress: CGFloat,
        visualOpacity: Double
    ) -> some View {
        let isReorderingCard = reorderDragId == card.id
        let isTransitioningCard = transitionCardId == card.id
        let walkTrackingPet = FocusHomeWalletCardContent.walkTrackingPet(for: card, isHero: isHero, pets: pets)
        let isInteractiveWalkCard = walkTrackingPet != nil

        return FocusHomeWalletCardStackItem(
            card: card,
            index: index,
            count: count,
            isExpanded: isExpanded,
            isHero: isHero,
            visibleHeight: visibleHeight,
            offsetY: offsetY,
            dragOffset: reorderDragOffset,
            isReorderingCard: isReorderingCard,
            isAnyReorderDragging: reorderDragId != nil,
            isTransitioningCard: isTransitioningCard,
            isInteractiveWalkCard: isInteractiveWalkCard,
            isReorderModeActive: isReorderModeActive,
            isReorderEnabled: isReorderEnabled,
            isActionPulsing: actionPulseCardId == card.id,
            visualOpacity: visualOpacity,
            heroProgress: heroProgress,
            heroDirection: heroDirection,
            heroIndex: heroIndex,
            heroId: heroId,
            cards: cards,
            animation: walletAnimation,
            onTap: { onTapCard(card, count, isHero) },
            onCollapsedLongPress: { currentOffsetY in
                onCollapsedLongPress(card, cards, currentOffsetY)
            },
            onCollapsedDragChanged: { translationY in
                onCollapsedDragChanged(card, cards, translationY, collapsedBottomY)
            },
            onCollapsedDragEnded: { translationY in
                onCollapsedDragEnded(card, cards, translationY, collapsedBottomY)
            },
            onHeroLongPress: {
                onHeroLongPress(card)
            }
        ) {
            FocusHomeWalletCardContent(
                card: card,
                namespace: namespace,
                heroNamespace: heroNamespace,
                expandedId: expandedId,
                isHeroExpanded: isHero,
                heroProgress: heroProgress,
                avatarCacheRevision: avatarCacheRevision,
                walkTrackingPet: walkTrackingPet
            )
        } pulseOverlay: {
            FocusHomeExpandedActionPulseOverlay(isActive: actionPulseCardId == card.id)
        } burstOverlay: {
            FocusHomeWalkTransformBurstOverlay(isActive: walkTransformBurstCardId == card.id)
        } contextMenuContent: {
            contextMenuContent(card)
        }
    }
}
