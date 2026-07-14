//
//  VerticalSolidHomeExpandedCardActions.swift
//  Ohana
//
//  Expanded quick-action render model and editor for verticalSolid home cards.
//

import SwiftUI

struct VerticalSolidHomeExpandedCardActions: View {
    let card: FocusCard
    let actionSnapshot: HomeExpandedActionSnapshot
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
            accentColor: Color(hex: card.themeColorHex),
            forcesSubmenusBelow: false,
            draggingItemId: $draggingItemId,
            onToggleEdit: toggleEditMode,
            onMove: moveAction,
            onRemove: removeAction,
            onAdd: addAction
        )
        .onAppear {
            primeRenderModelIfNeeded()
            scheduleRenderModelRefresh()
        }
        .onChange(of: card.id) { _, _ in
            exitEditMode(persists: false)
            scheduleRenderModelRefresh()
        }
        .onChange(of: renderRefreshKey) { _, _ in
            scheduleRenderModelRefresh()
        }
        .onChange(of: isEditMode) { _, _ in
            scheduleRenderModelRefresh()
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
            actionSnapshotRevisionKey,
            card.homePrimaryMetricValue,
            card.statusBadgeText ?? ""
        ].joined(separator: "|")
    }

    private var actionSnapshotRevisionKey: String {
        let items = actionSnapshot.currentItems.map { "\($0.id):\($0.actionType)" }.joined(separator: ",")
        let candidates = actionSnapshot.candidateItems.map(\.id).joined(separator: ",")
        let states = actionSnapshot.statesByActionType
            .sorted { $0.key < $1.key }
            .map { key, state in
                [
                    key,
                    state.status ?? "",
                    "\(state.isCompleted)",
                    "\(state.showsAttention)",
                    "\(state.isLocked)",
                    "\(state.menuPolicy.showsMenu)",
                    "\(state.menuPolicy.showsQuickButton)"
                ].joined(separator: ":")
            }
            .joined(separator: ";")
        return [items, candidates, states].joined(separator: "|")
    }

    private func primeRenderModelIfNeeded() {
        guard renderModel.actions.isEmpty, renderModel.addActions.isEmpty else { return }
        withTransaction(Transaction(animation: nil)) {
            renderModel = buildRenderModel()
        }
    }

    private func scheduleRenderModelRefresh() {
        renderModelTask?.cancel()
        renderModelTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            let nextModel = buildRenderModel()
            guard !Task.isCancelled else { return }
            withTransaction(Transaction(animation: nil)) {
                renderModel = nextModel
            }
            renderModelTask = nil
        }
    }

    private func buildRenderModel() -> VerticalSolidHomeExpandedActionRenderModel {
        let currentItems = buildCurrentItems()
        let visibleItems = Array(currentItems.prefix(QuickActionLimit.maxItemsPerEntity))
        let candidateItems = isEditMode ? buildCandidateItems() : []
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
        actionSnapshot.currentItems.isEmpty ? fallbackItems : actionSnapshot.currentItems
    }

    private func buildCandidateItems() -> [QuickActionItem] {
        actionSnapshot.candidateItems
    }

    private var fallbackItems: [QuickActionItem] {
        let entityID = card.id
        if card.isHuman {
            return [
                QuickActionItem(id: "human-\(entityID)-weight", label: l.homeQAWeight, icon: "scalemass.fill", colorHex: "80FFEA", actionType: "humanWeight", entityId: entityID, entityKind: .human),
                QuickActionItem(id: "human-\(entityID)-expense", label: l.expense, icon: "creditcard.fill", colorHex: "F59E0B", actionType: "humanExpense", entityId: entityID, entityKind: .human),
                QuickActionItem(id: "human-\(entityID)-medication", label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A", actionType: "humanMedication", entityId: entityID, entityKind: .human)
            ]
        }
        return [
            QuickActionItem(id: "pet-\(entityID)-feed", label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44", petId: entityID, actionType: "feed", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-water", label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA", petId: entityID, actionType: "water", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-play", label: l.homeQAPlay, icon: "tennisball.fill", colorHex: "FF6B6B", petId: entityID, actionType: "play", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-allFeatures", label: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "square.grid.2x2.fill", colorHex: "5B6AFF", petId: entityID, actionType: "allFeatures", entityId: entityID, entityKind: .pet)
        ]
    }

    private func makeEmbeddedAction(_ item: QuickActionItem) -> VerticalHomeEmbeddedAction {
        let state = actionSnapshot.state(for: item)
        let options = menuOptions(for: item)
        let menuPolicy = state.isLocked ? .none : state.menuPolicy.expandedPolicy
        let actionUsesQuickPath = menuPolicy.showsQuickButton
        let title = item.displayLabel(localization: l)
        return VerticalHomeEmbeddedAction(
            id: item.id,
            title: title,
            icon: item.icon,
            actionType: item.actionType,
            statusText: state.status,
            isCompleted: state.isCompleted,
            showsAttention: state.showsAttention,
            attentionLevel: state.attentionLevel,
            isLocked: state.isLocked,
            primaryIcon: primaryIcon(for: item),
            isPrimaryDisabled: isPrimaryDisabled(item: item, state: state),
            detailIcon: detailIcon(for: item.actionType, isHuman: card.isHuman),
            menuOptions: options,
            showsMenu: menuPolicy.showsMenu,
            showsQuickButton: menuPolicy.showsQuickButton,
            quickAccessibilityLabel: title,
            detailAccessibilityLabel: l.tr(zh: "查看详情", en: "Details", de: "Details"),
            detailAction: { onAction(item, false) },
            optionAction: { optionId in onOptionAction(item, optionId) },
            action: { onAction(item, actionUsesQuickPath) }
        )
    }

    private func makeAddEmbeddedAction(
        _ item: QuickActionItem,
        existingActionTypes: Set<String>
    ) -> VerticalHomeEmbeddedAction {
        let isAlreadyAdded = existingActionTypes.contains(normalizedActionType(item.actionType))
        let title = item.displayLabel(localization: l)
        return VerticalHomeEmbeddedAction(
            id: item.actionType,
            title: title,
            icon: item.icon,
            actionType: item.actionType,
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

    private func persistItems(_ items: [QuickActionItem]) {
        let kind: EntityKind = card.isHuman ? .human : .pet
        let stable = stableItems(items, entityID: card.id, kind: kind)
        if card.isHuman {
            quickActionItemsRaw = ExpandedQuickActionStore.savingHumanItems(
                stable,
                humanID: card.id,
                currentItems: currentItemsForMutation(),
                raw: quickActionItemsRaw
            )
        } else {
            quickActionItemsRaw = ExpandedQuickActionStore.savingPetItems(
                stable,
                petID: card.id,
                currentItems: currentItemsForMutation(),
                raw: quickActionItemsRaw
            )
        }
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

    private func primaryIcon(for item: QuickActionItem) -> String {
        switch item.actionType {
        case "walk": "figure.walk"
        case "medication", "humanMedication": "plus"
        case "weight", "expense", "moment", "humanWeight", "humanWorkout", "humanNote", "humanExpense":
            "square.and.pencil"
        case "water", "waterChange", "filterClean":
            "drop.fill"
        case "health":
            "cross.fill"
        default:
            "bolt.fill"
        }
    }

    private func isPrimaryDisabled(item: QuickActionItem, state: HomeQuickActionRenderSnapshot) -> Bool {
        ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil && state.isCompleted
    }

    private func menuOptions(for item: QuickActionItem) -> [VerticalHomeEmbeddedActionOption] {
        switch item.actionType {
        case "groom":
            [
                VerticalHomeEmbeddedActionOption(id: "bath", icon: "drop.fill", title: l.tr(zh: "洗澡", en: "Bath", de: "Bad"), tint: Color.goBlue),
                VerticalHomeEmbeddedActionOption(id: "teeth", icon: "mouth.fill", title: l.tr(zh: "刷牙", en: "Teeth", de: "Zähne"), tint: Color.goTeal),
                VerticalHomeEmbeddedActionOption(id: "nails", icon: "scissors", title: l.tr(zh: "剪甲", en: "Nails", de: "Krallen"), tint: Color.goPurple),
                VerticalHomeEmbeddedActionOption(id: "brushing", icon: "comb.fill", title: l.tr(zh: "梳毛", en: "Brush", de: "Bürsten"), tint: Color.goYellow),
                VerticalHomeEmbeddedActionOption(id: "ears", icon: "ear.fill", title: l.tr(zh: "清耳", en: "Ears", de: "Ohren"), tint: Color.goOrange)
            ]
        case "potty":
            [
                VerticalHomeEmbeddedActionOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill", title: l.tr(zh: "完美", en: "Good", de: "Gut"), tint: Color.goYellow),
                VerticalHomeEmbeddedActionOption(id: PottyType.softPoop.rawValue, icon: "circle.dashed", title: l.tr(zh: "软便", en: "Soft", de: "Weich"), tint: Color.goYellow),
                VerticalHomeEmbeddedActionOption(id: PottyType.liquidPoop.rawValue, icon: "exclamationmark.triangle.fill", title: l.tr(zh: "水便", en: "Loose", de: "Flüssig"), tint: Color.goRed),
                VerticalHomeEmbeddedActionOption(id: PottyType.pee.rawValue, icon: "drop.fill", title: l.tr(zh: "尿尿", en: "Pee", de: "Pipi"), tint: Color.goBlue)
            ]
        case "health":
            [
                VerticalHomeEmbeddedActionOption(id: "vaccine", icon: "syringe.fill", title: l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung"), tint: Color.goTeal),
                VerticalHomeEmbeddedActionOption(id: "deworming", icon: "shield.lefthalf.filled", title: l.tr(zh: "驱虫", en: "Deworm", de: "Entwurmen"), tint: Color.goPurple),
                VerticalHomeEmbeddedActionOption(id: "visit", icon: "stethoscope", title: l.tr(zh: "体检", en: "Visit", de: "Besuch"), tint: Color.goBlue)
            ]
        default:
            []
        }
    }

    private func detailIcon(for actionType: String, isHuman: Bool) -> String {
        let normalized = actionType.lowercased()
        if normalized.contains("medication") { return "list.bullet.rectangle.fill" }
        if normalized.contains("note") || normalized == "moment" { return "sparkles" }
        if normalized.contains("expense") { return "creditcard.fill" }
        if ["water", "waterchange", "filterclean"].contains(normalized) { return "drop.circle.fill" }
        if normalized.contains("weight") { return "chart.line.uptrend.xyaxis" }
        if isHuman { return "rectangle.stack.fill" }
        return "chart.line.uptrend.xyaxis"
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
