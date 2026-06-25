//
//  FeedHomeSnapshotBuilder.swift
//  Ohana
//
//  Pure snapshot builder for the feeding home surface.
//

import Foundation

struct FeedHomeSnapshotInput {
    let pet: Pet
    let allEvents: [Event]
    let careLogs: [PetCareLog]
    let feedingLedgerEntries: [QuickFeedLedgerEntry]?
    let foodRecords: [PetFoodRecord]
    let sharedCareSessions: [SharedCareSession]
    let now: Date
    let todayLabel: String
    let calendar: Calendar

    init(
        pet: Pet,
        allEvents: [Event],
        careLogs: [PetCareLog],
        feedingLedgerEntries: [QuickFeedLedgerEntry]? = nil,
        foodRecords: [PetFoodRecord],
        sharedCareSessions: [SharedCareSession] = [],
        now: Date,
        todayLabel: String,
        calendar: Calendar = .current
    ) {
        self.pet = pet
        self.allEvents = allEvents
        self.careLogs = careLogs
        self.feedingLedgerEntries = feedingLedgerEntries
        self.foodRecords = foodRecords
        self.sharedCareSessions = sharedCareSessions
        self.now = now
        self.todayLabel = todayLabel
        self.calendar = calendar
    }
}

enum FeedHomeSnapshotBuilder {
    static func build(input: FeedHomeSnapshotInput) -> QuickFeedHomeSnapshot {
        let pet = input.pet
        let allEvents = input.allEvents
        let careLogs = input.careLogs
        let feedingLedgerEntries = input.feedingLedgerEntries
        let foodRecords = input.foodRecords
        let sharedCareSessions = input.sharedCareSessions
        let now = input.now
        let calendar = input.calendar

        let rules = FeedRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
        let manualPlanEvents = rules.manualReminderEvents
        let autoFeederEvents = rules.autoFeederEvents
        let legacyTodayLogs = careLogs
            .filter {
                $0.careType == .feeding &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
            .sorted { $0.date > $1.date }
        let todaySummary = todaySummary(
            pet: pet,
            ledgerEntries: feedingLedgerEntries,
            legacyTodayLogs: legacyTodayLogs,
            now: now,
            calendar: calendar
        )

        let allPlanReminders = manualPlanEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let todayPlanReminders = allPlanReminders
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let pendingTodayPlanReminders = todayPlanReminders.filter { !$0.isCompleted && ($0.isPending || $0.isFailed) }
        let catchUpPlanReminders = allPlanReminders.filter { FeedPlanCatchUpPolicy.isCatchUpEligible($0, now: now) }
        let expiredMissedPlanReminders = allPlanReminders.filter { FeedPlanCatchUpPolicy.isExpiredMiss($0, now: now) }
        let nextActionablePlanReminder = expiredMissedPlanReminders.isEmpty
            ? (catchUpPlanReminders.first ?? pendingTodayPlanReminders.first)
            : nil
        let completedPlanReminders = todayPlanReminders.filter(\.isCompleted)
        let planTotal = max(todayPlanReminders.count, manualPlanEvents.count, 1)
        let planCompleted = min(completedPlanReminders.count, planTotal)

        let dryStock = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .dry,
            events: allEvents,
            careLogs: careLogs,
            feedingLedgerEntries: feedingLedgerEntries,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now,
            calendar: calendar
        )
        let wetStock = FeedStockCalculator.snapshot(
            for: pet,
            foodKind: .wet,
            events: allEvents,
            careLogs: careLogs,
            feedingLedgerEntries: feedingLedgerEntries,
            foodRecords: foodRecords,
            sharedCareSessions: sharedCareSessions,
            now: now,
            calendar: calendar
        )
        let stockCardRemainingDays = [dryStock, wetStock]
            .filter { $0.totalGrams > 0 }
            .map(\.remainingDays)
            .min()
        let dryStockRemainingGrams = dryStock.totalGrams > 0 ? dryStock.remainingGrams : nil
        let dryStockRemainingDays = dryStock.totalGrams > 0 ? dryStock.remainingDays : nil
        let wetStockRemainingGrams = wetStock.totalGrams > 0 ? wetStock.remainingGrams : nil
        let wetStockRemainingDays = wetStock.totalGrams > 0 ? wetStock.remainingDays : nil

        let latestAutoFeedDate = latestAutoFeedDate(
            ledgerEntries: feedingLedgerEntries,
            legacyCareLogs: careLogs
        )
        let nextAutoFeedDate = autoFeederEvents
            .compactMap { nextOccurrence(for: $0, after: now, calendar: calendar) }
            .min()

        let sevenDayPoints = makeSevenDayMainFoodPoints(
            pet: pet,
            ledgerEntries: feedingLedgerEntries,
            careLogs: careLogs,
            now: now,
            todayLabel: input.todayLabel,
            calendar: calendar
        )

        return QuickFeedHomeSnapshot(
            manualPlanEvents: manualPlanEvents,
            autoFeederEvents: autoFeederEvents,
            todayMainFoodGrams: todaySummary.dryFoodGrams + todaySummary.wetFoodGrams,
            todayDryFoodGrams: todaySummary.dryFoodGrams,
            todayWetFoodGrams: todaySummary.wetFoodGrams,
            todayTreatGrams: todaySummary.treatGrams,
            todayTreatCount: todaySummary.treatCount,
            todayAutoFeedCount: todaySummary.autoFeedCount,
            hasNextManualReminder: nextActionablePlanReminder != nil,
            hasMissedManualPlan: expiredMissedPlanReminders.isEmpty && !catchUpPlanReminders.isEmpty,
            todayManualPlanMissedCount: expiredMissedPlanReminders.isEmpty ? catchUpPlanReminders.count : 0,
            lastExpiredManualPlanDate: expiredMissedPlanReminders.map(\.scheduledAt).max(),
            todayManualPlanCompletionText: "\(planCompleted)/\(planTotal)",
            autoDailyTotalGrams: FeedStockCalculator.autoRuleDailyTotalGrams(for: pet, events: allEvents),
            latestAutoFeedDate: latestAutoFeedDate,
            nextAutoFeedDate: nextAutoFeedDate,
            stockCardRemainingDays: stockCardRemainingDays,
            dryStockRemainingGrams: dryStockRemainingGrams,
            dryStockRemainingDays: dryStockRemainingDays,
            wetStockRemainingGrams: wetStockRemainingGrams,
            wetStockRemainingDays: wetStockRemainingDays,
            guidedSevenDayMainFoodPoints: sevenDayPoints
        )
    }

    private static func makeSevenDayMainFoodPoints(
        pet: Pet,
        ledgerEntries: [QuickFeedLedgerEntry]?,
        careLogs: [PetCareLog],
        now: Date,
        todayLabel: String,
        calendar: Calendar
    ) -> [OhanaMinimalChartPoint] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        if let ledgerEntries {
            let entries = ledgerEntries
                .filter { $0.source != .treat && $0.date >= start }
            let totalsByDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
                .mapValues { entries in
                    entries.reduce(0) { $0 + QuickFeedOverviewSnapshot.effectiveMainFoodAmount(for: $1, pet: pet) }
                }
            return sevenDayPoints(
                totalsByDay: totalsByDay,
                start: start,
                todayLabel: todayLabel,
                calendar: calendar
            )
        }
        let logs = FeedStockCalculator.mainFoodLogs(for: pet, since: start, careLogs: careLogs)
        let totalsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { logs in
                logs.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
            }
        return sevenDayPoints(
            totalsByDay: totalsByDay,
            start: start,
            todayLabel: todayLabel,
            calendar: calendar
        )
    }

    private static func sevenDayPoints(
        totalsByDay: [Date: Double],
        start: Date,
        todayLabel: String,
        calendar: Calendar
    ) -> [OhanaMinimalChartPoint] {
        (0 ..< 7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let total = totalsByDay[calendar.startOfDay(for: day)] ?? 0
            return OhanaMinimalChartPoint(
                date: day,
                value: total,
                label: calendar.isDateInToday(day) ? todayLabel : day.formatted(.dateTime.weekday(.narrow))
            )
        }
    }

    private static func todaySummary(
        pet: Pet,
        ledgerEntries: [QuickFeedLedgerEntry]?,
        legacyTodayLogs: [PetCareLog],
        now: Date,
        calendar: Calendar
    ) -> (dryFoodGrams: Double, wetFoodGrams: Double, treatGrams: Double, treatCount: Int, autoFeedCount: Int) {
        if let ledgerEntries {
            let todayEntries = ledgerEntries
                .filter { calendar.isDate($0.date, inSameDayAs: now) }
                .sorted { $0.date > $1.date }
            let mainTodayEntries = todayEntries.filter { $0.source != .treat }
            let treatEntries = todayEntries.filter { $0.source == .treat }
            let dryFoodGrams = mainTodayEntries
                .filter { $0.foodKind == .dry }
                .reduce(0) { $0 + QuickFeedOverviewSnapshot.effectiveMainFoodAmount(for: $1, pet: pet) }
            let wetFoodGrams = mainTodayEntries
                .filter { $0.foodKind == .wet }
                .reduce(0) { $0 + QuickFeedOverviewSnapshot.effectiveMainFoodAmount(for: $1, pet: pet) }
            return (
                dryFoodGrams,
                wetFoodGrams,
                treatEntries.reduce(0) { $0 + $1.displayAmountGrams },
                treatEntries.count,
                mainTodayEntries.count(where: { $0.source == .autoMain })
            )
        }

        let mainTodayLogs = legacyTodayLogs.filter { FeedLogMetadata.isMainFoodLog($0) }
        let treatTodayLogs = legacyTodayLogs.filter { FeedLogMetadata.isTreatLog($0) }
        let dryFoodGrams = mainTodayLogs
            .filter { $0.foodKind == .dry }
            .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
        let wetFoodGrams = mainTodayLogs
            .filter { $0.foodKind == .wet }
            .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
        return (
            dryFoodGrams,
            wetFoodGrams,
            treatTodayLogs.reduce(0) { $0 + max(0, $1.amountGrams) },
            treatTodayLogs.count,
            mainTodayLogs.count(where: { FeedLogMetadata.source(for: $0) == .autoMain })
        )
    }

    private static func latestAutoFeedDate(
        ledgerEntries: [QuickFeedLedgerEntry]?,
        legacyCareLogs: [PetCareLog]
    ) -> Date? {
        if let ledgerEntries {
            return ledgerEntries
                .filter { $0.source == .autoMain }
                .max { $0.date < $1.date }?
                .date
        }
        return legacyCareLogs
            .filter { FeedLogMetadata.source(for: $0) == .autoMain }
            .max { $0.date < $1.date }?
            .date
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
