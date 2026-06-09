//
//  AppRouteDestinationContainers.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for global destinations.
//

import SwiftData
import SwiftUI

struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case let .petProfile(id, initialTab):
            AppPetRouteContainer(id: id, initialTab: initialTab)
        case let .humanProfile(id):
            AppHumanRouteContainer(id: id)
        case let .plantProfile(id):
            AppPlantRouteContainer(id: id)
        }
    }
}

struct AppRoutePresentationHost: ViewModifier {
    @ObservedObject var coordinator: AppRouteCoordinator
    let onRequiredHumanSaved: (Human) -> Void
    let onAddEntityDismissed: () -> Void
    let onPetSavedFromAddEntity: (Pet) -> Void
    let onHumanSavedFromAddEntity: (Human) -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onHumanDoseTaken: (UUID) -> Void

    @State private var lastSheetRoute: AppSheetRoute?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $coordinator.fullScreen) { route in
                AppFullScreenRouteDestination(
                    route: route,
                    onRequiredHumanSaved: onRequiredHumanSaved,
                    onDismiss: { coordinator.dismissFullScreen(route) }
                )
            }
            .sheet(item: $coordinator.sheet, onDismiss: handleSheetDismissed) { route in
                AppSheetRouteDestination(
                    route: route,
                    coordinator: coordinator,
                    onDismiss: { coordinator.dismissSheet(route) },
                    onPetSavedFromAddEntity: onPetSavedFromAddEntity,
                    onHumanSavedFromAddEntity: onHumanSavedFromAddEntity,
                    onCalendarEventDestination: handleCalendarEventDestination,
                    onHumanDoseTaken: onHumanDoseTaken
                )
                .onAppear {
                    lastSheetRoute = route
                }
            }
            .overlay {
                if let route = coordinator.overlay {
                    AppOverlayRouteDestination(
                        route: route,
                        onDismiss: { coordinator.dismissOverlay(route) },
                        onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
                        onOpenPet: { id, tab in coordinator.openPet(id, initialTab: tab) },
                        onOpenHuman: { id in coordinator.openHuman(id) }
                    )
                    .zIndex(140)
                }
            }
    }

    private func handleSheetDismissed() {
        defer { lastSheetRoute = nil }
        if case .addEntity = lastSheetRoute {
            onAddEntityDismissed()
        }
    }

    private func handleCalendarEventDestination(_ destination: FocusHomeReminderDestination) {
        coordinator.dismissSheet()
        OhanaFrameScheduler.runAfterNextFrame {
            openCalendarEventDestinationAfterDismiss(destination)
        }
    }

    private func openCalendarEventDestinationAfterDismiss(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            openPetQuickKey(key, pet: pet)
        case let .petFeature(feature, pet):
            openPetFeature(feature, pet: pet)
        case let .petHealth(pet, section):
            coordinator.presentSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, human: human)
        case let .humanDetail(human):
            coordinator.openHuman(human.id)
        case .plant:
            coordinator.presentFunctionMenu(destination: .plantsDashboard)
        case let .functionMenu(destination):
            coordinator.presentFunctionMenu(destination: destination)
        case let .calendar(entityID, humanID):
            coordinator.presentCalendar(entityID: entityID, humanID: humanID)
        }
    }

    private func openPetQuickKey(_ key: String, pet: Pet) {
        switch key {
        case "feed":
            coordinator.presentSheet(.petFeed(pet.id, opensManualSheet: false))
        case "water", "waterChange", "filterClean":
            coordinator.presentSheet(.petWater(pet.id))
        case "potty":
            coordinator.presentSheet(.petPotty(pet.id))
        case "litter":
            coordinator.presentSheet(.petLitter(pet.id))
        case "walk":
            coordinator.presentSheet(.petWalkSummary(pet.id))
        case "play":
            coordinator.presentSheet(.petPlay(pet.id))
        case "health":
            coordinator.presentSheet(.petHealth(pet.id, initialSection: nil))
        case "medication":
            coordinator.presentSheet(.petMedication(pet.id))
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            coordinator.presentSheet(.petHygiene(pet.id))
        case "weight":
            coordinator.presentSheet(.petWeight(pet.id))
        case "expense":
            coordinator.presentSheet(.petExpense(pet.id))
        case "moment":
            coordinator.presentQuickMoment(petID: pet.id)
        default:
            coordinator.presentSheet(.petAllFeatures(pet.id))
        }
    }

    private func openPetFeature(_ feature: PetFeature, pet: Pet) {
        switch feature {
        case .health:
            coordinator.presentSheet(.petHealth(pet.id, initialSection: nil))
        case .medications:
            coordinator.presentSheet(.petMedication(pet.id))
        case .food:
            coordinator.presentSheet(.petFood(pet.id))
        case .hygiene:
            coordinator.presentSheet(.petHygiene(pet.id))
        case .walks:
            coordinator.presentSheet(.petWalkSummary(pet.id))
        case .potty:
            coordinator.presentSheet(.petPotty(pet.id))
        case .basicInfo:
            coordinator.presentSheet(.petBasicInfo(pet.id))
        case .moments:
            coordinator.presentSheet(.petMomentHistory(pet.id))
        case .weight:
            coordinator.presentSheet(.petWeight(pet.id))
        case .expense:
            coordinator.presentSheet(.petExpense(pet.id))
        case .retention:
            coordinator.presentSheet(.petRetention(pet.id))
        case .documents:
            coordinator.presentSheet(.petDocuments(pet.id))
        case .achievements:
            coordinator.presentSheet(.petAchievements(pet.id))
        }
    }

    private func openHumanQuickKey(_ key: String, human: Human) {
        switch key {
        case "humanWeight":
            coordinator.presentSheet(.humanWeight(human.id))
        case "humanWorkout":
            coordinator.presentSheet(.humanWorkout(human.id))
        case "humanMedication":
            coordinator.presentSheet(.humanMedication(human.id))
        case "humanExpense":
            coordinator.presentSheet(.humanExpense(human.id))
        case "humanNote":
            coordinator.presentSheet(.humanNote(human.id))
        default:
            coordinator.presentSheet(.humanAllFeatures(human.id))
        }
    }
}

extension View {
    func appRoutePresentationHost(
        coordinator: AppRouteCoordinator,
        onRequiredHumanSaved: @escaping (Human) -> Void,
        onAddEntityDismissed: @escaping () -> Void = {},
        onPetSavedFromAddEntity: @escaping (Pet) -> Void = { _ in },
        onHumanSavedFromAddEntity: @escaping (Human) -> Void = { _ in },
        onFirstSuccessMomentCompleted: @escaping (Pet) -> Void = { _ in },
        onHumanDoseTaken: @escaping (UUID) -> Void = { _ in }
    ) -> some View {
        modifier(
            AppRoutePresentationHost(
                coordinator: coordinator,
                onRequiredHumanSaved: onRequiredHumanSaved,
                onAddEntityDismissed: onAddEntityDismissed,
                onPetSavedFromAddEntity: onPetSavedFromAddEntity,
                onHumanSavedFromAddEntity: onHumanSavedFromAddEntity,
                onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
                onHumanDoseTaken: onHumanDoseTaken
            )
        )
    }
}

private struct AppFullScreenRouteDestination: View {
    let route: AppFullScreenRoute
    let onRequiredHumanSaved: (Human) -> Void
    let onDismiss: () -> Void

    var body: some View {
        switch route {
        case .oasisReward:
            OasisRewardView()
        case .requiredHumanProfile:
            RequiredHumanProfileView { human in
                onRequiredHumanSaved(human)
                onDismiss()
            }
            .interactiveDismissDisabled(true)
        case let .walk(petID):
            AppWalkRouteContainer(id: petID, onDismiss: onDismiss)
        }
    }
}

private struct AppSheetRouteDestination: View {
    let route: AppSheetRoute
    @ObservedObject var coordinator: AppRouteCoordinator
    let onDismiss: () -> Void
    let onPetSavedFromAddEntity: (Pet) -> Void
    let onHumanSavedFromAddEntity: (Human) -> Void
    let onCalendarEventDestination: (FocusHomeReminderDestination) -> Void
    let onHumanDoseTaken: (UUID) -> Void

    var body: some View {
        switch route {
        case .accountSwitcher:
            AppAccountSwitcherRouteContainer(onSwitched: onDismiss)
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        case let .addEntity(type):
            AddEntityDestinationView(
                type: type,
                onComplete: onDismiss,
                onPetSaved: onPetSavedFromAddEntity,
                onHumanSaved: onHumanSavedFromAddEntity
            )
            .ohanaSheetPagePresentation()
        case let .calendar(entityID, humanID):
            CalendarView(
                preselectedPetId: entityID,
                preselectedHumanId: humanID,
                onOpenEventDestination: onCalendarEventDestination
            )
            .ohanaSheetPagePresentation()
        case let .functionMenu(destination):
            FunctionMenuSheet(initialDestination: destination)
                .ohanaSheetPagePresentation()
        case let .petAllFeatures(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .allFeatures,
                onMissing: onDismiss,
                onOpenFeatureDestination: openPetAllFeatureDestination
            )
            .ohanaSheetPagePresentation()
        case let .petBasicInfo(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .basicInfo,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petFood(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .food,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petWeight(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .weight,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petExpense(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .expense,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petFeed(id, opensManualSheet):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .feed(opensManualSheet),
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petWater(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .water,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petPotty(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .potty,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petLitter(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .litter,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petPlay(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .play,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petHygiene(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .hygiene,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petWalkSummary(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .walkSummary,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petHealth(id, initialSection):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .health(initialSection),
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petMedication(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .medication,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petMomentHistory(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .momentHistory,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petDocuments(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .documents,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petAchievements(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .achievements,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petRetention(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .retention,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petBondVault(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .bondVault,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanAllFeatures(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .allFeatures,
                onMissing: onDismiss,
                onOpenFeatureDestination: openHumanAllFeatureDestination
            )
            .ohanaSheetPagePresentation()
        case let .humanBasicInfo(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .basicInfo,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanMedication(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .medication,
                onMissing: onDismiss,
                onHumanDoseTaken: onHumanDoseTaken
            )
            .ohanaSheetPagePresentation()
        case let .humanWeight(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .weight,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanWorkout(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .workout,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanWorkoutDashboard(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .workoutDashboard,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanMetrics(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .metrics,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanReport(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .report,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanExpense(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .expense,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanWishlist(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .wishlist,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanNote(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .note,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case .requiredAccountSwitch:
            AppAccountSwitcherRouteContainer(onSwitched: onDismiss)
                .interactiveDismissDisabled(true)
        case .streakDetail:
            AppStreakDetailRouteContainer(onClose: onDismiss)
                .ohanaSheetPagePresentation()
        }
    }

    private func openPetAllFeatureDestination(_ pet: Pet, destination: PetAllFeatureDestination) {
        let route: AppSheetRoute
        switch destination {
        case .health:
            route = .petHealth(pet.id, initialSection: nil)
        case .medications:
            route = .petMedication(pet.id)
        case .food:
            route = .petFood(pet.id)
        case .hygiene:
            route = .petHygiene(pet.id)
        case .walks:
            route = .petWalkSummary(pet.id)
        case .potty:
            route = .petPotty(pet.id)
        case .basicInfo:
            route = .petBasicInfo(pet.id)
        case .documents:
            route = .petDocuments(pet.id)
        case .moments, .timeline:
            route = .petMomentHistory(pet.id)
        case .achievements:
            route = .petAchievements(pet.id)
        case .retention:
            route = .petRetention(pet.id)
        case .weight:
            route = .petWeight(pet.id)
        case .expense:
            route = .petExpense(pet.id)
        case .bondVault:
            route = .petBondVault(pet.id)
        }
        presentFeatureRouteAfterTap(route)
    }

    private func openHumanAllFeatureDestination(_ human: Human, destination: HumanAllFeatureDestination) {
        let route: AppSheetRoute
        switch destination {
        case .basicInfo:
            route = .humanBasicInfo(human.id)
        case .weight:
            route = .humanWeight(human.id)
        case .workout:
            route = .humanWorkoutDashboard(human.id)
        case .metrics:
            route = .humanMetrics(human.id)
        case .medication:
            route = .humanMedication(human.id)
        case .report:
            route = .humanReport(human.id)
        case .expense:
            route = .humanExpense(human.id)
        case .wishlist:
            route = .humanWishlist(human.id)
        case .notes:
            route = .humanNote(human.id)
        }
        presentFeatureRouteAfterTap(route)
    }

    private func presentFeatureRouteAfterTap(_ route: AppSheetRoute) {
        OhanaFrameScheduler.runAfterNextFrame {
            coordinator.presentSheet(route)
        }
    }
}

private enum AppPetDetailSheetDestination: Hashable {
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

private struct AppPetDetailSheetRouteContainer: View {
    @Query private var pets: [Pet]
    let destination: AppPetDetailSheetDestination
    let onMissing: () -> Void
    let onDismiss: () -> Void
    let onOpenFeatureDestination: ((Pet, PetAllFeatureDestination) -> Void)?

    init(
        id: UUID,
        destination: AppPetDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {},
        onOpenFeatureDestination: ((Pet, PetAllFeatureDestination) -> Void)? = nil
    ) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.destination = destination
        self.onMissing = onMissing
        self.onDismiss = onDismiss
        self.onOpenFeatureDestination = onOpenFeatureDestination
    }

    var body: some View {
        if let pet = pets.first {
            petDestination(for: pet)
        } else {
            MissingRouteEntityView(kind: "pet")
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
                    onOpenFeatureDestination?(pet, destination)
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
            QuickFeedDetailSheet(
                pet: pet,
                onRemove: onDismiss,
                onClose: onDismiss,
                opensManualSheetOnAppear: opensManualSheet
            )
        case .water:
            QuickWaterDetailSheet(pet: pet, onRemove: onDismiss, onClose: onDismiss)
        case .potty:
            QuickPottyDetailSheet(pet: pet, onRemove: onDismiss, onClose: onDismiss)
        case .litter:
            QuickLitterDetailSheet(pet: pet, onRemove: onDismiss, onClose: onDismiss)
        case .play:
            QuickPlayDetailSheet(pet: pet, onRemove: onDismiss, onClose: onDismiss)
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
            NavigationStack { AchievementWallView(pet: pet) }
        case .retention:
            PetRetentionHubView(pet: pet, showsCloseButton: true)
        case .bondVault:
            NavigationStack { PetBondVaultView(pet: pet) }
        }
    }
}

private enum AppHumanDetailSheetDestination: Hashable {
    case allFeatures
    case basicInfo
    case medication
    case weight
    case workout
    case workoutDashboard
    case metrics
    case report
    case expense
    case wishlist
    case note
}

private struct AppHumanDetailSheetRouteContainer: View {
    @Query private var humans: [Human]
    let destination: AppHumanDetailSheetDestination
    let onMissing: () -> Void
    let onHumanDoseTaken: (UUID) -> Void
    let onOpenFeatureDestination: ((Human, HumanAllFeatureDestination) -> Void)?

    init(
        id: UUID,
        destination: AppHumanDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onHumanDoseTaken: @escaping (UUID) -> Void = { _ in },
        onOpenFeatureDestination: ((Human, HumanAllFeatureDestination) -> Void)? = nil
    ) {
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
        self.destination = destination
        self.onMissing = onMissing
        self.onHumanDoseTaken = onHumanDoseTaken
        self.onOpenFeatureDestination = onOpenFeatureDestination
    }

    var body: some View {
        if let human = humans.first {
            humanDestination(for: human)
        } else {
            MissingRouteEntityView(kind: "human")
                .onAppear(perform: onMissing)
        }
    }

    @ViewBuilder
    private func humanDestination(for human: Human) -> some View {
        switch destination {
        case .allFeatures:
            HumanAllFeaturesSheet(
                human: human,
                onOpenDestination: { destination in
                    onOpenFeatureDestination?(human, destination)
                }
            )
        case .basicInfo:
            NavigationStack { HumanBasicInfoDetailView(human: human) }
        case .medication:
            NavigationStack {
                HumanMedicationView(
                    human: human,
                    showsDoneButton: true,
                    onDoseTaken: {
                        onHumanDoseTaken(human.id)
                    }
                )
            }
        case .weight:
            NavigationStack { HumanWeightHistoryView(human: human) }
        case .workout:
            HumanWorkoutHistoryView(human: human)
        case .workoutDashboard:
            CoHealthDashboardFullView(human: human)
        case .metrics:
            HumanHealthCheckupView(human: human)
        case .report:
            HumanHealthReportView(human: human)
        case .expense:
            NavigationStack { HumanExpenseDetailView(human: human) }
        case .wishlist:
            HumanWishlistView(human: human)
        case .note:
            HumanNoteHistorySheet(human: human)
        }
    }
}

private struct AppOverlayRouteDestination: View {
    let route: AppOverlayRoute
    let onDismiss: () -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onOpenPet: (UUID, PetDetailTab) -> Void
    let onOpenHuman: (UUID) -> Void

    var body: some View {
        switch route {
        case let .coconutLog(subject):
            HomeCoconutLogInlineHost(
                subject: subject,
                onClose: onDismiss
            )
            .ignoresSafeArea()
        case let .crewRoster(mode):
            HomeCrewRosterInlineHost(
                initialMode: mode,
                onClose: onDismiss,
                onSelectPet: { pet in
                    onDismiss()
                    onOpenPet(pet.id, .overview)
                },
                onSelectHuman: { human in
                    onDismiss()
                    onOpenHuman(human.id)
                }
            )
            .ignoresSafeArea()
        case let .quickMoment(_, petID):
            AppQuickMomentOverlayRouteContainer(
                id: petID,
                onSaved: onFirstSuccessMomentCompleted,
                onDismiss: onDismiss
            )
            .ignoresSafeArea()
        case .settings:
            AppSettingsOverlayRouteContainer(onClose: onDismiss)
                .ignoresSafeArea()
        }
    }
}

private struct AppQuickMomentOverlayRouteContainer: View {
    @Query private var pets: [Pet]
    let onSaved: (Pet) -> Void
    let onDismiss: () -> Void

    init(
        id: UUID,
        onSaved: @escaping (Pet) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.onSaved = onSaved
        self.onDismiss = onDismiss
    }

    var body: some View {
        if let pet = pets.first {
            QuickMomentSheet(
                pet: pet,
                onRemove: nil,
                onSaved: {
                    onSaved(pet)
                },
                onClose: onDismiss
            )
        } else {
            MissingRouteEntityView(kind: "pet")
                .onAppear(perform: onDismiss)
        }
    }
}

private struct AppAccountSwitcherRouteContainer: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var electronicPets: [OasisElectronicPet]

    let onSwitched: () -> Void

    var body: some View {
        HumanAccountSwitcherSheet(
            homePets: pets,
            homeHumans: humans,
            homeElectronicPets: electronicPets,
            onSwitched: onSwitched
        )
    }
}

private struct AppStreakDetailRouteContainer: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]

    let onClose: () -> Void

    var body: some View {
        DailyStreakDetailView(pets: pets, onClose: onClose)
    }
}

private struct AppSettingsOverlayRouteContainer: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var electronicPets: [OasisElectronicPet]

    let onClose: () -> Void

    var body: some View {
        HomeSettingsInlineHost(
            homePets: pets,
            homeHumans: humans,
            homeElectronicPets: electronicPets,
            onClose: onClose
        )
    }
}

private struct AppWalkRouteContainer: View {
    @Query private var pets: [Pet]
    let onDismiss: () -> Void

    init(id: UUID, onDismiss: @escaping () -> Void) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.onDismiss = onDismiss
    }

    var body: some View {
        if let pet = pets.first {
            WalkTrackingFullScreen(
                pet: pet,
                onMinimize: onDismiss
            )
        } else {
            MissingRouteEntityView(kind: "pet")
                .onAppear(perform: onDismiss)
        }
    }
}

private struct AppPetRouteContainer: View {
    @Query private var pets: [Pet]
    let initialTab: PetDetailTab

    init(id: UUID, initialTab: PetDetailTab) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.initialTab = initialTab
    }

    var body: some View {
        if let pet = pets.first {
            if initialTab == .health {
                PetHealthDetailView(pet: pet)
            } else {
                PetBasicInfoDetailView(pet: pet)
            }
        } else {
            MissingRouteEntityView(kind: "pet")
        }
    }
}

private struct AppHumanRouteContainer: View {
    @Query private var humans: [Human]

    init(id: UUID) {
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
    }

    var body: some View {
        if let human = humans.first {
            HumanDetailView(human: human)
        } else {
            MissingRouteEntityView(kind: "human")
        }
    }
}

private struct AppPlantRouteContainer: View {
    @Query private var plants: [Plant]

    init(id: UUID) {
        _plants = Query(filter: #Predicate<Plant> { plant in
            plant.id == id
        })
    }

    var body: some View {
        if let plant = plants.first {
            PlantDetailView(plant: plant)
        } else {
            MissingRouteEntityView(kind: "plant")
        }
    }
}

private struct RequiredHumanProfileView: View {
    let onHumanSaved: (Human) -> Void

    @State private var isCreatingProfile = false
    @State private var savedHuman: Human?

    var body: some View {
        NavigationStack {
            ZStack {
                GoIslandWizardBackdrop()

                if isCreatingProfile {
                    AddHumanWizardView(
                        onComplete: {
                            if let savedHuman {
                                onHumanSaved(savedHuman)
                            }
                        },
                        onHumanSaved: { human in
                            savedHuman = human
                        }
                    )
                } else {
                    promptCard
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var promptCard: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.goLime.opacity(0.16))
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.goLime)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("先建立你的本人档案")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("当前没有人类成员。Ohana 需要至少一个人类成员，用来记录谁完成了喂食、喂水、护理、健康记录和花费。")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    requirementRow(icon: "sparkles", text: "新的第一个人类会再次默认使用 2.5D 头像")
                    requirementRow(icon: "checkmark.seal.fill", text: "快速打卡会自动绑定到你")
                    requirementRow(icon: "creditcard.fill", text: "花费、护理和健康记录会有明确执行者")
                }

                Button {
                    withAnimation(GoMotion.page) {
                        isCreatingProfile = true
                    }
                } label: {
                    Text("建立我的档案")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 4)
            }
            .padding(24)
            .goTranslucentCard(cornerRadius: 30)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func requirementRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.goLime)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
    }
}

private struct MissingRouteEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goPrimary)
            Text("内容已不可用")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}
