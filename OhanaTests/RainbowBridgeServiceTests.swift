import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct RainbowBridgeServiceTests {
    @Test func markPassedAwayDeletesFuturePetRemindersAndEventsOnly() throws {
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
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
