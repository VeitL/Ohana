//
//  VerticalSolidHomePageDeck.swift
//  Ohana
//
//  Native tab lifecycle and page mounting for the vertical-solid home.
//

import Foundation
import SwiftUI

struct VerticalSolidHomePageLifecycle: Equatable {
    let isPrepared: Bool
    let isPreparingForDisplay: Bool
    let isVisible: Bool
    let isLive: Bool
}
enum VerticalHomeTabMountPolicy {
    static func mountedTabs(
        active: VerticalSolidHomeTab,
        outgoing: VerticalSolidHomeTab?,
        prepared: Set<VerticalSolidHomeTab> = []
    ) -> Set<VerticalSolidHomeTab> {
        var mounted: Set<VerticalSolidHomeTab> = [active]
        if let outgoing {
            mounted.insert(outgoing)
        }
        if prepared.contains(.calendar) {
            mounted.insert(.calendar)
        }
        return mounted
    }

    static func lifecycle(
        for tab: VerticalSolidHomeTab,
        active: VerticalSolidHomeTab,
        outgoing: VerticalSolidHomeTab?,
        selected _: VerticalSolidHomeTab,
        prepared: Set<VerticalSolidHomeTab> = [],
        preparing: VerticalSolidHomeTab? = nil
    ) -> VerticalSolidHomePageLifecycle {
        let isOutgoing = outgoing == tab
        let isPreparing = preparing == tab
        let isPrepared = tab == active || prepared.contains(tab) || isPreparing
        let isVisible = tab == active || isOutgoing
        let isLive = tab == active && outgoing == nil && !isPreparing
        return VerticalSolidHomePageLifecycle(
            isPrepared: isPrepared,
            isPreparingForDisplay: isPreparing,
            isVisible: isVisible,
            isLive: isLive
        )
    }
}

enum VerticalHomeTabTransitionPolicy {
    static let fullMotionOutgoingCleanupDelayMilliseconds: UInt64 = 700
    static let reducedMotionOutgoingCleanupDelayMilliseconds: UInt64 = 90

    static func outgoingCleanupDelayMilliseconds(for motionBudget: OhanaMotionBudget) -> UInt64 {
        motionBudget == .full
            ? fullMotionOutgoingCleanupDelayMilliseconds
            : reducedMotionOutgoingCleanupDelayMilliseconds
    }
}

enum VerticalSolidHomePageContentHeightPolicy {
    static func height(
        selectedTab: VerticalSolidHomeTab,
        containerHeight: CGFloat,
        topChromeHeight: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> CGFloat {
        _ = selectedTab
        _ = bottomChromeHeight
        // The native TabView owns bottom-bar and safe-area layout. Reserving a
        // second custom chrome inset would leave the selected page visibly short.
        return max(300, containerHeight - topChromeHeight)
    }
}

struct VerticalSolidHomePageDeck<HomePage: View, CalendarPage: View, OasisPage: View, PlantsPage: View>: View {
    let selectedTab: VerticalSolidHomeTab
    let outgoingTab: VerticalSolidHomeTab?
    let preparingTab: VerticalSolidHomeTab?
    let preparedTabs: Set<VerticalSolidHomeTab>
    let visibleTabs: [VerticalSolidHomeTab]
    let taskCenterBadge: TaskCenterBadgeSnapshot
    let localization: L10n
    let backgroundViewportSize: CGSize
    let backgroundViewportTopOffset: CGFloat
    let onSelect: (VerticalSolidHomeTab) -> Void
    @ViewBuilder var home: (VerticalSolidHomePageLifecycle) -> HomePage
    @ViewBuilder var calendar: (VerticalSolidHomePageLifecycle) -> CalendarPage
    @ViewBuilder var oasis: (VerticalSolidHomePageLifecycle) -> OasisPage
    @ViewBuilder var plants: (VerticalSolidHomePageLifecycle) -> PlantsPage

    var body: some View {
        TabView(selection: selection) {
            ForEach(visibleTabs) { tab in
                page(for: tab)
                    .background {
                        viewportAlignedPageBackground(for: tab)
                    }
                    .tabItem {
                        Label(tab.title(localization), systemImage: tab.icon)
                            .accessibilityIdentifier("home-tab-\(tab.rawValue)")
                            .accessibilityLabel(tabAccessibilityLabel(for: tab))
                    }
                    .tag(tab)
                    .badge(tab == .calendar ? taskCenterBadge.attentionCount : 0)
            }
        }
        .tint(Color.goPrimary)
        .tabBarMinimizeBehavior(.onScrollDown)
        .accessibilityIdentifier("home-native-tab-view")
    }

    private var selection: Binding<VerticalSolidHomeTab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                guard tab != selectedTab else { return }
                onSelect(tab)
            }
        )
    }

    private func tabAccessibilityLabel(for tab: VerticalSolidHomeTab) -> String {
        if tab == .calendar, taskCenterBadge.attentionCount > 0 {
            return localization.tr(
                zh: "\(tab.title(localization))，\(taskCenterBadge.attentionCount) 项待处理",
                en: "\(tab.title(localization)), \(taskCenterBadge.attentionCount) need attention",
                de: "\(tab.title(localization)), \(taskCenterBadge.attentionCount) offen"
            )
        }
        return tab.title(localization)
    }

    @ViewBuilder
    private func viewportAlignedPageBackground(for tab: VerticalSolidHomeTab) -> some View {
        if lifecycle(for: tab).isVisible {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    OhanaStaticBackgroundCanvas()
                        .frame(
                            width: backgroundViewportSize.width,
                            height: backgroundViewportSize.height
                        )
                        .offset(y: -backgroundViewportTopOffset)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
                .allowsHitTesting(false)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    @ViewBuilder
    private func page(for tab: VerticalSolidHomeTab) -> some View {
        let lifecycle = lifecycle(for: tab)

        if !isMounted(tab) {
            VerticalSolidHomePreparedPlaceholder()
        } else if lifecycle.isPreparingForDisplay {
            switch tab {
            case .calendar:
                calendar(lifecycle)
            case .oasis:
                oasis(lifecycle)
            case .home, .plants:
                VerticalSolidHomePreparedPlaceholder()
            }
        } else if lifecycle.isVisible {
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
        } else if lifecycle.isPrepared {
            switch tab {
            case .calendar:
                calendar(lifecycle)
            case .home, .oasis, .plants:
                VerticalSolidHomePreparedPlaceholder()
            }
        } else {
            VerticalSolidHomePreparedPlaceholder()
        }
    }

    private func isMounted(_ tab: VerticalSolidHomeTab) -> Bool {
        VerticalHomeTabMountPolicy
            .mountedTabs(active: selectedTab, outgoing: outgoingTab, prepared: preparedTabs)
            .contains(tab)
    }

    private func lifecycle(for tab: VerticalSolidHomeTab) -> VerticalSolidHomePageLifecycle {
        VerticalHomeTabMountPolicy.lifecycle(
            for: tab,
            active: selectedTab,
            outgoing: outgoingTab,
            selected: selectedTab,
            prepared: preparedTabs,
            preparing: preparingTab
        )
    }
}
