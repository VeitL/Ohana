import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var manageSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHero(icon: "slider.horizontal.3", title: l.tr(zh: "管理", en: "Manage", de: "Verwalten"), tint: Color.goPrimary)
            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "模式", en: "Mode", de: "Modus"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                feedModeSelector
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
            manageRow(
                icon: "fork.knife",
                title: l.tr(zh: "默认粮种 / 克数", en: "Default food / grams", de: "Standardfutter / Gramm"),
                value: pet.dailyPortionGrams > 0 ? "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))" : l.tr(zh: "待设置", en: "Not set", de: "Nicht gesetzt"),
                tint: mainFoodTint
            ) {
                openManualFeedSheet(settingsOnly: true)
            }
            manageRow(
                icon: FeedRuleKind.manualReminder.iconName,
                title: l.tr(zh: "喂食计划", en: "Feeding plan", de: "Fütterungsplan"),
                value: feedScheduleEvents.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : "\(feedScheduleEvents.count) \(l.tr(zh: "次/天", en: "x/day", de: "x/Tag"))",
                tint: Color.goPurple
            ) {
                openPlanEditor(.manualReminder)
            }
            manageRow(
                icon: FeedRuleKind.autoFeeder.iconName,
                title: l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat"),
                value: autoFeederEvents.isEmpty ? l.tr(zh: "未开启", en: "Off", de: "Aus") : formattedFoodWeight(feedTaskState.autoDailyTotalGrams) + l.tr(zh: "/天", en: "/day", de: "/Tag"),
                tint: Color.goTeal
            ) {
                openPlanEditor(.autoFeeder)
            }
            manageRow(
                icon: "shippingbox.fill",
                title: l.tr(zh: "余粮记录", en: "Stock records", de: "Vorratseinträge"),
                value: "\(stockSnapshot.records.count)",
                tint: stockTint
            ) {
                openFeedSheet(.stockRecords)
            }
            manageRow(
                icon: "clock.arrow.circlepath",
                title: l.tr(zh: "完整历史", en: "Full history", de: "Historie"),
                value: "\(allFeedLedgerEntries.count)",
                tint: Color.goPrimary
            ) {
                openFeedSheet(.history)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .ohanaAdaptiveSheetContentHeight(
            adaptiveSheetHeightBinding,
            minHeight: 300,
            maxHeight: 580,
            chromePadding: 66
        )
        .navigationTitle(l.tr(zh: "管理", en: "Manage", de: "Verwalten"))
    }

    var historySheet: some View {
        let logs = allFeedLedgerEntries
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if logs.isEmpty {
                    emptyInlineState(icon: "fork.knife", text: l.tr(zh: "还没有喂食记录", en: "No feeding logs yet", de: "Noch keine Einträge"))
                } else {
                    ForEach(logs) { entry in
                        feedLogRow(entry, compact: false)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var feedModeHistorySheet: some View {
        let logs = overviewSnapshot.feedModeRecentLogs
        return ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if activeFeedingMode == .manualReminder || activeFeedingMode == .autoFeeder {
                        feedPlanCalendarSection
                        feedPlanSelectedDateSection
                    } else {
                        if activeFeedingMode == .manual {
                            manualFeedSettingSummary
                        }
                        overviewRangePicker(tint: feedingModeTint)
                        overviewLineChart(
                            title: l.tr(zh: "打卡曲线", en: "Check-in chart", de: "Check-in-Kurve"),
                            subtitle: feedModeHistoryChartSubtitle,
                            points: feedModeChartPoints,
                            tint: feedingModeTint,
                            emptyText: l.tr(zh: "该模式还没有打卡记录", en: "No check-ins for this mode yet", de: "Noch keine Einträge für diesen Modus"),
                            showsSurface: false
                        )
                        feedModeHistoryStatusSection
                        overviewSectionHeader(l.tr(zh: "历史记录", en: "History", de: "Verlauf"))
                        if logs.isEmpty {
                            emptyInlineState(icon: "fork.knife", text: l.tr(zh: "该模式还没有记录", en: "No records in this mode", de: "Keine Einträge für diesen Modus"), solid: true)
                        } else {
                            ForEach(logs) { log in
                                feedLogRow(log, compact: false, solidSurface: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            if draftStore.showFeedPlanMonthPicker {
                Color.black.opacity(0.001) // ui-v4: allow invisible tap catcher for dismissing calendar picker
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(GoMotion.quick) {
                            draftStore.showFeedPlanMonthPicker = false
                        }
                    }
                    .zIndex(10)

                feedPlanYearMonthPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .navigationTitle("")
    }

    var stockRecordsSheet: some View {
        let records = stockSnapshot.records
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if records.isEmpty {
                    emptyInlineState(icon: "shippingbox", text: l.tr(zh: "补粮后会显示在这里", en: "Restocks appear here", de: "Nachfüllungen erscheinen hier"))
                } else {
                    ForEach(records) { record in
                        foodRecordRow(record)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("")
    }

    var editFeedLogSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sheetHero(icon: "pencil", title: l.tr(zh: "编辑记录", en: "Edit log", de: "Eintrag bearbeiten"), tint: mainFoodTint)
                gramInput(
                    title: l.tr(zh: "克数", en: "Grams", de: "Gramm"),
                    text: $draftStore.editFeedLogGrams,
                    field: .editLogGrams,
                    tint: mainFoodTint,
                    quickValues: quickMainGramOptions
                )
                DatePicker(l.tr(zh: "时间", en: "Time", de: "Zeit"), selection: $draftStore.editFeedLogDate)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .padding(12)
                    .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
                if let inputError = draftStore.inputError {
                    errorText(inputError)
                }
                FoodPrimaryButton(title: l.tr(zh: "保存修改", en: "Save changes", de: "Änderungen speichern"), icon: "checkmark", tint: mainFoodTint) {
                    saveFeedLogEdit()
                }
            }
            .padding(20)
            .ohanaAdaptiveSheetContentHeight(
                adaptiveSheetHeightBinding,
                minHeight: 330,
                maxHeight: 540,
                chromePadding: 66
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"))
    }

    var feedingOverviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                feedingOverviewAggregateSummary
                overviewFoodBreakdown
                overviewRangePicker(tint: mainFoodOverviewTint)
                feedingOverviewSourceBreakdown
                overviewLineChart(
                    title: l.tr(zh: "进食量曲线", en: "Intake trend", de: "Futtertrend"),
                    subtitle: overviewChartSubtitle,
                    points: mainFoodChartPoints,
                    tint: mainFoodOverviewTint,
                    emptyText: l.tr(zh: "打卡后会出现曲线", en: "Log meals to see a trend", de: "Nach Einträgen erscheint ein Trend"),
                    showsSurface: false
                )
                overviewSectionHeader(l.tr(zh: "最近主粮", en: "Recent main food", de: "Letztes Hauptfutter"))
                let logs = overviewSnapshot.recentMainFoodLogs
                if logs.isEmpty {
                    emptyInlineState(icon: "fork.knife", text: l.tr(zh: "还没有主粮记录", en: "No main food logs yet", de: "Noch keine Hauptfutter-Einträge"), solid: true)
                } else {
                    ForEach(logs) { log in
                        feedLogRow(log, compact: false, solidSurface: true)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
    }

    @ViewBuilder
    var feedingModeHistorySection: some View {
        switch activeFeedingMode {
        case .manual:
            EmptyView()
        case .manualReminder:
            overviewSectionHeader(l.tr(zh: "今日计划记录", en: "Plan check-ins", de: "Plan-Check-ins"))
            let reminders = overviewSnapshot.todayPlanReminders
            if reminders.isEmpty {
                emptyInlineState(icon: "clock.badge.questionmark", text: l.tr(zh: "今天还没有计划记录", en: "No plan check-ins today", de: "Heute keine Plan-Check-ins"), solid: true)
            } else {
                ForEach(reminders, id: \.id) { reminder in
                    planReminderHistoryRow(reminder, allowsCatchUp: canCatchUpPlanReminder(reminder))
                }
            }
        case .autoFeeder:
            overviewSectionHeader(l.tr(zh: "今日自动记录", en: "Auto check-ins", de: "Auto-Check-ins"))
            let logs = overviewSnapshot.todayAutoFeedLogs
            if logs.isEmpty {
                emptyInlineState(icon: "gearshape.2", text: l.tr(zh: "到点后会自动补记", en: "Due meals are logged automatically", de: "Fällige Mahlzeiten werden automatisch erfasst"), solid: true)
            } else {
                ForEach(logs) { log in
                    feedLogRow(log, compact: false, solidSurface: true)
                }
            }
        }
    }

    @ViewBuilder
    var feedModeHistoryStatusSection: some View {
        switch activeFeedingMode {
        case .manual:
            EmptyView()
        case .manualReminder:
            overviewSectionHeader(l.tr(zh: "计划状态", en: "Plan status", de: "Planstatus"))
            let reminders = feedModePlanRemindersInRange
            if reminders.isEmpty {
                emptyInlineState(icon: "clock.badge.questionmark", text: l.tr(zh: "当前范围内没有计划状态", en: "No plan status in this range", de: "Kein Planstatus in diesem Zeitraum"), solid: true)
            } else {
                ForEach(reminders, id: \.id) { reminder in
                    planReminderHistoryRow(reminder)
                }
            }
        case .autoFeeder:
            EmptyView()
        }
    }
}
