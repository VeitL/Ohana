//
//  FocusHomeExpandedQuickRouteRouter.swift
//  Ohana
//
//  Route dispatch for expanded-card quick action taps and detail actions.
//

import Foundation

enum FocusHomeExpandedQuickRouteRouter {
    struct Actions {
        let showPrivacyAlert: () -> Void
        let humanWeightQuick: (Human) -> Void
        let humanWorkoutQuick: (Human) -> Void
        let humanMedicationAdd: (Human) -> Void
        let humanNoteQuick: (Human) -> Void
        let humanExpenseQuick: (Human) -> Void
        let humanWeightDetail: (Human) -> Void
        let humanWorkoutDetail: (Human) -> Void
        let humanMedicationDetail: (Human) -> Void
        let humanNoteDetail: (Human) -> Void
        let humanExpenseDetail: (Human) -> Void
        let humanAllFeatures: (Human) -> Void
        let selectHuman: (Human) -> Void
        let performPetAction: (String, Pet) -> Void
        let waterManagement: (Pet) -> Void
        let petWeightQuick: (Pet) -> Void
        let petExpenseQuick: (Pet) -> Void
        let petMomentQuick: (Pet) -> Void
        let petHealth: (Pet) -> Void
        let feedDetail: (Pet) -> Void
        let walk: (Pet) -> Void
        let playDetail: (Pet) -> Void
        let pottyDetail: (Pet) -> Void
        let hygiene: (Pet) -> Void
        let petMedication: (Pet) -> Void
        let petWeightDetail: (Pet) -> Void
        let petExpenseDetail: (Pet) -> Void
        let momentHistory: (Pet) -> Void
    }

    static func handleHuman(_ route: ExpandedHumanQuickRoute, human: Human, actions: Actions) {
        switch route {
        case .privacyAlert:
            actions.showPrivacyAlert()
        case .weightQuick:
            actions.humanWeightQuick(human)
        case .workoutQuick:
            actions.humanWorkoutQuick(human)
        case .medicationAdd:
            actions.humanMedicationAdd(human)
        case .noteQuick:
            actions.humanNoteQuick(human)
        case .expenseQuick:
            actions.humanExpenseQuick(human)
        case .weightDetail:
            actions.humanWeightDetail(human)
        case .workoutDetail:
            actions.humanWorkoutDetail(human)
        case .medicationDetail:
            actions.humanMedicationDetail(human)
        case .noteDetail:
            actions.humanNoteDetail(human)
        case .expenseDetail:
            actions.humanExpenseDetail(human)
        case .allFeatures:
            actions.humanAllFeatures(human)
        case .selectHuman:
            actions.selectHuman(human)
        case .none:
            break
        }
    }

    static func handlePetTap(_ route: ExpandedPetQuickTapRoute, pet: Pet, actions: Actions) {
        switch route {
        case .perform(let actionType):
            actions.performPetAction(actionType, pet)
        case .waterManagement:
            actions.waterManagement(pet)
        case .weight:
            actions.petWeightQuick(pet)
        case .expense:
            actions.petExpenseQuick(pet)
        case .moment:
            actions.petMomentQuick(pet)
        case .health:
            actions.petHealth(pet)
        case .none:
            break
        }
    }

    static func handlePetLongPress(_ route: ExpandedPetQuickLongPressRoute, pet: Pet, actions: Actions) {
        switch route {
        case .feedDetail:
            actions.feedDetail(pet)
        case .waterManagement:
            actions.waterManagement(pet)
        case .walk:
            actions.walk(pet)
        case .playDetail:
            actions.playDetail(pet)
        case .pottyDetail:
            actions.pottyDetail(pet)
        case .hygiene:
            actions.hygiene(pet)
        case .health:
            actions.petHealth(pet)
        case .medication:
            actions.petMedication(pet)
        case .weightDetail:
            actions.petWeightDetail(pet)
        case .expenseDetail:
            actions.petExpenseDetail(pet)
        case .momentHistory:
            actions.momentHistory(pet)
        case .none:
            break
        }
    }
}
