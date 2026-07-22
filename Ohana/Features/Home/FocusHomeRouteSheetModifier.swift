//
//  FocusHomeRouteSheetModifier.swift
//  Ohana
//
//  Sheet/full-screen routing for the GO Focus home. Kept outside the main
//  home view so route churn does not bloat the card-stack render path.
//

import SwiftUI

struct FocusHomeRouteSheetModifier: ViewModifier {
    let l: L10n

    @Environment(AppServices.self) private var appServices
    @ObservedObject var routes: HomeRouteCoordinator

    @Binding var activeHumanIdStr: String
    @State private var lastModalRoute: HomeModalRoute?

    let onAddEntityDismissed: () -> Void
    let onPetSavedFromAddEntity: (Pet) -> Void
    let onHumanSavedFromAddEntity: (Human) -> Void
    let onPlantSavedFromAddEntity: (UUID) -> Void
    let onCrewPetSelected: (Pet) -> Void
    let onCrewHumanSelected: (Human) -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onHumanDoseTaken: (UUID) -> Void
    let onStartWalkFromQuickAction: (UUID) -> Void

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
                .globalCoconutRewardFeedbackOverlay()
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
                .globalCoconutRewardFeedbackOverlay()
            }
            .fullScreenCover(item: fullScreenRouteBinding) { route in
                AppDeferredRouteContent(
                    routeID: route.id,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    homeFullScreenDestination(for: route)
                }
                .globalCoconutRewardFeedbackOverlay()
            }
            .sheet(item: overlayRouteBinding) { route in
                AppDeferredRouteContent(
                    routeID: route.id.uuidString,
                    policy: AppPresentationPolicyProvider.policy(for: route)
                ) {
                    homeOverlayDestination(for: route)
                }
                .appPresentationSheet(AppPresentationPolicyProvider.policy(for: route))
                .globalCoconutRewardFeedbackOverlay()
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
                routes.modal
            },
            set: { route in
                routes.modal = route
            }
        )
    }

    private var fullScreenRouteBinding: Binding<HomeFullScreenRoute?> {
        Binding(
            get: {
                routes.fullScreen
            },
            set: { route in
                routes.fullScreen = route
            }
        )
    }

    private var systemSheetRouteBinding: Binding<HomeSheetRoute?> {
        Binding(
            get: {
                routes.sheet
            },
            set: { route in
                routes.sheet = route
            }
        )
    }

    private var overlayRouteBinding: Binding<HomeOverlayRoute?> {
        Binding(
            get: { routes.overlay },
            set: { routes.overlay = $0 }
        )
    }

    @ViewBuilder
    private func homeModalDestination(for route: HomeModalRoute) -> some View {
        switch route {
        case let .functionMenu(destination):
            FunctionMenuSheet(initialDestination: destination)
                .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
        case .critterCodex:
            OasisCritterCodexRouteContainer(
                mode: .codex,
                onClose: { routes.dismissModal() },
                onPresentCoconutLog: { subject in
                    routes.openCoconutLog(subject)
                }
            )
            .ohanaSheetPagePresentation()
        case .streakDetail:
            DailyStreakDetailRouteContainer(
                onClose: { routes.dismissModal() },
                onPresentCoconutLog: { subject in
                    routes.openCoconutLog(subject)
                },
                onPresentCoconutShop: { category in
                    routes.openCoconutShop(category, currentLevel: appServices.oasisTree.treeLevel.rawValue)
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow long streak overview
        case let .addEntity(type):
            if AppFeatureRouteGuard.allowsAddEntity(type, currentLevel: appServices.oasisTree.treeLevel.rawValue) {
                AddEntityDestinationView(
                    type: type,
                    onComplete: { routes.dismissModal() },
                    onPetSaved: onPetSavedFromAddEntity,
                    onHumanSaved: { human in
                        activeHumanIdStr = ActiveHumanSelectionPolicy.activeHumanIdAfterCreatingHuman(
                            currentHumanIdRaw: activeHumanIdStr,
                            createdHumanId: human.id
                        )
                        onHumanSavedFromAddEntity(human)
                    },
                    onPlantSaved: onPlantSavedFromAddEntity
                )
                .ohanaSheetPagePresentation() // ui-v4: allow role creation flow as long sheet
            } else {
                Color.clear
                    .onAppear {
                        AppFeatureRouteGuard.recordIntercept("homeAddEntity:\(type.rawValue)")
                        routes.dismissModal()
                    }
            }
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
                    onInlinePetSaved: { pet in
                        routes.dismissModal()
                        onPetSavedFromAddEntity(pet)
                    },
                    onInlineHumanSaved: { human in
                        routes.dismissModal()
                        onHumanSavedFromAddEntity(human)
                    },
                    onClose: { routes.dismissModal() },
                    onPresentCoconutLog: { subject in
                        routes.openCoconutLog(subject)
                    },
                    onOpenTaskCenter: {
                        routes.dismissModal()
                        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
                            routes.openTaskCenter()
                        }
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
            AppAccountSwitcherRouteContainer(onSwitched: { routes.dismissModal() })
            .ohanaCompactSheetPresentation(detents: [.medium, .large])
        case let .calendar(entityID, humanID, _):
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
            AppSettingsSheetRouteContainer(onClose: { routes.dismissModal() })
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
            openPetReminderQuickKey(key, petID: pet.id)
        case let .petFeature(feature, pet):
            openPetFeature(feature, petID: pet.id)
        case let .petHealth(pet, section):
            routes.openSheet(.petHealth(pet.id, initialSection: section))
        case let .humanQuick(key, human):
            openHumanQuickKey(key, humanID: human.id)
        case let .humanDetail(human):
            routes.openSheet(.humanBasicInfo(human.id))
        case let .plant(plant):
            openFunctionMenu(destination: .plantDetail(plant.id))
        case let .plantFeature(plant, destination):
            openFunctionMenu(destination: .plantFeature(plant.id, destination))
        case let .plantCare(plant, destination):
            openFunctionMenu(destination: .plantCare(plant.id, destination))
        case let .functionMenu(destination):
            openFunctionMenu(destination: destination)
        case let .calendar(entityId, humanId, plantId):
            routes.openCalendar(entityID: entityId, humanID: humanId, plantID: plantId)
        }
    }

    private func openPetReminderQuickKey(_ key: String, petID: UUID) {
        if key == "walk" {
            routes.openSheet(.petWalkSummary(petID))
        } else {
            openPetQuickKey(key, petID: petID)
        }
    }

    private func openFunctionMenu(destination: FMDest?) {
        routes.openFunctionMenu(
            destination: destination,
            currentLevel: appServices.oasisTree.treeLevel.rawValue,
            plan: appServices.commerce.ohanaPlanLevel
        )
    }

    private func openPetQuickKey(_ key: String, petID: UUID) {
        GrowthNewFeatureStore.markVisited(quickActionType: key)
        switch key {
        case "feed":
            routes.openSheet(.petFeed(petID, opensManualSheet: false))
        case "water", "waterChange", "filterClean":
            routes.openSheet(.petWater(petID))
        case "potty":
            routes.openSheet(.petPotty(petID))
        case "litter":
            routes.openSheet(.petLitter(petID))
        case "walk":
            routes.openSheet(.petWalkSummary(petID))
        case "play":
            routes.openSheet(.petPlay(petID))
        case "health":
            routes.openSheet(.petHealth(petID, initialSection: nil))
        case "medication":
            routes.openSheet(.petMedication(petID))
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            routes.openSheet(.petHygiene(petID))
        case "weight":
            routes.openSheet(.petWeight(petID))
        case "expense":
            routes.openSheet(.petExpense(petID))
        case "moment":
            routes.openQuickMoment(petID)
        default:
            routes.openSheet(.petAllFeatures(petID))
        }
    }

    private func openPetFeature(_ feature: PetFeature, petID: UUID) {
        GrowthNewFeatureStore.markVisited(feature: feature)
        switch feature {
        case .health:
            routes.openSheet(.petHealth(petID, initialSection: nil))
        case .medications:
            routes.openSheet(.petMedication(petID))
        case .food:
            routes.openSheet(.petFeed(petID, opensManualSheet: false))
        case .hygiene:
            routes.openSheet(.petHygiene(petID))
        case .walks:
            routes.openSheet(.petWalkSummary(petID))
        case .potty:
            routes.openSheet(.petPotty(petID))
        case .basicInfo:
            routes.openSheet(.petBasicInfo(petID))
        case .moments:
            routes.openSheet(.petMomentHistory(petID))
        case .weight:
            routes.openSheet(.petWeight(petID))
        case .expense:
            routes.openSheet(.petExpense(petID))
        case .retention, .documents, .achievements:
            routes.openSheet(.petAllFeatures(petID))
        }
    }

    private func openHumanQuickKey(_ key: String, humanID: UUID) {
        switch key {
        case "humanWeight":
            routes.openHumanWeightQuick(humanID)
        case "humanWorkout":
            routes.openSheet(.humanWorkoutQuick(humanID))
        case "humanMedication":
            routes.openSheet(.humanMedicationQuick(humanID))
        case "humanExpense":
            routes.openSheet(.humanExpenseQuick(humanID))
        case "humanNote":
            routes.openSheet(.humanNoteQuick(humanID))
        default:
            routes.openSheet(.humanAllFeatures(humanID))
        }
    }

    @ViewBuilder
    private func homeFullScreenDestination(for route: HomeFullScreenRoute) -> some View {
        switch route {
        case let .walk(id):
            AppWalkRouteContainer(id: id, onDismiss: { routes.dismissFullScreen() })
        case .oasisReward:
            OasisRewardView()
        }
    }

    @ViewBuilder
    private func homeOverlayDestination(for route: HomeOverlayRoute) -> some View {
        switch route {
        case let .quickMoment(routeID, petID):
            AppQuickMomentOverlayRouteContainer(
                id: petID,
                onSaved: onFirstSuccessMomentCompleted,
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
        case let .petWeightQuick(routeID, petID):
            AppPetWeightQuickSheetHost(
                id: petID,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
        case let .petExpenseQuick(routeID, petID):
            AppPetDetailSheetRouteContainer(
                id: petID,
                destination: .expenseQuick,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
        case let .humanMedicationQuick(routeID, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .medicationQuick,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) },
                onOpenDestination: { id, destination in
                    routes.dismissOverlay(routeID: routeID)
                    OhanaFrameScheduler.runAfterNextFrame {
                        routes.openSheet(homeHumanDetailRoute(humanID: id, destination: destination))
                    }
                }
            )
        case let .humanWeightQuick(routeID, humanID):
            AppHumanWeightQuickSheetHost(
                id: humanID,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
        case let .humanWorkoutQuick(routeID, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .workoutQuick,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
        case let .humanExpenseQuick(routeID, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .expenseQuick,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
        case let .humanNoteQuick(routeID, humanID):
            AppHumanDetailSheetRouteContainer(
                id: humanID,
                destination: .noteQuick,
                onMissing: { routes.dismissOverlay(routeID: routeID) },
                onDismiss: { routes.dismissOverlay(routeID: routeID) }
            )
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
}

private extension FocusHomeRouteSheetModifier {
    @ViewBuilder
    private func homeSheetDestination(for route: HomeSheetRoute) -> some View {
        switch route {
        case .petAllFeatures, .petBasicInfo, .petFood, .petWeightQuick, .petWeight,
             .petExpenseQuick, .petExpense, .petFeed, .petWater, .petPotty, .petLitter,
             .petPlay, .petHygiene, .petWalkSummary, .petHealth, .petMedication,
             .petMomentHistory, .petDocuments, .petAchievements, .petRetention, .petBondVault:
            petSheetDestination(for: route)
        case .humanAllFeatures, .humanBasicInfo, .humanMedicationQuick, .humanMedication,
             .humanWeightQuick, .humanWeight, .humanWorkoutQuick, .humanWorkout,
             .humanWorkoutDashboard, .humanMetrics, .humanReport, .humanExpenseQuick,
             .humanExpense, .humanWishlist, .humanNoteQuick, .humanNote:
            humanSheetDestination(for: route)
        case let .plantCareLog(id, initialCareType):
            HomePlantCareLogRouteContainer(
                id: id,
                initialCareType: initialCareType,
                onMissing: { routes.dismissSheet() }
            )
        }
    }

    @ViewBuilder
    private func petSheetDestination(for route: HomeSheetRoute) -> some View {
        switch route {
        case let .petAllFeatures(id):
            AppPetDetailSheetRouteContainer(
                id: id,
                destination: .allFeatures,
                onMissing: { routes.dismissSheet() },
                onOpenFeatureDestination: { petID, destination in
                    routes.openSheet(homePetFeatureRoute(petID: petID, destination: destination))
                },
                onPresentCoconutLog: { subject in
                    routes.openCoconutLog(subject)
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
        case let .petBasicInfo(id):
            petRouteContainer(id: id, destination: .basicInfo)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petFood(id):
            petRouteContainer(id: id, destination: .food)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petWeightQuick(id):
            AppPetWeightQuickSheetHost(
                id: id,
                onMissing: { routes.dismissSheet() },
                onDismiss: { routes.dismissSheet() }
            )
        case let .petWeight(id):
            petRouteContainer(id: id, destination: .weight)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petExpenseQuick(id):
            petRouteContainer(id: id, destination: .expenseQuick)
        case let .petExpense(id):
            petRouteContainer(id: id, destination: .expense)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petFeed(id, opensManualSheet):
            petRouteContainer(id: id, destination: .feed(opensManualSheet))
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petWater(id):
            petRouteContainer(id: id, destination: .water)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petPotty(id):
            petRouteContainer(id: id, destination: .potty)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petLitter(id):
            petRouteContainer(id: id, destination: .litter)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petPlay(id):
            petRouteContainer(id: id, destination: .play)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petHygiene(id):
            petRouteContainer(id: id, destination: .hygiene)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petWalkSummary(id):
            petRouteContainer(id: id, destination: .walkSummary)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petHealth(id, initialSection):
            petRouteContainer(id: id, destination: .health(initialSection))
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petMedication(id):
            petRouteContainer(id: id, destination: .medication)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petMomentHistory(id):
            petRouteContainer(id: id, destination: .momentHistory)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petDocuments(id):
            petRouteContainer(id: id, destination: .documents)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petAchievements(id):
            petRouteContainer(id: id, destination: .achievements)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petRetention(id):
            petRouteContainer(id: id, destination: .retention)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .petBondVault(id):
            petRouteContainer(id: id, destination: .bondVault)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func humanSheetDestination(for route: HomeSheetRoute) -> some View {
        switch route {
        case let .humanAllFeatures(id):
            HumanAllFeaturesRouteContainer(
                id: id,
                onMissing: { routes.dismissSheet() },
                onOpenDestination: { humanID, destination in
                    if let route = homeHumanFeatureRoute(humanID: humanID, destination: destination) {
                        routes.openSheet(route)
                    } else {
                        routes.dismissSheet()
                        DispatchQueue.main.async {
                            openFunctionMenu(destination: .featureAggregate(.achievements))
                        }
                    }
                }
            )
            .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
        case let .humanBasicInfo(id):
            humanRouteContainer(id: id, destination: .basicInfo)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanMedicationQuick(id):
            humanRouteContainer(id: id, destination: .medicationQuick)
        case let .humanMedication(id):
            humanRouteContainer(id: id, destination: .medication)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanWeightQuick(id):
            AppHumanWeightQuickSheetHost(
                id: id,
                onMissing: { routes.dismissSheet() },
                onDismiss: { routes.dismissSheet() }
            )
        case let .humanWeight(id):
            humanRouteContainer(id: id, destination: .weight)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanWorkoutQuick(id):
            humanRouteContainer(id: id, destination: .workoutQuick)
        case let .humanWorkout(id):
            humanRouteContainer(id: id, destination: .workout)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanWorkoutDashboard(id):
            humanRouteContainer(id: id, destination: .workoutDashboard)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanMetrics(id):
            humanRouteContainer(id: id, destination: .metrics)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanReport(id):
            humanRouteContainer(id: id, destination: .report)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanExpenseQuick(id):
            humanRouteContainer(id: id, destination: .expenseQuick)
        case let .humanExpense(id):
            humanRouteContainer(id: id, destination: .expense)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanWishlist(id):
            humanRouteContainer(id: id, destination: .wishlist)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        case let .humanNoteQuick(id):
            humanRouteContainer(id: id, destination: .noteQuick)
        case let .humanNote(id):
            humanRouteContainer(id: id, destination: .note)
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
        default:
            EmptyView()
        }
    }

    private func petRouteContainer(id: UUID, destination: AppPetDetailSheetDestination) -> some View {
        AppPetDetailSheetRouteContainer(
            id: id,
            destination: destination,
            onMissing: { routes.dismissSheet() },
            onDismiss: { routes.dismissSheet() },
            onOpenFeatureDestination: { petID, destination in
                routes.openSheet(homePetFeatureRoute(petID: petID, destination: destination))
            },
            onPresentCoconutLog: { subject in
                routes.openCoconutLog(subject)
            }
        )
    }

    private func humanRouteContainer(id: UUID, destination: AppHumanDetailSheetDestination) -> some View {
        AppHumanDetailSheetRouteContainer(
            id: id,
            destination: destination,
            onMissing: { routes.dismissSheet() },
            onDismiss: { routes.dismissSheet() },
            onOpenDestination: { humanID, destination in
                routes.openSheet(homeHumanDetailRoute(humanID: humanID, destination: destination))
            },
            onHumanDoseTaken: onHumanDoseTaken
        )
    }

    private func homePetFeatureRoute(
        petID: UUID,
        destination: PetAllFeatureDestination
    ) -> HomeSheetRoute {
        switch destination {
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
    }

    private func homeHumanFeatureRoute(
        humanID: UUID,
        destination: HumanAllFeatureDestination
    ) -> HomeSheetRoute? {
        switch destination {
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
            nil
        }
    }

    private func homeHumanDetailRoute(
        humanID: UUID,
        destination: AppHumanDetailSheetDestination
    ) -> HomeSheetRoute {
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
