//
//  PetDetailSheetRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for pet detail sheets.
//

import SwiftData
import SwiftUI

enum AppPetDetailSheetDestination: Hashable {
    case allFeatures
    case basicInfo
    case food
    case weight
    case expense
    case feed(Bool)
    case water
    case potty
    case litter
    case play
    case hygiene
    case walkSummary
    case health(PetHealthInitialSection?)
    case medication
    case momentHistory
    case documents
    case achievements
    case retention
    case bondVault
}

struct AppPetDetailSheetRouteContainer: View {
    @Query private var pets: [Pet]
    let destination: AppPetDetailSheetDestination
    let onMissing: () -> Void
    let onDismiss: () -> Void
    let onOpenFeatureDestination: ((UUID, PetAllFeatureDestination) -> Void)?
    let onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    init(
        id: UUID,
        destination: AppPetDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {},
        onOpenFeatureDestination: ((UUID, PetAllFeatureDestination) -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil
    ) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.destination = destination
        self.onMissing = onMissing
        self.onDismiss = onDismiss
        self.onOpenFeatureDestination = onOpenFeatureDestination
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        if let pet = pets.first {
            petDestination(for: pet)
        } else {
            PetRouteMissingEntityView(kind: "pet")
                .onAppear(perform: onMissing)
        }
    }

    @ViewBuilder
    private func petDestination(for pet: Pet) -> some View {
        switch destination {
        case .allFeatures:
            PetAllFeaturesSheet(
                pet: pet,
                onOpenDestination: { destination in
                    onOpenFeatureDestination?(pet.id, destination)
                }
            )
        case .basicInfo:
            NavigationStack { PetBasicInfoDetailView(pet: pet) }
        case .food:
            NavigationStack { PetFoodManagementView(pet: pet) }
        case .weight:
            NavigationStack { WeightHistoryView(pet: pet) }
        case .expense:
            NavigationStack { ExpenseHistoryView(pet: pet) }
        case let .feed(opensManualSheet):
            QuickFeedDetailRouteContainer(
                id: pet.id,
                onRemove: onDismiss,
                onClose: onDismiss,
                opensManualSheetOnAppear: opensManualSheet
            )
        case .water:
            QuickWaterDetailRouteContainer(id: pet.id, onRemove: onDismiss, onClose: onDismiss)
        case .potty:
            QuickPottyDetailRouteContainer(id: pet.id, onRemove: onDismiss, onClose: onDismiss)
        case .litter:
            QuickPottyDetailRouteContainer(id: pet.id, onRemove: onDismiss, onClose: onDismiss)
        case .play:
            QuickPlayDetailRouteContainer(id: pet.id, onRemove: onDismiss, onClose: onDismiss)
        case .hygiene:
            NavigationStack { PetHygieneDetailView(pet: pet) }
        case .walkSummary:
            NavigationStack { WalkSummarySheet(pet: pet) }
        case let .health(initialSection):
            NavigationStack {
                PetHealthDetailView(
                    pet: pet,
                    isModal: true,
                    initialSection: initialSection
                )
            }
        case .medication:
            NavigationStack { PetMedicationView(pet: pet) }
        case .momentHistory:
            PetMomentsHubView(pet: pet)
        case .documents:
            DocumentsListView(pet: pet, showsCloseButton: true)
        case .achievements:
            NavigationStack {
                AchievementWallView(
                    pet: pet,
                    onPresentCoconutLog: onPresentCoconutLog
                )
            }
        case .retention:
            PetRetentionHubView(pet: pet, showsCloseButton: true)
        case .bondVault:
            NavigationStack { PetBondVaultView(pet: pet) }
        }
    }
}

private struct PetRouteMissingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text("内容已不可用")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
