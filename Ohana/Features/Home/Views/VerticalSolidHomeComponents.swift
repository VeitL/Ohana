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
    let visibleTabs: [VerticalSolidHomeTab]
    let canAnimate: Bool
    @ViewBuilder var home: (VerticalSolidHomePageLifecycle) -> HomePage
    @ViewBuilder var calendar: (VerticalSolidHomePageLifecycle) -> CalendarPage
    @ViewBuilder var oasis: (VerticalSolidHomePageLifecycle) -> OasisPage
    @ViewBuilder var plants: (VerticalSolidHomePageLifecycle) -> PlantsPage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(visibleTabs) { tab in
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

        if !isMounted(tab) {
            VerticalSolidHomePreparedPlaceholder()
        } else if lifecycle.isPreparingForDisplay {
            switch tab {
            case .oasis:
                oasis(lifecycle)
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
    let interaction: HomeInteractionSnapshot
    let avatarCacheRevision: Int
    let isLive: Bool
    let walkPresentationRevision: Int
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
    let cardStateResetToken: UUID
    let onOpenCardDetails: (FocusCard) -> Void
    let onQuickActionForCard: (QuickActionItem, FocusCard, Bool) -> Void
    let onQuickActionOptionForCard: (QuickActionItem, FocusCard, String) -> Void
    let onQuickActionLimitReached: () -> Void
    let onExpandedCardCollapseIntent: () -> Bool
    let onWalkCardMinimizeToFloatingControl: () -> Void
    let onAddFirstPet: () -> Void

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
                if let firstPetEmptyState = snapshot.firstPetEmptyState, arrivingCardId == nil {
                    VerticalSolidHomeFirstPetEmptyStateView(
                        state: firstPetEmptyState,
                        onAddPet: onAddFirstPet
                    )
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if !snapshot.cards.isEmpty {
                    FocusHomeVerticalSolidScene(
                        cards: snapshot.cards,
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
                        walkPresentationRevision: walkPresentationRevision,
                        embedsQuickActionsInCard: true,
                        collapsedTopInset: collapsedTopInset,
                        quickActions: { card in
                            VerticalSolidHomeExpandedCardActions(
                                card: card,
                                actionSnapshot: interaction.expandedActions(for: card.id),
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
                        onCollapse: handleExpandedCardCollapseIntent,
                        onWalkCardMinimizeToFloatingControl: onWalkCardMinimizeToFloatingControl,
                        onOpenDetails: onOpenCardDetails
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
            reconcileCardSelectionWithSnapshot()
        }
        .onChange(of: heroSnapshotPreparationKey) { _, _ in
            prepareHeroSnapshots()
            reconcileCardSelectionWithSnapshot()
        }
        .onChange(of: cardIdentityKey) { _, _ in
            prepareHeroSnapshots()
            reconcileCardSelectionWithSnapshot()
        }
        .onChange(of: cardStateResetToken) { _, _ in
            resetCardPresentationState()
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

    private func handleExpandedCardCollapseIntent() {
        if onExpandedCardCollapseIntent() {
            return
        }
        collapseCard()
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

    private func reconcileCardSelectionWithSnapshot() {
        let reconciliation = FocusHomeCardDataSource.selectionReconciliation(
            cards: snapshot.cards,
            selectedCardId: selectedCardId,
            headerContextCardId: headerContextCardId
        )
        guard reconciliation.clearsSelectedCard || reconciliation.clearsHeaderContext else { return }

        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        withoutAnimation {
            if reconciliation.clearsSelectedCard {
                selectedCardId = nil
                activeHeroSnapshot = nil
                heroProgress = 0
                heroDirection = 0
                cardHeroProgress = 0
                isCardExpandedOrTransitioning = false
                isCardHeroAnimating = false
            }
            if reconciliation.clearsHeaderContext {
                headerContextCardId = nil
            }
        }
    }

    private func resetCardPresentationState() {
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        withoutAnimation {
            selectedCardId = nil
            activeHeroSnapshot = nil
            heroProgress = 0
            heroDirection = 0
            cardHeroProgress = 0
            headerContextCardId = nil
            isCardExpandedOrTransitioning = false
            isCardHeroAnimating = false
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

    private var cardIdentityKey: String {
        snapshot.cards.map(\.id.uuidString).joined(separator: "|")
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

private struct VerticalSolidHomeFirstPetEmptyStateView: View {
    let state: VerticalSolidHomeFirstPetEmptyState
    let onAddPet: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.16))
                    Image(systemName: "pawprint.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goPrimary)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(state.eyebrow)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.12), in: Capsule())

                    Text(state.title)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(state.subtitle)
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goTeal)
                Text(state.progressText)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurfaceElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

            Button(action: onAddPet) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .symbolRenderingMode(.monochrome)
                    Text(state.primaryActionTitle)
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(state.primaryActionTitle)
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(Color.ohanaCardSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
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
    let onOpenExchange: (TodayFocusExchangeRequestSnapshot) -> Void
    let onConfirmExchange: (TodayFocusExchangeRequestSnapshot) -> Void

    var body: some View {
        TodayFocusCard(
            snapshot: snapshot,
            presentation: .compactStack,
            onOpenQuest: onOpenQuest,
            onCompleteQuest: onCompleteQuest,
            onTapNegativeSignal: onTapNegativeSignal,
            onTapOasis: onOpenOasis,
            onTapFamilyTask: onTapFamilyTask,
            onOpenExchange: onOpenExchange,
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
                    .accessibilityIdentifier("home-plants-empty-add-action")
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
                        .accessibilityIdentifier("home-plants-card-\(plant.name)")
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("home-plants-page")
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

struct OasisTreeRenderSnapshot: Equatable {
    let level: Int
    let progressToNextLevel: Double
    let totalEnergy: Int
    let nextLevelThreshold: Int
    let shopLockedLevel: Int?
    let crittersLockedLevel: Int?
    let gachaLockedLevel: Int?

    init(
        level: Int,
        progressToNextLevel: Double,
        totalEnergy: Int = 0,
        nextLevelThreshold: Int = 0,
        shopLockedLevel: Int? = nil,
        crittersLockedLevel: Int? = nil,
        gachaLockedLevel: Int? = nil
    ) {
        self.level = min(max(level, 0), 10)
        self.progressToNextLevel = Self.clampedProgress(progressToNextLevel)
        self.totalEnergy = max(0, totalEnergy)
        self.nextLevelThreshold = max(0, nextLevelThreshold)
        self.shopLockedLevel = shopLockedLevel
        self.crittersLockedLevel = crittersLockedLevel
        self.gachaLockedLevel = gachaLockedLevel
    }

    static func clampedProgress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

struct VerticalSolidHomeOasisFrozenTreeStage: View {
    let snapshot: OasisTreeRenderSnapshot
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        GeometryReader { proxy in
            let metrics = OasisEmbeddedLayoutPolicy.metrics(availableHeight: proxy.size.height)

            VStack(spacing: metrics.sectionSpacing) {
                frozenTreeCard(metrics: metrics)
                    .frame(height: metrics.treeCardHeight)

                frozenBentoGrid
                    .frame(height: metrics.bentoGridHeight)
            }
            .padding(.horizontal, 16)
            .padding(.top, metrics.topPadding)
            .padding(.bottom, metrics.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("oasis-screen")
    }

    private func frozenTreeCard(metrics: OasisEmbeddedLayoutMetrics) -> some View {
        let stageShape = RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)

        return ZStack {
            frozenStageBackground(shape: stageShape)
            frozenStageStars
            frozenStageSun
            frozenIslandBase
            frozenTreeGlow

            VStack(spacing: 0) {
                frozenStageHUD
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                BeautifulCoconutTree(
                    level: snapshot.level,
                    isInjecting: false,
                    growthProgress: snapshot.progressToNextLevel,
                    pendingUpgradeCoconutCount: 0,
                    dailyCoconutCount: 0,
                    allowsAmbientMotion: false,
                    harvestedCoconuts: []
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .frame(height: metrics.treeVisualHeight)
                .padding(.bottom, 2)

                frozenUpgradeCoconutDock
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)

                frozenProgressRail
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .frame(height: metrics.treeCardHeight)
        .clipShape(stageShape)
        .overlay(stageShape.strokeBorder(Color.goPrimary.opacity(0.22), lineWidth: 1))
        .contentShape(stageShape)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("level \(snapshot.level)")
        .accessibilityIdentifier("oasis-tree-level-control")
    }

    private var frozenBentoGrid: some View {
        OasisBentoGridView(
            snapshot: OasisBentoSnapshot(
                shopMetric: "—",
                achievementMetric: "—",
                achievementsLocked: false,
                critterMetric: "—"
            ),
            localization: l,
            shopLockedLevel: snapshot.shopLockedLevel,
            crittersLockedLevel: snapshot.crittersLockedLevel,
            gachaLockedLevel: snapshot.gachaLockedLevel,
            isCompact: true,
            isInteractive: false,
            onOpenShop: {},
            onOpenAchievements: {},
            onOpenCritters: {},
            onOpenGacha: {}
        )
    }

    private var treeDisplayName: String {
        TreeLevel(rawValue: snapshot.level)?.displayName ?? "生命之树"
    }

    private var treeGlowColor: Color {
        TreeLevel(rawValue: snapshot.level)?.glowColor ?? Color.goPrimary
    }

    private var energyRailTitle: String {
        if snapshot.level >= TreeLevel.lv10.rawValue {
            return l.tr(zh: "满级", en: "Max", de: "Max")
        }
        if snapshot.nextLevelThreshold > 0 {
            return "\(snapshot.totalEnergy)/\(snapshot.nextLevelThreshold)"
        }
        return "\(Int(snapshot.progressToNextLevel * 100))%"
    }

    private var frozenUpgradeCoconutDock: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles") // a11y: allow decorative frozen Oasis hint icon
                    .accessibilityHidden(true)
                Text(nextStageHint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaSecondaryText)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }

    private var nextStageHint: String {
        if snapshot.level >= TreeLevel.lv10.rawValue {
            return l.tr(zh: "树冠已觉醒", en: "Tree awakened", de: "Baum erwacht")
        }
        return l.tr(
            zh: "下一颗升级椰子在树上成长",
            en: "Next upgrade coconut is growing",
            de: "Nächste Upgrade-Kokosnuss wächst"
        )
    }

    private var frozenProgressRail: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(energyRailTitle)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .monospacedDigit()
                Spacer()
                if passiveIncomeAmount > 0 {
                    Text("+\(passiveIncomeAmount)🥥/d")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goPrimary)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * CGFloat(snapshot.progressToNextLevel)))
                }
            }
            .frame(height: 8)
        }
    }

    private func frozenStageBackground(shape: RoundedRectangle) -> some View {
        shape
            .fill(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color(hex: "D9E8FA"), Color(hex: "BFD1EA"), Color(hex: "8DA8D4")]
                        : [Color(hex: "081338"), Color(hex: "051027"), Color(hex: "020617")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .fill(
                        RadialGradient(
                            colors: [treeGlowColor.opacity(colorScheme == .light ? 0.22 : 0.32), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 300
                        )
                    )
            }
    }

    private var passiveIncomeAmount: Int {
        switch snapshot.level {
        case 5: 3
        case 6: 4
        case 7: 6
        case 8: 8
        case 9: 10
        case 10...: 15
        default: 0
        }
    }

    private var frozenStageStars: some View {
        ZStack {
            ForEach(0 ..< 24, id: \.self) { index in
                let size = CGFloat([1.5, 2.0, 2.5, 1.8][index % 4])
                Circle()
                    .fill(Color.ohanaPrimaryText.opacity(Double([0.28, 0.44, 0.24, 0.5][index % 4])))
                    .frame(width: size, height: size)
                    .offset(
                        x: CGFloat((index * 53) % 320) - 160,
                        y: CGFloat((index * 37) % 220) - 160
                    )
            }
        }
        .opacity(colorScheme == .light ? 0.45 : 1)
    }

    private var frozenStageSun: some View {
        Circle()
            .fill(Color.goYellow)
            .frame(width: 26, height: 26) // a11y: allow non-interactive frozen Oasis celestial dot
            .shadow(color: Color.goYellow.opacity(0.68), radius: 14, x: 0, y: 0) // ui-v4: allow frozen Oasis stage celestial glow
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 24)
            .padding(.trailing, 28)
    }

    private var frozenIslandBase: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .light
                            ? [Color(hex: "D4B989"), Color(hex: "B58B55")]
                            : [Color(hex: "E2A545"), Color(hex: "9A5B22")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 304, height: 56)
                .blur(radius: 0.2)

            Ellipse()
                .fill(Color.black.opacity(colorScheme == .light ? 0.12 : 0.26)) // ui-v4: allow grounded frozen island stage shadow
                .frame(width: 250, height: 18)
                .offset(y: 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 110)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var frozenTreeGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [treeGlowColor.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 190
                    )
                )
                .frame(width: 340, height: 340)
                .scaleEffect(0.94)

            Circle()
                .stroke(Color.goPrimary.opacity(0.05), lineWidth: 2)
                .frame(width: 250, height: 250)
                .blur(radius: 2)
        }
        .offset(y: -32)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var frozenStageHUD: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv.\(snapshot.level)")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .monospacedDigit()
                Text(treeDisplayName)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("level \(snapshot.level)")

            Spacer(minLength: 4)
        }
    }
}
