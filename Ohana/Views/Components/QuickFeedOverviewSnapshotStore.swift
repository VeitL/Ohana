//
//  QuickFeedOverviewSnapshotStore.swift
//  Ohana
//
//  Cached read model for heavier QuickFeed overview surfaces.
//

import Combine
import Foundation

struct QuickFeedOverviewSnapshot {
    let range: FeedOverviewRange
    let activeMode: FeedOperatingMode
    let startDate: Date
    let dates: [Date]
    let mainFoodLogsInRange: [PetCareLog]
    let feedModeLogsInRange: [PetCareLog]
    let feedModeRecentLogs: [PetCareLog]
    let recentMainFoodLogs: [PetCareLog]
    let todayPlanReminders: [Reminder]
    let nextPendingManualReminder: Reminder?
    let todayAutoFeedLogs: [PetCareLog]
    let latestAutoFeedLog: PetCareLog?
    let feedModePlanRemindersInRange: [Reminder]
    let mainFoodChartPoints: [FeedOverviewChartPoint]
    let feedModeChartPoints: [FeedOverviewChartPoint]
    let sourceTotals: [FeedLogSource: Double]
    let quickMainGramOptions: [Double]

    static func build(
        pet: Pet,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event] = [],
        careLogs: [PetCareLog],
        range: FeedOverviewRange,
        activeMode: FeedOperatingMode,
        defaultFeedGrams: Double = 0,
        now: Date,
        calendar: Calendar = .current
    ) -> QuickFeedOverviewSnapshot {
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -(range.days - 1), to: today) ?? today
        let dates = (0 ..< range.days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        let mainLogs = FeedStockCalculator.mainFoodLogs(for: pet, since: startDate, careLogs: careLogs)
        let feedModeLogs = mainLogs.filter { log in
            switch activeMode {
            case .manual:
                return FeedLogMetadata.source(for: log) == .manualMain
            case .manualReminder:
                return FeedLogMetadata.source(for: log) == .manualReminder
            case .autoFeeder:
                return FeedLogMetadata.source(for: log) == .autoMain
            }
        }
        let todayPlanReminders = manualPlanEvents
            .flatMap(\.reminders)
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let nextPendingManualReminder = todayPlanReminders.first { ($0.isPending || $0.isFailed) && !$0.isCompleted }
        let feedModePlanRemindersInRange = manualPlanEvents
            .flatMap(\.reminders)
            .filter { $0.scheduledAt >= startDate && $0.scheduledAt <= now }
            .sorted { $0.scheduledAt > $1.scheduledAt }
        let todayAutoFeedLogs = careLogs
            .filter { log in
                log.pet?.id == pet.id &&
                    log.careType == .feeding &&
                    calendar.isDate(log.date, inSameDayAs: now) &&
                    FeedLogMetadata.source(for: log) == .autoMain
            }
            .sorted { $0.date > $1.date }
        let latestAutoFeedLog = careLogs
            .filter { log in
                log.pet?.id == pet.id &&
                    log.careType == .feeding &&
                    FeedLogMetadata.source(for: log) == .autoMain
            }
            .max { $0.date < $1.date }
        let recentMainFoodLogs = Array(mainLogs.sorted { $0.date > $1.date }.prefix(8))
        let sourceTotals = FeedLogSource.quickFeedMainSources.reduce(into: [FeedLogSource: Double]()) { totals, source in
            totals[source] = mainLogs
                .filter { FeedLogMetadata.source(for: $0) == source }
                .reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
        }

        return QuickFeedOverviewSnapshot(
            range: range,
            activeMode: activeMode,
            startDate: startDate,
            dates: dates,
            mainFoodLogsInRange: mainLogs,
            feedModeLogsInRange: feedModeLogs,
            feedModeRecentLogs: Array(feedModeLogs.sorted { $0.date > $1.date }.prefix(40)),
            recentMainFoodLogs: recentMainFoodLogs,
            todayPlanReminders: todayPlanReminders,
            nextPendingManualReminder: nextPendingManualReminder,
            todayAutoFeedLogs: todayAutoFeedLogs,
            latestAutoFeedLog: latestAutoFeedLog,
            feedModePlanRemindersInRange: feedModePlanRemindersInRange,
            mainFoodChartPoints: chartPoints(for: mainLogs, dates: dates, pet: pet, calendar: calendar),
            feedModeChartPoints: chartPoints(for: feedModeLogs, dates: dates, pet: pet, calendar: calendar),
            sourceTotals: sourceTotals,
            quickMainGramOptions: quickMainGramOptions(
                pet: pet,
                defaultFeedGrams: defaultFeedGrams,
                manualPlanEvents: manualPlanEvents,
                autoFeederEvents: autoFeederEvents,
                recentMainFoodLogs: recentMainFoodLogs
            )
        )
    }

    func sourceTotal(_ source: FeedLogSource) -> Double {
        sourceTotals[source] ?? 0
    }

    private static func chartPoints(
        for logs: [PetCareLog],
        dates: [Date],
        pet: Pet,
        calendar: Calendar
    ) -> [FeedOverviewChartPoint] {
        let totalsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { dayLogs in
                dayLogs.reduce(0) { $0 + FeedStockCalculator.effectiveMainFoodAmount(for: $1, pet: pet) }
            }
        return dates.map { day in
            FeedOverviewChartPoint(date: day, value: totalsByDay[calendar.startOfDay(for: day)] ?? 0)
        }
    }

    private static func quickMainGramOptions(
        pet: Pet,
        defaultFeedGrams: Double,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event],
        recentMainFoodLogs: [PetCareLog]
    ) -> [Double] {
        var values: [Double] = []
        func append(_ value: Double) {
            let rounded = value.rounded()
            guard rounded > 0, !values.contains(where: { Int($0) == Int(rounded) }) else { return }
            values.append(rounded)
        }
        append(pet.dailyPortionGrams)
        append(defaultFeedGrams)
        manualPlanEvents.forEach { append(FeedRuleMetadata.amountGrams(from: $0)) }
        autoFeederEvents.forEach { append(FeedRuleMetadata.amountGrams(from: $0)) }
        recentMainFoodLogs
            .filter { FeedLogMetadata.isMainFoodLog($0) && $0.amountGrams > 0 }
            .forEach { append($0.amountGrams) }
        if values.isEmpty { values = [30, 40, 50, 60] }
        return Array(values.prefix(5))
    }
}

private extension FeedLogSource {
    static let quickFeedMainSources: [FeedLogSource] = [.manualMain, .manualReminder, .autoMain]
}

struct QuickFeedOverviewSnapshotRevision: Equatable {
    let manualPlanRevision: Int
    let autoFeederRevision: Int
    let careLogRevision: Int
    let petRevision: Int
    let defaultFeedGrams: Int
    let rangeRawValue: String
    let activeModeRawValue: String
    let timeRevision: Int

    static func make(
        pet: Pet,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event],
        careLogs: [PetCareLog],
        range: FeedOverviewRange,
        activeMode: FeedOperatingMode,
        defaultFeedGrams: Double,
        now: Date
    ) -> QuickFeedOverviewSnapshotRevision {
        QuickFeedOverviewSnapshotRevision(
            manualPlanRevision: revisionHash(manualPlanEvents.prefix(40)) { hasher, event in
                hasher.combine(event.id)
                hasher.combine(event.startDate.timeIntervalSince1970)
                hasher.combine(event.recurrenceDays)
                hasher.combine(event.reminders.count)
                for reminder in event.reminders.prefix(40) {
                    hasher.combine(reminder.id)
                    hasher.combine(reminder.scheduledAt.timeIntervalSince1970)
                    hasher.combine(reminder.status)
                }
            },
            autoFeederRevision: revisionHash(autoFeederEvents.prefix(40)) { hasher, event in
                hasher.combine(event.id)
                hasher.combine(event.startDate.timeIntervalSince1970)
                hasher.combine(event.recurrenceDays)
                hasher.combine(event.feedAmountGrams)
                hasher.combine(event.foodKindRaw)
            },
            careLogRevision: revisionHash(careLogs.prefix(240)) { hasher, log in
                hasher.combine(log.id)
                hasher.combine(log.date.timeIntervalSince1970)
                hasher.combine(log.amountGrams)
                hasher.combine(log.foodKindRaw)
                hasher.combine(log.note)
            },
            petRevision: revisionHash([pet]) { hasher, pet in
                hasher.combine(pet.id)
                hasher.combine(pet.dailyPortionGrams)
                hasher.combine(pet.mainFoodKindRaw)
            },
            defaultFeedGrams: Int(defaultFeedGrams.rounded()),
            rangeRawValue: range.rawValue,
            activeModeRawValue: activeMode.rawValue,
            timeRevision: Int(now.timeIntervalSince1970 / 60)
        )
    }

    private static func revisionHash<S: Sequence, Element>(
        _ values: S,
        combine: (inout Hasher, Element) -> Void
    ) -> Int where S.Element == Element {
        var hasher = Hasher()
        var count = 0
        for value in values {
            combine(&hasher, value)
            count += 1
        }
        hasher.combine(count)
        return hasher.finalize()
    }
}

@MainActor
final class QuickFeedOverviewSnapshotStore: ObservableObject {
    @Published private(set) var snapshot: QuickFeedOverviewSnapshot
    private var revision: QuickFeedOverviewSnapshotRevision?

    init(initial: QuickFeedOverviewSnapshot) {
        snapshot = initial
    }

    func rebuild(
        pet: Pet,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event],
        careLogs: [PetCareLog],
        range: FeedOverviewRange,
        activeMode: FeedOperatingMode,
        defaultFeedGrams: Double,
        now: Date,
        force: Bool = false
    ) {
        let nextRevision = QuickFeedOverviewSnapshotRevision.make(
            pet: pet,
            manualPlanEvents: manualPlanEvents,
            autoFeederEvents: autoFeederEvents,
            careLogs: careLogs,
            range: range,
            activeMode: activeMode,
            defaultFeedGrams: defaultFeedGrams,
            now: now
        )
        guard force || nextRevision != revision else { return }
        snapshot = QuickFeedOverviewSnapshot.build(
            pet: pet,
            manualPlanEvents: manualPlanEvents,
            autoFeederEvents: autoFeederEvents,
            careLogs: careLogs,
            range: range,
            activeMode: activeMode,
            defaultFeedGrams: defaultFeedGrams,
            now: now
        )
        revision = nextRevision
    }
}
