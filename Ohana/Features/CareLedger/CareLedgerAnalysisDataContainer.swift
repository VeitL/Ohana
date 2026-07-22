//
//  CareLedgerAnalysisDataContainer.swift
//  Ohana
//
//  Deferred, range-scoped read model for household care analysis.
//

import Foundation
import SwiftData
import SwiftUI

nonisolated struct CareLedgerAnalysisEventSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
    let actorKind: String
    let actorId: String?
    let subjectKind: String
    let subjectId: String?
    let eventKind: String
    let actionType: String
    let amountValue: Double
    let coconutDelta: Int
    let metadataJSON: String
}

nonisolated struct CareLedgerAnalysisSubjectSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let kind: String
    let subjectID: String
    let name: String
}

nonisolated struct CareLedgerAnalysisSnapshot: Equatable, Sendable {
    let revisionID: UUID
    let events: [CareLedgerAnalysisEventSnapshot]
    let subjects: [CareLedgerAnalysisSubjectSnapshot]
    let isTruncated: Bool
    let hasLoaded: Bool

    static let empty = CareLedgerAnalysisSnapshot(
        revisionID: UUID(),
        events: [],
        subjects: [],
        isTruncated: false,
        hasLoaded: false
    )
}

@ModelActor
actor CareLedgerAnalysisDataActor {
    private static let maximumAggregateEventCount = 20_000

    func load(
        range: CareLedgerRangeFilter,
        subjectKey: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> CareLedgerAnalysisSnapshot {
        try Task.checkCancellation()
        let subjects = try fetchSubjects()
        let cutoff = range.dayCount.flatMap { dayCount in
            calendar.date(
                byAdding: .day,
                value: -(dayCount - 1),
                to: calendar.startOfDay(for: now)
            )
        }
        let subject = Self.parseSubjectKey(subjectKey)
        let fetch = try fetchEvents(cutoff: cutoff, subject: subject)
        try Task.checkCancellation()

        return CareLedgerAnalysisSnapshot(
            revisionID: UUID(),
            events: fetch.records.map(Self.snapshot),
            subjects: subjects,
            isTruncated: fetch.isTruncated,
            hasLoaded: true
        )
    }

    private func fetchEvents(
        cutoff: Date?,
        subject: (kind: String, id: String)?
    ) throws -> (records: [CareLedgerEvent], isTruncated: Bool) {
        var descriptor: FetchDescriptor<CareLedgerEvent>
        switch (cutoff, subject) {
        case let (.some(cutoff), .some(subject)):
            let subjectKind = subject.kind
            let subjectID = subject.id
            descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.occurredAt >= cutoff &&
                        event.subjectKind == subjectKind &&
                        event.subjectId == subjectID
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        case let (.some(cutoff), .none):
            descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { $0.occurredAt >= cutoff },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        case let (.none, .some(subject)):
            let subjectKind = subject.kind
            let subjectID = subject.id
            descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == subjectKind && event.subjectId == subjectID
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        case (.none, .none):
            descriptor = FetchDescriptor<CareLedgerEvent>(
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = Self.maximumAggregateEventCount + 1
        let fetched = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return (
            Array(fetched.prefix(Self.maximumAggregateEventCount)),
            fetched.count > Self.maximumAggregateEventCount
        )
    }

    private func fetchSubjects() throws -> [CareLedgerAnalysisSubjectSnapshot] {
        var result: [CareLedgerAnalysisSubjectSnapshot] = []

        var petDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.passedAwayDate == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        petDescriptor.fetchLimit = 500
        result.append(contentsOf: try modelContext.fetch(petDescriptor).map { pet in // route-first-frame: allow deferred-fetch
            CareLedgerAnalysisSubjectSnapshot(
                id: "pet:\(pet.id.uuidString)",
                kind: CareLedgerSubjectKind.pet.rawValue,
                subjectID: pet.id.uuidString,
                name: pet.name
            )
        })

        var humanDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.passedAwayDate == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        humanDescriptor.fetchLimit = 500
        result.append(contentsOf: try modelContext.fetch(humanDescriptor).map { human in // route-first-frame: allow deferred-fetch
            CareLedgerAnalysisSubjectSnapshot(
                id: "human:\(human.id.uuidString)",
                kind: CareLedgerSubjectKind.human.rawValue,
                subjectID: human.id.uuidString,
                name: human.name
            )
        })

        var plantDescriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        plantDescriptor.fetchLimit = 1_000
        result.append(contentsOf: try modelContext.fetch(plantDescriptor).map { plant in // route-first-frame: allow deferred-fetch
            CareLedgerAnalysisSubjectSnapshot(
                id: "plant:\(plant.id.uuidString)",
                kind: CareLedgerSubjectKind.plant.rawValue,
                subjectID: plant.id.uuidString,
                name: plant.name
            )
        })

        return result.sorted {
            if $0.kind == $1.kind {
                if $0.name == $1.name { return $0.id < $1.id }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.kind < $1.kind
        }
    }

    private static func parseSubjectKey(_ key: String?) -> (kind: String, id: String)? {
        guard let key,
              let separator = key.firstIndex(of: ":") else { return nil }
        let kind = String(key[..<separator])
        let id = String(key[key.index(after: separator)...])
        guard !kind.isEmpty, !id.isEmpty else { return nil }
        return (kind, id)
    }

    private static func snapshot(_ event: CareLedgerEvent) -> CareLedgerAnalysisEventSnapshot {
        CareLedgerAnalysisEventSnapshot(
            id: event.id,
            occurredAt: event.occurredAt,
            actorKind: event.actorKind,
            actorId: event.actorId,
            subjectKind: event.subjectKind,
            subjectId: event.subjectId,
            eventKind: event.eventKind,
            actionType: event.actionType,
            amountValue: event.amountValue,
            coconutDelta: event.coconutDelta,
            metadataJSON: event.metadataJSON
        )
    }
}

struct CareLedgerAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var snapshot = CareLedgerAnalysisSnapshot.empty
    @State private var requestedRange: CareLedgerRangeFilter = .week
    @State private var requestedSubjectKey: String?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        CareLedgerAnalysisContentView(
            snapshot: snapshot,
            onFilterChange: requestSnapshot
        )
        .onAppear { scheduleLoad() }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleLoad(force: true)
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func requestSnapshot(_ range: CareLedgerRangeFilter, _ subjectKey: String?) {
        guard requestedRange != range || requestedSubjectKey != subjectKey else { return }
        requestedRange = range
        requestedSubjectKey = subjectKey
        scheduleLoad(force: true)
    }

    private func scheduleLoad(force: Bool = false) {
        guard force || !snapshot.hasLoaded else { return }
        loadTask?.cancel()
        let container = modelContext.container
        let range = requestedRange
        let subjectKey = requestedSubjectKey
        loadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 80)
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await CareLedgerAnalysisDataActor(modelContainer: container)
                    .load(range: range, subjectKey: subjectKey)
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Care ledger analysis snapshot load failed: \(error.localizedDescription)",
                    category: "CareLedger"
                )
            }
            loadTask = nil
        }
    }
}
