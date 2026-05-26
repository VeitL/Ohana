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

    @Binding var functionMenuPresentation: FunctionMenuPresentation?
    @Binding var showStreakDetail: Bool
    @Binding var showingSettings: Bool
    @Binding var activeAddEntityType: EntityType?
    @Binding var activeHumanIdStr: String
    @Binding var showingCrewRoster: Bool
    @Binding var showingAccountSwitcher: Bool
    @Binding var showingCalendar: Bool
    @Binding var calendarEntityFilterId: String?
    @Binding var calendarHumanFilterId: String?
    @Binding var todayFocusWalkPet: Pet?
    @Binding var expandedQuickMomentPet: Pet?
    @Binding var showingOasisReward: Bool
    @Binding var activeCoconutLogSubject: CoconutLogSubject?
    @Binding var showingAntiRepeatAlert: Bool
    @Binding var pendingRepeatAction: (() -> Void)?
    @Binding var antiRepeatTitle: String
    @Binding var antiRepeatMessage: String
    @Binding var showingSingleUseNotice: Bool
    @Binding var singleUseNoticeTitle: String
    @Binding var singleUseNoticeMessage: String
    @Binding var showingQuickActionLimitAlert: Bool
    @Binding var showingHumanPrivacyAlert: Bool

    let onAddEntityDismissed: () -> Void
    let onPetSavedFromAddEntity: (Pet) -> Void
    let onCrewPetSelected: (Pet) -> Void
    let onCrewHumanSelected: (Human) -> Void
    let onFirstSuccessMomentCompleted: (Pet) -> Void
    let onHumanDoseTaken: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $functionMenuPresentation) { presentation in
                FunctionMenuSheet(initialDestination: presentation.destination)
                    .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
            }
            .sheet(isPresented: $showStreakDetail) {
                DailyStreakDetailView(pets: pets, onClose: { showStreakDetail = false })
                    .ohanaSheetPagePresentation() // ui-v4: allow long streak overview
            }
            .fullScreenCover(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $activeAddEntityType, onDismiss: onAddEntityDismissed) { type in
                AddEntityDestinationView(
                    type: type,
                    onComplete: { activeAddEntityType = nil },
                    onPetSaved: onPetSavedFromAddEntity,
                    onHumanSaved: { human in
                        activeHumanIdStr = human.id.uuidString
                    }
                )
                .ohanaSheetPagePresentation() // ui-v4: allow role creation flow as long sheet
            }
            .sheet(isPresented: $showingCrewRoster) {
                NavigationStack {
                    CrewRosterOverlay(
                        onSelectPet: onCrewPetSelected,
                        onSelectHuman: onCrewHumanSelected
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showingCrewRoster = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                        }
                    }
                }
                .ohanaSheetPagePresentation() // ui-v4: allow family collaboration/member hub
            }
            .sheet(isPresented: $showingAccountSwitcher) {
                HumanAccountSwitcherSheet()
                    .ohanaCompactSheetPresentation(detents: [.medium, .large])
            }
            .sheet(isPresented: $showingCalendar, onDismiss: {
                calendarEntityFilterId = nil
                calendarHumanFilterId = nil
            }) {
                CalendarView(
                    preselectedPetId: calendarEntityFilterId,
                    preselectedHumanId: calendarHumanFilterId
                )
                .ohanaSheetPagePresentation() // ui-v4: allow calendar as long sheet
            }
            .sheet(item: $routes.sheet) { route in
                homeSheetDestination(for: route)
            }
            .fullScreenCover(item: $todayFocusWalkPet) { pet in
                WalkTrackingFullScreen(pet: pet)
            }
            .overlay {
                if let pet = expandedQuickMomentPet {
                    QuickMomentSheet(
                        pet: pet,
                        onRemove: nil,
                        onSaved: {
                            onFirstSuccessMomentCompleted(pet)
                        },
                        onClose: {
                            expandedQuickMomentPet = nil
                        }
                    )
                    .ignoresSafeArea()
                    .zIndex(100)
                }
            }
            .fullScreenCover(isPresented: $showingOasisReward) {
                OasisRewardView()
            }
            .fullScreenCover(item: $activeCoconutLogSubject) { subject in
                CoconutLogView(subject: subject)
            }
            .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
                Button(l.homeConfirmCheckIn, role: .destructive) {
                    pendingRepeatAction?()
                    pendingRepeatAction = nil
                }
                Button(l.cancel, role: .cancel) {
                    pendingRepeatAction = nil
                }
            } message: {
                Text(antiRepeatMessage)
            }
            .alert(singleUseNoticeTitle, isPresented: $showingSingleUseNotice) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(singleUseNoticeMessage)
            }
            .alert(QuickActionLimit.title, isPresented: $showingQuickActionLimitAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(QuickActionLimit.message)
            }
            .alert("仅本人可见", isPresented: $showingHumanPrivacyAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("该成员已将此功能设为仅自己可见。")
            }
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
}

extension View {
    func focusHomeRouteSheets(
        pets: [Pet],
        humans: [Human],
        l: L10n,
        routes: HomeRouteCoordinator,
        functionMenuPresentation: Binding<FunctionMenuPresentation?>,
        showStreakDetail: Binding<Bool>,
        showingSettings: Binding<Bool>,
        activeAddEntityType: Binding<EntityType?>,
        activeHumanIdStr: Binding<String>,
        showingCrewRoster: Binding<Bool>,
        showingAccountSwitcher: Binding<Bool>,
        showingCalendar: Binding<Bool>,
        calendarEntityFilterId: Binding<String?>,
        calendarHumanFilterId: Binding<String?>,
        todayFocusWalkPet: Binding<Pet?>,
        expandedQuickMomentPet: Binding<Pet?>,
        showingOasisReward: Binding<Bool>,
        activeCoconutLogSubject: Binding<CoconutLogSubject?>,
        showingAntiRepeatAlert: Binding<Bool>,
        pendingRepeatAction: Binding<(() -> Void)?>,
        antiRepeatTitle: Binding<String>,
        antiRepeatMessage: Binding<String>,
        showingSingleUseNotice: Binding<Bool>,
        singleUseNoticeTitle: Binding<String>,
        singleUseNoticeMessage: Binding<String>,
        showingQuickActionLimitAlert: Binding<Bool>,
        showingHumanPrivacyAlert: Binding<Bool>,
        onAddEntityDismissed: @escaping () -> Void,
        onPetSavedFromAddEntity: @escaping (Pet) -> Void,
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
            functionMenuPresentation: functionMenuPresentation,
            showStreakDetail: showStreakDetail,
            showingSettings: showingSettings,
            activeAddEntityType: activeAddEntityType,
            activeHumanIdStr: activeHumanIdStr,
            showingCrewRoster: showingCrewRoster,
            showingAccountSwitcher: showingAccountSwitcher,
            showingCalendar: showingCalendar,
            calendarEntityFilterId: calendarEntityFilterId,
            calendarHumanFilterId: calendarHumanFilterId,
            todayFocusWalkPet: todayFocusWalkPet,
            expandedQuickMomentPet: expandedQuickMomentPet,
            showingOasisReward: showingOasisReward,
            activeCoconutLogSubject: activeCoconutLogSubject,
            showingAntiRepeatAlert: showingAntiRepeatAlert,
            pendingRepeatAction: pendingRepeatAction,
            antiRepeatTitle: antiRepeatTitle,
            antiRepeatMessage: antiRepeatMessage,
            showingSingleUseNotice: showingSingleUseNotice,
            singleUseNoticeTitle: singleUseNoticeTitle,
            singleUseNoticeMessage: singleUseNoticeMessage,
            showingQuickActionLimitAlert: showingQuickActionLimitAlert,
            showingHumanPrivacyAlert: showingHumanPrivacyAlert,
            onAddEntityDismissed: onAddEntityDismissed,
            onPetSavedFromAddEntity: onPetSavedFromAddEntity,
            onCrewPetSelected: onCrewPetSelected,
            onCrewHumanSelected: onCrewHumanSelected,
            onFirstSuccessMomentCompleted: onFirstSuccessMomentCompleted,
            onHumanDoseTaken: onHumanDoseTaken
        ))
    }
}
