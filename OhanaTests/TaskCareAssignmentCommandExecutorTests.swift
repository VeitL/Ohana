import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct TaskCareAssignmentCommandExecutorTests {
    @Test func multiHumanRecurringCareCreatesOneLinkedAssignmentPerOccurrenceInOneResult() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let assignee = Human(name: "Kid")
        let pet = Pet(name: "Momo", species: "cat")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        creator.coconutBalance = 100
        context.insert(creator)
        context.insert(assignee)
        context.insert(pet)
        try context.save()

        let result = try TaskCareAssignmentCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskCareAssignmentCommand(
                preset: TaskCreationPreset(subjectID: pet.id, careKind: .petFeeding),
                title: "Feed Momo",
                startDate: start,
                isAllDay: false,
                recurrenceDays: 1,
                recurrenceEndDate: start.addingTimeInterval(86400.0),
                creatorHumanID: creator.id,
                assigneeHumanID: assignee.id,
                rewardCoconuts: 0
            ),
            scheduleNotifications: false
        )

        let event = try #require(try context.fetch(FetchDescriptor<Event>()).first)
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        let tasks = try context.fetch(FetchDescriptor<FamilyCollaborationTask>())
        #expect(event.id == result.eventID)
        #expect(event.taskCareKindRaw == TaskCareKind.petFeeding.rawValue)
        #expect(event.relatedEntityId == pet.id.uuidString)
        #expect(event.assigneeId == assignee.id.uuidString)
        #expect(reminders.count == 2)
        #expect(tasks.count == 2)
        #expect(result.reminderIDs.count == 2)
        #expect(result.familyTaskIDs.count == 2)
        #expect(!result.scheduledNotifications)
        #expect(Set(tasks.compactMap(\.relatedReminderId)) == Set(reminders.map(\.id.uuidString)))
        #expect(tasks.allSatisfy {
            $0.relatedEventId == event.id.uuidString &&
                $0.subjectKind == .pet &&
                $0.resolvedSubjectId == pet.id.uuidString &&
                $0.kind == .careReminder
        })
    }

    @Test func soloCareStillCreatesInternalReminderWithoutCollaborationNoise() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Solo")
        let plant = Plant(name: "Fern", wateringIntervalDays: 3)
        context.insert(human)
        context.insert(plant)
        try context.save()

        let result = try TaskCareAssignmentCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskCareAssignmentCommand(
                preset: TaskCreationPreset(subjectID: plant.id, careKind: .plantWatering),
                title: "Water Fern",
                startDate: Date(timeIntervalSince1970: 1_800_100_000),
                isAllDay: true,
                creatorHumanID: human.id,
                assigneeHumanID: human.id
            ),
            scheduleNotifications: false
        )

        let event = try #require(try context.fetch(FetchDescriptor<Event>()).first)
        #expect(event.taskCareKindRaw == TaskCareKind.plantWatering.rawValue)
        #expect(event.assigneeId == human.id.uuidString)
        #expect(result.reminderIDs.count == 1)
        #expect(result.familyTaskIDs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
    }

    @Test func archivedTargetRejectsWholeCreationBeforeAnyRowIsInserted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plant = Plant(name: "Archived", wateringIntervalDays: 7)
        plant.archivedAt = Date()
        context.insert(plant)
        try context.save()

        #expect(throws: TaskCareAssignmentError.unavailableSubject) {
            try TaskCareAssignmentCommandExecutor(
                modelContext: context,
                services: AppServices(modelContainer: container)
            ).execute(
                TaskCareAssignmentCommand(
                    preset: TaskCreationPreset(subjectID: plant.id, careKind: .plantFertilizing),
                    title: "Fertilize",
                    startDate: Date(),
                    isAllDay: true
                ),
                scheduleNotifications: false
            )
        }

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
    }

    @Test func reminderLeadTimeDoesNotChangeTheCareOccurrenceDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Solo")
        let pet = Pet(name: "Momo", species: "cat")
        let occurrence = Date(timeIntervalSince1970: 1_800_172_800)
        context.insert(human)
        context.insert(pet)
        try context.save()

        _ = try TaskCareAssignmentCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskCareAssignmentCommand(
                preset: TaskCreationPreset(subjectID: pet.id, careKind: .petLitter),
                title: "Scoop litter",
                startDate: occurrence,
                isAllDay: false,
                recurrenceDays: 1,
                recurrenceEndDate: occurrence,
                notificationLeadMinutes: 13 * 60,
                creatorHumanID: human.id,
                assigneeHumanID: human.id
            ),
            scheduleNotifications: false
        )

        let reminder = try #require(try context.fetch(FetchDescriptor<Reminder>()).first)
        let event = try #require(reminder.event)
        #expect(reminder.scheduledAt == occurrence.addingTimeInterval(-13 * 3600))
        #expect(reminder.resolvedOccurrenceAt == occurrence)
        let mutation = try #require(DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .userCommand,
            context: context
        ))
        #expect(DomainScheduleWriter.completeReminder(
            reminder,
            mutation: mutation,
            completedBy: human.id.uuidString,
            completedAt: occurrence,
            context: context
        ))
        #expect(event.isOccurrenceMarkedComplete(on: occurrence))
        #expect(!event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
    }

    @Test func recurringRewardRequiresBalanceForEveryCreatedOccurrence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let assignee = Human(name: "Kid")
        let pet = Pet(name: "Momo", species: "cat")
        let start = Date(timeIntervalSince1970: 1_800_300_000)
        creator.coconutBalance = 5
        context.insert(creator)
        context.insert(assignee)
        context.insert(pet)
        try context.save()

        #expect(throws: TaskCareAssignmentError.unavailableAssignee) {
            try TaskCareAssignmentCommandExecutor(
                modelContext: context,
                services: AppServices(modelContainer: container)
            ).execute(
                TaskCareAssignmentCommand(
                    preset: TaskCreationPreset(subjectID: pet.id, careKind: .petFeeding),
                    title: "Feed Momo",
                    startDate: start,
                    isAllDay: false,
                    recurrenceDays: 1,
                    recurrenceEndDate: start.addingTimeInterval(86400),
                    creatorHumanID: creator.id,
                    assigneeHumanID: assignee.id,
                    rewardCoconuts: 5
                ),
                scheduleNotifications: false
            )
        }
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(ArkSchemaV89.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }
}
