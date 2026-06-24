//
//  ReminderNotificationScheduling.swift
//  Ohana
//
//  Injectable dependency boundary for reminder notification scheduling.
//
//  Domain/model services schedule and cancel local notifications as a side
//  effect of writing business facts. Routing those calls through this protocol
//  lets unit tests substitute an in-memory fake, so reminder/care write paths
//  become testable without touching the real UNUserNotificationCenter.
//
//  AppServices installs the production scheduler at startup; tests can still
//  override the scheduler directly.
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
    func cancelAll(for pet: Pet, reminders: [Reminder])
    func compensate(reminders: [Reminder])
}

/// Injectable accessor for the notification scheduler. Defaults to a no-op until
/// AppServices installs the app-owned scheduler; tests can override
/// `current` with a fake and restore it via `useLive()`.
enum ReminderNotificationSchedulerRegistry {
    private nonisolated(unsafe) static var makeLiveScheduler: (() -> ReminderNotificationScheduling)?
    nonisolated(unsafe) static var current: ReminderNotificationScheduling = DomainNoOpReminderNotificationScheduler()

    static func registerLiveSchedulerFactory(_ factory: @escaping () -> ReminderNotificationScheduling) {
        makeLiveScheduler = factory
    }

    /// Restores the app-registered notification scheduler. Call in test teardown.
    static func useLive() {
        current = makeLiveScheduler?() ?? DomainNoOpReminderNotificationScheduler()
    }
}

enum OhanaNotifications {
    static var current: ReminderNotificationScheduling {
        get { ReminderNotificationSchedulerRegistry.current }
        set { ReminderNotificationSchedulerRegistry.current = newValue }
    }

    static func registerLiveSchedulerFactory(_ factory: @escaping () -> ReminderNotificationScheduling) {
        ReminderNotificationSchedulerRegistry.registerLiveSchedulerFactory(factory)
    }

    static func useLive() {
        ReminderNotificationSchedulerRegistry.useLive()
    }
}

private final class DomainNoOpReminderNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
    func schedule(reminder _: Reminder) {}

    func schedule(
        reminder _: Reminder,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.skippedUserDisabled(""))
    }

    func schedule(
        reminder _: Reminder,
        deliveryDate _: Date?,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.skippedUserDisabled(""))
    }

    func pendingNotificationIds() async -> Set<String> { [] }
    func scheduleRollingWindow(reminders _: [Reminder]) {}
    func refillWindowIfNeeded(allReminders _: [Reminder]) {}
    func cancel(notificationId _: String) {}
    func cancelAll(for _: Pet, reminders _: [Reminder]) {}
    func compensate(reminders _: [Reminder]) {}
}
