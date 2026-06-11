//
//  QuickFeedOverviewSupportViews.swift
//  Ohana
//
//  Small presentation pieces shared by quick feeding overview surfaces.
//

import SwiftUI

struct QuickFeedModeInfoPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
    }
}

struct QuickFeedSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.top, 2)
    }
}

struct QuickFeedTreatOverviewHero: View {
    let icon: String
    let title: String
    let lastSeenText: String
    let todayCount: Int
    let todaySubtitle: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 22, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(lastSeenText)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(todayCount)")
                    .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(todaySubtitle)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.vertical, 2)
    }
}

struct QuickFeedTreatFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                Text("\(count)")
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(isSelected ? Color.arkInk : tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isSelected ? tint : tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }
}
