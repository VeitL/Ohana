//
//  QuickWaterDetailSheet+Sheets.swift
//  Ohana
//

import SwiftUI

extension QuickWaterDetailSheet {
    // MARK: - Sheets
    func waterSheetTitle(_ sheet: ActiveSheet) -> String {
        switch sheet {
        case .waterSettings: l.tr(zh: "换水计划", en: "Water change plan", de: "Wasserwechselplan")
        case .waterAmount: l.tr(zh: "默认水量", en: "Default amount", de: "Standardmenge")
        case .waterPlan: l.tr(zh: "喂水计划", en: "Water plan", de: "Trinkplan")
        case .filterSettings: l.tr(zh: "滤芯计划", en: "Filter plan", de: "Filterplan")
        case .history: l.tr(zh: "喂水记录", en: "Water history", de: "Trinkhistorie")
        case .waterOverview: l.tr(zh: "喂水总览", en: "Water overview", de: "Trinkübersicht")
        case .waterChangeOverview: l.tr(zh: "换水总览", en: "Water change overview", de: "Wasserwechsel-Übersicht")
        case .filterOverview: l.tr(zh: "滤芯总览", en: "Filter overview", de: "Filterübersicht")
        }
    }

    @ViewBuilder
    func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .waterSettings:
            WaterChangeSettingsSheet(
                tint: waterChangeTint,
                intervalDays: $waterIntervalDays,
                anchorDate: $waterChangeAnchorDate,
                reminderOn: $waterReminderOn,
                nextDateText: waterNextDateText,
                onSave: {
                    startWaterCalendarPlanSave {
                        saveWaterChangePlanToCalendar(toast: l.tr(zh: "已保存换水周期", en: "Water change cycle saved", de: "Wasserwechselzyklus gespeichert"))
                    }
                },
                onDelete: {
                    waterReminderOn = false
                    startWaterCalendarPlanSave {
                        saveWaterChangePlanToCalendar(toast: l.tr(zh: "已关闭换水提醒", en: "Water change reminder off", de: "Wasserwechselerinnerung aus"))
                    }
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 330,
                maxHeight: 560,
                chromePadding: 70
            )
        case .waterAmount:
            VStack(spacing: 12) {
                if sameSpeciesWaterPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "共同喂水", en: "Shared water", de: "Gemeinsames Trinken"),
                        subtitle: localizedPetCount(selectedWaterTargets.count, species: pet.species),
                        pets: sameSpeciesWaterPets,
                        selectedPetIds: $selectedSharedWaterPetIds,
                        tint: chromeTint,
                        fixedPetId: pet.id
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
                WaterAmountSettingsSheet(
                    tint: chromeTint,
                    amountEnabled: $waterAmountEnabled,
                    amountText: $waterAmountMlText,
                    onSave: {
                        persistWaterAmountSettings()
                        showSaveConfirmation(waterAmountEnabled ? l.tr(zh: "已保存默认水量", en: "Default water amount saved", de: "Standard-Trinkmenge gespeichert") : l.tr(zh: "已关闭默认水量", en: "Default water amount off", de: "Standard-Trinkmenge aus"))
                        dismissInlineWaterSheet()
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesWaterPets.count > 1 ? 420 : 320,
                maxHeight: 620,
                chromePadding: 70
            )
        case .waterPlan:
            VStack(spacing: 12) {
                if sameSpeciesWaterPets.count > 1 {
                    SharedCareTargetPicker(
                        title: l.tr(zh: "目标宠物", en: "Target pets", de: "Zieltiere"),
                        subtitle: localizedPetCount(selectedWaterTargets.count, species: pet.species),
                        pets: sameSpeciesWaterPets,
                        selectedPetIds: $selectedSharedWaterPetIds,
                        tint: Color.goTeal,
                        fixedPetId: pet.id
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
                WaterPlanSettingsSheet(
                    tint: Color.goTeal,
                    count: $waterPlanCount,
                    times: $waterPlanTimes,
                    completionText: waterRuleState.completionText,
                    onCountChange: syncWaterPlanTimesCount,
                    onSave: {
                        startWaterPlanSave()
                    },
                    onDelete: {
                        startWaterCalendarPlanSave {
                            deleteWaterPlanAndSwitchToManual()
                        }
                    }
                )
            }
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: sameSpeciesWaterPets.count > 1 ? 520 : 430,
                maxHeight: 620,
                chromePadding: 0
            )
        case .filterSettings:
            FilterSettingsSheet(
                tint: filterTint,
                cleanIntervalDays: $filterCleanIntervalDays,
                replaceIntervalDays: $filterReplaceIntervalDays,
                reminderOn: $filterReminderOn,
                nextCleanText: filterNextCleanText,
                nextReplaceText: filterNextReplaceText,
                onSave: {
                    startWaterCalendarPlanSave {
                        syncFilterPlan(showToast: true)
                    }
                },
                onDelete: {
                    filterReminderOn = false
                    startWaterCalendarPlanSave {
                        syncFilterPlan(showToast: true)
                    }
                }
            )
            .ohanaAdaptiveSheetContentHeight(
                $adaptiveSheetHeight,
                minHeight: 360,
                maxHeight: 620,
                chromePadding: 70
            )
        case .history:
            WaterHistorySheet(
                logs: allWaterLogs,
                tintForLog: tint(for:),
                onDelete: deleteLog
            )
        case .waterOverview:
            waterOverviewSheet
        case .waterChangeOverview:
            waterChangeOverviewSheet
        case .filterOverview:
            filterOverviewSheet
        }
    }

    var waterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewRangePicker(tint: waterMode == .reminder ? Color.goTeal : chromeTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: l.tr(zh: "今日次数", en: "Today count", de: "Heute Anzahl"), value: "\(todayWaterLogs.count)", icon: "number.circle.fill", tint: chromeTint)
                    overviewMetric(title: l.tr(zh: "今日水量", en: "Today amount", de: "Heute Menge"), value: todayWaterAmountText, icon: "drop.fill", tint: chromeTint)
                }
                overviewLineChart(
                    title: l.tr(zh: "饮水趋势", en: "Water trend", de: "Trinktrend"),
                    subtitle: waterAmountEnabled ? l.tr(zh: "按已记录 ml 聚合。", en: "Aggregated by logged ml.", de: "Nach eingetragenen ml aggregiert.") : l.tr(zh: "当前只记录次数。", en: "Currently tracking count only.", de: "Aktuell nur Anzahl erfasst."),
                    points: waterChartPoints,
                    tint: waterMode == .reminder ? Color.goTeal : chromeTint,
                    emptyText: l.tr(zh: "喂水后会出现趋势", en: "Trends appear after water logs", de: "Trends erscheinen nach Trinkeinträgen")
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: waterMode == .reminder ? l.tr(zh: "计划设置", en: "Plan settings", de: "Planeinstellungen") : l.tr(zh: "水量设置", en: "Amount settings", de: "Mengeneinstellungen"), icon: "gearshape.fill", tint: waterMode == .reminder ? Color.goTeal : chromeTint) {
                        handleWaterSettingsTap()
                    }
                    Button {
                        openWaterSheet(.history)
                    } label: {
                        Label(l.tr(zh: "全部记录", en: "All records", de: "Alle Einträge"), systemImage: "clock.arrow.circlepath")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(chromeTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近喂水", en: "Recent water logs", de: "Letzte Trinkeinträge"))
                let logs = Array(waterLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "drop", text: l.tr(zh: "还没有喂水记录", en: "No water logs yet", de: "Noch keine Trinkeinträge"))
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: chromeTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var waterChangeOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewRangePicker(tint: waterChangeStatusTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: l.tr(zh: "周期", en: "Cycle", de: "Zyklus"), value: localizedDays(waterIntervalDays), icon: "repeat", tint: waterChangeStatusTint)
                    overviewMetric(title: l.tr(zh: "下次", en: "Next", de: "Nächstes"), value: waterNextDateText, icon: "calendar", tint: waterChangeStatusTint)
                }
                overviewProgressCard(
                    title: isWaterChangeOverdue ? l.tr(zh: "换水逾期", en: "Water change overdue", de: "Wasserwechsel überfällig") : l.tr(zh: "换水进度", en: "Water change progress", de: "Wasserwechsel-Fortschritt"),
                    elapsed: waterElapsedDays,
                    interval: waterIntervalDays,
                    tint: waterChangeStatusTint,
                    isWarning: isWaterChangeOverdue
                )
                overviewLineChart(
                    title: l.tr(zh: "换水记录", en: "Water change records", de: "Wasserwechsel-Einträge"),
                    subtitle: l.tr(zh: "按天统计换水次数。", en: "Water changes counted by day.", de: "Wasserwechsel pro Tag gezählt."),
                    points: careChartPoints(for: .waterChange),
                    tint: waterChangeStatusTint,
                    emptyText: l.tr(zh: "换水后会出现趋势", en: "Trends appear after water changes", de: "Trends erscheinen nach Wasserwechseln")
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: l.tr(zh: "记录换水", en: "Log change", de: "Wechsel eintragen"), icon: "checkmark", tint: waterChangeStatusTint) { doWaterChange() }
                    Button {
                        openWaterSheet(.waterSettings)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(waterChangeStatusTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近换水", en: "Recent water changes", de: "Letzte Wasserwechsel"))
                let logs = Array(waterChangeLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "arrow.2.circlepath", text: l.tr(zh: "还没有换水记录", en: "No water change records yet", de: "Noch keine Wasserwechsel-Einträge"))
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: waterChangeStatusTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var filterOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewRangePicker(tint: filterStatusTint)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewMetric(title: l.tr(zh: "清洗", en: "Clean", de: "Reinigen"), value: filterNextCleanText, icon: "sparkles", tint: filterStatusTint)
                    overviewMetric(title: l.tr(zh: "更换", en: "Replace", de: "Wechseln"), value: filterNextReplaceText, icon: "arrow.triangle.2.circlepath", tint: filterStatusTint)
                }
                overviewProgressCard(
                    title: isFilterOverdue ? l.tr(zh: "滤芯逾期", en: "Filter overdue", de: "Filter überfällig") : l.tr(zh: "清洗进度", en: "Cleaning progress", de: "Reinigungsfortschritt"),
                    elapsed: filterCleanElapsedDays ?? 0,
                    interval: filterCleanIntervalDays,
                    tint: filterStatusTint,
                    isWarning: isFilterOverdue
                )
                overviewLineChart(
                    title: l.tr(zh: "滤芯清洗", en: "Filter cleaning", de: "Filterreinigung"),
                    subtitle: l.tr(zh: "按天统计清洗次数。", en: "Cleanings counted by day.", de: "Reinigungen pro Tag gezählt."),
                    points: careChartPoints(for: .filterClean),
                    tint: filterStatusTint,
                    emptyText: l.tr(zh: "清洗滤芯后会出现趋势", en: "Trends appear after filter cleanings", de: "Trends erscheinen nach Filterreinigungen")
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: l.tr(zh: "记录清洗", en: "Log cleaning", de: "Reinigung eintragen"), icon: "checkmark", tint: filterStatusTint) { doFilterClean() }
                    Button {
                        openWaterSheet(.filterSettings)
                    } label: {
                        Label(l.tr(zh: "管理", en: "Manage", de: "Verwalten"), systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(filterStatusTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader(l.tr(zh: "最近清洗", en: "Recent cleanings", de: "Letzte Reinigungen"))
                let logs = Array(filterCleanLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "sparkles", text: l.tr(zh: "还没有滤芯清洗记录", en: "No filter cleaning records yet", de: "Noch keine Filterreinigungen"))
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: filterStatusTint, showDelete: true) { deleteLog(log) }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    func overviewHero(icon: String, title: String, subtitle: String, tint: Color) -> some View {
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

    func overviewRangePicker(tint: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(WaterOverviewRange.allCases) { range in
                let isLocked = range == .days90 && !appServices.commerce.allows(.extendedTrends)
                Button {
                    guard !isLocked else {
                        personalUpgradePrompt = PersonalUpgradePrompt(feature: .extendedTrends)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        return
                    }
                    withAnimation(GoMotion.page) {
                        overviewRange = range
                        overviewChartProgress = 0
                    }
                    scheduleOverviewChartReplay(milliseconds: 60)
                } label: {
                    HStack(spacing: 4) {
                        Text(range.title(l))
                        if isLocked {
                            Image(systemName: "lock.fill").accessibilityHidden(true)
                        }
                    }
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(overviewRange == range ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(overviewRange == range ? tint : Color.ohanaControlFill.opacity(0.5), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityHint(isLocked
                    ? l.tr(zh: "需要 Ohana Personal", en: "Requires Ohana Personal", de: "Ohana Personal erforderlich")
                    : "")
            }
        }
    }

    @ViewBuilder
    func waterSheetTopChrome(_ sheet: ActiveSheet) -> some View {
        HStack(spacing: 12) {
            waterSheetChromeTitle(sheet)
            Spacer(minLength: 12)
            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                closeActiveWaterSheet()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    @ViewBuilder
    func waterSheetChromeTitle(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .waterSettings:
            waterSheetChromeTitleContent(
                icon: "arrow.2.circlepath",
                title: l.tr(zh: "换水计划", en: "Water change plan", de: "Wasserwechselplan"),
                tint: waterChangeTint
            )
        case .waterAmount:
            waterSheetChromeTitleContent(
                icon: "drop.fill",
                title: l.tr(zh: "默认水量", en: "Default amount", de: "Standardmenge"),
                tint: chromeTint
            )
        case .waterPlan:
            waterSheetChromeTitleContent(
                icon: "bell.badge.fill",
                title: l.tr(zh: "喂水计划", en: "Water plan", de: "Trinkplan"),
                tint: Color.goTeal
            )
        case .filterSettings:
            waterSheetChromeTitleContent(
                icon: "sparkles",
                title: l.tr(zh: "滤芯计划", en: "Filter plan", de: "Filterplan"),
                tint: filterTint
            )
        case .history:
            waterSheetChromeTitleContent(
                icon: "clock.arrow.circlepath",
                title: l.tr(zh: "浇水记录", en: "Water history", de: "Trinkhistorie"),
                tint: chromeTint
            )
        case .waterOverview:
            waterSheetChromeTitleContent(
                icon: "drop.fill",
                title: l.tr(zh: "喂水总览", en: "Water overview", de: "Trinkübersicht"),
                tint: waterMode == .reminder ? Color.goTeal : chromeTint
            )
        case .waterChangeOverview:
            waterSheetChromeTitleContent(icon: "arrow.2.circlepath", title: l.tr(zh: "换水总览", en: "Water change overview", de: "Wasserwechsel-Übersicht"), tint: waterChangeTint)
        case .filterOverview:
            waterSheetChromeTitleContent(icon: "sparkles", title: l.tr(zh: "滤芯总览", en: "Filter overview", de: "Filterübersicht"), tint: filterTint)
        }
    }

    func waterSheetChromeTitleContent(icon: String, title: String, tint: Color) -> some View {
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

    func overviewMetric(title: String, value: String, icon: String, tint: Color) -> some View {
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
        .waterGlassSurface(cornerRadius: OhanaRadius.controlLarge, tint: tint, tintOpacity: 0.04)
    }

    func overviewLineChart(title: String, subtitle: String, points: [WaterChartPoint], tint: Color, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

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

    func overviewProgressCard(
        title: String,
        elapsed: Int,
        interval: Int,
        tint: Color,
        isWarning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                    if isWarning {
                        Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                }
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(isWarning ? Color.goRed : Color.ohanaPrimaryText)
                Spacer()
                Text(localizedProgressDays(elapsed: elapsed, interval: max(interval, 1)))
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
        .waterGlassSurface(cornerRadius: OhanaRadius.input, tint: tint, tintOpacity: isWarning ? 0.16 : 0.04)
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

    var todayWaterAmountText: String {
        let total = todayWaterLogs.reduce(0) { $0 + $1.amountMl }
        return total > 0 ? "\(Int(total.rounded()))ml" : "--"
    }

    var waterChartPoints: [WaterChartPoint] {
        chartPoints(for: .watering, useAmountMl: waterAmountEnabled)
    }

    func careChartPoints(for type: CareType) -> [WaterChartPoint] {
        chartPoints(for: type, useAmountMl: false)
    }

    func chartPoints(for type: CareType, useAmountMl: Bool) -> [WaterChartPoint] {
        let calendar = Calendar.current
        let dayCount = overviewRange.days
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
        let logs = allWaterLogs.filter { log in
            log.careType == type &&
                log.date >= start &&
                log.date < end
        }
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
        return (0 ..< dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let logs = grouped[date] ?? []
            let value = useAmountMl ? logs.reduce(0) { $0 + $1.amountMl } : Double(logs.count)
            return WaterChartPoint(date: date, value: value)
        }
    }

    var waterNextDateText: String {
        dueDateText(nextCycleDate(lastDate: lastWaterChange?.date, anchorDate: waterChangeAnchorDate, intervalDays: waterIntervalDays))
    }

    var filterNextCleanText: String {
        guard let lastFilterClean else { return l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag") }
        return dueDateText(nextCycleDate(lastDate: lastFilterClean.date, anchorDate: lastFilterClean.date, intervalDays: filterCleanIntervalDays))
    }

    var filterNextReplaceText: String {
        guard let lastFilterClean else { return l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag") }
        return dueDateText(nextCycleDate(lastDate: lastFilterClean.date, anchorDate: lastFilterClean.date, intervalDays: filterReplaceIntervalDays))
    }

    func nextCycleDate(lastDate: Date?, anchorDate: Date, intervalDays: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let anchor = calendar.startOfDay(for: anchorDate)
        let last = lastDate.map { calendar.startOfDay(for: $0) }
        let base = max(last ?? anchor, anchor)
        var next = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: base) ?? base
        while next < today {
            next = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: next) ?? next.addingTimeInterval(Double(max(intervalDays, 1)) * 86400)
        }
        return next
    }

    func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 1 {
            return l.tr(zh: "明天", en: "Tomorrow", de: "Morgen")
        }
        if days > 1, days <= 7 {
            return l.tr(
                zh: "\(days)天后",
                en: "in \(days) days",
                de: "in \(days) Tagen"
            )
        }
        return date.formatted(.dateTime.month().day())
    }
}
