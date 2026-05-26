//
//  VerticalSolidHomeComponents.swift
//  Ohana
//
//  Pure render surfaces for verticalSolid home.
//

import Foundation
import SwiftUI

struct VerticalSolidHomePageLifecycle {
    let isPrepared: Bool
    let isVisible: Bool
    let isLive: Bool
}

struct VerticalSolidHomePageDeck<HomePage: View, CalendarPage: View, OasisPage: View, PlantsPage: View>: View {
    let selectedTab: VerticalSolidHomeTab
    let preparedTabs: Set<VerticalSolidHomeTab>
    let canAnimate: Bool
    @ViewBuilder var home: (VerticalSolidHomePageLifecycle) -> HomePage
    @ViewBuilder var calendar: (VerticalSolidHomePageLifecycle) -> CalendarPage
    @ViewBuilder var oasis: (VerticalSolidHomePageLifecycle) -> OasisPage
    @ViewBuilder var plants: (VerticalSolidHomePageLifecycle) -> PlantsPage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(VerticalSolidHomeTab.allCases) { tab in
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
    private func page(for tab: VerticalSolidHomeTab) -> some View {
        let lifecycle = VerticalSolidHomePageLifecycle(
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
            VerticalSolidHomePreparedPlaceholder()
        }
    }

    private func isMounted(_ tab: VerticalSolidHomeTab) -> Bool {
        preparedTabs.contains(tab)
    }
}

struct VerticalSolidHomeDashboardPage: View {
    let snapshot: VerticalSolidHomeSnapshot
    let pets: [Pet]
    let avatarCacheRevision: Int
    let isLive: Bool
    let collapsedTopInset: CGFloat
    @Binding var headerContextCardId: UUID?
    @Binding var isCardExpandedOrTransitioning: Bool
    @Binding var isCardHeroAnimating: Bool
    @Binding var cardHeroProgress: CGFloat
    let arrivingCardId: UUID?
    let onOpenCard: (FocusCard) -> Void
    let onQuickActionForCard: (VerticalSolidHomeQuickAction, FocusCard, Bool) -> Void
    let onAddPet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCardId: UUID?
    @State private var preparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    @State private var activeHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    @State private var heroProgress: CGFloat = 0
    @State private var heroDirection: Int = 0
    @State private var heroGeneration = 0
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
                        preparedHeroSnapshots: preparedHeroSnapshots,
                        heroSnapshot: activeHeroSnapshot,
                        progress: heroProgress,
                        heroDirection: heroDirection,
                        arrivingCardId: arrivingCardId,
                        reduceMotion: reduceMotion,
                        isVisible: isLive,
                        embedsQuickActionsInCard: true,
                        collapsedTopInset: collapsedTopInset,
                        quickActions: { card in
                            VerticalSolidHomeExpandedCardActions(card: card) { action, opensQuickSheet in
                                onQuickActionForCard(action, card, opensQuickSheet)
                            }
                        },
                        contextMenu: { _ in EmptyView() },
                        onSelect: expandCard,
                        onCollapse: collapseCard,
                        onLongPress: onOpenCard
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onDisappear {
            collapseCleanupTask?.cancel()
            collapseCleanupTask = nil
            headerContextCardId = nil
            isCardExpandedOrTransitioning = false
            isCardHeroAnimating = false
            activeHeroSnapshot = nil
            heroGeneration += 1
            cardHeroProgress = 0
        }
        .onAppear {
            prepareHeroSnapshots()
        }
        .onChange(of: heroSnapshotPreparationKey) { _, _ in
            prepareHeroSnapshots()
        }
    }

    private func expandCard(_ snapshot: FocusHomeVerticalSolidHeroSnapshot) {
        let card = snapshot.card
        let canReopenSettledCard = selectedCardId == card.id
            && heroDirection == 0
            && heroProgress <= 0.06
        guard selectedCardId != card.id || canReopenSettledCard else { return }
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        let generation = heroGeneration
        OhanaFeedback.light()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedCardId = card.id
            activeHeroSnapshot = snapshot
            heroDirection = 1
            heroProgress = 0
            cardHeroProgress = 0
            isCardExpandedOrTransitioning = true
            isCardHeroAnimating = true
        }
        withAnimation(headerCoconutAnimation) {
            headerContextCardId = card.id
        }
        OhanaFrameScheduler.runAfterNextFrame {
            guard generation == heroGeneration,
                  selectedCardId == card.id,
                  heroDirection == 1 else { return }
            withAnimation(todayFocusChromeAnimation) {
                cardHeroProgress = 1
            }
            withAnimation(heroAnimation, completionCriteria: .removed) {
                heroProgress = 1
            } completion: {
                completeExpand(cardId: card.id, generation: generation)
            }
        }
    }

    private func collapseCard() {
        guard let selectedCardId else { return }
        OhanaFeedback.light()
        collapseCleanupTask?.cancel()
        heroGeneration += 1
        let generation = heroGeneration
        guard let collapseSnapshot = activeHeroSnapshot
            ?? preparedHeroSnapshots[selectedCardId]
            ?? makeHeroSnapshot(for: selectedCardId) else {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeHeroSnapshot = collapseSnapshot
            heroDirection = -1
            isCardHeroAnimating = true
        }
        withAnimation(headerCoconutAnimation) {
            headerContextCardId = nil
        }
        withAnimation(todayFocusChromeAnimation) {
            cardHeroProgress = 0
        }
        withAnimation(heroAnimation, completionCriteria: .removed) {
            heroProgress = 0
        } completion: {
            completeCollapse(cardId: selectedCardId, generation: generation)
        }
    }

    private func completeExpand(cardId: UUID, generation: Int) {
        guard generation == heroGeneration,
              selectedCardId == cardId,
              heroDirection == 1 else { return }
        withoutAnimation {
            heroProgress = 1
            cardHeroProgress = 1
            heroDirection = 0
            isCardHeroAnimating = false
        }
    }

    private func completeCollapse(cardId: UUID, generation: Int) {
        guard generation == heroGeneration,
              selectedCardId == cardId,
              heroDirection == -1 else { return }
        withoutAnimation {
            heroProgress = 0
            cardHeroProgress = 0
            heroDirection = 0
            isCardHeroAnimating = false
        }
        collapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame {
            guard generation == heroGeneration,
                  selectedCardId == cardId,
                  heroDirection == 0 else { return }
            collapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame {
                guard generation == heroGeneration,
                      selectedCardId == cardId,
                      heroDirection == 0 else { return }
                withoutAnimation {
                    self.selectedCardId = nil
                    activeHeroSnapshot = nil
                    isCardExpandedOrTransitioning = false
                }
                collapseCleanupTask = nil
            }
        }
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    private var heroAnimation: Animation {
        reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero
    }

    private var todayFocusChromeAnimation: Animation {
        reduceMotion ? HeroAnim.walletReduced : GoMotion.stateChange
    }

    private var headerCoconutAnimation: Animation {
        reduceMotion ? HeroAnim.walletReduced : GoMotion.feedback
    }

    private func makeHeroSnapshot(for card: FocusCard) -> FocusHomeVerticalSolidHeroSnapshot {
        let index = snapshot.cards.firstIndex { $0.id == card.id } ?? 0
        return FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private var heroSnapshotPreparationKey: String {
        let cardKey = snapshot.cards.map { card in
            [
                card.id.uuidString,
                card.name,
                card.kind,
                "\(card.coconutBalance)",
                card.homePrimaryMetricValue,
                card.homePrimaryMetricUnit,
                card.statusBadgeText ?? "",
                card.themeColorHex
            ].joined(separator: ":")
        }
        .joined(separator: "|")
        return "\(avatarCacheRevision)|\(cardKey)"
    }

    private func makeHeroSnapshot(for cardId: UUID) -> FocusHomeVerticalSolidHeroSnapshot? {
        guard let card = snapshot.cards.first(where: { $0.id == cardId }) else {
            return nil
        }
        return makeHeroSnapshot(for: card)
    }

    private func prepareHeroSnapshots() {
        let next = Dictionary(
            uniqueKeysWithValues: snapshot.cards.enumerated().map { index, card in
                (
                    card.id,
                    FocusHomeVerticalSolidHeroSnapshot(
                        card: card,
                        index: index,
                        avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
                    )
                )
            }
        )

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            preparedHeroSnapshots = next
            if let selectedCardId,
               let refreshed = next[selectedCardId],
               !isCardHeroAnimating {
                activeHeroSnapshot = refreshed.preservingCollapsedGeometry(from: activeHeroSnapshot)
            }
        }
    }
}

struct VerticalSolidHomeTodayFocusChrome: View {
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
            freezesToFrontCard: !isLive,
            allowsAmbientMotion: false
        )
        .transaction { transaction in
            if !isLive {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(isLive)
    }
}

private struct VerticalSolidHomeExpandedCardActions: View {
    let card: FocusCard
    let onAction: (VerticalSolidHomeQuickAction, Bool) -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isEditMode = false
    @State private var jiggle = false
    @State private var draggingItemId: String?
    @State private var visibleActionIds: [String] = []
    @State private var didLoadActionIds = false
    @State private var persistTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VerticalHomeEmbeddedQuickActions(
            title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
            items: activeActions.map(makeEmbeddedAction),
            addItems: addableActions.map(makeEmbeddedAction),
            isEditMode: isEditMode,
            jiggle: jiggle,
            shouldReduceWork: reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full,
            forcesSubmenusBelow: true,
            draggingItemId: $draggingItemId,
            onToggleEdit: toggleEditMode,
            onMove: moveAction,
            onRemove: removeAction,
            onAdd: addAction
        )
        .onAppear {
            loadActionIdsIfNeeded()
        }
        .onChange(of: card.id) { _, _ in
            loadActionIdsIfNeeded(force: true)
        }
        .onDisappear {
            persistTask?.cancel()
            persistActionIds()
        }
    }

    private var activeActions: [VerticalSolidHomeQuickAction] {
        let ids = didLoadActionIds ? visibleActionIds : allActionIds
        return ids.compactMap(action(for:))
    }

    private var addableActions: [VerticalSolidHomeQuickAction] {
        guard isEditMode else { return [] }
        let visible = Set(activeActions.map(\.id))
        return VerticalSolidHomeQuickAction.allCases.filter { !visible.contains($0.id) }
    }

    private var allActionIds: [String] {
        VerticalSolidHomeQuickAction.allCases.map(\.id)
    }

    private var storageKey: String {
        "verticalSolidHome.expandedQuickActions.\(card.id.uuidString).v1"
    }

    private func makeEmbeddedAction(_ action: VerticalSolidHomeQuickAction) -> VerticalHomeEmbeddedAction {
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
    }

    private func toggleEditMode() {
        loadActionIdsIfNeeded()

        if isEditMode {
            exitEditMode()
        } else {
            enterEditMode()
        }
    }

    private func enterEditMode() {
        withAnimation(GoMotion.selection) {
            isEditMode = true
        }
        jiggle = false
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 50) {
            guard isEditMode else { return }
            withAnimation(nil) {
                jiggle = true
            }
        }
    }

    private func exitEditMode() {
        persistActionIds()
        draggingItemId = nil
        jiggle = false
        withAnimation(GoMotion.selection) {
            isEditMode = false
        }
    }

    private func moveAction(fromId: String, toId: String) {
        guard fromId != toId,
              let fromIndex = visibleActionIds.firstIndex(of: fromId),
              let toIndex = visibleActionIds.firstIndex(of: toId) else {
            return
        }

        withAnimation(GoMotion.selection) {
            let moved = visibleActionIds.remove(at: fromIndex)
            visibleActionIds.insert(moved, at: toIndex)
        }
        schedulePersistActionIds()
    }

    private func removeAction(_ id: String) {
        guard visibleActionIds.count > 1,
              visibleActionIds.contains(id) else {
            OhanaFeedback.warning()
            return
        }

        withAnimation(GoMotion.feedback) {
            visibleActionIds.removeAll { $0 == id }
        }
        schedulePersistActionIds()
    }

    private func addAction(_ id: String) {
        guard action(for: id) != nil,
              !visibleActionIds.contains(id) else {
            return
        }

        withAnimation(GoMotion.feedback) {
            visibleActionIds.append(id)
        }
        schedulePersistActionIds()
    }

    private func loadActionIdsIfNeeded(force: Bool = false) {
        guard force || !didLoadActionIds else { return }

        let rawValue = UserDefaults.standard.string(forKey: storageKey)
        let savedIds = rawValue.map { raw in
            raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        } ?? allActionIds
        let sanitizedIds = sanitize(savedIds)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visibleActionIds = sanitizedIds.isEmpty ? [allActionIds[0]] : sanitizedIds
            didLoadActionIds = true
            draggingItemId = nil
            isEditMode = false
            jiggle = false
        }
    }

    private func sanitize(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids where allActionIds.contains(id) && !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    private func schedulePersistActionIds() {
        guard didLoadActionIds else { return }
        persistTask?.cancel()
        let ids = visibleActionIds
        let key = storageKey
        persistTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            UserDefaults.standard.set(ids.joined(separator: ","), forKey: key)
        }
    }

    private func persistActionIds() {
        guard didLoadActionIds else { return }
        persistTask?.cancel()
        UserDefaults.standard.set(visibleActionIds.joined(separator: ","), forKey: storageKey)
    }

    private func action(for id: String) -> VerticalSolidHomeQuickAction? {
        VerticalSolidHomeQuickAction.allCases.first { $0.id == id }
    }
}

struct VerticalSolidHomePlantsPage: View {
    let plants: [VerticalSolidHomePlantSnapshot]
    let onOpenPlant: (VerticalSolidHomePlantSnapshot) -> Void
    let onAddPlant: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if plants.isEmpty {
                    VerticalSolidHomeEmptyAction(
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
                                VerticalSolidHomeAvatar(emoji: plant.emoji, color: Color(hex: plant.themeHex), size: 46)
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

struct VerticalSolidHomeBottomBar: View {
    let selectedTab: VerticalSolidHomeTab
    let safeBottom: CGFloat
    let canAnimate: Bool
    let onSelect: (VerticalSolidHomeTab) -> Void
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

    private func tabButton(_ tab: VerticalSolidHomeTab) -> some View {
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

struct VerticalSolidHomeAvatar: View {
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

struct VerticalSolidHomeEmptyAction: View {
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

struct VerticalSolidHomePreparedPlaceholder: View {
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
