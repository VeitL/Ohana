//
//  ReminderNotificationScheduling.swift
//  Ohana
//
//  Injectable dependency seam for reminder notification scheduling.
//
//  Domain/model services (CareEventService, ReminderSchedulingService,
//  FamilyTaskService, FeedManagementSupport, etc.) schedule and cancel local
//  notifications as a side effect of writing business facts. Routing those
//  calls through this protocol (instead of NotificationManager.shared directly)
//  lets unit tests substitute an in-memory fake, so reminder/care write paths
//  become testable without touching the real UNUserNotificationCenter.
//
//  AppServices installs the production NotificationManager instance at startup;
//  tests can still override the scheduler directly.
//

import Foundation

/// The subset of notification operations that domain services depend on.
nonisolated protocol ReminderNotificationScheduling: Sendable {
    func schedule(reminder: Reminder)
    func schedule(
        reminder: Reminder,
        existingNotificationIds: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    )
    func schedule(
        reminder: Reminder,
        deliveryDate: Date?,
        existingNotificationIds: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    )
    func pendingNotificationIds() async -> Set<String>
    func scheduleRollingWindow(reminders: [Reminder])
    func refillWindowIfNeeded(allReminders: [Reminder])
    func cancel(notificationId: String)
    func cancelAll(for petId: String, reminders: [Reminder])
    func compensate(reminders: [Reminder])
}

extension NotificationManager: ReminderNotificationScheduling {}

/// Injectable accessor for the notification scheduler. Defaults to a live
/// instance until AppServices installs the app-owned scheduler; tests can
/// override `current` with a fake and restore it via `useLive()`.
enum OhanaNotifications {
    nonisolated(unsafe) static var current: ReminderNotificationScheduling = makeLiveScheduler()

    /// Restores the live notification scheduler. Call in test teardown.
    static func useLive() {
        current = makeLiveScheduler()
    }

    private static func makeLiveScheduler() -> ReminderNotificationScheduling {
        NotificationManager(routeCenter: OhanaNotificationRouteCenter())
    }
}
