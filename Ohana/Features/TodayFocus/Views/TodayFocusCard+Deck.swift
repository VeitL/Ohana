//
//  TodayFocusCard+Deck.swift
//  Ohana
//

import SwiftUI

extension TodayFocusCard {
    // MARK: - Card switcher

    struct TodayFocusRenderDeck {
        let pendingQuests: [IslandQuest]
        let assignedFamilyTasks: [TodayFocusFamilyTaskSnapshot]
        let pendingExchangeRequests: [TodayFocusExchangeRequestSnapshot]
        let negativeSignals: [IslandNegativeSignal]
        let cards: [TodayFocusContent]
        let identity: String

        static func make(
            snapshot: TodayFocusSnapshot,
            skippedFocusKeys: Set<String>,
            closedNegativeKeys: Set<String>
        ) -> TodayFocusRenderDeck {
            let pendingQuests = snapshot.refreshedQuests.filter {
                !$0.isCompleted && !skippedFocusKeys.contains(TodayFocusCard.questSkipKey(for: $0))
            }
            let assignedFamilyTasks = snapshot.assignedFamilyTasks.filter {
                !skippedFocusKeys.contains(TodayFocusCard.familyTaskSkipKey(for: $0))
            }.prefix(TodayFocusLimits.maxFamilyTaskCards)
            let pendingExchangeRequests = CoconutExchangeFeatureGate.isEnabled
                ? snapshot.pendingExchangeRequests.filter {
                    !skippedFocusKeys.contains(TodayFocusCard.exchangeSkipKey(for: $0))
                }.prefix(TodayFocusLimits.maxExchangeCards)
                : ArraySlice<TodayFocusExchangeRequestSnapshot>()
            let negativeSignals = snapshot.negativeSignals.filter {
                !closedNegativeKeys.contains(TodayFocusCard.negativeSkipKey(for: $0))
            }.prefix(TodayFocusLimits.maxNegativeCards)

            let cards: [TodayFocusContent] = if !negativeSignals.isEmpty {
                negativeSignals.map { .negative($0) } +
                    assignedFamilyTasks.map { .familyTask($0) } +
                    pendingExchangeRequests.map { .coconutExchange($0) } +
                    pendingQuests.map { .quest($0) }
            } else if !assignedFamilyTasks.isEmpty {
                assignedFamilyTasks.map { .familyTask($0) } +
                    pendingExchangeRequests.map { .coconutExchange($0) } +
                    pendingQuests.map { .quest($0) }
            } else if !pendingExchangeRequests.isEmpty {
                pendingExchangeRequests.map { .coconutExchange($0) } +
                    pendingQuests.map { .quest($0) }
            } else if !pendingQuests.isEmpty {
                pendingQuests.map { .quest($0) }
            } else if !snapshot.refreshedQuests.isEmpty || !snapshot.pets.isEmpty || !snapshot.plants.isEmpty || !snapshot.humans.isEmpty {
                [.celebrate(pets: snapshot.pets)]
            } else {
                [.welcome]
            }

            return TodayFocusRenderDeck(
                pendingQuests: pendingQuests,
                assignedFamilyTasks: Array(assignedFamilyTasks),
                pendingExchangeRequests: Array(pendingExchangeRequests),
                negativeSignals: Array(negativeSignals),
                cards: cards,
                identity: cards.map { TodayFocusCard.contentKey(for: $0) }.joined(separator: "|")
            )
        }
    }

    struct FocusDeckCard: Identifiable {
        let id: String
        let content: TodayFocusContent
    }

    @ViewBuilder
    func card(showsPageIndicator: Bool) -> some View {
        if freezesToFrontCard {
            if presentation == .compactStack {
                frozenCompactStackCard(
                    content: frozenFrontContent ?? content,
                    backCardCount: min(TodayFocusLimits.maxVisibleBackCards, max(focusCards.count - 1, 0))
                )
            } else {
                cardContent(frozenFrontContent ?? content)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
            }
        } else {
            let cards = focusCards
            if presentation == .compactStack {
                compactStackCard(cards: cards)
            } else if cards.count > 1 {
                legacySwitchingCard(cards: cards, showsPageIndicator: showsPageIndicator)
            } else {
                cardContent(cards.first ?? .welcome)
            }
        }
    }

    @ViewBuilder
    func compactStackCard(cards: [TodayFocusContent]) -> some View {
        horizontalBannerCarousel(cards: cards)
    }

    func frozenCompactStackCard(content frontContent: TodayFocusContent, backCardCount: Int) -> some View {
        GeometryReader { geo in
            let width = todayFocusCarouselWidth(in: geo.size.width)
            let cardHeight = TodayFocusCardLayout.frontHeight
            let backSpacing = TodayFocusCardLayout.backCardSpacing
            let topPeekInset = TodayFocusCardLayout.carouselTopPeekInset
            ZStack {
                if backCardCount > 0 {
                    ForEach(Array((1 ... backCardCount).reversed()), id: \.self) { depth in
                        TodayFocusCarouselBackPlate(
                            depth: depth,
                            width: width,
                            height: cardHeight,
                            topInset: topPeekInset,
                            spacing: backSpacing
                        )
                    }
                }

                carouselCardContent(
                    frontContent,
                    selected: min(selectedFocusIndex, max(focusCards.count - 1, 0)),
                    count: max(focusCards.count, 1)
                )
                    .frame(width: width, height: cardHeight)
                    .offset(y: topPeekInset)
                    .zIndex(20)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .frame(height: TodayFocusCardLayout.compactStackHeight)
    }

    func horizontalBannerCarousel(cards sourceCards: [TodayFocusContent]) -> some View {
        let cards = sourceCards.isEmpty ? [TodayFocusContent.welcome] : sourceCards
        return GeometryReader { geo in
            let width = todayFocusCarouselWidth(in: geo.size.width)
            let cardHeight = TodayFocusCardLayout.frontHeight
            let backCount = min(TodayFocusLimits.maxVisibleBackCards, max(cards.count - 1, 0))
            let topPeekInset = TodayFocusCardLayout.carouselTopPeekInset
            ZStack {
                if backCount > 0 {
                    ForEach(Array((1 ... backCount).reversed()), id: \.self) { depth in
                        TodayFocusCarouselBackPlate(
                            depth: depth,
                            width: width,
                            height: cardHeight,
                            topInset: topPeekInset,
                            spacing: TodayFocusCardLayout.backCardSpacing
                        )
                    }
                }

                ZStack {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, item in
                        let relative = focusRelativeIndex(for: index, count: cards.count)
                        let itemOpacity = carouselItemOpacity(relative: relative)
                        let shouldMountContent = relative == 0 || itemOpacity > 0.001
                        Group {
                            if shouldMountContent {
                                carouselCardContent(item, selected: index, count: cards.count)
                                    .accessibilityHidden(relative != 0)
                            } else {
                                Color.clear.accessibilityHidden(true)
                            }
                        }
                        .frame(width: width, height: cardHeight)
                        .offset(x: carouselItemOffset(relative: relative, width: width))
                        .scaleEffect(carouselItemScale(relative: relative))
                        .opacity(itemOpacity)
                        .allowsHitTesting(relative == 0)
                    }
                }
                .frame(width: width, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: TodayFocusCardLayout.carouselCornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: TodayFocusCardLayout.carouselCornerRadius, style: .continuous))
                .highPriorityGesture(focusSwipeGesture(count: cards.count))
                .offset(y: topPeekInset)
                .zIndex(20)
                .animation(carouselSwitchAnimation, value: selectedFocusIndex)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: TodayFocusCardLayout.compactStackHeight)
        .onChange(of: cards.count) { _, count in
            if selectedFocusIndex >= count {
                selectedFocusIndex = max(0, count - 1)
            }
        }
    }

    func todayFocusCarouselWidth(in availableWidth: CGFloat) -> CGFloat {
        max(302, min(availableWidth - TodayFocusCardLayout.carouselHorizontalMargin * 2, 430))
    }

    var carouselSwitchAnimation: Animation? {
        guard !freezesToFrontCard, !reduceMotion else { return nil }
        guard workloadPolicy.shouldRunInteractionAnimation(isVisible: true) else { return nil }
        return .interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.12)
    }

    func carouselItemOffset(relative: Int, width: CGFloat) -> CGFloat {
        CGFloat(relative) * (width + TodayFocusCardLayout.carouselSideGap) + focusDragX
    }

    func carouselItemScale(relative: Int) -> CGFloat {
        let dragProgress = min(1, abs(focusDragX) / 120)
        if relative == 0 {
            return 1 - dragProgress * 0.018
        }
        return 0.985 + dragProgress * 0.015
    }

    func carouselItemOpacity(relative: Int) -> Double {
        let dragProgress = min(1, abs(focusDragX) / 120)
        if relative == 0 {
            return Double(1 - dragProgress * 0.20)
        }
        let isIncoming = (focusDragX < 0 && relative == 1) || (focusDragX > 0 && relative == -1)
        return isIncoming ? Double(0.18 + dragProgress * 0.82) : 0
    }

    @ViewBuilder
    func physicalStackCard(cards: [FocusDeckCard]) -> some View {
        if cards.count > 1 {
            GeometryReader { geo in
                let width = max(298, min(geo.size.width, 390))
                VerticalGlassCardStack(
                    cards: cards,
                    activeIndex: $selectedFocusIndex,
                    cardSize: CGSize(width: width, height: TodayFocusCardLayout.frontHeight),
                    visibleBackCardCount: min(TodayFocusLimits.maxVisibleBackCards, max(cards.count - 1, 0)),
                    backCardSpacing: TodayFocusCardLayout.backCardSpacing,
                    swipeThreshold: 42,
                    wraps: true,
                    onIndexChanged: { _ in OhanaFeedback.light() }
                ) { item, _ in
                    cardContent(item.content)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: TodayFocusCardLayout.compactStackHeight)
            .onChange(of: cards.count) { _, count in
                if selectedFocusIndex >= count {
                    selectedFocusIndex = max(0, count - 1)
                }
            }
        } else {
            cardContent(cards.first?.content ?? .welcome)
                .frame(height: TodayFocusCardLayout.frontHeight)
        }
    }

    @ViewBuilder
    func legacySwitchingCard(cards: [TodayFocusContent], showsPageIndicator: Bool) -> some View {
        if cards.count > 1 {
            VStack(spacing: 4) {
                ZStack {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, item in
                        let relative = focusRelativeIndex(for: index, count: cards.count)
                        let itemOpacity = focusItemOpacity(relative: relative)
                        let shouldMountContent = relative == 0 || itemOpacity > 0.001
                        Group {
                            if shouldMountContent {
                                cardContent(item)
                                    .accessibilityHidden(relative != 0)
                            } else {
                                Color.clear.accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 2)
                        .offset(x: focusItemOffset(relative: relative))
                        .scaleEffect(focusItemScale(relative: relative))
                        .opacity(itemOpacity)
                        .allowsHitTesting(relative == 0)
                    }
                }
                .frame(height: TodayFocusCardLayout.legacySwitchHeight)
                .clipped()
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
                .highPriorityGesture(focusSwipeGesture(count: cards.count))

                if showsPageIndicator {
                    focusPageIndicator(count: cards.count, selected: selectedFocusIndex)
                }
            }
        } else {
            cardContent(cards.first ?? .welcome)
        }
    }

    func focusSwipeGesture(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($focusDragX) { value, state, _ in
                guard count > 1 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = max(-92, min(92, value.translation.width))
            }
            .onEnded { value in
                guard count > 1 else { return }
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) else { return }
                let predicted = value.predictedEndTranslation.width
                guard abs(horizontal) > 44 || abs(predicted) > 92 else { return }
                shiftFocus(horizontal < 0 ? 1 : -1, count: count)
            }
    }

    func focusRelativeIndex(for index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let forward = (index - selectedFocusIndex + count) % count
        let backward = (selectedFocusIndex - index + count) % count
        return forward <= backward ? forward : -backward
    }

    func focusItemOffset(relative: Int) -> CGFloat {
        CGFloat(relative) * 76 + focusDragX
    }

    func focusItemScale(relative: Int) -> CGFloat {
        let dragProgress = min(1, abs(focusDragX) / 92)
        return relative == 0 ? (1 - dragProgress * 0.025) : (0.96 + dragProgress * 0.04)
    }

    func focusItemOpacity(relative: Int) -> Double {
        let dragProgress = min(1, abs(focusDragX) / 92)
        if relative == 0 {
            return Double(1 - dragProgress * 0.34)
        }
        let isIncoming = (focusDragX < 0 && relative == 1) || (focusDragX > 0 && relative == -1)
        return isIncoming ? Double(dragProgress) : 0
    }

    func shiftFocus(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        OhanaFeedback.light()
        withAnimation(GoMotion.selection) {
            selectedFocusIndex = (selectedFocusIndex + delta + count) % count
        }
    }
}
