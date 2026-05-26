import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var feedingOverviewAggregateSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 46, height: 46)
                    .background(mainFoodOverviewTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "全部喂食", en: "All feeding", de: "Alle Fütterungen"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "手动、计划、自动都会计入总览。", en: "Manual, plan, and auto logs are all included.", de: "Manuell, Plan und Auto sind enthalten."))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(feedTaskState.todayMainFoodGrams > 0 ? formattedFoodWeight(feedTaskState.todayMainFoodGrams) : "--")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(mainFoodOverviewTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
    }

    var overviewFoodBreakdown: some View {
        HStack(spacing: 8) {
            modeInfoPill(title: FeedFoodKind.dry.title(l), value: feedMetricsState.todayDryFoodGrams > 0 ? formattedFoodWeight(feedMetricsState.todayDryFoodGrams) : "--", tint: dryFoodTint)
            modeInfoPill(title: FeedFoodKind.wet.title(l), value: feedMetricsState.todayWetFoodGrams > 0 ? formattedFoodWeight(feedMetricsState.todayWetFoodGrams) : "--", tint: wetFoodTint)
            modeInfoPill(title: l.tr(zh: "总计", en: "Total", de: "Gesamt"), value: feedTaskState.todayMainFoodGrams > 0 ? formattedFoodWeight(feedTaskState.todayMainFoodGrams) : "--", tint: mainFoodOverviewTint)
        }
    }

    var feedingOverviewSourceBreakdown: some View {
        HStack(spacing: 8) {
            modeInfoPill(
                title: feedModeShortTitle(.manual),
                value: formattedSourceTotal(.manualMain),
                tint: feedModeTint(.manual)
            )
            modeInfoPill(
                title: feedModeShortTitle(.manualReminder),
                value: formattedSourceTotal(.manualReminder),
                tint: feedModeTint(.manualReminder)
            )
            modeInfoPill(
                title: feedModeShortTitle(.autoFeeder),
                value: formattedSourceTotal(.autoMain),
                tint: feedModeTint(.autoFeeder)
            )
        }
    }

    func overviewRangePicker(tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(FeedOverviewRange.allCases) { range in
                Button {
                    withAnimation(GoMotion.feedback) {
                        draftStore.overviewRange = range
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(range.title(l))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(draftStore.overviewRange == range ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(draftStore.overviewRange == range ? tint : tint.opacity(0.10), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(5)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    func overviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    func overviewLineChart(
        title: String,
        subtitle: String,
        points: [FeedOverviewChartPoint],
        tint: Color,
        emptyText: String,
        showsSurface: Bool = false
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(draftStore.overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                Text(emptyText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                let yDomain = OhanaChartStyle.yDomain(values: points.map(\.value), includeZero: true)
                OhanaMinimalTrendChart(
                    points: points.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                    yDomain: yDomain,
                    tint: tint,
                    progress: overviewChartProgress
                )
                .frame(height: 136)
                .animation(GoMotion.page, value: overviewChartProgress)
            }
        }
        .padding(showsSurface ? 14 : 0)
        return content
            .background {
                if showsSurface {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.clear)
                }
            }
            .modifier(ConditionalFeedGlassSurface(isEnabled: showsSurface, cornerRadius: 20, tint: tint, tintOpacity: 0.04))
    }

    func overviewFrequencyBarChart(
        title: String,
        subtitle: String,
        points: [FeedOverviewChartPoint],
        tint: Color,
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(draftStore.overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                Text(emptyText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 118)
            } else {
                let total = points.reduce(0) { $0 + $1.value }
                let average = total / Double(max(points.count, 1))
                HStack(spacing: 8) {
                    Text(l.tr(
                        zh: "总 \(Int(total)) 次",
                        en: "\(Int(total)) total",
                        de: "\(Int(total)) gesamt"
                    ))
                    Text(l.tr(
                        zh: "均 \(String(format: "%.1f", average))/天",
                        en: "avg \(String(format: "%.1f", average))/day",
                        de: "Ø \(String(format: "%.1f", average))/Tag"
                    ))
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)

                OhanaMinimalBarChart(
                    points: points.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                    tint: tint,
                    progress: overviewChartProgress,
                    showsLabels: draftStore.overviewRange == .days7,
                    maxBarHeight: 86
                )
                .frame(height: draftStore.overviewRange == .days7 ? 116 : 96)
                .opacity(0.40 + overviewChartProgress * 0.60)
                .scaleEffect(x: 1, y: 0.96 + overviewChartProgress * 0.04, anchor: .bottom)
                .animation(GoMotion.page, value: overviewChartProgress)
                .animation(GoMotion.page, value: draftStore.overviewRange)
            }
        }
    }

    func treatFrequencyPulseChart(
        title: String,
        points: [FeedOverviewChartPoint],
        tint: Color,
        emptyText: String
    ) -> some View {
        let total = Int(points.reduce(0) { $0 + $1.value })
        let activeDays = points.filter { $0.value > 0 }.count
        let maxCount = max(1, Int(points.map(\.value).max() ?? 1))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "按次数看节奏，没填克数也算",
                        en: "Frequency rhythm; no-gram logs count",
                        de: "Rhythmus nach Anzahl; ohne Gramm zählt"
                    ))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(draftStore.overviewRange.title(l))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            if points.allSatisfy({ $0.value <= 0 }) {
                emptyInlineState(icon: "birthday.cake", text: emptyText)
                    .frame(minHeight: 118)
            } else {
                Text(l.tr(
                    zh: "\(total) 次 · \(activeDays) 天有零食 · 峰值 \(maxCount)",
                    en: "\(total)x · \(activeDays) snack days · peak \(maxCount)",
                    de: "\(total)x · \(activeDays) Snacktage · Spitze \(maxCount)"
                ))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .contentTransition(.numericText())

                GeometryReader { proxy in
                    let spacing: CGFloat = draftStore.overviewRange == .days7 ? 7 : (draftStore.overviewRange == .days30 ? 4 : 2)
                    let count = max(points.count, 1)
                    let width = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(points) { point in
                            let ratio = CGFloat(point.value / Double(maxCount))
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: max(1, width / 2), style: .continuous)
                                    .fill(point.value > 0 ? tint : Color.ohanaControlFill.opacity(0.70))
                                    .frame(width: width, height: max(point.value > 0 ? 10 : 4, ratio * 84 * overviewChartProgress))
                                    .opacity(point.value > 0 ? 0.95 : 0.42)
                                if draftStore.overviewRange == .days7 {
                                    Text(point.date, format: .dateTime.weekday(.narrow))
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(Calendar.current.isDateInToday(point.date) ? tint : Color.ohanaTertiaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                            .accessibilityLabel(treatFrequencyAccessibilityText(point))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: draftStore.overviewRange == .days7 ? 116 : 96)
                .opacity(0.45 + overviewChartProgress * 0.55)
                .animation(GoMotion.page, value: overviewChartProgress)
                .animation(GoMotion.page, value: draftStore.overviewRange)
                .animation(GoMotion.page, value: draftStore.selectedTreatOverviewKind?.rawValue ?? "all")
            }
        }
        .padding(.vertical, 2)
    }

    func treatFrequencyAccessibilityText(_ point: FeedOverviewChartPoint) -> String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        return l.tr(
            zh: "\(date)，\(Int(point.value)) 次零食",
            en: "\(date), \(Int(point.value)) treat logs",
            de: "\(date), \(Int(point.value)) Snack-Einträge"
        )
    }
}
