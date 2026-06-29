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

    var kindStats: [(CareLedgerEventKind, Int)] {
        let grouped = Dictionary(grouping: filteredEvents, by: \.eventKindEnum)
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    func actorStats(l: L10n) -> [(String, Int)] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
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
}
