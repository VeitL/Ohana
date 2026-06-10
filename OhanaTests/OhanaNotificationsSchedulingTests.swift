import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct OhanaNotificationsSchedulingTests {
    /// In-memory stand-in for the notification scheduler so reminder/care write
    /// paths can be tested without touching UNUserNotificationCenter.
    final class FakeScheduler: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledIds: [String] = []

        func schedule(reminder _: Reminder) {}
        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledIds.append(notificationId) }
        func cancelAll(for _: String, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    @Test func skipRoutesCancelThroughInjectedSeam() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let reminder = Reminder(scheduledAt: Date(timeIntervalSince1970: 100))
        reminder.notificationId = "notif-123"
        context.insert(reminder)
        try context.save()

        ReminderCompletionService.skip(reminder, by: nil, context: context)

        #expect(fake.cancelledIds == ["notif-123"])
        #expect(reminder.statusEnum == .skipped)
    }

    @Test func defaultSchedulerIsLiveNotificationManager() {
        OhanaNotifications.useLive()
        #expect(OhanaNotifications.current is NotificationManager)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV60.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
