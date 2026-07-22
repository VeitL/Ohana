//
//  HumanHealthMetricDetailView.swift
//  Ohana
//
//  Trend, reference range, and history for one human checkup metric.
//

import SwiftData
import SwiftUI

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
    @State private var showingEntrySheet = false

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var l: L10n { L10n(appLanguage) }
    private var tint: Color { metric.category.color }

    private var allMetricLogs: [HumanHealthMetricLog] {
        human.healthMetricLogs
            .filter { $0.metricKey == metric.key }
            .sorted { $0.date > $1.date }
    }

    private var preferredUnit: HealthMetricUnit {
        if let latest = allMetricLogs.first,
           let latestUnit = metric.unit(for: latest.unitCode) {
            return latestUnit
        }
        return metric.defaultUnit(for: appCountry)
    }

    private var selectedUnit: HealthMetricUnit {
        metric.unit(for: selectedUnitCode) ?? preferredUnit
    }

    private var selectedUnitLogs: [HumanHealthMetricLog] {
        allMetricLogs.filter { $0.unitCode == selectedUnit.code }
    }

    private var chartLogs: [HumanHealthMetricLog] {
        Array(selectedUnitLogs.sorted { $0.date < $1.date }.suffix(30))
    }

    private var chartPoints: [OhanaMinimalChartPoint] {
        chartLogs.map {
            OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id.uuidString)
        }
    }

    private var chartYDomain: ClosedRange<Double> {
        var values = chartLogs.map(\.value)
        if let low = selectedUnit.normalLow { values.append(low) }
        if let high = selectedUnit.normalHigh { values.append(high) }
        return OhanaChartStyle.yDomain(values: values, includeZero: false)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OhanaAppBackground()

            if isPrivacyLocked {
                privacyLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        pageHeader
                        heroMetric
                        chartSection
                        unitSelector
                        referenceSection
                        historySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)

                addButton
                    .padding(.bottom, 28)
            }
        }
        .navigationTitle(metric.displayName(l))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEntrySheet) {
            HumanHealthMetricEntrySheet(
                human: human,
                metric: metric,
                initialUnitCode: selectedUnit.code,
                onSaved: { log in
                    selectedUnitCode = log.unitCode
                }
            )
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .environment(\.locale, AppLanguage.effectiveLocale)
        .accessibilityIdentifier("human-health-metric-detail-\(metric.key)")
        .onAppear {
            if selectedUnitCode.isEmpty {
                selectedUnitCode = preferredUnit.code
            }
        }
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

    private var heroMetric: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(l.tr(zh: "最新记录", en: "Latest", de: "Aktuell"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    if let latest = selectedUnitLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(selectedUnit.formattedValue(latest.value, includeUnit: false))
                                .font(OhanaFont.metric(size: 42, .black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .minimumScaleFactor(0.58)
                                .contentTransition(.numericText())
                            Text(selectedUnit.label)
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

                if let latest = selectedUnitLogs.first {
                    statusBadge(for: latest)
                }
            }

            HStack(spacing: 10) {
                miniStat(
                    icon: "list.bullet.rectangle.fill",
                    value: "\(allMetricLogs.count)",
                    label: l.tr(zh: "总记录", en: "Total", de: "Gesamt")
                )
                miniStat(
                    icon: "ruler.fill",
                    value: selectedUnit.normalRangeLabel(includeUnit: false),
                    label: selectedUnit.label
                )
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var unitSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "单位", en: "Unit", de: "Einheit"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(metric.units) { unit in
                        let selected = unit.code == selectedUnit.code
                        let isCountryDefault = unit.code == metric.defaultUnit(for: appCountry).code
                        Button {
                            withAnimation(GoMotion.feedback) {
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
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(l.tr(zh: "趋势", en: "Trend", de: "Verlauf"))
                Spacer()
                Text(l.tr(zh: "\(selectedUnitLogs.count) 条", en: "\(selectedUnitLogs.count) logs", de: "\(selectedUnitLogs.count) Einträge"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if chartPoints.isEmpty {
                emptyTrendState
            } else {
                OhanaMinimalTrendChart(
                    points: chartPoints,
                    yDomain: chartYDomain,
                    tint: tint,
                    yReferenceLineCount: 3,
                    yReferenceFormatter: { value, _ in selectedUnit.formattedValue(value, includeUnit: false) }
                )
                .frame(height: 150)

                if chartLogs.count >= 2,
                   let first = chartLogs.first,
                   let last = chartLogs.last {
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

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "参考范围", en: "Reference Range", de: "Referenzbereich"))

            HStack(spacing: 12) {
                Image(systemName: "target").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(tint.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedUnit.normalRangeLabel())
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(l.tr(zh: "历史", en: "History", de: "Historie"))
                Spacer()
                Text(selectedUnit.label)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(tint)
            }

            if selectedUnitLogs.isEmpty {
                emptyHistoryState
            } else {
                ForEach(selectedUnitLogs) { log in
                    historyRow(log)
                }
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

    private func statusBadge(for log: HumanHealthMetricLog) -> some View {
        let status = selectedUnit.status(for: log.value)
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

    private func historyRow(_ log: HumanHealthMetricLog) -> some View {
        let status = selectedUnit.status(for: log.value)
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
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(selectedUnit.formattedValue(log.value, includeUnit: false))
                    .font(OhanaFont.metric(size: 21, .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(selectedUnit.label)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(tint)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                commandQueue.enqueue(
                    .humanHealthMetricDelete(
                        humanID: human.id,
                        metricKey: log.metricKey,
                        logID: log.id
                    )
                ) {
                    HumanCareCommandExecutor(context: modelContext, services: appServices).deleteHealthMetric(
                        log,
                        human: human,
                        note: "humanHealthMetric.delete"
                    )
                }
            } label: {
                Image(systemName: "trash").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "删除记录", en: "Delete log", de: "Eintrag löschen"))
            .accessibilityIdentifier("human-health-metric-delete-action")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }
}
