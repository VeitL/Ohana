//
//  QuickFeedOverviewSnapshotStore.swift
//  Ohana
//
//  Cached read model for heavier QuickFeed overview surfaces.
//

import Combine
import Foundation

struct QuickFeedLedgerEntry: Identifiable, Hashable {
    let id: UUID
    let petId: UUID
    let date: Date
    let amountGrams: Double
    let note: String
    let source: FeedLogSource
    let foodKind: FeedFoodKind
    let treatKind: FeedTreatKind?
    let legacyModelId: String?
    let sharedSessionId: String
    let actorId: String?
    let sourceEventId: String?
    let sourceReminderId: String?
    let metadataJSON: String

    var displayAmountGrams: Double {
        max(0, amountGrams)
    }

    nonisolated static func entries(
        pet: Pet,
        feedingLedgerEvents: [CareLedgerEvent],
        legacyCareLogs: [PetCareLog],
        manualPlanEvents: [Event] = [],
        autoFeederEvents: [Event] = []
    ) -> [QuickFeedLedgerEntry] {
        let legacyLogsById = Dictionary(uniqueKeysWithValues: legacyCareLogs.map { ($0.id.uuidString, $0) })
        let eventFoodKinds = (manualPlanEvents + autoFeederEvents).reduce(into: [String: FeedFoodKind]()) { result, event in
            result[event.id.uuidString] = event.foodKind
        }
        return feedingLedgerEvents.compactMap { event -> QuickFeedLedgerEntry? in
            guard event.eventKindEnum == .care,
                  event.actionType == CareType.feeding.rawValue,
                  event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  event.subjectId == pet.id.uuidString
            else { return nil }
            let legacyLog = event.legacyModelId.flatMap { legacyLogsById[$0] }
            let source = FeedLogMetadata.source(
                actionType: event.actionType,
                note: event.note,
                ledgerSource: event.sourceEnum,
                sourceEventId: event.sourceEventId,
                sourceReminderId: event.sourceReminderId,
                metadataJSON: event.metadataJSON
            ) ?? .manualMain
            let metadataFoodKind = CareLedgerMetadata.stringValue(
                named: CareLedgerMetadata.feedFoodKind,
                in: event.metadataJSON
            ).flatMap(FeedFoodKind.init(rawValue:))
            let metadataTreatKind = CareLedgerMetadata.stringValue(
                named: CareLedgerMetadata.feedTreatKind,
                in: event.metadataJSON
            ).flatMap(FeedTreatKind.init(rawValue:))
            let metadataSharedSessionId = CareLedgerMetadata.stringValue(
                named: CareLedgerMetadata.sharedSessionId,
                in: event.metadataJSON
            )
            return QuickFeedLedgerEntry(
                id: event.id,
                petId: pet.id,
                date: event.occurredAt,
                amountGrams: event.amountValue,
                note: event.note,
                source: source,
                foodKind: metadataFoodKind ?? legacyLog?.foodKind ?? event.sourceEventId.flatMap { eventFoodKinds[$0] } ?? pet.mainFoodKind,
                treatKind: metadataTreatKind ?? legacyLog?.treatKind,
                legacyModelId: event.legacyModelId,
                sharedSessionId: metadataSharedSessionId ?? legacyLog?.sharedSessionId ?? "",
                actorId: event.actorId,
                sourceEventId: event.sourceEventId,
                sourceReminderId: event.sourceReminderId,
                metadataJSON: event.metadataJSON
            )
        }
        .sorted { $0.date > $1.date }
    }
}

struct QuickFeedOverviewSnapshot {
    let range: FeedOverviewRange
    let activeMode: FeedOperatingMode
    let startDate: Date
    let dates: [Date]
    let mainFoodLogsInRange: [QuickFeedLedgerEntry]
    let feedModeLogsInRange: [QuickFeedLedgerEntry]
    let feedModeRecentLogs: [QuickFeedLedgerEntry]
    let recentMainFoodLogs: [QuickFeedLedgerEntry]
    let todayPlanReminders: [Reminder]
    let nextPendingManualReminder: Reminder?
    let todayAutoFeedLogs: [QuickFeedLedgerEntry]
    let latestAutoFeedLog: QuickFeedLedgerEntry?
    let feedModePlanRemindersInRange: [Reminder]
    let mainFoodChartPoints: [FeedOverviewChartPoint]
    let feedModeChartPoints: [FeedOverviewChartPoint]
    let sourceTotals: [FeedLogSource: Double]
    let quickMainGramOptions: [Double]

    static func build(
        pet: Pet,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event] = [],
        feedingLedgerEntries: [QuickFeedLedgerEntry],
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
        let feedEntries = feedingLedgerEntries
        let mainLogs = feedEntries
            .filter { $0.source != .treat && $0.date >= startDate }
            .sorted { $0.date > $1.date }
        let feedModeLogs = mainLogs.filter { entry in
            switch activeMode {
            case .manual:
                entry.source == .manualMain
            case .manualReminder:
                entry.source == .manualReminder
            case .autoFeeder:
                entry.source == .autoMain
            }
        }
        let allPlanReminders = manualPlanEvents
            .flatMap(\.reminders)
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let todayPlanReminders = allPlanReminders
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let catchUpPlanReminders = allPlanReminders.filter { FeedPlanCatchUpPolicy.isCatchUpEligible($0, now: now) }
        let expiredMissedPlanReminders = allPlanReminders.filter { FeedPlanCatchUpPolicy.isExpiredMiss($0, now: now) }
        let nextPendingManualReminder = expiredMissedPlanReminders.isEmpty
            ? (catchUpPlanReminders.first ?? todayPlanReminders.first { ($0.isPending || $0.isFailed) && !$0.isCompleted })
            : nil
        let feedModePlanRemindersInRange = manualPlanEvents
            .flatMap(\.reminders)
            .filter { $0.scheduledAt >= startDate && $0.scheduledAt <= now }
            .sorted { $0.scheduledAt > $1.scheduledAt }
        let todayAutoFeedLogs = feedEntries
            .filter { log in
                calendar.isDate(log.date, inSameDayAs: now) &&
                    log.source == .autoMain
            }
            .sorted { $0.date > $1.date }
        let latestAutoFeedLog = feedEntries
            .filter { log in
                log.source == .autoMain
            }
            .max { $0.date < $1.date }
        let recentMainFoodLogs = Array(mainLogs.sorted { $0.date > $1.date }.prefix(8))
        let sourceTotals = FeedLogSource.quickFeedMainSources.reduce(into: [FeedLogSource: Double]()) { totals, source in
            totals[source] = mainLogs
                .filter { $0.source == source }
                .reduce(0) { $0 + effectiveMainFoodAmount(for: $1, pet: pet) }
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
        for logs: [QuickFeedLedgerEntry],
        dates: [Date],
        pet: Pet,
        calendar: Calendar
    ) -> [FeedOverviewChartPoint] {
        let totalsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { dayLogs in
                dayLogs.reduce(0) { $0 + effectiveMainFoodAmount(for: $1, pet: pet) }
            }
        return dates.map { day in
            FeedOverviewChartPoint(date: day, value: totalsByDay[calendar.startOfDay(for: day)] ?? 0)
        }
    }

    static func effectiveMainFoodAmount(for entry: QuickFeedLedgerEntry, pet: Pet) -> Double {
        entry.amountGrams > 0 ? entry.amountGrams : pet.dailyPortionGrams
    }

    private static func quickMainGramOptions(
        pet: Pet,
        defaultFeedGrams: Double,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event],
        recentMainFoodLogs: [QuickFeedLedgerEntry]
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
            .filter { $0.source != .treat && $0.amountGrams > 0 }
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
    let feedingLedgerRevision: Int
    let petRevision: Int
    let defaultFeedGrams: Int
    let rangeRawValue: String
    let activeModeRawValue: String
    let timeRevision: Int

    static func make(
        pet: Pet,
        manualPlanEvents: [Event],
        autoFeederEvents: [Event],
        feedingLedgerEntries: [QuickFeedLedgerEntry],
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
            feedingLedgerRevision: revisionHash(feedingLedgerEntries.prefix(360)) { hasher, entry in
                hasher.combine(entry.id)
                hasher.combine(entry.petId)
                hasher.combine(entry.date.timeIntervalSince1970)
                hasher.combine(entry.amountGrams)
                hasher.combine(entry.note)
                hasher.combine(entry.source.rawValue)
                hasher.combine(entry.foodKind.rawValue)
                hasher.combine(entry.treatKind?.rawValue)
                hasher.combine(entry.legacyModelId)
                hasher.combine(entry.sharedSessionId)
                hasher.combine(entry.actorId)
                hasher.combine(entry.sourceEventId)
                hasher.combine(entry.sourceReminderId)
                hasher.combine(entry.metadataJSON)
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

    private static func revisionHash<Element>(
        _ values: some Sequence<Element>,
        combine: (inout Hasher, Element) -> Void
    ) -> Int {
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
        feedingLedgerEntries: [QuickFeedLedgerEntry],
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
            feedingLedgerEntries: feedingLedgerEntries,
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
            feedingLedgerEntries: feedingLedgerEntries,
            range: range,
            activeMode: activeMode,
            defaultFeedGrams: defaultFeedGrams,
            now: now
        )
        revision = nextRevision
    }
}
