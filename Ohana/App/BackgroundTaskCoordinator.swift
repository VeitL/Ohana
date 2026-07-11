//
//  BackgroundTaskCoordinator.swift
//  Ohana
//
//  Central background refresh registration and execution.
//

import BackgroundTasks
import Foundation
import SwiftData

/// `BGTask` must receive exactly one terminal completion signal. The task body
/// and expiration handler race by design, so they claim the signal through this
/// main-actor gate rather than independently calling `setTaskCompleted`.
@MainActor
final class ReminderBackgroundTaskCompletionGate {
    private var didComplete = false

    @discardableResult
    func claimCompletion() -> Bool {
        guard !didComplete else { return false }
        didComplete = true
        return true
    }

    func complete(_ task: BGTask, success: Bool) {
        guard claimCompletion() else { return }
        task.setTaskCompleted(success: success)
    }
}

enum BackgroundTaskCoordinator {
    static let reminderRefillTaskID = "com.guanchen.li.Ohana.reminderRefill"

    private static var didRegister = false

    static func registerTasks() {
        guard !didRegister else { return }
        didRegister = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: reminderRefillTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleReminderRefill(task: refreshTask)
        }
    }

    static func scheduleReminderRefill() {
        Task { @MainActor in
            let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
                operation: "background_reminder_refill",
                requestedItemCount: 64,
                allowWhileBackground: true
            )
            submitReminderRefill(
                continuation: ReminderMaintenanceCursorStore.hasContinuation(),
                budget: budget
            )
        }
    }

    @MainActor
    private static func submitReminderRefill(
        continuation: Bool,
        budget: OhanaBackgroundWorkBudget
    ) {
        let request = BGAppRefreshTaskRequest(identifier: reminderRefillTaskID)
        let delay: TimeInterval = if continuation {
            budget.allowsExpensiveWork ? 15 * 60 : 60 * 60
        } else {
            60 * 60 * 6
        }
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        do {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: reminderRefillTaskID)
            try BGTaskScheduler.shared.submit(request)
            AppPerformanceMonitor.shared.record(
                "background_reminder_refill_scheduled",
                valueMS: 0,
                note: "\(reminderRefillTaskID), continuation=\(continuation), batch=\(budget.maximumItemCount)"
            )
        } catch {
            AppPerformanceMonitor.shared.record(
                "background_reminder_refill_schedule_failed",
                valueMS: 0,
                note: error.localizedDescription
            )
        }
    }

    private static func handleReminderRefill(task: BGAppRefreshTask) {
        let completionGate = ReminderBackgroundTaskCompletionGate()
        let work = Task { @MainActor in
            @MainActor
            func complete(_ success: Bool) {
                completionGate.complete(task, success: success)
            }

            let startedAt = CFAbsoluteTimeGetCurrent()
            let budgetStartedAt = Date()
            let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
                operation: "background_reminder_refill",
                requestedItemCount: 64,
                allowWhileBackground: true
            )
            guard budget.hasWorkCapacity else {
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_deferred",
                    valueMS: 0,
                    note: "runtime budget deferred"
                )
                ReminderMaintenanceCursorStore.markRetry()
                scheduleReminderRefill()
                complete(true)
                return
            }
            AppPerformanceMonitor.shared.record(
                "background_reminder_refill_started",
                valueMS: 0,
                note: "\(reminderRefillTaskID), batch=\(budget.maximumItemCount)"
            )

            let modelContainer: ModelContainer
            do {
                modelContainer = try SharedModelContainer.make()
            } catch {
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_store_unavailable",
                    valueMS: 0,
                    note: "primary store unavailable"
                )
                ReminderMaintenanceCursorStore.markRetry()
                scheduleReminderRefill()
                complete(false)
                return
            }
            let modelContext = ModelContext(modelContainer)
            let plan: ReminderMaintenancePlan
            do {
                plan = try await ReminderMaintenanceService.makeBackgroundPlan(
                    context: modelContext,
                    budget: budget
                )
            } catch is CancellationError {
                ReminderMaintenanceCursorStore.markRetry()
                scheduleReminderRefill()
                complete(false)
                return
            } catch {
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_plan_failed",
                    valueMS: 0,
                    note: error.localizedDescription
                )
                ReminderMaintenanceCursorStore.markRetry()
                scheduleReminderRefill()
                complete(false)
                return
            }
            guard !Task.isCancelled, budget.hasTimeRemaining(since: budgetStartedAt) else {
                ReminderMaintenanceCursorStore.record(
                    ReminderMaintenanceRunResult(
                        pendingCount: plan.reminderModelIDs.count,
                        completed: false,
                        hasMoreWork: plan.hasMoreWork
                    ),
                    plan: plan
                )
                scheduleReminderRefill()
                complete(false)
                return
            }

            let result = await ReminderMaintenanceService.run(plan: plan, context: modelContext)
            ReminderMaintenanceCursorStore.record(result, plan: plan)
            scheduleReminderRefill()
            guard !Task.isCancelled, result.completed else {
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_cancelled",
                    valueMS: 0,
                    note: "cancelled during maintenance"
                )
                complete(false)
                return
            }

            AppPerformanceMonitor.shared.record(
                "background_reminder_refill_completed",
                startedAt: startedAt,
                note: "\(result.pendingCount) pending reminders, continuation=\(result.hasMoreWork)"
            )
            complete(true)
        }

        task.expirationHandler = {
            work.cancel()
            Task { @MainActor in
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_cancelled",
                    valueMS: 0,
                    note: "expired"
                )
                ReminderMaintenanceCursorStore.markRetry()
                scheduleReminderRefill()
                completionGate.complete(task, success: false)
            }
        }
    }
}
