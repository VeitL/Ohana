//
//  HumanHealthConditionDetailView.swift
//  Ohana
//

import Foundation
import SwiftData
import SwiftUI

private enum HumanHealthConditionDetailSheetDestination: Identifiable {
    case editCondition
    case createObservation
    case editObservation(UUID)

    var id: String {
        switch self {
        case .editCondition: "edit-condition"
        case .createObservation: "create-observation"
        case let .editObservation(id): "edit-observation-\(id.uuidString)"
        }
    }
}

struct HumanHealthConditionDetailView: View {
    let human: Human
    let condition: HumanHealthCondition
    let canViewMedication: Bool
    let isReadOnly: Bool
    let observations: [HumanHealthObservation]
    let initialSnapshot: HumanHealthConditionTrendSnapshot
    let recentObservationCount: Int
    let analysisIsLimited: Bool
    let medicationAnalysisIsIncomplete: Bool
    let medications: [HumanMedication]
    let medicationLogs: [HumanMedicationLog]
    let metricLogs: [HumanHealthMetricLog]
    let onRecordsChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var sheetDestination: HumanHealthConditionDetailSheetDestination?
    @State private var refreshedObservations: [HumanHealthObservation]?
    @State private var refreshedSnapshot: HumanHealthConditionTrendSnapshot?
    @State private var refreshedRecentObservationCount: Int?
    @State private var refreshedAnalysisIsLimited: Bool?
    @State private var refreshFailed = false
    @State private var isLoadingRecentObservations = true
    @State private var hasLoadedRecentObservations = false

    private var l: L10n { L10n(appLanguage) }
    private var appLocale: Locale { AppLanguage.effectiveLocale }
    private var category: HumanHealthConditionCategory { condition.category }
    private var snapshot: HumanHealthConditionTrendSnapshot { refreshedSnapshot ?? initialSnapshot }
    private var currentRecentObservationCount: Int {
        refreshedRecentObservationCount ?? recentObservationCount
    }
    private var currentAnalysisIsLimited: Bool {
        refreshedAnalysisIsLimited ?? analysisIsLimited
    }
    private var medicationSnapshot: HumanHealthMedicationTrackingSnapshot {
        guard canViewMedication else { return .empty }
        return HumanHealthConditionAnalysis.medicationSnapshot(
            condition: condition,
            medications: medications,
            logs: medicationLogs
        )
    }
    private var linkedMedications: [HumanMedication] {
        guard canViewMedication else { return [] }
        let ids = Set(condition.linkedMedicationIDs)
        return medications.filter { ids.contains($0.id) }
    }
    private var sortedObservations: [HumanHealthObservation] {
        currentObservations.sorted {
            if $0.recordedAt == $1.recordedAt {
                if $0.createdAt == $1.createdAt { return $0.id > $1.id }
                return $0.createdAt > $1.createdAt
            }
            return $0.recordedAt > $1.recordedAt
        }
    }
    private var currentObservations: [HumanHealthObservation] {
        refreshedObservations ?? observations
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    if isLoadingRecentObservations {
                        recentObservationLoadingNotice
                    }
                    if refreshFailed {
                        refreshFailureNotice
                    }
                    summaryStrip
                    severityTrendCard
                    descriptiveSummaryCard
                    medicationSection
                    metricSection
                    carePlanSection
                    observationSection
                    boundaryNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityIdentifier("human-condition-detail-\(condition.id.uuidString)")
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            if condition.trackingStatus != .resolved, !isReadOnly {
                HumanModuleFloatingActionButton(
                    title: l.tr(zh: "记录状态", en: "Log state", de: "Status erfassen"),
                    icon: "plus"
                ) {
                    sheetDestination = .createObservation
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .accessibilityIdentifier("human-condition-status-add-action")
                .padding(.trailing, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle(condition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .editCondition:
                HumanHealthConditionEditorSheet(
                    human: human,
                    condition: condition,
                    medications: medications,
                    canViewMedication: canViewMedication,
                    onSaved: refreshRecords,
                    onDeleted: {
                        refreshedObservations = nil
                        refreshedSnapshot = nil
                        refreshedRecentObservationCount = nil
                        refreshedAnalysisIsLimited = nil
                        onRecordsChanged()
                        dismiss()
                    }
                )
            case .createObservation:
                HumanHealthObservationEditorSheet(
                    human: human,
                    condition: condition,
                    observation: nil,
                    canViewMedication: canViewMedication,
                    onSaved: refreshRecords,
                    onDeleted: refreshRecords
                )
            case let .editObservation(id):
                if let observation = currentObservations.first(where: { $0.id == id }) {
                    HumanHealthObservationEditorSheet(
                        human: human,
                        condition: condition,
                        observation: observation,
                        canViewMedication: canViewMedication,
                        onSaved: refreshRecords,
                        onDeleted: refreshRecords
                    )
                } else {
                    ContentUnavailableView(
                        l.tr(zh: "记录已不存在", en: "Record unavailable", de: "Eintrag nicht verfügbar"),
                        systemImage: "list.clipboard"
                    )
                }
            }
        }
        .task(id: condition.id) {
            guard refreshedObservations == nil else { return }
            await Task.yield()
            loadRecentRecords(notifyParent: false)
        }
    }
}

private extension HumanHealthConditionDetailView {
    @MainActor
    private func refreshRecords() {
        loadRecentRecords(notifyParent: true)
    }

    @MainActor
    private func retryRecentRecords() {
        loadRecentRecords(notifyParent: false)
    }

    @MainActor
    private func loadRecentRecords(notifyParent: Bool) {
        isLoadingRecentObservations = true
        defer { isLoadingRecentObservations = false }
        do {
            let refreshed = try HumanHealthConditionsRouteData.loadRecentObservations(
                humanID: human.id,
                conditionID: condition.id,
                context: modelContext
            )
            refreshedObservations = refreshed.observations
            refreshedSnapshot = HumanHealthConditionAnalysis.trendSnapshot(
                observations: refreshed.observations,
                includeMedicationDetails: canViewMedication
            )
            refreshedRecentObservationCount = refreshed.totalCount
            refreshedAnalysisIsLimited = refreshed.isLimited
            hasLoadedRecentObservations = true
            refreshFailed = false
            if notifyParent {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: l.tr(
                        zh: "健康状况分析已更新",
                        en: "Health condition analysis updated",
                        de: "Analyse des Gesundheitszustands aktualisiert"
                    )
                )
            }
        } catch {
            refreshFailed = true
            OhanaLog.warning("Human health condition detail failed to refresh observations: \(error.localizedDescription)")
            UIAccessibility.post(
                notification: .announcement,
                argument: l.tr(
                    zh: "近期状态记录刷新失败",
                    en: "Recent state logs failed to refresh",
                    de: "Aktuelle Status-Einträge konnten nicht aktualisiert werden"
                )
            )
        }
        if notifyParent { onRecordsChanged() }
    }

    private var recentObservationLoadingNotice: some View {
        Label(
            l.tr(
                zh: "正在读取完整的近 12 个月分析…",
                en: "Loading the complete 12-month analysis…",
                de: "Vollständige 12-Monats-Analyse wird geladen …"
            ),
            systemImage: "arrow.triangle.2.circlepath"
        )
        .font(OhanaFont.caption(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var pageHeader: some View {
        HumanModulePageHeader(
            human: human,
            title: condition.name,
            subtitle: "\(category.displayName(l)) · \(condition.trackingStatus.displayName(l))",
            showsCloseButton: false,
            onClose: {}
        ) {
            if !isReadOnly {
                Button {
                    sheetDestination = .editCondition
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "slider.horizontal.3").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .ohanaGlassIconButton()
                .accessibilityLabel(l.tr(zh: "编辑健康状况", en: "Edit health condition", de: "Gesundheitszustand bearbeiten"))
                .accessibilityIdentifier("human-condition-edit-action")
            }
        }
    }

    private var refreshFailureNotice: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                refreshFailureLabel
                Spacer(minLength: 8)
                Button(l.tr(zh: "重试", en: "Retry", de: "Erneut"), action: retryRecentRecords)
                    .font(OhanaFont.caption(.black))
            }
            VStack(alignment: .leading, spacing: 9) {
                refreshFailureLabel
                Button(l.tr(zh: "重试", en: "Retry", de: "Erneut"), action: retryRecentRecords)
                    .font(OhanaFont.caption(.black))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.goOrange.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var refreshFailureLabel: some View {
        Label(
            hasLoadedRecentObservations
                ? l.tr(
                    zh: "刷新失败，仍显示上一次成功读取的近期记录。",
                    en: "Refresh failed. The last successfully loaded recent records are still shown.",
                    de: "Aktualisierung fehlgeschlagen. Die zuletzt erfolgreich geladenen aktuellen Einträge bleiben sichtbar."
                )
                : l.tr(
                    zh: "近期记录未能读取；记录仍保存在本机，可重试或查看全部历史。",
                    en: "Recent logs couldn’t load. They remain on this device; retry or open the full history.",
                    de: "Aktuelle Einträge konnten nicht geladen werden. Sie bleiben auf diesem Gerät; erneut versuchen oder den vollständigen Verlauf öffnen."
                ),
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(OhanaFont.caption(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var summaryStrip: some View {
        HumanModuleMetricStrip(metrics: [
            FeatureHubMetric(
                id: "latest-severity",
                title: l.tr(zh: "最近严重度", en: "Latest severity", de: "Letzte Stärke"),
                value: snapshot.latestSeverity.map { "\($0)/10" } ?? "—"
            ),
            FeatureHubMetric(
                id: "thirty-day-logs",
                title: l.tr(zh: "近 30 天", en: "Last 30 days", de: "Letzte 30 Tage"),
                value: "\(snapshot.thirtyDayCount)"
            ),
            FeatureHubMetric(
                id: "severity-trend",
                title: l.tr(zh: "近 30 天变化", en: "30-day change", de: "30-Tage-Verlauf"),
                value: snapshot.severityTrend.displayName(l)
            )
        ])
    }

    @ViewBuilder
    private var severityTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    severityTrendTitle
                    Spacer(minLength: 8)
                    severityTrendBadge
                }
                VStack(alignment: .leading, spacing: 8) {
                    severityTrendTitle
                    severityTrendBadge
                }
            }

            if snapshot.severityChartPoints.isEmpty {
                Text(l.tr(zh: "暂无趋势", en: "No trend yet", de: "Noch kein Verlauf"))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 74)
            } else {
                if currentAnalysisIsLimited {
                    Label(
                        l.tr(
                            zh: "趋势最多使用近 12 个月 1,024 条；完整历史可分页查看。",
                            en: "Trends use up to 1,024 logs from 12 months; full history remains paged.",
                            de: "Trends nutzen bis zu 1.024 Einträge aus 12 Monaten; der vollständige Verlauf bleibt seitenweise verfügbar."
                        ),
                        systemImage: "info.circle"
                    )
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text(l.tr(
                    zh: "折线 14 条 · 方向对比近 30 天",
                    en: "14-point line · direction compares 30 days",
                    de: "14-Punkte-Linie · Richtung vergleicht 30 Tage"
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

                OhanaMinimalTrendChart(
                    points: snapshot.severityChartPoints,
                    yDomain: 0 ... 10,
                    tint: category.tint,
                    showsLatestPoint: true
                )
                .frame(height: 118)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l.tr(
                    zh: "自评严重度趋势，\(snapshot.severityTrend.displayName(l))",
                    en: "Self-reported severity trend, \(snapshot.severityTrend.displayName(l))",
                    de: "Verlauf der selbst eingeschätzten Stärke, \(snapshot.severityTrend.displayName(l))"
                ))

                Divider()

                HStack {
                    Text(l.tr(zh: "近 7 天记录频次", en: "Logging frequency in 7 days", de: "Eintragshäufigkeit in 7 Tagen"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Text("\(snapshot.sevenDayCount)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(category.tint)
                }
                OhanaMinimalBarChart(
                    points: snapshot.frequencyChartPoints,
                    tint: category.tint,
                    showsLabels: true,
                    maxBarHeight: 42
                )
                .frame(height: 62)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l.tr(
                    zh: "近 7 天共记录 \(snapshot.sevenDayCount) 次",
                    en: "\(snapshot.sevenDayCount) logs in the last 7 days",
                    de: "\(snapshot.sevenDayCount) Einträge in den letzten 7 Tagen"
                ))
            }
        }
        .padding(15)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var severityTrendTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(l.tr(zh: "自评严重度", en: "Self-reported severity", de: "Selbst eingeschätzte Stärke"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "0 表示无不适，10 表示影响很强", en: "0 is no impact; 10 is very high impact", de: "0 bedeutet keine, 10 eine sehr starke Belastung"))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var severityTrendBadge: some View {
        Text(snapshot.severityTrend.displayName(l))
            .font(OhanaFont.caption(.black))
            .foregroundStyle(snapshot.severityTrend.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(snapshot.severityTrend.tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var descriptiveSummaryCard: some View {
        let hasSummary = snapshot.averageSeverity != nil
            || snapshot.averageMood != nil
            || snapshot.averageSleepHours != nil
            || !snapshot.topSymptomTags.isEmpty
            || (canViewMedication && !snapshot.medicationResponseCounts.isEmpty)
            || (canViewMedication && snapshot.sideEffectNoteCount > 0)

        if hasSummary {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(l.tr(zh: "近 30 天摘要", en: "30-day summary", de: "30-Tage-Zusammenfassung"))
                if let severity = snapshot.averageSeverity {
                    let value = severity.formatted(
                        .number.precision(.fractionLength(1)).locale(appLocale)
                    )
                    summaryRow(
                        icon: "waveform.path.ecg",
                        title: l.tr(zh: "平均自评严重度", en: "Average self-reported severity", de: "Durchschnittliche selbst eingeschätzte Stärke"),
                        value: "\(value)/10"
                    )
                }
                if let mood = snapshot.averageMood {
                    let value = mood.formatted(
                        .number.precision(.fractionLength(1)).locale(appLocale)
                    )
                    summaryRow(
                        icon: "face.smiling.inverse",
                        title: l.tr(zh: "平均心情自评", en: "Average mood rating", de: "Durchschnittliche Stimmung"),
                        value: "\(value)/10"
                    )
                }
                if let sleep = snapshot.averageSleepHours {
                    let value = sleep.formatted(
                        .number.precision(.fractionLength(1)).locale(appLocale)
                    )
                    summaryRow(
                        icon: "moon.zzz.fill",
                        title: l.tr(zh: "平均睡眠", en: "Average sleep", de: "Durchschnittlicher Schlaf"),
                        value: l.tr(zh: "\(value) 小时", en: "\(value) hr", de: "\(value) Std.")
                    )
                }
                if !snapshot.topSymptomTags.isEmpty {
                    summaryRow(
                        icon: "tag.fill",
                        title: l.tr(zh: "常见标签", en: "Common tags", de: "Häufige Tags"),
                        value: snapshot.topSymptomTags.joined(separator: " · ")
                    )
                }
                if canViewMedication, !snapshot.medicationResponseCounts.isEmpty {
                    summaryRow(
                        icon: "pills.fill",
                        title: l.tr(zh: "主观用药反应", en: "Self-reported medication response", de: "Selbst berichtete Medikamentenreaktion"),
                        value: medicationResponseSummary
                    )
                }
                if canViewMedication, snapshot.sideEffectNoteCount > 0 {
                    summaryRow(
                        icon: "exclamationmark.bubble.fill",
                        title: l.tr(zh: "副作用/不适记录", en: "Side-effect/discomfort logs", de: "Nebenwirkungs-/Beschwerdeeinträge"),
                        value: "\(snapshot.sideEffectNoteCount)"
                    )
                }
            }
            .padding(15)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
    }

    @ViewBuilder
    private var medicationSection: some View {
        if canViewMedication, !linkedMedications.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle(l.tr(zh: "关联用药", en: "Linked medication", de: "Verknüpfte Medikamente"))
                    Spacer()
                    if medicationAnalysisIsIncomplete {
                        Text(l.tr(
                            zh: "近 7 天分析不完整",
                            en: "7-day analysis incomplete",
                            de: "7-Tage-Analyse unvollständig"
                        ))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goOrange)
                    } else if let rate = medicationSnapshot.completionRate {
                        Text(l.tr(
                            zh: "近 7 天已到时 \(rate)%",
                            en: "7-day due-to-now \(rate)%",
                            de: "7 Tage bis jetzt fällig \(rate)%"
                        ))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goTeal)
                    }
                }

                ForEach(linkedMedications) { medication in
                    HStack(spacing: 11) {
                        Circle()
                            .fill(Color(hex: medication.colorHex))
                            .frame(width: 10, height: 10) // a11y: allow decorative medication color dot; parent row owns accessibility.
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(medication.name)
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text("\(medication.dosage) · \(medication.frequency.displayTitle(l: l))")
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        Text(medication.isActive ? l.tr(zh: "启用", en: "Active", de: "Aktiv") : l.tr(zh: "停用", en: "Stopped", de: "Beendet"))
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(medication.isActive ? Color.goTeal : Color.ohanaTertiaryText)
                    }
                    .padding(12)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                }

                if medicationAnalysisIsIncomplete {
                    Label(
                        l.tr(
                            zh: "某个关联计划在近 7 天超过 \(HumanHealthConditionsRouteData.medicationLogAnalysisLimitPerPlan) 条服药日志；完成率已隐藏，较早记录仍保留。",
                            en: "A linked plan has more than \(HumanHealthConditionsRouteData.medicationLogAnalysisLimitPerPlan) dose logs in seven days. Completion is hidden; older logs remain saved.",
                            de: "Ein verknüpfter Plan hat in sieben Tagen mehr als \(HumanHealthConditionsRouteData.medicationLogAnalysisLimitPerPlan) Einnahmeprotokolle. Die Erfüllung ist ausgeblendet; ältere Einträge bleiben gespeichert."
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("human-condition-medication-analysis-incomplete")
                }

                Text(l.tr(
                    zh: "完成率按近 7 天当前计划估算；计划改动会影响回看，主观反应不代表疗效或因果。",
                    en: "Completion is estimated from the current 7-day plan. Plan changes affect the lookback; responses do not prove effect or cause.",
                    de: "Die Erfüllung wird aus dem aktuellen 7-Tage-Plan geschätzt. Planänderungen beeinflussen den Rückblick; Reaktionen belegen weder Wirkung noch Ursache."
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var metricSection: some View {
        if !condition.linkedMetricKeys.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(l.tr(zh: "关联体检指标", en: "Linked checkup metrics", de: "Verknüpfte Check-up-Werte"))

                ForEach(condition.linkedMetricKeys, id: \.self) { key in
                    if let metric = HealthMetricCatalog.metric(forKey: key) {
                        linkedMetricRow(metric)
                    }
                }
            }
        }
    }

    private func linkedMetricRow(_ metric: HealthMetric) -> some View {
        let latest = metricLogs
            .filter { $0.metricKey == metric.key }
            .max { lhs, rhs in
                if lhs.date == rhs.date { return lhs.createdAt < rhs.createdAt }
                return lhs.date < rhs.date
            }
        let unit = latest.flatMap { metric.unit(for: $0.unitCode) }

        return HStack(spacing: 11) {
            Image(systemName: metric.category.systemImage).accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(metric.category.color)
                .frame(width: 44, height: 44)
                .background(metric.category.color.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName(l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(latest?.date.formatted(Date.FormatStyle(
                    date: .abbreviated,
                    time: .omitted,
                    locale: appLocale
                )) ?? l.tr(zh: "尚未录入", en: "Not recorded", de: "Nicht erfasst"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if let latest, let unit {
                Text(formattedMetricValue(latest.value, unit: unit))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(metric.category.color)
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func formattedMetricValue(_ value: Double, unit: HealthMetricUnit) -> String {
        let magnitude = abs(value)
        let fractionDigits = if magnitude >= 1000 { 0 }
        else if magnitude >= 100 { 1 }
        else if magnitude >= 1 { 2 }
        else { 3 }
        let formatted = value.formatted(
            .number.precision(.fractionLength(fractionDigits)).locale(appLocale)
        )
        return "\(formatted) \(unit.label)"
    }

    @ViewBuilder
    private var carePlanSection: some View {
        if condition.startedOn != nil
            || !condition.carePlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !condition.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(l.tr(zh: "照护信息", en: "Care information", de: "Versorgungsinformationen"))
                if let startedOn = condition.startedOn {
                    summaryRow(
                        icon: "calendar",
                        title: l.tr(zh: "记录的开始日期", en: "Recorded start date", de: "Erfasstes Startdatum"),
                        value: startedOn.formatted(Date.FormatStyle(
                            date: .abbreviated,
                            time: .omitted,
                            locale: appLocale
                        ))
                    )
                }
                if !condition.carePlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textBlock(
                        title: l.tr(zh: "当前计划", en: "Current plan", de: "Aktueller Plan"),
                        text: condition.carePlan
                    )
                }
                if !condition.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textBlock(
                        title: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                        text: condition.notes
                    )
                }
            }
        }
    }

    private var observationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    sectionTitle(l.tr(zh: "状态记录", en: "State logs", de: "Status-Einträge"))
                    Spacer(minLength: 8)
                    recentObservationCountLabel
                }
                VStack(alignment: .leading, spacing: 4) {
                    sectionTitle(l.tr(zh: "状态记录", en: "State logs", de: "Status-Einträge"))
                    recentObservationCountLabel
                }
            }

            if !hasLoadedRecentObservations {
                Text(l.tr(
                    zh: isLoadingRecentObservations ? "正在读取近期状态记录…" : "近期状态记录暂不可用。",
                    en: isLoadingRecentObservations ? "Loading recent state logs…" : "Recent state logs are currently unavailable.",
                    de: isLoadingRecentObservations ? "Aktuelle Status-Einträge werden geladen …" : "Aktuelle Status-Einträge sind derzeit nicht verfügbar."
                ))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            } else if sortedObservations.isEmpty {
                Text(l.tr(zh: "还没有状态记录。", en: "No state logs yet.", de: "Noch keine Status-Einträge."))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            } else {
                ForEach(sortedObservations) { observation in
                    if isReadOnly {
                        observationRow(observation)
                            .accessibilityIdentifier("human-condition-observation-\(observation.id.uuidString)")
                    } else {
                        Button {
                            sheetDestination = .editObservation(observation.id)
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            observationRow(observation)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("human-condition-observation-\(observation.id.uuidString)")
                    }
                }
            }

            NavigationLink {
                HumanHealthObservationHistoryView(
                    human: human,
                    condition: condition,
                    canViewMedication: canViewMedication,
                    isReadOnly: isReadOnly,
                    onRecordsChanged: refreshRecords
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true)
                        .foregroundStyle(category.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "查看全部历史", en: "View all history", de: "Gesamten Verlauf ansehen"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "按页读取所有原始状态记录",
                            en: "Browse every raw state log in bounded pages",
                            de: "Alle rohen Status-Einträge seitenweise ansehen"
                        ))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward").accessibilityHidden(true)
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                .padding(13)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-condition-all-observations-action")
        }
    }

    private var recentObservationCountLabel: some View {
        Text(l.tr(
            zh: "近 12 个月 \(currentRecentObservationCount) 条",
            en: "\(currentRecentObservationCount) in 12 months",
            de: "\(currentRecentObservationCount) in 12 Monaten"
        ))
        .font(OhanaFont.caption(.bold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func observationRow(_ observation: HumanHealthObservation) -> some View {
        HumanHealthObservationCard(
            observation: observation,
            category: category,
            canViewMedication: canViewMedication
        )
    }

    private var medicationResponseSummary: String {
        [HumanMedicationResponse.helpful, .neutral, .worse].compactMap { response in
            guard let count = snapshot.medicationResponseCounts[response], count > 0 else { return nil }
            return "\(response.displayName(l)) \(count)"
        }
        .joined(separator: " · ")
    }

    private var boundaryNote: some View {
        Text(l.tr(
            zh: "若症状突然严重、持续恶化或你担心安全，请及时联系医生或当地急救服务。Ohana 不提供医疗诊断。",
            en: "If symptoms become suddenly severe, keep worsening, or safety is a concern, contact a clinician or local emergency service. Ohana does not provide diagnosis.",
            de: "Bei plötzlich starken, anhaltend schlimmeren Symptomen oder Sicherheitsbedenken wende dich an medizinische Hilfe oder den örtlichen Notdienst. Ohana stellt keine Diagnose."
        ))
        .font(OhanaFont.caption2(.semibold))
        .foregroundStyle(Color.ohanaSecondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .padding(13)
        .background(Color.goOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.headline(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
    }

    private func summaryRow(icon: String, title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                summaryRowIcon(icon)
                summaryRowTitle(title)
                Spacer(minLength: 8)
                summaryRowValue(value)
            }
            HStack(alignment: .top, spacing: 10) {
                summaryRowIcon(icon)
                VStack(alignment: .leading, spacing: 3) {
                    summaryRowTitle(title)
                    summaryRowValue(value)
                }
            }
        }
    }

    private func summaryRowIcon(_ icon: String) -> some View {
        Image(systemName: icon).accessibilityHidden(true)
            .foregroundStyle(category.tint)
            .frame(width: 24)
    }

    private func summaryRowTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryRowValue(_ value: String) -> some View {
        Text(value)
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryText)
            .multilineTextAlignment(.trailing)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func textBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(category.tint)
            Text(text)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}
