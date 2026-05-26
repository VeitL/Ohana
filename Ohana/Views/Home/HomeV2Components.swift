//
//  HomeV2Components.swift
//  Ohana
//
//  Pure render surfaces for Home V2.
//

import SwiftUI

struct HomeV2PageLifecycle {
    let isPrepared: Bool
    let isVisible: Bool
    let isLive: Bool
}

struct HomeV2PageDeck<HomePage: View, CalendarPage: View, OasisPage: View, PlantsPage: View>: View {
    let selectedTab: HomeV2Tab
    let preparedTabs: Set<HomeV2Tab>
    let canAnimate: Bool
    @ViewBuilder var home: (HomeV2PageLifecycle) -> HomePage
    @ViewBuilder var calendar: (HomeV2PageLifecycle) -> CalendarPage
    @ViewBuilder var oasis: (HomeV2PageLifecycle) -> OasisPage
    @ViewBuilder var plants: (HomeV2PageLifecycle) -> PlantsPage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(HomeV2Tab.allCases) { tab in
                    page(for: tab)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(x: CGFloat(tab.index - selectedTab.index) * proxy.size.width)
                        .opacity(isMounted(tab) ? 1 : 0)
                        .allowsHitTesting(tab == selectedTab && isMounted(tab))
                        .accessibilityHidden(tab != selectedTab)
                        .zIndex(tab == selectedTab ? 2 : 1)
                }
            }
            .clipped()
            .animation(canAnimate ? GoMotion.page : GoMotion.reduced, value: selectedTab)
        }
    }

    @ViewBuilder
    private func page(for tab: HomeV2Tab) -> some View {
        let lifecycle = HomeV2PageLifecycle(
            isPrepared: isMounted(tab),
            isVisible: tab == selectedTab,
            isLive: tab == selectedTab && isMounted(tab)
        )

        if isMounted(tab) {
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
        } else {
            HomeV2PreparedPlaceholder()
        }
    }

    private func isMounted(_ tab: HomeV2Tab) -> Bool {
        preparedTabs.contains(tab)
    }
}

struct HomeV2DashboardPage: View {
    let snapshot: HomeV2Snapshot
    let pets: [Pet]
    let avatarCacheRevision: Int
    let isLive: Bool
    let collapsedTopInset: CGFloat
    @Binding var headerContextCardId: UUID?
    @Binding var isCardExpandedOrTransitioning: Bool
    @Binding var cardHeroProgress: CGFloat
    let onOpenCard: (FocusCard) -> Void
    let onQuickActionForCard: (HomeV2QuickAction, FocusCard, Bool) -> Void
    let onAddPet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCardId: UUID?
    @State private var heroProgress: CGFloat = 0
    @State private var heroDirection: Int = 0
    @State private var collapseCleanupTask: Task<Void, Never>?
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if snapshot.cards.isEmpty {
                    EmptyStateWelcomeCard(
                        onAddPet: onAddPet,
                        onAddHuman: onAddPet
                    )
                    .padding(.horizontal, K.cardMargin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    FocusHomeVerticalSolidScene(
                        cards: snapshot.cards,
                        pets: pets,
                        safeTop: 0,
                        safeBottom: 0,
                        selectedCardId: selectedCardId,
                        progress: heroProgress,
                        heroDirection: heroDirection,
                        reduceMotion: reduceMotion,
                        isVisible: isLive,
                        embedsQuickActionsInCard: true,
                        collapsedTopInset: collapsedTopInset,
                        quickActions: { card in
                            HomeV2ExpandedCardActions(card: card) { action, opensQuickSheet in
                                onQuickActionForCard(action, card, opensQuickSheet)
                            }
                        },
                        contextMenu: { _ in EmptyView() },
                        onSelect: expandCard,
                        onCollapse: collapseCard,
                        onLongPress: onOpenCard
                    )
                    .id(avatarCacheRevision)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onDisappear {
            collapseCleanupTask?.cancel()
            collapseCleanupTask = nil
            headerContextCardId = nil
            isCardExpandedOrTransitioning = false
            cardHeroProgress = 0
        }
    }

    private func expandCard(_ card: FocusCard) {
        guard selectedCardId != card.id else { return }
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        OhanaFeedback.light()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedCardId = card.id
            heroDirection = 1
            heroProgress = 0
            cardHeroProgress = 0
        }
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            headerContextCardId = card.id
            isCardExpandedOrTransitioning = true
        }
        OhanaFrameScheduler.runAfterNextFrame {
            withAnimation(reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero) {
                heroProgress = 1
                cardHeroProgress = 1
            }
        }
    }

    private func collapseCard() {
        guard selectedCardId != nil else { return }
        OhanaFeedback.light()
        collapseCleanupTask?.cancel()
        heroDirection = -1
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            headerContextCardId = nil
        }
        withAnimation(reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero) {
            heroProgress = 0
            cardHeroProgress = 0
        }
        collapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: reduceMotion ? 180 : 420) {
            guard heroProgress <= 0.02 else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedCardId = nil
                heroDirection = 0
            }
            collapseCleanupTask = nil
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.feedback) {
                isCardExpandedOrTransitioning = false
            }
        }
    }

}

struct HomeV2TodayFocusChrome: View {
    let snapshot: TodayFocusSnapshot
    let isLive: Bool
    let onOpenOasis: () -> Void

    var body: some View {
        TodayFocusCard(
            snapshot: snapshot,
            presentation: .compactStack,
            onOpenQuest: { _ in onOpenOasis() },
            onCompleteQuest: { _ in },
            onTapNegativeSignal: { _ in onOpenOasis() },
            onTapMemory: onOpenOasis,
            onTapOasis: onOpenOasis,
            onTapFamilyTask: { _ in },
            onConfirmExchange: { _ in },
            freezesToFrontCard: !isLive
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(true)
    }
}

private struct HomeV2ExpandedCardActions: View {
    let card: FocusCard
    let onAction: (HomeV2QuickAction, Bool) -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VerticalHomeEmbeddedQuickActions(
            title: card.name,
            items: HomeV2QuickAction.allCases.map { action in
                VerticalHomeEmbeddedAction(
                    id: action.id,
                    title: action.title(l),
                    icon: action.icon,
                    isCompleted: false,
                    quickAccessibilityLabel: action.title(l),
                    detailAccessibilityLabel: l.tr(zh: "查看详情", en: "Details", de: "Details"),
                    detailAction: { onAction(action, false) },
                    action: { onAction(action, true) }
                )
            },
            shouldReduceWork: reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full,
            forcesSubmenusBelow: true
        )
    }
}

struct HomeV2PlantsPage: View {
    let plants: [HomeV2PlantSnapshot]
    let onOpenPlant: (HomeV2PlantSnapshot) -> Void
    let onAddPlant: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if plants.isEmpty {
                    HomeV2EmptyAction(
                        icon: "leaf.fill",
                        title: l.tr(zh: "添加第一株植物", en: "Add first plant", de: "Erste Pflanze hinzufügen"),
                        action: onAddPlant
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(plants) { plant in
                        Button {
                            onOpenPlant(plant)
                        } label: {
                            HStack(spacing: 12) {
                                HomeV2Avatar(emoji: plant.emoji, color: Color(hex: plant.themeHex), size: 46)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plant.name)
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                    Text(plant.subtitle.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.subtitle)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if plant.needsCare {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundStyle(Color.goTeal)
                                }
                            }
                            .padding(14)
                            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct HomeV2BottomBar: View {
    let selectedTab: HomeV2Tab
    let safeBottom: CGFloat
    let canAnimate: Bool
    let onSelect: (HomeV2Tab) -> Void
    let onCenter: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        let barBottomInset = max(safeBottom - 2, 4)
        let centerBottomInset = max(safeBottom + 4, 12)

        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.calendar)
                Spacer(minLength: 72)
                tabButton(.oasis)
                tabButton(.plants)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, barBottomInset)

            Button {
                onCenter()
            } label: {
                Image(systemName: centerIcon)
                    .font(.system(size: 24, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 64, height: 64)
                    .background(Color.goPrimary, in: Circle())
                    .shadow(color: Color.goPrimary.opacity(0.26), radius: 16, x: 0, y: 8) // ui-v4: allow elevated primary nav action
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, centerBottomInset)
        }
        .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: selectedTab)
    }

    private var centerIcon: String {
        switch selectedTab {
        case .home: return "plus"
        case .calendar: return "calendar.badge.plus"
        case .oasis: return "bolt.fill"
        case .plants: return "leaf.fill"
        }
    }

    private func tabButton(_ tab: HomeV2Tab) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .black))
                    .symbolRenderingMode(.monochrome)
                Text(tab.title(l))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(selectedTab == tab ? Color.goPrimary : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct HomeV2Avatar: View {
    let emoji: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
            if emoji.count <= 2 {
                Text(emoji)
                    .font(.system(size: size * 0.43))
            } else {
                Image(systemName: emoji)
                    .font(.system(size: size * 0.42, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
    }
}

struct HomeV2EmptyAction: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer()
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct HomeV2PreparedPlaceholder: View {
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
