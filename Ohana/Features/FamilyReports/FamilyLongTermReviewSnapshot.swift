import Foundation
import SwiftData

nonisolated enum FamilyLongTermReviewRange: String, CaseIterable, Identifiable, Hashable, Sendable {
    case days90
    case year
    case all

    var id: String { rawValue }

    var cutoffDayCount: Int? {
        switch self {
        case .days90: 90
        case .year: 365
        case .all: nil
        }
    }
}

nonisolated struct FamilyLongTermReviewMonth: Identifiable, Equatable, Sendable {
    var id: Date { monthStart }
    let monthStart: Date
    let operationCount: Int
    let memoryCount: Int
    let highlightKind: CareLedgerEventKind?
    let highlightSubjectName: String
}

nonisolated struct FamilyLongTermReviewSubjectStat: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let operationCount: Int
}

nonisolated struct FamilyLongTermReviewSnapshot: Equatable, Sendable {
    let range: FamilyLongTermReviewRange
    let interval: DateInterval
    let operationCount: Int
    let activeMonthCount: Int
    let memoryCount: Int
    let expenseTotal: Double
    let weightRecordCount: Int
    let months: [FamilyLongTermReviewMonth]
    let subjects: [FamilyLongTermReviewSubjectStat]
    let isTruncated: Bool
    let hasLoaded: Bool

    static func empty(range: FamilyLongTermReviewRange = .year, now: Date = Date()) -> Self {
        FamilyLongTermReviewSnapshot(
            range: range,
            interval: DateInterval(start: now, end: now),
            operationCount: 0,
            activeMonthCount: 0,
            memoryCount: 0,
            expenseTotal: 0,
            weightRecordCount: 0,
            months: [],
            subjects: [],
            isTruncated: false,
            hasLoaded: false
        )
    }
}

@ModelActor
actor FamilyLongTermReviewDataActor {
    private static let eventLimit = 8_000
    private static let memoryLimit = 800

    func load(
        range: FamilyLongTermReviewRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> FamilyLongTermReviewSnapshot {
        try Task.checkCancellation()
        let cutoff = range.cutoffDayCount.flatMap {
            calendar.date(byAdding: .day, value: -($0 - 1), to: calendar.startOfDay(for: now))
        }
        let eventFetch = try fetchEvents(cutoff: cutoff)
        let memoryFetch = try fetchMemories(cutoff: cutoff)
        let events = eventFetch.records
        let memories = memoryFetch.records
        let names = try fetchSubjectNames()
        try Task.checkCancellation()

        let representatives = operationRepresentatives(in: events)
        let earliestDate = min(
            representatives.map(\.occurredAt).min() ?? now,
            memories.map(\.date).min() ?? now
        )
        let intervalStart = cutoff ?? earliestDate
        let interval = DateInterval(start: intervalStart, end: now)
        let memoriesByMonth = Dictionary(grouping: memories) {
            calendar.dateInterval(of: .month, for: $0.date)?.start ?? calendar.startOfDay(for: $0.date)
        }
        let eventsByMonth = Dictionary(grouping: representatives) {
            calendar.dateInterval(of: .month, for: $0.occurredAt)?.start ?? calendar.startOfDay(for: $0.occurredAt)
        }
        let monthKeys = Set(memoriesByMonth.keys).union(eventsByMonth.keys).sorted(by: >)
        let months = monthKeys.map { monthStart in
            let monthEvents = eventsByMonth[monthStart] ?? []
            let latest = monthEvents.max { $0.occurredAt < $1.occurredAt }
            return FamilyLongTermReviewMonth(
                monthStart: monthStart,
                operationCount: monthEvents.count,
                memoryCount: memoriesByMonth[monthStart]?.count ?? 0,
                highlightKind: latest?.eventKindEnum,
                highlightSubjectName: subjectName(for: latest, names: names)
            )
        }
        let subjectStats = Dictionary(grouping: representatives) { event in
            subjectKey(for: event)
        }
            .compactMap { key, grouped -> FamilyLongTermReviewSubjectStat? in
                guard key != "household" else { return nil }
                let name = names[key] ?? fallbackSubjectName(for: grouped.first)
                return FamilyLongTermReviewSubjectStat(
                    id: key,
                    name: name,
                    operationCount: grouped.count
                )
            }
            .sorted { $0.operationCount > $1.operationCount }

        return FamilyLongTermReviewSnapshot(
            range: range,
            interval: interval,
            operationCount: representatives.count,
            activeMonthCount: months.count,
            memoryCount: memories.count,
            expenseTotal: representatives
                .filter { $0.eventKindEnum == .expense && $0.amountValue > 0 }
                .reduce(0) { $0 + $1.amountValue },
            weightRecordCount: representatives.count(where: { $0.eventKindEnum == .weight }),
            months: months,
            subjects: Array(subjectStats.prefix(12)),
            isTruncated: eventFetch.isTruncated || memoryFetch.isTruncated,
            hasLoaded: true
        )
    }

    private func fetchEvents(cutoff: Date?) throws -> (records: [CareLedgerEvent], isTruncated: Bool) {
        var descriptor: FetchDescriptor<CareLedgerEvent>
        if let cutoff {
            descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { $0.occurredAt >= cutoff },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<CareLedgerEvent>(
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = Self.eventLimit + 1
        let fetched = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return (Array(fetched.prefix(Self.eventLimit)), fetched.count > Self.eventLimit)
    }

    private func fetchMemories(cutoff: Date?) throws -> (records: [PetPhotoLog], isTruncated: Bool) {
        var descriptor: FetchDescriptor<PetPhotoLog>
        if let cutoff {
            descriptor = FetchDescriptor<PetPhotoLog>(
                predicate: #Predicate<PetPhotoLog> { $0.date >= cutoff },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<PetPhotoLog>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }
        descriptor.fetchLimit = Self.memoryLimit + 1
        let fetched = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return (Array(fetched.prefix(Self.memoryLimit)), fetched.count > Self.memoryLimit)
    }

    private func fetchSubjectNames() throws -> [String: String] {
        var names: [String: String] = [:]
        var petDescriptor = FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)])
        petDescriptor.fetchLimit = 500
        for pet in try modelContext.fetch(petDescriptor) { // route-first-frame: allow deferred-fetch
            names["pet:\(pet.id.uuidString)"] = pet.name
        }
        var humanDescriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)])
        humanDescriptor.fetchLimit = 500
        for human in try modelContext.fetch(humanDescriptor) { // route-first-frame: allow deferred-fetch
            names["human:\(human.id.uuidString)"] = human.name
        }
        var plantDescriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)])
        plantDescriptor.fetchLimit = 1_000
        for plant in try modelContext.fetch(plantDescriptor) { // route-first-frame: allow deferred-fetch
            names["plant:\(plant.id.uuidString)"] = plant.name
        }
        return names
    }

    private func operationRepresentatives(in events: [CareLedgerEvent]) -> [CareLedgerEvent] {
        Dictionary(grouping: events, by: operationKey(for:))
            .values
            .compactMap { $0.min { $0.occurredAt < $1.occurredAt } }
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

    private func subjectKey(for event: CareLedgerEvent) -> String {
        guard let id = event.subjectId, !id.isEmpty else { return "household" }
        return "\(event.subjectKind):\(id)"
    }

    private func subjectName(
        for event: CareLedgerEvent?,
        names: [String: String]
    ) -> String {
        guard let event else { return "" }
        return names[subjectKey(for: event)] ?? fallbackSubjectName(for: event)
    }

    private func fallbackSubjectName(for event: CareLedgerEvent?) -> String {
        switch event?.subjectKind {
        case CareLedgerSubjectKind.pet.rawValue: "Pet"
        case CareLedgerSubjectKind.human.rawValue: "Human"
        case CareLedgerSubjectKind.plant.rawValue: "Plant"
        default: "Household"
        }
    }
}
