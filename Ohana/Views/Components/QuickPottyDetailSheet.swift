//
//  QuickPottyDetailSheet.swift
//  Ohana
//
//  Unified poop management: potty, scoop, and litter changes.
//

import SwiftUI
import SwiftData

struct QuickPottyDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    @State private var activeSheet: ActiveSheet?
    @State private var nestedInlineSheet: ActiveSheet?
    @State private var pottySheetReturnStack: [ActiveSheet] = []
    @State private var scoopIntervalDays: Int = 1
    @State private var scoopAnchorDate: Date = Date()
    @State private var scoopReminderOn = false
    @State private var litterChangeIntervalDays: Int = 14
    @State private var litterCycleAnchorDate: Date = Date()
    @State private var litterReminderOn = false
    @State private var showSaveToast = false
    @State private var saveToastMessage = ""
    @State private var saveToastTask: Task<Void, Never>?
    @State private var pottyPlanSaveTask: Task<Void, Never>?
    @State private var isSavingPottyPlan = false
    @State private var showSingleUseNotice = false
    @State private var singleUseNoticeMessage = ""
    @State private var overviewRange: PoopOverviewRange = .days7
    @State private var overviewChartProgress: Double = 1
    @State private var inlineSheetVisible = false
    @State private var inlineSheetDragOffset: CGFloat = 0
    @State private var adaptiveSheetHeight: CGFloat = 430
    @State private var selectedFocus: PottyFocus = .potty
    @State private var pottyFeedbackToken: CheckInFeedbackToken?
    @State private var scoopFeedbackToken: CheckInFeedbackToken?
    @State private var litterFeedbackToken: CheckInFeedbackToken?
    @State private var feedbackClearTask: Task<Void, Never>?
    @State private var selectedSharedPottyPetIds: Set<UUID> = []

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
    private var isCatPet: Bool {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        return text.contains("猫") || text.contains("cat")
    }
    private var sameSpeciesPottyPets: [Pet] {
        let species = normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && normalizedSpecies($0.species) == species }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }
    private var selectedPottyTargets: [Pet] {
        let targets = sameSpeciesPottyPets.filter { selectedSharedPottyPetIds.contains($0.id) }
        return targets.isEmpty ? [pet] : targets
    }
    private var availableFocuses: [PottyFocus] {
        isCatPet ? [.potty, .scoop, .litter] : [.potty]
    }

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
        guard isCatPet else { return Array(pottyItems.prefix(12)) }
        let litterItems = litterLogs.map(PoopLogItem.litter)
        return Array((pottyItems + litterItems).sorted { $0.date > $1.date }.prefix(12))
    }

    private var systemSheetBinding: Binding<ActiveSheet?> {
        Binding(
            get: { activeSheet?.usesInlineOverlay == true ? nil : activeSheet },
            set: { newValue in
                if let newValue {
                    openRootPottySheet(newValue)
                } else if activeSheet?.usesInlineOverlay != true {
                    nestedInlineSheet = nil
                    pottySheetReturnStack.removeAll()
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
                    ZStack {
                        VStack(spacing: 0) {
                            pottySheetTopChrome(sheet)
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
                            inlinePoopSheetOverlay(nestedInlineSheet)
                                .zIndex(40)
                                .ignoresSafeArea(.container, edges: .bottom)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/history uses system sheet
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
            selectedSharedPottyPetIds = Set(sameSpeciesPottyPets.map(\.id))
            guard !pet.hasPassedAway else { return }
            if !isCatPet {
                selectedFocus = .potty
                return
            }
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
        .onChange(of: nestedInlineSheet?.id) { _, _ in
            adaptiveSheetHeight = nestedInlineSheet?.inlineHeight ?? activeSheet?.inlineHeight ?? 430
            inlineSheetDragOffset = 0
            if nestedInlineSheet == nil && activeSheet?.usesInlineOverlay != true {
                inlineSheetVisible = false
            }
        }
        .onDisappear {
            saveToastTask?.cancel()
            feedbackClearTask?.cancel()
            pottyPlanSaveTask?.cancel()
            isSavingPottyPlan = false
        }
        .interactiveDismissDisabled(activeInlineSheet != nil)
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
                    dismissInlinePoopSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    private func dismissInlinePoopSheet() {
        let dismissingSheetID = activeInlineSheet?.id
        withAnimation(GoMotion.page) {
            inlineSheetVisible = false
            inlineSheetDragOffset = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            if nestedInlineSheet?.id == dismissingSheetID {
                nestedInlineSheet = nil
            } else if activeSheet?.id == dismissingSheetID {
                closeActivePottySheet()
            }
        }
    }

    private func openRootPottySheet(_ sheet: ActiveSheet) {
        nestedInlineSheet = nil
        pottySheetReturnStack.removeAll()
        activeSheet = normalizedSheetForPet(sheet)
    }

    private func openPottySheet(_ sheet: ActiveSheet) {
        let sheet = normalizedSheetForPet(sheet)
        if activeSheet?.usesInlineOverlay == false, sheet.usesInlineOverlay {
            nestedInlineSheet = sheet
            return
        }
        if activeSheet?.usesInlineOverlay == true, sheet.usesInlineOverlay {
            activeSheet = sheet
            return
        }

        if let current = activeSheet, current.id != sheet.id {
            pottySheetReturnStack.append(current)
        } else if activeSheet == nil {
            pottySheetReturnStack.removeAll()
        }
        activeSheet = sheet
    }

    private func normalizedSheetForPet(_ sheet: ActiveSheet) -> ActiveSheet {
        guard !isCatPet else { return sheet }
        switch sheet {
        case .scoopCheckIn, .litterChangeCheckIn, .scoopSettings, .litterSettings, .scoopOverview, .litterOverview:
            return .pottyOverview
        case .scoopHistory, .litterHistory:
            return .pottyHistory
        default:
            return sheet
        }
    }

    private func closeActivePottySheet() {
        if nestedInlineSheet != nil {
            nestedInlineSheet = nil
            return
        }
        if let returnSheet = pottySheetReturnStack.popLast() {
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
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("噗噗电台")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button { closeDetail() } label: {
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

    private func closeDetail() {
        if let onClose {
            onClose()
        } else {
            dismiss()
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
                    Text("噗噗电台")
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
                pottySummaryPill(title: isCatPet ? "便便" : "今日", value: "\(todayPottyLogs.count)次", tint: pottyTint)
                if isCatPet {
                    pottySummaryPill(title: "铲屎", value: dueText(daysUntil: daysUntilScoop), tint: scoopTint)
                    pottySummaryPill(title: "猫砂", value: dueText(daysUntil: daysUntilLitterChange), tint: litterTint)
                } else {
                    pottySummaryPill(title: "最近", value: lastPottyLog.map { relativeDayText(for: $0.date) } ?? "暂无", tint: pottyTint)
                    pottySummaryPill(title: "异常", value: "\(Int(last7AbnormalRatio * 100))%", tint: last7AbnormalRatio > 0.3 ? Color.goRed : pottyTint)
                }
            }

            if isCatPet {
                pottyFocusSelector
            }
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
            ForEach(availableFocuses) { focus in
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
        availableFocuses
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
                    openRootPottySheet(.pottyOverview)
                    return
                }
                selectedFocus = .potty
                openPottySheet(.pottyType)
            },
            secondaryTitle: "历史",
            secondaryAction: {
                selectedFocus = .potty
                openPottySheet(.pottyHistory)
            },
            tapAction: {
                selectedFocus = .potty
                openRootPottySheet(.pottyOverview)
            },
            feedbackToken: pottyFeedbackToken
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
                    openRootPottySheet(.scoopOverview)
                    return
                }
                selectedFocus = .scoop
                openPottySheet(.scoopCheckIn)
            },
            secondaryTitle: "管理",
            secondaryAction: {
                selectedFocus = .scoop
                if pet.hasPassedAway {
                    openRootPottySheet(.scoopOverview)
                } else {
                    openPottySheet(.scoopSettings)
                }
            },
            tapAction: {
                selectedFocus = .scoop
                openRootPottySheet(.scoopOverview)
            },
            feedbackToken: scoopFeedbackToken
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
                    openRootPottySheet(.litterOverview)
                    return
                }
                selectedFocus = .litter
                openPottySheet(.litterChangeCheckIn)
            },
            secondaryTitle: "管理",
            secondaryAction: {
                selectedFocus = .litter
                if pet.hasPassedAway {
                    openRootPottySheet(.litterOverview)
                } else {
                    openPottySheet(.litterSettings)
                }
            },
            tapAction: {
                selectedFocus = .litter
                openRootPottySheet(.litterOverview)
            },
            feedbackToken: litterFeedbackToken
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
                    openPottySheet(.history)
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
            .shadow(color: chromeTint.opacity(0.32), radius: 12, y: 6) // ui-v4: allow toast elevation
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
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
            PottyTypeSheet(
                tint: pottyTint,
                unknownGroupTitle: sameSpeciesPottyPets.count > 1 ? "猫砂盆未知便便" : nil,
                onUnknownGroup: sameSpeciesPottyPets.count > 1 ? {
                    logUnknownGroupPotty()
                    dismissInlinePoopSheet()
                } : nil
            ) { type in
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
            VStack(spacing: 12) {
                if sameSpeciesPottyPets.count > 1 {
                    SharedCareTargetPicker(
                        title: "共同铲砂",
                        subtitle: "\(selectedPottyTargets.count)只\(pet.species)",
                        pets: sameSpeciesPottyPets,
                        selectedPetIds: $selectedSharedPottyPetIds,
                        tint: scoopTint
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
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
                        openPottySheet(.scoopSettings)
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesPottyPets.count > 1 ? 430 : 330,
                maxHeight: 620,
                chromePadding: 70
            )
        case .litterChangeCheckIn:
            VStack(spacing: 12) {
                if sameSpeciesPottyPets.count > 1 {
                    SharedCareTargetPicker(
                        title: "共同换砂",
                        subtitle: "\(selectedPottyTargets.count)只\(pet.species)",
                        pets: sameSpeciesPottyPets,
                        selectedPetIds: $selectedSharedPottyPetIds,
                        tint: litterTint
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
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
                        openPottySheet(.litterSettings)
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesPottyPets.count > 1 ? 430 : 330,
                maxHeight: 620,
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
                    startPottyPlanSave {
                        syncScoopPlan(showToast: true)
                    }
                },
                onDelete: {
                    startPottyPlanSave {
                        deleteScoopPlan()
                    }
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
                    startPottyPlanSave {
                        syncLitterChangePlan(showToast: true)
                    }
                },
                onDelete: {
                    startPottyPlanSave {
                        deleteLitterChangePlan()
                    }
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
        .navigationTitle("")
    }

    private var scoopOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                        openPottySheet(.scoopCheckIn)
                    }
                    Button {
                        openPottySheet(.scoopSettings)
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
        .navigationTitle("")
    }

    private var litterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: "周期", value: "\(litterChangeIntervalDays)天", icon: "repeat", tint: litterTint)
                    poopOverviewMetric(title: "下次", value: dueText(daysUntil: daysUntilLitterChange), icon: "calendar", tint: daysUntilLitterChange < 0 ? Color.goRed : litterTint)
                }
                poopProgressBlock(title: "换砂周期", elapsed: litterElapsedDays, interval: litterChangeIntervalDays, tint: litterTint)
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: litterPrimaryTitle, icon: "arrow.2.circlepath", tint: litterTint) {
                        openPottySheet(.litterChangeCheckIn)
                    }
                    Button {
                        openPottySheet(.litterSettings)
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
        .navigationTitle("")
    }

    private var litterHistorySheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                litterHistorySheetContent
            }
            .padding(20)
        }
        .navigationTitle("")
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

    @ViewBuilder
    private func pottySheetTopChrome(_ sheet: ActiveSheet) -> some View {
        HStack(spacing: 12) {
            pottySheetChromeTitle(sheet)
            Spacer(minLength: 12)
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                closeActivePottySheet()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    @ViewBuilder
    private func pottySheetChromeTitle(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .pottyOverview:
            pottySheetChromeTitleContent(icon: "seal.fill", title: "便便总览", tint: pottyTint)
        case .scoopOverview:
            pottySheetChromeTitleContent(icon: "trash.fill", title: "铲屎总览", tint: scoopTint)
        case .litterOverview:
            pottySheetChromeTitleContent(icon: "tray.full.fill", title: "猫砂总览", tint: litterTint)
        case .litterHistory:
            pottySheetChromeTitleContent(icon: "tray.full.fill", title: "换砂历史", tint: litterTint)
        default:
            EmptyView()
        }
    }

    private func pottySheetChromeTitleContent(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 30, height: 34)
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
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
        persistScoopSettings(for: pet)
    }

    private func persistScoopSettings(for target: Pet) {
        let defaults = UserDefaults.standard
        let key = target.id.uuidString
        defaults.set(scoopIntervalDays, forKey: "scoopIntervalDays_\(key)")
        defaults.set(scoopAnchorDate.timeIntervalSince1970, forKey: "scoopAnchorDate_\(key)")
        defaults.set(scoopReminderOn, forKey: "scoopReminder_\(key)")
    }

    private func persistLitterChangeSettings() {
        persistLitterChangeSettings(for: pet)
    }

    private func persistLitterChangeSettings(for target: Pet) {
        let defaults = UserDefaults.standard
        let key = target.id.uuidString
        defaults.set(litterChangeIntervalDays, forKey: "litterChangeInterval_\(key)")
        defaults.set(litterCycleAnchorDate.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(key)")
        defaults.set(litterReminderOn, forKey: "litterReminder_\(key)")
    }

    private func startPottyPlanSave(_ operation: @escaping @MainActor () -> Void) {
        guard !isSavingPottyPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingPottyPlan = true
        pottyPlanSaveTask?.cancel()
        dismissInlinePoopSheet()
        pottyPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: pottyPlanSaveDelayMilliseconds) {
            operation()
            isSavingPottyPlan = false
            pottyPlanSaveTask = nil
        }
    }

    private var pottyPlanSaveDelayMilliseconds: UInt64 {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion ? 120 : 40
    }

    private func syncScoopPlan(showToast: Bool) {
        for target in selectedPottyTargets {
            persistScoopSettings(for: target)
            CarePlanCalendarSync.syncScoopPlan(
                pet: target,
                context: modelContext,
                intervalDays: scoopIntervalDays,
                enabled: scoopReminderOn,
                anchor: scoopAnchorDate
            )
        }
        if scoopReminderOn {
            scheduleCarePlanReminders(titleContains: "铲屎")
        }
        if showToast {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaveConfirmation(scoopReminderOn ? "已保存铲屎提醒" : "已保存")
        }
    }

    private func syncLitterChangePlan(showToast: Bool) {
        for target in selectedPottyTargets {
            persistLitterChangeSettings(for: target)
            CarePlanCalendarSync.syncLitterFullChangePlan(
                pet: target,
                context: modelContext,
                intervalDays: litterChangeIntervalDays,
                enabled: litterReminderOn,
                cycleAnchor: litterCycleAnchorDate
            )
        }
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
        pottyFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: "+1", tint: pottyTint)
        scheduleFeedbackClear()
        showSaveConfirmation(delta > 0 ? "\(type.emoji) +\(delta)🥥" : "已记录便便")
    }

    private func logUnknownGroupPotty() {
        _ = CareEventService.recordUnknownSharedPotty(
            sourcePet: pet,
            targets: selectedPottyTargets,
            type: .perfectPoop,
            context: modelContext,
            executorId: activeExecutorId()
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        pottyFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: "+1", tint: pottyTint)
        scheduleFeedbackClear()
        showSaveConfirmation("已记录猫砂盆事件")
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
        let targets = selectedPottyTargets
        let reward = targets.count > 1
            ? CareEventService.recordSharedLitterCare(
                sourcePet: pet,
                targets: targets,
                context: modelContext,
                executorId: activeExecutorId()
            )
            : CareEventService.recordCare(
                pet: pet,
                type: .litter,
                context: modelContext,
                executorId: activeExecutorId(),
                reward: .potty(isLitter: true)
            )
        syncScoopPlan(showToast: false)
        let delta = reward.humanGot + reward.petGot
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        scoopFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: scoopTint)
        scheduleFeedbackClear()
        let actionText = targets.count > 1 ? "\(targets.count)只猫 已铲" : "已记录铲屎"
        showSaveConfirmation(delta > 0 ? "\(actionText) +\(delta)🥥" : actionText)
    }

    private func doFullChange() {
        let now = Date()
        let defaults = UserDefaults.standard
        defaults.set(now.timeIntervalSince1970, forKey: "lastLitterChangeDate_\(petKey)")
        litterCycleAnchorDate = Calendar.current.startOfDay(for: now)
        defaults.set(litterCycleAnchorDate.timeIntervalSince1970, forKey: "litterChangeCycleAnchor_\(petKey)")

        let targets = selectedPottyTargets
        if todayLitterLogs.isEmpty {
            _ = targets.count > 1
                ? CareEventService.recordSharedLitterCare(
                    sourcePet: pet,
                    targets: targets,
                    context: modelContext,
                    executorId: activeExecutorId(),
                    isFullChange: true
                )
                : CareEventService.recordCare(
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
        litterFeedbackToken = CheckInFeedbackToken(kind: .done, deltaText: "✓", tint: litterTint)
        scheduleFeedbackClear()
        showSaveConfirmation(targets.count > 1 ? "\(targets.count)只猫 已换砂" : "已记录换砂")
    }

    private func scheduleFeedbackClear() {
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.quick) {
                pottyFeedbackToken = nil
                scoopFeedbackToken = nil
                litterFeedbackToken = nil
            }
        }
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

    private func normalizedSpecies(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
