//
//  VerticalHomeShellComponents.swift
//  Ohana
//
//  Rendering-only shell pieces for the real-data portrait solid home style.
//

import SwiftUI

enum VerticalHomeTab: String, CaseIterable, Identifiable {
    case home
    case calendar
    case oasis
    case plants

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .home: l.tr(zh: "首页", en: "Home", de: "Start")
        case .calendar: l.tr(zh: "日历", en: "Calendar", de: "Kalender")
        case .oasis: l.tr(zh: "Oasis", en: "Oasis", de: "Oasis")
        case .plants: l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .calendar: "calendar"
        case .oasis: "tree.fill"
        case .plants: "leaf.fill"
        }
    }
}

struct VerticalHomePagedContent<Home: View, Calendar: View, Oasis: View, Plants: View>: View {
    let selectedTab: VerticalHomeTab
    @ViewBuilder var home: () -> Home
    @ViewBuilder var calendar: () -> Calendar
    @ViewBuilder var oasis: () -> Oasis
    @ViewBuilder var plants: () -> Plants

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var pagePosition: CGFloat = 0
    @State private var didSyncInitialPosition = false

    var body: some View {
        GeometryReader { geo in
            let position = didSyncInitialPosition ? pagePosition : CGFloat(selectedIndex)
            HStack(spacing: 0) {
                page(home(), tab: .home, size: geo.size, pagePosition: position)
                page(calendar(), tab: .calendar, size: geo.size, pagePosition: position)
                page(oasis(), tab: .oasis, size: geo.size, pagePosition: position)
                page(plants(), tab: .plants, size: geo.size, pagePosition: position)
            }
            .frame(width: geo.size.width * CGFloat(VerticalHomeTab.allCases.count), alignment: .leading)
            .offset(x: -geo.size.width * position)
            .onAppear {
                syncPagePosition(animated: false)
            }
            .onChange(of: selectedTab) { _, _ in
                syncPagePosition(animated: true)
            }
        }
        .clipped()
    }

    private var selectedIndex: Int {
        VerticalHomeTab.allCases.firstIndex(of: selectedTab) ?? 0
    }

    private var pageSwitchAnimation: Animation {
        .interactiveSpring(response: 0.48, dampingFraction: 0.88, blendDuration: 0.16)
    }

    private var canAnimatePages: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private func syncPagePosition(animated: Bool) {
        let target = CGFloat(selectedIndex)
        guard didSyncInitialPosition else {
            didSyncInitialPosition = true
            pagePosition = target
            return
        }
        guard abs(pagePosition - target) > 0.001 else { return }
        let animation = canAnimatePages ? pageSwitchAnimation : GoMotion.reduced
        if animated {
            withAnimation(animation) {
                pagePosition = target
            }
        } else {
            pagePosition = target
        }
    }

    @ViewBuilder
    private func page(_ content: some View, tab: VerticalHomeTab, size: CGSize, pagePosition: CGFloat) -> some View {
        let relative = relativePosition(for: tab, pagePosition: pagePosition)
        let pageContent = content
            .frame(width: size.width, height: size.height)
            .scaleEffect(pageScale(relative), anchor: .center)
            .rotation3DEffect(
                .degrees(pageRotation(relative)),
                axis: (x: 0, y: 1, z: 0),
                anchor: relative < 0 ? .trailing : .leading,
                perspective: 0.72
            )
            .offset(y: pageLift(relative))
            .opacity(pageOpacity(relative))
            .zIndex(Double(3 - min(abs(relative), 2)))
            .allowsHitTesting(abs(relative) < 0.5)

        if abs(relative) < 0.001 {
            pageContent
        } else {
            pageContent.compositingGroup()
        }
    }

    private func relativePosition(for tab: VerticalHomeTab, pagePosition: CGFloat) -> CGFloat {
        let index = VerticalHomeTab.allCases.firstIndex(of: tab) ?? 0
        return CGFloat(index) - pagePosition
    }

    private func pageScale(_ relative: CGFloat) -> CGFloat {
        1 - min(abs(relative), 1) * 0.10
    }

    private func pageRotation(_ relative: CGFloat) -> Double {
        Double(-min(max(relative, -1), 1) * 10)
    }

    private func pageLift(_ relative: CGFloat) -> CGFloat {
        min(abs(relative), 1) * 14
    }

    private func pageOpacity(_ relative: CGFloat) -> Double {
        let distance = abs(relative)
        guard distance > 1 else { return 1 }
        return max(0.18, 1 - Double(min(distance - 1, 1)) * 0.82)
    }
}

struct VerticalHomeTaskDeck: View {
    @Binding var isCollapsed: Bool
    let pendingCount: Int
    let height: CGFloat
    let activePets: [Pet]
    let plants: [Plant]
    let reminders: [Reminder]
    let humans: [Human]
    let events: [Event]
    let activePet: Pet?
    let showFirstSuccessCard: Bool
    let firstQuickCheckInCompleted: Bool
    let onOpenQuest: (IslandQuest) -> Void
    let onCompleteQuest: (IslandQuest) -> Void
    let onTapNegativeSignal: (IslandNegativeSignal) -> Void
    let onTapOasis: () -> Void
    let onTapFamilyTask: (FamilyCollaborationTask) -> Void
    let onFirstSuccessFeed: (Pet) -> Void
    let onFirstSuccessPlay: (Pet) -> Void
    let onFirstSuccessMoment: (Pet) -> Void

    @AppStorage("appLanguage") private var appLanguage = "zh"
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        expandedDeck
        .frame(height: height, alignment: .top)
    }

    private var expandedDeck: some View {
        ZStack {
            TodayFocusQuestCardHost(
                pets: activePets,
                plants: plants,
                reminders: reminders,
                humans: humans,
                events: events,
                activePet: activePet,
                presentation: .compactStack,
                onOpenQuest: onOpenQuest,
                onCompleteQuest: onCompleteQuest,
                onTapNegativeSignal: onTapNegativeSignal,
                onTapOasis: onTapOasis,
                onTapFamilyTask: onTapFamilyTask
            )
        }
    }

    private var collapsedTitle: String {
        pendingCount > 0
            ? l.tr(zh: "任务", en: "Focus", de: "Fokus")
            : l.tr(zh: "清空", en: "Clear", de: "Fertig")
    }
}

struct VerticalHomeBottomBar: View {
    @Binding var selectedTab: VerticalHomeTab
    @Binding var isFabExpanded: Bool
    @Binding var itemsVisible: Bool
    let activeCard: FocusCard?
    let homeShortcuts: [HomeFabFunctionShortcut]
    let expandedShortcuts: [ExpandedCardFabShortcut]
    let safeBottom: CGFloat
    let onTabSelected: (VerticalHomeTab) -> Void
    let onShortcut: (HomeFabFunctionShortcut) -> Void
    let onExpandedShortcut: (ExpandedCardFabShortcut, FocusCard) -> Void
    var onAddTapped: () -> Bool = { false }

    @AppStorage("appLanguage") private var appLanguage = "zh"
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var l: L10n { L10n(appLanguage) }
    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            menuRows
                .padding(.bottom, safeBottom + 98)

            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.calendar)

                Spacer(minLength: 76)

                tabButton(.oasis)
                tabButton(.plants)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(navBackground)
            .padding(.horizontal, 16)
            .padding(.bottom, safeBottom + 8)

            Button {
                OhanaFeedback.medium()
                if onAddTapped() {
                    return
                }
                toggleFab()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.goPrimary)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.goPrimary.opacity(0.32), radius: 18, x: 0, y: 8) // ui-v4: allow elevated primary nav add button
                    Image(systemName: centerButtonIcon)
                        .font(.system(size: 24, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .rotationEffect(.degrees(isFabExpanded ? 90 : 0))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, safeBottom + 26)
            .accessibilityLabel(centerButtonAccessibilityLabel)
        }
        .animation(HeroAnim.fabSpring, value: isFabExpanded)
        .animation(HeroAnim.fabSpring, value: itemsVisible)
    }

    private var centerButtonIcon: String {
        if isFabExpanded {
            return "xmark"
        }
        if activeCard != nil {
            return "square.grid.2x2.fill"
        }
        switch selectedTab {
        case .home:
            return "plus"
        case .calendar:
            return "plus"
        case .oasis:
            return "bolt.fill"
        case .plants:
            return "leaf.fill"
        }
    }

    private var centerButtonAccessibilityLabel: String {
        if isFabExpanded {
            return l.tr(zh: "收起菜单", en: "Close menu", de: "Menü schließen")
        }
        if activeCard != nil {
            return l.tr(zh: "打开快捷菜单", en: "Open quick menu", de: "Schnellmenü öffnen")
        }
        switch selectedTab {
        case .home:
            return l.tr(zh: "添加", en: "Add", de: "Hinzufügen")
        case .calendar:
            return l.tr(zh: "添加事件", en: "Add event", de: "Ereignis hinzufügen")
        case .oasis:
            return l.tr(zh: "注入能量", en: "Inject energy", de: "Energie einspeisen")
        case .plants:
            return l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen")
        }
    }

    private var navBackground: some View {
        Capsule()
            .fill(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.42 : 0.72))
            .overlay {
                Capsule()
                    .strokeBorder(Color.ohanaGlassStroke.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color.arkInk.opacity(0.18), radius: 20, x: 0, y: 10) // ui-v4: allow home bottom navigation lift
    }

    @ViewBuilder
    private var menuRows: some View {
        if isFabExpanded {
            let expandedContext = activeCard.map { card in
                expandedShortcuts.map { shortcut in
                    VerticalFabMenuItem(
                        id: shortcut.id,
                        label: shortcut.label,
                        icon: shortcut.icon,
                        isAvailable: shortcut.isAvailable,
                        badge: shortcut.badge,
                        action: { onExpandedShortcut(shortcut, card) }
                    )
                }
            }
            let items = expandedContext ?? homeShortcuts.map { shortcut in
                VerticalFabMenuItem(
                    id: shortcut.id,
                    label: shortcut.label,
                    icon: shortcut.icon,
                    isAvailable: shortcut.isAvailable,
                    badge: shortcut.badge,
                    action: { onShortcut(shortcut) }
                )
            }

            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VerticalFabShortcutButton(item: item)
                        .scaleEffect(canAnimate ? (itemsVisible ? 1 : 0.88) : 1, anchor: .bottom)
                        .opacity(itemsVisible ? 1 : 0)
                        .offset(
                            x: 0,
                            y: canAnimate ? (itemsVisible ? 0 : 34) : 0
                        )
                        .animation(
                            canAnimate ? HeroAnim.fabSpring.delay(GoMotion.staggerDelay(index, step: 0.035, maxDelay: 0.14)) : GoMotion.reduced,
                            value: itemsVisible
                        )
                        .allowsHitTesting(itemsVisible)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        }
    }

    private func tabButton(_ tab: VerticalHomeTab) -> some View {
        Button {
            OhanaFeedback.light()
            onTabSelected(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .black))
                    .symbolRenderingMode(.monochrome)
                Text(tab.title(l))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(selectedTab == tab ? Color.goPrimary : Color.ohanaSecondaryText)
            .scaleEffect(selectedTab == tab ? 1.04 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: selectedTab)
    }

    private func toggleFab() {
        if isFabExpanded {
            withAnimation(HeroAnim.fabSpring) {
                itemsVisible = false
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
                guard !itemsVisible else { return }
                withAnimation(HeroAnim.fabSpring) {
                    isFabExpanded = false
                }
            }
        } else {
            itemsVisible = false
            withAnimation(HeroAnim.fabSpring) {
                isFabExpanded = true
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
                withAnimation(HeroAnim.fabSpring) {
                    itemsVisible = true
                }
            }
        }
    }
}

private struct VerticalFabMenuItem: Identifiable {
    let id: String
    let label: String
    let icon: String
    let isAvailable: Bool
    let badge: String?
    let action: () -> Void
}

private struct VerticalFabShortcutButton: View {
    let item: VerticalFabMenuItem

    var body: some View {
        Button {
            guard item.isAvailable else {
                OhanaFeedback.light()
                return
            }
            item.action()
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(item.isAvailable ? 1 : 0.36))
                        .frame(width: 42, height: 42)
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryActionText.opacity(item.isAvailable ? 1 : 0.54))
                        .frame(width: 42, height: 42)

                    if let badge = item.badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(Color.goYellow, in: Capsule())
                            .offset(x: 5, y: -4)
                    }
                }

                Text(item.label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: 44)
            }
            .opacity(item.isAvailable ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(item.label)
    }
}

struct VerticalHomeComingSoonPage: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goPrimary)
            Text(title)
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(subtitle)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VerticalHomeEmbeddedAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isCompleted: Bool
    let detailIcon: String
    let quickAccessibilityLabel: String
    let detailAccessibilityLabel: String
    let detailAction: (() -> Void)?
    let action: () -> Void

    init(
        id: String,
        title: String,
        icon: String,
        isCompleted: Bool,
        detailIcon: String = "chart.line.uptrend.xyaxis",
        quickAccessibilityLabel: String = "Quick action",
        detailAccessibilityLabel: String = "Details",
        detailAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isCompleted = isCompleted
        self.detailIcon = detailIcon
        self.quickAccessibilityLabel = quickAccessibilityLabel
        self.detailAccessibilityLabel = detailAccessibilityLabel
        self.detailAction = detailAction
        self.action = action
    }
}

struct VerticalHomeEmbeddedQuickActions: View {
    let title: String
    let items: [VerticalHomeEmbeddedAction]
    let onAll: () -> Void
    @State private var openActionId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.78))
                Spacer()
                Button {
                    OhanaFeedback.light()
                    onAll()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goCardWhite)
                        .frame(width: 32, height: 28)
                        .background(Color.goCardWhite.opacity(0.14), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    actionCell(item, index: index)
                        .zIndex(openActionId == item.id ? 40 : Double(items.count - index))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.arkInk.opacity(0.18), in: RoundedRectangle(cornerRadius: 24, style: .continuous)) // ui-v4: allow embedded card action dock contrast
        .onChange(of: items.map(\.id).joined(separator: "|")) { _, _ in
            openActionId = nil
        }
    }

    private func actionCell(_ item: VerticalHomeEmbeddedAction, index: Int) -> some View {
        ZStack {
            Button {
                OhanaFeedback.light()
                if item.detailAction == nil {
                    item.action()
                } else {
                    withAnimation(GoMotion.feedback) {
                        openActionId = openActionId == item.id ? nil : item.id
                    }
                }
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: item.isCompleted ? "checkmark" : item.icon)
                        .font(.system(size: 16, weight: .black))
                        .symbolRenderingMode(.monochrome)
                    Text(item.title)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
                .foregroundStyle(Color.goCardWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.goCardWhite.opacity(item.isCompleted ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if openActionId == item.id, let detailAction = item.detailAction {
                verticalEmbeddedInlineMenu(
                    item: item,
                    detailAction: detailAction,
                    index: index
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                .zIndex(80)
            }
        }
    }

    private func verticalEmbeddedInlineMenu(
        item: VerticalHomeEmbeddedAction,
        detailAction: @escaping () -> Void,
        index: Int
    ) -> some View {
        HStack(spacing: 8) {
            inlineMenuButton(
                icon: item.isCompleted ? "checkmark" : "plus",
                accessibility: item.quickAccessibilityLabel,
                action: item.action
            )
            inlineMenuButton(
                icon: item.detailIcon,
                accessibility: item.detailAccessibilityLabel,
                action: detailAction
            )
        }
        .padding(6)
        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
        .shadow(color: Color.arkInk.opacity(0.24), radius: 14, x: 0, y: 8) // ui-v4: allow embedded quick action submenu lift
        .offset(x: menuOffsetX(index: index), y: menuOffsetY(index: index))
    }

    private func inlineMenuButton(icon: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.light()
            withAnimation(GoMotion.feedback) {
                openActionId = nil
            }
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(width: 38, height: 34)
                .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibility)
    }

    private func menuOffsetY(index: Int) -> CGFloat {
        index >= 3 ? -54 : 54
    }

    private func menuOffsetX(index: Int) -> CGFloat {
        switch index % 3 {
        case 0: return 16
        case 2: return -16
        default: return 0
        }
    }
}
