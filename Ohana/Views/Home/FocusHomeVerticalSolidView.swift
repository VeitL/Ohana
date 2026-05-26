//
//  FocusHomeVerticalSolidView.swift
//  Ohana
//
//  Real-data portrait solid home style.
//

import SwiftUI

struct FocusHomeVerticalSolidView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    let heroNS: Namespace.ID

    var body: some View {
        HomeDataContainer(
            selectedPet: $selectedPet,
            selectedHuman: $selectedHuman,
            selectedPlant: $selectedPlant,
            selectedPetTab: $selectedPetTab,
            heroNS: heroNS
        )
    }
}
