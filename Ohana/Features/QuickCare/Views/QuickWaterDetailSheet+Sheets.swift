//
//  QuickWaterDetailSheet+Sheets.swift
//  Ohana
//

import SwiftUI

extension QuickWaterDetailSheet {
    // MARK: - Sheets
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
                        saveWaterChangePlanToCalendar(toast: "已保存换水周期")
                    }
                },
                onDelete: {
                    waterReminderOn = false
                    startWaterCalendarPlanSave {
                        saveWaterChangePlanToCalendar(toast: "已关闭换水提醒")
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
                        title: "共同喂水",
                        subtitle: "\(selectedWaterTargets.count)只\(pet.species)",
                        pets: sameSpeciesWaterPets,
                        selectedPetIds: $selectedSharedWaterPetIds,
                        tint: chromeTint
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
                        showSaveConfirmation(waterAmountEnabled ? "已保存默认水量" : "已关闭默认水量")
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
                        title: "目标宠物",
                        subtitle: "\(selectedWaterTargets.count)只\(pet.species)",
                        pets: sameSpeciesWaterPets,
                        selectedPetIds: $selectedSharedWaterPetIds,
                        tint: Color.goTeal
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
                    overviewMetric(title: "今日次数", value: "\(todayWaterLogs.count)", icon: "number.circle.fill", tint: chromeTint)
                    overviewMetric(title: "今日水量", value: todayWaterAmountText, icon: "drop.fill", tint: chromeTint)
                }
                overviewLineChart(
                    title: "饮水趋势",
                    subtitle: waterAmountEnabled ? "按已记录 ml 聚合。" : "当前只记录次数。",
                    points: waterChartPoints,
                    tint: waterMode == .reminder ? Color.goTeal : chromeTint,
                    emptyText: "喂水后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: waterMode == .reminder ? "计划设置" : "水量设置", icon: "gearshape.fill", tint: waterMode == .reminder ? Color.goTeal : chromeTint) {
                        handleWaterSettingsTap()
                    }
                    Button {
                        openWaterSheet(.history)
                    } label: {
                        Label("全部记录", systemImage: "clock.arrow.circlepath")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(chromeTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近喂水")
                let logs = Array(waterLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "drop", text: "还没有喂水记录")
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
                    overviewMetric(title: "周期", value: "\(waterIntervalDays)天", icon: "repeat", tint: waterChangeStatusTint)
                    overviewMetric(title: "下次", value: waterNextDateText, icon: "calendar", tint: waterChangeStatusTint)
                }
                overviewProgressCard(
                    title: isWaterChangeOverdue ? "换水逾期" : "换水进度",
                    elapsed: waterElapsedDays,
                    interval: waterIntervalDays,
                    tint: waterChangeStatusTint,
                    isWarning: isWaterChangeOverdue
                )
                overviewLineChart(
                    title: "换水记录",
                    subtitle: "按天统计换水次数。",
                    points: careChartPoints(for: .waterChange),
                    tint: waterChangeStatusTint,
                    emptyText: "换水后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: "记录换水", icon: "checkmark", tint: waterChangeStatusTint) { doWaterChange() }
                    Button {
                        openWaterSheet(.waterSettings)
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(waterChangeStatusTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近换水")
                let logs = Array(waterChangeLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "arrow.2.circlepath", text: "还没有换水记录")
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
                    overviewMetric(title: "清洗", value: filterNextCleanText, icon: "sparkles", tint: filterStatusTint)
                    overviewMetric(title: "更换", value: filterNextReplaceText, icon: "arrow.triangle.2.circlepath", tint: filterStatusTint)
                }
                overviewProgressCard(
                    title: isFilterOverdue ? "滤芯逾期" : "清洗进度",
                    elapsed: filterCleanElapsedDays ?? 0,
                    interval: filterCleanIntervalDays,
                    tint: filterStatusTint,
                    isWarning: isFilterOverdue
                )
                overviewLineChart(
                    title: "滤芯清洗",
                    subtitle: "按天统计清洗次数。",
                    points: careChartPoints(for: .filterClean),
                    tint: filterStatusTint,
                    emptyText: "清洗滤芯后会出现趋势"
                )
                HStack(spacing: 10) {
                    WaterPrimaryButton(title: "记录清洗", icon: "checkmark", tint: filterStatusTint) { doFilterClean() }
                    Button {
                        openWaterSheet(.filterSettings)
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(filterStatusTint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                overviewSectionHeader("最近清洗")
                let logs = Array(filterCleanLogs.prefix(8))
                if logs.isEmpty {
                    emptyInlineState(icon: "sparkles", text: "还没有滤芯清洗记录")
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
                Button {
                    withAnimation(GoMotion.page) {
                        overviewRange = range
                        overviewChartProgress = 0
                    }
                    scheduleOverviewChartReplay(milliseconds: 60)
                } label: {
                    Text(range.title)
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
        case .waterOverview:
            waterSheetChromeTitleContent(
                icon: "drop.fill",
                title: "喂水总览",
                tint: waterMode == .reminder ? Color.goTeal : chromeTint
            )
        case .waterChangeOverview:
            waterSheetChromeTitleContent(icon: "arrow.2.circlepath", title: "换水总览", tint: waterChangeTint)
        case .filterOverview:
            waterSheetChromeTitleContent(icon: "sparkles", title: "滤芯总览", tint: filterTint)
        default:
            EmptyView()
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
                Text("\(elapsed)/\(max(interval, 1))天")
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
        let logs = waterCareLogs.filter { log in
            log.type == type.rawValue &&
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
        guard let lastFilterClean else { return "未记录" }
        return dueDateText(nextCycleDate(lastDate: lastFilterClean.date, anchorDate: lastFilterClean.date, intervalDays: filterCleanIntervalDays))
    }

    var filterNextReplaceText: String {
        guard let lastFilterClean else { return "未记录" }
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
            return "今天"
        }
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 1 {
            return "明天"
        }
        if days > 1, days <= 7 {
            return "\(days)天后"
        }
        return date.formatted(.dateTime.month().day())
    }
}
