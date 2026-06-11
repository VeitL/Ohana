//
//  IslandStatComponents.swift
//  Ohana
//
//  Island Stats 横向卡片 + 专属图表组件 (C4)
//

import Observation
import SwiftUI

private let legacyChartBaseDate = Date(timeIntervalSinceReferenceDate: 0)

private func legacyTrendPoints(_ values: [Double], idPrefix: String) -> [OhanaMinimalChartPoint] {
    values.enumerated().compactMap { index, value in
        guard value.isFinite else { return nil }
        return OhanaMinimalChartPoint(
            date: legacyChartBaseDate.addingTimeInterval(Double(index) * 86400),
            value: value,
            id: "\(idPrefix)-\(index)-\(Int((value * 1000).rounded()))"
        )
    }
}

private func legacyBarPoints(_ values: [Double], labels: [String]) -> [OhanaMinimalChartPoint] {
    values.enumerated().compactMap { index, value in
        guard value.isFinite else { return nil }
        let label = index < labels.count ? labels[index] : nil
        return OhanaMinimalChartPoint(
            date: legacyChartBaseDate.addingTimeInterval(Double(index) * 86400),
            value: max(0, value),
            label: label,
            id: "legacy-bar-\(index)-\(Int((value * 1000).rounded()))-\(label ?? "")"
        )
    }
}

private var legacyChartEmptyState: some View {
    Text(L10n().tr(zh: "暂无数据", en: "No data", de: "Keine Daten"))
        .font(OhanaFont.caption2(.medium))
        .foregroundStyle(Color.ohanaTertiaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Overlapping Avatars（微型头像组）
struct OverlappingAvatarsView: View {
    let emojis: [String]
    var maxCount: Int = 4

    var body: some View {
        let shown = Array(emojis.prefix(maxCount))
        HStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.offset) { i, emoji in
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.mix(with: .black, by: 0.3))
                        .overlay(Circle().strokeBorder(Color.ohanaCardStroke, lineWidth: 1.5))
                        .frame(width: 24, height: 24) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    Text(emoji)
                        .font(OhanaFont.adaptive(size: 12))
                }
                .offset(x: CGFloat(-i) * 8)
                .zIndex(Double(shown.count - i))
            }
            if emojis.count > maxCount {
                ZStack {
                    Circle()
                        .fill(Color.ohanaControlFill)
                        .overlay(Circle().strokeBorder(Color.ohanaCardStroke, lineWidth: 1.5))
                        .frame(width: 24, height: 24) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    Text("+\(emojis.count - maxCount)")
                        .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                }
                .offset(x: CGFloat(-maxCount) * 8)
            }
        }
    }
}

// MARK: - Island Stat Card 容器
struct IslandStatCard<Chart: View>: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let accentColor: Color
    var avatarEmojis: [String] = []
    var onTap: (() -> Void)?
    @ViewBuilder let chart: () -> Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：icon + 标题
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
            }

            // 大数字
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 34))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion(value)
                if !unit.isEmpty {
                    Text(unit)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(accentColor)
                }
            }

            // 图表区域
            chart()
                .frame(height: 80)

            // 底部：头像组 或 副标题
            if !avatarEmojis.isEmpty {
                HStack(spacing: 8) {
                    OverlappingAvatarsView(emojis: avatarEmojis)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(OhanaFont.caption2(.medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            .lineLimit(1)
                    }
                    Spacer()
                    if onTap != nil {
                        Image(systemName: "arrow.up.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 9, weight: .bold))
                            .foregroundStyle(accentColor.opacity(0.6))
                    }
                }
            } else if !subtitle.isEmpty {
                Text(subtitle)
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(width: 260, height: 212)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Mini Bar Chart (步数/遛狗/花费)
struct MiniBarChart: View {
    let values: [Double]
    let labels: [String]
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let points = legacyBarPoints(values, labels: labels)
            if points.isEmpty {
                legacyChartEmptyState
            } else {
                OhanaMinimalBarChart(
                    points: points,
                    tint: accentColor,
                    showsLabels: !labels.isEmpty,
                    maxBarHeight: max(8, geo.size.height - (labels.isEmpty ? 0 : 14)),
                    emptyBarColor: accentColor.opacity(0.16)
                )
            }
        }
    }
}
