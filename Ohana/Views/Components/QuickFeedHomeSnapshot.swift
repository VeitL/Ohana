//
//  QuickFeedHomeSnapshot.swift
//  Ohana
//
//  Lightweight render snapshot for the feeding home surface.
//

import Foundation

struct QuickFeedHomeSnapshot {
    let manualPlanEvents: [Event]
    let autoFeederEvents: [Event]
    let todayMainFoodGrams: Double
    let todayDryFoodGrams: Double
    let todayWetFoodGrams: Double
    let todayTreatGrams: Double
    let todayTreatCount: Int
    let todayAutoFeedCount: Int
    let hasNextManualReminder: Bool
    let hasMissedManualPlan: Bool
    let todayManualPlanMissedCount: Int
    let todayManualPlanCompletionText: String
    let autoDailyTotalGrams: Double
    let latestAutoFeedDate: Date?
    let nextAutoFeedDate: Date?
    let stockCardRemainingDays: Int?
    let guidedSevenDayMainFoodPoints: [OhanaMinimalChartPoint]

    static func make(
        pet: Pet,
        allEvents: [Event],
        careLogs: [PetCareLog],
        foodRecords: [PetFoodRecord],
        now: Date,
        todayLabel: String,
        calendar: Calendar = .current
    ) -> QuickFeedHomeSnapshot {
        let rules = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
        let manualPlanEvents = rules.manualReminderEvents
        let autoFeederEvents = rules.autoFeederEvents
        let todayLogs = careLogs
            .filter {
                $0.careType == .feeding &&
                calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
        let mainTodayLogs = todayLogs.filter { FeedLogMetadata.isMainFoodLog($0) }
        let treatTodayLogs = todayLogs.filter { FeedLogMetadata.isTreatLog($0) }
        let todayDryFoodGrams = mainTodayLogs
            .filter { $0.foodKind == .dry }
            .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
        let todayWetFoodGrams = mainTodayLogs
            .filter { $0.foodKind == .wet }
            .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }

        let todayPlanReminders = manualPlanEvents
            .flatMap(\.reminders)
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let pendingPlanReminders = todayPlanReminders.filter { $0.isPending || $0.isFailed }
        let missedPlanReminders = todayPlanReminders.filter { $0.isFailed || ($0.isPending && $0.scheduledAt < now) }
        let completedPlanReminders = todayPlanReminders.filter { $0.isCompleted }
        let planTotal = max(todayPlanReminders.count, manualPlanEvents.count, 1)
        let planCompleted = min(completedPlanReminders.count, planTotal)

        let dryStock = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .dry,
            events: allEvents,
            careLogs: careLogs,
            foodRecords: foodRecords,
            now: now,
            calendar: calendar
        )
        let wetStock = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .wet,
            events: allEvents,
            careLogs: careLogs,
            foodRecords: foodRecords,
            now: now,
            calendar: calendar
        )
        let stockCardRemainingDays = [dryStock, wetStock]
            .filter { $0.totalGrams > 0 && $0.remainingDays > 0 }
            .map(\.remainingDays)
            .min()

        let latestAutoFeedDate = careLogs
            .filter { FeedLogMetadata.source(for: $0) == .autoMain }
            .max { $0.date < $1.date }?
            .date
        let nextAutoFeedDate = autoFeederEvents
            .compactMap { nextOccurrence(for: $0, after: now, calendar: calendar) }
            .min()

        let sevenDayPoints = makeSevenDayMainFoodPoints(
            pet: pet,
            careLogs: careLogs,
            now: now,
            todayLabel: todayLabel,
            calendar: calendar
        )

        return QuickFeedHomeSnapshot(
            manualPlanEvents: manualPlanEvents,
            autoFeederEvents: autoFeederEvents,
            todayMainFoodGrams: todayDryFoodGrams + todayWetFoodGrams,
            todayDryFoodGrams: todayDryFoodGrams,
            todayWetFoodGrams: todayWetFoodGrams,
            todayTreatGrams: treatTodayLogs.reduce(0) { $0 + max(0, $1.amountGrams) },
            todayTreatCount: treatTodayLogs.count,
            todayAutoFeedCount: mainTodayLogs.filter { FeedLogMetadata.source(for: $0) == .autoMain }.count,
            hasNextManualReminder: pendingPlanReminders.first != nil,
            hasMissedManualPlan: !missedPlanReminders.isEmpty,
            todayManualPlanMissedCount: missedPlanReminders.count,
            todayManualPlanCompletionText: "\(planCompleted)/\(planTotal)",
            autoDailyTotalGrams: FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents),
            latestAutoFeedDate: latestAutoFeedDate,
            nextAutoFeedDate: nextAutoFeedDate,
            stockCardRemainingDays: stockCardRemainingDays,
            guidedSevenDayMainFoodPoints: sevenDayPoints
        )
    }

    private static func makeSevenDayMainFoodPoints(
        pet: Pet,
        careLogs: [PetCareLog],
        now: Date,
        todayLabel: String,
        calendar: Calendar
    ) -> [OhanaMinimalChartPoint] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let logs = FeedStockCalculator.mainFoodLogs(for: pet, since: start, careLogs: careLogs)
        let totalsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { logs in
                logs.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
            }
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let total = totalsByDay[calendar.startOfDay(for: day)] ?? 0
            return OhanaMinimalChartPoint(
                date: day,
                value: total,
                label: calendar.isDateInToday(day) ? todayLabel : day.formatted(.dateTime.weekday(.narrow))
            )
        }
    }

    private static func nextOccurrence(for event: Event, after now: Date, calendar: Calendar) -> Date? {
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
}
