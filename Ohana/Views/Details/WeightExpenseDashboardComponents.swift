//
//  WeightExpenseDashboardComponents.swift
//  Ohana
//
//  Shared V4 dashboards for weight trends and expense records.
//

import SwiftUI
import SwiftData
import Charts

struct WeightTrendPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let kilograms: Double
}

struct UnifiedWeightTrendChart: View {
    let points: [WeightTrendPoint]
    var accent: Color = .goPrimary

    @State private var chartProgress: Double = 0

    private var sortedPoints: [WeightTrendPoint] {
        points.sorted { $0.date < $1.date }
    }

    private var yDomain: ClosedRange<Double> {
        let values = sortedPoints.map(\.kilograms)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.18, 0.25)
        return max(0, minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        Chart {
            ForEach(sortedPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Baseline", yDomain.lowerBound),
                    yEnd: .value("Weight", animatedValue(point.kilograms))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.28), accent.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", animatedValue(point.kilograms))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accent)
            }

            if let latest = sortedPoints.last {
                PointMark(
                    x: .value("Date", latest.date),
                    y: .value("Weight", animatedValue(latest.kilograms))
                )
                .symbolSize(70)
                .foregroundStyle(accent)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel()
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                    .foregroundStyle(Color.ohanaDivider)
                AxisValueLabel()
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .chartYScale(domain: yDomain)
        .opacity(sortedPoints.count >= 2 ? 1 : 0.35)
        .onAppear { playEntrance() }
        .onChange(of: points) { _, _ in playEntrance() }
    }

    private func animatedValue(_ value: Double) -> Double {
        yDomain.lowerBound + (value - yDomain.lowerBound) * chartProgress
    }

    private func playEntrance() {
        chartProgress = 0
        withAnimation(GoMotion.page.delay(0.04)) {
            chartProgress = 1
        }
    }
}

struct ExpenseDashboardRange: CaseIterable, Hashable {
    enum Kind: Hashable { case week, month, quarter, all }
    let kind: Kind

    static let week = ExpenseDashboardRange(kind: .week)
    static let month = ExpenseDashboardRange(kind: .month)
    static let quarter = ExpenseDashboardRange(kind: .quarter)
    static let all = ExpenseDashboardRange(kind: .all)
    static let allCases: [ExpenseDashboardRange] = [.week, .month, .quarter, .all]

    func title(_ l: L10n) -> String {
        switch kind {
        case .week: return l.tr(zh: "7天", en: "7D", de: "7T")
        case .month: return l.tr(zh: "30天", en: "30D", de: "30T")
        case .quarter: return l.tr(zh: "90天", en: "90D", de: "90T")
        case .all: return l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }

    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch kind {
        case .week:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .month:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        case .quarter:
            return calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
        case .all:
            return nil
        }
    }
}

struct ExpenseTimeBucket: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let label: String
    let amount: Double
}

struct ExpenseBarDashboardChart: View {
    let buckets: [ExpenseTimeBucket]
    var accent: Color = .goPrimary

    @State private var chartProgress: Double = 0

    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Date", bucket.label),
                    y: .value("Amount", max(0, bucket.amount) * chartProgress)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .foregroundStyle(accent.gradient)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                    .foregroundStyle(Color.ohanaDivider)
                AxisValueLabel()
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .onAppear { playEntrance() }
        .onChange(of: buckets) { _, _ in playEntrance() }
    }

    private func playEntrance() {
        chartProgress = 0
        withAnimation(GoMotion.page.delay(0.04)) {
            chartProgress = 1
        }
    }
}

struct DashboardRangePicker<Range: Hashable>: View {
    let ranges: [Range]
    @Binding var selection: Range
    let title: (Range) -> String

    var body: some View {
        HStack(spacing: 7) {
            ForEach(ranges, id: \.self) { range in
                let selected = range == selection
                Button {
                    withAnimation(GoMotion.feedback) {
                        selection = range
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(title(range))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(selected ? Color.arkInk : Color.ohanaSecondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

struct PetWeightDashboardContent: View {
    let pet: Pet
    var showsCloseButton = true
    var onClose: () -> Void
    var onAdd: () -> Void
    var onRemove: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedRange: WeightRange = .days30

    enum WeightRange: Hashable, CaseIterable {
        case days7, days30, days90, all

        func title(_ l: L10n) -> String {
            switch self {
            case .days7: return l.tr(zh: "7天", en: "7D", de: "7T")
            case .days30: return l.tr(zh: "30天", en: "30D", de: "30T")
            case .days90: return l.tr(zh: "90天", en: "90D", de: "90T")
            case .all: return l.tr(zh: "全部", en: "All", de: "Alle")
            }
        }

        func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
            switch self {
            case .days7: return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
            case .days30: return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
            case .days90: return calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
            case .all: return nil
            }
        }
    }

    private var l: L10n { L10n(appLanguage) }
    private var logs: [PetWeightLog] { pet.weightLogs.sorted { $0.date > $1.date } }
    private var filteredLogs: [PetWeightLog] {
        guard let start = selectedRange.startDate() else { return logs }
        return logs.filter { $0.date >= start }
    }
    private var trendPoints: [WeightTrendPoint] {
        filteredLogs
            .sorted { $0.date < $1.date }
            .map { WeightTrendPoint(date: $0.date, kilograms: $0.weightInKg) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    metrics
                    chartBlock
                    historyBlock
                    if let onRemove {
                        removeButton(onRemove)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }

            addButton
                .padding(.trailing, 18)
                .padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageData: pet.avatarImageData,
                emoji: pet.avatarEmoji,
                fallback: pet.speciesEmoji,
                tint: Color(hex: pet.safeThemeColorHex)
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "体重趋势", en: "Weight Trend", de: "Gewicht"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
        }
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(
                id: "latest",
                title: l.tr(zh: "当前", en: "Current", de: "Aktuell"),
                value: latestWeightText
            ),
            FeatureHubMetric(
                id: "change",
                title: l.tr(zh: "变化", en: "Change", de: "Änderung"),
                value: weightDeltaText
            ),
            FeatureHubMetric(
                id: "count",
                title: l.tr(zh: "记录", en: "Logs", de: "Einträge"),
                value: "\(logs.count)"
            )
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "趋势", en: "Trend", de: "Trend"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: WeightRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }

            if trendPoints.count >= 2 {
                UnifiedWeightTrendChart(points: trendPoints, accent: .goPrimary)
                    .frame(height: 190)
            } else {
                emptyState(
                    icon: "chart.xyaxis.line",
                    text: l.tr(zh: "记录 2 次后显示趋势", en: "Add 2 logs to show a trend", de: "2 Einträge zeigen einen Trend")
                )
            }
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if logs.isEmpty {
                emptyState(
                    icon: "scalemass.fill",
                    text: l.tr(zh: "还没有体重记录", en: "No weight logs yet", de: "Noch keine Gewichtseinträge")
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(logs.prefix(20)) { log in
                        weightRow(log)
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加体重", en: "Add weight", de: "Gewicht hinzufügen"))
    }

    private var latestWeightText: String {
        guard let latest = logs.first else { return "—" }
        return AppMeasurementSystem.formatWeightKilograms(latest.weightInKg)
    }

    private var weightDeltaText: String {
        guard let latest = logs.first, let previous = logs.dropFirst().first else { return "—" }
        let delta = latest.weightInKg - previous.weightInKg
        return formatWeightDelta(delta)
    }

    private func weightRow(_ log: PetWeightLog) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(log.date.formatted(date: .omitted, time: .shortened))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(AppMeasurementSystem.formatWeightKilograms(log.weightInKg))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formatWeightDelta(_ kilograms: Double) -> String {
        let converted = AppMeasurementSystem.code == "imperial" ? kilograms * 2.2046226218 : kilograms
        let unit = AppMeasurementSystem.code == "imperial" ? "lb" : "kg"
        return String(format: "%+.1f %@", converted, unit)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func removeButton(_ onRemove: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            onRemove()
            onClose()
        } label: {
            Text(l.tr(zh: "移除此快捷入口", en: "Remove from quick actions", de: "Aus Schnellaktionen entfernen"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct HumanWeightDashboardContent: View {
    let human: Human
    var onClose: () -> Void
    var onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedRange: PetWeightDashboardContent.WeightRange = .days30

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var logs: [HumanWeightLog] { human.weightLogs.sorted { $0.date > $1.date } }
    private var filteredLogs: [HumanWeightLog] {
        guard let start = selectedRange.startDate() else { return logs }
        return logs.filter { $0.date >= start }
    }
    private var trendPoints: [WeightTrendPoint] {
        filteredLogs.sorted { $0.date < $1.date }.map { WeightTrendPoint(date: $0.date, kilograms: $0.weight) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OhanaAppBackground().ignoresSafeArea()

            if isPrivacyLocked {
                HumanModulePrivacyLockedView(
                    title: l.tr(zh: "体重记录仅本人可见", en: "Weight is private", de: "Gewicht ist privat"),
                    message: l.tr(zh: "请切换到本人账户后查看。", en: "Switch to this account to view it.", de: "Wechsle zu diesem Konto, um es zu sehen.")
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        HumanPrivateDataNotice(human: human, field: .weight)
                        metrics
                        chartBlock
                        historyBlock
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }

                addButton
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "体重趋势", en: "Weight Trend", de: "Gewicht"),
            subtitle: human.name,
            onClose: onClose
        ) {
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .weight)
            }
        }
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "latest", title: l.tr(zh: "当前", en: "Current", de: "Aktuell"), value: latestWeightText),
            FeatureHubMetric(id: "change", title: l.tr(zh: "变化", en: "Change", de: "Änderung"), value: deltaText),
            FeatureHubMetric(id: "count", title: l.tr(zh: "记录", en: "Logs", de: "Einträge"), value: "\(logs.count)")
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "趋势", en: "Trend", de: "Trend"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: PetWeightDashboardContent.WeightRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }
            if trendPoints.count >= 2 {
                UnifiedWeightTrendChart(points: trendPoints, accent: .goPrimary)
                    .frame(height: 190)
            } else {
                emptyState(icon: "chart.xyaxis.line", text: l.tr(zh: "记录 2 次后显示趋势", en: "Add 2 logs to show a trend", de: "2 Einträge zeigen einen Trend"))
            }
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if logs.isEmpty {
                emptyState(icon: "scalemass.fill", text: l.tr(zh: "还没有体重记录", en: "No weight logs yet", de: "Noch keine Gewichtseinträge"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(logs.prefix(20)) { log in
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(log.date.formatted(date: .omitted, time: .shortened))
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            Spacer()
                            Text(String(format: "%.1f kg", log.weight))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Button {
                                modelContext.delete(log)
                                modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加体重", en: "Add weight", de: "Gewicht hinzufügen"))
    }

    private var latestWeightText: String {
        guard let latest = logs.first else { return "—" }
        return String(format: "%.1f kg", latest.weight)
    }

    private var deltaText: String {
        guard let latest = logs.first, let previous = logs.dropFirst().first else { return "—" }
        return String(format: "%+.1f kg", latest.weight - previous.weight)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PetExpenseDashboardContent: View {
    let pet: Pet
    var showsCloseButton = true
    var onClose: () -> Void
    var onAdd: () -> Void
    var onRemove: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    @State private var selectedRange: ExpenseDashboardRange = .month
    @State private var selectedCategory: ExpenseCategory?

    private var l: L10n { L10n(appLanguage) }
    private var baseLogs: [PetExpenseLog] { pet.expenseLogs.sorted { $0.date > $1.date } }
    private var filteredLogs: [PetExpenseLog] {
        baseLogs.filter { log in
            let rangeOK = selectedRange.startDate().map { log.date >= $0 } ?? true
            let categoryOK = selectedCategory.map { log.expenseCategory == $0 } ?? true
            return rangeOK && categoryOK
        }
    }
    private var positiveLogs: [PetExpenseLog] { filteredLogs.filter { $0.amount > 0 } }
    private var total: Double { positiveLogs.reduce(0) { $0 + $1.amount } }
    private var categoryBreakdown: [(ExpenseCategory, Double)] {
        var dict: [ExpenseCategory: Double] = [:]
        for log in positiveLogs { dict[log.expenseCategory, default: 0] += log.amount }
        return dict.sorted { $0.value > $1.value }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OhanaAppBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    metrics
                    chartBlock
                    categoryStrip
                    historyBlock
                    if let onRemove {
                        removeButton(onRemove)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            addButton
                .padding(.trailing, 18)
                .padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(imageData: pet.avatarImageData, emoji: pet.avatarEmoji, fallback: pet.speciesEmoji, tint: Color(hex: pet.safeThemeColorHex))
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "花费记录", en: "Expenses", de: "Kosten"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(pet.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "range", title: l.tr(zh: "本期", en: "Period", de: "Zeitraum"), value: AppCurrency.format(total, fractionDigits: 0)),
            FeatureHubMetric(id: "count", title: l.tr(zh: "记录", en: "Logs", de: "Einträge"), value: "\(filteredLogs.count)"),
            FeatureHubMetric(id: "top", title: l.tr(zh: "最多", en: "Top", de: "Top"), value: categoryBreakdown.first.map { l.expenseCategoryTitle($0.0) } ?? "—")
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "时间分布", en: "Timeline", de: "Zeitverlauf"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: ExpenseDashboardRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }
            if chartBuckets.contains(where: { $0.amount > 0 }) {
                ExpenseBarDashboardChart(buckets: chartBuckets, accent: .goPrimary)
                    .frame(height: 180)
            } else {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "记录花费后显示趋势", en: "Add an expense to show bars", de: "Ausgaben zeigen Balken"))
            }
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "square.grid.2x2.fill")
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    categoryChip(category, title: l.expenseCategoryTitle(category), icon: category.systemIconName)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if filteredLogs.isEmpty {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "还没有花费记录", en: "No expenses yet", de: "Noch keine Kosten"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredLogs.prefix(30)) { log in expenseRow(log) }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加花费", en: "Add expense", de: "Kosten hinzufügen"))
    }

    private var chartBuckets: [ExpenseTimeBucket] {
        makeExpenseBuckets(from: positiveLogs, range: selectedRange)
    }

    private func categoryChip(_ category: ExpenseCategory?, title: String, icon: String) -> some View {
        let selected = selectedCategory == category
        return Button {
            withAnimation(GoMotion.feedback) { selectedCategory = category }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.caption(.black))
            }
            .foregroundStyle(selected ? Color.arkInk : Color.ohanaSecondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func expenseRow(_ log: PetExpenseLog) -> some View {
        HStack(spacing: 12) {
            Image(systemName: log.expenseCategory.systemIconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(log.note.isEmpty ? l.expenseCategoryTitle(log.expenseCategory) : log.note)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(rowSubtitle(log))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(AppCurrency.format(log.amount, fractionDigits: 2))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(log.amount >= 0 ? Color.ohanaPrimaryText : Color.goTeal)
            Button {
                modelContext.delete(log)
                modelContext.safeSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func rowSubtitle(_ log: PetExpenseLog) -> String {
        let payer = log.executorId.flatMap { id in allHumans.first { $0.id.uuidString == id }?.name }
        let dateText = log.date.formatted(date: .abbreviated, time: .omitted)
        guard let payer else { return dateText }
        return "\(dateText) · \(payer)"
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func removeButton(_ onRemove: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            onRemove()
            onClose()
        } label: {
            Text(l.tr(zh: "移除此快捷入口", en: "Remove from quick actions", de: "Aus Schnellaktionen entfernen"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct HumanExpenseDashboardContent: View {
    let human: Human
    let allExpenses: [PetExpenseLog]
    var onClose: () -> Void
    var onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedRange: ExpenseDashboardRange = .month
    @State private var selectedCategory: ExpenseCategory?

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { PrivacyService.isLocked(.expense, for: human, viewedBy: activeHumanId) }
    private var baseLogs: [PetExpenseLog] { allExpenses.filter { $0.executorId == human.id.uuidString }.sorted { $0.date > $1.date } }
    private var filteredLogs: [PetExpenseLog] {
        baseLogs.filter { log in
            let rangeOK = selectedRange.startDate().map { log.date >= $0 } ?? true
            let categoryOK = selectedCategory.map { log.expenseCategory == $0 } ?? true
            return rangeOK && categoryOK
        }
    }
    private var positiveLogs: [PetExpenseLog] { filteredLogs.filter { $0.amount > 0 } }
    private var total: Double { positiveLogs.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OhanaAppBackground().ignoresSafeArea()
            if isPrivacyLocked {
                HumanModulePrivacyLockedView(
                    title: PrivacyService.lockedMessage(for: .expense),
                    message: l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this account to view it.", de: "Wechsle zu diesem Konto, um es zu sehen.")
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        HumanPrivateDataNotice(human: human, field: .expense)
                        metrics
                        chartBlock
                        categoryStrip
                        historyBlock
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }
                addButton
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "花费记录", en: "Expenses", de: "Kosten"),
            subtitle: human.name,
            onClose: onClose
        ) {
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .expense)
            }
        }
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "range", title: l.tr(zh: "本期", en: "Period", de: "Zeitraum"), value: AppCurrency.format(total, fractionDigits: 0)),
            FeatureHubMetric(id: "count", title: l.tr(zh: "记录", en: "Logs", de: "Einträge"), value: "\(filteredLogs.count)"),
            FeatureHubMetric(id: "total", title: l.tr(zh: "累计", en: "Total", de: "Gesamt"), value: AppCurrency.format(baseLogs.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }, fractionDigits: 0))
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "时间分布", en: "Timeline", de: "Zeitverlauf"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: ExpenseDashboardRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }
            if chartBuckets.contains(where: { $0.amount > 0 }) {
                ExpenseBarDashboardChart(buckets: chartBuckets, accent: .goPrimary)
                    .frame(height: 180)
            } else {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "记录花费后显示趋势", en: "Add an expense to show bars", de: "Ausgaben zeigen Balken"))
            }
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "square.grid.2x2.fill")
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    categoryChip(category, title: l.expenseCategoryTitle(category), icon: category.systemIconName)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if filteredLogs.isEmpty {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "还没有花费记录", en: "No expenses yet", de: "Noch keine Kosten"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredLogs.prefix(30)) { log in
                        HStack(spacing: 12) {
                            Image(systemName: log.expenseCategory.systemIconName)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.note.isEmpty ? l.expenseCategoryTitle(log.expenseCategory) : log.note)
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)
                                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            Spacer()
                            Text(AppCurrency.format(log.amount, fractionDigits: 2))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(log.amount >= 0 ? Color.ohanaPrimaryText : Color.goTeal)
                            Button {
                                modelContext.delete(log)
                                modelContext.safeSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加花费", en: "Add expense", de: "Kosten hinzufügen"))
    }

    private var chartBuckets: [ExpenseTimeBucket] {
        makeExpenseBuckets(from: positiveLogs, range: selectedRange)
    }

    private func categoryChip(_ category: ExpenseCategory?, title: String, icon: String) -> some View {
        let selected = selectedCategory == category
        return Button {
            withAnimation(GoMotion.feedback) { selectedCategory = category }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.caption(.black))
            }
            .foregroundStyle(selected ? Color.arkInk : Color.ohanaSecondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private func makeExpenseBuckets(from logs: [PetExpenseLog], range: ExpenseDashboardRange) -> [ExpenseTimeBucket] {
    let calendar = Calendar.current
    let now = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.locale = AppLanguage.effectiveLocale

    switch range.kind {
    case .week:
        dateFormatter.setLocalizedDateFormatFromTemplate("E")
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: now)) else { return nil }
            let amount = logs
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + max(0, $1.amount) }
            return ExpenseTimeBucket(date: date, label: dateFormatter.string(from: date), amount: amount)
        }
    case .month:
        dateFormatter.setLocalizedDateFormatFromTemplate("d")
        return (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 29, to: calendar.startOfDay(for: now)) else { return nil }
            let amount = logs
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + max(0, $1.amount) }
            return ExpenseTimeBucket(date: date, label: dateFormatter.string(from: date), amount: amount)
        }
    case .quarter:
        dateFormatter.setLocalizedDateFormatFromTemplate("M/d")
        return stride(from: 0, to: 90, by: 7).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset - 89, to: calendar.startOfDay(for: now)),
                  let end = calendar.date(byAdding: .day, value: 6, to: start)
            else { return nil }
            let amount = logs
                .filter { $0.date >= start && $0.date <= end }
                .reduce(0) { $0 + max(0, $1.amount) }
            return ExpenseTimeBucket(date: start, label: dateFormatter.string(from: start), amount: amount)
        }
    case .all:
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM")
        return (0..<12).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset - 11, to: now) else { return nil }
            let amount = logs
                .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + max(0, $1.amount) }
            return ExpenseTimeBucket(date: date, label: dateFormatter.string(from: date), amount: amount)
        }
    }
}
