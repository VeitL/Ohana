//
//  FocusHomeTodayFocusRouter.swift
//  Ohana
//
//  Stateless routing decisions for Today Focus cards.
//

import Foundation

enum FocusHomeTodayFocusRouter {
    struct QuestActions {
        let presentAddEntity: (EntityType) -> Void
        let showOasis: () -> Void
        let openPetShortcut: (String, Pet) -> Void
        let openWalk: (Pet) -> Void
        let openPetWeight: (Pet) -> Void
        let openHumanWeight: (Human) -> Void
        let openPetMoment: (Pet) -> Void
        let selectPlant: (Plant) -> Void
        let openCalendar: () -> Void
        let selectPetOverview: (Pet) -> Void
        let openEvent: (Event) -> Void
        let completeMedicationDose: (Pet, UUID) -> Void
    }

    struct EventActions {
        let openHealth: (Pet, PetHealthInitialSection) -> Void
        let openMedication: (Pet) -> Void
    }

    struct NegativeSignalActions {
        let openHealth: (Pet, PetHealthInitialSection) -> Void
        let openWeight: (Pet) -> Void
        let expandPet: (Pet) -> Void
    }

    static func completeQuest(
        _ quest: IslandQuest,
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        events: [Event],
        actions: QuestActions
    ) {
        let activePets = pets.filter { !$0.hasPassedAway }

        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            switch quest.id {
            case IslandQuestEngine.oasisPetWizardQuestId:
                actions.presentAddEntity(humans.isEmpty ? .human : .pet)
            case IslandQuestEngine.oasisFirstMealQuestId:
                if let pet = activePets.first {
                    actions.openPetShortcut("feed", pet)
                } else {
                    actions.presentAddEntity(.pet)
                }
            default:
                actions.showOasis()
            }
            return
        }

        if quest.id.hasPrefix("q_feed_") {
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                actions.openPetShortcut("feed", pet)
            }
            return
        }

        if quest.id.hasPrefix("q_water_"), !quest.id.hasPrefix("q_water_plant") {
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                actions.openPetShortcut("water", pet)
            }
            return
        }

        switch quest.id {
        case "q_walk":
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                actions.openWalk(pet)
            }
        case "q_potty":
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                let actionType = (pet.species.contains("猫") || pet.species.contains("兔")) ? "litter" : "potty"
                actions.openPetShortcut(actionType, pet)
            }
        case let id where id.hasPrefix("q_play_"):
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                actions.openPetShortcut("play", pet)
            }
        case let id where id.hasPrefix("q_weight_"):
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                actions.openPetWeight(pet)
            }
        case let id where IslandQuestEngine.humanWeightId(fromQuestId: id) != nil:
            if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: id),
               let human = humans.first(where: { $0.id == humanId }) {
                actions.openHumanWeight(human)
            }
        case let id where id.hasPrefix("q_moment_"):
            if let pet = pet(matching: quest.targetPetId, in: activePets) {
                actions.openPetMoment(pet)
            }
        case "q_water_plant", "q_fertilize_plant":
            if let plant = plant(matching: quest.targetPlantId, in: plants) {
                actions.selectPlant(plant)
            }
        case "q_reminder":
            actions.openCalendar()
        case "q_visit":
            if let pet = pet(matching: quest.targetPetId, in: activePets) ?? activePets.first {
                actions.selectPetOverview(pet)
            }
        default:
            if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
               let event = events.first(where: { $0.id == eventId }) {
                actions.openEvent(event)
            } else if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
                for pet in activePets where pet.medications.contains(where: { $0.id == medicationId }) {
                    actions.completeMedicationDose(pet, medicationId)
                    break
                }
            }
        }
    }

    static func routeEventToFeature(
        _ event: Event,
        pets: [Pet],
        actions: EventActions
    ) -> Bool {
        let eventType = EventType(rawValue: event.eventType)
        let entityType = event.relatedEntityType.lowercased()

        if entityType == EntityKind.pet.rawValue.lowercased() || entityType == "pet",
           let petId = UUID(uuidString: event.relatedEntityId),
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            switch eventType {
            case .vaccine, .externalDeworming, .internalDeworming, .health, .vetVisit:
                actions.openHealth(pet, .preventive)
                return true
            default:
                break
            }
        }

        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased(),
           let medicationId = UUID(uuidString: event.relatedEntityId) {
            for pet in pets where !pet.hasPassedAway {
                if pet.medications.contains(where: { $0.id == medicationId }) {
                    actions.openMedication(pet)
                    return true
                }
            }
        }

        return false
    }

    static func petForNegativeSignal(
        _ signal: IslandNegativeSignal,
        pets: [Pet],
        activePet: Pet?
    ) -> Pet? {
        if let petId = signal.petId,
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            return pet
        }
        if let activePet {
            return activePet
        }
        return pets.first(where: { !$0.hasPassedAway })
    }

    static func handleNegativeSignal(
        _ signal: IslandNegativeSignal,
        pet: Pet,
        actions: NegativeSignalActions
    ) {
        if let alertType = signal.healthAlertType {
            switch alertType {
            case .checkupOverdue, .vaccineExpired, .vaccineExpiringSoon, .dewormingDue:
                actions.openHealth(pet, .preventive)
            case .weightGainAlert, .weightLossAlert:
                actions.openWeight(pet)
            case .drinkingWeightAlert:
                actions.openHealth(pet, .symptomVisit)
            default:
                actions.openHealth(pet, .symptomVisit)
            }
            return
        }

        actions.expandPet(pet)
    }

    private static func pet(matching id: UUID?, in pets: [Pet]) -> Pet? {
        guard let id else { return nil }
        return pets.first { $0.id == id }
    }

    private static func plant(matching id: UUID?, in plants: [Plant]) -> Plant? {
        guard let id else { return nil }
        return plants.first { $0.id == id }
    }
}
