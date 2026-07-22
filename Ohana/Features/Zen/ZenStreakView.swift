//
//  ZenStreakView.swift
//  Ohana
//
//  A quiet, all-history calendar. Only the bound owner has streak metrics;
//  other subjects retain their daily presence and status facts.
//

import SwiftUI

@MainActor
struct ZenStreakView: View {
    let snapshot: ZenPresenceSnapshot
    let actions: ZenShellActions

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var calendarCellHeight =
        ZenCalendarViewportMetrics.standardCellHeight
    @State private var selectedSubjectID: String?
    @State private var displayedMonth: Date
    @State private var monthPageOffset = 0
    @State private var calendarIsPresented = false
    @State private var calendarRevealTask: Task<Void, Never>?
    @State private var retrospectiveStatusDraft: ZenRetrospectiveStatusDraft?

    init(snapshot: ZenPresenceSnapshot, actions: ZenShellActions) {
        self.snapshot = snapshot
        self.actions = actions
        let initialSubjects = snapshot.streakSubjects.isEmpty ? snapshot.subjects : snapshot.streakSubjects
        _selectedSubjectID = State(initialValue: snapshot.ownerID ?? initialSubjects.first?.id)
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month], from: Date())
        _displayedMonth = State(initialValue: calendar.date(from: components) ?? Date())
    }

    private var l: L10n { L10n(appLanguage) }

    private var calendar: Calendar {
        var value = Calendar.autoupdatingCurrent
        value.locale = Locale(identifier: appLanguage)
        return value
    }

    private var subjects: [ZenPresenceSubjectDTO] {
        let source = snapshot.streakSubjects.isEmpty ? snapshot.subjects : snapshot.streakSubjects
        return ZenPresencePresentation.orderedSubjects(source)
    }

    private var selectedSubject: ZenPresenceSubjectDTO? {
        subjects.first(where: { $0.id == selectedSubjectID }) ?? subjects.first
    }

    private var selectedDays: [ZenPresenceDayDTO] {
        guard let subjectID = selectedSubject?.id else { return [] }
        return snapshot.days.filter { $0.subjectID == subjectID }
    }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    subjectPicker
                    metrics
                    calendarCard
                    personalAnalyticsAction
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(l.tr(
            zh: "打卡日历",
            en: "Check-in calendar",
            de: "Check-in-Kalender",
            es: "Calendario de check-in",
            pt: "Calendário de check-in",
            fr: "Calendrier de check-in",
            ja: "チェックインカレンダー",
            ko: "체크인 캘린더",
            it: "Calendario check-in"
        ))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await actions.onLoadStreak()
        }
        .onAppear {
            revealCalendarIfNeeded()
        }
        .onDisappear {
            calendarRevealTask?.cancel()
            calendarRevealTask = nil
        }
        .onChange(of: snapshot.ownerID) { _, ownerID in
            guard selectedSubjectID == nil else { return }
            selectedSubjectID = ownerID ?? subjects.first?.id
        }
        .onChange(of: snapshot.streakSubjects) { _, values in
            let availableValues = values.isEmpty ? snapshot.subjects : values
            guard let selectedSubjectID,
                  !availableValues.contains(where: { $0.id == selectedSubjectID })
            else { return }
            self.selectedSubjectID = snapshot.ownerID ?? availableValues.first?.id
        }
        .sheet(item: $retrospectiveStatusDraft) { draft in
            ZenRetrospectiveStatusSheet(
                draft: draft,
                localization: l,
                languageCode: appLanguage
            ) { score in
                await actions.onRecordRetrospectiveStatus(
                    draft.subjectID,
                    draft.subjectKind,
                    draft.dayKey,
                    ZenPresenceStatus(score: score)
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-streak-screen")
    }

    @ViewBuilder
    private var subjectPicker: some View {
        if subjects.isEmpty {
            Text(l.tr(
                zh: "添加成员后即可查看日历",
                en: "Add someone to see their calendar",
                de: "Füge jemanden hinzu, um den Kalender zu sehen",
                es: "Añade a alguien para ver su calendario",
                pt: "Adicione alguém para ver o calendário",
                fr: "Ajoutez quelqu’un pour voir son calendrier",
                ja: "メンバーを追加するとカレンダーを確認できます",
                ko: "구성원을 추가하면 캘린더를 볼 수 있어요",
                it: "Aggiungi qualcuno per vedere il calendario"
            ))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(subjects) { subject in
                        Button {
                            selectedSubjectID = subject.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: subject.kind.icon)
                                    .accessibilityHidden(true)
                                Text(subject.name)
                                    .lineLimit(1)
                                if subject.isOwner {
                                    Image(systemName: "person.crop.circle.badge.checkmark") // a11y: allow decorative owner marker is hidden below
                                        .accessibilityHidden(true)
                                }
                            }
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(subject.id == selectedSubjectID ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(subject.id == selectedSubjectID ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(subject.isOwner
                            ? l.tr(
                                zh: "\(subject.name)，本人",
                                en: "\(subject.name), me",
                                de: "\(subject.name), ich",
                                es: "\(subject.name), yo",
                                pt: "\(subject.name), eu",
                                fr: "\(subject.name), moi",
                                ja: "\(subject.name)、本人",
                                ko: "\(subject.name), 본인",
                                it: "\(subject.name), io"
                            )
                            : subject.name)
                        .accessibilityAddTraits(subject.id == selectedSubjectID ? .isSelected : [])
                        .accessibilityIdentifier("zen-streak-subject-\(subject.kind.rawValue)-\(subject.id)")
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityIdentifier("zen-streak-subject-picker")
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric(
                value: primaryMetricValue,
                title: primaryMetricTitle,
                icon: "flame.fill"
            )

            Divider()
                .frame(height: 42)

            metric(
                value: secondaryMetricValue,
                title: secondaryMetricTitle,
                icon: "trophy.fill"
            )
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-streak-metrics")
    }

    private func metric(value: Int, title: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 17, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(OhanaFont.metric(size: 24, .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .contentTransition(.numericText())
                Text(title)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .accessibilityElement(children: .combine)
    }

    private var primaryMetricValue: Int {
        selectedSubject?.isOwner == true ? snapshot.currentStreak : checkedCount(in: displayedMonth)
    }

    private var secondaryMetricValue: Int {
        selectedSubject?.isOwner == true ? snapshot.longestStreak : selectedDays.count(where: \.checkedIn)
    }

    private var primaryMetricTitle: String {
        selectedSubject?.isOwner == true
            ? l.tr(
                zh: "当前连续",
                en: "Current streak",
                de: "Aktuelle Serie",
                es: "Racha actual",
                pt: "Sequência atual",
                fr: "Série actuelle",
                ja: "現在の連続記録",
                ko: "현재 연속 기록",
                it: "Serie attuale"
            )
            : l.tr(
                zh: "本月打卡",
                en: "This month",
                de: "Diesen Monat",
                es: "Este mes",
                pt: "Este mês",
                fr: "Ce mois-ci",
                ja: "今月のチェックイン",
                ko: "이번 달",
                it: "Questo mese"
            )
    }

    private var secondaryMetricTitle: String {
        selectedSubject?.isOwner == true
            ? l.tr(
                zh: "最长连续",
                en: "Longest streak",
                de: "Längste Serie",
                es: "Racha más larga",
                pt: "Maior sequência",
                fr: "Série la plus longue",
                ja: "最長の連続記録",
                ko: "최장 연속 기록",
                it: "Serie più lunga"
            )
            : l.tr(
                zh: "累计打卡",
                en: "All check-ins",
                de: "Alle Check-ins",
                es: "Todos los check-ins",
                pt: "Todos os check-ins",
                fr: "Tous les check-ins",
                ja: "チェックイン総数",
                ko: "전체 체크인",
                it: "Tutti i check-in"
            )
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            calendarPager
            compactCalendarKey
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.07), lineWidth: 1)
        }
        .opacity(calendarIsPresented ? 1 : 0)
        .scaleEffect(calendarIsPresented ? 1 : 0.975, anchor: .top)
        .offset(y: calendarIsPresented ? 0 : 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-streak-calendar")
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left") // a11y: allow parent Button supplies localized previous-month label
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(l.tr(
                zh: "上个月",
                en: "Previous month",
                de: "Vorheriger Monat",
                es: "Mes anterior",
                pt: "Mês anterior",
                fr: "Mois précédent",
                ja: "前の月",
                ko: "이전 달",
                it: "Mese precedente"
            ))
            .accessibilityIdentifier("zen-streak-previous-month")

            Spacer(minLength: 8)

            Text(monthTitle)
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .animation(reduceMotion ? GoMotion.reduced : GoMotion.quick, value: monthTitle)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right") // a11y: allow parent Button supplies localized next-month label
                    .frame(width: 44, height: 44)
            }
            .disabled(isDisplayingCurrentMonth)
            .accessibilityLabel(l.tr(
                zh: "下个月",
                en: "Next month",
                de: "Nächster Monat",
                es: "Mes siguiente",
                pt: "Próximo mês",
                fr: "Mois suivant",
                ja: "次の月",
                ko: "다음 달",
                it: "Mese successivo"
            ))
            .accessibilityIdentifier("zen-streak-next-month")
        }
        .foregroundStyle(Color.goPrimary)
    }

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols
        return LazyVGrid(columns: calendarColumns, spacing: 6) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    private var calendarPager: some View {
        TabView(selection: $monthPageOffset) {
            ForEach(calendarPageOffsets, id: \.self) { offset in
                calendarGrid(for: month(byAdding: offset))
                    .tag(offset)
                    .accessibilityLabel(monthTitle(for: month(byAdding: offset)))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: ZenCalendarViewportMetrics.pagerHeight(cellHeight: calendarCellHeight))
        .onChange(of: monthPageOffset) { _, offset in
            guard offset != 0 else { return }
            let targetMonth = month(byAdding: offset)
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedMonth = targetMonth
                monthPageOffset = 0
            }
        }
        .accessibilityIdentifier("zen-streak-month-pager")
    }

    private func calendarGrid(for month: Date) -> some View {
        let dayLookup = Dictionary(
            selectedDays.map { ($0.dayKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return LazyVGrid(columns: calendarColumns, spacing: ZenCalendarViewportMetrics.rowSpacing) {
            ForEach(ZenCalendarLayout.slots(for: month, calendar: calendar)) { slot in
                if let date = slot.date {
                    let key = dayKey(for: date)
                    let day = dayLookup[key]
                    ZenCalendarDayCell(
                        date: date,
                        day: day,
                        isFuture: calendar.startOfDay(for: date) > calendar.startOfDay(for: Date()),
                        localization: l,
                        languageCode: appLanguage,
                        cellHeight: calendarCellHeight,
                        onSelectRetrospectiveStatus: retrospectiveStatusAction(
                            date: date,
                            dayKey: key,
                            day: day
                        )
                    )
                } else {
                    Color.clear
                        .frame(height: max(
                            ZenCalendarViewportMetrics.standardCellHeight,
                            calendarCellHeight
                        ))
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, ZenCalendarViewportMetrics.verticalInset)
    }

    private var compactCalendarKey: some View {
        Text(l.tr(
            zh: "数字为状态分数 · ◌ 补记不计打卡 · ✓ 仅打卡 · — 未参与",
            en: "Number = score · ◌ remembered, not checked in · ✓ check-in only · — not participating",
            de: "Zahl = Wert · ◌ nachgetragen, kein Check-in · ✓ nur Check-in · — nicht teilgenommen",
            es: "Número = puntuación · ◌ recordado, sin check-in · ✓ solo check-in · — sin participación",
            pt: "Número = pontuação · ◌ lembrado, sem check-in · ✓ só check-in · — sem participação",
            fr: "Nombre = score · ◌ ajouté, sans check-in · ✓ check-in seul · — hors participation",
            ja: "数字＝状態スコア · ◌ 補記（チェックイン外）· ✓ チェックインのみ · — 未参加",
            ko: "숫자 = 상태 점수 · ◌ 보충 기록(체크인 아님) · ✓ 체크인만 · — 미참여",
            it: "Numero = punteggio · ◌ annotato, senza check-in · ✓ solo check-in · — non partecipante"
        ))
        .font(OhanaFont.caption2(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("zen-streak-calendar-key")
    }

    private var personalAnalyticsAction: some View {
        let canOpen = PersonalFeatureAccessPolicy.allows(
            .presenceLongRangeAnalytics,
            level: snapshot.personalAccessLevel
        )
        return Button(action: actions.onOpenPersonalAnalytics) {
            HStack(spacing: 12) {
                Image(systemName: canOpen ? "chart.xyaxis.line" : "lock.fill")
                    .font(OhanaFont.adaptive(size: 19, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(
                        zh: "趋势与分析",
                        en: "Trends and insights",
                        de: "Trends und Analysen",
                        es: "Tendencias y análisis",
                        pt: "Tendências e análises",
                        fr: "Tendances et analyses",
                        ja: "トレンドと分析",
                        ko: "추세 및 분석",
                        it: "Tendenze e analisi"
                    ))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(canOpen
                        ? l.tr(
                            zh: "90 天、1 年与全部时间",
                            en: "90 days, one year, and all time",
                            de: "90 Tage, ein Jahr und Gesamtzeit",
                            es: "90 días, un año y todo el historial",
                            pt: "90 dias, um ano e todo o histórico",
                            fr: "90 jours, un an et tout l’historique",
                            ja: "90日、1年、すべての期間",
                            ko: "90일, 1년 및 전체 기간",
                            it: "90 giorni, un anno e tutto il periodo"
                        )
                        : l.tr(
                            zh: "Ohana Personal 解锁",
                            en: "Unlock with Ohana Personal",
                            de: "Mit Ohana Personal freischalten",
                            es: "Desbloquear con Ohana Personal",
                            pt: "Desbloqueie com o Ohana Personal",
                            fr: "Débloquer avec Ohana Personal",
                            ja: "Ohana Personalでロック解除",
                            ko: "Ohana Personal로 잠금 해제",
                            it: "Sblocca con Ohana Personal"
                        ))
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right") // a11y: allow decorative chevron is hidden below
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(canOpen ? "zen-streak-personal-analytics" : "zen-streak-personal-upgrade")
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 32), spacing: 6), count: 7)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    private var monthTitle: String {
        monthTitle(for: displayedMonth)
    }

    private func monthTitle(for month: Date) -> String {
        month.formatted(
            .dateTime
                .year()
                .month(.wide)
                .locale(Locale(identifier: appLanguage))
        )
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var calendarPageOffsets: [Int] {
        isDisplayingCurrentMonth ? [-1, 0] : [-1, 0, 1]
    }

    private func month(byAdding value: Int) -> Date {
        calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    private func moveMonth(by value: Int) {
        guard value <= 0 || !isDisplayingCurrentMonth else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedMonth = month(byAdding: value)
            monthPageOffset = 0
        }
    }

    private func dayKey(for date: Date) -> String {
        ZenDayKey.key(for: date, calendar: calendar)
    }

    private func checkedCount(in month: Date) -> Int {
        let monthKey = ZenDayKey.monthKey(for: month, calendar: calendar)
        return selectedDays.count { $0.checkedIn && $0.dayKey.hasPrefix(monthKey) }
    }

    private func retrospectiveStatusAction(
        date: Date,
        dayKey: String,
        day: ZenPresenceDayDTO?
    ) -> (() -> Void)? {
        guard let subject = selectedSubject else { return nil }
        let todayKey = snapshot.dayKey.isEmpty
            ? ZenDayKey.key(for: Date(), calendar: calendar)
            : snapshot.dayKey
        let createdDayKey = ZenDayKey.key(for: subject.createdAt, calendar: calendar)
        let inactiveDayKey = subject.inactiveAt.map {
            ZenDayKey.key(for: $0, calendar: calendar)
        }
        guard ZenRetrospectiveStatusEligibility.allows(
            day: day,
            targetDayKey: dayKey,
            todayKey: todayKey,
            subjectCreatedDayKey: createdDayKey,
            subjectInactiveDayKey: inactiveDayKey,
            isAnonymousHistory: subject.isAnonymousHistory
        ) else { return nil }

        let draft = ZenRetrospectiveStatusDraft(
            subjectID: subject.id,
            subjectKind: subject.kind,
            subjectName: subject.name,
            dayKey: dayKey,
            date: date,
            initialScore: day?.isRetrospectiveStatus == true ? day?.status?.score ?? 5 : 5
        )
        return {
            retrospectiveStatusDraft = draft
        }
    }

    private func revealCalendarIfNeeded() {
        guard !calendarIsPresented else { return }
        calendarRevealTask?.cancel()
        if reduceMotion {
            calendarIsPresented = true
            return
        }
        calendarRevealTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 40) {
            withAnimation(GoMotion.zStackPopup) {
                calendarIsPresented = true
            }
            calendarRevealTask = nil
        }
    }
}

private struct ZenCalendarDayCell: View {
    let date: Date
    let day: ZenPresenceDayDTO?
    let isFuture: Bool
    let localization: L10n
    let languageCode: String
    let cellHeight: CGFloat
    let onSelectRetrospectiveStatus: (() -> Void)?

    private var fill: Color {
        guard !isFuture else { return Color.clear }
        if day?.checkedIn == true {
            return day?.status?.zenColor ?? Color(hex: "64748B")
        }
        if day?.isRetrospectiveStatus == true {
            return (day?.status?.zenColor ?? Color(hex: "64748B")).opacity(0.18)
        }
        if effectiveParticipation == .notParticipating {
            return Color.ohanaControlFill
        }
        if effectiveParticipation == .participating {
            return Color.goRed.opacity(0.16)
        }
        return Color.ohanaCardSurfaceElevated
    }

    /// The bounded read service emits explicit rows for every participating
    /// day, including misses. A missing past row therefore means the user was
    /// in Standard mode (or had not joined Zen yet), never a missed check-in.
    private var effectiveParticipation: ZenParticipationState {
        ZenCalendarPresentation.participation(for: day)
    }

    private var textColor: Color {
        if day?.checkedIn == true {
            return Color.ohanaPrimaryActionText
        }
        return isFuture ? Color.ohanaTertiaryText : Color.ohanaPrimaryText
    }

    private var dayContent: some View {
        ZStack {
            Circle().fill(fill)

            if day?.isRetrospectiveStatus == true, !isFuture {
                Circle()
                    .stroke(
                        day?.status?.zenColor ?? Color.ohanaSecondaryText,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3])
                    )
            }

            Text("\(Calendar.autoupdatingCurrent.component(.day, from: date))")
                .font(OhanaFont.footnote(.bold))
                .foregroundStyle(textColor)
                .offset(y: (day?.checkedIn == true || day?.isRetrospectiveStatus == true) && !isFuture ? -5 : 0)
                .contentTransition(.numericText())

            if day?.checkedIn == true, let score = day?.status?.score, !isFuture {
                Text("\(score)")
                    .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .offset(y: 11)
                    .accessibilityHidden(true)
            } else if day?.checkedIn == true, !isFuture {
                Image(systemName: "checkmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 7, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .offset(y: 11)
            } else if day?.isRetrospectiveStatus == true,
                      let score = day?.status?.score,
                      !isFuture {
                Text("\(score)")
                    .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(day?.status?.zenColor ?? Color.ohanaSecondaryText)
                    .offset(y: 11)
                    .accessibilityHidden(true)
            } else if effectiveParticipation == .notParticipating, !isFuture {
                Image(systemName: "minus") // a11y: allow decorative day status is hidden below
                    .font(OhanaFont.adaptive(size: 8, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .offset(y: 12)
                    .accessibilityHidden(true)
            } else if effectiveParticipation == .participating,
                      day?.checkedIn == false,
                      !isFuture {
                Circle()
                    .strokeBorder(Color.ohanaSecondaryText, lineWidth: 1)
                    .frame(width: 5, height: 5) // a11y: allow non-interactive day status dot
                    .offset(y: 13)
                .accessibilityHidden(true)
            }
        }
    }

    var body: some View {
        Group {
            if let onSelectRetrospectiveStatus {
                Button(action: onSelectRetrospectiveStatus) {
                    dayContent
                }
                .buttonStyle(.plain)
                .accessibilityHint(retrospectiveAccessibilityHint)
            } else {
                dayContent
            }
        }
        .frame(
            width: ZenCalendarViewportMetrics.circleDiameter(cellHeight: cellHeight),
            height: ZenCalendarViewportMetrics.circleDiameter(cellHeight: cellHeight)
        )
        .frame(
            maxWidth: .infinity,
            minHeight: max(ZenCalendarViewportMetrics.standardCellHeight, cellHeight),
            maxHeight: max(ZenCalendarViewportMetrics.standardCellHeight, cellHeight)
        )
        .animation(GoMotion.quick, value: day?.checkedIn)
        .animation(GoMotion.quick, value: day?.status)
        .animation(GoMotion.quick, value: day?.isRetrospectiveStatus)
        .animation(GoMotion.quick, value: effectiveParticipation)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dateText = date.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
                .locale(Locale(identifier: languageCode))
        )
        if isFuture {
            return dateText
        }
        if day?.checkedIn == true {
            let status = day?.status?.title(localization)
                ?? localization.tr(
                    zh: "已打卡",
                    en: "Checked in",
                    de: "Eingecheckt",
                    es: "Check-in hecho",
                    pt: "Check-in feito",
                    fr: "Check-in effectué",
                    ja: "チェックイン済み",
                    ko: "체크인 완료",
                    it: "Check-in fatto"
                )
            return "\(dateText), \(status)"
        }
        if day?.isRetrospectiveStatus == true, let status = day?.status {
            let retrospectiveText = localization.tr(
                zh: "补记状态，未打卡",
                en: "Remembered status, not checked in",
                de: "Status nachgetragen, nicht eingecheckt",
                es: "Estado recordado, sin check-in",
                pt: "Estado lembrado, sem check-in",
                fr: "État ajouté, sans check-in",
                ja: "状態を補記、チェックインなし",
                ko: "상태 보충 기록, 체크인 안 함",
                it: "Stato annotato, senza check-in"
            )
            return "\(dateText), \(status.title(localization)), \(retrospectiveText)"
        }
        if effectiveParticipation == .notParticipating {
            let participationText = localization.tr(
                zh: "未参与",
                en: "Not participating",
                de: "Nicht teilgenommen",
                es: "Sin participación",
                pt: "Sem participação",
                fr: "Hors participation",
                ja: "未参加",
                ko: "미참여",
                it: "Non partecipante"
            )
            return "\(dateText), \(participationText)"
        }
        let missedText = localization.tr(
            zh: "未打卡",
            en: "No check-in",
            de: "Kein Check-in",
            es: "Sin check-in",
            pt: "Sem check-in",
            fr: "Aucun check-in",
            ja: "チェックインなし",
            ko: "체크인 없음",
            it: "Nessun check-in"
        )
        return "\(dateText), \(missedText)"
    }

    private var retrospectiveAccessibilityHint: String {
        localization.tr(
            zh: "轻点补记或修改状态分数；不会恢复打卡或连续天数",
            en: "Tap to remember or edit a score; this will not restore the check-in or streak",
            de: "Tippen, um einen Wert nachzutragen; Check-in und Serie werden nicht wiederhergestellt",
            es: "Toca para recordar o editar una puntuación; no restaurará el check-in ni la racha",
            pt: "Toque para lembrar ou editar uma pontuação; isso não restaura o check-in nem a sequência",
            fr: "Touchez pour ajouter ou modifier un score ; le check-in et la série ne seront pas restaurés",
            ja: "タップして状態を補記・変更します。チェックインや連続記録は戻りません",
            ko: "탭하여 점수를 보충 기록하거나 수정하세요. 체크인이나 연속 기록은 복원되지 않아요",
            it: "Tocca per annotare o modificare un punteggio; check-in e serie non verranno ripristinati"
        )
    }
}

private struct ZenRetrospectiveStatusDraft: Identifiable, Equatable {
    let subjectID: String
    let subjectKind: ZenPresenceSubjectKind
    let subjectName: String
    let dayKey: String
    let date: Date
    let initialScore: Int

    var id: String { "\(subjectKind.rawValue):\(subjectID):\(dayKey)" }
}

private struct ZenRetrospectiveStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let draft: ZenRetrospectiveStatusDraft
    let localization: L10n
    let languageCode: String
    let onSave: (_ score: Int) async -> Void

    @State private var score: Double
    @State private var isSaving = false

    init(
        draft: ZenRetrospectiveStatusDraft,
        localization: L10n,
        languageCode: String,
        onSave: @escaping (_ score: Int) async -> Void
    ) {
        self.draft = draft
        self.localization = localization
        self.languageCode = languageCode
        self.onSave = onSave
        _score = State(initialValue: Double(min(max(draft.initialScore, 1), 10)))
    }

    private var selectedScore: Int { Int(score.rounded()) }
    private var selectedStatus: ZenPresenceStatus { ZenPresenceStatus(score: selectedScore) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Text(draft.subjectName)
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(draft.date.formatted(
                        .dateTime
                            .year()
                            .month(.wide)
                            .day()
                            .locale(Locale(identifier: languageCode))
                    ))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }

                VStack(spacing: 8) {
                    Text("\(selectedScore)/10")
                        .font(OhanaFont.metric(size: 42, .black))
                        .foregroundStyle(selectedStatus.zenColor)
                        .contentTransition(.numericText())
                    Text(selectedStatus.scoreBand.title(localization))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)

                    Slider(value: $score, in: 1 ... 10, step: 1)
                        .tint(selectedStatus.zenColor)
                        .accessibilityLabel(localization.tr(
                            zh: "状态分数",
                            en: "Status score",
                            de: "Statuswert",
                            es: "Puntuación de estado",
                            pt: "Pontuação de estado",
                            fr: "Score d’état",
                            ja: "状態スコア",
                            ko: "상태 점수",
                            it: "Punteggio di stato"
                        ))
                        .accessibilityValue("\(selectedScore)/10")
                }
                .animation(reduceMotion ? GoMotion.reduced : GoMotion.quick, value: selectedScore)

                Label {
                    Text(localization.tr(
                        zh: "这是补记，不会恢复当天打卡、连续天数或椰子奖励。",
                        en: "This is a remembered note. It will not restore that day’s check-in, streak, or coconut rewards.",
                        de: "Dies ist ein Nachtrag. Check-in, Serie und Kokosnuss-Belohnungen werden nicht wiederhergestellt.",
                        es: "Es una nota recordada. No restaurará el check-in, la racha ni las recompensas de cocos.",
                        pt: "Esta é uma anotação lembrada. Ela não restaura o check-in, a sequência nem recompensas de cocos.",
                        fr: "C’est un ajout rétrospectif. Il ne restaure ni le check-in, ni la série, ni les récompenses en noix de coco.",
                        ja: "これは補記です。その日のチェックイン、連続記録、ココナッツ報酬は戻りません。",
                        ko: "이 기록은 보충 메모입니다. 해당 날짜의 체크인, 연속 기록, 코코넛 보상은 복원되지 않아요.",
                        it: "È un’annotazione retrospettiva. Non ripristina check-in, serie o ricompense in cocco."
                    ))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true)
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.ohanaControlFill,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                )

                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.ohanaPrimaryActionText)
                        }
                        Text(localization.tr(
                            zh: "保存补记",
                            en: "Save remembered status",
                            de: "Nachtrag speichern",
                            es: "Guardar estado recordado",
                            pt: "Salvar estado lembrado",
                            fr: "Enregistrer l’état ajouté",
                            ja: "補記を保存",
                            ko: "보충 기록 저장",
                            it: "Salva stato annotato"
                        ))
                            .font(OhanaFont.callout(.bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: OhanaRadius.controlLarge))
                .tint(selectedStatus.zenColor)
                .disabled(isSaving)
                .accessibilityIdentifier("zen-retrospective-status-save")
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .navigationTitle(localization.tr(
                zh: "补记状态",
                en: "Remember a status",
                de: "Status nachtragen",
                es: "Recordar un estado",
                pt: "Lembrar um estado",
                fr: "Ajouter un état",
                ja: "状態を補記",
                ko: "상태 보충 기록",
                it: "Annota uno stato"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.tr(
                        zh: "取消",
                        en: "Cancel",
                        de: "Abbrechen",
                        es: "Cancelar",
                        pt: "Cancelar",
                        fr: "Annuler",
                        ja: "キャンセル",
                        ko: "취소",
                        it: "Annulla"
                    )) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .presentationDetents(OhanaSheetDetents.overview)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .accessibilityIdentifier("zen-retrospective-status-sheet")
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let value = selectedScore
        Task {
            await onSave(value)
            isSaving = false
            dismiss()
        }
    }
}
