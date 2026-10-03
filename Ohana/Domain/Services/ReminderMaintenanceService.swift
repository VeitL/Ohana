//
//  ReminderMaintenanceService.swift
//  Ohana
//
//  Shared pending-only reminder maintenance for startup and background refresh.
//

import Foundation
import SwiftData

struct ReminderMaintenanceRunResult: Equatable {
    let pendingCount: Int
    let completed: Bool
    let hasMoreWork: Bool
}

/// Stable continuation position for future reminders. `scheduledAt` alone is
/// not sufficient because several reminders may legitimately share the same
/// delivery time.
nonisolated struct ReminderMaintenanceFutureCursor: Equatable, Sendable {
    var scheduledAt: Date
    var reminderID: UUID
}

/// The next lane matters only for single-item constrained budgets. Larger
/// budgets reserve capacity for both lanes, while a one-item batch alternates
/// so stale overdue rows cannot starve future notification refills.
nonisolated enum ReminderMaintenanceLane: String, Equatable, Sendable {
    case overdue
    case future
}

/// Durable, Sendable continuation state. It contains identifiers and values
/// only; no live SwiftData model crosses the planning actor boundary.
nonisolated struct ReminderMaintenanceCursor: Equatable, Sendable {
    var future: ReminderMaintenanceFutureCursor?
    var preferredLane: ReminderMaintenanceLane

    static var initial: ReminderMaintenanceCursor {
        ReminderMaintenanceCursor(
            future: nil,
            preferredLane: .overdue
        )
    }
}

/// Sendable bounded work returned by a dedicated SwiftData actor. The main
/// actor only rehydrates the small batch needed to talk to UserNotifications.
nonisolated struct ReminderMaintenancePlan: Equatable, Sendable {
    let reminderModelIDs: [PersistentIdentifier]
    let hasMoreWork: Bool
    let nextCursor: ReminderMaintenanceCursor
}

@ModelActor
actor ReminderMaintenancePlanActor {
    func makePlan(
        maximumItemCount: Int,
        cursor: ReminderMaintenanceCursor,
        now: Date = Date()
    ) throws -> ReminderMaintenancePlan {
        try Task.checkCancellation()
        let pendingStatus = ReminderStatus.pending.rawValue
        let batchLimit = max(1, maximumItemCount)
        if batchLimit == 1 {
            return try makeSingleItemPlan(
                pendingStatus: pendingStatus,
                cursor: cursor,
                now: now
            )
        }

        // Reserve future capacity whenever a future scan remains. This bounds
        // overdue work without allowing stale/unauthorizable overdue rows to
        // keep future notification registration from ever advancing.
        let overdueLimit = min(16, max(1, batchLimit / 2))
        let overdue = try fetchOverdue(
            pendingStatus: pendingStatus,
            now: now,
            limit: overdueLimit + 1
        )
        let selectedOverdue = Array(overdue.prefix(overdueLimit))
        let hasMoreOverdue = overdue.count > selectedOverdue.count

        var nextCursor = cursor
        var selectedFuture: [Reminder] = []
        var hasMoreFuture = false
        let futureLimit = max(1, batchLimit - selectedOverdue.count)
        let future = try fetchFuture(
            pendingStatus: pendingStatus,
            after: cursor.future,
            now: now,
            limit: futureLimit + 1
        )
        selectedFuture = Array(future.prefix(futureLimit))
        hasMoreFuture = future.count > selectedFuture.count
        updateFutureCursor(&nextCursor, selectedFuture: selectedFuture)
        nextCursor.preferredLane = .overdue

        try Task.checkCancellation()
        return ReminderMaintenancePlan(
            reminderModelIDs: (selectedOverdue + selectedFuture).map(\.persistentModelID),
            hasMoreWork: hasMoreOverdue || hasMoreFuture,
            nextCursor: nextCursor
        )
    }

    private func makeSingleItemPlan(
        pendingStatus: String,
        cursor: ReminderMaintenanceCursor,
        now: Date
    ) throws -> ReminderMaintenancePlan {
        let overdue = try fetchOverdue(
            pendingStatus: pendingStatus,
            now: now,
            limit: 2
        )
        let future = try fetchFuture(
            pendingStatus: pendingStatus,
            after: cursor.future,
            now: now,
            limit: 2
        )

        let choosesFuture: Bool = switch cursor.preferredLane {
        case .overdue:
            overdue.isEmpty && !future.isEmpty
        case .future:
            !future.isEmpty || overdue.isEmpty
        }

        let selectedOverdue = choosesFuture ? [] : Array(overdue.prefix(1))
        let selectedFuture = choosesFuture ? Array(future.prefix(1)) : []
        let hasMoreOverdue = overdue.count > selectedOverdue.count
        let hasMoreFuture = future.count > selectedFuture.count
        var nextCursor = cursor
        updateFutureCursor(&nextCursor, selectedFuture: selectedFuture)
        nextCursor.preferredLane = choosesFuture ? .overdue : .future

        try Task.checkCancellation()
        return ReminderMaintenancePlan(
            reminderModelIDs: (selectedOverdue + selectedFuture).map(\.persistentModelID),
            hasMoreWork: hasMoreOverdue || hasMoreFuture,
            nextCursor: nextCursor
        )
    }

    private func fetchOverdue(
        pendingStatus: String,
        now: Date,
        limit: Int
    ) throws -> [Reminder] {
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus && reminder.scheduledAt <= now
            },
            sortBy: [
                SortDescriptor(\Reminder.scheduledAt, order: .forward),
                SortDescriptor(\Reminder.id, order: .forward)
            ]
        )
        // `scheduledAt` is the notification time. V89 reminders can notify
        // before their task occurrence, so fetch a bounded superset and only
        // compensate rows whose actual occurrence is overdue.
        descriptor.fetchLimit = min(512, max(32, limit * 16))
        return Array(
            try modelContext.fetch(descriptor)
                .filter { $0.resolvedOccurrenceAt <= now }
                .prefix(max(1, limit))
        )
    }

    private func fetchFuture(
        pendingStatus: String,
        after cursor: ReminderMaintenanceFutureCursor?,
        now: Date,
        limit: Int
    ) throws -> [Reminder] {
        let descriptor: FetchDescriptor<Reminder>
        if let cursor {
            let cursorDate = cursor.scheduledAt
            let cursorID = cursor.reminderID
            descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.status == pendingStatus &&
                        (reminder.scheduledAt > cursorDate ||
                            (reminder.scheduledAt == cursorDate && reminder.id > cursorID))
                },
                sortBy: [
                    SortDescriptor(\Reminder.scheduledAt, order: .forward),
                    SortDescriptor(\Reminder.id, order: .forward)
                ]
            )
        } else {
            descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.status == pendingStatus && reminder.scheduledAt > now
                },
                sortBy: [
                    SortDescriptor(\Reminder.scheduledAt, order: .forward),
                    SortDescriptor(\Reminder.id, order: .forward)
                ]
            )
        }
        var boundedDescriptor = descriptor
        boundedDescriptor.fetchLimit = max(1, limit)
        return try modelContext.fetch(boundedDescriptor)
    }

    private func updateFutureCursor(
        _ cursor: inout ReminderMaintenanceCursor,
        selectedFuture: [Reminder]
    ) {
        if let lastFuture = selectedFuture.last {
            cursor.future = ReminderMaintenanceFutureCursor(
                scheduledAt: lastFuture.scheduledAt,
                reminderID: lastFuture.id
            )
        }
    }
}

/// Persists only continuation state, never reminder content. A follow-up BG
/// refresh consumes the next bounded batch rather than doing an unbounded scan.
enum ReminderMaintenanceCursorStore {
    private static let hasContinuationKey = "ohana_reminder_maintenance_has_continuation"
    private static let lastBatchCountKey = "ohana_reminder_maintenance_last_batch_count"
    private static let futureCursorDateKey = "ohana_reminder_maintenance_future_cursor_date"
    private static let futureCursorReferenceDateBitsKey = "ohana_reminder_maintenance_future_cursor_reference_date_bits"
    private static let futureCursorReminderIDKey = "ohana_reminder_maintenance_future_cursor_reminder_id"
    private static let preferredLaneKey = "ohana_reminder_maintenance_preferred_lane"

    static func hasContinuation(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: hasContinuationKey)
    }

    static func cursor(defaults: UserDefaults = .standard) -> ReminderMaintenanceCursor {
        let futureDate: Date? = if let rawBits = defaults.string(forKey: futureCursorReferenceDateBitsKey),
                                          let bits = UInt64(rawBits, radix: 16) {
            // Date keeps its native value relative to the reference date. Persisting
            // that exact bit pattern avoids an epoch conversion rounding the
            // keyset boundary backward and replaying a just-finished reminder.
            Date(timeIntervalSinceReferenceDate: Double(bitPattern: bits))
        } else if let timestamp = defaults.object(forKey: futureCursorDateKey) as? Double {
            // Read cursors written before the lossless representation landed.
            Date(timeIntervalSince1970: timestamp)
        } else {
            nil
        }
        let future: ReminderMaintenanceFutureCursor? = if let futureDate,
                                                          let rawID = defaults.string(forKey: futureCursorReminderIDKey),
                                                          let reminderID = UUID(uuidString: rawID) {
            ReminderMaintenanceFutureCursor(
                scheduledAt: futureDate,
                reminderID: reminderID
            )
        } else {
            nil
        }
        let preferredLane = ReminderMaintenanceLane(
            rawValue: defaults.string(forKey: preferredLaneKey) ?? ""
        ) ?? .overdue
        return ReminderMaintenanceCursor(
            future: future,
            preferredLane: preferredLane
        )
    }

    /// Compatibility for the startup coordinator while it still supplies the
    /// old argument label. The value is deliberately ignored by the planner;
    /// durable keyset state now lives in `cursor(defaults:)`.
    static func futureOffset(defaults _: UserDefaults = .standard) -> Int {
        0
    }

    static func record(
        _ result: ReminderMaintenanceRunResult,
        plan: ReminderMaintenancePlan? = nil,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(result.pendingCount, forKey: lastBatchCountKey)
        guard result.completed else {
            // Never advance the keyset after a cancelled/failed run. A plan
            // means that even a terminal slice may still need retrying.
            let shouldRetry = plan != nil || result.hasMoreWork || hasContinuation(defaults: defaults)
            defaults.set(shouldRetry, forKey: hasContinuationKey)
            return
        }

        guard result.hasMoreWork else {
            defaults.set(false, forKey: hasContinuationKey)
            clearCursor(defaults: defaults)
            return
        }

        defaults.set(true, forKey: hasContinuationKey)
        persist(plan?.nextCursor ?? cursor(defaults: defaults), defaults: defaults)
    }

    static func markRetry(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: hasContinuationKey)
    }

    private static func persist(
        _ cursor: ReminderMaintenanceCursor,
        defaults: UserDefaults
    ) {
        if let future = cursor.future {
            let referenceDateBits = future.scheduledAt
                .timeIntervalSinceReferenceDate
                .bitPattern
            defaults.set(String(referenceDateBits, radix: 16), forKey: futureCursorReferenceDateBitsKey)
            // Keep the old numeric representation during the rollout so a
            // prior build can safely resume instead of treating work as lost.
            defaults.set(future.scheduledAt.timeIntervalSince1970, forKey: futureCursorDateKey)
            defaults.set(future.reminderID.uuidString, forKey: futureCursorReminderIDKey)
        } else {
            defaults.removeObject(forKey: futureCursorReferenceDateBitsKey)
            defaults.removeObject(forKey: futureCursorDateKey)
            defaults.removeObject(forKey: futureCursorReminderIDKey)
        }
        defaults.set(cursor.preferredLane.rawValue, forKey: preferredLaneKey)
    }

    private static func clearCursor(defaults: UserDefaults) {
        defaults.removeObject(forKey: futureCursorReferenceDateBitsKey)
        defaults.removeObject(forKey: futureCursorDateKey)
        defaults.removeObject(forKey: futureCursorReminderIDKey)
        defaults.removeObject(forKey: preferredLaneKey)
    }
}

enum ReminderMaintenanceService {
    @MainActor
    static func pendingReminders(context: ModelContext) -> [Reminder] {
        let pendingStatus = ReminderStatus.pending.rawValue
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus
            },
            sortBy: [SortDescriptor(\Reminder.scheduledAt, order: .forward)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "ReminderMaintenanceService failed to fetch pending reminders: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    static func runPendingReminderMaintenance(
        context: ModelContext,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) async -> ReminderMaintenanceRunResult {
        let reminders = pendingReminders(context: context)
        return await run(
            reminders: reminders,
            hasMoreWork: false,
            context: context,
            reminderScheduling: providedReminderScheduling
        )
    }

    /// Builds a bounded plan off-main. The caller owns the continuation cursor
    /// and should request another BG run when `hasMoreWork` is true.
    @MainActor
    static func makeBackgroundPlan(
        context: ModelContext,
        budget: OhanaBackgroundWorkBudget
    ) async throws -> ReminderMaintenancePlan {
        try await makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: ReminderMaintenanceCursorStore.cursor()
        )
    }

    /// Compatibility bridge for the startup coordinator's old call shape. The
    /// durable cursor is no longer an offset, so the integer is intentionally
    /// ignored rather than reintroducing offset pagination.
    @MainActor
    static func makeBackgroundPlan(
        context: ModelContext,
        budget: OhanaBackgroundWorkBudget,
        futureOffset _: Int
    ) async throws -> ReminderMaintenancePlan {
        try await makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: ReminderMaintenanceCursorStore.cursor()
        )
    }

    @MainActor
    static func makeBackgroundPlan(
        context: ModelContext,
        budget: OhanaBackgroundWorkBudget,
        cursor: ReminderMaintenanceCursor
    ) async throws -> ReminderMaintenancePlan {
        guard budget.hasWorkCapacity else {
            return ReminderMaintenancePlan(
                reminderModelIDs: [],
                hasMoreWork: true,
                nextCursor: cursor
            )
        }
        let actor = ReminderMaintenancePlanActor(modelContainer: context.container)
        return try await actor.makePlan(
            maximumItemCount: budget.maximumItemCount,
            cursor: cursor
        )
    }

    @MainActor
    static func run(
        plan: ReminderMaintenancePlan,
        context: ModelContext,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) async -> ReminderMaintenanceRunResult {
        let reminders = plan.reminderModelIDs.compactMap { modelID in
            context.model(for: modelID) as? Reminder
        }
        return await run(
            reminders: reminders,
            hasMoreWork: plan.hasMoreWork,
            context: context,
            reminderScheduling: providedReminderScheduling
        )
    }

    @MainActor
    private static func run(
        reminders: [Reminder],
        hasMoreWork: Bool,
        context: ModelContext,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging?
    ) async -> ReminderMaintenanceRunResult {
        let reminderScheduling = providedReminderScheduling ?? DomainServiceDependencyRegistry.reminderScheduling(careLedger: CareLedgerService())
        let lifecycleSnapshot = MemberLifecycleActiveScheduleSnapshot(context: context)
        let activeReminders = reminders.filter { reminder in
            guard lifecycleSnapshot.includes(reminder) else {
                let notificationID = reminder.notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notificationID.isEmpty {
                    OhanaNotifications.current.cancel(notificationId: notificationID)
                }
                return false
            }
            return true
        }
        guard !Task.isCancelled else {
            return ReminderMaintenanceRunResult(pendingCount: activeReminders.count, completed: false, hasMoreWork: hasMoreWork)
        }

        await reminderScheduling.refillMissingPendingNotifications(
            reminders: activeReminders,
            context: context
        )
        guard !Task.isCancelled else {
            return ReminderMaintenanceRunResult(pendingCount: activeReminders.count, completed: false, hasMoreWork: hasMoreWork)
        }

        reminderScheduling.compensate(reminders: activeReminders, context: context)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return ReminderMaintenanceRunResult(pendingCount: reminders.count, completed: false, hasMoreWork: hasMoreWork)
        }
        return ReminderMaintenanceRunResult(pendingCount: activeReminders.count, completed: true, hasMoreWork: hasMoreWork)
    }
}
