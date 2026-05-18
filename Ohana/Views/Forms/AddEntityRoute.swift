//
//  AddEntityRoute.swift
//  Ohana
//
//  Direct add-flow routing for the home/member FAB menus.
//

import SwiftUI

enum EntityType: String, CaseIterable, Identifiable {
    case pet
    case human
    case plant

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .human: return "person.fill"
        case .plant: return "leaf.fill"
        }
    }

    var emoji: String {
        switch self {
        case .pet: return "🐾"
        case .human: return "👤"
        case .plant: return "🌱"
        }
    }

    var color: Color {
        switch self {
        case .pet: return Color.goPrimary
        case .human: return Color(hex: "7DA2FF")
        case .plant: return Color.goTeal
        }
    }

    var isAvailable: Bool { true }
}

struct AddEntityDestinationView: View {
    let type: EntityType
    let onComplete: () -> Void
    var onPetSaved: ((Pet) -> Void)? = nil
    var onHumanSaved: ((Human) -> Void)? = nil

    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""

    var body: some View {
        switch type {
        case .pet:
            AddPetWizardView(
                onComplete: onComplete,
                onPetSaved: { pet in onPetSaved?(pet) }
            )
        case .human:
            AddHumanWizardView(
                onComplete: onComplete,
                onHumanSaved: { human in
                    currentActiveHumanId = human.id.uuidString
                    onHumanSaved?(human)
                }
            )
        case .plant:
            ZStack {
                OhanaAppBackground()
                AddPlantView(onComplete: onComplete)
            }
        }
    }
}
