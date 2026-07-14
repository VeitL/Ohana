import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct ReminderMaintenanceServiceTests {
    @Test func pendingReminderQueryExcludesNonPendingAndSortsBySchedule() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let later = Reminder(scheduledAt: Date(timeIntervalSince1970: 300))
        let completed = Reminder(scheduledAt: Date(timeIntervalSince1970: 100))
        completed.statusEnum = .completed
        let earlier = Reminder(scheduledAt: Date(timeIntervalSince1970: 200))
        let skipped = Reminder(scheduledAt: Date(timeIntervalSince1970: 50))
        skipped.statusEnum = .skipped

        context.insert(later)
        context.insert(completed)
        context.insert(earlier)
        context.insert(skipped)
        try context.save()

        let reminders = ReminderMaintenanceService.pendingReminders(context: context)

        #expect(reminders.map(\.id) == [earlier.id, later.id])
    }

    @Test func runCompensatesOnlyPendingExpiredReminders() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let expiredPending = Reminder(scheduledAt: Date(timeIntervalSince1970: 1))
        let expiredCompleted = Reminder(scheduledAt: Date(timeIntervalSince1970: 1))
        expiredCompleted.statusEnum = .completed
        let futurePending = Reminder(scheduledAt: Date().addingTimeInterval(86400))

        context.insert(expiredPending)
        context.insert(expiredCompleted)
        context.insert(futurePending)
        try context.save()

        let result = await ReminderMaintenanceService.runPendingReminderMaintenance(context: context)

        #expect(result.completed)
        #expect(result.pendingCount == 2)
        #expect(expiredPending.statusEnum == .skipped)
        #expect(expiredCompleted.statusEnum == .completed)
        #expect(futurePending.statusEnum == .pending)
    }

    @Test func earlyNotificationDoesNotExpireBeforeItsTaskOccurrence() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let reminder = Reminder(
            scheduledAt: now.addingTimeInterval(-3600),
            occurrenceAt: now.addingTimeInterval(3600)
        )
        context.insert(reminder)
        try context.save()

        _ = await ReminderMaintenanceService.runPendingReminderMaintenance(context: context)
        #expect(reminder.statusEnum == .pending)

        let budget = OhanaBackgroundWorkBudget(
            operation: "test_reminder_occurrence",
            maximumItemCount: 1,
            maximumWallClockSeconds: 5,
            allowsExpensiveWork: false,
            isDeferred: false
        )
        let plan = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: .initial
        )
        #expect(!plan.reminderModelIDs.contains(reminder.persistentModelID))
    }

    @Test func backgroundPlanCapsWorkAndRecordsContinuationCursor() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        for offset in 0 ..< 3 {
            context.insert(Reminder(scheduledAt: Date().addingTimeInterval(3600 + TimeInterval(offset))))
        }
        try context.save()

        let budget = OhanaBackgroundWorkBudget(
            operation: "test_reminder_plan",
            maximumItemCount: 2,
            maximumWallClockSeconds: 5,
            allowsExpensiveWork: false,
            isDeferred: false
        )
        let plan = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: .initial
        )

        #expect(plan.reminderModelIDs.count == 2)
        #expect(plan.hasMoreWork)

        let suiteName = "ReminderMaintenanceCursorStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        ReminderMaintenanceCursorStore.record(
            ReminderMaintenanceRunResult(pendingCount: 2, completed: true, hasMoreWork: true),
            plan: plan,
            defaults: defaults
        )
        #expect(ReminderMaintenanceCursorStore.hasContinuation(defaults: defaults))
        #expect(ReminderMaintenanceCursorStore.cursor(defaults: defaults) == plan.nextCursor)

        let nextPlan = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: ReminderMaintenanceCursorStore.cursor(defaults: defaults)
        )
        #expect(nextPlan.reminderModelIDs.count == 1)
        #expect(!nextPlan.hasMoreWork)
    }

    @Test func backgroundPlanUsesDateAndIDKeysetForSameScheduledTime() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let scheduledAt = Date().addingTimeInterval(3600)
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        ]
        let reminders = ids.map { id -> Reminder in
            let reminder = Reminder(scheduledAt: scheduledAt)
            reminder.id = id
            context.insert(reminder)
            return reminder
        }
        try context.save()

        let budget = OhanaBackgroundWorkBudget(
            operation: "test_reminder_keyset",
            maximumItemCount: 1,
            maximumWallClockSeconds: 5,
            allowsExpensiveWork: false,
            isDeferred: false
        )
        let first = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: .initial
        )
        let second = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: first.nextCursor
        )

        #expect(first.reminderModelIDs == [reminders[0].persistentModelID])
        #expect(second.reminderModelIDs == [reminders[1].persistentModelID])
        #expect(first.nextCursor.future?.reminderID == reminders[0].id)
        #expect(second.nextCursor.future?.reminderID == reminders[1].id)
    }

    @Test func backgroundPlanReservesFutureCapacityWhenOverdueRowsRemainPending() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let overdueAt = Date().addingTimeInterval(-3600)
        let futureAt = Date().addingTimeInterval(3600)
        let overdue = (0 ..< 4).map { _ -> Reminder in
            let reminder = Reminder(scheduledAt: overdueAt)
            context.insert(reminder)
            return reminder
        }
        let future = (0 ..< 2).map { _ -> Reminder in
            let reminder = Reminder(scheduledAt: futureAt)
            context.insert(reminder)
            return reminder
        }
        try context.save()

        let budget = OhanaBackgroundWorkBudget(
            operation: "test_reminder_fairness",
            maximumItemCount: 2,
            maximumWallClockSeconds: 5,
            allowsExpensiveWork: false,
            isDeferred: false
        )
        let first = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: .initial
        )
        // Leave every overdue reminder pending, as happens when compensation is
        // deliberately rejected by a domain policy. Future work must advance.
        let second = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: first.nextCursor
        )

        #expect(first.reminderModelIDs.count == 2)
        #expect(second.reminderModelIDs.count == 2)
        let futureModelIDs = Set(future.map(\.persistentModelID))
        let firstFutureModelIDs = Set(first.reminderModelIDs).intersection(futureModelIDs)
        let secondFutureModelIDs = Set(second.reminderModelIDs).intersection(futureModelIDs)
        #expect(firstFutureModelIDs.count == 1)
        #expect(secondFutureModelIDs.count == 1)
        #expect(firstFutureModelIDs != secondFutureModelIDs)
        #expect(first.reminderModelIDs.contains(where: { overdue.map(\.persistentModelID).contains($0) }))
        #expect(second.reminderModelIDs.contains(where: { overdue.map(\.persistentModelID).contains($0) }))
    }

    @Test func futureAddedAfterCurrentKeysetEndIsPickedDuringOverdueContinuation() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let overdueAt = Date().addingTimeInterval(-3600)
        let firstFutureAt = Date().addingTimeInterval(3600)
        let laterFutureAt = Date().addingTimeInterval(7200)
        for _ in 0 ..< 2 {
            context.insert(Reminder(scheduledAt: overdueAt))
        }
        let firstFuture = Reminder(scheduledAt: firstFutureAt)
        context.insert(firstFuture)
        try context.save()

        let budget = OhanaBackgroundWorkBudget(
            operation: "test_reminder_new_future",
            maximumItemCount: 2,
            maximumWallClockSeconds: 5,
            allowsExpensiveWork: false,
            isDeferred: false
        )
        let first = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: .initial
        )
        #expect(first.reminderModelIDs.contains(firstFuture.persistentModelID))
        #expect(first.hasMoreWork)

        let laterFuture = Reminder(scheduledAt: laterFutureAt)
        context.insert(laterFuture)
        try context.save()
        let second = try await ReminderMaintenanceService.makeBackgroundPlan(
            context: context,
            budget: budget,
            cursor: first.nextCursor
        )

        #expect(second.reminderModelIDs.contains(laterFuture.persistentModelID))
    }

    @Test func failedPlanKeepsDurableCursorAndRequestsContinuation() {
        let suiteName = "ReminderMaintenanceCursorRetryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initialCursor = ReminderMaintenanceCursor(
            future: ReminderMaintenanceFutureCursor(
                scheduledAt: Date(timeIntervalSince1970: 3600),
                reminderID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
            ),
            preferredLane: .future
        )
        let successfulPlan = ReminderMaintenancePlan(
            reminderModelIDs: [],
            hasMoreWork: true,
            nextCursor: initialCursor
        )
        ReminderMaintenanceCursorStore.record(
            ReminderMaintenanceRunResult(pendingCount: 1, completed: true, hasMoreWork: true),
            plan: successfulPlan,
            defaults: defaults
        )

        let laterCursor = ReminderMaintenanceCursor(
            future: ReminderMaintenanceFutureCursor(
                scheduledAt: Date(timeIntervalSince1970: 7200),
                reminderID: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
            ),
            preferredLane: .overdue
        )
        ReminderMaintenanceCursorStore.record(
            ReminderMaintenanceRunResult(pendingCount: 1, completed: false, hasMoreWork: false),
            plan: ReminderMaintenancePlan(
                reminderModelIDs: [],
                hasMoreWork: false,
                nextCursor: laterCursor
            ),
            defaults: defaults
        )

        #expect(ReminderMaintenanceCursorStore.hasContinuation(defaults: defaults))
        #expect(ReminderMaintenanceCursorStore.cursor(defaults: defaults) == initialCursor)
    }

    @Test func durableCursorPreservesExactDateKeysetBoundary() {
        let suiteName = "ReminderMaintenanceCursorPrecisionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cursor = ReminderMaintenanceCursor(
            future: ReminderMaintenanceFutureCursor(
                scheduledAt: Date(timeIntervalSinceReferenceDate: 789_123_456.123_456_7),
                reminderID: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
            ),
            preferredLane: .future
        )
        ReminderMaintenanceCursorStore.record(
            ReminderMaintenanceRunResult(pendingCount: 1, completed: true, hasMoreWork: true),
            plan: ReminderMaintenancePlan(
                reminderModelIDs: [],
                hasMoreWork: true,
                nextCursor: cursor
            ),
            defaults: defaults
        )

        #expect(ReminderMaintenanceCursorStore.cursor(defaults: defaults) == cursor)
    }

    @Test func backgroundCompletionGateClaimsExactlyOnce() {
        let gate = ReminderBackgroundTaskCompletionGate()

        #expect(gate.claimCompletion())
        #expect(!gate.claimCompletion())
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
