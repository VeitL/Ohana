import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct RainbowBridgeServiceTests {
    @Test func markPassedAwayRemovesFutureSchedulesAndKeepsHistoryReadOnly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let now = Date()
        let past = now.addingTimeInterval(-3600)
        let future = now.addingTimeInterval(3600)
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        let futureEvent = Event(
            title: "Future vet",
            startDate: future,
            eventType: EventType.vetVisit.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let pastEvent = Event(
            title: "Past vet",
            startDate: past,
            eventType: EventType.vetVisit.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let otherFutureEvent = Event(
            title: "Other future vet",
            startDate: future,
            eventType: EventType.vetVisit.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: otherPet.id.uuidString
        )
        let futureReminder = Reminder(event: futureEvent, scheduledAt: future)
        let pastReminder = Reminder(event: pastEvent, scheduledAt: past)
        let otherFutureReminder = Reminder(event: otherFutureEvent, scheduledAt: future)
        let futureEventID = futureEvent.id
        let pastEventID = pastEvent.id
        let otherFutureEventID = otherFutureEvent.id
        let futureReminderID = futureReminder.id
        let pastReminderID = pastReminder.id
        let otherFutureReminderID = otherFutureReminder.id

        context.insert(pet)
        context.insert(otherPet)
        context.insert(futureEvent)
        context.insert(pastEvent)
        context.insert(otherFutureEvent)
        context.insert(futureReminder)
        context.insert(pastReminder)
        context.insert(otherFutureReminder)
        try context.save()

        RainbowBridgeService().markPassedAway(pet: pet, date: now, context: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(pet.passedAwayDate == now)
        #expect(!events.contains { $0.id == futureEventID })
        #expect(events.contains { $0.id == pastEventID })
        #expect(events.contains { $0.id == otherFutureEventID })
        #expect(!reminders.contains { $0.id == futureReminderID })
        #expect(reminders.contains { $0.id == pastReminderID })
        #expect(reminders.contains { $0.id == otherFutureReminderID })
        #expect(reminders.first { $0.id == pastReminderID }?.statusEnum == .pending)
        #expect(reminders.first { $0.id == otherFutureReminderID }?.statusEnum == .pending)
    }

    @Test func undoPassedAwayClearsLifecycleFieldWithoutRestoringFutureSchedules() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let now = Date()
        let future = now.addingTimeInterval(3600)
        let pet = Pet(name: "Momo", species: "cat")
        let event = Event(
            title: "Future vet",
            startDate: future,
            eventType: EventType.vetVisit.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let memorialReminder = Reminder(event: event, scheduledAt: future)
        let eventID = event.id
        let reminderID = memorialReminder.id
        let userSkippedEvent = Event(
            title: "User skipped future vet",
            startDate: future.addingTimeInterval(7200),
            eventType: EventType.vetVisit.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let userSkippedReminder = Reminder(event: userSkippedEvent, scheduledAt: future.addingTimeInterval(7200))
        userSkippedReminder.statusEnum = .skipped
        userSkippedReminder.completedBy = "human-1"
        let skippedEventID = userSkippedEvent.id
        let skippedReminderID = userSkippedReminder.id

        context.insert(pet)
        context.insert(event)
        context.insert(userSkippedEvent)
        context.insert(memorialReminder)
        context.insert(userSkippedReminder)
        try context.save()

        RainbowBridgeService().markPassedAway(pet: pet, date: now, context: context)
        RainbowBridgeService().undoPassedAway(pet: pet, context: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(pet.passedAwayDate == nil)
        #expect(!events.contains { $0.id == eventID })
        #expect(!reminders.contains { $0.id == reminderID })
        #expect(events.contains { $0.id == skippedEventID })
        #expect(reminders.contains { $0.id == skippedReminderID })
    }

    @Test func markPassedAwayTrimsRecurringFutureRemindersButKeepsHistoricalOccurrences() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let now = Date()
        let pet = Pet(name: "Momo", species: "cat")
        let recurring = Event(
            title: "Daily care",
            startDate: now.addingTimeInterval(-86400),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        recurring.recurrenceDays = 1
        recurring.completedOccurrences = ["past-occurrence"]
        let pastReminder = Reminder(event: recurring, scheduledAt: now.addingTimeInterval(-3600))
        pastReminder.statusEnum = .completed
        pastReminder.completedAt = now.addingTimeInterval(-1800)
        let futureReminder = Reminder(event: recurring, scheduledAt: now.addingTimeInterval(3600))
        let eventID = recurring.id
        let pastReminderID = pastReminder.id
        let futureReminderID = futureReminder.id

        context.insert(pet)
        context.insert(recurring)
        context.insert(pastReminder)
        context.insert(futureReminder)
        try context.save()

        RainbowBridgeService().markPassedAway(pet: pet, date: now, context: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let retainedEvent = try #require(events.first { $0.id == eventID })
        #expect(retainedEvent.recurrenceDays == 0)
        #expect(retainedEvent.recurrenceEndDate == now)
        #expect(retainedEvent.completedOccurrences == ["past-occurrence"])
        #expect(reminders.contains { $0.id == pastReminderID })
        #expect(!reminders.contains { $0.id == futureReminderID })
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(retainedEvent, now: now))
    }

    @Test func deceasedHumanDoesNotReceiveEconomyRewards() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Li")
        human.passedAwayDate = Date()
        context.insert(human)
        try context.save()

        let previousActiveHuman = UserDefaults.standard.string(forKey: "currentActiveHumanId")
        defer {
            if let previousActiveHuman {
                UserDefaults.standard.set(previousActiveHuman, forKey: "currentActiveHumanId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")
            }
        }
        UserDefaults.standard.set(human.id.uuidString, forKey: "currentActiveHumanId")

        let reward = QuestManager().awardAction(
            type: .dailyFocusCompletion,
            pet: nil,
            context: context,
            quality: .none,
            executorId: nil
        )

        #expect(reward.humanGot == 0)
        #expect(reward.petGot == 0)
        #expect(human.coconutBalance == 0)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV72.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
