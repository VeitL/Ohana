//
//  QuickWaterDetailSheet.swift
//  Ohana
//
//  Water management sheet: feed water, water changes, and filter care.
//

import SwiftData
import SwiftUI

struct QuickWaterDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)?
    let allEvents: [Event]
    let allPets: [Pet]
    let waterLedgerEvents: [CareLedgerEvent]
    let legacyWaterDeleteLogs: [PetCareLog]

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = AppLanguage.fallbackCode
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared
    @State var waterIntervalDays: Int = 3
    @State var waterChangeAnchorDate: Date = .init()
    @State var filterCleanIntervalDays: Int = 14
    @State var filterReplaceIntervalDays: Int = 90
    @State var waterAmountEnabled = true
    @State var waterAmountMlText = "250"
    @State var waterReminderOn = false
    @State var filterReminderOn = false
    @State var activeSheet: ActiveSheet?
    @State var nestedInlineSheet: ActiveSheet?
    @State var waterSheetReturnStack: [ActiveSheet] = []
    @State var showSaveToast = false
    @State var saveToastMessage = ""
    @State var saveToastTask: Task<Void, Never>?
    @State var waterPlanCount = 3
    @State var waterPlanTimes: [Date] = []
    @State var overviewRange: WaterOverviewRange = .days7
    @State var overviewChartProgress: Double = 1
    @State var inlineSheetVisible = false
    @State var inlineSheetDragOffset: CGFloat = 0
    @State var adaptiveSheetHeight: CGFloat = 430
    @State var waterModeStorageTick = 0
    @State var displayedWaterMode: WaterOperatingMode
    @State var waterSnapshot = QuickWaterRenderSnapshot.empty
    @State var pendingWaterRefreshRequest = QuickWaterRefreshRequest()
    @State var waterSnapshotRefreshTask: Task<Void, Never>?
    @State var waterRefreshDelayMilliseconds: UInt64?
    @State var waterModeTransitionTask: Task<Void, Never>?
    @State var activeWaterModeTransitionID: UUID?
    @State var waterModeMaintenanceTask: Task<Void, Never>?
    @State var waterPlanMaintenanceTask: Task<Void, Never>?
    @State var waterPlanSaveTask: Task<Void, Never>?
    @State var isSavingWaterPlan = false
    @State var waterReminderSchedulingTask: Task<Void, Never>?
    @State var waterReminderSchedulingID: UUID?
    @State var carePlanReminderSchedulingTask: Task<Void, Never>?
    @State var carePlanReminderSchedulingID: UUID?
    @State var optimisticWaterPlanEvents: [Event] = []
    @State var waterFeedbackToken: CheckInFeedbackToken?
    @State var waterChangeFeedbackToken: CheckInFeedbackToken?
    @State var filterFeedbackToken: CheckInFeedbackToken?
    @State var feedbackClearTask: Task<Void, Never>?
    @State var waterActionTask: Task<Void, Never>?
    @State var inlineSheetDismissTask: Task<Void, Never>?
    @State var overviewChartReplayTask: Task<Void, Never>?
    @State var selectedSharedWaterPetIds: Set<UUID> = []
    @Namespace var waterModeSelectionNamespace
    typealias ActiveSheet = QuickWaterActiveSheet
    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        allEvents: [Event] = [],
        allPets: [Pet] = [],
        waterLedgerEvents: [CareLedgerEvent] = [],
        legacyWaterDeleteLogs: [PetCareLog] = []
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.onClose = onClose
        self.allEvents = allEvents
        self.allPets = allPets
        self.waterLedgerEvents = waterLedgerEvents
        self.legacyWaterDeleteLogs = legacyWaterDeleteLogs
        _displayedWaterMode = State(initialValue: WaterOperatingMode.stored(pet.id) ?? .manual)
    }

    var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    var isDark: Bool { colorScheme == .dark }
    var chromeTint: Color { Color.goPrimary }
    var petKey: String { pet.id.uuidString }
    var isAquatic: Bool { WaterQuickActionPolicy.isAquatic(species: pet.species) }
    var l: L10n { L10n(appLanguage) }
    var sameSpeciesWaterPets: [Pet] {
        let species = normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && normalizedSpecies($0.species) == species }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var selectedWaterTargets: [Pet] {
        let targets = sameSpeciesWaterPets.filter { selectedSharedWaterPetIds.contains($0.id) }
        return SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
    }

    var waterChangeTint: Color { Color(hex: CareType.waterChange.accentColorHex) }
    var filterTint: Color { Color(hex: CareType.filterClean.accentColorHex) }
    var waterRuleState: QuickWaterRuleSnapshot {
        waterSnapshot.rule
    }

    var waterMode: WaterOperatingMode {
        _ = waterModeStorageTick
        return isAquatic ? .manual : displayedWaterMode
    }

    var commandExecutor: QuickWaterCommandExecutor {
        QuickWaterCommandExecutor(
            context: modelContext,
            activeHumanSelection: appServices.activeHumanSelection,
            careEvents: appServices.careEvents,
            userNotifications: appServices.userNotifications,
            reminderScheduling: appServices.reminderScheduling,
            revisions: appServices.domainRevisions
        )
    }

    var systemSheetBinding: Binding<ActiveSheet?> {
        Binding(
            get: { activeSheet?.usesInlineOverlay == true ? nil : activeSheet },
            set: { newValue in
                if let newValue {
                    openRootWaterSheet(newValue)
                } else if activeSheet?.usesInlineOverlay != true {
                    nestedInlineSheet = nil
                    waterSheetReturnStack.removeAll()
                    activeSheet = nil
                }
            }
        )
    }

    var activeInlineSheet: ActiveSheet? {
        nestedInlineSheet ?? (activeSheet?.usesInlineOverlay == true ? activeSheet : nil)
    }

    var inlineOverlayBlocksBackground: Bool {
        activeInlineSheet != nil
    }

    var todayWaterLogs: [QuickWaterLedgerEntry] {
        waterSnapshot.todayWaterLogs
    }

    var waterChangeLogs: [QuickWaterLedgerEntry] {
        waterSnapshot.waterChangeLogs
    }

    var filterCleanLogs: [QuickWaterLedgerEntry] {
        waterSnapshot.filterCleanLogs
    }

    var allWaterLogs: [QuickWaterLedgerEntry] {
        waterSnapshot.allWaterLogs
    }

    var lastWaterLog: QuickWaterLedgerEntry? { waterSnapshot.lastWaterLog }
    var waterLogs: [QuickWaterLedgerEntry] {
        waterSnapshot.waterLogs
    }

    var lastWaterChange: QuickWaterLedgerEntry? { waterSnapshot.lastWaterChange }
    var lastFilterClean: QuickWaterLedgerEntry? { waterSnapshot.lastFilterClean }
    var waterElapsedDays: Int { daysSinceDate(lastWaterChange?.date ?? waterChangeAnchorDate) }
    var filterCleanElapsedDays: Int? { lastFilterClean.map { daysSinceDate($0.date) } }
    var filterReplaceElapsedDays: Int? { lastFilterClean.map { daysSinceDate($0.date) } }
    var daysUntilWaterChange: Int { waterIntervalDays - waterElapsedDays }
    var daysUntilFilterClean: Int? { filterCleanElapsedDays.map { filterCleanIntervalDays - $0 } }
    var daysUntilFilterReplace: Int? { filterReplaceElapsedDays.map { filterReplaceIntervalDays - $0 } }
    var isWaterChangeOverdue: Bool { daysUntilWaterChange < 0 }
    var isFilterCleanOverdue: Bool { (daysUntilFilterClean ?? 1) < 0 }
    var isFilterReplaceOverdue: Bool { (daysUntilFilterReplace ?? 1) < 0 }
    var isFilterOverdue: Bool { isFilterCleanOverdue || isFilterReplaceOverdue }
    var waterChangeStatusTint: Color { isWaterChangeOverdue ? Color.goRed : waterChangeTint }
    var filterStatusTint: Color { isFilterOverdue ? Color.goRed : filterTint }
    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        if pet.hasPassedAway {
                            PetMemorialBanner(pet: pet)
                        }
                        waterDashboard
                        coreCards
                        recentStrip
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
            .overlay(alignment: .top) {
                if showSaveToast {
                    toastView
                }
            }
            .overlay {
                if let sheet = activeSheet, sheet.usesInlineOverlay {
                    inlineWaterSheetOverlay(sheet)
                        .zIndex(40)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: systemSheetBinding) { sheet in
                NavigationStack {
                    ZStack {
                        VStack(spacing: 0) {
                            waterSheetTopChrome(sheet)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                            sheetContent(sheet)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .allowsHitTesting(nestedInlineSheet == nil)
                                .petMemorialTone(isActive: pet.hasPassedAway)
                        }

                        if nestedInlineSheet != nil {
                            Color.clear
                                .contentShape(Rectangle())
                                .ignoresSafeArea()
                                .zIndex(35)
                        }

                        if let nestedInlineSheet {
                            inlineWaterSheetOverlay(nestedInlineSheet)
                                .zIndex(40)
                                .ignoresSafeArea(.container, edges: .bottom)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/history uses system sheet
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .petMemorialTone(isActive: pet.hasPassedAway)
        }
        .onAppear {
            loadSettings()
            rebuildWaterSnapshot(force: true)
            selectedSharedWaterPetIds = SharedPetSelectionMemory.restoredSelection(
                sourcePet: pet,
                scope: "quickCare.water",
                candidates: sameSpeciesWaterPets,
                defaultToAll: true
            )
            syncDisplayedWaterMode(force: true)
            scheduleWaterPlanMaintenance(delayMilliseconds: 220)
            if filterReminderOn {
                OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
                    syncFilterPlan(showToast: false)
                }
            }
        }
        .onChange(of: allEvents.count) { _, _ in
            let refreshDelay = activeWaterModeTransitionID == nil
                ? UInt64(96)
                : waterModeTransitionDelayMilliseconds + 140
            let maintenanceDelay = activeWaterModeTransitionID == nil
                ? UInt64(520)
                : waterModeMaintenanceDelayMilliseconds
            scheduleWaterSnapshotRefresh(milliseconds: refreshDelay, syncModeAfterRefresh: true)
            scheduleWaterPlanMaintenance(delayMilliseconds: maintenanceDelay)
        }
        .onChange(of: waterLedgerEvents.count) { _, _ in
            scheduleWaterSnapshotRefresh()
        }
        .onChange(of: activeSheet?.id) { _, _ in
            adaptiveSheetHeight = activeSheet?.inlineHeight ?? 430
            inlineSheetDragOffset = 0
            if activeSheet?.usesInlineOverlay != true {
                inlineSheetVisible = false
            }
            if activeSheet == .waterOverview || activeSheet == .waterChangeOverview || activeSheet == .filterOverview {
                overviewChartProgress = 0
                scheduleOverviewChartReplay(milliseconds: 90)
            }
        }
        .onChange(of: nestedInlineSheet?.id) { _, _ in
            adaptiveSheetHeight = nestedInlineSheet?.inlineHeight ?? activeSheet?.inlineHeight ?? 430
            inlineSheetDragOffset = 0
            if nestedInlineSheet == nil, activeSheet?.usesInlineOverlay != true {
                inlineSheetVisible = false
            }
        }
        .onDisappear {
            waterSnapshotRefreshTask?.cancel()
            waterModeTransitionTask?.cancel()
            waterModeMaintenanceTask?.cancel()
            waterPlanMaintenanceTask?.cancel()
            waterPlanSaveTask?.cancel()
            waterReminderSchedulingTask?.cancel()
            carePlanReminderSchedulingTask?.cancel()
            waterActionTask?.cancel()
            inlineSheetDismissTask?.cancel()
            overviewChartReplayTask?.cancel()
            activeWaterModeTransitionID = nil
            waterReminderSchedulingID = nil
            carePlanReminderSchedulingID = nil
            isSavingWaterPlan = false
        }
        .interactiveDismissDisabled(activeInlineSheet != nil)
    }

    // MARK: - Main UI
    func inlineWaterSheetOverlay(_ sheet: ActiveSheet) -> some View {
        GeometryReader { proxy in
            let bottomInset = CGFloat(8)
            let maxHeight = min(max(sheet.inlineHeight, adaptiveSheetHeight), proxy.size.height * 0.94)
            let panelHeight = min(max(300, adaptiveSheetHeight), maxHeight)
            let horizontalInset = CGFloat(6)
            let panelWidth = max(0, proxy.size.width - horizontalInset * 2)
            let cornerRadius = CGFloat(54)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let hiddenOffset = panelHeight + bottomInset + 64

            ZStack(alignment: .bottom) {
                inlineSheetBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture { dismissInlineWaterSheet() }

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
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { dismissInlineWaterSheet() }
                            .padding(.top, 10)
                            .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background {
                    WaterInlineSheetGlassSurface(cornerRadius: cornerRadius)
                }
                .clipShape(shape)
                .frame(width: panelWidth)
                .shadow(color: Color.black.opacity(inlineSheetVisible ? 0.56 : 0), radius: 48, x: 0, y: -18) // ui-v4: allow popup liftedAlert shadow
                .shadow(color: Color(hex: "0B102C").opacity(inlineSheetVisible ? 0.46 : 0), radius: 28, x: 0, y: 12) // ui-v4: allow popup liftedAlert shadow
                .offset(y: inlineSheetVisible ? inlineSheetDragOffset : hiddenOffset)
                .opacity(inlineSheetVisible ? 1 : 0.94)
                .scaleEffect(inlineSheetVisible ? 1 : 0.982, anchor: .bottom)
                .padding(.bottom, bottomInset)
                .animation(GoMotion.feedback, value: inlineSheetDragOffset)
                .animation(GoMotion.page, value: inlineSheetVisible)
            }
            .onAppear {
                inlineSheetVisible = false
                DispatchQueue.main.async {
                    withAnimation(GoMotion.page) {
                        inlineSheetVisible = true
                    }
                }
            }
        }
    }

    var inlineSheetBackdrop: some View {
        ZStack {
            Color.black.opacity(inlineSheetVisible ? 0.16 : 0) // ui-v4: allow modal scrim
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(inlineSheetVisible ? 0.26 : 0)], // ui-v4: allow modal scrim
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(GoMotion.page, value: inlineSheetVisible)
    }

    var inlineSheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                inlineSheetDragOffset = min(140, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 72 || value.predictedEndTranslation.height > 130 {
                    dismissInlineWaterSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    func dismissInlineWaterSheet() {
        let dismissingSheetID = activeInlineSheet?.id
        withAnimation(GoMotion.page) {
            inlineSheetVisible = false
            inlineSheetDragOffset = 0
        }
        inlineSheetDismissTask?.cancel()
        inlineSheetDismissTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
            if nestedInlineSheet?.id == dismissingSheetID {
                nestedInlineSheet = nil
            } else if activeSheet?.id == dismissingSheetID {
                closeActiveWaterSheet()
            }
            inlineSheetDismissTask = nil
        }
    }

    func openRootWaterSheet(_ sheet: ActiveSheet) {
        nestedInlineSheet = nil
        waterSheetReturnStack.removeAll()
        activeSheet = sheet
    }

    func openWaterSheet(_ sheet: ActiveSheet) {
        if activeSheet?.usesInlineOverlay == false, sheet.usesInlineOverlay {
            nestedInlineSheet = sheet
            return
        }
        if activeSheet?.usesInlineOverlay == true, sheet.usesInlineOverlay {
            activeSheet = sheet
            return
        }

        if let current = activeSheet, current.id != sheet.id {
            waterSheetReturnStack.append(current)
        } else if activeSheet == nil {
            waterSheetReturnStack.removeAll()
        }
        activeSheet = sheet
    }

    func closeActiveWaterSheet() {
        if nestedInlineSheet != nil {
            nestedInlineSheet = nil
            return
        }
        if let returnSheet = waterSheetReturnStack.popLast() {
            activeSheet = returnSheet
        } else {
            activeSheet = nil
        }
    }

    var header: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: themeColor,
                size: 48,
                backgroundOpacity: 0.16
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isAquatic ? l.tr(zh: "水体 / 换水 / 滤芯", en: "Water tank / Changes / Filter", de: "Wasserbecken / Wechsel / Filter") : l.tr(zh: "喂水 / 换水 / 滤芯", en: "Water / Changes / Filter", de: "Trinken / Wechsel / Filter"))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { closeDetail() } label: {
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

    func closeDetail() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    var waterModeSelector: some View {
        HStack(spacing: 8) {
            waterModeChip(.manual)
            waterModeChip(.reminder)
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
        .animation(waterModeTransitionAnimation, value: waterMode)
    }

    func waterModeChip(_ mode: WaterOperatingMode) -> some View {
        let selected = waterMode == mode
        let tint = mode == .manual ? chromeTint : Color.goTeal
        return Button {
            handleWaterModeTap(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode == .manual ? "hand.tap.fill" : "bell.badge.fill")
                    .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(mode == .manual ? l.tr(zh: "手动", en: "Manual", de: "Manuell") : l.tr(zh: "计划", en: "Plan", de: "Plan"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(selected ? Color.arkInk : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule()
                        .fill(tint)
                        .matchedGeometryEffect(id: "quickWaterModeSelection", in: waterModeSelectionNamespace)
                } else {
                    Capsule()
                        .fill(Color.ohanaCardSurfaceElevated)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .zIndex(selected ? 1 : 0)
    }

    var waterDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((waterMode == .reminder ? Color.goTeal : chromeTint).opacity(0.14))
                        .frame(width: 66, height: 66)
                    Image(systemName: isAquatic ? "water.waves" : "drop.fill")
                        .font(OhanaFont.adaptive(size: 28, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(waterMode == .reminder ? Color.goTeal : chromeTint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(isAquatic ? l.tr(zh: "水体管理", en: "Water tank care", de: "Wasserbeckenpflege") : l.tr(zh: "今日喂水", en: "Today's water", de: "Trinken heute"))
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isAquatic ? l.tr(zh: "换水、滤芯和水体状态", en: "Water changes, filter, and tank status", de: "Wasserwechsel, Filter und Beckenstatus") : waterSubtitle)
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                waterSummaryPill(
                    title: l.tr(zh: "喂水", en: "Water", de: "Trinken"),
                    value: isAquatic ? l.tr(zh: "水族", en: "Aquatic", de: "Aquaristik") : localizedTimes(todayWaterLogs.count),
                    tint: chromeTint
                )
                waterSummaryPill(
                    title: l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel"),
                    value: dueText(daysUntil: daysUntilWaterChange),
                    tint: waterChangeStatusTint,
                    isWarning: isWaterChangeOverdue
                )
                waterSummaryPill(
                    title: l.tr(zh: "滤芯", en: "Filter", de: "Filter"),
                    value: optionalDueText(daysUntilFilterClean),
                    tint: filterStatusTint,
                    isWarning: isFilterOverdue
                )
            }

            if !isAquatic {
                waterModeSelector
            }
        }
        .padding(.vertical, 2)
    }

    func waterSummaryPill(title: String, value: String, tint: Color, isWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                if isWarning {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 8, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
            }
            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(isWarning ? Color.goRed : Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isWarning ? Color.goRed.opacity(0.16) : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .strokeBorder(isWarning ? Color.goRed.opacity(0.62) : Color.clear, lineWidth: 1)
        )
    }

    var waterHero: some View {
        WaterHeroCard(
            tint: chromeTint,
            secondaryTint: filterTint,
            waterCount: todayWaterLogs.count,
            waterDueProgress: cycleProgress(elapsed: waterElapsedDays, interval: waterIntervalDays),
            filterDueProgress: cycleProgress(elapsed: filterCleanElapsedDays ?? 0, interval: filterCleanIntervalDays),
            isAquatic: isAquatic
        )
        .frame(height: 128)
    }

    var coreCards: some View {
        VStack(spacing: 12) {
            waterCard
            waterChangeCard
            filterCard
        }
    }

    var waterCard: some View {
        WaterCoreCard(
            title: l.tr(zh: "喂水", en: "Water", de: "Trinken"),
            icon: isAquatic ? "water.waves" : "drop.fill",
            tint: waterMode == .reminder ? Color.goTeal : chromeTint,
            value: waterCardValue,
            subtitle: waterSubtitle,
            progress: waterCardProgress,
            primaryTitle: waterPrimaryTitle,
            primaryIcon: waterPrimaryIcon,
            primaryAction: {
                guard !pet.hasPassedAway else {
                    openRootWaterSheet(.waterOverview)
                    return
                }
                if isAquatic {
                    openRootWaterSheet(.waterOverview)
                } else if waterMode == .reminder {
                    completeNextPlannedWaterOrOpenOverview()
                } else {
                    commitWater()
                }
            },
            secondaryTitle: isAquatic ? nil : l.tr(zh: "设置", en: "Settings", de: "Einstellungen"),
            secondaryAction: isAquatic ? nil : {
                guard !pet.hasPassedAway else {
                    openRootWaterSheet(.waterOverview)
                    return
                }
                handleWaterSettingsTap()
            },
            tapAction: { openRootWaterSheet(.waterOverview) },
            feedbackToken: waterFeedbackToken
        )
    }

    var waterChangeCard: some View {
        WaterCoreCard(
            title: l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel"),
            icon: "arrow.2.circlepath",
            tint: waterChangeStatusTint,
            value: dueText(daysUntil: daysUntilWaterChange),
            subtitle: waterChangeSubtitle,
            progress: cycleProgress(elapsed: waterElapsedDays, interval: waterIntervalDays),
            primaryTitle: l.tr(zh: "记录", en: "Log", de: "Eintragen"),
            primaryIcon: "checkmark",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    openRootWaterSheet(.waterChangeOverview)
                    return
                }
                doWaterChange()
            },
            secondaryTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
            secondaryAction: {
                if pet.hasPassedAway {
                    openRootWaterSheet(.waterChangeOverview)
                } else {
                    openWaterSheet(.waterSettings)
                }
            },
            tapAction: { openRootWaterSheet(.waterChangeOverview) },
            feedbackToken: waterChangeFeedbackToken,
            isWarning: isWaterChangeOverdue
        )
    }

    var filterCard: some View {
        WaterCoreCard(
            title: l.tr(zh: "滤芯", en: "Filter", de: "Filter"),
            icon: "sparkles",
            tint: filterStatusTint,
            value: optionalDueText(daysUntilFilterClean),
            subtitle: filterSubtitle,
            progress: cycleProgress(elapsed: filterCleanElapsedDays ?? 0, interval: filterCleanIntervalDays),
            primaryTitle: l.tr(zh: "清洗", en: "Clean", de: "Reinigen"),
            primaryIcon: "checkmark",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    openRootWaterSheet(.filterOverview)
                    return
                }
                doFilterClean()
            },
            secondaryTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
            secondaryAction: {
                if pet.hasPassedAway {
                    openRootWaterSheet(.filterOverview)
                } else {
                    openWaterSheet(.filterSettings)
                }
            },
            tapAction: { openRootWaterSheet(.filterOverview) },
            feedbackToken: filterFeedbackToken,
            isWarning: isFilterOverdue
        )
    }

    var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Button {
                    openWaterSheet(.history)
                } label: {
                    Text(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(chromeTint)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if allWaterLogs.isEmpty {
                Text(l.tr(zh: "暂无记录", en: "No records yet", de: "Noch keine Einträge"))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(allWaterLogs.prefix(3))) { log in
                    WaterLogRow(log: log, tint: tint(for: log), showDelete: true) {
                        deleteLog(log)
                    }
                }
            }
        }
        .padding(14)
        .background(sheetSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    var toastView: some View {
        Text(saveToastMessage)
            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(chromeTint, in: Capsule())
            .shadow(color: chromeTint.opacity(0.32), radius: 12, y: 6) // ui-v4: allow toast elevation
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    var sheetSurface: some ShapeStyle {
        Color.ohanaCardSurface
    }

    var waterCardValue: String {
        if isAquatic { return l.tr(zh: "水族", en: "Aquatic", de: "Aquaristik") }
        if waterMode == .reminder {
            if waterRuleState.missedCount > 0 { return localizedMissedCount(waterRuleState.missedCount) }
            return waterRuleState.completionText
        }
        return localizedTimes(todayWaterLogs.count)
    }

    var waterCardProgress: Double? {
        if isAquatic { return nil }
        if waterMode == .reminder {
            return min(Double(waterRuleState.completedTodayPlanReminders.count) / Double(max(waterRuleState.todayPlanReminders.count, 1)), 1)
        }
        return min(Double(todayWaterLogs.count) / 3, 1)
    }

    var waterSubtitle: String {
        if isAquatic { return l.tr(zh: "不做喂水打卡", en: "No water check-ins", de: "Keine Trink-Check-ins") }
        if waterMode == .reminder {
            if let missed = waterRuleState.missedPlanReminders.first {
                return localizedCatchUpTime(missed.scheduledAt.formatted(date: .omitted, time: .shortened))
            }
            if let next = waterRuleState.nextPendingReminder {
                return localizedNextTime(next.scheduledAt.formatted(date: .omitted, time: .shortened))
            }
            return localizedTodayPlan(waterRuleState.completionText)
        }
        if let lastWaterLog {
            let amountText = lastWaterLog.amountMl > 0 ? " · \(Int(lastWaterLog.amountMl))ml" : ""
            return "\(relativeDayText(for: lastWaterLog.date))\(amountText)"
        }
        return waterAmountEnabled ? localizedOneTapAmount(Int(defaultWaterAmountMl ?? 250)) : l.tr(zh: "只记录一次", en: "Log one time", de: "Einmal eintragen")
    }

    var waterChangeSubtitle: String {
        if isWaterChangeOverdue {
            return localizedOverdueAction(days: abs(daysUntilWaterChange), action: l.tr(zh: "立即换水", en: "change now", de: "jetzt wechseln"))
        }
        if let lastWaterChange {
            return "\(relativeDayText(for: lastWaterChange.date)) · \(localizedDayCycle(waterIntervalDays))"
        }
        return localizedDayCycle(waterIntervalDays)
    }

    var filterSubtitle: String {
        if let daysUntilFilterClean, daysUntilFilterClean < 0 {
            return localizedMaintenanceOverdue(kind: l.tr(zh: "清洗", en: "Cleaning", de: "Reinigung"), days: abs(daysUntilFilterClean))
        }
        if let daysUntilFilterReplace, daysUntilFilterReplace < 0 {
            return localizedMaintenanceOverdue(kind: l.tr(zh: "更换", en: "Replacement", de: "Wechsel"), days: abs(daysUntilFilterReplace))
        }
        let replaceText = daysUntilFilterReplace.map { localizedReplaceDue(dueText(daysUntil: $0)) } ?? l.tr(zh: "先清洗一次", en: "Clean once first", de: "Zuerst einmal reinigen")
        if let lastFilterClean {
            return "\(relativeDayText(for: lastFilterClean.date)) · \(replaceText)"
        }
        return replaceText
    }

    func localizedTimes(_ count: Int) -> String {
        l.tr(
            zh: "\(count) 次",
            en: count == 1 ? "1 time" : "\(count) times",
            de: count == 1 ? "1 Mal" : "\(count) Mal"
        )
    }

    func localizedPetCount(_ count: Int, species: String) -> String {
        l.tr(
            zh: "\(count)只\(species)",
            en: "\(count) \(species)",
            de: "\(count) \(species)"
        )
    }

    func localizedDays(_ days: Int) -> String {
        l.tr(
            zh: "\(days)天",
            en: "\(days) days",
            de: "\(days) Tage"
        )
    }

    func localizedProgressDays(elapsed: Int, interval: Int) -> String {
        l.tr(
            zh: "\(elapsed)/\(interval)天",
            en: "\(elapsed)/\(interval) days",
            de: "\(elapsed)/\(interval) Tage"
        )
    }

    func localizedMissedCount(_ count: Int) -> String {
        l.tr(
            zh: "待补 \(count)",
            en: "\(count) missed",
            de: "\(count) offen"
        )
    }

    func localizedCatchUpTime(_ timeText: String) -> String {
        l.tr(
            zh: "待补 \(timeText)",
            en: "Catch up \(timeText)",
            de: "Nachholen \(timeText)"
        )
    }

    func localizedNextTime(_ timeText: String) -> String {
        l.tr(
            zh: "下一次 \(timeText)",
            en: "Next \(timeText)",
            de: "Nächstes \(timeText)"
        )
    }

    func localizedTodayPlan(_ completionText: String) -> String {
        l.tr(
            zh: "今日计划 \(completionText)",
            en: "Today's plan \(completionText)",
            de: "Tagesplan \(completionText)"
        )
    }

    func localizedOneTapAmount(_ amountMl: Int) -> String {
        l.tr(
            zh: "一键记录 \(amountMl)ml",
            en: "Log \(amountMl) ml",
            de: "\(amountMl) ml eintragen"
        )
    }

    func localizedDayCycle(_ days: Int) -> String {
        l.tr(
            zh: "\(days)天周期",
            en: "Every \(days) days",
            de: "Alle \(days) Tage"
        )
    }

    func localizedOverdueAction(days: Int, action: String) -> String {
        l.tr(
            zh: "逾期\(days)天 · \(action)",
            en: "\(days) days overdue · \(action)",
            de: "\(days) Tage überfällig · \(action)"
        )
    }

    func localizedMaintenanceOverdue(kind: String, days: Int) -> String {
        l.tr(
            zh: "\(kind)逾期\(days)天 · 立即处理",
            en: "\(kind) \(days) days overdue · handle now",
            de: "\(kind) \(days) Tage überfällig · jetzt erledigen"
        )
    }

    func localizedReplaceDue(_ dueText: String) -> String {
        l.tr(
            zh: "更换 \(dueText)",
            en: "Replace \(dueText)",
            de: "Wechsel \(dueText)"
        )
    }
}
