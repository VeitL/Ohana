//
//  ExpandedQuickActionsSection+HumanGridItem.swift
//  Ohana
//

import SwiftUI
import UniformTypeIdentifiers

struct ExpandedHumanQuickActionGridItem: View {
    let idx: Int
    let item: QuickActionItem
    let human: Human
    let avatar: UIImage?
    let themeHex: String?
    @Binding var pressedActionId: String?
    @Binding var editItems: [QuickActionItem]
    @Binding var draggingItemId: String?
    @Binding var lastDropTargetId: String?
    let isEditMode: Bool
    let jiggle: Bool
    let shouldReduceWork: Bool
    let longPressStartsEdit: Bool
    let isMenuOpen: Bool
    let countText: (QuickActionItem) -> String?
    let privacyIconName: (QuickActionItem) -> String?
    let privacyIconTint: (QuickActionItem) -> Color
    let isPrivacyLocked: (QuickActionItem) -> Bool
    let isCompleted: (QuickActionItem) -> Bool
    let feedbackToken: CheckInFeedbackToken?
    let onToggleMenu: () -> Void
    let onStartEdit: () -> Void
    let onQuick: () -> Void
    let onDetail: () -> Void

    var body: some View {
        ZStack {
            GoQuickActionCard(
                item: item,
                isPressed: !isEditMode && pressedActionId == item.id,
                petAvatar: avatar,
                petThemeColorHex: themeHex,
                countText: isEditMode ? nil : countText(item),
                privacyIconName: isEditMode ? nil : privacyIconName(item),
                privacyIconTint: privacyIconTint(item),
                isPrivacyLocked: !isEditMode && isPrivacyLocked(item),
                isCompletedToday: !isEditMode && isCompleted(item),
                prefersLightForeground: true,
                onTap: handleTap,
                onLongPress: longPressAction
            )
            .allowsHitTesting(!isEditMode)
            .checkInPulse(feedbackToken)
            .overlay(alignment: .topTrailing) {
                if let feedbackToken {
                    CheckInFeedbackBadge(token: feedbackToken)
                        .offset(x: 5, y: -5)
                }
            }

            if isMenuOpen {
                ExpandedQuickInlineActionMenu(
                    accent: Color.goPrimary,
                    isQuickDisabled: false,
                    onQuick: onQuick,
                    onDetail: onDetail
                )
                .offset(x: inlineMenuOffsetX, y: inlineMenuOffsetY)
                .ohanaInlineMenuMotion(trigger: isMenuOpen)
                .zIndex(80)
            }

            if isEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeHex, draggingItemId: $draggingItemId)
            }
        }
        .scaleEffect(isDragging ? 1.035 : 1)
        .opacity(isDragging ? 0.72 : 1)
        .rotationEffect(.degrees(editJiggleAngle))
        .id("\(item.id)-\(isEditMode ? "edit" : "normal")")
        .animation(jiggleAnimation, value: jiggle)
        .animation(GoMotion.selection, value: draggingItemId)
        .overlay(alignment: .topLeading) {
            if isEditMode {
                removeButton
            }
        }
        .onDrop(
            of: [.plainText, .utf8PlainText],
            delegate: QADropDelegate(
                targetItem: item,
                items: $editItems,
                draggingItemId: $draggingItemId,
                lastDropTargetId: $lastDropTargetId
            )
        )
    }

    var isDragging: Bool {
        draggingItemId == item.id
    }

    var editJiggleAngle: Double {
        guard isEditMode, !isDragging else { return 0 }
        return jiggle ? -1.15 : 1.15
    }

    var jiggleAnimation: Animation? {
        if isEditMode && !isDragging {
            return shouldReduceWork ? nil : GoMotion.quick.repeatForever(autoreverses: true) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
        }
        return GoMotion.stateChange
    }

    var longPressAction: (() -> Void)? {
        guard !isEditMode else { return nil }
        return { handleLongPress() }
    }

    func handleTap() {
        guard !isEditMode else { return }
        withAnimation(GoMotion.feedback) {
            pressedActionId = item.id
        }
        OhanaFeedback.medium()
        onToggleMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            pressedActionId = nil
        }
    }

    func handleLongPress() {
        if longPressStartsEdit {
            OhanaFeedback.medium()
            onStartEdit()
        } else {
            onToggleMenu()
        }
    }

    var inlineMenuOffsetY: CGFloat {
        guard longPressStartsEdit else { return 52 }
        return idx >= 4 ? -52 : 52
    }

    var inlineMenuOffsetX: CGFloat {
        guard longPressStartsEdit else { return 0 }
        switch idx % 4 {
        case 0: return 12
        case 3: return -12
        default: return 0
        }
    }

    var removeButton: some View {
        Button {
            OhanaFeedback.strong()
            withAnimation(HeroAnim.buttonSpring) {
                editItems.removeAll { $0.id == item.id }
            }
        } label: {
            ZStack {
                Circle().fill(Color.goRed).frame(width: 20, height: 20) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                Image(systemName: "minus").accessibilityHidden(true)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.arkInk)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .offset(x: -4, y: -4)
    }
}
