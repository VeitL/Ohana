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

    var title: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .all: return "全部"
        }
    }

    var cutoff: Date? {
        switch self {
        case .week:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month:
            return Calendar.current.date(byAdding: .month, value: -1, to: Date())
        case .all:
            return nil
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

    var actorStats: [(String, Int)] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            actorName(for: event.actorId, kind: event.actorKind)
        }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    func actorName(for id: String?, kind: String) -> String {
        guard let id, !id.isEmpty else { return "系统/未指定" }
        if kind == CareLedgerActorKind.human.rawValue {
            return humans.first { $0.id.uuidString == id }?.name ?? "家人"
        }
        if kind == CareLedgerActorKind.pet.rawValue {
            return pets.first { $0.id.uuidString == id }?.name ?? "宠物"
        }
        if kind == CareLedgerActorKind.plant.rawValue {
            return "植物"
        }
        return "系统"
    }

    func subjectName(for id: String?, kind: String) -> String {
        guard let id, !id.isEmpty else { return "全家" }
        if kind == CareLedgerSubjectKind.pet.rawValue {
            return pets.first { $0.id.uuidString == id }?.name ?? "宠物"
        }
        if kind == CareLedgerSubjectKind.human.rawValue {
            return humans.first { $0.id.uuidString == id }?.name ?? "家人"
        }
        if kind == CareLedgerSubjectKind.plant.rawValue {
            return "植物"
        }
        return "全家"
    }
}
