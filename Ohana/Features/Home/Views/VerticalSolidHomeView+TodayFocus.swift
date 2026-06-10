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
        homeCardOrderRaw = FocusHomeCardDataSource.promotedOrderRaw(id: id, currentRaw: homeCardOrderRaw)
        arrivingHomeCardId = id
        arrivalClearTask?.cancel()
        arrivalClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1500) {
            guard arrivingHomeCardId == id else { return }
            arrivingHomeCardId = nil
            arrivalClearTask = nil
        }
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

        if let plant = targetPlant(for: quest) {
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
                commandExecutor.recordMedicationDose(petID: petID, medicationID: medicationID)
                applyTodayFocusMutationFeedback(entityId: petID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
           let event = allEvents.first(where: { $0.id == eventId }) {
            let eventID = event.id
            enqueueHomeCommand(.todayFocus(entityID: eventID, action: "eventComplete")) {
                commandExecutor.completeTodayFocusEvent(eventID: eventID)
                applyTodayFocusMutationFeedback(entityId: eventID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if quest.id == "q_water_plant",
           let plant = targetPlant(for: quest) {
            let plantID = plant.id
            enqueueHomeCommand(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
                commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
                applyTodayFocusMutationFeedback(entityId: plantID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        if quest.id == "q_fertilize_plant",
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
            let petID = pet.id
            enqueueHomeCommand(.quickCare(entityID: petID, action: "potty")) {
                commandExecutor.applyPottyCheckIn(
                    raw: PottyType.perfectPoop.rawValue,
                    petID: petID,
                    executorId: currentExecutorId(),
                    feedback: applyQuickActionExecutorFeedback
                )
            }
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
            switch signal.healthAlertType {
            case .some(.weightGainAlert), .some(.weightLossAlert):
                routeCoordinator.openSheet(.petWeight(pet.id))
            case .some(.drinkingWeightAlert):
                routeCoordinator.openSheet(.petWater(pet.id))
            case .some(.noPotty):
                routeCoordinator.openSheet(.petPotty(pet.id))
            case .some(.noWalk):
                routeCoordinator.openSheet(.petWalkSummary(pet.id))
            case .some(.documentExpiringSoon):
                routeCoordinator.openSheet(.petAllFeatures(pet.id))
            default:
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: .preventive))
            }
            return
        }

        if signal.iconName.contains("fork.knife"),
           let pet = pets.first(where: { signal.title.contains($0.name) && !$0.hasPassedAway }) {
            routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
            return
        }

        if signal.iconName.contains("drop"),
           let pet = pets.first(where: { signal.title.contains($0.name) && !$0.hasPassedAway }) {
            routeCoordinator.openSheet(.petWater(pet.id))
            return
        }

        if signal.iconName.contains("triangle"),
           let pet = pets.first(where: { signal.title.contains($0.name) && !$0.hasPassedAway }) {
            routeCoordinator.openSheet(.petPotty(pet.id))
            return
        }

        openFunctionMenu(destination: .featureGroup(.healthBody))
    }

    func openTodayFocusFamilyTask(_: TodayFocusFamilyTaskSnapshot) {
        routeCoordinator.openCrewRoster(mode: .collaboration)
    }

    func confirmTodayFocusExchange(_ request: TodayFocusExchangeRequestSnapshot) {
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
            routeCoordinator.openAddEntity(humans.isEmpty ? .human : .pet)
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
        guard let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
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
        if quest.id == "q_walk" || quest.id == "q_potty" {
            return pets.first(where: { !$0.hasPassedAway })
        }
        return nil
    }

    func targetPlant(for quest: IslandQuest) -> Plant? {
        if let targetPlantId = quest.targetPlantId {
            return plants.first(where: { $0.id == targetPlantId })
        }
        switch quest.id {
        case "q_water_plant":
            return plants.first(where: { $0.needsWatering })
        case "q_fertilize_plant":
            return plants.first(where: { $0.needsFertilizing })
        default:
            return nil
        }
    }

    func openTodayFocusPlant(_ plant: Plant) {
        onOpenPlant(plant.id)
    }

    func todayFocusPetQuickKey(for quest: IslandQuest, pet: Pet) -> String {
        if quest.id.hasPrefix("q_feed_") { return "feed" }
        if quest.id.hasPrefix("q_water_") { return "water" }
        if quest.id == "q_walk" { return "walk" }
        if quest.id == "q_potty" {
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
        let pending = controller.snapshot.todayFocus.refreshedQuests.filter { !$0.isCompleted }
        if pending.count == 1,
           let finalQuest = pending.first,
           appServices.todayFocus.quest(finalQuest, matchesCompletedEntity: entityId) {
            _ = appServices.todayFocus.awardDailyCompletionIfNeeded(
                context: modelContext,
                executorId: currentExecutorId()
            )
        }
    }
}
