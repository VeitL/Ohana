//
//  HumanHealthSummaryView.swift
//  Ohana
//
//  UI contract: compact V4 operational overview, inspired by the hierarchy of
//  Apple Fitness and Apple Health without copying Activity Rings.
//

import SwiftUI

struct HumanHealthSummaryView: View {
    let human: Human

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pinnedDestinations: [HumanHealthSummaryDestination]
    @State private var showingPinnedEditor = false

    init(human: Human) {
        self.human = human
        let key = HumanHealthSummaryPinPreference.storageKey(humanID: human.id)
        let stored = UserDefaults.standard.string(forKey: key)
        _pinnedDestinations = State(
            initialValue: HumanHealthSummaryPinPreference.decode(stored)
        )
    }

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanID: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var bodyIsVisible: Bool {
        !human.isPrivate(.weight, viewedBy: activeHumanID)
    }

    private var medicationIsVisible: Bool {
        !human.isPrivate(.medication, viewedBy: activeHumanID)
    }

    private var workoutIsVisible: Bool {
        !human.isPrivate(.workout, viewedBy: activeHumanID)
    }

    private var pinColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10)]
        }
        return [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    var body: some View {
        HumanHealthSummaryDataContainer(
            human: human,
            bodyIsVisible: bodyIsVisible,
            medicationIsVisible: medicationIsVisible,
            workoutIsVisible: workoutIsVisible
        ) { snapshot in
            ZStack {
                OhanaAppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        identityHeader(snapshot)
                        todaySection(snapshot)
                        pinnedSection(snapshot)
                        highlightsSection(snapshot)
                        trendsSection(snapshot)
                        recordsAndSourcesSection(snapshot)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .accessibilityIdentifier("human-health-summary-screen")
            .navigationTitle(l.tr(zh: "健康摘要", en: "Health Summary", de: "Gesundheitsübersicht"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPinnedEditor) {
                HumanHealthSummaryPinEditor(
                    initialItems: pinnedDestinations,
                    onSave: savePinnedDestinations
                )
            }
        }
        .environment(\.locale, AppLanguage.effectiveLocale)
    }

    private func identityHeader(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(human.name)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(l.tr(
                    zh: "今天先看待处理、需复核和复查安排",
                    en: "Start with what is due, needs review, and comes next",
                    de: "Zuerst Fälliges, zu Prüfendes und nächste Kontrollen"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Label(
                l.tr(zh: "本机", en: "On device", de: "Auf dem Gerät"),
                systemImage: "iphone"
            )
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.goTeal)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.goTeal.opacity(0.12), in: Capsule())
            .accessibilityLabel(l.tr(
                zh: "健康摘要在本机处理",
                en: "Health summary processed on device",
                de: "Gesundheitsübersicht wird auf dem Gerät verarbeitet"
            ))
        }
    }

    private func todaySection(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(
                l.tr(zh: "今天", en: "Today", de: "Heute"),
                subtitle: l.tr(zh: "当前需要处理的事项", en: "What needs attention now", de: "Was jetzt wichtig ist"),
                identifier: "human-health-summary-today-section"
            )

            VStack(spacing: 0) {
                todayMedicationRow(snapshot)
                summaryDivider
                todayMetricRow(snapshot)
                summaryDivider
                todayFollowUpRow(snapshot)
                summaryDivider
                todayObservationRow(snapshot)
            }
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private func todayMedicationRow(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        summaryNavigationRow(
            route: .feature(.medication),
            icon: "pills.fill",
            tint: .goPurple,
            title: l.tr(zh: "今日用药", en: "Medication today", de: "Medikamente heute"),
            value: medicationTodayValue(snapshot),
            detail: medicationTodayDetail(snapshot),
            isLocked: !snapshot.medicationIsVisible,
            identifier: "human-health-summary-today-medication"
        )
    }

    private func todayMetricRow(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        summaryNavigationRow(
            route: .feature(.metrics),
            icon: "waveform.path.ecg.rectangle.fill",
            tint: snapshot.abnormalMetrics.isEmpty ? .goTeal : .goOrange,
            title: l.tr(zh: "最新指标", en: "Latest metrics", de: "Aktuelle Werte"),
            value: metricTodayValue(snapshot),
            detail: metricTodayDetail(snapshot),
            isLocked: !snapshot.bodyIsVisible,
            identifier: "human-health-summary-today-metrics"
        )
    }

    private func todayFollowUpRow(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        summaryNavigationRow(
            route: .feature(.reports),
            icon: "calendar.badge.clock",
            tint: .goBlue,
            title: l.tr(zh: "复查安排", en: "Follow-up", de: "Kontrolle"),
            value: followUpValue(snapshot),
            detail: followUpDetail(snapshot),
            isLocked: !snapshot.bodyIsVisible,
            identifier: "human-health-summary-today-follow-up"
        )
    }

    private func todayObservationRow(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        summaryNavigationRow(
            route: .feature(.conditions),
            icon: "heart.text.clipboard.fill",
            tint: .goTeal,
            title: l.tr(zh: "近期状态", en: "Recent state", de: "Letzter Zustand"),
            value: observationValue(snapshot),
            detail: observationDetail(snapshot),
            isLocked: !snapshot.bodyIsVisible,
            identifier: "human-health-summary-today-observation"
        )
    }

    private func pinnedSection(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(
                    l.tr(zh: "重点项目", en: "Pinned", de: "Fixiert"),
                    subtitle: l.tr(zh: "按自己的顺序快速进入", en: "Your shortcuts, in your order", de: "Deine Kurzbefehle in eigener Reihenfolge"),
                    identifier: "human-health-summary-pinned-section"
                )
                Spacer(minLength: 8)
                Button {
                    showingPinnedEditor = true
                } label: {
                    Text(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"))
                        .font(OhanaFont.caption(.black))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.goPrimary)
                .accessibilityIdentifier("human-health-summary-edit-pins-action")
            }

            if pinnedDestinations.isEmpty {
                Button {
                    showingPinnedEditor = true
                } label: {
                    Label(
                        l.tr(zh: "选择重点项目", en: "Choose pinned items", de: "Fixierte Bereiche auswählen"),
                        systemImage: "pin.fill"
                    )
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
            } else {
                LazyVGrid(columns: pinColumns, alignment: .leading, spacing: 10) {
                    ForEach(pinnedDestinations) { destination in
                        pinnedTile(destination, snapshot: snapshot)
                    }
                }
            }
        }
    }

    private func pinnedTile(
        _ destination: HumanHealthSummaryDestination,
        snapshot: HumanHealthSummarySnapshot
    ) -> some View {
        NavigationLink {
            destinationView(.feature(destination))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: destination.systemImage)
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .foregroundStyle(destination.tint)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right") // a11y: allow decorative navigation affordance; link text supplies the label
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .accessibilityHidden(true)
                }
                Text(destination.title(l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(destinationValue(destination, snapshot: snapshot))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(destination.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(destinationDetail(destination, snapshot: snapshot))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(14)
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("human-health-summary-pin-\(destination.rawValue)")
    }

    private func highlightsSection(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(
                l.tr(zh: "摘要", en: "Highlights", de: "Highlights"),
                subtitle: l.tr(zh: "只描述已记录事实，不作诊断", en: "Recorded facts, not a diagnosis", de: "Erfasste Fakten, keine Diagnose"),
                identifier: "human-health-summary-highlights-section"
            )

            if snapshot.highlights.isEmpty {
                inlineEmptyState(
                    icon: "sparkles",
                    text: l.tr(
                        zh: "记录用药、指标或状态后，这里会出现简短摘要。",
                        en: "Short highlights appear after you log medication, metrics, or a condition state.",
                        de: "Kurze Highlights erscheinen nach Einträgen zu Medikamenten, Werten oder Zuständen."
                    )
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(snapshot.highlights) { highlight in
                        highlightRow(highlight)
                    }
                }
            }
        }
    }

    private func highlightRow(_ highlight: HumanHealthSummaryHighlight) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: highlightIcon(highlight))
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(highlightTint(highlight))
                .frame(width: 28, height: 28) // a11y: allow decorative glyph; row is non-interactive and combines its text
                .background(highlightTint(highlight).opacity(0.13), in: Circle())
                .accessibilityHidden(true)
            Text(highlightText(highlight))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func trendsSection(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(
                l.tr(zh: "趋势", en: "Trends", de: "Trends"),
                subtitle: l.tr(zh: "最新两次同单位记录的变化", en: "Change between the latest two logs in the same unit", de: "Änderung zwischen den letzten zwei Einträgen derselben Einheit"),
                identifier: "human-health-summary-trends-section"
            )

            if snapshot.trends.isEmpty {
                NavigationLink {
                    destinationView(.feature(.metrics))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line") // a11y: allow decorative icon; link text supplies the label
                            .font(OhanaFont.adaptive(size: 18, weight: .black))
                            .foregroundStyle(Color.goTeal)
                            .accessibilityHidden(true)
                        Text(l.tr(
                            zh: "同一指标记录至少两次后显示趋势",
                            en: "Log the same metric twice to see a trend",
                            de: "Denselben Wert zweimal erfassen, um einen Trend zu sehen"
                        ))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.right") // a11y: allow decorative navigation affordance; link text supplies the label
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 14)
                    .background(
                        Color.ohanaCardSurface,
                        in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                VStack(spacing: 10) {
                    ForEach(snapshot.trends) { trend in
                        trendRow(trend)
                    }
                }
            }

            Text(l.tr(
                zh: "数值变化只表示记录差异，不代表原因或诊断。",
                en: "A value change describes recorded difference only; it does not explain a cause or diagnosis.",
                de: "Eine Wertänderung beschreibt nur den Unterschied der Einträge, nicht Ursache oder Diagnose."
            ))
            .font(OhanaFont.caption2(.semibold))
            .foregroundStyle(Color.ohanaTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trendRow(_ trend: HumanHealthSummaryTrend) -> some View {
        NavigationLink {
            destinationView(.metric(trend.metricKey))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: trendIcon(trend.direction))
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(trendTint(trend))
                    .frame(width: 38, height: 38) // a11y: allow decorative glyph; the enclosing link has a 54pt minimum height
                    .background(trendTint(trend).opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(metricTitle(trend.metricKey))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(trend.currentDate, format: .dateTime.year().month().day())
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(metricValue(trend.currentValue, metricKey: trend.metricKey, unitCode: trend.unitCode))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(trendDelta(trend))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(trendTint(trend))
                }
                Image(systemName: "chevron.right") // a11y: allow decorative navigation affordance; link text supplies the label
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 54)
            .padding(.horizontal, 14)
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("human-health-summary-trend-\(trend.metricKey)")
    }

    private func recordsAndSourcesSection(_ snapshot: HumanHealthSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(
                l.tr(zh: "记录与来源", en: "Records & Sources", de: "Einträge & Quellen"),
                subtitle: l.tr(zh: "查看完整历史和数据归属", en: "Open full history and data ownership", de: "Verlauf und Datenzuordnung öffnen"),
                identifier: "human-health-summary-records-section"
            )

            VStack(spacing: 0) {
                recordRow(.medication, value: boundedCountText(snapshot.recordCounts.activeMedicationPlans))
                summaryDivider
                recordRow(.metrics, value: boundedCountText(snapshot.recordCounts.trackedMetrics))
                summaryDivider
                recordRow(.conditions, value: boundedCountText(snapshot.recordCounts.activeConditions))
                summaryDivider
                recordRow(.reports, value: boundedCountText(snapshot.recordCounts.reports))
                summaryDivider
                recordRow(.weight, value: l.tr(zh: "趋势", en: "Trend", de: "Trend"))
            }
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 9) {
                sourceRow(
                    icon: "iphone",
                    title: l.tr(zh: "Ohana 本机记录", en: "Ohana on-device records", de: "Ohana-Einträge auf dem Gerät"),
                    detail: l.tr(zh: "用药、指标、状态与报告", en: "Medication, metrics, conditions, and reports", de: "Medikamente, Werte, Zustände und Berichte"),
                    tint: .goTeal
                )
                NavigationLink {
                    destinationView(.feature(.workouts))
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        sourceRow(
                            icon: "heart.fill",
                            title: "Apple Health",
                            detail: appleHealthSourceDetail(snapshot.sourceState),
                            tint: .goRed
                        )
                        Image(systemName: "chevron.right") // a11y: allow decorative disclosure glyph; NavigationLink supplies the label
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-health-summary-apple-health-source")
            }
            .padding(.top, 2)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised.fill") // a11y: allow decorative privacy icon; adjacent text conveys the disclosure
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goBlue)
                    .accessibilityHidden(true)
                Text(l.tr(
                    zh: "身体指标、健康报告和健康状况目前沿用本机“身体与健康记录（原体重）”隐私开关。此说明不改变数据模型或既有记录。",
                    en: "Metrics, health reports, and conditions currently use the on-device “Body & Health Records (formerly Weight)” privacy setting. This does not change the data model or existing records.",
                    de: "Messwerte, Gesundheitsberichte und Zustände verwenden derzeit die lokale Datenschutzeinstellung „Körper- & Gesundheitsdaten (früher Gewicht)“. Datenmodell und vorhandene Einträge bleiben unverändert."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                Color.goBlue.opacity(0.08),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("human-health-summary-body-privacy-disclosure")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill") // a11y: allow decorative privacy icon; adjacent text conveys the notice
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .accessibilityHidden(true)
                Text(l.tr(
                    zh: "Ohana 外部备份不包含人类健康、用药或 Apple Health 记录。重要医疗资料请另行妥善保存。",
                    en: "Ohana external backups exclude Human health, medication, and Apple Health records. Keep important medical documents separately.",
                    de: "Externe Ohana-Backups enthalten keine Gesundheits-, Medikamenten- oder Apple-Health-Daten. Wichtige medizinische Unterlagen separat aufbewahren."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                Color.ohanaControlFill,
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("human-health-summary-backup-boundary-notice")
        }
    }

    private func summaryNavigationRow(
        route: HumanHealthSummaryRoute,
        icon: String,
        tint: Color,
        title: String,
        value: String,
        detail: String,
        isLocked: Bool,
        identifier: String
    ) -> some View {
        NavigationLink {
            destinationView(route)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isLocked ? "lock.fill" : icon)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(isLocked ? Color.goYellow : tint)
                    .frame(width: 38, height: 38) // a11y: allow decorative glyph; the enclosing link has a 58pt minimum height
                    .background((isLocked ? Color.goYellow : tint).opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(detail)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(isLocked ? Color.ohanaTertiaryText : tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.right") // a11y: allow decorative navigation affordance; link text supplies the label
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 58)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private func recordRow(
        _ destination: HumanHealthSummaryDestination,
        value: String
    ) -> some View {
        NavigationLink {
            destinationView(.feature(destination))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.systemImage)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(destination.tint)
                    .frame(width: 34, height: 34) // a11y: allow decorative glyph; the enclosing link has a 52pt minimum height
                    .accessibilityHidden(true)
                Text(destination.title(l))
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Image(systemName: "chevron.right") // a11y: allow decorative navigation affordance; link text supplies the label
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 14)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("human-health-summary-record-\(destination.rawValue)")
    }

    private func sourceRow(
        icon: String,
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28) // a11y: allow decorative glyph; source row is non-interactive and combines its text
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(detail)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionHeading(
        _ title: String,
        subtitle: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(subtitle)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func inlineEmptyState(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color.goTeal)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.ohanaDivider)
            .frame(height: 1)
            .padding(.leading, 64)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func destinationView(_ route: HumanHealthSummaryRoute) -> some View {
        switch route {
        case let .feature(destination):
            switch destination {
            case .medication:
                HumanMedicationView(human: human)
            case .metrics:
                HumanHealthCheckupView(human: human)
            case .conditions:
                HumanHealthConditionsView(human: human, showsCloseButton: false)
            case .reports:
                HumanHealthReportView(human: human)
            case .weight:
                HumanWeightHistoryView(human: human)
            case .workouts:
                HumanWorkoutSummaryView(human: human)
            }
        case let .metric(metricKey):
            if let metric = HealthMetricCatalog.metric(forKey: metricKey) {
                HumanHealthMetricDetailView(human: human, metric: metric)
            } else {
                HumanHealthCheckupView(human: human)
            }
        }
    }

    private func savePinnedDestinations(_ values: [HumanHealthSummaryDestination]) {
        let normalized = HumanHealthSummaryPinPreference.normalized(values)
        pinnedDestinations = normalized
        let key = HumanHealthSummaryPinPreference.storageKey(humanID: human.id)
        UserDefaults.standard.set(
            HumanHealthSummaryPinPreference.encode(normalized),
            forKey: key
        )
    }
}

struct HumanHealthSummaryCompactCard: View {
    let snapshot: HumanHealthSummarySnapshot
    let onOpen: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.clipboard.fill") // a11y: allow decorative icon; button text supplies the label
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .foregroundStyle(Color.goTeal)
                        .frame(width: 38, height: 38) // a11y: allow decorative glyph; the enclosing card button has a larger hit target
                        .background(Color.goTeal.opacity(0.13), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "健康摘要", en: "Health Summary", de: "Gesundheitsübersicht"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "今天、重点、趋势与记录",
                            en: "Today, pinned items, trends, and records",
                            de: "Heute, Fixiertes, Trends und Einträge"
                        ))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right") // a11y: allow decorative navigation affordance; button text supplies the label
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .accessibilityHidden(true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        compactMetric(
                            value: medicationValue,
                            label: l.tr(zh: "今日待处理", en: "Due today", de: "Heute fällig"),
                            tint: medicationTint
                        )
                        compactDivider
                        compactMetric(
                            value: attentionValue,
                            label: l.tr(zh: "需复核", en: "Review", de: "Prüfen"),
                            tint: attentionTint
                        )
                        compactDivider
                        compactMetric(
                            value: followUpValue,
                            label: l.tr(zh: "复查", en: "Follow-up", de: "Kontrolle"),
                            tint: .goBlue
                        )
                    }

                    VStack(spacing: 8) {
                        compactHorizontalMetric(
                            value: medicationValue,
                            label: l.tr(zh: "今日待处理", en: "Due today", de: "Heute fällig")
                        )
                        compactHorizontalMetric(
                            value: attentionValue,
                            label: l.tr(zh: "需复核", en: "Review", de: "Prüfen")
                        )
                        compactHorizontalMetric(
                            value: followUpValue,
                            label: l.tr(zh: "复查", en: "Follow-up", de: "Kontrolle")
                        )
                    }
                }
            }
            .padding(14)
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("human-detail-health-summary-action")
    }

    private var medicationValue: String {
        guard snapshot.medicationIsVisible else { return "—" }
        if snapshot.medicationScheduleIsIncomplete {
            return snapshot.pendingDoseCount > 0
                ? "\(snapshot.pendingDoseCount)+"
                : incompleteCompactValue
        }
        return "\(snapshot.pendingDoseCount)"
    }

    private var attentionValue: String {
        guard snapshot.bodyIsVisible else { return "—" }
        if snapshot.metricLogsAreTruncated {
            return snapshot.abnormalMetrics.isEmpty
                ? incompleteCompactValue
                : "\(snapshot.abnormalMetrics.count)+"
        }
        return "\(snapshot.abnormalMetrics.count)"
    }

    private var followUpValue: String {
        guard snapshot.bodyIsVisible else { return "—" }
        switch snapshot.followUpStatus {
        case let .attention(followUp):
            if followUp.timing.isOverdue {
                return l.tr(zh: "逾期", en: "Overdue", de: "Überfällig")
            }
            return followUp.date.formatted(.dateTime.month().day())
        case .incomplete:
            return incompleteCompactValue
        case .none:
            return "—"
        }
    }

    private var medicationTint: Color {
        if snapshot.medicationScheduleIsIncomplete,
           snapshot.pendingDoseCount == 0 {
            return .goBlue
        }
        return snapshot.pendingDoseCount > 0 ? .goOrange : .goTeal
    }

    private var attentionTint: Color {
        if snapshot.metricLogsAreTruncated,
           snapshot.abnormalMetrics.isEmpty {
            return .goBlue
        }
        return snapshot.abnormalMetrics.isEmpty ? .goTeal : .goOrange
    }

    private var incompleteCompactValue: String {
        l.tr(zh: "未完整", en: "Partial", de: "Teilw.")
    }

    private func compactMetric(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactHorizontalMetric(value: String, label: String) -> some View {
        HStack {
            Text(label)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private var compactDivider: some View {
        Rectangle()
            .fill(Color.ohanaDivider)
            .frame(width: 1, height: 34) // a11y: allow non-interactive visual divider
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private extension HumanHealthSummaryView {
    func medicationTodayValue(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.medicationIsVisible else { return l.tr(zh: "已隐藏", en: "Hidden", de: "Ausgeblendet") }
        if snapshot.medicationScheduleIsIncomplete {
            return snapshot.pendingDoseCount > 0
                ? "\(snapshot.pendingDoseCount)+"
                : l.tr(zh: "未完整", en: "Incomplete", de: "Unvollständig")
        }
        if snapshot.scheduledDoseCount == 0 {
            return l.tr(zh: "无计划", en: "None", de: "Keine")
        }
        if snapshot.pendingDoseCount == 0 {
            return l.tr(zh: "已处理", en: "Handled", de: "Erledigt")
        }
        return l.tr(
            zh: "\(snapshot.pendingDoseCount) 次",
            en: "\(snapshot.pendingDoseCount) due",
            de: "\(snapshot.pendingDoseCount) fällig"
        )
    }

    func medicationTodayDetail(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.medicationIsVisible else { return privateDetail }
        if snapshot.medicationScheduleIsIncomplete {
            return l.tr(
                zh: "今日计划或日志超过显示上限；仅显示已载入部分，不能据此判断全部剂量已处理",
                en: "Today's plans or logs exceed the display limit; loaded data is partial and cannot establish that every dose is handled",
                de: "Heutige Pläne oder Einträge überschreiten das Anzeigelimit; die geladenen Daten sind unvollständig und bestätigen nicht, dass alle Dosen erledigt sind"
            )
        }
        guard let dose = snapshot.nextPendingDose else {
            return snapshot.scheduledDoseCount == 0
                ? l.tr(zh: "今天没有定时用药", en: "No scheduled doses today", de: "Heute keine geplanten Dosen")
                : l.tr(zh: "今天的定时用药均已处理", en: "All scheduled doses are handled", de: "Alle geplanten Dosen sind erledigt")
        }
        let time = dose.scheduledTime.formatted(.dateTime.hour().minute())
        return dose.name.isEmpty ? time : "\(dose.name) · \(time)"
    }

    func metricTodayValue(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.bodyIsVisible else { return l.tr(zh: "已隐藏", en: "Hidden", de: "Ausgeblendet") }
        if snapshot.metricLogsAreTruncated,
           snapshot.abnormalMetrics.isEmpty {
            return l.tr(zh: "未完整", en: "Incomplete", de: "Unvollständig")
        }
        if snapshot.latestMetricCount == 0 {
            return l.tr(zh: "无记录", en: "No logs", de: "Keine")
        }
        if snapshot.abnormalMetrics.isEmpty {
            return l.tr(zh: "无待复核", en: "No review", de: "Nichts zu prüfen")
        }
        if snapshot.metricLogsAreTruncated {
            return "\(snapshot.abnormalMetrics.count)+"
        }
        return l.tr(
            zh: "\(snapshot.abnormalMetrics.count) 项",
            en: "\(snapshot.abnormalMetrics.count) to review",
            de: "\(snapshot.abnormalMetrics.count) zu prüfen"
        )
    }

    func metricTodayDetail(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.bodyIsVisible else { return privateDetail }
        if snapshot.metricLogsAreTruncated {
            return l.tr(
                zh: "仅检查最近载入的 256 条指标记录；结果不完整，不能据此判断没有待复核标记",
                en: "Only the latest 256 metric logs were checked; the result is incomplete and cannot establish that no review flags exist",
                de: "Nur die letzten 256 Werteinträge wurden geprüft; das Ergebnis ist unvollständig und belegt nicht, dass keine Prüfmarkierungen vorliegen"
            )
        }
        guard let first = snapshot.abnormalMetrics.first else {
            return snapshot.latestMetricCount == 0
                ? l.tr(zh: "添加或扫描化验结果", en: "Add or scan lab results", de: "Laborwerte hinzufügen oder scannen")
                : l.tr(zh: "按每项最新记录计算", en: "Based on each metric’s latest log", de: "Basierend auf dem letzten Eintrag je Wert")
        }
        return metricTitle(first.metricKey)
    }

    func followUpValue(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.bodyIsVisible else { return l.tr(zh: "已隐藏", en: "Hidden", de: "Ausgeblendet") }
        switch snapshot.followUpStatus {
        case let .attention(followUp):
            if case let .overdue(days) = followUp.timing {
                return l.tr(
                    zh: "逾期 \(days) 天",
                    en: "\(days)d overdue",
                    de: "\(days) T. überfällig"
                )
            }
            return followUp.date.formatted(.dateTime.month().day())
        case .incomplete:
            return l.tr(zh: "未完整", en: "Incomplete", de: "Unvollständig")
        case .none:
            return l.tr(zh: "暂无", en: "None", de: "Keine")
        }
    }

    func followUpDetail(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.bodyIsVisible else { return privateDetail }
        switch snapshot.followUpStatus {
        case let .attention(followUp):
            let type = reportTypeTitle(followUp.reportTypeRaw)
            if followUp.timing.isOverdue {
                return "\(type) · \(followUp.date.formatted(.dateTime.year().month().day()))"
            }
            return type
        case .incomplete:
            return l.tr(
                zh: "仅检查最近载入的报告；更早的报告类型可能未包含，不能断言没有复查安排",
                en: "Only recently loaded reports were checked; older report types may be missing, so no-follow-up cannot be established",
                de: "Nur zuletzt geladene Berichte wurden geprüft; ältere Berichtstypen können fehlen, daher ist „keine Kontrolle“ nicht belegt"
            )
        case .none:
            return l.tr(zh: "每种报告仅按最新一份检查；没有逾期或未来 30 天复查记录", en: "Checked the latest report of each type; no overdue or next-30-day follow-up is recorded", de: "Je Berichtstyp wurde nur der neueste geprüft; keine überfällige oder in 30 Tagen anstehende Kontrolle")
        }
    }

    func observationValue(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.bodyIsVisible else { return l.tr(zh: "已隐藏", en: "Hidden", de: "Ausgeblendet") }
        guard let observation = snapshot.recentObservation else {
            return l.tr(zh: "暂无", en: "None", de: "Keine")
        }
        return l.tr(
            zh: "强度 \(observation.severity)/10",
            en: "Impact \(observation.severity)/10",
            de: "Belastung \(observation.severity)/10"
        )
    }

    func observationDetail(_ snapshot: HumanHealthSummarySnapshot) -> String {
        guard snapshot.bodyIsVisible else { return privateDetail }
        guard let observation = snapshot.recentObservation else {
            return snapshot.observationsAreTruncated
                ? l.tr(zh: "最近载入的记录中没有近 14 天状态", en: "No state from the past 14 days in recently loaded logs", de: "Keine Zustände der letzten 14 Tage in den zuletzt geladenen Einträgen")
                : l.tr(zh: "近 14 天没有状态记录", en: "No state log in the past 14 days", de: "Kein Zustandseintrag in den letzten 14 Tagen")
        }
        let name = observation.conditionName.isEmpty
            ? l.tr(zh: "状态记录", en: "State log", de: "Zustandseintrag")
            : observation.conditionName
        return "\(name) · \(observation.recordedAt.formatted(.dateTime.month().day()))"
    }

    func destinationValue(
        _ destination: HumanHealthSummaryDestination,
        snapshot: HumanHealthSummarySnapshot
    ) -> String {
        switch destination {
        case .medication:
            guard snapshot.medicationIsVisible else { return "—" }
            if snapshot.medicationScheduleIsIncomplete {
                return snapshot.pendingDoseCount > 0
                    ? "\(snapshot.pendingDoseCount)+"
                    : l.tr(zh: "未完整", en: "Incomplete", de: "Unvollständig")
            }
            return "\(snapshot.pendingDoseCount)"
        case .metrics:
            guard snapshot.bodyIsVisible else { return "—" }
            return boundedCountText(snapshot.recordCounts.trackedMetrics)
        case .conditions:
            guard snapshot.bodyIsVisible else { return "—" }
            return boundedCountText(snapshot.recordCounts.activeConditions)
        case .reports:
            guard snapshot.bodyIsVisible else { return "—" }
            return boundedCountText(snapshot.recordCounts.reports)
        case .weight:
            guard snapshot.bodyIsVisible else { return "—" }
            return l.tr(zh: "趋势", en: "Trend", de: "Trend")
        case .workouts:
            guard snapshot.workoutIsVisible else { return "—" }
            switch snapshot.sourceState {
            case .appleHealthBound:
                return l.tr(zh: "已绑定", en: "Bound", de: "Verbunden")
            case .localOnly:
                return l.tr(zh: "本机", en: "Local", de: "Lokal")
            case .hidden, .unavailable:
                return l.tr(zh: "不可用", en: "Unavailable", de: "Nicht verfügbar")
            }
        }
    }

    func destinationDetail(
        _ destination: HumanHealthSummaryDestination,
        snapshot: HumanHealthSummarySnapshot
    ) -> String {
        switch destination {
        case .medication:
            snapshot.medicationIsVisible
                ? l.tr(zh: "今日待处理", en: "Due today", de: "Heute fällig")
                : privateDetail
        case .metrics:
            snapshot.bodyIsVisible
                ? l.tr(zh: "已追踪指标", en: "Tracked metrics", de: "Erfasste Werte")
                : privateDetail
        case .conditions:
            snapshot.bodyIsVisible
                ? l.tr(zh: "正在关注", en: "Actively tracked", de: "Aktiv beobachtet")
                : privateDetail
        case .reports:
            snapshot.bodyIsVisible
                ? l.tr(zh: "报告与复查", en: "Reports and follow-ups", de: "Berichte und Kontrollen")
                : privateDetail
        case .weight:
            snapshot.bodyIsVisible
                ? l.tr(zh: "体重记录", en: "Weight records", de: "Gewichtseinträge")
                : privateDetail
        case .workouts:
            snapshot.workoutIsVisible
                ? l.tr(zh: "运动与 Apple Health", en: "Workouts & Apple Health", de: "Training & Apple Health")
                : privateDetail
        }
    }

    func highlightIcon(_ highlight: HumanHealthSummaryHighlight) -> String {
        switch highlight {
        case .dosesRemaining: "pills.fill"
        case .dosesHandled: "checkmark.circle.fill"
        case .latestMetricsWithoutReviewFlag: "checkmark.seal.fill"
        case .latestMetricsNeedReview: "exclamationmark.triangle.fill"
        case .metricReviewIncomplete: "ellipsis.circle.fill"
        case .recentObservation: "heart.text.clipboard.fill"
        case .followUp: "calendar.badge.clock"
        }
    }

    func highlightTint(_ highlight: HumanHealthSummaryHighlight) -> Color {
        switch highlight {
        case .dosesRemaining, .latestMetricsNeedReview: .goOrange
        case .dosesHandled, .latestMetricsWithoutReviewFlag, .recentObservation: .goTeal
        case .metricReviewIncomplete: .goBlue
        case let .followUp(followUp): followUp.timing.isOverdue ? .goOrange : .goBlue
        }
    }

    func highlightText(_ highlight: HumanHealthSummaryHighlight) -> String {
        switch highlight {
        case let .dosesRemaining(count):
            l.tr(zh: "今天还有 \(count) 次定时用药待处理。", en: "\(count) scheduled dose(s) still need handling today.", de: "Heute sind noch \(count) geplante Dosis/Dosen offen.")
        case let .dosesHandled(count):
            l.tr(zh: "今天的 \(count) 次定时用药均已处理。", en: "All \(count) scheduled dose(s) are handled today.", de: "Alle \(count) geplanten Dosis/Dosen sind heute erledigt.")
        case let .latestMetricsWithoutReviewFlag(count):
            l.tr(zh: "已追踪的 \(count) 项最新指标没有偏高或偏低复核标记。未知参考范围不等于正常。", en: "The latest logs for \(count) tracked metric(s) have no high or low review flag. An unknown range does not mean normal.", de: "Die letzten Einträge für \(count) Wert(e) haben keine Hoch-/Niedrig-Markierung. Ein unbekannter Bereich bedeutet nicht normal.")
        case let .latestMetricsNeedReview(count):
            l.tr(zh: "有 \(count) 项最新指标带偏高或偏低标记，请对照原报告复核。", en: "\(count) latest metric(s) carry a high or low flag; review the original report.", de: "\(count) aktuelle Wert(e) sind als hoch oder niedrig markiert; Originalbericht prüfen.")
        case let .metricReviewIncomplete(count):
            if count > 0 {
                l.tr(
                    zh: "只载入了最近记录中的 \(count) 项指标；复核结果不完整，不能据此判断其余记录没有标记。",
                    en: "Only \(count) metric(s) from the recently loaded logs were checked; review is incomplete and cannot clear the remaining history.",
                    de: "Nur \(count) Wert(e) aus den zuletzt geladenen Einträgen wurden geprüft; die Prüfung ist unvollständig und entlastet den übrigen Verlauf nicht."
                )
            } else {
                l.tr(
                    zh: "指标记录载入不完整，不能据此判断没有偏高或偏低复核标记。",
                    en: "Metric history is incompletely loaded, so the absence of high or low review flags cannot be established.",
                    de: "Der Werteverlauf ist unvollständig geladen; das Fehlen von Hoch-/Niedrig-Markierungen ist daher nicht belegt."
                )
            }
        case let .recentObservation(observation):
            l.tr(zh: "最近一次状态记录强度为 \(observation.severity)/10。", en: "The latest condition-state log records impact at \(observation.severity)/10.", de: "Der letzte Zustandseintrag erfasst eine Belastung von \(observation.severity)/10.")
        case let .followUp(followUp):
            if case let .overdue(days) = followUp.timing {
                l.tr(
                    zh: "一项复查已逾期 \(days) 天，请核对原报告和实际安排。",
                    en: "A follow-up is \(days) day(s) overdue; check the original report and actual plan.",
                    de: "Eine Kontrolle ist seit \(days) Tag(en) überfällig; Originalbericht und tatsächlichen Plan prüfen."
                )
            } else {
                l.tr(
                    zh: "复查记录在 \(followUp.date.formatted(.dateTime.year().month().day()))。",
                    en: "A follow-up is recorded for \(followUp.date.formatted(.dateTime.year().month().day())).",
                    de: "Eine Kontrolle ist für den \(followUp.date.formatted(.dateTime.year().month().day())) erfasst."
                )
            }
        }
    }

    func trendIcon(_ direction: HumanHealthSummaryTrendDirection) -> String {
        switch direction {
        case .rising: "arrow.up.right"
        case .steady: "arrow.right"
        case .falling: "arrow.down.right"
        }
    }

    func trendTint(_ trend: HumanHealthSummaryTrend) -> Color {
        trend.status.needsReview ? .goOrange : .goTeal
    }

    func trendDelta(_ trend: HumanHealthSummaryTrend) -> String {
        guard let metric = HealthMetricCatalog.metric(forKey: trend.metricKey),
              let unit = metric.unit(for: trend.unitCode) else { return "—" }
        let delta = trend.currentValue - trend.previousValue
        let value = unit.formatted(delta)
        return delta > 0 ? "+\(value) \(unit.label)" : "\(value) \(unit.label)"
    }

    func metricTitle(_ key: String) -> String {
        HealthMetricCatalog.metric(forKey: key)?.displayName(l) ?? key
    }

    func metricValue(_ value: Double, metricKey: String, unitCode: String) -> String {
        guard let metric = HealthMetricCatalog.metric(forKey: metricKey),
              let unit = metric.unit(for: unitCode) else { return "—" }
        return unit.formattedValue(value)
    }

    func reportTypeTitle(_ rawValue: String) -> String {
        HealthReportType(rawValue: rawValue)?.localizedTitle(l)
            ?? l.tr(zh: "健康报告", en: "Health report", de: "Gesundheitsbericht")
    }

    func appleHealthSourceDetail(_ state: HumanHealthSummarySourceState) -> String {
        switch state {
        case .hidden:
            privateDetail
        case .unavailable:
            l.tr(zh: "当前档案不可读取", en: "Unavailable for this profile", de: "Für dieses Profil nicht verfügbar")
        case .localOnly:
            l.tr(zh: "未绑定；可在运动页设置", en: "Not bound; set up in Workouts", de: "Nicht verbunden; unter Training einrichten")
        case .appleHealthBound:
            l.tr(zh: "已绑定此成员；在运动页管理", en: "Bound to this member; manage in Workouts", de: "Mit diesem Mitglied verbunden; unter Training verwalten")
        }
    }

    var privateDetail: String {
        l.tr(zh: "当前查看者不可见", en: "Hidden from the current viewer", de: "Für die aktuelle Person ausgeblendet")
    }

    func boundedCountText(_ count: HumanHealthSummaryBoundedCount) -> String {
        guard count.isTruncated else { return "\(count.loaded)" }
        return count.loaded > 0
            ? "\(count.loaded)+"
            : l.tr(zh: "未完整", en: "Incomplete", de: "Unvollständig")
    }
}

extension HumanHealthSummaryDestination {
    func title(_ l: L10n) -> String {
        switch self {
        case .medication: l.tr(zh: "用药", en: "Medication", de: "Medikamente")
        case .metrics: l.tr(zh: "体检指标", en: "Metrics", de: "Messwerte")
        case .conditions: l.tr(zh: "健康状况", en: "Conditions", de: "Zustände")
        case .reports: l.tr(zh: "健康报告", en: "Reports", de: "Berichte")
        case .weight: l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .workouts: l.tr(zh: "运动", en: "Workouts", de: "Training")
        }
    }

    var systemImage: String {
        switch self {
        case .medication: "pills.fill"
        case .metrics: "waveform.path.ecg.rectangle.fill"
        case .conditions: "heart.text.clipboard.fill"
        case .reports: "doc.text.magnifyingglass"
        case .weight: "scalemass.fill"
        case .workouts: "figure.run"
        }
    }

    var tint: Color {
        switch self {
        case .medication: .goPurple
        case .metrics: .goTeal
        case .conditions: .goOrange
        case .reports: .goBlue
        case .weight: .goTeal
        case .workouts: .goRed
        }
    }
}
