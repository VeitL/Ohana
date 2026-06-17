//
//  VerticalSolidHomeView+TodayFocus.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension VerticalSolidHomeView {
    func openHomeFabShortcut(_ shortcut: HomeFabFunctionShortcut) {
        closeVerticalFabMenu(immediate: true)
        openFunctionMenu(destination: shortcut.destination)
    }

    func handleNewHomeMemberSaved(id: UUID) {
        cancelGrowthOnboardingPrompt()
        homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: id, currentRaw: homeCardOrderRaw)
        arrivalClearTask?.cancel()
        arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: newMemberArrivalStartDelayMilliseconds) {
            guard arrivingHomeCardId != id else { return }
            arrivingHomeCardId = id
            arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1500) {
                guard arrivingHomeCardId == id else { return }
                arrivingHomeCardId = nil
                arrivalClearTask = nil
            }
        }
    }

    func handleCreatedEntitySignalIfNeeded(_ signal: HomeCreatedEntitySignal?) {
        guard let signal,
              handledCreatedEntityToken != signal.token else { return }
        handledCreatedEntityToken = signal.token
        handleNewHomeMemberSaved(id: signal.entityID)
        onCreatedEntitySignalHandled(signal)
    }

    var newMemberArrivalStartDelayMilliseconds: UInt64 {
        AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true).allowsMotion ? 560 : 120
    }

    func clearArrivalState() {
        arrivalClearTask?.cancel()
        arrivalClearTask = nil
        arrivingHomeCardId = nil
    }

    func openCard(_ card: FocusCard) {
        if card.isHuman {
            onOpenHuman(card.id)
        } else if card.isElectronicPet {
            controller.select(.oasis)
        } else {
            onOpenPet(card.id, .overview)
        }
    }

    func openPlant(_ plant: VerticalSolidHomePlantSnapshot) {
        guard PlantFeatureGate.allows(.plants) else {
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
            routeCoordinator.openSheet(.petMedication(target.pet.id))
            return
        }

        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           let human = humans.first(where: { $0.id == humanId }) {
            routeCoordinator.openSheet(.humanWeight(human.id))
            return
        }

        if let pet = targetPet(for: quest) {
            openPetQuickKey(todayFocusPetQuickKey(for: quest, pet: pet), pet: pet)
            return
        }

        if PlantFeatureGate.allows(.plants), let plant = targetPlant(for: quest) {
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
            let petID = target.pet.id
            let medicationID = target.medication.id
            enqueueHomeCommand(.medicationDose(petID: petID, medicationID: medicationID)) {
                if commandExecutor.recordMedicationDose(petID: petID, medicationID: medicationID) {
                    applyTodayFocusMutationFeedback(entityId: petID)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            return
        }

        if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
           let event = allEvents.first(where: { $0.id == eventId }) {
            let eventID = event.id
            enqueueHomeCommand(.todayFocus(entityID: eventID, action: "eventComplete")) {
                if commandExecutor.completeTodayFocusEvent(eventID: eventID) {
                    applyTodayFocusMutationFeedback(entityId: eventID)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            return
        }

        if PlantFeatureGate.allows(.plants),
           quest.id == "q_water_plant" || quest.id.hasPrefix("q_water_plant_"),
           let plant = targetPlant(for: quest) {
            let plantID = plant.id
            enqueueHomeCommand(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
                commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
                applyTodayFocusMutationFeedback(entityId: plantID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if PlantFeatureGate.allows(.plants),
           quest.id == "q_fertilize_plant" || quest.id.hasPrefix("q_fertilize_plant_"),
           let plant = targetPlant(for: quest) {
            let plantID = plant.id
            enqueueHomeCommand(.plantCare(plantID: plantID, action: PlantCareType.fertilizing.rawValue)) {
                commandExecutor.recordPlantCare(.fertilizing, plantID: plantID, executorId: currentExecutorId())
                applyTodayFocusMutationFeedback(entityId: plantID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id),
           let human = humans.first(where: { $0.id == humanId }) {
            routeCoordinator.openSheet(.humanWeight(human.id))
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
            openPetQuickKey(todayFocusPetQuickKey(for: quest, pet: pet), pet: pet)
        default:
            openTodayFocusQuest(quest)
        }
    }

    func openTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        if let petId = signal.petId,
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            switch todayFocusNegativeRouteHint(for: signal) {
            case .petOverview:
                onOpenPet(pet.id, .overview)
            case .feed:
                routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
            case .water:
                routeCoordinator.openSheet(.petWater(pet.id))
            case .potty:
                routeCoordinator.openSheet(.petPotty(pet.id))
            case .walk:
                routeCoordinator.openSheet(.petWalkSummary(pet.id))
            case .weight:
                routeCoordinator.openSheet(.petWeight(pet.id))
            case .medication:
                routeCoordinator.openSheet(.petMedication(pet.id))
            case .allFeatures:
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            case .health, .plant:
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: .preventive))
            }
            return
        }

        if PlantFeatureGate.allows(.plants),
           let plantId = signal.plantId,
           plants.contains(where: { $0.id == plantId }) {
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

    func openTodayFocusFamilyTask(_: TodayFocusFamilyTaskSnapshot) {
        guard OnlineFeatureGate.allows(.onlineCollaboration) else {
            AppFeatureRouteGuard.recordIntercept("todayFocusFamilyTask:onlineGate")
            routeCoordinator.openCrewRoster()
            return
        }
        routeCoordinator.openCrewRoster(mode: .collaboration)
    }

    func openTodayFocusExchange(_ request: TodayFocusExchangeRequestSnapshot) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        if let receiverId = UUID(uuidString: request.receiverId),
           let receiver = humans.first(where: { $0.id == receiverId }) {
            routeCoordinator.openCoconutLog(.human(receiver.id))
            return
        }

        if let receiver = activeHuman {
            routeCoordinator.openCoconutLog(.human(receiver.id))
            return
        }

        routeCoordinator.openAccountSwitcher()
    }

    func confirmTodayFocusExchange(_ request: TodayFocusExchangeRequestSnapshot) {
        guard CoconutExchangeFeatureGate.isEnabled else { return }
        guard let receiver = activeHuman else {
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
            if let pet = pets.first(where: { !$0.hasPassedAway }) {
                routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
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

    func eventDestination(for quest: IslandQuest) -> FocusHomeReminderDestination? {
        guard let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id)
            ?? IslandQuestEngine.carePlanEventId(fromQuestId: quest.id),
            let event = allEvents.first(where: { $0.id == eventId }) else {
            return nil
        }
        return FocusHomeReminderDeepLinkRouter.destination(
            for: event,
            pets: pets,
            humans: humans,
            plants: plants,
            humanMedications: humanMedications
        )
    }

    func petMedicationTarget(_ medicationId: UUID) -> (pet: Pet, medication: PetMedication)? {
        for pet in pets where !pet.hasPassedAway {
            if let medication = pet.medications.first(where: { $0.id == medicationId }) {
                return (pet, medication)
            }
        }
        return nil
    }

    func targetPet(for quest: IslandQuest) -> Pet? {
        if let targetPetId = quest.targetPetId,
           let pet = pets.first(where: { $0.id == targetPetId && !$0.hasPassedAway }) {
            return pet
        }
        if quest.id == "q_walk" || quest.id == "q_potty" || quest.id.hasPrefix("q_walk_") || quest.id.hasPrefix("q_potty_") {
            return pets.first(where: { !$0.hasPassedAway })
        }
        return nil
    }

    func targetPlant(for quest: IslandQuest) -> Plant? {
        guard PlantFeatureGate.allows(.plants) else { return nil }
        if let targetPlantId = quest.targetPlantId {
            return plants.first(where: { $0.id == targetPlantId })
        }
        switch quest.id {
        case "q_water_plant":
            let focusDate = todayFocusSnapshotDate()
            return plants.first(where: { $0.needsWatering(on: focusDate) })
        case "q_fertilize_plant":
            let focusDate = todayFocusSnapshotDate()
            return plants.first(where: { $0.needsFertilizing(on: focusDate) })
        default:
            return nil
        }
    }

    func todayFocusSnapshotDate() -> Date {
        let dayToken = controller.snapshot.todayFocus.dayToken
        guard dayToken > 0 else { return Date() }
        return Date(timeIntervalSince1970: TimeInterval(dayToken))
    }

    func openTodayFocusPlant(_ plant: Plant) {
        onOpenPlant(plant.id)
    }

    func todayFocusPetQuickKey(for quest: IslandQuest, pet: Pet) -> String {
        if quest.id.hasPrefix("q_feed_") { return "feed" }
        if quest.id.hasPrefix("q_water_") { return "water" }
        if quest.id == "q_walk" || quest.id.hasPrefix("q_walk_") { return "walk" }
        if quest.id == "q_potty" || quest.id.hasPrefix("q_potty_") {
            return pet.species.contains("猫") || pet.species.contains("兔") ? "litter" : "potty"
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
