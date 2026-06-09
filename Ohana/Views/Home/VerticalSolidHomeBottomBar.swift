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
    let dividerWidth: CGFloat
    let actionDiameter: CGFloat
    let actionHitSize: CGFloat
    let showsTabLabels: Bool
}

enum HomeBottomNavigationLayoutPolicy {
    static func metrics(tabCount: Int, isAccessibilitySize: Bool = false) -> HomeBottomNavigationLayoutMetrics {
        let normalizedCount = max(tabCount, 1)
        let showsTabLabels = normalizedCount <= 4 && !isAccessibilitySize
        let actionDiameter: CGFloat = showsTabLabels ? 56 : 52
        let barHeight: CGFloat = max(64, actionDiameter + 12)

        return HomeBottomNavigationLayoutMetrics(
            barHeight: barHeight,
            horizontalPadding: 16,
            leadingPadding: normalizedCount >= 5 ? 8 : 10,
            trailingPadding: 8,
            tabSpacing: normalizedCount >= 5 ? 2 : 4,
            actionGap: normalizedCount >= 5 ? 6 : 8,
            dividerWidth: 1,
            actionDiameter: actionDiameter,
            actionHitSize: max(actionDiameter, 56),
            showsTabLabels: showsTabLabels
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
            + metrics.dividerWidth
            + metrics.actionGap * 2
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
    let canAnimate: Bool
    let localization: L10n
    let onSelect: (VerticalSolidHomeTab) -> Void
    let onHomeShortcut: (HomeFabFunctionShortcut) -> Void
    let onExpandedShortcut: (ExpandedCardFabShortcut, FocusCard) -> Void
    let onCenter: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

            Rectangle()
                .fill(Color.ohanaGlassStroke.opacity(colorScheme == .dark ? 0.20 : 0.28))
                .frame(width: metrics.dividerWidth, height: 32)
                .accessibilityHidden(true)

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
                    showsLabel: metrics.showsTabLabels,
                    localization: l,
                    action: onSelect
                )
                .frame(maxWidth: .infinity)
            }
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
            .fill(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.44 : 0.76))
            .overlay {
                Capsule()
                    .strokeBorder(Color.ohanaGlassStroke.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: Color.arkInk.opacity(0.16), radius: 18, x: 0, y: 9) // ui-v4: allow home bottom navigation lift
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
    let showsLabel: Bool
    let localization: L10n
    let action: (VerticalSolidHomeTab) -> Void

    var body: some View {
        Button {
            action(tab)
        } label: {
            tabContent
                .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaSecondaryText)
                .frame(minWidth: 44, maxWidth: .infinity)
                .frame(height: showsLabel ? 54 : 50)
                .padding(.horizontal, 3)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.goPrimary.opacity(0.12))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(tab.title(localization))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var tabContent: some View {
        if showsLabel {
            ViewThatFits(in: .horizontal) {
                VStack(spacing: 3) {
                    icon
                    Text(tab.title(localization))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                iconOnly
            }
        } else {
            iconOnly
        }
    }

    private var iconOnly: some View {
        icon
            .frame(width: 44, height: 44) // a11y: allow icon-only nav tab; this is the complete 44pt hit target.
    }

    private var icon: some View {
        Image(systemName: tab.icon)
            .font(OhanaFont.adaptive(size: isSelected ? 18 : 17, weight: .black))
            .symbolRenderingMode(.monochrome)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
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
                .font(OhanaFont.adaptive(size: 23, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: diameter, height: diameter)
                .background(Color.goPrimary, in: Circle())
                .shadow(color: Color.goPrimary.opacity(0.24), radius: 14, x: 0, y: 7) // ui-v4: allow elevated primary nav action
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
        case .quick(let actionType), .humanQuick(let actionType):
            return actionType
        case .detail(let feature):
            return feature.rawValue
        case .allFeatures, .humanAllFeatures:
            return shortcut.id
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
