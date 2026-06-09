//
//  QuickWaterDetailSheet.swift
//  Ohana
//
//  Water management sheet: feed water, water changes, and filter care.
//

import SwiftUI
import SwiftData

struct QuickWaterDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)? = nil
    let allEvents: [Event]
    let allPets: [Pet]
    let waterCareLogs: [PetCareLog]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    @State private var waterIntervalDays: Int = 3
    @State private var waterChangeAnchorDate: Date = Date()
    @State private var filterCleanIntervalDays: Int = 14
    @State private var filterReplaceIntervalDays: Int = 90
    @State private var waterAmountEnabled = true
    @State private var waterAmountMlText = "250"
    @State private var waterReminderOn = false
    @State private var filterReminderOn = false
    @State private var activeSheet: ActiveSheet?
    @State private var nestedInlineSheet: ActiveSheet?
    @State private var waterSheetReturnStack: [ActiveSheet] = []
    @State private var showSaveToast = false
    @State private var saveToastMessage = ""
    @State private var saveToastTask: Task<Void, Never>?
    @State private var waterPlanCount = 3
    @State private var waterPlanTimes: [Date] = []
    @State private var overviewRange: WaterOverviewRange = .days7
    @State private var overviewChartProgress: Double = 1
    @State private var inlineSheetVisible = false
    @State private var inlineSheetDragOffset: CGFloat = 0
    @State private var adaptiveSheetHeight: CGFloat = 430
    @State private var waterModeStorageTick = 0
    @State private var displayedWaterMode: WaterOperatingMode
    @State private var waterSnapshot = QuickWaterRenderSnapshot.empty
    @State private var pendingWaterRefreshRequest = QuickWaterRefreshRequest()
    @State private var waterSnapshotRefreshTask: Task<Void, Never>?
    @State private var waterRefreshDelayMilliseconds: UInt64?
    @State private var waterModeTransitionTask: Task<Void, Never>?
    @State private var activeWaterModeTransitionID: UUID?
    @State private var waterModeMaintenanceTask: Task<Void, Never>?
    @State private var waterPlanMaintenanceTask: Task<Void, Never>?
    @State private var waterPlanSaveTask: Task<Void, Never>?
    @State private var isSavingWaterPlan = false
    @State private var waterReminderSchedulingTask: Task<Void, Never>?
    @State private var waterReminderSchedulingID: UUID?
    @State private var carePlanReminderSchedulingTask: Task<Void, Never>?
    @State private var carePlanReminderSchedulingID: UUID?
    @State private var optimisticWaterPlanEvents: [Event] = []
    @State private var waterFeedbackToken: CheckInFeedbackToken?
    @State private var waterChangeFeedbackToken: CheckInFeedbackToken?
    @State private var filterFeedbackToken: CheckInFeedbackToken?
    @State private var feedbackClearTask: Task<Void, Never>?
    @State private var waterActionTask: Task<Void, Never>?
    @State private var inlineSheetDismissTask: Task<Void, Never>?
    @State private var overviewChartReplayTask: Task<Void, Never>?
    @State private var selectedSharedWaterPetIds: Set<UUID> = []
    @Namespace private var waterModeSelectionNamespace

    private enum ActiveSheet: String, Identifiable {
        case waterSettings
        case waterAmount
        case waterPlan
        case filterSettings
        case history
        case waterOverview
        case waterChangeOverview
        case filterOverview

        var id: String { rawValue }

        var usesInlineOverlay: Bool {
            switch self {
            case .waterSettings, .waterAmount, .waterPlan, .filterSettings:
                return true
            case .history, .waterOverview, .waterChangeOverview, .filterOverview:
                return false
            }
        }

        var inlineHeight: CGFloat {
            switch self {
            case .waterAmount:
                return 430
            case .waterPlan:
                return 486
            case .waterSettings:
                return 420
            case .filterSettings:
                return 460
            case .history, .waterOverview, .waterChangeOverview, .filterOverview:
                return 720
            }
        }
    }

    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        allEvents: [Event] = [],
        allPets: [Pet] = [],
        waterCareLogs: [PetCareLog] = []
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.onClose = onClose
        self.allEvents = allEvents
        self.allPets = allPets
        self.waterCareLogs = waterCareLogs
        _displayedWaterMode = State(initialValue: WaterOperatingMode.stored(pet.id) ?? .manual)
    }

    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var isDark: Bool { colorScheme == .dark }
    private var chromeTint: Color { Color.goPrimary }
    private var petKey: String { pet.id.uuidString }
    private var isAquatic: Bool { WaterQuickActionPolicy.isAquatic(species: pet.species) }
    private var sameSpeciesWaterPets: [Pet] {
        let species = normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && normalizedSpecies($0.species) == species }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }
    private var selectedWaterTargets: [Pet] {
        let targets = sameSpeciesWaterPets.filter { selectedSharedWaterPetIds.contains($0.id) }
        return targets.isEmpty ? [pet] : targets
    }
    private var waterChangeTint: Color { Color(hex: CareType.waterChange.accentColorHex) }
    private var filterTint: Color { Color(hex: CareType.filterClean.accentColorHex) }
    private var waterRuleState: QuickWaterRuleSnapshot {
        waterSnapshot.rule
    }
    private var waterMode: WaterOperatingMode {
        _ = waterModeStorageTick
        return isAquatic ? .manual : displayedWaterMode
    }
    private var commandExecutor: QuickWaterCommandExecutor {
        QuickWaterCommandExecutor(context: modelContext)
    }
    private var systemSheetBinding: Binding<ActiveSheet?> {
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

    private var activeInlineSheet: ActiveSheet? {
        nestedInlineSheet ?? (activeSheet?.usesInlineOverlay == true ? activeSheet : nil)
    }

    private var inlineOverlayBlocksBackground: Bool {
        activeInlineSheet != nil
    }

    private var todayWaterLogs: [PetCareLog] {
        waterSnapshot.todayWaterLogs
    }

    private var waterChangeLogs: [PetCareLog] {
        waterSnapshot.waterChangeLogs
    }

    private var filterCleanLogs: [PetCareLog] {
        waterSnapshot.filterCleanLogs
    }

    private var allWaterLogs: [PetCareLog] {
        waterSnapshot.allWaterLogs
    }

    private var lastWaterLog: PetCareLog? { waterSnapshot.lastWaterLog }
    private var waterLogs: [PetCareLog] {
        waterSnapshot.waterLogs
    }

    private var lastWaterChange: PetCareLog? { waterSnapshot.lastWaterChange }
    private var lastFilterClean: PetCareLog? { waterSnapshot.lastFilterClean }
    private var waterElapsedDays: Int { daysSinceDate(lastWaterChange?.date ?? waterChangeAnchorDate) }
    private var filterCleanElapsedDays: Int? { lastFilterClean.map { daysSinceDate($0.date) } }
    private var filterReplaceElapsedDays: Int? { lastFilterClean.map { daysSinceDate($0.date) } }
    private var daysUntilWaterChange: Int { waterIntervalDays - waterElapsedDays }
    private var daysUntilFilterClean: Int? { filterCleanElapsedDays.map { filterCleanIntervalDays - $0 } }
    private var daysUntilFilterReplace: Int? { filterReplaceElapsedDays.map { filterReplaceIntervalDays - $0 } }
    private var isWaterChangeOverdue: Bool { daysUntilWaterChange < 0 }
    private var isFilterCleanOverdue: Bool { (daysUntilFilterClean ?? 1) < 0 }
    private var isFilterReplaceOverdue: Bool { (daysUntilFilterReplace ?? 1) < 0 }
    private var isFilterOverdue: Bool { isFilterCleanOverdue || isFilterReplaceOverdue }
    private var waterChangeStatusTint: Color { isWaterChangeOverdue ? Color.goRed : waterChangeTint }
    private var filterStatusTint: Color { isFilterOverdue ? Color.goRed : filterTint }

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
            selectedSharedWaterPetIds = Set(sameSpeciesWaterPets.map(\.id))
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
        .onChange(of: waterCareLogs.count) { _, _ in
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
            if nestedInlineSheet == nil && activeSheet?.usesInlineOverlay != true {
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
    private func inlineWaterSheetOverlay(_ sheet: ActiveSheet) -> some View {
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

    private var inlineSheetBackdrop: some View {
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

    private var inlineSheetDragGesture: some Gesture {
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

    private func dismissInlineWaterSheet() {
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

    private func openRootWaterSheet(_ sheet: ActiveSheet) {
        nestedInlineSheet = nil
        waterSheetReturnStack.removeAll()
        activeSheet = sheet
    }

    private func openWaterSheet(_ sheet: ActiveSheet) {
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

    private func closeActiveWaterSheet() {
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

    private var header: some View {
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
                Text(isAquatic ? "水体 / 换水 / 滤芯" : "喂水 / 换水 / 滤芯")
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

    private func closeDetail() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var waterModeSelector: some View {
        HStack(spacing: 8) {
            waterModeChip(.manual)
            waterModeChip(.reminder)
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
        .animation(waterModeTransitionAnimation, value: waterMode)
    }

    private func waterModeChip(_ mode: WaterOperatingMode) -> some View {
        let selected = waterMode == mode
        let tint = mode == .manual ? chromeTint : Color.goTeal
        return Button {
            handleWaterModeTap(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode == .manual ? "hand.tap.fill" : "bell.badge.fill")
                    .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(mode == .manual ? "手动" : "计划")
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

    private var waterDashboard: some View {
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
                    Text(isAquatic ? "水体管理" : "今日喂水")
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isAquatic ? "换水、滤芯和水体状态" : waterSubtitle)
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                waterSummaryPill(title: "喂水", value: isAquatic ? "水族" : "\(todayWaterLogs.count)次", tint: chromeTint)
                waterSummaryPill(
                    title: "换水",
                    value: dueText(daysUntil: daysUntilWaterChange),
                    tint: waterChangeStatusTint,
                    isWarning: isWaterChangeOverdue
                )
                waterSummaryPill(
                    title: "滤芯",
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

    private func waterSummaryPill(title: String, value: String, tint: Color, isWarning: Bool = false) -> some View {
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
        .background(isWarning ? Color.goRed.opacity(0.16) : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isWarning ? Color.goRed.opacity(0.62) : Color.clear, lineWidth: 1)
        )
    }

    private var waterHero: some View {
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

    private var coreCards: some View {
        VStack(spacing: 12) {
            waterCard
            waterChangeCard
            filterCard
        }
    }

    private var waterCard: some View {
        WaterCoreCard(
            title: "喂水",
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
            secondaryTitle: isAquatic ? nil : "设置",
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

    private var waterChangeCard: some View {
        WaterCoreCard(
            title: "换水",
            icon: "arrow.2.circlepath",
            tint: waterChangeStatusTint,
            value: dueText(daysUntil: daysUntilWaterChange),
            subtitle: waterChangeSubtitle,
            progress: cycleProgress(elapsed: waterElapsedDays, interval: waterIntervalDays),
            primaryTitle: "记录",
            primaryIcon: "checkmark",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    openRootWaterSheet(.waterChangeOverview)
                    return
                }
                doWaterChange()
            },
            secondaryTitle: "管理",
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

    private var filterCard: some View {
        WaterCoreCard(
            title: "滤芯",
            icon: "sparkles",
            tint: filterStatusTint,
            value: optionalDueText(daysUntilFilterClean),
            subtitle: filterSubtitle,
            progress: cycleProgress(elapsed: filterCleanElapsedDays ?? 0, interval: filterCleanIntervalDays),
            primaryTitle: "清洗",
            primaryIcon: "checkmark",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    openRootWaterSheet(.filterOverview)
                    return
                }
                doFilterClean()
            },
            secondaryTitle: "管理",
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

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Button {
                    openWaterSheet(.history)
                } label: {
                    Text("管理")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(chromeTint)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if allWaterLogs.isEmpty {
                Text("暂无记录")
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
        .background(sheetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var toastView: some View {
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

    private var sheetSurface: some ShapeStyle {
        Color.ohanaCardSurface
    }

    private var waterCardValue: String {
        if isAquatic { return "水族" }
        if waterMode == .reminder {
            if waterRuleState.missedCount > 0 { return "待补 \(waterRuleState.missedCount)" }
            return waterRuleState.completionText
        }
        return "\(todayWaterLogs.count) 次"
    }

    private var waterCardProgress: Double? {
        if isAquatic { return nil }
        if waterMode == .reminder {
            return min(Double(waterRuleState.completedTodayPlanReminders.count) / Double(max(waterRuleState.todayPlanReminders.count, 1)), 1)
        }
        return min(Double(todayWaterLogs.count) / 3, 1)
    }

    private var waterSubtitle: String {
        if isAquatic { return "不做喂水打卡" }
        if waterMode == .reminder {
            if let missed = waterRuleState.missedPlanReminders.first {
                return "待补 \(missed.scheduledAt.formatted(date: .omitted, time: .shortened))"
            }
            if let next = waterRuleState.nextPendingReminder {
                return "下一次 \(next.scheduledAt.formatted(date: .omitted, time: .shortened))"
            }
            return "今日计划 \(waterRuleState.completionText)"
        }
        if let lastWaterLog {
            let amountText = lastWaterLog.amountMl > 0 ? " · \(Int(lastWaterLog.amountMl))ml" : ""
            return "\(relativeDayText(for: lastWaterLog.date))\(amountText)"
        }
        return waterAmountEnabled ? "一键记录 \(Int(defaultWaterAmountMl ?? 250))ml" : "只记录一次"
    }

    private var waterChangeSubtitle: String {
        if isWaterChangeOverdue {
            return "逾期\(abs(daysUntilWaterChange))天 · 立即换水"
        }
        if let lastWaterChange {
            return "\(relativeDayText(for: lastWaterChange.date)) · \(waterIntervalDays)天周期"
        }
        return "\(waterIntervalDays)天周期"
    }

    private var filterSubtitle: String {
        if let daysUntilFilterClean, daysUntilFilterClean < 0 {
            return "清洗逾期\(abs(daysUntilFilterClean))天 · 立即处理"
        }
        if let daysUntilFilterReplace, daysUntilFilterReplace < 0 {
            return "更换逾期\(abs(daysUntilFilterReplace))天 · 立即处理"
        }
        let replaceText = daysUntilFilterReplace.map { "更换 \(dueText(daysUntil: $0))" } ?? "先清洗一次"
        if let lastFilterClean {
            return "\(relativeDayText(for: lastFilterClean.date)) · \(replaceText)"
        }
        return replaceText
    }

    // MARK: - Sheets
    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .waterSettings:
            WaterChangeSettingsSheet(
                tint: waterChangeTint,
                intervalDays: $waterIntervalDays,
                anchorDate: $waterChangeAnchorDate,
                reminderOn: $waterReminderOn,
                nextDateText: waterNextDateText,
                onSave: {
                    startWaterCalendarPlanSave {
                        saveWaterChangePlanToCalendar(toast: "已保存换水周期")
                    }
                },
                onDelete: {
                    waterReminderOn = false
                    startWaterCalendarPlanSave {
                        saveWaterChangePlanToCalendar(toast: "已关闭换水提醒")
                    }
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 70
            )
        case .waterAmount:
            VStack(spacing: 12) {
                if sameSpeciesWaterPets.count > 1 {
                    SharedCareTargetPicker(
                        title: "共同喂水",
                        subtitle: "\(selectedWaterTargets.count)只\(pet.species)",
                        pets: sameSpeciesWaterPets,
                        selectedPetIds: $selectedSharedWaterPetIds,
                        tint: chromeTint
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
                WaterAmountSettingsSheet(
                    tint: chromeTint,
                    amountEnabled: $waterAmountEnabled,
                    amountText: $waterAmountMlText,
                    onSave: {
                        persistWaterAmountSettings()
                        showSaveConfirmation(waterAmountEnabled ? "已保存默认水量" : "已关闭默认水量")
                        dismissInlineWaterSheet()
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesWaterPets.count > 1 ? 420 : 320,
                maxHeight: 620,
                chromePadding: 70
            )
        case .waterPlan:
            VStack(spacing: 12) {
                if sameSpeciesWaterPets.count > 1 {
                    SharedCareTargetPicker(
                        title: "目标宠物",
                        subtitle: "\(selectedWaterTargets.count)只\(pet.species)",
                        pets: sameSpeciesWaterPets,
                        selectedPetIds: $selectedSharedWaterPetIds,
                        tint: Color.goTeal
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
                WaterPlanSettingsSheet(
                    tint: Color.goTeal,
                    count: $waterPlanCount,
                    times: $waterPlanTimes,
                    completionText: waterRuleState.completionText,
                    onCountChange: syncWaterPlanTimesCount,
                    onSave: {
                        startWaterPlanSave()
                    },
                    onDelete: {
                        startWaterCalendarPlanSave {
                            deleteWaterPlanAndSwitchToManual()
                        }
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesWaterPets.count > 1 ? 520 : 430,
                maxHeight: 620,
                chromePadding: 0
            )
        case .filterSettings:
            FilterSettingsSheet(
                tint: filterTint,
                cleanIntervalDays: $filterCleanIntervalDays,
                replaceIntervalDays: $filterReplaceIntervalDays,
                reminderOn: $filterReminderOn,
                nextCleanText: filterNextCleanText,
                nextReplaceText: filterNextReplaceText,
                onSave: {
                    startWaterCalendarPlanSave {
                        syncFilterPlan(showToast: true)
                    }
                },
                onDelete: {
                    filterReminderOn = false
                    startWaterCalendarPlanSave {
                        syncFilterPlan(showToast: true)
                    }
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 360,
                maxHeight: 620,
                chromePadding: 70
            )
        case .history:
            WaterHistorySheet(
                logs: allWaterLogs,
                tintForLog: tint(for:),
                onDelete: deleteLog
            )
        case .waterOverview:
            waterOverviewSheet
        case .waterChangeOverview:
            waterChangeOverviewSheet
        case .filterOverview:
            filterOverviewSheet
        }
    }

    private var waterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewRangePicker(tint: waterMode == .reminder ? Color.goTeal : chromeTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: "今日次数", value: "\(todayWaterLogs.count)", icon: "number.circle.fill", tint: chromeTint)
                    overviewMetric(title: "今日水量", value: todayWaterAmountText, icon: "drop.fill", tint: chromeTint)
                }
                overviewLineChart(
                    title: "饮水趋势",
                    subtitle: waterAmountEnabled ? "按已记录 ml 聚合。" : "当前只记录次数。",
                    points: waterChartPoints,
                    tint: waterMode == .reminder ? Color.goTeal : chromeTint,
                    emptyText: "喂水后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: waterMode == .reminder ? "计划设置" : "水量设置", icon: "gearshape.fill", tint: waterMode == .reminder ? Color.goTeal : chromeTint) {
                        handleWaterSettingsTap()
                    }
                    Button {
                        openWaterSheet(.history)
                    } label: {
                        Label("全部记录", systemImage: "clock.arrow.circlepath")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(chromeTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近喂水")
                let logs = Array(waterLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "drop", text: "还没有喂水记录")
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: chromeTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    private var waterChangeOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewRangePicker(tint: waterChangeStatusTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: "周期", value: "\(waterIntervalDays)天", icon: "repeat", tint: waterChangeStatusTint)
                    overviewMetric(title: "下次", value: waterNextDateText, icon: "calendar", tint: waterChangeStatusTint)
                }
                overviewProgressCard(
                    title: isWaterChangeOverdue ? "换水逾期" : "换水进度",
                    elapsed: waterElapsedDays,
                    interval: waterIntervalDays,
                    tint: waterChangeStatusTint,
                    isWarning: isWaterChangeOverdue
                )
                overviewLineChart(
                    title: "换水记录",
                    subtitle: "按天统计换水次数。",
                    points: careChartPoints(for: .waterChange),
                    tint: waterChangeStatusTint,
                    emptyText: "换水后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: "记录换水", icon: "checkmark", tint: waterChangeStatusTint) { doWaterChange() }
                    Button {
                        openWaterSheet(.waterSettings)
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(waterChangeStatusTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近换水")
                let logs = Array(waterChangeLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "arrow.2.circlepath", text: "还没有换水记录")
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: waterChangeStatusTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    private var filterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewRangePicker(tint: filterStatusTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: "清洗", value: filterNextCleanText, icon: "sparkles", tint: filterStatusTint)
                    overviewMetric(title: "更换", value: filterNextReplaceText, icon: "arrow.triangle.2.circlepath", tint: filterStatusTint)
                }
                overviewProgressCard(
                    title: isFilterOverdue ? "滤芯逾期" : "清洗进度",
                    elapsed: filterCleanElapsedDays ?? 0,
                    interval: filterCleanIntervalDays,
                    tint: filterStatusTint,
                    isWarning: isFilterOverdue
                )
                overviewLineChart(
                    title: "滤芯清洗",
                    subtitle: "按天统计清洗次数。",
                    points: careChartPoints(for: .filterClean),
                    tint: filterStatusTint,
                    emptyText: "清洗滤芯后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: "记录清洗", icon: "checkmark", tint: filterStatusTint) { doFilterClean() }
                    Button {
                        openWaterSheet(.filterSettings)
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(filterStatusTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近清洗")
                let logs = Array(filterCleanLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "sparkles", text: "还没有滤芯清洗记录")
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: filterStatusTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    private func overviewHero(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 24, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func overviewRangePicker(tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(WaterOverviewRange.allCases) { range in
                Button {
                    withAnimation(GoMotion.page) {
                        overviewRange = range
                        overviewChartProgress = 0
                    }
                    scheduleOverviewChartReplay(milliseconds: 60)
                } label: {
                    Text(range.title)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(overviewRange == range ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(overviewRange == range ? tint : Color.ohanaControlFill.opacity(0.5), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func waterSheetTopChrome(_ sheet: ActiveSheet) -> some View {
        HStack(spacing: 12) {
            waterSheetChromeTitle(sheet)
            Spacer(minLength: 12)
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                closeActiveWaterSheet()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    @ViewBuilder
    private func waterSheetChromeTitle(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .waterOverview:
            waterSheetChromeTitleContent(
                icon: "drop.fill",
                title: "喂水总览",
                tint: waterMode == .reminder ? Color.goTeal : chromeTint
            )
        case .waterChangeOverview:
            waterSheetChromeTitleContent(icon: "arrow.2.circlepath", title: "换水总览", tint: waterChangeTint)
        case .filterOverview:
            waterSheetChromeTitleContent(icon: "sparkles", title: "滤芯总览", tint: filterTint)
        default:
            EmptyView()
        }
    }

    private func waterSheetChromeTitleContent(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 30, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(title)
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    private func overviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .waterGlassSurface(cornerRadius: 18, tint: tint, tintOpacity: 0.04)
    }

    private func overviewLineChart(title: String, subtitle: String, points: [WaterChartPoint], tint: Color, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                emptyInlineState(icon: "chart.line.uptrend.xyaxis", text: emptyText)
                    .frame(height: 160)
            } else {
                let yDomain = OhanaChartStyle.yDomain(values: points.map(\.value), includeZero: true)
                OhanaMinimalTrendChart(
                    points: points.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                    yDomain: yDomain,
                    tint: tint,
                    progress: overviewChartProgress
                )
                .frame(height: 128)
                .animation(GoMotion.page, value: overviewChartProgress)
            }
        }
        .padding(.vertical, 8)
    }

    private func overviewProgressCard(
        title: String,
        elapsed: Int,
        interval: Int,
        tint: Color,
        isWarning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                    if isWarning {
                        Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                }
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(isWarning ? Color.goRed : Color.ohanaPrimaryText)
                Spacer()
                Text("\(elapsed)/\(max(interval, 1))天")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * cycleProgress(elapsed: elapsed, interval: interval))
                    }
            }
            .frame(height: 10)
        }
        .padding(16)
        .waterGlassSurface(cornerRadius: 20, tint: tint, tintOpacity: isWarning ? 0.16 : 0.04)
    }

    private func overviewSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.top, 4)
    }

    private func emptyInlineState(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var todayWaterAmountText: String {
        let total = todayWaterLogs.reduce(0) { $0 + $1.amountMl }
        return total > 0 ? "\(Int(total.rounded()))ml" : "--"
    }

    private var waterChartPoints: [WaterChartPoint] {
        chartPoints(for: .watering, useAmountMl: waterAmountEnabled)
    }

    private func careChartPoints(for type: CareType) -> [WaterChartPoint] {
        chartPoints(for: type, useAmountMl: false)
    }

    private func chartPoints(for type: CareType, useAmountMl: Bool) -> [WaterChartPoint] {
        let calendar = Calendar.current
        let dayCount = overviewRange.days
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let logs = waterCareLogs.filter { log in
            log.type == type.rawValue &&
            log.date >= start &&
            log.date < end
        }
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
        return (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let logs = grouped[date] ?? []
            let value = useAmountMl ? logs.reduce(0) { $0 + $1.amountMl } : Double(logs.count)
            return WaterChartPoint(date: date, value: value)
        }
    }

    private var waterNextDateText: String {
        dueDateText(nextCycleDate(lastDate: lastWaterChange?.date, anchorDate: waterChangeAnchorDate, intervalDays: waterIntervalDays))
    }

    private var filterNextCleanText: String {
        guard let lastFilterClean else { return "未记录" }
        return dueDateText(nextCycleDate(lastDate: lastFilterClean.date, anchorDate: lastFilterClean.date, intervalDays: filterCleanIntervalDays))
    }

    private var filterNextReplaceText: String {
        guard let lastFilterClean else { return "未记录" }
        return dueDateText(nextCycleDate(lastDate: lastFilterClean.date, anchorDate: lastFilterClean.date, intervalDays: filterReplaceIntervalDays))
    }

    private func nextCycleDate(lastDate: Date?, anchorDate: Date, intervalDays: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let anchor = calendar.startOfDay(for: anchorDate)
        let last = lastDate.map { calendar.startOfDay(for: $0) }
        let base = max(last ?? anchor, anchor)
        var next = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: base) ?? base
        while next < today {
            next = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: next) ?? next.addingTimeInterval(Double(max(intervalDays, 1)) * 86_400)
        }
        return next
    }

    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        }
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 1 {
            return "明天"
        }
        if days > 1 && days <= 7 {
            return "\(days)天后"
        }
        return date.formatted(.dateTime.month().day())
    }

    // MARK: - Persistence
    private func loadSettings() {
        let defaults = UserDefaults.standard
        let storedWaterInterval = defaults.integer(forKey: "waterInterval_\(petKey)")
        waterIntervalDays = storedWaterInterval > 0 ? storedWaterInterval : 3

        let storedFilterClean = defaults.integer(forKey: "filterCleanInterval_\(petKey)")
        filterCleanIntervalDays = storedFilterClean > 0 ? storedFilterClean : 14

        let storedFilterReplace = defaults.integer(forKey: "filterReplaceInterval_\(petKey)")
        filterReplaceIntervalDays = storedFilterReplace > 0 ? storedFilterReplace : 90

        waterReminderOn = defaults.bool(forKey: "waterReminder_\(petKey)")
        filterReminderOn = defaults.bool(forKey: "filterReminder_\(petKey)")
        waterAmountEnabled = defaults.object(forKey: "waterAmountEnabled_\(petKey)") == nil
            ? true
            : defaults.bool(forKey: "waterAmountEnabled_\(petKey)")
        let storedWaterAmount = defaults.double(forKey: "waterAmountMl_\(petKey)")
        waterAmountMlText = storedWaterAmount > 0 ? String(format: "%.0f", storedWaterAmount) : "250"

        let anchorTimeInterval = defaults.double(forKey: "waterChangeCycleAnchor_\(petKey)")
        if anchorTimeInterval > 0 {
            waterChangeAnchorDate = Date(timeIntervalSince1970: anchorTimeInterval)
        } else {
            waterChangeAnchorDate = Calendar.current.startOfDay(for: Date())
            persistWaterSettings()
        }
    }

    private func persistWaterSettings() {
        commandExecutor.persistWaterSettings(
            pet: pet,
            intervalDays: waterIntervalDays,
            reminderOn: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate
        )
    }

    private func persistWaterAmountSettings() {
        commandExecutor.persistWaterAmountSettings(
            pet: pet,
            enabled: waterAmountEnabled,
            amountMl: defaultWaterAmountMl
        )
    }

    private func persistFilterSettings() {
        commandExecutor.persistFilterSettings(
            pet: pet,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            reminderOn: filterReminderOn
        )
    }

    private func saveWaterChangePlanToCalendar(toast: String) {
        let reminders = commandExecutor.saveWaterChangePlan(
            pet: pet,
            allEvents: allEvents,
            intervalDays: waterIntervalDays,
            reminderOn: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate
        )
        scheduleCarePlanReminders(reminders)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(toast)
    }

    private func syncFilterPlan(showToast: Bool) {
        let reminders = commandExecutor.syncFilterPlan(
            pet: pet,
            allEvents: allEvents,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            reminderOn: filterReminderOn
        )
        scheduleCarePlanReminders(reminders)
        if showToast {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaveConfirmation(filterReminderOn ? "已保存滤芯提醒" : "已保存")
        }
    }

    private func showSaveConfirmation(_ message: String) {
        saveToastTask?.cancel()
        saveToastMessage = message
        withAnimation(GoMotion.feedback) {
            showSaveToast = true
        }
        saveToastTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(GoMotion.quick) {
                    showSaveToast = false
                }
            }
        }
    }

    private func rebuildWaterSnapshot(force: Bool = false) {
        guard force || waterSnapshotRefreshTask == nil else { return }
        performWaterModeUpdatesWithoutAnimation {
            let snapshot = QuickWaterRenderSnapshot.build(
                pet: pet,
                allEvents: allEvents,
                waterCareLogs: waterCareLogs
            )
            waterSnapshot = snapshot
            if !snapshot.rule.planEvents.isEmpty {
                optimisticWaterPlanEvents = []
            }
        }
    }

    private func scheduleWaterSnapshotRefresh(milliseconds: UInt64 = 0, syncModeAfterRefresh: Bool = false) {
        var request: QuickWaterRefreshRequest = .reloadSnapshot
        if syncModeAfterRefresh {
            request.insert(.syncDisplayedMode)
        }
        scheduleDeferredWaterRefresh(request, milliseconds: milliseconds)
    }

    private func scheduleDeferredWaterRefresh(
        _ request: QuickWaterRefreshRequest,
        milliseconds: UInt64 = 0
    ) {
        pendingWaterRefreshRequest.formUnion(request)
        if let currentDelay = waterRefreshDelayMilliseconds,
           waterSnapshotRefreshTask != nil,
           currentDelay <= milliseconds {
            return
        }

        waterSnapshotRefreshTask?.cancel()
        waterRefreshDelayMilliseconds = milliseconds
        waterSnapshotRefreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            let request = pendingWaterRefreshRequest
            pendingWaterRefreshRequest = QuickWaterRefreshRequest()
            waterRefreshDelayMilliseconds = nil
            waterSnapshotRefreshTask = nil
            performDeferredWaterRefresh(request)
        }
    }

    private func performDeferredWaterRefresh(_ request: QuickWaterRefreshRequest) {
        guard !request.isEmpty else { return }
        if request.contains(.reloadSnapshot) {
            rebuildWaterSnapshot(force: true)
        }
        if request.contains(.syncDisplayedMode) {
            syncDisplayedWaterMode(
                animated: activeWaterModeTransitionID == nil,
                force: request.contains(.forceDisplayedMode)
            )
        }
    }

    @discardableResult
    private func scheduleDeferredWaterAction(
        milliseconds: UInt64 = 48,
        _ action: @escaping @MainActor () -> Void
    ) -> Bool {
        guard waterActionTask == nil else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return false
        }
        waterActionTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            action()
            waterActionTask = nil
        }
        return true
    }

    private func scheduleOverviewChartReplay(milliseconds: UInt64) {
        overviewChartReplayTask?.cancel()
        overviewChartReplayTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            withAnimation(GoMotion.page) {
                overviewChartProgress = 1
            }
            overviewChartReplayTask = nil
        }
    }

    // MARK: - Actions
    private func handleWaterModeTap(_ mode: WaterOperatingMode) {
        guard !isAquatic else {
            openRootWaterSheet(.waterOverview)
            return
        }
        guard mode != waterMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        switch mode {
        case .manual:
            activateManualWaterMode()
        case .reminder:
            if latestWaterPlanEvents().isEmpty {
                openWaterPlanSettings()
            } else {
                activateExistingWaterPlanMode()
            }
        }
    }

    private func handleWaterSettingsTap() {
        if waterMode == .reminder {
            openWaterPlanSettings()
        } else {
            openWaterSheet(.waterAmount)
        }
    }

    private func openWaterPlanSettings() {
        let events = latestWaterPlanEvents()
        if events.isEmpty {
            waterPlanCount = 3
            waterPlanTimes = commandExecutor.suggestedWaterPlanTimes(count: waterPlanCount)
        } else {
            waterPlanCount = min(max(events.count, 1), 6)
            waterPlanTimes = commandExecutor.normalizedWaterPlanTimes(events.map(\.startDate), count: waterPlanCount)
        }
        openWaterSheet(.waterPlan)
    }

    private func syncWaterPlanTimesCount(_ count: Int) {
        withAnimation(GoMotion.feedback) {
            waterPlanTimes = commandExecutor.normalizedWaterPlanTimes(waterPlanTimes, count: count)
        }
    }

    private func startWaterPlanSave() {
        guard !isSavingWaterPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingWaterPlan = true
        waterPlanSaveTask?.cancel()
        dismissInlineWaterSheet()
        performWaterModeUpdatesWithoutAnimation {
            displayedWaterMode = .reminder
        }
        UISelectionFeedbackGenerator().selectionChanged()
        waterPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: waterPlanSaveDelayMilliseconds) {
            saveWaterPlan()
        }
    }

    private func startWaterCalendarPlanSave(_ operation: @escaping @MainActor () -> Void) {
        guard !isSavingWaterPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingWaterPlan = true
        waterPlanSaveTask?.cancel()
        dismissInlineWaterSheet()
        UISelectionFeedbackGenerator().selectionChanged()
        waterPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: waterPlanSaveDelayMilliseconds) {
            operation()
            isSavingWaterPlan = false
            waterPlanSaveTask = nil
        }
    }

    private func saveWaterPlan() {
        let result = commandExecutor.saveWaterPlan(
            pet: pet,
            targets: selectedWaterTargets,
            times: waterPlanTimes,
            count: waterPlanCount,
            allEvents: latestAllEvents()
        )
        waterPlanTimes = result.normalizedTimes
        optimisticWaterPlanEvents = result.optimisticPlanEvents
        scheduleWaterReminders(
            result.reminders,
            delayMilliseconds: waterPlanPostSaveReminderDelayMilliseconds,
            requiresReminderMode: true
        )
        scheduleWaterSnapshotRefresh(milliseconds: waterPlanPostSaveSnapshotDelayMilliseconds)
        scheduleWaterPlanMaintenance(delayMilliseconds: waterPlanPostSaveMaintenanceDelayMilliseconds)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        setActiveWaterMode(.reminder)
        showSaveConfirmation(result.targetCount > 1 ? "共同喂水计划已保存 · \(result.targetCount)只" : "已保存喂水计划")
        isSavingWaterPlan = false
        waterPlanSaveTask = nil
    }

    private func activateManualWaterMode() {
        waterReminderSchedulingTask?.cancel()
        waterReminderSchedulingID = nil
        commitWaterModeSideEffects(.manual)
        beginWaterModeVisualTransition(to: .manual) {
            scheduleSettledWaterModeMaintenance(for: .manual) {
                commandExecutor.deactivateWaterPlanReminders(
                    pet: pet,
                    allEvents: latestAllEvents()
                )
                showSaveConfirmation("已切换到手动喂水")
            }
        }
    }

    private func activateExistingWaterPlanMode() {
        let events = latestWaterPlanEvents()
        guard !events.isEmpty else {
            openWaterPlanSettings()
            return
        }
        commitWaterModeSideEffects(.reminder)
        beginWaterModeVisualTransition(to: .reminder) {
            scheduleSettledWaterModeMaintenance(for: .reminder) {
                ensureUpcomingWaterPlanReminders()
                showSaveConfirmation("已切换到喂水计划")
            }
        }
    }

    private func deleteWaterPlanAndSwitchToManual() {
        optimisticWaterPlanEvents = []
        waterReminderSchedulingTask?.cancel()
        waterReminderSchedulingID = nil
        commitWaterModeSideEffects(.manual)
        beginWaterModeVisualTransition(to: .manual, commitWhenUnchanged: true) {
            scheduleSettledWaterModeMaintenance(for: .manual) {
                commandExecutor.deleteWaterPlan(pet: pet, allEvents: latestAllEvents())
                showSaveConfirmation("已删除喂水计划")
            }
        }
    }

    private func setActiveWaterMode(_ mode: WaterOperatingMode) {
        performWaterModeUpdatesWithoutAnimation {
            displayedWaterMode = isAquatic ? .manual : mode
            commitWaterModeSideEffects(mode)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func commitWaterModeSideEffects(_ mode: WaterOperatingMode) {
        commandExecutor.setWaterMode(mode, pet: pet)
        waterModeStorageTick += 1
    }

    private func resolvedWaterModeFromStorageAndSnapshot() -> WaterOperatingMode {
        guard !isAquatic else { return .manual }
        let hasPlan = !latestWaterPlanEvents().isEmpty
        if let storedMode = WaterOperatingMode.stored(pet.id) {
            return storedMode == .reminder && !hasPlan ? .manual : storedMode
        }
        return hasPlan ? .reminder : .manual
    }

    private func syncDisplayedWaterMode(animated: Bool = false, force: Bool = false) {
        guard force || activeWaterModeTransitionID == nil else { return }
        let resolvedMode = resolvedWaterModeFromStorageAndSnapshot()
        guard displayedWaterMode != resolvedMode else { return }
        if animated {
            withAnimation(waterModeTransitionAnimation) {
                displayedWaterMode = resolvedMode
            }
        } else {
            performWaterModeUpdatesWithoutAnimation {
                displayedWaterMode = resolvedMode
            }
        }
    }

    private func beginWaterModeVisualTransition(
        to targetMode: WaterOperatingMode,
        commitWhenUnchanged: Bool = false,
        commitAfterAnimation: @escaping @MainActor () -> Void
    ) {
        let fromMode = waterMode
        guard fromMode != targetMode || commitWhenUnchanged else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        waterModeTransitionTask?.cancel()
        waterModeMaintenanceTask?.cancel()
        waterPlanMaintenanceTask?.cancel()
        let transitionID = UUID()
        activeWaterModeTransitionID = transitionID

        if fromMode != targetMode {
            withAnimation(waterModeTransitionAnimation) {
                displayedWaterMode = targetMode
            }
        }

        UISelectionFeedbackGenerator().selectionChanged()
        scheduleWaterModeTransitionFinish(transitionID: transitionID, commit: commitAfterAnimation)
    }

    private var waterModeTransitionAnimation: Animation {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? GoMotion.page : GoMotion.reduced
    }

    private var waterModeTransitionDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 320 : 120
    }

    private func scheduleWaterModeTransitionFinish(
        transitionID: UUID,
        commit: @escaping @MainActor () -> Void
    ) {
        waterModeTransitionTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: waterModeTransitionDelayMilliseconds)
            guard !Task.isCancelled,
                  activeWaterModeTransitionID == transitionID else { return }

            performWaterModeUpdatesWithoutAnimation {
                activeWaterModeTransitionID = nil
            }
            commit()
            waterModeTransitionTask = nil
        }
    }

    private var waterModeMaintenanceDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 850 : 300
    }

    private var waterPlanPostSaveSnapshotDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 180 : 80
    }

    private var waterPlanSaveDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 120 : 40
    }

    private var waterPlanPostSaveReminderDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 980 : 320
    }

    private var waterPlanPostSaveMaintenanceDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 1_120 : 420
    }

    private func scheduleSettledWaterModeMaintenance(
        for mode: WaterOperatingMode,
        _ maintenance: @escaping @MainActor () -> Void
    ) {
        waterModeMaintenanceTask?.cancel()
        waterModeMaintenanceTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: waterModeMaintenanceDelayMilliseconds)
            guard !Task.isCancelled,
                  activeWaterModeTransitionID == nil,
                  waterMode == mode,
                  !pet.hasPassedAway
            else { return }

            performWaterModeUpdatesWithoutAnimation {
                maintenance()
            }
            scheduleWaterSnapshotRefresh()
            syncDisplayedWaterMode(force: true)
            waterModeMaintenanceTask = nil
        }
    }

    private func scheduleWaterPlanMaintenance(delayMilliseconds: UInt64) {
        guard !pet.hasPassedAway, !isAquatic else { return }
        waterPlanMaintenanceTask?.cancel()
        waterPlanMaintenanceTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard activeWaterModeTransitionID == nil else {
                waterPlanMaintenanceTask = nil
                scheduleWaterPlanMaintenance(delayMilliseconds: waterModeMaintenanceDelayMilliseconds)
                return
            }
            performWaterModeUpdatesWithoutAnimation {
                ensureUpcomingWaterPlanReminders()
            }
            scheduleWaterSnapshotRefresh(milliseconds: 80)
            waterPlanMaintenanceTask = nil
        }
    }

    private func performWaterModeUpdatesWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    private func ensureUpcomingWaterPlanReminders() {
        guard !isAquatic else { return }
        let reminders = commandExecutor.ensureUpcomingWaterPlanReminders(pet: pet, allEvents: latestAllEvents())
        scheduleWaterReminders(reminders, delayMilliseconds: 480, requiresReminderMode: true)
    }

    private func latestAllEvents() -> [Event] {
        commandExecutor.latestAllEvents(fallback: allEvents)
    }

    private func latestWaterPlanEvents() -> [Event] {
        if !waterRuleState.planEvents.isEmpty {
            return waterRuleState.planEvents
        }
        if !optimisticWaterPlanEvents.isEmpty {
            return optimisticWaterPlanEvents
        }
        return commandExecutor.waterPlanEvents(pet: pet, allEvents: allEvents)
    }

    private func scheduleWaterReminders(
        _ reminders: [Reminder],
        delayMilliseconds: UInt64 = 0,
        requiresReminderMode: Bool = false
    ) {
        guard !reminders.isEmpty else { return }
        waterReminderSchedulingTask?.cancel()
        let requestID = UUID()
        waterReminderSchedulingID = requestID
        waterReminderSchedulingTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled,
                  waterReminderSchedulingID == requestID
            else {
                finishWaterReminderScheduling(requestID)
                return
            }
            if requiresReminderMode {
                guard activeWaterModeTransitionID == nil,
                      waterMode == .reminder
                else {
                    finishWaterReminderScheduling(requestID)
                    return
                }
            }
            guard !Task.isCancelled,
                  waterReminderSchedulingID == requestID
            else {
                finishWaterReminderScheduling(requestID)
                return
            }
            await commandExecutor.scheduleReminders(reminders, requestPermission: true)
            finishWaterReminderScheduling(requestID)
        }
    }

    private func finishWaterReminderScheduling(_ requestID: UUID) {
        guard waterReminderSchedulingID == requestID else { return }
        waterReminderSchedulingTask = nil
        waterReminderSchedulingID = nil
    }

    private func scheduleCarePlanReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        carePlanReminderSchedulingTask?.cancel()
        let requestID = UUID()
        carePlanReminderSchedulingID = requestID
        carePlanReminderSchedulingTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 180)
            guard !Task.isCancelled,
                  carePlanReminderSchedulingID == requestID
            else {
                finishCarePlanReminderScheduling(requestID)
                return
            }
            guard !Task.isCancelled,
                  carePlanReminderSchedulingID == requestID
            else {
                finishCarePlanReminderScheduling(requestID)
                return
            }
            await commandExecutor.scheduleReminders(reminders, requestPermission: true)
            finishCarePlanReminderScheduling(requestID)
        }
    }

    private func finishCarePlanReminderScheduling(_ requestID: UUID) {
        guard carePlanReminderSchedulingID == requestID else { return }
        carePlanReminderSchedulingTask = nil
        carePlanReminderSchedulingID = nil
    }

    private func completeNextPlannedWaterOrOpenOverview() {
        guard let reminder = waterRuleState.nextPendingReminder else {
            openRootWaterSheet(.waterOverview)
            return
        }
        guard scheduleDeferredWaterAction({ completePlannedWater(reminder) }) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWaterFeedback()
    }

    private func completePlannedWater(_ reminder: Reminder) {
        let result = commandExecutor.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: defaultWaterAmountMl ?? 0,
            executorId: commandExecutor.activeExecutorId()
        )
        showSaveConfirmation(result.coconutDelta > 0 ? "喂水计划 +\(result.coconutDelta)🥥" : "已完成喂水")
        scheduleWaterPlanMaintenance(delayMilliseconds: 180)
    }

    private func commitWater() {
        guard scheduleDeferredWaterAction(commitWaterBusiness) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWaterFeedback()
    }

    private func commitWaterBusiness() {
        let result = commandExecutor.recordWater(
            pet: pet,
            targets: selectedWaterTargets,
            amountMl: defaultWaterAmountMl ?? 0,
            executorId: commandExecutor.activeExecutorId()
        )
        let actionText = result.targetCount > 1 ? "共同喂水 · \(result.targetCount)只" : "已记录喂水"
        showSaveConfirmation(result.coconutDelta > 0 ? "\(actionText) +\(result.coconutDelta)🥥" : actionText)
    }

    private func doWaterChange() {
        guard scheduleDeferredWaterAction(recordWaterChangeBusiness) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWaterChangeFeedback()
    }

    private func recordWaterChangeBusiness() {
        let reminders = commandExecutor.recordWaterChange(
            pet: pet,
            targets: selectedWaterTargets,
            allEvents: allEvents,
            intervalDays: waterIntervalDays,
            reminderOn: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate,
            executorId: commandExecutor.activeExecutorId()
        )
        scheduleCarePlanReminders(reminders)
        showSaveConfirmation("已记录换水")
    }

    private func doFilterClean() {
        guard scheduleDeferredWaterAction(recordFilterCleanBusiness) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerFilterFeedback()
    }

    private func recordFilterCleanBusiness() {
        let reminders = commandExecutor.recordFilterClean(
            pet: pet,
            targets: selectedWaterTargets,
            allEvents: allEvents,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            reminderOn: filterReminderOn,
            executorId: commandExecutor.activeExecutorId()
        )
        scheduleCarePlanReminders(reminders)
        showSaveConfirmation("滤芯已清洗")
    }

    private func triggerWaterFeedback() {
        let text = defaultWaterAmountMl.map { "+\(Int($0.rounded()))ml" } ?? "+1"
        waterFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: text, tint: waterMode == .reminder ? Color.goTeal : chromeTint)
        scheduleFeedbackClear()
    }

    private func triggerWaterChangeFeedback() {
        waterChangeFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: waterChangeTint)
        scheduleFeedbackClear()
    }

    private func triggerFilterFeedback() {
        filterFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: filterTint)
        scheduleFeedbackClear()
    }

    private func scheduleFeedbackClear() {
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                waterFeedbackToken = nil
                waterChangeFeedbackToken = nil
                filterFeedbackToken = nil
            }
        }
    }

    private func deleteLog(_ log: PetCareLog) {
        guard scheduleDeferredWaterAction({ deleteLogBusiness(log) }) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteLogBusiness(_ log: PetCareLog) {
        switch commandExecutor.deleteLog(log) {
        case .waterChange:
            saveWaterChangePlanToCalendar(toast: "已更新换水周期")
        case .filterClean:
            syncFilterPlan(showToast: false)
        case .other:
            break
        }
    }

    private func normalizedSpecies(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Formatting
    private func daysSinceDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
    }

    private func dueText(daysUntil: Int) -> String {
        if daysUntil > 0 { return "\(daysUntil)天" }
        if daysUntil == 0 { return "今天" }
        return "逾期\(abs(daysUntil))天"
    }

    private func optionalDueText(_ daysUntil: Int?) -> String {
        guard let daysUntil else { return "未记录" }
        return dueText(daysUntil: daysUntil)
    }

    private func cycleProgress(elapsed: Int, interval: Int) -> Double {
        min(Double(max(elapsed, 0)) / Double(max(interval, 1)), 1)
    }

    private func relativeDayText(for date: Date) -> String {
        let days = daysSinceDate(date)
        if days == 0 {
            return "今天"
        }
        return "\(days)天前"
    }

    private func tint(for log: PetCareLog) -> Color {
        if log.type == CareType.waterChange.rawValue {
            return waterChangeTint
        }
        if log.type == CareType.filterClean.rawValue {
            return filterTint
        }
        return chromeTint
    }

    private var parsedWaterAmountMl: Double? {
        Double(waterAmountMlText.replacingOccurrences(of: ",", with: "."))
    }

    private var defaultWaterAmountMl: Double? {
        guard waterAmountEnabled else { return nil }
        guard let amount = parsedWaterAmountMl, amount > 0 else { return 250 }
        return amount
    }

    private var waterPrimaryTitle: String {
        if isAquatic { return "总览" }
        if waterMode == .reminder {
            if waterRuleState.missedCount > 0 { return "补打卡" }
            return waterRuleState.nextPendingReminder == nil ? waterRuleState.completionText : "完成"
        }
        guard let amount = defaultWaterAmountMl else { return "打卡" }
        return "\(Int(amount.rounded()))ml"
    }

    private var waterPrimaryIcon: String {
        if isAquatic { return "chart.line.uptrend.xyaxis" }
        if waterMode == .reminder {
            return waterRuleState.nextPendingReminder == nil ? "checkmark.seal.fill" : "checkmark"
        }
        return "plus"
    }
}
