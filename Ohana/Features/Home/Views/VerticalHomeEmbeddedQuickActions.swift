//
//  VerticalHomeEmbeddedQuickActions.swift
//  Ohana
//
//  Embedded quick-action grid used inside the active vertical solid home card.
//

import SwiftUI
import UniformTypeIdentifiers

struct VerticalHomeEmbeddedAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let actionType: String
    let statusText: String?
    let isCompleted: Bool
    let showsAttention: Bool
    let isLocked: Bool
    let isAddDisabled: Bool
    let primaryIcon: String
    let isPrimaryDisabled: Bool
    let detailIcon: String
    let menuOptions: [VerticalHomeEmbeddedActionOption]
    let showsMenu: Bool
    let showsQuickButton: Bool
    let quickAccessibilityLabel: String
    let detailAccessibilityLabel: String
    let detailAction: (() -> Void)?
    let optionAction: (String) -> Void
    let action: () -> Void

    init(
        id: String,
        title: String,
        icon: String,
        actionType: String? = nil,
        statusText: String? = nil,
        isCompleted: Bool,
        showsAttention: Bool = false,
        isLocked: Bool = false,
        isAddDisabled: Bool = false,
        primaryIcon: String = "bolt.fill",
        isPrimaryDisabled: Bool = false,
        detailIcon: String = "chart.line.uptrend.xyaxis",
        menuOptions: [VerticalHomeEmbeddedActionOption] = [],
        showsMenu: Bool = true,
        showsQuickButton: Bool = true,
        quickAccessibilityLabel: String = "Quick action",
        detailAccessibilityLabel: String = "Details",
        detailAction: (() -> Void)? = nil,
        optionAction: @escaping (String) -> Void = { _ in },
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.actionType = actionType ?? Self.inferredActionType(id: id, icon: icon)
        self.statusText = statusText
        self.isCompleted = isCompleted
        self.showsAttention = showsAttention
        self.isLocked = isLocked
        self.isAddDisabled = isAddDisabled
        self.primaryIcon = primaryIcon
        self.isPrimaryDisabled = isPrimaryDisabled
        self.detailIcon = detailIcon
        self.menuOptions = menuOptions
        self.showsMenu = showsMenu
        self.showsQuickButton = showsQuickButton
        self.quickAccessibilityLabel = quickAccessibilityLabel
        self.detailAccessibilityLabel = detailAccessibilityLabel
        self.detailAction = detailAction
        self.optionAction = optionAction
        self.action = action
    }

    private static func inferredActionType(id: String, icon: String) -> String {
        let fallback = id.split(separator: "-").last.map(String.init) ?? id
        return OhanaQuickActionGlyphKind.resolve(actionType: fallback, fallbackSystemName: icon) == nil
            ? id
            : fallback
    }
}

struct VerticalHomeEmbeddedActionOption: Identifiable {
    let id: String
    let icon: String
    let title: String
    let tint: Color
}

struct VerticalHomeEmbeddedQuickActions: View {
    let title: String
    let items: [VerticalHomeEmbeddedAction]
    var addItems: [VerticalHomeEmbeddedAction] = []
    let localization: L10n
    var itemsRevision: String = ""
    var addItemsRevision: String = ""
    var isEditMode = false
    var jiggle = false
    var shouldReduceWork = false
    var forcesSubmenusBelow = true
    var draggingItemId: Binding<String?>?
    var onToggleEdit: (() -> Void)?
    var onMove: (_ fromId: String, _ toId: String) -> Void = { _, _ in }
    var onRemove: (_ id: String) -> Void = { _ in }
    var onAdd: (_ id: String) -> Void = { _ in }

    @State private var openActionId: String?
    @State private var showingAddPanel = false
    @State private var lastDropTargetId: String?
    @State private var iconAnimationTokens: [String: Int] = [:]

    private var l: L10n { localization }
    private let maxItems = QuickActionLimit.maxItemsPerEntity
    private let cellHeight: CGFloat = 72
    private let iconSize: CGFloat = 29

    private var visibleItems: [VerticalHomeEmbeddedAction] {
        Array(items.prefix(maxItems))
    }

    private var visibleItemsRevision: String {
        itemsRevision.isEmpty ? Self.revisionKey(for: visibleItems) : itemsRevision
    }

    private var availableAddItems: [VerticalHomeEmbeddedAction] {
        guard isEditMode, visibleItems.count < maxItems else { return [] }
        return addItems
    }

    private var availableAddItemsRevision: String {
        addItemsRevision.isEmpty ? Self.revisionKey(for: availableAddItems) : addItemsRevision
    }

    private var showsAddLauncher: Bool {
        isEditMode && visibleItems.count < maxItems && !availableAddItems.isEmpty
    }

    private var activeDraggingItemId: String? {
        draggingItemId?.wrappedValue
    }

    private var isDraggingAnyItem: Bool {
        activeDraggingItemId != nil
    }

    private var motion: Animation {
        shouldReduceWork ? GoMotion.reduced : GoMotion.fab
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 4), spacing: 8) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    actionCell(item, index: index)
                        .zIndex(openActionId == item.id ? 40 : Double(visibleItems.count - index))
                }

                if showsAddLauncher {
                    addLauncherCell
                        .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                        .zIndex(35)
                }
            }
            .animation(GoMotion.selection, value: visibleItemsRevision)
            .animation(GoMotion.selection, value: availableAddItemsRevision)
            .onDrop(
                of: [.plainText, .utf8PlainText],
                delegate: VerticalHomeEmbeddedActionDropResetDelegate(
                    isEnabled: isEditMode,
                    draggingItemId: draggingItemId,
                    lastDropTargetId: $lastDropTargetId
                )
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if isEditMode, showingAddPanel {
                addOptionsPanel
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.84, anchor: .bottom))
                                .combined(with: .offset(y: 18)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.94, anchor: .bottom))
                                .combined(with: .offset(y: 10))
                        )
                    )
                    .zIndex(120)
            }
        }
        .onChange(of: visibleItemsRevision) { _, _ in
            openActionId = nil
            if visibleItems.count >= maxItems || availableAddItems.isEmpty {
                showingAddPanel = false
            }
        }
        .onChange(of: isEditMode) { _, _ in
            openActionId = nil
            lastDropTargetId = nil
            showingAddPanel = false
        }
        .onChange(of: activeDraggingItemId) { _, newValue in
            if newValue == nil {
                lastDropTargetId = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite.opacity(0.92))
            Spacer()
            if let onToggleEdit {
                Button {
                    OhanaFeedback.light()
                    withAnimation(GoMotion.feedback) {
                        openActionId = nil
                    }
                    onToggleEdit()
                } label: {
                    Image(systemName: isEditMode ? "checkmark" : "pencil")
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isEditMode ? Color.goPrimary : Color.goCardWhite)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isEditMode
                    ? l.tr(zh: "完成编辑快捷操作", en: "Done editing quick actions", de: "Schnellaktionen fertig bearbeiten")
                    : l.tr(zh: "编辑快捷操作", en: "Edit quick actions", de: "Schnellaktionen bearbeiten"))
            }
        }
    }

    private func actionCell(_ item: VerticalHomeEmbeddedAction, index: Int) -> some View {
        ZStack {
            Button {
                guard !isEditMode else { return }
                triggerIconAnimation(for: item.id)
                OhanaFeedback.light()
                if shouldOpenMenu(for: item) {
                    withAnimation(motion) {
                        openActionId = openActionId == item.id ? nil : item.id
                    }
                } else {
                    item.action()
                }
            } label: {
                let state = visualState(for: item)
                let statusLine = statusText(for: item)
                VStack(spacing: 2) {
                    ZStack(alignment: .topTrailing) {
                        OhanaQuickActionIcon(
                            actionType: item.actionType,
                            fallbackSystemName: item.icon,
                            size: iconSize,
                            color: state.foreground,
                            isCompleted: state.showsCompleted,
                            showsCompletionBadge: state.showsCompleted,
                            animationTrigger: iconAnimationTokens[item.id, default: 0],
                            animatesStateChanges: !shouldReduceWork
                        )
                        if item.showsAttention, !isEditMode {
                            Circle()
                                .fill(Color.goRed)
                                .frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                                .offset(x: 3, y: -3)
                        }
                        if item.isLocked, !isEditMode {
                            Image(systemName: "lock.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 8, weight: .black))
                                .foregroundStyle(Color.goYellow)
                                .offset(x: 4, y: -4)
                        }
                    }
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(state.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(statusLine)
                        .font(OhanaFont.adaptive(size: 8.4, weight: .bold, design: .rounded))
                        .foregroundStyle(state.statusForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity)
                .frame(height: cellHeight)
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .allowsHitTesting(!isEditMode)
            .accessibilityLabel(accessibilityLabel(for: item, statusText: statusText(for: item)))

            if openActionId == item.id {
                inlineMenu(item: item, detailAction: item.detailAction, index: index)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.82, anchor: .top))
                                .combined(with: .offset(y: -10)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.92, anchor: .top))
                                .combined(with: .offset(y: -4))
                        )
                    )
                    .zIndex(80)
            }

            if isEditMode {
                editDragLayer(for: item)
            }
        }
        .scaleEffect(isDragging(item) ? 1.035 : 1)
        .opacity(isDragging(item) ? 0.72 : 1)
        .rotationEffect(.degrees(editJiggleAngle(for: item)))
        .animation(editJiggleAnimation, value: jiggle)
        .animation(GoMotion.selection, value: activeDraggingItemId)
        .animation(motion, value: openActionId)
        .overlay(alignment: .topLeading) {
            if isEditMode {
                removeButton(for: item)
            }
        }
        .onDrop(
            of: [.plainText, .utf8PlainText],
            delegate: VerticalHomeEmbeddedActionDropDelegate(
                isEnabled: isEditMode,
                targetId: item.id,
                draggingItemId: draggingItemId,
                lastDropTargetId: $lastDropTargetId,
                onMove: onMove
            )
        )
    }

    private func inlineMenu(item: VerticalHomeEmbeddedAction, detailAction: (() -> Void)?, index: Int) -> some View {
        HStack(spacing: 8) {
            if item.menuOptions.isEmpty {
                if item.showsQuickButton {
                    inlineMenuButton(
                        actionType: item.actionType,
                        icon: item.isPrimaryDisabled ? "checkmark" : item.primaryIcon,
                        tint: item.isPrimaryDisabled ? Color.goCardWhite.opacity(0.16) : Color.goPrimary,
                        foreground: item.isPrimaryDisabled ? Color.goCardWhite.opacity(0.42) : Color.arkInk,
                        accessibility: item.quickAccessibilityLabel,
                        isDisabled: item.isPrimaryDisabled,
                        action: item.action
                    )
                }
            } else {
                ForEach(item.menuOptions) { option in
                    inlineMenuButton(
                        actionType: option.id,
                        icon: option.icon,
                        tint: option.tint.opacity(0.92),
                        foreground: Color.arkInk,
                        accessibility: option.title,
                        isDisabled: false,
                        action: { item.optionAction(option.id) }
                    )
                }
            }

            if let detailAction {
                inlineMenuButton(
                    actionType: detailActionType(for: item),
                    icon: item.detailIcon,
                    tint: Color.goCardWhite.opacity(0.16),
                    foreground: Color.goCardWhite,
                    accessibility: item.detailAccessibilityLabel,
                    isDisabled: false,
                    action: detailAction
                )
            }
        }
        .padding(6)
        .background(Color.arkInk.opacity(0.34), in: Capsule()) // ui-v4: allow embedded quick action submenu contrast on dark card gradient
        .shadow(color: Color.arkInk.opacity(0.24), radius: 14, x: 0, y: 8) // ui-v4: allow embedded quick action submenu lift
        .fixedSize()
        .offset(x: menuOffsetX(index: index, optionCount: item.menuOptions.count), y: menuOffsetY(index: index))
    }

    private func shouldOpenMenu(for item: VerticalHomeEmbeddedAction) -> Bool {
        guard item.showsMenu else { return false }
        return item.showsQuickButton || item.detailAction != nil || !item.menuOptions.isEmpty
    }

    private func inlineMenuButton(
        actionType: String,
        icon: String,
        tint: Color,
        foreground: Color,
        accessibility: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isDisabled else { return }
            OhanaFeedback.light()
            withAnimation(motion) {
                openActionId = nil
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 28) {
                action()
            }
        } label: {
            OhanaQuickActionIcon(
                actionType: actionType,
                fallbackSystemName: icon,
                size: 20,
                color: foreground,
                animatesStateChanges: false
            )
            .frame(width: 44, height: 38)
            .background(tint, in: Circle())
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(accessibility)
    }

    private func detailActionType(for item: VerticalHomeEmbeddedAction) -> String {
        let action = item.actionType.lowercased()
        if item.detailIcon.contains("credit") { return "expense" }
        if item.detailIcon.contains("chart") { return action.contains("weight") ? "weight" : "document" }
        if item.detailIcon.contains("sparkles") { return "moment" }
        if item.detailIcon.contains("list") { return "document" }
        return item.actionType
    }

    private var addLauncherCell: some View {
        Button {
            OhanaFeedback.light()
            withAnimation(motion) {
                openActionId = nil
                showingAddPanel.toggle()
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "plus").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.goCardWhite.opacity(0.12), in: Circle())
                Text(l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                    .font(OhanaFont.adaptive(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .stroke(
                        Color.goCardWhite.opacity(0.24),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"))
    }

    private var addOptionsPanel: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 0)
                Button {
                    OhanaFeedback.light()
                    withAnimation(motion) {
                        showingAddPanel = false
                    }
                } label: {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 28, height: 28) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            ScrollView(.vertical, showsIndicators: availableAddItems.count > 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 7), count: 4), spacing: 7) {
                    ForEach(availableAddItems) { item in
                        Button {
                            guard !item.isAddDisabled else { return }
                            OhanaFeedback.medium()
                            withAnimation(motion) {
                                showingAddPanel = false
                            }
                            onAdd(item.id)
                        } label: {
                            addOptionCell(item)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(item.isAddDisabled)
                    }
                }
            }
            .frame(maxHeight: 179)
        }
        .padding(10)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .shadow(color: Color.arkInk.opacity(0.22), radius: 20, x: 0, y: 12) // ui-v4: allow floating quick-action add panel
    }

    private func addOptionCell(_ item: VerticalHomeEmbeddedAction) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 5) {
                OhanaQuickActionIcon(
                    actionType: item.actionType,
                    fallbackSystemName: item.icon,
                    size: 23,
                    color: item.isAddDisabled ? Color.ohanaSecondaryText : Color.ohanaFunctionalIcon
                )
                Text(item.title)
                    .font(OhanaFont.adaptive(size: 9.5, weight: .black, design: .rounded))
                    .foregroundStyle(item.isAddDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)

            if item.isAddDisabled {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                    .padding(6)
            }
        }
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .opacity(item.isAddDisabled ? 0.62 : 1)
    }

    private func editDragLayer(for item: VerticalHomeEmbeddedAction) -> some View {
        Color.clear
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .onDrag {
                OhanaFeedback.light()
                showingAddPanel = false
                openActionId = nil
                lastDropTargetId = nil
                withAnimation(GoMotion.selection) {
                    draggingItemId?.wrappedValue = item.id
                }
                return NSItemProvider(object: item.id as NSString)
            } preview: {
                VStack(spacing: 6) {
                    OhanaQuickActionIcon(
                        actionType: item.actionType,
                        fallbackSystemName: item.icon,
                        size: 34,
                        color: Color.goPrimary
                    )
                    .frame(width: 44, height: 44)
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .fixedSize()
            }
    }

    private func removeButton(for item: VerticalHomeEmbeddedAction) -> some View {
        Button {
            OhanaFeedback.strong()
            onRemove(item.id)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.goRed)
                    .frame(width: 20, height: 20) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(systemName: "minus").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 9, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.arkInk)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .offset(x: -14, y: -14)
        .accessibilityLabel(l.tr(zh: "移除快捷操作", en: "Remove quick action", de: "Schnellaktion entfernen"))
    }

    private func isDragging(_ item: VerticalHomeEmbeddedAction) -> Bool {
        activeDraggingItemId == item.id
    }

    private func triggerIconAnimation(for id: String) {
        guard !shouldReduceWork else { return }
        iconAnimationTokens[id, default: 0] += 1
    }

    private func editJiggleAngle(for item: VerticalHomeEmbeddedAction) -> Double {
        guard isEditMode, !isDraggingAnyItem, !isDragging(item) else { return 0 }
        return jiggle ? -1.05 : 1.05
    }

    private var editJiggleAnimation: Animation? {
        guard isEditMode, !shouldReduceWork, !isDraggingAnyItem else { return nil }
        return GoMotion.quick.repeatForever(autoreverses: true) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
    }

    private func menuOffsetY(index: Int) -> CGFloat {
        if forcesSubmenusBelow {
            return 66
        }
        return index >= 4 ? -52 : 52
    }

    private func menuOffsetX(index: Int, optionCount: Int) -> CGFloat {
        let isWide = optionCount > 2
        switch index % 4 {
        case 0: return isWide ? 82 : 18
        case 1: return isWide ? 26 : 0
        case 2: return isWide ? -26 : 0
        case 3: return isWide ? -82 : -18
        default: return 0
        }
    }

    private static func revisionKey(for items: [VerticalHomeEmbeddedAction]) -> String {
        items.map(\.id).joined(separator: "|")
    }

    private func visualState(for item: VerticalHomeEmbeddedAction) -> (
        showsCompleted: Bool,
        foreground: Color,
        statusForeground: Color
    ) {
        let completed = item.isCompleted && !isEditMode
        if item.isLocked, !isEditMode {
            return (false, Color.goCardWhite.opacity(0.74), Color.goYellow.opacity(0.92))
        }
        if completed {
            return (true, Color.goPrimary, Color.goPrimary.opacity(0.9))
        }
        if item.showsAttention, !isEditMode {
            return (false, Color.goCardWhite, Color.goRed.mix(with: Color.goCardWhite, by: 0.18))
        }
        return (false, Color.goCardWhite, Color.goCardWhite.opacity(0.58))
    }

    private func statusText(for item: VerticalHomeEmbeddedAction) -> String {
        guard !isEditMode else { return " " }
        if item.isLocked {
            return l.tr(zh: "私密", en: "Private", de: "Privat")
        }
        if let raw = item.statusText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            return raw
        }
        if item.isCompleted {
            return l.tr(zh: "已打卡", en: "Done", de: "Erledigt")
        }
        if item.showsAttention {
            return l.tr(zh: "待处理", en: "Needs care", de: "Offen")
        }
        if showsCheckInStatus(for: item) {
            return l.tr(zh: "未打卡", en: "Open", de: "Offen")
        }
        return " "
    }

    private func showsCheckInStatus(for item: VerticalHomeEmbeddedAction) -> Bool {
        let action = item.actionType.lowercased()
        return [
            "feed",
            "water",
            "walk",
            "potty",
            "litter",
            "groom",
            "health",
            "medication",
            "play",
            "cagecleaning",
            "freeflight",
            "misting",
            "substratechange",
            "humanworkout"
        ].contains { action.contains($0) }
    }

    private func accessibilityLabel(for item: VerticalHomeEmbeddedAction, statusText: String) -> String {
        let trimmed = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? item.quickAccessibilityLabel : "\(item.quickAccessibilityLabel), \(trimmed)"
    }
}

private struct VerticalHomeEmbeddedActionDropResetDelegate: DropDelegate {
    let isEnabled: Bool
    let draggingItemId: Binding<String?>?
    @Binding var lastDropTargetId: String?

    func validateDrop(info _: DropInfo) -> Bool {
        isEnabled
    }

    func performDrop(info _: DropInfo) -> Bool {
        draggingItemId?.wrappedValue = nil
        lastDropTargetId = nil
        return isEnabled
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        isEnabled ? DropProposal(operation: .move) : nil
    }

    func dropExited(info _: DropInfo) {
        lastDropTargetId = nil
    }
}

private struct VerticalHomeEmbeddedActionDropDelegate: DropDelegate {
    let isEnabled: Bool
    let targetId: String
    let draggingItemId: Binding<String?>?
    @Binding var lastDropTargetId: String?
    let onMove: (_ fromId: String, _ toId: String) -> Void

    func performDrop(info _: DropInfo) -> Bool {
        draggingItemId?.wrappedValue = nil
        lastDropTargetId = nil
        return isEnabled
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled, lastDropTargetId != targetId else { return }
        if let fromId = draggingItemId?.wrappedValue {
            move(fromId)
            return
        }

        let types: [UTType] = [.plainText, .utf8PlainText]
        guard let provider = info.itemProviders(for: types).first else { return }
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let ns = obj as? NSString else { return }
            let fromId = ns as String
            DispatchQueue.main.async {
                move(fromId)
            }
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        isEnabled ? DropProposal(operation: .move) : nil
    }

    func dropExited(info _: DropInfo) {
        if lastDropTargetId == targetId {
            lastDropTargetId = nil
        }
    }

    private func move(_ fromId: String) {
        guard fromId != targetId else { return }
        lastDropTargetId = targetId
        OhanaFeedback.light()
        onMove(fromId, targetId)
    }
}
