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
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 16, weight: .semibold))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .default))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(value)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .default))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold))
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
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .default))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            recordSummary
            if !compact, onEdit != nil || onDelete != nil {
                QuickFeedRecordActions(title: title, editTint: editTint, onEdit: onEdit, onDelete: onDelete)
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

    private var recordSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: compact ? 12 : 14, weight: .semibold))
                .foregroundStyle(Color.arkInk)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(tint, in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: compact ? 12 : 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(date, format: compact ? .dateTime.hour().minute() : .dateTime.month().day().hour().minute())
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(Color.ohanaSecondaryText)
                if dynamicTypeSize.isAccessibilitySize {
                    amount
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize {
                amount
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var amount: some View {
        Text(gramsText)
            .font(OhanaFont.adaptive(size: compact ? 13 : 15, weight: .semibold, design: .default))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct QuickFeedPlanStatusRow: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let actionTitle: String?
    let onAction: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            planSummary
            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(Color.arkInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }

    private var planSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            recordSummary
            QuickFeedRecordActions(title: title, editTint: stockTint, onEdit: onEdit, onDelete: onDelete)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }

    private var recordSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(foodTint, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(Color.ohanaSecondaryText)
                if dynamicTypeSize.isAccessibilitySize, let value {
                    amount(value)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize, let value {
                amount(value)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func amount(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .default))
            .foregroundStyle(foodTint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct QuickFeedRecordActions: View {
    let title: String
    let editTint: Color
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(spacing: 4) {
            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                        .foregroundStyle(editTint)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(
                    zh: "编辑\(title)", en: "Edit \(title)", de: "\(title) bearbeiten",
                    es: "Editar \(title)", pt: "Editar \(title)", fr: "Modifier \(title)",
                    ja: "\(title)を編集", ko: "\(title) 편집", it: "Modifica \(title)"
                ))
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                        .foregroundStyle(Color.goRed)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(
                    zh: "删除\(title)", en: "Delete \(title)", de: "\(title) löschen",
                    es: "Eliminar \(title)", pt: "Excluir \(title)", fr: "Supprimer \(title)",
                    ja: "\(title)を削除", ko: "\(title) 삭제", it: "Elimina \(title)"
                ))
            }
        }
    }
}
