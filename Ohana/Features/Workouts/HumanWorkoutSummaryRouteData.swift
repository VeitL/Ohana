//
//  HumanWorkoutSummaryRouteData.swift
//  Ohana
//
//  Bounded SwiftData reads for the Human workout summary route.
//

import Foundation
import SwiftData

nonisolated struct HumanWorkoutBoundHumanProfile: Equatable, Sendable {
    let id: UUID
    let name: String
    let hasPassedAway: Bool
}

@MainActor
struct HumanWorkoutLocalHistoryPage {
    let logs: [HumanWorkoutLog]
    let readState: HumanWorkoutHistoryReadState
}

enum HumanWorkoutSummaryRouteData {
    private static let maximumWorkoutQueryLimit = 512

    @MainActor
    static func boundHumanProfile(
        id: UUID,
        from context: ModelContext
    ) throws -> HumanWorkoutBoundHumanProfile? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { candidate in
                candidate.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map {
            HumanWorkoutBoundHumanProfile(
                id: $0.id,
                name: $0.name,
                hasPassedAway: $0.hasPassedAway
            )
        }
    }

    @MainActor
    static func localWorkoutHistory(
        humanID: UUID,
        since startDate: Date,
        through endDate: Date,
        limit: Int,
        from context: ModelContext
    ) throws -> HumanWorkoutLocalHistoryPage {
        let queryLimit = max(1, min(limit, maximumWorkoutQueryLimit))
        var descriptor = FetchDescriptor<HumanWorkoutLog>(
            predicate: #Predicate<HumanWorkoutLog> { log in
                log.human?.id == humanID && log.date >= startDate && log.date <= endDate
            },
            sortBy: [SortDescriptor(\HumanWorkoutLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = queryLimit + 1
        let logs = try context.fetch(descriptor)
        return HumanWorkoutLocalHistoryPage(
            logs: Array(logs.prefix(queryLimit)),
            readState: logs.count > queryLimit ? .truncated : .complete
        )
    }
}
