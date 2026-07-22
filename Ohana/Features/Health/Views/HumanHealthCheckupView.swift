//
//  HumanHealthCheckupView.swift
//  Ohana
//
//  Human checkup metric catalog and recent logs.
//

import SwiftData
import SwiftUI

struct HumanHealthCheckupView: View {
    let human: Human

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var recordingMetric: HealthMetric?
    @State private var detailMetric: HealthMetric?
    @State private var metricToOpenAfterEntry: HealthMetric?

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var l: L10n { L10n(appLanguage) }

    private var sortedLogs: [HumanHealthMetricLog] {
        human.healthMetricLogs.sorted {
            if $0.date == $1.date { return $0.createdAt > $1.createdAt }
            return $0.date > $1.date
        }
    }

    private var trackedMetricCount: Int {
        Set(human.healthMetricLogs.map(\.metricKey)).count
    }

    private var abnormalLogCount: Int {
        human.healthMetricLogs.count(where: { log in
            guard let metric = HealthMetricCatalog.metric(forKey: log.metricKey),
                  let unit = metric.unit(for: log.unitCode) else { return false }
            let status = unit.status(for: log.value)
            return status == .low || status == .high
        })
    }

    private var trackedMetrics: [HealthMetric] {
        var seen = Set<String>()
        return sortedLogs.compactMap { log in
            guard seen.insert(log.metricKey).inserted else { return nil }
            return HealthMetricCatalog.metric(forKey: log.metricKey)
        }
    }

    private var starterMetric: HealthMetric? {
        HealthMetricCatalog.metric(forKey: "tsh") ?? HealthMetricCatalog.all.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        pageHeader
                        summaryStrip
                        trackedChartSection
                        recentSection
                        catalogSection
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
                initialUnitCode: preferredUnit(for: metric).code,
                onSaved: { _ in
                    metricToOpenAfterEntry = metric
                }
            )
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.locale, AppLanguage.effectiveLocale)
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

    @ViewBuilder
    private var trackedChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(l.tr(zh: "已追踪图表", en: "Tracked Charts", de: "Getrackte Diagramme"))
                Spacer()
                Text(l.tr(zh: "\(trackedMetrics.count) 项", en: "\(trackedMetrics.count) tracked", de: "\(trackedMetrics.count) getrackt"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if trackedMetrics.isEmpty {
                trackedChartEmptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(trackedMetrics.prefix(12)) { metric in
                            trackedMetricChartCard(metric)
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

            if let starterMetric {
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
                    .frame(height: 36)
                    .background(Color.goOrange, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-health-metric-starter-record-action")
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func trackedMetricChartCard(_ metric: HealthMetric) -> some View {
        let logs = logs(for: metric)
        let latest = logs.first
        let unit = latest.flatMap { metric.unit(for: $0.unitCode) } ?? metric.defaultUnit(for: appCountry)
        let unitLogs = logs.filter { $0.unitCode == unit.code }.sorted { $0.date < $1.date }
        let points = unitLogs.suffix(12).map {
            OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id.uuidString)
        }
        var yValues = unitLogs.map(\.value)
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
        .accessibilityLabel(l.tr(
            zh: "查看 \(metric.displayName(l)) 追踪图",
            en: "View \(metric.displayName(l)) tracking chart",
            de: "Tracking-Diagramm für \(metric.displayName(l)) anzeigen"
        ))
        .accessibilityIdentifier("human-health-metric-chart-\(metric.key)")
    }

    private var countryTitle: String {
        AppCountry.option(for: appCountry).displayName.resolve(appLanguage)
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryItem(
                icon: "list.bullet.rectangle.fill",
                value: "\(HealthMetricCatalog.all.count)",
                label: l.tr(zh: "目录指标", en: "Catalog", de: "Katalog"),
                tint: Color.goTeal
            )
            summaryItem(
                icon: "chart.xyaxis.line",
                value: "\(trackedMetricCount)",
                label: l.tr(zh: "已追踪", en: "Tracked", de: "Getrackt"),
                tint: Color.goOrange
            )
            summaryItem(
                icon: "exclamationmark.triangle.fill",
                value: "\(abnormalLogCount)",
                label: l.tr(zh: "偏离记录", en: "Outliers", de: "Abweichungen"),
                tint: Color.goYellow
            )
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "最近录入", en: "Recent Logs", de: "Letzte Einträge"))

            if sortedLogs.isEmpty {
                emptyRecentState
            } else {
                ForEach(Array(sortedLogs.prefix(5))) { log in
                    recentLogRow(log)
                }
            }
        }
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(l.tr(zh: "分类指标", en: "Metric Catalog", de: "Wertekatalog"))

            ForEach(HealthMetricCategory.allCases) { category in
                categoryBlock(category)
            }
        }
    }

    private func categoryBlock(_ category: HealthMetricCategory) -> some View {
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
                metricRow(metric)
            }
        }
    }

    private func metricRow(_ metric: HealthMetric) -> some View {
        let defaultUnit = metric.defaultUnit(for: appCountry)
        let latest = latestLog(for: metric)
        return HStack(spacing: 8) {
            Button {
                withAnimation(GoMotion.feedback) {
                    recordingMetric = metric
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
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
                            zh: "参考 \(defaultUnit.normalRangeLabel())",
                            en: "Ref \(defaultUnit.normalRangeLabel())",
                            de: "Ref \(defaultUnit.normalRangeLabel())"
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
                            Text(l.tr(zh: "待记录", en: "Record", de: "Erfassen"))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(metric.category.color)
                        }
                    }
                }
                .contentShape(Rectangle())
                .frame(minHeight: 64)
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityLabel(l.tr(
                zh: "记录 \(metric.displayName(l))",
                en: "Record \(metric.displayName(l))",
                de: "\(metric.displayName(l)) erfassen"
            ))
            .accessibilityIdentifier("human-health-metric-record-\(metric.key)")

            Button {
                detailMetric = metric
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(metric.category.color)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
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

    private func recentLogRow(_ log: HumanHealthMetricLog) -> some View {
        guard let metric = HealthMetricCatalog.metric(forKey: log.metricKey) else {
            return AnyView(EmptyView())
        }
        let unit = metric.unit(for: log.unitCode) ?? metric.defaultUnit(for: appCountry)
        let status = unit.status(for: log.value)
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
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func latestLog(for metric: HealthMetric) -> HumanHealthMetricLog? {
        sortedLogs.first { $0.metricKey == metric.key }
    }

    private func logs(for metric: HealthMetric) -> [HumanHealthMetricLog] {
        sortedLogs.filter { $0.metricKey == metric.key }
    }

    private func preferredUnit(for metric: HealthMetric) -> HealthMetricUnit {
        if let latest = latestLog(for: metric),
           let unit = metric.unit(for: latest.unitCode) {
            return unit
        }
        return metric.defaultUnit(for: appCountry)
    }

    private func latestStatusDot(metric: HealthMetric, log: HumanHealthMetricLog?) -> some View {
        let color: Color = if let log, let unit = metric.unit(for: log.unitCode) {
            unit.status(for: log.value).color
        } else {
            metric.category.color.opacity(0.46)
        }
        return Circle()
            .fill(color)
            .frame(width: 9, height: 9) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
    }
}
