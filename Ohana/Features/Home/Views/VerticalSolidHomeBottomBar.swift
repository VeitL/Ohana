//
//  VerticalSolidHomeBottomBar.swift
//  Ohana
//
//  Adaptive bottom navigation chrome for the vertical solid home surface.
//

import Foundation
import SwiftUI

struct HomeBottomNavigationLayoutMetrics: Equatable {
    let barHeight: CGFloat
    let horizontalPadding: CGFloat
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat
    let tabSpacing: CGFloat
    let actionGap: CGFloat
    let actionDiameter: CGFloat
    let actionHitSize: CGFloat
    let showsSelectedLabel: Bool
}

enum HomeBottomNavigationLayoutPolicy {
    static func metrics(tabCount: Int, isAccessibilitySize: Bool = false) -> HomeBottomNavigationLayoutMetrics {
        let normalizedCount = max(tabCount, 1)
        let showsSelectedLabel = normalizedCount <= 4 && !isAccessibilitySize
        let actionDiameter: CGFloat = 48
        let barHeight: CGFloat = 58

        return HomeBottomNavigationLayoutMetrics(
            barHeight: barHeight,
            horizontalPadding: 14,
            leadingPadding: 8,
            trailingPadding: 4,
            tabSpacing: normalizedCount >= 5 ? 4 : 6,
            actionGap: 6,
            actionDiameter: actionDiameter,
            actionHitSize: max(actionDiameter, 52),
            showsSelectedLabel: showsSelectedLabel
        )
    }

    static func estimatedTabSlotWidth(
        containerWidth: CGFloat,
        tabCount: Int,
        isAccessibilitySize: Bool = false
    ) -> CGFloat {
        let metrics = metrics(tabCount: tabCount, isAccessibilitySize: isAccessibilitySize)
        let normalizedCount = max(tabCount, 1)
        let fixedWidth = metrics.horizontalPadding * 2
            + metrics.leadingPadding
            + metrics.trailingPadding
            + metrics.actionHitSize
            + metrics.actionGap
            + CGFloat(max(normalizedCount - 1, 0)) * metrics.tabSpacing
        let availableWidth = max(44 * CGFloat(normalizedCount), containerWidth - fixedWidth)
        return availableWidth / CGFloat(normalizedCount)
    }
}

struct VerticalSolidHomeBottomBar: View {
    let selectedTab: VerticalSolidHomeTab
    @Binding var isFabExpanded: Bool
    @Binding var itemsVisible: Bool
    let activeCard: FocusCard?
    let homeShortcuts: [HomeFabFunctionShortcut]
    let expandedShortcuts: [ExpandedCardFabShortcut]
    let safeBottom: CGFloat
    let treeLevel: Int
    let treeProgress: Double
    let canAnimate: Bool
    let localization: L10n
    let onSelect: (VerticalSolidHomeTab) -> Void
    let onHomeShortcut: (HomeFabFunctionShortcut) -> Void
    let onExpandedShortcut: (ExpandedCardFabShortcut, FocusCard) -> Void
    let onCenter: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var l: L10n { localization }
    private var visibleTabs: [VerticalSolidHomeTab] { VerticalSolidHomeTab.visibleTabs }
    private var metrics: HomeBottomNavigationLayoutMetrics {
        HomeBottomNavigationLayoutPolicy.metrics(
            tabCount: visibleTabs.count,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    var body: some View {
        let barBottomInset = max(safeBottom - 2, 4)

        ZStack(alignment: .bottom) {
            menuRows
                .padding(.bottom, safeBottom + metrics.barHeight + 18)

            navigationChrome(metrics: metrics)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.bottom, barBottomInset)
        }
        .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: selectedTab)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: isFabExpanded)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: itemsVisible)
    }

    private func navigationChrome(metrics: HomeBottomNavigationLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.actionGap) {
            tabStrip(metrics: metrics)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            HomeBottomNavigationPrimaryAction(
                icon: centerIcon,
                isExpanded: isFabExpanded,
                diameter: metrics.actionDiameter,
                hitSize: metrics.actionHitSize,
                accessibilityLabel: centerButtonAccessibilityLabel
            ) {
                OhanaFeedback.medium()
                if usesFabMenu {
                    toggleFab()
                    return
                }
                onCenter()
            }
        }
        .padding(.leading, metrics.leadingPadding)
        .padding(.trailing, metrics.trailingPadding)
        .frame(height: metrics.barHeight)
        .background(navBackground)
        .accessibilityElement(children: .contain)
    }

    private func tabStrip(metrics: HomeBottomNavigationLayoutMetrics) -> some View {
        HStack(spacing: metrics.tabSpacing) {
            ForEach(visibleTabs) { tab in
                HomeBottomNavigationTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    showsSelectedLabel: metrics.showsSelectedLabel,
                    treeLevel: treeLevel,
                    treeProgress: treeProgress,
                    localization: l,
                    selectionAnimation: canAnimate ? GoMotion.selection : GoMotion.reduced,
                    action: onSelect
                )
            }
            Spacer(minLength: 0)
        }
    }

    private var centerIcon: String {
        if isFabExpanded {
            return "xmark"
        }
        if usesFabMenu {
            return "plus"
        }
        switch selectedTab {
        case .home: return "plus"
        case .calendar: return "calendar.badge.plus"
        case .oasis: return "bolt.fill"
        case .plants: return "leaf.fill"
        }
    }

    private var centerButtonAccessibilityLabel: String {
        if isFabExpanded {
            return l.tr(zh: "收起菜单", en: "Close menu", de: "Menü schließen")
        }
        if activeCard != nil {
            return l.tr(zh: "显示该成员剩余功能", en: "Show remaining member features", de: "Weitere Funktionen anzeigen")
        }
        if selectedTab == .home {
            return l.tr(zh: "展开首页快捷菜单", en: "Show home shortcuts", de: "Home-Schnellzugriffe anzeigen")
        }
        switch selectedTab {
        case .home:
            return l.tr(zh: "更多功能", en: "More features", de: "Weitere Funktionen")
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
            .fill(reduceTransparency ? Color.ohanaCardSurface.opacity(0.94) : Color.clear)
            .glassEffect(.regular.tint(navGlassTint).interactive(true), in: Capsule()) // ui-v4: allow app-level Liquid Glass bottom navigation background
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.ohanaPrimaryText.opacity(colorScheme == .dark ? 0.18 : 0.14),
                                navSpecularStroke,
                                Color.ohanaGlassStroke.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }

    private var navGlassTint: Color {
        if reduceTransparency {
            return Color.ohanaCardSurface.opacity(0.94)
        }
        return Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.30 : 0.36)
    }

    private var navSpecularStroke: Color {
        colorScheme == .dark ? Color.ohanaPrimaryText.opacity(0.18) : Color.ohanaSecondaryText.opacity(0.10)
    }

    @ViewBuilder
    private var menuRows: some View {
        if isFabExpanded, let activeCard {
            HStack(spacing: 8) {
                ForEach(Array(expandedShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeFabShortcutButton(shortcut: shortcut) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        onExpandedShortcut(shortcut, activeCard)
                    }
                    .scaleEffect(canAnimate ? (itemsVisible ? 1 : 0.88) : 1, anchor: .bottom)
                    .opacity(itemsVisible ? 1 : 0)
                    .offset(y: canAnimate ? (itemsVisible ? 0 : 34) : 0)
                    .animation(
                        canAnimate ? HeroAnim.fabSpring.delay(GoMotion.staggerDelay(index, step: 0.035, maxDelay: 0.14)) : GoMotion.reduced,
                        value: itemsVisible
                    )
                    .allowsHitTesting(itemsVisible)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        } else if isFabExpanded, selectedTab == .home {
            HStack(spacing: 8) {
                ForEach(Array(homeShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeHomeFabShortcutButton(shortcut: shortcut) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        onHomeShortcut(shortcut)
                    }
                    .scaleEffect(canAnimate ? (itemsVisible ? 1 : 0.88) : 1, anchor: .bottom)
                    .opacity(itemsVisible ? 1 : 0)
                    .offset(y: canAnimate ? (itemsVisible ? 0 : 34) : 0)
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

    private var usesFabMenu: Bool {
        activeCard != nil || selectedTab == .home
    }

    private func toggleFab() {
        if isFabExpanded {
            withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                itemsVisible = false
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
                guard !itemsVisible else { return }
                withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                    isFabExpanded = false
                }
            }
        } else {
            itemsVisible = false
            withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                isFabExpanded = true
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
                withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                    itemsVisible = true
                }
            }
        }
    }
}

private struct HomeBottomNavigationTabButton: View {
    let tab: VerticalSolidHomeTab
    let isSelected: Bool
    let showsSelectedLabel: Bool
    let treeLevel: Int
    let treeProgress: Double
    let localization: L10n
    let selectionAnimation: Animation
    let action: (VerticalSolidHomeTab) -> Void

    private var title: String {
        HomeBottomNavigationTreePresentation.title(for: tab, treeLevel: treeLevel, localization: localization)
    }

    var body: some View {
        Button {
            withAnimation(selectionAnimation) {
                action(tab)
            }
        } label: {
            tabContent
                .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                .frame(width: isSelected && showsSelectedLabel ? 70 : 44)
                .frame(height: 44)
                .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var tabContent: some View {
        if isSelected, showsSelectedLabel {
            HStack(spacing: 5) {
                icon
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        } else {
            iconOnly
        }
    }

    private var iconOnly: some View {
        Group {
            if tab == .oasis {
                VStack(spacing: 0) {
                    icon
                    Text(HomeBottomNavigationTreePresentation.levelText(treeLevel))
                        .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .monospacedDigit()
                }
            } else {
                icon
            }
        }
        .frame(width: 44, height: 44) // a11y: allow icon-only nav tab; this is the complete 44pt hit target.
    }

    @ViewBuilder
    private var icon: some View {
        if tab == .oasis {
            HomeBottomNavigationTreeIcon(
                progress: treeProgress,
                isSelected: isSelected,
                size: isSelected ? 17 : 16
            )
        } else {
            Image(systemName: tab.icon)
                .font(OhanaFont.adaptive(size: isSelected ? 16 : 15, weight: .black))
                .symbolRenderingMode(.monochrome)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
    }

    private var accessibilityLabel: String {
        if tab == .oasis {
            return localization.tr(
                zh: "椰子树 \(HomeBottomNavigationTreePresentation.levelText(treeLevel))",
                en: "Coconut Tree \(HomeBottomNavigationTreePresentation.levelText(treeLevel))",
                de: "Kokosbaum \(HomeBottomNavigationTreePresentation.levelText(treeLevel))"
            )
        }
        return tab.title(localization)
    }
}

enum HomeBottomNavigationTreePresentation {
    static func levelText(_ level: Int) -> String {
        "Lv.\(max(0, level))"
    }

    static func progressFill(_ progress: Double) -> CGFloat {
        guard progress.isFinite else { return 0 }
        return CGFloat(min(1, max(0, progress)))
    }

    static func title(for tab: VerticalSolidHomeTab, treeLevel: Int, localization: L10n) -> String {
        if tab == .oasis {
            return levelText(treeLevel)
        }
        return tab.title(localization)
    }
}

private struct HomeBottomNavigationTreeIcon: View {
    let progress: Double
    let isSelected: Bool
    let size: CGFloat

    private var fillProgress: CGFloat {
        HomeBottomNavigationTreePresentation.progressFill(progress)
    }

    var body: some View {
        treeSymbol
            .foregroundStyle(baseColor)
            .overlay {
                treeSymbol
                    .foregroundStyle(progressGradient)
                    .mask {
                        GeometryReader { proxy in
                            let fillHeight = finiteFillHeight(for: proxy.size.height)
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .frame(height: fillHeight)
                            }
                        }
                    }
            }
            .shadow( // ui-v4: allow tree icon separation from selected tab fill
                color: isSelected ? Color.arkInk.opacity(0.38) : Color.goPrimary.opacity(0.24),
                radius: isSelected ? 2.8 : 1.6,
                x: 0,
                y: isSelected ? 1.8 : 1
            )
            .accessibilityHidden(true)
    }

    private var treeSymbol: some View {
        Image(systemName: "tree.fill")
            .font(OhanaFont.adaptive(size: size, weight: .black))
            .symbolRenderingMode(.monochrome)
            .frame(width: 22, height: 22)
            .contentTransition(.symbolEffect(.replace))
    }

    private func finiteFillHeight(for height: CGFloat) -> CGFloat {
        guard height.isFinite, height > 0 else { return 1 }
        let candidate = height * fillProgress
        guard candidate.isFinite else { return 1 }
        return max(1, candidate)
    }

    private var baseColor: Color {
        isSelected ? Color.ohanaPrimaryActionText.opacity(0.82) : Color.ohanaSecondaryText.opacity(0.52)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.goPrimary,
                Color.goTeal
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

private struct HomeBottomNavigationPrimaryAction: View {
    let icon: String
    let isExpanded: Bool
    let diameter: CGFloat
    let hitSize: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 21, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: diameter, height: diameter)
                .background(Color.goPrimary, in: Circle())
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(width: hitSize, height: hitSize)
        .contentShape(Circle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct VerticalSolidHomeFabShortcutButton: View {
    let shortcut: ExpandedCardFabShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54)
                    )
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

                    if let badge = shortcut.badge {
                        Text(badge)
                            .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(Color.goYellow, in: Capsule())
                            .offset(x: 5, y: -4)
                    }
                }

                Text(shortcut.label)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: 44)
            }
            .opacity(shortcut.isAvailable ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(shortcut.label)
    }

    private var iconActionType: String {
        switch shortcut.action {
        case let .quick(actionType), let .humanQuick(actionType):
            actionType
        case let .detail(feature):
            feature.rawValue
        case .allFeatures, .humanAllFeatures:
            shortcut.id
        }
    }
}

private struct VerticalSolidHomeHomeFabShortcutButton: View {
    let shortcut: HomeFabFunctionShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
                        animatesStateChanges: false
                    )
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

                    if let badge = shortcut.badge {
                        Text(badge)
                            .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(Color.goYellow, in: Capsule())
                            .offset(x: 5, y: -4)
                    }
                }

                Text(shortcut.label)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: 46)
            }
            .opacity(shortcut.isAvailable ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(shortcut.label)
    }

    private var iconActionType: String {
        if case let .featureAggregate(feature)? = shortcut.destination {
            return feature.rawValue
        }
        if case .calendar? = shortcut.destination {
            return "calendar"
        }
        return shortcut.id
    }
}
