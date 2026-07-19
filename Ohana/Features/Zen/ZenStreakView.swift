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
    @State private var selectedSubjectID: String?
    @State private var displayedMonth: Date

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
                VStack(alignment: .leading, spacing: 18) {
                    subjectPicker
                    metrics
                    calendarCard
                    legend
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
        VStack(spacing: 14) {
            monthHeader
            weekdayHeader
            calendarGrid
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
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

    private var calendarGrid: some View {
        let dayLookup = Dictionary(
            selectedDays.map { ($0.dayKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return LazyVGrid(columns: calendarColumns, spacing: 8) {
            ForEach(ZenCalendarLayout.slots(for: displayedMonth, calendar: calendar)) { slot in
                if let date = slot.date {
                    ZenCalendarDayCell(
                        date: date,
                        day: dayLookup[dayKey(for: date)],
                        isFuture: calendar.startOfDay(for: date) > calendar.startOfDay(for: Date()),
                        localization: l,
                        languageCode: appLanguage
                    )
                } else {
                    Color.clear
                        .frame(minHeight: 42)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var legend: some View {
        let columns = [GridItem(.adaptive(minimum: 118), spacing: 8, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(ZenPresenceStatus.allCases) { status in
                legendItem(color: status.zenColor, icon: status.icon, title: status.title(l))
            }
            legendItem(
                color: Color.goPrimary,
                icon: "checkmark",
                title: l.tr(
                    zh: "仅打卡",
                    en: "Checked in",
                    de: "Eingecheckt",
                    es: "Check-in hecho",
                    pt: "Check-in feito",
                    fr: "Check-in effectué",
                    ja: "チェックインのみ",
                    ko: "체크인만",
                    it: "Check-in fatto"
                )
            )
            legendItem(
                color: Color.ohanaControlFill,
                icon: "minus",
                title: l.tr(
                    zh: "未参与",
                    en: "Not participating",
                    de: "Nicht teilgenommen",
                    es: "Sin participación",
                    pt: "Sem participação",
                    fr: "Hors participation",
                    ja: "未参加",
                    ko: "미참여",
                    it: "Non partecipante"
                ),
                usesSecondarySymbol: true
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-streak-status-legend")
    }

    private func legendItem(
        color: Color,
        icon: String,
        title: String,
        usesSecondarySymbol: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(color)
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 8, weight: .black))
                    .foregroundStyle(usesSecondarySymbol ? Color.ohanaSecondaryText : Color.ohanaPrimaryActionText)
            }
            .frame(width: 18, height: 18) // a11y: allow non-interactive legend glyph
            Text(title)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
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
        displayedMonth.formatted(
            .dateTime
                .year()
                .month(.wide)
                .locale(Locale(identifier: appLanguage))
        )
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func moveMonth(by value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = date
    }

    private func dayKey(for date: Date) -> String {
        ZenDayKey.key(for: date, calendar: calendar)
    }

    private func checkedCount(in month: Date) -> Int {
        let monthKey = ZenDayKey.monthKey(for: month, calendar: calendar)
        return selectedDays.count { $0.checkedIn && $0.dayKey.hasPrefix(monthKey) }
    }
}

private struct ZenCalendarDayCell: View {
    let date: Date
    let day: ZenPresenceDayDTO?
    let isFuture: Bool
    let localization: L10n
    let languageCode: String

    private var fill: Color {
        guard !isFuture else { return Color.clear }
        if day?.checkedIn == true {
            return day?.status?.zenColor ?? Color.goPrimary
        }
        if effectiveParticipation == .notParticipating {
            return Color.ohanaControlFill
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                .fill(fill)

            Text("\(Calendar.autoupdatingCurrent.component(.day, from: date))")
                .font(OhanaFont.footnote(.bold))
                .foregroundStyle(textColor)

            if day?.checkedIn == true, !isFuture {
                Image(systemName: day?.status?.icon ?? "checkmark")
                    .font(OhanaFont.adaptive(size: 7, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .offset(y: 13)
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
        .frame(maxWidth: .infinity, minHeight: 42)
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
}
