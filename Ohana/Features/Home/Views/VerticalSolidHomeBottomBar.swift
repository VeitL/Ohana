//
//  VerticalSolidHomeBottomBar.swift
//  Ohana
//
//  Quick-action menu that sits above the system-owned root tab bar.
//

import Foundation
import SwiftUI

struct HomeBottomNavigationLayoutMetrics: Equatable {
    let barHeight: CGFloat
    let horizontalPadding: CGFloat
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat
    let tabSpacing: CGFloat
    let actionDiameter: CGFloat
    let actionHitSize: CGFloat
    let showsSelectedLabel: Bool
}

enum HomeBottomNavigationLayoutPolicy {
    static func metrics(tabCount: Int, isAccessibilitySize: Bool = false) -> HomeBottomNavigationLayoutMetrics {
        let normalizedCount = max(tabCount, 1)
        let showsSelectedLabel = false
        let barHeight: CGFloat = isAccessibilitySize ? 72 : 64
        let tabSpacing: CGFloat = normalizedCount >= 5 ? 0 : 2

        return HomeBottomNavigationLayoutMetrics(
            barHeight: barHeight,
            horizontalPadding: 10,
            leadingPadding: 8,
            trailingPadding: 8,
            tabSpacing: tabSpacing,
            actionDiameter: 48,
            actionHitSize: 52,
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
            + CGFloat(max(normalizedCount - 1, 0)) * metrics.tabSpacing
        let availableWidth = max(44 * CGFloat(normalizedCount), containerWidth - fixedWidth)
        return availableWidth / CGFloat(normalizedCount)
    }
}

nonisolated enum HomeFabShortcutHitAreaPolicy {
    static let minimumHitSize: CGFloat = 44
    static let visualDiameter: CGFloat = 42
    static let menuColumnWidth: CGFloat = 52
    static let expandedCardEmbeddedActionClearance: CGFloat = 184
}

nonisolated enum HomeBottomNavigationPrimaryActionPresentation {
    static func icon(
        selectedTab: VerticalSolidHomeTab,
        isFabExpanded: Bool,
        usesFabMenu: Bool
    ) -> String {
        if isFabExpanded {
            return "xmark"
        }
        if usesFabMenu {
            return "plus"
        }
        switch selectedTab {
        case .home: return "plus"
        case .calendar: return "plus"
        case .oasis: return "bolt.fill"
        case .plants: return "plus"
        }
    }
}

struct VerticalSolidHomeQuickActionMenu: View {
    let selectedTab: VerticalSolidHomeTab
    @Binding var isFabExpanded: Bool
    @Binding var itemsVisible: Bool
    let activeCard: FocusCard?
    let homeShortcuts: [HomeFabFunctionShortcut]
    let plantShortcuts: [HomeFabFunctionShortcut]
    let expandedShortcuts: [ExpandedCardFabShortcut]
    let safeBottom: CGFloat
    let canAnimate: Bool
    let primaryActionIcon: String
    let primaryActionAccessibilityLabel: String
    let localization: L10n
    let onHomeShortcut: (HomeFabFunctionShortcut) -> Void
    let onExpandedShortcut: (ExpandedCardFabShortcut, FocusCard) -> Void
    let onPrimaryAction: () -> Void

    @State private var activeHomeSubmenu: HomeFabShortcutSubmenu?
    @State private var submenuItemsVisible = false

    private var l: L10n { localization }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            menuRows
                .frame(width: HomeFabShortcutHitAreaPolicy.menuColumnWidth, alignment: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, menuRowsBottomPadding)

            Button(action: onPrimaryAction) {
                Label(primaryActionAccessibilityLabel, systemImage: primaryActionIcon)
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(Color.goPrimary)
            .accessibilityLabel(primaryActionAccessibilityLabel)
            .accessibilityIdentifier("home-primary-action")
            .padding(.trailing, 14)
            .padding(.bottom, primaryActionBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: isFabExpanded)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: itemsVisible)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: activeHomeSubmenu)
        .onChange(of: isFabExpanded) { _, expanded in
            if !expanded { resetHomeSubmenu() }
        }
        .onChange(of: selectedTab) { _, _ in
            resetHomeSubmenu()
        }
        .onChange(of: activeCard?.id) { _, _ in
            resetHomeSubmenu()
        }
    }

    private var menuRowsBottomPadding: CGFloat {
        let basePadding = safeBottom + 76
        guard activeCard != nil else { return basePadding }
        return basePadding + HomeFabShortcutHitAreaPolicy.expandedCardEmbeddedActionClearance
    }

    private var primaryActionBottomPadding: CGFloat {
        max(safeBottom - 2, 4)
    }

    @ViewBuilder
    private var menuRows: some View {
        if isFabExpanded, let activeCard {
            VStack(spacing: 10) {
                ForEach(Array(expandedShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeFabShortcutButton(
                        shortcut: shortcut,
                        accentColor: Color(hex: activeCard.themeColorHex)
                    ) {
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
                if activeHomeSubmenu == .addMember {
                    let childShortcuts = HomeFabShortcutCatalog.addMemberShortcuts(l: l)
                    ForEach(Array(childShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                        VerticalSolidHomeHomeFabShortcutButton(shortcut: shortcut) {
                            guard shortcut.isAvailable else {
                                OhanaFeedback.light()
                                return
                            }
                            resetHomeSubmenu()
                            onHomeShortcut(shortcut)
                        }
                        .ohanaStaggeredMenuItem(
                            isVisible: submenuItemsVisible && itemsVisible,
                            index: index,
                            total: childShortcuts.count,
                            anchor: .bottom
                        )
                        .allowsHitTesting(submenuItemsVisible && itemsVisible)
                        .accessibilityHidden(!(submenuItemsVisible && itemsVisible))
                    }
                }

                ForEach(Array(homeShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    VerticalSolidHomeHomeFabShortcutButton(
                        shortcut: shortcut,
                        isDimmed: activeHomeSubmenu == .addMember && shortcut.action == .submenu(.addMember)
                    ) {
                        guard shortcut.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        handleHomeShortcut(shortcut)
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
        } else if isFabExpanded, selectedTab == .plants {
            VStack(spacing: 10) {
                ForEach(Array(plantShortcuts.enumerated()), id: \.element.id) { index, shortcut in
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
                        total: plantShortcuts.count,
                        anchor: .bottom
                    )
                    .allowsHitTesting(itemsVisible)
                    .accessibilityHidden(!itemsVisible)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func handleHomeShortcut(_ shortcut: HomeFabFunctionShortcut) {
        switch shortcut.action {
        case .submenu(.addMember):
            OhanaFeedback.light()
            if activeHomeSubmenu == .addMember {
                withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                    submenuItemsVisible = false
                    activeHomeSubmenu = nil
                }
                return
            }
            submenuItemsVisible = false
            withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                activeHomeSubmenu = .addMember
            }
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
                guard activeHomeSubmenu == .addMember else { return }
                withAnimation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced) {
                    submenuItemsVisible = true
                }
            }
        case .addEntity, .destination, .unavailable:
            resetHomeSubmenu()
            onHomeShortcut(shortcut)
        }
    }

    private func resetHomeSubmenu() {
        submenuItemsVisible = false
        activeHomeSubmenu = nil
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
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("starter-oasis-tab-prompt")
    }
}

private struct VerticalSolidHomeFabShortcutButton: View {
    let shortcut: ExpandedCardFabShortcut
    let accentColor: Color
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
                        color: accentColor.opacity(shortcut.isAvailable ? 1 : 0.54),
                        primaryColor: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
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
    var isDimmed = false
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
                        primaryColor: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
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
            .opacity(shortcut.isAvailable ? (isDimmed ? 0.42 : 1) : 0.55)
            .frame(
                minWidth: HomeFabShortcutHitAreaPolicy.minimumHitSize,
                minHeight: HomeFabShortcutHitAreaPolicy.minimumHitSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(shortcut.label)
        .accessibilityIdentifier("home-fab-shortcut-\(shortcut.accessibilityIdentifierFragment)")
    }

    private var iconActionType: String {
        if case let .destination(.featureAggregate(feature)) = shortcut.action {
            return feature.rawValue
        }
        return shortcut.id
    }
}

private extension HomeFabFunctionShortcut {
    var accessibilityIdentifierFragment: String {
        switch action {
        case let .addEntity(type):
            return "add-\(type.rawValue)"
        case let .submenu(submenu):
            return "submenu-\(submenu.rawValue.dashSeparatedIdentifier)"
        case let .destination(destination):
            switch destination {
            case .petFeatureCollection:
                return "pet-feature-collection"
            case .petSharedCheckIn:
                return "pet-shared-check-in"
            case .plantFeatureCollection:
                return "plant-feature-collection"
            case let .featureAggregate(feature):
                return "feature-\(feature.rawValue)"
            case let .featureGroup(group):
                return "feature-group-\(group.rawValue)"
            case .plantsBatchCare:
                return "plants-batch-care"
            case let .plantsBatchCareFiltered(careType):
                return "plants-batch-care-\(careType.rawValue)"
            case .plantsBatchQuickRecord:
                return "plants-batch-quick-record"
            case let .plantCareAggregate(feature):
                return "plant-care-\(feature.rawValue)"
            case .coconutShop:
                return "coconutShop"
            case .gacha:
                return "gacha"
            case .wealthDashboard:
                return "wealth"
            case .familyWeeklyReport:
                return "weeklyReport"
            case .familyLongTermReview:
                return "longTermReview"
            case .careLedgerAnalysis:
                return "careLedgerAnalysis"
            case .reminderObservability:
                return "reminderObservability"
            default:
                break
            }
        case .unavailable:
            break
        }
        return "more"
    }
}

private extension String {
    var dashSeparatedIdentifier: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                if !result.isEmpty {
                    result.append("-")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
