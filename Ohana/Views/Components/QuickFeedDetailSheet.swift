//
//  QuickFeedDetailSheet.swift
//  Ohana
//
//  Feeding management — three-core-card experience.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

private enum ManualFeedSheetMode {
    case log
    case settingsOnly
}

struct QuickFeedDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var showsRemoveQuickActionFooter: Bool = true
    var showsCloseButton: Bool = true
    var opensManualSheetOnAppear: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \PetCareLog.date) private var allCareLogs: [PetCareLog]
    @Query(sort: \PetFoodRecord.startDate) private var allFoodRecords: [PetFoodRecord]
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("defaultFeedGrams") private var defaultFeedGrams: Double = 0
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    @State private var activeSheet: ActiveFeedSheet?
    @State private var nestedInlineSheet: ActiveFeedSheet?
    @State private var nestedInlineReturnStack: [ActiveFeedSheet] = []
    @State private var feedSheetReturnStack: [ActiveFeedSheet] = []
    @State private var adaptiveSheetHeight: CGFloat = ActiveFeedSheet.defaultAdaptiveHeight
    @State private var overviewRange: FeedOverviewRange = .days7
    @State private var feedPlanCalendarMonth = Date()
    @State private var feedPlanCalendarSelectedDate = Date()
    @State private var showFeedPlanMonthPicker = false
    @State private var feedPlanCalendarMonthSlideDirection = 1
    @State private var selectedStockFoodKind: FeedFoodKind = .dry
    @State private var selectedTreatKind: FeedTreatKind = .lickable
    @State private var selectedTreatOverviewKind: FeedTreatKind? = nil
    @State private var manualFeedSheetMode: ManualFeedSheetMode = .log
    @State private var manualFoodKindDraft: FeedFoodKind = .dry
    @State private var manualGramsText = ""
    @State private var saveManualAsDefault = true
    @State private var selectedSharedFeedPetIds: Set<UUID> = []
    @State private var selectedSharedPlanPetIds: Set<UUID> = []
    @State private var treatGramsText = ""
    @State private var planCount = 3
    @State private var planTimes: [Date] = []
    @State private var planMeals: [FeedPlanMealDraft] = []
    @State private var stockBrandText = ""
    @State private var stockWeightText = ""
    @State private var stockPurchaseDate = Date()
    @State private var stockOpenDate = Date()
    @State private var stockHasPurchaseDate = false
    @State private var stockHasOpenDate = false
    @State private var stockExpenseAmountText = ""
    @State private var stockExpensePayerId: String? = nil
    @State private var stockExpenseAmountKeypadVisible = false
    @State private var stockReminderEnabled = false
    @State private var stockReminderAdvanceDays = 7
    @State private var editingFoodRecord: PetFoodRecord?
    @State private var stockCorrectionText = ""
    @State private var inputError: String?
    @State private var editingFeedLog: PetCareLog?
    @State private var editFeedLogGrams = ""
    @State private var editFeedLogDate = Date()
    @State private var feedLogPendingDelete: PetCareLog?
    @State private var showingDeleteFeedLogConfirm = false
    @State private var foodRecordPendingDelete: PetFoodRecord?
    @State private var showingDeleteFoodRecordConfirm = false
    @State private var showingAntiRepeatAlert = false
    @State private var pendingRepeatAction: (() -> Void)?
    @State private var antiRepeatTitle = ""
    @State private var antiRepeatMessage = ""
    @State private var showToast = false
    @State private var showTreatCelebration = false
    @State private var toastMessage = ""
    @State private var toastTint: Color = .goPrimary
    @State private var toastTask: Task<Void, Never>?
    @State private var inlineKeyboardHeight: CGFloat = 0
    @State private var inlineSheetDragOffset: CGFloat = 0
    @State private var inlineSheetVisible = false
    @State private var inlineSheetScrollTopOffset: CGFloat = 0
    @State private var inlineSheetTopPullDismissArmed = false
    @State private var inlineSheetDismissGestureShield = false
    @StateObject private var feedHomeController: FeedHomeController
    @State private var loadedCareLogs: [PetCareLog] = []
    @State private var loadedFoodRecords: [PetFoodRecord] = []
    @State private var hasLoadedFullCareLogs = false
    @State private var hasLoadedFullFoodRecords = false
    @State private var feedDetailDataTask: Task<Void, Never>?
    @State private var didApplyInitialSheet = false
    @State private var didScheduleBootstrapMaintenance = false
    @State private var overviewChartProgress: Double = 1
    @State private var feedModeMaintenanceTask: Task<Void, Never>?
    @State private var clockTick = Date()
    @State private var feedFeedbackToken: CheckInFeedbackToken?
    @State private var feedFeedbackMetricId: String?
    @State private var stockFeedbackToken: CheckInFeedbackToken?
    @State private var stockFeedbackKind: FeedFoodKind?
    @State private var treatFeedbackToken: CheckInFeedbackToken?
    @State private var feedbackClearTask: Task<Void, Never>?
    @FocusState private var focusedField: FeedInputField?

    private let stockReminderAdvanceOptions = [1, 3, 7, 14]

    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        showsRemoveQuickActionFooter: Bool = true,
        showsCloseButton: Bool = true,
        opensManualSheetOnAppear: Bool = false
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.showsRemoveQuickActionFooter = showsRemoveQuickActionFooter
        self.showsCloseButton = showsCloseButton
        self.opensManualSheetOnAppear = opensManualSheetOnAppear
        let initialFeedMode = FeedOperatingMode.stored(for: pet.id) ?? .manual
        _feedHomeController = StateObject(wrappedValue: FeedHomeController(initialMode: initialFeedMode))

        let petID = pet.id
        let petKey = petID.uuidString
        let dryStockKey = "\(petKey):\(FeedFoodKind.dry.rawValue)"
        let wetStockKey = "\(petKey):\(FeedFoodKind.wet.rawValue)"
        let feedingType = CareType.feeding.rawValue
        let homeLogStartDate = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(-6 * 86_400)

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
                log.pet?.id == petID &&
                log.date >= homeLogStartDate
            },
            sort: \.date,
            order: .reverse
        )
        _allFoodRecords = Query(
            filter: #Predicate<PetFoodRecord> { record in
                record.pet?.id == petID
            },
            sort: \.startDate,
            order: .reverse
        )
    }

    private var l: L10n { L10n(appLanguage) }
    private var feedClockInterval: TimeInterval {
        workloadPolicy.refreshInterval(default: 30, throttled: 120, paused: 300)
    }
    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var dashboard: FeedingDashboardState {
        FeedingDashboardState(
            pet: pet,
            allEvents: allEvents,
            manualGoalCount: savedGoal,
            careLogs: observedCareLogs,
            foodRecords: observedFoodRecords,
            now: clockTick
        )
    }
    private var feedScheduleEvents: [Event] { dashboard.manualPlanEvents }
    private var autoFeederEvents: [Event] { dashboard.autoFeederEvents }
    private var activeFeedingMode: FeedOperatingMode {
        feedHomeController.displayedMode
    }
    private var feedHomeSnapshotInput: FeedHomeSnapshotInput {
        FeedHomeSnapshotInput(
            pet: pet,
            allEvents: allEvents,
            careLogs: allCareLogs,
            foodRecords: allFoodRecords,
            now: clockTick,
            todayLabel: l.tr(zh: "今", en: "T", de: "H")
        )
    }
    private var currentUserId: String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
    }
    private func normalizedSpecies(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private var savedGoal: Int {
        let value = UserDefaults.standard.integer(forKey: "feedGoal_\(pet.id.uuidString)")
        return value > 0 ? value : 1
    }
    private var dryFoodTint: Color { Color.goPrimary }
    private var wetFoodTint: Color { Color.goPrimary }
    private var treatTint: Color { Color.goPrimary }
    private func foodKindTint(_ foodKind: FeedFoodKind) -> Color {
        foodKind == .dry ? dryFoodTint : wetFoodTint
    }
    private var observedCareLogs: [PetCareLog] {
        if hasLoadedFullCareLogs {
            return loadedCareLogs
        }
        return allCareLogs
    }
    private var observedFoodRecords: [PetFoodRecord] {
        if hasLoadedFullFoodRecords {
            return loadedFoodRecords
        }
        return allFoodRecords
    }
    private var sameSpeciesFeedPets: [Pet] {
        let species = normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && normalizedSpecies($0.species) == species }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }
    private var selectedFeedTargets: [Pet] {
        let targets = sameSpeciesFeedPets.filter { selectedSharedFeedPetIds.contains($0.id) }
        return targets.isEmpty ? [pet] : targets
    }
    private var selectedPlanTargets: [Pet] {
        let targets = sameSpeciesFeedPets.filter { selectedSharedPlanPetIds.contains($0.id) }
        return targets.isEmpty ? [pet] : targets
    }
    private var systemSheetBinding: Binding<ActiveFeedSheet?> {
        Binding(
            get: {
                activeSheet?.usesInlineOverlay == true ? nil : activeSheet
            },
            set: { newValue in
                if let newValue {
                    openRootFeedSheet(newValue)
                } else if activeSheet?.usesInlineOverlay != true {
                    closeActiveFeedSheet()
                }
            }
        )
    }

    private var activeInlineSheet: ActiveFeedSheet? {
        if let nestedInlineSheet { return nestedInlineSheet }
        guard let activeSheet, activeSheet.usesInlineOverlay else { return nil }
        return activeSheet
    }

    private var inlineOverlayBlocksBackground: Bool {
        activeInlineSheet != nil || inlineSheetDismissGestureShield
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        petHeader
                        if pet.hasPassedAway {
                            PetMemorialBanner(pet: pet)
                        }
                        guidedFeedHome
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(inlineOverlayBlocksBackground)
                .allowsHitTesting(!inlineOverlayBlocksBackground)

                if showToast {
                    toastView
                        .zIndex(10)
                }

                if showTreatCelebration {
                    TreatCelebrationOverlay(tint: treatTint)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                        .zIndex(20)
                }

                if let sheet = activeSheet, sheet.usesInlineOverlay {
                    inlineFeedSheetOverlay(sheet)
                        .zIndex(40)
                        .ignoresSafeArea(.container, edges: .bottom)
                }

                if inlineSheetDismissGestureShield && activeSheet?.usesInlineOverlay != true {
                    Color.clear
                        .contentShape(Rectangle())
                        .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global))
                        .zIndex(39)
                        .ignoresSafeArea()
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .petMemorialTone(isActive: pet.hasPassedAway)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        dismissFeedKeyboard()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .onAppear(perform: bootstrap)
        .onDisappear {
            feedModeMaintenanceTask?.cancel()
            feedDetailDataTask?.cancel()
            feedHomeController.cancel()
        }
        .onChange(of: activeSheet?.id) { _, _ in
            adaptiveSheetHeight = activeSheet?.defaultAdaptiveHeight ?? ActiveFeedSheet.defaultAdaptiveHeight
            inlineSheetDragOffset = 0
            inlineSheetScrollTopOffset = 0
            if activeSheet == .feedingOverview || activeSheet == .feedModeHistory || activeSheet == .treatOverview {
                overviewChartProgress = 0
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(GoMotion.page) {
                        overviewChartProgress = 1
                    }
                }
            }
            if activeSheet?.usesInlineOverlay != true {
                inlineKeyboardHeight = 0
                inlineSheetVisible = false
            }
            if activeSheet == nil {
                feedSheetReturnStack.removeAll()
                nestedInlineReturnStack.removeAll()
            }
        }
        .onChange(of: nestedInlineSheet?.id) { _, _ in
            adaptiveSheetHeight = nestedInlineSheet?.defaultAdaptiveHeight ?? activeSheet?.defaultAdaptiveHeight ?? ActiveFeedSheet.defaultAdaptiveHeight
            inlineSheetDragOffset = 0
            inlineSheetScrollTopOffset = 0
            inlineSheetTopPullDismissArmed = false
            if nestedInlineSheet == nil {
                inlineKeyboardHeight = 0
                inlineSheetVisible = false
            }
        }
        .onChange(of: allEvents.count) { _, _ in
            reloadFeedSnapshots()
            syncDisplayedFeedMode()
            ensureUpcomingPlanReminders()
        }
        .onChange(of: allCareLogs.count) { _, _ in
            if hasLoadedFullCareLogs {
                loadFullCareLogs(force: true)
            }
            reloadFeedSnapshots()
        }
        .onChange(of: allFoodRecords.count) { _, _ in
            if hasLoadedFullFoodRecords {
                loadFullFoodRecords(force: true)
            }
            reloadFeedSnapshots()
        }
        .onChange(of: appLanguage) { _, _ in
            refreshFeedHomeSnapshot(force: true)
        }
        .sheet(item: systemSheetBinding) { sheet in
            NavigationStack {
                ZStack {
                    Color.clear.ignoresSafeArea()
                    VStack(spacing: 0) {
                        feedSheetTopChrome(sheet)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        sheetContent(sheet)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .petMemorialTone(isActive: pet.hasPassedAway)
                            .allowsHitTesting(nestedInlineSheet == nil && !inlineSheetDismissGestureShield)
                    }

                    if let nestedInlineSheet {
                        inlineFeedSheetOverlay(nestedInlineSheet)
                            .zIndex(40)
                            .ignoresSafeArea(.container, edges: .bottom)
                    }

                    if inlineSheetDismissGestureShield && nestedInlineSheet == nil {
                        Color.clear
                            .contentShape(Rectangle())
                            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global))
                            .zIndex(39)
                            .ignoresSafeArea()
                    }
                }
                .feedSheetScrollChrome()
                .toolbar(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                            dismissFeedKeyboard()
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .presentationDetents(sheet.detents(measuredHeight: adaptiveSheetHeight))
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                FeedNativeSheetGlassSurface(
                    cornerRadius: 30,
                    glassMode: .regular
                )
                .ignoresSafeArea() // ui-v4: sheet glass belongs to presentation background, not content background
            }
            .presentationCornerRadius(30)
            .presentationContentInteraction(.scrolls)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateInlineKeyboardHeight(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(GoMotion.quick) {
                inlineKeyboardHeight = 0
            }
        }
        .onReceive(Timer.publish(every: feedClockInterval, on: .main, in: .common).autoconnect()) { date in
            clockTick = date
            refreshFeedHomeSnapshot()
            syncDisplayedFeedMode()
        }
        .alert(antiRepeatTitle, isPresented: $showingAntiRepeatAlert) {
            Button(l.tr(zh: "继续打卡", en: "Log anyway", de: "Trotzdem")) {
                pendingRepeatAction?()
                pendingRepeatAction = nil
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                pendingRepeatAction = nil
            }
        } message: {
            Text(antiRepeatMessage)
        }
        .alert(l.tr(zh: "删除喂食记录？", en: "Delete feeding log?", de: "Fütterung löschen?"), isPresented: $showingDeleteFeedLogConfirm) {
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                if let log = feedLogPendingDelete { deleteFeedLog(log) }
                feedLogPendingDelete = nil
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                feedLogPendingDelete = nil
            }
        } message: {
            Text(l.tr(zh: "余粮会根据删除后的记录重新计算。", en: "Stock will recalculate after deletion.", de: "Der Vorrat wird danach neu berechnet."))
        }
        .alert(l.tr(zh: "删除这袋粮？", en: "Delete this stock bag?", de: "Diesen Vorrat löschen?"), isPresented: $showingDeleteFoodRecordConfirm) {
            Button(l.tr(zh: "删除这袋粮", en: "Delete this bag", de: "Diesen Vorrat löschen"), role: .destructive) {
                if let record = foodRecordPendingDelete { deleteFoodRecord(record) }
                foodRecordPendingDelete = nil
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                foodRecordPendingDelete = nil
            }
        } message: {
            Text(l.tr(
                zh: "只删除这条补粮/开袋记录，不影响喂食历史。余粮会回退到上一袋已开袋粮；如果没有上一袋，则变为未设置。",
                en: "Only this restock/opened-bag record is removed. Feeding history stays. Stock falls back to the previous opened bag, or becomes unset.",
                de: "Nur dieser Nachfüll-/Öffnungseintrag wird gelöscht. Fütterungshistorie bleibt. Der Vorrat fällt auf den vorherigen geöffneten Beutel zurück oder wird leer."
            ))
        }
        .interactiveDismissDisabled(inlineOverlayBlocksBackground)
        .animation(GoMotion.page, value: activeSheet?.id)
    }

    private func inlineFeedSheetOverlay(_ sheet: ActiveFeedSheet) -> some View {
        GeometryReader { proxy in
            let bottomInset = inlineKeyboardHeight > 0 ? inlineKeyboardHeight + 8 : CGFloat(8)
            let maxHeight = min(sheet.inlineOverlayMaxHeight, proxy.size.height * (inlineKeyboardHeight > 0 ? 0.68 : 0.94))
            let measuredHeight = max(260, adaptiveSheetHeight - sheet.inlineOverlayChromeReduction)
            let panelHeight = min(max(sheet.inlineOverlayMinHeight, measuredHeight), maxHeight)
            let horizontalInset = CGFloat(6)
            let panelWidth = max(0, proxy.size.width - horizontalInset * 2)
            let cornerRadius = CGFloat(52)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let hiddenOffset = panelHeight + bottomInset + 64

            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: inlineSheetVisible) {
                inlineSheetBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isInlineInputActive {
                            dismissFeedKeyboard()
                        } else {
                            dismissInlineFeedSheet()
                        }
                    }

                ZStack(alignment: .top) {
                    sheetContent(sheet)
                        .frame(maxWidth: .infinity)
                        .frame(height: panelHeight)
                        .clipShape(shape)

                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .gesture(inlineSheetDragGesture)
                        .zIndex(3)

                    HStack {
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                            dismissInlineFeedSheet()
                        }
                        .padding(.top, inlineSheetCloseTopPadding(for: sheet))
                        .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background {
                    FeedInlineSheetGlassSurface(
                        cornerRadius: cornerRadius,
                        glassMode: .regular
                    )
                }
                .clipShape(shape)
                .frame(width: panelWidth)
                .shadow( // ui-v4: allow alert-style inline sheet lift shadow
                    color: Color.black.opacity(inlineSheetVisible ? 0.56 : 0), // ui-v4: allow alert-style inline sheet lift shadow
                    radius: 48,
                    x: 0,
                    y: -18
                )
                .shadow( // ui-v4: allow soft grounding shadow behind glass sheet
                    color: Color(hex: "0B102C").opacity(inlineSheetVisible ? 0.46 : 0), // ui-v4: allow soft grounding shadow behind glass sheet
                    radius: 28,
                    x: 0,
                    y: 12
                )
                .offset(y: inlineSheetVisible ? inlineSheetDragOffset : hiddenOffset)
                .opacity(inlineSheetVisible ? 1 : 0.94)
                .scaleEffect(inlineSheetVisible ? 1 : 0.982, anchor: .bottom)
                .padding(.bottom, bottomInset)
                .animation(GoMotion.page, value: inlineKeyboardHeight)
                .animation(GoMotion.feedback, value: inlineSheetDragOffset)
                .animation(GoMotion.page, value: inlineSheetVisible)
            }
            .onAppear {
                inlineSheetVisible = false
                inlineSheetTopPullDismissArmed = false
                inlineSheetDismissGestureShield = false
                DispatchQueue.main.async {
                    withAnimation(GoMotion.page) {
                        inlineSheetVisible = true
                    }
                }
            }
        }
    }

    private func inlineSheetCloseTopPadding(for sheet: ActiveFeedSheet) -> CGFloat {
        switch sheet {
        case .plan:
            return 22
        default:
            return 10
        }
    }

    private var inlineSheetScrollTopMarker: some View {
        Color.clear
            .frame(height: 0)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FeedInlineSheetScrollTopPreferenceKey.self,
                        value: proxy.frame(in: .named(FeedInlineSheetScrollCoordinateSpace.name)).minY
                    )
                }
            }
    }

    private var inlineSheetTopPullDismissGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onEnded { value in
                let vertical = value.translation.height
                let horizontal = abs(value.translation.width)
                guard inlineSheetScrollTopOffset >= -3,
                      vertical > 86,
                      vertical > horizontal * 1.18
                else { return }

                if isInlineInputActive {
                    dismissFeedKeyboard()
                } else if inlineSheetTopPullDismissArmed {
                    dismissInlineFeedSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetTopPullDismissArmed = true
                    }
                }
            }
    }

    private var inlineSheetBackdrop: some View {
        ZStack {
            Color.black.opacity(inlineSheetVisible ? 0.16 : 0) // ui-v4: allow modal scrim behind inline glass sheet
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(inlineSheetVisible ? 0.26 : 0) // ui-v4: allow modal grounding shade behind bottom glass sheet
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(GoMotion.page, value: inlineSheetVisible)
    }

    private var inlineSheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                inlineSheetDragOffset = min(140, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 72 || value.predictedEndTranslation.height > 130 {
                    dismissInlineFeedSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    private func openRootFeedSheet(_ sheet: ActiveFeedSheet) {
        nestedInlineSheet = nil
        nestedInlineReturnStack.removeAll()
        feedSheetReturnStack.removeAll()
        activeSheet = sheet
        scheduleDetailDataLoad(for: sheet)
    }

    private func openFeedSheet(_ sheet: ActiveFeedSheet) {
        if let currentNested = nestedInlineSheet, sheet.usesInlineOverlay {
            if currentNested.id != sheet.id {
                nestedInlineReturnStack.append(currentNested)
            }
            nestedInlineSheet = sheet
            scheduleDetailDataLoad(for: sheet)
            return
        }
        if activeSheet?.usesInlineOverlay == false, sheet.usesInlineOverlay {
            nestedInlineSheet = sheet
            scheduleDetailDataLoad(for: sheet)
            return
        }
        if let current = activeSheet, current.id != sheet.id {
            feedSheetReturnStack.append(current)
        } else if activeSheet == nil {
            feedSheetReturnStack.removeAll()
        }
        activeSheet = sheet
        scheduleDetailDataLoad(for: sheet)
    }

    private func closeActiveFeedSheet() {
        if nestedInlineSheet != nil {
            if let returnSheet = nestedInlineReturnStack.popLast() {
                nestedInlineSheet = returnSheet
            } else {
                nestedInlineSheet = nil
            }
            return
        }
        if let returnSheet = feedSheetReturnStack.popLast() {
            activeSheet = returnSheet
        } else {
            activeSheet = nil
        }
    }

    private func dismissInlineFeedSheet() {
        dismissFeedKeyboard()
        let dismissingSheetID = activeInlineSheet?.id
        inlineSheetDismissGestureShield = true
        withAnimation(GoMotion.page) {
            inlineSheetVisible = false
            inlineKeyboardHeight = 0
            inlineSheetDragOffset = 0
            inlineSheetTopPullDismissArmed = false
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            if nestedInlineSheet?.id == dismissingSheetID {
                nestedInlineSheet = nil
            } else if activeSheet?.id == dismissingSheetID {
                closeActiveFeedSheet()
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            if activeInlineSheet == nil {
                inlineSheetDismissGestureShield = false
            }
        }
    }

    private func updateInlineKeyboardHeight(_ notification: Notification) {
        guard activeInlineSheet != nil else { return }
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let height = max(0, frame.height)
        withAnimation(GoMotion.quick) {
            inlineKeyboardHeight = height
        }
    }

    private func scheduleDetailDataLoad(for sheet: ActiveFeedSheet) {
        let needsCareLogs = sheet.needsFullCareLogs
        let needsFoodRecords = sheet.needsFullFoodRecords
        guard (needsCareLogs && !hasLoadedFullCareLogs) ||
              (needsFoodRecords && !hasLoadedFullFoodRecords)
        else { return }

        feedDetailDataTask?.cancel()
        feedDetailDataTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: sheet.usesInlineOverlay ? 70 : 120) {
            FeedHomePerformance.measure("detail.lazyLoad") {
                if needsCareLogs {
                    loadFullCareLogs()
                }
                if needsFoodRecords {
                    loadFullFoodRecords()
                }
            }
            reloadFeedSnapshots()
            feedDetailDataTask = nil
        }
    }

    private func loadFullCareLogs(force: Bool = false) {
        guard force || !hasLoadedFullCareLogs else { return }
        let petID = pet.id
        let feedingType = CareType.feeding.rawValue
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.type == feedingType && log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        loadedCareLogs = (try? modelContext.fetch(descriptor)) ?? allCareLogs
        hasLoadedFullCareLogs = true
    }

    private func loadFullFoodRecords(force: Bool = false) {
        guard force || !hasLoadedFullFoodRecords else { return }
        let petID = pet.id
        let descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { record in
                record.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        loadedFoodRecords = (try? modelContext.fetch(descriptor)) ?? allFoodRecords
        hasLoadedFullFoodRecords = true
    }

    // MARK: - Main

    private var petHeader: some View {
        HStack(spacing: 12) {
            avatarView(size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "粮食记录", en: "Food log", de: "Futter"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .frame(width: 44, height: 44)
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var guidedFeedHome: some View {
        QuickFeedHomePresenter(
            pet: pet,
            localization: l,
            viewState: feedHomeController.viewState,
            modeTransition: feedHomeController.modeTransition,
            isAuxiliaryReady: feedHomeController.isAuxiliaryReady,
            overviewChartProgress: overviewChartProgress,
            feedFeedbackToken: feedFeedbackToken,
            feedFeedbackMetricId: feedFeedbackMetricId,
            stockFeedbackToken: stockFeedbackToken,
            dryFoodTint: dryFoodTint,
            wetFoodTint: wetFoodTint,
            stockTint: stockTint,
            treatTint: treatTint,
            mainFoodOverviewTint: mainFoodOverviewTint,
            onModeTap: handleFeedModeChipTap,
            onPrimaryAction: handleGuidedFeedPrimaryTap,
            onOpenFeedingOverview: openFeedingOverview,
            onOpenStockOverview: { openRootFeedSheet(.stockOverview) },
            onOpenTreatOverview: { openRootFeedSheet(.treatOverview) },
            onOpenManualHistory: { openRootFeedSheet(.history) },
            onOpenModeHistory: { openRootFeedSheet(.feedModeHistory) },
            onOpenManage: { openFeedSheet(.manage) }
        )
        .body
    }

    private var toastView: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(toastMessage)
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(toastTint, in: Capsule())
            .padding(.bottom, 34)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveFeedSheet) -> some View {
        switch sheet {
        case .manual:
            manualFeedSheet
        case .treat:
            treatFeedSheet
        case .plan(let kind):
            planEditorSheet(kind)
        case .stock:
            stockSheet
        case .stockManage:
            stockManageSheet
        case .manage:
            manageSheet
        case .history:
            historySheet
        case .feedModeHistory:
            feedModeHistorySheet
        case .stockRecords:
            stockRecordsSheet
        case .editLog:
            editFeedLogSheet
        case .feedingOverview:
            feedingOverviewSheet
        case .stockOverview:
            stockOverviewSheet
        case .treatOverview:
            treatOverviewSheet
        }
    }

    private var manualFeedSheet: some View {
        let isSettingsOnly = manualFeedSheetMode == .settingsOnly
        let isPlannedCompletion = !isSettingsOnly && dashboard.nextManualReminder != nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sheetHero(icon: "fork.knife.circle.fill", title: manualFeedSheetTitle, tint: mainFoodTint)
                if !isSettingsOnly, let reminder = dashboard.nextManualReminder {
                    plannedReminderBanner(reminder)
                }
                if isSettingsOnly || dashboard.nextManualReminder == nil {
                    manualFoodKindSelector
                }
                if !isSettingsOnly, dashboard.nextManualReminder == nil, sameSpeciesFeedPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "共同照护", en: "Shared care", de: "Gemeinsam"),
                        subtitle: "\(selectedFeedTargets.count)只\(pet.species)",
                        pets: sameSpeciesFeedPets,
                        selectedPetIds: $selectedSharedFeedPetIds,
                        tint: mainFoodTint
                    )
                }
                manualGramInput(
                    title: l.tr(zh: "克数", en: "Grams", de: "Gramm"),
                    text: $manualGramsText,
                    field: .manualGrams,
                    tint: mainFoodTint,
                    quickValues: quickMainGramOptions
                )
                if !isSettingsOnly {
                    manualDefaultToggle
                }

                if let inputError {
                    errorText(inputError)
                }

                FoodPrimaryButton(
                    title: isSettingsOnly
                        ? l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
                        : (isPlannedCompletion ? l.tr(zh: "完成计划餐", en: "Complete planned meal", de: "Planmahlzeit erledigen") : l.tr(zh: "完成打卡", en: "Log feeding", de: "Eintragen")),
                    icon: isSettingsOnly ? "checkmark" : "checkmark.circle.fill",
                    tint: mainFoodTint
                ) {
                    if isSettingsOnly {
                        saveManualFeedSettings()
                    } else if dashboard.nextManualReminder == nil {
                        commitManualFeed()
                    } else {
                        completeNextPlannedFeed()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 310,
                maxHeight: 560,
                chromePadding: 66
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }

    private var manualFeedSheetTitle: String {
        manualFeedSheetMode == .settingsOnly
            ? l.tr(zh: "喂食设置", en: "Feeding settings", de: "Fütterung einstellen")
            : l.tr(zh: "记录喂食", en: "Log feeding", de: "Fütterung eintragen")
    }

    private var treatFeedSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sheetHero(icon: "birthday.cake.fill", title: l.tr(zh: "记录零食", en: "Log treats", de: "Snack eintragen"), tint: treatTint)
                treatKindPicker(selection: $selectedTreatKind)
                gramInput(
                    title: l.tr(zh: "克数（可选）", en: "Grams (optional)", de: "Gramm (optional)"),
                    text: $treatGramsText,
                    field: .treatGrams,
                    tint: treatTint,
                    quickValues: [5, 10, 15, 20]
                )
                if let inputError {
                    errorText(inputError)
                }
                FoodPrimaryButton(title: l.tr(zh: "保存零食", en: "Save treat", de: "Snack speichern"), icon: "checkmark", tint: treatTint) {
                    commitTreatFeed()
                }
            }
            .padding(20)
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 66
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.tr(zh: "零食", en: "Treats", de: "Snacks"))
    }

    private func planEditorSheet(_ kind: FeedRuleKind) -> some View {
        let tint = kind == .manualReminder ? Color.goPurple : Color.goTeal
        let hasExistingPlan = !FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents).isEmpty

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inlineSheetScrollTopMarker
                sheetHero(
                    icon: kind.iconName,
                    title: kind == .manualReminder ? l.tr(zh: "喂食计划", en: "Feeding plan", de: "Fütterungsplan") : l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat"),
                    tint: tint
                )
                compactNotice(
                    icon: kind.iconName,
                    text: kind == .manualReminder
                        ? l.tr(zh: "到点提醒你确认打卡；每餐可单独设置干粮/湿粮和克数。", en: "Reminds you to confirm meals. Each meal can set food type and grams.", de: "Erinnert dich. Jede Mahlzeit hat Sorte und Gramm.")
                        : l.tr(zh: "不提醒、不等待确认；App 打开或进入本页时会自动补记并扣余粮。", en: "No reminder or confirmation. The app backfills due meals and deducts stock.", de: "Keine Erinnerung. Fällige Mahlzeiten werden automatisch eingetragen."),
                    tint: tint
                )
                if sameSpeciesFeedPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "目标宠物", en: "Pets", de: "Tiere"),
                        subtitle: "\(selectedPlanTargets.count)只\(pet.species)",
                        pets: sameSpeciesFeedPets,
                        selectedPetIds: $selectedSharedPlanPetIds,
                        tint: tint
                    )
                }

                HStack(spacing: 12) {
                    planStepperCard(
                        title: l.tr(zh: "每天", en: "Per day", de: "Pro Tag"),
                        value: "\(planCount)",
                        tint: tint
                    ) {
                        Stepper("", value: $planCount, in: 1...6)
                            .labelsHidden()
                            .onChange(of: planCount) { _, newValue in
                                syncPlanTimesCount(newValue)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(zh: "每餐", en: "Meals", de: "Mahlzeiten"))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    ForEach(Array(planMeals.indices), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(FeedRuleMetadata.mealName(for: planMeals[index].time), systemImage: "clock.fill")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(tint)
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { planMeals[index].time },
                                    set: { planMeals[index].time = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()

                            foodKindSegmentedControl(selection: planMeals[index].foodKind) { foodKind in
                                withAnimation(GoMotion.feedback) {
                                    planMeals[index].foodKind = foodKind
                                }
                                UISelectionFeedbackGenerator().selectionChanged()
                            }

                            planMealGramEditor(index: index, tint: tint)
                        }
                        .padding(10)
                        .feedFlatBlockSurface(cornerRadius: 16)
                    }
                }

                if let inputError {
                    errorText(inputError)
                }
            }
            .padding(18)
            .padding(.bottom, hasExistingPlan ? 126 : 78)
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesFeedPets.count > 1 ? 690 : 620,
                maxHeight: 860,
                chromePadding: 70
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            planEditorFooter(kind: kind, tint: tint, hasExistingPlan: hasExistingPlan)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FeedScrollBounceConfigurator(isBouncingEnabled: false))
        .coordinateSpace(name: FeedInlineSheetScrollCoordinateSpace.name)
        .onPreferenceChange(FeedInlineSheetScrollTopPreferenceKey.self) { value in
            inlineSheetScrollTopOffset = value
            if value < -8 {
                inlineSheetTopPullDismissArmed = false
            }
        }
        .simultaneousGesture(inlineSheetTopPullDismissGesture)
        .navigationTitle(kind == .manualReminder ? l.tr(zh: "计划", en: "Plan", de: "Plan") : l.tr(zh: "自动", en: "Auto", de: "Auto"))
    }

    private func planEditorFooter(kind: FeedRuleKind, tint: Color, hasExistingPlan: Bool) -> some View {
        VStack(spacing: 10) {
            FoodPrimaryButton(
                title: kind == .manualReminder ? l.tr(zh: "保存计划", en: "Save plan", de: "Plan speichern") : l.tr(zh: "保存自动记录", en: "Save auto feeder", de: "Automat speichern"),
                icon: "checkmark",
                tint: tint
            ) {
                savePlan(kind)
            }

            if hasExistingPlan {
                Button(role: .destructive) {
                    deletePlan(kind)
                } label: {
                    Label(l.tr(zh: "删除当前计划", en: "Delete current plan", de: "Aktuellen Plan löschen"), systemImage: "trash")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .feedFlatBlockSurface(cornerRadius: 16)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background {
            LinearGradient(
                colors: [
                    Color.ohanaCardSurface.opacity(0.70),
                    Color.ohanaCardSurface.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var stockSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sheetHero(
                    icon: "shippingbox.fill",
                    title: editingFoodRecord == nil
                        ? l.tr(zh: "补粮", en: "Restock", de: "Nachfüllen")
                        : l.tr(zh: "修改余粮", en: "Edit stock", de: "Vorrat bearbeiten"),
                    tint: stockTint
                )
                foodKindPicker(selection: $selectedStockFoodKind)
                VStack(spacing: 12) {
                    TextField(l.tr(zh: "品牌，可选", en: "Brand, optional", de: "Marke, optional"), text: $stockBrandText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .stockBrand)
                        .feedingTextFieldStyle(tint: stockTint)
                    brandSuggestionChips
                    gramInput(
                        title: l.tr(zh: "总重量", en: "Total weight", de: "Gesamtgewicht"),
                        text: $stockWeightText,
                        field: .stockWeight,
                        tint: stockTint,
                        quickValues: [1000, 1500, 2000, 4000]
                    )
                    optionalStockDateRow(
                        title: l.tr(zh: "购买日期", en: "Purchase date", de: "Kaufdatum"),
                        isOn: $stockHasPurchaseDate,
                        date: $stockPurchaseDate
                    )
                    stockExpenseOptions
                    optionalStockDateRow(
                        title: l.tr(zh: "开袋日期", en: "Open date", de: "Öffnungsdatum"),
                        isOn: $stockHasOpenDate,
                        date: $stockOpenDate
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $stockReminderEnabled) {
                        Text(l.tr(zh: "低余粮提醒", en: "Low stock reminder", de: "Vorrats-Erinnerung"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .tint(stockTint)

                    if stockReminderEnabled {
                        Picker(l.tr(zh: "提前", en: "Advance", de: "Vorher"), selection: $stockReminderAdvanceDays) {
                            ForEach(stockReminderAdvanceOptions, id: \.self) { days in
                                Text("\(days) \(l.tr(zh: "天", en: "days", de: "Tage"))").tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(14)
                .feedFlatBlockSurface(cornerRadius: 18)

                if let inputError {
                    errorText(inputError)
                }
            }
            .padding(18)
            .padding(.bottom, 88)
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 620,
                maxHeight: 820,
                chromePadding: 112
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stockSheetFooter
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: selectedStockFoodKind) { _, newValue in
            guard editingFoodRecord == nil else { return }
            stockBrandText = ""
            stockWeightText = ""
            stockHasPurchaseDate = false
            stockPurchaseDate = Date()
            stockHasOpenDate = false
            stockOpenDate = Date()
            configureStockExpenseFields(for: nil)
            stockExpenseAmountKeypadVisible = false
        }
        .navigationTitle(l.tr(zh: "余粮", en: "Stock", de: "Vorrat"))
    }

    private var stockSheetFooter: some View {
        VStack(spacing: 0) {
            FoodPrimaryButton(
                title: editingFoodRecord == nil
                    ? l.tr(zh: "保存补粮", en: "Save restock", de: "Speichern")
                    : l.tr(zh: "保存修改", en: "Save changes", de: "Änderungen speichern"),
                icon: "checkmark",
                tint: stockTint
            ) {
                saveStock()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background {
            LinearGradient(
                colors: [
                    Color.ohanaCardSurface.opacity(0.02),
                    Color.ohanaCardSurface.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }

    private func optionalStockDateRow(title: String, isOn: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: isOn.animation(GoMotion.feedback)) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(stockTint)

            if isOn.wrappedValue {
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(stockTint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    private var stockExpenseOptions: some View {
        VStack(spacing: 10) {
            HStack {
                Text(l.tr(zh: "支付人", en: "Payer", de: "Zahlende Person"))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Menu {
                    Button(l.tr(zh: "未指定", en: "Unspecified", de: "Nicht angegeben")) {
                        stockExpensePayerId = nil
                    }
                    ForEach(allHumans) { human in
                        Button(human.name) {
                            stockExpensePayerId = human.id.uuidString
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(stockExpensePayerName)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(stockTint)
                }
            }

            stockExpenseAmountInput
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    private var stockExpenseAmountInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(l.tr(zh: "金额", en: "Amount", de: "Betrag"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(l.tr(zh: "可选", en: "Optional", de: "Optional"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(stockExpenseAmountText.isEmpty ? Color.ohanaTertiaryText : stockTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            }

            Button {
                dismissSystemFeedKeyboardIfNeeded()
                focusedField = nil
                withAnimation(GoMotion.feedback) {
                    stockExpenseAmountKeypadVisible.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(AppCurrency.symbol)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(stockTint)
                    Text(stockExpenseAmountText.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code) : stockExpenseAmountText)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(stockExpenseAmountText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 8)
                    Image(systemName: stockExpenseAmountKeypadVisible ? "keyboard.chevron.compact.down" : "number")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(stockTint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            if stockExpenseAmountKeypadVisible {
                EmbeddedDecimalKeypad(
                    text: $stockExpenseAmountText,
                    countryCode: AppCountry.code,
                    maxFractionDigits: 2,
                    accent: stockTint,
                    isMini: true
                ) {
                    withAnimation(GoMotion.feedback) {
                        stockExpenseAmountKeypadVisible = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private var stockExpensePayerName: String {
        guard let stockExpensePayerId,
              let human = allHumans.first(where: { $0.id.uuidString == stockExpensePayerId })
        else {
            return l.tr(zh: "未指定", en: "Unspecified", de: "Nicht angegeben")
        }
        return human.name
    }

    private var stockManageSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sheetHero(icon: "shippingbox.fill", title: l.tr(zh: "余粮管理", en: "Stock manage", de: "Vorrat verwalten"), tint: stockTint)
                foodKindSegmentedControl(selection: selectedStockFoodKind) { foodKind in
                    withAnimation(GoMotion.page) {
                        selectedStockFoodKind = foodKind
                        prepareStockCorrectionText()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                let activeRecord = managedActiveStockRecord
                if let activeRecord {
                    stockManagementCurrentCard(record: activeRecord)
                    stockCorrectionCard(record: activeRecord)
                } else {
                    emptyInlineState(icon: "shippingbox", text: l.tr(zh: "当前类型还没有已开袋余粮", en: "No opened stock for this type", de: "Kein geöffneter Vorrat für diesen Typ"))
                }

                stockReminderManageCard
                stockPendingRecordsCard
                stockRecentRecordsCard

                FoodPrimaryButton(title: l.tr(zh: "新增补粮", en: "Add restock", de: "Nachfüllung hinzufügen"), icon: "plus", tint: stockTint) {
                    prepareStockSheet(foodKind: selectedStockFoodKind)
                    openFeedSheet(.stock)
                }

                if let activeRecord {
                    stockDeleteCurrentRecordCard(record: activeRecord)
                }
            }
            .padding(20)
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 520,
                maxHeight: 760,
                chromePadding: 70
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.tr(zh: "余粮管理", en: "Stock manage", de: "Vorrat verwalten"))
    }

    private func stockDeleteCurrentRecordCard(record: PetFoodRecord) -> some View {
        Button {
            foodRecordPendingDelete = record
            showingDeleteFoodRecordConfirm = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 34, height: 34)
                    .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "删除这袋粮", en: "Delete this bag", de: "Diesen Vorrat löschen"))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                    Text(l.tr(
                        zh: "只删除当前补粮/开袋记录，不删除喂食历史。",
                        en: "Removes only this stock record, not feeding history.",
                        de: "Entfernt nur diesen Vorratseintrag, nicht die Fütterungshistorie."
                    ))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            .padding(14)
            .feedFlatBlockSurface(cornerRadius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(pet.hasPassedAway)
    }

    private var managedStockRecords: [PetFoodRecord] {
        observedFoodRecords
            .filter { $0.foodKind == selectedStockFoodKind }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate > rhs.startDate }
                if (lhs.purchaseDate ?? .distantPast) != (rhs.purchaseDate ?? .distantPast) {
                    return (lhs.purchaseDate ?? .distantPast) > (rhs.purchaseDate ?? .distantPast)
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
    }

    private var managedActiveStockRecord: PetFoodRecord? {
        FeedStockCalculator.activeStockRecord(for: pet, foodKind: selectedStockFoodKind, foodRecords: observedFoodRecords)
    }

    private var managedPendingStockRecords: [PetFoodRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        return managedStockRecords
            .filter { FeedStockCalculator.stockOpenDay(for: $0) > today }
            .sorted { FeedStockCalculator.stockOpenDay(for: $0) < FeedStockCalculator.stockOpenDay(for: $1) }
    }

    private var managedOpenedHistoryStockRecords: [PetFoodRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        let activeID = managedActiveStockRecord?.id
        return managedStockRecords.filter {
            $0.id != activeID && FeedStockCalculator.stockOpenDay(for: $0) <= today
        }
    }

    private func stockManagementCurrentCard(record: PetFoodRecord) -> some View {
        let snapshot = dashboard.stock(foodKind: selectedStockFoodKind)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.brand.isEmpty ? l.tr(zh: "当前余粮", en: "Current stock", de: "Aktueller Vorrat") : record.brand)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("\(selectedStockFoodKind.title(l)) · \(formattedStockWeight(snapshot.remainingGrams))")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(stockStatusTint(snapshot))
                }
                Spacer()
                Text(snapshot.remainingDays > 0 ? "\(snapshot.remainingDays)d" : "--")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(stockStatusTint(snapshot))
            }

            stockDateLine(
                title: l.tr(zh: "购买", en: "Bought", de: "Gekauft"),
                date: record.purchaseDate ?? record.startDate
            )
            stockDateLine(
                title: l.tr(zh: "开袋", en: "Opened", de: "Geöffnet"),
                date: record.startDate
            )
            if let grams = record.remainingCorrectionGrams, let date = record.remainingCorrectionDate {
                Text(l.tr(
                    zh: "已手动修正为 \(formattedStockWeight(grams)) · \(date.formatted(date: .numeric, time: .shortened))",
                    en: "Manually corrected to \(formattedStockWeight(grams)) · \(date.formatted(date: .numeric, time: .shortened))",
                    de: "Manuell korrigiert auf \(formattedStockWeight(grams)) · \(date.formatted(date: .numeric, time: .shortened))"
                ))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            prepareStockSheet(record: record)
            openFeedSheet(.stock)
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .accessibilityAddTraits(.isButton)
    }

    private func stockDateLine(title: String, date: Date) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
            Text(date.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private func stockCorrectionCard(record: PetFoodRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "手动修正余量", en: "Correct remaining stock", de: "Restbestand korrigieren"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    openFeedNumberPad(.stockCorrection)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(stockCorrectionText.isEmpty ? "800" : stockCorrectionText)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(stockCorrectionText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(stockTint)
                        Spacer()
                        Image(systemName: "number")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(stockTint)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                feedInlineNumberPad(field: .stockCorrection, text: $stockCorrectionText, tint: stockTint, maxFractionDigits: 0)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 16)
            FoodPrimaryButton(title: l.tr(zh: "保存修正", en: "Save correction", de: "Korrektur speichern"), icon: "checkmark", tint: stockTint) {
                correctStock(record)
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
    }

    private var stockReminderManageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $stockReminderEnabled) {
                Text(l.tr(zh: "低余粮提醒", en: "Low stock reminder", de: "Vorrats-Erinnerung"))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(stockTint)

            if stockReminderEnabled {
                Picker(l.tr(zh: "提前", en: "Advance", de: "Vorher"), selection: $stockReminderAdvanceDays) {
                    ForEach(stockReminderAdvanceOptions, id: \.self) { days in
                        Text("\(days) \(l.tr(zh: "天", en: "days", de: "Tage"))").tag(days)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                saveStockReminderSettings()
            } label: {
                Label(l.tr(zh: "保存提醒", en: "Save reminder", de: "Erinnerung speichern"), systemImage: "bell.badge.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(stockTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .feedFlatBlockSurface(cornerRadius: 16)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
    }

    private var stockPendingRecordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            overviewSectionHeader(l.tr(zh: "待开袋", en: "Pending open", de: "Wartet auf Öffnung"))
            if managedPendingStockRecords.isEmpty {
                emptyInlineState(icon: "clock", text: l.tr(zh: "没有未来开袋的粮", en: "No future stock", de: "Kein künftiger Vorrat"))
            } else {
                ForEach(managedPendingStockRecords.prefix(3)) { record in
                    foodRecordRow(record)
                }
            }
        }
    }

    @ViewBuilder
    private var stockRecentRecordsCard: some View {
        if !managedOpenedHistoryStockRecords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                overviewSectionHeader(l.tr(zh: "最近补粮", en: "Recent restocks", de: "Letzte Nachfüllungen"))
                ForEach(managedOpenedHistoryStockRecords.prefix(4)) { record in
                    foodRecordRow(record)
                }
            }
        }
    }

    private var manageSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHero(icon: "slider.horizontal.3", title: l.tr(zh: "管理", en: "Manage", de: "Verwalten"), tint: Color.goPrimary)
            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "模式", en: "Mode", de: "Modus"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                feedModeSelector
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 18)
            manageRow(
                icon: "fork.knife",
                title: l.tr(zh: "默认粮种 / 克数", en: "Default food / grams", de: "Standardfutter / Gramm"),
                value: pet.dailyPortionGrams > 0 ? "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))" : l.tr(zh: "待设置", en: "Not set", de: "Nicht gesetzt"),
                tint: mainFoodTint
            ) {
                openManualFeedSheet(settingsOnly: true)
            }
            manageRow(
                icon: FeedRuleKind.manualReminder.iconName,
                title: l.tr(zh: "喂食计划", en: "Feeding plan", de: "Fütterungsplan"),
                value: feedScheduleEvents.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : "\(feedScheduleEvents.count) \(l.tr(zh: "次/天", en: "x/day", de: "x/Tag"))",
                tint: Color.goPurple
            ) {
                openPlanEditor(.manualReminder)
            }
            manageRow(
                icon: FeedRuleKind.autoFeeder.iconName,
                title: l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat"),
                value: autoFeederEvents.isEmpty ? l.tr(zh: "未开启", en: "Off", de: "Aus") : formattedFoodWeight(dashboard.autoDailyTotalGrams) + l.tr(zh: "/天", en: "/day", de: "/Tag"),
                tint: Color.goTeal
            ) {
                openPlanEditor(.autoFeeder)
            }
            manageRow(
                icon: "shippingbox.fill",
                title: l.tr(zh: "余粮记录", en: "Stock records", de: "Vorratseinträge"),
                value: "\(observedFoodRecords.count)",
                tint: stockTint
            ) {
                openFeedSheet(.stockRecords)
            }
            manageRow(
                icon: "clock.arrow.circlepath",
                title: l.tr(zh: "完整历史", en: "Full history", de: "Historie"),
                value: "\(observedCareLogs.count)",
                tint: Color.goPrimary
            ) {
                openFeedSheet(.history)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .ohanaAdaptiveSheetContentHeight(
            $adaptiveSheetHeight,
            minHeight: 300,
            maxHeight: 580,
            chromePadding: 66
        )
        .navigationTitle(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
    }

    private var historySheet: some View {
        let logs = observedCareLogs.sorted { $0.date > $1.date }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if logs.isEmpty {
                    emptyInlineState(icon: "fork.knife", text: l.tr(zh: "还没有喂食记录", en: "No feeding logs yet", de: "Noch keine Einträge"))
                } else {
                    ForEach(logs) { log in
                        feedLogRow(log, compact: false)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    private var feedModeHistorySheet: some View {
        let logs = Array(feedModeLogsInRange.sorted { $0.date > $1.date }.prefix(40))
        return ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if activeFeedingMode == .manualReminder || activeFeedingMode == .autoFeeder {
                        feedPlanCalendarSection
                        feedPlanSelectedDateSection
                    } else {
                        if activeFeedingMode == .manual {
                            manualFeedSettingSummary
                        }
                        overviewRangePicker(tint: feedingModeTint)
                        overviewLineChart(
                            title: l.tr(zh: "打卡曲线", en: "Check-in chart", de: "Check-in-Kurve"),
                            subtitle: feedModeHistoryChartSubtitle,
                            points: feedModeChartPoints,
                            tint: feedingModeTint,
                            emptyText: l.tr(zh: "该模式还没有打卡记录", en: "No check-ins for this mode yet", de: "Noch keine Einträge für diesen Modus"),
                            showsSurface: false
                        )
                        feedModeHistoryStatusSection
                        overviewSectionHeader(l.tr(zh: "历史记录", en: "History", de: "Verlauf"))
                        if logs.isEmpty {
                            emptyInlineState(icon: "fork.knife", text: l.tr(zh: "该模式还没有记录", en: "No records in this mode", de: "Keine Einträge für diesen Modus"), solid: true)
                        } else {
                            ForEach(logs) { log in
                                feedLogRow(log, compact: false, solidSurface: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            if showFeedPlanMonthPicker {
                Color.black.opacity(0.001) // ui-v4: allow invisible tap catcher for dismissing calendar picker
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(GoMotion.quick) {
                            showFeedPlanMonthPicker = false
                        }
                    }
                    .zIndex(10)

                feedPlanYearMonthPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .navigationTitle("")
    }

    private var stockRecordsSheet: some View {
        let records = observedFoodRecords.sorted { $0.startDate > $1.startDate }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if records.isEmpty {
                    emptyInlineState(icon: "shippingbox", text: l.tr(zh: "补粮后会显示在这里", en: "Restocks appear here", de: "Nachfüllungen erscheinen hier"))
                } else {
                    ForEach(records) { record in
                        foodRecordRow(record)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    private var editFeedLogSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sheetHero(icon: "pencil", title: l.tr(zh: "编辑记录", en: "Edit log", de: "Eintrag bearbeiten"), tint: mainFoodTint)
                gramInput(
                    title: l.tr(zh: "克数", en: "Grams", de: "Gramm"),
                    text: $editFeedLogGrams,
                    field: .editLogGrams,
                    tint: mainFoodTint,
                    quickValues: quickMainGramOptions
                )
                DatePicker(l.tr(zh: "时间", en: "Time", de: "Zeit"), selection: $editFeedLogDate)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(12)
                    .feedFlatBlockSurface(cornerRadius: 16)
                if let inputError {
                    errorText(inputError)
                }
                FoodPrimaryButton(title: l.tr(zh: "保存修改", en: "Save changes", de: "Änderungen speichern"), icon: "checkmark", tint: mainFoodTint) {
                    saveFeedLogEdit()
                }
            }
            .padding(20)
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 540,
                chromePadding: 66
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"))
    }

    private var feedingOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                feedingOverviewAggregateSummary
                overviewFoodBreakdown
                overviewRangePicker(tint: mainFoodOverviewTint)
                feedingOverviewSourceBreakdown
                overviewLineChart(
                    title: l.tr(zh: "进食量曲线", en: "Intake trend", de: "Futtertrend"),
                    subtitle: overviewChartSubtitle,
                    points: mainFoodChartPoints,
                    tint: mainFoodOverviewTint,
                    emptyText: l.tr(zh: "打卡后会出现曲线", en: "Log meals to see a trend", de: "Nach Einträgen erscheint ein Trend"),
                    showsSurface: false
                )
                overviewSectionHeader(l.tr(zh: "最近主粮", en: "Recent main food", de: "Letztes Hauptfutter"))
                let logs = Array(mainFoodLogsInRange.sorted { $0.date > $1.date }.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "fork.knife", text: l.tr(zh: "还没有主粮记录", en: "No main food logs yet", de: "Noch keine Hauptfutter-Einträge"), solid: true)
                } else {
                    ForEach(logs) { log in
                        feedLogRow(log, compact: false, solidSurface: true)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }

    @ViewBuilder
    private var feedingModeHistorySection: some View {
        switch activeFeedingMode {
        case .manual:
            EmptyView()
        case .manualReminder:
            overviewSectionHeader(l.tr(zh: "今日计划记录", en: "Plan check-ins", de: "Plan-Check-ins"))
            let reminders = dashboard.today.todayPlanReminders
            if reminders.isEmpty {
                emptyInlineState(icon: "clock.badge.questionmark", text: l.tr(zh: "今天还没有计划记录", en: "No plan check-ins today", de: "Heute keine Plan-Check-ins"), solid: true)
            } else {
                ForEach(reminders, id: \.id) { reminder in
                    planReminderHistoryRow(reminder, allowsCatchUp: true)
                }
            }
        case .autoFeeder:
            overviewSectionHeader(l.tr(zh: "今日自动记录", en: "Auto check-ins", de: "Auto-Check-ins"))
            let logs = dashboard.todayAutoFeedLogs.sorted { $0.date > $1.date }
            if logs.isEmpty {
                emptyInlineState(icon: "gearshape.2", text: l.tr(zh: "到点后会自动补记", en: "Due meals are logged automatically", de: "Fällige Mahlzeiten werden automatisch erfasst"), solid: true)
            } else {
                ForEach(logs) { log in
                    feedLogRow(log, compact: false, solidSurface: true)
                }
            }
        }
    }

    @ViewBuilder
    private var feedModeHistoryStatusSection: some View {
        switch activeFeedingMode {
        case .manual:
            EmptyView()
        case .manualReminder:
            overviewSectionHeader(l.tr(zh: "计划状态", en: "Plan status", de: "Planstatus"))
            let reminders = feedModePlanRemindersInRange
            if reminders.isEmpty {
                emptyInlineState(icon: "clock.badge.questionmark", text: l.tr(zh: "当前范围内没有计划状态", en: "No plan status in this range", de: "Kein Planstatus in diesem Zeitraum"), solid: true)
            } else {
                ForEach(reminders, id: \.id) { reminder in
                    planReminderHistoryRow(reminder)
                }
            }
        case .autoFeeder:
            EmptyView()
        }
    }

    private var manualFeedSettingSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: pet.mainFoodKind.systemIconName)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 42, height: 42)
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "当前打卡设置", en: "Current log setting", de: "Aktuelle Einstellung"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(manualFeedSettingSummaryText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Button {
                openManualFeedSheet(settingsOnly: true)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42)
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "修改打卡设置", en: "Edit log setting", de: "Einstellung ändern"))
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private var manualFeedSettingSummaryText: String {
        if pet.dailyPortionGrams > 0 {
            return l.tr(
                zh: "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))",
                en: "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))",
                de: "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))"
            )
        }
        return l.tr(
            zh: "\(pet.mainFoodKind.title(l)) · 未设置默认克数",
            en: "\(pet.mainFoodKind.title(l)) · no default amount",
            de: "\(pet.mainFoodKind.title(l)) · keine Standardmenge"
        )
    }

    private var feedPlanCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    shiftFeedPlanCalendarMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36)
                        .feedFlatBlockSurface(cornerRadius: 14)
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    withAnimation(GoMotion.quick) {
                        showFeedPlanMonthPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                    Text(feedPlanCalendarMonthTitle)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        Image(systemName: showFeedPlanMonthPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(ScaleButtonStyle())
                Spacer()
                Button {
                    let today = Date()
                    let direction = today >= feedPlanCalendarMonth ? 1 : -1
                    setFeedPlanCalendarMonth(today, direction: direction)
                } label: {
                    Text(l.tr(zh: "今天", en: "Today", de: "Heute"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .feedFlatBlockSurface(cornerRadius: 14)
                }
                .buttonStyle(ScaleButtonStyle())
                Button {
                    shiftFeedPlanCalendarMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36)
                        .feedFlatBlockSurface(cornerRadius: 14)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            FeedPlanMonthlyCalendarView(
                weekdayTitles: feedPlanWeekdayTitles,
                days: feedPlanCalendarDaySummaries,
                tint: feedingModeTint,
                textColor: Color.ohanaPrimaryText,
                secondaryTextColor: Color.ohanaSecondaryText,
                selectedDate: feedPlanCalendarSelectedDate,
                onSelectDate: { date in
                    withAnimation(GoMotion.quick) {
                        selectFeedPlanCalendarDate(date)
                    }
                }
            )
            .id(feedPlanCalendarMonthKey)
            .transition(.asymmetric(
                insertion: .move(edge: feedPlanCalendarMonthSlideDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: feedPlanCalendarMonthSlideDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
            ))
            .simultaneousGesture(
                DragGesture(minimumDistance: 28, coordinateSpace: .local)
                    .onEnded { value in
                        let width = value.translation.width
                        let height = value.translation.height
                        guard abs(width) > 54, abs(width) > abs(height) * 1.35 else { return }
                        shiftFeedPlanCalendarMonth(by: width < 0 ? 1 : -1)
                    }
            )
        }
    }

    private var feedPlanYearMonthPicker: some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: feedPlanCalendarMonth)
        let selectedMonth = calendar.component(.month, from: feedPlanCalendarMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    setFeedPlanCalendarYear(year - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 34)
                        .feedFlatBlockSurface(cornerRadius: 13)
                }
                .buttonStyle(ScaleButtonStyle())

                Text(feedPlanPlainYearText(year))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)

                Button {
                    setFeedPlanCalendarYear(year + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 34)
                        .feedFlatBlockSurface(cornerRadius: 13)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    let isSelected = month == selectedMonth
                    Button {
                        selectFeedPlanCalendarMonth(year: year, month: month)
                    } label: {
                        Text(feedPlanMonthTitle(month, year: year))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(isSelected ? feedingModeTint : Color.ohanaSecondaryText.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(12)
        .background {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(false), in: shape)
        }
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 12) // ui-v4: allow floating calendar picker lift shadow
    }

    private func shiftFeedPlanCalendarMonth(by delta: Int) {
        let calendar = Calendar.current
        guard let targetMonth = calendar.date(byAdding: .month, value: delta, to: feedPlanCalendarMonth) else { return }
        let targetYear = calendar.component(.year, from: targetMonth)
        let targetMonthNumber = calendar.component(.month, from: targetMonth)
        let firstDay = feedPlanDate(year: targetYear, month: targetMonthNumber, day: 1) ?? targetMonth
        setFeedPlanCalendarMonth(firstDay, direction: delta >= 0 ? 1 : -1)
    }

    private func setFeedPlanCalendarYear(_ year: Int) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: feedPlanCalendarMonth)
        guard let target = feedPlanDate(year: year, month: month, day: 1) else { return }
        let currentYear = calendar.component(.year, from: feedPlanCalendarMonth)
        setFeedPlanCalendarMonth(target, direction: year >= currentYear ? 1 : -1)
    }

    private func selectFeedPlanCalendarMonth(year: Int, month: Int) {
        let calendar = Calendar.current
        guard let firstDay = feedPlanDate(year: year, month: month, day: 1) else { return }
        let direction = firstDay >= calendar.startOfDay(for: feedPlanCalendarMonth) ? 1 : -1
        setFeedPlanCalendarMonth(firstDay, direction: direction)
    }

    private func selectFeedPlanCalendarDate(_ date: Date) {
        let calendar = Calendar.current
        let targetMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let direction = targetMonth >= (calendar.dateInterval(of: .month, for: feedPlanCalendarMonth)?.start ?? feedPlanCalendarMonth) ? 1 : -1
        feedPlanCalendarMonthSlideDirection = direction
        feedPlanCalendarMonth = targetMonth
        feedPlanCalendarSelectedDate = date
    }

    private func setFeedPlanCalendarMonth(_ firstDay: Date, direction: Int) {
        withAnimation(GoMotion.page) {
            feedPlanCalendarMonthSlideDirection = direction
            feedPlanCalendarMonth = firstDay
            feedPlanCalendarSelectedDate = defaultFeedPlanSelectedDate(forMonth: firstDay)
        }
    }

    private func defaultFeedPlanSelectedDate(forMonth firstDay: Date) -> Date {
        let calendar = Calendar.current
        let today = Date()
        if calendar.isDate(firstDay, equalTo: today, toGranularity: .month) {
            return today
        }
        return firstDay
    }

    private func feedPlanDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func feedPlanMonthTitle(_ month: Int, year: Int) -> String {
        if appLanguage == "zh" {
            return "\(month)月"
        }
        guard let date = feedPlanDate(year: year, month: month, day: 1) else { return "\(month)" }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func feedPlanPlainYearText(_ year: Int) -> String {
        String(format: "%04d", year)
    }

    @ViewBuilder
    private var feedPlanSelectedDateSection: some View {
        overviewSectionHeader(feedPlanSelectedDateSectionTitle)
        let occurrences = feedPlanSelectedDateOccurrences
        if occurrences.isEmpty {
            emptyInlineState(
                icon: "clock.badge.questionmark",
                text: activeFeedingMode == .autoFeeder
                    ? l.tr(zh: "这一天没有自动餐次", en: "No auto meals on this day", de: "Keine Auto-Mahlzeiten an diesem Tag")
                    : l.tr(zh: "这一天没有计划餐", en: "No planned meals on this day", de: "Keine Planmahlzeiten an diesem Tag"),
                solid: true
            )
        } else {
            ForEach(occurrences) { occurrence in
                feedPlanSelectedOccurrenceRow(occurrence)
            }
        }
    }

    private func feedPlanSelectedOccurrenceRow(_ occurrence: FeedPlanCalendarOccurrence) -> some View {
        let event = occurrence.event
        let grams = formattedFoodWeight(FeedRuleMetadata.amountGrams(from: event, fallback: pet.dailyPortionGrams))
        let status = feedPlanStatus(for: occurrence)
        let actionTitle = feedPlanActionTitle(for: occurrence)
        return HStack(spacing: 10) {
            Image(systemName: status.icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(status.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(occurrence.date.formatted(date: .omitted, time: .shortened)) · \(event.foodKind.title(l)) · \(grams)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if let actionTitle {
                Button {
                    completeSelectedPlanOccurrence(occurrence)
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(status.tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var feedPlanHistoryRecordsSection: some View {
        overviewSectionHeader(l.tr(zh: "历史记录", en: "History", de: "Verlauf"))
        let reminders = feedPlanHistoryReminders
        if reminders.isEmpty {
            emptyInlineState(icon: "fork.knife", text: l.tr(zh: "还没有已发生的计划餐", en: "No past planned meals yet", de: "Noch keine vergangenen Planmahlzeiten"), solid: true)
        } else {
            ForEach(reminders, id: \.id) { reminder in
                planReminderHistoryRow(reminder, allowsCatchUp: canCatchUpPlanReminder(reminder))
            }
        }
    }

    private var stockOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                stockOverviewStatusStrip
                stockSnapshotCard(foodKind: .dry, tint: dryFoodTint)
                stockSnapshotCard(foodKind: .wet, tint: wetFoodTint)
                HStack(spacing: 10) {
                    FoodPrimaryButton(title: l.tr(zh: "补粮", en: "Restock", de: "Nachfüllen"), icon: "plus", tint: stockTint) {
                        prepareStockSheet()
                        openFeedSheet(.stock)
                    }
                    Button {
                        prepareStockManageSheet()
                        openFeedSheet(.stockManage)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(stockTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .feedFlatBlockSurface(cornerRadius: 18)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                stockOverviewRestockSection
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }

    private var treatOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                overviewRangePicker(tint: treatTint)
                treatOverviewHero
                treatKindFilterBar

                treatFrequencyPulseChart(
                    title: treatFrequencyTitle,
                    points: filteredTreatChartPoints,
                    tint: treatTint,
                    emptyText: l.tr(zh: "记录零食后会显示频率", en: "Log treats to see frequency", de: "Snack eintragen, dann erscheint die Frequenz")
                )

                let logs = Array(filteredTreatLogsInRange.sorted { $0.date > $1.date }.prefix(4))
                if logs.isEmpty {
                    emptyInlineState(icon: "birthday.cake", text: l.tr(zh: "还没有零食记录", en: "No treat logs yet", de: "Noch keine Snack-Einträge"))
                } else {
                    Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    ForEach(logs) { log in
                        feedLogRow(log, compact: true)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }

    // MARK: - Sheet Pieces

    private func foodKindPicker(selection: Binding<FeedFoodKind>) -> some View {
        foodKindSegmentedControl(selection: selection.wrappedValue) { foodKind in
            guard selection.wrappedValue != foodKind else { return }
            withAnimation(GoMotion.page) {
                selection.wrappedValue = foodKind
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private var feedModeSelector: some View {
        QuickFeedModeSelector(
            localization: l,
            selectedMode: activeFeedingMode,
            onSelect: handleFeedModeChipTap
        )
    }

    private func handleFeedModeChipTap(_ mode: FeedOperatingMode) {
        if activeFeedingMode == mode {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        switch mode {
        case .manual:
            switchToManualFeedMode()
        case .manualReminder:
            if currentFeedRuleEvents(kind: .manualReminder).isEmpty {
                openPlanEditor(.manualReminder)
            } else {
                activateExistingFeedRuleMode(.manualReminder)
            }
        case .autoFeeder:
            if currentFeedRuleEvents(kind: .autoFeeder).isEmpty {
                openPlanEditor(.autoFeeder)
            } else {
                activateExistingFeedRuleMode(.autoFeeder)
            }
        }
    }

    private var mainFoodKindSelector: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                mainFoodKindLabel
                Spacer(minLength: 0)
                mainFoodKindButtons
            }
            VStack(alignment: .leading, spacing: 8) {
                mainFoodKindLabel
                mainFoodKindButtons
            }
        }
        .padding(.vertical, 2)
    }

    private var mainFoodKindLabel: some View {
        Text(l.tr(zh: "当前主粮", en: "Current food", de: "Aktuelles Futter"))
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var mainFoodKindButtons: some View {
        HStack(spacing: 8) {
            ForEach(FeedFoodKind.allCases) { foodKind in
                Button {
                    withAnimation(GoMotion.feedback) {
                        setMainFoodKind(foodKind)
                    }
                } label: {
                    Text(foodKind.title(l))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(pet.mainFoodKind == foodKind ? Color.arkInk : foodKindTint(foodKind))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            pet.mainFoodKind == foodKind ? foodKindTint(foodKind) : Color.ohanaControlFill,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .animation(GoMotion.feedback, value: pet.mainFoodKind)
    }

    private var manualFoodKindSelector: some View {
        foodKindSegmentedControl(selection: manualFoodKindDraft) { foodKind in
            guard manualFoodKindDraft != foodKind else { return }
            withAnimation(GoMotion.page) {
                manualFoodKindDraft = foodKind
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func foodKindSegmentedControl(
        selection: FeedFoodKind,
        setSelection: @escaping (FeedFoodKind) -> Void
    ) -> some View {
        GeometryReader { proxy in
            let spacing = CGFloat(10)
            let options = FeedFoodKind.allCases
            let selectedIndex = options.firstIndex(of: selection) ?? 0
            let segmentWidth = max(0, (proxy.size.width - spacing) / 2)
            let selectedTint = foodKindTint(selection)

            ZStack(alignment: .leading) {
                HStack(spacing: spacing) {
                    ForEach(options) { _ in
                        Capsule()
                            .fill(Color.ohanaControlFill.opacity(0.82))
                            .frame(width: segmentWidth, height: 46)
                    }
                }

                Capsule()
                    .fill(selectedTint)
                    .frame(width: segmentWidth, height: 46)
                    .offset(x: CGFloat(selectedIndex) * (segmentWidth + spacing))
                    .shadow(color: selectedTint.opacity(0.20), radius: 10, y: 5) // ui-v4: allow stable local segmented-control lift
                    .animation(GoMotion.page, value: selection)

                HStack(spacing: spacing) {
                    ForEach(options) { foodKind in
                        Button {
                            setSelection(foodKind)
                        } label: {
                            Text(foodKind.title(l))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(selection == foodKind ? Color.arkInk : foodKindTint(foodKind))
                                .contentTransition(.opacity)
                                .frame(width: segmentWidth, height: 46)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .frame(height: 46)
    }

    private func treatKindPicker(selection: Binding<FeedTreatKind>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(FeedTreatKind.allCases) { treatKind in
                Button {
                    withAnimation(GoMotion.feedback) {
                        selection.wrappedValue = treatKind
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(treatKind.title(l), systemImage: treatKind.systemIconName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(selection.wrappedValue == treatKind ? Color.arkInk : treatTint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == treatKind ? treatTint : treatTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var brandSuggestionChips: some View {
        let brands = PetFoodBrandCatalog.brands(foodKind: selectedStockFoodKind)
        let filtered = stockBrandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? brands
            : brands.filter { $0.localizedCaseInsensitiveContains(stockBrandText) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filtered.prefix(18)), id: \.self) { brand in
                    Button {
                        stockBrandText = brand
                        dismissFeedKeyboard()
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(brand)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(stockTint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(stockTint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func sheetHero(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 42, height: 42)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
        }
    }

    private func feedSheetTopChrome(_ sheet: ActiveFeedSheet) -> some View {
        HStack(spacing: 12) {
            feedSheetChromeTitle(sheet)
            Spacer(minLength: 12)
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                closeActiveFeedSheet()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    private func feedSheetChromeTitle(_ sheet: ActiveFeedSheet) -> some View {
        let chrome = feedSheetChrome(for: sheet)
        return HStack(spacing: 10) {
            Image(systemName: chrome.icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(chrome.tint)
                .frame(width: 30, height: 34)
            Text(chrome.title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    private func feedSheetChrome(for sheet: ActiveFeedSheet) -> (icon: String, title: String, tint: Color) {
        switch sheet {
        case .feedingOverview:
            return (
                feedModeIcon(activeFeedingMode),
                l.tr(zh: "喂食总览", en: "Feeding overview", de: "Futterübersicht"),
                feedingModeTint
            )
        case .feedModeHistory:
            return ("chart.line.uptrend.xyaxis", feedModeHistoryTitle, feedingModeTint)
        case .stockOverview:
            return (
                "shippingbox.fill",
                l.tr(zh: "余粮总览", en: "Stock overview", de: "Vorratsübersicht"),
                stockTint
            )
        case .treatOverview:
            return (
                "birthday.cake.fill",
                l.tr(zh: "零食总览", en: "Treat overview", de: "Snackübersicht"),
                treatTint
            )
        case .history:
            return (
                "clock.arrow.circlepath",
                l.tr(zh: "喂食历史", en: "Feeding history", de: "Fütterungshistorie"),
                Color.goPrimary
            )
        case .stockRecords:
            return (
                "shippingbox.fill",
                l.tr(zh: "余粮记录", en: "Stock records", de: "Vorratseinträge"),
                stockTint
            )
        case .manual:
            return (
                "fork.knife.circle.fill",
                manualFeedSheetTitle,
                mainFoodTint
            )
        case .treat:
            return (
                "birthday.cake.fill",
                l.tr(zh: "记录零食", en: "Log treats", de: "Snack eintragen"),
                treatTint
            )
        case .plan(let kind):
            return (
                kind.iconName,
                kind == .autoFeeder
                    ? l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat")
                    : l.tr(zh: "喂食计划", en: "Feeding plan", de: "Fütterungsplan"),
                kind == .autoFeeder ? Color.goTeal : Color.goPurple
            )
        case .stock:
            return (
                "shippingbox.fill",
                editingFoodRecord == nil
                    ? l.tr(zh: "补粮", en: "Restock", de: "Nachfüllen")
                    : l.tr(zh: "编辑余粮", en: "Edit stock", de: "Vorrat bearbeiten"),
                stockTint
            )
        case .stockManage:
            return (
                "shippingbox.fill",
                l.tr(zh: "余粮管理", en: "Stock manage", de: "Vorrat verwalten"),
                stockTint
            )
        case .manage:
            return ("slider.horizontal.3", l.tr(zh: "管理", en: "Manage", de: "Verwalten"), Color.goPrimary)
        case .editLog:
            return ("pencil", l.tr(zh: "编辑记录", en: "Edit log", de: "Eintrag bearbeiten"), mainFoodTint)
        }
    }

    private func plannedReminderBanner(_ reminder: Reminder) -> some View {
        let grams = reminder.event.map {
            FeedRuleMetadata.amountGrams(from: $0, fallback: pet.dailyPortionGrams)
        } ?? pet.dailyPortionGrams
        let kindTitle = reminder.event?.foodKind.title(l) ?? FeedFoodKind.dry.title(l)
        return compactNotice(
            icon: "bell.badge.fill",
            text: l.tr(
                zh: "计划餐 \(reminder.scheduledAt.formatted(date: .omitted, time: .shortened)) · \(kindTitle) \(formattedFoodWeight(grams))",
                en: "Planned \(reminder.scheduledAt.formatted(date: .omitted, time: .shortened)) · \(kindTitle) \(formattedFoodWeight(grams))",
                de: "Geplant \(reminder.scheduledAt.formatted(date: .omitted, time: .shortened)) · \(kindTitle) \(formattedFoodWeight(grams))"
            ),
            tint: reminder.event.map { foodKindTint($0.foodKind) } ?? mainFoodTint
        )
    }

    private func gramInput(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color,
        quickValues: [Double]
    ) -> some View {
        quickGramInput(title: title, text: text, field: field, tint: tint, quickValues: quickValues)
    }

    private func manualGramInput(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color,
        quickValues: [Double]
    ) -> some View {
        quickGramInput(title: title, text: text, field: field, tint: tint, quickValues: quickValues)
    }

    private func quickGramInput(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color,
        quickValues: [Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 10) {
                gramStepButton(systemName: "minus", tint: tint) {
                    adjustGramText(text, delta: -5)
                }
                Button {
                    openFeedNumberPad(field)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text.wrappedValue.isEmpty ? "50" : text.wrappedValue)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(text.wrappedValue.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
                gramStepButton(systemName: "plus", tint: tint) {
                    adjustGramText(text, delta: 5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .feedFlatBlockSurface(cornerRadius: 18)

            feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
            quickGramChips(values: quickValues, text: text, tint: tint)
        }
    }

    private func gramStepButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            dismissFeedKeyboard()
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(tint, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(.isButton)
    }

    private func planMealGramEditor(index: Int, tint: Color) -> some View {
        let field = FeedInputField.planMealGrams(index)
        let text = planMealGramsTextBinding(index: index)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                gramStepButton(systemName: "minus", tint: tint) {
                    adjustPlanMealGrams(index: index, delta: -5)
                }
                Button {
                    openFeedNumberPad(field)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text.wrappedValue.isEmpty ? "50" : text.wrappedValue)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(text.wrappedValue.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
                gramStepButton(systemName: "plus", tint: tint) {
                    adjustPlanMealGrams(index: index, delta: 5)
                }
            }
            feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
        }
        .padding(10)
        .feedFlatBlockSurface(cornerRadius: 14)
    }

    private func adjustGramText(_ text: Binding<String>, delta: Double) {
        let current = parsePositiveDouble(text.wrappedValue) ?? 0
        let next = max(0, current + delta)
        text.wrappedValue = next > 0 ? String(format: "%.0f", next) : ""
    }

    private func adjustPlanMealGrams(index: Int, delta: Double) {
        guard planMeals.indices.contains(index) else { return }
        planMeals[index].grams = max(0, planMeals[index].grams + delta)
    }

    private var manualDefaultToggle: some View {
        Toggle(isOn: $saveManualAsDefault) {
            Text(l.tr(zh: "保存为默认克数", en: "Save as default", de: "Als Standard speichern"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .tint(mainFoodTint)
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    private func gramInputCompact(
        title: String,
        text: Binding<String>,
        field: FeedInputField,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 5) {
                Button {
                    openFeedNumberPad(field)
                } label: {
                    Text(text.wrappedValue.isEmpty ? "50" : text.wrappedValue)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(text.wrappedValue.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
                Text("g")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 16)
            feedInlineNumberPad(field: field, text: text, tint: tint, maxFractionDigits: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openFeedNumberPad(_ field: FeedInputField) {
        dismissSystemFeedKeyboardIfNeeded()
        stockExpenseAmountKeypadVisible = false
        withAnimation(GoMotion.feedback) {
            focusedField = focusedField == field ? nil : field
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @ViewBuilder
    private func feedInlineNumberPad(
        field: FeedInputField,
        text: Binding<String>,
        tint: Color,
        maxFractionDigits: Int
    ) -> some View {
        if focusedField == field {
            EmbeddedDecimalKeypad(
                text: text,
                countryCode: AppCountry.code,
                maxFractionDigits: maxFractionDigits,
                accent: tint,
                isMini: true
            ) {
                withAnimation(GoMotion.feedback) {
                    focusedField = nil
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
    }

    private func planMealGramsTextBinding(index: Int) -> Binding<String> {
        Binding(
            get: { planMeals.indices.contains(index) ? String(format: "%.0f", planMeals[index].grams) : "" },
            set: { value in
                guard planMeals.indices.contains(index) else { return }
                planMeals[index].grams = parsePositiveDouble(value) ?? 0
            }
        )
    }

    private func quickGramChips(values: [Double], text: Binding<String>, tint: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        dismissFeedKeyboard()
                        text.wrappedValue = String(format: "%.0f", value)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(formattedFoodWeight(value))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func planStepperCard<Control: View>(
        title: String,
        value: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                control()
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactNotice(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 16)
    }

    private func errorText(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.goRed)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 14)
    }

    private func manageRow(icon: String, title: String, value: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42)
                    .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func emptyInlineState(icon: String, text: String, solid: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private func feedLogRow(_ log: PetCareLog, compact: Bool, solidSurface: Bool = false) -> some View {
        let badge = feedLogBadge(for: log)
        let grams = feedLogDisplayGrams(for: log)
        return HStack(spacing: 10) {
            Image(systemName: badge.icon)
                .font(.system(size: compact ? 12 : 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(badge.tint, in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: compact ? 12 : 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(log.date, format: compact ? .dateTime.hour().minute() : .dateTime.month().day().hour().minute())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(grams > 0 ? formattedFoodWeight(grams) : "--")
                .font(.system(size: compact ? 13 : 15, weight: .black, design: .rounded))
                .foregroundStyle(badge.tint)
            if !compact {
                Button {
                    beginEditingFeedLog(log)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(mainFoodTint)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(ScaleButtonStyle())
                Button {
                    feedLogPendingDelete = log
                    showingDeleteFeedLogConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(compact ? 0 : 12)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ohanaCardSurface)
            }
        }
    }

    private func planReminderHistoryRow(_ reminder: Reminder, allowsCatchUp: Bool = false) -> some View {
        let isSatisfied = reminder.isCompleted
        let overdue = !isSatisfied && (reminder.isFailed || (reminder.isPending && reminder.scheduledAt < clockTick))
        let statusTitle: String = {
            if isSatisfied { return l.tr(zh: "打卡成功", en: "Checked in", de: "Erledigt") }
            if overdue { return l.tr(zh: "未打卡", en: "Missed", de: "Verpasst") }
            return l.tr(zh: "待打卡", en: "Pending", de: "Ausstehend")
        }()
        let tint: Color = isSatisfied ? Color.goPrimary : (overdue ? Color.goRed : Color.goYellow)
        let icon = isSatisfied ? "checkmark.seal.fill" : (overdue ? "exclamationmark.triangle.fill" : "clock.fill")
        let event = reminder.event
        let grams = event.map { formattedFoodWeight(FeedRuleMetadata.amountGrams(from: $0, fallback: pet.dailyPortionGrams)) } ?? "--"
        let foodKind = event?.foodKind.title(l) ?? pet.mainFoodKind.title(l)

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened)) · \(foodKind) · \(grams)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if allowsCatchUp && overdue && !isSatisfied && (reminder.isPending || reminder.isFailed) {
                Button {
                    completePlannedFeed(reminder)
                } label: {
                    Text(l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private func foodRecordRow(_ record: PetFoodRecord) -> some View {
        let total = FeedStockCalculator.activeStockTotalGrams(for: pet, record: record, foodKind: record.foodKind)
        return HStack(spacing: 10) {
            Image(systemName: record.foodKind.systemIconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(foodKindTint(record.foodKind), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.brand.isEmpty ? l.tr(zh: "未命名主粮", en: "Food", de: "Futter") : record.brand)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(stockRecordDateSummary(record))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if total > 0 {
                Text(formattedFoodWeight(total))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(foodKindTint(record.foodKind))
            }
            Button {
                prepareStockSheet(record: record)
                openFeedSheet(.stock)
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(stockTint)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(ScaleButtonStyle())
            Button {
                foodRecordPendingDelete = record
                showingDeleteFoodRecordConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private var feedingOverviewAggregateSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 46, height: 46)
                    .background(mainFoodOverviewTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "全部喂食", en: "All feeding", de: "Alle Fütterungen"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "手动、计划、自动都会计入总览。", en: "Manual, plan, and auto logs are all included.", de: "Manuell, Plan und Auto sind enthalten."))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(dashboard.todayMainFoodGrams > 0 ? formattedFoodWeight(dashboard.todayMainFoodGrams) : "--")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(mainFoodOverviewTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
    }

    private var overviewFoodBreakdown: some View {
        HStack(spacing: 8) {
            modeInfoPill(title: FeedFoodKind.dry.title(l), value: dashboard.todayDryFoodGrams > 0 ? formattedFoodWeight(dashboard.todayDryFoodGrams) : "--", tint: dryFoodTint)
            modeInfoPill(title: FeedFoodKind.wet.title(l), value: dashboard.todayWetFoodGrams > 0 ? formattedFoodWeight(dashboard.todayWetFoodGrams) : "--", tint: wetFoodTint)
            modeInfoPill(title: l.tr(zh: "总计", en: "Total", de: "Gesamt"), value: dashboard.todayMainFoodGrams > 0 ? formattedFoodWeight(dashboard.todayMainFoodGrams) : "--", tint: mainFoodOverviewTint)
        }
    }

    private var feedingOverviewSourceBreakdown: some View {
        HStack(spacing: 8) {
            modeInfoPill(
                title: feedModeShortTitle(.manual),
                value: formattedSourceTotal(.manualMain),
                tint: feedModeTint(.manual)
            )
            modeInfoPill(
                title: feedModeShortTitle(.manualReminder),
                value: formattedSourceTotal(.manualReminder),
                tint: feedModeTint(.manualReminder)
            )
            modeInfoPill(
                title: feedModeShortTitle(.autoFeeder),
                value: formattedSourceTotal(.autoMain),
                tint: feedModeTint(.autoFeeder)
            )
        }
    }

    private func overviewRangePicker(tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(FeedOverviewRange.allCases) { range in
                Button {
                    withAnimation(GoMotion.feedback) {
                        overviewRange = range
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(range.title(l))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(overviewRange == range ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(overviewRange == range ? tint : tint.opacity(0.10), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(5)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private func overviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private func overviewLineChart(
        title: String,
        subtitle: String,
        points: [FeedOverviewChartPoint],
        tint: Color,
        emptyText: String,
        showsSurface: Bool = false
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                Text(emptyText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                let yDomain = OhanaChartStyle.yDomain(values: points.map(\.value), includeZero: true)
                OhanaMinimalTrendChart(
                    points: points.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                    yDomain: yDomain,
                    tint: tint,
                    progress: overviewChartProgress
                )
                .frame(height: 136)
                .animation(GoMotion.page, value: overviewChartProgress)
            }
        }
        .padding(showsSurface ? 14 : 0)
        return content
            .background {
                if showsSurface {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.clear)
                }
            }
            .modifier(ConditionalFeedGlassSurface(isEnabled: showsSurface, cornerRadius: 20, tint: tint, tintOpacity: 0.04))
    }

    private func overviewFrequencyBarChart(
        title: String,
        subtitle: String,
        points: [FeedOverviewChartPoint],
        tint: Color,
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                Text(emptyText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 118)
            } else {
                let total = points.reduce(0) { $0 + $1.value }
                let average = total / Double(max(points.count, 1))
                HStack(spacing: 8) {
                    Text(l.tr(
                        zh: "总 \(Int(total)) 次",
                        en: "\(Int(total)) total",
                        de: "\(Int(total)) gesamt"
                    ))
                    Text(l.tr(
                        zh: "均 \(String(format: "%.1f", average))/天",
                        en: "avg \(String(format: "%.1f", average))/day",
                        de: "Ø \(String(format: "%.1f", average))/Tag"
                    ))
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)

                OhanaMinimalBarChart(
                    points: points.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                    tint: tint,
                    progress: overviewChartProgress,
                    showsLabels: overviewRange == .days7,
                    maxBarHeight: 86
                )
                .frame(height: overviewRange == .days7 ? 116 : 96)
                .opacity(0.40 + overviewChartProgress * 0.60)
                .scaleEffect(x: 1, y: 0.96 + overviewChartProgress * 0.04, anchor: .bottom)
                .animation(GoMotion.page, value: overviewChartProgress)
                .animation(GoMotion.page, value: overviewRange)
            }
        }
    }

    private func treatFrequencyPulseChart(
        title: String,
        points: [FeedOverviewChartPoint],
        tint: Color,
        emptyText: String
    ) -> some View {
        let total = Int(points.reduce(0) { $0 + $1.value })
        let activeDays = points.filter { $0.value > 0 }.count
        let maxCount = max(1, Int(points.map(\.value).max() ?? 1))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "按次数看节奏，没填克数也算",
                        en: "Frequency rhythm; no-gram logs count",
                        de: "Rhythmus nach Anzahl; ohne Gramm zählt"
                    ))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                emptyInlineState(icon: "birthday.cake", text: emptyText)
                    .frame(minHeight: 118)
            } else {
                Text(l.tr(
                    zh: "\(total) 次 · \(activeDays) 天有零食 · 峰值 \(maxCount)",
                    en: "\(total)x · \(activeDays) snack days · peak \(maxCount)",
                    de: "\(total)x · \(activeDays) Snacktage · Spitze \(maxCount)"
                ))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .contentTransition(.numericText())

                GeometryReader { proxy in
                    let spacing: CGFloat = overviewRange == .days7 ? 7 : (overviewRange == .days30 ? 4 : 2)
                    let count = max(points.count, 1)
                    let width = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(points) { point in
                            let ratio = CGFloat(point.value / Double(maxCount))
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: max(1, width / 2), style: .continuous)
                                    .fill(point.value > 0 ? tint : Color.ohanaControlFill.opacity(0.70))
                                    .frame(width: width, height: max(point.value > 0 ? 10 : 4, ratio * 84 * overviewChartProgress))
                                    .opacity(point.value > 0 ? 0.95 : 0.42)
                                if overviewRange == .days7 {
                                    Text(point.date, format: .dateTime.weekday(.narrow))
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(Calendar.current.isDateInToday(point.date) ? tint : Color.ohanaTertiaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                            .accessibilityLabel(treatFrequencyAccessibilityText(point))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: overviewRange == .days7 ? 116 : 96)
                .opacity(0.45 + overviewChartProgress * 0.55)
                .animation(GoMotion.page, value: overviewChartProgress)
                .animation(GoMotion.page, value: overviewRange)
                .animation(GoMotion.page, value: selectedTreatOverviewKind?.rawValue ?? "all")
            }
        }
        .padding(.vertical, 2)
    }

    private func treatFrequencyAccessibilityText(_ point: FeedOverviewChartPoint) -> String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        return l.tr(
            zh: "\(date)，\(Int(point.value)) 次零食",
            en: "\(date), \(Int(point.value)) treat logs",
            de: "\(date), \(Int(point.value)) Snack-Einträge"
        )
    }

    private func stockSnapshotCard(foodKind: FeedFoodKind, tint: Color) -> some View {
        let snapshot = dashboard.stock(foodKind: foodKind)
        let progress = snapshot.totalGrams > 0 ? max(0, min(1, snapshot.remainingGrams / snapshot.totalGrams)) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(foodKind.title(l), systemImage: "shippingbox.fill")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                Text(snapshot.totalGrams > 0 ? "\(snapshot.remainingDays) \(l.tr(zh: "天", en: "days", de: "Tage"))" : l.tr(zh: "未添加", en: "Not set", de: "Nicht gesetzt"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(snapshot.totalGrams > 0 && snapshot.remainingDays <= 3 ? Color.goRed : Color.ohanaSecondaryText)
            }
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(snapshot.totalGrams > 0 ? formattedStockWeight(snapshot.remainingGrams) : "--")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Text(snapshot.totalGrams > 0 ? "/ \(formattedStockWeight(snapshot.totalGrams))" : "")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(snapshot.totalGrams > 0 && snapshot.remainingDays <= 3 ? Color.goRed : tint)
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 20)
    }

    private var stockOverviewStatusStrip: some View {
        let dry = dashboard.stock(foodKind: .dry)
        let wet = dashboard.stock(foodKind: .wet)
        let activeCount = [
            FeedStockCalculator.activeStockRecord(for: pet, foodKind: .dry, foodRecords: observedFoodRecords),
            FeedStockCalculator.activeStockRecord(for: pet, foodKind: .wet, foodRecords: observedFoodRecords)
        ].compactMap { $0 }.count
        let pendingCount = stockOverviewRecords.filter { FeedStockCalculator.stockOpenDay(for: $0) > Calendar.current.startOfDay(for: Date()) }.count
        let days = [dry, wet].filter { $0.totalGrams > 0 && $0.remainingDays > 0 }.map(\.remainingDays).min()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(days.map { "\($0)d" } ?? "--")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(stockOverviewStatusTint(dry: dry, wet: wet))
                    .contentTransition(.numericText())
                Text(l.tr(zh: "预计可用", en: "estimated", de: "geschätzt"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(stockOverviewStatusText(dry: dry, wet: wet))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(stockOverviewStatusTint(dry: dry, wet: wet))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stockOverviewStatusTint(dry: dry, wet: wet), in: Capsule())
                    .foregroundStyle(Color.arkInk)
            }

            HStack(spacing: 8) {
                stockOverviewMetric(
                    title: l.tr(zh: "开袋中", en: "Open", de: "Offen"),
                    value: "\(activeCount)",
                    icon: "shippingbox.fill"
                )
                stockOverviewMetric(
                    title: l.tr(zh: "待开袋", en: "Pending", de: "Wartend"),
                    value: "\(pendingCount)",
                    icon: "clock.fill"
                )
                stockOverviewMetric(
                    title: l.tr(zh: "提醒", en: "Alert", de: "Alarm"),
                    value: pet.foodReminderEnabled ? l.tr(zh: "开", en: "On", de: "Ein") : l.tr(zh: "关", en: "Off", de: "Aus"),
                    icon: pet.foodReminderEnabled ? "bell.badge.fill" : "bell.slash.fill"
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func stockOverviewMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(stockTint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var stockOverviewRestockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                overviewSectionHeader(l.tr(zh: "补粮记录", en: "Restocks", de: "Nachfüllungen"))
                Spacer()
                Text("\(stockOverviewRecords.count)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(stockTint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.ohanaControlFill, in: Capsule())
            }

            if stockOverviewRecords.isEmpty {
                emptyInlineState(
                    icon: "shippingbox",
                    text: l.tr(zh: "补粮后会显示每袋粮的购买、开袋和使用状态", en: "Restocks show purchase, open date, and status.", de: "Nachfüllungen zeigen Kauf, Öffnung und Status.")
                )
            } else {
                ForEach(stockOverviewRecords.prefix(6)) { record in
                    stockOverviewRecordCard(record)
                }
            }
        }
    }

    private var stockOverviewRecords: [PetFoodRecord] {
        observedFoodRecords.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate > rhs.startDate }
            return (lhs.purchaseDate ?? lhs.startDate) > (rhs.purchaseDate ?? rhs.startDate)
        }
    }

    private func stockOverviewRecordCard(_ record: PetFoodRecord) -> some View {
        let total = FeedStockCalculator.activeStockTotalGrams(for: pet, record: record, foodKind: record.foodKind)
        let activeRecord = FeedStockCalculator.activeStockRecord(for: pet, foodKind: record.foodKind, foodRecords: observedFoodRecords)
        let isActive = activeRecord?.id == record.id
        let isPending = FeedStockCalculator.stockOpenDay(for: record) > Calendar.current.startOfDay(for: Date())
        let statusTint = isActive ? stockTint : (isPending ? Color.goYellow : Color.ohanaSecondaryText)
        let statusText = isActive
            ? l.tr(zh: "使用中", en: "Active", de: "Aktiv")
            : (isPending ? l.tr(zh: "待开袋", en: "Pending", de: "Wartend") : l.tr(zh: "历史", en: "Past", de: "Verlauf"))

        return Button {
            prepareStockSheet(record: record)
            openFeedSheet(.stock)
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(systemName: record.foodKind.systemIconName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.arkInk)
                    Text(record.foodKind == .dry ? "DRY" : "WET")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.72))
                }
                .frame(width: 44, height: 48)
                .background(foodKindTint(record.foodKind), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(record.brand.isEmpty ? l.tr(zh: "未命名主粮", en: "Food", de: "Futter") : record.brand)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(statusText)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(statusTint, in: Capsule())
                    }
                    Text(stockRecordDateSummary(record))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(total > 0 ? formattedStockWeight(total) : "--")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(foodKindTint(record.foodKind))
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var autoFeederOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: FeedRuleKind.autoFeeder.iconName)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34)
                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(autoFeederStatusText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(autoFeederEvents.count)x")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
            }

            HStack(spacing: 8) {
                modeInfoPill(
                    title: l.tr(zh: "每日", en: "Daily", de: "Täglich"),
                    value: formattedFoodWeight(dashboard.autoDailyTotalGrams),
                    tint: Color.goTeal
                )
                modeInfoPill(
                    title: l.tr(zh: "下次", en: "Next", de: "Nächste"),
                    value: nextAutoFeedDate?.formatted(date: .omitted, time: .shortened) ?? "--",
                    tint: Color.goTeal
                )
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    private func stockRecordDateSummary(_ record: PetFoodRecord) -> String {
        let purchase = (record.purchaseDate ?? record.startDate).formatted(date: .numeric, time: .omitted)
        let open = record.startDate.formatted(date: .numeric, time: .omitted)
        let pending = record.startDate > Date() ? l.tr(zh: "待开袋", en: "Pending", de: "Ausstehend") + " · " : ""
        return pending + l.tr(
            zh: "\(record.foodKind.title(l)) · 买 \(purchase) · 开 \(open)",
            en: "\(record.foodKind.title(l)) · bought \(purchase) · open \(open)",
            de: "\(record.foodKind.title(l)) · gekauft \(purchase) · offen \(open)"
        )
    }

    private func modeInfoPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var overviewStockChart: some View {
        let points = stockTrendPoints
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l.tr(zh: "余量变化", en: "Remaining stock", de: "Restbestand"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(stockTint)
            }
            stockTrendLegend(points: points)
            if points.isEmpty {
                Text(l.tr(zh: "添加补粮记录后会出现趋势", en: "Add a restock to see the trend", de: "Nach einer Nachfüllung erscheint ein Trend"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                let yDomain = OhanaChartStyle.yDomain(values: points.map(\.value), includeZero: true, paddingRatio: 0.10, minimumSpan: 100)
                OhanaMinimalMultiTrendChart(
                    series: FeedFoodKind.allCases.map { foodKind in
                        OhanaMinimalLineSeries(
                            id: foodKind.rawValue,
                            points: points
                                .filter { $0.foodKind == foodKind }
                                .map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                            tint: foodKindTint(foodKind)
                        )
                    },
                    yDomain: yDomain,
                    progress: overviewChartProgress
                )
                .frame(height: 132)
                .opacity(0.35 + overviewChartProgress * 0.65)
                .scaleEffect(x: 1, y: 0.96 + overviewChartProgress * 0.04, anchor: .bottom)
                .animation(GoMotion.page, value: overviewChartProgress)
                .animation(GoMotion.page, value: overviewRange)
            }
        }
        .padding(.vertical, 4)
    }

    private func stockTrendLegend(points: [FeedStockTrendPoint]) -> some View {
        HStack(spacing: 8) {
            ForEach(FeedFoodKind.allCases) { foodKind in
                let kindPoints = points.filter { $0.foodKind == foodKind }
                let latest = kindPoints.last?.value
                HStack(spacing: 6) {
                    Circle()
                        .fill(foodKindTint(foodKind))
                        .frame(width: 7, height: 7)
                    Text(foodKind.title(l))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(latest.map { formattedStockWeight($0) } ?? "--")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(foodKindTint(foodKind))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func latestStockTrendPoints(from points: [FeedStockTrendPoint]) -> [FeedStockTrendPoint] {
        FeedFoodKind.allCases.compactMap { foodKind in
            points.last { $0.foodKind == foodKind }
        }
    }

    private func overviewSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.top, 2)
    }

    private var treatOverviewHero: some View {
        let selectedTitle = selectedTreatOverviewKind?.title(l) ?? l.tr(zh: "全部零食", en: "All treats", de: "Alle Snacks")
        let count = filteredTreatLogsToday.count
        let gramsText = filteredTreatGramsToday > 0 ? formattedFoodWeight(filteredTreatGramsToday) : "--"

        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: selectedTreatOverviewKind?.systemIconName ?? "birthday.cake.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(treatTint)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTitle)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(treatLastSeenText(lastTreatDate(for: selectedTreatOverviewKind)))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(count)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(treatTint)
                    .contentTransition(.numericText())
                Text(l.tr(zh: "今日 · \(gramsText)", en: "Today · \(gramsText)", de: "Heute · \(gramsText)"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.vertical, 2)
    }

    private var treatKindFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                treatFilterChip(
                    title: l.tr(zh: "全部", en: "All", de: "Alle"),
                    icon: "square.grid.2x2.fill",
                    count: treatLogsInRange.count,
                    isSelected: selectedTreatOverviewKind == nil
                ) {
                    selectedTreatOverviewKind = nil
                }

                ForEach(FeedTreatKind.allCases) { kind in
                    let count = treatLogsInRange.filter { ($0.treatKind ?? .other) == kind }.count
                    treatFilterChip(
                        title: kind.title(l),
                        icon: kind.systemIconName,
                        count: count,
                        isSelected: selectedTreatOverviewKind == kind
                    ) {
                        selectedTreatOverviewKind = kind
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func treatFilterChip(
        title: String,
        icon: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isSelected else { return }
            withAnimation(GoMotion.feedback) {
                action()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(isSelected ? Color.arkInk : treatTint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isSelected ? treatTint : treatTint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(count == 0 && !isSelected)
        .opacity(count == 0 && !isSelected ? 0.42 : 1)
    }

    private func lastTreatDate(for kind: FeedTreatKind?) -> Date? {
        let logs = FeedStockCalculator.treatLogs(for: pet, careLogs: observedCareLogs)
        let matchingLogs: [PetCareLog]
        if let kind {
            matchingLogs = logs.filter { ($0.treatKind ?? .other) == kind }
        } else {
            matchingLogs = logs
        }
        return matchingLogs.map(\.date).max()
    }

    private func treatLastSeenText(_ date: Date?) -> String {
        guard let date else {
            return l.tr(zh: "还没喂过", en: "Never logged", de: "Noch nie")
        }

        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) {
            return l.tr(
                zh: "上次 今天 \(time)",
                en: "Last today \(time)",
                de: "Zuletzt heute \(time)"
            )
        }
        if calendar.isDateInYesterday(date) {
            return l.tr(
                zh: "上次 昨天 \(time)",
                en: "Last yesterday \(time)",
                de: "Zuletzt gestern \(time)"
            )
        }

        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        if days > 1 && days < 7 {
            return l.tr(
                zh: "上次 \(days) 天前",
                en: "Last \(days)d ago",
                de: "Zuletzt vor \(days) T."
            )
        }

        let day = date.formatted(.dateTime.month().day())
        return l.tr(
            zh: "上次 \(day)",
            en: "Last \(day)",
            de: "Zuletzt \(day)"
        )
    }

    private func avatarView(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            imageData: pet.avatarImageData,
            fallbackText: pet.avatarEmoji,
            themeColor: themeColor,
            size: size,
            backgroundOpacity: 0.16
        )
    }

    // MARK: - Actions

    private func openManualFeedSheet(settingsOnly: Bool = false) {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }
        prepareManualSheet(settingsOnly: settingsOnly)
        openFeedSheet(.manual)
    }

    private func openTreatFeedSheet() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.treatOverview)
            return
        }
        prepareTreatSheet()
        openFeedSheet(.treat)
    }

    private func openStockOverview() {
        if observedFoodRecords.isEmpty {
            prepareStockSheet()
            openFeedSheet(.stock)
        } else {
            prepareStockManageSheet()
            openFeedSheet(.stockManage)
        }
    }

    private func openFeedingOverview() {
        openRootFeedSheet(.feedingOverview)
    }

    private func openFeedModeHistory() {
        openRootFeedSheet(.feedModeHistory)
    }

    private func handleFeedPrimaryTap() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }
        switch activeFeedingMode {
        case .manual:
            guard pet.dailyPortionGrams > 0 else {
                openManualFeedSheet()
                return
            }
            commitManualFeed(grams: pet.dailyPortionGrams, saveAsDefault: false, foodKind: pet.mainFoodKind)
        case .manualReminder:
            openFeedModeHistory()
        case .autoFeeder:
            openFeedModeHistory()
        }
    }

    private func handleGuidedFeedPrimaryTap() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }

        switch activeFeedingMode {
        case .manual:
            if pet.dailyPortionGrams > 0 {
                handleFeedPrimaryTap()
            } else {
                openManualFeedSheet(settingsOnly: true)
            }
        case .manualReminder:
            if feedHomeController.viewState.primaryActionState == .completeManualPlan {
                completeNextPlannedFeed()
            } else {
                openFeedModeHistory()
            }
        case .autoFeeder:
            materializeAutoFeedLogs()
            reloadFeedSnapshots()
            openFeedModeHistory()
        }
    }

    private func handleFeedSettingsTap() {
        guard !pet.hasPassedAway else {
            openRootFeedSheet(.feedingOverview)
            return
        }
        switch activeFeedingMode {
        case .manual:
            openFeedModeHistory()
        case .manualReminder:
            openPlanEditor(.manualReminder)
        case .autoFeeder:
            openPlanEditor(.autoFeeder)
        }
    }

    private func syncDisplayedFeedMode(animated: Bool = false, force: Bool = false) {
        guard force || feedHomeController.modeTransition == nil else { return }
        let resolvedMode = FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: clockTick)
        feedHomeController.syncDisplayedMode(resolvedMode, pet: pet, animated: animated, force: force)
    }

    private func refreshFeedHomeSnapshot(force: Bool = false) {
        feedHomeController.rebuild(input: feedHomeSnapshotInput, force: force)
    }

    private func bootstrap() {
        feedHomeController.setAuxiliaryReady(false)
        if manualGramsText.isEmpty, let grams = currentPortionAmount {
            manualGramsText = String(format: "%.0f", grams)
        }
        stockBrandText = pet.foodBrand
        stockWeightText = pet.restockWeight > 0 ? String(format: "%.0f", pet.restockWeight * 1000) : ""
        stockHasPurchaseDate = false
        stockPurchaseDate = Date()
        stockHasOpenDate = pet.restockDate != nil
        stockOpenDate = pet.restockDate ?? Date()
        configureStockExpenseFields(for: nil)
        stockReminderEnabled = pet.foodReminderEnabled
        stockReminderAdvanceDays = pet.foodReminderAdvanceDays
        reloadFeedSnapshots()
        syncDisplayedFeedMode()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            feedHomeController.setAuxiliaryReady(true, animated: true)
        }

        if !didScheduleBootstrapMaintenance {
            didScheduleBootstrapMaintenance = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !pet.hasPassedAway else { return }
                materializeAutoFeedLogs()
                ensureUpcomingPlanReminders()
                reloadFeedSnapshots()
            }
        }

        if opensManualSheetOnAppear && !didApplyInitialSheet {
            didApplyInitialSheet = true
            Task { @MainActor in
                prepareManualSheet(settingsOnly: pet.dailyPortionGrams <= 0)
                openFeedSheet(.manual)
            }
        }
    }

    private func prepareManualSheet(settingsOnly: Bool = false) {
        inputError = nil
        manualFeedSheetMode = settingsOnly ? .settingsOnly : .log
        manualFoodKindDraft = pet.mainFoodKind
        selectedSharedFeedPetIds = settingsOnly
            ? Set([pet.id])
            : Set(sameSpeciesFeedPets.map(\.id))
        if let grams = currentPortionAmount ?? (defaultFeedGrams > 0 ? defaultFeedGrams : nil) {
            manualGramsText = String(format: "%.0f", grams)
        } else {
            manualGramsText = "50"
        }
        saveManualAsDefault = !settingsOnly
    }

    private func prepareTreatSheet() {
        inputError = nil
        selectedTreatKind = .lickable
        treatGramsText = ""
    }

    private func prepareStockSheet(foodKind: FeedFoodKind = .dry, record: PetFoodRecord? = nil) {
        inputError = nil
        editingFoodRecord = record
        selectedStockFoodKind = record?.foodKind ?? foodKind
        if let record {
            stockBrandText = record.brand
            stockWeightText = String(format: "%.0f", FeedStockCalculator.activeStockTotalGrams(for: pet, record: record, foodKind: selectedStockFoodKind))
            stockHasPurchaseDate = record.purchaseDate != nil
            stockPurchaseDate = record.purchaseDate ?? Date()
            stockHasOpenDate = true
            stockOpenDate = record.startDate
            configureStockExpenseFields(for: record)
        } else {
            stockBrandText = ""
            stockWeightText = ""
            stockHasPurchaseDate = false
            stockPurchaseDate = Date()
            stockHasOpenDate = false
            stockOpenDate = Date()
            configureStockExpenseFields(for: nil)
        }
        stockReminderEnabled = pet.foodReminderEnabled
        stockReminderAdvanceDays = pet.foodReminderAdvanceDays
    }

    private func prepareStockManageSheet() {
        inputError = nil
        editingFoodRecord = nil
        stockReminderEnabled = pet.foodReminderEnabled
        stockReminderAdvanceDays = pet.foodReminderAdvanceDays
        prepareStockCorrectionText()
    }

    private func prepareStockCorrectionText() {
        guard let record = managedActiveStockRecord else {
            stockCorrectionText = ""
            return
        }
        let snapshot = dashboard.stock(foodKind: record.foodKind)
        stockCorrectionText = snapshot.remainingGrams > 0 ? String(format: "%.0f", snapshot.remainingGrams) : ""
    }

    private func openPlanEditor(_ kind: FeedRuleKind) {
        inputError = nil
        let events = FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents)
        selectedSharedPlanPetIds = Set(sameSpeciesFeedPets.map(\.id))
        if events.isEmpty {
            planCount = 3
            let grams = currentPortionAmount ?? 50
            planTimes = FeedPlanDraft.suggestedTimes(for: planCount)
            planMeals = planTimes.map { FeedPlanMealDraft(time: $0, foodKind: pet.mainFoodKind, grams: grams) }
        } else {
            planCount = min(max(events.count, 1), 6)
            let grams = FeedRuleMetadata.amountGrams(from: events.first!, fallback: currentPortionAmount ?? 50)
            planTimes = FeedPlanDraft.normalizedTimes(events.map(\.startDate), count: planCount)
            planMeals = FeedPlanDraft.normalizedMeals(
                events.map { FeedPlanMealDraft(time: $0.startDate, foodKind: $0.foodKind, grams: FeedRuleMetadata.amountGrams(from: $0, fallback: grams)) },
                count: planCount
            )
        }
        openFeedSheet(.plan(kind))
    }

    private func syncPlanTimesCount(_ count: Int) {
        planTimes = FeedPlanDraft.normalizedTimes(planTimes, count: count)
        planMeals = FeedPlanDraft.normalizedMeals(planMeals, count: count)
    }

    private func commitManualFeed() {
        dismissFeedKeyboard()
        guard let grams = parsePositiveDouble(manualGramsText), grams > 0 else {
            inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        commitManualFeed(grams: grams, saveAsDefault: saveManualAsDefault)
    }

    private func saveManualFeedSettings() {
        dismissFeedKeyboard()
        guard let grams = parsePositiveDouble(manualGramsText), grams > 0 else {
            inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        inputError = nil
        ManualFeedCommand.saveSettings(
            pet: pet,
            foodKind: manualFoodKindDraft,
            grams: grams,
            context: modelContext
        )
        defaultFeedGrams = grams
        reloadFeedSnapshots()
        dismissInlineFeedSheet()
        triggerToast(
            l.tr(zh: "喂食设置已保存", en: "Feeding settings saved", de: "Fütterung gespeichert"),
            tint: mainFoodTint
        )
    }

    private func commitManualFeed(grams: Double, saveAsDefault: Bool, foodKind selectedFoodKind: FeedFoodKind? = nil) {
        inputError = nil
        let foodKind = selectedFoodKind ?? manualFoodKindDraft
        let action = {
            if saveAsDefault {
                defaultFeedGrams = grams
            }
            let result = ManualFeedCommand.recordManual(
                pet: pet,
                targets: selectedFeedTargets,
                grams: grams,
                foodKind: foodKind,
                saveAsDefault: saveAsDefault,
                foodRecords: observedFoodRecords,
                allEvents: allEvents,
                context: modelContext,
                executorId: currentUserId
            )
            triggerFeedCheckInFeedback(foodKind: result.foodKind, grams: result.grams, affectsStock: result.affectsStock)
            let message = result.targetCount > 1
                ? l.tr(zh: "共同喂食 · \(result.targetCount)只", en: "Shared feeding · \(result.targetCount)", de: "Gemeinsam gefüttert · \(result.targetCount)")
                : l.tr(zh: "已记录\(result.foodKind.title(l))", en: "\(result.foodKind.title(l)) saved", de: "\(result.foodKind.title(l)) gespeichert")
            afterFoodLogSaved(message: message, tint: mainFoodTint, stockReminders: result.stockReminders)
        }
        performWithAntiRepeat(action)
    }

    private func completeNextPlannedFeed() {
        dismissFeedKeyboard()
        guard let reminder = dashboard.nextManualReminder else {
            prepareManualSheet()
            openFeedSheet(.manual)
            return
        }
        completePlannedFeed(reminder)
    }

    private func completePlannedFeed(_ reminder: Reminder) {
        let action = {
            let result = ManualFeedCommand.completePlanned(
                pet: pet,
                reminder: reminder,
                foodRecords: observedFoodRecords,
                allEvents: allEvents,
                context: modelContext,
                executorId: currentUserId
            )
            triggerFeedCheckInFeedback(foodKind: result.foodKind, grams: result.grams, affectsStock: result.affectsStock)
            afterFoodLogSaved(
                message: l.tr(zh: "计划餐已完成", en: "Planned meal done", de: "Planmahlzeit erledigt"),
                tint: Color.goPurple,
                stockReminders: result.stockReminders
            )
        }
        performWithAntiRepeat(action)
    }

    private func completeSelectedPlanOccurrence(_ occurrence: FeedPlanCalendarOccurrence) {
        let reminder: Reminder
        if let existingReminder = occurrence.reminder {
            reminder = existingReminder
        } else {
            reminder = FeedMaintenanceCommand.reminder(
                for: occurrence.event,
                scheduledAt: occurrence.date,
                existing: nil,
                context: modelContext
            )
        }
        completePlannedFeed(reminder)
    }

    private func commitTreatFeed() {
        dismissFeedKeyboard()
        let grams = parsePositiveDouble(treatGramsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : treatGramsText)
        guard let grams else {
            inputError = l.tr(zh: "请输入有效克数，或留空。", en: "Enter valid grams or leave it empty.", de: "Gültige Gramm oder leer lassen.")
            return
        }
        let result = TreatFeedCommand.record(
            pet: pet,
            grams: grams,
            treatKind: selectedTreatKind,
            context: modelContext,
            executorId: currentUserId
        )
        showTreatSavedCelebration()
        triggerTreatCheckInFeedback(grams: result.grams)
        afterFoodLogSaved(message: l.tr(zh: "已记录零食", en: "Treat saved", de: "Snack gespeichert"), tint: treatTint)
    }

    private func savePlan(_ kind: FeedRuleKind) {
        dismissFeedKeyboard()
        let normalizedMeals = FeedPlanDraft.normalizedMeals(planMeals, count: planCount)
        guard normalizedMeals.allSatisfy({ $0.grams > 0 }) else {
            inputError = l.tr(zh: "请为每餐填写克数。", en: "Enter grams for every meal.", de: "Gramm für jede Mahlzeit eingeben.")
            return
        }
        let draft = FeedPlanDraft(kind: kind, meals: normalizedMeals)
        let targets = selectedPlanTargets
        let result = SaveFeedPlanCommand.run(
            pet: pet,
            targets: targets,
            kind: kind,
            draft: draft,
            allEvents: targets.count > 1 ? latestAllEvents() : allEvents,
            context: modelContext
        )

        if kind == .manualReminder {
            scheduleReminders(result.planReminders)
        }
        scheduleStockReminders(result.stockReminders)
        reloadFeedSnapshots()
        closeActiveFeedSheet()
        performFeedModeUpdatesWithoutAnimation {
            feedHomeController.setModeImmediately(result.mode, pet: pet)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        triggerToast(
            result.targetCount > 1
                ? (kind == .manualReminder
                   ? l.tr(zh: "共同计划已保存 · \(result.targetCount)只", en: "Shared plan saved · \(result.targetCount)", de: "Gemeinsamer Plan · \(result.targetCount)")
                   : l.tr(zh: "共同自动记录已保存 · \(result.targetCount)只", en: "Shared auto saved · \(result.targetCount)", de: "Gemeinsame Auto-Regel · \(result.targetCount)"))
                : (kind == .manualReminder
                   ? l.tr(zh: "喂食计划已保存", en: "Plan saved", de: "Plan gespeichert")
                   : l.tr(zh: "自动记录已保存", en: "Auto feeder saved", de: "Automat gespeichert")),
            tint: kind == .manualReminder ? Color.goPurple : Color.goTeal
        )
    }

    private func switchToManualFeedMode() {
        guard activeFeedingMode != .manual else {
            closeActiveFeedSheet()
            return
        }
        beginFeedModeVisualTransition(to: .manual) {
            SwitchFeedModeCommand.switchToManual(
                pet: pet,
                allEvents: latestAllEvents(),
                context: modelContext
            )
            reloadFeedSnapshots(forceSnapshot: true)
        }
        closeActiveFeedSheet()
    }

    private func activateExistingFeedRuleMode(_ kind: FeedRuleKind) {
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        guard activeFeedingMode != targetMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        beginFeedModeVisualTransition(to: targetMode) {
            let currentEvents = latestAllEvents()
            let result = SwitchFeedModeCommand.activateExistingRule(
                pet: pet,
                kind: kind,
                allEvents: currentEvents,
                context: modelContext
            )

            switch result {
            case .missingPlan:
                performFeedModeUpdatesWithoutAnimation {
                    feedHomeController.cancelModeTransition()
                }
                syncDisplayedFeedMode(force: true)
                openPlanEditor(kind)
                return
            case .switched(let reminders):
                scheduleReminders(reminders)
            }
            reloadFeedSnapshots(forceSnapshot: true)
        }
        closeActiveFeedSheet()
    }

    private func eventsReplacingFeedRules(kind: FeedRuleKind, with replacement: [Event]) -> [Event] {
        allEvents.filter { event in
            switch kind {
            case .manualReminder:
                return !FeedRuleMetadata.isManualReminderEvent(event, pet: pet)
            case .autoFeeder:
                return !FeedRuleMetadata.isAutoFeederEvent(event, pet: pet)
            }
        } + replacement
    }

    private func setActiveFeedMode(_ mode: FeedOperatingMode) {
        performFeedModeUpdatesWithoutAnimation {
            feedHomeController.setModeImmediately(mode, pet: pet)
            commitFeedModeSideEffects(mode)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func commitFeedModeSideEffects(_ mode: FeedOperatingMode) {
        SetFeedModeCommand.run(mode, pet: pet)
    }

    private func beginFeedModeVisualTransition(
        to targetMode: FeedOperatingMode,
        commitAfterAnimation: @escaping @MainActor () -> Void
    ) {
        let fromMode = activeFeedingMode
        guard fromMode != targetMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        feedModeMaintenanceTask?.cancel()
        guard let transitionID = feedHomeController.beginOptimisticModeTransition(to: targetMode, pet: pet) else { return }

        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(feedModeTransitionAnimation) {
            feedHomeController.updateModeTransition(id: transitionID, progress: 1)
        }

        scheduleFeedModeSideEffectsAfterAnimation(transitionID: transitionID, commit: commitAfterAnimation)
    }

    private var feedModeTransitionAnimation: Animation {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? GoMotion.page : GoMotion.reduced
    }

    private var feedModeTransitionDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 340 : 130
    }

    private func scheduleFeedModeSideEffectsAfterAnimation(
        transitionID: UUID,
        commit: @escaping @MainActor () -> Void
    ) {
        feedModeMaintenanceTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: feedModeTransitionDelayMilliseconds)
            guard !Task.isCancelled,
                  feedHomeController.modeTransition?.id == transitionID else { return }

            performFeedModeUpdatesWithoutAnimation {
                FeedHomePerformance.measure("mode.sideEffects") {
                    commit()
                }
            }

            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled,
                  feedHomeController.modeTransition?.id == transitionID else { return }

            performFeedModeUpdatesWithoutAnimation {
                feedHomeController.finishModeTransition(id: transitionID)
            }
            feedModeMaintenanceTask = nil
        }
    }

    private func performFeedModeUpdatesWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    private func latestAllEvents() -> [Event] {
        var descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        descriptor.fetchLimit = 0
        return (try? modelContext.fetch(descriptor)) ?? allEvents
    }

    private func currentFeedRuleEvents(kind: FeedRuleKind) -> [Event] {
        FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents)
    }

    private func deletePlan(_ kind: FeedRuleKind) {
        let result = DeleteFeedPlanCommand.run(
            pet: pet,
            kind: kind,
            activeMode: activeFeedingMode,
            allEvents: allEvents,
            context: modelContext
        )
        scheduleStockReminders(result.stockReminders)
        if result.shouldSwitchToManual {
            setActiveFeedMode(.manual)
        }
        closeActiveFeedSheet()
        triggerToast(l.tr(zh: "计划已删除", en: "Plan deleted", de: "Plan gelöscht"), tint: Color.goRed)
    }

    private func saveStock() {
        dismissFeedKeyboard()
        guard let totalGrams = parsePositiveDouble(stockWeightText), totalGrams > 0 else {
            inputError = l.tr(zh: "请输入购买重量。", en: "Enter stock weight.", de: "Vorratsgewicht eingeben.")
            return
        }
        let previousExpenseId = editingFoodRecord.flatMap { FeedStockExpenseLink.expenseId(from: $0.notes) }
        let expenseAmountText = stockExpenseAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let expenseAmount = expenseAmountText.isEmpty ? nil : parsePositiveDouble(expenseAmountText)
        if !expenseAmountText.isEmpty, (expenseAmount ?? 0) <= 0 {
            inputError = l.tr(zh: "请输入有效金额，或留空。", en: "Enter a valid amount or leave it blank.", de: "Gültigen Betrag eingeben oder leer lassen.")
            return
        }
        let result = SaveFoodStockCommand.run(
            pet: pet,
            brand: stockBrandText,
            totalGrams: totalGrams,
            purchaseDate: stockHasPurchaseDate ? stockPurchaseDate : nil,
            openDate: stockHasOpenDate ? stockOpenDate : nil,
            dailyGrams: nil,
            foodKind: selectedStockFoodKind,
            reminderEnabled: stockReminderEnabled,
            reminderAdvanceDays: stockReminderAdvanceDays,
            executorId: currentUserId,
            allEvents: allEvents,
            context: modelContext,
            recordToUpdate: editingFoodRecord,
            previousExpenseId: previousExpenseId,
            expenseAmount: expenseAmount,
            expensePayerId: stockExpensePayerId,
            expenseDate: stockHasPurchaseDate ? stockPurchaseDate : Date(),
            expenseNote: stockExpenseNote()
        )
        reloadFeedSnapshots()
        scheduleStockReminders(result.stockReminders)
        editingFoodRecord = nil
        dismissInlineFeedSheet()
        triggerToast(l.tr(zh: "余粮已更新", en: "Stock updated", de: "Vorrat aktualisiert"), tint: stockTint)
    }

    private func configureStockExpenseFields(for record: PetFoodRecord?) {
        stockExpensePayerId = currentUserId
        stockExpenseAmountText = ""
        stockExpenseAmountKeypadVisible = false
        guard let record,
              let expenseId = FeedStockExpenseLink.expenseId(from: record.notes),
              let expense = FeedStockExpenseLink.fetchExpense(id: expenseId, context: modelContext)
        else { return }
        stockExpensePayerId = expense.executorId
        stockExpenseAmountText = String(format: "%.2f", expense.amount)
    }

    private func stockExpenseNote() -> String {
        let cleanBrand = stockBrandText.trimmingCharacters(in: .whitespacesAndNewlines)
        let kindTitle = selectedStockFoodKind.title(l)
        let note = cleanBrand.isEmpty
            ? l.tr(zh: "\(pet.name) \(kindTitle)补粮", en: "\(pet.name) \(kindTitle) restock", de: "\(pet.name) \(kindTitle) Nachfüllung")
            : l.tr(zh: "\(pet.name) \(kindTitle)补粮 · \(cleanBrand)", en: "\(pet.name) \(kindTitle) restock · \(cleanBrand)", de: "\(pet.name) \(kindTitle) Nachfüllung · \(cleanBrand)")
        return note
    }

    private func saveStockReminderSettings() {
        let result = StockReminderSettingsCommand.run(
            pet: pet,
            enabled: stockReminderEnabled,
            advanceDays: stockReminderAdvanceDays,
            allEvents: allEvents,
            context: modelContext
        )
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "余粮提醒已更新", en: "Stock reminder updated", de: "Vorratserinnerung aktualisiert"), tint: stockTint)
    }

    private func correctStock(_ record: PetFoodRecord) {
        dismissFeedKeyboard()
        guard let grams = parsePositiveDouble(stockCorrectionText), grams >= 0 else {
            inputError = l.tr(zh: "请输入有效余量。", en: "Enter valid remaining stock.", de: "Gültigen Restbestand eingeben.")
            return
        }
        let result = CorrectStockCommand.run(
            pet: pet,
            record: record,
            remainingGrams: grams,
            allEvents: allEvents,
            context: modelContext
        )
        reloadFeedSnapshots()
        prepareStockCorrectionText()
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "余量已修正", en: "Stock corrected", de: "Vorrat korrigiert"), tint: stockTint)
    }

    private func beginEditingFeedLog(_ log: PetCareLog) {
        editingFeedLog = log
        editFeedLogDate = log.date
        editFeedLogGrams = String(format: "%.0f", feedLogDisplayGrams(for: log))
        inputError = nil
        openFeedSheet(.editLog)
    }

    private func saveFeedLogEdit() {
        dismissFeedKeyboard()
        guard let log = editingFeedLog else {
            closeActiveFeedSheet()
            return
        }
        guard let grams = parsePositiveDouble(editFeedLogGrams), grams >= 0 else {
            inputError = l.tr(zh: "请输入有效克数。", en: "Enter valid grams.", de: "Bitte gültige Gramm eingeben.")
            return
        }
        let result = FeedRecordCommand.updateLog(
            log,
            grams: grams,
            date: editFeedLogDate,
            pet: pet,
            allEvents: allEvents,
            context: modelContext
        )
        reloadFeedSnapshots()
        scheduleStockReminders(result.stockReminders)
        closeActiveFeedSheet()
        triggerToast(l.tr(zh: "记录已更新", en: "Log updated", de: "Eintrag aktualisiert"), tint: mainFoodTint)
    }

    private func deleteFeedLog(_ log: PetCareLog) {
        if editingFeedLog?.id == log.id { editingFeedLog = nil }
        let result = FeedRecordCommand.deleteLog(
            log,
            pet: pet,
            allEvents: allEvents,
            context: modelContext
        )
        reloadFeedSnapshots()
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "记录已删除", en: "Log deleted", de: "Eintrag gelöscht"), tint: Color.goRed)
    }

    private func deleteFoodRecord(_ record: PetFoodRecord) {
        if editingFoodRecord?.id == record.id { editingFoodRecord = nil }
        let result = FeedRecordCommand.deleteFoodRecord(
            record,
            pet: pet,
            allEvents: allEvents,
            context: modelContext
        )
        reloadFeedSnapshots()
        prepareStockCorrectionText()
        scheduleStockReminders(result.stockReminders)
        triggerToast(l.tr(zh: "补粮记录已删除", en: "Stock record deleted", de: "Vorratseintrag gelöscht"), tint: Color.goRed)
    }

    private func afterFoodLogSaved(message: String, tint: Color, stockReminders: [Reminder] = []) {
        reloadFeedSnapshots()
        scheduleStockReminders(stockReminders)
        closeActiveFeedSheet()
        triggerToast(message, tint: tint)
        checkDailyTargetToast()
    }

    private func triggerFeedCheckInFeedback(foodKind: FeedFoodKind, grams: Double, affectsStock: Bool) {
        let tint = foodKindTint(foodKind)
        feedFeedbackMetricId = foodKind.title(l)
        feedFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: "+\(formattedFoodCardWeight(grams))", tint: tint)
        if affectsStock {
            stockFeedbackKind = foodKind
            stockFeedbackToken = CheckInFeedbackToken(kind: .loss, deltaText: "-\(formattedFoodCardWeight(grams))", tint: tint)
        }
        scheduleFeedbackClear()
    }

    private func triggerTreatCheckInFeedback(grams: Double) {
        let delta = grams > 0 ? "+\(formattedFoodWeight(grams))" : "+1"
        treatFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: delta, tint: treatTint)
        scheduleFeedbackClear()
    }

    private func scheduleFeedbackClear() {
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                feedFeedbackToken = nil
                feedFeedbackMetricId = nil
                stockFeedbackToken = nil
                stockFeedbackKind = nil
                treatFeedbackToken = nil
            }
        }
    }

    private func performWithAntiRepeat(_ action: @escaping () -> Void) {
        if let warning = AntiRepeatCareManager.checkRecentCareLog(for: pet, type: .feeding, thresholdMinutes: 120, currentUserId: currentUserId, in: allHumans) {
            antiRepeatTitle = l.tr(zh: "重复喂食提醒", en: "Recent feeding", de: "Kürzlich gefüttert")
            antiRepeatMessage = l.tr(
                zh: "\(warning.executorName) 在 \(warning.minutesAgo) 分钟前刚喂过 \(pet.name)。",
                en: "\(warning.executorName) fed \(pet.name) \(warning.minutesAgo) minutes ago.",
                de: "\(warning.executorName) hat \(pet.name) vor \(warning.minutesAgo) Minuten gefüttert."
            )
            pendingRepeatAction = action
            showingAntiRepeatAlert = true
        } else {
            action()
        }
    }

    private func materializeAutoFeedLogs() {
        let currentEvents = latestAllEvents()
        let result = FeedMaintenanceCommand.materializeDueAutoLogs(
            pet: pet,
            allEvents: currentEvents,
            context: modelContext
        )
        if result.insertedCount > 0 {
            reloadFeedSnapshots()
            scheduleStockReminders(result.stockReminders)
        }
    }

    private func reloadFeedSnapshots(forceSnapshot: Bool = false) {
        if let visibleSheet = activeInlineSheet ?? activeSheet {
            if visibleSheet.needsFullCareLogs, hasLoadedFullCareLogs {
                loadFullCareLogs(force: true)
            }
            if visibleSheet.needsFullFoodRecords, hasLoadedFullFoodRecords {
                loadFullFoodRecords(force: true)
            }
        }
        refreshFeedHomeSnapshot(force: forceSnapshot)
    }

    private func ensureUpcomingPlanReminders() {
        let currentEvents = latestAllEvents()
        let reminders = FeedMaintenanceCommand.ensureUpcomingPlanReminders(
            pet: pet,
            allEvents: currentEvents,
            context: modelContext
        )
        scheduleReminders(reminders)
    }

    private func scheduleReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            guard await NotificationManager.shared.requestPermission() else { return }
            await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: modelContext, source: .detail)
        }
    }

    private func scheduleStockReminder(_ reminder: Reminder?) {
        guard let reminder else { return }
        Task { @MainActor in
            await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: modelContext, source: .detail)
        }
    }

    private func scheduleStockReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: modelContext, source: .detail)
        }
    }

    private func checkDailyTargetToast() {
        guard pet.dailyPortionGrams > 0 else { return }
        let total = dashboard.todayMainFoodGrams
        if total > pet.dailyPortionGrams * 1.1 {
            triggerToast(l.tr(zh: "今日主粮偏多", en: "Main food is high today", de: "Heute viel Hauptfutter"), tint: Color.goYellow)
        }
    }

    private func triggerToast(_ message: String, tint: Color) {
        toastTask?.cancel()
        toastMessage = message
        toastTint = tint
        withAnimation(GoMotion.feedback) {
            showToast = true
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                withAnimation(GoMotion.feedback) {
                    showToast = false
                }
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func showTreatSavedCelebration() {
        withAnimation(GoMotion.fab) {
            showTreatCelebration = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_650_000_000)
            await MainActor.run {
                withAnimation(GoMotion.quick) {
                    showTreatCelebration = false
                }
            }
        }
    }

    private func dismissFeedKeyboard() {
        dismissSystemFeedKeyboardIfNeeded()
        focusedField = nil
        stockExpenseAmountKeypadVisible = false
    }

    private func dismissSystemFeedKeyboardIfNeeded() {
        guard focusedField == .stockBrand else { return }
        GoKeyboard.dismiss()
    }

    private var isInlineInputActive: Bool {
        focusedField != nil || stockExpenseAmountKeypadVisible
    }

    // MARK: - Helpers

    private var feedingOverviewModeValue: String {
        switch activeFeedingMode {
        case .manual:
            return pet.dailyPortionGrams > 0 ? formattedFoodWeight(pet.dailyPortionGrams) : "--"
        case .manualReminder:
            return dashboard.todayManualPlanCompletionText
        case .autoFeeder:
            return "\(dashboard.todayAutoFeedCount)x"
        }
    }

    private var feedingOverviewModeSubtitle: String {
        switch activeFeedingMode {
        case .manual:
            if pet.dailyPortionGrams > 0 {
                return l.tr(zh: "默认 \(formattedFoodWeight(pet.dailyPortionGrams)) · 当前 \(pet.mainFoodKind.title(l))", en: "Default \(formattedFoodWeight(pet.dailyPortionGrams)) · \(pet.mainFoodKind.title(l))", de: "Standard \(formattedFoodWeight(pet.dailyPortionGrams))")
            }
            return l.tr(zh: "还没有默认克数，设置后即可一键打卡。", en: "Set a default amount for one-tap logging.", de: "Standardmenge festlegen.")
        case .manualReminder:
            return nextFeedDetailText(events: feedScheduleEvents, fallback: l.tr(zh: "今日计划 \(dashboard.todayManualPlanCompletionText) 已完成", en: "Today \(dashboard.todayManualPlanCompletionText) complete", de: "Heute \(dashboard.todayManualPlanCompletionText)"))
        case .autoFeeder:
            return nextFeedDetailText(events: autoFeederEvents, fallback: autoFeederStatusText)
        }
    }

    private var overviewChartSubtitle: String {
        l.tr(
            zh: "聚合手动、计划和自动记录。",
            en: "Manual, plan, and auto logs combined.",
            de: "Manuelle, Plan- und Auto-Einträge kombiniert."
        )
    }

    private var feedingModeTint: Color {
        feedModeTint(activeFeedingMode)
    }

    private var mainFoodOverviewTint: Color {
        Color.goPrimary
    }

    private func formattedSourceTotal(_ source: FeedLogSource) -> String {
        let total = sourceTotal(source)
        return total > 0 ? formattedFoodWeight(total) : "--"
    }

    private func sourceTotal(_ source: FeedLogSource) -> Double {
        mainFoodLogsInRange
            .filter { FeedLogMetadata.source(for: $0) == source }
            .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
    }

    private func feedModeTint(_ mode: FeedOperatingMode) -> Color {
        mode.feedTint
    }

    private func feedModeIcon(_ mode: FeedOperatingMode) -> String {
        mode.feedIconName
    }

    private func feedModeShortTitle(_ mode: FeedOperatingMode) -> String {
        mode.feedShortTitle(l)
    }

    private var feedModeHistoryTitle: String {
        switch activeFeedingMode {
        case .manual:
            return l.tr(zh: "手动历史", en: "Manual history", de: "Manueller Verlauf")
        case .manualReminder:
            return l.tr(zh: "计划日历", en: "Plan calendar", de: "Plankalender")
        case .autoFeeder:
            return l.tr(zh: "自动日历", en: "Auto calendar", de: "Auto-Kalender")
        }
    }

    private var feedModeHistoryChartSubtitle: String {
        switch activeFeedingMode {
        case .manual:
            return l.tr(zh: "只显示手动主粮记录。", en: "Manual main-food logs only.", de: "Nur manuelle Hauptfutter-Einträge.")
        case .manualReminder:
            return l.tr(zh: "只显示喂食计划完成记录。", en: "Completed plan check-ins only.", de: "Nur erledigte Plan-Check-ins.")
        case .autoFeeder:
            return l.tr(zh: "只显示自动猫粮机补记。", en: "Auto feeder logs only.", de: "Nur Futterautomat-Einträge.")
        }
    }

    private var autoFeederStatusText: String {
        let daily = formattedFoodWeight(dashboard.autoDailyTotalGrams)
        if let latest = latestAutoFeedLog {
            return l.tr(
                zh: "\(daily)/天 · 上次 \(latest.date.formatted(date: .omitted, time: .shortened))",
                en: "\(daily)/day · last \(latest.date.formatted(date: .omitted, time: .shortened))",
                de: "\(daily)/Tag · zuletzt \(latest.date.formatted(date: .omitted, time: .shortened))"
            )
        }
        if let next = nextAutoFeedDate {
            return l.tr(
                zh: "\(daily)/天 · 下次 \(next.formatted(date: .omitted, time: .shortened))",
                en: "\(daily)/day · next \(next.formatted(date: .omitted, time: .shortened))",
                de: "\(daily)/Tag · nächste \(next.formatted(date: .omitted, time: .shortened))"
            )
        }
        return l.tr(zh: "\(daily)/天 · 自动补记", en: "\(daily)/day · auto logging", de: "\(daily)/Tag · Auto")
    }

    private var latestAutoFeedLog: PetCareLog? {
        observedCareLogs
            .filter { FeedLogMetadata.source(for: $0) == .autoMain }
            .max { $0.date < $1.date }
    }

    private var nextAutoFeedDate: Date? {
        autoFeederEvents
            .compactMap { nextOccurrence(for: $0) }
            .min()
    }

    private func nextOccurrence(for event: Event, after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        if event.startDate > now { return event.startDate }
        let time = calendar.dateComponents([.hour, .minute, .second], from: event.startDate)
        var day = calendar.dateComponents([.year, .month, .day], from: now)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second
        guard var candidate = calendar.date(from: day) else { return nil }
        let intervalDays = max(event.recurrenceDays, 1)
        while candidate <= now {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: candidate) else { return nil }
            candidate = next
        }
        if let end = event.recurrenceEndDate, candidate > end { return nil }
        return candidate
    }

    private func nextFeedDetailText(events: [Event], fallback: String) -> String {
        guard let next = events
            .compactMap({ event -> (Event, Date)? in
                guard let date = nextOccurrence(for: event) else { return nil }
                return (event, date)
            })
            .min(by: { $0.1 < $1.1 })
        else {
            return fallback
        }
        let time = next.1.formatted(date: .omitted, time: .shortened)
        let grams = formattedFoodWeight(FeedRuleMetadata.amountGrams(from: next.0, fallback: pet.dailyPortionGrams))
        let kind = next.0.foodKind.title(l)
        return l.tr(
            zh: "下次 \(time) · \(kind) · \(grams)",
            en: "Next \(time) · \(kind) · \(grams)",
            de: "Nächste \(time) · \(kind) · \(grams)"
        )
    }

    private var stockTint: Color {
        Color.goPrimary
    }

    private func stockStatusTint(_ snapshot: FeedStockSnapshot) -> Color {
        guard snapshot.totalGrams > 0 else { return Color.ohanaSecondaryText }
        if snapshot.remainingGrams <= 0 || snapshot.remainingDays <= 3 { return Color.goRed }
        if snapshot.remainingDays <= 7 { return Color.goYellow }
        return stockTint
    }

    private func stockOverviewStatusTint(dry: FeedStockSnapshot, wet: FeedStockSnapshot) -> Color {
        let snapshots = [dry, wet].filter { $0.totalGrams > 0 }
        guard !snapshots.isEmpty else { return Color.ohanaSecondaryText }
        if snapshots.contains(where: { $0.remainingGrams <= 0 || $0.remainingDays <= 3 }) { return Color.goRed }
        if snapshots.contains(where: { $0.remainingDays <= 7 }) { return Color.goYellow }
        return stockTint
    }

    private func stockOverviewStatusText(dry: FeedStockSnapshot, wet: FeedStockSnapshot) -> String {
        let snapshots = [dry, wet].filter { $0.totalGrams > 0 }
        guard !snapshots.isEmpty else {
            return l.tr(zh: "未建立", en: "Empty", de: "Leer")
        }
        if snapshots.contains(where: { $0.remainingGrams <= 0 }) {
            return l.tr(zh: "已断粮", en: "Out", de: "Leer")
        }
        if snapshots.contains(where: { $0.remainingDays > 0 && $0.remainingDays <= 3 }) {
            return l.tr(zh: "快补粮", en: "Refill", de: "Nachfüllen")
        }
        if snapshots.contains(where: { $0.remainingDays > 0 && $0.remainingDays <= 7 }) {
            return l.tr(zh: "关注", en: "Watch", de: "Achten")
        }
        return l.tr(zh: "稳定", en: "Good", de: "Gut")
    }

    private var mainFoodTint: Color {
        foodKindTint(pet.mainFoodKind)
    }

    private var overviewStartDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(overviewRange.days - 1), to: today) ?? today
    }

    private var overviewDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<overviewRange.days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var mainFoodLogsInRange: [PetCareLog] {
        FeedStockCalculator.mainFoodLogs(for: pet, since: overviewStartDate, careLogs: observedCareLogs)
    }

    private var feedModeLogsInRange: [PetCareLog] {
        mainFoodLogsInRange.filter { log in
            switch activeFeedingMode {
            case .manual:
                return FeedLogMetadata.source(for: log) == .manualMain
            case .manualReminder:
                return FeedLogMetadata.source(for: log) == .manualReminder
            case .autoFeeder:
                return FeedLogMetadata.source(for: log) == .autoMain
            }
        }
    }

    private var feedModePlanRemindersInRange: [Reminder] {
        feedScheduleEvents
            .flatMap(\.reminders)
            .filter { $0.scheduledAt >= overviewStartDate && $0.scheduledAt <= clockTick }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private var feedPlanAllReminders: [Reminder] {
        feedScheduleEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var feedPlanHistoryReminders: [Reminder] {
        feedPlanAllReminders
            .filter { $0.scheduledAt < clockTick }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private var feedPlanSelectedDateOccurrences: [FeedPlanCalendarOccurrence] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: feedPlanCalendarSelectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return feedPlanOccurrences(from: start, through: end)
            .filter { calendar.isDate($0.date, inSameDayAs: feedPlanCalendarSelectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var feedPlanSelectedDateSectionTitle: String {
        let calendar = Calendar.current
        let prefix = activeFeedingMode == .autoFeeder
            ? l.tr(zh: "自动", en: "Auto", de: "Auto")
            : l.tr(zh: "计划", en: "Plan", de: "Plan")
        if calendar.isDateInToday(feedPlanCalendarSelectedDate) {
            return "\(prefix) · \(l.tr(zh: "今天", en: "Today", de: "Heute"))"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(feedPlanCalendarSelectedDate, inSameDayAs: tomorrow) {
            return "\(prefix) · \(l.tr(zh: "明天", en: "Tomorrow", de: "Morgen"))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(feedPlanCalendarSelectedDate, inSameDayAs: yesterday) {
            return "\(prefix) · \(l.tr(zh: "昨天", en: "Yesterday", de: "Gestern"))"
        }
        return "\(prefix) · \(feedPlanCalendarSelectedDate.formatted(.dateTime.month().day()))"
    }

    private var feedPlanCalendarMonthTitle: String {
        feedPlanCalendarMonth.formatted(.dateTime.year().month(.wide))
    }

    private var feedPlanCalendarMonthKey: String {
        let components = Calendar.current.dateComponents([.year, .month], from: feedPlanCalendarMonth)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private var feedPlanWeekdayTitles: [String] {
        if appLanguage == "zh" {
            return ["一", "二", "三", "四", "五", "六", "日"]
        }
        if appLanguage == "de" {
            return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        }
        return ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var feedPlanCalendarDaySummaries: [FeedPlanCalendarDaySummary] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: feedPlanCalendarMonth) else { return [] }
        let monthStart = monthInterval.start
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayFirstLeadingDays = (weekday + 5) % 7
        let monthEnd = calendar.date(byAdding: .second, value: -1, to: monthInterval.end) ?? monthInterval.end
        let occurrences = feedPlanOccurrences(from: monthStart, through: monthEnd)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let leadingPlaceholders: [FeedPlanCalendarDaySummary] = (0..<mondayFirstLeadingDays).compactMap { offset in
            let day = calendar.date(byAdding: .day, value: offset - mondayFirstLeadingDays, to: monthStart) ?? monthStart
            return FeedPlanCalendarDaySummary(
                date: day,
                dayNumber: 0,
                isInDisplayedMonth: false,
                isToday: false,
                markers: []
            )
        }

        let currentMonthDays: [FeedPlanCalendarDaySummary] = dayRange.compactMap { dayNumber in
            guard let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) else { return nil }
            let dayOccurrences = occurrences.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let markers = dayOccurrences.map { occurrence in
                FeedPlanCalendarMarker(status: feedPlanCalendarMarkerStatus(for: occurrence))
            }
            return FeedPlanCalendarDaySummary(
                date: day,
                dayNumber: dayNumber,
                isInDisplayedMonth: true,
                isToday: calendar.isDateInToday(day),
                markers: markers
            )
        }

        return leadingPlaceholders + currentMonthDays
    }

    private func feedPlanStatus(for occurrence: FeedPlanCalendarOccurrence) -> (title: String, tint: Color, icon: String) {
        let isToday = Calendar.current.isDateInToday(occurrence.date)
        if activeFeedingMode == .autoFeeder {
            if occurrence.isCompleted {
                return (l.tr(zh: "自动记录", en: "Auto logged", de: "Automatisch erfasst"), Color.goTeal, FeedRuleKind.autoFeeder.iconName)
            }
            if occurrence.date < clockTick {
                return (l.tr(zh: "未自动记录", en: "Not logged", de: "Nicht erfasst"), Color.goRed, "exclamationmark.triangle.fill")
            }
            if !isToday {
                return (l.tr(zh: "自动计划", en: "Auto planned", de: "Auto geplant"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
            }
            return (l.tr(zh: "待自动", en: "Pending auto", de: "Ausstehend"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
        }
        if occurrence.isCompleted {
            return (l.tr(zh: "打卡成功", en: "Checked in", de: "Erledigt"), Color.goPrimary, "checkmark.seal.fill")
        }
        if occurrence.date < clockTick {
            return (l.tr(zh: "未打卡", en: "Missed", de: "Verpasst"), Color.goRed, "exclamationmark.triangle.fill")
        }
        if !isToday {
            return (l.tr(zh: "计划中", en: "Planned", de: "Geplant"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
        }
        return (l.tr(zh: "待打卡", en: "Pending", de: "Ausstehend"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
    }

    private func feedPlanActionTitle(for occurrence: FeedPlanCalendarOccurrence) -> String? {
        guard activeFeedingMode == .manualReminder else { return nil }
        let calendar = Calendar.current
        guard calendar.isDateInToday(feedPlanCalendarSelectedDate), !occurrence.isCompleted else { return nil }
        if occurrence.date < clockTick {
            return l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen")
        }
        return l.tr(zh: "提前打卡", en: "Check in early", de: "Früher abhaken")
    }

    private func feedPlanCalendarMarkerStatus(for occurrence: FeedPlanCalendarOccurrence) -> FeedPlanCalendarMarker.Status {
        if occurrence.isCompleted { return .completed }
        if occurrence.date < clockTick { return .missed }
        if !Calendar.current.isDateInToday(occurrence.date) { return .planned }
        return .pending
    }

    private func feedPlanOccurrences(from start: Date, through end: Date) -> [FeedPlanCalendarOccurrence] {
        let reminders = feedPlanAllReminders
        return feedModeCalendarEvents.flatMap { event in
            feedPlanOccurrenceDates(for: event, from: start, through: end).map { date in
                let reminder = activeFeedingMode == .manualReminder
                    ? reminders.first { reminder in
                        reminder.event?.id == event.id && abs(reminder.scheduledAt.timeIntervalSince(date)) < 60
                    }
                    : nil
                let autoLog = activeFeedingMode == .autoFeeder ? autoFeedLog(for: event, scheduledAt: date) : nil
                return FeedPlanCalendarOccurrence(date: date, event: event, reminder: reminder, autoLog: autoLog)
            }
        }
    }

    private var feedModeCalendarEvents: [Event] {
        switch activeFeedingMode {
        case .manual:
            return []
        case .manualReminder:
            return feedScheduleEvents
        case .autoFeeder:
            return autoFeederEvents
        }
    }

    private func autoFeedLog(for event: Event, scheduledAt: Date) -> PetCareLog? {
        let key = FeedLogMetadata.autoDedupKey(eventId: event.id, scheduledAt: scheduledAt)
        return observedCareLogs.first { log in
            FeedLogMetadata.autoDedupKey(from: log.note) == key
        }
    }

    private func feedPlanOccurrenceDates(for event: Event, from start: Date, through end: Date) -> [Date] {
        let calendar = Calendar.current
        let intervalDays = max(event.recurrenceDays, 1)
        let limitedEnd = min(event.recurrenceEndDate ?? end, end)
        guard event.startDate <= limitedEnd else { return [] }

        var cursor = event.startDate
        if cursor < start {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: event.startDate),
                to: calendar.startOfDay(for: start)
            ).day ?? 0
            let steps = max(0, days / intervalDays)
            cursor = calendar.date(byAdding: .day, value: steps * intervalDays, to: event.startDate) ?? event.startDate
            while cursor < start {
                guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
                cursor = next
            }
        }

        var dates: [Date] = []
        var guardCount = 0
        while cursor <= limitedEnd && guardCount < 500 {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return dates
    }

    private func canCatchUpPlanReminder(_ reminder: Reminder) -> Bool {
        guard !reminder.isCompleted, reminder.scheduledAt < clockTick else { return false }
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: clockTick) ?? clockTick.addingTimeInterval(-24 * 60 * 60)
        return reminder.scheduledAt >= cutoff && (reminder.isPending || reminder.isFailed)
    }

    private func friendlyPlanDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) {
            return "\(l.tr(zh: "今天", en: "Today", de: "Heute")) \(time)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "\(l.tr(zh: "明天", en: "Tomorrow", de: "Morgen")) \(time)"
        }
        if let afterTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(date, inSameDayAs: afterTomorrow) {
            return "\(l.tr(zh: "后天", en: "In 2 days", de: "Übermorgen")) \(time)"
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    private var treatLogsInRange: [PetCareLog] {
        FeedStockCalculator.treatLogs(for: pet, since: overviewStartDate, careLogs: observedCareLogs)
    }

    private var filteredTreatLogsInRange: [PetCareLog] {
        guard let selectedTreatOverviewKind else { return treatLogsInRange }
        return treatLogsInRange.filter { ($0.treatKind ?? .other) == selectedTreatOverviewKind }
    }

    private var treatLogsToday: [PetCareLog] {
        treatLogsInRange.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var filteredTreatLogsToday: [PetCareLog] {
        filteredTreatLogsInRange.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var filteredTreatGramsToday: Double {
        filteredTreatLogsToday.reduce(0) { $0 + max(0, $1.amountGrams) }
    }

    private var mainFoodChartPoints: [FeedOverviewChartPoint] {
        let calendar = Calendar.current
        let logs = mainFoodLogsInRange
        let totalsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { logs in
                logs.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
            }
        return overviewDates.map { day in
            FeedOverviewChartPoint(date: day, value: totalsByDay[calendar.startOfDay(for: day)] ?? 0)
        }
    }

    private var feedModeChartPoints: [FeedOverviewChartPoint] {
        let calendar = Calendar.current
        let logs = feedModeLogsInRange
        let totalsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { logs in
                logs.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
            }
        return overviewDates.map { day in
            FeedOverviewChartPoint(date: day, value: totalsByDay[calendar.startOfDay(for: day)] ?? 0)
        }
    }

    private var treatChartPoints: [FeedOverviewChartPoint] {
        let calendar = Calendar.current
        let countsByDay = Dictionary(grouping: treatLogsInRange) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.count }
        return overviewDates.map { day in
            FeedOverviewChartPoint(date: day, value: Double(countsByDay[calendar.startOfDay(for: day)] ?? 0))
        }
    }

    private var filteredTreatChartPoints: [FeedOverviewChartPoint] {
        let calendar = Calendar.current
        let countsByDay = Dictionary(grouping: filteredTreatLogsInRange) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.count }
        return overviewDates.map { day in
            FeedOverviewChartPoint(date: day, value: Double(countsByDay[calendar.startOfDay(for: day)] ?? 0))
        }
    }

    private var treatFrequencyTitle: String {
        if let selectedTreatOverviewKind {
            return l.tr(
                zh: "\(selectedTreatOverviewKind.title(l))频率",
                en: "\(selectedTreatOverviewKind.title(l)) frequency",
                de: "\(selectedTreatOverviewKind.title(l))-Frequenz"
            )
        }
        return l.tr(zh: "零食频率", en: "Treat frequency", de: "Snackfrequenz")
    }

    private var stockTrendPoints: [FeedStockTrendPoint] {
        FeedFoodKind.allCases.flatMap { stockTrendPoints(for: $0) }
    }

    private var currentPortionAmount: Double? {
        if pet.dailyPortionGrams > 0 { return pet.dailyPortionGrams }
        return nil
    }

    private func stockTrendPoints(for foodKind: FeedFoodKind) -> [FeedStockTrendPoint] {
        let calendar = Calendar.current
        let record = FeedStockCalculator.activeStockRecord(for: pet, foodKind: foodKind, foodRecords: observedFoodRecords)
        let hasModernRecord = observedFoodRecords.contains { foodRecord in
            foodRecord.pet?.id == pet.id && foodRecord.foodKind == foodKind
        }
        let total = record == nil && hasModernRecord
            ? 0
            : FeedStockCalculator.activeStockTotalGrams(for: pet, record: record, foodKind: foodKind)
        guard total > 0 else { return [] }

        let openDay = record.map { FeedStockCalculator.stockOpenDay(for: $0, calendar: calendar) }
            ?? (foodKind == .dry ? pet.restockDate.map { calendar.startOfDay(for: $0) } : nil)
            ?? overviewStartDate
        let logs = FeedStockCalculator.mainFoodLogs(for: pet, foodKind: foodKind, since: openDay, careLogs: observedCareLogs)
        return overviewDates.compactMap { day in
            guard day >= openDay else { return nil }
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            if let correctionGrams = record?.remainingCorrectionGrams,
               let correctionDate = record?.remainingCorrectionDate,
               end > correctionDate {
                let consumedAfterCorrection = logs
                    .filter { $0.date >= correctionDate && $0.date < end }
                    .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
                return FeedStockTrendPoint(date: day, value: max(0, correctionGrams - consumedAfterCorrection), foodKind: foodKind)
            } else {
                let consumed = logs
                    .filter { $0.date < end }
                    .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
                return FeedStockTrendPoint(date: day, value: max(0, total - consumed), foodKind: foodKind)
            }
        }
    }

    private func formattedStockAxisWeight(_ grams: Double) -> String {
        let value = max(0, grams)
        if value >= 10_000 {
            return "\(Int((value / 1_000).rounded()))kg"
        }
        if value >= 1_000 {
            return String(format: "%.1fkg", value / 1_000)
        }
        return "\(Int(value.rounded()))g"
    }

    private var quickMainGramOptions: [Double] {
        var values: [Double] = []
        func append(_ value: Double) {
            let rounded = value.rounded()
            guard rounded > 0, !values.contains(where: { Int($0) == Int(rounded) }) else { return }
            values.append(rounded)
        }
        append(pet.dailyPortionGrams)
        append(defaultFeedGrams)
        feedScheduleEvents.forEach { append(FeedRuleMetadata.amountGrams(from: $0)) }
        autoFeederEvents.forEach { append(FeedRuleMetadata.amountGrams(from: $0)) }
        observedCareLogs
            .filter { FeedLogMetadata.isMainFoodLog($0) && $0.amountGrams > 0 }
            .sorted { $0.date > $1.date }
            .prefix(8)
            .forEach { append($0.amountGrams) }
        if values.isEmpty { values = [30, 40, 50, 60] }
        return Array(values.prefix(5))
    }

    private func setMainFoodKind(_ foodKind: FeedFoodKind) {
        guard pet.mainFoodKind != foodKind else { return }
        SetMainFoodKindCommand.run(pet: pet, foodKind: foodKind, context: modelContext)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func feedLogBadge(for log: PetCareLog) -> (title: String, tint: Color, icon: String) {
        switch FeedLogMetadata.source(for: log) ?? .manualMain {
        case .manualMain:
            return ("\(l.tr(zh: "手动", en: "Manual", de: "Manuell")) · \(log.foodKind.title(l))", foodKindTint(log.foodKind), "hand.tap.fill")
        case .manualReminder:
            return ("\(l.tr(zh: "计划", en: "Plan", de: "Plan")) · \(log.foodKind.title(l))", Color.goPurple, FeedRuleKind.manualReminder.iconName)
        case .autoMain:
            return ("\(l.tr(zh: "自动", en: "Auto", de: "Auto")) · \(log.foodKind.title(l))", Color.goTeal, FeedRuleKind.autoFeeder.iconName)
        case .treat:
            return (log.treatKind?.title(l) ?? l.tr(zh: "零食", en: "Treat", de: "Snack"), treatTint, log.treatKind?.systemIconName ?? "birthday.cake.fill")
        }
    }

    private func feedLogDisplayGrams(for log: PetCareLog) -> Double {
        FeedLogMetadata.isMainFoodLog(log)
            ? FeedStockCalculator.effectiveMainFoodAmount(for: log, pet: pet)
            : max(0, log.amountGrams)
    }

    private func parsePositiveDouble(_ raw: String) -> Double? {
        guard let number = CountryDecimalInput.parse(raw, countryCode: AppCountry.code), number >= 0 else { return nil }
        return number
    }

    private func formattedFoodWeight(_ grams: Double) -> String {
        AppMeasurementSystem.formatFoodGrams(grams)
    }

    private func formattedFoodCardWeight(_ grams: Double) -> String {
        "\(Int(max(0, grams).rounded()))g"
    }

    private func formattedStockWeight(_ grams: Double) -> String {
        let digits = grams >= 1_000 && grams < 10_000 ? 2 : 1
        return AppMeasurementSystem.formatFoodGrams(grams, fractionDigits: digits)
    }
}
