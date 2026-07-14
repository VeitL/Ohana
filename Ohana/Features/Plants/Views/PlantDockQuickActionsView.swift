//
//  PlantDockQuickActionsView.swift
//  Ohana
//
//  Shared editable dock for plant quick actions.
//

import SwiftUI

struct PlantDockQuickActionsView: View {
    let plantID: UUID
    let plantName: String
    let dueCareTypes: Set<PlantCareType>
    var overdueCareTypes: Set<PlantCareType> = []
    var pendingCareTypes: Set<PlantCareType> = []
    var completedCareTypes: Set<PlantCareType> = []
    var failedCareTypes: Set<PlantCareType> = []
    let localization: L10n
    @Binding var quickActionItemsRaw: String
    var shouldReduceWork = false
    var accentColor: Color = .goTeal
    var forcesSubmenusBelow = false
    var onLimitReached: () -> Void = {
        OhanaFeedback.warning()
    }
    let onAction: (PlantDockQuickAction) -> Void
    let onDetail: (PlantDockQuickAction) -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isEditMode = false
    @State private var jiggle = false
    @State private var draggingItemId: String?
    @State private var renderModel = PlantDockQuickActionsRenderModel.empty
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
            shouldReduceWork: shouldReduceWork || workloadPolicy.interactionMotionBudget(isVisible: true) != .full,
            accentColor: accentColor,
            forcesSubmenusBelow: forcesSubmenusBelow,
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
            plantID.uuidString,
            quickActionItemsRaw,
            localization.languageCode,
            dueCareTypes.map(\.rawValue).sorted().joined(separator: ","),
            overdueCareTypes.map(\.rawValue).sorted().joined(separator: ","),
            pendingCareTypes.map(\.rawValue).sorted().joined(separator: ","),
            completedCareTypes.map(\.rawValue).sorted().joined(separator: ","),
            failedCareTypes.map(\.rawValue).sorted().joined(separator: ",")
        ].joined(separator: "|")
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

    private func buildRenderModel() -> PlantDockQuickActionsRenderModel {
        let currentItems = stableItems(
            ExpandedQuickActionStore.plantItems(raw: quickActionItemsRaw, plantID: plantID, localization: l)
        )
        let visibleItems = Array(currentItems.prefix(PlantDockQuickAction.maxVisibleItems))
        let candidateItems = isEditMode && visibleItems.count < PlantDockQuickAction.maxVisibleItems
            ? stableItems(ExpandedQuickActionStore.plantCandidateItems(plantID: plantID, localization: l))
            : []
        let existingActionTypes = Set(currentItems.map(\.actionType))
        return PlantDockQuickActionsRenderModel(
            currentItems: currentItems,
            candidateItems: candidateItems,
            actions: visibleItems.compactMap(makeEmbeddedAction),
            actionsRevision: actionRevisionKey(for: visibleItems),
            addActions: candidateItems.map {
                makeAddEmbeddedAction($0, existingActionTypes: existingActionTypes)
            },
            addActionsRevision: actionRevisionKey(for: candidateItems)
        )
    }

    private func makeEmbeddedAction(_ item: QuickActionItem) -> VerticalHomeEmbeddedAction? {
        guard let dockAction = PlantDockQuickAction(actionType: item.actionType) else { return nil }
        let isDue = dockAction.careType.map { dueCareTypes.contains($0) } ?? false
        let isOverdue = dockAction.careType.map { overdueCareTypes.contains($0) } ?? false
        let isPending = dockAction.careType.map { pendingCareTypes.contains($0) } ?? false
        let didComplete = dockAction.careType.map { completedCareTypes.contains($0) } ?? false
        let didFail = dockAction.careType.map { failedCareTypes.contains($0) } ?? false
        return VerticalHomeEmbeddedAction(
            id: item.id,
            title: item.label,
            icon: item.icon,
            actionType: item.actionType,
            statusText: statusText(for: dockAction, isDue: isDue, isPending: isPending, didComplete: didComplete, didFail: didFail),
            isInProgress: isPending,
            isCompleted: didComplete,
            showsAttention: (isDue || didFail) && !didComplete && !isPending,
            attentionLevel: attentionLevel(isDue: isDue, isOverdue: isOverdue, didFail: didFail, didComplete: didComplete, isPending: isPending),
            primaryIcon: isPending ? "hourglass" : dockAction.primaryIcon,
            isPrimaryDisabled: isPending,
            detailIcon: dockAction.detailIcon,
            showsMenu: dockAction.careType != nil,
            showsQuickButton: dockAction.careType != nil,
            quickAccessibilityLabel: quickAccessibilityLabel(for: dockAction),
            detailAccessibilityLabel: detailAccessibilityLabel(for: dockAction),
            detailAction: isPending ? nil : { onDetail(dockAction) },
            action: isPending ? {} : { onAction(dockAction) }
        )
    }

    private func makeAddEmbeddedAction(
        _ item: QuickActionItem,
        existingActionTypes: Set<String>
    ) -> VerticalHomeEmbeddedAction {
        let isAlreadyAdded = existingActionTypes.contains(item.actionType)
        return VerticalHomeEmbeddedAction(
            id: item.actionType,
            title: item.label,
            icon: item.icon,
            actionType: item.actionType,
            statusText: PlantDockQuickAction(actionType: item.actionType)?
                .careCategory?
                .shortTitle(l: l),
            isCompleted: false,
            isAddDisabled: isAlreadyAdded,
            quickAccessibilityLabel: l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"),
            detailAccessibilityLabel: l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"),
            action: {}
        )
    }

    private func toggleEditMode() {
        isEditMode ? exitEditMode() : enterEditMode()
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
        guard items.count < PlantDockQuickAction.maxVisibleItems else {
            onLimitReached()
            return
        }
        guard !items.contains(where: { $0.actionType == actionType }),
              let item = renderModel.candidateItems.first(where: { $0.actionType == actionType }) else {
            return
        }
        withAnimation(GoMotion.feedback) {
            items.append(item)
            persistItems(items)
        }
    }

    private func currentItemsForMutation() -> [QuickActionItem] {
        renderModel.currentItems.isEmpty
            ? stableItems(ExpandedQuickActionStore.plantItems(raw: quickActionItemsRaw, plantID: plantID, localization: l))
            : renderModel.currentItems
    }

    private func persistItems(_ items: [QuickActionItem]) {
        let stable = stableItems(items)
        quickActionItemsRaw = ExpandedQuickActionStore.savingPlantItems(
            stable,
            plantID: plantID,
            currentItems: currentItemsForMutation(),
            raw: quickActionItemsRaw
        )
    }

    private func stableItems(_ items: [QuickActionItem]) -> [QuickActionItem] {
        items.compactMap { item in
            guard PlantDockQuickAction(actionType: item.actionType) != nil else { return nil }
            var stable = item
            stable.id = "plant-\(plantID.uuidString)-\(item.actionType)"
            stable.entityId = plantID
            stable.entityKind = .plant
            stable.petId = nil
            return stable
        }
    }

    private func statusText(
        for action: PlantDockQuickAction,
        isDue: Bool,
        isPending: Bool,
        didComplete: Bool,
        didFail: Bool
    ) -> String {
        if isPending {
            return l.tr(zh: "记录中", en: "Logging", de: "Erfasst")
        }
        if didComplete {
            return l.tr(zh: "已记录", en: "Logged", de: "Erfasst")
        }
        if didFail {
            return l.tr(zh: "未记录", en: "Not logged", de: "Nicht erfasst")
        }
        if isDue {
            return l.tr(zh: "待打卡", en: "Due", de: "Fällig")
        }
        switch action {
        case .detail:
            return l.tr(zh: "资料页", en: "Profile", de: "Profil")
        case .photo:
            return l.tr(zh: "照片记录", en: "Photo log", de: "Fotoeintrag")
        case .note:
            return l.tr(zh: "备注/观察", en: "Note", de: "Notiz")
        default:
            return l.tr(zh: "快速记录", en: "Quick log", de: "Schnell erfassen")
        }
    }

    private func attentionLevel(
        isDue: Bool,
        isOverdue: Bool,
        didFail: Bool,
        didComplete: Bool,
        isPending: Bool
    ) -> HomeQuickActionAttentionLevel {
        guard !didComplete, !isPending else { return .none }
        if didFail || isOverdue {
            return .urgent
        }
        return isDue ? .due : .none
    }

    private func quickAccessibilityLabel(for action: PlantDockQuickAction) -> String {
        if action == .detail {
            return l.tr(zh: "打开\(plantName)详情", en: "Open details for \(plantName)", de: "Details für \(plantName) öffnen")
        }
        return l.tr(zh: "记录\(plantName)\(action.title(l: l))", en: "Log \(action.title(l: l)) for \(plantName)", de: "\(action.title(l: l)) für \(plantName) erfassen")
    }

    private func detailAccessibilityLabel(for action: PlantDockQuickAction) -> String {
        if action == .detail {
            return quickAccessibilityLabel(for: action)
        }
        return l.tr(zh: "打开\(plantName)\(action.title(l: l))详情", en: "Open \(action.title(l: l)) details for \(plantName)", de: "\(action.title(l: l))-Details für \(plantName) öffnen")
    }

    private func actionRevisionKey(for items: [QuickActionItem]) -> String {
        items.map(\.id).joined(separator: "|")
    }
}

private struct PlantDockQuickActionsRenderModel {
    var currentItems: [QuickActionItem]
    var candidateItems: [QuickActionItem]
    var actions: [VerticalHomeEmbeddedAction]
    var actionsRevision: String
    var addActions: [VerticalHomeEmbeddedAction]
    var addActionsRevision: String

    static let empty = PlantDockQuickActionsRenderModel(
        currentItems: [],
        candidateItems: [],
        actions: [],
        actionsRevision: "",
        addActions: [],
        addActionsRevision: ""
    )
}
