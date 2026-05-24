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
    let l: L10n

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
    @Binding var expandedAllFeaturesPet: Pet?
    @Binding var expandedAllFeaturesHuman: Human?
    @Binding var expandedBasicInfoPet: Pet?
    @Binding var expandedBasicInfoHuman: Human?
    @Binding var expandedQuickWeightDetailPet: Pet?
    @Binding var expandedQuickExpenseDetailPet: Pet?
    @Binding var expandedQuickFeedDetailPet: Pet?
    @Binding var expandedQuickFeedOpensManualSheet: Bool
    @Binding var expandedQuickWaterDetailPet: Pet?
    @Binding var expandedQuickPottyDetailPet: Pet?
    @Binding var expandedQuickLitterDetailPet: Pet?
    @Binding var expandedQuickPlayDetailPet: Pet?
    @Binding var expandedQuickHygienePet: Pet?
    @Binding var expandedQuickWalkPet: Pet?
    @Binding var todayFocusWalkPet: Pet?
    @Binding var expandedQuickHealthPet: Pet?
    @Binding var expandedQuickHealthInitialSection: PetHealthInitialSection?
    @Binding var expandedQuickPetMedicationPet: Pet?
    @Binding var expandedQuickMomentPet: Pet?
    @Binding var expandedMomentHistoryPet: Pet?
    @Binding var expandedQuickHumanMedication: Human?
    @Binding var expandedHumanWeightDetail: Human?
    @Binding var expandedHumanWorkoutDetail: Human?
    @Binding var expandedHumanExpenseDetail: Human?
    @Binding var expandedHumanNoteDetail: Human?
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
            .sheet(item: $expandedAllFeaturesPet) { pet in
                PetAllFeaturesSheet(pet: pet)
                    .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
            }
            .sheet(item: $expandedAllFeaturesHuman) { human in
                HumanAllFeaturesSheet(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long feature hub sheet
            }
            .sheet(item: $expandedBasicInfoPet) { pet in
                NavigationStack { PetBasicInfoDetailView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedBasicInfoHuman) { human in
                NavigationStack { HumanBasicInfoDetailView(human: human) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickWeightDetailPet) { pet in
                NavigationStack { WeightHistoryView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickExpenseDetailPet) { pet in
                NavigationStack { ExpenseHistoryView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickFeedDetailPet) { pet in
                QuickFeedDetailSheet(
                    pet: pet,
                    onRemove: { expandedQuickFeedDetailPet = nil },
                    opensManualSheetOnAppear: expandedQuickFeedOpensManualSheet
                )
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
                .onDisappear { expandedQuickFeedOpensManualSheet = false }
            }
            .sheet(item: $expandedQuickWaterDetailPet) { pet in
                QuickWaterDetailSheet(pet: pet) {
                    expandedQuickWaterDetailPet = nil
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickPottyDetailPet) { pet in
                QuickPottyDetailSheet(pet: pet) { expandedQuickPottyDetailPet = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickLitterDetailPet) { pet in
                QuickLitterDetailSheet(pet: pet) { expandedQuickLitterDetailPet = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickPlayDetailPet) { pet in
                QuickPlayDetailSheet(pet: pet) { expandedQuickPlayDetailPet = nil }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickHygienePet) { pet in
                NavigationStack { PetHygieneDetailView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickWalkPet) { pet in
                NavigationStack { WalkSummarySheet(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .fullScreenCover(item: $todayFocusWalkPet) { pet in
                WalkTrackingFullScreen(pet: pet)
            }
            .sheet(item: $expandedQuickHealthPet, onDismiss: {
                expandedQuickHealthInitialSection = nil
            }) { pet in
                NavigationStack {
                    PetHealthDetailView(
                        pet: pet,
                        isModal: true,
                        initialSection: expandedQuickHealthInitialSection
                    )
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickPetMedicationPet) { pet in
                NavigationStack { PetMedicationView(pet: pet) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
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
            .sheet(item: $expandedMomentHistoryPet) { pet in
                PetMomentsHubView(pet: pet)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedQuickHumanMedication) { human in
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
            }
            .sheet(item: $expandedHumanWeightDetail) { human in
                NavigationStack { HumanWeightHistoryView(human: human) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedHumanWorkoutDetail) { human in
                HumanWorkoutHistoryView(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedHumanExpenseDetail) { human in
                NavigationStack { HumanExpenseDetailView(human: human) }
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
            }
            .sheet(item: $expandedHumanNoteDetail) { human in
                HumanNoteHistorySheet(human: human)
                    .ohanaSheetPagePresentation() // ui-v4: allow long overview/detail sheet
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
}

extension View {
    func focusHomeRouteSheets(
        pets: [Pet],
        l: L10n,
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
        expandedAllFeaturesPet: Binding<Pet?>,
        expandedAllFeaturesHuman: Binding<Human?>,
        expandedBasicInfoPet: Binding<Pet?>,
        expandedBasicInfoHuman: Binding<Human?>,
        expandedQuickWeightDetailPet: Binding<Pet?>,
        expandedQuickExpenseDetailPet: Binding<Pet?>,
        expandedQuickFeedDetailPet: Binding<Pet?>,
        expandedQuickFeedOpensManualSheet: Binding<Bool>,
        expandedQuickWaterDetailPet: Binding<Pet?>,
        expandedQuickPottyDetailPet: Binding<Pet?>,
        expandedQuickLitterDetailPet: Binding<Pet?>,
        expandedQuickPlayDetailPet: Binding<Pet?>,
        expandedQuickHygienePet: Binding<Pet?>,
        expandedQuickWalkPet: Binding<Pet?>,
        todayFocusWalkPet: Binding<Pet?>,
        expandedQuickHealthPet: Binding<Pet?>,
        expandedQuickHealthInitialSection: Binding<PetHealthInitialSection?>,
        expandedQuickPetMedicationPet: Binding<Pet?>,
        expandedQuickMomentPet: Binding<Pet?>,
        expandedMomentHistoryPet: Binding<Pet?>,
        expandedQuickHumanMedication: Binding<Human?>,
        expandedHumanWeightDetail: Binding<Human?>,
        expandedHumanWorkoutDetail: Binding<Human?>,
        expandedHumanExpenseDetail: Binding<Human?>,
        expandedHumanNoteDetail: Binding<Human?>,
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
            l: l,
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
            expandedAllFeaturesPet: expandedAllFeaturesPet,
            expandedAllFeaturesHuman: expandedAllFeaturesHuman,
            expandedBasicInfoPet: expandedBasicInfoPet,
            expandedBasicInfoHuman: expandedBasicInfoHuman,
            expandedQuickWeightDetailPet: expandedQuickWeightDetailPet,
            expandedQuickExpenseDetailPet: expandedQuickExpenseDetailPet,
            expandedQuickFeedDetailPet: expandedQuickFeedDetailPet,
            expandedQuickFeedOpensManualSheet: expandedQuickFeedOpensManualSheet,
            expandedQuickWaterDetailPet: expandedQuickWaterDetailPet,
            expandedQuickPottyDetailPet: expandedQuickPottyDetailPet,
            expandedQuickLitterDetailPet: expandedQuickLitterDetailPet,
            expandedQuickPlayDetailPet: expandedQuickPlayDetailPet,
            expandedQuickHygienePet: expandedQuickHygienePet,
            expandedQuickWalkPet: expandedQuickWalkPet,
            todayFocusWalkPet: todayFocusWalkPet,
            expandedQuickHealthPet: expandedQuickHealthPet,
            expandedQuickHealthInitialSection: expandedQuickHealthInitialSection,
            expandedQuickPetMedicationPet: expandedQuickPetMedicationPet,
            expandedQuickMomentPet: expandedQuickMomentPet,
            expandedMomentHistoryPet: expandedMomentHistoryPet,
            expandedQuickHumanMedication: expandedQuickHumanMedication,
            expandedHumanWeightDetail: expandedHumanWeightDetail,
            expandedHumanWorkoutDetail: expandedHumanWorkoutDetail,
            expandedHumanExpenseDetail: expandedHumanExpenseDetail,
            expandedHumanNoteDetail: expandedHumanNoteDetail,
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
