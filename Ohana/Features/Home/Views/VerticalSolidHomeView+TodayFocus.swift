//
//  VerticalSolidHomeView+TodayFocus.swift
//  Ohana
//

import SwiftUI

extension VerticalSolidHomeView {
    func handleNewHomeMemberSaved(id: UUID) {
        cancelGrowthOnboardingPrompt()
        arrivalClearTask?.cancel()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            arrivingHomeCardId = id
            homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: id, currentRaw: homeCardOrderRaw)
        }
        arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: newMemberArrivalClearDelayMilliseconds) {
            guard arrivingHomeCardId == id else { return }
            arrivingHomeCardId = nil
            arrivalClearTask = nil
        }
    }

    func handleNewHomePlantSaved(id: UUID) {
        plantArrivalClearTask?.cancel()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            arrivingPlantCardId = id
        }
        plantArrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: newMemberArrivalClearDelayMilliseconds) {
            guard arrivingPlantCardId == id else { return }
            arrivingPlantCardId = nil
            plantArrivalClearTask = nil
        }
    }

    func handleCreatedEntitySignalIfNeeded(_ signal: HomeCreatedEntitySignal?) {
        guard let signal,
              handledCreatedEntityToken != signal.token else { return }
        handledCreatedEntityToken = signal.token
        handleNewHomeMemberSaved(id: signal.entityID)
        onCreatedEntitySignalHandled(signal)
    }

    var newMemberArrivalClearDelayMilliseconds: UInt64 {
        AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true).allowsMotion ? 1500 : 420
    }

    func clearArrivalState() {
        arrivalClearTask?.cancel()
        arrivalClearTask = nil
        arrivingHomeCardId = nil
        plantArrivalClearTask?.cancel()
        plantArrivalClearTask = nil
        arrivingPlantCardId = nil
    }

    func openCard(_ card: FocusCard) {
        if card.isHuman {
            onOpenHuman(card.id)
        } else if card.isElectronicPet {
            selectTab(.oasis)
        } else {
            onOpenPet(card.id, .overview)
        }
    }

    var isPlantCareUnlockedForHome: Bool {
        PlantUnlockPolicy.isUnlocked(currentLevel: appServices.oasisTree.treeLevel.rawValue)
    }

    func openPlant(_ plant: VerticalSolidHomePlantSnapshot) {
        guard isPlantCareUnlockedForHome else {
            AppFeatureRouteGuard.recordIntercept("plantGate:homePlantCard")
            return
        }
        onOpenPlant(plant.id)
    }

    func openTodayFocusQuest(_ quest: IslandQuest) {
        if openTodayFocusOasisQuest(quest) { return }

        if let destination = eventDestination(for: quest) {
            openCalendarEventDestinationAfterDismiss(destination)
            return
        }

        if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id),
           let target = petMedicationTarget(medicationId) {
            routeCoordinator.openSheet(.petMedication(target))
            return
        }

        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           interaction.containsHuman(humanId) {
            routeCoordinator.openSheet(.humanWeight(humanId))
            return
        }

        if let pet = targetPet(for: quest) {
            openPetQuickKey(todayFocusPetQuickKey(for: quest, pet: pet), petID: pet.id)
            return
        }

        if isPlantCareUnlockedForHome, let plant = targetPlant(for: quest) {
            openTodayFocusPlant(plant)
            return
        }

        if quest.id == "q_reminder" {
            selectTab(.calendar)
            return
        }

        selectTab(.oasis)
    }

    func completeTodayFocusQuest(_ quest: IslandQuest) {
        OhanaFeedback.light()

        if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id),
           let target = petMedicationTarget(medicationId) {
            requestTodayFocusMedicationDose(
                quest: quest,
                petID: target,
                medicationID: medicationId
            )
            return
        }

        if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
           interaction.eventRoutesByEventID[eventId] != nil {
            requestTodayFocusEventCompletion(eventID: eventId, actionTitle: quest.title)
            return
        }

        if isPlantCareUnlockedForHome,
           let plantCareType = IslandQuestEngine.plantCareType(fromQuestId: quest.id),
           !quest.targetPlantIds.isEmpty {
            let plantIDs = quest.targetPlantIds
            let primaryID = plantIDs[0]
            performWithActionHuman(actionTitle: plantCareType.displayName(l: l)) { executorID in
                enqueueHomeCommand(.todayFocus(entityID: primaryID, action: "plantBatch.\(plantCareType.rawValue)")) {
                    let recordedIDs = commandExecutor.recordPlantCare(
                        plantCareType,
                        plantIDs: plantIDs,
                        executorId: executorID
                    )
                    guard let firstRecordedID = recordedIDs.first else { return }
                    applyTodayFocusMutationFeedback(entityId: firstRecordedID)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            return
        }

        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           interaction.containsHuman(humanId) {
            routeCoordinator.openSheet(.humanWeight(humanId))
            return
        }

        guard let pet = targetPet(for: quest) else {
            openTodayFocusQuest(quest)
            return
        }

        switch todayFocusPetQuickKey(for: quest, pet: pet) {
        case "feed", "water", "walk", "play":
            performPetQuickAction(todayFocusPetQuickKey(for: quest, pet: pet), petID: pet.id)
        case "potty":
            routeCoordinator.openSheet(.petPotty(pet.id))
        case "litter":
            performPetQuickAction("litter", petID: pet.id)
        case "weight", "moment":
            openPetQuickKey(todayFocusPetQuickKey(for: quest, pet: pet), petID: pet.id)
        default:
            openTodayFocusQuest(quest)
        }
    }

    func requestTodayFocusEventCompletion(eventID: UUID, actionTitle: String) {
        let perform: (String?) -> Void = { executorID in
            enqueueHomeCommand(.todayFocus(entityID: eventID, action: "eventComplete")) {
                if commandExecutor.completeTodayFocusEvent(eventID: eventID, executorId: executorID) {
                    applyTodayFocusMutationFeedback(entityId: eventID)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
        guard interaction.eventActionHumanRequiredIDs.contains(eventID) else {
            perform(nil)
            return
        }
        performWithActionHuman(actionTitle: actionTitle, perform: perform)
    }

    func requestTodayFocusMedicationDose(
        quest: IslandQuest,
        petID: UUID,
        medicationID: UUID
    ) {
        performWithActionHuman(actionTitle: quest.title) { executorID in
            performTodayFocusMedicationDose(
                petID: petID,
                medicationID: medicationID,
                executorID: executorID
            )
        }
    }

    func performTodayFocusMedicationDose(
        petID: UUID,
        medicationID: UUID,
        executorID: String?
    ) {
        enqueueHomeCommand(.medicationDose(petID: petID, medicationID: medicationID)) {
            if commandExecutor.recordMedicationDose(
                petID: petID,
                medicationID: medicationID,
                executorId: executorID
            ) {
                applyTodayFocusMutationFeedback(entityId: petID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    func openTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        if let petId = signal.petId,
           interaction.activePet(id: petId) != nil {
            switch todayFocusNegativeRouteHint(for: signal) {
            case .petOverview:
                onOpenPet(petId, .overview)
            case .feed:
                routeCoordinator.openSheet(.petFeed(petId, opensManualSheet: false))
            case .water:
                routeCoordinator.openSheet(.petWater(petId))
            case .potty:
                routeCoordinator.openSheet(.petPotty(petId))
            case .walk:
                routeCoordinator.openSheet(.petWalkSummary(petId))
            case .weight:
                routeCoordinator.openSheet(.petWeight(petId))
            case .medication:
                routeCoordinator.openSheet(.petMedication(petId))
            case .allFeatures:
                routeCoordinator.openSheet(.petAllFeatures(petId))
            case .health, .plant:
                routeCoordinator.openSheet(.petHealth(petId, initialSection: .preventive))
            }
            return
        }

        if isPlantCareUnlockedForHome,
           let plantId = signal.plantId,
           interaction.plantIDs.contains(plantId) {
            onOpenPlant(plantId)
            return
        }

        openFunctionMenu(destination: .featureGroup(.healthBody))
    }

    func todayFocusNegativeRouteHint(for signal: IslandNegativeSignal) -> IslandNegativeSignal.RouteHint {
        if let routeHint = signal.routeHint {
            return routeHint
        }
        switch signal.healthAlertType {
        case .some(.weightGainAlert), .some(.weightLossAlert):
            return .weight
        case .some(.drinkingWeightAlert):
            return .water
        case .some(.noPotty):
            return .potty
        case .some(.noWalk):
            return .walk
        case .some(.documentExpiringSoon):
            return .allFeatures
        default:
            return .health
        }
    }

    func openTodayFocusFamilyTask(_ task: TodayFocusFamilyTaskSnapshot) {
        taskCenterFocusedItemID = task.id
        taskCenterFocusedFamilyTaskID = task.taskCenterItem.familyTaskID
        taskCenterFocusRequestID = UUID()
        selectTab(.calendar, preservesTaskFocus: true)
    }

    func performTodayFocusTask(_ task: TodayFocusFamilyTaskSnapshot) {
        guard let action = task.primaryAction else {
            openTodayFocusFamilyTask(task)
            return
        }
        let item = task.taskCenterItem
        guard let entityID = item.familyTaskID ?? item.eventID ?? item.reminderID ?? item.subject.id else {
            openTodayFocusFamilyTask(task)
            return
        }
        let domainCommand = DomainCommand.todayFocus(
            entityID: entityID,
            action: "task.\(action.rawValue)"
        )
        enqueueHomeCommand(domainCommand) {
            do {
                let result = try TaskActionCommandExecutor(
                    modelContext: modelContext,
                    services: appServices
                ).execute(TaskActionCommand(item: item, action: action))
                guard result.didSucceed else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    appServices.islandToasts.show(l.tr(
                        zh: "待办状态已变化，请打开待办后重试。",
                        en: "This task changed. Open Tasks and try again.",
                        de: "Diese Aufgabe wurde geändert. Öffne Aufgaben und versuche es erneut."
                    ))
                    return
                }
                applyTodayFocusMutationFeedback(
                    entityId: item.subject.id ?? item.eventID ?? item.familyTaskID ?? entityID
                )
                requestHomeSnapshotRefresh()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                appServices.domainRevisions.publishFailure(command: domainCommand, error: error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    func openTodayFocusExchange(_ request: TodayFocusExchangeRequestSnapshot) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        if let receiverId = UUID(uuidString: request.receiverId),
           interaction.containsHuman(receiverId) {
            routeCoordinator.openCoconutLog(.human(receiverId))
            return
        }

        if let receiver = interaction.activeHuman {
            routeCoordinator.openCoconutLog(.human(receiver.id))
            return
        }

        routeCoordinator.openAccountSwitcher()
    }

    func confirmTodayFocusExchange(_ request: TodayFocusExchangeRequestSnapshot) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let receiver = interaction.activeHuman else {
            routeCoordinator.openAccountSwitcher()
            return
        }
        let requestID = request.id
        let receiverID = receiver.id
        OhanaFeedback.light()
        enqueueHomeCommand(.coconutExchange(requestID: requestID)) {
            do {
                try commandExecutor.confirmCoconutExchange(requestID: requestID, receiverID: receiverID)
                applyTodayFocusMutationFeedback(entityId: requestID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                routeCoordinator.openCoconutLog(.human(receiverID))
            }
        }
    }

    func openTodayFocusOasisQuest(_ quest: IslandQuest) -> Bool {
        guard IslandQuestEngine.isOasisBuildQuest(quest.id) else { return false }
        switch quest.id {
        case IslandQuestEngine.oasisPetWizardQuestId:
            routeCoordinator.openAddEntity(.pet)
        case IslandQuestEngine.oasisFirstMealQuestId:
            if let petID = interaction.firstActivePetID {
                routeCoordinator.openSheet(.petFeed(petID, opensManualSheet: false))
            } else {
                routeCoordinator.openAddEntity(.pet)
            }
        case IslandQuestEngine.oasisThemeQuestId:
            routeCoordinator.openCrewRoster()
        default:
            selectTab(.oasis)
        }
        return true
    }

    func eventDestination(for quest: IslandQuest) -> HomeReminderRouteSnapshot? {
        guard let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id)
            ?? IslandQuestEngine.carePlanEventId(fromQuestId: quest.id) else {
            return nil
        }
        return interaction.eventRoutesByEventID[eventId]
    }

    func petMedicationTarget(_ medicationId: UUID) -> UUID? {
        interaction.petMedicationTargetsByMedicationID[medicationId]
    }

    func targetPet(for quest: IslandQuest) -> HomePetInteractionSnapshot? {
        if let targetPetId = quest.targetPetId,
           let pet = interaction.activePet(id: targetPetId) {
            return pet
        }
        if quest.id == "q_walk" || quest.id == "q_potty" || quest.id.hasPrefix("q_walk_") || quest.id.hasPrefix("q_potty_") {
            return interaction.firstActivePetID.flatMap { interaction.activePet(id: $0) }
        }
        return nil
    }

    func targetPlant(for quest: IslandQuest) -> VerticalSolidHomePlantSnapshot? {
        guard isPlantCareUnlockedForHome else { return nil }
        if let targetPlantId = quest.targetPlantId {
            return controller.snapshot.plants.first(where: { $0.id == targetPlantId })
        }
        if let targetPlantId = quest.targetPlantIds.first {
            return controller.snapshot.plants.first(where: { $0.id == targetPlantId })
        }
        switch quest.id {
        case "q_water_plant":
            return controller.snapshot.plants.first(where: { $0.needsCare }) ?? controller.snapshot.plants.first
        case "q_fertilize_plant":
            return controller.snapshot.plants.first(where: { $0.needsCare }) ?? controller.snapshot.plants.first
        default:
            return nil
        }
    }

    func todayFocusSnapshotDate() -> Date {
        let dayToken = controller.snapshot.todayFocus.dayToken
        guard dayToken > 0 else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(dayToken))
    }

    func openTodayFocusPlant(_ plant: VerticalSolidHomePlantSnapshot) {
        onOpenPlant(plant.id)
    }

    func todayFocusPetQuickKey(for quest: IslandQuest, pet: HomePetInteractionSnapshot) -> String {
        if quest.id.hasPrefix("q_feed_") { return "feed" }
        if quest.id.hasPrefix("q_water_") { return "water" }
        if quest.id == "q_walk" || quest.id.hasPrefix("q_walk_") { return "walk" }
        if quest.id == "q_potty" || quest.id.hasPrefix("q_potty_") {
            return Pet.isCatSpecies(pet.species) || Pet.isRabbitSpecies(pet.species) ? "litter" : "potty"
        }
        if quest.id.hasPrefix("q_play_") { return "play" }
        if quest.id.hasPrefix("q_weight_") { return "weight" }
        if quest.id.hasPrefix("q_moment_") { return "moment" }
        return "basic"
    }

    func applyTodayFocusMutationFeedback(entityId: UUID) {
        applyQuickActionExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: entityId,
                coconutDelta: 0,
                label: nil
            )
        )
    }

    func scheduleTodayFocusDailyCompletion(afterCompleting entityId: UUID) {
        let visibleQuests = controller.snapshot.todayFocus.refreshedQuests
        let pending = visibleQuests.filter { !$0.isCompleted }
        if pending.count == 1,
           let finalQuest = pending.first,
           appServices.todayFocus.quest(finalQuest, matchesCompletedEntity: entityId) {
            scheduleTodayFocusDailyCompletion(visibleQuests: visibleQuests, visibleSnapshot: controller.snapshot.todayFocus)
        }
    }

    func scheduleTodayFocusDailyCompletionIfCleared(previousQuests: [IslandQuest], currentQuests: [IslandQuest]) {
        let pending = previousQuests.filter { !$0.isCompleted }
        guard pending.count == 1 else { return }

        let previousIds = Set(previousQuests.map(\.id))
        let hasSamePendingQuest = currentQuests.contains {
            previousIds.contains($0.id) && !$0.isCompleted
        }
        guard !hasSamePendingQuest else { return }

        scheduleTodayFocusDailyCompletion(visibleQuests: previousQuests, visibleSnapshot: controller.snapshot.todayFocus)
    }

    func scheduleTodayFocusDailyCompletion(visibleQuests: [IslandQuest], visibleSnapshot: TodayFocusSnapshot) {
        guard !visibleQuests.isEmpty else { return }
        todayFocusDailyCompletionTask?.cancel()
        todayFocusDailyCompletionTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 420) {
            _ = appServices.todayFocus.awardDailyCompletionIfNeeded(
                context: modelContext,
                executorId: currentExecutorId(),
                visibleQuests: visibleQuests,
                visibleSnapshot: visibleSnapshot
            )
            todayFocusDailyCompletionTask = nil
        }
    }
}
