//
//  FocusHomeQuickRecordOverlayLayer.swift
//  Ohana
//
//  Inline record popups launched from expanded quick actions.
//

import SwiftUI

enum FocusHomeOverlayState {
    static func hasInlineRecordOverlay(
        petWeight: ExpandedQuickPetRecordRoute?,
        petExpense: ExpandedQuickPetRecordRoute?,
        humanWeight: ExpandedQuickHumanRecordRoute?,
        humanWorkout: ExpandedQuickHumanRecordRoute?,
        humanMedication: ExpandedQuickHumanRecordRoute?,
        petMedication: ExpandedQuickPetRecordRoute?,
        humanNote: ExpandedQuickHumanRecordRoute?,
        humanExpense: ExpandedQuickHumanRecordRoute?,
        quickActionMenu: ExpandedQuickActionMenuTarget?
    ) -> Bool {
        petWeight != nil
        || petExpense != nil
        || humanWeight != nil
        || humanWorkout != nil
        || humanMedication != nil
        || petMedication != nil
        || humanNote != nil
        || humanExpense != nil
        || quickActionMenu != nil
    }
}

struct FocusHomeQuickRecordOverlayLayer: View {
    let petWeight: ExpandedQuickPetRecordRoute?
    let petExpense: ExpandedQuickPetRecordRoute?
    let humanWeight: ExpandedQuickHumanRecordRoute?
    let humanWorkout: ExpandedQuickHumanRecordRoute?
    let humanMedication: ExpandedQuickHumanRecordRoute?
    let petMedication: ExpandedQuickPetRecordRoute?
    let humanNote: ExpandedQuickHumanRecordRoute?
    let humanExpense: ExpandedQuickHumanRecordRoute?
    let preselectedPayerId: String?

    let onPetWeightRewarded: (UUID, Int) -> Void
    let onPetExpenseRewarded: (UUID, Int) -> Void
    let onHumanSaved: (UUID, String) -> Void
    let onManageHumanMedication: (Human) -> Void
    let onPetMedicationSaved: (Pet) -> Void

    let dismissPetWeight: (UUID) -> Void
    let dismissPetExpense: (UUID) -> Void
    let dismissHumanWeight: (UUID) -> Void
    let dismissHumanWorkout: (UUID) -> Void
    let dismissHumanMedication: (UUID) -> Void
    let dismissPetMedication: (UUID) -> Void
    let dismissHumanNote: (UUID) -> Void
    let dismissHumanExpense: (UUID) -> Void

    var body: some View {
        ZStack {
            if let route = petWeight {
                let pet = route.pet
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    onRewarded: { delta in
                        onPetWeightRewarded(pet.id, delta)
                    },
                    onDismiss: {
                        dismissPetWeight(route.id)
                    }
                )
                .id(route.id)
                .zIndex(1)
            }

            if let route = petExpense {
                let pet = route.pet
                AddExpenseSheet(
                    pet: pet,
                    preselectedPayerId: preselectedPayerId,
                    onRewarded: { delta in
                        onPetExpenseRewarded(pet.id, delta)
                    },
                    onDismiss: {
                        dismissPetExpense(route.id)
                    }
                )
                .id(route.id)
                .zIndex(2)
            }

            if let route = humanWeight {
                let human = route.human
                GenericWeightEntrySheet(
                    target: .human(human),
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        dismissHumanWeight(route.id)
                    }
                )
                .id(route.id)
                .zIndex(3)
            }

            if let route = humanExpense {
                let human = route.human
                QuickHumanExpenseSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        dismissHumanExpense(route.id)
                    }
                )
                .id(route.id)
                .zIndex(4)
            }

            if let route = humanNote {
                let human = route.human
                QuickHumanNoteSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        dismissHumanNote(route.id)
                    }
                )
                .id(route.id)
                .zIndex(5)
            }

            if let route = humanWorkout {
                let human = route.human
                QuickHumanWorkoutSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        dismissHumanWorkout(route.id)
                    }
                )
                .id(route.id)
                .zIndex(6)
            }

            if let route = humanMedication {
                let human = route.human
                QuickHumanMedicationSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onManage: {
                        onManageHumanMedication(human)
                    },
                    onDismiss: {
                        dismissHumanMedication(route.id)
                    }
                )
                .id(route.id)
                .zIndex(7)
            }

            if let route = petMedication {
                let pet = route.pet
                AddPetMedicationSheet(
                    pet: pet,
                    isInlinePopup: true,
                    onClose: {
                        dismissPetMedication(route.id)
                    },
                    onSaved: {
                        onPetMedicationSaved(pet)
                        dismissPetMedication(route.id)
                    }
                )
                .id(route.id)
                .zIndex(8)
            }
        }
    }
}
