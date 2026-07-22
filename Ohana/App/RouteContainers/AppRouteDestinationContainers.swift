//
//  AppRouteDestinationContainers.swift
//  Ohana
//
//  Typed route composition for global destinations.
//

import SwiftUI

struct AppRouteDestination: View {
    let route: AppRoute
    let onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    let onPresentTaskCenter: ((TaskCenterRouteContext) -> Void)?

    init(
        route: AppRoute,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil,
        onPresentTaskCenter: ((TaskCenterRouteContext) -> Void)? = nil
    ) {
        self.route = route
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onPresentTaskCenter = onPresentTaskCenter
    }

    var body: some View {
        switch route {
        case let .petProfile(id, initialTab):
            AppPetRouteContainer(
                id: id,
                initialTab: initialTab,
                onCreateCareTask: { preset in
                    onPresentTaskCenter?(.createCare(preset))
                }
            )
        case let .humanProfile(id):
            AppHumanRouteContainer(
                id: id,
                onPresentCoconutLog: onPresentCoconutLog ?? { _ in },
                onOpenTasks: { onPresentTaskCenter?(.human(id)) }
            )
        case let .plantProfile(id):
            if AppFeatureRouteGuard.allowsAppRoute(route) {
                AppPlantRouteContainer(
                    id: id,
                    onCreateCareTask: { preset in
                        onPresentTaskCenter?(.createCare(preset))
                    }
                )
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
    let onRequestStarterGiftClaim: () -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onHumanDoseTaken: (UUID) -> Void
    let routeLanguageCode: String

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
                .ohanaLocalizedEnvironment(routeLanguageCode)
                .globalCoconutRewardFeedbackOverlay()
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
                        onRequestStarterGiftClaim: onRequestStarterGiftClaim,
                        onCalendarEventDestination: handleCalendarEventDestination,
                        onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
                        onHumanDoseTaken: onHumanDoseTaken
                    )
                }
                .ohanaLocalizedEnvironment(routeLanguageCode)
                .appRouteSheetPresentation(for: route)
                .globalCoconutRewardFeedbackOverlay()
                .onAppear {
                    lastSheetRoute = route
                }
            }
            .sheet(item: $coordinator.overlay) { route in
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
                        onPresentSheet: { route in coordinator.presentSheet(route) },
                        onPresentCoconutLog: { subject in
                            coordinator.presentCoconutLog(subject)
                        }
                    )
                }
                .ohanaLocalizedEnvironment(routeLanguageCode)
                .appPresentationSheet(AppPresentationPolicyProvider.policy(for: route))
                .globalCoconutRewardFeedbackOverlay()
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
        case let .plant(plant):
            coordinator.openPlant(plant.id)
        case let .plantFeature(plant, destination):
            coordinator.presentFunctionMenu(destination: .plantFeature(plant.id, destination))
        case let .plantCare(plant, destination):
            coordinator.presentFunctionMenu(destination: .plantCare(plant.id, destination))
        case let .functionMenu(destination):
            coordinator.presentFunctionMenu(destination: destination)
        case let .calendar(entityID, humanID, plantID):
            coordinator.presentCalendar(entityID: entityID, humanID: humanID, plantID: plantID)
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
        onRequestStarterGiftClaim: @escaping () -> Void = {},
        onFirstSuccessMomentCompleted: @escaping (Pet) -> Void = { _ in },
        onHumanDoseTaken: @escaping (UUID) -> Void = { _ in },
        routeLanguageCode: String = AppLanguage.code
    ) -> some View {
        modifier(
            AppRoutePresentationHost(
                coordinator: coordinator,
                onRequiredHumanSaved: onRequiredHumanSaved,
                onAddEntityDismissed: onAddEntityDismissed,
                onPetSavedFromAddEntity: onPetSavedFromAddEntity,
                onHumanSavedFromAddEntity: onHumanSavedFromAddEntity,
                onRequestStarterGiftClaim: onRequestStarterGiftClaim,
                onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
                onHumanDoseTaken: onHumanDoseTaken,
                routeLanguageCode: routeLanguageCode
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
    let onRequestStarterGiftClaim: () -> Void
    let onCalendarEventDestination: (FocusHomeReminderDestination) -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onHumanDoseTaken: (UUID) -> Void
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        switch route {
        case .accountSwitcher:
            AppAccountSwitcherRouteContainer(onSwitched: onDismiss)
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        case let .addEntity(type):
            if AppFeatureRouteGuard.allowsAddEntity(type, currentLevel: currentFeatureLevel) {
                AddEntityDestinationView(
                    type: type,
                    onComplete: onDismiss,
                    onPetSaved: onPetSavedFromAddEntity,
                    onHumanSaved: onHumanSavedFromAddEntity
                )
                .ohanaSheetPagePresentation()
            } else {
                HiddenRouteInterceptView(note: "addEntity:\(type.rawValue)")
                    .onAppear(perform: onDismiss)
            }
        case let .calendar(entityID, humanID, _):
            CalendarRouteContainer(
                preselectedPetId: entityID,
                preselectedHumanId: humanID,
                onOpenEventDestination: onCalendarEventDestination,
                onPresentCoconutLog: { subject in
                    coordinator.presentCoconutLog(subject)
                }
            )
            .ohanaSheetPagePresentation()
        case let .taskCenter(context):
            TaskCenterRouteContainer(
                presentation: .sheet,
                initialSurface: .tasks,
                routeContext: context,
                onOpenEventDestination: onCalendarEventDestination,
                onOpenSystemDestination: { item in
                    switch item.systemDestination {
                    case .createFirstPet:
                        coordinator.presentAddEntity(.pet)
                    case .claimStarterGift:
                        onDismiss()
                        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
                            onRequestStarterGiftClaim()
                        }
                    case .completeHumanProfile:
                        if let id = item.subject.id { coordinator.presentSheet(.humanBasicInfo(id)) }
                    case .completeFirstPetProfile:
                        if let id = item.subject.id { coordinator.presentSheet(.petBasicInfo(id)) }
                    case .confirmPetIdentityProtection:
                        if let id = item.subject.id { coordinator.presentSheet(.petDocuments(id)) }
                    case .confirmPetPreventiveCare:
                        if let id = item.subject.id {
                            coordinator.presentSheet(.petHealth(id, initialSection: .preventive))
                        }
                    case .configureFirstCarePlan:
                        if let id = item.subject.id { coordinator.presentSheet(.petFood(id)) }
                    case .recordFirstCare:
                        if let id = item.subject.id {
                            coordinator.presentSheet(.petFeed(id, opensManualSheet: true))
                        }
                    case nil:
                        break
                    }
                },
                onPresentCoconutLog: { subject in
                    coordinator.presentCoconutLog(subject)
                },
                onDismiss: onDismiss
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
            if AppFeatureRouteGuard.allowsSheetRoute(route, currentLevel: currentFeatureLevel) {
                CoconutShopRouteContainer(initialCategory: category)
                    .ohanaSheetPagePresentation()
            } else {
                HiddenRouteInterceptView(
                    note: AppFeatureRouteGuard.lockedRouteNote(for: route, currentLevel: currentFeatureLevel)
                )
                .onAppear(perform: onDismiss)
            }
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
                    onInlinePetSaved: { pet in
                        onDismiss()
                        onPetSavedFromAddEntity(pet)
                    },
                    onInlineHumanSaved: { human in
                        onDismiss()
                        onHumanSavedFromAddEntity(human)
                    },
                    onClose: onDismiss,
                    onPresentCoconutLog: { subject in
                        coordinator.presentCoconutLog(subject)
                    },
                    onOpenTaskCenter: {
                        onDismiss()
                        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
                            coordinator.presentTaskCenter()
                        }
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
        case let .petWeightQuick(id):
            AppPetWeightQuickSheetHost(
                id: id,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .petWeight(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .weight,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .petExpenseQuick(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .expenseQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
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
        case let .petMomentQuick(id):
            AppQuickMomentOverlayRouteContainer(
                id: id,
                onSaved: onFirstSuccessMomentCompleted,
                onDismiss: onDismiss
            )
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
        case let .humanMedicationQuick(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .medicationQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss,
                onOpenDestination: openHumanDetailDestination
            )
        case let .humanMedication(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .medication,
                onMissing: onDismiss,
                onDismiss: onDismiss,
                onHumanDoseTaken: onHumanDoseTaken
            )
            .ohanaSheetPagePresentation()
        case let .humanWeightQuick(id):
            AppHumanWeightQuickSheetHost(
                id: id,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .humanWeight(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .weight,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .humanWorkoutQuick(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .workoutQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
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
        case let .humanExpenseQuick(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .expenseQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
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
        case let .humanNoteQuick(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .noteQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .humanNote(id):
            AppHumanDetailSheetRouteContainer(
                id: id,
                destination: .note,
                onMissing: onDismiss
            )
            .ohanaSheetPagePresentation()
        case let .guardianSafety(invitationCode, incidentID):
            NavigationStack {
                GuardianSafetyDashboardView(
                    initialInviteCode: invitationCode,
                    initialIncidentID: incidentID
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onDismiss) {
                            Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .ohanaSheetPagePresentation()
        case .requiredAccountSwitch:
            AppAccountSwitcherRouteContainer(allowsDismiss: false, onSwitched: onDismiss)
                .interactiveDismissDisabled(true)
        case .settings:
            AppSettingsSheetRouteContainer(onClose: onDismiss)
                .ohanaSheetPagePresentation()
        case .streakDetail:
            AppStreakDetailRouteContainer(
                onClose: onDismiss,
                onPresentCoconutLog: { subject in
                    coordinator.dismissSheet(.streakDetail)
                    OhanaFrameScheduler.runAfterNextFrame {
                        coordinator.presentCoconutLog(subject)
                    }
                },
                onPresentCoconutShop: { category in
                    coordinator.dismissSheet(.streakDetail)
                    OhanaFrameScheduler.runAfterNextFrame {
                        coordinator.presentCoconutShop(category: category)
                    }
                }
            )
            .ohanaSheetPagePresentation()
        }
    }

    private var currentFeatureLevel: Int {
        OasisTreeManagerRegistry.current.treeLevel.rawValue
    }

    private func openPetAllFeatureDestination(_ petID: UUID, destination: PetAllFeatureDestination) {
        let route: AppSheetRoute = switch destination {
        case .health:
            .petHealth(petID, initialSection: nil)
        case .medications:
            .petMedication(petID)
        case .food:
            .petFood(petID)
        case .hygiene:
            .petHygiene(petID)
        case .walks:
            .petWalkSummary(petID)
        case .potty:
            .petPotty(petID)
        case .basicInfo:
            .petBasicInfo(petID)
        case .documents:
            .petDocuments(petID)
        case .moments, .timeline:
            .petMomentHistory(petID)
        case .achievements:
            .petAchievements(petID)
        case .retention:
            .petRetention(petID)
        case .weight:
            .petWeight(petID)
        case .expense:
            .petExpense(petID)
        case .bondVault:
            .petBondVault(petID)
        }
        presentFeatureRouteAfterTap(route)
    }

    private func openHumanAllFeatureDestination(_ humanID: UUID, destination: HumanAllFeatureDestination) {
        let route: AppSheetRoute = switch destination {
        case .basicInfo:
            .humanBasicInfo(humanID)
        case .weight:
            .humanWeight(humanID)
        case .workout:
            .humanWorkoutDashboard(humanID)
        case .metrics:
            .humanMetrics(humanID)
        case .medication:
            .humanMedication(humanID)
        case .report:
            .humanReport(humanID)
        case .expense:
            .humanExpense(humanID)
        case .wishlist:
            .humanWishlist(humanID)
        case .notes:
            .humanNote(humanID)
        case .achievements:
            .functionMenu(destination: .featureAggregate(.achievements))
        }
        presentFeatureRouteAfterTap(route)
    }

    private func openHumanDetailDestination(_ humanID: UUID, destination: AppHumanDetailSheetDestination) {
        let route: AppSheetRoute = switch destination {
        case .basicInfo:
            .humanBasicInfo(humanID)
        case .medicationQuick:
            .humanMedicationQuick(humanID)
        case .medication:
            .humanMedication(humanID)
        case .weightQuick:
            .humanWeightQuick(humanID)
        case .weight:
            .humanWeight(humanID)
        case .workoutQuick:
            .humanWorkoutQuick(humanID)
        case .workout:
            .humanWorkout(humanID)
        case .workoutDashboard:
            .humanWorkoutDashboard(humanID)
        case .metrics:
            .humanMetrics(humanID)
        case .report:
            .humanReport(humanID)
        case .expenseQuick:
            .humanExpenseQuick(humanID)
        case .expense:
            .humanExpense(humanID)
        case .wishlist:
            .humanWishlist(humanID)
        case .noteQuick:
            .humanNoteQuick(humanID)
        case .note:
            .humanNote(humanID)
        }
        presentFeatureRouteAfterTap(route)
    }

    private func presentFeatureRouteAfterTap(_ route: AppSheetRoute) {
        OhanaFrameScheduler.runAfterNextFrame {
            coordinator.presentSheet(route)
        }
    }
}

private struct AppOverlayRouteDestination: View {
    let route: AppOverlayRoute
    let onDismiss: () -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onOpenPet: (UUID, PetDetailTab) -> Void
    let onOpenHuman: (UUID) -> Void
    let onPresentSheet: (AppSheetRoute) -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    var body: some View {
        switch route {
        case let .quickMoment(_, petID):
            AppQuickMomentOverlayRouteContainer(
                id: petID,
                onSaved: onFirstSuccessMomentCompleted,
                onDismiss: onDismiss
            )
        case let .petWeightQuick(_, petID):
            AppPetWeightQuickSheetHost(
                id: petID,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .petExpenseQuick(_, petID):
            AppPetDetailSheetRouteContainer(
                id: petID,
                destination: .expenseQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .humanMedicationQuick(_, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .medicationQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss,
                onOpenDestination: { id, destination in
                    onDismiss()
                    OhanaFrameScheduler.runAfterNextFrame {
                        onPresentSheet(humanDetailRoute(humanID: id, destination: destination))
                    }
                }
            )
        case let .humanWeightQuick(_, humanID):
            AppHumanWeightQuickSheetHost(
                id: humanID,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .humanWorkoutQuick(_, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .workoutQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .humanExpenseQuick(_, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .expenseQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        case let .humanNoteQuick(_, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .noteQuick,
                onMissing: onDismiss,
                onDismiss: onDismiss
            )
        }
    }

    private func humanDetailRoute(
        humanID: UUID,
        destination: AppHumanDetailSheetDestination
    ) -> AppSheetRoute {
        switch destination {
        case .basicInfo:
            .humanBasicInfo(humanID)
        case .medicationQuick:
            .humanMedicationQuick(humanID)
        case .medication:
            .humanMedication(humanID)
        case .weightQuick:
            .humanWeightQuick(humanID)
        case .weight:
            .humanWeight(humanID)
        case .workoutQuick:
            .humanWorkoutQuick(humanID)
        case .workout:
            .humanWorkout(humanID)
        case .workoutDashboard:
            .humanWorkoutDashboard(humanID)
        case .metrics:
            .humanMetrics(humanID)
        case .report:
            .humanReport(humanID)
        case .expenseQuick:
            .humanExpenseQuick(humanID)
        case .expense:
            .humanExpense(humanID)
        case .wishlist:
            .humanWishlist(humanID)
        case .noteQuick:
            .humanNoteQuick(humanID)
        case .note:
            .humanNote(humanID)
        }
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
