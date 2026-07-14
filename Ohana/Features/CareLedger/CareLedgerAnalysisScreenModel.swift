//
//  CareLedgerAnalysisScreenModel.swift
//  Ohana
//
//  Read-model boundary for the care ledger analysis screen.
//

import Foundation
import Observation

enum CareLedgerRangeFilter: CaseIterable {
    case week
    case month
    case all

    func title(l: L10n) -> String {
        switch self {
        case .week:
            l.tr(zh: "本周", en: "This week", de: "Diese Woche")
        case .month:
            l.tr(zh: "本月", en: "This month", de: "Dieser Monat")
        case .all:
            l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }

    var cutoff: Date? {
        switch self {
        case .week:
            Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month:
            Calendar.current.date(byAdding: .month, value: -1, to: Date())
        case .all:
            nil
        }
    }

    var trendDayCount: Int {
        switch self {
        case .week:
            7
        case .month:
            30
        case .all:
            14
        }
    }
}

@Observable
final class CareLedgerAnalysisScreenModel {
    var selectedRange: CareLedgerRangeFilter = .week
    var selectedKind: CareLedgerEventKind?

    private var ledgerEvents: [CareLedgerEvent] = []
    private var pets: [Pet] = []
    private var humans: [Human] = []

    func applyQuerySnapshot(
        ledgerEvents: [CareLedgerEvent],
        pets: [Pet],
        humans: [Human]
    ) {
        self.ledgerEvents = ledgerEvents
        self.pets = pets
        self.humans = humans
    }

    var filteredEvents: [CareLedgerEvent] {
        let cutoff = selectedRange.cutoff
        return ledgerEvents.filter { event in
            let inRange = cutoff.map { event.occurredAt >= $0 } ?? true
            let matchesKind = selectedKind.map { event.eventKindEnum == $0 } ?? true
            return inRange && matchesKind
        }
    }

    var positiveRewardTotal: Int {
        filteredEvents.reduce(0) { $0 + max($1.coconutDelta, 0) }
    }

    /// A shared pet-care session or plant batch is one real-world action even
    /// when it produces one ledger event per covered subject.
    var realOperationCount: Int {
        operationRepresentatives(in: filteredEvents).count
    }

    /// Ledger child events intentionally stay subject-scoped, so their count
    /// describes how many pets, plants, or humans the actions covered.
    var objectCoverageCount: Int {
        Set(filteredEvents.map(coverageKey(for:))).count
    }

    var kindStats: [(CareLedgerEventKind, Int)] {
        let grouped = Dictionary(grouping: operationRepresentatives(in: filteredEvents), by: \.eventKindEnum)
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    var dailyTrendPoints: [OhanaMinimalChartPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayCount = selectedRange.trendDayCount
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let eventsInTrendWindow = operationRepresentatives(in: filteredEvents).filter { event in
            event.occurredAt >= start
        }
        let countByDay = Dictionary(grouping: eventsInTrendWindow) { event in
            calendar.startOfDay(for: event.occurredAt)
        }.mapValues(\.count)

        return (0 ..< dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return OhanaMinimalChartPoint(
                date: date,
                value: Double(countByDay[date, default: 0]),
                label: trendLabel(for: date, calendar: calendar),
                id: "care-ledger-trend-\(offset)"
            )
        }
    }

    var dailyTrendActiveDayCount: Int {
        dailyTrendPoints.count(where: { $0.value > 0 })
    }

    var dailyTrendTotal: Int {
        Int(dailyTrendPoints.reduce(0) { $0 + $1.value })
    }

    var averageEventsPerActiveDay: Double {
        let activeDays = dailyTrendActiveDayCount
        guard activeDays > 0 else { return 0 }
        return Double(dailyTrendTotal) / Double(activeDays)
    }

    func actorStats(l: L10n) -> [(String, Int)] {
        let grouped = Dictionary(grouping: operationRepresentatives(in: filteredEvents)) { event in
            actorName(for: event.actorId, kind: event.actorKind, l: l)
        }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    func actorName(for id: String?, kind: String, l: L10n = .current) -> String {
        guard let id, !id.isEmpty else {
            return l.tr(zh: "系统/未指定", en: "System/unspecified", de: "System/nicht festgelegt")
        }
        if kind == CareLedgerActorKind.human.rawValue {
            return humans.first { $0.id.uuidString == id }?.name ?? l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        if kind == CareLedgerActorKind.pet.rawValue {
            return pets.first { $0.id.uuidString == id }?.name ?? l.tr(zh: "宠物", en: "Pet", de: "Haustier")
        }
        if kind == CareLedgerActorKind.plant.rawValue {
            return l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        }
        return l.tr(zh: "系统", en: "System", de: "System")
    }

    func subjectName(for id: String?, kind: String, l: L10n = .current) -> String {
        guard let id, !id.isEmpty else {
            return l.tr(zh: "全家", en: "Household", de: "Haushalt")
        }
        if kind == CareLedgerSubjectKind.pet.rawValue {
            return pets.first { $0.id.uuidString == id }?.name ?? l.tr(zh: "宠物", en: "Pet", de: "Haustier")
        }
        if kind == CareLedgerSubjectKind.human.rawValue {
            return humans.first { $0.id.uuidString == id }?.name ?? l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        if kind == CareLedgerSubjectKind.plant.rawValue {
            return l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        }
        return l.tr(zh: "全家", en: "Household", de: "Haushalt")
    }

    private func trendLabel(for date: Date, calendar: Calendar) -> String {
        if selectedRange == .week {
            return date.formatted(.dateTime.weekday(.narrow))
        }
        return "\(calendar.component(.day, from: date))"
    }

    private func operationRepresentatives(in events: [CareLedgerEvent]) -> [CareLedgerEvent] {
        Dictionary(grouping: events, by: operationKey(for:))
            .values
            .compactMap { group in
                group.min { $0.occurredAt < $1.occurredAt }
            }
    }

    private func operationKey(for event: CareLedgerEvent) -> String {
        let metadata = event.metadataJSON
        let transactionKey = CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.careTransactionId,
            in: metadata
        ) ?? CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.sharedSessionId,
            in: metadata
        ) ?? CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.batchID,
            in: metadata
        ) ?? event.id.uuidString

        return "\(transactionKey):\(event.eventKind):\(event.actionType)"
    }

    private func coverageKey(for event: CareLedgerEvent) -> String {
        let subjectKey = event.subjectId.map { "\(event.subjectKind):\($0)" }
            ?? "event:\(event.id.uuidString)"
        return "\(operationKey(for: event)):\(subjectKey)"
    }
}
