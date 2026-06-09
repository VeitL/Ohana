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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

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
        func title(_ l: L10n) -> String {
            switch self {
            case .potty: return l.tr(zh: "噗噗", en: "Poop", de: "Häufchen")
            case .scoop: return l.tr(zh: "铲砂", en: "Scoop", de: "Schaufeln")
            case .litter: return l.tr(zh: "猫砂", en: "Litter", de: "Streu")
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
    private var l: L10n { L10n(appLanguage) }
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
            .alert(l.tr(zh: "今天已经完成了", en: "Already done today", de: "Heute schon erledigt"), isPresented: $showSingleUseNotice) {
                Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {}
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
                Text(l.tr(zh: "噗噗电台", en: "Poop Radio", de: "Häufchen-Radio"))
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
                    Text(l.tr(zh: "噗噗电台", en: "Poop Radio", de: "Häufchen-Radio"))
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
                pottySummaryPill(title: isCatPet ? l.tr(zh: "噗噗", en: "Poop", de: "Häufchen") : l.tr(zh: "今日", en: "Today", de: "Heute"), value: timesText(todayPottyLogs.count), tint: pottyTint)
                if isCatPet {
                    pottySummaryPill(title: l.tr(zh: "铲砂", en: "Scoop", de: "Klo"), value: dueText(daysUntil: daysUntilScoop), tint: scoopTint)
                    pottySummaryPill(title: l.tr(zh: "猫砂", en: "Litter", de: "Streu"), value: dueText(daysUntil: daysUntilLitterChange), tint: litterTint)
                } else {
                    pottySummaryPill(title: l.tr(zh: "最近", en: "Latest", de: "Zuletzt"), value: lastPottyLog.map { relativeDayText(for: $0.date) } ?? l.tr(zh: "暂无", en: "None", de: "Keine"), tint: pottyTint)
                    pottySummaryPill(title: l.tr(zh: "留意", en: "Watch", de: "Achten"), value: "\(Int(last7AbnormalRatio * 100))%", tint: last7AbnormalRatio > 0.3 ? Color.goRed : pottyTint)
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
                Text(focus.title(l))
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
            title: l.tr(zh: "噗噗", en: "Poop", de: "Häufchen"),
            icon: lastPottyLog?.pottyType.systemIconName ?? "seal.fill",
            tint: pottyTint,
            value: timesText(todayPottyLogs.count),
            subtitle: pottySubtitle,
            progress: min(Double(todayPottyLogs.count) / 3, 1),
            primaryTitle: l.tr(zh: "记录", en: "Log", de: "Loggen"),
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
            secondaryTitle: l.tr(zh: "历史", en: "History", de: "Verlauf"),
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
            title: l.tr(zh: "铲砂", en: "Scoop", de: "Schaufeln"),
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
            secondaryTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
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
            title: l.tr(zh: "猫砂", en: "Litter", de: "Streu"),
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
            secondaryTitle: l.tr(zh: "管理", en: "Manage", de: "Verwalten"),
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
                Text(l.tr(zh: "最近", en: "Latest", de: "Zuletzt"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Button {
                    openPottySheet(.history)
                } label: {
                    Text(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(chromeTint)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if recentItems.isEmpty {
                Text(l.tr(zh: "暂无记录", en: "No logs yet", de: "Noch keine Einträge"))
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
                return l.tr(
                    zh: "留意 \(abnormalPercent)% · \(relativeDayText(for: lastPottyLog.date))",
                    en: "Watch \(abnormalPercent)% · \(relativeDayText(for: lastPottyLog.date))",
                    de: "Auffällig \(abnormalPercent)% · \(relativeDayText(for: lastPottyLog.date))"
                )
            }
            return "\(lastPottyLog.pottyType.localizedLabel(l)) · \(relativeDayText(for: lastPottyLog.date))"
        }
        return l.tr(zh: "记录形态和次数", en: "Track shape and rhythm", de: "Form und Rhythmus erfassen")
    }

    private var scoopSubtitle: String {
        if let lastScoopLog {
            return "\(relativeDayText(for: lastScoopLog.date)) · \(cycleText(scoopIntervalDays))"
        }
        return cycleText(scoopIntervalDays)
    }

    private var litterChangeSubtitle: String {
        if let lastFullChange {
            return "\(relativeDayText(for: lastFullChange)) · \(cycleText(litterChangeIntervalDays))"
        }
        return cycleText(litterChangeIntervalDays)
    }

    private var scoopNeedsCatchUp: Bool {
        daysUntilScoop < 0
    }

    private var scoopDoneToday: Bool {
        !todayLitterLogs.isEmpty && daysUntilScoop >= 0
    }

    private var scoopPrimaryTitle: String {
        if scoopNeedsCatchUp { return l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen") }
        if todayLitterLogs.isEmpty { return l.tr(zh: "打卡", en: "Check in", de: "Eintragen") }
        return l.tr(zh: "已完成", en: "Done", de: "Erledigt")
    }

    private var litterPrimaryTitle: String {
        if daysUntilLitterChange < 0 { return l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen") }
        return l.tr(zh: "换砂", en: "Change litter", de: "Streu wechseln")
    }

    private var scoopPlanDetail: String {
        everyDaysText(scoopIntervalDays)
    }

    private var litterPlanDetail: String {
        everyDaysText(litterChangeIntervalDays)
    }

    private var scoopLastActionText: String {
        lastScoopLog.map {
            l.tr(zh: "上次 \(relativeDayText(for: $0.date))", en: "Last \(relativeDayText(for: $0.date))", de: "Zuletzt \(relativeDayText(for: $0.date))")
        } ?? l.tr(zh: "还没有打卡", en: "No scoop yet", de: "Noch nicht gereinigt")
    }

    private var litterLastActionText: String {
        lastFullChange.map {
            l.tr(zh: "上次 \(relativeDayText(for: $0))", en: "Last \(relativeDayText(for: $0))", de: "Zuletzt \(relativeDayText(for: $0))")
        } ?? l.tr(zh: "还没有换砂", en: "No litter change yet", de: "Noch kein Streuwechsel")
    }

    // MARK: - Sheets
    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .pottyType:
            PottyTypeSheet(
                tint: pottyTint,
                unknownGroupTitle: sameSpeciesPottyPets.count > 1 ? l.tr(zh: "猫砂盆未知噗噗", en: "Mystery litter-box poop", de: "Unbekanntes Klo-Häufchen") : nil,
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
                        title: l.tr(zh: "共同铲砂", en: "Scoop together", de: "Gemeinsam reinigen"),
                        subtitle: petCountText(selectedPottyTargets.count, species: pet.species),
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
                    title: l.tr(zh: "铲砂打卡", en: "Scoop check-in", de: "Klo-Check-in"),
                    value: dueText(daysUntil: daysUntilScoop),
                    subtitle: scoopSubtitle,
                    primaryTitle: scoopNeedsCatchUp ? l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen") : (todayLitterLogs.isEmpty ? l.tr(zh: "完成铲砂", en: "Scoop done", de: "Klo sauber") : l.tr(zh: "今天已完成", en: "Done today", de: "Heute erledigt")),
                    secondaryTitle: l.tr(zh: "编辑计划", en: "Edit plan", de: "Plan ändern"),
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
                        title: l.tr(zh: "共同换砂", en: "Change together", de: "Gemeinsam wechseln"),
                        subtitle: petCountText(selectedPottyTargets.count, species: pet.species),
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
                    title: l.tr(zh: "换猫砂", en: "Change litter", de: "Streu wechseln"),
                    value: dueText(daysUntil: daysUntilLitterChange),
                    subtitle: litterChangeSubtitle,
                    primaryTitle: l.tr(zh: "记录换砂", en: "Log change", de: "Wechsel loggen"),
                    secondaryTitle: l.tr(zh: "编辑计划", en: "Edit plan", de: "Plan ändern"),
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
                title: l.tr(zh: "铲砂计划", en: "Scoop plan", de: "Klo-Plan"),
                subtitle: l.tr(zh: "编辑 \(pet.name) 的铲砂周期", en: "Edit \(pet.name)'s scoop rhythm", de: "\(pet.name)s Klo-Rhythmus ändern"),
                statusTitle: scoopReminderOn ? l.tr(zh: "提醒已开启", en: "Reminder on", de: "Erinnerung an") : l.tr(zh: "仅本地记录", en: "Local only", de: "Nur lokal"),
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
                title: l.tr(zh: "换猫砂计划", en: "Litter-change plan", de: "Streuwechsel-Plan"),
                subtitle: l.tr(zh: "编辑 \(pet.name) 的整盆换砂周期", en: "Edit \(pet.name)'s full litter-change rhythm", de: "\(pet.name)s Streuwechsel-Rhythmus ändern"),
                statusTitle: litterReminderOn ? l.tr(zh: "提醒已开启", en: "Reminder on", de: "Erinnerung an") : l.tr(zh: "仅本地记录", en: "Local only", de: "Nur lokal"),
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
                title: l.tr(zh: "噗噗历史", en: "Poop history", de: "Häufchen-Verlauf"),
                items: pottyLogs.map(PoopLogItem.potty),
                tintForItem: tint(for:),
                onDelete: deleteItem
            )
        case .scoopHistory:
            PoopHistorySheet(
                title: l.tr(zh: "铲砂历史", en: "Scoop history", de: "Klo-Verlauf"),
                items: litterLogs.map(PoopLogItem.litter),
                tintForItem: tint(for:),
                onDelete: deleteItem
            )
        case .litterHistory:
            litterHistorySheet
        case .history:
            PoopHistorySheet(
                title: l.tr(zh: "噗噗节目单", en: "Poop Radio log", de: "Häufchen-Radio-Log"),
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
                    poopOverviewMetric(title: l.tr(zh: "今日次数", en: "Today", de: "Heute"), value: "\(todayPottyLogs.count)", icon: "number.circle.fill", tint: pottyTint)
                    poopOverviewMetric(title: l.tr(zh: "留意比例", en: "Watch rate", de: "Auffällig"), value: "\(Int(last7AbnormalRatio * 100))%", icon: "exclamationmark.triangle.fill", tint: last7AbnormalRatio > 0.3 ? Color.goRed : pottyTint)
                }
                poopOverviewLineChart(
                    title: l.tr(zh: "噗噗趋势", en: "Poop trend", de: "Häufchen-Trend"),
                    subtitle: l.tr(zh: "按天统计次数。", en: "Daily count.", de: "Tageszahlen."),
                    points: pottyChartPoints,
                    tint: pottyTint,
                    emptyText: l.tr(zh: "记录噗噗后会出现趋势", en: "Log poop to see the trend", de: "Logge Häufchen für den Trend")
                )
                overviewSectionHeader(l.tr(zh: "类型", en: "Types", de: "Typen"))
                ForEach(pottyTypeSummaries) { summary in
                    poopSummaryRow(icon: summary.icon, title: summary.title, value: timesText(summary.count), tint: summary.tint)
                }
                overviewSectionHeader(l.tr(zh: "最近噗噗", en: "Latest poop", de: "Neueste Häufchen"))
                if pottyLogs.isEmpty {
                    emptyInlineState(icon: "seal", text: l.tr(zh: "还没有噗噗记录", en: "No poop logs yet", de: "Noch keine Häufchen"))
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
                    poopOverviewMetric(title: l.tr(zh: "今日", en: "Today", de: "Heute"), value: todayLitterLogs.isEmpty ? l.tr(zh: "未完成", en: "Open", de: "Offen") : l.tr(zh: "已完成", en: "Done", de: "Erledigt"), icon: "checkmark.seal.fill", tint: scoopTint)
                    poopOverviewMetric(title: l.tr(zh: "下次", en: "Next", de: "Nächstes"), value: dueText(daysUntil: daysUntilScoop), icon: "calendar", tint: daysUntilScoop < 0 ? Color.goRed : scoopTint)
                }
                poopProgressBlock(title: l.tr(zh: "铲砂周期", en: "Scoop rhythm", de: "Klo-Rhythmus"), elapsed: scoopElapsedDays, interval: scoopIntervalDays, tint: scoopTint)
                poopOverviewLineChart(
                    title: l.tr(zh: "铲砂记录", en: "Scoop logs", de: "Klo-Einträge"),
                    subtitle: l.tr(zh: "按天统计铲砂次数。", en: "Daily scoop count.", de: "Reinigungen pro Tag."),
                    points: scoopChartPoints,
                    tint: scoopTint,
                    emptyText: l.tr(zh: "铲砂后会出现趋势", en: "Scoop to see the trend", de: "Reinigen zeigt den Trend")
                )
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: scoopDoneToday ? l.tr(zh: "今天已完成", en: "Done today", de: "Heute erledigt") : scoopPrimaryTitle, icon: "checkmark", tint: scoopTint, isDisabled: scoopDoneToday) {
                        openPottySheet(.scoopCheckIn)
                    }
                    Button {
                        openPottySheet(.scoopSettings)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(scoopTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近铲砂", en: "Latest scoops", de: "Letzte Reinigungen"))
                if litterLogs.isEmpty {
                    emptyInlineState(icon: "trash", text: l.tr(zh: "还没有铲砂记录", en: "No scoop logs yet", de: "Noch keine Klo-Einträge"))
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
                    poopOverviewMetric(title: l.tr(zh: "周期", en: "Cycle", de: "Rhythmus"), value: dayCountText(litterChangeIntervalDays), icon: "repeat", tint: litterTint)
                    poopOverviewMetric(title: l.tr(zh: "下次", en: "Next", de: "Nächstes"), value: dueText(daysUntil: daysUntilLitterChange), icon: "calendar", tint: daysUntilLitterChange < 0 ? Color.goRed : litterTint)
                }
                poopProgressBlock(title: l.tr(zh: "换砂周期", en: "Litter rhythm", de: "Streu-Rhythmus"), elapsed: litterElapsedDays, interval: litterChangeIntervalDays, tint: litterTint)
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: litterPrimaryTitle, icon: "arrow.2.circlepath", tint: litterTint) {
                        openPottySheet(.litterChangeCheckIn)
                    }
                    Button {
                        openPottySheet(.litterSettings)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(litterTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近换砂", en: "Latest changes", de: "Letzte Wechsel"))
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
                    Text(l.tr(zh: "整盆换砂", en: "Full litter change", de: "Kompletter Streuwechsel"))
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
            emptyInlineState(icon: "tray", text: l.tr(zh: "还没有换砂记录", en: "No litter changes yet", de: "Noch kein Streuwechsel"))
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
                    Text(range.title(l))
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
            pottySheetChromeTitleContent(icon: "seal.fill", title: l.tr(zh: "噗噗总览", en: "Poop overview", de: "Häufchen-Überblick"), tint: pottyTint)
        case .scoopOverview:
            pottySheetChromeTitleContent(icon: "trash.fill", title: l.tr(zh: "铲砂总览", en: "Scoop overview", de: "Klo-Überblick"), tint: scoopTint)
        case .litterOverview:
            pottySheetChromeTitleContent(icon: "tray.full.fill", title: l.tr(zh: "猫砂总览", en: "Litter overview", de: "Streu-Überblick"), tint: litterTint)
        case .litterHistory:
            pottySheetChromeTitleContent(icon: "tray.full.fill", title: l.tr(zh: "换砂历史", en: "Litter history", de: "Streu-Verlauf"), tint: litterTint)
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
                Text(progressDaysText(elapsed: elapsed, interval: max(interval, 1)))
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
            return PoopTypeSummary(title: type.localizedLabel(l), icon: type.systemIconName, count: count, tint: pottyTypeColor(type))
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
            showSaveConfirmation(scoopReminderOn ? l.tr(zh: "铲砂提醒已保存", en: "Scoop reminder saved", de: "Klo-Erinnerung gespeichert") : l.tr(zh: "已保存", en: "Saved", de: "Gespeichert"))
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
            showSaveConfirmation(litterReminderOn ? l.tr(zh: "换砂提醒已保存", en: "Litter reminder saved", de: "Streu-Erinnerung gespeichert") : l.tr(zh: "已保存", en: "Saved", de: "Gespeichert"))
        }
    }

    private func deleteScoopPlan() {
        scoopReminderOn = false
        syncScoopPlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(l.tr(zh: "铲砂计划已删除", en: "Scoop plan deleted", de: "Klo-Plan gelöscht"))
    }

    private func deleteLitterChangePlan() {
        litterReminderOn = false
        syncLitterChangePlan(showToast: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSaveConfirmation(l.tr(zh: "换砂计划已删除", en: "Litter plan deleted", de: "Streu-Plan gelöscht"))
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
        showSaveConfirmation(delta > 0 ? "\(type.emoji) +\(delta)🥥" : l.tr(zh: "噗噗已记录", en: "Poop logged", de: "Häufchen erfasst"))
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
        showSaveConfirmation(l.tr(zh: "猫砂盆事件已记录", en: "Litter-box event logged", de: "Klo-Ereignis erfasst"))
    }

    private func doScoop() {
        guard !todayLitterLogs.isEmpty else {
            recordScoop()
            return
        }
        singleUseNoticeMessage = l.tr(
            zh: "\(pet.name) 今天已经铲砂过了。要修改的话，先在最近记录里删除。",
            en: "\(pet.name)'s litter was already scooped today. Delete the latest log to change it.",
            de: "\(pet.name)s Klo wurde heute schon gereinigt. Lösche den letzten Eintrag zum Ändern."
        )
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
        let actionText = targets.count > 1
            ? l.tr(zh: "\(targets.count)只猫 已铲", en: "\(targets.count) cats scooped", de: "\(targets.count) Katzenklos sauber")
            : l.tr(zh: "铲砂已记录", en: "Scoop logged", de: "Klo erfasst")
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
        showSaveConfirmation(
            targets.count > 1
            ? l.tr(zh: "\(targets.count)只猫 已换砂", en: "\(targets.count) litter boxes changed", de: "\(targets.count) Katzenstreus gewechselt")
            : l.tr(zh: "换砂已记录", en: "Litter change logged", de: "Streuwechsel erfasst")
        )
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            commandQueue.enqueue(.petPottyDelete(petID: pet.id, logID: log.id)) {
                _ = PetCareCommandExecutor(context: modelContext).deletePottyLog(
                    log,
                    pet: pet,
                    note: "quickPotty.deletePotty"
                )
            }
        case .litter(let log):
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            commandQueue.enqueue(.petCareDelete(petID: pet.id, logID: log.id)) {
                _ = PetCareCommandExecutor(context: modelContext).deleteCareLog(
                    log,
                    pet: pet,
                    note: "quickPotty.deleteLitter"
                )
                syncScoopPlan(showToast: false)
            }
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
        if days == 0 { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        return l.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) T.")
    }

    private func dueText(daysUntil: Int) -> String {
        if daysUntil > 0 { return dayCountText(daysUntil) }
        if daysUntil == 0 { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        let overdue = abs(daysUntil)
        return l.tr(zh: "逾期\(overdue)天", en: "\(overdue)d overdue", de: "\(overdue) T. fällig")
    }

    private func timesText(_ count: Int) -> String {
        l.tr(zh: "\(count) 次", en: "\(count)x", de: "\(count)x")
    }

    private func dayCountText(_ days: Int) -> String {
        l.tr(zh: "\(days)天", en: "\(days)d", de: "\(days) T.")
    }

    private func cycleText(_ days: Int) -> String {
        l.tr(zh: "\(days)天周期", en: "\(days)d rhythm", de: "\(days)-Tage-Rhythmus")
    }

    private func everyDaysText(_ days: Int) -> String {
        l.tr(zh: "每\(days)天", en: "Every \(days)d", de: "Alle \(days) Tage")
    }

    private func progressDaysText(elapsed: Int, interval: Int) -> String {
        l.tr(zh: "\(elapsed)/\(interval)天", en: "\(elapsed)/\(interval)d", de: "\(elapsed)/\(interval) T.")
    }

    private func petCountText(_ count: Int, species: String) -> String {
        l.tr(zh: "\(count)只\(species)", en: "\(count) \(species)", de: "\(count) \(species)")
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
