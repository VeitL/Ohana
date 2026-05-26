//
//  FocusHomeView+QuickActions.swift
//  Ohana
//
//  Split FocusHomeView responsibilities.
//

import SwiftUI

extension FocusHomeView {
    @ViewBuilder
    func verticalEmbeddedQuickModules(
        for card: FocusCard,
        pets sourcePets: [Pet]? = nil,
        humans sourceHumans: [Human]? = nil,
        events sourceEvents: [Event]? = nil
    ) -> some View {
        let quickPets = sourcePets ?? pets
        let quickHumans = sourceHumans ?? humans
        let quickEvents = sourceEvents ?? allEvents
        if card.isReal,
           !card.isHuman,
           let pet = quickPets.first(where: { $0.id == card.id && !$0.hasPassedAway })
        {
            let sourceItems = expandedQuickEdit.isEditMode
                ? expandedQuickEdit.items
                : expandedQuickActionItems(for: pet)
            let visibleLimit = QuickActionLimit.maxItemsPerEntity
            let items = Array(sourceItems.prefix(visibleLimit))
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: items.map { item in
                    VerticalHomeEmbeddedAction(
                        id: item.id,
                        title: item.label,
                        icon: item.icon,
                        isCompleted: ExpandedQuickActionLogic.isCompleted(item: item, pet: pet, allEvents: quickEvents, allFeedCareLogs: pet.careLogs, now: Date()),
                        detailIcon: verticalEmbeddedDetailIcon(for: item.actionType, isHuman: false),
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { handlePetQuickDetail(item, pet: pet) },
                        action: { handlePetQuickPrimary(item, pet: pet) }
                    )
                },
                addItems: expandedPetQuickAddItems(for: pet).map { embeddedAddAction(for: $0) },
                isEditMode: expandedQuickEdit.isEditMode,
                jiggle: expandedQuickEdit.jiggle,
                shouldReduceWork: shouldReduceWork,
                forcesSubmenusBelow: true,
                draggingItemId: $expandedQuickEdit.draggingItemId,
                onToggleEdit: {
                    expandedQuickEdit.isEditMode ? exitExpandedQAEditMode(for: pet) : enterExpandedQAEditMode(for: pet)
                },
                onMove: { fromId, toId in moveExpandedQuickEditItem(fromId: fromId, toId: toId) },
                onRemove: { id in removeExpandedQuickEditItem(id: id) },
                onAdd: { actionType in addExpandedPetQuickEditItem(actionType: actionType, pet: pet) }
            )
        } else if card.isReal,
                  card.isHuman,
                  let human = quickHumans.first(where: { $0.id == card.id })
        {
            let sourceItems = expandedQuickEdit.isEditMode
                ? expandedQuickEdit.items
                : expandedHumanQuickActionItems(for: human)
            let visibleLimit = QuickActionLimit.maxItemsPerEntity
            let items = Array(sourceItems.prefix(visibleLimit))
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: items.map { item in
                    VerticalHomeEmbeddedAction(
                        id: item.id,
                        title: item.label,
                        icon: item.icon,
                        isCompleted: false,
                        detailIcon: verticalEmbeddedDetailIcon(for: item.actionType, isHuman: true),
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { handleHumanQuickDetail(item, human: human) },
                        action: { handleHumanQuickPrimary(item, human: human) }
                    )
                },
                addItems: expandedHumanQuickAddItems(for: human).map { embeddedAddAction(for: $0) },
                isEditMode: expandedQuickEdit.isEditMode,
                jiggle: expandedQuickEdit.jiggle,
                shouldReduceWork: shouldReduceWork,
                forcesSubmenusBelow: true,
                draggingItemId: $expandedQuickEdit.draggingItemId,
                onToggleEdit: {
                    expandedQuickEdit.isEditMode ? exitExpandedHumanQAEditMode(for: human) : enterExpandedHumanQAEditMode(for: human)
                },
                onMove: { fromId, toId in moveExpandedQuickEditItem(fromId: fromId, toId: toId) },
                onRemove: { id in removeExpandedQuickEditItem(id: id) },
                onAdd: { actionType in addExpandedHumanQuickEditItem(actionType: actionType, human: human) }
            )
        } else {
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: [
                    VerticalHomeEmbeddedAction(
                        id: "primary",
                        title: card.isHuman ? l.homeQAWeight : l.homeQAFeed,
                        icon: card.isHuman ? "scalemass.fill" : "fork.knife",
                        isCompleted: false,
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { openQuickModule(.all, for: card) }
                    ) { openQuickModule(.primary, for: card) },
                    VerticalHomeEmbeddedAction(
                        id: "secondary",
                        title: card.isHuman ? l.expense : l.homeQAWater,
                        icon: card.isHuman ? "creditcard.fill" : "drop.fill",
                        isCompleted: false,
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { openQuickModule(.all, for: card) }
                    ) { openQuickModule(.secondary, for: card) },
                    VerticalHomeEmbeddedAction(
                        id: "tertiary",
                        title: card.isHuman ? l.homeQAMeds : l.tr(zh: "健康", en: "Health", de: "Gesundheit"),
                        icon: card.isHuman ? "pill.fill" : "cross.fill",
                        isCompleted: false,
                        quickAccessibilityLabel: l.tr(zh: "快速操作", en: "Quick action", de: "Schnellaktion"),
                        detailAccessibilityLabel: l.tr(zh: "查看详情", en: "View details", de: "Details anzeigen"),
                        detailAction: { openQuickModule(.all, for: card) }
                    ) { openQuickModule(.tertiary, for: card) },
                ]
            )
        }
    }

    func verticalEmbeddedDetailIcon(for actionType: String, isHuman: Bool) -> String {
        if actionType.contains("medication") { return "list.bullet.rectangle.fill" }
        if actionType.contains("note") || actionType == "moment" { return "sparkles" }
        if actionType.contains("expense") { return "creditcard.fill" }
        if actionType.contains("weight") { return "chart.line.uptrend.xyaxis" }
        if isHuman { return "rectangle.stack.fill" }
        return "chart.line.uptrend.xyaxis"
    }

    func expandedPetQuickActions(pet: Pet) -> some View {
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedQuickActionItems(for: pet).prefix(8))
        let avatar = FocusWalletAvatarCache.entry(for: pet.id, data: snapshotController.avatarData(for: pet.id)).image
        let embedsActionsInVerticalCard = true

        return ExpandedPetQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            pet: pet,
            items: items,
            avatar: avatar,
            themeHex: pet.safeThemeColorHex,
            editItems: $expandedQuickEdit.items,
            draggingItemId: $expandedQuickEdit.draggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: expandedQuickEdit.isEditMode,
            jiggle: expandedQuickEdit.jiggle,
            shouldReduceWork: shouldReduceWork,
            showsHeader: !embedsActionsInVerticalCard,
            longPressStartsEdit: embedsActionsInVerticalCard,
            showFirstSuccessPrompt: false,
            waterManagementLabel: waterManagementLabel,
            onToggleEdit: {
                expandedQuickEdit.isEditMode ? exitExpandedQAEditMode(for: pet) : enterExpandedQAEditMode(for: pet)
            },
            onFirstSuccessFeed: { openPetQuickKey("feed", card: FocusCard.from(pet, includeAvatarData: true)) },
            onFirstSuccessPlay: { openPetQuickKey("play", card: FocusCard.from(pet, includeAvatarData: true)) },
            onFirstSuccessMoment: { routeCoordinator.openQuickMoment(pet) },
            showsAttentionDot: { _ in false },
            countText: { ExpandedQuickActionLogic.countText(item: $0, pet: pet, allEvents: allEvents, allFeedCareLogs: pet.careLogs, now: Date()) },
            isCompleted: { ExpandedQuickActionLogic.isCompleted(item: $0, pet: pet, allEvents: allEvents, allFeedCareLogs: pet.careLogs, now: Date()) },
            onTap: { handlePetQuickPrimary($0, pet: pet) },
            onLongPress: { handlePetQuickDetail($0, pet: pet) },
            onGroomCheckIn: { _ in routeCoordinator.openSheet(.petHygiene(pet.id)) },
            onPottySelect: { _ in routeCoordinator.openSheet(.petPotty(pet.id)) },
            onHealthSelect: { _ in routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil)) },
            onLimitReached: { routeCoordinator.showQuickActionLimit() }
        )
    }

    func expandedHumanQuickActions(human: Human) -> some View {
        let items = expandedQuickEdit.isEditMode
            ? expandedQuickEdit.items
            : Array(expandedHumanQuickActionItems(for: human).prefix(8))
        let defaultItems = ExpandedQuickActionDefaults.humanItems(for: human, localization: l)
        let avatar = FocusWalletAvatarCache.entry(for: human.id, data: snapshotController.avatarData(for: human.id)).image
        let embedsActionsInVerticalCard = true
        let viewedBy = UUID(uuidString: activeHumanIdStr)

        return ExpandedHumanQuickActionsSection(
            title: l.tr(zh: "动作", en: "Actions", de: "Aktionen"),
            human: human,
            items: items,
            defaultItems: defaultItems,
            avatar: avatar,
            themeHex: human.safeThemeColorHex,
            editItems: $expandedQuickEdit.items,
            draggingItemId: $expandedQuickEdit.draggingItemId,
            pressedActionId: $pressedExpandedActionId,
            isEditMode: expandedQuickEdit.isEditMode,
            jiggle: expandedQuickEdit.jiggle,
            shouldReduceWork: shouldReduceWork,
            showsHeader: !embedsActionsInVerticalCard,
            longPressStartsEdit: embedsActionsInVerticalCard,
            onToggleEdit: {
                expandedQuickEdit.isEditMode ? exitExpandedHumanQAEditMode(for: human) : enterExpandedHumanQAEditMode(for: human)
            },
            countText: { item in
                if item.actionType == "humanMedication",
                   let warning = CarePlanOverdueStatusCalculator.humanMedicationWarning(
                       for: human,
                       medications: humanMedications,
                       logs: humanMedicationLogs
                   )
                {
                    return warning.compactText
                }
                return ExpandedQuickActionLogic.humanCountText(
                    item: item,
                    human: human,
                    isLocked: PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: viewedBy),
                    activeMedications: humanMedications,
                    todayMedicationLogs: humanMedicationLogs
                )
            },
            privacyIconName: { ExpandedQuickActionLogic.humanPrivacyIconName(for: $0, human: human) },
            privacyIconTint: { ExpandedQuickActionLogic.humanPrivacyIconTint(for: $0, human: human) },
            isPrivacyLocked: { PrivacyService.isHumanQuickActionLocked($0, human: human, viewedBy: viewedBy) },
            isCompleted: {
                ExpandedQuickActionLogic.humanCompleted(
                    item: $0,
                    human: human,
                    isLocked: PrivacyService.isHumanQuickActionLocked($0, human: human, viewedBy: viewedBy),
                    todayMedicationLogs: humanMedicationLogs
                )
            },
            feedbackActionKey: nil,
            feedbackToken: nil,
            onTap: { handleHumanQuickPrimary($0, human: human) },
            onLongPress: { handleHumanQuickDetail($0, human: human) },
            onLimitReached: { routeCoordinator.showQuickActionLimit() }
        )
    }

    @ViewBuilder
    func contextMenu(for card: FocusCard) -> some View {
        Button(l.tr(zh: "基本信息", en: "Basic Info", de: "Basisdaten")) { openCardBasicInfo(card) }
        Button(l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen")) { openAllFeatures(card) }
    }

    func expandedQuickActionItems(for pet: Pet) -> [QuickActionItem] {
        ExpandedQuickActionStore.petItems(
            raw: quickActionItemsJSON,
            pet: pet,
            localization: l,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
    }

    func expandedHumanQuickActionItems(for human: Human) -> [QuickActionItem] {
        ExpandedQuickActionStore.humanItems(
            raw: quickActionItemsJSON,
            human: human,
            localization: l
        )
    }

    func expandedPetQuickAddItems(for pet: Pet) -> [QuickActionItem] {
        let existing = Set(expandedQuickEdit.items.filter { $0.petId == pet.id && $0.entityKind != .human }.map(\.actionType))
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existing).map { option in
            QuickActionItem(
                label: option.label,
                icon: option.icon,
                colorHex: option.colorHex,
                petId: pet.id,
                actionType: option.id,
                entityId: pet.id,
                entityKind: .pet
            )
        }
    }

    func expandedHumanQuickAddItems(for human: Human) -> [QuickActionItem] {
        let existing = Set(expandedQuickEdit.items.map(\.actionType))
        return ExpandedQuickActionDefaults.humanItems(for: human, localization: l)
            .filter { !existing.contains($0.actionType) }
    }

    func embeddedAddAction(for item: QuickActionItem) -> VerticalHomeEmbeddedAction {
        VerticalHomeEmbeddedAction(
            id: item.actionType,
            title: item.label,
            icon: item.icon,
            isCompleted: false,
            quickAccessibilityLabel: l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen"),
            detailAccessibilityLabel: l.tr(zh: "添加快捷操作", en: "Add quick action", de: "Schnellaktion hinzufügen")
        ) {}
    }

    func enterExpandedQAEditMode(for pet: Pet) {
        expandedQuickEdit.enter(with: expandedQuickActionItems(for: pet), animation: HeroAnim.buttonSpring)
    }

    func exitExpandedQAEditMode(for pet: Pet) {
        pressedExpandedActionId = nil
        quickActionItemsJSON = ExpandedQuickActionStore.savingPetItems(
            expandedQuickEdit.items,
            pet: pet,
            raw: quickActionItemsJSON,
            localization: l,
            waterLabel: l.homeQAWater,
            managementLabel: waterManagementLabel
        )
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    func enterExpandedHumanQAEditMode(for human: Human) {
        expandedQuickEdit.enter(with: expandedHumanQuickActionItems(for: human), animation: HeroAnim.buttonSpring)
    }

    func exitExpandedHumanQAEditMode(for human: Human) {
        pressedExpandedActionId = nil
        quickActionItemsJSON = ExpandedQuickActionStore.savingHumanItems(
            expandedQuickEdit.items,
            human: human,
            raw: quickActionItemsJSON,
            localization: l
        )
        expandedQuickEdit.exit(animation: HeroAnim.buttonSpring)
    }

    func moveExpandedQuickEditItem(fromId: String, toId: String) {
        guard let fromIndex = expandedQuickEdit.items.firstIndex(where: { $0.id == fromId }),
              let toIndex = expandedQuickEdit.items.firstIndex(where: { $0.id == toId })
        else { return }
        withAnimation(GoMotion.selection) {
            expandedQuickEdit.items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func removeExpandedQuickEditItem(id: String) {
        withAnimation(HeroAnim.buttonSpring) {
            expandedQuickEdit.items.removeAll { $0.id == id }
        }
    }

    func addExpandedPetQuickEditItem(actionType: String, pet: Pet) {
        guard expandedQuickEdit.items.count < QuickActionLimit.maxItemsPerEntity else {
            routeCoordinator.showQuickActionLimit()
            return
        }
        guard let item = expandedPetQuickAddItems(for: pet).first(where: { $0.actionType == actionType }) else { return }
        withAnimation(HeroAnim.buttonSpring) {
            expandedQuickEdit.items.append(item)
        }
    }

    func addExpandedHumanQuickEditItem(actionType: String, human: Human) {
        guard expandedQuickEdit.items.count < QuickActionLimit.maxItemsPerEntity else {
            routeCoordinator.showQuickActionLimit()
            return
        }
        guard let item = expandedHumanQuickAddItems(for: human).first(where: { $0.actionType == actionType }) else { return }
        withAnimation(HeroAnim.buttonSpring) {
            expandedQuickEdit.items.append(item)
        }
    }

    func handlePetQuickPrimary(_ item: QuickActionItem, pet: Pet) {
        OhanaFeedback.light()
        if item.actionType == "medication" {
            openExpandedQuickPetMedicationAdd(for: pet)
            return
        }

        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case let .perform(actionType):
            switch actionType {
            case "feed":
                performTodayFocusPetAction("feed", pet: pet)
            case "water":
                performTodayFocusPetAction("water", pet: pet)
            case "walk":
                performTodayFocusPetAction("walk", pet: pet)
            case "play":
                performTodayFocusPetAction("play", pet: pet)
            case "litter":
                performTodayFocusPetAction("litter", pet: pet)
            case "cageCleaning", "freeFlight", "misting", "substrateChange", "groom":
                performTodayFocusPetAction(actionType, pet: pet)
            default:
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            }
        case .waterManagement:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .weight:
            openExpandedQuickWeight(for: pet)
        case .expense:
            openExpandedQuickExpense(for: pet)
        case .moment:
            routeCoordinator.openQuickMoment(pet)
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .none:
            break
        }
    }

    func handlePetQuickDetail(_ item: QuickActionItem, pet: Pet) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.petLongPressRoute(for: item) {
        case .feedDetail:
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .waterManagement:
            routeCoordinator.openSheet(.petWater(pet.id))
        case .walk:
            routeCoordinator.openSheet(.petWalkSummary(pet.id))
        case .playDetail:
            routeCoordinator.openSheet(.petPlay(pet.id))
        case .pottyDetail:
            routeCoordinator.openSheet(.petPotty(pet.id))
        case .hygiene:
            routeCoordinator.openSheet(.petHygiene(pet.id))
        case .health:
            routeCoordinator.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medication:
            routeCoordinator.openSheet(.petMedication(pet.id))
        case .weightDetail:
            routeCoordinator.openSheet(.petWeight(pet.id))
        case .expenseDetail:
            routeCoordinator.openSheet(.petExpense(pet.id))
        case .momentHistory:
            routeCoordinator.openSheet(.petMomentHistory(pet.id))
        case .none:
            break
        }
    }

    func handleHumanQuickPrimary(_ item: QuickActionItem, human: Human) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: false) {
        case .weightQuick:
            openExpandedQuickHumanWeight(for: human)
        case .workoutQuick:
            openExpandedQuickHumanWorkout(for: human)
        case .medicationAdd:
            openExpandedQuickHumanMedication(for: human)
        case .noteQuick:
            openExpandedQuickHumanNote(for: human)
        case .expenseQuick:
            openExpandedQuickHumanExpense(for: human)
        case .weightDetail:
            routeCoordinator.openSheet(.humanWeight(human.id))
        case .workoutDetail:
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case .medicationDetail:
            routeCoordinator.openSheet(.humanMedication(human.id))
        case .noteDetail:
            routeCoordinator.openSheet(.humanNote(human.id))
        case .expenseDetail:
            routeCoordinator.openSheet(.humanExpense(human.id))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        case .privacyAlert:
            routeCoordinator.showHumanPrivacy()
        case .none:
            break
        }
    }

    func handleHumanQuickDetail(_ item: QuickActionItem, human: Human) {
        OhanaFeedback.light()
        switch ExpandedQuickActionLogic.humanLongPressRoute(actionType: item.actionType, isLocked: false) {
        case .weightDetail, .weightQuick:
            routeCoordinator.openSheet(.humanWeight(human.id))
        case .workoutDetail, .workoutQuick:
            routeCoordinator.openSheet(.humanWorkout(human.id))
        case .medicationDetail, .medicationAdd:
            routeCoordinator.openSheet(.humanMedication(human.id))
        case .noteDetail, .noteQuick:
            routeCoordinator.openSheet(.humanNote(human.id))
        case .expenseDetail, .expenseQuick:
            routeCoordinator.openSheet(.humanExpense(human.id))
        case .allFeatures, .selectHuman:
            routeCoordinator.openSheet(.humanAllFeatures(human.id))
        case .privacyAlert:
            routeCoordinator.showHumanPrivacy()
        case .none:
            break
        }
    }

    @ViewBuilder
    func quickInlineRecordOverlays() -> some View {
        FocusHomeQuickRecordOverlayLayer(
            router: routeCoordinator,
            pets: pets,
            humans: humans,
            preselectedPayerId: activeHumanIdStr,
            onPetWeightRewarded: { petId, delta in
                requestSnapshotRefresh()
                if delta > 0 {
                    showReward(amount: delta, label: "体重 +\(delta)🥥", cardId: petId)
                }
            },
            onPetExpenseRewarded: { petId, delta in
                requestSnapshotRefresh()
                if delta > 0 {
                    showReward(amount: delta, label: "花费 +\(delta)🥥", cardId: petId)
                }
            },
            onHumanSaved: { humanId, actionKey in
                requestSnapshotRefresh()
                showReward(amount: 2, label: rewardLabel(for: actionKey), cardId: humanId)
            },
            onManageHumanMedication: { human in
                routeCoordinator.openSheet(.humanMedication(human.id))
            },
            onPetMedicationSaved: { pet in
                commandExecutor.scheduleMedicationReminders(for: pet)
                requestSnapshotRefresh()
            }
        )
    }

    func openExpandedQuickWeight(for pet: Pet) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openPetWeight(pet)
    }

    func openExpandedQuickExpense(for pet: Pet) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openPetExpense(pet)
    }

    func openExpandedQuickPetMedicationAdd(for pet: Pet) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openPetMedication(pet)
    }

    func openExpandedQuickHumanWeight(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanWeight(human)
    }

    func openExpandedQuickHumanWorkout(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanWorkout(human)
    }

    func openExpandedQuickHumanMedication(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanMedication(human)
    }

    func openExpandedQuickHumanNote(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanNote(human)
    }

    func openExpandedQuickHumanExpense(for human: Human) {
        closeTransientMenusForQuickRecord()
        routeCoordinator.openHumanExpense(human)
    }

    func closeTransientMenusForQuickRecord() {
        withAnimation(routeAnimation) {
            fabExpanded = false
            fabMenuItemsVisible = false
        }
    }

    func rewardLabel(for actionKey: String) -> String? {
        if actionKey.contains("humanWeight") { return l.tr(zh: "体重 +2🥥", en: "Weight +2🥥", de: "Gewicht +2🥥") }
        if actionKey.contains("humanExpense") { return l.tr(zh: "花费 +2🥥", en: "Expense +2🥥", de: "Ausgaben +2🥥") }
        if actionKey.contains("humanMedication") { return l.tr(zh: "用药 +2🥥", en: "Medication +2🥥", de: "Medikation +2🥥") }
        if actionKey.contains("humanWorkout") { return l.tr(zh: "运动 +2🥥", en: "Workout +2🥥", de: "Training +2🥥") }
        if actionKey.contains("humanNote") { return l.tr(zh: "记录 +2🥥", en: "Moment +2🥥", de: "Moment +2🥥") }
        return nil
    }

    func currentExecutorId() -> String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }
}
