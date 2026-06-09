//
//  OhanaChartStyle.swift
//  Ohana
//
//  Shared chart rules for V4: calm area trends, quiet axes, and no over-shooting curves.
//

import SwiftUI

enum OhanaChartStyle {
    static let trendLineStyle = StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
    static let quietReferenceLineStyle = StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [3, 7])

    static func areaGradient(for tint: Color, topOpacity: Double = 0.24, bottomOpacity: Double = 0.02) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(topOpacity), tint.opacity(bottomOpacity)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func yDomain(
        values: [Double],
        includeZero: Bool,
        paddingRatio: Double = 0.14,
        minimumSpan: Double = 1
    ) -> ClosedRange<Double> {
        let cleanValues = values.filter(\.isFinite)
        guard let minValue = cleanValues.min(), let maxValue = cleanValues.max() else {
            return 0...1
        }

        var lower = includeZero ? min(0, minValue) : minValue
        var upper = includeZero ? max(1, maxValue) : maxValue
        let span = max(upper - lower, minimumSpan)

        if includeZero {
            upper += span * paddingRatio
            lower = min(0, lower)
        } else {
            lower -= span * paddingRatio
            upper += span * paddingRatio
        }

        if upper <= lower {
            upper = lower + minimumSpan
        }
        return lower...upper
    }

    static func weightReferenceLabel(kilograms: Double, domain: ClosedRange<Double>) -> String {
        let convertedSpan = AppMeasurementSystem.code == "imperial"
            ? (domain.upperBound - domain.lowerBound) * 2.2046226218
            : domain.upperBound - domain.lowerBound
        let fractionDigits = convertedSpan < 6 ? 1 : 0
        return AppMeasurementSystem.formatWeightKilograms(kilograms, fractionDigits: fractionDigits)
    }

    static func softenedLinePath(points: [CGPoint]) -> Path {
        let points = normalizedTrendPoints(points)
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            appendMonotoneSegments(to: &path, points: points)
        }
    }

    static func softenedAreaPath(points: [CGPoint], baselineY: CGFloat) -> Path {
        let points = normalizedTrendPoints(points)
        return Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: baselineY))
            path.addLine(to: first)
            appendMonotoneSegments(to: &path, points: points)
            path.addLine(to: CGPoint(x: last.x, y: baselineY))
            path.closeSubpath()
        }
    }

    private static func normalizedTrendPoints(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points
            .filter { $0.x.isFinite && $0.y.isFinite }
            .sorted { $0.x < $1.x }
        guard !sorted.isEmpty else { return [] }

        let duplicateThreshold: CGFloat = 0.5
        var result: [CGPoint] = []
        var group: [CGPoint] = []

        func averaged(_ values: [CGPoint]) -> CGPoint? {
            guard !values.isEmpty else { return nil }
            let x = values.map(\.x).reduce(0, +) / CGFloat(values.count)
            let y = values.map(\.y).reduce(0, +) / CGFloat(values.count)
            return CGPoint(x: x, y: y)
        }

        for point in sorted {
            if let anchor = group.first, abs(point.x - anchor.x) > duplicateThreshold {
                if let averagedPoint = averaged(group) {
                    result.append(averagedPoint)
                }
                group = [point]
            } else {
                group.append(point)
            }
        }
        if let averagedPoint = averaged(group) {
            result.append(averagedPoint)
        }

        return result
    }

    private static func appendMonotoneSegments(to path: inout Path, points: [CGPoint]) {
        guard points.count > 1 else { return }

        guard points.count > 2 else {
            path.addLine(to: points[1])
            return
        }

        let count = points.count
        var slopes = Array(repeating: CGFloat.zero, count: count - 1)
        for index in 0..<(count - 1) {
            let dx = max(points[index + 1].x - points[index].x, 0.0001)
            slopes[index] = (points[index + 1].y - points[index].y) / dx
        }

        var tangents = Array(repeating: CGFloat.zero, count: count)
        tangents[0] = slopes[0]
        tangents[count - 1] = slopes[count - 2]

        if count > 2 {
            for index in 1..<(count - 1) {
                let previous = slopes[index - 1]
                let next = slopes[index]
                if previous == 0 || next == 0 || previous.sign != next.sign {
                    tangents[index] = 0
                } else {
                    let h0 = max(points[index].x - points[index - 1].x, 0.0001)
                    let h1 = max(points[index + 1].x - points[index].x, 0.0001)
                    let w1 = 2 * h1 + h0
                    let w2 = h1 + 2 * h0
                    tangents[index] = (w1 + w2) / (w1 / previous + w2 / next)
                }
            }
        }

        for index in 0..<(count - 1) {
            let p1 = points[index]
            let p2 = points[index + 1]
            let dx = p2.x - p1.x
            guard dx > 0.0001 else {
                path.addLine(to: p2)
                continue
            }
            let segmentMinY = min(p1.y, p2.y)
            let segmentMaxY = max(p1.y, p2.y)

            let c1 = CGPoint(
                x: p1.x + dx / 3,
                y: clamp(p1.y + tangents[index] * dx / 3, segmentMinY, segmentMaxY)
            )
            let c2 = CGPoint(
                x: p2.x - dx / 3,
                y: clamp(p2.y - tangents[index + 1] * dx / 3, segmentMinY, segmentMaxY)
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

struct OhanaMinimalChartPoint: Identifiable, Hashable {
    let id: String
    let date: Date
    let value: Double
    var label: String?

    init(date: Date, value: Double, label: String? = nil, id: String? = nil) {
        let timestamp = Int(date.timeIntervalSinceReferenceDate.rounded())
        let scaledValue = Int((value * 1000).rounded())
        self.id = id ?? "\(timestamp)-\(scaledValue)-\(label ?? "")"
        self.date = date
        self.value = value
        self.label = label
    }
}

struct OhanaMinimalLineSeries: Identifiable {
    let id: String
    let points: [OhanaMinimalChartPoint]
    let tint: Color

    init(id: String, points: [OhanaMinimalChartPoint], tint: Color) {
        self.id = id
        self.points = points
        self.tint = tint
    }
}

struct OhanaMinimalTrendChart: View {
    let points: [OhanaMinimalChartPoint]
    var xDomain: ClosedRange<Date>?
    var yDomain: ClosedRange<Double>?
    var tint: Color = .goPrimary
    var progress: Double = 1
    var showsLatestPoint: Bool = true
    var yReferenceLineCount: Int = 0
    var yReferenceFormatter: ((Double, ClosedRange<Double>) -> String)? = nil

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var entranceProgress: Double = 0

    private var sortedPoints: [OhanaMinimalChartPoint] {
        points.sorted { $0.date < $1.date }
    }

    private var resolvedYDomain: ClosedRange<Double> {
        yDomain ?? OhanaChartStyle.yDomain(values: sortedPoints.map(\.value), includeZero: false)
    }

    private var animationKey: String {
        sortedPoints.map(\.id).joined(separator: "|")
    }

    private var effectiveProgress: Double {
        max(0, min(1, progress)) * max(0, min(1, entranceProgress))
    }

    private var showsYReferenceLines: Bool {
        yReferenceLineCount > 0 && yReferenceFormatter != nil
    }

    private var plotLeadingInset: CGFloat {
        showsYReferenceLines ? 46 : 0
    }

    private var yReferenceValues: [Double] {
        guard showsYReferenceLines else { return [] }
        let count = max(2, yReferenceLineCount)
        let domain = resolvedYDomain
        let span = domain.upperBound - domain.lowerBound
        guard span.isFinite, span > 0 else { return [] }
        return (0..<count).map { index in
            domain.lowerBound + span * Double(index) / Double(count - 1)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let chartPoints = resolvedPoints(in: proxy.size)
            ZStack {
                if showsYReferenceLines {
                    referenceLayer(in: proxy.size)
                }

                if chartPoints.count >= 2 {
                    OhanaChartStyle.softenedAreaPath(points: chartPoints, baselineY: proxy.size.height)
                        .fill(OhanaChartStyle.areaGradient(for: tint, topOpacity: 0.20, bottomOpacity: 0.01))
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: max(1, proxy.size.width * effectiveProgress))
                        }
                    OhanaChartStyle.softenedLinePath(points: chartPoints)
                        .trim(from: 0, to: effectiveProgress)
                        .stroke(tint, style: OhanaChartStyle.trendLineStyle)
                } else if let point = chartPoints.first {
                    Circle()
                        .fill(tint)
                        .frame(width: 9, height: 9) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .position(point)
                        .scaleEffect(0.72 + 0.28 * effectiveProgress)
                        .opacity(effectiveProgress)
                }

                if showsLatestPoint, let latest = chartPoints.last {
                    Circle()
                        .fill(tint)
                        .frame(width: 9, height: 9) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .overlay(Circle().stroke(Color.ohanaCardSurface, lineWidth: 2))
                        .position(latest)
                        .scaleEffect(0.72 + 0.28 * effectiveProgress)
                        .opacity(max(0, min(1, (effectiveProgress - 0.82) / 0.18)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(sortedPoints.isEmpty ? 0.35 : 1)
        .onAppear(perform: playEntrance)
        .onChange(of: animationKey) { _, _ in playEntrance() }
        .onChange(of: workloadPolicy.isReduceMotionEnabled) { _, _ in playEntrance() }
        .onChange(of: workloadPolicy.isLowPowerModeEnabled) { _, _ in playEntrance() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Minimal trend chart")
    }

    @ViewBuilder
    private func referenceLayer(in size: CGSize) -> some View {
        ForEach(yReferenceValues.indices, id: \.self) { index in
            let value = yReferenceValues[index]
            let lineY = yPosition(for: value, in: size)
            Path { path in
                path.move(to: CGPoint(x: plotLeadingInset, y: lineY))
                path.addLine(to: CGPoint(x: size.width, y: lineY))
            }
            .stroke(Color.ohanaSecondaryText.opacity(0.18), style: OhanaChartStyle.quietReferenceLineStyle)

            if let formatter = yReferenceFormatter {
                Text(formatter(value, resolvedYDomain))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: plotLeadingInset - 6, alignment: .leading)
                    .position(x: max(18, plotLeadingInset / 2 - 1), y: min(max(lineY, 8), size.height - 8))
            }
        }
    }

    private func resolvedPoints(in size: CGSize) -> [CGPoint] {
        let sorted = sortedPoints
        guard !sorted.isEmpty, size.width > 0, size.height > 0 else { return [] }
        let dateDomain = resolvedDateDomain(from: sorted)
        let start = dateDomain.lowerBound.timeIntervalSinceReferenceDate
        let span = max(dateDomain.upperBound.timeIntervalSinceReferenceDate - start, 1)
        let y = resolvedYDomain
        let ySpan = max(y.upperBound - y.lowerBound, 0.0001)
        let plotWidth = max(size.width - plotLeadingInset, 1)

        return sorted.map { point in
            let xRatio = (point.date.timeIntervalSinceReferenceDate - start) / span
            let animatedValue = y.lowerBound + (point.value - y.lowerBound) * effectiveProgress
            let yRatio = (animatedValue - y.lowerBound) / ySpan
            return CGPoint(
                x: plotLeadingInset + min(max(CGFloat(xRatio) * plotWidth, 0), plotWidth),
                y: min(max(size.height - CGFloat(yRatio) * size.height, 0), size.height)
            )
        }
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        let domain = resolvedYDomain
        let span = max(domain.upperBound - domain.lowerBound, 0.0001)
        let ratio = (value - domain.lowerBound) / span
        return min(max(size.height - CGFloat(ratio) * size.height, 0), size.height)
    }

    private func resolvedDateDomain(from points: [OhanaMinimalChartPoint]) -> ClosedRange<Date> {
        if let xDomain { return xDomain }
        guard let first = points.first?.date, let last = points.last?.date else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }
        if first == last {
            return first.addingTimeInterval(-43_200)...last.addingTimeInterval(43_200)
        }
        return first...last
    }

    private func playEntrance() {
        guard workloadPolicy.shouldRunInteractionAnimation(isVisible: true) else {
            entranceProgress = 1
            return
        }
        entranceProgress = 0
        withAnimation(GoMotion.page) {
            entranceProgress = 1
        }
    }
}

struct OhanaMinimalMultiTrendChart: View {
    let series: [OhanaMinimalLineSeries]
    var xDomain: ClosedRange<Date>?
    var yDomain: ClosedRange<Double>?
    var progress: Double = 1
    var showsLatestPoint: Bool = true
    var drawProgress: Double = 1

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var entranceProgress: Double = 0

    private var allPoints: [OhanaMinimalChartPoint] {
        series.flatMap(\.points).sorted { $0.date < $1.date }
    }

    private var resolvedYDomain: ClosedRange<Double> {
        yDomain ?? OhanaChartStyle.yDomain(values: allPoints.map(\.value), includeZero: false)
    }

    private var animationKey: String {
        series
            .map { "\($0.id):\($0.points.map(\.id).joined(separator: ","))" }
            .joined(separator: "|")
    }

    private var effectiveProgress: Double {
        max(0, min(1, progress)) * max(0, min(1, entranceProgress))
    }

    private var effectiveDrawProgress: Double {
        max(0, min(1, drawProgress)) * max(0, min(1, entranceProgress))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(series) { item in
                    let chartPoints = resolvedPoints(item.points, in: proxy.size)
                    if chartPoints.count >= 2 {
                        OhanaChartStyle.softenedLinePath(points: chartPoints)
                            .trim(from: 0, to: effectiveDrawProgress)
                            .stroke(item.tint, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    }
                    if showsLatestPoint, effectiveDrawProgress > 0.82, let latest = chartPoints.last {
                        Circle()
                            .fill(item.tint)
                            .frame(width: 8, height: 8) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            .overlay(Circle().stroke(Color.ohanaCardSurface, lineWidth: 2))
                            .position(latest)
                            .scaleEffect(max(0.72, min(1, effectiveDrawProgress)))
                            .opacity(max(0, min(1, (effectiveDrawProgress - 0.82) / 0.18)))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(allPoints.isEmpty ? 0.35 : 1)
        .onAppear(perform: playEntrance)
        .onChange(of: animationKey) { _, _ in playEntrance() }
        .onChange(of: workloadPolicy.isReduceMotionEnabled) { _, _ in playEntrance() }
        .onChange(of: workloadPolicy.isLowPowerModeEnabled) { _, _ in playEntrance() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Minimal multi-series trend chart")
    }

    private func resolvedPoints(_ points: [OhanaMinimalChartPoint], in size: CGSize) -> [CGPoint] {
        let sorted = points.sorted { $0.date < $1.date }
        guard !sorted.isEmpty, size.width > 0, size.height > 0 else { return [] }
        let dateDomain = resolvedDateDomain()
        let start = dateDomain.lowerBound.timeIntervalSinceReferenceDate
        let span = max(dateDomain.upperBound.timeIntervalSinceReferenceDate - start, 1)
        let y = resolvedYDomain
        let ySpan = max(y.upperBound - y.lowerBound, 0.0001)

        return sorted.map { point in
            let xRatio = (point.date.timeIntervalSinceReferenceDate - start) / span
            let animatedValue = y.lowerBound + (point.value - y.lowerBound) * effectiveProgress
            let yRatio = (animatedValue - y.lowerBound) / ySpan
            return CGPoint(
                x: min(max(CGFloat(xRatio) * size.width, 0), size.width),
                y: min(max(size.height - CGFloat(yRatio) * size.height, 0), size.height)
            )
        }
    }

    private func resolvedDateDomain() -> ClosedRange<Date> {
        if let xDomain { return xDomain }
        guard let first = allPoints.first?.date, let last = allPoints.last?.date else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }
        if first == last {
            return first.addingTimeInterval(-43_200)...last.addingTimeInterval(43_200)
        }
        return first...last
    }

    private func playEntrance() {
        guard workloadPolicy.shouldRunInteractionAnimation(isVisible: true) else {
            entranceProgress = 1
            return
        }
        entranceProgress = 0
        withAnimation(GoMotion.page) {
            entranceProgress = 1
        }
    }
}

struct OhanaMinimalBarChart: View {
    let points: [OhanaMinimalChartPoint]
    var tint: Color = .goPrimary
    var progress: Double = 1
    var showsLabels: Bool = true
    var maxBarHeight: CGFloat = 90
    var emptyBarColor: Color = Color.ohanaControlFill.opacity(0.70)

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var entranceProgress: Double = 0

    private var maxValue: Double {
        max(1, points.map(\.value).max() ?? 1)
    }

    private var animationKey: String {
        points.map(\.id).joined(separator: "|")
    }

    private var effectiveProgress: Double {
        max(0, min(1, progress)) * max(0, min(1, entranceProgress))
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = points.count <= 10 ? 7 : (points.count <= 35 ? 4 : 2)
            let count = max(points.count, 1)
            let width = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(points) { point in
                    let visibleValue = max(0, point.value) * effectiveProgress
                    let ratio = CGFloat(visibleValue / maxValue)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: max(1, width / 2), style: .continuous)
                            .fill(point.value > 0 ? tint : emptyBarColor)
                            .frame(width: width, height: max(point.value > 0 ? 10 : 4, ratio * maxBarHeight))
                            .opacity(point.value > 0 ? 0.95 : 0.42)
                            .scaleEffect(x: 1, y: 0.98 + 0.02 * effectiveProgress, anchor: .bottom)
                        if showsLabels, points.count <= 10 {
                            Text(point.label ?? point.date.formatted(.dateTime.weekday(.narrow)))
                                .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(Calendar.current.isDateInToday(point.date) ? tint : Color.ohanaTertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .accessibilityLabel("\(point.label ?? point.date.formatted(date: .abbreviated, time: .omitted)): \(point.value)")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement(children: .contain)
        .onAppear(perform: playEntrance)
        .onChange(of: animationKey) { _, _ in playEntrance() }
        .onChange(of: workloadPolicy.isReduceMotionEnabled) { _, _ in playEntrance() }
        .onChange(of: workloadPolicy.isLowPowerModeEnabled) { _, _ in playEntrance() }
    }

    private func playEntrance() {
        guard workloadPolicy.shouldRunInteractionAnimation(isVisible: true) else {
            entranceProgress = 1
            return
        }
        entranceProgress = 0
        withAnimation(GoMotion.page) {
            entranceProgress = 1
        }
    }
}
