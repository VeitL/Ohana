//
//  QuickPlayDetailSheet.swift
//  Ohana
//
//  逗玩详情：轻量状态 + 频率图 + 计划 + 最近记录
//

import SwiftData
import SwiftUI

struct QuickPlayLedgerEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let legacyLogId: UUID?

    static func entries(from events: [CareLedgerEvent], petID: UUID) -> [QuickPlayLedgerEntry] {
        let petKey = petID.uuidString
        return events.compactMap { event in
            guard event.eventKindEnum == .care,
                  event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  event.subjectId == petKey,
                  event.actionType == CareType.play.rawValue else { return nil }
            let legacyLogId = event.legacyModelName == "PetCareLog"
                ? event.legacyModelId.flatMap(UUID.init(uuidString:))
                : nil
            return QuickPlayLedgerEntry(
                id: event.id,
                date: event.occurredAt,
                legacyLogId: legacyLogId
            )
        }
        .sorted { $0.date > $1.date }
    }
}

struct QuickPlayDetailSheet: View {
    let pet: Pet
    let onRemove: () -> Void
    var onClose: (() -> Void)?
    var allEvents: [Event] = []
    let playEntries: [QuickPlayLedgerEntry]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingPlayPlanEditor = false
    @State private var inlineSheetVisible = false
    @State private var inlineSheetDragOffset: CGFloat = 0
    @State private var playPlanIntervalDays = 3
    @State private var playPlanAnchorDate = Date()
    @State private var saveToastMessage: String?
    @State private var playPlanSaveTask: Task<Void, Never>?
    @State private var isSavingPlayPlan = false
    @State private var isCommittingPlay = false
    @State private var playFeedbackToken: CheckInFeedbackToken?
    @State private var chartProgress: Double = 0

    private var l: L10n { L10n(appLanguage) }
    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var playTint: Color { Color.goOrange }
    private var petKey: String { pet.id.uuidString }
    private var playPlanTitle: String { "\(pet.name) 陪玩计划" }
    private var playCommandExecutor: QuickPlayCommandExecutor {
        QuickPlayCommandExecutor(
            context: modelContext,
            careEvents: appServices.careEvents,
            revisions: appServices.domainRevisions
        )
    }

    init(
        pet: Pet,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        allEvents: [Event] = [],
        playEntries: [QuickPlayLedgerEntry] = []
    ) {
        self.pet = pet
        self.onRemove = onRemove
        self.onClose = onClose
        self.allEvents = allEvents
        self.playEntries = playEntries
    }

    private var playPlanEvent: Event? {
        allEvents
            .filter(isPlayPlanEvent)
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private func isPlayPlanEvent(_ event: Event) -> Bool {
        MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: petKey) &&
            event.title == playPlanTitle
    }

    private var missedPlayPlanReminder: Reminder? {
        let now = Date()
        return playPlanEvent?.reminders
            .filter { !$0.isCompleted && ($0.isPending || $0.isFailed) && $0.scheduledAt <= now }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }

    private struct DayCount: Identifiable {
        var id: Date { day }
        let day: Date
        let count: Int
    }

    private var monthPlayStrip: [DayCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0 ..< 28).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = playEntries.count(where: { cal.isDate($0.date, inSameDayAs: d) })
            return DayCount(day: d, count: count)
        }
    }

    private var chartPoints: [OhanaMinimalChartPoint] {
        monthPlayStrip.suffix(14).map { item in
            OhanaMinimalChartPoint(
                date: item.day,
                value: Double(item.count),
                label: Calendar.current.isDateInToday(item.day) ? l.tr(zh: "今", en: "Now", de: "Jetzt") : nil
            )
        }
    }

    private var recentLogs: [QuickPlayLedgerEntry] {
        playEntries
            .prefix(12)
            .map(\.self)
    }

    private var todayPlayCount: Int {
        playEntries.count(where: { Calendar.current.isDateInToday($0.date) })
    }

    private var weekPlayCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return playEntries.count(where: { $0.date >= cutoff })
    }

    private var streakDays: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var streak = 0
        while playEntries.contains(where: { cal.isDate($0.date, inSameDayAs: day) }) {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private var lastPlayText: String {
        guard let last = playEntries.first?.date else {
            return l.tr(zh: "还没有", en: "None yet", de: "Noch keine")
        }
        if Calendar.current.isDateInToday(last) {
            return last.formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(last) {
            return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern")
        }
        return last.formatted(.dateTime.month().day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerRow
                        playSummaryMetrics
                        primaryPlayCard
                        QuickCareExecutorPickerBarContainer(tint: playTint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        playFrequencySection
                        playPlanModule
                        recentLogsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 42)
                }

                if showingPlayPlanEditor {
                    playPlanInlineOverlay
                        .zIndex(10)
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                if let saveToastMessage {
                    toast(message: saveToastMessage)
                }
            }
            .onAppear {
                loadPlayPlanDraft()
                animateChartIn()
            }
            .onDisappear {
                playPlanSaveTask?.cancel()
                isSavingPlayPlan = false
                isCommittingPlay = false
                commandQueue.cancelAll()
            }
        }
        .accessibilityIdentifier("quick-play-detail-sheet")
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                pet: pet,
                fallbackText: pet.avatarEmoji,
                themeColor: themeColor,
                size: 48,
                backgroundOpacity: 0.12
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Label(l.tr(zh: "逗玩记录", en: "Play log", de: "Spielverlauf"), systemImage: "tennisball.fill")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(playTint)
            }

            Spacer()

            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: closeDetail)
        }
    }

    private func closeDetail() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var playSummaryMetrics: some View {
        HStack(spacing: 12) {
            playMetric(
                value: "\(todayPlayCount)",
                label: l.tr(zh: "今天", en: "Today", de: "Heute"),
                tint: playTint
            )
            playMetric(
                value: "\(weekPlayCount)",
                label: l.tr(zh: "7天", en: "7d", de: "7T"),
                tint: Color.goPurple
            )
            playMetric(
                value: streakDays > 0 ? "\(streakDays)" : "–",
                label: l.tr(zh: "连玩", en: "Streak", de: "Serie"),
                tint: Color.goTeal
            )
            playMetric(
                value: lastPlayText,
                label: l.tr(zh: "上次", en: "Last", de: "Zuletzt"),
                tint: themeColor
            )
        }
        .contentTransition(.numericText())
        .animation(GoMotion.feedback, value: todayPlayCount)
    }

    private func playMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
            Text(label)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryPlayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "tennisball.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 22, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 48, height: 48)
                    .background(playTint, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(todayPlayCount > 0 ? l.tr(zh: "今天玩过啦", en: "Played today", de: "Heute gespielt") : l.tr(zh: "来玩一下", en: "Play now", de: "Jetzt spielen"))
                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Text(playPlanSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer()

                if let playFeedbackToken {
                    CheckInFeedbackBadge(token: playFeedbackToken)
                }
            }

            Button { commitPlay() } label: {
                Label(playPrimaryTitle, systemImage: missedPlayPlanReminder == nil ? "checkmark" : "clock.badge.exclamationmark")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(isCommittingPlay ? playTint.opacity(0.72) : playTint, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isCommittingPlay)
        }
        .padding(18)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .checkInPulse(playFeedbackToken)
    }

    private var playFrequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "逗玩频率", en: "Play frequency", de: "Spielfrequenz"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "按每天次数", en: "Daily sessions", de: "Einheiten pro Tag"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(l.tr(zh: "14天", en: "14d", de: "14T"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(playTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            }

            OhanaMinimalBarChart(
                points: chartPoints,
                tint: playTint,
                progress: chartProgress,
                showsLabels: false,
                maxBarHeight: 76,
                emptyBarColor: Color.ohanaControlFill.opacity(0.78)
            )
            .frame(height: 88)
        }
    }

    private var playPlanModule: some View {
        Button {
            openPlayPlanEditor()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: playPlanEvent == nil ? "calendar.badge.plus" : "calendar.badge.clock")
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goPurple, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "陪玩计划", en: "Play plan", de: "Spielplan"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(planStatusText)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            }
            .padding(14)
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var playPlanSubtitle: String {
        if let missed = missedPlayPlanReminder {
            return l.tr(
                zh: "待补 \(playPlanDueText(for: missed.scheduledAt))",
                en: "Catch up \(playPlanDueText(for: missed.scheduledAt))",
                de: "\(playPlanDueText(for: missed.scheduledAt)) nachtragen"
            )
        }
        guard let event = playPlanEvent else {
            return l.tr(zh: "自由玩，或设置一个轻提醒。", en: "Free play, or add a light reminder.", de: "Frei spielen oder sanft erinnern.")
        }
        return l.tr(
            zh: "下次 \(nextPlayPlanText(for: event.startDate))",
            en: "Next \(nextPlayPlanText(for: event.startDate))",
            de: "Nächstes Mal \(nextPlayPlanText(for: event.startDate))"
        )
    }

    private var planStatusText: String {
        if let missed = missedPlayPlanReminder {
            return l.tr(
                zh: "待补 · \(playPlanDueText(for: missed.scheduledAt))",
                en: "Catch up · \(playPlanDueText(for: missed.scheduledAt))",
                de: "Nachtragen · \(playPlanDueText(for: missed.scheduledAt))"
            )
        }
        guard let event = playPlanEvent else {
            return l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt")
        }
        return l.tr(
            zh: "每 \(max(event.recurrenceDays, 1)) 天 · \(nextPlayPlanText(for: event.startDate))",
            en: "Every \(max(event.recurrenceDays, 1))d · \(nextPlayPlanText(for: event.startDate))",
            de: "Alle \(max(event.recurrenceDays, 1))T · \(nextPlayPlanText(for: event.startDate))"
        )
    }

    private var playPrimaryTitle: String {
        missedPlayPlanReminder == nil
            ? l.tr(zh: "打卡", en: "Check in", de: "Eintragen")
            : l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen")
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(recentLogs.count)")
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if recentLogs.isEmpty {
                emptyRecentState
            } else {
                VStack(spacing: 8) {
                    ForEach(recentLogs) { log in
                        recentLogRow(log)
                    }
                }
            }
        }
    }

    private var emptyRecentState: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(playTint)
            Text(l.tr(zh: "第一次逗玩后会出现在这里", en: "Your first play session appears here", de: "Das erste Spiel erscheint hier"))
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func recentLogRow(_ entry: QuickPlayLedgerEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.arkInk)
                .frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(playTint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, format: .dateTime.month().day().hour().minute())
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "已完成", en: "Done", de: "Erledigt"))
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            if let legacyLogId = entry.legacyLogId {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    commandQueue.enqueue(.petCareDelete(petID: pet.id, logID: legacyLogId)) {
                        let executor = PetCareCommandExecutor(context: modelContext, services: appServices)
                        guard let log = executor.careLog(id: legacyLogId) else {
                            OhanaLog.warning(
                                "QuickPlayDetailSheet could not resolve care log \(legacyLogId.uuidString)",
                                category: "Care"
                            )
                            return
                        }
                        withAnimation(GoMotion.feedback) {
                            _ = executor.deleteCareLog(
                                log,
                                pet: pet,
                                note: "quickPlay.deleteRecentLog"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .frame(width: 36, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var playPlanInlineOverlay: some View {
        GeometryReader { proxy in
            let bottomInset = CGFloat(8)
            let panelHeight = min(max(376, proxy.size.height * 0.42), proxy.size.height * 0.78)
            let horizontalInset = CGFloat(6)
            let panelWidth = max(0, proxy.size.width - horizontalInset * 2)
            let cornerRadius = CGFloat(52)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let hiddenOffset = panelHeight + bottomInset + 64

            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(inlineSheetVisible ? 0.10 : 0), // ui-v4: allow popup scrim gradient
                                Color.black.opacity(inlineSheetVisible ? 0.42 : 0) // ui-v4: allow popup scrim gradient
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closePlayPlanEditor() }

                ZStack(alignment: .top) {
                    playPlanEditorContent
                        .frame(maxWidth: .infinity)
                        .frame(height: panelHeight)
                        .clipShape(shape)

                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .gesture(inlineSheetDragGesture)
                        .zIndex(3)

                    HStack {
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                            closePlayPlanEditor()
                        }
                        .padding(.top, 10)
                        .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background {
                    FeedInlineSheetGlassSurface(cornerRadius: cornerRadius, glassMode: .regular)
                }
                .clipShape(shape)
                .frame(width: panelWidth)
                .shadow(color: Color.black.opacity(inlineSheetVisible ? 0.52 : 0), radius: 44, x: 0, y: -18) // ui-v4: allow popup liftedAlert shadow
                .shadow(color: Color(hex: "0B102C").opacity(inlineSheetVisible ? 0.40 : 0), radius: 24, x: 0, y: 12) // ui-v4: allow popup grounding shadow
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

    private var playPlanEditorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goPurple, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(playPlanEvent == nil ? l.tr(zh: "添加陪玩计划", en: "Add play plan", de: "Spielplan hinzufügen") : l.tr(zh: "陪玩计划", en: "Play plan", de: "Spielplan"))
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "轻提醒，不制造压力。", en: "A light reminder, no pressure.", de: "Sanfte Erinnerung, kein Druck."))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(.top, 26)

            VStack(alignment: .leading, spacing: 8) {
                Text(l.tr(zh: "频率", en: "Frequency", de: "Häufigkeit"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)

                HStack {
                    Text(l.tr(zh: "每 \(playPlanIntervalDays) 天", en: "Every \(playPlanIntervalDays)d", de: "Alle \(playPlanIntervalDays)T"))
                        .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Spacer()
                    Stepper("", value: $playPlanIntervalDays, in: 1 ... 30)
                        .labelsHidden()
                }
            }
            .padding(15)
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))

            DatePicker(
                l.tr(zh: "起算日", en: "Start date", de: "Startdatum"),
                selection: $playPlanAnchorDate,
                displayedComponents: .date
            )
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(15)
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if playPlanEvent != nil {
                    Button(role: .destructive) {
                        deletePlayPlan()
                    } label: {
                        Text(l.tr(zh: "关闭", en: "Turn off", de: "Ausschalten"))
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isSavingPlayPlan)
                }

                Button {
                    savePlayPlan()
                } label: {
                    Text(isSavingPlayPlan ? l.tr(zh: "保存中", en: "Saving", de: "Speichert") : l.tr(zh: "保存", en: "Save", de: "Speichern"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.goPurple, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSavingPlayPlan)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private var inlineSheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                inlineSheetDragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 90 || value.predictedEndTranslation.height > 150 {
                    closePlayPlanEditor()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    private func toast(message: String) -> some View {
        Text(message)
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(playTint, in: Capsule())
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func commitPlay() {
        guard !isCommittingPlay else { return }
        let executorId = appServices.activeHumanSelection.currentHumanId
        let rewardTitle = l.tr(zh: "\(pet.name) 互动奖励", en: "\(pet.name) play reward", de: "\(pet.name) Spielbelohnung")
        isCommittingPlay = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: CareType.play.rawValue)) {
            let result = playCommandExecutor.recordPlay(
                petID: pet.id,
                executorId: executorId,
                rewardTitle: rewardTitle
            )
            isCommittingPlay = false
            guard let result else {
                showToast(l.tr(zh: "未找到成员", en: "Member not found", de: "Mitglied nicht gefunden"))
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            let deltaText = result.coconutDelta > 0 ? "+\(result.coconutDelta)" : "+1"
            playFeedbackToken = CheckInFeedbackToken(kind: .gain, deltaText: deltaText, tint: playTint)
            showToast(l.tr(zh: "已记录", en: "Logged", de: "Gespeichert"))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func openPlayPlanEditor() {
        loadPlayPlanDraft()
        inlineSheetDragOffset = 0
        showingPlayPlanEditor = true
    }

    private func closePlayPlanEditor() {
        withAnimation(GoMotion.page) {
            inlineSheetVisible = false
            inlineSheetDragOffset = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            showingPlayPlanEditor = false
        }
    }

    private func loadPlayPlanDraft() {
        if let event = playPlanEvent {
            playPlanIntervalDays = max(1, event.recurrenceDays)
            playPlanAnchorDate = event.startDate
        } else {
            playPlanIntervalDays = 3
            playPlanAnchorDate = Date()
        }
    }

    private func savePlayPlan() {
        guard !isSavingPlayPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingPlayPlan = true
        playPlanSaveTask?.cancel()
        closePlayPlanEditor()
        playPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: playPlanSaveDelayMilliseconds) {
            let event = CarePlanCalendarSync.syncPlayPlan(
                pet: pet,
                context: modelContext,
                intervalDays: playPlanIntervalDays,
                enabled: true,
                anchor: playPlanAnchorDate
            )
            showToast(l.tr(zh: "计划已保存", en: "Plan saved", de: "Plan gespeichert"))
            if let event {
                Task { @MainActor in
                    await appServices.reminderScheduling.scheduleManyIfNeeded(reminders: event.reminders, context: modelContext, source: .detail)
                }
            }
            isSavingPlayPlan = false
            playPlanSaveTask = nil
        }
    }

    private func deletePlayPlan() {
        guard !isSavingPlayPlan else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        isSavingPlayPlan = true
        playPlanSaveTask?.cancel()
        closePlayPlanEditor()
        playPlanSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: playPlanSaveDelayMilliseconds) {
            CarePlanCalendarSync.syncPlayPlan(
                pet: pet,
                context: modelContext,
                intervalDays: 0,
                enabled: false,
                anchor: playPlanAnchorDate
            )
            showToast(l.tr(zh: "计划已关闭", en: "Plan off", de: "Plan aus"))
            isSavingPlayPlan = false
            playPlanSaveTask = nil
        }
    }

    private var playPlanSaveDelayMilliseconds: UInt64 {
        AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true).allowsMotion ? 120 : 40
    }

    private func showToast(_ message: String) {
        withAnimation(GoMotion.page) {
            saveToastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(GoMotion.page) {
                if saveToastMessage == message {
                    saveToastMessage = nil
                }
            }
        }
    }

    private func animateChartIn() {
        chartProgress = 0
        DispatchQueue.main.async {
            withAnimation(GoMotion.page) {
                chartProgress = 1
            }
        }
    }

    private func nextPlayPlanText(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return l.tr(zh: "今天", en: "today", de: "heute")
        }
        if cal.isDateInTomorrow(date) {
            return l.tr(zh: "明天", en: "tomorrow", de: "morgen")
        }
        return date.formatted(.dateTime.month().day())
    }

    private func playPlanDueText(for date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) {
            return l.tr(zh: "今天 \(time)", en: "today \(time)", de: "heute \(time)")
        }
        if cal.isDateInYesterday(date) {
            return l.tr(zh: "昨天 \(time)", en: "yesterday \(time)", de: "gestern \(time)")
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
