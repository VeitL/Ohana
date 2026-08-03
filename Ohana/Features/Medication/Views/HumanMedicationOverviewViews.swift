//
//  HumanMedicationOverviewViews.swift
//  Ohana
//
//  Read-only medication summary components with explicit presentation inputs.
//

import SwiftUI

struct HumanMedicationSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

struct HumanMedicationBoundedReadNotice: View {
    let l: L10n

    var body: some View {
        Label {
            Text(l.tr(
                zh: "记录已超过本页显示上限。当前计划会优先保留；今日进度和七日趋势仅代表已载入数据，不能据此判断全部剂量已完成。更早数据仍保存在本机。",
                en: "Records exceed this page's display limit. Current plans are prioritized; today's progress and the 7-day trend describe loaded data only and must not be used to infer that every dose is complete. Older data remains on this device.",
                de: "Die Einträge überschreiten das Anzeigelimit. Aktuelle Pläne haben Vorrang; Tagesfortschritt und 7-Tage-Verlauf beziehen sich nur auf geladene Daten und bestätigen nicht, dass alle Dosen erledigt sind. Ältere Daten bleiben auf diesem Gerät."
            ))
            .font(OhanaFont.caption(.semibold))
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill") // a11y: allow decorative icon; the adjacent text owns the message
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ohanaControlFill,
            in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("human-medication-bounded-read-notice")
    }
}

struct HumanMedicationIdentityHeader: View {
    let human: Human
    let showsDoneButton: Bool
    let todayTotal: Int
    let todayDone: Int
    let isTodayReadComplete: Bool
    let showsPrivacyToggle: Bool
    let l: L10n
    let onClose: () -> Void

    var body: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente"),
            subtitle: human.name,
            showsCloseButton: showsDoneButton,
            onClose: onClose
        ) {
            if todayTotal > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isTodayReadComplete ? "\(todayDone)/\(todayTotal)" : "≥\(todayDone)")
                        .font(OhanaFont.metric(size: 20))
                        .foregroundStyle(
                            isTodayReadComplete && todayDone == todayTotal
                                ? Color.goTeal
                                : Color.goPrimary
                        )
                    Text(isTodayReadComplete
                        ? l.tr(zh: "今日服药", en: "Today", de: "Heute")
                        : l.tr(zh: "今日已载入", en: "Loaded today", de: "Heute geladen"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            if showsPrivacyToggle {
                HumanPrivacyToggleButton(human: human, field: .medication)
            }
        }
    }
}

struct HumanMedicationPrivacyLockedPage: View {
    let human: Human
    let showsDoneButton: Bool
    let l: L10n
    let onClose: () -> Void

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            VStack(spacing: 20) {
                HumanModulePageHeader(
                    human: human,
                    title: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente"),
                    subtitle: human.name,
                    showsCloseButton: showsDoneButton,
                    onClose: onClose
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer(minLength: 16)
                HumanModulePrivacyLockedView(
                    title: l.tr(
                        zh: "吃药提醒仅本人可见",
                        en: "Medication is private",
                        de: "Medikamente sind privat"
                    ),
                    message: l.tr(
                        zh: "当前家庭成员无权查看用药计划、剂量和服药记录。",
                        en: "This household member cannot view medication plans, doses, or logs.",
                        de: "Dieses Haushaltsmitglied kann Medikamentenpläne, Dosen oder Protokolle nicht sehen."
                    )
                )
                Spacer()
            }
        }
    }
}

struct HumanMedicationTodayFocusCard: View {
    let hasOverdueDose: Bool
    let todayCompletion: Double
    let isTodayReadComplete: Bool
    let todayPlannedCount: Int
    let currentMedicationCount: Int
    let isActivePlansReadComplete: Bool
    let sevenDayCompletionLabel: String
    let title: String
    let subtitle: String
    let l: L10n

    var body: some View {
        HumanMedicationSurface {
            HStack(spacing: 18) {
                HumanMedicationProgressRing(
                    completion: todayCompletion,
                    isTodayReadComplete: isTodayReadComplete,
                    todayPlannedCount: todayPlannedCount,
                    l: l
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: hasOverdueDose
                            ? "exclamationmark.triangle.fill"
                            : "pills.fill")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(hasOverdueDose ? Color.goRed : Color.goPrimary)
                        Text(l.tr(zh: "TODAY FOCUS", en: "TODAY FOCUS", de: "HEUTE"))
                            .font(OhanaFont.caption(.black))
                            .tracking(1.2)
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }

                    Text(title)
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        HumanMedicationOverviewPill(
                            text: isActivePlansReadComplete
                                ? l.tr(
                                    zh: "\(currentMedicationCount) 个固定用药",
                                    en: "\(currentMedicationCount) scheduled",
                                    de: "\(currentMedicationCount) geplant"
                                )
                                : l.tr(
                                    zh: "≥\(currentMedicationCount) 个固定用药",
                                    en: "≥\(currentMedicationCount) scheduled",
                                    de: "≥\(currentMedicationCount) geplant"
                                ),
                            color: Color.goRed
                        )
                        HumanMedicationOverviewPill(
                            text: sevenDayCompletionLabel,
                            color: Color.goPrimary
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
    }
}

private struct HumanMedicationProgressRing: View {
    let completion: Double
    let isTodayReadComplete: Bool
    let todayPlannedCount: Int
    let l: L10n

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ohanaControlFill, lineWidth: 12)
                .frame(width: 108, height: 108)
            Circle()
                .trim(from: 0, to: isTodayReadComplete ? completion : 0)
                .stroke(
                    LinearGradient(
                        colors: [Color.goPrimary, Color.goTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 108, height: 108)
            VStack(spacing: 0) {
                Text(!isTodayReadComplete || todayPlannedCount == 0
                    ? "—"
                    : "\(Int((completion * 100).rounded()))%")
                    .font(OhanaFont.metric(size: 26))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "今日", en: "Today", de: "Heute"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
    }
}

private struct HumanMedicationOverviewPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct HumanMedicationOverviewMetricGrid: View {
    let isTodayReadComplete: Bool
    let todayTakenCount: Int
    let todaySkippedCount: Int
    let todayPlannedCount: Int
    let pendingCount: Int
    let overdueCount: Int
    let l: L10n

    private var hasOverdueDose: Bool { overdueCount > 0 }

    var body: some View {
        HStack(spacing: 10) {
            HumanMedicationOverviewMetricCard(
                icon: "checkmark.seal.fill",
                label: l.tr(zh: "今日已服", en: "Taken", de: "Genommen"),
                value: isTodayReadComplete ? "\(todayTakenCount)" : "≥\(todayTakenCount)",
                suffix: isTodayReadComplete && todayPlannedCount > 0 ? "/\(todayPlannedCount)" : "",
                color: Color.goTeal
            )
            HumanMedicationOverviewMetricCard(
                icon: "forward.fill",
                label: l.tr(zh: "已跳过", en: "Skipped", de: "Übersprungen"),
                value: isTodayReadComplete ? "\(todaySkippedCount)" : "≥\(todaySkippedCount)",
                suffix: l.tr(zh: "次", en: "", de: ""),
                color: Color.goOrange
            )
            HumanMedicationOverviewMetricCard(
                icon: hasOverdueDose ? "exclamationmark.triangle.fill" : "clock.badge.checkmark",
                label: hasOverdueDose
                    ? l.tr(zh: "已超时", en: "Overdue", de: "Überfällig")
                    : l.tr(zh: "待记录", en: "Pending", de: "Offen"),
                value: isTodayReadComplete
                    ? "\(hasOverdueDose ? overdueCount : pendingCount)"
                    : "≥\(hasOverdueDose ? overdueCount : pendingCount)",
                suffix: l.tr(zh: "次", en: "", de: ""),
                color: hasOverdueDose ? Color.goRed : Color.goYellow
            )
        }
    }
}

private struct HumanMedicationOverviewMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let suffix: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(color)
                Text(label)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(OhanaFont.metric(size: 24))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Color.ohanaControlFill,
            in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }
}

struct HumanMedicationAdherenceCard: View {
    let snapshot: HumanMedicationAdherenceSnapshot
    let isSevenDayReadComplete: Bool
    let l: L10n

    var body: some View {
        HumanMedicationSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(
                            zh: "近 7 天服药趋势",
                            en: "7-day medication trend",
                            de: "7-Tage-Verlauf"
                        ))
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(isSevenDayReadComplete
                            ? l.tr(
                                zh: "按当前计划估算截至目前的到期剂量与已服剂量",
                                en: "Estimated from the current plan: doses due vs taken through now",
                                de: "Aus dem aktuellen Plan geschätzt: fällige und eingenommene Dosen"
                            )
                            : l.tr(
                                zh: "仅展示已载入记录，不计算完整完成率",
                                en: "Loaded records only; no complete adherence rate is calculated",
                                de: "Nur geladene Einträge; keine vollständige Adhärenzrate"
                            ))
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isSevenDayReadComplete
                            ? snapshot.completionRate.map { "\($0)%" } ?? "—"
                            : "—")
                            .font(OhanaFont.metric(size: 24))
                            .foregroundStyle(Color.goPrimary)
                        Text(!isSevenDayReadComplete
                            ? l.tr(zh: "部分数据", en: "Partial data", de: "Teildaten")
                            : snapshot.plannedDoseCount > 0
                                ? l.tr(zh: "估算完成率", en: "Estimated", de: "Geschätzt")
                                : l.tr(zh: "暂无到期剂量", en: "No doses due", de: "Keine Dosis fällig"))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }

                HumanMedicationAdherenceChart(
                    days: snapshot.days,
                    plannedTint: Color.ohanaSecondaryText.opacity(0.32),
                    takenTint: Color.goPrimary
                )
                .frame(height: 150)

                HStack(spacing: 14) {
                    HumanMedicationChartLegendDot(
                        color: Color.ohanaSecondaryText.opacity(0.55),
                        label: l.tr(zh: "计划", en: "Planned", de: "Geplant")
                    )
                    HumanMedicationChartLegendDot(
                        color: Color.goPrimary,
                        label: l.tr(zh: "已服", en: "Taken", de: "Genommen")
                    )
                    Spacer()
                    Text(l.tr(
                        zh: "编辑或停用计划会改变历史估算；按需记录不计入",
                        en: "Editing or stopping a plan changes this estimate; as-needed logs are excluded",
                        de: "Änderungen oder Stoppen eines Plans verändern die Schätzung; Bedarfsprotokolle zählen nicht"
                    ))
                        .font(OhanaFont.caption2())
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
            }
            .padding(16)
        }
    }
}

private struct HumanMedicationChartLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }
}

struct HumanMedicationEmptyState: View {
    let l: L10n

    var body: some View {
        HumanMedicationSurface {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.goRed.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "pills").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 32))
                        .foregroundStyle(Color.goRed) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                Text(l.tr(
                    zh: "还没有添加药物",
                    en: "No medication yet",
                    de: "Noch keine Medikamente"
                ))
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "添加第一个服药提醒，今天的待处理剂量会显示在这里。",
                    en: "Add the first medication reminder to see today's doses here.",
                    de: "Füge die erste Erinnerung hinzu, um heutige Dosen hier zu sehen."
                ))
                    .font(OhanaFont.callout())
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
}

private struct HumanMedicationAdherenceChart: View {
    let days: [MedicationAdherenceDay]
    let plannedTint: Color
    let takenTint: Color

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        GeometryReader { proxy in
            let maxPlanned = max(1, days.map(\.planned).max() ?? 1)
            let availableBarHeight = max(32, proxy.size.height - 26)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(plannedTint)
                                .frame(height: barHeight(
                                    value: day.planned,
                                    maximum: maxPlanned,
                                    availableHeight: availableBarHeight
                                ))

                            if day.taken > 0 {
                                Capsule()
                                    .fill(takenTint)
                                    .frame(height: barHeight(
                                        value: day.taken,
                                        maximum: maxPlanned,
                                        availableHeight: availableBarHeight
                                    ))
                            }
                        }
                        .frame(maxHeight: availableBarHeight, alignment: .bottom)

                        Text(day.date.formatted(
                            Date.FormatStyle()
                                .weekday(.narrow)
                                .locale(AppLanguage.effectiveLocale)
                        ))
                        .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(
                            Calendar.current.isDateInToday(day.date)
                                ? takenTint
                                : Color.ohanaTertiaryText
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: day))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func barHeight(
        value: Int,
        maximum: Int,
        availableHeight: CGFloat
    ) -> CGFloat {
        guard value > 0 else { return 4 }
        return max(10, CGFloat(value) / CGFloat(maximum) * availableHeight)
    }

    private func accessibilityLabel(for day: MedicationAdherenceDay) -> String {
        let date = day.date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(AppLanguage.effectiveLocale)
        )
        return l.tr(
            zh: "\(date)，计划 \(day.planned) 次，已服 \(day.taken) 次",
            en: "\(date), \(day.planned) planned, \(day.taken) taken",
            de: "\(date), \(day.planned) geplant, \(day.taken) eingenommen"
        )
    }
}
