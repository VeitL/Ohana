import SwiftUI

struct HumanWorkoutHistoryOverviewCard: View {
    @Binding var selectedPeriod: HumanWorkoutHistoryPeriod
    let trendSnapshot: HumanWorkoutTrendSnapshot
    let historyCoverage: HumanWorkoutHistoryCoverage

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HumanWorkoutSectionHeading(
                icon: "chart.xyaxis.line",
                title: l.tr(zh: "运动趋势与历史", en: "Trends & History", de: "Trends & Verlauf"),
                subtitle: l.tr(
                    zh: "区分 Ohana 本地、遛狗与 Apple Health 实时来源。",
                    en: "Separates Ohana local, dog-walk, and live Apple Health sources.",
                    de: "Trennt lokale Ohana-, Hundegang- und Live-Apple-Health-Quellen."
                )
            )

            Picker(
                l.tr(zh: "历史区间", en: "History period", de: "Verlaufszeitraum"),
                selection: $selectedPeriod
            ) {
                ForEach(HumanWorkoutHistoryPeriod.allCases) { period in
                    Text(periodPickerTitle(period)).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            .accessibilityIdentifier("human-workout-history-period")

            if let historyCoverageStatusText {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: historyCoverage.isLoading ? "clock" : "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(historyCoverage.isLoading ? Color.ohanaTertiaryText : Color.goYellow)
                    Text(historyCoverageStatusText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("human-workout-history-coverage-status")
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        historyMetric(
                            value: historyMetricValue("\(trendSnapshot.totalDurationMinutes)"),
                            unit: l.tr(zh: "分钟", en: "min", de: "Min."),
                            title: l.tr(zh: "总时长", en: "Duration", de: "Dauer")
                        )
                        historyMetric(
                            value: historyMetricValue(String(format: "%.1f", trendSnapshot.totalDistanceKm)),
                            unit: "km",
                            title: l.tr(zh: "总距离", en: "Distance", de: "Distanz")
                        )
                        historyMetric(
                            value: historyMetricValue("\(trendSnapshot.activeDayCount)"),
                            unit: l.tr(zh: "天", en: "days", de: "Tage"),
                            title: l.tr(zh: "活跃天数", en: "Active", de: "Aktiv")
                        )
                    }
                } else {
                    HStack(spacing: 0) {
                        historyMetric(
                            value: historyMetricValue("\(trendSnapshot.totalDurationMinutes)"),
                            unit: l.tr(zh: "分钟", en: "min", de: "Min."),
                            title: l.tr(zh: "总时长", en: "Duration", de: "Dauer")
                        )
                        historyMetricDivider
                        historyMetric(
                            value: historyMetricValue(String(format: "%.1f", trendSnapshot.totalDistanceKm)),
                            unit: "km",
                            title: l.tr(zh: "总距离", en: "Distance", de: "Distanz")
                        )
                        historyMetricDivider
                        historyMetric(
                            value: historyMetricValue("\(trendSnapshot.activeDayCount)"),
                            unit: l.tr(zh: "天", en: "days", de: "Tage"),
                            title: l.tr(zh: "活跃天数", en: "Active", de: "Aktiv")
                        )
                    }
                }
            }

            Divider().overlay(Color.ohanaGlassStroke.opacity(0.7))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: historyTrendIcon).accessibilityHidden(true)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(historyTrendTint)
                    .frame(width: 44, height: 44)
                    .background(historyTrendTint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "本地时长趋势", en: "Local Duration Trend", de: "Lokaler Dauertrend"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(historyTrendText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        historySourceLabel(
                            icon: "tray.full.fill",
                            count: trendSnapshot.durableRecordCount,
                            title: l.tr(zh: "本地记录", en: "Local records", de: "Lokale Einträge"),
                            tint: .goTeal
                        )
                        historySourceLabel(
                            icon: "pawprint.fill",
                            count: trendSnapshot.petWalkCount,
                            title: l.tr(zh: "遛狗", en: "Dog walks", de: "Hundegänge"),
                            tint: .goCardCyan
                        )
                        historySourceLabel(
                            icon: "heart.fill",
                            count: trendSnapshot.liveAppleHealthCount,
                            title: l.tr(zh: "Apple Health 实时", en: "Live Apple Health", de: "Live Apple Health"),
                            tint: .goPrimary
                        )
                    }
                } else {
                    HStack(spacing: 12) {
                        historySourceLabel(
                            icon: "tray.full.fill",
                            count: trendSnapshot.durableRecordCount,
                            title: l.tr(zh: "本地", en: "Local", de: "Lokal"),
                            tint: .goTeal
                        )
                        historySourceLabel(
                            icon: "pawprint.fill",
                            count: trendSnapshot.petWalkCount,
                            title: l.tr(zh: "遛狗", en: "Dog walks", de: "Hundegänge"),
                            tint: .goCardCyan
                        )
                        historySourceLabel(
                            icon: "heart.fill",
                            count: trendSnapshot.liveAppleHealthCount,
                            title: l.tr(zh: "实时", en: "Live", de: "Live"),
                            tint: .goPrimary
                        )
                    }
                }
            }

            Text(l.tr(
                zh: "趋势只使用这台设备内已保存的历史（Ohana、遛狗和既有 Apple Health 记录）；临时 Apple Health 行不会改变本地趋势。",
                en: "The trend uses history saved on this device (Ohana, dog walks, and existing Apple Health records); temporary Apple Health rows do not change the local trend.",
                de: "Der Trend nutzt auf diesem Gerät gespeicherte Verläufe (Ohana, Hundegänge und vorhandene Apple-Health-Einträge); temporäre Apple-Health-Zeilen ändern den lokalen Trend nicht."
            ))
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(Color.ohanaTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .workoutSummaryCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l.tr(zh: "运动趋势摘要", en: "Workout trend summary", de: "Trainingstrend-Zusammenfassung"))
        .accessibilityValue(historyAccessibilitySummary)
        .accessibilityIdentifier("human-workout-history-overview")
    }

    private func historyMetric(value: String, unit: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(unit)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Text(title)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func historyMetricValue(_ value: String) -> String {
        if historyCoverage.isLoading { return "—" }
        return historyCoverage.isComplete ? value : "≥\(value)"
    }

    private var historyMetricDivider: some View {
        Divider()
            .overlay(Color.ohanaGlassStroke.opacity(0.7))
            .padding(.horizontal, 10)
    }

    private func historySourceLabel(icon: String, count: Int, title: String, tint: Color) -> some View {
        Label {
            Text("\(historyMetricValue("\(count)")) \(title)")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        } icon: {
            Image(systemName: icon).accessibilityHidden(true)
                .foregroundStyle(tint)
        }
        .frame(minHeight: 44)
    }

    private func periodPickerTitle(_ period: HumanWorkoutHistoryPeriod) -> String {
        l.tr(
            zh: "\(period.dayCount) 天",
            en: "\(period.dayCount)D",
            de: "\(period.dayCount) T."
        )
    }

    private var selectedPeriodTitle: String {
        l.tr(
            zh: "最近 \(selectedPeriod.dayCount) 天",
            en: "Last \(selectedPeriod.dayCount) days",
            de: "Letzte \(selectedPeriod.dayCount) Tage"
        )
    }

    private var historyCoverageStatusText: String? {
        if historyCoverage.isComplete { return nil }
        if historyCoverage.isLoading {
            return l.tr(
                zh: "正在更新所选区间；完成前不会显示精确合计或趋势。",
                en: "Updating the selected period; exact totals and trends stay hidden until it finishes.",
                de: "Der gewählte Zeitraum wird aktualisiert; exakte Summen und Trends bleiben bis dahin ausgeblendet."
            )
        }
        return l.tr(
            zh: "部分来源读取失败或达到本地安全上限。当前数值仅为至少值，暂不生成趋势。",
            en: "A source failed to load or reached its local safety limit. Current values are minimums, and no trend is calculated.",
            de: "Eine Quelle konnte nicht geladen werden oder erreichte ihr lokales Sicherheitslimit. Die Werte sind Mindestwerte; ein Trend wird nicht berechnet."
        )
    }

    private var historyTrendIcon: String {
        switch trendSnapshot.durationTrend.direction {
        case .unavailable: "minus"
        case .rising: "arrow.up.right"
        case .steady: "arrow.right"
        case .falling: "arrow.down.right"
        }
    }

    private var historyTrendTint: Color {
        switch trendSnapshot.durationTrend.direction {
        case .unavailable: .ohanaTertiaryText
        case .rising: .goTeal
        case .steady: .goPrimary
        case .falling: .goYellow
        }
    }

    private var historyTrendText: String {
        if !historyCoverage.isComplete {
            return historyCoverageStatusText ?? l.tr(
                zh: "区间数据不完整，暂不生成趋势。",
                en: "Period data is incomplete, so no trend is calculated.",
                de: "Die Zeitraumdaten sind unvollständig; daher wird kein Trend berechnet."
            )
        }
        let percent = trendSnapshot.durationTrend.changePercent.map(abs)
        switch trendSnapshot.durationTrend.direction {
        case .unavailable:
            return l.tr(
                zh: "本地区间记录不足，暂不生成变化判断。",
                en: "There is not enough local history in this period to assess change.",
                de: "In diesem Zeitraum gibt es noch nicht genug lokale Daten für eine Trendbewertung."
            )
        case .rising:
            if let percent {
                return l.tr(
                    zh: "后半段日均运动时长比前半段上升 \(percent)%。",
                    en: "Average daily duration rose \(percent)% in the second half.",
                    de: "Die durchschnittliche tägliche Dauer stieg in der zweiten Hälfte um \(percent) %."
                )
            }
            return l.tr(
                zh: "后半段开始出现本地运动记录。",
                en: "Local workout activity started in the second half.",
                de: "Lokale Trainingsaktivität begann in der zweiten Hälfte."
            )
        case .steady:
            return l.tr(
                zh: "前后半段的日均运动时长基本稳定。",
                en: "Average daily duration stayed broadly steady across the period.",
                de: "Die durchschnittliche tägliche Dauer blieb im Zeitraum weitgehend stabil."
            )
        case .falling:
            return l.tr(
                zh: "后半段日均运动时长比前半段下降 \(percent ?? 0)%。",
                en: "Average daily duration fell \(percent ?? 0)% in the second half.",
                de: "Die durchschnittliche tägliche Dauer sank in der zweiten Hälfte um \(percent ?? 0) %."
            )
        }
    }

    private var historyAccessibilitySummary: String {
        if let historyCoverageStatusText {
            return l.tr(
                zh: "\(selectedPeriodTitle)。\(historyCoverageStatusText)",
                en: "\(selectedPeriodTitle). \(historyCoverageStatusText)",
                de: "\(selectedPeriodTitle). \(historyCoverageStatusText)"
            )
        }
        return l.tr(
            zh: "\(selectedPeriodTitle)，共 \(trendSnapshot.visibleSampleCount) 项，\(trendSnapshot.totalDurationMinutes) 分钟，\(String(format: "%.1f", trendSnapshot.totalDistanceKm)) 公里，活跃 \(trendSnapshot.activeDayCount) 天。本地 \(trendSnapshot.durableRecordCount) 项，遛狗 \(trendSnapshot.petWalkCount) 项，Apple Health 实时 \(trendSnapshot.liveAppleHealthCount) 项。\(historyTrendText)",
            en: "\(selectedPeriodTitle): \(trendSnapshot.visibleSampleCount) activities, \(trendSnapshot.totalDurationMinutes) minutes, \(String(format: "%.1f", trendSnapshot.totalDistanceKm)) kilometers, and \(trendSnapshot.activeDayCount) active days. \(trendSnapshot.durableRecordCount) local, \(trendSnapshot.petWalkCount) dog walks, and \(trendSnapshot.liveAppleHealthCount) live Apple Health. \(historyTrendText)",
            de: "\(selectedPeriodTitle): \(trendSnapshot.visibleSampleCount) Aktivitäten, \(trendSnapshot.totalDurationMinutes) Minuten, \(String(format: "%.1f", trendSnapshot.totalDistanceKm)) Kilometer und \(trendSnapshot.activeDayCount) aktive Tage. \(trendSnapshot.durableRecordCount) lokal, \(trendSnapshot.petWalkCount) Hundegänge und \(trendSnapshot.liveAppleHealthCount) live aus Apple Health. \(historyTrendText)"
        )
    }
}

struct HumanWorkoutRecentWorkoutsCard: View {
    let selectedPeriod: HumanWorkoutHistoryPeriod
    let rows: [HumanWorkoutSummaryRow]
    let historyCoverage: HumanWorkoutHistoryCoverage
    let canReadLiveAppleHealth: Bool
    let isHealthLoading: Bool
    let recentWorkoutsStatus: HumanHealthRecentWorkoutsStatus
    let onDelete: (HumanWorkoutLog) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(
                    zh: "\(selectedPeriod.dayCount) 天运动记录",
                    en: "\(selectedPeriod.dayCount)-Day History",
                    de: "Verlauf: \(selectedPeriod.dayCount) Tage"
                ))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(recentWorkoutsCountText)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if let recentWorkoutsStatusText {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text(recentWorkoutsStatusText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("human-workout-recent-status")
            }

            if rows.isEmpty {
                VStack(spacing: 8) {
                    if isHealthLoading, recentWorkoutsStatus == .notLoaded {
                        ProgressView()
                            .tint(Color.goPrimary)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "figure.run.circle").accessibilityHidden(true)
                            .font(OhanaFont.metric(size: 34))
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    Text(recentWorkoutsEmptyText)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        workoutRow(row)
                        if row.id != rows.last?.id {
                            GoDashedDivider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .workoutSummaryCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l.tr(zh: "区间运动记录", en: "Workout history", de: "Trainingsverlauf"))
        .accessibilityValue(l.tr(
            zh: "\(selectedPeriodTitle)，\(historyMetricValue("\(rows.count)")) 项",
            en: "\(selectedPeriodTitle), \(historyMetricValue("\(rows.count)")) activities",
            de: "\(selectedPeriodTitle), \(historyMetricValue("\(rows.count)")) Aktivitäten"
        ))
        .accessibilityIdentifier("human-workout-period-history")
    }

    private func workoutRow(_ row: HumanWorkoutSummaryRow) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: row.type.icon)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color(hex: row.type.colorHex))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: row.type.colorHex).opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(row.title)
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        if row.isHealthKit {
                            sourceBadge(row.sourceName.isEmpty ? "Apple Health" : row.sourceName, tint: .goPrimary)
                        }
                        if row.isPetWalk {
                            sourceBadge(l.tr(zh: "遛狗", en: "Dog Walk", de: "Hundegang"), tint: .goCardCyan)
                        }
                        if row.isMatched {
                            sourceBadge(l.tr(zh: "已匹配", en: "Matched", de: "Abgeglichen"), tint: .goYellow)
                        }
                    }
                    Text(row.date, format: .dateTime.month().day().hour().minute())
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    if let overlapText = row.overlapText {
                        Text(overlapText)
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.goYellow)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(row.durationMinutes) min")
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color(hex: row.type.colorHex))
                    Text(row.secondaryMetric)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(workoutRowAccessibilityLabel(row))

            rowAction(row)
        }
        .padding(.vertical, 10)
    }

    private func sourceBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.arkInk)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint, in: Capsule())
    }

    @ViewBuilder
    private func rowAction(_ row: HumanWorkoutSummaryRow) -> some View {
        if let log = row.log, !row.isHealthKit, !row.isPetWalk {
            Button {
                onDelete(log)
            } label: {
                Image(systemName: "trash").accessibilityHidden(true)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.58))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "删除运动记录", en: "Delete workout log", de: "Trainingseintrag löschen"))
            .accessibilityIdentifier("human-workout-delete-action")
        }
    }

    private var recentWorkoutsCountText: String {
        let count = historyMetricValue("\(rows.count)")
        return l.tr(
            zh: "\(count) 项活动",
            en: "\(count) activities",
            de: "\(count) Aktivitäten"
        )
    }

    private var recentWorkoutsStatusText: String? {
        guard canReadLiveAppleHealth else { return nil }
        guard case .failed = recentWorkoutsStatus else { return nil }
        return l.tr(
            zh: "Apple Health 最近运动读取失败。请刷新重试；Ohana 手动记录不受影响。",
            en: "Recent Apple Health workouts could not be read. Refresh to retry; Ohana manual records are unaffected.",
            de: "Letzte Apple-Health-Trainings konnten nicht gelesen werden. Aktualisiere erneut; manuelle Ohana-Einträge bleiben erhalten."
        )
    }

    private var recentWorkoutsEmptyText: String {
        if historyCoverage.isLoading {
            return l.tr(
                zh: "正在更新所选区间…",
                en: "Updating the selected period…",
                de: "Der gewählte Zeitraum wird aktualisiert…"
            )
        }
        if !historyCoverage.isComplete {
            return l.tr(
                zh: "当前没有已读取的记录，但部分来源未能完整加载。",
                en: "No loaded records are visible, but some sources could not be read completely.",
                de: "Derzeit sind keine geladenen Einträge sichtbar; einige Quellen konnten jedoch nicht vollständig gelesen werden."
            )
        }
        guard canReadLiveAppleHealth else {
            return l.tr(
                zh: "最近 \(selectedPeriod.dayCount) 天没有手动运动或遛狗记录",
                en: "No manual workouts or dog walks in the last \(selectedPeriod.dayCount) days",
                de: "Keine manuellen Trainings oder Hundegänge in den letzten \(selectedPeriod.dayCount) Tagen"
            )
        }
        if isHealthLoading, recentWorkoutsStatus == .notLoaded {
            return l.tr(zh: "正在读取运动记录…", en: "Loading workouts…", de: "Trainings werden geladen…")
        }
        switch recentWorkoutsStatus {
        case .noData:
            return l.tr(
                zh: "最近 \(selectedPeriod.dayCount) 天没有可读取的运动记录",
                en: "No readable workouts in the last \(selectedPeriod.dayCount) days",
                de: "Keine lesbaren Trainings in den letzten \(selectedPeriod.dayCount) Tagen"
            )
        case .failed:
            return l.tr(
                zh: "最近 \(selectedPeriod.dayCount) 天没有 Ohana 本地记录",
                en: "No local Ohana workouts in the last \(selectedPeriod.dayCount) days",
                de: "Keine lokalen Ohana-Trainings in den letzten \(selectedPeriod.dayCount) Tagen"
            )
        case .notLoaded, .available:
            return l.tr(
                zh: "最近 \(selectedPeriod.dayCount) 天没有运动记录",
                en: "No workouts in the last \(selectedPeriod.dayCount) days",
                de: "Keine Trainings in den letzten \(selectedPeriod.dayCount) Tagen"
            )
        }
    }

    private var selectedPeriodTitle: String {
        l.tr(
            zh: "最近 \(selectedPeriod.dayCount) 天",
            en: "Last \(selectedPeriod.dayCount) days",
            de: "Letzte \(selectedPeriod.dayCount) Tage"
        )
    }

    private func historyMetricValue(_ value: String) -> String {
        if historyCoverage.isLoading { return "—" }
        return historyCoverage.isComplete ? value : "≥\(value)"
    }

    private func workoutRowAccessibilityLabel(_ row: HumanWorkoutSummaryRow) -> String {
        let source = switch row.historySource {
        case .ohanaLocal:
            l.tr(zh: "Ohana 本地", en: "Ohana local", de: "Ohana lokal")
        case .storedAppleHealth:
            l.tr(zh: "本地 Apple Health 历史", en: "saved Apple Health history", de: "gespeicherter Apple-Health-Verlauf")
        case .petWalk:
            l.tr(zh: "Ohana 遛狗", en: "Ohana dog walk", de: "Ohana Hundegang")
        case .liveAppleHealth:
            l.tr(zh: "Apple Health 实时", en: "live Apple Health", de: "live Apple Health")
        case .matchedPetWalkAndAppleHealth:
            l.tr(zh: "已匹配的遛狗与 Apple Health", en: "matched dog walk and Apple Health", de: "abgeglichener Hundegang und Apple Health")
        }
        let distance = row.distanceKm > 0.01
            ? l.tr(
                zh: "，\(String(format: "%.1f", row.distanceKm)) 公里",
                en: ", \(String(format: "%.1f", row.distanceKm)) kilometers",
                de: ", \(String(format: "%.1f", row.distanceKm)) Kilometer"
            )
            : ""
        return l.tr(
            zh: "\(row.title)，\(row.durationMinutes) 分钟\(distance)，来源：\(source)",
            en: "\(row.title), \(row.durationMinutes) minutes\(distance), source: \(source)",
            de: "\(row.title), \(row.durationMinutes) Minuten\(distance), Quelle: \(source)"
        )
    }
}

struct HumanWorkoutSummaryRow: Identifiable {
    let id: String
    let title: String
    let type: WorkoutType
    let date: Date
    let durationMinutes: Int
    let distanceKm: Double
    let calories: Int
    let steps: Int
    let isHealthKit: Bool
    let isPetWalk: Bool
    let isMatched: Bool
    let sourceName: String
    let overlapText: String?
    let log: HumanWorkoutLog?
    let historySource: HumanWorkoutHistorySource

    var trendSample: HumanWorkoutTrendSample {
        HumanWorkoutTrendSample(
            id: id,
            date: date,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            source: historySource
        )
    }

    var secondaryMetric: String {
        if distanceKm > 0.01 {
            return String(format: "%.1f km", distanceKm)
        }
        if calories > 0 {
            return "\(calories) kcal"
        }
        if steps > 0 {
            return "\(steps) steps"
        }
        return ""
    }

    static func local(
        _ log: HumanWorkoutLog,
        title: String,
        sourceName: String,
        isPetWalk: Bool,
        isMatched: Bool
    ) -> HumanWorkoutSummaryRow {
        let historySource: HumanWorkoutHistorySource = switch (isMatched, isPetWalk, log.sourceHealthKit) {
        case (true, _, _):
            .matchedPetWalkAndAppleHealth
        case (_, true, _):
            .petWalk
        case (_, _, true):
            .storedAppleHealth
        default:
            .ohanaLocal
        }
        return HumanWorkoutSummaryRow(
            id: "local-\(log.id.uuidString)",
            title: title,
            type: log.workoutType,
            date: log.date,
            durationMinutes: log.durationMinutes,
            distanceKm: log.distanceKm,
            calories: log.calories,
            steps: log.steps,
            isHealthKit: log.sourceHealthKit,
            isPetWalk: isPetWalk,
            isMatched: isMatched,
            sourceName: sourceName,
            overlapText: nil,
            log: log,
            historySource: historySource
        )
    }

    static func healthKit(
        _ workout: HumanHealthKitWorkoutSnapshot,
        title: String
    ) -> HumanWorkoutSummaryRow {
        HumanWorkoutSummaryRow(
            id: "healthkit-\(workout.healthKitWorkoutUUID)",
            title: title,
            type: workout.type,
            date: workout.startDate,
            durationMinutes: workout.durationMinutes,
            distanceKm: workout.distanceKm,
            calories: workout.calories,
            steps: workout.steps,
            isHealthKit: true,
            isPetWalk: false,
            isMatched: false,
            sourceName: workout.sourceName,
            overlapText: nil,
            log: nil,
            historySource: .liveAppleHealth
        )
    }

    static func petWalk(
        _ walk: HumanWorkoutPetWalkSnapshot,
        title: String,
        sourceName: String,
        overlapText: String?,
        matchedHealthKitWorkout: HumanHealthKitWorkoutSnapshot?
    ) -> HumanWorkoutSummaryRow {
        HumanWorkoutSummaryRow(
            id: "pet-walk-\(walk.id)",
            title: title,
            type: .walking,
            date: walk.startDate,
            durationMinutes: walk.durationMinutes,
            distanceKm: walk.distanceKm,
            calories: matchedHealthKitWorkout?.calories ?? 0,
            steps: matchedHealthKitWorkout?.steps ?? 0,
            isHealthKit: matchedHealthKitWorkout != nil,
            isPetWalk: true,
            isMatched: matchedHealthKitWorkout != nil,
            sourceName: matchedHealthKitWorkout?.sourceName ?? sourceName,
            overlapText: overlapText,
            log: nil,
            historySource: matchedHealthKitWorkout == nil ? .petWalk : .matchedPetWalkAndAppleHealth
        )
    }
}
