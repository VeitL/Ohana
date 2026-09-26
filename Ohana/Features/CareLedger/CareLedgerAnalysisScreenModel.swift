//
//  CareLedgerAnalysisScreenModel.swift
//  Ohana
//
//  Read-model boundary for the care ledger analysis screen.
//

import Foundation
import Observation

nonisolated enum CareLedgerRangeFilter: CaseIterable, Hashable, Sendable {
    case week
    case month
    case days90
    case year
    case all

    @MainActor
    func title(l: L10n) -> String {
        switch self {
        case .week:
            l.tr(zh: "7 天", en: "7 days", de: "7 Tage")
        case .month:
            l.tr(zh: "30 天", en: "30 days", de: "30 Tage")
        case .days90:
            l.tr(zh: "90 天", en: "90 days", de: "90 Tage")
        case .year:
            l.tr(zh: "1 年", en: "1 year", de: "1 Jahr")
        case .all:
            l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }

    var requiresPersonal: Bool {
        self == .days90 || self == .year || self == .all
    }

    var cutoff: Date? {
        dayCount.flatMap {
            Calendar.current.date(byAdding: .day, value: -($0 - 1), to: Calendar.current.startOfDay(for: Date()))
        }
    }

    var dayCount: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .days90: 90
        case .year: 365
        case .all: nil
        }
    }

    var trendDayCount: Int {
        switch self {
        case .week:
            7
        case .month:
            30
        case .days90:
            90
        case .year:
            365
        case .all:
            365
        }
    }
}

@Observable
final class CareLedgerAnalysisScreenModel {
    var selectedRange: CareLedgerRangeFilter = .week
    var selectedKind: CareLedgerEventKind?
    var selectedSubjectKey: String?

    private var ledgerEvents: [CareLedgerAnalysisEventSnapshot] = []
    private var subjects: [CareLedgerAnalysisSubjectSnapshot] = []

    func applyQuerySnapshot(
        ledgerEvents: [CareLedgerAnalysisEventSnapshot],
        subjects: [CareLedgerAnalysisSubjectSnapshot] = []
    ) {
        self.ledgerEvents = ledgerEvents
        self.subjects = subjects
    }

    var availableSubjects: [CareLedgerAnalysisSubjectSnapshot] {
        subjects
    }

    var filteredEvents: [CareLedgerAnalysisEventSnapshot] {
        let cutoff = selectedRange.cutoff
        return ledgerEvents.filter { event in
            let inRange = cutoff.map { event.occurredAt >= $0 } ?? true
            let matchesKind = selectedKind.map { eventKind(for: event) == $0 } ?? true
            let matchesSubject = selectedSubjectKey.map { subjectKey(for: event) == $0 } ?? true
            return inRange && matchesKind && matchesSubject
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
        let grouped = Dictionary(grouping: operationRepresentatives(in: filteredEvents), by: eventKind(for:))
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
        if let name = subjects.first(where: { $0.kind == kind && $0.subjectID == id })?.name {
            return name
        }
        if kind == CareLedgerActorKind.human.rawValue {
            return l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        if kind == CareLedgerActorKind.pet.rawValue {
            return l.tr(zh: "宠物", en: "Pet", de: "Haustier")
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
        if let name = subjects.first(where: { $0.kind == kind && $0.subjectID == id })?.name {
            return name
        }
        if kind == CareLedgerSubjectKind.pet.rawValue {
            return l.tr(zh: "宠物", en: "Pet", de: "Haustier")
        }
        if kind == CareLedgerSubjectKind.human.rawValue {
            return l.tr(zh: "家人", en: "Family", de: "Familie")
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

    private func operationRepresentatives(
        in events: [CareLedgerAnalysisEventSnapshot]
    ) -> [CareLedgerAnalysisEventSnapshot] {
        Dictionary(grouping: events, by: operationKey(for:))
            .values
            .compactMap { group in
                group.min { $0.occurredAt < $1.occurredAt }
            }
    }

    private func operationKey(for event: CareLedgerAnalysisEventSnapshot) -> String {
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

    private func coverageKey(for event: CareLedgerAnalysisEventSnapshot) -> String {
        let subjectKey = event.subjectId.map { "\(event.subjectKind):\($0)" }
            ?? "event:\(event.id.uuidString)"
        return "\(operationKey(for: event)):\(subjectKey)"
    }

    private func subjectKey(for event: CareLedgerAnalysisEventSnapshot) -> String {
        guard let id = event.subjectId, !id.isEmpty else { return "household" }
        return "\(event.subjectKind):\(id)"
    }

    private func eventKind(for event: CareLedgerAnalysisEventSnapshot) -> CareLedgerEventKind {
        CareLedgerEventKind(rawValue: event.eventKind) ?? .unknown
    }
}
