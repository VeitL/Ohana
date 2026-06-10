//
//  ExpandedQuickActionsSection+HumanSection.swift
//  Ohana
//

import SwiftUI
import UniformTypeIdentifiers

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
    @State var openActionId: String? = nil
    @State var showingAddPanel = false
    @State var lastDropTargetId: String? = nil

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

    var displayedItems: [QuickActionItem] {
        isEditMode ? editItems : items
    }

    var displayedOrderSignature: String {
        displayedItems.map(\.id).joined(separator: "|")
    }

    var availableAddItems: [QuickActionItem] {
        let existing = Set(editItems.map(\.actionType))
        return defaultItems.filter { !existing.contains($0.actionType) }
    }

    func itemZIndex(_ item: QuickActionItem, index: Int) -> Double {
        if draggingItemId == item.id { return 40 }
        if openActionId == item.id { return 20 }
        return Double(displayedItems.count - index)
    }

    func toggleMenu(for item: QuickActionItem) {
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            openActionId = openActionId == item.id ? nil : item.id
        }
    }

    func closeMenu() {
        withAnimation(GoMotion.feedback) {
            openActionId = nil
        }
    }

    func openAddPanel() {
        OhanaFeedback.light()
        guard editItems.count < QuickActionLimit.maxItemsPerEntity else {
            onLimitReached()
            return
        }
        withAnimation(GoMotion.feedback) {
            showingAddPanel.toggle()
        }
    }

    func closeAddPanel() {
        withAnimation(GoMotion.feedback) {
            showingAddPanel = false
        }
    }

    func addQuickAction(_ item: QuickActionItem) {
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

    func actionKey(for item: QuickActionItem) -> String {
        "\(human.id.uuidString):\(item.actionType)"
    }

    var header: some View {
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

    var compactDoneRow: some View {
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

    var limitText: some View {
        Text("8 max")
            .font(OhanaFont.caption2(.medium))
            .foregroundStyle(Color.ohanaTertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}
