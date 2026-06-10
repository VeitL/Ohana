//
//  QuickFeedTreatSnapshotStore.swift
//  Ohana
//
//  Cached read model for treat overview filters and chart data.
//

import Combine
import Foundation

struct QuickFeedTreatSnapshot {
    let range: FeedOverviewRange
    let selectedKind: FeedTreatKind?
    let startDate: Date
    let dates: [Date]
    let logsInRange: [PetCareLog]
    let filteredLogsInRange: [PetCareLog]
    let filteredLogsToday: [PetCareLog]
    let filteredGramsToday: Double
    let chartPoints: [FeedOverviewChartPoint]
    let filteredChartPoints: [FeedOverviewChartPoint]
    let countByKind: [FeedTreatKind: Int]
    let lastDateByKind: [FeedTreatKind: Date]
    let lastAnyDate: Date?

    static func build(
        pet: Pet,
        careLogs: [PetCareLog],
        range: FeedOverviewRange,
        selectedKind: FeedTreatKind?,
        now: Date,
        calendar: Calendar = .current
    ) -> QuickFeedTreatSnapshot {
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -(range.days - 1), to: today) ?? today
        let dates = (0 ..< range.days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        let logs = FeedStockCalculator
            .treatLogs(for: pet, since: startDate, careLogs: careLogs)
            .sorted { $0.date > $1.date }
        let filtered = selectedKind.map { kind in
            logs.filter { ($0.treatKind ?? .other) == kind }
        } ?? logs
        let todayLogs = filtered.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let logsByKind = Dictionary(grouping: logs) { $0.treatKind ?? .other }

        return QuickFeedTreatSnapshot(
            range: range,
            selectedKind: selectedKind,
            startDate: startDate,
            dates: dates,
            logsInRange: logs,
            filteredLogsInRange: filtered,
            filteredLogsToday: todayLogs,
            filteredGramsToday: todayLogs.reduce(0) { $0 + max(0, $1.amountGrams) },
            chartPoints: countChartPoints(logs: logs, dates: dates, calendar: calendar),
            filteredChartPoints: countChartPoints(logs: filtered, dates: dates, calendar: calendar),
            countByKind: Dictionary(uniqueKeysWithValues: FeedTreatKind.allCases.map { kind in
                (kind, logsByKind[kind]?.count ?? 0)
            }),
            lastDateByKind: Dictionary(uniqueKeysWithValues: FeedTreatKind.allCases.compactMap { kind in
                guard let date = logsByKind[kind]?.map(\.date).max() else { return nil }
                return (kind, date)
            }),
            lastAnyDate: logs.map(\.date).max()
        )
    }

    func count(for kind: FeedTreatKind?) -> Int {
        kind.map { countByKind[$0] ?? 0 } ?? logsInRange.count
    }

    func lastDate(for kind: FeedTreatKind?) -> Date? {
        kind.map { lastDateByKind[$0] } ?? lastAnyDate
    }

    private static func countChartPoints(
        logs: [PetCareLog],
        dates: [Date],
        calendar: Calendar
    ) -> [FeedOverviewChartPoint] {
        let countsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.count }
        return dates.map { day in
            FeedOverviewChartPoint(date: day, value: Double(countsByDay[calendar.startOfDay(for: day)] ?? 0))
        }
    }
}

struct QuickFeedTreatSnapshotRevision: Equatable {
    let careLogRevision: Int
    let petRevision: Int
    let rangeRawValue: String
    let selectedKindRawValue: String
    let timeRevision: Int

    static func make(
        pet: Pet,
        careLogs: [PetCareLog],
        range: FeedOverviewRange,
        selectedKind: FeedTreatKind?,
        now: Date
    ) -> QuickFeedTreatSnapshotRevision {
        QuickFeedTreatSnapshotRevision(
            careLogRevision: revisionHash(careLogs.prefix(240)) { hasher, log in
                hasher.combine(log.id)
                hasher.combine(log.date.timeIntervalSince1970)
                hasher.combine(log.amountGrams)
                hasher.combine(log.note)
                hasher.combine(log.treatKindRaw)
            },
            petRevision: revisionHash([pet]) { hasher, pet in
                hasher.combine(pet.id)
            },
            rangeRawValue: range.rawValue,
            selectedKindRawValue: selectedKind?.rawValue ?? "all",
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
final class QuickFeedTreatSnapshotStore: ObservableObject {
    @Published private(set) var snapshot: QuickFeedTreatSnapshot
    private var revision: QuickFeedTreatSnapshotRevision?

    init(initial: QuickFeedTreatSnapshot) {
        snapshot = initial
    }

    func rebuild(
        pet: Pet,
        careLogs: [PetCareLog],
        range: FeedOverviewRange,
        selectedKind: FeedTreatKind?,
        now: Date,
        force: Bool = false
    ) {
        let nextRevision = QuickFeedTreatSnapshotRevision.make(
            pet: pet,
            careLogs: careLogs,
            range: range,
            selectedKind: selectedKind,
            now: now
        )
        guard force || nextRevision != revision else { return }
        snapshot = QuickFeedTreatSnapshot.build(
            pet: pet,
            careLogs: careLogs,
            range: range,
            selectedKind: selectedKind,
            now: now
        )
        revision = nextRevision
    }
}
