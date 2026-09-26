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

    private var selectedPresentationSubject: ZenPresenceSubjectDTO? {
        guard let selectedSubject else { return nil }
        if selectedSubject.kind == .plant,
           let activeSubject = snapshot.subjects.first(where: { $0.id == selectedSubject.id }) {
            // Active Home snapshots carry the Plant expanded-profile projection,
            // whose care-day metric already prefers acquiredDate over createdAt.
            return activeSubject
        }
        return selectedSubject
    }

    private var isPlantSelected: Bool {
        selectedSubject?.kind == .plant
    }

    private var selectedSemantic: ZenPresenceRecordSemantic {
        selectedSubject?.recordSemantic ?? .ownerSafety
    }

    private var screenTitle: String {
        switch selectedSemantic {
        case .ownerSafety:
            l.tr(
                zh: "平安日历",
                en: "Safety calendar",
                de: "Bestätigungskalender",
                es: "Calendario de bienestar",
                pt: "Calendário de segurança",
                fr: "Calendrier de confirmation",
                ja: "無事確認カレンダー",
                ko: "무사 확인 달력",
                it: "Calendario di conferma"
            )
        case .humanContact:
            l.tr(
                zh: "联系日历",
                en: "Contact calendar",
                de: "Kontaktkalender",
                es: "Calendario de contacto",
                pt: "Calendário de contato",
                fr: "Calendrier de contact",
                ja: "連絡カレンダー",
                ko: "연락 달력",
                it: "Calendario dei contatti"
            )
        case .petObservation:
            l.tr(
                zh: "观察日历",
                en: "Observation calendar",
                de: "Beobachtungskalender",
                es: "Calendario de observación",
                pt: "Calendário de observação",
                fr: "Calendrier d’observation",
                ja: "観察カレンダー",
                ko: "관찰 달력",
                it: "Calendario delle osservazioni"
            )
        case .plantObservation:
            l.tr(
                zh: "陪伴日历",
                en: "Companion calendar",
                de: "Begleitkalender",
                es: "Calendario de compañía",
                pt: "Calendário de companhia",
                fr: "Calendrier de compagnie",
                ja: "一緒のカレンダー",
                ko: "함께한 달력",
                it: "Calendario insieme"
            )
        }
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
                    if selectedSubject?.isOwner == true {
                        ownerStreakReassurance
                    }
                    calendarCard
                    personalAnalyticsAction
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(screenTitle)
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
                icon: isPlantSelected ? "heart.fill" : "flame.fill"
            )

            Divider()
                .frame(height: 42)

            metric(
                value: secondaryMetricValue,
                title: secondaryMetricTitle,
                icon: isPlantSelected ? "sparkles" : "trophy.fill"
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

    private var ownerStreakReassurance: some View {
        Label {
            Text(l.tr(
                zh: "中断会开启新一轮，最佳记录保留。",
                en: "A missed day starts a new round; your best stays.",
                de: "Eine Pause startet eine neue Runde; dein Bestwert bleibt.",
                es: "Una pausa inicia otra ronda; tu mejor marca permanece.",
                pt: "Uma pausa inicia outra rodada; seu melhor fica.",
                fr: "Une pause ouvre un nouveau cycle ; votre record reste.",
                ja: "途切れても新しい一周が始まり、最高記録は残ります。",
                ko: "쉬어도 새 라운드가 시작되고 최고 기록은 남아요.",
                it: "Una pausa apre un nuovo giro; il record resta."
            ))
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90") // a11y: allow decorative icon; adjacent reassurance text carries the meaning
                .accessibilityHidden(true)
                .foregroundStyle(Color.goPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("zen-streak-reassurance")
    }

    private var primaryMetricValue: Int {
        if isPlantSelected {
            return selectedPresentationSubject?.plantCompanionDays(calendar: calendar) ?? 1
        }
        return selectedSubject?.isOwner == true
            ? snapshot.currentStreak
            : checkedCount(in: displayedMonth)
    }

    private var secondaryMetricValue: Int {
        if isPlantSelected {
            return selectedDays.count(where: \.checkedIn)
        }
        return selectedSubject?.isOwner == true
            ? snapshot.longestStreak
            : selectedDays.count(where: \.checkedIn)
    }

    private var primaryMetricTitle: String {
        switch selectedSemantic {
        case .plantObservation:
            l.tr(
                zh: "已陪伴天数",
                en: "Days together",
                de: "Tage zusammen",
                es: "Días juntos",
                pt: "Dias juntos",
                fr: "Jours ensemble",
                ja: "一緒にいる日数",
                ko: "함께한 날",
                it: "Giorni insieme"
            )
        case .ownerSafety:
            l.tr(
                zh: "当前连续确认",
                en: "Current confirmations",
                de: "Aktuelle Serie",
                es: "Racha actual",
                pt: "Sequência atual",
                fr: "Série actuelle",
                ja: "現在の連続記録",
                ko: "현재 연속 기록",
                it: "Serie attuale"
            )
        case .humanContact:
            l.tr(
                zh: "本月联系",
                en: "Contacts this month",
                de: "Kontakte diesen Monat",
                es: "Contactos este mes",
                pt: "Contatos neste mês",
                fr: "Contacts ce mois-ci",
                ja: "今月の連絡",
                ko: "이번 달 연락",
                it: "Contatti del mese"
            )
        case .petObservation:
            l.tr(
                zh: "本月观察",
                en: "Observations this month",
                de: "Diesen Monat",
                es: "Este mes",
                pt: "Este mês",
                fr: "Ce mois-ci",
                ja: "今月の観察",
                ko: "이번 달 관찰",
                it: "Questo mese"
            )
        }
    }

    private var secondaryMetricTitle: String {
        switch selectedSemantic {
        case .plantObservation, .petObservation:
            l.tr(
                zh: "观察记录",
                en: "Observations",
                de: "Beobachtungen",
                es: "Observaciones",
                pt: "Observações",
                fr: "Observations",
                ja: "観察記録",
                ko: "관찰 기록",
                it: "Osservazioni"
            )
        case .ownerSafety:
            l.tr(
                zh: "最长连续确认",
                en: "Longest confirmations",
                de: "Längste Serie",
                es: "Racha más larga",
                pt: "Maior sequência",
                fr: "Série la plus longue",
                ja: "最長の連続記録",
                ko: "최장 연속 기록",
                it: "Serie più lunga"
            )
        case .humanContact:
            l.tr(
                zh: "累计联系",
                en: "All contacts",
                de: "Alle Kontakte",
                es: "Todos los contactos",
                pt: "Todos os contatos",
                fr: "Tous les contacts",
                ja: "連絡の合計",
                ko: "전체 연락",
                it: "Tutti i contatti"
            )
        }
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
                        recordSemantic: selectedSemantic,
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
        Text(compactCalendarKeyText)
        .font(OhanaFont.caption2(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("zen-streak-calendar-key")
    }

    private var compactCalendarKeyText: String {
        switch selectedSemantic {
        case .plantObservation, .petObservation:
            l.tr(
                zh: "数字为观察分数 · ◌ 补记观察 · ✓ 当天记录 · — 无观察记录",
                en: "Number = observation score · ◌ remembered · ✓ recorded that day · — no observation",
                de: "Zahl = Beobachtungswert · ◌ nachgetragen · ✓ an diesem Tag erfasst · — keine Beobachtung",
                es: "Número = puntuación observada · ◌ recordado · ✓ registrado ese día · — sin observación",
                pt: "Número = pontuação observada · ◌ lembrado · ✓ registrado no dia · — sem observação",
                fr: "Nombre = score observé · ◌ ajouté · ✓ noté ce jour-là · — sans observation",
                ja: "数字＝観察スコア · ◌ あとから記録 · ✓ 当日の記録 · — 観察記録なし",
                ko: "숫자 = 관찰 점수 · ◌ 나중에 기록 · ✓ 당일 기록 · — 관찰 기록 없음",
                it: "Numero = punteggio osservato · ◌ annotato · ✓ registrato quel giorno · — nessuna osservazione"
            )
        case .humanContact:
            l.tr(
                zh: "数字为状态分数 · ◌ 补记状态 · ✓ 当天联系 · — 无联系记录",
                en: "Number = score · ◌ remembered status · ✓ contact that day · — no contact",
                de: "Zahl = Wert · ◌ Status nachgetragen · ✓ Kontakt an diesem Tag · — kein Kontakt",
                es: "Número = puntuación · ◌ estado recordado · ✓ contacto ese día · — sin contacto",
                pt: "Número = pontuação · ◌ status lembrado · ✓ contato no dia · — sem contato",
                fr: "Nombre = score · ◌ état ajouté · ✓ contact ce jour-là · — sans contact",
                ja: "数字＝状態スコア · ◌ 状態を補記 · ✓ 当日の連絡 · — 連絡記録なし",
                ko: "숫자 = 상태 점수 · ◌ 상태 보충 기록 · ✓ 당일 연락 · — 연락 기록 없음",
                it: "Numero = punteggio · ◌ stato annotato · ✓ contatto del giorno · — nessun contatto"
            )
        case .ownerSafety:
            l.tr(
                zh: "数字为状态分数 · ◌ 仅补记状态 · ✓ 当天平安确认 · — 未参与",
                en: "Number = score · ◌ status note only · ✓ safety confirmed · — not participating",
                de: "Zahl = Wert · ◌ nur Statusnotiz · ✓ bestätigt · — nicht teilgenommen",
                es: "Número = puntuación · ◌ solo nota de estado · ✓ confirmado · — sin participación",
                pt: "Número = pontuação · ◌ só nota de status · ✓ confirmado · — sem participação",
                fr: "Nombre = score · ◌ simple note d’état · ✓ confirmation · — hors participation",
                ja: "数字＝状態スコア · ◌ 状態の補記のみ · ✓ 無事確認 · — 未参加",
                ko: "숫자 = 상태 점수 · ◌ 상태 메모만 · ✓ 무사 확인 · — 미참여",
                it: "Numero = punteggio · ◌ sola nota di stato · ✓ conferma · — non partecipante"
            )
        }
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
                    if !canOpen {
                        Text(l.tr(
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
            recordSemantic: subject.recordSemantic,
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
    let recordSemantic: ZenPresenceRecordSemantic
    let localization: L10n
    let languageCode: String
    let cellHeight: CGFloat
    let onSelectRetrospectiveStatus: (() -> Void)?

    private var isPlant: Bool {
        recordSemantic == .plantObservation
    }

    private var usesObservationCopy: Bool {
        recordSemantic == .petObservation || recordSemantic == .plantObservation
    }

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
            return isPlant ? Color.ohanaControlFill : Color.goRed.opacity(0.16)
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
            return checkedInForeground
        }
        return isFuture ? Color.ohanaTertiaryText : Color.ohanaPrimaryText
    }

    private var checkedInForeground: Color {
        guard let score = day?.status?.score else { return Color.goCardWhite }
        return OhanaResolvedPrimaryAccent(
            customHex: ZenPresenceScorePalette.hex(for: score)
        )?.actionTextColor ?? Color.goCardWhite
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
                    .foregroundStyle(checkedInForeground)
                    .offset(y: 11)
                    .accessibilityHidden(true)
            } else if day?.checkedIn == true, !isFuture {
                Image(systemName: "checkmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 7, weight: .black))
                    .foregroundStyle(checkedInForeground)
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
                ?? recordedThatDayText
            return "\(dateText), \(status)"
        }
        if day?.isRetrospectiveStatus == true, let status = day?.status {
            return "\(dateText), \(status.title(localization)), \(retrospectiveRecordText)"
        }
        if effectiveParticipation == .notParticipating {
            return "\(dateText), \(notParticipatingText)"
        }
        return "\(dateText), \(missingRecordText)"
    }

    private var recordedThatDayText: String {
        switch recordSemantic {
        case .ownerSafety:
            localization.tr(
                zh: "当天已平安确认", en: "Safety confirmed that day",
                de: "An diesem Tag bestätigt", es: "Bienestar confirmado ese día",
                pt: "Segurança confirmada no dia", fr: "Confirmation effectuée ce jour-là",
                ja: "当日に無事確認済み", ko: "당일 무사 확인됨", it: "Conferma effettuata quel giorno"
            )
        case .humanContact:
            localization.tr(
                zh: "当天已联系", en: "Contact recorded that day",
                de: "Kontakt an diesem Tag", es: "Contacto registrado ese día",
                pt: "Contato registrado no dia", fr: "Contact noté ce jour-là",
                ja: "当日に連絡済み", ko: "당일 연락 기록됨", it: "Contatto registrato quel giorno"
            )
        case .petObservation, .plantObservation:
            localization.tr(
                zh: "当天已观察", en: "Observed that day",
                de: "An diesem Tag beobachtet", es: "Observado ese día",
                pt: "Observado no dia", fr: "Observé ce jour-là",
                ja: "当日に観察済み", ko: "당일 관찰됨", it: "Osservato quel giorno"
            )
        }
    }

    private var retrospectiveRecordText: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "补记观察，未形成当天记录",
                en: "Remembered observation, not a same-day record",
                de: "Beobachtung nachgetragen, kein Eintrag vom selben Tag",
                es: "Observación recordada, no es un registro del mismo día",
                pt: "Observação lembrada, não é um registro do mesmo dia",
                fr: "Observation ajoutée, pas une note du jour même",
                ja: "あとから観察を記録、当日の記録ではありません",
                ko: "나중에 관찰을 기록함, 당일 기록은 아님",
                it: "Osservazione annotata, non registrata lo stesso giorno"
            )
        }
        if recordSemantic == .humanContact {
            return localization.tr(
                zh: "补记状态，不代表当天联系", en: "Remembered status, not same-day contact",
                de: "Status nachgetragen, kein Kontakt am selben Tag",
                es: "Estado recordado, no es contacto del mismo día",
                pt: "Status lembrado, não é contato no mesmo dia",
                fr: "État ajouté, pas un contact du jour même",
                ja: "状態を補記、当日の連絡ではありません",
                ko: "상태 보충 기록, 당일 연락은 아님",
                it: "Stato annotato, non è un contatto dello stesso giorno"
            )
        }
        return localization.tr(
            zh: "补记状态，不代表当天平安确认", en: "Remembered status, not a safety confirmation",
            de: "Status nachgetragen, keine Bestätigung", es: "Estado recordado, no es una confirmación",
            pt: "Status lembrado, não é uma confirmação", fr: "État ajouté, pas une confirmation",
            ja: "状態を補記、当日の無事確認ではありません",
            ko: "상태 보충 기록, 당일 무사 확인은 아님",
            it: "Stato annotato, non è una conferma"
        )
    }

    private var notParticipatingText: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "未参与观察", en: "Not participating in observations",
                de: "Keine Beobachtungsteilnahme", es: "Sin participación en observaciones",
                pt: "Sem participação em observações", fr: "Hors période d’observation",
                ja: "観察に未参加", ko: "관찰 미참여", it: "Fuori dal periodo di osservazione"
            )
        }
        return localization.tr(
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
    }

    private var missingRecordText: String {
        switch recordSemantic {
        case .ownerSafety:
            localization.tr(
                zh: "未确认平安", en: "Safety not confirmed",
                de: "Nicht bestätigt", es: "Bienestar sin confirmar",
                pt: "Segurança não confirmada", fr: "Confirmation absente",
                ja: "無事未確認", ko: "무사 미확인", it: "Conferma assente"
            )
        case .humanContact:
            localization.tr(
                zh: "无联系记录", en: "No contact recorded",
                de: "Kein Kontakt erfasst", es: "Sin contacto registrado",
                pt: "Nenhum contato registrado", fr: "Aucun contact noté",
                ja: "連絡記録なし", ko: "연락 기록 없음", it: "Nessun contatto registrato"
            )
        case .petObservation, .plantObservation:
            localization.tr(
                zh: "未记录观察",
                en: "No observation recorded",
                de: "Keine Beobachtung erfasst",
                es: "Sin observación registrada",
                pt: "Nenhuma observação registrada",
                fr: "Aucune observation notée",
                ja: "観察記録なし",
                ko: "관찰 기록 없음",
                it: "Nessuna osservazione registrata"
            )
        }
    }

    private var retrospectiveAccessibilityHint: String {
        if usesObservationCopy {
            return localization.tr(
                zh: "轻点补记或修改观察分数；不会变成当天记录或产生椰子奖励",
                en: "Tap to remember or edit an observation score; it will not become a same-day record or earn coconut rewards",
                de: "Tippen, um einen Beobachtungswert nachzutragen; daraus wird kein Tageseintrag und es gibt keine Kokosnuss-Belohnung",
                es: "Toca para recordar o editar una observación; no será un registro del mismo día ni dará cocos",
                pt: "Toque para lembrar ou editar uma observação; ela não vira registro do mesmo dia nem gera cocos",
                fr: "Touchez pour ajouter ou modifier une observation ; elle ne deviendra pas une note du jour et ne donnera pas de noix de coco",
                ja: "タップして観察スコアを補記・変更します。当日の記録やココナッツ報酬にはなりません",
                ko: "탭하여 관찰 점수를 나중에 기록하거나 수정하세요. 당일 기록이나 코코넛 보상이 되지는 않아요",
                it: "Tocca per annotare o modificare un’osservazione; non diventa una registrazione del giorno e non dà ricompense in cocco"
            )
        }
        if recordSemantic == .humanContact {
            return localization.tr(
                zh: "轻点补记或修改状态分数；不会变成当天联系记录或产生椰子奖励",
                en: "Tap to remember or edit a score; it will not become same-day contact or earn coconut rewards",
                de: "Tippen, um einen Wert nachzutragen; daraus wird kein Kontakt und es gibt keine Belohnung",
                es: "Toca para recordar una puntuación; no será contacto del mismo día ni dará cocos",
                pt: "Toque para lembrar uma pontuação; ela não vira contato do dia nem gera cocos",
                fr: "Touchez pour ajouter un score ; il ne deviendra pas un contact du jour et ne donnera pas de récompense",
                ja: "状態を補記・変更します。当日の連絡や報酬にはなりません",
                ko: "상태 점수를 보충 기록해도 당일 연락이나 보상이 되지 않아요",
                it: "Tocca per annotare un punteggio; non diventa un contatto del giorno e non dà ricompense"
            )
        }
        return localization.tr(
            zh: "轻点补记或修改状态分数；不会恢复平安确认、连续天数或椰子奖励",
            en: "Tap to remember or edit a score; this will not restore the safety confirmation, streak, or rewards",
            de: "Tippen, um einen Wert nachzutragen; Bestätigung, Serie und Belohnung werden nicht wiederhergestellt",
            es: "Toca para recordar una puntuación; no restaurará la confirmación, la racha ni las recompensas",
            pt: "Toque para lembrar uma pontuação; isso não restaura a confirmação, a sequência nem recompensas",
            fr: "Touchez pour ajouter un score ; confirmation, série et récompenses ne seront pas restaurées",
            ja: "状態を補記しても、無事確認・連続記録・報酬は戻りません",
            ko: "상태 점수를 보충 기록해도 무사 확인, 연속 기록, 보상은 복원되지 않아요",
            it: "Tocca per annotare un punteggio; conferma, serie e ricompense non verranno ripristinate"
        )
    }
}
