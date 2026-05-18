//
//  QuickFeedCoreCards.swift
//  Ohana
//
//  Pure card rendering for the feeding dashboard.
//

import SwiftUI

struct FoodCardMetricLine: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let tint: Color
    var isCurrent: Bool = false
}

struct CoreFoodCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let metricLines: [FoodCardMetricLine]
    let primaryTitle: String
    let primaryIcon: String
    let secondaryTitle: String
    let secondaryIcon: String
    let cardAction: (() -> Void)?
    let primaryLongPressAction: (() -> Void)?
    let feedbackToken: CheckInFeedbackToken?
    let highlightMetricId: String?
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    init(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        metricLines: [FoodCardMetricLine] = [],
        primaryTitle: String,
        primaryIcon: String,
        secondaryTitle: String,
        secondaryIcon: String,
        cardAction: (() -> Void)? = nil,
        primaryLongPressAction: (() -> Void)? = nil,
        feedbackToken: CheckInFeedbackToken? = nil,
        highlightMetricId: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.metricLines = metricLines
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.secondaryTitle = secondaryTitle
        self.secondaryIcon = secondaryIcon
        self.cardAction = cardAction
        self.primaryLongPressAction = primaryLongPressAction
        self.feedbackToken = feedbackToken
        self.highlightMetricId = highlightMetricId
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 12) {
                if let cardAction {
                    Button(action: cardAction) {
                        infoContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ScaleButtonStyle())
                } else {
                    infoContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    Label(primaryTitle, systemImage: primaryIcon)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .labelStyle(.titleAndIcon)
                        .frame(width: 84)
                        .frame(minHeight: 44)
                        .background(tint, in: Capsule())
                        .contentShape(Capsule())
                        .onTapGesture(perform: primaryAction)
                        .onLongPressGesture(minimumDuration: 0.48, maximumDistance: 18) {
                            primaryLongPressAction?()
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: Text(primaryTitle), primaryAction)

                    Button(action: secondaryAction) {
                        Label(secondaryTitle, systemImage: secondaryIcon)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .labelStyle(.titleAndIcon)
                            .frame(width: 84)
                            .frame(minHeight: 44)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if let feedbackToken {
                CheckInFeedbackBadge(token: feedbackToken)
                    .offset(x: 62, y: 2)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 22)
        .checkInPulse(feedbackToken)
    }

    private var infoContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 54, height: 54)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if metricLines.isEmpty {
                        Text(value)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .contentTransition(.numericText())
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(metricLines) { line in
                            let isFeedbackHighlighted = line.id == highlightMetricId
                            let isHighlighted = line.isCurrent || isFeedbackHighlighted
                            HStack(spacing: 6) {
                                Text(line.title)
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(isHighlighted ? Color.arkInk.opacity(0.78) : Color.ohanaSecondaryText)
                                Spacer(minLength: 6)
                                Text(line.value)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(isHighlighted ? Color.arkInk : line.tint)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .contentTransition(.numericText())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isHighlighted ? line.tint : line.tint.opacity(0.08), in: Capsule())
                            .opacity(line.isCurrent ? 1 : 0.82)
                            .scaleEffect(isFeedbackHighlighted ? 1.025 : 1)
                            .animation(GoMotion.feedback, value: highlightMetricId)
                            .animation(GoMotion.feedback, value: line.isCurrent)
                        }
                    }
                }
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .contentShape(Rectangle())
    }
}

struct StockFoodCard: View {
    let title: String
    let drySnapshot: FeedStockSnapshot
    let wetSnapshot: FeedStockSnapshot
    let dryTitle: String
    let wetTitle: String
    let emptyText: String
    let primaryTitle: String
    let primaryIcon: String
    let secondaryTitle: String
    let secondaryIcon: String
    let cardAction: (() -> Void)?
    let stockPulseKind: FeedFoodKind?
    let stockFeedbackToken: CheckInFeedbackToken?
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    init(
        title: String,
        drySnapshot: FeedStockSnapshot,
        wetSnapshot: FeedStockSnapshot,
        dryTitle: String,
        wetTitle: String,
        emptyText: String,
        primaryTitle: String,
        primaryIcon: String,
        secondaryTitle: String,
        secondaryIcon: String,
        cardAction: (() -> Void)? = nil,
        stockPulseKind: FeedFoodKind? = nil,
        stockFeedbackToken: CheckInFeedbackToken? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) {
        self.title = title
        self.drySnapshot = drySnapshot
        self.wetSnapshot = wetSnapshot
        self.dryTitle = dryTitle
        self.wetTitle = wetTitle
        self.emptyText = emptyText
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.secondaryTitle = secondaryTitle
        self.secondaryIcon = secondaryIcon
        self.cardAction = cardAction
        self.stockPulseKind = stockPulseKind
        self.stockFeedbackToken = stockFeedbackToken
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 12) {
                if let cardAction {
                    Button(action: cardAction) {
                        infoContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ScaleButtonStyle())
                } else {
                    infoContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    Button(action: primaryAction) {
                        Label(primaryTitle, systemImage: primaryIcon)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .labelStyle(.titleAndIcon)
                            .frame(width: 84)
                            .frame(minHeight: 44)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: secondaryAction) {
                        Label(secondaryTitle, systemImage: secondaryIcon)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                            .labelStyle(.titleAndIcon)
                            .frame(width: 84)
                            .frame(minHeight: 44)
                            .background(Color.goPrimary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if let stockFeedbackToken {
                CheckInFeedbackBadge(token: stockFeedbackToken)
                    .offset(x: 62, y: 2)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 22)
        .checkInPulse(stockFeedbackToken)
    }

    private var infoContent: some View {
        HStack(spacing: 12) {
            Image("feed_food_bag")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .padding(3)
                .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if drySnapshot.totalGrams <= 0 && wetSnapshot.totalGrams <= 0 {
                    Text(emptyText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                } else {
                    stockLine(title: dryTitle, snapshot: drySnapshot, tint: Color.goPrimary, isHighlighted: stockPulseKind == .dry)
                    stockLine(title: wetTitle, snapshot: wetSnapshot, tint: Color.goPrimary, isHighlighted: stockPulseKind == .wet)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func stockLine(title: String, snapshot: FeedStockSnapshot, tint: Color, isHighlighted: Bool) -> some View {
        let progress = snapshot.totalGrams > 0 ? max(0, min(1, snapshot.remainingGrams / snapshot.totalGrams)) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(snapshot.totalGrams > 0 ? "\(Int(snapshot.remainingDays))d · \(formattedStockWeight(snapshot.remainingGrams))" : "--")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, isHighlighted ? 7 : 0)
            .padding(.vertical, isHighlighted ? 3 : 0)
            .background(isHighlighted ? tint.opacity(0.10) : Color.clear, in: Capsule())
            GeometryReader { proxy in
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * progress)
                            .animation(GoMotion.feedback, value: progress)
                    }
            }
            .frame(height: 6)
        }
    }

    private func formattedStockWeight(_ grams: Double) -> String {
        let digits = grams >= 1_000 && grams < 10_000 ? 2 : 1
        return AppMeasurementSystem.formatFoodGrams(grams, fractionDigits: digits)
    }
}

struct FeedingMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FoodPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct FeedingBowlIllustration: View {
    let progress: Double
    let tint: Color
    let secondaryTint: Color
    let isComplete: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.20), secondaryTint.opacity(0.13)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? tint : secondaryTint)
                    .frame(width: CGFloat(7 + (index % 3) * 2), height: CGFloat(7 + (index % 3) * 2))
                    .offset(
                        x: CGFloat(index - 3) * 12,
                        y: CGFloat(Self.particleYOffset(index)) - 24
                    )
                    .opacity(0.72)
            }

            Image("feed_dry_bowl")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 96)
                .scaleEffect(isComplete ? 1.04 : 0.96 + 0.08 * min(max(progress, 0.2), 1))
                .offset(y: 14)
                .shadow(color: tint.opacity(0.22), radius: 14, y: 8) // ui-v4: allow asset grounding shadow
                .animation(GoMotion.page, value: progress)
        }
        .accessibilityHidden(true)
    }

    private static func particleYOffset(_ index: Int) -> Double {
        let values: [Double] = [-2.0, 2.5, -4.0, 0.5, 3.0, -1.5, 1.0]
        return values[index % values.count]
    }
}
