//
//  ExpandedQuickActionHygieneStatus.swift
//  Ohana
//
//  Hygiene cycle status helpers for expanded-card quick actions.
//

import Foundation

nonisolated struct HomeHygieneCycleWarning: Equatable {
    let type: HygieneType
    let status: CareCycleStatus
}

extension ExpandedQuickActionLogic {
    nonisolated static func mostUrgentHygieneWarning(
        for pet: Pet,
        hygieneLedgerEntries: [HomeHygieneQuickActionEntry],
        now: Date,
        calendar cal: Calendar,
        includeDueToday: Bool
    ) -> HomeHygieneCycleWarning? {
        HygieneType.allCases.compactMap { type -> HomeHygieneCycleWarning? in
            guard let status = hygieneCycleStatus(
                for: pet,
                type: type,
                hygieneLedgerEntries: hygieneLedgerEntries,
                now: now,
                calendar: cal
            ) else { return nil }
            guard includeDueToday ? status.requiresAttention : status.isOverdue else { return nil }
            return HomeHygieneCycleWarning(type: type, status: status)
        }
        .sorted { lhs, rhs in
            if lhs.status.daysUntilDue == rhs.status.daysUntilDue {
                return lhs.type.rawValue < rhs.type.rawValue
            }
            return lhs.status.daysUntilDue < rhs.status.daysUntilDue
        }
        .first
    }

    nonisolated static func hygieneCycleStatus(
        for pet: Pet,
        type: HygieneType,
        hygieneLedgerEntries: [HomeHygieneQuickActionEntry],
        now: Date,
        calendar cal: Calendar
    ) -> CareCycleStatus? {
        let latestDate = hygieneLedgerEntries
            .filter { $0.petId == pet.id && $0.hygieneType == type }
            .map(\.date)
            .max()
        return type.cycleStatus(lastDate: latestDate, petId: pet.id, now: now, calendar: cal)
    }
}
