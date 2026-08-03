//
//  HumanHealthMetricDetailView.swift
//  Ohana
//
//  Trend, reference range, and history for one human checkup metric.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct HumanHealthMetricDetailLogSnapshot {
    let allMetricLogs: [HumanHealthMetricLog]
    let preferredUnit: HealthMetricUnit
    let selectedUnit: HealthMetricUnit
    let selectedUnitLogs: [HumanHealthMetricLog]
    let visibleHistoryLogs: [HumanHealthMetricLog]
    let hasMoreHistory: Bool
    let didReachFetchLimit: Bool
    let chartLogs: [HumanHealthMetricLog]
    let chartPoints: [OhanaMinimalChartPoint]
    let chartYDomain: ClosedRange<Double>

    init(
        logs: [HumanHealthMetricLog],
        metric: HealthMetric,
        selectedUnitCode: String,
        appCountry: String,
        didReachFetchLimit: Bool? = nil
    ) {
        let sortedLogs = logs
            .filter { $0.metricKey == metric.key }
            .sorted {
                HumanHealthMetricLogOrdering.newestFirst(
                    HumanHealthMetricLogOrdering.key(for: $0),
                    HumanHealthMetricLogOrdering.key(for: $1)
                )
            }
        let preferred = sortedLogs.first
            .flatMap { metric.unit(for: $0.unitCode) }
            ?? metric.defaultUnit(for: appCountry)
        let selected = metric.unit(for: selectedUnitCode) ?? preferred
        let unitLogs = sortedLogs.filter { $0.unitCode == selected.code }
        let chart = Array(unitLogs.prefix(HumanHealthMetricReadPolicy.detailChartLimit).reversed())
        var yValues = chart.map(\.value)
        yValues.append(contentsOf: chart.compactMap(\.referenceLow))
        yValues.append(contentsOf: chart.compactMap(\.referenceHigh))
        if let low = selected.normalLow { yValues.append(low) }
        if let high = selected.normalHigh { yValues.append(high) }

        allMetricLogs = sortedLogs
        preferredUnit = preferred
        selectedUnit = selected
        selectedUnitLogs = unitLogs
        visibleHistoryLogs = Array(unitLogs.prefix(HumanHealthMetricReadPolicy.detailHistoryLimit))
        hasMoreHistory = unitLogs.count > HumanHealthMetricReadPolicy.detailHistoryLimit
        self.didReachFetchLimit = didReachFetchLimit
            ?? (sortedLogs.count >= HumanHealthMetricReadPolicy.detailFetchLimit)
        chartLogs = chart
        chartPoints = chart.map {
            OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id.uuidString)
        }
        chartYDomain = OhanaChartStyle.yDomain(values: yValues, includeZero: false)
    }
}

struct HumanHealthMetricDetailView: View {
    let human: Human
    let metric: HealthMetric

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var selectedUnitCode = ""
    @State private var metricLogs: [HumanHealthMetricLog] = []
    @State private var didReachSelectedUnitFetchLimit = false
    @State private var metricLoadRevision = 0
    @State private var metricLoadFailed = false
    @State private var showingEntrySheet = false
    @State private var logPendingEdit: HumanHealthMetricLog?
    @State private var presentationState = HumanHealthMetricPresentationState()
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var logPendingDeletion: HumanHealthMetricLog?
    @State private var showingDeleteConfirmation = false

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var isReadOnly: Bool { human.hasPassedAway }
    private var l: L10n { L10n(appLanguage) }
    private var tint: Color { metric.category.color }

    init(human: Human, metric: HealthMetric) {
        self.human = human
        self.metric = metric
    }

    var body: some View {
        let snapshot = HumanHealthMetricDetailLogSnapshot(
            logs: metricLogs,
            metric: metric,
            selectedUnitCode: selectedUnitCode,
            appCountry: appCountry,
            didReachFetchLimit: didReachSelectedUnitFetchLimit
        )
        return ZStack(alignment: .bottom) {
            OhanaAppBackground()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        pageHeader
                        if metricLoadFailed {
                            metricLoadFailureNotice
                        }
                        heroMetric(snapshot)
                        chartSection(snapshot)
                        unitSelector(snapshot)
                        referenceSection(snapshot)
                        historySection(snapshot)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, isReadOnly ? 36 : 112)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)

                if !isReadOnly {
                    addButton
                        .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle(metric.displayName(l))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEntrySheet) {
            HumanHealthMetricEntrySheet(
                human: human,
                metric: metric,
                initialUnitCode: snapshot.selectedUnit.code,
                onSaved: { log in
                    metricLogs = []
                    didReachSelectedUnitFetchLimit = false
                    selectedUnitCode = log.unitCode
                    metricLoadRevision &+= 1
                }
            )
        }
        .sheet(item: $logPendingEdit) { log in
            HumanHealthMetricEditSheet(
                human: human,
                metric: metric,
                log: log,
                onSaved: { result in
                    metricLogs = []
                    didReachSelectedUnitFetchLimit = false
                    selectedUnitCode = result.unitCode
                    metricLoadRevision &+= 1
                }
            )
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.locale, AppLanguage.effectiveLocale)
        .accessibilityIdentifier("human-health-metric-detail-\(metric.key)")
        .onAppear {
            if selectedUnitCode.isEmpty {
                selectedUnitCode = preferredInitialUnitCode()
            }
            if isReadOnly {
                showingEntrySheet = false
            }
        }
        .task(id: metricLoadKey) {
            await loadSelectedUnitLogs()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates.dropFirst()) { _ in
            metricLoadRevision &+= 1
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                showingEntrySheet = false
                logPendingEdit = nil
                commandQueue.cancelAll()
                presentationState.cancelAll()
                logPendingDeletion = nil
                showingDeleteConfirmation = false
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
            presentationState.cancelAll()
            logPendingEdit = nil
            logPendingDeletion = nil
            showingDeleteConfirmation = false
        }
        .alert(
            l.tr(zh: "未能删除记录", en: "Log not deleted", de: "Eintrag nicht gelöscht"),
            isPresented: $showingError
        ) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            l.tr(zh: "删除这条指标记录？", en: "Delete this metric log?", de: "Diesen Messwert löschen?"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: logPendingDeletion
        ) { log in
            Button(
                l.tr(zh: "删除记录", en: "Delete Log", de: "Eintrag löschen"),
                role: .destructive
            ) {
                logPendingDeletion = nil
                deleteLog(log)
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                logPendingDeletion = nil
            }
        } message: { _ in
            Text(l.tr(
                zh: "删除后无法撤销。趋势和统计会随之更新。",
                en: "This cannot be undone. Trends and summaries will update.",
                de: "Dies kann nicht rückgängig gemacht werden. Verlauf und Zusammenfassung werden aktualisiert."
            ))
        }
    }

    private var metricLoadKey: String {
        "\(selectedUnitCode)|\(metricLoadRevision)"
    }

    @MainActor
    private func preferredInitialUnitCode() -> String {
        let fallback = metric.defaultUnit(for: appCountry).code
        return HumanHealthMetricDetailQuery.preferredUnitCode(
            humanID: human.id,
            metricKey: metric.key,
            validUnitCodes: Set(metric.units.map(\.code)),
            fallbackUnitCode: fallback,
            context: modelContext
        )
    }

    @MainActor
    private func loadSelectedUnitLogs() async {
        let requestedUnitCode = selectedUnitCode
        guard metric.unit(for: requestedUnitCode) != nil else { return }
        metricLoadFailed = false
        await Task.yield()
        guard !Task.isCancelled, requestedUnitCode == selectedUnitCode else { return }

        do {
            let page = try HumanHealthMetricDetailQuery.page(
                humanID: human.id,
                metricKey: metric.key,
                unitCode: requestedUnitCode,
                context: modelContext
            )
            guard !Task.isCancelled, requestedUnitCode == selectedUnitCode else { return }
            metricLogs = page.logs
            didReachSelectedUnitFetchLimit = page.didReachFetchLimit
        } catch {
            guard !Task.isCancelled, requestedUnitCode == selectedUnitCode else { return }
            metricLogs = []
            didReachSelectedUnitFetchLimit = false
            metricLoadFailed = true
            OhanaLog.warning("Human health metric detail query failed.", category: "Health")
        }
    }

    private var metricLoadFailureNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative warning icon; adjacent text names the failure
                .accessibilityHidden(true)
                .foregroundStyle(Color.goOrange)
            VStack(alignment: .leading, spacing: 5) {
                Text(l.tr(
                    zh: "未能读取这个单位的记录",
                    en: "Could not load logs for this unit",
                    de: "Einträge für diese Einheit konnten nicht geladen werden"
                ))
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "记录仍安全保留。请重试。",
                    en: "Your logs remain safe. Try again.",
                    de: "Deine Einträge bleiben erhalten. Versuche es erneut.",
                    es: "Tus registros siguen seguros. Inténtalo de nuevo.",
                    pt: "Os seus registos continuam seguros. Tente novamente.",
                    fr: "Vos entrées restent en sécurité. Réessayez.",
                    ja: "記録は安全に保持されています。もう一度お試しください。",
                    ko: "기록은 안전하게 보관되어 있습니다. 다시 시도해 주세요.",
                    it: "Le registrazioni restano al sicuro. Riprova."
                ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) {
                    metricLoadRevision &+= 1
                }
                .font(OhanaFont.caption(.bold))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .accessibilityIdentifier("human-health-metric-load-failure")
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.category.systemImage)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(metric.displayName(l))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(metric.hint(l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private func heroMetric(_ snapshot: HumanHealthMetricDetailLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(l.tr(zh: "最新记录", en: "Latest", de: "Aktuell"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    if let latest = snapshot.selectedUnitLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(snapshot.selectedUnit.formattedValue(latest.value, includeUnit: false))
                                .font(OhanaFont.metric(size: 42, .black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .minimumScaleFactor(0.58)
                                .contentTransition(.numericText())
                            Text(snapshot.selectedUnit.label)
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(tint)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Text(latest.date, format: .dateTime.year().month().day())
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    } else {
                        Text("—")
                            .font(OhanaFont.metric(size: 42, .black))
                            .foregroundStyle(Color.ohanaTertiaryText)
                        Text(l.tr(zh: "此单位暂无记录", en: "No logs in this unit", de: "Keine Einträge in dieser Einheit"))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }

                Spacer(minLength: 0)

                if let latest = snapshot.selectedUnitLogs.first {
                    statusBadge(for: latest, snapshot: snapshot)
                }
            }

            HStack(spacing: 10) {
                miniStat(
                    icon: "list.bullet.rectangle.fill",
                    value: "\(snapshot.allMetricLogs.count)\(snapshot.didReachFetchLimit ? "+" : "")",
                    label: l.tr(zh: "最近记录", en: "Recent", de: "Zuletzt")
                )
                miniStat(
                    icon: "ruler.fill",
                    value: snapshot.selectedUnitLogs.first.map {
                        HumanHealthMetricReferenceEvaluator.referenceLabel(
                            for: $0,
                            fallbackUnit: snapshot.selectedUnit,
                            includeUnit: false
                        )
                    } ?? snapshot.selectedUnit.normalRangeLabel(includeUnit: false),
                    label: snapshot.selectedUnit.label
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private func unitSelector(_ snapshot: HumanHealthMetricDetailLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "单位", en: "Unit", de: "Einheit"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(metric.units) { unit in
                        let selected = unit.code == snapshot.selectedUnit.code
                        let isCountryDefault = unit.code == metric.defaultUnit(for: appCountry).code
                        Button {
                            withAnimation(GoMotion.feedback) {
                                metricLogs = []
                                didReachSelectedUnitFetchLimit = false
                                metricLoadFailed = false
                                selectedUnitCode = unit.code
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unit.label)
                                    .font(OhanaFont.callout(.black))
                                Text(unit.normalRangeLabel(includeUnit: false))
                                    .font(OhanaFont.caption2(.bold))
                                    .opacity(0.78)
                                if isCountryDefault {
                                    Text(l.tr(zh: "国家默认", en: "Country default", de: "Länderstandard"))
                                        .font(OhanaFont.caption2(.black))
                                        .opacity(0.62)
                                }
                            }
                            .foregroundStyle(selected ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minWidth: 116, minHeight: 64, alignment: .leading)
                            .goSelectableSurface(isSelected: selected, tint: tint, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(unit.label)
                        .accessibilityValue(unitAccessibilityValue(
                            unit,
                            isCountryDefault: isCountryDefault
                        ))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func chartSection(_ snapshot: HumanHealthMetricDetailLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(l.tr(zh: "趋势", en: "Trend", de: "Verlauf"))
                Spacer()
                Text(l.tr(
                    zh: "\(snapshot.selectedUnitLogs.count)\(snapshot.didReachFetchLimit ? "+" : "") 条",
                    en: "\(snapshot.selectedUnitLogs.count)\(snapshot.didReachFetchLimit ? "+" : "") logs",
                    de: "\(snapshot.selectedUnitLogs.count)\(snapshot.didReachFetchLimit ? "+" : "") Einträge"
                ))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if snapshot.chartPoints.isEmpty {
                emptyTrendState
            } else {
                OhanaMinimalTrendChart(
                    points: snapshot.chartPoints,
                    yDomain: snapshot.chartYDomain,
                    tint: tint,
                    yReferenceLineCount: 3,
                    yReferenceFormatter: { value, _ in snapshot.selectedUnit.formattedValue(value, includeUnit: false) }
                )
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chartAccessibilitySummary(snapshot))

                if snapshot.chartLogs.count >= 2,
                   let first = snapshot.chartLogs.first,
                   let last = snapshot.chartLogs.last {
                    HStack {
                        Text(first.date, format: .dateTime.month(.abbreviated).day())
                        Spacer()
                        Text(last.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                } else {
                    Text(l.tr(zh: "再记录 1 次即可形成趋势线", en: "Add one more log to form a trend line.", de: "Ein weiterer Eintrag bildet eine Trendlinie."))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private func referenceSection(_ snapshot: HumanHealthMetricDetailLogSnapshot) -> some View {
        let latest = snapshot.selectedUnitLogs.first
        let referenceLabel = latest.map {
            HumanHealthMetricReferenceEvaluator.referenceLabel(
                for: $0,
                fallbackUnit: snapshot.selectedUnit
            )
        } ?? snapshot.selectedUnit.normalRangeLabel()
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "参考范围", en: "Reference Range", de: "Referenzbereich"))

            HStack(spacing: 12) {
                Image(systemName: "target").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(tint.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(referenceLabel)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if let latest,
                       latest.sourceReportID != nil,
                       HumanHealthMetricReferenceEvaluator.hasSourceReference(latest) {
                        Text(l.tr(
                            zh: "采用最近一份化验单的参考范围",
                            en: "Using the latest lab report's reference range",
                            de: "Referenzbereich des neuesten Laborberichts"
                        ))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(tint)
                    }
                    Text(l.tr(
                        zh: "参考范围会随实验室、年龄、孕期与医生判断变化，请以报告单为准。",
                        en: "Ranges vary by lab, age, pregnancy, and clinician context; use the report as source of truth.",
                        de: "Bereiche variieren je nach Labor, Alter, Schwangerschaft und ärztlichem Kontext; maßgeblich ist der Bericht."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func historySection(_ snapshot: HumanHealthMetricDetailLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(l.tr(zh: "历史", en: "History", de: "Historie"))
                Spacer()
                Text(snapshot.selectedUnit.label)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(tint)
            }

            if snapshot.selectedUnitLogs.isEmpty {
                emptyHistoryState
            } else {
                ForEach(snapshot.visibleHistoryLogs) { log in
                    historyRow(log, snapshot: snapshot)
                }
                if snapshot.hasMoreHistory {
                    Text(l.tr(
                        zh: "仅显示最近 \(HumanHealthMetricReadPolicy.detailHistoryLimit) 条；更早记录仍保留。",
                        en: "Showing the latest \(HumanHealthMetricReadPolicy.detailHistoryLimit) logs; older logs remain saved.",
                        de: "Angezeigt werden die letzten \(HumanHealthMetricReadPolicy.detailHistoryLimit) Einträge; ältere bleiben gespeichert."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if snapshot.didReachFetchLimit {
                Text(l.tr(
                    zh: "当前单位只读取最近 \(HumanHealthMetricReadPolicy.detailFetchLimit) 条记录；更早记录仍保留。",
                    en: "Only the latest \(HumanHealthMetricReadPolicy.detailFetchLimit) logs in this unit are loaded; older logs remain saved.",
                    de: "Nur die letzten \(HumanHealthMetricReadPolicy.detailFetchLimit) Einträge dieser Einheit werden geladen; ältere bleiben gespeichert."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyTrendState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 28, weight: .bold))
                .foregroundStyle(tint)
            Text(l.tr(zh: "记录后会显示趋势图", en: "A trend appears after logging.", de: "Nach dem Erfassen erscheint ein Verlauf."))
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var emptyHistoryState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 24, weight: .bold))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(l.tr(zh: "当前单位还没有历史记录", en: "No history in the selected unit.", de: "Keine Historie in dieser Einheit."))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var addButton: some View {
        Button {
            withAnimation(GoMotion.feedback) {
                showingEntrySheet = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                Text(l.tr(zh: "记录", en: "Record", de: "Erfassen"))
                    .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 26)
            .frame(height: 54)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var privacyLockedView: some View {
        HumanModulePrivacyLockedView(
            title: l.tr(zh: "身体数据仅本人可见", en: "Body data is private", de: "Körperdaten sind privat"),
            message: l.tr(zh: "请切换到本人档案后再查看体检指标。", en: "Switch to this profile to view checkup metrics.", de: "Wechsle zu diesem Profil, um Check-up-Werte zu sehen.")
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(label)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func statusBadge(
        for log: HumanHealthMetricLog,
        snapshot: HumanHealthMetricDetailLogSnapshot
    ) -> some View {
        let status = HumanHealthMetricReferenceEvaluator.status(
            for: log,
            fallbackUnit: snapshot.selectedUnit
        )
        return HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            Text(status.label(l))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(status.color.opacity(0.14), in: Capsule())
    }

    private func historyRow(
        _ log: HumanHealthMetricLog,
        snapshot: HumanHealthMetricDetailLogSnapshot
    ) -> some View {
        let status = HumanHealthMetricReferenceEvaluator.status(
            for: log,
            fallbackUnit: snapshot.selectedUnit
        )
        return HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 9, height: 9) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.

            VStack(alignment: .leading, spacing: 3) {
                Text(log.date, format: .dateTime.year().month().day())
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                HStack(spacing: 6) {
                    Text(status.label(l))
                        .foregroundStyle(status.color)
                    if !log.notes.isEmpty {
                        Text("·")
                        Text(log.notes)
                            .lineLimit(1)
                    }
                }
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                if log.sourceReportID != nil {
                    Label(
                        log.sourceLabel.isEmpty
                            ? l.tr(zh: "化验单导入", en: "Imported report", de: "Importierter Bericht")
                            : log.sourceLabel,
                        systemImage: "doc.text.viewfinder"
                    )
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(snapshot.selectedUnit.formattedValue(log.value, includeUnit: false))
                    .font(OhanaFont.metric(size: 21, .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(snapshot.selectedUnit.label)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(tint)
            }

            if !isReadOnly {
                Menu {
                    Button {
                        logPendingEdit = log
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(
                            l.tr(
                                zh: "编辑记录", en: "Edit Log", de: "Eintrag bearbeiten",
                                es: "Editar registro", pt: "Editar registro", fr: "Modifier l’entrée",
                                ja: "記録を編集", ko: "기록 편집", it: "Modifica voce"
                            ),
                            systemImage: "pencil"
                        )
                    }
                    .accessibilityIdentifier("human-health-metric-edit-action")

                    Button(role: .destructive) {
                        logPendingDeletion = log
                        showingDeleteConfirmation = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(
                            l.tr(zh: "删除记录", en: "Delete Log", de: "Eintrag löschen"),
                            systemImage: "trash"
                        )
                    }
                    .accessibilityIdentifier("human-health-metric-delete-action")
                } label: {
                    Image(systemName: "ellipsis").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 15, weight: .bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(presentationState.isDeletePending(logID: log.id))
                .opacity(presentationState.isDeletePending(logID: log.id) ? 0.5 : 1)
                .accessibilityLabel(l.tr(
                    zh: "记录操作", en: "Log actions", de: "Eintragsaktionen",
                    es: "Acciones del registro", pt: "Ações do registro", fr: "Actions de l’entrée",
                    ja: "記録の操作", ko: "기록 작업", it: "Azioni della voce"
                ))
                .accessibilityIdentifier("human-health-metric-log-actions")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func deleteLog(_ log: HumanHealthMetricLog) {
        switch presentationState.beginDelete(logID: log.id, isReadOnly: isReadOnly) {
        case .rejectedReadOnly:
            presentDeleteFailure(readOnlyDeleteFailureMessage)
            return
        case .ignoredPending:
            return
        case .started:
            break
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(
            .humanHealthMetricDelete(
                humanID: human.id,
                metricKey: log.metricKey,
                logID: log.id
            )
        ) {
            let result = HumanCareCommandExecutor(context: modelContext, services: appServices).deleteHealthMetric(
                log,
                human: human,
                note: "humanHealthMetric.delete"
            )
            switch presentationState.completeDelete(logID: log.id, result: result) {
            case .deleted:
                metricLogs.removeAll { $0.id == log.id }
                metricLoadRevision &+= 1
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failed:
                presentDeleteFailure(isReadOnly ? readOnlyDeleteFailureMessage : deleteFailureMessage)
            }
        }
    }

    private func unitAccessibilityValue(
        _ unit: HealthMetricUnit,
        isCountryDefault: Bool
    ) -> String {
        let range = unit.normalRangeLabel(includeUnit: false)
        if isCountryDefault {
            return l.tr(
                zh: "参考范围 \(range)，国家默认单位",
                en: "Reference range \(range), country default unit",
                de: "Referenzbereich \(range), Standard für dieses Land"
            )
        }
        return l.tr(
            zh: "参考范围 \(range)",
            en: "Reference range \(range)",
            de: "Referenzbereich \(range)"
        )
    }

    private func chartAccessibilitySummary(_ snapshot: HumanHealthMetricDetailLogSnapshot) -> String {
        guard let latest = snapshot.chartLogs.last else {
            return l.tr(
                zh: "\(metric.displayName(l)) 趋势，暂无记录",
                en: "\(metric.displayName(l)) trend, no logs",
                de: "Verlauf für \(metric.displayName(l)), keine Einträge"
            )
        }
        let latestValue = snapshot.selectedUnit.formattedValue(latest.value)
        let latestStatus = HumanHealthMetricReferenceEvaluator.status(
            for: latest,
            fallbackUnit: snapshot.selectedUnit
        ).label(l)
        guard let earliest = snapshot.chartLogs.first,
              earliest.id != latest.id else {
            return l.tr(
                zh: "\(metric.displayName(l)) 趋势，最新 \(latestValue)，\(latestStatus)，共 1 条记录",
                en: "\(metric.displayName(l)) trend, latest \(latestValue), \(latestStatus), 1 log",
                de: "Verlauf für \(metric.displayName(l)), aktuell \(latestValue), \(latestStatus), 1 Eintrag"
            )
        }
        let earliestValue = snapshot.selectedUnit.formattedValue(earliest.value)
        return l.tr(
            zh: "\(metric.displayName(l)) 最近 \(snapshot.chartLogs.count) 条趋势，最早 \(earliestValue)，最新 \(latestValue)，\(latestStatus)",
            en: "\(metric.displayName(l)) trend over the latest \(snapshot.chartLogs.count) logs, earliest \(earliestValue), latest \(latestValue), \(latestStatus)",
            de: "Verlauf für \(metric.displayName(l)) über die letzten \(snapshot.chartLogs.count) Einträge, zuerst \(earliestValue), aktuell \(latestValue), \(latestStatus)"
        )
    }

    private var readOnlyDeleteFailureMessage: String {
        l.tr(
            zh: "纪念模式为只读，这条体检指标记录仍保留。",
            en: "Memorial mode is read-only. This checkup metric log was kept.",
            de: "Der Gedenkmodus ist schreibgeschützt. Dieser Check-up-Eintrag wurde beibehalten."
        )
    }

    private var deleteFailureMessage: String {
        l.tr(
            zh: "无法删除这条体检指标记录。记录仍保留，请重试。",
            en: "Could not delete this checkup metric log. It was kept; try again.",
            de: "Dieser Check-up-Eintrag konnte nicht gelöscht werden. Er wurde beibehalten; versuche es erneut."
        )
    }

    private func presentDeleteFailure(_ message: String) {
        errorMessage = message
        showingError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
