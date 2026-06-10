//
//  FocusHomeWalletCardStackItem.swift
//  Ohana
//
//  One positioned card inside the GO Focus wallet stack.
//

import SwiftUI

struct FocusHomeWalletCardStackItem<Content: View, PulseOverlay: View, BurstOverlay: View, ContextMenuContent: View>: View {
    let card: FocusCard
    let index: Int
    let count: Int
    let isExpanded: Bool
    let isHero: Bool
    let visibleHeight: CGFloat
    let offsetY: CGFloat
    let dragOffset: CGFloat
    let isReorderingCard: Bool
    let isAnyReorderDragging: Bool
    let isTransitioningCard: Bool
    let isInteractiveWalkCard: Bool
    let isReorderModeActive: Bool
    let isReorderEnabled: Bool
    let isActionPulsing: Bool
    let visualOpacity: Double
    let heroProgress: CGFloat
    let heroDirection: Int
    let heroIndex: Int?
    let heroId: UUID?
    let cards: [FocusCard]
    let animation: Animation
    let onTap: () -> Void
    let onCollapsedLongPress: (_ currentOffsetY: CGFloat) -> Void
    let onCollapsedDragChanged: (_ translationY: CGFloat) -> Void
    let onCollapsedDragEnded: (_ translationY: CGFloat) -> Void
    let onHeroLongPress: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let pulseOverlay: () -> PulseOverlay
    @ViewBuilder let burstOverlay: () -> BurstOverlay
    @ViewBuilder let contextMenuContent: () -> ContextMenuContent

    var body: some View {
        FocusHomeWalletCardVisual(
            isHero: isHero,
            visibleHeight: visibleHeight,
            verticalOffset: offsetY + (isReorderingCard ? dragOffset : 0),
            visualOpacity: visualOpacity,
            scale: scale,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowY: shadowY,
            zIndex: zIndex,
            content: content,
            pulseOverlay: pulseOverlay,
            burstOverlay: burstOverlay
        )
        .modifier(
            FocusHomeWalletCardInteractionModifier(
                cardName: card.name,
                accessibilityHint: accessibilityHint,
                isExpanded: isExpanded,
                isHero: isHero,
                isAnyReorderDragging: isAnyReorderDragging,
                isInteractiveWalkCard: isInteractiveWalkCard,
                isReorderEnabled: isReorderEnabled,
                isReorderingCard: isReorderingCard,
                visualOpacity: visualOpacity,
                currentOffsetY: offsetY,
                onTap: onTap,
                onCollapsedLongPress: onCollapsedLongPress,
                onCollapsedDragChanged: onCollapsedDragChanged,
                onCollapsedDragEnded: onCollapsedDragEnded,
                onHeroLongPress: onHeroLongPress,
                contextMenuContent: contextMenuContent
            )
        )
        .modifier(
            FocusHomeWalletCardAnimationModifier(
                animation: animation,
                isExpanded: isExpanded,
                heroId: heroId,
                heroProgress: heroProgress,
                isReorderingCard: isReorderingCard
            )
        )
    }

    private var scale: CGFloat {
        (isHero ? 1.0 : HomeWalletHeroTimeline.inactiveScale(
            index: index,
            selectedIndex: heroIndex,
            progress: heroProgress,
            direction: heroDirection
        )) *
            (isTransitioningCard && !isExpanded ? 1.012 : 1.0) *
            (isReorderingCard ? 1.015 : 1.0) *
            (isActionPulsing ? 1.025 : 1.0)
    }

    private var shadowOpacity: Double {
        isHero ? 0.24 : (isReorderingCard || isTransitioningCard ? 0.17 : 0.09)
    }

    private var shadowRadius: CGFloat {
        isHero ? 22 : (isReorderingCard || isTransitioningCard ? 14 : 7)
    }

    private var shadowY: CGFloat {
        isHero ? 13 : (isReorderingCard || isTransitioningCard ? 8 : 4)
    }

    private var zIndex: Double {
        if isReorderingCard { return Double(count + 120) }
        if isHero, heroDirection < 0 {
            return Double(index) + 0.25
        }
        return FocusWalletLayout.zIndex(
            idx: index,
            n: count,
            isHero: isHero,
            heroId: heroId,
            cards: cards,
            isExpanded: isExpanded
        )
    }

    private var accessibilityHint: String {
        if isHero { return "点击返回首页，长按进入基本信息" }
        if isExpanded { return "点击返回首页" }
        return isReorderModeActive ? "拖动调整排序，点击退出排序" : "点击展开查看，长按进入排序"
    }
}

private struct FocusHomeWalletCardVisual<CardContent: View, PulseOverlay: View, BurstOverlay: View>: View {
    let isHero: Bool
    let visibleHeight: CGFloat
    let verticalOffset: CGFloat
    let visualOpacity: Double
    let scale: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let zIndex: Double
    @ViewBuilder let content: () -> CardContent
    @ViewBuilder let pulseOverlay: () -> PulseOverlay
    @ViewBuilder let burstOverlay: () -> BurstOverlay

    var body: some View {
        content()
            .frame(height: isHero ? K.expandedCardH : K.cardH)
            .frame(height: visibleHeight, alignment: .top)
            .clipped()
            .frame(maxWidth: .infinity)
            .overlay { pulseOverlay() }
            .overlay { burstOverlay() }
            .shadow( // ui-v4: allow home card stack depth
                color: .black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .scaleEffect(scale, anchor: isHero ? .center : .top)
            .offset(y: verticalOffset)
            .opacity(visualOpacity)
            .zIndex(zIndex)
            .transition(.identity)
    }
}

private struct FocusHomeWalletCardInteractionModifier<MenuContent: View>: ViewModifier {
    let cardName: String
    let accessibilityHint: String
    let isExpanded: Bool
    let isHero: Bool
    let isAnyReorderDragging: Bool
    let isInteractiveWalkCard: Bool
    let isReorderEnabled: Bool
    let isReorderingCard: Bool
    let visualOpacity: Double
    let currentOffsetY: CGFloat
    let onTap: () -> Void
    let onCollapsedLongPress: (_ currentOffsetY: CGFloat) -> Void
    let onCollapsedDragChanged: (_ translationY: CGFloat) -> Void
    let onCollapsedDragEnded: (_ translationY: CGFloat) -> Void
    let onHeroLongPress: () -> Void
    @ViewBuilder let contextMenuContent: () -> MenuContent

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isExpanded || isHero || visualOpacity > 0.15)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(cardName) 的卡片")
            .accessibilityHint(accessibilityHint)
            .if(isExpanded && !isHero && !isAnyReorderDragging) { view in
                view.contextMenu { contextMenuContent() }
            }
            .if(isExpanded && !isInteractiveWalkCard) { view in
                view.highPriorityGesture(TapGesture().onEnded { onTap() })
            }
            .if(!isExpanded && !isInteractiveWalkCard) { view in
                view.highPriorityGesture(TapGesture().onEnded { onTap() })
                    .simultaneousGesture(collapsedLongPressGesture)
                    .simultaneousGesture(collapsedDragGesture)
            }
            .if(isHero && isExpanded && !isInteractiveWalkCard) { view in
                view.onLongPressGesture(minimumDuration: 0.45, perform: onHeroLongPress)
            }
    }

    private var collapsedLongPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .onEnded { _ in onCollapsedLongPress(currentOffsetY) }
    }

    private var collapsedDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { drag in
                guard isReorderEnabled, isReorderingCard else { return }
                onCollapsedDragChanged(drag.translation.height)
            }
            .onEnded { drag in
                guard isReorderEnabled, isReorderingCard else { return }
                onCollapsedDragEnded(drag.translation.height)
            }
    }
}

private struct FocusHomeWalletCardAnimationModifier: ViewModifier {
    let animation: Animation
    let isExpanded: Bool
    let heroId: UUID?
    let heroProgress: CGFloat
    let isReorderingCard: Bool

    func body(content: Content) -> some View {
        content
            .animation(animation, value: isExpanded)
            .animation(animation, value: heroId)
            .animation(animation, value: heroProgress)
            .animation(animation, value: isReorderingCard)
    }
}
