import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Ohana

@MainActor
struct OhanaNotificationsSchedulingTests {
    /// In-memory stand-in for the notification scheduler so reminder/care write
    /// paths can be tested without touching UNUserNotificationCenter.
    final class FakeScheduler: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledIds: [String] = []
        private(set) var scheduledIds: [String] = []
        private(set) var scheduledDeliveryDates: [Date] = []

        func schedule(reminder: Reminder) {
            scheduledIds.append(reminder.notificationId)
            scheduledDeliveryDates.append(reminder.scheduledAt)
        }

        func schedule(
            reminder: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledIds.append(reminder.notificationId)
            scheduledDeliveryDates.append(reminder.scheduledAt)
            completion?(.scheduled)
        }

        func schedule(
            reminder: Reminder,
            deliveryDate: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledIds.append(reminder.notificationId)
            scheduledDeliveryDates.append(deliveryDate ?? reminder.scheduledAt)
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

    @Test func routineReminderSchedulingHonorsDailyBudget() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let calendar = Calendar(identifier: .gregorian)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let day = calendar.startOfDay(for: tomorrow)
        let base = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
        let reminders = (0 ..< 5).map { index in
            let event = Event(
                title: "日常照护 \(index)",
                startDate: base,
                eventType: EventType.grooming.rawValue,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: UUID().uuidString
            )
            context.insert(event)
            let reminder = Reminder(event: event, scheduledAt: base.addingTimeInterval(Double(index) * 3600))
            context.insert(reminder)
            return reminder
        }
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: context)

        #expect(fake.scheduledIds.count == 4)
        let ledgerActions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(ledgerActions.contains("scheduleSkippedBudget"))
    }

    @Test func nonCriticalReminderInQuietHoursIsDeferredButAppReminderStaysPending() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 23, minute: 15)
        let event = Event(
            title: "夜间护理",
            startDate: scheduledAt,
            eventType: EventType.grooming.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [reminder], context: context)

        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: scheduledAt)!
        let expectedDelivery = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: nextDay)!
        #expect(fake.scheduledDeliveryDates == [expectedDelivery])
        #expect(reminder.statusEnum == .pending)
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["scheduleDeferred"])
        #expect(ledgerEvents.first?.metadataJSON.contains("\"deferred\":true") == true)
    }

    @Test func healthCriticalRemindersBypassBudgetMergeAndQuietHours() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 23, minute: 45)
        let reminders = (0 ..< 7).map { index in
            let event = Event(
                title: "用药 \(index)",
                startDate: scheduledAt,
                eventType: EventType.medication.rawValue,
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: UUID().uuidString
            )
            let reminder = Reminder(event: event, scheduledAt: scheduledAt.addingTimeInterval(Double(index) * 60))
            context.insert(event)
            context.insert(reminder)
            return reminder
        }
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: context)

        #expect(fake.scheduledIds.count == 7)
        #expect(fake.scheduledDeliveryDates == reminders.map(\.scheduledAt))
        let ledgerActions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType)
        #expect(ledgerActions.allSatisfy { $0 == "scheduleSuccess" })
    }

    @Test func sameDaySameMemberSameCategoryNonMedicationRemindersAreMerged() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let petId = UUID().uuidString
        let firstTime = futureDate(dayOffset: 2, hour: 9, minute: 0)
        let secondTime = futureDate(dayOffset: 2, hour: 11, minute: 0)
        let first = makeReminder(
            title: "洗澡",
            eventType: .grooming,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petId,
            scheduledAt: firstTime,
            context: context
        )
        let second = makeReminder(
            title: "梳毛",
            eventType: .grooming,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petId,
            scheduledAt: secondTime,
            context: context
        )
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [second, first], context: context)

        #expect(fake.scheduledIds == [first.notificationId])
        #expect(first.statusEnum == .pending)
        #expect(second.statusEnum == .pending)
        let ledgerActions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType).sorted()
        #expect(ledgerActions == ["scheduleMerged", "scheduleSuccess"])
    }

    @Test func ambientRemindersAllowOnlyOnePerDeliveryDay() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let base = futureDate(dayOffset: 2, hour: 12, minute: 0)
        let reminders = (0 ..< 2).map { index in
            makeReminder(
                title: "纪念日 \(index)",
                eventType: .anniversary,
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: UUID().uuidString,
                scheduledAt: base.addingTimeInterval(Double(index) * 3600),
                context: context
            )
        }
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: context)

        #expect(fake.scheduledIds.count == 1)
        let ledgerActions = try context.fetch(FetchDescriptor<CareLedgerEvent>()).map(\.actionType).sorted()
        #expect(ledgerActions == ["scheduleSkippedBudget", "scheduleSuccess"])
    }

    @Test func weeklyReportNotificationIsAmbientCareCopy() {
        let content = FamilyWeeklyReportService.makeWeeklyReportContent(l: L10n("zh"))

        #expect(content.title.contains("照护周报"))
        #expect(content.body.contains("照护"))
        #expect(!content.title.contains("悬赏"))
        #expect(!content.body.contains("悬赏"))
        #expect(!content.body.contains("勤快"))
        #expect(content.userInfo["notificationTier"] as? String == NotificationDeliveryTier.ambient.rawValue)
        #expect(content.userInfo["notificationCategory"] as? String == NotificationDeliveryCategory.weeklyReport.rawValue)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func futureDate(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let future = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
        let day = calendar.startOfDay(for: future)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func makeReminder(
        title: String,
        eventType: EventType,
        relatedEntityType: String,
        relatedEntityId: String,
        scheduledAt: Date,
        context: ModelContext
    ) -> Reminder {
        let event = Event(
            title: title,
            startDate: scheduledAt,
            eventType: eventType.rawValue,
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityId
        )
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(event)
        context.insert(reminder)
        return reminder
    }
}
