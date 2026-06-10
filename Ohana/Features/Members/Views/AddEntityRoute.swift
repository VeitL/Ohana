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
            false
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

    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"

    var body: some View {
        let l = L10n(appLanguage)
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
                    currentActiveHumanId = human.id.uuidString
                    onHumanSaved?(human)
                }
            )
        case .plant:
            ZStack {
                OhanaAppBackground()
                VStack(spacing: 12) {
                    Image(systemName: "leaf") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                        .font(.system(size: 30, weight: .semibold)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.tr(
                        zh: "植物模块暂不开放",
                        en: "Plants are hidden in this version.",
                        de: "Pflanzen sind in dieser Version ausgeblendet."
                    ))
                    .font(.headline)
                    .foregroundStyle(Color.ohanaPrimaryText)
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schließen"), action: onComplete)
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
            }
        }
    }
}
