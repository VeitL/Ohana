//
//  QuickPottyDetailSheet+Sheets.swift
//  Ohana
//

import SwiftUI

extension QuickPottyDetailSheet {
    // MARK: - Sheets
    @ViewBuilder
    func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .pottyType:
            PottyTypeSheet(
                tint: pottyTint,
                unknownGroupTitle: sameSpeciesPottyPets.count > 1 ? l.tr(zh: "猫砂盆未知噗噗", en: "Mystery litter-box poop", de: "Unbekanntes Klo-Häufchen") : nil,
                onUnknownGroup: sameSpeciesPottyPets.count > 1 ? {
                    logUnknownGroupPotty()
                    dismissInlinePoopSheet()
                } : nil
            ) { type in
                logPotty(type: type)
                dismissInlinePoopSheet()
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 350,
                maxHeight: 620,
                chromePadding: 70
            )
        case .scoopCheckIn:
            VStack(spacing: 12) {
                if sameSpeciesPottyPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "共同铲砂", en: "Scoop together", de: "Gemeinsam reinigen"),
                        subtitle: petCountText(selectedPottyTargets.count, species: pet.species),
                        pets: sameSpeciesPottyPets,
                        selectedPetIds: $selectedSharedPottyPetIds,
                        tint: scoopTint,
                        fixedPetId: pet.id
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
                PoopCheckInSheet(
                    tint: scoopTint,
                    icon: "trash.fill",
                    title: l.tr(zh: "铲砂打卡", en: "Scoop check-in", de: "Klo-Check-in"),
                    value: dueText(daysUntil: daysUntilScoop),
                    subtitle: scoopSubtitle,
                    primaryTitle: scoopNeedsCatchUp ? l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen") : (todayLitterLogs.isEmpty ? l.tr(zh: "完成铲砂", en: "Scoop done", de: "Klo sauber") : l.tr(zh: "今天已完成", en: "Done today", de: "Heute erledigt")),
                    secondaryTitle: l.tr(zh: "编辑计划", en: "Edit plan", de: "Plan ändern"),
                    isPrimaryDisabled: !todayLitterLogs.isEmpty && daysUntilScoop >= 0,
                    primaryAccessibilityIdentifier: "quick-potty-scoop-confirm-action",
                    secondaryAccessibilityIdentifier: "quick-potty-scoop-edit-plan-action",
                    primaryAction: {
                        recordScoop()
                        dismissInlinePoopSheet()
                    },
                    secondaryAction: {
                        openPottySheet(.scoopSettings)
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesPottyPets.count > 1 ? 430 : 330,
                maxHeight: 620,
                chromePadding: 70
            )
        case .litterChangeCheckIn:
            VStack(spacing: 12) {
                if sameSpeciesPottyPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "共同换砂", en: "Change together", de: "Gemeinsam wechseln"),
                        subtitle: petCountText(selectedPottyTargets.count, species: pet.species),
                        pets: sameSpeciesPottyPets,
                        selectedPetIds: $selectedSharedPottyPetIds,
                        tint: litterTint,
                        fixedPetId: pet.id
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
                PoopCheckInSheet(
                    tint: litterTint,
                    icon: "tray.full.fill",
                    title: l.tr(zh: "换猫砂", en: "Change litter", de: "Streu wechseln"),
                    value: dueText(daysUntil: daysUntilLitterChange),
                    subtitle: litterChangeSubtitle,
                    primaryTitle: l.tr(zh: "记录换砂", en: "Log change", de: "Wechsel loggen"),
                    secondaryTitle: l.tr(zh: "编辑计划", en: "Edit plan", de: "Plan ändern"),
                    isPrimaryDisabled: false,
                    primaryAccessibilityIdentifier: "quick-potty-litter-confirm-action",
                    secondaryAccessibilityIdentifier: "quick-potty-litter-edit-plan-action",
                    primaryAction: {
                        doFullChange()
                        dismissInlinePoopSheet()
                    },
                    secondaryAction: {
                        openPottySheet(.litterSettings)
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesPottyPets.count > 1 ? 430 : 330,
                maxHeight: 620,
                chromePadding: 70
            )
        case .scoopSettings:
            PoopCycleSettingsSheet(
                tint: scoopTint,
                icon: "trash.fill",
                title: l.tr(zh: "铲砂计划", en: "Scoop plan", de: "Klo-Plan"),
                subtitle: l.tr(zh: "编辑 \(pet.name) 的铲砂周期", en: "Edit \(pet.name)'s scoop rhythm", de: "\(pet.name)s Klo-Rhythmus ändern"),
                statusTitle: scoopReminderOn ? l.tr(zh: "提醒已开启", en: "Reminder on", de: "Erinnerung an") : l.tr(zh: "仅本地记录", en: "Local only", de: "Nur lokal"),
                statusValue: dueText(daysUntil: daysUntilScoop),
                statusDetail: "\(scoopPlanDetail) · \(scoopLastActionText)",
                intervalRange: 1 ... 14,
                intervalDays: $scoopIntervalDays,
                anchorDate: $scoopAnchorDate,
                reminderOn: $scoopReminderOn,
                accessibilityIDPrefix: "quick-potty-scoop-settings",
                onSave: {
                    startPottyPlanSave {
                        syncScoopPlan(showToast: true)
                    }
                },
                onDelete: {
                    startPottyPlanSave {
                        deleteScoopPlan()
                    }
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 460,
                maxHeight: 720,
                chromePadding: 70
            )
        case .litterSettings:
            PoopCycleSettingsSheet(
                tint: litterTint,
                icon: "tray.full.fill",
                title: l.tr(zh: "换猫砂计划", en: "Litter-change plan", de: "Streuwechsel-Plan"),
                subtitle: l.tr(zh: "编辑 \(pet.name) 的整盆换砂周期", en: "Edit \(pet.name)'s full litter-change rhythm", de: "\(pet.name)s Streuwechsel-Rhythmus ändern"),
                statusTitle: litterReminderOn ? l.tr(zh: "提醒已开启", en: "Reminder on", de: "Erinnerung an") : l.tr(zh: "仅本地记录", en: "Local only", de: "Nur lokal"),
                statusValue: dueText(daysUntil: daysUntilLitterChange),
                statusDetail: "\(litterPlanDetail) · \(litterLastActionText)",
                intervalRange: 3 ... 60,
                intervalDays: $litterChangeIntervalDays,
                anchorDate: $litterCycleAnchorDate,
                reminderOn: $litterReminderOn,
                accessibilityIDPrefix: "quick-potty-litter-settings",
                onSave: {
                    startPottyPlanSave {
                        syncLitterChangePlan(showToast: true)
                    }
                },
                onDelete: {
                    startPottyPlanSave {
                        deleteLitterChangePlan()
                    }
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 460,
                maxHeight: 720,
                chromePadding: 70
            )
        case .pottyOverview:
            pottyOverviewSheet
        case .scoopOverview:
            scoopOverviewSheet
        case .litterOverview:
            litterOverviewSheet
        case .pottyHistory:
            PoopHistorySheet(
                title: l.tr(zh: "噗噗历史", en: "Poop history", de: "Häufchen-Verlauf"),
                items: pottyHistoryItems,
                tintForItem: tint(for:),
                claimTargets: sameSpeciesPottyPets,
                onClaim: claimUnknownPotty,
                onDelete: deleteItem
            )
        case .scoopHistory:
            PoopHistorySheet(
                title: l.tr(zh: "铲砂历史", en: "Scoop history", de: "Klo-Verlauf"),
                items: litterLogs.map(PoopLogItem.litter),
                tintForItem: tint(for:),
                onDelete: deleteItem
            )
        case .litterHistory:
            litterHistorySheet
        case .history:
            PoopHistorySheet(
                title: l.tr(zh: "噗噗节目单", en: "Poop Radio log", de: "Häufchen-Radio-Log"),
                items: recentItems,
                tintForItem: tint(for:),
                claimTargets: sameSpeciesPottyPets,
                onClaim: claimUnknownPotty,
                onDelete: deleteItem
            )
        }
    }

    var pottyOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                poopOverviewRangePicker(tint: pottyTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: l.tr(zh: "今日次数", en: "Today", de: "Heute"), value: "\(todayPottyLogs.count)", icon: "number.circle.fill", tint: pottyTint)
                    poopOverviewMetric(title: l.tr(zh: "留意比例", en: "Watch rate", de: "Auffällig"), value: "\(Int(last7AbnormalRatio * 100))%", icon: "exclamationmark.triangle.fill", tint: last7AbnormalRatio > 0.3 ? Color.goRed : pottyTint)
                }
                poopOverviewLineChart(
                    title: l.tr(zh: "噗噗趋势", en: "Poop trend", de: "Häufchen-Trend"),
                    subtitle: l.tr(zh: "按天统计次数。", en: "Daily count.", de: "Tageszahlen."),
                    points: pottyChartPoints,
                    tint: pottyTint,
                    emptyText: l.tr(zh: "记录噗噗后会出现趋势", en: "Log poop to see the trend", de: "Logge Häufchen für den Trend")
                )
                overviewSectionHeader(l.tr(zh: "类型", en: "Types", de: "Typen"))
                ForEach(pottyTypeSummaries) { summary in
                    poopSummaryRow(icon: summary.icon, title: summary.title, value: timesText(summary.count), tint: summary.tint)
                }
                overviewSectionHeader(l.tr(zh: "最近噗噗", en: "Latest poop", de: "Neueste Häufchen"))
                if pottyHistoryItems.isEmpty {
                    emptyInlineState(icon: "seal", text: l.tr(zh: "还没有噗噗记录", en: "No poop logs yet", de: "Noch keine Häufchen"))
                } else {
                    ForEach(Array(pottyHistoryItems.prefix(8))) { item in
                        PoopLogRow(
                            item: item,
                            tint: tint(for: item),
                            showDelete: true,
                            claimTargets: sameSpeciesPottyPets,
                            onClaim: claimUnknownPotty
                        ) {
                            deleteItem(item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var scoopOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                poopOverviewRangePicker(tint: scoopTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: l.tr(zh: "今日", en: "Today", de: "Heute"), value: todayLitterLogs.isEmpty ? l.tr(zh: "未完成", en: "Open", de: "Offen") : l.tr(zh: "已完成", en: "Done", de: "Erledigt"), icon: "checkmark.seal.fill", tint: scoopTint)
                    poopOverviewMetric(title: l.tr(zh: "下次", en: "Next", de: "Nächstes"), value: dueText(daysUntil: daysUntilScoop), icon: "calendar", tint: daysUntilScoop < 0 ? Color.goRed : scoopTint)
                }
                poopProgressBlock(title: l.tr(zh: "铲砂周期", en: "Scoop rhythm", de: "Klo-Rhythmus"), elapsed: scoopElapsedDays, interval: scoopIntervalDays, tint: scoopTint)
                poopOverviewLineChart(
                    title: l.tr(zh: "铲砂记录", en: "Scoop logs", de: "Klo-Einträge"),
                    subtitle: l.tr(zh: "按天统计铲砂次数。", en: "Daily scoop count.", de: "Reinigungen pro Tag."),
                    points: scoopChartPoints,
                    tint: scoopTint,
                    emptyText: l.tr(zh: "铲砂后会出现趋势", en: "Scoop to see the trend", de: "Reinigen zeigt den Trend")
                )
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: scoopDoneToday ? l.tr(zh: "今天已完成", en: "Done today", de: "Heute erledigt") : scoopPrimaryTitle, icon: "checkmark", tint: scoopTint, isDisabled: scoopDoneToday) {
                        openPottySheet(.scoopCheckIn)
                    }
                    Button {
                        openPottySheet(.scoopSettings)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(scoopTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近铲砂", en: "Latest scoops", de: "Letzte Reinigungen"))
                if litterLogs.isEmpty {
                    emptyInlineState(icon: "trash", text: l.tr(zh: "还没有铲砂记录", en: "No scoop logs yet", de: "Noch keine Klo-Einträge"))
                } else {
                    ForEach(Array(litterLogs.prefix(8)).map(PoopLogItem.litter)) { item in
                        PoopLogRow(item: item, tint: scoopTint, showDelete: true) {
                            deleteItem(item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var litterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    poopOverviewMetric(title: l.tr(zh: "周期", en: "Cycle", de: "Rhythmus"), value: dayCountText(litterChangeIntervalDays), icon: "repeat", tint: litterTint)
                    poopOverviewMetric(title: l.tr(zh: "下次", en: "Next", de: "Nächstes"), value: dueText(daysUntil: daysUntilLitterChange), icon: "calendar", tint: daysUntilLitterChange < 0 ? Color.goRed : litterTint)
                }
                poopProgressBlock(title: l.tr(zh: "换砂周期", en: "Litter rhythm", de: "Streu-Rhythmus"), elapsed: litterElapsedDays, interval: litterChangeIntervalDays, tint: litterTint)
                HStack(spacing: 10) {
                    PoopPrimaryButton(title: litterPrimaryTitle, icon: "arrow.2.circlepath", tint: litterTint) {
                        openPottySheet(.litterChangeCheckIn)
                    }
                    Button {
                        openPottySheet(.litterSettings)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(litterTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近换砂", en: "Latest changes", de: "Letzte Wechsel"))
                litterHistorySheetContent
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var litterHistorySheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                litterHistorySheetContent
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    @ViewBuilder
    var litterHistorySheetContent: some View {
        if let lastFullChange {
            HStack(spacing: 10) {
                Image(systemName: "tray.full.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(litterTint)
                    .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(litterTint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "整盆换砂", en: "Full litter change", de: "Kompletter Streuwechsel"))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(relativeDayText(for: lastFullChange))
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(lastFullChange, format: .dateTime.month().day().hour().minute())
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.vertical, 3)
        } else {
            emptyInlineState(icon: "tray", text: l.tr(zh: "还没有换砂记录", en: "No litter changes yet", de: "Noch kein Streuwechsel"))
        }
    }

    func poopOverviewHero(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 24, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    func poopOverviewRangePicker(tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(PoopOverviewRange.allCases) { range in
                Button {
                    withAnimation(GoMotion.page) {
                        overviewRange = range
                        overviewChartProgress = 0
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        withAnimation(GoMotion.page) {
                            overviewChartProgress = 1
                        }
                    }
                } label: {
                    Text(range.title(l))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(overviewRange == range ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(overviewRange == range ? tint : Color.ohanaControlFill.opacity(0.5), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    func pottySheetTopChrome(_ sheet: ActiveSheet) -> some View {
        HStack(spacing: 12) {
            pottySheetChromeTitle(sheet)
            Spacer(minLength: 12)
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                closeActivePottySheet()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    @ViewBuilder
    func pottySheetChromeTitle(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .pottyOverview:
            pottySheetChromeTitleContent(icon: "seal.fill", title: l.tr(zh: "噗噗总览", en: "Poop overview", de: "Häufchen-Überblick"), tint: pottyTint)
        case .scoopOverview:
            pottySheetChromeTitleContent(icon: "trash.fill", title: l.tr(zh: "铲砂总览", en: "Scoop overview", de: "Klo-Überblick"), tint: scoopTint)
        case .litterOverview:
            pottySheetChromeTitleContent(icon: "tray.full.fill", title: l.tr(zh: "猫砂总览", en: "Litter overview", de: "Streu-Überblick"), tint: litterTint)
        case .litterHistory:
            pottySheetChromeTitleContent(icon: "tray.full.fill", title: l.tr(zh: "换砂历史", en: "Litter history", de: "Streu-Verlauf"), tint: litterTint)
        default:
            EmptyView()
        }
    }

    func pottySheetChromeTitleContent(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 30, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(title)
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    func poopOverviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func poopOverviewLineChart(title: String, subtitle: String, points: [PoopChartPoint], tint: Color, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(subtitle)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)

            if points.allSatisfy({ $0.value <= 0 }) {
                emptyInlineState(icon: "chart.line.uptrend.xyaxis", text: emptyText)
                    .frame(height: 160)
            } else {
                let yDomain = OhanaChartStyle.yDomain(values: points.map(\.value), includeZero: true)
                OhanaMinimalTrendChart(
                    points: points.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value) },
                    yDomain: yDomain,
                    tint: tint,
                    progress: overviewChartProgress
                )
                .frame(height: 128)
                .animation(GoMotion.page, value: overviewChartProgress)
            }
        }
        .padding(.vertical, 8)
    }

    func poopProgressBlock(title: String, elapsed: Int, interval: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(progressDaysText(elapsed: elapsed, interval: max(interval, 1)))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * cycleProgress(elapsed: elapsed, interval: interval))
                    }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    func overviewSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.top, 4)
    }

    func emptyInlineState(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(Color.ohanaSecondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    func poopSummaryRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint.opacity(0.14), in: Circle())
            Text(title)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    var pottyChartPoints: [PoopChartPoint] {
        let calendar = Calendar.current
        let dayCount = overviewRange.days
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let grouped = Dictionary(grouping: pottyLogs.filter { $0.date >= start }) { calendar.startOfDay(for: $0.date) }
        return (0 ..< dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return PoopChartPoint(date: date, value: Double(grouped[date]?.count ?? 0))
        }
    }

    var scoopChartPoints: [PoopChartPoint] {
        let calendar = Calendar.current
        let dayCount = overviewRange.days
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let grouped = Dictionary(grouping: litterLogs.filter { $0.date >= start }) { calendar.startOfDay(for: $0.date) }
        return (0 ..< dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return PoopChartPoint(date: date, value: Double(grouped[date]?.count ?? 0))
        }
    }

    var pottyTypeSummaries: [PoopTypeSummary] {
        PottyType.allCases.compactMap { type in
            let count = pottyLogs.count(where: { $0.pottyType == type })
            guard count > 0 else { return nil }
            return PoopTypeSummary(title: type.localizedLabel(l), icon: type.systemIconName, count: count, tint: pottyTypeColor(type))
        }
    }
}
