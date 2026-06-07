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
        selected: VerticalSolidHomeTab,
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
        let lifecycle = lifecycle(for: tab)

        if lifecycle.isPreparingForDisplay && tab != .oasis {
            VerticalSolidHomePreparedPlaceholder()
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
    let onTapFamilyTask: (FamilyCollaborationTask) -> Void
    let onConfirmExchange: (CoconutExchangeRequest) -> Void

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

private struct VerticalSolidHomeExpandedCardActions: View {
    let card: FocusCard
    let pets: [Pet]
    let humans: [Human]
    let allEvents: [Event]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let expenseLogs: [PetExpenseLog]
    let localization: L10n
    let activeHumanID: UUID?
    @Binding var quickActionItemsRaw: String
    let onAction: (QuickActionItem, Bool) -> Void
    let onOptionAction: (QuickActionItem, String) -> Void
    let onLimitReached: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isEditMode = false
    @State private var jiggle = false
    @State private var draggingItemId: String?
    @State private var renderModel = VerticalSolidHomeExpandedActionRenderModel.empty
    @State private var renderModelTask: Task<Void, Never>?
    @State private var jiggleTask: Task<Void, Never>?

    private var l: L10n { localization }

    var body: some View {
        VerticalHomeEmbeddedQuickActions(
            title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
            items: renderModel.actions,
            addItems: renderModel.addActions,
            localization: l,
            itemsRevision: renderModel.actionsRevision,
            addItemsRevision: renderModel.addActionsRevision,
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
            scheduleRenderModelRefresh(normalizesStoredItems: true)
        }
        .onChange(of: card.id) { _, _ in
            exitEditMode(persists: false)
            scheduleRenderModelRefresh(normalizesStoredItems: true)
        }
        .onChange(of: renderRefreshKey) { _, _ in
            scheduleRenderModelRefresh(normalizesStoredItems: true)
        }
        .onChange(of: isEditMode) { _, _ in
            scheduleRenderModelRefresh(normalizesStoredItems: false)
        }
        .onDisappear {
            renderModelTask?.cancel()
            renderModelTask = nil
            jiggleTask?.cancel()
            jiggleTask = nil
            jiggle = false
            renderModel = .empty
        }
    }

    private var renderRefreshKey: String {
        [
            card.id.uuidString,
            card.isHuman ? "human" : "pet",
            quickActionItemsRaw,
            localization.languageCode,
            activeHumanID?.uuidString ?? "",
            "\(allEvents.count)",
            "\(humanMedications.count)",
            "\(humanMedicationLogs.count)",
            "\(expenseLogs.count)",
            card.homePrimaryMetricValue,
            card.statusBadgeText ?? ""
        ].joined(separator: "|")
    }

    private func scheduleRenderModelRefresh(normalizesStoredItems: Bool) {
        renderModelTask?.cancel()
        renderModelTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            let nextModel = buildRenderModel()
            guard !Task.isCancelled else { return }
            withTransaction(Transaction(animation: nil)) {
                renderModel = nextModel
            }
            if normalizesStoredItems {
                normalizeStoredItemsIfNeeded(using: nextModel)
            }
            renderModelTask = nil
        }
    }

    private func buildRenderModel() -> VerticalSolidHomeExpandedActionRenderModel {
        let currentItems = buildCurrentItems()
        let visibleItems = Array(currentItems.prefix(QuickActionLimit.maxItemsPerEntity))
        let candidateItems = buildCandidateItems()
        let existingActionTypes = Set(currentItems.map { normalizedActionType($0.actionType) })
        return VerticalSolidHomeExpandedActionRenderModel(
            currentItems: currentItems,
            visibleItems: visibleItems,
            candidateItems: candidateItems,
            actions: visibleItems.map(makeEmbeddedAction),
            actionsRevision: actionRevisionKey(for: visibleItems),
            addActions: candidateItems.map {
                makeAddEmbeddedAction($0, existingActionTypes: existingActionTypes)
            },
            addActionsRevision: actionRevisionKey(for: candidateItems)
        )
    }

    private func buildCurrentItems() -> [QuickActionItem] {
        if let pet = currentPet {
            return stableItems(
                ExpandedQuickActionStore.petItems(
                    raw: quickActionItemsRaw,
                    pet: pet,
                    localization: l,
                    waterLabel: l.homeQAWater,
                    managementLabel: waterManagementLabel
                ),
                entityID: pet.id,
                kind: .pet
            )
        }
        if let human = currentHuman {
            return stableItems(
                ExpandedQuickActionStore.humanItems(
                    raw: quickActionItemsRaw,
                    human: human,
                    localization: l
                ),
                entityID: human.id,
                kind: .human
            )
        }
        return fallbackItems
    }

    private func buildCandidateItems() -> [QuickActionItem] {
        guard isEditMode else { return [] }
        if let pet = currentPet {
            return stableItems(
                QuickActionPickerCatalog.options(for: pet).map { option in
                    QuickActionItem(
                        id: "\(EntityKind.pet.rawValue)-\(pet.id.uuidString)-\(option.id)",
                        label: option.label,
                        icon: option.icon,
                        colorHex: option.colorHex,
                        petId: pet.id,
                        actionType: option.id,
                        entityId: pet.id,
                        entityKind: .pet
                    )
                },
                entityID: pet.id,
                kind: .pet
            )
        }
        if let human = currentHuman {
            return stableItems(
                ExpandedQuickActionDefaults.humanItems(for: human, localization: l),
                entityID: human.id,
                kind: .human
            )
        }
        return []
    }

    private var currentPet: Pet? {
        guard !card.isHuman, !card.isElectronicPet else { return nil }
        return pets.first { $0.id == card.id && !$0.hasPassedAway }
    }

    private var currentHuman: Human? {
        guard card.isHuman else { return nil }
        return humans.first { $0.id == card.id }
    }

    private var waterManagementLabel: String {
        l.tr(zh: "管理", en: "Manage", de: "Verwalten")
    }

    private var fallbackItems: [QuickActionItem] {
        let entityID = card.id
        if card.isHuman {
            return [
                QuickActionItem(id: "human-\(entityID)-weight", label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA", actionType: "humanWeight", entityId: entityID, entityKind: .human),
                QuickActionItem(id: "human-\(entityID)-expense", label: l.expense, icon: "creditcard.fill", colorHex: "F59E0B", actionType: "humanExpense", entityId: entityID, entityKind: .human),
                QuickActionItem(id: "human-\(entityID)-medication", label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A", actionType: "humanMedication", entityId: entityID, entityKind: .human),
            ]
        }
        return [
            QuickActionItem(id: "pet-\(entityID)-feed", label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44", petId: entityID, actionType: "feed", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-water", label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA", petId: entityID, actionType: "water", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-play", label: l.homeQAPlay, icon: "tennisball.fill", colorHex: "FF6B6B", petId: entityID, actionType: "play", entityId: entityID, entityKind: .pet),
        ]
    }

    private func makeEmbeddedAction(_ item: QuickActionItem) -> VerticalHomeEmbeddedAction {
        let state = quickActionState(for: item)
        return VerticalHomeEmbeddedAction(
            id: item.id,
            title: item.label,
            icon: item.icon,
            statusText: state.status,
            isCompleted: state.isCompleted,
            showsAttention: state.showsAttention,
            isLocked: state.isLocked,
            primaryIcon: primaryIcon(for: item),
            isPrimaryDisabled: isPrimaryDisabled(item: item, state: state),
            detailIcon: detailIcon(for: item.actionType, isHuman: card.isHuman),
            menuOptions: menuOptions(for: item),
            quickAccessibilityLabel: item.label,
            detailAccessibilityLabel: l.tr(zh: "查看详情", en: "Details", de: "Details"),
            detailAction: { onAction(item, false) },
            optionAction: { optionId in onOptionAction(item, optionId) },
            action: { onAction(item, true) }
        )
    }

    private func makeAddEmbeddedAction(
        _ item: QuickActionItem,
        existingActionTypes: Set<String>
    ) -> VerticalHomeEmbeddedAction {
        let isAlreadyAdded = existingActionTypes.contains(normalizedActionType(item.actionType))
        return VerticalHomeEmbeddedAction(
            id: item.actionType,
            title: item.label,
            icon: item.icon,
            isCompleted: false,
            isAddDisabled: isAlreadyAdded,
            quickAccessibilityLabel: l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"),
            detailAccessibilityLabel: l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"),
            action: {}
        )
    }

    private func toggleEditMode() {
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
        jiggleTask?.cancel()
        jiggle = false
        jiggleTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 50) {
            guard !Task.isCancelled, isEditMode else { return }
            withAnimation(nil) {
                jiggle = true
            }
            jiggleTask = nil
        }
    }

    private func exitEditMode(persists: Bool = true) {
        if persists {
            persistItems(currentItemsForMutation())
        }
        jiggleTask?.cancel()
        jiggleTask = nil
        draggingItemId = nil
        jiggle = false
        withAnimation(GoMotion.selection) {
            isEditMode = false
        }
    }

    private func moveAction(fromId: String, toId: String) {
        var items = currentItemsForMutation()
        guard fromId != toId,
              let fromIndex = items.firstIndex(where: { $0.id == fromId }),
              let toIndex = items.firstIndex(where: { $0.id == toId }) else {
            return
        }

        withAnimation(GoMotion.selection) {
            let moved = items.remove(at: fromIndex)
            items.insert(moved, at: toIndex)
            persistItems(items)
        }
    }

    private func removeAction(_ id: String) {
        var items = currentItemsForMutation()
        guard items.count > 1,
              items.contains(where: { $0.id == id }) else {
            OhanaFeedback.warning()
            return
        }

        withAnimation(GoMotion.feedback) {
            items.removeAll { $0.id == id }
            persistItems(items)
        }
    }

    private func addAction(_ actionType: String) {
        var items = currentItemsForMutation()
        guard items.count < QuickActionLimit.maxItemsPerEntity else {
            onLimitReached()
            return
        }

        let normalizedType = normalizedActionType(actionType)
        let existingActionTypes = Set(items.map { normalizedActionType($0.actionType) })
        guard !existingActionTypes.contains(normalizedType),
              let item = renderModel.candidateItems.first(where: { normalizedActionType($0.actionType) == normalizedType }) else {
            return
        }
        withAnimation(GoMotion.feedback) {
            items.append(item)
            persistItems(items)
        }
    }

    private func normalizedActionType(_ actionType: String) -> String {
        WaterQuickActionPolicy.foldedActionTypes.contains(actionType) ? "water" : actionType
    }

    private func currentItemsForMutation() -> [QuickActionItem] {
        renderModel.currentItems.isEmpty ? buildCurrentItems() : renderModel.currentItems
    }

    private func stableItems(_ items: [QuickActionItem], entityID: UUID, kind: EntityKind) -> [QuickActionItem] {
        items.map { item in
            var stableItem = item
            stableItem.id = "\(kind.rawValue)-\(entityID.uuidString)-\(item.actionType)"
            return stableItem
        }
    }

    private func actionRevisionKey(for items: [QuickActionItem]) -> String {
        items.map(\.id).joined(separator: "|")
    }

    private func quickActionState(for item: QuickActionItem) -> QuickActionRenderState {
        if let pet = currentPet {
            let now = Date()
            return QuickActionRenderState(
                status: ExpandedQuickActionLogic.countText(
                    item: item,
                    pet: pet,
                    allEvents: allEvents,
                    allFeedCareLogs: pet.careLogs,
                    now: now
                ),
                isCompleted: ExpandedQuickActionLogic.isCompleted(
                    item: item,
                    pet: pet,
                    allEvents: allEvents,
                    allFeedCareLogs: pet.careLogs,
                    now: now
                ),
                showsAttention: ExpandedQuickActionLogic.showsAttentionDot(
                    item: item,
                    pet: pet,
                    allEvents: allEvents,
                    allFeedCareLogs: pet.careLogs,
                    now: now
                ),
                isLocked: false
            )
        }

        if let human = currentHuman {
            let viewedBy = activeHumanID
            let isLocked = ExpandedHumanQuickActionStateProvider.isPrivate(item, human: human, viewedBy: viewedBy)
            let medicationWarning = item.actionType == "humanMedication"
                ? CarePlanOverdueStatusCalculator.humanMedicationWarning(
                    for: human,
                    medications: humanMedications,
                    logs: humanMedicationLogs
                )
                : nil
            let status = medicationWarning?.compactText ?? humanStatusText(for: item, human: human, viewedBy: viewedBy)
            return QuickActionRenderState(
                status: status,
                isCompleted: ExpandedHumanQuickActionStateProvider.completed(
                    item: item,
                    human: human,
                    viewedBy: viewedBy,
                    todayMedicationLogs: humanMedicationLogs
                ),
                showsAttention: medicationWarning != nil,
                isLocked: isLocked
            )
        }

        return QuickActionRenderState(status: nil, isCompleted: false, showsAttention: false, isLocked: false)
    }

    private func humanStatusText(for item: QuickActionItem, human: Human, viewedBy: UUID?) -> String? {
        return ExpandedHumanQuickActionStateProvider.countText(
            item: item,
            human: human,
            viewedBy: viewedBy,
            activeMedications: humanMedications,
            todayMedicationLogs: humanMedicationLogs,
            recentExpenses: expenseLogs
        )
    }

    private func primaryIcon(for item: QuickActionItem) -> String {
        switch item.actionType {
        case "walk": return "figure.walk"
        case "medication", "humanMedication": return "plus"
        case "weight", "expense", "moment", "humanWeight", "humanWorkout", "humanNote", "humanExpense":
            return "square.and.pencil"
        case "water", "waterChange", "filterClean":
            return "drop.fill"
        case "health":
            return "cross.fill"
        default:
            return "bolt.fill"
        }
    }

    private func isPrimaryDisabled(item: QuickActionItem, state: QuickActionRenderState) -> Bool {
        ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil && state.isCompleted
    }

    private func menuOptions(for item: QuickActionItem) -> [VerticalHomeEmbeddedActionOption] {
        switch item.actionType {
        case "groom":
            return [
                VerticalHomeEmbeddedActionOption(id: "bath", icon: "drop.fill", title: l.tr(zh: "洗澡", en: "Bath", de: "Bad"), tint: Color.goBlue),
                VerticalHomeEmbeddedActionOption(id: "teeth", icon: "mouth.fill", title: l.tr(zh: "刷牙", en: "Teeth", de: "Zähne"), tint: Color.goTeal),
                VerticalHomeEmbeddedActionOption(id: "nails", icon: "scissors", title: l.tr(zh: "剪甲", en: "Nails", de: "Krallen"), tint: Color.goPurple),
                VerticalHomeEmbeddedActionOption(id: "brushing", icon: "comb.fill", title: l.tr(zh: "梳毛", en: "Brush", de: "Bürsten"), tint: Color.goYellow),
                VerticalHomeEmbeddedActionOption(id: "ears", icon: "ear.fill", title: l.tr(zh: "清耳", en: "Ears", de: "Ohren"), tint: Color.goOrange)
            ]
        case "potty":
            return [
                VerticalHomeEmbeddedActionOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill", title: l.tr(zh: "完美", en: "Good", de: "Gut"), tint: Color.goYellow),
                VerticalHomeEmbeddedActionOption(id: PottyType.softPoop.rawValue, icon: "circle.dashed", title: l.tr(zh: "软便", en: "Soft", de: "Weich"), tint: Color.goYellow),
                VerticalHomeEmbeddedActionOption(id: PottyType.liquidPoop.rawValue, icon: "exclamationmark.triangle.fill", title: l.tr(zh: "水便", en: "Loose", de: "Flüssig"), tint: Color.goRed),
                VerticalHomeEmbeddedActionOption(id: PottyType.pee.rawValue, icon: "drop.fill", title: l.tr(zh: "尿尿", en: "Pee", de: "Pipi"), tint: Color.goBlue)
            ]
        case "health":
            return [
                VerticalHomeEmbeddedActionOption(id: "vaccine", icon: "syringe.fill", title: l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung"), tint: Color.goTeal),
                VerticalHomeEmbeddedActionOption(id: "deworming", icon: "shield.lefthalf.filled", title: l.tr(zh: "驱虫", en: "Deworm", de: "Entwurmen"), tint: Color.goPurple),
                VerticalHomeEmbeddedActionOption(id: "visit", icon: "stethoscope", title: l.tr(zh: "体检", en: "Visit", de: "Besuch"), tint: Color.goBlue)
            ]
        default:
            return []
        }
    }

    private func normalizeStoredItemsIfNeeded(using model: VerticalSolidHomeExpandedActionRenderModel) {
        guard !model.currentItems.isEmpty else { return }
        let stableIds = model.currentItems.map(\.id).joined(separator: "|")
        let rawIds = model.visibleItems.map(\.id).joined(separator: "|")
        guard stableIds != rawIds else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            persistItems(model.currentItems)
        }
    }

    private func persistItems(_ items: [QuickActionItem]) {
        if let pet = currentPet {
            quickActionItemsRaw = ExpandedQuickActionStore.savingPetItems(
                stableItems(items, entityID: pet.id, kind: .pet),
                pet: pet,
                currentItems: currentItemsForMutation(),
                raw: quickActionItemsRaw
            )
            return
        }
        if let human = currentHuman {
            quickActionItemsRaw = ExpandedQuickActionStore.savingHumanItems(
                stableItems(items, entityID: human.id, kind: .human),
                human: human,
                currentItems: currentItemsForMutation(),
                raw: quickActionItemsRaw
            )
        }
    }

    private func detailIcon(for actionType: String, isHuman: Bool) -> String {
        if actionType.contains("medication") { return "list.bullet.rectangle.fill" }
        if actionType.contains("note") || actionType == "moment" { return "sparkles" }
        if actionType.contains("expense") { return "creditcard.fill" }
        if actionType.contains("weight") { return "chart.line.uptrend.xyaxis" }
        if isHuman { return "rectangle.stack.fill" }
        return "chart.line.uptrend.xyaxis"
    }

    private struct QuickActionRenderState {
        let status: String?
        let isCompleted: Bool
        let showsAttention: Bool
        let isLocked: Bool
    }
}

private struct VerticalSolidHomeExpandedActionRenderModel {
    var currentItems: [QuickActionItem]
    var visibleItems: [QuickActionItem]
    var candidateItems: [QuickActionItem]
    var actions: [VerticalHomeEmbeddedAction]
    var actionsRevision: String
    var addActions: [VerticalHomeEmbeddedAction]
    var addActionsRevision: String

    static let empty = VerticalSolidHomeExpandedActionRenderModel(
        currentItems: [],
        visibleItems: [],
        candidateItems: [],
        actions: [],
        actionsRevision: "",
        addActions: [],
        addActionsRevision: ""
    )
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
    private var l: L10n { localization }

    var body: some View {
        let barBottomInset = max(safeBottom - 2, 4)
        let centerBottomInset = max(safeBottom + 4, 12)

        ZStack(alignment: .bottom) {
            menuRows
                .padding(.bottom, safeBottom + 90)

            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.calendar)
                Spacer(minLength: 72)
                tabButton(.oasis)
                tabButton(.plants)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(navBackground)
            .padding(.horizontal, 16)
            .padding(.bottom, barBottomInset)

            Button {
                OhanaFeedback.medium()
                if usesFabMenu {
                    toggleFab()
                    return
                }
                onCenter()
            } label: {
                Image(systemName: centerIcon)
                    .font(.system(size: 24, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 64, height: 64)
                    .background(Color.goPrimary, in: Circle())
                    .shadow(color: Color.goPrimary.opacity(0.26), radius: 16, x: 0, y: 8) // ui-v4: allow elevated primary nav action
                    .rotationEffect(.degrees(isFabExpanded ? 90 : 0))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, centerBottomInset)
            .accessibilityLabel(centerButtonAccessibilityLabel)
        }
        .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: selectedTab)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: isFabExpanded)
        .animation(canAnimate ? HeroAnim.fabSpring : GoMotion.reduced, value: itemsVisible)
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
            .fill(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.42 : 0.72))
            .overlay {
                Capsule()
                    .strokeBorder(Color.ohanaGlassStroke.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color.arkInk.opacity(0.18), radius: 20, x: 0, y: 10) // ui-v4: allow home bottom navigation lift
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

private struct VerticalSolidHomeFabShortcutButton: View {
    let shortcut: ExpandedCardFabShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.goPrimary.opacity(shortcut.isAvailable ? 1 : 0.36))
                        .frame(width: 42, height: 42)
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54)
                    )
                    .frame(width: 42, height: 42)

                    if let badge = shortcut.badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black, design: .rounded))
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
                    .font(.system(size: 9, weight: .black, design: .rounded))
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
                        .frame(width: 42, height: 42)
                    OhanaQuickActionIcon(
                        actionType: iconActionType,
                        fallbackSystemName: shortcut.icon,
                        size: 24,
                        color: Color.ohanaPrimaryActionText.opacity(shortcut.isAvailable ? 1 : 0.54),
                        animatesStateChanges: false
                    )
                        .frame(width: 42, height: 42)

                    if let badge = shortcut.badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black, design: .rounded))
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
                    .font(.system(size: 9, weight: .black, design: .rounded))
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
