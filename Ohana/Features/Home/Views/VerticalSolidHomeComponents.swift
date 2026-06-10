//
//  VerticalSolidHomeComponents.swift
//  Ohana
//
//  Pure render surfaces for verticalSolid home.
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
        mounted.formUnion(prepared)
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

struct VerticalSolidHomePageDeck<HomePage: View, CalendarPage: View, OasisPage: View, PlantsPage: View>: View {
    let selectedTab: VerticalSolidHomeTab
    let outgoingTab: VerticalSolidHomeTab?
    let preparingTab: VerticalSolidHomeTab?
    let preparedTabs: Set<VerticalSolidHomeTab>
    let canAnimate: Bool
    @ViewBuilder var home: (VerticalSolidHomePageLifecycle) -> HomePage
    @ViewBuilder var calendar: (VerticalSolidHomePageLifecycle) -> CalendarPage
    @ViewBuilder var oasis: (VerticalSolidHomePageLifecycle) -> OasisPage
    @ViewBuilder var plants: (VerticalSolidHomePageLifecycle) -> PlantsPage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(VerticalSolidHomeTab.visibleTabs) { tab in
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
        let lifecycle = lifecycle(for: tab)

        if lifecycle.isPreparingForDisplay {
            switch tab {
            case .oasis:
                VerticalSolidHomeOasisPreparedPreview()
            case .home, .calendar, .plants:
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

struct VerticalSolidHomeDashboardPage: View {
    let snapshot: VerticalSolidHomeSnapshot
    let pets: [Pet]
    let humans: [Human]
    let allEvents: [Event]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let expenseLogs: [PetExpenseLog]
    let avatarCacheRevision: Int
    let isLive: Bool
    let collapsedTopInset: CGFloat
    let localization: L10n
    let activeHumanID: UUID?
    let allowsAmbientFloat: Bool
    @Binding var quickActionItemsRaw: String
    @Binding var headerContextCardId: UUID?
    @Binding var isCardExpandedOrTransitioning: Bool
    @Binding var isCardHeroAnimating: Bool
    @Binding var cardHeroProgress: CGFloat
    let arrivingCardId: UUID?
    let onOpenCard: (FocusCard) -> Void
    let onQuickActionForCard: (QuickActionItem, FocusCard, Bool) -> Void
    let onQuickActionOptionForCard: (QuickActionItem, FocusCard, String) -> Void
    let onQuickActionLimitReached: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCardId: UUID?
    @State private var preparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    @State private var activeHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    @State private var heroProgress: CGFloat = 0
    @State private var heroDirection: Int = 0
    @State private var heroGeneration = 0
    @State private var collapseCleanupTask: Task<Void, Never>?
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                if !snapshot.cards.isEmpty {
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
                        localization: localization,
                        allowsAmbientFloat: allowsAmbientFloat,
                        isVisible: isLive,
                        embedsQuickActionsInCard: true,
                        collapsedTopInset: collapsedTopInset,
                        quickActions: { card in
                            VerticalSolidHomeExpandedCardActions(
                                card: card,
                                pets: pets,
                                humans: humans,
                                allEvents: allEvents,
                                humanMedications: humanMedications,
                                humanMedicationLogs: humanMedicationLogs,
                                expenseLogs: expenseLogs,
                                localization: localization,
                                activeHumanID: activeHumanID,
                                quickActionItemsRaw: $quickActionItemsRaw,
                                onAction: { item, usesPrimaryAction in
                                    onQuickActionForCard(item, card, usesPrimaryAction)
                                },
                                onOptionAction: { item, optionId in
                                    onQuickActionOptionForCard(item, card, optionId)
                                },
                                onLimitReached: onQuickActionLimitReached
                            )
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
        "\(avatarCacheRevision)|\(snapshot.heroPreparationRevision)"
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
    let onOpenQuest: (IslandQuest) -> Void
    let onCompleteQuest: (IslandQuest) -> Void
    let onTapNegativeSignal: (IslandNegativeSignal) -> Void
    let onTapFamilyTask: (TodayFocusFamilyTaskSnapshot) -> Void
    let onConfirmExchange: (TodayFocusExchangeRequestSnapshot) -> Void

    var body: some View {
        TodayFocusCard(
            snapshot: snapshot,
            presentation: .compactStack,
            onOpenQuest: onOpenQuest,
            onCompleteQuest: onCompleteQuest,
            onTapNegativeSignal: onTapNegativeSignal,
            onTapMemory: onOpenOasis,
            onTapOasis: onOpenOasis,
            onTapFamilyTask: onTapFamilyTask,
            onConfirmExchange: onConfirmExchange,
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

struct VerticalSolidHomePlantsPage: View {
    let plants: [VerticalSolidHomePlantSnapshot]
    let localization: L10n
    let onOpenPlant: (VerticalSolidHomePlantSnapshot) -> Void
    let onAddPlant: () -> Void

    private var l: L10n { localization }

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
                                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                    Text(plant.subtitle.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.subtitle)
                                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if plant.needsCare {
                                    Image(systemName: "drop.fill").accessibilityHidden(true)
                                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                                        .foregroundStyle(Color.goTeal)
                                }
                            }
                            .padding(14)
                            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                Text(title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer()
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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

struct VerticalSolidHomeOasisPreparedPreview: View {
    var body: some View {
        GeometryReader { proxy in
            let stageHeight = min(540, max(360, proxy.size.height * 0.76))

            VStack(spacing: 14) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.goPrimary.opacity(0.14),
                                    Color.goTeal.opacity(0.12),
                                    Color.goYellow.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                                .strokeBorder(Color.goPrimary.opacity(0.18), lineWidth: 1)
                        }

                    VStack(spacing: 22) {
                        Spacer(minLength: 0)

                        VerticalSolidHomeOasisPreviewTree()
                            .frame(width: 188, height: 238)

                        RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                            .fill(Color.goPrimary.opacity(0.18))
                            .frame(width: 220, height: 12)
                            .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 18)
                }
                .frame(height: stageHeight)

                HStack(spacing: 10) {
                    ForEach(0 ..< 3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                            .fill(index == 0 ? Color.goPrimary.opacity(0.16) : Color.ohanaControlFill.opacity(0.72))
                            .frame(height: 52)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct VerticalSolidHomeOasisPreviewTree: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.arkInk.opacity(0.12))
                .frame(width: 164, height: 24)
                .offset(y: 7)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.goYellow.opacity(0.86), Color.goPrimary.opacity(0.72)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 18, height: 150)
                .rotationEffect(.degrees(-4))
                .offset(y: -22)

            ZStack {
                ForEach(0 ..< 6, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color.goPrimary.opacity(0.82) : Color.goTeal.opacity(0.72))
                        .frame(width: 22, height: 118)
                        .rotationEffect(.degrees(Double(index) * 42 - 105))
                        .offset(y: -84)
                }
            }
            .offset(y: -106)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.goYellow.opacity(0.92))
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(Color.goYellow.opacity(0.78))
                    .frame(width: 20, height: 20)
            }
            .offset(x: 22, y: -128)
        }
    }
}
