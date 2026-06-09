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
    let onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    init(
        route: AppRoute,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil
    ) {
        self.route = route
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        switch route {
        case let .petProfile(id, initialTab):
            AppPetRouteContainer(id: id, initialTab: initialTab)
        case let .humanProfile(id):
            AppHumanRouteContainer(
                id: id,
                onPresentCoconutLog: onPresentCoconutLog ?? { _ in }
            )
        case let .plantProfile(id):
            if AppFeatureRouteGuard.allowsAppRoute(route) {
                AppPlantRouteContainer(id: id)
            } else {
                HiddenRouteInterceptView(note: route.id)
            }
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
                AppDeferredRouteContent(
                    routeID: route.id,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    AppFullScreenRouteDestination(
                        route: route,
                        onRequiredHumanSaved: onRequiredHumanSaved,
                        onDismiss: { coordinator.dismissFullScreen(route) },
                        onPresentCoconutLog: { subject in
                            coordinator.presentCoconutLog(subject)
                        }
                    )
                }
            }
            .sheet(item: $coordinator.sheet, onDismiss: handleSheetDismissed) { route in
                AppDeferredRouteContent(
                    routeID: route.id,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    AppSheetRouteDestination(
                        route: route,
                        coordinator: coordinator,
                        onDismiss: { coordinator.dismissSheet(route) },
                        onPetSavedFromAddEntity: onPetSavedFromAddEntity,
                        onHumanSavedFromAddEntity: onHumanSavedFromAddEntity,
                        onCalendarEventDestination: handleCalendarEventDestination,
                        onHumanDoseTaken: onHumanDoseTaken
                    )
                }
                .appRouteSheetPresentation(for: route)
                .onAppear {
                    lastSheetRoute = route
                }
            }
            .overlay {
                if let route = coordinator.overlay {
                    AppDeferredRouteContent(
                        routeID: route.id,
                        policy: AppPresentationPolicyProvider.policy(for: route)
                    ) {
                        AppOverlayRouteDestination(
                            route: route,
                            onDismiss: { coordinator.dismissOverlay(route) },
                            onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
                            onOpenPet: { id, tab in coordinator.openPet(id, initialTab: tab) },
                            onOpenHuman: { id in coordinator.openHuman(id) },
                            onPresentCoconutLog: { subject in
                                coordinator.presentCoconutLog(subject)
                            }
                        )
                    }
                    .ignoresSafeArea()
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
            AppFeatureRouteGuard.recordIntercept("calendarPlant")
            coordinator.presentFunctionMenu(destination: .growthRoadmap)
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
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    var body: some View {
        switch route {
        case .oasisReward:
            OasisRewardView(onPresentCoconutLog: onPresentCoconutLog)
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
    @AppStorage("appLanguage") private var appLanguage = "zh"

    private var l: L10n { L10n(appLanguage) }

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
            CalendarRouteContainer(
                preselectedPetId: entityID,
                preselectedHumanId: humanID,
                onOpenEventDestination: onCalendarEventDestination,
                onPresentCoconutLog: { subject in
                    coordinator.presentCoconutLog(subject)
                }
            )
            .ohanaSheetPagePresentation()
        case let .coconutLog(subject):
            CoconutLogView(
                subject: subject,
                onClose: onDismiss,
                historyContentDelayMilliseconds: 80
            )
            .ohanaSheetPagePresentation()
        case let .coconutShop(category):
            CoconutShopRouteContainer(initialCategory: category)
                .ohanaSheetPagePresentation()
        case let .crewRoster(mode):
            NavigationStack {
                CrewRosterOverlayRouteContainer(
                    initialMode: mode,
                    onSelectPet: { pet in
                        onDismiss()
                        coordinator.openPet(pet.id, initialTab: .overview)
                    },
                    onSelectHuman: { human in
                        onDismiss()
                        coordinator.openHuman(human.id)
                    },
                    onClose: onDismiss,
                    onPresentCoconutLog: { subject in
                        coordinator.presentCoconutLog(subject)
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: onDismiss) {
                            Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark.circle.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
            }
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
                onMissing: onDismiss,
                onPresentCoconutLog: { subject in
                    coordinator.presentCoconutLog(subject)
                }
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
            HumanAllFeaturesRouteContainer(
                id: id,
                onMissing: onDismiss,
                onOpenDestination: openHumanAllFeatureDestination
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
        case .settings:
            AppSettingsSheetRouteContainer(onClose: onDismiss)
                .ohanaSheetPagePresentation()
        case .streakDetail:
            AppStreakDetailRouteContainer(
                onClose: onDismiss,
                onPresentCoconutLog: { subject in
                    coordinator.presentCoconutLog(subject)
                },
                onPresentCoconutShop: { category in
                    coordinator.presentCoconutShop(category: category)
                }
            )
                .ohanaSheetPagePresentation()
        }
    }

    private func openPetAllFeatureDestination(_ petID: UUID, destination: PetAllFeatureDestination) {
        let route: AppSheetRoute
        switch destination {
        case .health:
            route = .petHealth(petID, initialSection: nil)
        case .medications:
            route = .petMedication(petID)
        case .food:
            route = .petFood(petID)
        case .hygiene:
            route = .petHygiene(petID)
        case .walks:
            route = .petWalkSummary(petID)
        case .potty:
            route = .petPotty(petID)
        case .basicInfo:
            route = .petBasicInfo(petID)
        case .documents:
            route = .petDocuments(petID)
        case .moments, .timeline:
            route = .petMomentHistory(petID)
        case .achievements:
            route = .petAchievements(petID)
        case .retention:
            route = .petRetention(petID)
        case .weight:
            route = .petWeight(petID)
        case .expense:
            route = .petExpense(petID)
        case .bondVault:
            route = .petBondVault(petID)
        }
        presentFeatureRouteAfterTap(route)
    }

    private func openHumanAllFeatureDestination(_ humanID: UUID, destination: HumanAllFeatureDestination) {
        let route: AppSheetRoute
        switch destination {
        case .basicInfo:
            route = .humanBasicInfo(humanID)
        case .weight:
            route = .humanWeight(humanID)
        case .workout:
            route = .humanWorkoutDashboard(humanID)
        case .metrics:
            route = .humanMetrics(humanID)
        case .medication:
            route = .humanMedication(humanID)
        case .report:
            route = .humanReport(humanID)
        case .expense:
            route = .humanExpense(humanID)
        case .wishlist:
            route = .humanWishlist(humanID)
        case .notes:
            route = .humanNote(humanID)
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

private enum AppHumanDetailSheetDestination: Hashable {
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

struct HumanAllFeaturesRouteContainer: View {
    @Query private var humans: [Human]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]
    @Query private var allExpenses: [PetExpenseLog]

    let onMissing: () -> Void
    let onOpenDestination: (UUID, HumanAllFeatureDestination) -> Void

    init(
        id: UUID,
        onMissing: @escaping () -> Void,
        onOpenDestination: @escaping (UUID, HumanAllFeatureDestination) -> Void
    ) {
        let humanKey = id.uuidString
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
        _allMeds = Query(
            filter: #Predicate<HumanMedication> { med in
                med.humanId == humanKey
            },
            sort: \.createdAt
        )
        _allReports = Query(
            filter: #Predicate<HumanHealthReport> { report in
                report.humanId == humanKey
            },
            sort: \.reportDate,
            order: .reverse
        )
        _allExpenses = Query(
            filter: #Predicate<PetExpenseLog> { expense in
                expense.executorId == humanKey
            },
            sort: \.date,
            order: .reverse
        )
        self.onMissing = onMissing
        self.onOpenDestination = onOpenDestination
    }

    var body: some View {
        if let human = humans.first {
            HumanAllFeaturesSheet(
                human: human,
                allMeds: allMeds,
                allReports: allReports,
                allExpenses: allExpenses,
                onOpenDestination: { destination in
                    onOpenDestination(human.id, destination)
                }
            )
        } else {
            MissingRouteEntityView(kind: "human")
                .onAppear(perform: onMissing)
        }
    }
}

struct OasisCritterCodexRouteContainer: View {
    let mode: OasisCritterViewMode
    let initialCatalogId: String?
    let isPopup: Bool
    let onClose: (() -> Void)?
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \OasisElectronicPet.obtainedAt) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt) private var fragments: [OasisCritterFragmentBalance]

    init(
        mode: OasisCritterViewMode = .codex,
        initialCatalogId: String? = nil,
        isPopup: Bool = false,
        onClose: (() -> Void)? = nil,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        self.mode = mode
        self.initialCatalogId = initialCatalogId
        self.isPopup = isPopup
        self.onClose = onClose
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        OasisCritterCodexView(
            mode: mode,
            initialCatalogId: initialCatalogId,
            isPopup: isPopup,
            onClose: onClose,
            humans: humans,
            electronicPets: electronicPets,
            fragments: fragments,
            onPresentCoconutLog: onPresentCoconutLog
        )
    }
}

struct CrewRosterOverlayRouteContainer: View {
    let initialMode: CrewRosterMode
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddEntity: ((EntityType) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var addMemberTrigger: Bool = false
    var safeTopInset: CGFloat = 0
    var safeBottomInset: CGFloat = 0
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(sort: \FamilyCollaborationTask.updatedAt, order: .reverse) private var familyTasks: [FamilyCollaborationTask]

    var body: some View {
        CrewRosterOverlay(
            initialMode: initialMode,
            pets: pets,
            humans: humans,
            plants: [],
            pendingReminders: pendingReminders,
            familyTasks: familyTasks,
            onSelectPet: onSelectPet,
            onSelectHuman: onSelectHuman,
            onAddEntity: onAddEntity,
            onClose: onClose,
            hideToolbar: hideToolbar,
            searchTrigger: searchTrigger,
            addMemberTrigger: addMemberTrigger,
            safeTopInset: safeTopInset,
            safeBottomInset: safeBottomInset,
            onPresentCoconutLog: onPresentCoconutLog
        )
    }
}

struct CalendarRouteContainer: View {
    var preselectedPetId: String? = nil
    var preselectedHumanId: String? = nil
    var hideToolbar: Bool = false
    var showsEmbeddedControls: Bool = false
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (() -> Void)? = nil
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)? = nil
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \PetInsurance.createdAt) private var insurances: [PetInsurance]
    @Query(sort: \PetMedication.createdAt) private var petMedications: [PetMedication]
    @Query(sort: \HumanMedication.createdAt) private var humanMedications: [HumanMedication]

    var body: some View {
        CalendarView(
            preselectedPetId: preselectedPetId,
            preselectedHumanId: preselectedHumanId,
            hideToolbar: hideToolbar,
            showsEmbeddedControls: showsEmbeddedControls,
            addEventTrigger: addEventTrigger,
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            onRequestAddEvent: onRequestAddEvent,
            onOpenEventDestination: onOpenEventDestination,
            onPresentCoconutLog: onPresentCoconutLog,
            events: events,
            pets: pets,
            humans: humans,
            plants: [],
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications
        )
    }
}

private struct AppHumanDetailSheetRouteContainer: View {
    @Query private var humans: [Human]
    let destination: AppHumanDetailSheetDestination
    let onMissing: () -> Void
    let onHumanDoseTaken: (UUID) -> Void

    init(
        id: UUID,
        destination: AppHumanDetailSheetDestination,
        onMissing: @escaping () -> Void,
        onHumanDoseTaken: @escaping (UUID) -> Void = { _ in }
    ) {
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
        self.destination = destination
        self.onMissing = onMissing
        self.onHumanDoseTaken = onHumanDoseTaken
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
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    var body: some View {
        switch route {
        case let .quickMoment(_, petID):
            OhanaInlinePageRouteHost(routeID: route.id, onClose: onDismiss) { requestClose in
                AppQuickMomentOverlayRouteContainer(
                    id: petID,
                    onSaved: onFirstSuccessMomentCompleted,
                    onDismiss: requestClose
                )
            }
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
            humans: humans,
            homePets: pets,
            homeHumans: humans,
            homeElectronicPets: electronicPets,
            onSwitched: onSwitched
        )
    }
}

private struct AppStreakDetailRouteContainer: View {
    let onClose: () -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void
    let onPresentCoconutShop: (ShopItem.ShopCategory) -> Void

    var body: some View {
        DailyStreakDetailRouteContainer(
            onClose: onClose,
            onPresentCoconutLog: onPresentCoconutLog,
            onPresentCoconutShop: onPresentCoconutShop
        )
    }
}

struct DailyStreakDetailRouteContainer: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var ledgerEvents: [CareLedgerEvent]

    var onClose: (() -> Void)? = nil
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil
    var onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)? = nil

    init(
        onClose: (() -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil,
        onPresentCoconutShop: ((ShopItem.ShopCategory) -> Void)? = nil
    ) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.date(byAdding: .day, value: -7, to: Date())
            ?? Date()
        _ledgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= weekStart
            },
            sort: \.occurredAt,
            order: .reverse
        )
        self.onClose = onClose
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onPresentCoconutShop = onPresentCoconutShop
    }

    var body: some View {
        DailyStreakDetailView(
            pets: pets,
            humans: humans,
            ledgerEvents: ledgerEvents,
            onClose: onClose,
            onPresentCoconutLog: onPresentCoconutLog,
            onPresentCoconutShop: onPresentCoconutShop
        )
    }
}

private struct AppSettingsSheetRouteContainer: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var electronicPets: [OasisElectronicPet]

    let onClose: () -> Void

    var body: some View {
        SettingsView(
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
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query private var allPendingReminders: [Reminder]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]

    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    init(
        id: UUID,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        let humanKey = id.uuidString
        let humanType = "Human"
        let pendingStatus = "pending"
        _humans = Query(filter: #Predicate<Human> { human in
            human.id == id
        })
        _allPendingReminders = Query(
            filter: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus &&
                    reminder.event?.relatedEntityType == humanType &&
                    reminder.event?.relatedEntityId == humanKey
            },
            sort: \.scheduledAt
        )
        _allMeds = Query(
            filter: #Predicate<HumanMedication> { med in
                med.humanId == humanKey
            },
            sort: \.createdAt
        )
        _allReports = Query(
            filter: #Predicate<HumanHealthReport> { report in
                report.humanId == humanKey
            },
            sort: \.reportDate,
            order: .reverse
        )
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        if let human = humans.first {
            HumanDetailView(
                human: human,
                allPets: allPets,
                allHumans: allHumans,
                allPendingReminders: allPendingReminders,
                allMeds: allMeds,
                allReports: allReports,
                onPresentCoconutLog: onPresentCoconutLog
            )
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

struct FunctionMenuDestinationRouteContainer: View {
    let destination: FMDest
    @Binding var parentPath: NavigationPath

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    var body: some View {
        FunctionMenuDestinationRouter(
            destination: destination,
            parentPath: $parentPath,
            pets: pets,
            humans: humans,
            plants: []
        )
    }
}

struct FunctionMenuRootRouteContainer: View {
    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    var body: some View {
        FunctionMenuRootView(
            appLanguage: appLanguage,
            onSelect: onSelect,
            onClose: onClose,
            pets: pets,
            humans: humans
        )
    }
}

private struct HiddenRouteInterceptView: View {
    let note: String

    var body: some View {
        Color.clear
            .onAppear {
                AppFeatureRouteGuard.recordIntercept(note)
            }
    }
}

struct ExecutorPickerBarRouteContainer: View {
    var tint: Color = .goPrimary
    var compact: Bool = false

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        ExecutorPickerBar(
            humans: humans,
            tint: tint,
            compact: compact
        )
    }
}

struct QuickPlayDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey
            },
            sort: \.startDate
        )
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        if let pet = pets.first {
            QuickPlayDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                allEvents: allEvents
            )
        } else {
            MissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct QuickFeedDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query private var allCareLogs: [PetCareLog]
    @Query private var allFoodRecords: [PetFoodRecord]

    let onRemove: () -> Void
    let onClose: (() -> Void)?
    let showsRemoveQuickActionFooter: Bool
    let showsCloseButton: Bool
    let opensManualSheetOnAppear: Bool

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        showsRemoveQuickActionFooter: Bool = true,
        showsCloseButton: Bool = true,
        opensManualSheetOnAppear: Bool = false
    ) {
        let petKey = id.uuidString
        let dryStockKey = "\(petKey):\(FeedFoodKind.dry.rawValue)"
        let wetStockKey = "\(petKey):\(FeedFoodKind.wet.rawValue)"
        let feedingType = CareType.feeding.rawValue
        let homeLogStartDate = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(-6 * 86_400)

        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey ||
                    event.relatedEntityId == dryStockKey ||
                    event.relatedEntityId == wetStockKey
            },
            sort: \.startDate
        )
        _allCareLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                log.type == feedingType &&
                    log.pet?.id == id &&
                    log.date >= homeLogStartDate
            },
            sort: \.date,
            order: .reverse
        )
        _allFoodRecords = Query(
            filter: #Predicate<PetFoodRecord> { record in
                record.pet?.id == id
            },
            sort: \.startDate,
            order: .reverse
        )
        self.onRemove = onRemove
        self.onClose = onClose
        self.showsRemoveQuickActionFooter = showsRemoveQuickActionFooter
        self.showsCloseButton = showsCloseButton
        self.opensManualSheetOnAppear = opensManualSheetOnAppear
    }

    var body: some View {
        if let pet = pets.first {
            QuickFeedDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                showsRemoveQuickActionFooter: showsRemoveQuickActionFooter,
                showsCloseButton: showsCloseButton,
                opensManualSheetOnAppear: opensManualSheetOnAppear,
                allEvents: allEvents,
                allHumans: allHumans,
                allPets: allPets,
                allCareLogs: allCareLogs,
                allFoodRecords: allFoodRecords
            )
        } else {
            MissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct QuickWaterDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query private var waterCareLogs: [PetCareLog]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        let wateringType = CareType.watering.rawValue
        let waterChangeType = CareType.waterChange.rawValue
        let filterCleanType = CareType.filterClean.rawValue

        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey
            },
            sort: \.startDate
        )
        _waterCareLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                (log.type == wateringType ||
                 log.type == waterChangeType ||
                 log.type == filterCleanType) &&
                    log.pet?.id == id
            },
            sort: \.date,
            order: .reverse
        )
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        if let pet = pets.first {
            QuickWaterDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                allEvents: allEvents,
                allPets: allPets,
                waterCareLogs: waterCareLogs
            )
        } else {
            MissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct QuickPottyDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey
            },
            sort: \.startDate
        )
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        if let pet = pets.first {
            QuickPottyDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                allEvents: allEvents,
                allPets: allPets
            )
        } else {
            MissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct FamilyActivityStripRouteContainer: View {
    let pet: Pet
    var style: FamilyActivityStripView.Style = .full
    var onExpand: () -> Void = {}

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        FamilyActivityStripView(
            pet: pet,
            humans: humans,
            style: style,
            onExpand: onExpand
        )
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
                    Image(systemName: "person.crop.circle.badge.exclamationmark.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.title(.bold))
                        .foregroundStyle(Color.goLime)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("先建立你的本人档案")
                        .font(OhanaFont.title(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("当前没有人类成员。Ohana 需要至少一个人类成员，用来记录谁完成了喂食、喂水、护理、健康记录和花费。")
                        .font(OhanaFont.callout(.semibold))
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
                        .font(OhanaFont.callout(.black))
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
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goLime)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
    }
}

private struct MissingRouteEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: allow decorative icon covered by surrounding text or control
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
