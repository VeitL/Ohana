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
        let showsSelectedLabel = false
        let actionDiameter: CGFloat = 48
        let barHeight: CGFloat = isAccessibilitySize ? 58 : 56
        let tabSpacing: CGFloat = isAccessibilitySize ? 2 : (normalizedCount >= 5 ? 2 : 4)

        return HomeBottomNavigationLayoutMetrics(
            barHeight: barHeight,
            horizontalPadding: 14,
            leadingPadding: 6,
            trailingPadding: 6,
            tabSpacing: tabSpacing,
            actionGap: 10,
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

nonisolated enum HomeFabShortcutHitAreaPolicy {
    static let minimumHitSize: CGFloat = 44
    static let visualDiameter: CGFloat = 42
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
    private var visibleTabs: [VerticalSolidHomeTab] {
        AppFeatureRouteGuard.visibleHomeTabs(currentLevel: treeLevel)
    }
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
                .frame(width: metrics.actionHitSize, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, metrics.horizontalPadding)
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
        GeometryReader { proxy in
            let tabBackgroundWidth = tabBackgroundWidth(for: proxy.size.width, metrics: metrics)

            HStack(alignment: .center, spacing: metrics.actionGap) {
                tabStrip(metrics: metrics)
                    .padding(.leading, metrics.leadingPadding)
                    .padding(.trailing, metrics.leadingPadding)
                    .frame(width: tabBackgroundWidth, height: metrics.barHeight)
                    .background(navBackground)
                    .layoutPriority(1)

                Spacer(minLength: 0)

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
            .frame(width: proxy.size.width, height: metrics.barHeight)
        }
        .frame(height: metrics.barHeight)
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
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func tabBackgroundWidth(for availableWidth: CGFloat, metrics: HomeBottomNavigationLayoutMetrics) -> CGFloat {
        let requestedWidth = availableWidth * 0.66
        let minimumWidth = CGFloat(visibleTabs.count) * 44
            + CGFloat(max(visibleTabs.count - 1, 0)) * metrics.tabSpacing
            + metrics.leadingPadding * 2
        let maximumWidth = max(minimumWidth, availableWidth - metrics.actionHitSize - metrics.actionGap)
        return min(max(requestedWidth, minimumWidth), maximumWidth)
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
            .shadow( // ui-v4: allow floating Instagram-style glass navigation depth
                color: Color.arkInk.opacity(colorScheme == .dark ? 0.22 : 0.10),
                radius: 18,
                x: 0,
                y: 10
            )
    }

    private var navGlassTint: Color {
        if reduceTransparency {
            return Color.ohanaCardSurface.opacity(0.94)
        }
        return Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.34 : 0.42)
    }

    private var navSpecularStroke: Color {
        colorScheme == .dark ? Color.ohanaPrimaryText.opacity(0.18) : Color.ohanaSecondaryText.opacity(0.10)
    }

    @ViewBuilder
    private var menuRows: some View {
        if isFabExpanded, let activeCard {
            VStack(spacing: 10) {
                ForEach(Array(expandedShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeFabShortcutButton(shortcut: shortcut) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        onExpandedShortcut(shortcut, activeCard)
                    }
                    .ohanaStaggeredMenuItem(
                        isVisible: itemsVisible,
                        index: index,
                        total: expandedShortcuts.count,
                        anchor: .bottom
                    )
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                }
            }
            .padding(.vertical, 2)
        } else if isFabExpanded, selectedTab == .home {
            VStack(spacing: 10) {
                ForEach(Array(homeShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeHomeFabShortcutButton(shortcut: shortcut) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        onHomeShortcut(shortcut)
                    }
                    .ohanaStaggeredMenuItem(
                        isVisible: itemsVisible,
                        index: index,
                        total: homeShortcuts.count,
                        anchor: .bottom
                    )
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                }
            }
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
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
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

struct StarterOasisTabPromptView: View {
    let localization: L10n

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.down.circle.fill") // a11y: allow decorative onboarding prompt arrow; parent prompt text owns accessibility.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color.goPrimary)

            Text(localization.tr(
                zh: "椰子树已解锁，点击底部椰子树进入 Oasis",
                en: "Coconut Tree unlocked. Tap the tree tab to enter Oasis.",
                de: "Kokosbaum freigeschaltet. Tippe unten auf den Baum."
            ))
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurface, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.goPrimary.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: Color.arkInk.opacity(0.16), radius: 16, x: 0, y: 8) // ui-v4: allow one-time onboarding nudge depth.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("starter-oasis-tab-prompt")
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

    @Environment(\.colorScheme) private var colorScheme

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
                .foregroundStyle(isSelected ? selectedIconColor : inactiveIconColor)
                .frame(width: isSelected && showsSelectedLabel ? 70 : 44, height: 44)
                .background {
                    selectionHalo
                }
                .overlay(alignment: .bottom) {
                    selectedIndicator
                        .offset(y: 2)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("home-tab-\(tab.rawValue)")
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

    @ViewBuilder
    private var selectionHalo: some View {
        if isSelected {
            Circle()
                .fill(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.20 : 0.34))
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.ohanaGlassStroke.opacity(colorScheme == .dark ? 0.24 : 0.34),
                            lineWidth: 1
                        )
                }
        } else {
            Circle()
                .fill(Color.clear)
        }
    }

    @ViewBuilder
    private var selectedIndicator: some View {
        if isSelected {
            Capsule()
                .fill(Color.goPrimary)
                .frame(width: 15, height: 3) // a11y: allow decorative selected-tab indicator; parent tab owns the 44pt hit target
                .shadow( // ui-v4: allow tiny selected-tab glow for floating nav clarity
                    color: Color.goPrimary.opacity(0.26),
                    radius: 5,
                    x: 0,
                    y: 2
                )
                .transition(.scale(scale: 0.72).combined(with: .opacity))
        }
    }

    private var selectedIconColor: Color {
        colorScheme == .dark ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText
    }

    private var inactiveIconColor: Color {
        Color.ohanaSecondaryText.opacity(colorScheme == .dark ? 0.72 : 0.78)
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

    @Environment(\.colorScheme) private var colorScheme

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
        Image(systemName: "tree.fill") // a11y: allow decorative tree glyph inside the labeled 44pt navigation tab
            .font(OhanaFont.adaptive(size: size, weight: .black))
            .symbolRenderingMode(.monochrome)
            .frame(width: 22, height: 22) // a11y: allow decorative glyph frame; parent tab owns the 44pt hit target
            .contentTransition(.symbolEffect(.replace))
    }

    private func finiteFillHeight(for height: CGFloat) -> CGFloat {
        guard height.isFinite, height > 0 else { return 1 }
        let candidate = height * fillProgress
        guard candidate.isFinite else { return 1 }
        return max(1, candidate)
    }

    private var baseColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.ohanaPrimaryActionText.opacity(0.90)
                : Color.ohanaPrimaryText.opacity(0.90)
        }
        return Color.ohanaSecondaryText.opacity(0.52)
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
                .background(primaryActionBackground)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(width: hitSize, height: hitSize)
        .contentShape(Circle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("home-primary-action")
    }

    private var primaryActionBackground: some View {
        Circle()
            .fill(Color.goPrimary)
            .overlay {
                Circle()
                    .strokeBorder(Color.ohanaPrimaryActionText.opacity(0.22), lineWidth: 1)
            }
            .shadow( // ui-v4: allow detached primary FAB depth
                color: Color.goPrimary.opacity(0.28),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

private struct VerticalSolidHomeFabShortcutButton: View {
    let shortcut: ExpandedCardFabShortcut
    let action: () -> Void
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    var body: some View {
        let showsNewFeature: Bool = {
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(expandedShortcut: shortcut)
        }()

        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54)
                    )
                    .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.

                    if showsNewFeature {
                        GrowthNewFeatureDot(size: 9)
                            .offset(x: 5, y: -5)
                    } else if let badge = shortcut.badge {
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
            .frame(
                minWidth: HomeFabShortcutHitAreaPolicy.minimumHitSize,
                minHeight: HomeFabShortcutHitAreaPolicy.minimumHitSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(shortcut.label)
        .accessibilityIdentifier("home-expanded-shortcut-\(shortcut.action.accessibilityIdentifierFragment)")
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

private extension ExpandedCardFabAction {
    var accessibilityIdentifierFragment: String {
        switch self {
        case let .quick(actionType):
            "quick-\(actionType)"
        case let .detail(feature):
            "detail-\(feature.rawValue)"
        case .allFeatures:
            "allFeatures"
        case let .humanQuick(actionType):
            "humanQuick-\(actionType)"
        case .humanAllFeatures:
            "humanAllFeatures"
        }
    }
}

private struct VerticalSolidHomeHomeFabShortcutButton: View {
    let shortcut: HomeFabFunctionShortcut
    let action: () -> Void
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    var body: some View {
        let showsNewFeature: Bool = {
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(homeShortcut: shortcut)
        }()

        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
                        animatesStateChanges: false
                    )
                    .frame(width: HomeFabShortcutHitAreaPolicy.visualDiameter, height: HomeFabShortcutHitAreaPolicy.visualDiameter) // a11y: allow visual glyph frame; parent button owns the 44pt hit target.

                    if showsNewFeature {
                        GrowthNewFeatureDot(size: 9)
                            .offset(x: 5, y: -5)
                    } else if let badge = shortcut.badge {
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
            .frame(
                minWidth: HomeFabShortcutHitAreaPolicy.minimumHitSize,
                minHeight: HomeFabShortcutHitAreaPolicy.minimumHitSize
            )
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
