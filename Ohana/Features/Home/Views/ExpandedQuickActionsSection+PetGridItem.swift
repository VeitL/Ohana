//
//  ExpandedQuickActionsSection+PetGridItem.swift
//  Ohana
//

import SwiftUI
import UniformTypeIdentifiers

struct ExpandedPetQuickActionGridItem: View {
    let idx: Int
    let item: QuickActionItem
    let pet: Pet
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
    let waterManagementLabel: String
    let showsAttentionDot: (QuickActionItem) -> Bool
    let countText: (QuickActionItem) -> String?
    let isCompleted: (QuickActionItem) -> Bool
    let onToggleMenu: () -> Void
    let onStartEdit: () -> Void
    let onQuick: () -> Void
    let onDetail: () -> Void
    let onGroomCheckIn: (String) -> Void
    let onPottySelect: (String) -> Void
    let onHealthSelect: (String) -> Void

    var body: some View {
        ZStack {
            GoQuickActionCard(
                item: item,
                isPressed: !isEditMode && pressedActionId == item.id,
                petAvatar: avatar,
                petThemeColorHex: themeHex,
                displayIcon: WaterQuickActionPolicy.iconOverride(for: item, pet: pet),
                titleLabelOverride: WaterQuickActionPolicy.titleOverride(for: item, pet: pet, managementLabel: waterManagementLabel),
                showsAttentionDot: !isEditMode && showsAttentionDot(item),
                countText: isEditMode ? nil : countText(item),
                isCompletedToday: !isEditMode && isCompleted(item),
                prefersLightForeground: true,
                onTap: handleTap,
                onLongPress: longPressAction,
                onGroomCheckIn: nil,
                onPottySelect: nil,
                onHealthSelect: nil
            )
            .allowsHitTesting(!isEditMode)

            if isMenuOpen {
                ExpandedQuickInlineActionMenu(
                    accent: Color.goPrimary,
                    quickIcon: quickIconName,
                    detailIcon: detailIconName,
                    quickAccessibility: quickAccessibilityLabel,
                    detailAccessibility: detailAccessibilityLabel,
                    isQuickDisabled: quickDisabled,
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
        if item.actionType == "health" {
            onDetail()
        } else {
            onToggleMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            pressedActionId = nil
        }
    }

    func handleLongPress() {
        if longPressStartsEdit {
            OhanaFeedback.medium()
            onStartEdit()
        } else if item.actionType == "health" {
            onDetail()
        } else {
            onToggleMenu()
        }
    }

    var quickIconName: String {
        "plus"
    }

    var detailIconName: String {
        item.actionType == "medication" ? "list.bullet.rectangle.fill" : "chart.line.uptrend.xyaxis"
    }

    var quickAccessibilityLabel: String {
        item.actionType == "medication" ? "添加药物" : (quickDisabled ? "今日已完成" : "快速打卡")
    }

    var detailAccessibilityLabel: String {
        item.actionType == "medication" ? "用药详情" : "查看详情"
    }

    var quickDisabled: Bool {
        ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil && isCompleted(item)
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
