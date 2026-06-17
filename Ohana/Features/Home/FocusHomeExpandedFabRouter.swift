//
//  FocusHomeExpandedFabRouter.swift
//  Ohana
//
//  Stateless route dispatch for expanded-card FAB shortcuts.
//

import Foundation

enum FocusHomeExpandedFabRouter {
    struct Actions {
        let showPetAllFeatures: (Pet) -> Void
        let showHumanAllFeatures: (Human) -> Void
        let openFeed: (Pet) -> Void
        let openWater: (Pet) -> Void
        let openWalk: (Pet) -> Void
        let openWalkSummary: (Pet) -> Void
        let openPotty: (Pet) -> Void
        let openPlay: (Pet) -> Void
        let openMedication: (Pet) -> Void
        let openHygiene: (Pet) -> Void
        let openMoment: (Pet) -> Void
        let openHealth: (Pet) -> Void
        let openWeight: (Pet) -> Void
        let openExpense: (Pet) -> Void
        let showHumanWeight: (Human) -> Void
        let showHumanWorkout: (Human) -> Void
        let showHumanMedication: (Human) -> Void
        let showHumanNote: (Human) -> Void
        let quickHumanExpense: (Human) -> Void
        let showPrivacyAlert: () -> Void
    }

    static func open(
        _ item: ExpandedCardFabShortcut,
        card: FocusCard,
        pets: [Pet],
        humans: [Human],
        activeHumanId: UUID?,
        privacy: HumanPrivacyManaging,
        actions: Actions
    ) {
        switch item.action {
        case .allFeatures:
            if let pet = pet(for: card, in: pets) {
                actions.showPetAllFeatures(pet)
            }
        case .humanAllFeatures:
            if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
                actions.showHumanAllFeatures(human)
            }
        case let .quick(actionType):
            if let pet = pet(for: card, in: pets) {
                openPetShortcut(actionType, pet: pet, actions: actions)
            }
        case let .detail(feature):
            if let pet = pet(for: card, in: pets) {
                openPetDetail(feature, pet: pet, actions: actions)
            }
        case let .humanQuick(actionType):
            if let human = humans.first(where: { $0.id == card.id }) {
                openHumanShortcut(actionType, human: human, activeHumanId: activeHumanId, privacy: privacy, actions: actions)
            }
        }
    }

    static func openPetShortcut(_ actionType: String, pet: Pet, actions: Actions) {
        switch actionType {
        case "feed":
            actions.openFeed(pet)
        case "water", "waterChange", "filterClean":
            actions.openWater(pet)
        case "walk":
            actions.openWalk(pet)
        case "potty", "litter":
            actions.openPotty(pet)
        case "play":
            actions.openPlay(pet)
        case "medication":
            actions.openMedication(pet)
        case "groom":
            actions.openHygiene(pet)
        case "moment":
            actions.openMoment(pet)
        default:
            break
        }
    }

    static func openPetDetail(_ feature: PetFeature, pet: Pet, actions: Actions) {
        switch feature {
        case .health:
            actions.openHealth(pet)
        case .food:
            actions.openFeed(pet)
        case .hygiene:
            actions.openHygiene(pet)
        case .walks:
            actions.openWalkSummary(pet)
        case .potty:
            actions.openPotty(pet)
        case .weight:
            actions.openWeight(pet)
        case .expense:
            actions.openExpense(pet)
        case .retention, .basicInfo, .documents, .moments, .achievements, .medications:
            actions.showPetAllFeatures(pet)
        }
    }

    static func openHumanShortcut(
        _ actionType: String,
        human: Human,
        activeHumanId: UUID?,
        privacy: HumanPrivacyManaging,
        actions: Actions
    ) {
        if let field = privacy.field(forHumanAction: actionType),
           privacy.isLocked(field, for: human, viewedBy: activeHumanId) {
            actions.showPrivacyAlert()
            return
        }

        switch actionType {
        case "humanWeight":
            actions.showHumanWeight(human)
        case "humanWorkout":
            actions.showHumanWorkout(human)
        case "humanMedication":
            actions.showHumanMedication(human)
        case "humanNote":
            actions.showHumanNote(human)
        case "humanExpense":
            actions.quickHumanExpense(human)
        default:
            actions.showHumanAllFeatures(human)
        }
    }

    private static func pet(for card: FocusCard, in pets: [Pet]) -> Pet? {
        pets.first { $0.id == card.id && !$0.hasPassedAway }
    }
}
