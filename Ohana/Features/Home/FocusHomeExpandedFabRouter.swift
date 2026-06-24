//
//  FocusHomeExpandedFabRouter.swift
//  Ohana
//
//  Stateless route dispatch for expanded-card FAB shortcuts.
//

import Foundation

enum FocusHomeExpandedFabRouter {
    struct Actions {
        let showPetAllFeatures: (UUID) -> Void
        let showHumanAllFeatures: (UUID) -> Void
        let openFeed: (UUID) -> Void
        let openWater: (UUID) -> Void
        let openWalk: (UUID) -> Void
        let openWalkSummary: (UUID) -> Void
        let openPotty: (UUID) -> Void
        let openPlay: (UUID) -> Void
        let openMedication: (UUID) -> Void
        let openHygiene: (UUID) -> Void
        let openMoment: (UUID) -> Void
        let openHealth: (UUID) -> Void
        let openWeight: (UUID) -> Void
        let openExpense: (UUID) -> Void
        let showHumanWeight: (UUID) -> Void
        let showHumanWorkout: (UUID) -> Void
        let showHumanMedication: (UUID) -> Void
        let showHumanNote: (UUID) -> Void
        let quickHumanExpense: (UUID) -> Void
        let showPrivacyAlert: () -> Void
    }

    static func open(
        _ item: ExpandedCardFabShortcut,
        card: FocusCard,
        interaction: HomeInteractionSnapshot,
        actions: Actions
    ) {
        switch item.action {
        case .allFeatures:
            if card.isHuman, interaction.containsHuman(card.id) {
                actions.showHumanAllFeatures(card.id)
            } else if interaction.pet(id: card.id) != nil {
                actions.showPetAllFeatures(card.id)
            }
        case .humanAllFeatures:
            if interaction.containsHuman(card.id) {
                actions.showHumanAllFeatures(card.id)
            }
        case let .quick(actionType):
            if interaction.activePet(id: card.id) != nil {
                openPetShortcut(actionType, petID: card.id, actions: actions)
            }
        case let .detail(feature):
            if interaction.activePet(id: card.id) != nil {
                openPetDetail(feature, petID: card.id, actions: actions)
            }
        case let .humanQuick(actionType):
            guard interaction.containsHuman(card.id) else { return }
            if interaction.expandedActions(for: card.id).statesByActionType[actionType]?.isLocked == true {
                actions.showPrivacyAlert()
                return
            }
            openHumanShortcut(actionType, humanID: card.id, actions: actions)
        }
    }

    static func openPetShortcut(_ actionType: String, petID: UUID, actions: Actions) {
        switch actionType {
        case "feed":
            actions.openFeed(petID)
        case "water", "waterChange", "filterClean":
            actions.openWater(petID)
        case "walk":
            actions.openWalk(petID)
        case "potty", "litter":
            actions.openPotty(petID)
        case "play":
            actions.openPlay(petID)
        case "medication":
            actions.openMedication(petID)
        case "groom":
            actions.openHygiene(petID)
        case "moment":
            actions.openMoment(petID)
        default:
            break
        }
    }

    static func openPetDetail(_ feature: PetFeature, petID: UUID, actions: Actions) {
        switch feature {
        case .health:
            actions.openHealth(petID)
        case .food:
            actions.openFeed(petID)
        case .hygiene:
            actions.openHygiene(petID)
        case .walks:
            actions.openWalkSummary(petID)
        case .potty:
            actions.openPotty(petID)
        case .weight:
            actions.openWeight(petID)
        case .expense:
            actions.openExpense(petID)
        case .retention, .basicInfo, .documents, .moments, .achievements, .medications:
            actions.showPetAllFeatures(petID)
        }
    }

    static func openHumanShortcut(_ actionType: String, humanID: UUID, actions: Actions) {
        switch actionType {
        case "humanWeight":
            actions.showHumanWeight(humanID)
        case "humanWorkout":
            actions.showHumanWorkout(humanID)
        case "humanMedication":
            actions.showHumanMedication(humanID)
        case "humanNote":
            actions.showHumanNote(humanID)
        case "humanExpense":
            actions.quickHumanExpense(humanID)
        default:
            actions.showHumanAllFeatures(humanID)
        }
    }
}
