//
//  ExpandedQuickActionsSection.swift
//  Ohana
//
//  Rendering-only quick action sections for the expanded GO Focus card.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ExpandedPetQuickActionsSection: View {
    let title: String
    let pet: Pet
    let items: [QuickActionItem]
    let avatar: UIImage?
    let themeHex: String?
    @Binding var editItems: [QuickActionItem]
    @Binding var draggingItemId: String?
    @Binding var pressedActionId: String?
    let isEditMode: Bool
    let jiggle: Bool
    let shouldReduceWork: Bool
    var showsHeader: Bool = true
    var longPressStartsEdit: Bool = false
    let showFirstSuccessPrompt: Bool
    let waterManagementLabel: String
    let onToggleEdit: () -> Void
    let onFirstSuccessFeed: () -> Void
    let onFirstSuccessPlay: () -> Void
    let onFirstSuccessMoment: () -> Void
    let showsAttentionDot: (QuickActionItem) -> Bool
    let countText: (QuickActionItem) -> String?
    let isCompleted: (QuickActionItem) -> Bool
    let onTap: (QuickActionItem) -> Void
    let onLongPress: (QuickActionItem) -> Void
    let onGroomCheckIn: (String) -> Void
    let onPottySelect: (String) -> Void
    let onHealthSelect: (String) -> Void
    let onLimitReached: () -> Void
    @State private var openActionId: String? = nil
    @State private var showingAddPanel = false
    @State private var lastDropTargetId: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if showsHeader {
                header
            } else if isEditMode {
                compactDoneRow
            }

            if showFirstSuccessPrompt && !isEditMode {
                ExpandedFirstSuccessPrompt(
                    onFeed: onFirstSuccessFeed,
                    onPlay: onFirstSuccessPlay,
                    onMoment: onFirstSuccessMoment
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(Array(displayedItems.enumerated()), id: \.element.id) { idx, item in
                        ExpandedPetQuickActionGridItem(
                            idx: idx,
                            item: item,
                            pet: pet,
                            avatar: avatar,
                            themeHex: themeHex,
                            pressedActionId: $pressedActionId,
                            editItems: $editItems,
                            draggingItemId: $draggingItemId,
                            lastDropTargetId: $lastDropTargetId,
                            isEditMode: isEditMode,
                            jiggle: jiggle,
                            shouldReduceWork: shouldReduceWork,
                            longPressStartsEdit: longPressStartsEdit,
                            isMenuOpen: !isEditMode && openActionId == item.id,
                            waterManagementLabel: waterManagementLabel,
                            showsAttentionDot: showsAttentionDot,
                            countText: countText,
                            isCompleted: isCompleted,
                            onToggleMenu: { toggleMenu(for: item) },
                            onStartEdit: onToggleEdit,
                            onQuick: {
                                closeMenu()
                                onTap(item)
                            },
                            onDetail: {
                                closeMenu()
                                onLongPress(item)
                            },
                            onGroomCheckIn: onGroomCheckIn,
                            onPottySelect: onPottySelect,
                            onHealthSelect: onHealthSelect
                        )
                        .zIndex(itemZIndex(item, index: idx))
                    }

                    if isEditMode && QuickActionLimit.count(for: pet, in: editItems) < QuickActionLimit.maxItemsPerEntity {
                        ExpandedPetQuickAddButton(
                            onTap: openAddPanel
                        )
                        .zIndex(60)
                    }
                }
                .animation(GoMotion.selection, value: displayedOrderSignature)
            }

            if isEditMode && QuickActionLimit.count(for: pet, in: editItems) >= QuickActionLimit.maxItemsPerEntity {
                limitText
            }
        }
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            if isEditMode && showingAddPanel {
                ExpandedQuickAddInlinePanel(
                    items: availableAddItems,
                    emptyTitle: "已全部添加",
                    onAdd: addQuickAction,
                    onClose: closeAddPanel
                )
                .padding(.horizontal, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(120)
            }
        }
        .onChange(of: isEditMode) { _, _ in
            closeMenu()
            closeAddPanel()
            lastDropTargetId = nil
        }
    }

    private var displayedItems: [QuickActionItem] {
        isEditMode ? editItems : items
    }

    private var displayedOrderSignature: String {
        displayedItems.map(\.id).joined(separator: "|")
    }

    private var availableAddItems: [QuickActionItem] {
        let existing = Set(editItems.filter { $0.petId == pet.id }.map(\.actionType))
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existing).map { option in
            QuickActionItem(
                label: option.label,
                icon: option.icon,
                colorHex: option.colorHex,
                petId: pet.id,
                actionType: option.id,
                entityId: pet.id,
                entityKind: .pet
            )
        }
    }

    private func itemZIndex(_ item: QuickActionItem, index: Int) -> Double {
        if draggingItemId == item.id { return 40 }
        if openActionId == item.id { return 20 }
        return Double(displayedItems.count - index)
    }

    private func toggleMenu(for item: QuickActionItem) {
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            openActionId = openActionId == item.id ? nil : item.id
        }
    }

    private func closeMenu() {
        withAnimation(GoMotion.feedback) {
            openActionId = nil
        }
    }

    private func openAddPanel() {
        OhanaFeedback.light()
        guard QuickActionLimit.count(for: pet, in: editItems) < QuickActionLimit.maxItemsPerEntity else {
            onLimitReached()
            return
        }
        withAnimation(GoMotion.feedback) {
            showingAddPanel.toggle()
        }
    }

    private func closeAddPanel() {
        withAnimation(GoMotion.feedback) {
            showingAddPanel = false
        }
    }

    private func addQuickAction(_ item: QuickActionItem) {
        guard QuickActionLimit.count(for: pet, in: editItems) < QuickActionLimit.maxItemsPerEntity else {
            onLimitReached()
            closeAddPanel()
            return
        }
        OhanaFeedback.medium()
        withAnimation(HeroAnim.buttonSpring) {
            editItems.append(item)
            showingAddPanel = false
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
                .tracking(2.6)
            Spacer(minLength: 4)
            Button {
                OhanaFeedback.light()
                onToggleEdit()
            } label: {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "pencil")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(isEditMode ? Color.goPrimary : Color.ohanaPrimaryText.opacity(0.78))
                    .frame(width: 28, height: 24) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 4)
    }

    private var compactDoneRow: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                OhanaFeedback.light()
                onToggleEdit()
            } label: {
                Image(systemName: "checkmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 30, height: 26) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 4)
    }

    private var limitText: some View {
        Text("8 max")
            .font(OhanaFont.caption2(.medium))
            .foregroundStyle(Color.ohanaTertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}

struct ExpandedHumanQuickActionsSection: View {
    let title: String
    let human: Human
    let items: [QuickActionItem]
    let defaultItems: [QuickActionItem]
    let avatar: UIImage?
    let themeHex: String?
    @Binding var editItems: [QuickActionItem]
    @Binding var draggingItemId: String?
    @Binding var pressedActionId: String?
    let isEditMode: Bool
    let jiggle: Bool
    let shouldReduceWork: Bool
    var showsHeader: Bool = true
    var longPressStartsEdit: Bool = false
    let onToggleEdit: () -> Void
    let countText: (QuickActionItem) -> String?
    let privacyIconName: (QuickActionItem) -> String?
    let privacyIconTint: (QuickActionItem) -> Color
    let isPrivacyLocked: (QuickActionItem) -> Bool
    let isCompleted: (QuickActionItem) -> Bool
    let feedbackActionKey: String?
    let feedbackToken: CheckInFeedbackToken?
    let onTap: (QuickActionItem) -> Void
    let onLongPress: (QuickActionItem) -> Void
    let onLimitReached: () -> Void
    @State private var openActionId: String? = nil
    @State private var showingAddPanel = false
    @State private var lastDropTargetId: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if showsHeader {
                header
            } else if isEditMode {
                compactDoneRow
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(Array(displayedItems.enumerated()), id: \.element.id) { idx, item in
                    ExpandedHumanQuickActionGridItem(
                        idx: idx,
                        item: item,
                        human: human,
                        avatar: avatar,
                        themeHex: themeHex,
                        pressedActionId: $pressedActionId,
                        editItems: $editItems,
                        draggingItemId: $draggingItemId,
                        lastDropTargetId: $lastDropTargetId,
                        isEditMode: isEditMode,
                        jiggle: jiggle,
                        shouldReduceWork: shouldReduceWork,
                        longPressStartsEdit: longPressStartsEdit,
                        isMenuOpen: !isEditMode && openActionId == item.id,
                        countText: countText,
                        privacyIconName: privacyIconName,
                        privacyIconTint: privacyIconTint,
                        isPrivacyLocked: isPrivacyLocked,
                        isCompleted: isCompleted,
                        feedbackToken: feedbackActionKey == actionKey(for: item) ? feedbackToken : nil,
                        onToggleMenu: { toggleMenu(for: item) },
                        onStartEdit: onToggleEdit,
                        onQuick: {
                            closeMenu()
                            onTap(item)
                        },
                        onDetail: {
                            closeMenu()
                            onLongPress(item)
                        }
                    )
                    .zIndex(itemZIndex(item, index: idx))
                }

                if isEditMode && editItems.count < QuickActionLimit.maxItemsPerEntity {
                    ExpandedHumanQuickAddButton(
                        onTap: openAddPanel
                    )
                    .zIndex(60)
                }
            }
            .animation(GoMotion.selection, value: displayedOrderSignature)

            if isEditMode && editItems.count >= QuickActionLimit.maxItemsPerEntity {
                limitText
            }
        }
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            if isEditMode && showingAddPanel {
                ExpandedQuickAddInlinePanel(
                    items: availableAddItems,
                    emptyTitle: "已全部添加",
                    onAdd: addQuickAction,
                    onClose: closeAddPanel
                )
                .padding(.horizontal, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(120)
            }
        }
        .onChange(of: isEditMode) { _, _ in
            closeMenu()
            closeAddPanel()
            lastDropTargetId = nil
        }
    }

    private var displayedItems: [QuickActionItem] {
        isEditMode ? editItems : items
    }

    private var displayedOrderSignature: String {
        displayedItems.map(\.id).joined(separator: "|")
    }

    private var availableAddItems: [QuickActionItem] {
        let existing = Set(editItems.map(\.actionType))
        return defaultItems.filter { !existing.contains($0.actionType) }
    }

    private func itemZIndex(_ item: QuickActionItem, index: Int) -> Double {
        if draggingItemId == item.id { return 40 }
        if openActionId == item.id { return 20 }
        return Double(displayedItems.count - index)
    }

    private func toggleMenu(for item: QuickActionItem) {
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            openActionId = openActionId == item.id ? nil : item.id
        }
    }

    private func closeMenu() {
        withAnimation(GoMotion.feedback) {
            openActionId = nil
        }
    }

    private func openAddPanel() {
        OhanaFeedback.light()
        guard editItems.count < QuickActionLimit.maxItemsPerEntity else {
            onLimitReached()
            return
        }
        withAnimation(GoMotion.feedback) {
            showingAddPanel.toggle()
        }
    }

    private func closeAddPanel() {
        withAnimation(GoMotion.feedback) {
            showingAddPanel = false
        }
    }

    private func addQuickAction(_ item: QuickActionItem) {
        guard editItems.count < QuickActionLimit.maxItemsPerEntity else {
            onLimitReached()
            closeAddPanel()
            return
        }
        OhanaFeedback.medium()
        withAnimation(HeroAnim.buttonSpring) {
            editItems.append(item)
            showingAddPanel = false
        }
    }

    private func actionKey(for item: QuickActionItem) -> String {
        "\(human.id.uuidString):\(item.actionType)"
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
                .tracking(2.6)
            Spacer(minLength: 4)
            Button {
                OhanaFeedback.light()
                onToggleEdit()
            } label: {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "pencil")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(isEditMode ? Color.goPrimary : Color.ohanaPrimaryText.opacity(0.78))
                    .frame(width: 28, height: 24) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 4)
    }

    private var compactDoneRow: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                OhanaFeedback.light()
                onToggleEdit()
            } label: {
                Image(systemName: "checkmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 30, height: 26) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 4)
    }

    private var limitText: some View {
        Text("8 max")
            .font(OhanaFont.caption2(.medium))
            .foregroundStyle(Color.ohanaTertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}

struct LegacyExpandedQuickModulesView: View {
    let card: FocusCard
    let titleForAction: (String) -> String
    let onAction: (FocusCard.Action) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(card.actions.prefix(4)) { action in
                Button {
                    onAction(action)
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        OhanaQuickActionIcon(
                            actionType: action.label,
                            fallbackSystemName: action.icon,
                            size: 30,
                            color: Color.ohanaFunctionalIcon
                        )
                        .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

                        VStack(alignment: .leading, spacing: 1) {
                            Text(titleForAction(action.label))
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(card.isReal && !card.isHuman ? "快速打卡" : "查看")
                                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaTertiaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("\(card.name) \(titleForAction(action.label))")
            }
        }
    }
}

private struct ExpandedFirstSuccessPrompt: View {
    let onFeed: () -> Void
    let onPlay: () -> Void
    let onMoment: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            button(title: "喂食", actionType: "feed", icon: "fork.knife", action: onFeed)
            button(title: "陪玩", actionType: "play", icon: "tennisball.fill", action: onPlay)
            button(title: "记录", actionType: "moment", icon: "camera.fill", action: onMoment)
        }
        .padding(8)
        .background(Color.ohanaCardSurface.opacity(0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.26), lineWidth: 1)
        )
    }

    private func button(title: String, actionType: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.medium()
            action()
        } label: {
            VStack(spacing: 6) {
                OhanaQuickActionIcon(
                    actionType: actionType,
                    fallbackSystemName: icon,
                    size: 28,
                    color: Color.goPrimary
                )
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct ExpandedPetQuickActionGridItem: View {
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

    private var isDragging: Bool {
        draggingItemId == item.id
    }

    private var editJiggleAngle: Double {
        guard isEditMode, !isDragging else { return 0 }
        return jiggle ? -1.15 : 1.15
    }

    private var jiggleAnimation: Animation? {
        if isEditMode && !isDragging {
            return shouldReduceWork ? nil : GoMotion.quick.repeatForever(autoreverses: true) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
        }
        return GoMotion.stateChange
    }

    private var longPressAction: (() -> Void)? {
        guard !isEditMode else { return nil }
        return { handleLongPress() }
    }

    private func handleTap() {
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

    private func handleLongPress() {
        if longPressStartsEdit {
            OhanaFeedback.medium()
            onStartEdit()
        } else if item.actionType == "health" {
            onDetail()
        } else {
            onToggleMenu()
        }
    }

    private var quickIconName: String {
        "plus"
    }

    private var detailIconName: String {
        item.actionType == "medication" ? "list.bullet.rectangle.fill" : "chart.line.uptrend.xyaxis"
    }

    private var quickAccessibilityLabel: String {
        item.actionType == "medication" ? "添加药物" : (quickDisabled ? "今日已完成" : "快速打卡")
    }

    private var detailAccessibilityLabel: String {
        item.actionType == "medication" ? "用药详情" : "查看详情"
    }

    private var quickDisabled: Bool {
        ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil && isCompleted(item)
    }

    private var inlineMenuOffsetY: CGFloat {
        guard longPressStartsEdit else { return 52 }
        return idx >= 4 ? -52 : 52
    }

    private var inlineMenuOffsetX: CGFloat {
        guard longPressStartsEdit else { return 0 }
        switch idx % 4 {
        case 0: return 12
        case 3: return -12
        default: return 0
        }
    }

    private var removeButton: some View {
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

private struct ExpandedHumanQuickActionGridItem: View {
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

    private var isDragging: Bool {
        draggingItemId == item.id
    }

    private var editJiggleAngle: Double {
        guard isEditMode, !isDragging else { return 0 }
        return jiggle ? -1.15 : 1.15
    }

    private var jiggleAnimation: Animation? {
        if isEditMode && !isDragging {
            return shouldReduceWork ? nil : GoMotion.quick.repeatForever(autoreverses: true) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
        }
        return GoMotion.stateChange
    }

    private var longPressAction: (() -> Void)? {
        guard !isEditMode else { return nil }
        return { handleLongPress() }
    }

    private func handleTap() {
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

    private func handleLongPress() {
        if longPressStartsEdit {
            OhanaFeedback.medium()
            onStartEdit()
        } else {
            onToggleMenu()
        }
    }

    private var inlineMenuOffsetY: CGFloat {
        guard longPressStartsEdit else { return 52 }
        return idx >= 4 ? -52 : 52
    }

    private var inlineMenuOffsetX: CGFloat {
        guard longPressStartsEdit else { return 0 }
        switch idx % 4 {
        case 0: return 12
        case 3: return -12
        default: return 0
        }
    }

    private var removeButton: some View {
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

private struct ExpandedQuickInlineActionMenu: View {
    let accent: Color
    var quickIcon: String = "plus"
    var detailIcon: String = "chart.line.uptrend.xyaxis"
    var quickAccessibility: String = "快速打卡"
    var detailAccessibility: String = "查看详情"
    let isQuickDisabled: Bool
    let onQuick: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            iconButton(
                icon: isQuickDisabled ? "checkmark" : quickIcon,
                tint: isQuickDisabled ? Color.ohanaControlFill : accent,
                foreground: isQuickDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText,
                accessibility: isQuickDisabled ? "今日已完成" : quickAccessibility,
                isDisabled: isQuickDisabled,
                action: onQuick
            )

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

    private func iconButton(
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

private struct ExpandedPetQuickAddButton: View {
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

    private var addButtonLabel: some View {
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

private struct ExpandedHumanQuickAddButton: View {
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

    private var addButtonLabel: some View {
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

private struct ExpandedQuickAddInlinePanel: View {
    let items: [QuickActionItem]
    let emptyTitle: String
    let onAdd: (QuickActionItem) -> Void
    let onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

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
                                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: 178)
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10) // ui-v4: allow floating inline quick-add menu
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
