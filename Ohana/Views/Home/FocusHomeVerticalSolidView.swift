//
//  FocusHomeVerticalSolidView.swift
//  Ohana
//
//  Real-data portrait solid home style. It reuses the Home V3 data and routing
//  shell, and swaps only the visual card scene.
//

import SwiftUI

struct FocusHomeVerticalSolidView: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    let heroNS: Namespace.ID

    var body: some View {
        FocusHomeV3View(
            selectedPet: $selectedPet,
            selectedHuman: $selectedHuman,
            selectedPlant: $selectedPlant,
            selectedPetTab: $selectedPetTab,
            heroNS: heroNS,
            sceneStyle: .verticalSolid
        )
    }
}
