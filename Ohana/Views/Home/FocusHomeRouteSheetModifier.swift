//
//  FocusHomeRouteSheetModifier.swift
//  Ohana
//
//  Sheet/full-screen routing for the GO Focus home. Kept outside the main
//  home view so route churn does not bloat the card-stack render path.
//

import SwiftUI

struct FocusHomeRouteSheetModifier: ViewModifier {
    let pets: [Pet]
    let humans: [Human]
    let electronicPets: [OasisElectronicPet]
    let l: L10n

    @ObservedObject var routes: HomeRouteCoordinator

    @Binding var activeHumanIdStr: String
    @State private var lastModalRoute: HomeModalRoute?

    let onAddEntityDismissed: () -> Void
    let onPetSavedFromAddEntity: (Pet) -> Void
    let onHumanSavedFromAddEntity: (Human) -> Void
    let onCrewPetSelected: (Pet) -> Void
    let onCrewHumanSelected: (Human) -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onHumanDoseTaken: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: modalSheetRouteBinding, onDismiss: handleModalDismissed) { route in
                AppDeferredRouteContent(
                    routeID: route.id,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    homeModalDestination(for: route)
                }
                .appPresentationSheet(AppPresentationPolicyProvider.policy(for: route))
                .onAppear {
                    lastModalRoute = route
                }
            }
            .sheet(item: systemSheetRouteBinding) { route in
                AppDeferredRouteContent(
                    routeID: route.id,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    homeSheetDestination(for: route)
                }
                .appPresentationSheet(AppPresentationPolicyProvider.policy(for: route))
            }
            .fullScreenCover(item: fullScreenRouteBinding) { route in
                AppDeferredRouteContent(
                    routeID: route.id,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    homeFullScreenDestination(for: route)
                }
            }
            .overlay {
                homeOverlayLayer()
            }
            .alert(antiRepeatTitleText, isPresented: antiRepeatAlertBinding) {
                Button(l.homeConfirmCheckIn, role: .destructive) {
                    routes.confirmAntiRepeatAction()
                }
                Button(l.cancel, role: .cancel) {
                    routes.dismissAlert()
                }
            } message: {
                Text(antiRepeatMessageText)
            }
            .alert(singleUseNoticeTitleText, isPresented: singleUseNoticeAlertBinding) {
                Button(acknowledgeText, role: .cancel) {
                    routes.dismissAlert()
                }
            } message: {
                Text(singleUseNoticeMessageText)
            }
            .alert(quickActionLimitTitle, isPresented: quickActionLimitAlertBinding) {
                Button(acknowledgeText, role: .cancel) {
                    routes.dismissAlert()
                }
            } message: {
                Text(quickActionLimitMessage)
            }
            .alert(humanPrivacyTitle, isPresented: humanPrivacyAlertBinding) {
                Button(acknowledgeText, role: .cancel) {
                    routes.dismissAlert()
                }
            } message: {
                Text(humanPrivacyMessage)
            }
    }

    private var modalSheetRouteBinding: Binding<HomeModalRoute?> {
        Binding(
            get: {
                return routes.modal
            },
            set: { route in
                routes.modal = route
            }
        )
    }

    private var fullScreenRouteBinding: Binding<HomeFullScreenRoute?> {
        Binding(
            get: {
                return routes.fullScreen
            },
            set: { route in
                routes.fullScreen = route
            }
        )
    }

    private var systemSheetRouteBinding: Binding<HomeSheetRoute?> {
        Binding(
            get: {
                return routes.sheet
            },
            set: { route in
                routes.sheet = route
            }
        )
    }

    @ViewBuilder
    private func homeModalDestination(for route: HomeModalRoute) -> some View {
        switch route {
        case let .functionMenu(destination):
            FunctionMenuSheet(initialDestination: destination)
                .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
        case .streakDetail:
            DailyStreakDetailRouteContainer(
                onClose: { routes.dismissModal() },
                onPresentCoconutLog: { subject in
                    routes.openCoconutLog(subject)
                }
            )
                .ohanaSheetPagePresentation() // ui-v4: allow long streak overview
        case let .addEntity(type):
            AddEntityDestinationView(
                type: type,
                onComplete: { routes.dismissModal() },
                onPetSaved: onPetSavedFromAddEntity,
                onHumanSaved: { human in
                    activeHumanIdStr = human.id.uuidString
                    onHumanSavedFromAddEntity(human)
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow role creation flow as long sheet
        case let .coconutLog(subject):
            CoconutLogView(
                subject: subject,
                onClose: { routes.dismissModal() },
                historyContentDelayMilliseconds: 80
            )
            .ohanaSheetPagePresentation() // ui-v4: allow coconut history as long sheet
        case let .crewRoster(mode):
            NavigationStack {
                CrewRosterOverlayRouteContainer(
                    initialMode: mode,
                    onSelectPet: { pet in
                        routes.dismissModal()
                        onCrewPetSelected(pet)
                    },
                    onSelectHuman: { human in
                        routes.dismissModal()
                        onCrewHumanSelected(human)
                    },
                    onClose: { routes.dismissModal() },
                    onPresentCoconutLog: { subject in
                        routes.openCoconutLog(subject)
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { routes.dismissModal() } label: {
                            Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow family collaboration/member hub
        case .accountSwitcher:
            HumanAccountSwitcherSheet(
                humans: humans,
                homePets: pets,
                homeHumans: humans,
                homeElectronicPets: electronicPets
            )
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        case let .calendar(entityID, humanID):
            CalendarRouteContainer(
                preselectedPetId: entityID,
                preselectedHumanId: humanID,
                onOpenEventDestination: openCalendarEventDestination,
                onPresentCoconutLog: { subject in
                    routes.openCoconutLog(subject)
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow calendar as long sheet
        case .settings:
            SettingsView(
                homePets: pets,
                homeHumans: humans,
                homeElectronicPets: electronicPets,
                onClose: { routes.dismissModal() }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow settings as long sheet
        }
    }

    private func openCalendarEventDestination(_ destination: FocusHomeReminderDestination) {
        routes.dismissModal()
        DispatchQueue.main.async {
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
            routes.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, human: human)
        case let .humanDetail(human):
            routes.openSheet(.humanBasicInfo(human.id))
        case .plant:
            AppFeatureRouteGuard.recordIntercept("sheetReminderPlant")
            routes.openFunctionMenu(destination: .growthRoadmap)
        case let .functionMenu(destination):
            routes.openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId):
            routes.openCalendar(entityID: entityId, humanID: humanId)
        }
    }

    private func openPetQuickKey(_ key: String, pet: Pet) {
        switch key {
        case "feed":
            routes.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case "water", "waterChange", "filterClean":
            routes.openSheet(.petWater(pet.id))
        case "potty":
            routes.openSheet(.petPotty(pet.id))
        case "litter":
            routes.openSheet(.petLitter(pet.id))
        case "walk":
            routes.openSheet(.petWalkSummary(pet.id))
        case "play":
            routes.openSheet(.petPlay(pet.id))
        case "health":
            routes.openSheet(.petHealth(pet.id, initialSection: nil))
        case "medication":
            routes.openSheet(.petMedication(pet.id))
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            routes.openSheet(.petHygiene(pet.id))
        case "weight":
            routes.openSheet(.petWeight(pet.id))
        case "expense":
            routes.openSheet(.petExpense(pet.id))
        case "moment":
            routes.openQuickMoment(pet)
        default:
            routes.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openPetFeature(_ feature: PetFeature, pet: Pet) {
        switch feature {
        case .health:
            routes.openSheet(.petHealth(pet.id, initialSection: nil))
        case .medications:
            routes.openSheet(.petMedication(pet.id))
        case .food:
            routes.openSheet(.petFeed(pet.id, opensManualSheet: false))
        case .hygiene:
            routes.openSheet(.petHygiene(pet.id))
        case .walks:
            routes.openSheet(.petWalkSummary(pet.id))
        case .potty:
            routes.openSheet(.petPotty(pet.id))
        case .basicInfo:
            routes.openSheet(.petBasicInfo(pet.id))
        case .moments:
            routes.openSheet(.petMomentHistory(pet.id))
        case .weight:
            routes.openSheet(.petWeight(pet.id))
        case .expense:
            routes.openSheet(.petExpense(pet.id))
        case .retention, .documents, .achievements:
            routes.openSheet(.petAllFeatures(pet.id))
        }
    }

    private func openHumanQuickKey(_ key: String, human: Human) {
        switch key {
        case "humanWeight":
            routes.openSheet(.humanWeight(human.id))
        case "humanWorkout":
            routes.openSheet(.humanWorkout(human.id))
        case "humanMedication":
            routes.openSheet(.humanMedication(human.id))
        case "humanExpense":
            routes.openSheet(.humanExpense(human.id))
        case "humanNote":
            routes.openSheet(.humanNote(human.id))
        default:
            routes.openSheet(.humanAllFeatures(human.id))
        }
    }

    @ViewBuilder
    private func homeFullScreenDestination(for route: HomeFullScreenRoute) -> some View {
        switch route {
        case let .walk(id):
            if let pet = pet(id) {
                WalkTrackingFullScreen(pet: pet)
            } else {
                missingFullScreenDismissView()
            }
        case .oasisReward:
            OasisRewardView()
        }
    }

    @ViewBuilder
    private func homeOverlayLayer() -> some View {
        homeOverlayDestination()
    }

    @ViewBuilder
    private func homeOverlayDestination() -> some View {
        if let route = routes.overlay {
            AppDeferredRouteContent(
                routeID: route.id.uuidString,
                policy: AppPresentationPolicyProvider.policy(for: route)
            ) {
                switch route {
                case let .quickMoment(routeID, petID):
                    if let pet = pet(petID) {
                        OhanaInlinePageRouteHost(routeID: routeID.uuidString, onClose: {
                            routes.dismissOverlay(routeID: routeID)
                        }) { requestClose in
                            QuickMomentSheet(
                                pet: pet,
                                onRemove: nil,
                                onSaved: {
                                    onFirstSuccessMomentCompleted(pet)
                                },
                                onClose: requestClose
                            )
                        }
                    } else {
                        Color.clear
                            .onAppear {
                                routes.dismissOverlay(routeID: routeID)
                            }
                    }
                }
            }
            .ignoresSafeArea()
            .zIndex(100)
        }
    }

    private func handleModalDismissed() {
        defer { lastModalRoute = nil }
        if case .addEntity = lastModalRoute {
            onAddEntityDismissed()
        }
    }

    private var antiRepeatAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .antiRepeat = routes.alert { return true }
                return false
            },
            set: { isPresented in
                if !isPresented { routes.dismissAlert() }
            }
        )
    }

    private var singleUseNoticeAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .singleUseNotice = routes.alert { return true }
                return false
            },
            set: { isPresented in
                if !isPresented { routes.dismissAlert() }
            }
        )
    }

    private var quickActionLimitAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .quickActionLimit = routes.alert { return true }
                return false
            },
            set: { isPresented in
                if !isPresented { routes.dismissAlert() }
            }
        )
    }

    private var humanPrivacyAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .humanPrivacy = routes.alert { return true }
                return false
            },
            set: { isPresented in
                if !isPresented { routes.dismissAlert() }
            }
        )
    }

    private var antiRepeatTitleText: String {
        if case let .antiRepeat(_, title, _) = routes.alert { return title }
        return ""
    }

    private var antiRepeatMessageText: String {
        if case let .antiRepeat(_, _, message) = routes.alert { return message }
        return ""
    }

    private var singleUseNoticeTitleText: String {
        if case let .singleUseNotice(_, title, _) = routes.alert { return title }
        return ""
    }

    private var singleUseNoticeMessageText: String {
        if case let .singleUseNotice(_, _, message) = routes.alert { return message }
        return ""
    }

    private var acknowledgeText: String {
        l.tr(zh: "知道了", en: "Got it", de: "Verstanden")
    }

    private var quickActionLimitTitle: String {
        l.tr(
            zh: QuickActionLimit.title,
            en: "Quick actions are full",
            de: "Schnellaktionen sind voll"
        )
    }

    private var quickActionLimitMessage: String {
        l.tr(
            zh: QuickActionLimit.message,
            en: "You can add up to 8 quick actions here. More features are available in All Features.",
            de: "Hier sind bis zu 8 Schnellaktionen moglich. Weitere Funktionen findest du unter Alle Funktionen."
        )
    }

    private var humanPrivacyTitle: String {
        l.tr(zh: "仅本人可见", en: "Private to this member", de: "Nur fur dieses Mitglied")
    }

    private var humanPrivacyMessage: String {
        l.tr(
            zh: "该成员已将此功能设为仅自己可见。",
            en: "This member has made this feature visible only to themselves.",
            de: "Dieses Mitglied hat diese Funktion nur fur sich selbst sichtbar gemacht."
        )
    }

    @ViewBuilder
    private func homeSheetDestination(for route: HomeSheetRoute) -> some View {
        switch route {
        case let .petAllFeatures(id):
            if let pet = pet(id) {
                PetAllFeaturesSheet(
                    pet: pet,
                    onOpenDestination: { destination in
                        routes.openSheet(homePetFeatureRoute(petID: pet.id, destination: destination))
                    }
                )
                    .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanAllFeatures(id):
            HumanAllFeaturesRouteContainer(
                id: id,
                onMissing: { routes.dismissSheet() },
                onOpenDestination: { humanID, destination in
                    routes.openSheet(homeHumanFeatureRoute(humanID: humanID, destination: destination))
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
        case let .petBasicInfo(id):
            if let pet = pet(id) {
                NavigationStack { PetBasicInfoDetailView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanBasicInfo(id):
            if let human = human(id) {
                NavigationStack { HumanBasicInfoDetailView(human: human) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petFood(id):
            if let pet = pet(id) {
                NavigationStack { PetFoodManagementView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petWeight(id):
            if let pet = pet(id) {
                NavigationStack { WeightHistoryView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petExpense(id):
            if let pet = pet(id) {
                NavigationStack { ExpenseHistoryView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petFeed(id, opensManualSheet):
            if let pet = pet(id) {
                QuickFeedDetailRouteContainer(
                    id: pet.id,
                    onRemove: { routes.dismissSheet() },
                    onClose: { routes.dismissSheet() },
                    opensManualSheetOnAppear: opensManualSheet
                )
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petWater(id):
            if let pet = pet(id) {
                QuickWaterDetailRouteContainer(id: pet.id, onRemove: { routes.dismissSheet() }, onClose: { routes.dismissSheet() })
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petPotty(id):
            if let pet = pet(id) {
                QuickPottyDetailRouteContainer(id: pet.id, onRemove: { routes.dismissSheet() }, onClose: { routes.dismissSheet() })
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petLitter(id):
            if let pet = pet(id) {
                QuickPottyDetailRouteContainer(id: pet.id, onRemove: { routes.dismissSheet() }, onClose: { routes.dismissSheet() })
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petPlay(id):
            QuickPlayDetailRouteContainer(id: id, onRemove: { routes.dismissSheet() })
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petHygiene(id):
            if let pet = pet(id) {
                NavigationStack { PetHygieneDetailView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petWalkSummary(id):
            if let pet = pet(id) {
                NavigationStack { WalkSummarySheet(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petHealth(id, initialSection):
            if let pet = pet(id) {
                NavigationStack {
                    PetHealthDetailView(
                        pet: pet,
                        isModal: true,
                        initialSection: initialSection
                    )
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petMedication(id):
            if let pet = pet(id) {
                NavigationStack { PetMedicationView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petMomentHistory(id):
            if let pet = pet(id) {
                PetMomentsHubView(pet: pet)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petDocuments(id):
            if let pet = pet(id) {
                DocumentsListView(pet: pet, showsCloseButton: true)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petAchievements(id):
            if let pet = pet(id) {
                NavigationStack {
                    AchievementWallView(
                        pet: pet,
                        onPresentCoconutLog: { subject in
                            routes.openCoconutLog(subject)
                        }
                    )
                }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petRetention(id):
            if let pet = pet(id) {
                PetRetentionHubView(pet: pet, showsCloseButton: true)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petBondVault(id):
            if let pet = pet(id) {
                NavigationStack { PetBondVaultView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanMedication(id):
            if let human = human(id) {
                NavigationStack {
                    HumanMedicationView(
                        human: human,
                        showsDoneButton: true,
                        onDoseTaken: {
                            onHumanDoseTaken(human.id)
                        }
                    )
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanWeight(id):
            if let human = human(id) {
                NavigationStack { HumanWeightHistoryView(human: human) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanWorkout(id):
            if let human = human(id) {
                HumanWorkoutHistoryView(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanWorkoutDashboard(id):
            if let human = human(id) {
                CoHealthDashboardFullView(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanMetrics(id):
            if let human = human(id) {
                HumanHealthCheckupView(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanReport(id):
            if let human = human(id) {
                HumanHealthReportView(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanExpense(id):
            if let human = human(id) {
                NavigationStack { HumanExpenseDetailView(human: human) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanWishlist(id):
            if let human = human(id) {
                HumanWishlistView(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanNote(id):
            if let human = human(id) {
                HumanNoteHistorySheet(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        }
    }

    private func pet(_ id: UUID) -> Pet? {
        pets.first { $0.id == id }
    }

    private func human(_ id: UUID) -> Human? {
        humans.first { $0.id == id }
    }

    private func homePetFeatureRoute(
        petID: UUID,
        destination: PetAllFeatureDestination
    ) -> HomeSheetRoute {
        switch destination {
        case .health:
            return .petHealth(petID, initialSection: nil)
        case .medications:
            return .petMedication(petID)
        case .food:
            return .petFood(petID)
        case .hygiene:
            return .petHygiene(petID)
        case .walks:
            return .petWalkSummary(petID)
        case .potty:
            return .petPotty(petID)
        case .basicInfo:
            return .petBasicInfo(petID)
        case .documents:
            return .petDocuments(petID)
        case .moments, .timeline:
            return .petMomentHistory(petID)
        case .achievements:
            return .petAchievements(petID)
        case .retention:
            return .petRetention(petID)
        case .weight:
            return .petWeight(petID)
        case .expense:
            return .petExpense(petID)
        case .bondVault:
            return .petBondVault(petID)
        }
    }

    private func homeHumanFeatureRoute(
        humanID: UUID,
        destination: HumanAllFeatureDestination
    ) -> HomeSheetRoute {
        switch destination {
        case .basicInfo:
            return .humanBasicInfo(humanID)
        case .weight:
            return .humanWeight(humanID)
        case .workout:
            return .humanWorkoutDashboard(humanID)
        case .metrics:
            return .humanMetrics(humanID)
        case .medication:
            return .humanMedication(humanID)
        case .report:
            return .humanReport(humanID)
        case .expense:
            return .humanExpense(humanID)
        case .wishlist:
            return .humanWishlist(humanID)
        case .notes:
            return .humanNote(humanID)
        }
    }

    private func missingRouteDismissView() -> some View {
        Color.clear
            .onAppear {
                routes.dismissSheet()
            }
    }

    private func missingFullScreenDismissView() -> some View {
        Color.clear
            .onAppear {
                routes.dismissFullScreen()
            }
    }

}

struct HomeSettingsInlineHost: View {
    let homePets: [Pet]
    let homeHumans: [Human]
    let homeElectronicPets: [OasisElectronicPet]
    let onClose: () -> Void

    var body: some View {
        OhanaInlinePageRouteHost(routeID: "home-settings", onClose: onClose) { requestClose in
            SettingsView(
                homePets: homePets,
                homeHumans: homeHumans,
                homeElectronicPets: homeElectronicPets,
                onClose: requestClose
            )
        }
    }
}

struct HomeCrewRosterInlineHost: View {
    let initialMode: CrewRosterMode
    let onClose: () -> Void
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onPresentCoconutLog: (CoconutLogSubject?) -> Void = { _ in }

    var body: some View {
        OhanaInlinePageRouteHost(routeID: "home-crew-roster-\(initialMode.rawValue)", onClose: onClose) { requestClose in
            HomeCrewRosterInlineContent(
                initialMode: initialMode,
                onClose: requestClose,
                onSelectPet: onSelectPet,
                onSelectHuman: onSelectHuman,
                onPresentCoconutLog: onPresentCoconutLog
            )
        }
    }
}

private struct HomeCrewRosterInlineContent: View {
    let initialMode: CrewRosterMode
    let onClose: () -> Void
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @Environment(\.ohanaInlinePageSafeAreaInsets) private var inlineSafeAreaInsets

    var body: some View {
        CrewRosterOverlayRouteContainer(
            initialMode: initialMode,
            onSelectPet: onSelectPet,
            onSelectHuman: onSelectHuman,
            onClose: onClose,
            safeTopInset: inlineSafeAreaInsets.top,
            safeBottomInset: inlineSafeAreaInsets.bottom,
            onPresentCoconutLog: onPresentCoconutLog
        )
    }
}

struct HomeCoconutLogInlineHost: View {
    let subject: CoconutLogSubject?
    let onClose: () -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    var body: some View {
        OhanaInlinePageRouteHost(routeID: "home-coconut-log-\(subject?.id ?? "all")", onClose: onClose) { requestClose in
            HomeCoconutLogInlineContent(
                subject: subject,
                onClose: requestClose,
                historyContentDelayMilliseconds: historyContentDelayMilliseconds
            )
        }
    }

    private var allowsMotion: Bool {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion
    }

    private var historyContentDelayMilliseconds: UInt64 {
        allowsMotion ? 220 : 0
    }
}

private struct HomeCoconutLogInlineContent: View {
    let subject: CoconutLogSubject?
    let onClose: () -> Void
    let historyContentDelayMilliseconds: UInt64
    @Environment(\.ohanaInlinePageSafeAreaInsets) private var inlineSafeAreaInsets

    var body: some View {
        CoconutLogView(
            subject: subject,
            onClose: onClose,
            safeTopInset: inlineSafeAreaInsets.top,
            safeBottomInset: inlineSafeAreaInsets.bottom,
            historyContentDelayMilliseconds: historyContentDelayMilliseconds
        )
    }
}

private extension AppPresentationPolicyProvider {
    static func policy(for route: HomeModalRoute) -> AppPresentationPolicy {
        switch route {
        case .accountSwitcher:
            return AppPresentationPolicy(
                surface: .compactSheet,
                loading: .shellFirst(delayMS: 64),
                instrumentationName: "home.accountSwitcher",
                detents: [.medium, .large],
                cornerRadius: 32
            )
        case .functionMenu:
            return homeSheetPagePolicy("home.functionMenu")
        case .streakDetail:
            return homeSheetPagePolicy("home.streakDetail")
        case .addEntity:
            return homeSheetPagePolicy("home.addEntity")
        case .coconutLog:
            return homeSheetPagePolicy("home.coconutLog")
        case .crewRoster:
            return homeSheetPagePolicy("home.crewRoster")
        case .calendar:
            return homeSheetPagePolicy("home.calendar")
        case .settings:
            return homeSheetPagePolicy("home.settings")
        }
    }

    static func policy(for route: HomeSheetRoute) -> AppPresentationPolicy {
        homeSheetPagePolicy("home.\(route.presentationName)")
    }

    static func policy(for route: HomeFullScreenRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .fullScreen,
            loading: .shellFirst(delayMS: 64),
            instrumentationName: "home.\(route.presentationName)"
        )
    }

    static func policy(for route: HomeOverlayRoute) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .inlineOverlay,
            loading: .immediate,
            instrumentationName: "home.\(route.presentationName)"
        )
    }

    static func policyForHomeCoconutLog() -> AppPresentationPolicy {
        homeSheetPagePolicy("home.coconutLog")
    }

    static func policyForHomeCrewRoster() -> AppPresentationPolicy {
        homeSheetPagePolicy("home.crewRoster")
    }

    static func policyForHomeSettings() -> AppPresentationPolicy {
        homeSheetPagePolicy("home.settings")
    }

    private static func homeSheetPagePolicy(_ name: String) -> AppPresentationPolicy {
        AppPresentationPolicy(
            surface: .sheetPage,
            loading: .shellFirst(delayMS: 80),
            instrumentationName: name,
            detents: [.large],
            cornerRadius: 36
        )
    }
}

private extension HomeSheetRoute {
    var presentationName: String {
        switch self {
        case .petAllFeatures:
            return "petAllFeatures"
        case .humanAllFeatures:
            return "humanAllFeatures"
        case .petBasicInfo:
            return "petBasicInfo"
        case .humanBasicInfo:
            return "humanBasicInfo"
        case .petFood:
            return "petFood"
        case .petWeight:
            return "petWeight"
        case .petExpense:
            return "petExpense"
        case .petFeed:
            return "petFeed"
        case .petWater:
            return "petWater"
        case .petPotty:
            return "petPotty"
        case .petLitter:
            return "petLitter"
        case .petPlay:
            return "petPlay"
        case .petHygiene:
            return "petHygiene"
        case .petWalkSummary:
            return "petWalkSummary"
        case .petHealth:
            return "petHealth"
        case .petMedication:
            return "petMedication"
        case .petMomentHistory:
            return "petMomentHistory"
        case .petDocuments:
            return "petDocuments"
        case .petAchievements:
            return "petAchievements"
        case .petRetention:
            return "petRetention"
        case .petBondVault:
            return "petBondVault"
        case .humanMedication:
            return "humanMedication"
        case .humanWeight:
            return "humanWeight"
        case .humanWorkout:
            return "humanWorkout"
        case .humanWorkoutDashboard:
            return "humanWorkoutDashboard"
        case .humanMetrics:
            return "humanMetrics"
        case .humanReport:
            return "humanReport"
        case .humanExpense:
            return "humanExpense"
        case .humanWishlist:
            return "humanWishlist"
        case .humanNote:
            return "humanNote"
        }
    }
}

private extension HomeFullScreenRoute {
    var presentationName: String {
        switch self {
        case .walk:
            return "walk"
        case .oasisReward:
            return "oasisReward"
        }
    }
}

private extension HomeOverlayRoute {
    var presentationName: String {
        switch self {
        case .quickMoment:
            return "quickMoment"
        }
    }
}

extension View {
    func focusHomeRouteSheets(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        l: L10n,
        routes: HomeRouteCoordinator,
        activeHumanIdStr: Binding<String>,
        onAddEntityDismissed: @escaping () -> Void,
        onPetSavedFromAddEntity: @escaping (Pet) -> Void,
        onHumanSavedFromAddEntity: @escaping (Human) -> Void = { _ in },
        onCrewPetSelected: @escaping (Pet) -> Void,
        onCrewHumanSelected: @escaping (Human) -> Void,
        onFirstSuccessMomentCompleted: @escaping (Pet) -> Void,
        onHumanDoseTaken: @escaping (UUID) -> Void
    ) -> some View {
        modifier(FocusHomeRouteSheetModifier(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            l: l,
            routes: routes,
            activeHumanIdStr: activeHumanIdStr,
            onAddEntityDismissed: onAddEntityDismissed,
            onPetSavedFromAddEntity: onPetSavedFromAddEntity,
            onHumanSavedFromAddEntity: onHumanSavedFromAddEntity,
            onCrewPetSelected: onCrewPetSelected,
            onCrewHumanSelected: onCrewHumanSelected,
            onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
            onHumanDoseTaken: onHumanDoseTaken
        ))
    }
}
