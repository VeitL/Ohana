//
//  FocusHomeRouteSheetModifier+View.swift
//  Ohana
//
//  View convenience entry point for home route sheets.
//

import SwiftUI

extension View {
    func focusHomeRouteSheets(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        l: L10n,
        routes: HomeRouteCoordinator,
        activeHumanIdStr: Binding<String>,
        onAddEntityDismissed: @escaping () -> Void,
        onPetSavedFromAddEntity: @escaping (Pet) -> Void,
        onHumanSavedFromAddEntity: @escaping (Human) -> Void = { _ in },
        onCrewPetSelected: @escaping (Pet) -> Void,
        onCrewHumanSelected: @escaping (Human) -> Void,
        onFirstSuccessMomentCompleted: @escaping (Pet) -> Void,
        onHumanDoseTaken: @escaping (UUID) -> Void
    ) -> some View {
        modifier(FocusHomeRouteSheetModifier(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            l: l,
            routes: routes,
            activeHumanIdStr: activeHumanIdStr,
            onAddEntityDismissed: onAddEntityDismissed,
            onPetSavedFromAddEntity: onPetSavedFromAddEntity,
            onHumanSavedFromAddEntity: onHumanSavedFromAddEntity,
            onCrewPetSelected: onCrewPetSelected,
            onCrewHumanSelected: onCrewHumanSelected,
            onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
            onHumanDoseTaken: onHumanDoseTaken
        ))
    }
}
