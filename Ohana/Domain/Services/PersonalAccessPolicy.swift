//
//  PersonalAccessPolicy.swift
//  Ohana
//
//  Pure Free/Personal quota decisions. Persistence adapters provide counts;
//  this policy never fetches or mutates SwiftData models.
//

import Foundation

nonisolated enum PersonalAccessLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case personal
}

/// Resources whose *active* count is limited for Free households.
///
/// Records, history, exports, deceased members, archived plants, completed
/// plans, and health-critical plans are intentionally absent from this list.
nonisolated enum PersonalLimitedResource: String, Codable, CaseIterable, Hashable, Sendable {
    case activePet
    case activeHuman
    case activePlant
    case ordinaryActivePlan
}

nonisolated struct PersonalFreeLimits: Equatable, Sendable {
    static let current = PersonalFreeLimits(
        activePets: 1,
        activeHumans: 2,
        activePlants: 5,
        ordinaryActivePlans: 3
    )

    let activePets: Int
    let activeHumans: Int
    let activePlants: Int
    let ordinaryActivePlans: Int

    private init(
        activePets: Int,
        activeHumans: Int,
        activePlants: Int,
        ordinaryActivePlans: Int
    ) {
        self.activePets = activePets
        self.activeHumans = activeHumans
        self.activePlants = activePlants
        self.ordinaryActivePlans = ordinaryActivePlans
    }

    func limit(for resource: PersonalLimitedResource) -> Int {
        switch resource {
        case .activePet:
            activePets
        case .activeHuman:
            activeHumans
        case .activePlant:
            activePlants
        case .ordinaryActivePlan:
            ordinaryActivePlans
        }
    }
}

/// Sendable usage value assembled by a bounded read model before asking the
/// policy for a decision. Negative inputs normalize to zero at this boundary.
nonisolated struct PersonalUsageSnapshot: Equatable, Sendable {
    /// Count `Pet` rows where `hasPassedAway == false`.
    let activePetCount: Int
    /// Count `Human` rows where `hasPassedAway == false`.
    let activeHumanCount: Int
    /// Count `Plant` rows where `isArchived == false`.
    let activePlantCount: Int
    /// Count logical ordinary plans once. Do not count an `Event` and each of
    /// its derived `Reminder` rows as separate quota items.
    let ordinaryActivePlanCount: Int
    /// Active medication and other safety-critical plans are tracked for
    /// presentation only and never participate in a Free denial.
    let healthCriticalActivePlanCount: Int

    init(
        activePetCount: Int = 0,
        activeHumanCount: Int = 0,
        activePlantCount: Int = 0,
        ordinaryActivePlanCount: Int = 0,
        healthCriticalActivePlanCount: Int = 0
    ) {
        self.activePetCount = max(0, activePetCount)
        self.activeHumanCount = max(0, activeHumanCount)
        self.activePlantCount = max(0, activePlantCount)
        self.ordinaryActivePlanCount = max(0, ordinaryActivePlanCount)
        self.healthCriticalActivePlanCount = max(0, healthCriticalActivePlanCount)
    }

    func count(for resource: PersonalLimitedResource) -> Int {
        switch resource {
        case .activePet:
            activePetCount
        case .activeHuman:
            activeHumanCount
        case .activePlant:
            activePlantCount
        case .ordinaryActivePlan:
            ordinaryActivePlanCount
        }
    }

    var totalActivePlanCount: Int {
        ordinaryActivePlanCount + healthCriticalActivePlanCount
    }

    func grandfatheredResources(
        limits: PersonalFreeLimits = .current
    ) -> Set<PersonalLimitedResource> {
        Set(PersonalLimitedResource.allCases.filter { count(for: $0) > limits.limit(for: $0) })
    }
}

nonisolated enum PersonalExistingDataOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case view
    /// Editing content is protected. A separate quota decision is still
    /// required if that edit activates a member, plant, or ordinary plan.
    case editWithoutIncreasingQuota
    case recordCareFact
    case export
    /// Restore and migration may recreate grandfathered data and must not turn
    /// a commercial limit into data loss.
    case restoreOrMigrate
}

nonisolated enum PersonalPlanQuotaClass: String, Codable, CaseIterable, Hashable, Sendable {
    case ordinary
    case healthCritical
}

/// A signed change makes the grandfather rule reusable for create, reactivate,
/// archive, complete, delete, and replacement flows.
nonisolated struct PersonalUsageChange: Equatable, Sendable {
    let resource: PersonalLimitedResource
    let countDelta: Int

    init(resource: PersonalLimitedResource, countDelta: Int) {
        self.resource = resource
        self.countDelta = countDelta
    }

    static func adding(
        _ resource: PersonalLimitedResource,
        count: Int = 1
    ) -> PersonalUsageChange {
        PersonalUsageChange(resource: resource, countDelta: max(0, count))
    }

    static func removing(
        _ resource: PersonalLimitedResource,
        count: Int = 1
    ) -> PersonalUsageChange {
        PersonalUsageChange(resource: resource, countDelta: -max(0, count))
    }
}

nonisolated enum PersonalAccessRequest: Equatable, Sendable {
    case useExistingData(PersonalExistingDataOperation)
    case changeLimitedUsage(PersonalUsageChange)
    case createPlan(PersonalPlanQuotaClass)

    static func addActivePet(count: Int = 1) -> PersonalAccessRequest {
        .changeLimitedUsage(.adding(.activePet, count: count))
    }

    static func addActiveHuman(count: Int = 1) -> PersonalAccessRequest {
        .changeLimitedUsage(.adding(.activeHuman, count: count))
    }

    static func addActivePlant(count: Int = 1) -> PersonalAccessRequest {
        .changeLimitedUsage(.adding(.activePlant, count: count))
    }
}

nonisolated enum PersonalAccessAllowance: Equatable, Sendable {
    case personalUnlimited
    case protectedExistingData(PersonalExistingDataOperation)
    case healthCriticalPlanExemption
    case withinFreeLimit(
        resource: PersonalLimitedResource,
        resultingCount: Int,
        limit: Int
    )
    case nonIncreasingFreeUsage(
        resource: PersonalLimitedResource,
        currentCount: Int,
        resultingCount: Int,
        limit: Int,
        preservesGrandfatheredData: Bool
    )
}

nonisolated struct PersonalFreeLimitDenial: Equatable, Sendable {
    let resource: PersonalLimitedResource
    let currentCount: Int
    let attemptedCount: Int
    let limit: Int

    /// True means the household was already over the new Free limit before the
    /// attempted addition. Existing data remains usable; only further growth is
    /// denied.
    let preservesGrandfatheredData: Bool
}

nonisolated enum PersonalAccessDenialReason: Equatable, Sendable {
    case wouldExceedFreeLimit(PersonalFreeLimitDenial)
}

/// Semantic destinations for UI or command adapters. The policy does not
/// present UI and never requires deletion as a condition of continued access.
nonisolated enum PersonalAccessNextAction: Equatable, Sendable {
    case offerPersonalUpgrade
    case reviewActiveItems(PersonalLimitedResource)
}

nonisolated struct PersonalAccessDenial: Equatable, Sendable {
    let reason: PersonalAccessDenialReason
    let primaryNextAction: PersonalAccessNextAction
    let secondaryNextAction: PersonalAccessNextAction
}

nonisolated enum PersonalAccessDisposition: Equatable, Sendable {
    case allow(PersonalAccessAllowance)
    case deny(PersonalAccessDenial)

    var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }

    var allowance: PersonalAccessAllowance? {
        if case let .allow(allowance) = self { return allowance }
        return nil
    }

    var denial: PersonalAccessDenial? {
        if case let .deny(denial) = self { return denial }
        return nil
    }
}

enum PersonalAccessPolicy {
    nonisolated static func disposition(
        level: PersonalAccessLevel,
        usage: PersonalUsageSnapshot,
        request: PersonalAccessRequest,
        limits: PersonalFreeLimits = .current
    ) -> PersonalAccessDisposition {
        if level == .personal {
            return .allow(.personalUnlimited)
        }

        switch request {
        case let .useExistingData(operation):
            return .allow(.protectedExistingData(operation))
        case .createPlan(.healthCritical):
            return .allow(.healthCriticalPlanExemption)
        case .createPlan(.ordinary):
            return dispositionForFreeUsageChange(
                .adding(.ordinaryActivePlan),
                usage: usage,
                limits: limits
            )
        case let .changeLimitedUsage(change):
            return dispositionForFreeUsageChange(change, usage: usage, limits: limits)
        }
    }

    private nonisolated static func dispositionForFreeUsageChange(
        _ change: PersonalUsageChange,
        usage: PersonalUsageSnapshot,
        limits: PersonalFreeLimits
    ) -> PersonalAccessDisposition {
        let resource = change.resource
        let currentCount = usage.count(for: resource)
        let resultingCount = max(0, currentCount + change.countDelta)
        let limit = limits.limit(for: resource)

        if change.countDelta <= 0 {
            return .allow(
                .nonIncreasingFreeUsage(
                    resource: resource,
                    currentCount: currentCount,
                    resultingCount: resultingCount,
                    limit: limit,
                    preservesGrandfatheredData: currentCount > limit
                )
            )
        }

        guard resultingCount > limit else {
            return .allow(
                .withinFreeLimit(
                    resource: resource,
                    resultingCount: resultingCount,
                    limit: limit
                )
            )
        }

        return .deny(
            PersonalAccessDenial(
                reason: .wouldExceedFreeLimit(
                    PersonalFreeLimitDenial(
                        resource: resource,
                        currentCount: currentCount,
                        attemptedCount: resultingCount,
                        limit: limit,
                        preservesGrandfatheredData: currentCount > limit
                    )
                ),
                primaryNextAction: .offerPersonalUpgrade,
                secondaryNextAction: .reviewActiveItems(resource)
            )
        )
    }
}
