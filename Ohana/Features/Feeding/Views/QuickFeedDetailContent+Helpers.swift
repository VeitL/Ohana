import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    // MARK: - Helpers

    var feedingOverviewModeValue: String {
        switch activeFeedingMode {
        case .manual:
            pet.dailyPortionGrams > 0 ? formattedFoodWeight(pet.dailyPortionGrams) : "--"
        case .manualReminder:
            feedTaskState.todayManualPlanCompletionText
        case .autoFeeder:
            "\(feedTaskState.todayAutoFeedCount)x"
        }
    }

    var feedingOverviewModeSubtitle: String {
        switch activeFeedingMode {
        case .manual:
            if pet.dailyPortionGrams > 0 {
                return l.tr(zh: "默认 \(formattedFoodWeight(pet.dailyPortionGrams)) · 当前 \(pet.mainFoodKind.title(l))", en: "Default \(formattedFoodWeight(pet.dailyPortionGrams)) · \(pet.mainFoodKind.title(l))", de: "Standard \(formattedFoodWeight(pet.dailyPortionGrams))")
            }
            return l.tr(zh: "还没有默认克数，设置后即可一键打卡。", en: "Set a default amount for one-tap logging.", de: "Standardmenge festlegen.")
        case .manualReminder:
            return nextFeedDetailText(events: feedScheduleEvents, fallback: l.tr(zh: "今日计划 \(feedTaskState.todayManualPlanCompletionText) 已完成", en: "Today \(feedTaskState.todayManualPlanCompletionText) complete", de: "Heute \(feedTaskState.todayManualPlanCompletionText)"))
        case .autoFeeder:
            return nextFeedDetailText(events: autoFeederEvents, fallback: autoFeederStatusText)
        }
    }

    var overviewChartSubtitle: String {
        l.tr(
            zh: "聚合手动、计划和自动记录。",
            en: "Manual, plan, and auto logs combined.",
            de: "Manuelle, Plan- und Auto-Einträge kombiniert."
        )
    }

    var feedingModeTint: Color {
        feedModeTint(activeFeedingMode)
    }

    var mainFoodOverviewTint: Color {
        Color.goPrimary
    }

    func formattedSourceTotal(_ source: FeedLogSource) -> String {
        let total = sourceTotal(source)
        return total > 0 ? formattedFoodWeight(total) : "--"
    }

    func sourceTotal(_ source: FeedLogSource) -> Double {
        overviewSnapshot.sourceTotal(source)
    }

    func feedModeTint(_ mode: FeedOperatingMode) -> Color {
        mode.feedTint
    }

    func feedModeIcon(_ mode: FeedOperatingMode) -> String {
        mode.feedIconName
    }

    func feedModeShortTitle(_ mode: FeedOperatingMode) -> String {
        mode.feedShortTitle(l)
    }

    var feedModeHistoryTitle: String {
        switch activeFeedingMode {
        case .manual:
            l.tr(zh: "手动历史", en: "Manual history", de: "Manueller Verlauf")
        case .manualReminder:
            l.tr(zh: "计划日历", en: "Plan calendar", de: "Plankalender")
        case .autoFeeder:
            l.tr(zh: "自动日历", en: "Auto calendar", de: "Auto-Kalender")
        }
    }

    var feedModeHistoryChartSubtitle: String {
        switch activeFeedingMode {
        case .manual:
            l.tr(zh: "只显示手动主粮记录。", en: "Manual main-food logs only.", de: "Nur manuelle Hauptfutter-Einträge.")
        case .manualReminder:
            l.tr(zh: "只显示喂食计划完成记录。", en: "Completed plan check-ins only.", de: "Nur erledigte Plan-Check-ins.")
        case .autoFeeder:
            l.tr(zh: "只显示自动猫粮机补记。", en: "Auto feeder logs only.", de: "Nur Futterautomat-Einträge.")
        }
    }

    var autoFeederStatusText: String {
        let daily = formattedFoodWeight(feedTaskState.autoDailyTotalGrams)
        if let latest = latestAutoFeedLog {
            return l.tr(
                zh: "\(daily)/天 · 上次 \(latest.date.formatted(date: .omitted, time: .shortened))",
                en: "\(daily)/day · last \(latest.date.formatted(date: .omitted, time: .shortened))",
                de: "\(daily)/Tag · zuletzt \(latest.date.formatted(date: .omitted, time: .shortened))"
            )
        }
        if let next = nextAutoFeedDate {
            return l.tr(
                zh: "\(daily)/天 · 下次 \(next.formatted(date: .omitted, time: .shortened))",
                en: "\(daily)/day · next \(next.formatted(date: .omitted, time: .shortened))",
                de: "\(daily)/Tag · nächste \(next.formatted(date: .omitted, time: .shortened))"
            )
        }
        return l.tr(zh: "\(daily)/天 · 自动补记", en: "\(daily)/day · auto logging", de: "\(daily)/Tag · Auto")
    }

    var latestAutoFeedLog: QuickFeedLedgerEntry? {
        overviewSnapshot.latestAutoFeedLog
    }

    var nextAutoFeedDate: Date? {
        autoFeederEvents
            .compactMap { nextOccurrence(for: $0) }
            .min()
    }

    func nextOccurrence(for event: Event, after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        if event.startDate > now { return event.startDate }
        let time = calendar.dateComponents([.hour, .minute, .second], from: event.startDate)
        var day = calendar.dateComponents([.year, .month, .day], from: now)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second
        guard var candidate = calendar.date(from: day) else { return nil }
        let intervalDays = max(event.recurrenceDays, 1)
        while candidate <= now {
            guard let next = calendar.date(byAdding: .day, value: intervalDays, to: candidate) else { return nil }
            candidate = next
        }
        if let end = event.recurrenceEndDate, candidate > end { return nil }
        return candidate
    }

    func nextFeedDetailText(events: [Event], fallback: String) -> String {
        guard let next = events
            .compactMap({ event -> (Event, Date)? in
                guard let date = nextOccurrence(for: event) else { return nil }
                return (event, date)
            })
            .min(by: { $0.1 < $1.1 })
        else {
            return fallback
        }
        let time = next.1.formatted(date: .omitted, time: .shortened)
        let grams = formattedFoodWeight(FeedRuleMetadata.amountGrams(from: next.0, fallback: pet.dailyPortionGrams))
        let kind = next.0.foodKind.title(l)
        return l.tr(
            zh: "下次 \(time) · \(kind) · \(grams)",
            en: "Next \(time) · \(kind) · \(grams)",
            de: "Nächste \(time) · \(kind) · \(grams)"
        )
    }

    var stockTint: Color {
        Color.goPrimary
    }

    func stockStatusTint(_ snapshot: FeedStockSnapshot) -> Color {
        guard snapshot.totalGrams > 0 else { return Color.ohanaSecondaryText }
        if snapshot.remainingGrams <= 0 || snapshot.remainingDays <= 3 { return Color.goRed }
        if snapshot.remainingDays <= 7 { return Color.goYellow }
        return stockTint
    }

    func stockOverviewStatusTint(dry: FeedStockSnapshot, wet: FeedStockSnapshot) -> Color {
        let snapshots = [dry, wet].filter { $0.totalGrams > 0 }
        guard !snapshots.isEmpty else { return Color.ohanaSecondaryText }
        if snapshots.contains(where: { $0.remainingGrams <= 0 || $0.remainingDays <= 3 }) { return Color.goRed }
        if snapshots.contains(where: { $0.remainingDays <= 7 }) { return Color.goYellow }
        return stockTint
    }

    func stockOverviewStatusText(dry: FeedStockSnapshot, wet: FeedStockSnapshot) -> String {
        let snapshots = [dry, wet].filter { $0.totalGrams > 0 }
        guard !snapshots.isEmpty else {
            return l.tr(zh: "未建立", en: "Empty", de: "Leer")
        }
        if snapshots.contains(where: { $0.remainingGrams <= 0 }) {
            return l.tr(zh: "已断粮", en: "Out", de: "Leer")
        }
        if snapshots.contains(where: { $0.remainingDays > 0 && $0.remainingDays <= 3 }) {
            return l.tr(zh: "快补粮", en: "Refill", de: "Nachfüllen")
        }
        if snapshots.contains(where: { $0.remainingDays > 0 && $0.remainingDays <= 7 }) {
            return l.tr(zh: "关注", en: "Watch", de: "Achten")
        }
        return l.tr(zh: "稳定", en: "Good", de: "Gut")
    }

    var mainFoodTint: Color {
        foodKindTint(pet.mainFoodKind)
    }

    var feedModeLogsInRange: [QuickFeedLedgerEntry] {
        overviewSnapshot.feedModeLogsInRange
    }

    var feedModePlanRemindersInRange: [Reminder] {
        overviewSnapshot.feedModePlanRemindersInRange
    }

    var feedPlanAllReminders: [Reminder] {
        planCalendarSnapshot.allReminders
    }

    var feedPlanHistoryReminders: [Reminder] {
        planCalendarSnapshot.historyReminders
    }

    var feedPlanSelectedDateOccurrences: [FeedPlanCalendarOccurrence] {
        planCalendarSnapshot.selectedDateOccurrences
    }

    var feedPlanSelectedDateSectionTitle: String {
        let calendar = Calendar.current
        let prefix = activeFeedingMode == .autoFeeder
            ? l.tr(zh: "自动", en: "Auto", de: "Auto")
            : l.tr(zh: "计划", en: "Plan", de: "Plan")
        if calendar.isDateInToday(draftStore.feedPlanCalendarSelectedDate) {
            return "\(prefix) · \(l.tr(zh: "今天", en: "Today", de: "Heute"))"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(draftStore.feedPlanCalendarSelectedDate, inSameDayAs: tomorrow) {
            return "\(prefix) · \(l.tr(zh: "明天", en: "Tomorrow", de: "Morgen"))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(draftStore.feedPlanCalendarSelectedDate, inSameDayAs: yesterday) {
            return "\(prefix) · \(l.tr(zh: "昨天", en: "Yesterday", de: "Gestern"))"
        }
        return "\(prefix) · \(draftStore.feedPlanCalendarSelectedDate.formatted(.dateTime.month().day()))"
    }

    var feedPlanCalendarMonthTitle: String {
        draftStore.feedPlanCalendarMonth.formatted(.dateTime.year().month(.wide))
    }

    var feedPlanCalendarMonthKey: String {
        planCalendarSnapshot.monthKey
    }

    var feedPlanWeekdayTitles: [String] {
        let l = L10n(appLanguage)
        return [
            l.tr(zh: "一", en: "M", de: "Mo"),
            l.tr(zh: "二", en: "T", de: "Di"),
            l.tr(zh: "三", en: "W", de: "Mi"),
            l.tr(zh: "四", en: "T", de: "Do"),
            l.tr(zh: "五", en: "F", de: "Fr"),
            l.tr(zh: "六", en: "S", de: "Sa"),
            l.tr(zh: "日", en: "S", de: "So")
        ]
    }

    var feedPlanCalendarDaySummaries: [FeedPlanCalendarDaySummary] {
        planCalendarSnapshot.daySummaries
    }

    func feedPlanStatus(for occurrence: FeedPlanCalendarOccurrence) -> (title: String, tint: Color, icon: String) {
        let isToday = Calendar.current.isDateInToday(occurrence.date)
        if activeFeedingMode == .autoFeeder {
            if occurrence.isCompleted {
                return (l.tr(zh: "自动记录", en: "Auto logged", de: "Automatisch erfasst"), Color.goTeal, FeedRuleKind.autoFeeder.iconName)
            }
            if !isToday {
                return (l.tr(zh: "自动计划", en: "Auto planned", de: "Auto geplant"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
            }
            return (l.tr(zh: "待自动", en: "Pending auto", de: "Ausstehend"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
        }
        if occurrence.isCompleted {
            return (l.tr(zh: "打卡成功", en: "Checked in", de: "Erledigt"), Color.goPrimary, "checkmark.seal.fill")
        }
        if occurrence.date < clockTick {
            return (l.tr(zh: "未打卡", en: "Missed", de: "Verpasst"), Color.goRed, "exclamationmark.triangle.fill")
        }
        if !isToday {
            return (l.tr(zh: "计划中", en: "Planned", de: "Geplant"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
        }
        return (l.tr(zh: "待打卡", en: "Pending", de: "Ausstehend"), Color.ohanaSecondaryText.opacity(0.42), "clock.fill")
    }

    func feedPlanActionTitle(for occurrence: FeedPlanCalendarOccurrence) -> String? {
        guard activeFeedingMode == .manualReminder else { return nil }
        let calendar = Calendar.current
        guard calendar.isDateInToday(draftStore.feedPlanCalendarSelectedDate), !occurrence.isCompleted else { return nil }
        if occurrence.date < clockTick {
            guard FeedPlanCatchUpPolicy.isCatchUpEligible(scheduledAt: occurrence.date, now: clockTick) else { return nil }
            return l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen")
        }
        return l.tr(zh: "提前打卡", en: "Check in early", de: "Früher abhaken")
    }

    func canCatchUpPlanReminder(_ reminder: Reminder) -> Bool {
        FeedPlanCatchUpPolicy.isCatchUpEligible(reminder, now: clockTick)
    }

    func friendlyPlanDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) {
            return "\(l.tr(zh: "今天", en: "Today", de: "Heute")) \(time)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "\(l.tr(zh: "明天", en: "Tomorrow", de: "Morgen")) \(time)"
        }
        if let afterTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: clockTick)),
           calendar.isDate(date, inSameDayAs: afterTomorrow) {
            return "\(l.tr(zh: "后天", en: "In 2 days", de: "Übermorgen")) \(time)"
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    var treatLogsInRange: [QuickFeedLedgerEntry] {
        treatSnapshot.logsInRange
    }

    var filteredTreatLogsInRange: [QuickFeedLedgerEntry] {
        treatSnapshot.filteredLogsInRange
    }

    var filteredTreatLogsToday: [QuickFeedLedgerEntry] {
        treatSnapshot.filteredLogsToday
    }

    var filteredTreatGramsToday: Double {
        treatSnapshot.filteredGramsToday
    }

    var mainFoodChartPoints: [FeedOverviewChartPoint] {
        overviewSnapshot.mainFoodChartPoints
    }

    var feedModeChartPoints: [FeedOverviewChartPoint] {
        overviewSnapshot.feedModeChartPoints
    }

    var filteredTreatChartPoints: [FeedOverviewChartPoint] {
        treatSnapshot.filteredChartPoints
    }

    var treatFrequencyTitle: String {
        if let selectedTreatOverviewKind = draftStore.selectedTreatOverviewKind {
            return l.tr(
                zh: "\(selectedTreatOverviewKind.title(l))频率",
                en: "\(selectedTreatOverviewKind.title(l)) frequency",
                de: "\(selectedTreatOverviewKind.title(l))-Frequenz"
            )
        }
        return l.tr(zh: "零食频率", en: "Treat frequency", de: "Snackfrequenz")
    }

    var currentPortionAmount: Double? {
        if pet.dailyPortionGrams > 0 { return pet.dailyPortionGrams }
        return nil
    }

    var quickMainGramOptions: [Double] {
        overviewSnapshot.quickMainGramOptions
    }

    var allFeedLedgerEntries: [QuickFeedLedgerEntry] {
        observedFeedingLedgerEntries
    }

    func setMainFoodKind(_ foodKind: FeedFoodKind) {
        guard pet.mainFoodKind != foodKind else { return }
        commandExecutor.setMainFoodKind(pet: pet, foodKind: foodKind)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func feedLogDisplayGrams(for log: PetCareLog) -> Double {
        FeedLogMetadata.isMainFoodLog(log)
            ? FeedStockCalculator.effectiveMainFoodAmount(for: log, pet: pet)
            : max(0, log.amountGrams)
    }

    func parsePositiveDouble(_ raw: String) -> Double? {
        guard let number = CountryDecimalInput.parse(raw, countryCode: AppCountry.code), number >= 0 else { return nil }
        return number
    }

    func formattedFoodWeight(_ grams: Double) -> String {
        AppMeasurementSystem.formatFoodGrams(grams)
    }

    func formattedFoodCardWeight(_ grams: Double) -> String {
        "\(Int(max(0, grams).rounded()))g"
    }

    func formattedStockWeight(_ grams: Double) -> String {
        let digits = grams >= 1000 && grams < 10000 ? 2 : 1
        return AppMeasurementSystem.formatFoodGrams(grams, fractionDigits: digits)
    }
}
