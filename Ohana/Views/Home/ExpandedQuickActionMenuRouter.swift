//
//  ExpandedQuickActionMenuRouter.swift
//  Ohana
//
//  Keeps quick-action menu decisions out of the home view body.
//

import Foundation

enum ExpandedQuickActionMenuRouter {
    struct PetActions {
        let detail: (QuickActionItem, Pet) -> Void
        let quick: (QuickActionItem, Pet) -> Void
        let medicationAdd: (Pet) -> Void
        let groomOption: (String, Pet) -> Void
        let pottyOption: (String, Pet) -> Void
    }

    struct HumanActions {
        let quick: (QuickActionItem, Human) -> Void
    }

    static func runPetPrimary(
        _ item: QuickActionItem,
        pet: Pet,
        localization: L10n,
        actions: PetActions
    ) {
        if !ExpandedQuickActionMenuPolicy.petOptions(for: item, l: localization).isEmpty {
            actions.detail(item, pet)
            return
        }

        if item.actionType == "medication" {
            actions.medicationAdd(pet)
            return
        }

        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case .waterManagement, .health, .none:
            actions.detail(item, pet)
        default:
            actions.quick(item, pet)
        }
    }

    static func runPetOption(
        _ optionId: String,
        item: QuickActionItem,
        pet: Pet,
        actions: PetActions
    ) {
        switch item.actionType {
        case "groom":
            actions.groomOption(optionId, pet)
        case "potty":
            actions.pottyOption(optionId, pet)
        default:
            break
        }
    }

    static func runHumanPrimary(
        _ item: QuickActionItem,
        human: Human,
        actions: HumanActions
    ) {
        actions.quick(item, human)
    }
}
