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
                homeModalDestination(for: route)
                    .onAppear {
                        lastModalRoute = route
                    }
            }
            .sheet(item: systemSheetRouteBinding) { route in
                homeSheetDestination(for: route)
            }
            .fullScreenCover(item: fullScreenRouteBinding) { route in
                homeFullScreenDestination(for: route)
            }
            .overlay {
                ZStack {
                    homeOverlayLayer()
                    inlineSettingsLayer()
                }
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
                if activeCrewRosterMode != nil {
                    return nil
                }
                return routes.modal
            },
            set: { route in
                if route == nil,
                   activeCrewRosterMode != nil {
                    return
                }
                routes.modal = route
            }
        )
    }

    private var fullScreenRouteBinding: Binding<HomeFullScreenRoute?> {
        Binding(
            get: {
                if case .coconutLog = routes.fullScreen {
                    return nil
                }
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

    private var settingsRouteIsActive: Bool {
        routes.settingsPresented
    }

    private var activeCrewRosterMode: CrewRosterMode? {
        if case let .some(.crewRoster(mode)) = routes.modal {
            return mode
        }
        return nil
    }

    @ViewBuilder
    private func homeModalDestination(for route: HomeModalRoute) -> some View {
        switch route {
        case let .functionMenu(destination):
            FunctionMenuSheet(initialDestination: destination)
                .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
        case .streakDetail:
            DailyStreakDetailView(pets: pets, onClose: { routes.dismissModal() })
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
        case let .crewRoster(mode):
            NavigationStack {
                CrewRosterOverlay(
                    initialMode: mode,
                    onSelectPet: { pet in
                        routes.dismissModal()
                        onCrewPetSelected(pet)
                    },
                    onSelectHuman: { human in
                        routes.dismissModal()
                        onCrewHumanSelected(human)
                    },
                    onClose: { routes.dismissModal() }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { routes.dismissModal() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow family collaboration/member hub
        case .accountSwitcher:
            HumanAccountSwitcherSheet(
                homePets: pets,
                homeHumans: humans,
                homeElectronicPets: electronicPets
            )
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        case let .calendar(entityID, humanID):
            CalendarView(
                preselectedPetId: entityID,
                preselectedHumanId: humanID,
                onOpenEventDestination: openCalendarEventDestination
            )
            .ohanaSheetPagePresentation() // ui-v4: allow calendar as long sheet
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
            routes.openFunctionMenu(destination: .plantsDashboard)
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
        case let .coconutLog(subject):
            CoconutLogView(subject: subject)
        }
    }

    @ViewBuilder
    private func inlineSettingsLayer() -> some View {
        if settingsRouteIsActive {
            HomeSettingsInlineHost(
                homePets: pets,
                homeHumans: humans,
                homeElectronicPets: electronicPets,
                onClose: {
                    if routes.settingsPresented {
                        routes.dismissSettings()
                    }
                }
            )
            .ignoresSafeArea()
            .zIndex(120)
        }
    }

    @ViewBuilder
    private func homeOverlayLayer() -> some View {
        homeOverlayDestination()
        inlineCoconutLogDestination()
        crewRosterOverlayDestination()
    }

    @ViewBuilder
    private func inlineCoconutLogDestination() -> some View {
        if case let .coconutLog(subject) = routes.fullScreen {
            HomeCoconutLogInlineHost(
                subject: subject,
                onClose: {
                    routes.dismissFullScreen()
                }
            )
            .ignoresSafeArea()
            .zIndex(130)
        }
    }

    @ViewBuilder
    private func crewRosterOverlayDestination() -> some View {
        if case let .some(.crewRoster(mode)) = routes.modal {
            HomeCrewRosterInlineHost(
                initialMode: mode,
                onClose: {
                    routes.dismissModal()
                },
                onSelectPet: { pet in
                    routes.dismissModal()
                    onCrewPetSelected(pet)
                },
                onSelectHuman: { human in
                    routes.dismissModal()
                    onCrewHumanSelected(human)
                }
            )
            .ignoresSafeArea()
            .zIndex(140)
        }
    }

    @ViewBuilder
    private func homeOverlayDestination() -> some View {
        if let route = routes.overlay {
            switch route {
            case let .quickMoment(routeID, petID):
                if let pet = pet(petID) {
                    QuickMomentSheet(
                        pet: pet,
                        onRemove: nil,
                        onSaved: {
                            onFirstSuccessMomentCompleted(pet)
                        },
                        onClose: {
                            routes.dismissOverlay(routeID: routeID)
                        }
                    )
                    .ignoresSafeArea()
                    .zIndex(100)
                } else {
                    Color.clear
                        .onAppear {
                            routes.dismissOverlay(routeID: routeID)
                        }
                }
            }
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
            if let human = human(id) {
                HumanAllFeaturesSheet(
                    human: human,
                    onOpenDestination: { destination in
                        routes.openSheet(homeHumanFeatureRoute(humanID: human.id, destination: destination))
                    }
                )
                    .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
            } else {
                missingRouteDismissView()
            }
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
                QuickFeedDetailSheet(
                    pet: pet,
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
                QuickWaterDetailSheet(pet: pet) {
                    routes.dismissSheet()
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petPotty(id):
            if let pet = pet(id) {
                QuickPottyDetailSheet(pet: pet) { routes.dismissSheet() }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petLitter(id):
            if let pet = pet(id) {
                QuickLitterDetailSheet(pet: pet) { routes.dismissSheet() }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
        case let .petPlay(id):
            if let pet = pet(id) {
                QuickPlayDetailSheet(pet: pet) { routes.dismissSheet() }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            } else {
                missingRouteDismissView()
            }
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
                NavigationStack { AchievementWallView(pet: pet) }
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

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var presentationProgress: CGFloat = 0
    @State private var isContentMounted = false
    @State private var isInteractionReady = false
    @State private var isClosing = false
    @State private var closeTask: Task<Void, Never>?

    var body: some View {
        OhanaDeferredInlinePageCover(
            progress: presentationProgress,
            isContentMounted: isContentMounted
        ) {
            SettingsView(
                homePets: homePets,
                homeHumans: homeHumans,
                homeElectronicPets: homeElectronicPets,
                onClose: requestClose
            )
        }
        .allowsHitTesting(isInteractionReady && !isClosing)
        .accessibilityAddTraits(.isModal)
        .task {
            await playEntrance()
        }
        .onDisappear {
            closeTask?.cancel()
        }
    }

    @MainActor
    private func playEntrance() async {
        closeTask?.cancel()
        presentationProgress = 0
        isContentMounted = false
        isInteractionReady = false
        isClosing = false

        await OhanaFrameScheduler.waitAfterNextFrame()
        guard !Task.isCancelled else { return }
        setPresentationProgress(1)

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: contentMountDelayMilliseconds)
        guard !Task.isCancelled, !isClosing else { return }
        withAnimation(GoMotion.quick) {
            isContentMounted = true
        }

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: interactionReadyDelayMilliseconds)
        guard !Task.isCancelled, !isClosing else { return }
        isInteractionReady = true
    }

    private func requestClose() {
        guard !isClosing else { return }
        isClosing = true
        isInteractionReady = false
        OhanaFeedback.light()
        withAnimation(GoMotion.quick) {
            isContentMounted = false
        }
        setPresentationProgress(0)
        closeTask?.cancel()
        closeTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: closeDelayMilliseconds) {
            onClose()
        }
    }

    private func setPresentationProgress(_ progress: CGFloat) {
        guard allowsMotion else {
            presentationProgress = progress
            return
        }
        withAnimation(GoMotion.sheetEnter) {
            presentationProgress = progress
        }
    }

    private var allowsMotion: Bool {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion
    }

    private var contentMountDelayMilliseconds: UInt64 {
        allowsMotion ? 80 : 0
    }

    private var interactionReadyDelayMilliseconds: UInt64 {
        allowsMotion ? 360 : 0
    }

    private var closeDelayMilliseconds: UInt64 {
        allowsMotion ? 340 : 90
    }
}

struct HomeCrewRosterInlineHost: View {
    let initialMode: CrewRosterMode
    let onClose: () -> Void
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void

    @StateObject private var safeAreaController = FocusHomeSafeAreaController()
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isShellVisible = false
    @State private var isContentMounted = false
    @State private var isContentVisible = false
    @State private var isInteractionReady = false
    @State private var isClosing = false
    @State private var closeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let safeTop = safeAreaController.resolvedTop(in: proxy)
            let safeBottom = safeAreaController.resolvedBottom(in: proxy)

            ZStack {
                ZStack {
                    OhanaAppBackground()
                        .ignoresSafeArea()

                    ZStack {
                        HomeCrewRosterOpeningShell(
                            initialMode: initialMode,
                            safeTopInset: safeTop,
                            onClose: requestClose
                        )
                        .opacity(isContentMounted ? 0 : 1)

                        if isContentMounted {
                            CrewRosterOverlay(
                                initialMode: initialMode,
                                onSelectPet: selectPet,
                                onSelectHuman: selectHuman,
                                onClose: requestClose,
                                safeTopInset: safeTop,
                                safeBottomInset: safeBottom
                            )
                            .opacity(isContentVisible ? 1 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: presentationOffset(in: proxy, safeBottom: safeBottom))
                .allowsHitTesting(isInteractionReady && !isClosing)
            }
            .accessibilityAddTraits(.isModal)
            .onAppear {
                safeAreaController.stabilize(from: proxy)
            }
        }
        .task {
            await playEntrance()
        }
        .onDisappear {
            closeTask?.cancel()
        }
    }

    @MainActor
    private func playEntrance() async {
        isShellVisible = false
        isContentMounted = false
        isContentVisible = false
        isInteractionReady = false
        isClosing = false

        await OhanaFrameScheduler.waitAfterNextFrame()
        guard !Task.isCancelled else { return }
        isContentMounted = true
        isContentVisible = true

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: contentPrepareDelayMilliseconds)
        guard !Task.isCancelled, !isClosing else { return }
        withAnimation(drawerEnterAnimation) {
            isShellVisible = true
        }

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: interactionReadyDelayMilliseconds)
        guard !Task.isCancelled, !isClosing else { return }
        isInteractionReady = true
    }

    private func requestClose() {
        closeThen(onClose)
    }

    private func selectPet(_ pet: Pet) {
        closeThen {
            onSelectPet(pet)
        }
    }

    private func selectHuman(_ human: Human) {
        closeThen {
            onSelectHuman(human)
        }
    }

    private func closeThen(_ action: @escaping () -> Void) {
        guard !isClosing else { return }
        isClosing = true
        isInteractionReady = false
        OhanaFeedback.light()
        withAnimation(drawerExitAnimation) {
            isShellVisible = false
        }
        closeTask?.cancel()
        closeTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: closeDelayMilliseconds) {
            action()
        }
    }

    private func presentationOffset(in proxy: GeometryProxy, safeBottom: CGFloat) -> CGFloat {
        guard allowsMotion else { return 0 }
        return isShellVisible ? 0 : proxy.size.height + safeBottom + 24
    }

    private var allowsMotion: Bool {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion
    }

    private var drawerEnterAnimation: Animation {
        allowsMotion ? .smooth(duration: 0.38, extraBounce: 0.0) : GoMotion.reduced
    }

    private var drawerExitAnimation: Animation {
        allowsMotion ? .smooth(duration: 0.38, extraBounce: 0.0) : GoMotion.reduced
    }

    private var contentPrepareDelayMilliseconds: UInt64 {
        allowsMotion ? 32 : 0
    }

    private var closeDelayMilliseconds: UInt64 {
        allowsMotion ? 430 : 90
    }

    private var interactionReadyDelayMilliseconds: UInt64 {
        allowsMotion ? 420 : 0
    }
}

private struct HomeCrewRosterOpeningShell: View {
    let initialMode: CrewRosterMode
    let safeTopInset: CGFloat
    let onClose: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        let isCollaboration = initialMode == .collaboration
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: isCollaboration ? "hands.sparkles.fill" : "person.2.crop.square.stack.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCollaboration
                         ? l.tr(zh: "家庭协作", en: "Family Care", de: "Familienpflege")
                         : l.tr(zh: "Ohana 成员", en: "Ohana Members", de: "Ohana Mitglieder"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isCollaboration
                         ? l.tr(zh: "任务、悬赏和今日分工", en: "Tasks, bounties, and today's handoff", de: "Aufgaben, Prämien und heutige Übergabe")
                         : l.tr(zh: "成员和首页显示", en: "Members and home cards", de: "Mitglieder und Startkarten"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
            .padding(.horizontal, 18)
            .padding(.top, safeTopInset + 16)
            .padding(.bottom, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HomeCoconutLogInlineHost: View {
    let subject: CoconutLogSubject
    let onClose: () -> Void

    @StateObject private var safeAreaController = FocusHomeSafeAreaController()
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isShellVisible = false
    @State private var isContentMounted = false
    @State private var isContentVisible = false
    @State private var isInteractionReady = false
    @State private var isClosing = false
    @State private var closeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let safeTop = safeAreaController.resolvedTop(in: proxy)
            let safeBottom = safeAreaController.resolvedBottom(in: proxy)

            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                ZStack {
                    HomeCoconutLogOpeningShell(
                        safeTopInset: safeTop,
                        onClose: requestClose
                    )
                    .opacity(isContentMounted ? 0 : 1)

                    if isContentMounted {
                        CoconutLogView(
                            subject: subject,
                            onClose: requestClose,
                            safeTopInset: safeTop,
                            safeBottomInset: safeBottom,
                            historyContentDelayMilliseconds: historyContentDelayMilliseconds
                        )
                            .opacity(isContentVisible ? 1 : 0)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: presentationOffset(in: proxy, safeBottom: safeBottom))
                .allowsHitTesting(isInteractionReady && !isClosing)
            }
            .accessibilityAddTraits(.isModal)
            .onAppear {
                safeAreaController.stabilize(from: proxy)
            }
        }
        .task(id: subject.id) {
            await playEntrance()
        }
        .onDisappear {
            closeTask?.cancel()
        }
    }

    @MainActor
    private func playEntrance() async {
        closeTask?.cancel()
        isShellVisible = false
        isContentMounted = false
        isContentVisible = false
        isInteractionReady = false
        isClosing = false

        await OhanaFrameScheduler.waitAfterNextFrame()
        guard !Task.isCancelled else { return }
        isContentMounted = true
        isContentVisible = true

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: contentPrepareDelayMilliseconds)
        guard !Task.isCancelled, !isClosing else { return }
        withAnimation(drawerEnterAnimation) {
            isShellVisible = true
        }

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: interactionReadyDelayMilliseconds)
        guard !Task.isCancelled, !isClosing else { return }
        isInteractionReady = true
    }

    private func requestClose() {
        guard !isClosing else { return }
        isClosing = true
        isInteractionReady = false
        OhanaFeedback.light()
        withAnimation(drawerExitAnimation) {
            isShellVisible = false
        }
        closeTask?.cancel()
        closeTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: closeDelayMilliseconds) {
            onClose()
        }
    }

    private func presentationOffset(in proxy: GeometryProxy, safeBottom: CGFloat) -> CGFloat {
        guard allowsMotion else { return 0 }
        return isShellVisible ? 0 : proxy.size.height + safeBottom + 24
    }

    private var allowsMotion: Bool {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion
    }

    private var drawerEnterAnimation: Animation {
        allowsMotion ? .smooth(duration: 0.38, extraBounce: 0.0) : GoMotion.reduced
    }

    private var drawerExitAnimation: Animation {
        allowsMotion ? .smooth(duration: 0.38, extraBounce: 0.0) : GoMotion.reduced
    }

    private var contentPrepareDelayMilliseconds: UInt64 {
        allowsMotion ? 32 : 0
    }

    private var closeDelayMilliseconds: UInt64 {
        allowsMotion ? 430 : 90
    }

    private var interactionReadyDelayMilliseconds: UInt64 {
        allowsMotion ? 420 : 0
    }

    private var historyContentDelayMilliseconds: UInt64 {
        allowsMotion ? 470 : 0
    }
}

private struct HomeCoconutLogOpeningShell: View {
    let safeTopInset: CGFloat
    let onClose: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "椰子历史", en: "Coconut History", de: "Kokosnuss-Historie"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "每一笔收支", en: "Every coconut change", de: "Jede Bewegung"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
            .padding(.horizontal, 18)
            .padding(.top, safeTopInset + 16)
            .padding(.bottom, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
