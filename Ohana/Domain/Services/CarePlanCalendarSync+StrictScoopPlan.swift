//
//  CarePlanCalendarSync+StrictScoopPlan.swift
//  Ohana
//
//  Retry-aware scoop-plan persistence for deferred shared-care settlement.
//

import Foundation
import SwiftData

extension CarePlanCalendarSync {
    @discardableResult
    static func syncScoopPlan(
        pet: Pet,
        context: ModelContext,
        intervalDays: Int,
        enabled: Bool,
        anchor: Date,
        preferredEventID: UUID? = nil
    ) -> Event? {
        syncScoopPlanResult(
            pet: pet,
            context: context,
            intervalDays: intervalDays,
            enabled: enabled,
            anchor: anchor,
            preferredEventID: preferredEventID
        ).event
    }

    struct ScoopPlanSyncResult {
        let event: Event?
        let didPersist: Bool
    }

    /// Strict variant used by deferred shared-care settlement. Unlike the
    /// legacy optional return, it distinguishes an intentionally disabled plan
    /// from a failed save so the receipt can remain retryable.
    static func syncScoopPlanResult(
        pet: Pet,
        context: ModelContext,
        intervalDays: Int,
        enabled: Bool,
        anchor: Date,
        preferredEventID: UUID? = nil
    ) -> ScoopPlanSyncResult {
        let petKey = pet.id.uuidString
        guard MemberWritePolicy.disposition(
            pet: pet,
            intent: .activeOnly
        ).allowsDerivedEffects else {
            removeActiveCalendarPlans(for: pet, context: context)
            return ScoopPlanSyncResult(event: nil, didPersist: false)
        }
        if intervalDays > 0 {
            suppressDefaultPlan(kind: "litter", pet: pet, context: context)
        }
        guard enabled, intervalDays > 0 else {
            let didPersist = removeCalendarPlan(kind: "scoop", petKey: petKey, context: context)
            return ScoopPlanSyncResult(event: nil, didPersist: didPersist)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let anchorDay = calendar.startOfDay(for: anchor)
        let last = pet.careLogs.filter { $0.type == CareType.litter.rawValue }.map(\.date).max()
        var base = anchorDay
        if let last { base = max(base, calendar.startOfDay(for: last)) }
        var next = calendar.date(byAdding: .day, value: intervalDays, to: base) ?? base
        while next < today {
            next = calendar.date(byAdding: .day, value: intervalDays, to: next) ?? next
        }
        let event = persistScoopPlanEvent(
            pet: pet,
            context: context,
            intervalDays: intervalDays,
            startDate: next,
            preferredEventID: preferredEventID
        )
        return ScoopPlanSyncResult(event: event, didPersist: event != nil)
    }
}
