//
//  QuickFeedDetailRows.swift
//  Ohana
//
//  Reusable row surfaces for the quick feeding detail flow.
//

import SwiftUI

struct QuickFeedManageRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(value)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct QuickFeedEmptyInlineState: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }
}

struct QuickFeedLogRow: View {
    let icon: String
    let title: String
    let tint: Color
    let date: Date
    let gramsText: String
    let compact: Bool
    let editTint: Color
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: compact ? 12 : 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(tint, in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: compact ? 12 : 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(date, format: compact ? .dateTime.hour().minute() : .dateTime.month().day().hour().minute())
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(gramsText)
                .font(.system(size: compact ? 13 : 15, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            if !compact {
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(editTint)
                            .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.goRed)
                            .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(compact ? 0 : 12)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(Color.ohanaCardSurface)
            }
        }
    }
}

struct QuickFeedPlanStatusRow: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let actionTitle: String?
    let onAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }
}

struct QuickFeedFoodRecordRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String?
    let foodTint: Color
    let stockTint: Color
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(foodTint, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if let value {
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(foodTint)
            }
            Button(action: onEdit) {
                Image(systemName: "pencil").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(stockTint)
                    .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())
            Button(action: onDelete) {
                Image(systemName: "trash").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }
}
