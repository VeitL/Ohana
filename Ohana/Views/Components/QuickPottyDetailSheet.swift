//
//  QuickPottyDetailSheet.swift
//  Ohana
//
//  Unified poop management: potty, scoop, and litter changes.
//

import SwiftUI
import SwiftData
import Charts

struct QuickPottyDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    @State private var activeSheet: ActiveSheet?
    @State private var scoopIntervalDays: Int = 1
    @State private var scoopAnchorDate: Date = Date()
    @State private var scoopReminderOn = false
    @State private var litterChangeIntervalDays: Int = 14
    @State private var litterCycleAnchorDate: Date = Date()
    @State private var litterReminderOn = false
    @State private var showSaveToast = false
    @State private var saveToastMessage = ""
    @State private var saveToastTask: Task<Void, Never>?
    @State private var showSingleUseNotice = false
    @State private var singleUseNoticeMessage = ""
    @State private var overviewRange: PoopOverviewRange = .days7
    @State private var overviewChartProgress: Double = 1
    @State private var inlineSheetVisible = false
    @State private var inlineSheetDragOffset: CGFloat = 0
    @State private var adaptiveSheetHeight: CGFloat = 430
    @State private var selectedFocus: PottyFocus = .potty

    private enum PottyFocus: String, CaseIterable, Identifiable {
        case potty
        case scoop
        case litter

        var id: String { rawValue }
        var title: String {
            switch self {
            case .potty: return "便便"
            case .scoop: return "铲屎"
            case .litter: return "猫砂"
            }
        }
        var icon: String {
            switch self {
            case .potty: return "seal.fill"
            case .scoop: return "trash.fill"
            case .litter: return "tray.full.fill"
            }
        }
    }

    private enum ActiveSheet: String, Identifiable {
        case pottyType
        case scoopCheckIn
        case litterChangeCheckIn
        case scoopSettings
        case litterSettings
        case pottyOverview
        case scoopOverview
        case litterOverview
        case pottyHistory
        case scoopHistory
        case litterHistory
        case history

        var id: String { rawValue }

        var usesInlineOverlay: Bool {
            switch self {
            case .pottyType, .scoopCheckIn, .litterChangeCheckIn, .scoopSettings, .litterSettings:
                return true
            case .pottyOverview, .scoopOverview, .litterOverview, .pottyHistory, .scoopHistory, .litterHistory, .history:
                return false
            }
        }

        var inlineHeight: CGFloat {
            switch self {
            case .pottyType:
                return 430
            case .scoopCheckIn, .litterChangeCheckIn:
                return 390
            case .scoopSettings, .litterSettings:
                return 560
            case .pottyOverview, .scoopOverview, .litterOverview, .pottyHistory, .scoopHistory, .litterHistory, .history:
                return 720
            }
        }
    }

    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var isDark: Bool { colorScheme == .dark }
    private var petKey: String { pet.id.uuidString }
    private var pottyTint: Color { Color(hex: "A66A3F") }
    private var scoopTint: Color { isDark ? Color.goPrimary : Color(hex: CareType.litter.accentColorHex) }
    private var litterTint: Color { Color(hex: "D4A574") }
    private var chromeTint: Color { isDark ? Color.goPrimary : themeColor }

    private var todayPottyLogs: [PetPottyLog] {
        pet.pottyLogs
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var pottyLogs: [PetPottyLog] {
        pet.pottyLogs.sorted { $0.date > $1.date }
    }

    private var litterLogs: [PetCareLog] {
        pet.careLogs
            .filter { $0.type == CareType.litter.rawValue }
            .sorted { $0.date > $1.date }
    }

    private var todayLitterLogs: [PetCareLog] {
        litterLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var recentItems: [PoopLogItem] {
        let pottyItems = pottyLogs.map(PoopLogItem.potty)
        let litterItems = litterLogs.map(PoopLogItem.litter)
        return Array((pottyItems + litterItems).sorted { $0.date > $1.date }.prefix(12))
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

    private var lastPottyLog: PetPottyLog? { pottyLogs.first }
    private var lastScoopLog: PetCareLog? { litterLogs.first }

    private var lastFullChange: Date? {
        let timeInterval = UserDefaults.standard.double(forKey: "lastLitterChangeDate_\(petKey)")
        return timeInterval > 0 ? Date(timeIntervalSince1970: timeInterval) : nil
    }

    private var scoopElapsedDays: Int {
        daysSinceDate(lastScoopLog?.date ?? scoopAnchorDate)
    }

    private var litterElapsedDays: Int {
        daysSinceDate(lastFullChange ?? litterCycleAnchorDate)
    }

    private var daysUntilScoop: Int { scoopIntervalDays - scoopElapsedDays }
    private var daysUntilLitterChange: Int { litterChangeIntervalDays - litterElapsedDays }

    private var last7DaysCounts: [(date: Date, count: Int)] {
        (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let count = pet.pottyLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count
            return (date, count)
        }
        .reversed()
    }

    private var last7AbnormalRatio: Double {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let logs = pet.pottyLogs.filter { $0.date >= start }
        guard !logs.isEmpty else { return 0 }
        let abnormal = logs.filter { $0.pottyType == .softPoop || $0.pottyType == .liquidPoop }.count
        return Double(abnormal) / Double(logs.count)
    }

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
                        pottyDashboard
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
                    inlinePoopSheetOverlay(sheet)
                        .zIndex(40)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: systemSheetBinding) { sheet in
                NavigationStack {
                    sheetContent(sheet)
                        .petMemorialTone(isActive: pet.hasPassedAway)
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
            }
            .alert("今天已经完成了", isPresented: $showSingleUseNotice) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(singleUseNoticeMessage)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .petMemorialTone(isActive: pet.hasPassedAway)
        }
        .onAppear {
            loadSettings()
            guard !pet.hasPassedAway else { return }
            if scoopReminderOn {
                syncScoopPlan(showToast: false)
            }
            if litterReminderOn {
                syncLitterChangePlan(showToast: false)
            }
        }
        .onChange(of: activeSheet?.id) { _, _ in
            adaptiveSheetHeight = activeSheet?.inlineHeight ?? 430
            inlineSheetDragOffset = 0
            if activeSheet?.usesInlineOverlay != true {
                inlineSheetVisible = false
            }
            if activeSheet == .pottyOverview || activeSheet == .scoopOverview || activeSheet == .litterOverview {
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
    private func inlinePoopSheetOverlay(_ sheet: ActiveSheet) -> some View {
        GeometryReader { proxy in
            let bottomInset = CGFloat(8)
            let maxHeight = min(max(sheet.inlineHeight, adaptiveSheetHeight), proxy.size.height * 0.94)
            let panelHeight = min(max(300, adaptiveSheetHeight), maxHeight)
            let horizontalInset = CGFloat(6)
            let panelWidth = max(0, proxy.size.width - horizontalInset * 2)
            let cornerRadius = CGFloat(56)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let hiddenOffset = panelHeight + bottomInset + 64

            ZStack(alignment: .bottom) {
                inlineSheetBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture { dismissInlinePoopSheet() }

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
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { dismissInlinePoopSheet() }
                            .padding(.top, 10)
                            .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background { PoopInlineSheetGlassSurface(cornerRadius: cornerRadius) }
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
                    dismissInlinePoopSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    private func dismissInlinePoopSheet() {
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
                Text("便便 / 铲屎 / 猫砂")
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

    private var poopHero: some View {
        PoopHeroCard(
            tint: pottyTint,
            scoopTint: scoopTint,
            litterTint: litterTint,
            pottyCount: todayPottyLogs.count,
            scoopProgress: cycleProgress(elapsed: scoopElapsedDays, interval: scoopIntervalDays),
            litterProgress: cycleProgress(elapsed: litterElapsedDays, interval: litterChangeIntervalDays),
            abnormalRatio: last7AbnormalRatio
        )
        .frame(height: 132)
    }

    private var pottyDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint(for: selectedFocus).opacity(0.14))
                        .frame(width: 66, height: 66)
                    Image(systemName: selectedFocus.icon)
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(tint(for: selectedFocus))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("便便管理")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pottyDashboardSubtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                pottySummaryPill(title: "便便", value: "\(todayPottyLogs.count)次", tint: pottyTint)
                pottySummaryPill(title: "铲屎", value: dueText(daysUntil: daysUntilScoop), tint: scoopTint)
                pottySummaryPill(title: "猫砂", value: dueText(daysUntil: daysUntilLitterChange), tint: litterTint)
            }

            pottyFocusSelector
        }
        .padding(.vertical, 2)
    }

    private var pottyDashboardSubtitle: String {
        switch selectedFocus {
        case .potty:
            return pottySubtitle
        case .scoop:
            return scoopSubtitle
        case .litter:
            return litterChangeSubtitle
        }
    }

    private var pottyFocusSelector: some View {
        HStack(spacing: 8) {
            ForEach(PottyFocus.allCases) { focus in
                pottyFocusChip(focus)
            }
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    private func pottyFocusChip(_ focus: PottyFocus) -> some View {
        let selected = selectedFocus == focus
        let tint = tint(for: focus)
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedFocus = focus
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: focus.icon)
                    .font(.system(size: 10, weight: .black))
                Text(focus.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
            }
            .foregroundStyle(selected ? Color.arkInk : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? tint : Color.ohanaCardSurfaceElevated, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func pottySummaryPill(title: String, value: String, tint: Color) -> some View {
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

    private func tint(for focus: PottyFocus) -> Color {
        switch focus {
        case .potty:
            return pottyTint
        case .scoop:
            return scoopTint
        case .litter:
            return litterTint
        }
    }

    private var coreCards: some View {
        VStack(spacing: 12) {
            ForEach(coreCardOrder, id: \.rawValue) { focus in
                coreCard(for: focus)
            }
        }
    }

    private var coreCardOrder: [PottyFocus] {
        [.potty, .scoop, .litter]
    }

    @ViewBuilder
    private func coreCard(for focus: PottyFocus) -> some View {
        switch focus {
        case .potty:
            pottyCard
        case .scoop:
            scoopCard
        case .litter:
            litterChangeCard
        }
    }

    private var pottyCard: some View {
        PoopCoreCard(
            title: "便便",
            icon: lastPottyLog?.pottyType.systemIconName ?? "seal.fill",
            tint: pottyTint,
            value: "\(todayPottyLogs.count) 次",
            subtitle: pottySubtitle,
            progress: min(Double(todayPottyLogs.count) / 3, 1),
            primaryTitle: "记录",
            primaryIcon: "plus",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    selectedFocus = .potty
                    activeSheet = .pottyOverview
                    return
                }
                selectedFocus = .potty
                activeSheet = .pottyType
            },
            secondaryTitle: "历史",
            secondaryAction: {
                selectedFocus = .potty
                activeSheet = .pottyHistory
            },
            tapAction: {
                selectedFocus = .potty
                activeSheet = .pottyOverview
            }
        )
    }

    private var scoopCard: some View {
        PoopCoreCard(
            title: "铲屎",
            icon: "trash.fill",
            tint: scoopTint,
            value: dueText(daysUntil: daysUntilScoop),
            subtitle: scoopSubtitle,
            progress: cycleProgress(elapsed: scoopElapsedDays, interval: scoopIntervalDays),
            primaryTitle: scoopPrimaryTitle,
            primaryIcon: "checkmark",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    selectedFocus = .scoop
                    activeSheet = .scoopOverview
                    return
                }
                selectedFocus = .scoop
                activeSheet = .scoopCheckIn
            },
            secondaryTitle: "管理",
            secondaryAction: {
                selectedFocus = .scoop
                activeSheet = pet.hasPassedAway ? .scoopOverview : .scoopSettings
            },
            tapAction: {
                selectedFocus = .scoop
                activeSheet = .scoopOverview
            }
        )
    }

    private var litterChangeCard: some View {
        PoopCoreCard(
            title: "猫砂",
            icon: "tray.full.fill",
            tint: litterTint,
            value: dueText(daysUntil: daysUntilLitterChange),
            subtitle: litterChangeSubtitle,
            progress: cycleProgress(elapsed: litterElapsedDays, interval: litterChangeIntervalDays),
            primaryTitle: litterPrimaryTitle,
            primaryIcon: "arrow.2.circlepath",
            primaryAction: {
                guard !pet.hasPassedAway else {
                    selectedFocus = .litter
                    activeSheet = .litterOverview
                    return
                }
                selectedFocus = .litter
                activeSheet = .litterChangeCheckIn
            },
            secondaryTitle: "管理",
            secondaryAction: {
                selectedFocus = .litter
                activeSheet = pet.hasPassedAway ? .litterOverview : .litterSettings
            },
            tapAction: {
                selectedFocus = .litter
                activeSheet = .litterOverview
            }
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

            if recentItems.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(recentItems.prefix(3))) { item in
                    PoopLogRow(item: item, tint: tint(for: item), showDelete: true) {
                        deleteItem(item)
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

    private var pottySubtitle: String {
        if let lastPottyLog {
            let abnormalPercent = Int(last7AbnormalRatio * 100)
            if abnormalPercent >= 30 {
                return "异常 \(abnormalPercent)% · \(relativeDayText(for: lastPottyLog.date))"
            }
            return "\(lastPottyLog.pottyType.rawValue) · \(relativeDayText(for: lastPottyLog.date))"
        }
        return "记录形态和次数"
    }

    private var scoopSubtitle: String {
        if let lastScoopLog {
            return "\(relativeDayText(for: lastScoopLog.date)) · \(scoopIntervalDays)天周期"
        }
        return "\(scoopIntervalDays)天周期"
    }

    private var litterChangeSubtitle: String {
        if let lastFullChange {
            return "\(relativeDayText(for: lastFullChange)) · \(litterChangeIntervalDays)天周期"
        }
        return "\(litterChangeIntervalDays)天周期"
    }

    private var scoopPrimaryTitle: String {
        if daysUntilScoop < 0 { return "补打卡" }
        if todayLitterLogs.isEmpty { return "打卡" }
        return "已完成"
    }

    private var litterPrimaryTitle: String {
        if daysUntilLitterChange < 0 { return "补打卡" }
        return "换砂"
    }

    private var scoopPlanDetail: String {
        "每\(scoopIntervalDays)天"
    }

    private var litterPlanDetail: String {
        "每\(litterChangeIntervalDays)天"
    }

    private var scoopLastActionText: String {
        lastScoopLog.map { "上次 \(relativeDayText(for: $0.date))" } ?? "还没有打卡"
    }

    private var litterLastActionText: String {
        lastFullChange.map { "上次 \(relativeDayText(for: $0))" } ?? "还没有换砂"
    }

    // MARK: - Sheets
    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .pottyType:
            PottyTypeSheet(tint: pottyTint) { type in
                logPotty(type: type)
                dismissInlinePoopSheet()
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 350,
                maxHeight: 620,
                chromePadding: 70
            )
        case .scoopCheckIn:
            PoopCheckInSheet(
                tint: scoopTint,
                icon: "trash.fill",
                title: "铲屎打卡",
                value: dueText(daysUntil: daysUntilScoop),
                subtitle: scoopSubtitle,
                primaryTitle: scoopPrimaryTitle == "补打卡" ? "补打卡" : (todayLitterLogs.isEmpty ? "完成铲屎" : "今天已完成"),
                secondaryTitle: "编辑计划",
                isPrimaryDisabled: !todayLitterLogs.isEmpty && daysUntilScoop >= 0,
                primaryAction: {
                    recordScoop()
                    dismissInlinePoopSheet()
                },
                secondaryAction: {
                    activeSheet = .scoopSettings
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 70
            )
        case .litterChangeCheckIn:
            PoopCheckInSheet(
                tint: litterTint,
                icon: "tray.full.fill",
                title: "换猫砂",
                value: dueText(daysUntil: daysUntilLitterChange),
                subtitle: litterChangeSubtitle,
                primaryTitle: "记录换砂",
                secondaryTitle: "编辑计划",
                isPrimaryDisabled: false,
                primaryAction: {
                    doFullChange()
                    dismissInlinePoopSheet()
                },
                secondaryAction: {
                    activeSheet = .litterSettings
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 70
            )
        case .scoopSettings:
            PoopCycleSettingsSheet(
                tint: scoopTint,
                icon: "trash.fill",
                title: "铲屎计划",
                subtitle: "编辑 \(pet.name) 的铲屎周期",
                statusTitle: scoopReminderOn ? "提醒已开启" : "仅本地记录",
                statusValue: dueText(daysUntil: daysUntilScoop),
                statusDetail: "\(scoopPlanDetail) · \(scoopLastActionText)",
                intervalRange: 1...14,
                intervalDays: $scoopIntervalDays,
                anchorDate: $scoopAnchorDate,
                reminderOn: $scoopReminderOn,
                onSave: {
                    syncScoopPlan(showToast: true)
                    dismissInlinePoopSheet()
                },
                onDelete: {
                    deleteScoopPlan()
                    dismissInlinePoopSheet()
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 460,
                maxHeight: 720,
                chromePadding: 70
            )
        case .litterSettings:
            PoopCycleSettingsSheet(
                tint: litterTint,
                icon: "tray.full.fill",
                title: "换猫砂计划",
                subtitle: "编辑 \(pet.name) 的整盆换砂周期",
                statusTitle: litterReminderOn ? "提醒已开启" : "仅本地记录",
                statusValue: dueText(daysUntil: daysUntilLitterChange),
                statusDetail: "\(litterPlanDetail) · \(litterLastActionText)",
                intervalRange: 3...60,
                intervalDays: $litterChangeIntervalDays,
                anchorDate: $litterCycleAnchorDate,
                reminderOn: $litterReminderOn,
                onSave: {
                    syncLitterChangePlan(showToast: true)
                    dismissInlinePoopSheet()
                },
                onDelete: {
                    deleteLitterChangePlan()
                    dismissInlinePoopSheet()
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 460,
                maxHeight: 720,
                chromePadding: 70
            )
        case .pottyOverview:
            pottyOverviewSheet
        case .scoopOverview:
            scoopOverviewSheet
        case .litterOverview:
            litterOverviewSheet
        case .pottyHistory:
            PoopHistorySheet(
                title: "便便历史",
                items: pottyLogs.map(PoopLogItem.potty),
                tintForItem: tint(for:),
                onDelete: deleteItem
            )
        case .scoopHistory:
            PoopHistorySheet(
                title: "铲屎历史",
                items: litterLogs.map(PoopLogItem.litter),
                tintForItem: tint(for:),
                onDelete: deleteItem
            )
        case .litterHistory:
            litterHistorySheet
        case .history:
            PoopHistorySheet(
                title: "便便管理记录",
                items: recentItems,
                tintForItem: tint(for:),
                onDelete: deleteItem
            )
        }
    }

    private var pottyOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                poopOverviewHero(icon: "seal.fill", title: "便便总览", subtitle: pottySubtitle, tint: pottyTint)
                poopOverviewRangePicker(tint: pottyTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: "今日次数", value: "\(todayPottyLogs.count)", icon: "number.circle.fill", tint: pottyTint)
                    poopOverviewMetric(title: "异常比例", value: "\(Int(last7AbnormalRatio * 100))%", icon: "exclamationmark.triangle.fill", tint: last7AbnormalRatio > 0.3 ? Color.goRed : pottyTint)
                }
                poopOverviewLineChart(
                    title: "便便趋势",
                    subtitle: "按天统计次数。",
                    points: pottyChartPoints,
                    tint: pottyTint,
                    emptyText: "记录便便后会出现趋势"
                )
                overviewSectionHeader("类型")
                ForEach(pottyTypeSummaries) { summary in
                    poopSummaryRow(icon: summary.icon, title: summary.title, value: "\(summary.count)次", tint: summary.tint)
                }
                overviewSectionHeader("最近便便")
                if pottyLogs.isEmpty {
                    emptyInlineState(icon: "seal", text: "还没有便便记录")
                } else {
                    ForEach(Array(pottyLogs.prefix(8)).map(PoopLogItem.potty)) { item in
                        PoopLogRow(item: item, tint: tint(for: item), showDelete: true) {
                            deleteItem(item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("便便")
    }

    private var scoopOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                poopOverviewHero(icon: "trash.fill", title: "铲屎总览", subtitle: scoopSubtitle, tint: scoopTint)
                poopOverviewRangePicker(tint: scoopTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: "今日", value: todayLitterLogs.isEmpty ? "未完成" : "已完成", icon: "checkmark.seal.fill", tint: scoopTint)
                    poopOverviewMetric(title: "下次", value: dueText(daysUntil: daysUntilScoop), icon: "calendar", tint: daysUntilScoop < 0 ? Color.goRed : scoopTint)
                }
                poopProgressBlock(title: "铲屎周期", elapsed: scoopElapsedDays, interval: scoopIntervalDays, tint: scoopTint)
                poopOverviewLineChart(
                    title: "铲屎记录",
                    subtitle: "按天统计铲屎次数。",
                    points: scoopChartPoints,
                    tint: scoopTint,
                    emptyText: "铲屎后会出现趋势"
                )
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: scoopPrimaryTitle == "已完成" ? "今天已完成" : scoopPrimaryTitle, icon: "checkmark", tint: scoopTint, isDisabled: scoopPrimaryTitle == "已完成") {
                        activeSheet = .scoopCheckIn
                    }
                    Button {
                        activeSheet = .scoopSettings
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(scoopTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近铲屎")
                if litterLogs.isEmpty {
                    emptyInlineState(icon: "trash", text: "还没有铲屎记录")
                } else {
                    ForEach(Array(litterLogs.prefix(8)).map(PoopLogItem.litter)) { item in
                        PoopLogRow(item: item, tint: scoopTint, showDelete: true) {
                            deleteItem(item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("铲屎")
    }

    private var litterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                poopOverviewHero(icon: "tray.full.fill", title: "猫砂总览", subtitle: litterChangeSubtitle, tint: litterTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: "周期", value: "\(litterChangeIntervalDays)天", icon: "repeat", tint: litterTint)
                    poopOverviewMetric(title: "下次", value: dueText(daysUntil: daysUntilLitterChange), icon: "calendar", tint: daysUntilLitterChange < 0 ? Color.goRed : litterTint)
                }
                poopProgressBlock(title: "换砂周期", elapsed: litterElapsedDays, interval: litterChangeIntervalDays, tint: litterTint)
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: litterPrimaryTitle, icon: "arrow.2.circlepath", tint: litterTint) {
                        activeSheet = .litterChangeCheckIn
                    }
                    Button {
                        activeSheet = .litterSettings
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(litterTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近换砂")
                litterHistorySheetContent
            }
            .padding(20)
        }
        .navigationTitle("猫砂")
    }

    private var litterHistorySheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                poopOverviewHero(icon: "tray.full.fill", title: "换砂历史", subtitle: litterChangeSubtitle, tint: litterTint)
                litterHistorySheetContent
            }
            .padding(20)
        }
        .navigationTitle("换砂历史")
    }

    @ViewBuilder
    private var litterHistorySheetContent: some View {
        if let lastFullChange {
            HStack(spacing: 10) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(litterTint)
                    .frame(width: 28, height: 28)
                    .background(litterTint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("整盆换砂")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(relativeDayText(for: lastFullChange))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(lastFullChange, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.vertical, 3)
        } else {
            emptyInlineState(icon: "tray", text: "还没有换砂记录")
        }
    }

    private func poopOverviewHero(icon: String, title: String, subtitle: String, tint: Color) -> some View {
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

    private func poopOverviewRangePicker(tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(PoopOverviewRange.allCases) { range in
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

    private func poopOverviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func poopOverviewLineChart(title: String, subtitle: String, points: [PoopChartPoint], tint: Color, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(subtitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)

            if points.allSatisfy({ $0.value <= 0 }) {
                emptyInlineState(icon: "chart.line.uptrend.xyaxis", text: emptyText)
                    .frame(height: 160)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Value", point.value * overviewChartProgress)
                    )
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0.04)], startPoint: .top, endPoint: .bottom))
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

    private func poopProgressBlock(title: String, elapsed: Int, interval: Int, tint: Color) -> some View {
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private func poopSummaryRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var pottyChartPoints: [PoopChartPoint] {
        let calendar = Calendar.current
        let dayCount = overviewRange.days
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let grouped = Dictionary(grouping: pottyLogs.filter { $0.date >= start }) { calendar.startOfDay(for: $0.date) }
        return (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return PoopChartPoint(date: date, value: Double(grouped[date]?.count ?? 0))
        }
    }

    private var scoopChartPoints: [PoopChartPoint] {
        let calendar = Calendar.current
        let dayCount = overviewRange.days
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let grouped = Dictionary(grouping: litterLogs.filter { $0.date >= start }) { calendar.startOfDay(for: $0.date) }
        return (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return PoopChartPoint(date: date, value: Double(grouped[date]?.count ?? 0))
        }
    }

    private var pottyTypeSummaries: [PoopTypeSummary] {
        PottyType.allCases.compactMap { type in
            let count = pottyLogs.filter { $0.pottyType == type }.count
            guard count > 0 else { return nil }
            return PoopTypeSummary(title: type.rawValue, icon: type.systemIconName, count: count, tint: pottyTypeColor(type))
        }
    }

    // MARK: - Persistence
    private func loadSettings() {
        let defaults = UserDefaults.standard

        let storedScoopInterval = defaults.integer(forKey: "scoopIntervalDays_\(petKey)")
        scoopIntervalDays = storedScoopInterval > 0 ? storedScoopInterval : 1
        scoopReminderOn = defaults.bool(forKey: "scoopReminder_\(petKey)")
        let storedScoopAnchor = defaults.double(forKey: "scoopAnchorDate_\(petKey)")
        if storedScoopAnchor > 0 {
            scoopAnchorDate = Date(timeIntervalSince1970: storedScoopAnchor)
        } else {
            scoopAnchorDate = Calendar.current.startOfDay(for: Date())
            defaults.set(scoopAnchorDate.timeIntervalSince1970, forKey: "scoopAnchorDate_\(petKey)")
        }

        let storedLitterInterval = defaults.integer(forKey: "litterChangeInterval_\(petKey)")
        litterChangeIntervalDays = storedLitterInterval > 0 ? storedLitterInterval : 14
        litterReminderOn = defaults.bool(forKey: "litterReminder_\(petKey)")
        let storedLitterAnchor = defaults.double(forKey: "litterChangeCycleAnchor_\(petKey)")
        if storedLitterAnchor > 0 {
            litterCycleAnchorDate = Date(timeIntervalSince1970: storedLitterAnchor)
        } else {
            litterCycleAnchorDate = Calendar.current.startOfDay(for: Date())
            defaults.set(litterCycleAnchorDate.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(petKey)")
        }
    }

    private func persistScoopSettings() {
        let defaults = UserDefaults.standard
        defaults.set(scoopIntervalDays, forKey: "scoopIntervalDays_\(petKey)")
        defaults.set(scoopAnchorDate.timeIntervalSince1970, forKey: "scoopAnchorDate_\(petKey)")
        defaults.set(scoopReminderOn, forKey: "scoopReminder_\(petKey)")
    }

    private func persistLitterChangeSettings() {
        let defaults = UserDefaults.standard
        defaults.set(litterChangeIntervalDays, forKey: "litterChangeInterval_\(petKey)")
        defaults.set(litterCycleAnchorDate.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(petKey)")
        defaults.set(litterReminderOn, forKey: "litterReminder_\(petKey)")
    }

    private func syncScoopPlan(showToast: Bool) {
        persistScoopSettings()
        CarePlanCalendarSync.syncScoopPlan(
            pet: pet,
            context: modelContext,
            intervalDays: scoopIntervalDays,
            enabled: scoopReminderOn,
            anchor: scoopAnchorDate
        )
        if scoopReminderOn {
            scheduleCarePlanReminders(titleContains: "铲屎")
        }
        if showToast {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaveConfirmation(scoopReminderOn ? "已保存铲屎提醒" : "已保存")
        }
    }

    private func syncLitterChangePlan(showToast: Bool) {
        persistLitterChangeSettings()
        CarePlanCalendarSync.syncLitterFullChangePlan(
            pet: pet,
            context: modelContext,
            intervalDays: litterChangeIntervalDays,
            enabled: litterReminderOn,
            cycleAnchor: litterCycleAnchorDate
        )
        if litterReminderOn {
            scheduleCarePlanReminders(titleContains: "猫砂")
        }
        if showToast {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaveConfirmation(litterReminderOn ? "已保存换砂提醒" : "已保存")
        }
    }

    private func deleteScoopPlan() {
        scoopReminderOn = false
        syncScoopPlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("铲屎计划已删除")
    }

    private func deleteLitterChangePlan() {
        litterReminderOn = false
        syncLitterChangePlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("换砂计划已删除")
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
    private func logPotty(type: PottyType) {
        let reward = CareEventService.recordPotty(
            pet: pet,
            type: type,
            context: modelContext,
            executorId: activeExecutorId()
        )
        let delta = reward.humanGot + reward.petGot
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(delta > 0 ? "\(type.emoji) +\(delta)🥥" : "已记录便便")
    }

    private func doScoop() {
        guard !todayLitterLogs.isEmpty else {
            recordScoop()
            return
        }
        singleUseNoticeMessage = "\(pet.name) 今天已经铲屎过了，这类操作一天记录一次就够了。需要修改记录的话，可以在下方最近记录中删除。"
        showSingleUseNotice = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func recordScoop() {
        let reward = CareEventService.recordCare(
            pet: pet,
            type: .litter,
            context: modelContext,
            executorId: activeExecutorId(),
            reward: .potty(isLitter: true)
        )
        syncScoopPlan(showToast: false)
        let delta = reward.humanGot + reward.petGot
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(delta > 0 ? "铲屎 +\(delta)🥥" : "已记录铲屎")
    }

    private func doFullChange() {
        let now = Date()
        let defaults = UserDefaults.standard
        defaults.set(now.timeIntervalSince1970, forKey: "lastLitterChangeDate_\(petKey)")
        litterCycleAnchorDate = Calendar.current.startOfDay(for: now)
        defaults.set(litterCycleAnchorDate.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(petKey)")

        if todayLitterLogs.isEmpty {
            _ = CareEventService.recordCare(
                pet: pet,
                type: .litter,
                context: modelContext,
                executorId: activeExecutorId(),
                reward: .potty(isLitter: true)
            )
        }
        syncScoopPlan(showToast: false)
        syncLitterChangePlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation("已记录换砂")
    }

    private func deleteItem(_ item: PoopLogItem) {
        switch item {
        case .potty(let log):
            modelContext.delete(log)
            modelContext.safeSave()
        case .litter(let log):
            modelContext.delete(log)
            modelContext.safeSave()
            syncScoopPlan(showToast: false)
        }
    }

    private func activeExecutorId() -> String? {
        UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func latestAllEvents() -> [Event] {
        let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate)])
        return (try? modelContext.fetch(descriptor)) ?? allEvents
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
            await ReminderSchedulingService.scheduleManyIfNeeded(
                reminders: reminders,
                context: modelContext,
                source: .detail
            )
        }
    }

    // MARK: - Formatting
    private func daysSinceDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
    }

    private func relativeDayText(for date: Date) -> String {
        let days = daysSinceDate(date)
        if days == 0 { return "今天" }
        return "\(days)天前"
    }

    private func dueText(daysUntil: Int) -> String {
        if daysUntil > 0 { return "\(daysUntil)天" }
        if daysUntil == 0 { return "今天" }
        return "逾期\(abs(daysUntil))天"
    }

    private func cycleProgress(elapsed: Int, interval: Int) -> Double {
        min(Double(max(elapsed, 0)) / Double(max(interval, 1)), 1)
    }

    private func tint(for item: PoopLogItem) -> Color {
        switch item {
        case .potty(let log):
            return pottyTypeColor(log.pottyType)
        case .litter:
            return scoopTint
        }
    }

    private func pottyTypeColor(_ type: PottyType) -> Color {
        switch type {
        case .perfectPoop: return pottyTint
        case .softPoop: return Color(hex: "F59E0B")
        case .liquidPoop: return Color(hex: "EF4444")
        case .pee: return Color(hex: "06B6D4")
        }
    }
}
