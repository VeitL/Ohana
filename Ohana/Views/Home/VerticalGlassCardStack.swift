//
//  VerticalGlassCardStack.swift
//  Ohana
//
//  A reusable vertically swipeable glass card deck for Today Focus-style widgets.
//

import SwiftUI

struct ReminderCardModel: Identifiable, Equatable {
    let id = UUID()
    var symbolName: String
    var title: String
    var value: String
    var subtitle: String
    var tint: Color

    static let samples: [ReminderCardModel] = [
        ReminderCardModel(symbolName: "drop.fill", title: "Water Reminder", value: "1200 ml", subtitle: "Today goal 1600 ml", tint: .cyan),
        ReminderCardModel(symbolName: "figure.walk", title: "Steps", value: "6800", subtitle: "Goal 10000", tint: .green),
        ReminderCardModel(symbolName: "moon.zzz.fill", title: "Sleep", value: "7.5 h", subtitle: "Goal 8 h", tint: .indigo),
        ReminderCardModel(symbolName: "flame.fill", title: "Calories", value: "420 kcal", subtitle: "Goal 600 kcal", tint: .orange)
    ]
}

struct VerticalGlassCardStack<Card: Identifiable, CardContent: View>: View {
    let cards: [Card]
    var cardSize = CGSize(width: 340, height: 150)
    var visibleBackCardCount = 3
    var backCardSpacing: CGFloat = 18
    var swipeThreshold: CGFloat = 72
    var wraps = false
    var onIndexChanged: ((Int) -> Void)?
    @ViewBuilder var content: (Card, Bool) -> CardContent

    private var externalActiveIndex: Binding<Int>?
    @State private var activeIndex = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let stackAnimation = Animation.interactiveSpring(response: 0.45, dampingFraction: 0.82)

    init(
        cards: [Card],
        cardSize: CGSize = CGSize(width: 340, height: 150),
        visibleBackCardCount: Int = 3,
        backCardSpacing: CGFloat = 18,
        swipeThreshold: CGFloat = 72,
        wraps: Bool = false,
        onIndexChanged: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Card, Bool) -> CardContent
    ) {
        self.cards = cards
        self.cardSize = cardSize
        self.visibleBackCardCount = visibleBackCardCount
        self.backCardSpacing = backCardSpacing
        self.swipeThreshold = swipeThreshold
        self.wraps = wraps
        self.onIndexChanged = onIndexChanged
        self.content = content
        self.externalActiveIndex = nil
    }

    init(
        cards: [Card],
        activeIndex: Binding<Int>,
        cardSize: CGSize = CGSize(width: 340, height: 150),
        visibleBackCardCount: Int = 3,
        backCardSpacing: CGFloat = 18,
        swipeThreshold: CGFloat = 72,
        wraps: Bool = false,
        onIndexChanged: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Card, Bool) -> CardContent
    ) {
        self.cards = cards
        self.cardSize = cardSize
        self.visibleBackCardCount = visibleBackCardCount
        self.backCardSpacing = backCardSpacing
        self.swipeThreshold = swipeThreshold
        self.wraps = wraps
        self.onIndexChanged = onIndexChanged
        self.content = content
        self.externalActiveIndex = activeIndex
    }

    var body: some View {
        let topPeekInset = wraps ? backCardSpacing : 0
        ZStack {
            ForEach(visibleCards, id: \.card.id) { item in
                let metrics = metrics(forDepth: item.depth)
                content(item.card, item.index == currentIndex)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .scaleEffect(metrics.scale)
                    .offset(y: topPeekInset + metrics.offsetY)
                    .opacity(metrics.opacity)
                    .brightness(metrics.brightness)
                    .shadow( // ui-v4: allow intentional physical deck depth for stacked cards
                        color: .black.opacity(metrics.shadowOpacity),
                        radius: metrics.shadowRadius,
                        x: 0,
                        y: metrics.shadowY
                    )
                    .rotation3DEffect(
                        .degrees(metrics.rotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.45
                    )
                    .zIndex(metrics.zIndex)
                    .allowsHitTesting(item.index == currentIndex && abs(dragOffset) < 2)
            }
        }
        .frame(
            width: cardSize.width,
            height: cardSize.height + CGFloat(visibleBackCardCount) * backCardSpacing + topPeekInset
        )
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture, including: .all)
        .animation(stackAnimation, value: currentIndex)
    }

    private var currentIndex: Int {
        guard !cards.isEmpty else { return 0 }
        let rawValue = externalActiveIndex?.wrappedValue ?? activeIndex
        return min(max(rawValue, 0), cards.count - 1)
    }

    private func setCurrentIndex(_ nextIndex: Int) {
        let clamped = normalizedIndex(nextIndex)
        if let externalActiveIndex {
            externalActiveIndex.wrappedValue = clamped
        } else {
            activeIndex = clamped
        }
        onIndexChanged?(clamped)
    }

    private var dragProgress: CGFloat {
        guard cards.count > 1 else { return 0 }
        let raw = -dragOffset / swipeThreshold
        if wraps {
            return min(max(raw, -1), 1)
        }
        let minProgress = currentIndex == 0 ? CGFloat(0) : CGFloat(-1)
        let maxProgress = currentIndex == cards.count - 1 ? CGFloat(0) : CGFloat(1)
        return min(max(raw, minProgress), maxProgress)
    }

    private var visibleCards: [(index: Int, depth: CGFloat, card: Card)] {
        guard !cards.isEmpty else { return [] }
        if wraps {
            return wrappedVisibleCards
        }
        let lower = max(0, currentIndex - 1)
        let upper = min(cards.count - 1, currentIndex + visibleBackCardCount)
        return (lower...upper)
            .map { ($0, CGFloat($0 - currentIndex) - dragProgress, cards[$0]) }
            .sorted { lhs, rhs in
                abs(lhs.depth) > abs(rhs.depth)
            }
    }

    private var wrappedVisibleCards: [(index: Int, depth: CGFloat, card: Card)] {
        let deepest = min(visibleBackCardCount, max(cards.count - 1, 0))
        let positions = [-1] + Array(0...deepest)

        var used = Set<Int>()
        var output: [(index: Int, depth: CGFloat, card: Card)] = []
        for position in positions {
            let index = normalizedIndex(currentIndex + position)
            guard used.insert(index).inserted else { continue }
            output.append((index, CGFloat(position) - dragProgress, cards[index]))
        }
        return output.sorted { abs($0.depth) > abs($1.depth) }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.height
                let translation = value.translation.height
                let shouldAdvance = translation < -swipeThreshold || predicted < -swipeThreshold * 1.35
                let shouldGoBack = translation > swipeThreshold || predicted > swipeThreshold * 1.35
                let nextIndex: Int

                if shouldAdvance {
                    nextIndex = wraps ? currentIndex + 1 : min(currentIndex + 1, cards.count - 1)
                } else if shouldGoBack {
                    nextIndex = wraps ? currentIndex - 1 : max(currentIndex - 1, 0)
                } else {
                    nextIndex = currentIndex
                }

                guard nextIndex != currentIndex else { return }
                setCurrentIndex(nextIndex)
            }
    }

    private func normalizedIndex(_ index: Int) -> Int {
        guard !cards.isEmpty else { return 0 }
        if wraps {
            return (index % cards.count + cards.count) % cards.count
        }
        return min(max(index, 0), max(cards.count - 1, 0))
    }

    private func metrics(forDepth depth: CGFloat) -> CardMetrics {
        let clampedDepth = min(max(depth, -1), CGFloat(visibleBackCardCount))
        let depthMagnitude = abs(clampedDepth)
        let incomingBias: Double
        if dragProgress > 0.001 {
            incomingBias = clampedDepth > 0 ? 0.06 : 0
        } else if dragProgress < -0.001 {
            incomingBias = clampedDepth < 0 ? 0.06 : 0
        } else {
            incomingBias = depthMagnitude < 0.001 ? 0.08 : 0
        }

        return CardMetrics(
            scale: max(0.86, 1 - depthMagnitude * 0.045),
            offsetY: clampedDepth * backCardSpacing,
            opacity: max(0.34, 1 - depthMagnitude * 0.18),
            brightness: -depthMagnitude * 0.055,
            rotation: Double(-clampedDepth * 2.2),
            shadowOpacity: max(0.08, 0.24 - depthMagnitude * 0.035),
            shadowRadius: max(8, 24 - depthMagnitude * 2),
            shadowY: max(6, 16 - depthMagnitude),
            zIndex: 100 - Double(depthMagnitude) + incomingBias
        )
    }

    private struct CardMetrics {
        var scale: CGFloat
        var offsetY: CGFloat
        var opacity: Double
        var brightness: Double
        var rotation: Double
        var shadowOpacity: Double
        var shadowRadius: CGFloat
        var shadowY: CGFloat
        var zIndex: Double
    }
}

struct GlassReminderCard: View {
    let card: ReminderCardModel

    private let cornerRadius: CGFloat = 42

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(card.tint.opacity(0.16))
                    .frame(width: 72, height: 72)
                Image(systemName: card.symbolName)
                    .font(.system(size: 32, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(card.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(card.value)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                Text(card.subtitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            glassBackground(shape: shape)
        }
        .overlay {
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.55),
                            card.tint.opacity(0.22),
                            .black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .clipShape(shape)
    }

    @ViewBuilder
    private func glassBackground(shape: RoundedRectangle) -> some View {
        if #available(iOS 26.0, *) {
            shape
                .fill(card.tint.opacity(0.035))
                .glassEffect(.regular.tint(card.tint.opacity(0.06)).interactive(false), in: shape)
                .overlay(alignment: .topLeading) {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.34),
                                    .white.opacity(0.08),
                                    card.tint.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }
        } else {
            shape
                .fill(.ultraThinMaterial) // ui-v4: allow requested pre-iOS-26 glass fallback
                .overlay {
                    shape.fill(Color.goCardWhite.opacity(0.22))
                }
                .overlay(alignment: .topLeading) {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.32),
                                    .white.opacity(0.08),
                                    card.tint.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
    }
}

#Preview("Vertical Glass Card Stack") {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.10, blue: 0.16),
                Color(red: 0.16, green: 0.20, blue: 0.28),
                Color(red: 0.04, green: 0.05, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VerticalGlassCardStack(cards: ReminderCardModel.samples) { card, _ in
            GlassReminderCard(card: card)
        }
    }
}
