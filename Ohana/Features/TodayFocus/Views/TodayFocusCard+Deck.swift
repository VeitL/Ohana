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
                physicalStackCard(cards: cards.map { FocusDeckCard(id: contentKey($0), content: $0) })
            } else if cards.count > 1 {
                legacySwitchingCard(cards: cards, showsPageIndicator: showsPageIndicator)
            } else {
                cardContent(cards.first ?? .welcome)
            }
        }
    }

    func frozenCompactStackCard(content frontContent: TodayFocusContent, backCardCount: Int) -> some View {
        GeometryReader { geo in
            let width = max(298, min(geo.size.width, 390))
            let cardHeight = TodayFocusCardLayout.frontHeight
            let backSpacing = TodayFocusCardLayout.backCardSpacing
            let topPeekInset: CGFloat = backSpacing
            ZStack {
                if backCardCount > 0 {
                    ForEach(Array((1 ... backCardCount).reversed()), id: \.self) { depth in
                        TodayFocusFrozenBackPlate(
                            depth: depth,
                            width: width,
                            height: cardHeight,
                            topInset: topPeekInset,
                            spacing: backSpacing
                        )
                    }
                }

                cardContent(frontContent)
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
                        cardContent(item)
                            .padding(.horizontal, 2)
                            .offset(x: focusItemOffset(relative: relative))
                            .scaleEffect(focusItemScale(relative: relative))
                            .opacity(focusItemOpacity(relative: relative))
                            .allowsHitTesting(relative == 0)
                            .accessibilityHidden(relative != 0)
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
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = max(-92, min(92, value.translation.width))
            }
            .onEnded { value in
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
