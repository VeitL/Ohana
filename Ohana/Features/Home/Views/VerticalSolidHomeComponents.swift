//
//  VerticalSolidHomeComponents.swift
//  Ohana
//
//  Pure render surfaces for verticalSolid home.
//

import Foundation
import SwiftUI

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
    @State private var cardScrollOffsetTracker = VerticalSolidHomeMemberCardScrollOffsetTracker()
    @State private var expandedCardScrollOffsetY: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let firstPetEmptyState = snapshot.firstPetEmptyState, arrivingCardId == nil {
                    VerticalSolidHomeFirstPetEmptyStateView(
                        state: firstPetEmptyState,
                        onAddPet: onAddFirstPet
                    )
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if !snapshot.cards.isEmpty {
                    if VerticalSolidHomeMemberWalletScrollPolicy.usesExtendedLayout(
                        cardCount: snapshot.cards.count
                    ) {
                        extendedMemberCardDeck(viewportHeight: proxy.size.height)
                    } else {
                        memberCardScene()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onDisappear {
            resetCardPresentationState()
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

    private func extendedMemberCardDeck(viewportHeight: CGFloat) -> some View {
        let baseSceneHeight = VerticalSolidHomeMemberWalletScrollPolicy.sceneHeight(
            cardCount: snapshot.cards.count,
            viewportHeight: viewportHeight,
            collapsedTopInset: collapsedTopInset
        )
        let sceneHeight = VerticalSolidHomeMemberWalletScrollPolicy.anchoredExpandedSceneHeight(
            baseHeight: baseSceneHeight,
            selectedCardId: selectedCardId,
            scrollOffsetY: expandedCardScrollOffsetY
        )

        return ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                memberCardScene(
                    collapsedLayoutMode: .scrollExtended,
                    expandedVerticalPlacement: .viewportTop(
                        topInset: VerticalSolidHomeMemberWalletScrollPolicy.expandedCardViewportTopInset,
                        scrollOffsetY: expandedCardScrollOffsetY
                    )
                )
                .frame(height: sceneHeight)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(
            VerticalSolidHomeMemberWalletScrollPolicy.scrollIsDisabled(
                selectedCardId: selectedCardId
            )
        )
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offsetY in
            guard selectedCardId == nil else { return }
            cardScrollOffsetTracker.offsetY = max(0, offsetY)
        }
        .accessibilityIdentifier("home-member-card-scroll-view")
    }

    private func memberCardScene(
        collapsedLayoutMode: FocusHomeVerticalSolidCollapsedLayoutMode = .balanced,
        expandedVerticalPlacement: FocusHomeVerticalSolidExpandedVerticalPlacement = .sceneCenter
    ) -> some View {
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
            collapsedLayoutMode: collapsedLayoutMode,
            expandedVerticalPlacement: expandedVerticalPlacement,
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
        let frozenScrollOffsetY = VerticalSolidHomeMemberWalletScrollPolicy.usesExtendedLayout(
            cardCount: self.snapshot.cards.count
        ) ? cardScrollOffsetTracker.offsetY : 0
        OhanaFeedback.light()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            expandedCardScrollOffsetY = frozenScrollOffsetY
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

private final class VerticalSolidHomeMemberCardScrollOffsetTracker {
    var offsetY: CGFloat = 0
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
    let availableCoconutBalance: Int?
    let shopLockedLevel: Int?
    let shopInitialCategory: ShopItem.ShopCategory
    let achievementsLockedLevel: Int?
    let crittersLockedLevel: Int?
    let gachaLockedLevel: Int?

    var coconutBalance: Int? { availableCoconutBalance }

    init(
        level: Int,
        progressToNextLevel: Double,
        totalEnergy: Int = 0,
        nextLevelThreshold: Int = 0,
        coconutBalance: Int? = nil,
        shopLockedLevel: Int? = nil,
        shopInitialCategory: ShopItem.ShopCategory = .effect,
        achievementsLockedLevel: Int? = nil,
        crittersLockedLevel: Int? = nil,
        gachaLockedLevel: Int? = nil
    ) {
        self.level = min(max(level, 0), 10)
        self.progressToNextLevel = Self.clampedProgress(progressToNextLevel)
        self.totalEnergy = max(0, totalEnergy)
        self.nextLevelThreshold = max(0, nextLevelThreshold)
        availableCoconutBalance = coconutBalance.map { max(0, $0) }
        self.shopLockedLevel = shopLockedLevel
        self.shopInitialCategory = shopInitialCategory
        self.achievementsLockedLevel = achievementsLockedLevel
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
    var injectionPulseToken = 0
    var allowsAmbientMotion = false
    var allowsInteractionMotion = false
    var usesFullVisualEffects = true
    var layoutStyle: OasisHomeTreeLayoutStyle = .standard
    var onInjectEnergy: () -> Void = {}
    var onOpenShop: (ShopItem.ShopCategory) -> Void = { _ in }
    var onOpenAchievements: () -> Void = {}
    var onOpenCritters: () -> Void = {}
    var onOpenGacha: () -> Void = {}
    var onOpenGrowthRoadmap: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

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

            VStack(spacing: 0) {
                frozenStageHUD
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                if layoutStyle == .zen {
                    VStack(spacing: 0) {
                        frozenTreeScene(height: metrics.treeVisualHeight)

                        frozenUpgradeCoconutDock
                            .padding(.horizontal, 18)
                            .padding(.bottom, 4)

                        frozenProgressRail
                            .padding(.horizontal, 18)
                            .padding(.bottom, 8)

                        frozenInjectEnergyButton
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    }
                    .offset(y: -28)
                } else {
                    frozenTreeScene(height: metrics.treeVisualHeight)

                    frozenUpgradeCoconutDock
                        .padding(.horizontal, 18)
                        .padding(.bottom, 5)

                    frozenInjectEnergyButton
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)

                    frozenProgressRail
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
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

    private func frozenTreeScene(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            frozenTreeGlow
                .zIndex(0)

            OasisTreeEnergySurgeView(
                pulseToken: injectionPulseToken,
                color: treeGlowColor,
                allowsMotion: allowsInteractionMotion
            )
            .zIndex(1)

            OasisTreeIslandBase(
                level: snapshot.level,
                progress: snapshot.progressToNextLevel
            )
            .zIndex(2)

            BeautifulCoconutTree(
                level: snapshot.level,
                isInjecting: false,
                growthProgress: snapshot.progressToNextLevel,
                injectionPulseToken: injectionPulseToken,
                pendingUpgradeCoconutCount: 0,
                dailyCoconutCount: 0,
                allowsAmbientMotion: allowsAmbientMotion,
                allowsInteractionMotion: allowsInteractionMotion,
                usesLiquidGlassLeaves: usesFullVisualEffects,
                harvestedCoconuts: []
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .frame(height: max(0, height - 18))
            .offset(y: -18)
            .zIndex(3)
        }
        .frame(height: height)
    }

    private var frozenInjectEnergyButton: some View {
        let cost = OasisTreeEnergyInjectionPolicy.starterPackageCost
        let energy = OasisTreeEnergyInjectionPolicy.starterPackageXP
        return Button {
            OhanaFeedback.medium()
            onInjectEnergy()
        } label: {
            Label(
                frozenInjectionButtonTitle(cost: cost, energy: energy),
                systemImage: "bolt.fill"
            )
            .font(OhanaFont.body(.black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 14)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: 236)
        .frame(maxWidth: .infinity)
        .opacity(canInjectFrozenEnergy(cost: cost) ? 1 : 0.52)
        .disabled(!canInjectFrozenEnergy(cost: cost))
        .accessibilityIdentifier("oasis-inject-energy-action")
        .accessibilityHint(l.tr(
            zh: "照护会自然增加能量，椰子可以用于加速成长",
            en: "Care grows the tree naturally; coconuts can accelerate it",
            de: "Pflege lässt den Baum natürlich wachsen; Kokosnüsse beschleunigen das Wachstum"
        ))
    }

    private func canInjectFrozenEnergy(cost: Int) -> Bool {
        snapshot.availableCoconutBalance.map { $0 >= cost } ?? true
    }

    private func frozenInjectionButtonTitle(cost: Int, energy: Int) -> String {
        guard canInjectFrozenEnergy(cost: cost) else {
            return l.tr(
                zh: "椰子不足 · 需要 \(cost)🥥",
                en: "Need \(cost)🥥",
                de: "\(cost)🥥 benötigt"
            )
        }
        return l.tr(
            zh: "注入 \(cost)🥥 · +\(energy) 能量",
            en: "Use \(cost)🥥 · +\(energy) energy",
            de: "\(cost)🥥 nutzen · +\(energy) Energie"
        )
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
            achievementsLockedLevel: snapshot.achievementsLockedLevel,
            crittersLockedLevel: snapshot.crittersLockedLevel,
            gachaLockedLevel: snapshot.gachaLockedLevel,
            isCompact: true,
            interactiveFeatures: Set(OasisBentoFeature.allCases),
            onOpenShop: {
                onOpenShop(snapshot.shopInitialCategory)
            },
            onOpenAchievements: onOpenAchievements,
            onOpenCritters: onOpenCritters,
            onOpenGacha: onOpenGacha
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
            return l.tr(zh: "生命树已达到满级", en: "Life Tree at max level", de: "Lebensbaum auf höchster Stufe")
        }
        if snapshot.nextLevelThreshold > 0 {
            let nextLevel = min(TreeLevel.lv10.rawValue, snapshot.level + 1)
            let remaining = max(0, snapshot.nextLevelThreshold - snapshot.totalEnergy)
            return l.tr(
                zh: "距 Lv.\(nextLevel) 还差 \(remaining) 能量",
                en: "\(remaining) energy to Lv.\(nextLevel)",
                de: "Noch \(remaining) Energie bis Lv.\(nextLevel)"
            )
        }
        return "\(Int(snapshot.progressToNextLevel * 100))%"
    }

    private var energyRailValue: String? {
        guard snapshot.level < TreeLevel.lv10.rawValue, snapshot.nextLevelThreshold > 0 else { return nil }
        return "\(snapshot.totalEnergy)/\(snapshot.nextLevelThreshold)"
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
        .frame(minHeight: 28)
    }

    private var nextStageHint: String {
        if snapshot.level >= TreeLevel.lv10.rawValue {
            return l.tr(zh: "树冠已觉醒", en: "Tree awakened", de: "Baum erwacht")
        }
        return l.tr(
            zh: "完成照护，生命树会自然成长",
            en: "Care grows the Life Tree naturally",
            de: "Pflege lässt den Lebensbaum natürlich wachsen"
        )
    }

    private var frozenProgressRail: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(energyRailTitle)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                if passiveIncomeAmount > 0 {
                    Text("+\(passiveIncomeAmount)🥥/d")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goPrimary)
                }
                if let energyRailValue {
                    Text(energyRailValue)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .monospacedDigit()
                }
            }

            OasisEnergyProgressBar(
                progress: snapshot.progressToNextLevel,
                pulseToken: injectionPulseToken,
                allowsMotion: allowsInteractionMotion
            )
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
            ForEach(0 ..< 8, id: \.self) { index in
                let size = CGFloat([2.0, 2.8, 2.2, 3.0][index % 4])
                Circle()
                    .fill(Color.ohanaPrimaryText.opacity(Double([0.22, 0.38, 0.20, 0.32][index % 4])))
                    .frame(width: size, height: size)
                    .shadow(color: Color.ohanaPrimaryText.opacity(0.18), radius: 3) // ui-v4: allow subtle decorative star glow inside the frozen Oasis illustration
                    .offset(
                        x: CGFloat((index * 53) % 320) - 160,
                        y: CGFloat((index * 37) % 220) - 160
                    )
            }
        }
        .opacity(colorScheme == .light ? 0.45 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var frozenStageSun: some View {
        Image(systemName: "moon.fill") // a11y: allow non-interactive frozen Oasis moon
            .font(OhanaFont.adaptive(size: 25, weight: .black))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(Color.goYellow)
            .shadow(color: Color.goYellow.opacity(0.68), radius: 14, x: 0, y: 0) // ui-v4: allow frozen Oasis stage celestial glow
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 24)
            .padding(.trailing, 28)
            .accessibilityHidden(true)
    }

    private var frozenTreeGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [treeGlowColor.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 145
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(0.96)

            Circle()
                .stroke(Color.goPrimary.opacity(0.035), lineWidth: 1.5)
                .frame(width: 210, height: 210)
                .blur(radius: 2)
        }
        .offset(y: -12)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var frozenStageHUD: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                OhanaFeedback.light()
                onOpenGrowthRoadmap()
            } label: {
                HStack(spacing: 9) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lv.\(snapshot.level)")
                            .font(OhanaFont.title3(.black))
                            .monospacedDigit()
                        Text(treeDisplayName)
                            .font(OhanaFont.caption(.black))
                            .opacity(0.72)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right") // a11y: allow decorative disclosure glyph; the button owns the localized label
                        .font(OhanaFont.caption(.black))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .accessibilityLabel(l.tr(
                zh: "椰子树等级 Lv.\(snapshot.level)",
                en: "Coconut Tree level \(snapshot.level)",
                de: "Kokosbaum Stufe \(snapshot.level)"
            ))
            .accessibilityHint(l.tr(
                zh: "打开升级路线和解锁规则",
                en: "Open upgrade roadmap and unlock rules",
                de: "Upgrade-Roadmap und Freischaltregeln öffnen"
            ))

            Spacer(minLength: 4)
        }
    }
}
