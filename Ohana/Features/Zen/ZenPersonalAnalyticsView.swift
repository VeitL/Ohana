//
//  ZenPersonalAnalyticsView.swift
//  Ohana
//
//  Personal-only, value-snapshot analytics. The view never reaches into
//  SwiftData and its CSV export contains only the check-in facts on screen.
//

import Charts
import SwiftUI

@MainActor
struct ZenPersonalAnalyticsView: View {
    let snapshot: ZenPresenceSnapshot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedRange: ZenAnalyticsRange = .days90

    private var l: L10n { L10n(appLanguage) }

    private var filteredDays: [ZenPresenceDayDTO] {
        guard let cutoffDayKey = selectedRange.cutoffDayKey(calendar: .autoupdatingCurrent) else {
            return snapshot.days
        }
        return snapshot.days.filter { $0.dayKey >= cutoffDayKey }
    }

    private var analytics: ZenAnalyticsProjection {
        let subjects = snapshot.streakSubjects.isEmpty ? snapshot.subjects : snapshot.streakSubjects
        return ZenAnalyticsProjection(
            subjects: subjects,
            days: filteredDays,
            calendar: .autoupdatingCurrent
        )
    }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    rangePicker
                    summary
                    trendSection
                    statusSection
                    comparisonSection
                    exportAction
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(l.tr(
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(l.tr(
                    zh: "完成",
                    en: "Done",
                    de: "Fertig",
                    es: "Listo",
                    pt: "Concluído",
                    fr: "Terminé",
                    ja: "完了",
                    ko: "완료",
                    it: "Fatto"
                )) { dismiss() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-personal-analytics-screen")
    }

    private var rangePicker: some View {
        Picker(
            l.tr(
                zh: "时间范围",
                en: "Time range",
                de: "Zeitraum",
                es: "Periodo",
                pt: "Período",
                fr: "Période",
                ja: "期間",
                ko: "기간",
                it: "Intervallo"
            ),
            selection: $selectedRange
        ) {
            ForEach(ZenAnalyticsRange.allCases) { range in
                Text(range.title(l)).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("zen-analytics-range-picker")
    }

    private var summary: some View {
        HStack(spacing: 0) {
            analyticsMetric(
                value: "\(analytics.checkedCount)",
                title: l.tr(
                    zh: "完成打卡",
                    en: "Check-ins",
                    de: "Check-ins",
                    es: "Check-ins",
                    pt: "Check-ins",
                    fr: "Check-ins",
                    ja: "チェックイン",
                    ko: "체크인",
                    it: "Check-in"
                )
            )
            Divider().frame(height: 42)
            analyticsMetric(
                value: "\(analytics.completionRate)%",
                title: l.tr(
                    zh: "完成率",
                    en: "Completion",
                    de: "Abschlussrate",
                    es: "Cumplimiento",
                    pt: "Conclusão",
                    fr: "Réalisation",
                    ja: "達成率",
                    ko: "완료율",
                    it: "Completamento"
                )
            )
            Divider().frame(height: 42)
            analyticsMetric(
                value: "\(analytics.statusCount)",
                title: l.tr(
                    zh: "状态记录",
                    en: "Statuses",
                    de: "Statusangaben",
                    es: "Estados",
                    pt: "Status",
                    fr: "États",
                    ja: "状態記録",
                    ko: "상태 기록",
                    it: "Stati"
                )
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-analytics-summary")
    }

    private func analyticsMetric(value: String, title: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(OhanaFont.metric(size: 23, .black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
            Text(title)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .accessibilityElement(children: .combine)
    }

    private var trendSection: some View {
        analyticsSection(
            title: l.tr(
                zh: "每周完成率",
                en: "Weekly completion",
                de: "Wöchentlicher Abschluss",
                es: "Cumplimiento semanal",
                pt: "Conclusão semanal",
                fr: "Réalisation hebdomadaire",
                ja: "週ごとの達成率",
                ko: "주간 완료율",
                it: "Completamento settimanale"
            ),
            identifier: "zen-analytics-trend"
        ) {
            if analytics.weeklyBins.isEmpty {
                emptyAnalyticsMessage
            } else {
                Chart(analytics.weeklyBins) { bin in
                    AreaMark(
                        x: .value(l.tr(
                            zh: "周",
                            en: "Week",
                            de: "Woche",
                            es: "Semana",
                            pt: "Semana",
                            fr: "Semaine",
                            ja: "週",
                            ko: "주",
                            it: "Settimana"
                        ), bin.start),
                        y: .value(l.tr(
                            zh: "完成率",
                            en: "Completion",
                            de: "Abschlussrate",
                            es: "Cumplimiento",
                            pt: "Conclusão",
                            fr: "Réalisation",
                            ja: "達成率",
                            ko: "완료율",
                            it: "Completamento"
                        ), bin.rate)
                    )
                    .foregroundStyle(Color.goPrimary.opacity(0.16))

                    LineMark(
                        x: .value(l.tr(
                            zh: "周",
                            en: "Week",
                            de: "Woche",
                            es: "Semana",
                            pt: "Semana",
                            fr: "Semaine",
                            ja: "週",
                            ko: "주",
                            it: "Settimana"
                        ), bin.start),
                        y: .value(l.tr(
                            zh: "完成率",
                            en: "Completion",
                            de: "Abschlussrate",
                            es: "Cumplimiento",
                            pt: "Conclusão",
                            fr: "Réalisation",
                            ja: "達成率",
                            ko: "완료율",
                            it: "Completamento"
                        ), bin.rate)
                    )
                    .foregroundStyle(Color.goPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0 ... 100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine().foregroundStyle(Color.ohanaDivider)
                        AxisValueLabel {
                            if let percent = value.as(Int.self) {
                                Text("\(percent)%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l.tr(
                    zh: "每周完成率趋势，当前范围平均 \(analytics.completionRate)%",
                    en: "Weekly completion trend, averaging \(analytics.completionRate)% in this range",
                    de: "Wöchentlicher Trend, durchschnittlich \(analytics.completionRate)%",
                    es: "Tendencia semanal, con un promedio del \(analytics.completionRate)% en este periodo",
                    pt: "Tendência semanal, com média de \(analytics.completionRate)% neste período",
                    fr: "Tendance hebdomadaire, moyenne de \(analytics.completionRate) % sur cette période",
                    ja: "週ごとの達成率の推移、この期間の平均は \(analytics.completionRate)%",
                    ko: "주간 완료율 추세, 이 기간 평균 \(analytics.completionRate)%",
                    it: "Andamento settimanale, media del \(analytics.completionRate)% in questo intervallo"
                ))
            }
        }
    }

    private var statusSection: some View {
        analyticsSection(
            title: l.tr(
                zh: "状态分布",
                en: "Status distribution",
                de: "Statusverteilung",
                es: "Distribución de estados",
                pt: "Distribuição de status",
                fr: "Répartition des états",
                ja: "状態の分布",
                ko: "상태 분포",
                it: "Distribuzione degli stati"
            ),
            identifier: "zen-analytics-status-distribution"
        ) {
            let statusTotal = analytics.statusCount
            if statusTotal == 0 {
                emptyAnalyticsMessage
            } else {
                VStack(spacing: 10) {
                    ForEach(ZenPresenceStatus.allCases) { status in
                        let count = analytics.participatingDays.count(where: { $0.status == status })
                        statusDistributionRow(status: status, count: count, total: statusTotal)
                    }
                }
            }
        }
    }

    private func statusDistributionRow(
        status: ZenPresenceStatus,
        count: Int,
        total: Int
    ) -> some View {
        let fraction = total > 0 ? Double(count) / Double(total) : 0
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(status.zenColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(status.title(l))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(count) · \(Int((fraction * 100).rounded()))%")
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .monospacedDigit()
            }
            ProgressView(value: fraction)
                .tint(status.zenColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var comparisonSection: some View {
        analyticsSection(
            title: l.tr(
                zh: "对象比较",
                en: "Subject comparison",
                de: "Vergleich",
                es: "Comparación",
                pt: "Comparação",
                fr: "Comparaison",
                ja: "対象別の比較",
                ko: "대상 비교",
                it: "Confronto"
            ),
            identifier: "zen-analytics-subject-comparison"
        ) {
            if analytics.comparisonRows.isEmpty {
                emptyAnalyticsMessage
            } else {
                VStack(spacing: 0) {
                    ForEach(analytics.comparisonRows) { row in
                        HStack(spacing: 11) {
                            Image(systemName: row.subject.kind.icon)
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.subject.name)
                                    .font(OhanaFont.callout(.bold))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(2)
                                Text(l.tr(
                                    zh: "\(row.checkedCount) / \(row.participatingCount) 天",
                                    en: "\(row.checkedCount) of \(row.participatingCount) days",
                                    de: "\(row.checkedCount) von \(row.participatingCount) Tagen",
                                    es: "\(row.checkedCount) de \(row.participatingCount) días",
                                    pt: "\(row.checkedCount) de \(row.participatingCount) dias",
                                    fr: "\(row.checkedCount) jours sur \(row.participatingCount)",
                                    ja: "\(row.participatingCount)日中 \(row.checkedCount)日",
                                    ko: "\(row.participatingCount)일 중 \(row.checkedCount)일",
                                    it: "\(row.checkedCount) giorni su \(row.participatingCount)"
                                ))
                                .font(OhanaFont.caption())
                                .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            Spacer(minLength: 8)
                            Text("\(row.rate)%")
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.goPrimary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)

                        if row.id != analytics.comparisonRows.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var exportAction: some View {
        ShareLink(item: analytics.csvExport) {
            Label(
                l.tr(
                    zh: "导出 CSV",
                    en: "Export CSV",
                    de: "CSV exportieren",
                    es: "Exportar CSV",
                    pt: "Exportar CSV",
                    fr: "Exporter en CSV",
                    ja: "CSVを書き出す",
                    ko: "CSV 내보내기",
                    it: "Esporta CSV"
                ),
                systemImage: "square.and.arrow.up"
            )
            .font(OhanaFont.callout(.bold))
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
        .disabled(filteredDays.isEmpty)
        .accessibilityIdentifier("zen-analytics-export-action")
    }

    private func analyticsSection(
        title: String,
        identifier: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var emptyAnalyticsMessage: some View {
        Label(
            l.tr(
                zh: "这个范围还没有数据",
                en: "No data in this range",
                de: "Keine Daten in diesem Zeitraum",
                es: "No hay datos en este periodo",
                pt: "Não há dados neste período",
                fr: "Aucune donnée sur cette période",
                ja: "この期間にはまだデータがありません",
                ko: "이 기간에는 데이터가 없어요",
                it: "Nessun dato in questo intervallo"
            ),
            systemImage: "chart.xyaxis.line"
        )
        .font(OhanaFont.callout(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity, minHeight: 72)
    }
}

enum ZenAnalyticsRange: String, CaseIterable, Identifiable {
    case days90
    case year
    case all

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .days90:
            l.tr(
                zh: "90 天",
                en: "90 days",
                de: "90 Tage",
                es: "90 días",
                pt: "90 dias",
                fr: "90 jours",
                ja: "90日",
                ko: "90일",
                it: "90 giorni"
            )
        case .year:
            l.tr(
                zh: "1 年",
                en: "1 year",
                de: "1 Jahr",
                es: "1 año",
                pt: "1 ano",
                fr: "1 an",
                ja: "1年",
                ko: "1년",
                it: "1 anno"
            )
        case .all:
            l.tr(
                zh: "全部",
                en: "All",
                de: "Alle",
                es: "Todo",
                pt: "Tudo",
                fr: "Tout",
                ja: "すべて",
                ko: "전체",
                it: "Tutto"
            )
        }
    }

    func cutoffDayKey(calendar: Calendar, now: Date = Date()) -> String? {
        let cutoff: Date? = switch self {
        case .days90:
            calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
        case .year:
            calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: now))
        case .all:
            nil
        }
        return cutoff.map { ZenDayKey.key(for: $0, calendar: calendar) }
    }
}

struct ZenAnalyticsWeekBin: Identifiable, Equatable {
    let start: Date
    let checkedCount: Int
    let participatingCount: Int

    var id: Date { start }
    var rate: Int {
        guard participatingCount > 0 else { return 0 }
        return Int((Double(checkedCount) / Double(participatingCount) * 100).rounded())
    }
}

struct ZenAnalyticsSubjectRow: Identifiable, Equatable {
    let subject: ZenPresenceSubjectDTO
    let checkedCount: Int
    let participatingCount: Int

    var id: String { subject.id }
    var rate: Int {
        guard participatingCount > 0 else { return 0 }
        return Int((Double(checkedCount) / Double(participatingCount) * 100).rounded())
    }
}

/// A value-only analytics projection. Only explicitly participating days enter
/// completion denominators; standard-mode dates remain visible in raw exports
/// without being mislabeled as missed Zen check-ins.
struct ZenAnalyticsProjection {
    let subjects: [ZenPresenceSubjectDTO]
    let days: [ZenPresenceDayDTO]
    let calendar: Calendar

    var participatingDays: [ZenPresenceDayDTO] {
        days.filter { $0.participation == .participating }
    }

    var checkedCount: Int {
        participatingDays.count(where: \.checkedIn)
    }

    var statusCount: Int {
        participatingDays.count(where: { $0.status != nil })
    }

    var completionRate: Int {
        guard !participatingDays.isEmpty else { return 0 }
        return Int((Double(checkedCount) / Double(participatingDays.count) * 100).rounded())
    }

    var weeklyBins: [ZenAnalyticsWeekBin] {
        let grouped = Dictionary(grouping: participatingDays) { day in
            guard let date = ZenDayKey.date(day.dayKey, calendar: calendar) else {
                return Date.distantPast
            }
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
        return grouped.map { start, days in
            ZenAnalyticsWeekBin(
                start: start,
                checkedCount: days.count(where: \.checkedIn),
                participatingCount: days.count
            )
        }
        .sorted { $0.start < $1.start }
    }

    var comparisonRows: [ZenAnalyticsSubjectRow] {
        subjects.compactMap { subject in
            let subjectDays = participatingDays.filter { $0.subjectID == subject.id }
            guard !subjectDays.isEmpty else { return nil }
            return ZenAnalyticsSubjectRow(
                subject: subject,
                checkedCount: subjectDays.count(where: \.checkedIn),
                participatingCount: subjectDays.count
            )
        }
    }

    var csvExport: String {
        let names = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0.name) })
        var rows = ["subject,date,participation,checked,status"]
        rows += days.sorted { lhs, rhs in
            if lhs.dayKey == rhs.dayKey { return lhs.subjectID < rhs.subjectID }
            return lhs.dayKey < rhs.dayKey
        }.map { day in
            let name = Self.csvEscaped(names[day.subjectID] ?? day.subjectID)
            let status = Self.csvEscaped(day.status?.rawValue ?? "")
            return "\(name),\(day.dayKey),\(day.participation.rawValue),\(day.checkedIn),\(status)"
        }
        return rows.joined(separator: "\n")
    }

    private static func csvEscaped(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
