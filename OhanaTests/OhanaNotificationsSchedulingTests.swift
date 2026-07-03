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
            existingNotificationIds: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            guard existingNotificationIds?.contains(reminder.notificationId) != true else {
                completion?(.skippedDuplicate)
                return
            }
            scheduledIds.append(reminder.notificationId)
            scheduledDeliveryDates.append(reminder.scheduledAt)
            completion?(.scheduled)
        }

        func schedule(
            reminder: Reminder,
            deliveryDate: Date?,
            existingNotificationIds: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            guard existingNotificationIds?.contains(reminder.notificationId) != true else {
                completion?(.skippedDuplicate)
                return
            }
            scheduledIds.append(reminder.notificationId)
            scheduledDeliveryDates.append(deliveryDate ?? reminder.scheduledAt)
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledIds.append(notificationId) }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    @Test func skipRoutesCancelThroughInjectedScheduler() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()

        let reminder = Reminder(scheduledAt: Date(timeIntervalSince1970: 100))
        reminder.notificationId = "notif-123"
        context.insert(reminder)
        try context.save()

        ReminderCompletionService.skip(reminder, by: nil, context: context, notifications: fake)

        #expect(fake.cancelledIds == ["notif-123"])
        #expect(reminder.statusEnum == .skipped)
    }

    @Test func physicalDeletionCancelsThroughInjectedScheduler() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        let event = Event(title: "Bath", startDate: Date(timeIntervalSince1970: 200), eventType: EventType.grooming.rawValue)
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSince1970: 200))
        reminder.notificationId = "delete-event-notif"
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let deletedCount = PhysicalDeletionService.deleteEvent(event, context: context, notifications: fake)

        #expect(deletedCount == 1)
        #expect(fake.cancelledIds == ["delete-event-notif"])
    }

    @Test func scheduleDeleteDispatcherUsesInjectedScheduler() {
        let fake = FakeScheduler()
        let result = DomainScheduleDeleteResult(
            eventID: UUID(),
            reminderIDs: [],
            notificationIdsToCancel: [" cancel-me ", "cancel-me", "", "cancel-too"],
            didDelete: true
        )

        DomainScheduleEffectsDispatcher.dispatch(delete: result, notifications: fake)

        #expect(fake.cancelledIds == ["cancel-me", "cancel-too"])
    }

    @Test func defaultSchedulerIsLiveNotificationManager() {
        OhanaNotifications.registerLiveSchedulerFactory {
            NotificationManager(routeCenter: OhanaNotificationRouteCenter())
        }
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

    @Test func reminderObservabilityShowsChineseSchedulingLedgerActions() {
        #expect(ReminderObservabilityContentView.actionDisplayName("scheduleDeferred") == "夜间延后")
        #expect(ReminderObservabilityContentView.actionDisplayName("scheduleSkippedBudget") == "预算跳过")
        #expect(ReminderObservabilityContentView.actionDisplayName("scheduleMerged") == "同类合并")
    }

    @Test func notificationDelegateHandoffKeepsDefaultTapAndActionsSeparate() throws {
        let managerSource = try source("Ohana/Features/Notifications/NotificationManager.swift")

        #expect(managerSource.contains("identifier: \"COMPLETE\""))
        #expect(managerSource.contains("identifier: \"SKIP\""))
        #expect(managerSource.contains("identifier: \"SNOOZE\""))
        #expect(managerSource.contains("actions: [completeAction, skipAction, snoozeAction]"))
        #expect(managerSource.contains("case UNNotificationDefaultActionIdentifier:"))
        #expect(managerSource.contains("self.routeCenter.requestReminderRoute(payload)"))
        #expect(managerSource.contains("case \"COMPLETE\", \"SKIP\", \"SNOOZE\":"))
        #expect(managerSource.contains("self.routeCenter.publishReminderAction(payload)"))

        for key in [
            "reminderId",
            "notificationId",
            "eventId",
            "relatedEntityType",
            "relatedEntityId",
            "plantId",
            "petId",
            "humanId",
            "medicationId",
            "humanMedicationId",
            "scheduledAt"
        ] {
            #expect(managerSource.contains("payload[\"\(key)\"]"))
        }
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

    @Test func disabledNotificationPreferenceSkipsMatchingReminder() async throws {
        let defaults = UserDefaults.standard
        let preferenceKey = NotificationPreferenceGroup.hygiene.storageKey
        let previousPreference = defaults.object(forKey: preferenceKey)
        NotificationPreferenceStore.set(false, for: .hygiene, defaults: defaults)
        defer {
            if let previousPreference {
                defaults.set(previousPreference, forKey: preferenceKey)
            } else {
                defaults.removeObject(forKey: preferenceKey)
            }
        }

        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 10, minute: 0)
        let reminder = makeReminder(
            title: "梳毛",
            eventType: .grooming,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString,
            scheduledAt: scheduledAt,
            context: context
        )
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [reminder], context: context)

        #expect(fake.scheduledIds.isEmpty)
        #expect(reminder.statusEnum == .pending)
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["scheduleUserDisabled"])
        #expect(ledgerEvents.first?.metadataJSON.contains("\"reason\":\"userDisabled\"") == true)
    }

    @Test func calendarReminderIgnoresDisabledCheckInPreference() async throws {
        let defaults = UserDefaults.standard
        let checkInPreferenceKey = NotificationPreferenceGroup.checkIn.storageKey
        let calendarPreferenceKey = NotificationPreferenceGroup.calendar.storageKey
        let previousCheckInPreference = defaults.object(forKey: checkInPreferenceKey)
        let previousCalendarPreference = defaults.object(forKey: calendarPreferenceKey)
        NotificationPreferenceStore.set(false, for: .checkIn, defaults: defaults)
        NotificationPreferenceStore.set(true, for: .calendar, defaults: defaults)
        defer {
            restorePreference(previousCheckInPreference, key: checkInPreferenceKey, defaults: defaults)
            restorePreference(previousCalendarPreference, key: calendarPreferenceKey, defaults: defaults)
        }

        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 10, minute: 0)
        let reminder = makeReminder(
            title: "Calendar task",
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            scheduledAt: scheduledAt,
            context: context
        )
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [reminder], context: context, source: .calendar)

        #expect(fake.scheduledIds == [reminder.notificationId])
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["scheduleSuccess"])
    }

    @Test func lateNightCalendarReminderKeepsUserSelectedTimeWhenSavedFromCalendar() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 23, minute: 30)
        let reminder = makeReminder(
            title: "Late calendar task",
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            scheduledAt: scheduledAt,
            context: context
        )
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [reminder], context: context, source: .calendar)

        #expect(fake.scheduledDeliveryDates == [scheduledAt])
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["scheduleSuccess"])
    }

    @Test func lateNightPlantLinkedCalendarReminderKeepsUserSelectedTime() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 23, minute: 30)
        let plant = Plant(name: "Calendar Fern")
        context.insert(plant)
        let reminder = makeReminder(
            title: "Move fern before guests arrive",
            eventType: .task,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString,
            scheduledAt: scheduledAt,
            context: context
        )
        try context.save()

        let decision = try #require(NotificationDeliveryPolicy.plan(reminders: [reminder])[reminder.id])
        guard case let .deliver(deliveryDate, classification, deferred) = decision else {
            Issue.record("Expected a plant-linked user calendar reminder to deliver normally")
            return
        }
        #expect(classification.category == .calendar)
        #expect(deliveryDate == scheduledAt)
        #expect(!deferred)

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [reminder], context: context, source: .calendar)

        #expect(fake.scheduledDeliveryDates == [scheduledAt])
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["scheduleSuccess"])
    }

    @Test func lateNightCalendarReminderKeepsUserSelectedTimeDuringRefill() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 23, minute: 30)
        let reminder = makeReminder(
            title: "Refill calendar task",
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            scheduledAt: scheduledAt,
            context: context
        )
        try context.save()

        await ReminderSchedulingService.refillMissingPendingNotifications(
            reminders: [reminder],
            context: context,
            careLedger: CareLedgerService()
        )

        #expect(fake.scheduledDeliveryDates == [scheduledAt])
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["refillSuccess"])
    }

    @Test func refillReplacesPreviouslyDeferredCalendarReminderRequest() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 23, minute: 30)
        let reminder = makeReminder(
            title: "Already deferred calendar task",
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            scheduledAt: scheduledAt,
            context: context
        )
        let deferredMetadata = "{\"tier\":\"routine\",\"category\":\"calendar\",\"deliveryAt\":\(scheduledAt.addingTimeInterval(9 * 3600).timeIntervalSince1970),\"deferred\":true}"
        context.insert(CareLedgerEvent(
            occurredAt: scheduledAt.addingTimeInterval(-120),
            eventKind: .reminder,
            actionType: "scheduleDeferred",
            sourceReminderId: reminder.id.uuidString,
            metadataJSON: deferredMetadata
        ))
        context.insert(CareLedgerEvent(
            occurredAt: scheduledAt.addingTimeInterval(-60),
            eventKind: .reminder,
            actionType: "refillSkippedExisting",
            sourceReminderId: reminder.id.uuidString
        ))
        try context.save()

        let result = await ReminderSchedulingService.scheduleIfNeeded(
            reminder: reminder,
            context: context,
            source: .service,
            existingNotificationIds: [reminder.notificationId],
            operation: "refill"
        )

        #expect(result == .scheduled)
        #expect(fake.cancelledIds == [reminder.notificationId])
        #expect(fake.scheduledDeliveryDates == [scheduledAt])
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType).contains("refillSuccess"))
    }

    @Test func disabledCalendarPreferenceSkipsCalendarReminder() async throws {
        let defaults = UserDefaults.standard
        let preferenceKey = NotificationPreferenceGroup.calendar.storageKey
        let previousPreference = defaults.object(forKey: preferenceKey)
        NotificationPreferenceStore.set(false, for: .calendar, defaults: defaults)
        defer {
            restorePreference(previousPreference, key: preferenceKey, defaults: defaults)
        }

        let container = try makeContainer()
        let context = container.mainContext
        let fake = FakeScheduler()
        OhanaNotifications.current = fake
        defer { OhanaNotifications.useLive() }

        let scheduledAt = futureDate(dayOffset: 2, hour: 10, minute: 0)
        let reminder = makeReminder(
            title: "Calendar task",
            eventType: .task,
            relatedEntityType: "",
            relatedEntityId: "",
            scheduledAt: scheduledAt,
            context: context
        )
        try context.save()

        await ReminderSchedulingService.scheduleManyIfNeeded(reminders: [reminder], context: context, source: .calendar)

        #expect(fake.scheduledIds.isEmpty)
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledgerEvents.map(\.actionType) == ["scheduleUserDisabled"])
    }

    @Test func calendarEventEditorRequestsNotificationPermissionBeforeSavingReminder() throws {
        let addEventSource = try source("Ohana/Features/Calendar/Views/AddEventView.swift")

        #expect(addEventSource.contains("guard input.reminderLeadMinutes == nil else"))
        #expect(addEventSource.contains("await appServices.userNotifications.requestPermission()"))
        #expect(addEventSource.contains("enqueueSaveEvent(input: input, command: command)"))
    }

    @Test func localNotificationTriggerPreservesSecondsForNearFutureCalendarReminders() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fireDate = calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: 1,
                hour: 12,
                minute: 34,
                second: 56
            )
        )!

        let components = NotificationManager.triggerDateComponents(for: fireDate, calendar: calendar)

        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 1)
        #expect(components.hour == 12)
        #expect(components.minute == 34)
        #expect(components.second == 56)
    }

    @Test func newCalendarEventDefaultStartDateLeavesTimeForPermissionPrompt() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: 1,
                hour: 12,
                minute: 34,
                second: 20
            )
        )!

        let defaultStartDate = AddEventContentView.defaultNewEventStartDate(now: now)

        #expect(defaultStartDate.timeIntervalSince(now) >= 5 * 60)
        #expect(calendar.component(.second, from: defaultStartDate) == 0)
        #expect(calendar.component(.minute, from: defaultStartDate).isMultiple(of: 5))
    }

    @Test func petNotificationCancellationUsesDomainSubjectResolution() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "cat")
        let medication = PetMedication(name: "Drops", pet: pet)
        let scheduledAt = futureDate(dayOffset: 2, hour: 13, minute: 0)

        let direct = makeReminder(
            title: "Groom",
            eventType: .grooming,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            scheduledAt: scheduledAt,
            context: context
        )
        direct.notificationId = "direct-pet"
        let indirectMedication = makeReminder(
            title: "Drops",
            eventType: .medication,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: medication.id.uuidString,
            scheduledAt: scheduledAt.addingTimeInterval(1800),
            context: context
        )
        indirectMedication.notificationId = "indirect-medication"
        let other = makeReminder(
            title: "Other",
            eventType: .grooming,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: otherPet.id.uuidString,
            scheduledAt: scheduledAt.addingTimeInterval(3600),
            context: context
        )
        other.notificationId = "other-pet"
        context.insert(pet)
        context.insert(otherPet)
        context.insert(medication)
        try context.save()

        let ids = NotificationManager.cancellableNotificationIds(
            for: pet,
            reminders: [direct, indirectMedication, other]
        )

        #expect(ids == ["direct-pet", "indirect-medication"])
    }

    @Test func weeklyReportNotificationIsAmbientCareCopy() {
        let localizedCases: [(language: String, careNeedle: String, blockedTerms: [String])] = [
            ("zh", "照护", ["悬赏", "悬赏榜", "指派", "竞争", "谁更勤快", "勤快"]),
            ("en", "care", ["bounty", "leaderboard", "assign", "competition", "who did more"]),
            ("de", "pflege", ["prämie", "rangliste", "zuweisen", "wettbewerb"])
        ]

        for localizedCase in localizedCases {
            let content = FamilyWeeklyReportService.makeWeeklyReportContent(l: L10n(localizedCase.language))
            let copy = "\(content.title)\n\(content.body)"

            #expect(copy.localizedCaseInsensitiveContains(localizedCase.careNeedle))
            for term in localizedCase.blockedTerms {
                #expect(!copy.localizedCaseInsensitiveContains(term))
            }
            #expect(content.categoryIdentifier == "FAMILY_WEEKLY_REPORT")
            #expect(content.userInfo["notificationTier"] as? String == NotificationDeliveryTier.ambient.rawValue)
            #expect(content.userInfo["notificationCategory"] as? String == NotificationDeliveryCategory.weeklyReport.rawValue)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }

    private func restorePreference(_ previousValue: Any?, key: String, defaults: UserDefaults) {
        if let previousValue {
            defaults.set(previousValue, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
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
