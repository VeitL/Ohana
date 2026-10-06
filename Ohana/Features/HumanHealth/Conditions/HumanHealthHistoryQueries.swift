//
//  HumanHealthHistoryQueries.swift
//  Ohana
//
//  Stable, bounded keyset pagination for Human health-condition facts.
//

import Foundation
import SwiftData

nonisolated struct HumanHealthHistoryPageCursor: Equatable, Hashable, Sendable {
    let primaryDate: Date
    let createdAt: Date
    let id: UUID
}

@MainActor
struct HumanHealthConditionPage {
    let records: [HumanHealthCondition]
    let nextCursor: HumanHealthHistoryPageCursor?
    let hasOlder: Bool
}

@MainActor
struct HumanHealthObservationPage {
    let records: [HumanHealthObservation]
    let nextCursor: HumanHealthHistoryPageCursor?
    let hasOlder: Bool
}

@MainActor
enum HumanHealthConditionHistoryQuery {
    nonisolated static let defaultPageSize = 64
    nonisolated static let maximumPageSize = 128
    private nonisolated static let ownerCandidateMultiplier = 4

    static func page(
        humanID: UUID,
        olderThan cursor: HumanHealthHistoryPageCursor? = nil,
        limit: Int = defaultPageSize,
        context: ModelContext
    ) throws -> HumanHealthConditionPage {
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        let pageSize = max(1, min(limit, maximumPageSize))
        let candidateLimit = pageSize * ownerCandidateMultiplier + 1
        var descriptor: FetchDescriptor<HumanHealthCondition>

        if let cursor {
            let cursorDate = cursor.primaryDate
            let cursorCreatedAt = cursor.createdAt
            let cursorID = cursor.id
            descriptor = FetchDescriptor<HumanHealthCondition>(
                predicate: #Predicate<HumanHealthCondition> { condition in
                    (condition.humanId.contains(humanKey) || condition.humanId.contains(humanKeyLower))
                        && (condition.updatedAt < cursorDate
                            || (condition.updatedAt == cursorDate
                                && (condition.createdAt < cursorCreatedAt
                                    || (condition.createdAt == cursorCreatedAt
                                        && condition.id < cursorID))))
                },
                sortBy: [
                    SortDescriptor(\HumanHealthCondition.updatedAt, order: .reverse),
                    SortDescriptor(\HumanHealthCondition.createdAt, order: .reverse),
                    SortDescriptor(\HumanHealthCondition.id, order: .reverse)
                ]
            )
        } else {
            descriptor = FetchDescriptor<HumanHealthCondition>(
                predicate: #Predicate<HumanHealthCondition> { condition in
                    condition.humanId.contains(humanKey) || condition.humanId.contains(humanKeyLower)
                },
                sortBy: [
                    SortDescriptor(\HumanHealthCondition.updatedAt, order: .reverse),
                    SortDescriptor(\HumanHealthCondition.createdAt, order: .reverse),
                    SortDescriptor(\HumanHealthCondition.id, order: .reverse)
                ]
            )
        }

        descriptor.fetchLimit = candidateLimit
        let fetched = try context.fetch(descriptor)
        let canonical = fetched.filter { canonicalUUID($0.humanId) == humanID }
        let probed = Array(canonical.prefix(pageSize + 1))
        let records = Array(probed.prefix(pageSize))
        let hasOlder = probed.count > pageSize ||
            (fetched.count == candidateLimit && records.count == pageSize)
        return HumanHealthConditionPage(
            records: records,
            nextCursor: hasOlder ? records.last.map { makeCursor(for: $0) } : nil,
            hasOlder: hasOlder
        )
    }

    private static func makeCursor(for condition: HumanHealthCondition) -> HumanHealthHistoryPageCursor {
        HumanHealthHistoryPageCursor(
            primaryDate: condition.updatedAt,
            createdAt: condition.createdAt,
            id: condition.id
        )
    }

    private nonisolated static func canonicalUUID(_ raw: String) -> UUID? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

@MainActor
enum HumanHealthObservationHistoryQuery {
    nonisolated static let defaultPageSize = 40
    nonisolated static let maximumPageSize = 100
    private nonisolated static let ownerCandidateMultiplier = 4

    static func page(
        humanID: UUID,
        conditionID: UUID,
        olderThan cursor: HumanHealthHistoryPageCursor? = nil,
        limit: Int = defaultPageSize,
        context: ModelContext
    ) throws -> HumanHealthObservationPage {
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        let conditionKey = conditionID.uuidString
        let conditionKeyLower = conditionKey.lowercased()
        let pageSize = max(1, min(limit, maximumPageSize))
        let candidateLimit = pageSize * ownerCandidateMultiplier + 1
        let candidates = try fetchCandidates(
            humanKey: humanKey,
            humanKeyLower: humanKeyLower,
            conditionKey: conditionKey,
            conditionKeyLower: conditionKeyLower,
            olderThan: cursor,
            limit: candidateLimit,
            context: context
        )
        let canonical = candidates.filter { observation in
            canonicalUUID(observation.humanId) == humanID &&
                canonicalUUID(observation.conditionId) == conditionID
        }
        let probed = Array(canonical.prefix(pageSize + 1))
        let records = Array(probed.prefix(pageSize))
        let hasOlder = probed.count > pageSize ||
            (candidates.count == candidateLimit && records.count == pageSize)
        return HumanHealthObservationPage(
            records: records,
            nextCursor: hasOlder ? records.last.map { makeCursor(for: $0) } : nil,
            hasOlder: hasOlder
        )
    }

    private static func fetchCandidates(
        humanKey: String,
        humanKeyLower: String,
        conditionKey: String,
        conditionKeyLower: String,
        olderThan cursor: HumanHealthHistoryPageCursor?,
        limit: Int,
        context: ModelContext
    ) throws -> [HumanHealthObservation] {
        let humanKeys = humanKey == humanKeyLower ? [humanKey] : [humanKey, humanKeyLower]
        let conditionKeys = conditionKey == conditionKeyLower
            ? [conditionKey]
            : [conditionKey, conditionKeyLower]
        var candidatesByID: [UUID: HumanHealthObservation] = [:]

        for ownerCandidate in humanKeys {
            for conditionCandidate in conditionKeys {
                let candidates = try fetchCandidateVariant(
                    humanKey: ownerCandidate,
                    conditionKey: conditionCandidate,
                    olderThan: cursor,
                    limit: limit,
                    context: context
                )
                for candidate in candidates {
                    candidatesByID[candidate.id] = candidate
                }
            }
        }

        return Array(candidatesByID.values.sorted(by: Self.isNewer).prefix(limit))
    }

    private static func fetchCandidateVariant(
        humanKey: String,
        conditionKey: String,
        olderThan cursor: HumanHealthHistoryPageCursor?,
        limit: Int,
        context: ModelContext
    ) throws -> [HumanHealthObservation] {
        var descriptor: FetchDescriptor<HumanHealthObservation>
        if let cursor {
            let cursorDate = cursor.primaryDate
            let cursorCreatedAt = cursor.createdAt
            let cursorID = cursor.id
            descriptor = FetchDescriptor<HumanHealthObservation>(
                predicate: #Predicate<HumanHealthObservation> { observation in
                    observation.humanId.contains(humanKey)
                        && observation.conditionId.contains(conditionKey)
                        && (observation.recordedAt < cursorDate
                            || (observation.recordedAt == cursorDate
                                && (observation.createdAt < cursorCreatedAt
                                    || (observation.createdAt == cursorCreatedAt
                                        && observation.id < cursorID))))
                },
                sortBy: sortDescriptors
            )
        } else {
            descriptor = FetchDescriptor<HumanHealthObservation>(
                predicate: #Predicate<HumanHealthObservation> { observation in
                    observation.humanId.contains(humanKey)
                        && observation.conditionId.contains(conditionKey)
                },
                sortBy: sortDescriptors
            )
        }
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    private static func isNewer(_ lhs: HumanHealthObservation, _ rhs: HumanHealthObservation) -> Bool {
        if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt > rhs.recordedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id > rhs.id
    }

    private static var sortDescriptors: [SortDescriptor<HumanHealthObservation>] {
        [
            SortDescriptor(\HumanHealthObservation.recordedAt, order: .reverse),
            SortDescriptor(\HumanHealthObservation.createdAt, order: .reverse),
            SortDescriptor(\HumanHealthObservation.id, order: .reverse)
        ]
    }

    private static func makeCursor(for observation: HumanHealthObservation) -> HumanHealthHistoryPageCursor {
        HumanHealthHistoryPageCursor(
            primaryDate: observation.recordedAt,
            createdAt: observation.createdAt,
            id: observation.id
        )
    }

    private nonisolated static func canonicalUUID(_ raw: String) -> UUID? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
