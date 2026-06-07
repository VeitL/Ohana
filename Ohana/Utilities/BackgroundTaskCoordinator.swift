//
//  BackgroundTaskCoordinator.swift
//  Ohana
//
//  Central background refresh registration and execution.
//

import BackgroundTasks
import Foundation
import SwiftData

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
        let request = BGAppRefreshTaskRequest(identifier: reminderRefillTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6)
        do {
            try BGTaskScheduler.shared.submit(request)
            Task { @MainActor in
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_scheduled",
                    valueMS: 0,
                    note: reminderRefillTaskID
                )
            }
        } catch {
            Task { @MainActor in
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_schedule_failed",
                    valueMS: 0,
                    note: error.localizedDescription
                )
            }
        }
    }

    private static func handleReminderRefill(task: BGAppRefreshTask) {
        scheduleReminderRefill()

        let work = Task { @MainActor in
            let startedAt = CFAbsoluteTimeGetCurrent()
            AppPerformanceMonitor.shared.record(
                "background_reminder_refill_started",
                valueMS: 0,
                note: reminderRefillTaskID
            )

            let modelContext = ModelContext(SharedModelContainer.make())
            let result = await ReminderMaintenanceService.runPendingReminderMaintenance(context: modelContext)
            guard !Task.isCancelled, result.completed else {
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_cancelled",
                    valueMS: 0,
                    note: "cancelled during maintenance"
                )
                task.setTaskCompleted(success: false)
                return
            }

            AppPerformanceMonitor.shared.record(
                "background_reminder_refill_completed",
                startedAt: startedAt,
                note: "\(result.pendingCount) pending reminders"
            )
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            Task { @MainActor in
                AppPerformanceMonitor.shared.record(
                    "background_reminder_refill_cancelled",
                    valueMS: 0,
                    note: "expired"
                )
                task.setTaskCompleted(success: false)
            }
        }
    }
}
