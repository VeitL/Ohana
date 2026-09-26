//
//  HumanHealthCheckupView.swift
//  Ohana
//
//  Human checkup metric catalog and recent logs.
//

import SwiftUI

enum HumanHealthMetricReadPolicy {
    static let checkupFetchLimit = 256
    static let checkupProbeLimit = checkupFetchLimit + 1
    static let detailFetchLimit = 256
    static let detailProbeLimit = detailFetchLimit + 1
    static let detailHistoryLimit = 120
    static let detailChartLimit = 30
}

struct HumanHealthCheckupLogSnapshot {
    let sortedLogs: [HumanHealthMetricLog]
    let latestByKey: [String: HumanHealthMetricLog]
    let logsByKey: [String: [HumanHealthMetricLog]]
    let trackedMetrics: [HealthMetric]
    let trackedMetricCount: Int
    let abnormalLatestMetricCount: Int
    let didReachFetchLimit: Bool

    init(logs: [HumanHealthMetricLog]) {
        let probed = logs.sorted {
            HumanHealthMetricLogOrdering.newestFirst(
                HumanHealthMetricLogOrdering.key(for: $0),
                HumanHealthMetricLogOrdering.key(for: $1)
            )
        }
        let sorted = Array(probed.prefix(HumanHealthMetricReadPolicy.checkupFetchLimit))
        let grouped = Dictionary(grouping: sorted, by: \.metricKey)
        sortedLogs = sorted
        logsByKey = grouped
        latestByKey = grouped.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.first
        }
        trackedMetricCount = Set(sorted.map(\.metricKey)).count
        abnormalLatestMetricCount = latestByKey.values.count(where: { log in
            guard let metric = HealthMetricCatalog.metric(forKey: log.metricKey),
                  let unit = metric.unit(for: log.unitCode) else { return false }
            let status = HumanHealthMetricReferenceEvaluator.status(
                for: log,
                fallbackUnit: unit
            )
            return status == .low || status == .high
        })
        var seen = Set<String>()
        trackedMetrics = sorted.compactMap { log in
            guard seen.insert(log.metricKey).inserted else { return nil }
            return HealthMetricCatalog.metric(forKey: log.metricKey)
        }
        didReachFetchLimit = probed.count > HumanHealthMetricReadPolicy.checkupFetchLimit
    }
}

private enum HumanHealthCheckupSheetDestination: String, Identifiable {
    case labReportImport
    case personalUpgrade

    var id: String { rawValue }
}

struct HumanHealthCheckupView: View {
    let human: Human

    var body: some View {
        HumanHealthCheckupDataContainer(human: human)
    }
}

struct HumanHealthCheckupContentView: View {
    let human: Human
    let metricLogs: [HumanHealthMetricLog]

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(AppServices.self) private var appServices
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var recordingMetric: HealthMetric?
    @State private var detailMetric: HealthMetric?
    @State private var metricToOpenAfterEntry: HealthMetric?
    @State private var sheetDestination: HumanHealthCheckupSheetDestination?

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var isReadOnly: Bool { human.hasPassedAway }
    private var l: L10n { L10n(appLanguage) }

    private var starterMetric: HealthMetric? {
        HealthMetricCatalog.metric(forKey: "tsh") ?? HealthMetricCatalog.all.first
    }

    var body: some View {
        let snapshot = HumanHealthCheckupLogSnapshot(logs: metricLogs)
        return ZStack(alignment: .bottom) {
            OhanaAppBackground()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        pageHeader
                        summaryStrip(snapshot)
                        if !isReadOnly {
                            labReportImportEntry
                        }
                        trackedChartSection(snapshot)
                        recentSection(snapshot)
                        catalogSection(snapshot)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .navigationTitle(l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $detailMetric) { metric in
            HumanHealthMetricDetailView(human: human, metric: metric)
        }
        .sheet(item: $recordingMetric, onDismiss: openSavedMetricDetailIfNeeded) { metric in
            HumanHealthMetricEntrySheet(
                human: human,
                metric: metric,
                initialUnitCode: preferredUnit(for: metric, snapshot: snapshot).code,
                onSaved: { _ in
                    metricToOpenAfterEntry = metric
                }
            )
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .labReportImport:
                HumanLabResultImportView(human: human)
                    .ohanaSheetPagePresentation()
            case .personalUpgrade:
                PersonalPlanView(prompt: PersonalUpgradePrompt(feature: .documentScanning))
                    .ohanaSheetPagePresentation()
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.locale, AppLanguage.effectiveLocale)
        .onAppear {
            if isReadOnly {
                recordingMetric = nil
                metricToOpenAfterEntry = nil
                sheetDestination = nil
            }
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                recordingMetric = nil
                metricToOpenAfterEntry = nil
                sheetDestination = nil
            }
        }
        .onChange(of: isPrivacyLocked) { _, isLocked in
            if isLocked {
                recordingMetric = nil
                metricToOpenAfterEntry = nil
                sheetDestination = nil
            }
        }
    }

    private func openSavedMetricDetailIfNeeded() {
        guard let metric = metricToOpenAfterEntry else { return }
        metricToOpenAfterEntry = nil
        DispatchQueue.main.async {
            detailMetric = metric
        }
    }

    private var pageHeader: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"),
            subtitle: l.tr(
                zh: "\(countryTitle) · \(HealthMetricCatalog.all.count) 项常见指标",
                en: "\(countryTitle) · \(HealthMetricCatalog.all.count) common metrics",
                de: "\(countryTitle) · \(HealthMetricCatalog.all.count) häufige Werte"
            ),
            showsCloseButton: false,
            onClose: {}
        ) {
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .weight)
            }
        }
    }

    private var labReportImportEntry: some View {
        Button {
            sheetDestination = appServices.commerce.allows(.documentScanning)
                ? .labReportImport
                : .personalUpgrade
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.viewfinder.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(HumanLabScanCopy.text(.scanLabReport, l: l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(HumanLabScanCopy.text(.checkupEntryDetail, l: l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.goTeal.opacity(0.32), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(HumanLabScanCopy.text(.entryAccessibility, l: l))
        .accessibilityIdentifier("human-health-lab-report-import-action")
    }

    @ViewBuilder
    private func trackedChartSection(_ snapshot: HumanHealthCheckupLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(l.tr(zh: "已追踪图表", en: "Tracked Charts", de: "Getrackte Diagramme"))
                Spacer()
                Text(l.tr(
                    zh: "\(snapshot.trackedMetrics.count)\(snapshot.didReachFetchLimit ? "+" : "") 项",
                    en: "\(snapshot.trackedMetrics.count)\(snapshot.didReachFetchLimit ? "+" : "") tracked",
                    de: "\(snapshot.trackedMetrics.count)\(snapshot.didReachFetchLimit ? "+" : "") getrackt"
                ))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if snapshot.trackedMetrics.isEmpty {
                trackedChartEmptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(snapshot.trackedMetrics.prefix(12)) { metric in
                            trackedMetricChartCard(metric, snapshot: snapshot)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private var trackedChartEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .foregroundStyle(Color.goOrange)
                    .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.goOrange.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "录入任意指标后会生成追踪图", en: "Charts appear after you log a metric.", de: "Diagramme erscheinen nach dem ersten Wert."))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "从下方分类选择指标开始。", en: "Pick a metric from the catalog below.", de: "Wähle unten einen Wert aus dem Katalog."))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer(minLength: 0)
            }

            if !isReadOnly, let starterMetric {
                Button {
                    withAnimation(GoMotion.feedback) {
                        recordingMetric = starterMetric
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label(
                        l.tr(
                            zh: "记录 \(starterMetric.displayName(l))",
                            en: "Record \(starterMetric.displayName(l))",
                            de: "\(starterMetric.displayName(l)) erfassen"
                        ),
                        systemImage: "plus.circle.fill"
                    )
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color.goOrange, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-health-metric-starter-record-action")
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func trackedMetricChartCard(
        _ metric: HealthMetric,
        snapshot: HumanHealthCheckupLogSnapshot
    ) -> some View {
        let logs = logs(for: metric, snapshot: snapshot)
        let latest = logs.first
        let unit = latest.flatMap { metric.unit(for: $0.unitCode) } ?? metric.defaultUnit(for: appCountry)
        let unitLogs = logs.filter { $0.unitCode == unit.code }
        let chartLogs = Array(unitLogs.prefix(12).reversed())
        let points = chartLogs.map {
            OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id.uuidString)
        }
        var yValues = chartLogs.map(\.value)
        if let low = unit.normalLow { yValues.append(low) }
        if let high = unit.normalHigh { yValues.append(high) }

        return Button {
            detailMetric = metric
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: metric.category.systemImage)
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .background(metric.category.color, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(metric.displayName(l))
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(unit.label)
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(metric.category.color)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latest.map { unit.formattedValue($0.value, includeUnit: false) } ?? "—")
                        .font(OhanaFont.metric(size: 27, .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .contentTransition(.numericText())
                    Text(unit.label)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(metric.category.color)
                    Spacer(minLength: 0)
                }

                OhanaMinimalTrendChart(
                    points: Array(points),
                    yDomain: OhanaChartStyle.yDomain(values: yValues, includeZero: false),
                    tint: metric.category.color,
                    showsLatestPoint: true
                )
                .frame(height: 58)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .padding(14)
            .frame(width: 226, height: 156, alignment: .topLeading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(trackedChartAccessibilitySummary(
            metric: metric,
            logs: unitLogs,
            unit: unit
        ))
        .accessibilityHint(l.tr(
            zh: "打开完整趋势和历史记录",
            en: "Opens the full trend and history",
            de: "Öffnet den vollständigen Verlauf und die Historie"
        ))
        .accessibilityIdentifier("human-health-metric-chart-\(metric.key)")
    }

    private var countryTitle: String {
        AppCountry.option(for: appCountry).displayName.resolve(appLanguage)
    }

    private func summaryStrip(_ snapshot: HumanHealthCheckupLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                summaryItem(
                    icon: "list.bullet.rectangle.fill",
                    value: "\(HealthMetricCatalog.all.count)",
                    label: l.tr(zh: "目录指标", en: "Catalog", de: "Katalog"),
                    tint: Color.goTeal
                )
                summaryItem(
                    icon: "chart.xyaxis.line",
                    value: "\(snapshot.trackedMetricCount)\(snapshot.didReachFetchLimit ? "+" : "")",
                    label: snapshot.didReachFetchLimit
                        ? l.tr(zh: "近期追踪", en: "Recent", de: "Zuletzt")
                        : l.tr(zh: "已追踪", en: "Tracked", de: "Getrackt"),
                    tint: Color.goOrange
                )
                summaryItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(snapshot.abnormalLatestMetricCount)\(snapshot.didReachFetchLimit ? "+" : "")",
                    label: snapshot.didReachFetchLimit
                        ? l.tr(zh: "近期异常", en: "Recent", de: "Zuletzt")
                        : l.tr(zh: "当前异常", en: "Current", de: "Aktuell"),
                    tint: Color.goYellow
                )
            }

            Text(snapshot.didReachFetchLimit
                ? l.tr(
                    zh: "当前仅分析最近 \(HumanHealthMetricReadPolicy.checkupFetchLimit) 条记录；带“+”的追踪与异常数是下界，更早记录中的指标可能未显示。",
                    en: "Only the latest \(HumanHealthMetricReadPolicy.checkupFetchLimit) logs are analyzed. Counts marked “+” are lower bounds, and metrics found only in older logs may be absent.",
                    de: "Nur die letzten \(HumanHealthMetricReadPolicy.checkupFetchLimit) Einträge werden ausgewertet. Werte mit „+“ sind Untergrenzen; ältere Messgrößen können fehlen."
                )
                : l.tr(
                    zh: "异常数按每项指标的最新值统计。",
                    en: "Outliers use the latest value for each tracked metric.",
                    de: "Abweichungen basieren auf dem neuesten Wert jeder erfassten Messgröße."
                )
            )
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(Color.ohanaTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func recentSection(_ snapshot: HumanHealthCheckupLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "最近录入", en: "Recent Logs", de: "Letzte Einträge"))

            if snapshot.sortedLogs.isEmpty {
                emptyRecentState
            } else {
                ForEach(Array(snapshot.sortedLogs.prefix(5))) { log in
                    recentLogRow(log)
                }
            }
        }
    }

    private func catalogSection(_ snapshot: HumanHealthCheckupLogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(l.tr(zh: "分类指标", en: "Metric Catalog", de: "Wertekatalog"))

            ForEach(HealthMetricCategory.allCases) { category in
                categoryBlock(category, snapshot: snapshot)
            }
        }
    }

    private func categoryBlock(
        _ category: HealthMetricCategory,
        snapshot: HumanHealthCheckupLogSnapshot
    ) -> some View {
        let metrics = HealthMetricCatalog.metrics(in: category)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: category.systemImage)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 32, height: 32) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(category.color, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.displayName(l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "\(metrics.count) 项", en: "\(metrics.count) metrics", de: "\(metrics.count) Werte"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 0)
            }

            ForEach(metrics) { metric in
                metricRow(metric, snapshot: snapshot)
            }
        }
    }

    private func metricRow(
        _ metric: HealthMetric,
        snapshot: HumanHealthCheckupLogSnapshot
    ) -> some View {
        let defaultUnit = metric.defaultUnit(for: appCountry)
        let latest = latestLog(for: metric, snapshot: snapshot)
        let historyMayExistOutsideWindow = latest == nil && snapshot.didReachFetchLimit
        return HStack(spacing: 8) {
            Group {
                if isReadOnly {
                    metricSummaryContent(
                        metric,
                        defaultUnit: defaultUnit,
                        latest: latest,
                        historyMayExistOutsideWindow: historyMayExistOutsideWindow
                    )
                        .accessibilityLabel(metric.displayName(l))
                } else {
                    Button {
                        withAnimation(GoMotion.feedback) {
                            recordingMetric = metric
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        metricSummaryContent(
                            metric,
                            defaultUnit: defaultUnit,
                            latest: latest,
                            historyMayExistOutsideWindow: historyMayExistOutsideWindow
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(
                        zh: "记录 \(metric.displayName(l))",
                        en: "Record \(metric.displayName(l))",
                        de: "\(metric.displayName(l)) erfassen"
                    ))
                    .accessibilityIdentifier("human-health-metric-record-\(metric.key)")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())

            Button {
                detailMetric = metric
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(metric.category.color)
                    .frame(width: 44, height: 44)
                    .background(metric.category.color.opacity(0.14), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(
                zh: "查看 \(metric.displayName(l)) 趋势",
                en: "View \(metric.displayName(l)) trend",
                de: "Verlauf von \(metric.displayName(l)) anzeigen"
            ))
            .accessibilityIdentifier("human-health-metric-trend-\(metric.key)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func metricSummaryContent(
        _ metric: HealthMetric,
        defaultUnit: HealthMetricUnit,
        latest: HumanHealthMetricLog?,
        historyMayExistOutsideWindow: Bool
    ) -> some View {
        let referenceUnit = latest.flatMap { metric.unit(for: $0.unitCode) } ?? defaultUnit
        let referenceLabel = latest.map {
            HumanHealthMetricReferenceEvaluator.referenceLabel(
                for: $0,
                fallbackUnit: referenceUnit
            )
        } ?? referenceUnit.normalRangeLabel()
        return HStack(spacing: 12) {
            latestStatusDot(metric: metric, log: latest)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(metric.displayName(l))
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if let short = metric.shortNames.first, short != metric.displayName(l) {
                        Text(short)
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(metric.category.color)
                            .padding(.horizontal, 6)
                            .frame(height: 20)
                            .background(metric.category.color.opacity(0.13), in: Capsule())
                    }
                }
                Text(l.tr(
                    zh: "参考 \(referenceLabel)",
                    en: "Ref \(referenceLabel)",
                    de: "Ref \(referenceLabel)"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                if let latest,
                   let unit = metric.unit(for: latest.unitCode) {
                    Text(unit.formattedValue(latest.value))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(latest.date, format: .dateTime.month().day())
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                } else {
                    Text(historyMayExistOutsideWindow
                        ? l.tr(zh: "更早记录可能存在", en: "Older logs may exist", de: "Ältere Einträge möglich")
                        : isReadOnly
                            ? l.tr(zh: "暂无记录", en: "No log", de: "Kein Eintrag")
                            : l.tr(zh: "待记录", en: "Record", de: "Erfassen")
                    )
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(metric.category.color)
                }
            }
        }
        .contentShape(Rectangle())
        .frame(minHeight: 64)
    }

    private func recentLogRow(_ log: HumanHealthMetricLog) -> some View {
        guard let metric = HealthMetricCatalog.metric(forKey: log.metricKey) else {
            return AnyView(EmptyView())
        }
        let unit = metric.unit(for: log.unitCode) ?? metric.defaultUnit(for: appCountry)
        let status = HumanHealthMetricReferenceEvaluator.status(
            for: log,
            fallbackUnit: unit
        )
        return AnyView(
            NavigationLink {
                HumanHealthMetricDetailView(human: human, metric: metric)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: metric.category.systemImage)
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .background(metric.category.color, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.displayName(l))
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 6, height: 6) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            Text(status.label(l))
                            Text("·")
                            Text(log.date, format: .dateTime.year().month().day())
                        }
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    }

                    Spacer(minLength: 0)

                    Text(unit.formattedValue(log.value))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 62)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
        )
    }

    private var emptyRecentState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 28, weight: .bold))
                .foregroundStyle(Color.goTeal)
            Text(l.tr(zh: "还没有体检指标记录", en: "No checkup metrics yet", de: "Noch keine Check-up-Werte"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "从下方分类选择一个指标开始追踪。", en: "Pick a metric below to start tracking.", de: "Wähle unten einen Wert zum Tracken."))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var privacyLockedView: some View {
        HumanModulePrivacyLockedView(
            title: l.tr(zh: "身体数据仅本人可见", en: "Body data is private", de: "Körperdaten sind privat"),
            message: l.tr(zh: "请切换到本人档案后再查看体检指标。", en: "Switch to this profile to view checkup metrics.", de: "Wechsle zu diesem Profil, um Check-up-Werte zu sehen.")
        )
    }

    private func summaryItem(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(tint)
            Text(value)
                .font(OhanaFont.metric(size: 24, .black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
            Text(label)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func latestLog(
        for metric: HealthMetric,
        snapshot: HumanHealthCheckupLogSnapshot
    ) -> HumanHealthMetricLog? {
        snapshot.latestByKey[metric.key]
    }

    private func logs(
        for metric: HealthMetric,
        snapshot: HumanHealthCheckupLogSnapshot
    ) -> [HumanHealthMetricLog] {
        snapshot.logsByKey[metric.key] ?? []
    }

    private func preferredUnit(
        for metric: HealthMetric,
        snapshot: HumanHealthCheckupLogSnapshot
    ) -> HealthMetricUnit {
        if let latest = latestLog(for: metric, snapshot: snapshot),
           let unit = metric.unit(for: latest.unitCode) {
            return unit
        }
        return metric.defaultUnit(for: appCountry)
    }

    private func trackedChartAccessibilitySummary(
        metric: HealthMetric,
        logs: [HumanHealthMetricLog],
        unit: HealthMetricUnit
    ) -> String {
        guard let latest = logs.first else {
            return l.tr(
                zh: "\(metric.displayName(l))，暂无趋势记录",
                en: "\(metric.displayName(l)), no trend logs",
                de: "\(metric.displayName(l)), keine Verlaufseinträge"
            )
        }
        let latestValue = unit.formattedValue(latest.value)
        guard logs.count > 1, let oldest = logs.last else {
            return l.tr(
                zh: "\(metric.displayName(l))，最新 \(latestValue)，共 1 条记录",
                en: "\(metric.displayName(l)), latest \(latestValue), 1 log",
                de: "\(metric.displayName(l)), aktuell \(latestValue), 1 Eintrag"
            )
        }
        let oldestValue = unit.formattedValue(oldest.value)
        return l.tr(
            zh: "\(metric.displayName(l)) 趋势，最早 \(oldestValue)，最新 \(latestValue)，共 \(logs.count) 条记录",
            en: "\(metric.displayName(l)) trend, earliest \(oldestValue), latest \(latestValue), \(logs.count) logs",
            de: "Verlauf für \(metric.displayName(l)), zuerst \(oldestValue), aktuell \(latestValue), \(logs.count) Einträge"
        )
    }

    private func latestStatusDot(metric: HealthMetric, log: HumanHealthMetricLog?) -> some View {
        let color: Color = if let log, let unit = metric.unit(for: log.unitCode) {
            HumanHealthMetricReferenceEvaluator.status(
                for: log,
                fallbackUnit: unit
            ).color
        } else {
            metric.category.color.opacity(0.46)
        }
        return Circle()
            .fill(color)
            .frame(width: 9, height: 9) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
    }
}
