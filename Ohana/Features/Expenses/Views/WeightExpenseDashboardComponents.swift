//
//  WeightExpenseDashboardComponents.swift
//  Ohana
//
//  Shared V4 dashboards for weight trends and expense records.
//

import SwiftData
import SwiftUI

struct WeightTrendPoint: Identifiable, Hashable {
    let date: Date
    let kilograms: Double
    var isSynthetic: Bool = false

    var id: String {
        let timestamp = Int(date.timeIntervalSinceReferenceDate.rounded())
        let grams = Int((kilograms * 1000).rounded())
        return "\(timestamp)-\(grams)-\(isSynthetic ? "synthetic" : "actual")"
    }
}

enum WeightTrendDataBuilder {
    static func points(
        from entries: [(date: Date, kilograms: Double)],
        rangeStart: Date?,
        rangeEnd: Date = Date()
    ) -> [WeightTrendPoint] {
        let sorted = entries
            .filter { $0.kilograms > 0 && $0.date <= rangeEnd }
            .sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        guard let rangeStart else {
            return sorted.map { WeightTrendPoint(date: $0.date, kilograms: $0.kilograms) }
        }

        var points: [WeightTrendPoint] = []
        if let previous = sorted.last(where: { $0.date < rangeStart }) {
            points.append(WeightTrendPoint(date: rangeStart, kilograms: previous.kilograms, isSynthetic: true))
        }

        points.append(contentsOf: sorted
            .filter { $0.date >= rangeStart && $0.date <= rangeEnd }
            .map { WeightTrendPoint(date: $0.date, kilograms: $0.kilograms) }
        )

        if points.isEmpty, let previous = sorted.last(where: { $0.date < rangeStart }) {
            points = [
                WeightTrendPoint(date: rangeStart, kilograms: previous.kilograms, isSynthetic: true),
                WeightTrendPoint(date: rangeEnd, kilograms: previous.kilograms, isSynthetic: true)
            ]
        } else if let last = points.last, last.date < rangeEnd {
            points.append(WeightTrendPoint(date: rangeEnd, kilograms: last.kilograms, isSynthetic: true))
        }

        return points
    }
}

struct UnifiedWeightTrendChart: View {
    let points: [WeightTrendPoint]
    var xDomain: ClosedRange<Date>?
    var accent: Color = .goPrimary

    @State private var chartProgress: Double = 0

    private var sortedPoints: [WeightTrendPoint] {
        points.sorted { $0.date < $1.date }
    }

    private var actualPoints: [WeightTrendPoint] {
        sortedPoints.filter { !$0.isSynthetic }
    }

    private var yDomain: ClosedRange<Double> {
        let values = sortedPoints.map(\.kilograms)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.18, 0.25)
        return max(0, minValue - padding) ... (maxValue + padding)
    }

    var body: some View {
        OhanaMinimalTrendChart(
            points: sortedPoints.map {
                OhanaMinimalChartPoint(date: $0.date, value: $0.kilograms, id: $0.id)
            },
            xDomain: xDomain,
            yDomain: yDomain,
            tint: accent,
            progress: chartProgress,
            showsLatestPoint: !actualPoints.isEmpty || !sortedPoints.isEmpty,
            yReferenceLineCount: 3,
            yReferenceFormatter: { OhanaChartStyle.weightReferenceLabel(kilograms: $0, domain: $1) }
        )
        .opacity(sortedPoints.isEmpty ? 0.35 : 1)
        .onAppear { playEntrance() }
        .onChange(of: chartSignature) { _, _ in playEntrance() }
    }

    private var chartSignature: String {
        sortedPoints.map(\.id).joined(separator: "|")
            + "|\(xDomain?.lowerBound.timeIntervalSinceReferenceDate ?? 0)"
            + "|\(xDomain?.upperBound.timeIntervalSinceReferenceDate ?? 0)"
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

    var requiresPersonal: Bool {
        kind == .quarter || kind == .all
    }

    func title(_ l: L10n) -> String {
        switch kind {
        case .week: l.tr(zh: "7天", en: "7D", de: "7T")
        case .month: l.tr(zh: "30天", en: "30D", de: "30T")
        case .quarter: l.tr(zh: "90天", en: "90D", de: "90T")
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }

    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch kind {
        case .week:
            calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .month:
            calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        case .quarter:
            calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
        case .all:
            nil
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
        OhanaMinimalBarChart(
            points: buckets.map {
                OhanaMinimalChartPoint(date: $0.date, value: max(0, $0.amount), label: $0.label)
            },
            tint: accent,
            progress: chartProgress,
            showsLabels: buckets.count <= 10,
            maxBarHeight: 124
        )
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
    var isLocked: (Range) -> Bool = { _ in false }
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
                    HStack(spacing: 3) {
                        Text(title(range))
                        if isLocked(range) {
                            Image(systemName: "lock.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 8, weight: .black))
                        }
                    }
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(selected ? Color.arkInk : Color.ohanaSecondaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(
                    isLocked(range) ? "\(title(range)), Ohana Personal" : title(range)
                )
            }
        }
    }
}

func makeExpenseBuckets(from logs: [PetExpenseLog], range: ExpenseDashboardRange) -> [ExpenseTimeBucket] {
    let calendar = Calendar.current
    let now = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.locale = AppLanguage.effectiveLocale

    switch range.kind {
    case .week:
        dateFormatter.setLocalizedDateFormatFromTemplate("E")
        return (0 ..< 7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: now)) else { return nil }
            let amount = logs
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + max(0, $1.amount) }
            return ExpenseTimeBucket(date: date, label: dateFormatter.string(from: date), amount: amount)
        }
    case .month:
        dateFormatter.setLocalizedDateFormatFromTemplate("d")
        return (0 ..< 30).compactMap { offset in
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
        return (0 ..< 12).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset - 11, to: now) else { return nil }
            let amount = logs
                .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + max(0, $1.amount) }
            return ExpenseTimeBucket(date: date, label: dateFormatter.string(from: date), amount: amount)
        }
    }
}
