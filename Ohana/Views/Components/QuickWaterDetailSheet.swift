//
//  QuickWaterDetailSheet.swift
//  Ohana
//
//  Water management sheet: feed water, water changes, and filter care.
//

import SwiftUI
import SwiftData
import Charts

struct QuickWaterDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    @State private var waterIntervalDays: Int = 3
    @State private var waterChangeAnchorDate: Date = Date()
    @State private var filterCleanIntervalDays: Int = 14
    @State private var filterReplaceIntervalDays: Int = 90
    @State private var waterAmountEnabled = true
    @State private var waterAmountMlText = "250"
    @State private var waterReminderOn = false
    @State private var filterReminderOn = false
    @State private var activeSheet: ActiveSheet?
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
                return 620
            case .waterSettings:
                return 420
            case .filterSettings:
                return 460
            case .history, .waterOverview, .waterChangeOverview, .filterOverview:
                return 720
            }
        }
    }

    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var isDark: Bool { colorScheme == .dark }
    private var chromeTint: Color { Color.goPrimary }
    private var petKey: String { pet.id.uuidString }
    private var isAquatic: Bool { WaterQuickActionPolicy.isAquatic(species: pet.species) }
    private var waterChangeTint: Color { Color(hex: CareType.waterChange.accentColorHex) }
    private var filterTint: Color { Color(hex: CareType.filterClean.accentColorHex) }
    private var waterRuleState: WaterRuleState {
        WaterRuleState(pet: pet, allEvents: allEvents)
    }
    private var waterMode: WaterOperatingMode {
        isAquatic ? .manual : waterRuleState.operatingMode
    }
    private var systemSheetBinding: Binding<ActiveSheet?> {
        Binding(
            get: { activeSheet?.usesInlineOverlay == true ? nil : activeSheet },
            set: { newValue in
                if let newValue {
                    activeSheet = newValue
                } else if activeSheet?.usesInlineOverlay != true {
                    activeSheet = nil
                }
            }
        )
    }

    private var inlineOverlayBlocksBackground: Bool {
        activeSheet?.usesInlineOverlay == true
    }

    private var todayWaterLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var waterChangeLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.waterChange.rawValue }
            .sorted { $0.date > $1.date }
    }

    private var filterCleanLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.filterClean.rawValue }
            .sorted { $0.date > $1.date }
    }

    private var allWaterLogs: [PetCareLog] {
        pet.careLogs
            .filter {
                $0.type == CareType.watering.rawValue ||
                $0.type == CareType.waterChange.rawValue ||
                $0.type == CareType.filterClean.rawValue
            }
            .sorted { $0.date > $1.date }
    }

    private var lastWaterLog: PetCareLog? { todayWaterLogs.first ?? waterLogs.first }
    private var waterLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.watering.rawValue }
            .sorted { $0.date > $1.date }
    }

    private var lastWaterChange: PetCareLog? { waterChangeLogs.first }
    private var lastFilterClean: PetCareLog? { filterCleanLogs.first }
    private var waterElapsedDays: Int { daysSinceDate(lastWaterChange?.date ?? waterChangeAnchorDate) }
    private var filterCleanElapsedDays: Int? { lastFilterClean.map { daysSinceDate($0.date) } }
    private var filterReplaceElapsedDays: Int? { lastFilterClean.map { daysSinceDate($0.date) } }
    private var daysUntilWaterChange: Int { waterIntervalDays - waterElapsedDays }
    private var daysUntilFilterClean: Int? { filterCleanElapsedDays.map { filterCleanIntervalDays - $0 } }
    private var daysUntilFilterReplace: Int? { filterReplaceElapsedDays.map { filterReplaceIntervalDays - $0 } }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        waterDashboard
                        coreCards
                        recentStrip
                        removeQuickActionFooter
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
                    sheetContent(sheet)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                                    activeSheet = nil
                                }
                            }
                        }
                }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.ohanaCardSurface)
                    .presentationCornerRadius(30)
                    .presentationContentInteraction(.scrolls)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear {
            loadSettings()
            ensureUpcomingWaterPlanReminders()
            if filterReminderOn {
                syncFilterPlan(showToast: false)
            }
        }
        .onChange(of: allEvents.count) { _, _ in
            ensureUpcomingWaterPlanReminders()
        }
        .onChange(of: activeSheet?.id) { _, _ in
            adaptiveSheetHeight = activeSheet?.inlineHeight ?? 430
            inlineSheetDragOffset = 0
            if activeSheet?.usesInlineOverlay != true {
                inlineSheetVisible = false
            }
            if activeSheet == .waterOverview || activeSheet == .waterChangeOverview || activeSheet == .filterOverview {
                overviewChartProgress = 0
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    withAnimation(GoMotion.page) {
                        overviewChartProgress = 1
                    }
                }
            }
        }
        .interactiveDismissDisabled(activeSheet?.usesInlineOverlay == true)
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
                .shadow(color: Color.black.opacity(inlineSheetVisible ? 0.56 : 0), radius: 48, x: 0, y: -18)
                .shadow(color: Color(hex: "0B102C").opacity(inlineSheetVisible ? 0.46 : 0), radius: 28, x: 0, y: 12)
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
            Color.black.opacity(inlineSheetVisible ? 0.16 : 0)
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(inlineSheetVisible ? 0.26 : 0)],
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
        let dismissingSheetID = activeSheet?.id
        withAnimation(GoMotion.page) {
            inlineSheetVisible = false
            inlineSheetDragOffset = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            if activeSheet?.id == dismissingSheetID {
                activeSheet = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                if let data = pet.avatarImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(pet.avatarEmoji)
                        .font(.system(size: 24))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isAquatic ? "水体 / 换水 / 滤芯" : "喂水 / 换水 / 滤芯")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { dismiss() } label: {
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

    private var waterModeSelector: some View {
        HStack(spacing: 8) {
            waterModeChip(.manual)
            waterModeChip(.reminder)
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    private func waterModeChip(_ mode: WaterOperatingMode) -> some View {
        let selected = waterMode == mode
        let tint = mode == .manual ? chromeTint : Color.goTeal
        return Button {
            handleWaterModeTap(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode == .manual ? "hand.tap.fill" : "bell.badge.fill")
                    .font(.system(size: 10, weight: .black))
                Text(mode == .manual ? "手动" : "计划")
                    .font(.system(size: 12, weight: .black, design: .rounded))
            }
            .foregroundStyle(selected ? Color.arkInk : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? tint : Color.ohanaCardSurfaceElevated, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var waterDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((waterMode == .reminder ? Color.goTeal : chromeTint).opacity(0.14))
                        .frame(width: 66, height: 66)
                    Image(systemName: isAquatic ? "water.waves" : "drop.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(waterMode == .reminder ? Color.goTeal : chromeTint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(isAquatic ? "水体管理" : "今日喂水")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isAquatic ? "换水、滤芯和水体状态" : waterSubtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                waterSummaryPill(title: "喂水", value: isAquatic ? "水族" : "\(todayWaterLogs.count)次", tint: chromeTint)
                waterSummaryPill(title: "换水", value: dueText(daysUntil: daysUntilWaterChange), tint: waterChangeTint)
                waterSummaryPill(title: "滤芯", value: optionalDueText(daysUntilFilterClean), tint: filterTint)
            }

            if !isAquatic {
                waterModeSelector
            }
        }
        .padding(.vertical, 2)
    }

    private func waterSummaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                if isAquatic {
                    activeSheet = .waterOverview
                } else if waterMode == .reminder {
                    completeNextPlannedWaterOrOpenOverview()
                } else {
                    commitWater()
                }
            },
            secondaryTitle: isAquatic ? nil : "设置",
            secondaryAction: isAquatic ? nil : { handleWaterSettingsTap() },
            tapAction: { activeSheet = .waterOverview }
        )
    }

    private var waterChangeCard: some View {
        WaterCoreCard(
            title: "换水",
            icon: "arrow.2.circlepath",
            tint: waterChangeTint,
            value: dueText(daysUntil: daysUntilWaterChange),
            subtitle: waterChangeSubtitle,
            progress: cycleProgress(elapsed: waterElapsedDays, interval: waterIntervalDays),
            primaryTitle: "记录",
            primaryIcon: "checkmark",
            primaryAction: { doWaterChange() },
            secondaryTitle: "管理",
            secondaryAction: { activeSheet = .waterSettings },
            tapAction: { activeSheet = .waterChangeOverview }
        )
    }

    private var filterCard: some View {
        WaterCoreCard(
            title: "滤芯",
            icon: "sparkles",
            tint: filterTint,
            value: optionalDueText(daysUntilFilterClean),
            subtitle: filterSubtitle,
            progress: cycleProgress(elapsed: filterCleanElapsedDays ?? 0, interval: filterCleanIntervalDays),
            primaryTitle: "清洗",
            primaryIcon: "checkmark",
            primaryAction: { doFilterClean() },
            secondaryTitle: "管理",
            secondaryAction: { activeSheet = .filterSettings },
            tapAction: { activeSheet = .filterOverview }
        )
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Button {
                    activeSheet = .history
                } label: {
                    Text("管理")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(chromeTint)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if allWaterLogs.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(chromeTint, in: Capsule())
            .shadow(color: chromeTint.opacity(0.32), radius: 12, y: 6)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var removeQuickActionFooter: some View {
        VStack(spacing: 14) {
            Divider().opacity(0.35)
            Button(role: .destructive) {
                onRemove()
                dismiss()
            } label: {
                Text("移除此快捷入口")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.goRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 4)
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
        if let lastWaterChange {
            return "\(relativeDayText(for: lastWaterChange.date)) · \(waterIntervalDays)天周期"
        }
        return "\(waterIntervalDays)天周期"
    }

    private var filterSubtitle: String {
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
                    saveWaterChangePlanToCalendar(toast: "已保存换水周期")
                    dismissInlineWaterSheet()
                },
                onDelete: {
                    waterReminderOn = false
                    saveWaterChangePlanToCalendar(toast: "已关闭换水提醒")
                    dismissInlineWaterSheet()
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 70
            )
        case .waterAmount:
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
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 320,
                maxHeight: 560,
                chromePadding: 70
            )
        case .waterPlan:
            WaterPlanSettingsSheet(
                tint: Color.goTeal,
                count: $waterPlanCount,
                times: $waterPlanTimes,
                completionText: waterRuleState.completionText,
                onCountChange: syncWaterPlanTimesCount,
                onSave: {
                    saveWaterPlan()
                    dismissInlineWaterSheet()
                },
                onDelete: {
                    switchToManualWaterMode()
                    dismissInlineWaterSheet()
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 520,
                maxHeight: 820,
                chromePadding: 70
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
                    syncFilterPlan(showToast: true)
                    dismissInlineWaterSheet()
                },
                onDelete: {
                    filterReminderOn = false
                    syncFilterPlan(showToast: true)
                    dismissInlineWaterSheet()
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
                overviewHero(icon: "drop.fill", title: "喂水总览", subtitle: waterMode == .reminder ? "计划 \(waterRuleState.completionText)" : waterSubtitle, tint: waterMode == .reminder ? Color.goTeal : chromeTint)
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
                        activeSheet = .history
                    } label: {
                        Label("全部记录", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .black, design: .rounded))
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
        .navigationTitle("喂水")
    }

    private var waterChangeOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewHero(icon: "arrow.2.circlepath", title: "换水总览", subtitle: waterChangeSubtitle, tint: waterChangeTint)
                overviewRangePicker(tint: waterChangeTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: "周期", value: "\(waterIntervalDays)天", icon: "repeat", tint: waterChangeTint)
                    overviewMetric(title: "下次", value: waterNextDateText, icon: "calendar", tint: waterChangeTint)
                }
                overviewProgressCard(title: "换水进度", elapsed: waterElapsedDays, interval: waterIntervalDays, tint: waterChangeTint)
                overviewLineChart(
                    title: "换水记录",
                    subtitle: "按天统计换水次数。",
                    points: careChartPoints(for: .waterChange),
                    tint: waterChangeTint,
                    emptyText: "换水后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: "记录换水", icon: "checkmark", tint: waterChangeTint) { doWaterChange() }
                    Button {
                        activeSheet = .waterSettings
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(waterChangeTint)
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
                        WaterLogRow(log: log, tint: waterChangeTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("换水")
    }

    private var filterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewHero(icon: "sparkles", title: "滤芯总览", subtitle: filterSubtitle, tint: filterTint)
                overviewRangePicker(tint: filterTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: "清洗", value: filterNextCleanText, icon: "sparkles", tint: filterTint)
                    overviewMetric(title: "更换", value: filterNextReplaceText, icon: "arrow.triangle.2.circlepath", tint: filterTint)
                }
                overviewProgressCard(title: "清洗进度", elapsed: filterCleanElapsedDays ?? 0, interval: filterCleanIntervalDays, tint: filterTint)
                overviewLineChart(
                    title: "滤芯清洗",
                    subtitle: "按天统计清洗次数。",
                    points: careChartPoints(for: .filterClean),
                    tint: filterTint,
                    emptyText: "清洗滤芯后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: "记录清洗", icon: "checkmark", tint: filterTint) { doFilterClean() }
                    Button {
                        activeSheet = .filterSettings
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(filterTint)
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
                        WaterLogRow(log: log, tint: filterTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("滤芯")
    }

    private func overviewHero(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        withAnimation(GoMotion.page) {
                            overviewChartProgress = 1
                        }
                    }
                } label: {
                    Text(range.title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(overviewRange == range ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(overviewRange == range ? tint : Color.ohanaControlFill.opacity(0.5), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func overviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
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
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                emptyInlineState(icon: "chart.line.uptrend.xyaxis", text: emptyText)
                    .frame(height: 160)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Value", point.value * overviewChartProgress)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.32), tint.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Value", point.value * overviewChartProgress)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 160)
            }
        }
        .padding(.vertical, 8)
    }

    private func overviewProgressCard(title: String, elapsed: Int, interval: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(elapsed)/\(max(interval, 1))天")
                    .font(.system(size: 13, weight: .black, design: .rounded))
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
        .waterGlassSurface(cornerRadius: 20, tint: tint, tintOpacity: 0.04)
    }

    private func overviewSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.top, 4)
    }

    private func emptyInlineState(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
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
        let logs = pet.careLogs.filter { log in
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
        let defaults = UserDefaults.standard
        defaults.set(waterIntervalDays, forKey: "waterInterval_\(petKey)")
        defaults.set(waterChangeAnchorDate.timeIntervalSince1970, forKey: "waterChangeCycleAnchor_\(petKey)")
        defaults.set(waterReminderOn, forKey: "waterReminder_\(petKey)")
    }

    private func persistWaterAmountSettings() {
        let defaults = UserDefaults.standard
        defaults.set(waterAmountEnabled, forKey: "waterAmountEnabled_\(petKey)")
        if let amount = defaultWaterAmountMl {
            defaults.set(amount, forKey: "waterAmountMl_\(petKey)")
        }
    }

    private func persistFilterSettings() {
        let defaults = UserDefaults.standard
        defaults.set(filterCleanIntervalDays, forKey: "filterCleanInterval_\(petKey)")
        defaults.set(filterReplaceIntervalDays, forKey: "filterReplaceInterval_\(petKey)")
        defaults.set(filterReminderOn, forKey: "filterReminder_\(petKey)")
    }

    private func saveWaterChangePlanToCalendar(toast: String) {
        persistWaterSettings()
        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: modelContext,
            intervalDays: waterIntervalDays,
            enabled: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate
        )
        scheduleCarePlanReminders(titleContains: "换水")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(toast)
    }

    private func syncFilterPlan(showToast: Bool) {
        persistFilterSettings()
        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: modelContext,
            cleanIntervalDays: filterCleanIntervalDays,
            replaceIntervalDays: filterReplaceIntervalDays,
            enabled: filterReminderOn
        )
        scheduleCarePlanReminders(titleContains: "滤芯")
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

    // MARK: - Actions
    private func handleWaterModeTap(_ mode: WaterOperatingMode) {
        guard !isAquatic else {
            activeSheet = .waterOverview
            return
        }
        guard mode != waterMode else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        switch mode {
        case .manual:
            switchToManualWaterMode()
        case .reminder:
            if latestWaterPlanEvents().isEmpty {
                openWaterPlanSettings()
            } else {
                ensureUpcomingWaterPlanReminders()
                UISelectionFeedbackGenerator().selectionChanged()
                showSaveConfirmation("已切换到喂水计划")
            }
        }
    }

    private func handleWaterSettingsTap() {
        if waterMode == .reminder {
            openWaterPlanSettings()
        } else {
            activeSheet = .waterAmount
        }
    }

    private func openWaterPlanSettings() {
        let events = latestWaterPlanEvents()
        if events.isEmpty {
            waterPlanCount = 3
            waterPlanTimes = WaterPlanWriter.suggestedTimes(count: waterPlanCount)
        } else {
            waterPlanCount = min(max(events.count, 1), 6)
            waterPlanTimes = WaterPlanWriter.normalizedTimes(events.map(\.startDate), count: waterPlanCount)
        }
        activeSheet = .waterPlan
    }

    private func syncWaterPlanTimesCount(_ count: Int) {
        withAnimation(GoMotion.feedback) {
            waterPlanTimes = WaterPlanWriter.normalizedTimes(waterPlanTimes, count: count)
        }
    }

    private func saveWaterPlan() {
        let normalized = WaterPlanWriter.normalizedTimes(waterPlanTimes, count: waterPlanCount)
        waterPlanTimes = normalized
        let reminders = WaterPlanWriter.replacePlan(
            pet: pet,
            times: normalized,
            allEvents: latestAllEvents(),
            context: modelContext
        )
        scheduleWaterReminders(reminders)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("已保存喂水计划")
    }

    private func switchToManualWaterMode() {
        WaterPlanWriter.deletePlan(pet: pet, allEvents: latestAllEvents(), context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("已切换到手动喂水")
    }

    private func ensureUpcomingWaterPlanReminders() {
        guard !isAquatic else { return }
        let reminders = WaterPlanWriter.ensureUpcomingReminders(pet: pet, allEvents: latestAllEvents(), context: modelContext)
        scheduleWaterReminders(reminders)
    }

    private func latestAllEvents() -> [Event] {
        var descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        descriptor.fetchLimit = 0
        return (try? modelContext.fetch(descriptor)) ?? allEvents
    }

    private func latestWaterPlanEvents() -> [Event] {
        WaterPlanWriter.planEvents(pet: pet, allEvents: latestAllEvents())
    }

    private func scheduleWaterReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            guard await NotificationManager.shared.requestPermission() else { return }
            await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: modelContext, source: .detail)
        }
    }

    private func scheduleCarePlanReminders(titleContains text: String) {
        let reminders = latestAllEvents()
            .filter { event in
                event.relatedEntityId == pet.id.uuidString &&
                event.title.contains(text)
            }
            .flatMap(\.reminders)
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            guard await NotificationManager.shared.requestPermission() else { return }
            await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: modelContext, source: .detail)
        }
    }

    private func completeNextPlannedWaterOrOpenOverview() {
        guard let reminder = waterRuleState.nextPendingReminder else {
            activeSheet = .waterOverview
            return
        }
        let reward = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: defaultWaterAmountMl ?? 0,
            context: modelContext,
            executorId: activeExecutorId()
        )
        let delta = (reward?.humanGot ?? 0) + (reward?.petGot ?? 0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(delta > 0 ? "喂水计划 +\(delta)🥥" : "已完成喂水")
        ensureUpcomingWaterPlanReminders()
    }

    private func commitWater() {
        let executorId = activeExecutorId()
        let reward = CareEventService.recordCare(
            pet: pet,
            type: .watering,
            amountMl: defaultWaterAmountMl ?? 0,
            context: modelContext,
            executorId: executorId,
            reward: .water
        )
        let delta = reward.humanGot + reward.petGot
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(delta > 0 ? "喂水 +\(delta)🥥" : "已记录喂水")
    }

    private func doWaterChange() {
        let executorId = activeExecutorId()
        _ = CareEventService.recordCare(
            pet: pet,
            type: .waterChange,
            context: modelContext,
            executorId: executorId,
            reward: .general(
                humanReward: 15,
                petReward: 20,
                emoji: CareType.waterChange.emoji,
                title: "\(pet.name) 换水奖励"
            )
        )
        persistWaterSettings()
        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: modelContext,
            intervalDays: waterIntervalDays,
            enabled: waterReminderOn,
            cycleAnchor: waterChangeAnchorDate
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("已记录换水")
    }

    private func doFilterClean() {
        let executorId = activeExecutorId()
        _ = CareEventService.recordCare(
            pet: pet,
            type: .filterClean,
            context: modelContext,
            executorId: executorId,
            reward: .general(
                humanReward: 25,
                petReward: 40,
                emoji: CareType.filterClean.emoji,
                title: "\(pet.name) 清理滤材报酬"
            )
        )
        syncFilterPlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("滤芯已清洗")
    }

    private func deleteLog(_ log: PetCareLog) {
        modelContext.delete(log)
        modelContext.safeSave()
        if log.type == CareType.waterChange.rawValue {
            saveWaterChangePlanToCalendar(toast: "已更新换水周期")
        } else if log.type == CareType.filterClean.rawValue {
            syncFilterPlan(showToast: false)
        }
    }

    private func activeExecutorId() -> String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
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

private enum WaterOverviewRange: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        }
    }

    var title: String {
        switch self {
        case .days7: return "7天"
        case .days30: return "30天"
        case .days90: return "90天"
        }
    }
}

private struct WaterChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

private struct WaterNativeSheetGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.clear)
            .glassEffect(.regular.interactive(false), in: shape)
    }
}

private struct WaterInlineSheetGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.clear)
            .glassEffect(.regular.interactive(false), in: shape)
    }
}

private struct WaterPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private extension View {
    func waterGlassSurface(cornerRadius: CGFloat, tint: Color = .white, tintOpacity: Double = 0.04) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.ohanaCardSurface.opacity(0.62))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            )
    }
}

private struct WaterCoreCard: View {
    let title: String
    let icon: String
    let tint: Color
    let value: String
    let subtitle: String
    let progress: Double?
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var tapAction: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var surface: some ShapeStyle {
        Color.ohanaCardSurface
    }

    var body: some View {
        HStack(spacing: 14) {
            tappableInfo

            VStack(spacing: 8) {
                Button(action: primaryAction) {
                    HStack(spacing: 5) {
                        Image(systemName: primaryIcon)
                            .font(.system(size: 11, weight: .black))
                        Text(primaryTitle)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(minWidth: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .frame(minWidth: 72)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tappableInfo: some View {
        if let tapAction {
            Button(action: tapAction) {
                infoContent
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            infoContent
        }
    }

    private var infoContent: some View {
        HStack(spacing: 14) {
            ZStack {
                if let progress {
                    WaterProgressRing(progress: progress, tint: tint)
                        .frame(width: 58, height: 58)
                } else {
                    Circle()
                        .stroke(tint.opacity(0.2), lineWidth: 7)
                        .frame(width: 58, height: 58)
                }
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }
}

private struct WaterProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(GoMotion.page, value: progress)
        }
    }
}

private struct WaterHeroCard: View {
    let tint: Color
    let secondaryTint: Color
    let waterCount: Int
    let waterDueProgress: Double
    let filterDueProgress: Double
    let isAquatic: Bool

    @State private var ripple = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ohanaCardSurface)

            HStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(tint.opacity(0.16 - Double(index) * 0.03), lineWidth: 2)
                            .frame(width: ripple ? 98 + CGFloat(index * 18) : 62 + CGFloat(index * 10))
                            .opacity(ripple ? 0.18 : 0.58)
                            .animation(
                                .easeInOut(duration: 1.9 + Double(index) * 0.18).repeatForever(autoreverses: true),
                                value: ripple
                            )
                    }

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(tint.opacity(0.68), lineWidth: 4)
                            .frame(width: 86, height: 54)
                            .offset(y: 12)
                        Capsule()
                            .fill(tint.opacity(0.28))
                            .frame(width: 68, height: 16)
                            .offset(y: 9)
                        Image(systemName: isAquatic ? "water.waves" : "drop.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(tint)
                            .offset(y: -12)
                    }
                }
                .frame(width: 118, height: 100)

                VStack(alignment: .leading, spacing: 10) {
                    Text(isAquatic ? "水体状态" : "今日饮水")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(isAquatic ? "管理" : "\(waterCount) 次")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                    HStack(spacing: 12) {
                        MiniWaterGauge(title: "换水", progress: waterDueProgress, tint: tint)
                        MiniWaterGauge(title: "滤芯", progress: filterDueProgress, tint: secondaryTint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
        }
        .onAppear { ripple = true }
    }
}

private struct MiniWaterGauge: View {
    let title: String
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(tint.opacity(0.2))
                .frame(width: 34, height: 8)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, 34 * min(max(progress, 0), 1)), height: 8)
                }
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }
}

private struct WaterLogRow: View {
    let log: PetCareLog
    let tint: Color
    var showDelete = true
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.careType.systemIconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(log.careType.label)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if log.amountMl > 0 {
                    Text("\(Int(log.amountMl))ml")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            Spacer()
            Text(log.date, format: .dateTime.month().day().hour().minute())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.55))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, 3)
    }
}

private struct WaterAmountSettingsSheet: View {
    let tint: Color
    @Binding var amountEnabled: Bool
    @Binding var amountText: String
    let onSave: () -> Void

    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("喂水")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text(amountEnabled ? "默认 \(displayAmount)ml" : "只记录次数")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Toggle(isOn: $amountEnabled.animation(GoMotion.feedback)) {
                settingsRow("记录水量", value: amountEnabled ? "开" : "关")
            }
            .tint(tint)

            if amountEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("默认水量")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("250", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .submitLabel(.done)
                            .onSubmit { amountFocused = false }
                        Text("ml")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([100, 150, 200, 250, 300, 500], id: \.self) { amount in
                                Button {
                                    withAnimation(GoMotion.feedback) {
                                        amountText = "\(amount)"
                                        amountFocused = false
                                    }
                                } label: {
                                    Text("\(amount)ml")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            Button {
                amountFocused = false
                onSave()
            } label: {
                Text("保存")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(tint, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { amountFocused = false }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
    }

    private var displayAmount: Int {
        Int((Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 250).rounded())
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

private struct WaterChangeSettingsSheet: View {
    let tint: Color
    @Binding var intervalDays: Int
    @Binding var anchorDate: Date
    @Binding var reminderOn: Bool
    let nextDateText: String
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            settingsHero(icon: "arrow.2.circlepath", title: "换水计划", value: "下次 \(nextDateText)")

            Stepper(value: $intervalDays.animation(GoMotion.feedback), in: 1...30) {
                settingsRow("周期", value: "\(intervalDays)天")
            }
            .tint(tint)

            DatePicker("起算日", selection: $anchorDate, displayedComponents: .date)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow("日历提醒", value: reminderOn ? "开" : "关")
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
    }

    private func settingsHero(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

private struct FilterSettingsSheet: View {
    let tint: Color
    @Binding var cleanIntervalDays: Int
    @Binding var replaceIntervalDays: Int
    @Binding var reminderOn: Bool
    let nextCleanText: String
    let nextReplaceText: String
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("滤芯计划")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("清洗 \(nextCleanText) · 更换 \(nextReplaceText)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Stepper(value: $cleanIntervalDays.animation(GoMotion.feedback), in: 1...60) {
                settingsRow("清洗", value: "\(cleanIntervalDays)天")
            }
            .tint(tint)

            Stepper(value: $replaceIntervalDays.animation(GoMotion.feedback), in: 7...365) {
                settingsRow("更换", value: "\(replaceIntervalDays)天")
            }
            .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow("提醒", value: reminderOn ? "开" : "关")
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

private struct WaterPlanSettingsSheet: View {
    let tint: Color
    @Binding var count: Int
    @Binding var times: [Date]
    let completionText: String
    let onCountChange: (Int) -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 54, height: 54)
                        .background(tint.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("喂水计划")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text("今日 \(completionText) · 每天 \(count) 次")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }

                Stepper(value: $count.animation(GoMotion.feedback), in: 1...6) {
                    settingsRow("每日次数", value: "\(count)次")
                }
                .tint(tint)
                .onChange(of: count) { _, newValue in
                    onCountChange(newValue)
                }

                VStack(spacing: 10) {
                    ForEach(0..<count, id: \.self) { index in
                        DatePicker(
                            "第 \(index + 1) 次",
                            selection: Binding(
                                get: { time(at: index) },
                                set: { setTime($0, at: index) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tint(tint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("切回手动")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        onSave()
                    } label: {
                        Text("保存计划")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private func time(at index: Int) -> Date {
        if index < times.count {
            return times[index]
        }
        return WaterPlanWriter.suggestedTimes(count: count)[min(index, max(count - 1, 0))]
    }

    private func setTime(_ date: Date, at index: Int) {
        while times.count <= index {
            times.append(WaterPlanWriter.suggestedTimes(count: count)[min(times.count, max(count - 1, 0))])
        }
        times[index] = date
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }
}

private struct WaterHistorySheet: View {
    let logs: [PetCareLog]
    let tintForLog: (PetCareLog) -> Color
    let onDelete: (PetCareLog) -> Void

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    Text("暂无记录")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: tintForLog(log), showDelete: true) {
                            onDelete(log)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("水管理记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
