import Foundation
@testable import Ohana
import SwiftData
import Testing

@MainActor
struct ReminderActionCoordinatorTests {
    @Test func notificationActionUsesNarrowReminderLookup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let untouched = Reminder()
        let target = Reminder()
        context.insert(untouched)
        context.insert(target)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "SKIP",
                "notificationId": target.notificationId
            ],
            currentActiveHumanId: "human-1",
            context: context
        )

        #expect(result == .skipped)
        #expect(target.statusEnum == .skipped)
        #expect(target.completedBy == "human-1")
        #expect(untouched.statusEnum == .pending)
    }

    @Test func missingReminderDoesNotMutateExistingReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reminder = Reminder()
        context.insert(reminder)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "reminderId": UUID().uuidString
            ],
            currentActiveHumanId: "human-1",
            context: context
        )

        #expect(result == .missingReminder)
        #expect(reminder.statusEnum == .pending)
        #expect(reminder.completedBy.isEmpty)
    }

    @Test func manualFeedReminderCompletesThroughCareService() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "早餐",
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(60))
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "reminderId": reminder.id.uuidString
            ],
            currentActiveHumanId: "human-1",
            context: context
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(result == .completed)
        #expect(reminder.statusEnum == .completed)
        #expect(event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV56.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
