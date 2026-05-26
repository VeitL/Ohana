//
//  VerticalHomeShellComponents.swift
//  Ohana
//
//  Rendering-only shell pieces for the real-data portrait solid home style.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

enum VerticalHomeTab: String, CaseIterable, Identifiable, Hashable {
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

@MainActor
final class VerticalHomeTabVisualState: ObservableObject {
    @Published private(set) var selectedTab: VerticalHomeTab
    private var commitTask: Task<Void, Never>?

    init(selectedTab: VerticalHomeTab = .home) {
        self.selectedTab = selectedTab
    }

    deinit {
        commitTask?.cancel()
    }

    func select(_ tab: VerticalHomeTab) {
        guard selectedTab != tab else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedTab = tab
        }
    }

    func sync(_ tab: VerticalHomeTab) {
        select(tab)
    }

    func scheduleCommit(
        for tab: VerticalHomeTab,
        milliseconds: UInt64,
        commit: @escaping @MainActor () -> Void
    ) {
        commitTask?.cancel()
        commitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) { [weak self] in
            guard let self, self.selectedTab == tab else { return }
            commit()
            self.commitTask = nil
        }
    }

    func cancelCommit() {
        commitTask?.cancel()
        commitTask = nil
    }
}

enum VerticalHomeTabMountPolicy {
    static func mountedTabs(
        active: VerticalHomeTab,
        outgoing: VerticalHomeTab?,
        prepared: Set<VerticalHomeTab> = []
    ) -> Set<VerticalHomeTab> {
        var tabs: Set<VerticalHomeTab> = prepared
        tabs.insert(active)
        if let outgoing {
            tabs.insert(outgoing)
        }
        return tabs
    }

    static func lifecycle(
        for tab: VerticalHomeTab,
        active: VerticalHomeTab,
        outgoing: VerticalHomeTab?,
        selected: VerticalHomeTab,
        preparing: VerticalHomeTab? = nil,
        prepared: Set<VerticalHomeTab> = []
    ) -> VerticalHomePageLifecycle {
        let isActivePage = tab == active
        let isVisiblePage = isActivePage || tab == outgoing
        let isPreparingPage = tab == preparing
        return VerticalHomePageLifecycle(
            isPrepared: isPreparingPage || prepared.contains(tab) || (isActivePage && selected == tab),
            isPreparingForDisplay: isPreparingPage,
            isVisible: isVisiblePage,
            isLive: isActivePage && outgoing == nil && selected == tab
        )
    }
}

struct VerticalHomePageLifecycle: Equatable {
    let isPrepared: Bool
    let isPreparingForDisplay: Bool
    let isVisible: Bool
    let isLive: Bool
}

struct VerticalHomePagedContent<Home: View, Calendar: View, Oasis: View, Plants: View>: View {
    @ObservedObject var tabState: VerticalHomeTabVisualState
    @ViewBuilder var home: (_ lifecycle: VerticalHomePageLifecycle) -> Home
    @ViewBuilder var calendar: (_ lifecycle: VerticalHomePageLifecycle) -> Calendar
    @ViewBuilder var oasis: (_ lifecycle: VerticalHomePageLifecycle) -> Oasis
    @ViewBuilder var plants: (_ lifecycle: VerticalHomePageLifecycle) -> Plants

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var activeTab: VerticalHomeTab = .home
    @State private var outgoingTab: VerticalHomeTab?
    @State private var preparingTab: VerticalHomeTab?
    @State private var mountedTabs: Set<VerticalHomeTab> = [.home]
    @State private var preparedTabs: Set<VerticalHomeTab> = []
    @State private var transitionProgress: CGFloat = 1
    @State private var transitionDirection: CGFloat = 1
    @State private var preflightTask: Task<Void, Never>?
    @State private var animationTask: Task<Void, Never>?
    @State private var cleanupTask: Task<Void, Never>?
    @State private var prepareTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(mountedTabsInDisplayOrder, id: \.self) { tab in
                    let isVisiblePage = tab == activeTab || tab == outgoingTab
                    let isActivePage = tab == activeTab
                    let lifecycle = VerticalHomeTabMountPolicy.lifecycle(
                        for: tab,
                        active: activeTab,
                        outgoing: outgoingTab,
                        selected: tabState.selectedTab,
                        preparing: preparingTab,
                        prepared: preparedTabs
                    )
                    page(
                        for: tab,
                        size: geo.size,
                        relative: pageRelative(for: tab),
                        isActive: isActivePage,
                        lifecycle: lifecycle,
                        isVisiblePage: isVisiblePage
                    )
                    .zIndex(pageZIndex(for: tab))
                    .allowsHitTesting(lifecycle.isLive)
                    .accessibilityHidden(!lifecycle.isLive)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .onAppear {
            syncActiveTabIfNeeded()
            schedulePreparedTabsWarmup()
        }
        .onDisappear {
            cleanupTask?.cancel()
            cleanupTask = nil
            preflightTask?.cancel()
            preflightTask = nil
            animationTask?.cancel()
            animationTask = nil
            prepareTask?.cancel()
            prepareTask = nil
        }
        .onChange(of: tabState.selectedTab) { _, newValue in
            beginPageTransition(to: newValue)
        }
    }

    private var mountedTabsInDisplayOrder: [VerticalHomeTab] {
        VerticalHomeTab.allCases.filter { mountedTabs.contains($0) }
    }

    private var warmupTabs: Set<VerticalHomeTab> {
        Set(warmupOrder)
    }

    private var warmupOrder: [VerticalHomeTab] {
        [.calendar, .oasis, .plants]
    }

    private var hasActivePageTransition: Bool {
        outgoingTab != nil
    }

    private var incomingRelative: CGFloat {
        guard outgoingTab != nil else { return 0 }
        return transitionDirection * (1 - transitionProgress)
    }

    private var outgoingRelative: CGFloat {
        guard outgoingTab != nil else { return 0 }
        return -transitionDirection * transitionProgress
    }

    private var pageSwitchAnimation: Animation {
        GoMotion.page
    }

    private var canAnimatePages: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var cleanupDelayMilliseconds: UInt64 {
        canAnimatePages ? 520 : 130
    }

    private func preflightDelayMilliseconds(for tab: VerticalHomeTab) -> UInt64 {
        if tab == .oasis {
            return 0
        }
        return preparedTabs.contains(tab) ? 8 : 32
    }

    @ViewBuilder
    private func page(
        for tab: VerticalHomeTab,
        size: CGSize,
        relative: CGFloat,
        isActive _: Bool,
        lifecycle: VerticalHomePageLifecycle,
        isVisiblePage: Bool
    ) -> some View {
        ZStack {
            pageContent(for: tab, lifecycle: lifecycle)
                .transaction { transaction in
                    if outgoingTab != nil {
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
        }
        .frame(width: size.width, height: size.height)
        .offset(x: pageOffset(relative, width: size.width))
        .animation(hasActivePageTransition && canAnimatePages ? pageSwitchAnimation : nil, value: transitionProgress)
        .opacity(isVisiblePage ? 1 : 0)
    }

    @ViewBuilder
    private func pageContent(for tab: VerticalHomeTab, lifecycle: VerticalHomePageLifecycle) -> some View {
        switch tab {
        case .home:
            home(lifecycle)
        case .calendar:
            calendar(lifecycle)
        case .oasis:
            oasis(lifecycle)
        case .plants:
            plants(lifecycle)
        }
    }

    private func syncActiveTabIfNeeded() {
        guard activeTab != tabState.selectedTab else { return }
        cleanupTask?.cancel()
        cleanupTask = nil
        preflightTask?.cancel()
        preflightTask = nil
        animationTask?.cancel()
        animationTask = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            mountedTabs = mountedTabsFor(active: tabState.selectedTab, outgoing: nil)
            activeTab = tabState.selectedTab
            outgoingTab = nil
            preparingTab = nil
            transitionProgress = 1
        }
    }

    private func schedulePreparedTabsWarmup() {
        guard !warmupTabs.isSubset(of: preparedTabs) else { return }
        prepareTask?.cancel()
        prepareTask = Task { @MainActor in
            for (index, tab) in warmupOrder.enumerated() where !preparedTabs.contains(tab) {
                await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: index == 0 ? 360 : 180)
                guard !Task.isCancelled else { return }
                guard !preparedTabs.contains(tab) else { continue }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    preparedTabs.insert(tab)
                    mountedTabs = mountedTabsFor(active: activeTab, outgoing: outgoingTab)
                }
            }
            prepareTask = nil
        }
    }

    private func beginPageTransition(to tab: VerticalHomeTab) {
        guard tab != activeTab else {
            cleanupOutgoingPage()
            return
        }

        cleanupTask?.cancel()
        preflightTask?.cancel()
        animationTask?.cancel()
        prepareTask?.cancel()
        prepareTask = nil
        let previousTab = activeTab
        let direction = transitionDirection(from: previousTab, to: tab)
        let preflightDelay = preflightDelayMilliseconds(for: tab)

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            preparingTab = tab
            preparedTabs.insert(tab)
            mountedTabs = mountedTabsFor(active: activeTab, outgoing: outgoingTab)
            transitionDirection = direction
            transitionProgress = 1
        }

        preflightTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: preflightDelay) {
            guard preparingTab == tab, activeTab == previousTab else {
                preflightTask = nil
                return
            }
            startPreparedPageTransition(to: tab, from: previousTab, direction: direction)
            preflightTask = nil
        }
    }

    private func startPreparedPageTransition(to tab: VerticalHomeTab, from previousTab: VerticalHomeTab, direction: CGFloat) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            preparingTab = nil
            outgoingTab = previousTab
            activeTab = tab
            preparedTabs.insert(tab)
            mountedTabs = mountedTabsFor(active: tab, outgoing: previousTab)
            transitionDirection = direction
            transitionProgress = 0
        }

        let shouldAnimate = canAnimatePages
        let cleanupDelay = cleanupDelayMilliseconds
        let animation = pageSwitchAnimation
        if shouldAnimate {
            animationTask = OhanaFrameScheduler.runAfterNextFrame {
                guard activeTab == tab, outgoingTab == previousTab else { return }
                withAnimation(animation) {
                    transitionProgress = 1
                }
                animationTask = nil
            }
        } else {
            var reducedTransaction = Transaction(animation: nil)
            reducedTransaction.disablesAnimations = true
            withTransaction(reducedTransaction) {
                transitionProgress = 1
            }
        }

        cleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: cleanupDelay) {
            guard activeTab == tab else { return }
            cleanupOutgoingPage()
        }
    }

    private func cleanupOutgoingPage() {
        cleanupTask?.cancel()
        cleanupTask = nil
        preflightTask?.cancel()
        preflightTask = nil
        animationTask?.cancel()
        animationTask = nil
        guard outgoingTab != nil || preparingTab != nil || transitionProgress != 1 else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            outgoingTab = nil
            preparingTab = nil
            transitionProgress = 1
            mountedTabs = mountedTabsFor(active: activeTab, outgoing: nil)
        }
        schedulePreparedTabsWarmup()
    }

    private func mountedTabsFor(active: VerticalHomeTab, outgoing: VerticalHomeTab?) -> Set<VerticalHomeTab> {
        VerticalHomeTabMountPolicy.mountedTabs(active: active, outgoing: outgoing, prepared: preparedTabs)
    }

    private func pageRelative(for tab: VerticalHomeTab) -> CGFloat {
        if tab == activeTab {
            return incomingRelative
        }
        if tab == outgoingTab {
            return outgoingRelative
        }
        if tab == preparingTab {
            return transitionDirection
        }
        return 0
    }

    private func pageZIndex(for tab: VerticalHomeTab) -> Double {
        if tab == activeTab { return 3 }
        if tab == outgoingTab { return 2 }
        return 0
    }

    private func transitionDirection(from oldTab: VerticalHomeTab, to newTab: VerticalHomeTab) -> CGFloat {
        let oldIndex = VerticalHomeTab.allCases.firstIndex(of: oldTab) ?? 0
        let newIndex = VerticalHomeTab.allCases.firstIndex(of: newTab) ?? oldIndex
        return newIndex >= oldIndex ? 1 : -1
    }

    private func pageOffset(_ relative: CGFloat, width: CGFloat) -> CGFloat {
        min(max(relative, -1), 1) * width
    }
}

struct VerticalHomeTaskDeck: View {
    @Binding var isCollapsed: Bool
    let isVisible: Bool
    let isLive: Bool
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
    let onConfirmExchange: (CoconutExchangeRequest) -> Void
    let onFirstSuccessFeed: (Pet) -> Void
    let onFirstSuccessPlay: (Pet) -> Void
    let onFirstSuccessMoment: (Pet) -> Void

    @AppStorage("appLanguage") private var appLanguage = "zh"
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Group {
            if isVisible || isLive {
                expandedDeck
            } else {
                Color.clear
            }
        }
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isLive)
            .accessibilityHidden(!isVisible)
            .transaction { transaction in
                if !isVisible {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
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
                isLive: isLive,
                presentation: .compactStack,
                onOpenQuest: onOpenQuest,
                onCompleteQuest: onCompleteQuest,
                onTapNegativeSignal: onTapNegativeSignal,
                onTapOasis: onTapOasis,
                onTapFamilyTask: onTapFamilyTask,
                onConfirmExchange: onConfirmExchange
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
    @ObservedObject var tabState: VerticalHomeTabVisualState
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
    private var selectedTab: VerticalHomeTab { tabState.selectedTab }
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
                if activeCard != nil {
                    toggleFab()
                    return
                }
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
            return "plus"
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
            return l.tr(zh: "显示该成员剩余功能", en: "Show remaining member features", de: "Weitere Funktionen anzeigen")
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
                    OhanaQuickActionIcon(
                        actionType: item.id,
                        fallbackSystemName: item.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(item.isAvailable ? 1 : 0.54)
                    )
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
    let isAddDisabled: Bool
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
        isAddDisabled: Bool = false,
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
        self.isAddDisabled = isAddDisabled
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
    var addItems: [VerticalHomeEmbeddedAction] = []
    var isEditMode: Bool = false
    var jiggle: Bool = false
    var shouldReduceWork: Bool = false
    var forcesSubmenusBelow: Bool = true
    var draggingItemId: Binding<String?>?
    var onToggleEdit: (() -> Void)?
    var onMove: (_ fromId: String, _ toId: String) -> Void = { _, _ in }
    var onRemove: (_ id: String) -> Void = { _ in }
    var onAdd: (_ id: String) -> Void = { _ in }
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @State private var openActionId: String? = nil
    @State private var lastDropTargetId: String? = nil
    @State private var showingAddPanel = false

    private var l: L10n { L10n(appLanguage) }
    private let cellHeight: CGFloat = 66
    private let iconSize: CGFloat = 30
    private let maxItems = QuickActionLimit.maxItemsPerEntity

    private var visibleItems: [VerticalHomeEmbeddedAction] {
        Array(items.prefix(maxItems))
    }

    private var availableAddItems: [VerticalHomeEmbeddedAction] {
        guard isEditMode, visibleItems.count < maxItems else { return [] }
        return addItems
    }

    private var showsAddLauncher: Bool {
        isEditMode && visibleItems.count < maxItems && !availableAddItems.isEmpty
    }

    private var activeDraggingItemId: String? {
        guard let draggingItemId else { return nil }
        return draggingItemId.wrappedValue
    }

    private var isDraggingAnyItem: Bool {
        activeDraggingItemId != nil
    }

    private var submenuAnimation: Animation {
        shouldReduceWork ? GoMotion.reduced : GoMotion.fab
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
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
                            .font(.system(size: 13, weight: .black))
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
            .animation(GoMotion.selection, value: visibleItems.map(\.id).joined(separator: "|"))
            .animation(GoMotion.selection, value: availableAddItems.map(\.id).joined(separator: "|"))
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
            if isEditMode && showingAddPanel {
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
        .onChange(of: items.map(\.id).joined(separator: "|")) { _, _ in
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

    private func actionCell(_ item: VerticalHomeEmbeddedAction, index: Int) -> some View {
        ZStack {
            Button {
                guard !isEditMode else { return }
                OhanaFeedback.light()
                if item.detailAction == nil {
                    item.action()
                } else {
                    withAnimation(submenuAnimation) {
                        openActionId = openActionId == item.id ? nil : item.id
                    }
                }
            } label: {
                let showsCompleted = item.isCompleted && !isEditMode
                VStack(spacing: 6) {
                    OhanaQuickActionIcon(
                        actionType: item.id,
                        fallbackSystemName: item.icon,
                        size: iconSize,
                        color: showsCompleted ? Color.goPrimary : Color.goCardWhite,
                        isCompleted: showsCompleted,
                        showsCompletionBadge: showsCompleted
                    )
                    Text(item.title)
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(showsCompleted ? Color.goPrimary : Color.goCardWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity)
                .frame(height: cellHeight)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .allowsHitTesting(!isEditMode)

            if openActionId == item.id, let detailAction = item.detailAction {
                verticalEmbeddedInlineMenu(
                    item: item,
                    detailAction: detailAction,
                    index: index
                )
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
        .animation(submenuAnimation, value: openActionId)
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
        .background(Color.arkInk.opacity(0.34), in: Capsule()) // ui-v4: allow embedded quick action submenu contrast on dark card gradient
        .shadow(color: Color.arkInk.opacity(0.24), radius: 14, x: 0, y: 8) // ui-v4: allow embedded quick action submenu lift
        .offset(x: menuOffsetX(index: index), y: menuOffsetY(index: index))
    }

    private func inlineMenuButton(icon: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button {
            OhanaFeedback.light()
            withAnimation(submenuAnimation) {
                openActionId = nil
            }
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goCardWhite)
                .frame(width: 44, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibility)
    }

    private var addLauncherCell: some View {
        Button {
            OhanaFeedback.light()
            withAnimation(submenuAnimation) {
                openActionId = nil
                showingAddPanel.toggle()
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 38, height: 38)
                        .background(Color.goCardWhite.opacity(0.12), in: Circle())
                }

                Text(l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color.goCardWhite.opacity(0.24),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"))
    }

    private var addOptionsPanel: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 0)
                Button {
                    OhanaFeedback.light()
                    withAnimation(submenuAnimation) {
                        showingAddPanel = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 28, height: 28)
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
                            withAnimation(submenuAnimation) {
                                showingAddPanel = false
                            }
                            onAdd(item.id)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                VStack(spacing: 5) {
                                    OhanaQuickActionIcon(
                                        actionType: item.id,
                                        fallbackSystemName: item.icon,
                                        size: 23,
                                        color: item.isAddDisabled ? Color.ohanaSecondaryText : Color.ohanaFunctionalIcon
                                    )
                                    Text(item.title)
                                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                                        .foregroundStyle(item.isAddDisabled ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.58)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)

                                if item.isAddDisabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .black))
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(Color.goPrimary)
                                        .padding(6)
                                }
                            }
                            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .opacity(item.isAddDisabled ? 0.62 : 1)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(item.isAddDisabled)
                    }
                }
            }
            .frame(maxHeight: 179)
        }
        .padding(10)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .shadow(color: Color.arkInk.opacity(0.22), radius: 20, x: 0, y: 12) // ui-v4: allow floating quick-action add panel
    }

    private func editDragLayer(for item: VerticalHomeEmbeddedAction) -> some View {
        Color.clear
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        actionType: item.id,
                        fallbackSystemName: item.icon,
                        size: 34,
                        color: Color.goPrimary
                    )
                    .frame(width: 44, height: 44)
                    Text(item.title)
                        .font(.system(size: 10, weight: .black, design: .rounded))
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
                    .frame(width: 20, height: 20)
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .black))
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

    private func editJiggleAngle(for item: VerticalHomeEmbeddedAction) -> Double {
        guard isEditMode, !isDraggingAnyItem, !isDragging(item) else { return 0 }
        return jiggle ? -1.05 : 1.05
    }

    private var editJiggleAnimation: Animation? {
        guard isEditMode, !shouldReduceWork, !isDraggingAnyItem else { return nil }
        return GoMotion.quick.repeatForever(autoreverses: true)
    }

    private func menuOffsetY(index: Int) -> CGFloat {
        if forcesSubmenusBelow {
            return 66
        }
        return index >= 4 ? -52 : 52
    }

    private func menuOffsetX(index: Int) -> CGFloat {
        switch index % 4 {
        case 0: return 18
        case 3: return -18
        default: return 0
        }
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
