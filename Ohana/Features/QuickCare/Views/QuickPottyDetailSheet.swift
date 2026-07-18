//
//  QuickPottyDetailSheet.swift
//  Ohana
//
//  Unified poop management: potty, scoop, and litter changes.
//

import SwiftData
import SwiftUI

struct QuickPottyDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)?
    var onRecordChanged: () -> Void
    let allEvents: [Event]
    let allPets: [Pet]
    let pottyEntries: [PoopPottyLedgerEntry]
    let litterEntries: [PoopLitterLedgerEntry]
    let unknownPottyEntries: [PoopUnknownPottyEntry]

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared
    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var activeSheet: ActiveSheet?
    @State var nestedInlineSheet: ActiveSheet?
    @State var pottySheetReturnStack: [ActiveSheet] = []
    @State var scoopIntervalDays: Int = 1
    @State var scoopAnchorDate: Date = .init()
    @State var scoopReminderOn = false
    @State var litterChangeIntervalDays: Int = 14
    @State var litterCycleAnchorDate: Date = .init()
    @State var litterReminderOn = false
    @State var showSaveToast = false
    @State var saveToastMessage = ""
    @State var saveToastTask: Task<Void, Never>?
    @State var pottyPlanSaveTask: Task<Void, Never>?
    @State var isSavingPottyPlan = false
    @State var showSingleUseNotice = false
    @State var singleUseNoticeMessage = ""
    @State var overviewRange: PoopOverviewRange = .days7
    @State var overviewChartProgress: Double = 1
    @State var inlineSheetVisible = false
    @State var inlineSheetDragOffset: CGFloat = 0
    @State var adaptiveSheetHeight: CGFloat = 430
    @State var selectedFocus: PottyFocus = .potty
    @State var pottyFeedbackToken: CheckInFeedbackToken?
    @State var scoopFeedbackToken: CheckInFeedbackToken?
    @State var litterFeedbackToken: CheckInFeedbackToken?
    @State var feedbackClearTask: Task<Void, Never>?
    @State var selectedSharedPottyPetIds: Set<UUID> = []
    @State var isCommittingPottyLog = false
    @State var selectedActionHumanID: UUID?
    @State var requiresActionHumanSelection = false
    @State var personalUpgradePrompt: PersonalUpgradePrompt?
    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        onRecordChanged: @escaping () -> Void = {},
        allEvents: [Event] = [],
        allPets: [Pet] = [],
        pottyEntries: [PoopPottyLedgerEntry] = [],
        litterEntries: [PoopLitterLedgerEntry] = [],
        unknownPottyEntries: [PoopUnknownPottyEntry] = []
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.onClose = onClose
        self.onRecordChanged = onRecordChanged
        self.allEvents = allEvents
        self.allPets = allPets
        self.pottyEntries = pottyEntries
        self.litterEntries = litterEntries
        self.unknownPottyEntries = unknownPottyEntries
    }

    typealias PottyFocus = QuickPottyFocus
    typealias ActiveSheet = QuickPottyActiveSheet
    var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    var isDark: Bool { colorScheme == .dark }
    var petKey: String { pet.id.uuidString }
    var pottyTint: Color { Color(hex: "A66A3F") }
    var scoopTint: Color { isDark ? Color.goPrimary : Color(hex: CareType.litter.accentColorHex) }
    var litterTint: Color { Color(hex: "D4A574") }
    var chromeTint: Color { isDark ? Color.goPrimary : themeColor }
    var pottyCommandExecutor: QuickPottyCommandExecutor {
        QuickPottyCommandExecutor(
            context: modelContext,
            careEvents: appServices.careEvents,
            revisions: appServices.domainRevisions,
            personalAccessLevel: appServices.commerce.hasPersonalEntitlement ? .personal : .free
        )
    }

    var l: L10n { L10n(appLanguage) }
    var isCatPet: Bool {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        return text.contains("猫") || text.contains("cat")
    }

    var sameSpeciesPottyPets: [Pet] {
        let species = normalizedSpecies(pet.species)
        return allPets
            .filter { !$0.hasPassedAway && normalizedSpecies($0.species) == species }
            .sorted { lhs, rhs in
                if lhs.id == pet.id { return true }
                if rhs.id == pet.id { return false }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var selectedPottyTargets: [Pet] {
        let targets = sameSpeciesPottyPets.filter { selectedSharedPottyPetIds.contains($0.id) }
        return SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
    }

    var availableFocuses: [PottyFocus] {
        isCatPet ? [.potty, .scoop, .litter] : [.potty]
    }

    var todayPottyLogs: [PoopPottyLedgerEntry] {
        pottyLogs
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var pottyLogs: [PoopPottyLedgerEntry] {
        pottyEntries
    }

    var unknownSharedPottyItems: [PoopLogItem] {
        unknownPottyEntries.map(PoopLogItem.unknownPotty)
    }

    var pottyHistoryItems: [PoopLogItem] {
        (pottyLogs.map(PoopLogItem.potty) + unknownSharedPottyItems)
            .sorted { $0.date > $1.date }
    }

    var litterLogs: [PoopLitterLedgerEntry] {
        litterEntries
    }

    var todayLitterLogs: [PoopLitterLedgerEntry] {
        litterLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    var recentItems: [PoopLogItem] {
        let pottyItems = pottyHistoryItems
        guard isCatPet else { return Array(pottyItems.prefix(12)) }
        let litterItems = litterLogs.map(PoopLogItem.litter)
        return Array((pottyItems + litterItems).sorted { $0.date > $1.date }.prefix(12))
    }

    var systemSheetBinding: Binding<ActiveSheet?> {
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

    var activeInlineSheet: ActiveSheet? {
        nestedInlineSheet ?? (activeSheet?.usesInlineOverlay == true ? activeSheet : nil)
    }

    var inlineOverlayBlocksBackground: Bool {
        activeInlineSheet != nil
    }

    var lastPottyLog: PoopPottyLedgerEntry? { pottyLogs.first }
    var lastScoopLog: PoopLitterLedgerEntry? { litterLogs.first }
    var lastFullChange: Date? {
        LitterCareSettingsStore.lastFullChangeDate(petKey: petKey)
    }

    var scoopElapsedDays: Int {
        daysSinceDate(lastScoopLog?.date ?? scoopAnchorDate)
    }

    var litterElapsedDays: Int {
        daysSinceDate(lastFullChange ?? litterCycleAnchorDate)
    }

    var daysUntilScoop: Int { scoopIntervalDays - scoopElapsedDays }
    var daysUntilLitterChange: Int { litterChangeIntervalDays - litterElapsedDays }

    var last7DaysCounts: [(date: Date, count: Int)] {
        (0 ..< 7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let count = pottyLogs.count(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
            return (date, count)
        }
        .reversed()
    }

    var last7AbnormalRatio: Double {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let logs = pottyLogs.filter { $0.date >= start }
        guard !logs.isEmpty else { return 0 }
        let abnormal = logs.count(where: { $0.pottyType == .softPoop || $0.pottyType == .liquidPoop })
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
            }
            .overlay(alignment: .top) {
                if showSaveToast {
                    toastView
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: systemSheetBinding) { sheet in
                NavigationStack {
                    sheetContent(sheet)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .petMemorialTone(isActive: pet.hasPassedAway)
                        .navigationTitle(pottySheetTitle(sheet))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(l.cancel) {
                                    closeActivePottySheet()
                                }
                                .accessibilityIdentifier("quick-potty-sheet-cancel-action")
                            }
                        }
                }
                .ohanaSheetPagePresentation() // ui-v4: allow long overview/history uses system sheet
            }
            .sheet(item: $personalUpgradePrompt) { prompt in
                PersonalPlanView(prompt: prompt)
            }
            .alert(l.tr(zh: "今天已经完成了", en: "Already done today", de: "Heute schon erledigt"), isPresented: $showSingleUseNotice) {
                Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {}
            } message: {
                Text(singleUseNoticeMessage)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .petMemorialTone(isActive: pet.hasPassedAway)
        }
        .accessibilityIdentifier("quick-potty-detail-sheet")
        .onAppear {
            loadSettings()
            selectedSharedPottyPetIds = SharedPetSelectionMemory.restoredSelection(
                sourcePet: pet,
                scope: "quickCare.potty",
                candidates: sameSpeciesPottyPets,
                defaultToAll: true
            )
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
            if nestedInlineSheet == nil, activeSheet?.usesInlineOverlay != true {
                inlineSheetVisible = false
            }
        }
        .onChange(of: appServices.commerce.hasPersonalEntitlement) { _, isEntitled in
            if !isEntitled, overviewRange == .days90 {
                overviewRange = .days30
            }
        }
        .onDisappear {
            saveToastTask?.cancel()
            feedbackClearTask?.cancel()
            pottyPlanSaveTask?.cancel()
            isSavingPottyPlan = false
            isCommittingPottyLog = false
            commandQueue.cancelAll()
        }
        .interactiveDismissDisabled(activeInlineSheet != nil)
    }

    // MARK: - Main UI
    func inlinePoopSheetOverlay(_ sheet: ActiveSheet) -> some View { // native-ui: allow retired compatibility renderer; runtime uses sheet(item:)
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
                    dismissInlinePoopSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    func dismissInlinePoopSheet() {
        guard activeInlineSheet != nil else {
            closeActivePottySheet()
            return
        }
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

    var header: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                pet: pet,
                fallbackText: pet.avatarEmoji,
                themeColor: themeColor,
                size: 48,
                backgroundOpacity: 0.16
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "噗噗电台", en: "Poop Radio", de: "Häufchen-Radio"))
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

    var poopHero: some View {
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

    var pottyDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint(for: selectedFocus).opacity(0.14))
                        .frame(width: 66, height: 66)
                    Image(systemName: selectedFocus.icon)
                        .font(OhanaFont.adaptive(size: 27, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tint(for: selectedFocus))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(l.tr(zh: "噗噗电台", en: "Poop Radio", de: "Häufchen-Radio"))
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pottyDashboardSubtitle)
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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

    var pottyDashboardSubtitle: String {
        switch selectedFocus {
        case .potty:
            pottySubtitle
        case .scoop:
            scoopSubtitle
        case .litter:
            litterChangeSubtitle
        }
    }

    var pottyFocusSelector: some View {
        HStack(spacing: 8) {
            ForEach(availableFocuses) { focus in
                pottyFocusChip(focus)
            }
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    func pottyFocusChip(_ focus: PottyFocus) -> some View {
        let selected = selectedFocus == focus
        let tint = tint(for: focus)
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedFocus = focus
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: focus.icon)
                    .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(focus.title(l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(selected ? Color.arkInk : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? tint : Color.ohanaCardSurfaceElevated, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func pottySummaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    func tint(for focus: PottyFocus) -> Color {
        switch focus {
        case .potty:
            pottyTint
        case .scoop:
            scoopTint
        case .litter:
            litterTint
        }
    }

    var coreCards: some View {
        VStack(spacing: 12) {
            ForEach(coreCardOrder, id: \.rawValue) { focus in
                coreCard(for: focus)
            }
        }
    }

    var coreCardOrder: [PottyFocus] {
        availableFocuses
    }

    @ViewBuilder
    func coreCard(for focus: PottyFocus) -> some View {
        switch focus {
        case .potty:
            pottyCard
        case .scoop:
            scoopCard
        case .litter:
            litterChangeCard
        }
    }

    var pottyCard: some View {
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
            feedbackToken: pottyFeedbackToken,
            accessibilityIDPrefix: "quick-potty-poop"
        )
    }

    var scoopCard: some View {
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
            feedbackToken: scoopFeedbackToken,
            accessibilityIDPrefix: "quick-potty-scoop"
        )
    }

    var litterChangeCard: some View {
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
            feedbackToken: litterFeedbackToken,
            accessibilityIDPrefix: "quick-potty-litter"
        )
    }

    var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l.tr(zh: "最近", en: "Latest", de: "Zuletzt"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .accessibilityIdentifier("quick-potty-recent-strip")
                Spacer()
                Button {
                    openPottySheet(.history)
                } label: {
                    Text(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(chromeTint)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if recentItems.isEmpty {
                Text(l.tr(zh: "暂无记录", en: "No logs yet", de: "Noch keine Einträge"))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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

    var pottySubtitle: String {
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

    var scoopSubtitle: String {
        if let lastScoopLog {
            return "\(relativeDayText(for: lastScoopLog.date)) · \(cycleText(scoopIntervalDays))"
        }
        return cycleText(scoopIntervalDays)
    }

    var litterChangeSubtitle: String {
        if let lastFullChange {
            return "\(relativeDayText(for: lastFullChange)) · \(cycleText(litterChangeIntervalDays))"
        }
        return cycleText(litterChangeIntervalDays)
    }

    var scoopNeedsCatchUp: Bool {
        daysUntilScoop < 0
    }

    var scoopDoneToday: Bool {
        !todayLitterLogs.isEmpty && daysUntilScoop >= 0
    }

    var scoopPrimaryTitle: String {
        if scoopNeedsCatchUp { return l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen") }
        if todayLitterLogs.isEmpty { return l.tr(zh: "打卡", en: "Check in", de: "Eintragen") }
        return l.tr(zh: "已完成", en: "Done", de: "Erledigt")
    }

    var litterPrimaryTitle: String {
        if daysUntilLitterChange < 0 { return l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen") }
        return l.tr(zh: "换砂", en: "Change litter", de: "Streu wechseln")
    }

    var scoopPlanDetail: String {
        everyDaysText(scoopIntervalDays)
    }

    var litterPlanDetail: String {
        everyDaysText(litterChangeIntervalDays)
    }

    var scoopLastActionText: String {
        lastScoopLog.map {
            l.tr(zh: "上次 \(relativeDayText(for: $0.date))", en: "Last \(relativeDayText(for: $0.date))", de: "Zuletzt \(relativeDayText(for: $0.date))")
        } ?? l.tr(zh: "还没有打卡", en: "No scoop yet", de: "Noch nicht gereinigt")
    }

    var litterLastActionText: String {
        lastFullChange.map {
            l.tr(zh: "上次 \(relativeDayText(for: $0))", en: "Last \(relativeDayText(for: $0))", de: "Zuletzt \(relativeDayText(for: $0))")
        } ?? l.tr(zh: "还没有换砂", en: "No litter change yet", de: "Noch kein Streuwechsel")
    }
}
