//
//  FocusHomeView+TodayFocus.swift
//  Ohana
//
//  Split FocusHomeView responsibilities.
//

import SwiftUI

extension FocusHomeView {
    func openTodayFocusQuestDetail(_ quest: IslandQuest) {
        routeTodayFocusQuest(quest, prefersDirectCompletion: false)
    }

    func completeTodayFocusQuest(_ quest: IslandQuest) {
        routeTodayFocusQuest(quest, prefersDirectCompletion: true)
    }

    func routeTodayFocusQuest(_ quest: IslandQuest, prefersDirectCompletion: Bool) {
        let activePets = pets.filter { !$0.hasPassedAway }

        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            switch quest.id {
            case IslandQuestEngine.oasisPetWizardQuestId:
                routeCoordinator.openAddEntity(humans.isEmpty ? .human : .pet)
            case IslandQuestEngine.oasisFirstMealQuestId:
                if let pet = activePets.first {
                    if prefersDirectCompletion {
                        performTodayFocusPetAction("feed", pet: pet)
                    } else {
                        routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false))
                    }
                } else {
                    routeCoordinator.openAddEntity(.pet)
                }
            default:
                routeCoordinator.openOasisReward()
            }
            return
        }

        if quest.id.hasPrefix("q_feed_"), let pet = todayFocusPet(for: quest, in: activePets) {
            prefersDirectCompletion ? performTodayFocusPetAction("feed", pet: pet) : (routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: false)))
            return
        }

        if quest.id.hasPrefix("q_water_"), !quest.id.hasPrefix("q_water_plant"), let pet = todayFocusPet(for: quest, in: activePets) {
            prefersDirectCompletion ? performTodayFocusPetAction("water", pet: pet) : (routeCoordinator.openSheet(.petWater(pet.id)))
            return
        }

        switch quest.id {
        case "q_walk":
            if let pet = todayFocusPet(for: quest, in: activePets) {
                routeCoordinator.openWalk(pet)
            }
        case "q_potty":
            if let pet = todayFocusPet(for: quest, in: activePets) {
                let isSharedLitterPet = pet.species.contains("猫") || pet.species.contains("兔")
                if prefersDirectCompletion {
                    isSharedLitterPet ? performTodayFocusPetAction("litter", pet: pet) : performTodayFocusPottyCheckIn(pet)
                } else {
                    isSharedLitterPet ? (routeCoordinator.openSheet(.petLitter(pet.id))) : (routeCoordinator.openSheet(.petPotty(pet.id)))
                }
            }
        case let id where id.hasPrefix("q_play_"):
            if let pet = todayFocusPet(for: quest, in: activePets) {
                prefersDirectCompletion ? performTodayFocusPetAction("play", pet: pet) : (routeCoordinator.openSheet(.petPlay(pet.id)))
            }
        case let id where id.hasPrefix("q_weight_"):
            if let pet = todayFocusPet(for: quest, in: activePets) {
                routeCoordinator.openSheet(.petWeight(pet.id))
            }
        case let id where IslandQuestEngine.humanWeightId(fromQuestId: id) != nil:
            if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: id),
               let human = humans.first(where: { $0.id == humanId })
            {
                openTodayFocusHumanWeight(human)
            }
        case let id where id.hasPrefix("q_moment_"):
            if let pet = todayFocusPet(for: quest, in: activePets) {
                routeCoordinator.openSheet(.petMomentHistory(pet.id))
            }
        case "q_water_plant", "q_fertilize_plant":
            if let plant = todayFocusPlant(for: quest) {
                selectedPlant = plant
            }
        case "q_reminder":
            openHeaderCalendarDestination()
        case "q_visit":
            if let pet = todayFocusPet(for: quest, in: activePets) ?? activePets.first {
                routeCoordinator.openSheet(.petHealth(pet.id, initialSection: .symptomVisit))
            }
        default:
            if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
               let event = allEvents.first(where: { $0.id == eventId })
            {
                prefersDirectCompletion ? completeTodayFocusEvent(event) : openTodayFocusEvent(event)
            } else if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id),
                      let pet = activePets.first(where: { $0.medications.contains(where: { $0.id == medicationId }) })
            {
                prefersDirectCompletion ? performTodayFocusMedicationDose(pet: pet, medicationId: medicationId) : (routeCoordinator.openSheet(.petMedication(pet.id)))
            }
        }
    }

    func todayFocusPet(for quest: IslandQuest, in activePets: [Pet]) -> Pet? {
        guard let target = quest.targetPetId else { return activePets.first }
        return activePets.first { $0.id == target }
    }

    func todayFocusPlant(for quest: IslandQuest) -> Plant? {
        guard let target = quest.targetPlantId else { return plants.first }
        return plants.first { $0.id == target }
    }

    func performTodayFocusPetAction(_ actionType: String, pet: Pet) {
        commandExecutor.performActionType(
            actionType,
            pet: pet,
            executorId: currentExecutorId(),
            allEvents: allEvents,
            allFeedCareLogs: pet.careLogs,
            humans: humans,
            now: Date(),
            antiRepeatTitle: l.tr(zh: "刚刚已经记录过", en: "Already logged", de: "Bereits erfasst"),
            antiRepeatMessage: { warning in
                l.tr(
                    zh: "\(warning.executorName) \(warning.minutesAgo)分钟前刚记录过，确定再记一次吗？",
                    en: "\(warning.executorName) logged this \(warning.minutesAgo)m ago. Log again?",
                    de: "\(warning.executorName) hat das vor \(warning.minutesAgo) Min. erfasst. Erneut erfassen?"
                )
            },
            openFeedDetail: { opensManualSheet in
                routeCoordinator.openSheet(.petFeed(pet.id, opensManualSheet: opensManualSheet))
            },
            completePlannedFeed: completeTodayFocusPlannedFeed,
            showAntiRepeat: { title, message, pendingAction in
                routeCoordinator.showAntiRepeat(
                    title: title,
                    message: message,
                    pendingAction: pendingAction
                )
            },
            startWalk: startWalkInExpandedCard,
            openWaterManagement: { routeCoordinator.openSheet(.petWater($0.id)) },
            openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) },
            feedback: applyTodayFocusExecutorFeedback
        )
    }

    func completeTodayFocusPlannedFeed(_ pet: Pet) -> Bool {
        guard let reminder = ExpandedQuickActionLogic.pendingFeedReminder(
            for: pet,
            allEvents: allEvents,
            allFeedCareLogs: pet.careLogs,
            now: Date()
        ) else {
            return false
        }

        let reward = commandExecutor.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            executorId: currentExecutorId()
        )
        let delta = (reward?.humanGot ?? 0) + (reward?.petGot ?? 0)
        applyTodayFocusExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(
                cardId: pet.id,
                coconutDelta: delta,
                label: delta > 0 ? "喂食 +\(delta)🥥" : nil
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    func performTodayFocusPottyCheckIn(_ pet: Pet) {
        commandExecutor.applyPottyCheckIn(
            raw: PottyType.perfectPoop.rawValue,
            pet: pet,
            executorId: currentExecutorId(),
            feedback: applyTodayFocusExecutorFeedback
        )
    }

    func performTodayFocusMedicationDose(pet: Pet, medicationId: UUID) {
        guard let medication = pet.medications.first(where: { $0.id == medicationId }) else {
            routeCoordinator.openSheet(.petMedication(pet.id))
            return
        }
        commandExecutor.recordMedicationDose(medication: medication, pet: pet)
        applyTodayFocusExecutorFeedback(
            ExpandedQuickActionExecutor.Feedback(cardId: pet.id, coconutDelta: 1, label: "用药 +1🥥")
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func completeTodayFocusEvent(_ event: Event) {
        commandExecutor.completeTodayFocusEvent(event)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func applyTodayFocusExecutorFeedback(_ feedback: ExpandedQuickActionExecutor.Feedback) {
        requestSnapshotRefresh()
        if feedback.coconutDelta > 0 {
            showReward(amount: feedback.coconutDelta, label: feedback.label, cardId: feedback.cardId)
        }
    }

    func openTodayFocusHumanWeight(_ human: Human) {
        guard !PrivacyService.isLocked(.weight, for: human, viewedBy: UUID(uuidString: activeHumanIdStr)) else {
            routeCoordinator.showHumanPrivacy()
            return
        }
        routeCoordinator.openSheet(.humanWeight(human.id))
    }

    func openTodayFocusEvent(_ event: Event) {
        if routeTodayFocusEventToFeature(event) {
            return
        }
        routeCoordinator.openCalendar(entityID: event.relatedEntityId, humanID: nil)
    }

    func routeTodayFocusEventToFeature(_ event: Event) -> Bool {
        FocusHomeTodayFocusRouter.routeEventToFeature(
            event,
            pets: pets,
            actions: FocusHomeTodayFocusRouter.EventActions(
                openHealth: { pet, section in
                    routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
                },
                openMedication: { routeCoordinator.openSheet(.petMedication($0.id)) }
            )
        )
    }

    func openFamilyTaskFromTodayFocus(_ task: FamilyCollaborationTask) {
        if let petId = task.relatedPetId,
           let petUUID = UUID(uuidString: petId),
           let pet = pets.first(where: { $0.id == petUUID && !$0.hasPassedAway })
        {
            if let eventId = task.relatedEventId,
               let eventUUID = UUID(uuidString: eventId),
               let event = allEvents.first(where: { $0.id == eventUUID })
            {
                openTodayFocusEvent(event)
            } else {
                selectedPetTab = .overview
                selectedPet = pet
            }
            return
        }
        routeCoordinator.openCrewRoster()
    }

    func confirmTodayFocusExchange(_ request: CoconutExchangeRequest) {
        guard let receiver = activeHuman else { return }
        do {
            try commandExecutor.confirmCoconutExchange(request, receiver: receiver)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            requestSnapshotRefresh()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func handleTodayFocusNegativeSignal(_ signal: IslandNegativeSignal) {
        guard let pet = FocusHomeTodayFocusRouter.petForNegativeSignal(
            signal,
            pets: pets,
            activePet: activePetForFocus
        ) else { return }

        FocusHomeTodayFocusRouter.handleNegativeSignal(
            signal,
            pet: pet,
            actions: FocusHomeTodayFocusRouter.NegativeSignalActions(
                openHealth: { pet, section in
                    routeCoordinator.openSheet(.petHealth(pet.id, initialSection: section))
                },
                openWeight: { routeCoordinator.openSheet(.petWeight($0.id)) },
                expandPet: { expandWalletToCard(id: $0.id) }
            )
        )
    }

}
