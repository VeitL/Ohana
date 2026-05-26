//
//  FocusHomeQuickRecordOverlayLayer.swift
//  Ohana
//
//  Inline record popups launched from expanded quick actions.
//

import SwiftUI

enum FocusHomeOverlayState {
    static func hasInlineRecordOverlay(
        router: HomeRouteCoordinator,
        quickActionMenu: ExpandedQuickActionMenuTarget?
    ) -> Bool {
        router.hasActiveOverlay || quickActionMenu != nil
    }
}

struct FocusHomeQuickRecordOverlayLayer: View {
    @ObservedObject var router: HomeRouteCoordinator
    let pets: [Pet]
    let humans: [Human]
    let preselectedPayerId: String?

    let onPetWeightRewarded: (UUID, Int) -> Void
    let onPetExpenseRewarded: (UUID, Int) -> Void
    let onHumanSaved: (UUID, String) -> Void
    let onManageHumanMedication: (Human) -> Void
    let onPetMedicationSaved: (Pet) -> Void

    var body: some View {
        OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: router.hasActiveOverlay) {
            if let route = router.popup {
                popupContent(for: route)
            }
        }
    }

    @ViewBuilder
    private func popupContent(for route: HomePopupRoute) -> some View {
        switch route {
        case .petWeight(_, let petID):
            if let pet = pets.first(where: { $0.id == petID }) {
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    onRewarded: { delta in onPetWeightRewarded(pet.id, delta) },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(1)
            }
        case .petExpense(_, let petID):
            if let pet = pets.first(where: { $0.id == petID }) {
                AddExpenseSheet(
                    pet: pet,
                    preselectedPayerId: preselectedPayerId,
                    onRewarded: { delta in onPetExpenseRewarded(pet.id, delta) },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(2)
            }
        case .humanWeight(_, let humanID, let actionType):
            if let human = humans.first(where: { $0.id == humanID }) {
                GenericWeightEntrySheet(
                    target: .human(human),
                    onSaved: { onHumanSaved(human.id, "\(human.id.uuidString):\(actionType)") },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(3)
            }
        case .humanExpense(_, let humanID, let actionType):
            if let human = humans.first(where: { $0.id == humanID }) {
                QuickHumanExpenseSheet(
                    human: human,
                    onSaved: { onHumanSaved(human.id, "\(human.id.uuidString):\(actionType)") },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(4)
            }
        case .humanNote(_, let humanID, let actionType):
            if let human = humans.first(where: { $0.id == humanID }) {
                QuickHumanNoteSheet(
                    human: human,
                    onSaved: { onHumanSaved(human.id, "\(human.id.uuidString):\(actionType)") },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(5)
            }
        case .humanWorkout(_, let humanID, let actionType):
            if let human = humans.first(where: { $0.id == humanID }) {
                QuickHumanWorkoutSheet(
                    human: human,
                    onSaved: { onHumanSaved(human.id, "\(human.id.uuidString):\(actionType)") },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(6)
            }
        case .humanMedication(_, let humanID, let actionType):
            if let human = humans.first(where: { $0.id == humanID }) {
                QuickHumanMedicationSheet(
                    human: human,
                    onSaved: { onHumanSaved(human.id, "\(human.id.uuidString):\(actionType)") },
                    onManage: { onManageHumanMedication(human) },
                    onDismiss: { router.dismissPopup(routeID: route.id) }
                )
                .id(route.id)
                .zIndex(7)
            }
        case .petMedication(_, let petID):
            if let pet = pets.first(where: { $0.id == petID }) {
                PetMedicationQuickRecordPopupLayer(
                    pet: pet,
                    onClose: { router.dismissPopup(routeID: route.id) },
                    onSaved: {
                        onPetMedicationSaved(pet)
                        router.dismissPopup(routeID: route.id)
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
