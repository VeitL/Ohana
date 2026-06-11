//
//  ExpandedQuickActionsSection+InlineMenuAndAdd.swift
//  Ohana
//

import SwiftUI
import UniformTypeIdentifiers

struct ExpandedQuickInlineActionMenu: View {
    let accent: Color
    var quickIcon: String = "plus"
    var detailIcon: String = "chart.line.uptrend.xyaxis"
    var quickAccessibility: String = "快速打卡"
    var detailAccessibility: String = "查看详情"
    let isQuickDisabled: Bool
    var showsQuickButton: Bool = true
    let onQuick: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showsQuickButton {
                iconButton(
                    icon: isQuickDisabled ? "checkmark" : quickIcon,
                    tint: isQuickDisabled ? Color.ohanaControlFill : accent,
                    foreground: isQuickDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText,
                    accessibility: isQuickDisabled ? "今日已完成" : quickAccessibility,
                    isDisabled: isQuickDisabled,
                    action: onQuick
                )
            }

            iconButton(
                icon: detailIcon,
                tint: Color.ohanaCardSurface,
                foreground: Color.ohanaPrimaryText,
                accessibility: detailAccessibility,
                isDisabled: false,
                action: onDetail
            )
        }
        .padding(5)
        .background(Color.ohanaControlFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8) // ui-v4: allow floating submenu lift
    }

    func iconButton(
        icon: String,
        tint: Color,
        foreground: Color,
        accessibility: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isDisabled else { return }
            OhanaFeedback.medium()
            action()
        } label: {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(accessibility)
    }
}

struct ExpandedPetQuickAddButton: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            addButtonLabel
        }
        .buttonStyle(ScaleButtonStyle())
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    var addButtonLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
            Text("添加")
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.86))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}

struct ExpandedHumanQuickAddButton: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            addButtonLabel
        }
        .buttonStyle(ScaleButtonStyle())
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    var addButtonLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.title3(.bold))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
            Text("添加")
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.86))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}

struct ExpandedQuickAddInlinePanel: View {
    let items: [QuickActionItem]
    let emptyTitle: String
    let onAdd: (QuickActionItem) -> Void
    let onClose: () -> Void

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("添加")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 0)
                Button {
                    OhanaFeedback.light()
                    onClose()
                } label: {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 24, height: 24) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if items.isEmpty {
                Text(emptyTitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            } else {
                ScrollView(.vertical, showsIndicators: items.count > 8) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(items) { item in
                            Button {
                                onAdd(item)
                            } label: {
                                VStack(spacing: 5) {
                                    OhanaQuickActionIcon(
                                        actionType: item.actionType,
                                        fallbackSystemName: item.icon,
                                        size: 22,
                                        color: Color.ohanaFunctionalIcon
                                    )
                                    .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                                    .background(Color.ohanaControlFill, in: Circle())
                                    Text(item.label)
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: 178)
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10) // ui-v4: allow floating inline quick-add menu
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }
}
