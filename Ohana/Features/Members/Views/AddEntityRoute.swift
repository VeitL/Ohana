//
//  AddEntityRoute.swift
//  Ohana
//
//  Direct add-flow routing for the home/member FAB menus.
//

import SwiftUI

enum EntityType: String, CaseIterable, Hashable, Identifiable {
    case pet
    case human
    case plant

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pet: "pawprint.fill"
        case .human: "person.fill"
        case .plant: "leaf.fill"
        }
    }

    var emoji: String {
        switch self {
        case .pet: "🐾"
        case .human: "👤"
        case .plant: "🌱"
        }
    }

    var color: Color {
        switch self {
        case .pet: Color.goPrimary
        case .human: Color(hex: "7DA2FF")
        case .plant: Color.goTeal
        }
    }

    var isAvailable: Bool {
        switch self {
        case .plant:
            PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel)
        case .pet, .human:
            true
        }
    }
}

struct AddEntityDestinationView: View {
    let type: EntityType
    let onComplete: () -> Void
    var onPetSaved: ((Pet) -> Void)?
    var onHumanSaved: ((Human) -> Void)?
    var onPlantSaved: ((UUID) -> Void)?

    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""

    var body: some View {
        switch type {
        case .pet:
            AddPetWizardView(
                onComplete: onComplete,
                onCancel: onComplete,
                onPetSaved: { pet in onPetSaved?(pet) }
            )
        case .human:
            AddHumanWizardView(
                onComplete: onComplete,
                onCancel: onComplete,
                onHumanSaved: { human in
                    currentActiveHumanId = ActiveHumanSelectionPolicy.activeHumanIdAfterCreatingHuman(
                        currentHumanIdRaw: currentActiveHumanId,
                        createdHumanId: human.id
                    )
                    onHumanSaved?(human)
                }
            )
        case .plant:
            AddPlantDataContainer(
                onComplete: onComplete,
                onPlantSaved: onPlantSaved
            )
        }
    }
}
