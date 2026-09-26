//
//  PersonalPlanQuotaCommandGate.swift
//  Ohana
//
//  Shared write-boundary enforcement for feature-specific ordinary plans.
//

import Foundation
import SwiftData

nonisolated enum PersonalPlanQuotaCommandError: LocalizedError, Equatable, Sendable {
    case personalUpgradeRequired(PersonalFreeLimitDenial)
    case usageUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .personalUpgradeRequired(denial):
            "Ohana Free supports up to \(denial.limit) active ordinary plans. Ohana Personal removes this limit."
        case let .usageUnavailable(reason):
            "Could not verify the current Ohana Personal allowance: \(reason)"
        }
    }
}

/// Applies the Free plan allowance before a feature command mutates schedules.
///
/// Callers pass the number of logical plans the command will make active and
/// the specific active plans it replaces or deactivates. This keeps edits and
/// grandfathered non-increasing changes usable while still blocking growth.
enum PersonalPlanQuotaCommandGate {
    @MainActor
    static func requirePlanChange(
        context: ModelContext,
        personalAccessLevel: PersonalAccessLevel = .personal,
        quotaClass: PersonalPlanQuotaClass = .ordinary,
        addingActivePlanCount: Int,
        replacingPlans: [Event] = [],
        now: Date = Date()
    ) throws {
        guard personalAccessLevel == .free else { return }
        guard quotaClass == .ordinary else { return }

        let usage: PersonalUsageSnapshot
        do {
            usage = try PersonalUsageSnapshotReader.snapshot(context: context, now: now)
        } catch {
            throw PersonalPlanQuotaCommandError.usageUnavailable(error.localizedDescription)
        }

        let uniqueReplacementCount = Set(
            replacingPlans
                .filter { countsAsActiveOrdinaryPlan($0, now: now) }
                .map(PersonalUsageSnapshotReader.logicalPlanKey(for:))
        ).count
        let replacingCount = min(uniqueReplacementCount, usage.ordinaryActivePlanCount)
        let delta = max(0, addingActivePlanCount) - replacingCount
        let disposition = PersonalAccessPolicy.disposition(
            level: personalAccessLevel,
            usage: usage,
            request: .changeLimitedUsage(
                PersonalUsageChange(resource: .ordinaryActivePlan, countDelta: delta)
            )
        )
        guard case let .deny(denial) = disposition,
              case let .wouldExceedFreeLimit(limitDenial) = denial.reason
        else { return }
        throw PersonalPlanQuotaCommandError.personalUpgradeRequired(limitDenial)
    }

    nonisolated static func countsAsActiveOrdinaryPlan(
        _ event: Event,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !event.isCompleted,
              let eventType = event.eventTypeEnum,
              PersonalPlanQuotaClassifier.quotaClass(for: eventType) == .ordinary
        else { return false }

        if event.recurrenceDays > 0 {
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return recurrenceEndDate >= calendar.startOfDay(for: now)
        }
        if event.reminders.contains(where: \.isPending) {
            return true
        }
        return false
    }
}
