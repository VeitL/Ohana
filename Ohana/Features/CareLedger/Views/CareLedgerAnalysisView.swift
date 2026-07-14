//
//  CareLedgerAnalysisView.swift
//  Ohana
//
//  Analysis surface for the unified care ledger.
//

import SwiftData
import SwiftUI

struct CareLedgerAnalysisContentView: View {
    let ledgerEvents: [CareLedgerEvent]
    let pets: [Pet]
    let humans: [Human]

    @State private var screenModel = CareLedgerAnalysisScreenModel()
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    filterCard
                    dailyTrendCard
                    kindBreakdownCard
                    actorBreakdownCard
                    latestEventsCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(l.tr(zh: "照护账本分析", en: "Care ledger analysis", de: "Pflegebuch-Analyse"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncScreenModel)
        .onChange(of: ledgerEvents.count) { syncScreenModel() }
        .onChange(of: pets.count) { syncScreenModel() }
        .onChange(of: humans.count) { syncScreenModel() }
    }

    private func syncScreenModel() {
        screenModel.applyQuerySnapshot(
            ledgerEvents: ledgerEvents,
            pets: pets,
            humans: humans
        )
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "统一照护事件账本", en: "Unified care event ledger", de: "Einheitliches Pflegeereignis-Buch"))
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                    Text(l.tr(
                        zh: "用同一事件层查看谁、给谁、做了什么",
                        en: "See who did what for whom from one event layer",
                        de: "Sieh in einer Ereignisebene, wer was fuer wen getan hat"
                    ))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                metric(l.tr(zh: "现实操作", en: "Actions", de: "Aktionen"), "\(screenModel.realOperationCount)", .goPrimary)
                metric(l.tr(zh: "对象覆盖", en: "Coverage", de: "Abdeckung"), "\(screenModel.objectCoverageCount)", .goTeal)
                metric(l.tr(zh: "奖励", en: "Rewards", de: "Belohnungen"), "\(screenModel.positiveRewardTotal)🥥", .goYellow)
            }
            Text(l.tr(
                zh: "同一批量或共享照护只计一次现实操作；每个被照护对象各计一次覆盖。",
                en: "A batch or shared-care session counts as one action; each cared-for subject counts once toward coverage.",
                de: "Eine Sammel- oder gemeinsame Pflege zaehlt als eine Aktion; jedes versorgte Objekt als eine Abdeckung."
            ))
                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "筛选", en: "Filter", de: "Filter"), icon: "line.3.horizontal.decrease.circle.fill")
            Picker(l.tr(zh: "范围", en: "Range", de: "Zeitraum"), selection: $screenModel.selectedRange) {
                ForEach(CareLedgerRangeFilter.allCases, id: \.self) { range in
                    Text(range.title(l: l)).tag(range)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    kindChip(title: l.tr(zh: "全部", en: "All", de: "Alle"), kind: nil)
                    ForEach(CareLedgerEventKind.allCases, id: \.self) { kind in
                        if kind != .unknown {
                            kindChip(title: kind.displayName(l: l), kind: kind)
                        }
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var kindBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "事件类型分布", en: "Event type breakdown", de: "Ereignistyp-Verteilung"), icon: "chart.bar.xaxis")
            if screenModel.kindStats.isEmpty {
                emptyText(l.tr(zh: "暂无账本事件", en: "No ledger events yet", de: "Noch keine Buchereignisse"))
            } else {
                ForEach(screenModel.kindStats, id: \.0) { kind, count in
                    statBar(title: kind.displayName(l: l), count: count, total: max(screenModel.realOperationCount, 1), color: kind.color)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var dailyTrendCard: some View {
        let trendPoints = screenModel.dailyTrendPoints
        let hasEvents = screenModel.dailyTrendTotal > 0
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "照护趋势", en: "Care trend", de: "Pflegetrend"), icon: "chart.xyaxis.line")
            if hasEvents {
                OhanaMinimalBarChart(
                    points: trendPoints,
                    tint: .goTeal,
                    showsLabels: true,
                    maxBarHeight: 58,
                    emptyBarColor: Color.ohanaControlFill.opacity(0.65)
                )
                .frame(height: 86)
                .accessibilityLabel(l.tr(
                    zh: "照护账本每日趋势图",
                    en: "Daily care ledger trend chart",
                    de: "Taegliches Pflegebuch-Trenddiagramm"
                ))

                HStack(spacing: 10) {
                    metric(
                        l.tr(zh: "活跃天", en: "Active days", de: "Aktive Tage"),
                        "\(screenModel.dailyTrendActiveDayCount)",
                        .goTeal
                    )
                    metric(
                        l.tr(zh: "日均", en: "Daily avg", de: "Tagesmittel"),
                        screenModel.averageEventsPerActiveDay.formatted(.number.precision(.fractionLength(1))),
                        .goPrimary
                    )
                }
            } else {
                emptyText(l.tr(
                    zh: "选定范围内暂无趋势数据",
                    en: "No trend data in the selected range",
                    de: "Keine Trenddaten im gewaehlten Zeitraum"
                ))
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var actorBreakdownCard: some View {
        let actorStats = screenModel.actorStats(l: l)
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "谁做得最多", en: "Most active helper", de: "Aktivste helfende Person"), icon: "person.fill.checkmark")
            if actorStats.isEmpty {
                emptyText(l.tr(zh: "暂无成员统计", en: "No member stats yet", de: "Noch keine Mitgliederstatistik"))
            } else {
                ForEach(actorStats.prefix(6), id: \.0) { name, count in
                    statBar(title: name, count: count, total: max(screenModel.realOperationCount, 1), color: .goPrimary)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private var latestEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l.tr(zh: "最近账本流水", en: "Recent ledger activity", de: "Aktuelle Buchaktivitaet"), icon: "list.bullet.rectangle")
            if screenModel.filteredEvents.isEmpty {
                emptyText(l.tr(
                    zh: "完成一次照护、提醒或椰子操作后，这里会出现流水",
                    en: "Care, reminder, or coconut activity will appear here after it is completed",
                    de: "Pflege-, Erinnerungs- oder Kokosnuss-Aktivitaet erscheint hier nach Abschluss"
                ))
            } else {
                ForEach(screenModel.filteredEvents.prefix(20)) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.eventKindEnum.icon)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold))
                            .foregroundStyle(event.eventKindEnum.color)
                            .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .background(event.eventKindEnum.color.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.eventKindEnum.displayName(l: l)) · \(event.actionType)")
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text("\(screenModel.actorName(for: event.actorId, kind: event.actorKind, l: l)) → \(screenModel.subjectName(for: event.subjectId, kind: event.subjectKind, l: l))")
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(event.occurredAt, format: .dateTime.month().day().hour().minute())
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
    }

    private func kindChip(title: String, kind: CareLedgerEventKind?) -> some View {
        let isSelected = screenModel.selectedKind == kind
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                screenModel.selectedKind = kind
            }
        } label: {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func statBar(title: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text("\(count)").font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(count) / CGFloat(total))
                }
            }
            .frame(height: 8)
        }
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.goPrimary)
            Text(title).font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
            Spacer()
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension CareLedgerEventKind {
    func displayName(l: L10n) -> String {
        switch self {
        case .care:
            l.tr(zh: "照护", en: "Care", de: "Pflege")
        case .potty:
            l.tr(zh: "便便", en: "Potty", de: "Toilette")
        case .walk:
            l.tr(zh: "遛狗", en: "Walk", de: "Spaziergang")
        case .hygiene:
            l.tr(zh: "护理", en: "Grooming", de: "Pflege")
        case .health:
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .medication:
            l.tr(zh: "吃药", en: "Medication", de: "Medikation")
        case .workout:
            l.tr(zh: "运动", en: "Workout", de: "Training")
        case .expense:
            l.tr(zh: "花费", en: "Expense", de: "Ausgabe")
        case .reminder:
            l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung")
        case .plantCare:
            l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        case .coconut:
            l.tr(zh: "椰子", en: "Coconuts", de: "Kokosnuesse")
        case .milestone:
            l.tr(zh: "里程碑", en: "Milestone", de: "Meilenstein")
        case .unknown:
            l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")
        }
    }

    var icon: String {
        switch self {
        case .care: "pawprint.fill"
        case .potty: "drop.fill"
        case .walk: "figure.walk"
        case .hygiene: "sparkles"
        case .health: "cross.fill"
        case .weight: "scalemass.fill"
        case .medication: "pills.fill"
        case .workout: "figure.run"
        case .expense: "creditcard.fill"
        case .reminder: "bell.fill"
        case .plantCare: "leaf.fill"
        case .coconut: "circle.hexagongrid.fill"
        case .milestone: "flag.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .expense: .goYellow
        case .reminder: .goOrange
        case .coconut: .goPrimary
        case .health, .medication: .goRed
        case .walk, .workout: .goTeal
        default: .goPrimary
        }
    }
}
