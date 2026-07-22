//
//  AddEntityRoute.swift
//  Ohana
//
//  Direct add-flow routing for the home/member FAB menus.
//

import SwiftData
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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @State private var petEntryState = PetCreationEntryState.checking

    var body: some View {
        switch type {
        case .pet:
            petDestination
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

    @ViewBuilder
    private var petDestination: some View {
        Group {
            switch petEntryState {
            case .checking:
                ZStack {
                    OhanaAppBackground()
                    ProgressView()
                        .tint(Color.goPrimary)
                        .accessibilityLabel(l.tr(
                            zh: "正在检查 Personal 额度",
                            en: "Checking Personal allowance",
                            de: "Personal-Limit wird geprüft"
                        ))
                }
            case .allowed:
                AddPetWizardView(
                    onComplete: onComplete,
                    onCancel: onComplete,
                    onPetSaved: { pet in onPetSaved?(pet) }
                )
            case let .upgradeRequired(denial):
                PersonalPlanView(prompt: PersonalUpgradePrompt(denial: denial))
            case .failed:
                petEntryFailure
            }
        }
        .task(id: appServices.commerce.personalAccessLevel) {
            evaluatePetCreationAccess()
        }
    }

    private var petEntryFailure: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative failure glyph is hidden by the chained modifier below
                    .font(OhanaFont.title(.bold))
                    .foregroundStyle(Color.goOrange)
                    .accessibilityHidden(true)
                Text(l.tr(
                    zh: "暂时无法检查宠物额度",
                    en: "Pet allowance is temporarily unavailable",
                    de: "Das Tierlimit ist vorübergehend nicht verfügbar"
                ))
                .font(OhanaFont.body(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)

                Button {
                    evaluatePetCreationAccess()
                } label: {
                    Label(l.tr(zh: "重试", en: "Try again", de: "Erneut versuchen"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.goPrimary)
                .accessibilityIdentifier("member-pet-entry-retry")

                Button(l.cancel) {
                    onComplete()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: 340)
            .padding(24)
        }
    }

    private var l: L10n { L10n(appLanguage) }

    private func evaluatePetCreationAccess() {
        petEntryState = .checking
        do {
            if let denial = try appServices.memberCreation.creationAccessDenial(
                kind: .pet,
                context: modelContext
            ) {
                petEntryState = .upgradeRequired(denial)
            } else {
                petEntryState = .allowed
            }
        } catch {
            petEntryState = .failed
        }
    }
}

private enum PetCreationEntryState {
    case checking
    case allowed
    case upgradeRequired(PersonalFreeLimitDenial)
    case failed
}
