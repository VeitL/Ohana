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

    var body: some View {
        VStack(spacing: 8) {
            header

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
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        ExpandedPetQuickActionGridItem(
                            idx: idx,
                            item: item,
                            pet: pet,
                            avatar: avatar,
                            themeHex: themeHex,
                            pressedActionId: $pressedActionId,
                            editItems: $editItems,
                            draggingItemId: $draggingItemId,
                            isEditMode: isEditMode,
                            jiggle: jiggle,
                            shouldReduceWork: shouldReduceWork,
                            isMenuOpen: !isEditMode && openActionId == item.id,
                            waterManagementLabel: waterManagementLabel,
                            showsAttentionDot: showsAttentionDot,
                            countText: countText,
                            isCompleted: isCompleted,
                            onToggleMenu: { toggleMenu(for: item) },
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
                        .zIndex(openActionId == item.id ? 20 : Double(items.count - idx))
                    }

                    if isEditMode && QuickActionLimit.count(for: pet, in: editItems) < QuickActionLimit.maxItemsPerEntity {
                        ExpandedPetQuickAddButton(
                            pet: pet,
                            editItems: $editItems,
                            onLimitReached: onLimitReached
                        )
                    }
                }
            }

            if isEditMode && QuickActionLimit.count(for: pet, in: editItems) >= QuickActionLimit.maxItemsPerEntity {
                limitText
            }
        }
        .padding(.horizontal, 2)
        .onChange(of: isEditMode) { _, _ in closeMenu() }
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
                    .frame(width: 28, height: 24)
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
            .transition(.opacity)
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

    var body: some View {
        VStack(spacing: 8) {
            header

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    ExpandedHumanQuickActionGridItem(
                        idx: idx,
                        item: item,
                        human: human,
                        avatar: avatar,
                        themeHex: themeHex,
                        pressedActionId: $pressedActionId,
                        editItems: $editItems,
                        draggingItemId: $draggingItemId,
                        isEditMode: isEditMode,
                        jiggle: jiggle,
                        shouldReduceWork: shouldReduceWork,
                        isMenuOpen: !isEditMode && openActionId == item.id,
                        countText: countText,
                        privacyIconName: privacyIconName,
                        privacyIconTint: privacyIconTint,
                        isPrivacyLocked: isPrivacyLocked,
                        isCompleted: isCompleted,
                        feedbackToken: feedbackActionKey == actionKey(for: item) ? feedbackToken : nil,
                        onToggleMenu: { toggleMenu(for: item) },
                        onQuick: {
                            closeMenu()
                            onTap(item)
                        },
                        onDetail: {
                            closeMenu()
                            onLongPress(item)
                        }
                    )
                    .zIndex(openActionId == item.id ? 20 : Double(items.count - idx))
                }

                if isEditMode && editItems.count < QuickActionLimit.maxItemsPerEntity {
                    ExpandedHumanQuickAddButton(
                        defaultItems: defaultItems,
                        editItems: $editItems,
                        onLimitReached: onLimitReached
                    )
                }
            }

            if isEditMode && editItems.count >= QuickActionLimit.maxItemsPerEntity {
                limitText
            }
        }
        .padding(.horizontal, 2)
        .onChange(of: isEditMode) { _, _ in closeMenu() }
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
                    .frame(width: 28, height: 24)
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
            .transition(.opacity)
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
                        Image(systemName: action.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Color(hex: action.colorHex))
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(titleForAction(action.label))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(card.isReal && !card.isHuman ? "快速打卡" : "查看")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
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
            button(title: "喂食", icon: "fork.knife", action: onFeed)
            button(title: "陪玩", icon: "tennisball.fill", action: onPlay)
            button(title: "记录", icon: "camera.fill", action: onMoment)
        }
        .padding(8)
        .background(Color.ohanaCardSurface.opacity(0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.26), lineWidth: 1)
        )
    }

    private func button(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.medium()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 28, height: 28)
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
    let isEditMode: Bool
    let jiggle: Bool
    let shouldReduceWork: Bool
    let isMenuOpen: Bool
    let waterManagementLabel: String
    let showsAttentionDot: (QuickActionItem) -> Bool
    let countText: (QuickActionItem) -> String?
    let isCompleted: (QuickActionItem) -> Bool
    let onToggleMenu: () -> Void
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
                onLongPress: isEditMode ? nil : onToggleMenu,
                onGroomCheckIn: nil,
                onPottySelect: nil,
                onHealthSelect: nil
            )
            .allowsHitTesting(!isEditMode)

            if isMenuOpen {
                ExpandedQuickInlineActionMenu(
                    accent: Color(hex: item.colorHex),
                    isQuickDisabled: quickDisabled,
                    onQuick: onQuick,
                    onDetail: onDetail
                )
                .offset(y: 52)
                .ohanaInlineMenuMotion(trigger: isMenuOpen)
                .zIndex(12)
            }

            if isEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeHex, draggingItemId: $draggingItemId)
            }
        }
        .rotationEffect(.degrees(isEditMode ? (jiggle ? -2.5 : 2.5) : 0))
        .animation(
            isEditMode
                ? (shouldReduceWork ? nil : GoMotion.quick.repeatForever(autoreverses: true))
                : GoMotion.stateChange,
            value: jiggle
        )
        .overlay(alignment: .topLeading) {
            if isEditMode {
                removeButton
            }
        }
        .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(targetItem: item, items: $editItems, draggingItemId: $draggingItemId))
    }

    private func handleTap() {
        guard !isEditMode else { return }
        pressedActionId = item.id
        OhanaFeedback.medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pressedActionId = nil
            onToggleMenu()
        }
    }

    private var quickDisabled: Bool {
        ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil && isCompleted(item)
    }

    private var removeButton: some View {
        Button {
            OhanaFeedback.strong()
            withAnimation(HeroAnim.buttonSpring) {
                editItems.removeAll { $0.id == item.id }
            }
        } label: {
            ZStack {
                Circle().fill(Color.goRed).frame(width: 20, height: 20)
                Image(systemName: "minus")
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
    let isEditMode: Bool
    let jiggle: Bool
    let shouldReduceWork: Bool
    let isMenuOpen: Bool
    let countText: (QuickActionItem) -> String?
    let privacyIconName: (QuickActionItem) -> String?
    let privacyIconTint: (QuickActionItem) -> Color
    let isPrivacyLocked: (QuickActionItem) -> Bool
    let isCompleted: (QuickActionItem) -> Bool
    let feedbackToken: CheckInFeedbackToken?
    let onToggleMenu: () -> Void
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
                onLongPress: isEditMode ? nil : onToggleMenu
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
                    accent: Color(hex: item.colorHex),
                    isQuickDisabled: false,
                    onQuick: onQuick,
                    onDetail: onDetail
                )
                .offset(y: 52)
                .ohanaInlineMenuMotion(trigger: isMenuOpen)
                .zIndex(12)
            }

            if isEditMode {
                QAEditModeDragLayer(item: item, themeHex: themeHex, draggingItemId: $draggingItemId)
            }
        }
        .rotationEffect(.degrees(isEditMode ? (jiggle ? -2.5 : 2.5) : 0))
        .animation(
            isEditMode
                ? (shouldReduceWork ? nil : GoMotion.quick.repeatForever(autoreverses: true))
                : GoMotion.stateChange,
            value: jiggle
        )
        .overlay(alignment: .topLeading) {
            if isEditMode {
                removeButton
            }
        }
        .onDrop(of: [.plainText, .utf8PlainText], delegate: QADropDelegate(targetItem: item, items: $editItems, draggingItemId: $draggingItemId))
    }

    private func handleTap() {
        guard !isEditMode else { return }
        pressedActionId = item.id
        OhanaFeedback.medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pressedActionId = nil
            onToggleMenu()
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
                Circle().fill(Color.goRed).frame(width: 20, height: 20)
                Image(systemName: "minus")
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
    let isQuickDisabled: Bool
    let onQuick: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            iconButton(
                icon: isQuickDisabled ? "checkmark" : "checkmark.circle.fill",
                tint: isQuickDisabled ? Color.ohanaControlFill : accent,
                foreground: isQuickDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText,
                accessibility: isQuickDisabled ? "今日已完成" : "快速打卡",
                isDisabled: isQuickDisabled,
                action: onQuick
            )

            iconButton(
                icon: "chart.line.uptrend.xyaxis",
                tint: Color.ohanaCardSurface,
                foreground: Color.ohanaPrimaryText,
                accessibility: "查看详情",
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
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background(tint, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(accessibility)
    }
}

private struct ExpandedPetQuickAddButton: View {
    let pet: Pet
    @Binding var editItems: [QuickActionItem]
    let onLimitReached: () -> Void
    @State private var showingQuickAdd = false

    var body: some View {
        Button {
            OhanaFeedback.light()
            guard QuickActionLimit.count(for: pet, in: editItems) < QuickActionLimit.maxItemsPerEntity else {
                onLimitReached()
                return
            }
            showingQuickAdd = true
        } label: {
            addButtonLabel
        }
        .buttonStyle(ScaleButtonStyle())
        .popover(isPresented: $showingQuickAdd, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            QAQuickAddPopoverContent(pet: pet, existingItems: editItems) { newItem in
                withAnimation(HeroAnim.buttonSpring) {
                    if QuickActionLimit.count(for: pet, in: editItems) < QuickActionLimit.maxItemsPerEntity {
                        editItems.append(newItem)
                    }
                }
            }
            .presentationCompactAdaptation(.popover)
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var addButtonLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
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
    let defaultItems: [QuickActionItem]
    @Binding var editItems: [QuickActionItem]
    let onLimitReached: () -> Void

    var body: some View {
        Menu {
            if editItems.count >= QuickActionLimit.maxItemsPerEntity {
                Button("已达 8 个上限，可去「全部功能」查看更多") {
                    onLimitReached()
                }
            }
            let existing = Set(editItems.map(\.actionType))
            ForEach(defaultItems.filter { !existing.contains($0.actionType) }) { item in
                Button {
                    guard editItems.count < QuickActionLimit.maxItemsPerEntity else {
                        onLimitReached()
                        return
                    }
                    withAnimation(HeroAnim.buttonSpring) {
                        editItems.append(item)
                    }
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
            }
        } label: {
            addButtonLabel
        }
        .buttonStyle(ScaleButtonStyle())
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var addButtonLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
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
