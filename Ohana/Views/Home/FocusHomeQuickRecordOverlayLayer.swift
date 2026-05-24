//
//  FocusHomeQuickRecordOverlayLayer.swift
//  Ohana
//
//  Inline record popups launched from expanded quick actions.
//

import SwiftUI

enum FocusHomeOverlayState {
    static func hasInlineRecordOverlay(
        router: FocusHomeQuickRecordRouter,
        quickActionMenu: ExpandedQuickActionMenuTarget?
    ) -> Bool {
        router.hasActiveOverlay || quickActionMenu != nil
    }
}

struct FocusHomeQuickRecordOverlayLayer: View {
    @ObservedObject var router: FocusHomeQuickRecordRouter
    let preselectedPayerId: String?

    let onPetWeightRewarded: (UUID, Int) -> Void
    let onPetExpenseRewarded: (UUID, Int) -> Void
    let onHumanSaved: (UUID, String) -> Void
    let onManageHumanMedication: (Human) -> Void
    let onPetMedicationSaved: (Pet) -> Void

    var body: some View {
        OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: router.hasActiveOverlay) {
            if let route = router.petWeight {
                let pet = route.pet
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    onRewarded: { delta in
                        onPetWeightRewarded(pet.id, delta)
                    },
                    onDismiss: {
                        router.dismissPetWeight(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(1)
            }

            if let route = router.petExpense {
                let pet = route.pet
                AddExpenseSheet(
                    pet: pet,
                    preselectedPayerId: preselectedPayerId,
                    onRewarded: { delta in
                        onPetExpenseRewarded(pet.id, delta)
                    },
                    onDismiss: {
                        router.dismissPetExpense(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(2)
            }

            if let route = router.humanWeight {
                let human = route.human
                GenericWeightEntrySheet(
                    target: .human(human),
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        router.dismissHumanWeight(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(3)
            }

            if let route = router.humanExpense {
                let human = route.human
                QuickHumanExpenseSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        router.dismissHumanExpense(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(4)
            }

            if let route = router.humanNote {
                let human = route.human
                QuickHumanNoteSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        router.dismissHumanNote(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(5)
            }

            if let route = router.humanWorkout {
                let human = route.human
                QuickHumanWorkoutSheet(
                    human: human,
                    onSaved: {
                        onHumanSaved(human.id, route.actionKey)
                    },
                    onDismiss: {
                        router.dismissHumanWorkout(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(6)
            }

            if let route = router.humanMedication {
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
                        router.dismissHumanMedication(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(7)
            }

            if let route = router.petMedication {
                let pet = route.pet
                PetMedicationQuickRecordPopupLayer(
                    pet: pet,
                    onClose: {
                        router.dismissPetMedication(routeID: route.id)
                    },
                    onSaved: {
                        onPetMedicationSaved(pet)
                        router.dismissPetMedication(routeID: route.id)
                    }
                )
                .id(route.id)
                .zIndex(8)
            }
        }
    }
}

private struct PetMedicationQuickRecordPopupLayer: View {
    let pet: Pet
    let onClose: () -> Void
    let onSaved: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.14 : 0.07), // ui-v4: allow modal scrim
                        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.20) // ui-v4: allow modal scrim
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

                AddPetMedicationSheet(
                    pet: pet,
                    isInlinePopup: true,
                    onClose: onClose,
                    onSaved: onSaved
                )
                .frame(maxHeight: min(proxy.size.height * 0.88, 690))
                .padding(.horizontal, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8) + 6)
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
