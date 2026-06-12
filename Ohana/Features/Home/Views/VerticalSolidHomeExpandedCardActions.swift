//
//  VerticalSolidHomeExpandedCardActions.swift
//  Ohana
//
//  Expanded quick-action render model and editor for verticalSolid home cards.
//

import SwiftUI

struct VerticalSolidHomeExpandedCardActions: View {
    let card: FocusCard
    let pets: [Pet]
    let humans: [Human]
    let allEvents: [Event]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let feedingLedgerEntries: [HomeFeedQuickActionEntry]
    let careLedgerEntries: [HomeCareQuickActionEntry]
    let hygieneLedgerEntries: [HomeHygieneQuickActionEntry]
    let walkLedgerEntries: [HomeWalkQuickActionEntry]
    let pottyLedgerEntries: [HomePottyQuickActionEntry]
    let petExpenseLedgerEntries: [HomePetExpenseQuickActionEntry]
    let petWeightLedgerEntries: [HomePetWeightQuickActionEntry]
    let expenseEntries: [HomeExpensePreviewEntry]
    let localization: L10n
    let activeHumanID: UUID?
    @Binding var quickActionItemsRaw: String
    let onAction: (QuickActionItem, Bool) -> Void
    let onOptionAction: (QuickActionItem, String) -> Void
    let onLimitReached: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppServices.self) private var appServices
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isEditMode = false
    @State private var jiggle = false
    @State private var draggingItemId: String?
    @State private var renderModel = VerticalSolidHomeExpandedActionRenderModel.empty
    @State private var renderModelTask: Task<Void, Never>?
    @State private var jiggleTask: Task<Void, Never>?
    @State private var observedHomeRevision = HomeRevision()
    @State private var currentDayToken = HomeReadModelRefreshKey.dayToken(for: Date())

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
            forcesSubmenusBelow: false,
            draggingItemId: $draggingItemId,
            onToggleEdit: toggleEditMode,
            onMove: moveAction,
            onRemove: removeAction,
            onAdd: addAction
        )
        .onAppear {
            observedHomeRevision = appServices.domainRevisions.homeRevision
            currentDayToken = HomeReadModelRefreshKey.dayToken(for: Date())
            scheduleRenderModelRefresh(normalizesStoredItems: true)
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { revision in
            observedHomeRevision = revision
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            currentDayToken = HomeReadModelRefreshKey.dayToken(for: Date())
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
            "\(observedHomeRevision.value)",
            "\(currentDayToken)",
            "\(allEvents.count)",
            "\(humanMedications.count)",
            "\(humanMedicationLogs.count)",
            feedingLedgerRevisionKey,
            careLedgerRevisionKey,
            hygieneLedgerRevisionKey,
            walkLedgerRevisionKey,
            pottyLedgerRevisionKey,
            petExpenseLedgerRevisionKey,
            petWeightLedgerRevisionKey,
            "\(expenseEntries.count)",
            card.homePrimaryMetricValue,
            card.statusBadgeText ?? ""
        ].joined(separator: "|")
    }

    private var feedingLedgerRevisionKey: String {
        feedingLedgerEntries.prefix(120).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.source.rawValue,
                "\(Int(entry.date.timeIntervalSince1970))"
            ].joined(separator: ":")
        }.joined(separator: ";")
    }

    private var careLedgerRevisionKey: String {
        careLedgerEntries.prefix(180).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.actionType,
                "\(Int(entry.date.timeIntervalSince1970))",
                "\(Int(entry.amountValue.rounded()))"
            ].joined(separator: ":")
        }.joined(separator: ";")
    }

    private var hygieneLedgerRevisionKey: String {
        hygieneLedgerEntries.prefix(160).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.hygieneType.rawValue,
                "\(Int(entry.date.timeIntervalSince1970))"
            ].joined(separator: ":")
        }.joined(separator: ";")
    }

    private var walkLedgerRevisionKey: String {
        walkLedgerEntries.prefix(80).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                "\(Int(entry.startDate.timeIntervalSince1970))",
                "\(Int(entry.distanceMeters.rounded()))"
            ].joined(separator: ":")
        }.joined(separator: ";")
    }

    private var pottyLedgerRevisionKey: String {
        pottyLedgerEntries.prefix(120).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.pottyType.rawValue,
                "\(Int(entry.date.timeIntervalSince1970))"
            ].joined(separator: ":")
        }.joined(separator: ";")
    }

    private var petExpenseLedgerRevisionKey: String {
        petExpenseLedgerEntries.prefix(160).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                "\(Int(entry.date.timeIntervalSince1970))",
                "\(Int(entry.amount.rounded()))"
            ].joined(separator: ":")
        }.joined(separator: ";")
    }

    private var petWeightLedgerRevisionKey: String {
        petWeightLedgerEntries.prefix(160).map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                "\(Int(entry.date.timeIntervalSince1970))",
                "\(Int((entry.weightKg * 1000).rounded()))"
            ].joined(separator: ":")
        }.joined(separator: ";")
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
                QuickActionItem(id: "human-\(entityID)-medication", label: l.homeQAMeds, icon: "pill.fill", colorHex: "FF6B8A", actionType: "humanMedication", entityId: entityID, entityKind: .human)
            ]
        }
        return [
            QuickActionItem(id: "pet-\(entityID)-feed", label: l.homeQAFeed, icon: "fork.knife", colorHex: "FFDD44", petId: entityID, actionType: "feed", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-water", label: l.homeQAWater, icon: "drop.fill", colorHex: "00D4AA", petId: entityID, actionType: "water", entityId: entityID, entityKind: .pet),
            QuickActionItem(id: "pet-\(entityID)-play", label: l.homeQAPlay, icon: "tennisball.fill", colorHex: "FF6B6B", petId: entityID, actionType: "play", entityId: entityID, entityKind: .pet)
        ]
    }

    private func makeEmbeddedAction(_ item: QuickActionItem) -> VerticalHomeEmbeddedAction {
        let state = quickActionState(for: item)
        let options = menuOptions(for: item)
        let menuPolicy = state.isLocked ? .none : embeddedMenuPolicy(for: item, options: options)
        let directActionUsesQuickPath = menuPolicy.showsQuickButton
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
            menuOptions: options,
            showsMenu: menuPolicy.showsMenu,
            showsQuickButton: menuPolicy.showsQuickButton,
            quickAccessibilityLabel: item.label,
            detailAccessibilityLabel: l.tr(zh: "查看详情", en: "Details", de: "Details"),
            detailAction: { onAction(item, false) },
            optionAction: { optionId in onOptionAction(item, optionId) },
            action: { onAction(item, directActionUsesQuickPath) }
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
                    feedingLedgerEntries: feedingLedgerEntries,
                    careLedgerEntries: careLedgerEntries,
                    hygieneLedgerEntries: hygieneLedgerEntries,
                    walkLedgerEntries: walkLedgerEntries,
                    pottyLedgerEntries: pottyLedgerEntries,
                    petExpenseLedgerEntries: petExpenseLedgerEntries,
                    petWeightLedgerEntries: petWeightLedgerEntries,
                    now: now
                ),
                isCompleted: ExpandedQuickActionLogic.isCompleted(
                    item: item,
                    pet: pet,
                    allEvents: allEvents,
                    feedingLedgerEntries: feedingLedgerEntries,
                    careLedgerEntries: careLedgerEntries,
                    hygieneLedgerEntries: hygieneLedgerEntries,
                    walkLedgerEntries: walkLedgerEntries,
                    pottyLedgerEntries: pottyLedgerEntries,
                    petWeightLedgerEntries: petWeightLedgerEntries,
                    now: now
                ),
                showsAttention: ExpandedQuickActionLogic.showsAttentionDot(
                    item: item,
                    pet: pet,
                    allEvents: allEvents,
                    feedingLedgerEntries: feedingLedgerEntries,
                    careLedgerEntries: careLedgerEntries,
                    walkLedgerEntries: walkLedgerEntries,
                    pottyLedgerEntries: pottyLedgerEntries,
                    now: now
                ),
                isLocked: false
            )
        }

        if let human = currentHuman {
            let viewedBy = activeHumanID
            let isLocked = ExpandedHumanQuickActionStateProvider.isPrivate(
                item,
                human: human,
                viewedBy: viewedBy,
                privacy: appServices.privacy
            )
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
                    privacy: appServices.privacy,
                    todayMedicationLogs: humanMedicationLogs
                ),
                showsAttention: medicationWarning != nil,
                isLocked: isLocked
            )
        }

        return QuickActionRenderState(status: nil, isCompleted: false, showsAttention: false, isLocked: false)
    }

    private func humanStatusText(for item: QuickActionItem, human: Human, viewedBy: UUID?) -> String? {
        ExpandedHumanQuickActionStateProvider.countText(
            item: item,
            human: human,
            viewedBy: viewedBy,
            privacy: appServices.privacy,
            activeMedications: humanMedications,
            todayMedicationLogs: humanMedicationLogs,
            recentExpenses: expenseEntries
        )
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

    private func isPrimaryDisabled(item: QuickActionItem, state: QuickActionRenderState) -> Bool {
        ExpandedQuickActionLogic.singleUseLabel(for: item.actionType) != nil && state.isCompleted
    }

    private func embeddedMenuPolicy(
        for item: QuickActionItem,
        options: [VerticalHomeEmbeddedActionOption]
    ) -> ExpandedQuickMenuPolicy {
        if let pet = currentPet {
            let policy = ExpandedQuickActionLogic.petMenuPolicy(
                for: item,
                pet: pet,
                allEvents: allEvents,
                feedingLedgerEntries: feedingLedgerEntries,
                now: Date()
            )
            guard !options.isEmpty else { return policy }
            return ExpandedQuickMenuPolicy(
                showsMenu: policy.showsMenu || !options.isEmpty,
                showsQuickButton: false
            )
        }
        if currentHuman != nil {
            return ExpandedQuickActionLogic.humanMenuPolicy(actionType: item.actionType)
        }
        return .none
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
        let normalized = actionType.lowercased()
        if normalized.contains("medication") { return "list.bullet.rectangle.fill" }
        if normalized.contains("note") || normalized == "moment" { return "sparkles" }
        if normalized.contains("expense") { return "creditcard.fill" }
        if ["water", "waterchange", "filterclean"].contains(normalized) { return "drop.circle.fill" }
        if normalized.contains("weight") { return "chart.line.uptrend.xyaxis" }
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
