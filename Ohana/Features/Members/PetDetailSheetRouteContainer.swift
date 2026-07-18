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
    case weightQuick
    case weight
    case expenseQuick
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

extension AppPetDetailSheetDestination {
    var isAvailableInMemorialMode: Bool {
        switch self {
        case .allFeatures, .basicInfo, .momentHistory, .documents, .achievements, .retention:
            true
        case .food, .weightQuick, .weight, .expenseQuick, .expense, .feed, .water, .potty, .litter, .play, .hygiene,
             .walkSummary, .health, .medication, .bondVault:
            false
        }
    }
}

struct AppPetDetailSheetRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Query private var pets: [Pet]
    @State private var allFeaturesActivitySummary = PetAllFeaturesActivitySummary.empty
    @State private var allFeaturesActivitySummaryTask: Task<Void, Never>?
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    let destination: AppPetDetailSheetDestination
    let onMissing: () -> Void
    let onDismiss: () -> Void
    let showsFoodCloseButton: Bool
    let onOpenFeatureDestination: ((UUID, PetAllFeatureDestination) -> Void)?
    let onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    init(
        id: UUID,
        destination: AppPetDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {},
        showsFoodCloseButton: Bool = false,
        onOpenFeatureDestination: ((UUID, PetAllFeatureDestination) -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil
    ) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.destination = destination
        self.onMissing = onMissing
        self.onDismiss = onDismiss
        self.showsFoodCloseButton = showsFoodCloseButton
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
        if pet.hasPassedAway && !destination.isAvailableInMemorialMode {
            PetRouteMissingEntityView(kind: "memorial")
        } else {
            switch destination {
            case .allFeatures:
                PetAllFeaturesSheet(
                    pet: pet,
                    activitySummary: allFeaturesActivitySummary,
                    onOpenDestination: { destination in
                        onOpenFeatureDestination?(pet.id, destination)
                    }
                )
                .onAppear {
                    scheduleAllFeaturesActivitySummaryLoad(petID: pet.id)
                }
                .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
                    scheduleAllFeaturesActivitySummaryLoad(petID: pet.id, force: true)
                }
                .onDisappear {
                    allFeaturesActivitySummaryTask?.cancel()
                    allFeaturesActivitySummaryTask = nil
                }
            case .basicInfo:
                NavigationStack { PetBasicInfoDetailView(pet: pet) }
            case .food:
                NavigationStack {
                    PetFoodManagementView(
                        pet: pet,
                        onClose: onDismiss,
                        showsCloseButton: showsFoodCloseButton
                    )
                }
            case .weightQuick:
                GenericWeightEntrySheet(
                    target: .pet(pet),
                    petLedgerSource: .quickAction,
                    onDismiss: onDismiss
                )
            case .weight:
                NavigationStack { WeightHistoryView(pet: pet) }
            case .expenseQuick:
                PetExpenseQuickRouteContent(
                    pet: pet,
                    activeHumanIdRaw: activeHumanIdRaw,
                    loadData: { PetExpenseQuickRouteData.load(from: modelContext) },
                    onDismiss: onDismiss
                )
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
                PetMomentsHubRouteContainer(pet: pet)
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

    private func scheduleAllFeaturesActivitySummaryLoad(
        petID: UUID,
        force: Bool = false,
        delayMilliseconds: UInt64 = 24
    ) {
        guard destination == .allFeatures else { return }
        guard force || allFeaturesActivitySummary == .empty else { return }
        guard allFeaturesActivitySummaryTask == nil else { return }
        let container = modelContext.container
        let now = Date()
        allFeaturesActivitySummaryTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                allFeaturesActivitySummaryTask = nil
                return
            }
            let actor = PetAllFeaturesActivitySummaryActor(modelContainer: container)
            do {
                allFeaturesActivitySummary = try await actor.load(petID: petID, now: now)
            } catch is CancellationError {
                // The route disappeared or a newer load replaced this one.
            } catch {
                OhanaLog.warning(
                    "Pet all-features activity summary load failed: \(error.localizedDescription)",
                    category: "Members"
                )
            }
            allFeaturesActivitySummaryTask = nil
        }
    }
}

private struct PetExpenseQuickRouteContent: View {
    let pet: Pet
    let activeHumanIdRaw: String
    let loadData: @MainActor () -> PetExpenseQuickRouteData
    let onDismiss: () -> Void

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: PetExpenseQuickRouteData(),
            loadDelayMilliseconds: 120,
            shouldLoad: { !$0.hasLoaded },
            load: loadData
        ) { data in
            if data.hasLoaded {
                AddExpenseSheet(
                    pet: pet,
                    humans: data.humans,
                    allPets: data.allPets.isEmpty ? [pet] : data.allPets,
                    preselectedPayerId: activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw,
                    onDismiss: onDismiss
                )
            } else {
                PetRouteLoadingEntityView(kind: "expense")
            }
        }
    }
}

private struct PetExpenseQuickRouteData {
    var humans: [Human] = []
    var allPets: [Pet] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> PetExpenseQuickRouteData {
        PetExpenseQuickRouteData(
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            allPets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            hasLoaded: true
        )
    }
}

private func fetch<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    name: String
) -> [T] {
    do {
        return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
    } catch {
        OhanaLog.warning(
            "Pet detail route data fetch failed for \(name): \(error.localizedDescription)",
            category: "Members"
        )
        return []
    }
}

struct PetRouteMissingEntityView: View {
    let kind: String
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text(l.tr(zh: "内容已不可用", en: "Content is no longer available", de: "Inhalt ist nicht mehr verfuegbar"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
        .accessibilityIdentifier("pet-route-missing-\(kind)")
    }
}

private struct PetRouteLoadingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
