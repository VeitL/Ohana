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
            .sheet(item: $routes.modal, onDismiss: handleModalDismissed) { route in
                homeModalDestination(for: route)
                    .onAppear {
                        lastModalRoute = route
                    }
            }
            .sheet(item: $routes.sheet) { route in
                homeSheetDestination(for: route)
            }
            .fullScreenCover(item: $routes.fullScreen) { route in
                homeFullScreenDestination(for: route)
            }
            .overlay {
                homeOverlayDestination()
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
        case .crewRoster:
            NavigationStack {
                CrewRosterOverlay(
                    onSelectPet: { pet in
                        routes.dismissModal()
                        onCrewPetSelected(pet)
                    },
                    onSelectHuman: { human in
                        routes.dismissModal()
                        onCrewHumanSelected(human)
                    }
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
            HumanAccountSwitcherSheet()
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        case let .calendar(entityID, humanID):
            CalendarView(
                preselectedPetId: entityID,
                preselectedHumanId: humanID
            )
            .ohanaSheetPagePresentation() // ui-v4: allow calendar as long sheet
        }
    }

    @ViewBuilder
    private func homeFullScreenDestination(for route: HomeFullScreenRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
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
                PetAllFeaturesSheet(pet: pet)
                    .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
            } else {
                missingRouteDismissView()
            }
        case let .humanAllFeatures(id):
            if let human = human(id) {
                HumanAllFeaturesSheet(human: human)
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
        case let .humanExpense(id):
            if let human = human(id) {
                NavigationStack { HumanExpenseDetailView(human: human) }
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

extension View {
    func focusHomeRouteSheets(
        pets: [Pet],
        humans: [Human],
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
