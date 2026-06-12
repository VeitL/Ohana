//
//  QuickFeedDetailSheet.swift
//  Ohana
//
//  Feeding management — three-core-card experience.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

enum ManualFeedSheetMode {
    case log
    case settingsOnly
}

struct QuickFeedDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)?
    var showsRemoveQuickActionFooter: Bool = true
    var showsCloseButton: Bool = true
    var opensManualSheetOnAppear: Bool = false
    let allEvents: [Event]
    let allHumans: [Human]
    let allPets: [Pet]
    let feedingLedgerEvents: [CareLedgerEvent]
    let allCareLogs: [PetCareLog]
    let allFoodRecords: [PetFoodRecord]
    let allSharedCareSessions: [SharedCareSession]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("defaultFeedGrams") private var defaultFeedGrams: Double = 0

    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        showsRemoveQuickActionFooter: Bool = true,
        showsCloseButton: Bool = true,
        opensManualSheetOnAppear: Bool = false,
        allEvents: [Event] = [],
        allHumans: [Human] = [],
        allPets: [Pet] = [],
        feedingLedgerEvents: [CareLedgerEvent] = [],
        allCareLogs: [PetCareLog] = [],
        allFoodRecords: [PetFoodRecord] = [],
        allSharedCareSessions: [SharedCareSession] = []
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.onClose = onClose
        self.showsRemoveQuickActionFooter = showsRemoveQuickActionFooter
        self.showsCloseButton = showsCloseButton
        self.opensManualSheetOnAppear = opensManualSheetOnAppear
        self.allEvents = allEvents
        self.allHumans = allHumans
        self.allPets = allPets
        self.feedingLedgerEvents = feedingLedgerEvents
        self.allCareLogs = allCareLogs
        self.allFoodRecords = allFoodRecords
        self.allSharedCareSessions = allSharedCareSessions
    }

    var body: some View {
        QuickFeedDetailContent(
            pet: pet,
            onRemove: onRemove,
            onClose: onClose,
            showsRemoveQuickActionFooter: showsRemoveQuickActionFooter,
            showsCloseButton: showsCloseButton,
            opensManualSheetOnAppear: opensManualSheetOnAppear,
            allEvents: allEvents,
            allHumans: allHumans,
            allPets: allPets,
            feedingLedgerEvents: feedingLedgerEvents,
            allCareLogs: allCareLogs,
            allFoodRecords: allFoodRecords,
            allSharedCareSessions: allSharedCareSessions,
            commandExecutor: QuickFeedCommandExecutor(
                context: modelContext,
                careEvents: appServices.careEvents,
                revisions: appServices.domainRevisions,
                reminderScheduling: appServices.reminderScheduling
            ),
            appLanguage: appLanguage,
            defaultFeedGrams: $defaultFeedGrams
        )
    }
}

struct QuickFeedDetailContent: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)?
    var showsRemoveQuickActionFooter: Bool = true
    var showsCloseButton: Bool = true
    var opensManualSheetOnAppear: Bool = false
    let allEvents: [Event]
    let allHumans: [Human]
    let allPets: [Pet]
    let feedingLedgerEvents: [CareLedgerEvent]
    let allCareLogs: [PetCareLog]
    let allFoodRecords: [PetFoodRecord]
    let allSharedCareSessions: [SharedCareSession]
    let commandExecutor: QuickFeedCommandExecutor
    let appLanguage: String
    @Binding var defaultFeedGrams: Double

    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared

    @StateObject var sheetCoordinator = QuickFeedSheetCoordinator()
    @StateObject var dataController = QuickFeedDataController()
    @StateObject var draftStore = QuickFeedDraftStore()
    @StateObject var stockSnapshotStore: QuickFeedStockSnapshotStore
    @StateObject var overviewSnapshotStore: QuickFeedOverviewSnapshotStore
    @StateObject var planCalendarSnapshotStore: QuickFeedPlanCalendarSnapshotStore
    @StateObject var treatSnapshotStore: QuickFeedTreatSnapshotStore
    @StateObject var presentationState = QuickFeedPresentationState()
    @StateObject var runtimeState = QuickFeedRuntimeState()
    @StateObject var feedHomeController: FeedHomeController
    @FocusState var focusedField: FeedInputField?

    let stockReminderAdvanceOptions = [1, 3, 7, 14]

    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        showsRemoveQuickActionFooter: Bool = true,
        showsCloseButton: Bool = true,
        opensManualSheetOnAppear: Bool = false,
        allEvents: [Event],
        allHumans: [Human],
        allPets: [Pet],
        feedingLedgerEvents: [CareLedgerEvent],
        allCareLogs: [PetCareLog],
        allFoodRecords: [PetFoodRecord],
        allSharedCareSessions: [SharedCareSession],
        commandExecutor: QuickFeedCommandExecutor,
        appLanguage: String,
        defaultFeedGrams: Binding<Double>
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.onClose = onClose
        self.showsRemoveQuickActionFooter = showsRemoveQuickActionFooter
        self.showsCloseButton = showsCloseButton
        self.opensManualSheetOnAppear = opensManualSheetOnAppear
        self.allEvents = allEvents
        self.allHumans = allHumans
        self.allPets = allPets
        self.feedingLedgerEvents = feedingLedgerEvents
        self.allCareLogs = allCareLogs
        self.allFoodRecords = allFoodRecords
        self.allSharedCareSessions = allSharedCareSessions
        self.commandExecutor = commandExecutor
        self.appLanguage = appLanguage
        _defaultFeedGrams = defaultFeedGrams
        let initialNow = Date()
        let initialFeedMode = FeedOperatingMode.stored(for: pet.id) ?? .manual
        let initialRules = FeedRuleState(pet: pet, allEvents: allEvents, now: initialNow)
        _feedHomeController = StateObject(wrappedValue: FeedHomeController(initialMode: initialFeedMode))
        _stockSnapshotStore = StateObject(wrappedValue: QuickFeedStockSnapshotStore(
            initial: QuickFeedStockSnapshot.build(
                pet: pet,
                allEvents: allEvents,
                careLogs: allCareLogs,
                foodRecords: allFoodRecords,
                sharedCareSessions: allSharedCareSessions,
                now: initialNow
            )
        ))
        _overviewSnapshotStore = StateObject(wrappedValue: QuickFeedOverviewSnapshotStore(
            initial: QuickFeedOverviewSnapshot.build(
                pet: pet,
                manualPlanEvents: initialRules.manualReminderEvents,
                autoFeederEvents: initialRules.autoFeederEvents,
                feedingLedgerEvents: feedingLedgerEvents,
                legacyCareLogs: allCareLogs,
                range: .days7,
                activeMode: initialFeedMode,
                defaultFeedGrams: defaultFeedGrams.wrappedValue,
                now: initialNow
            )
        ))
        _planCalendarSnapshotStore = StateObject(wrappedValue: QuickFeedPlanCalendarSnapshotStore(
            initial: QuickFeedPlanCalendarSnapshot.build(
                manualEvents: initialRules.manualReminderEvents,
                autoEvents: initialRules.autoFeederEvents,
                feedingLedgerEvents: feedingLedgerEvents,
                activeMode: initialFeedMode,
                month: initialNow,
                selectedDate: initialNow,
                now: initialNow
            )
        ))
        _treatSnapshotStore = StateObject(wrappedValue: QuickFeedTreatSnapshotStore(
            initial: QuickFeedTreatSnapshot.build(
                pet: pet,
                feedingLedgerEvents: feedingLedgerEvents,
                legacyCareLogs: allCareLogs,
                range: .days7,
                selectedKind: nil,
                now: initialNow
            )
        ))
    }

    var l: L10n { L10n(appLanguage) }
    var deleteFoodRecordAlertTitle: String {
        l.tr(zh: "删除这袋粮？", en: "Delete this stock bag?", de: "Diesen Vorrat löschen?")
    }

    var deleteFoodRecordConfirmTitle: String {
        l.tr(zh: "删除这袋粮", en: "Delete this bag", de: "Diesen Vorrat löschen")
    }

    var deleteFoodRecordAlertMessage: String {
        l.tr(
            zh: "只删除这条补粮/开袋记录，不影响喂食历史。余粮会回退到上一袋已开袋粮；如果没有上一袋，则变为未设置。",
            en: "Only this restock/opened-bag record is removed. Feeding history stays. Stock falls back to the previous opened bag, or becomes unset.",
            de: "Nur dieser Nachfüll-/Öffnungseintrag wird gelöscht. Fütterungshistorie bleibt. Der Vorrat fällt auf den vorherigen geöffneten Beutel zurück oder wird leer."
        )
    }

    var feedAlertHost: QuickFeedAlertHost {
        QuickFeedAlertHost(
            logAnywayTitle: l.tr(zh: "继续打卡", en: "Log anyway", de: "Trotzdem"),
            cancelTitle: l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"),
            deleteFeedLogTitle: l.tr(zh: "删除喂食记录？", en: "Delete feeding log?", de: "Fütterung löschen?"),
            deleteFeedLogConfirmTitle: l.tr(zh: "删除", en: "Delete", de: "Löschen"),
            deleteFeedLogMessage: l.tr(zh: "余粮会根据删除后的记录重新计算。", en: "Stock will recalculate after deletion.", de: "Der Vorrat wird danach neu berechnet."),
            deleteFoodRecordTitle: deleteFoodRecordAlertTitle,
            deleteFoodRecordConfirmTitle: deleteFoodRecordConfirmTitle,
            deleteFoodRecordMessage: deleteFoodRecordAlertMessage,
            activeAlert: activeAlertBinding,
            pendingRepeatAction: pendingRepeatActionBinding,
            onDeleteFeedLog: deleteFeedLog,
            onDeleteFoodRecord: deleteFoodRecord
        )
    }

    var feedClockInterval: TimeInterval {
        workloadPolicy.refreshInterval(default: 30, throttled: 120, paused: 300)
    }

    var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    var feedTaskState: FeedHomeTaskViewState {
        feedHomeController.viewState.task
    }

    var feedMetricsState: FeedHomeMetricsViewState {
        feedHomeController.viewState.metrics
    }

    var feedScheduleEvents: [Event] { feedTaskState.manualPlanEvents }
    var autoFeederEvents: [Event] { feedTaskState.autoFeederEvents }
    var activeFeedingMode: FeedOperatingMode {
        feedHomeController.displayedMode
    }

    var feedHomeSnapshotInput: FeedHomeSnapshotInput {
        FeedHomeSnapshotInput(
            pet: pet,
            allEvents: allEvents,
            careLogs: allCareLogs,
            foodRecords: allFoodRecords,
            sharedCareSessions: allSharedCareSessions,
            now: clockTick,
            todayLabel: l.tr(zh: "今", en: "T", de: "H")
        )
    }

    var currentUserId: String? {
        appServices.activeHumanSelection.currentHumanId
    }

    func normalizedSpecies(_ value: String) -> String {
        SharedPetTargetResolver.normalizedSpecies(value)
    }

    var savedGoal: Int {
        FeedGoalPreferences.manualGoalCount(for: pet.id, default: 1)
    }

    var dryFoodTint: Color { Color.goPrimary }
    var wetFoodTint: Color { Color.goPrimary }
    var treatTint: Color { Color.goPrimary }
    func foodKindTint(_ foodKind: FeedFoodKind) -> Color {
        foodKind == .dry ? dryFoodTint : wetFoodTint
    }

    var observedCareLogs: [PetCareLog] {
        dataController.observedCareLogs(fallback: allCareLogs)
    }

    var observedFeedingLedgerEvents: [CareLedgerEvent] {
        dataController.observedFeedingLedgerEvents(fallback: feedingLedgerEvents)
    }

    var observedFoodRecords: [PetFoodRecord] {
        dataController.observedFoodRecords(fallback: allFoodRecords)
    }

    var stockSnapshot: QuickFeedStockSnapshot {
        stockSnapshotStore.snapshot
    }

    var overviewSnapshot: QuickFeedOverviewSnapshot {
        overviewSnapshotStore.snapshot
    }

    var planCalendarSnapshot: QuickFeedPlanCalendarSnapshot {
        planCalendarSnapshotStore.snapshot
    }

    var treatSnapshot: QuickFeedTreatSnapshot {
        treatSnapshotStore.snapshot
    }

    var sameSpeciesFeedPets: [Pet] {
        let species = normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && normalizedSpecies($0.species) == species }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var selectedFeedTargets: [Pet] {
        let targets = sameSpeciesFeedPets.filter { draftStore.selectedSharedFeedPetIds.contains($0.id) }
        return SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
    }

    var selectedPlanTargets: [Pet] {
        let targets = sameSpeciesFeedPets.filter { draftStore.selectedSharedPlanPetIds.contains($0.id) }
        return SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
    }

    var activeSheet: ActiveFeedSheet? {
        get { sheetCoordinator.activeSheet }
        nonmutating set { sheetCoordinator.activeSheet = newValue }
    }

    var nestedInlineSheet: ActiveFeedSheet? {
        get { sheetCoordinator.nestedInlineSheet }
        nonmutating set { sheetCoordinator.nestedInlineSheet = newValue }
    }

    var adaptiveSheetHeight: CGFloat {
        get { sheetCoordinator.adaptiveSheetHeight }
        nonmutating set { sheetCoordinator.adaptiveSheetHeight = newValue }
    }

    var adaptiveSheetHeightBinding: Binding<CGFloat> {
        Binding(
            get: { adaptiveSheetHeight },
            set: { adaptiveSheetHeight = $0 }
        )
    }

    var inlineKeyboardHeight: CGFloat {
        get { sheetCoordinator.inlineKeyboardHeight }
        nonmutating set { sheetCoordinator.inlineKeyboardHeight = newValue }
    }

    var inlineSheetDragOffset: CGFloat {
        get { sheetCoordinator.inlineSheetDragOffset }
        nonmutating set { sheetCoordinator.inlineSheetDragOffset = newValue }
    }

    var inlineSheetVisible: Bool {
        get { sheetCoordinator.inlineSheetVisible }
        nonmutating set { sheetCoordinator.inlineSheetVisible = newValue }
    }

    var inlineSheetScrollTopOffset: CGFloat {
        get { sheetCoordinator.inlineSheetScrollTopOffset }
        nonmutating set { sheetCoordinator.inlineSheetScrollTopOffset = newValue }
    }

    var inlineSheetTopPullDismissArmed: Bool {
        get { sheetCoordinator.inlineSheetTopPullDismissArmed }
        nonmutating set { sheetCoordinator.inlineSheetTopPullDismissArmed = newValue }
    }

    var inlineSheetDismissGestureShield: Bool {
        get { sheetCoordinator.inlineSheetDismissGestureShield }
        nonmutating set { sheetCoordinator.inlineSheetDismissGestureShield = newValue }
    }

    var systemSheetBinding: Binding<ActiveFeedSheet?> {
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

    var activeInlineSheet: ActiveFeedSheet? {
        sheetCoordinator.activeInlineSheet
    }

    var inlineOverlayBlocksBackground: Bool {
        sheetCoordinator.inlineOverlayBlocksBackground
    }

    var body: some View {
        configuredRoot
    }

    var configuredRoot: some View {
        rootNavigation
            .modifier(rootEventHost)
            .modifier(systemSheetHost)
            .modifier(feedAlertHost)
            .interactiveDismissDisabled(inlineOverlayBlocksBackground)
            .animation(GoMotion.page, value: activeSheet?.id)
            .animation(GoMotion.page, value: activeEmbeddedPanel)
    }

    var rootEventHost: QuickFeedRootEventHost {
        QuickFeedRootEventHost(
            activeSheetID: activeSheet?.id,
            overviewRange: draftStore.overviewRange,
            displayedMode: feedHomeController.displayedMode,
            nestedInlineSheetID: nestedInlineSheet?.id,
            selectedTreatKindRawValue: draftStore.selectedTreatOverviewKind?.rawValue,
            planCalendarMonth: draftStore.feedPlanCalendarMonth,
            planCalendarSelectedDate: draftStore.feedPlanCalendarSelectedDate,
            eventCount: allEvents.count,
            feedingLedgerEventCount: feedingLedgerEvents.count,
            careLogCount: allCareLogs.count,
            foodRecordCount: allFoodRecords.count,
            sharedSessionCount: allSharedCareSessions.count,
            appLanguage: appLanguage,
            feedClockInterval: feedClockInterval,
            workloadPolicy: workloadPolicy,
            onAppear: bootstrap,
            onDisappear: cancelFeedTasks,
            onActiveSheetChange: handleActiveSheetChange,
            onOverviewRangeChange: {
                scheduleDeferredFeedRefresh([.refreshOverviewSnapshot, .forceOverviewSnapshot, .refreshTreatSnapshot, .forceTreatSnapshot])
            },
            onDisplayedModeChange: {
                scheduleDeferredFeedRefresh([.refreshOverviewSnapshot, .forceOverviewSnapshot, .refreshPlanCalendarSnapshot, .forcePlanCalendarSnapshot])
            },
            onNestedInlineSheetChange: {
                sheetCoordinator.resetForNestedInlineSheetChange()
            },
            onTreatFilterChange: {
                scheduleDeferredFeedRefresh([.refreshTreatSnapshot, .forceTreatSnapshot])
            },
            onPlanCalendarChange: {
                scheduleDeferredFeedRefresh([.refreshPlanCalendarSnapshot])
            },
            onEventCountChange: {
                scheduleDeferredFeedRefresh([.reloadSnapshots, .syncDisplayedMode, .ensurePlanReminders])
            },
            onFeedingLedgerEventCountChange: {
                scheduleDeferredFeedRefresh([.reloadFullCareLogsIfLoaded, .reloadSnapshots])
            },
            onCareLogCountChange: {
                scheduleDeferredFeedRefresh([.reloadFullCareLogsIfLoaded, .reloadSnapshots])
            },
            onFoodRecordCountChange: {
                scheduleDeferredFeedRefresh([.reloadFullFoodRecordsIfLoaded, .reloadSnapshots])
            },
            onSharedSessionCountChange: {
                scheduleDeferredFeedRefresh([.reloadSnapshots, .refreshFeedHomeSnapshot, .forceFeedHomeSnapshot])
            },
            onLanguageChange: {
                scheduleDeferredFeedRefresh([.refreshFeedHomeSnapshot, .forceFeedHomeSnapshot])
            },
            onKeyboardFrameChange: updateInlineKeyboardHeight,
            onKeyboardHide: {
                withAnimation(GoMotion.quick) {
                    inlineKeyboardHeight = 0
                }
            },
            onClockTick: handleFeedClockTick
        )
    }

    var rootNavigation: some View {
        NavigationStack {
            rootScene
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                            dismissFeedKeyboard()
                        }
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                    }
                }
        }
    }

    var rootScene: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            rootScrollContent

            QuickFeedOverlayHost(route: activeOverlay)

            if let sheet = activeSheet, sheet.usesInlineOverlay {
                inlineFeedSheetOverlay(sheet)
                    .zIndex(40)
                    .ignoresSafeArea(.container, edges: .bottom)
            }

            if inlineSheetDismissGestureShield, activeSheet?.usesInlineOverlay != true {
                Color.clear
                    .contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .zIndex(39)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .petMemorialTone(isActive: pet.hasPassedAway)
    }

    var rootScrollContent: some View {
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
    }

    var systemSheetHost: QuickFeedSystemSheetHost {
        QuickFeedSystemSheetHost(systemSheet: systemSheetBinding) { sheet in
            AnyView(systemFeedSheetContent(sheet))
        }
    }

    func cancelFeedTasks() {
        runtimeState.cancelTasks()
        presentationState.cancelTransientTasks()
        draftStore.isSavingFeedPlan = false
        feedHomeController.cancel()
    }

    func openRootFeedSheet(_ sheet: ActiveFeedSheet) {
        sheetCoordinator.openRoot(sheet)
        scheduleDetailDataLoad(for: sheet)
    }

    func openFeedSheet(_ sheet: ActiveFeedSheet) {
        sheetCoordinator.open(sheet)
        scheduleDetailDataLoad(for: sheet)
    }

    func closeActiveFeedSheet() {
        sheetCoordinator.closeActive()
    }

    func dismissInlineFeedSheet() {
        dismissFeedKeyboard()
        let dismissingSheetID = sheetCoordinator.beginInlineDismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            sheetCoordinator.finishInlineDismiss(dismissingSheetID: dismissingSheetID)
            try? await Task.sleep(nanoseconds: 160_000_000)
            sheetCoordinator.clearInlineDismissShieldIfIdle()
        }
    }

    func handleFeedClockTick(_ date: Date) {
        let minute = Int(date.timeIntervalSince1970 / 60)
        guard minute != lastFeedClockMinute else { return }
        lastFeedClockMinute = minute
        clockTick = date
        if activeFeedingMode == .autoFeeder, !autoFeederEvents.isEmpty {
            materializeAutoFeedLogs()
        }
        scheduleDeferredFeedRefresh([.reloadSnapshots, .syncDisplayedMode])
    }

    func handleActiveSheetChange() {
        sheetCoordinator.resetForActiveSheetChange()
        guard shouldReplayOverviewChart(for: activeSheet) else { return }
        replayOverviewChart()
    }

    func shouldReplayOverviewChart(for sheet: ActiveFeedSheet?) -> Bool {
        sheet == .feedingOverview || sheet == .feedModeHistory || sheet == .treatOverview
    }

    func replayOverviewChart() {
        overviewChartProgress = 0
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(GoMotion.page) {
                overviewChartProgress = 1
            }
        }
    }

    func scheduleDeferredFeedRefresh(
        _ request: QuickFeedRefreshRequest,
        milliseconds: UInt64 = 0
    ) {
        pendingFeedRefreshRequest.formUnion(request)
        guard feedRefreshTask == nil else { return }
        feedRefreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            let request = pendingFeedRefreshRequest
            pendingFeedRefreshRequest = QuickFeedRefreshRequest()
            feedRefreshTask = nil
            performDeferredFeedRefresh(request)
        }
    }

    func performDeferredFeedRefresh(_ request: QuickFeedRefreshRequest) {
        guard !request.isEmpty else { return }
        if request.contains(.reloadFullCareLogsIfLoaded), dataController.hasLoadedFullCareLogs {
            loadFullCareLogs(force: true)
        }
        if request.contains(.reloadFullCareLogsIfLoaded), dataController.hasLoadedFullFeedingLedgerEvents {
            loadFullFeedingLedgerEvents(force: true)
        }
        if request.contains(.reloadFullFoodRecordsIfLoaded), dataController.hasLoadedFullFoodRecords {
            loadFullFoodRecords(force: true)
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if request.contains(.reloadSnapshots) {
                reloadFeedSnapshots()
            }
            if request.contains(.refreshFeedHomeSnapshot) {
                refreshFeedHomeSnapshot(force: request.contains(.forceFeedHomeSnapshot))
            }
            if request.contains(.refreshOverviewSnapshot) {
                refreshOverviewSnapshot(force: request.contains(.forceOverviewSnapshot))
            }
            if request.contains(.refreshPlanCalendarSnapshot) {
                refreshPlanCalendarSnapshot(force: request.contains(.forcePlanCalendarSnapshot))
            }
            if request.contains(.refreshTreatSnapshot) {
                refreshTreatSnapshot(force: request.contains(.forceTreatSnapshot))
            }
            if request.contains(.syncDisplayedMode) {
                syncDisplayedFeedMode(force: request.contains(.forceDisplayedMode))
            }
        }

        if request.contains(.ensurePlanReminders) {
            ensureUpcomingPlanReminders()
        }
    }

    func scheduleDetailDataLoad(for sheet: ActiveFeedSheet) {
        let needsCareLogs = sheet.needsFullCareLogs
        let needsFoodRecords = sheet.needsFullFoodRecords
        guard (needsCareLogs && (!dataController.hasLoadedFullCareLogs || !dataController.hasLoadedFullFeedingLedgerEvents)) ||
            (needsFoodRecords && !dataController.hasLoadedFullFoodRecords)
        else { return }

        feedDetailDataTask?.cancel()
        feedDetailDataTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: sheet.usesInlineOverlay ? 70 : 120) {
            FeedHomePerformance.measure("detail.lazyLoad") {
                if needsCareLogs {
                    loadFullCareLogs()
                    loadFullFeedingLedgerEvents()
                }
                if needsFoodRecords {
                    loadFullFoodRecords()
                }
            }
            reloadFeedSnapshots()
            feedDetailDataTask = nil
        }
    }

    func loadFullCareLogs(force: Bool = false) {
        dataController.loadFullCareLogs(
            petID: pet.id,
            feedingType: CareType.feeding.rawValue,
            fallback: allCareLogs,
            force: force,
            fetcher: commandExecutor.fullCareLogs
        )
    }

    func loadFullFeedingLedgerEvents(force: Bool = false) {
        dataController.loadFullFeedingLedgerEvents(
            petID: pet.id,
            fallback: feedingLedgerEvents,
            force: force,
            fetcher: commandExecutor.fullFeedingLedgerEvents
        )
    }

    func loadFullFoodRecords(force: Bool = false) {
        dataController.loadFullFoodRecords(
            petID: pet.id,
            fallback: allFoodRecords,
            force: force,
            fetcher: commandExecutor.fullFoodRecords
        )
    }

    // MARK: - Main

    var petHeader: some View {
        HStack(spacing: 12) {
            avatarView(size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "粮食记录", en: "Food log", de: "Futter"))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if showsCloseButton {
                Button {
                    closeDetail()
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .contentShape(Rectangle())
                }
                .frame(width: 44, height: 44)
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func closeDetail() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    var guidedFeedHome: some View {
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
            onOpenStockOverview: {
                collapseEmbeddedPanel()
                openRootFeedSheet(.stockOverview)
            },
            onOpenTreatOverview: {
                collapseEmbeddedPanel()
                openRootFeedSheet(.treatOverview)
            },
            onOpenTaskSettings: toggleEmbeddedModeSettings,
            onQuickAddTreat: toggleEmbeddedTreatAdd,
            onOpenManualHistory: {
                collapseEmbeddedPanel()
                openRootFeedSheet(.history)
            },
            onOpenModeHistory: {
                collapseEmbeddedPanel()
                openRootFeedSheet(.feedModeHistory)
            },
            inlineTaskPanel: guidedInlineTaskPanel,
            inlineTreatPanel: guidedInlineTreatPanel
        )
        .body
    }
}
