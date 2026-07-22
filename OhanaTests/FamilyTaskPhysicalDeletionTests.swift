import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct FamilyTaskPhysicalDeletionTests {
    final class NotificationSpy: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledIDs: [String] = []

        func schedule(reminder _: Reminder) {}

        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func schedule(
            reminder _: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledIDs.append(notificationId) }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    @Test func deletingPetRemovesEveryOccurrenceAndDerivedScheduleForMatchingPlan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let notifications = NotificationSpy()
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        let deletedPet = Pet(name: "Deleted pet")
        let historicalPet = Pet(name: "Historical pet")
        context.insert(creator)
        context.insert(assignee)
        context.insert(deletedPet)
        context.insert(historicalPet)

        let deletedGraph = makeGraph(
            title: "Moved pet series",
            planSubjectKind: .pet,
            planSubjectID: deletedPet.id,
            occurrenceSubjectKind: .pet,
            occurrenceSubjectID: historicalPet.id,
            creator: creator,
            assignee: assignee,
            context: context
        )
        let retainedGraph = makeGraph(
            title: "Retained pet series",
            planSubjectKind: .pet,
            planSubjectID: historicalPet.id,
            occurrenceSubjectKind: .pet,
            occurrenceSubjectID: historicalPet.id,
            creator: creator,
            assignee: assignee,
            context: context
        )
        try context.save()

        PhysicalDeletionService.deletePet(
            deletedPet,
            context: context,
            notifications: notifications
        )
        try context.save()

        try expectOnlyGraph(retainedGraph, remainsIn: context)
        #expect(try context.fetch(FetchDescriptor<Pet>()).map(\.id).contains(historicalPet.id))
        #expect(Set(notifications.cancelledIDs) == Set(deletedGraph.notificationIDs))
        try expectDeletionTombstones(for: deletedGraph, context: context)
    }

    @Test func deletingPlantRemovesHistoricalOccurrencesWhoseSubjectChanged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let notifications = NotificationSpy()
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        let deletedPlant = Plant(name: "Deleted plant")
        let historicalPlant = Plant(name: "Historical plant")
        context.insert(creator)
        context.insert(assignee)
        context.insert(deletedPlant)
        context.insert(historicalPlant)

        let deletedGraph = makeGraph(
            title: "Moved plant series",
            planSubjectKind: .plant,
            planSubjectID: deletedPlant.id,
            occurrenceSubjectKind: .plant,
            occurrenceSubjectID: historicalPlant.id,
            creator: creator,
            assignee: assignee,
            context: context
        )
        let retainedGraph = makeGraph(
            title: "Retained plant series",
            planSubjectKind: .plant,
            planSubjectID: historicalPlant.id,
            occurrenceSubjectKind: .plant,
            occurrenceSubjectID: historicalPlant.id,
            creator: creator,
            assignee: assignee,
            context: context
        )
        try context.save()

        PhysicalDeletionService.deletePlant(
            deletedPlant,
            context: context,
            notifications: notifications
        )
        try context.save()

        try expectOnlyGraph(retainedGraph, remainsIn: context)
        #expect(try context.fetch(FetchDescriptor<Plant>()).map(\.id).contains(historicalPlant.id))
        #expect(Set(notifications.cancelledIDs) == Set(deletedGraph.notificationIDs))
        try expectDeletionTombstones(for: deletedGraph, context: context)
    }

    @Test func deletingHumanRemovesSubjectPlanHistoryAndDirectInboxActivities() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let notifications = NotificationSpy()
        let deletedHuman = Human(name: "Deleted human")
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        let historicalPet = Pet(name: "Historical pet")
        context.insert(deletedHuman)
        context.insert(creator)
        context.insert(assignee)
        context.insert(historicalPet)

        let deletedGraph = makeGraph(
            title: "Moved human series",
            planSubjectKind: .human,
            planSubjectID: deletedHuman.id,
            occurrenceSubjectKind: .pet,
            occurrenceSubjectID: historicalPet.id,
            creator: creator,
            assignee: assignee,
            context: context
        )
        let retainedGraph = makeGraph(
            title: "Retained household series",
            planSubjectKind: .household,
            planSubjectID: nil,
            occurrenceSubjectKind: .pet,
            occurrenceSubjectID: historicalPet.id,
            creator: creator,
            assignee: assignee,
            context: context
        )
        let directInboxActivity = FamilyTaskActivity(
            planId: retainedGraph.plan.id.uuidString,
            taskId: retainedGraph.tasks[0].id.uuidString,
            kind: .commented,
            actorHumanId: deletedHuman.id.uuidString,
            actorHumanName: deletedHuman.name,
            recipientHumanId: assignee.id.uuidString,
            taskTitleSnapshot: retainedGraph.plan.title,
            idempotencyKey: "direct-deleted-human-activity"
        )
        context.insert(directInboxActivity)
        try context.save()

        #expect(PhysicalDeletionService.deleteHuman(
            deletedHuman,
            context: context,
            notifications: notifications
        ) >= 0)
        try context.save()

        try expectOnlyGraph(retainedGraph, remainsIn: context)
        #expect(try context.fetch(FetchDescriptor<FamilyTaskActivity>()).allSatisfy {
            $0.id != directInboxActivity.id
        })
        #expect(Set(notifications.cancelledIDs) == Set(deletedGraph.notificationIDs))
        try expectDeletionTombstones(for: deletedGraph, context: context)
    }

    private struct Graph {
        let plan: FamilyTaskPlan
        let tasks: [FamilyCollaborationTask]
        let events: [Event]
        let reminders: [Reminder]
        let activities: [FamilyTaskActivity]

        var notificationIDs: [String] { reminders.map(\.notificationId) }
    }

    private func makeGraph(
        title: String,
        planSubjectKind: FamilyCollaborationTaskSubjectKind,
        planSubjectID: UUID?,
        occurrenceSubjectKind: FamilyCollaborationTaskSubjectKind,
        occurrenceSubjectID: UUID?,
        creator: Human,
        assignee: Human,
        context: ModelContext
    ) -> Graph {
        let anchor = Date(timeIntervalSinceReferenceDate: 1000)
        let plan = FamilyTaskPlan(
            title: title,
            subjectKind: planSubjectKind,
            subjectId: planSubjectID?.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            recurrenceRule: .everyNDays(7),
            anchorAt: anchor,
            timeZoneIdentifier: "UTC"
        )
        let relatedEntity = eventEntity(
            subjectKind: occurrenceSubjectKind,
            subjectID: occurrenceSubjectID
        )
        var tasks: [FamilyCollaborationTask] = []
        var events: [Event] = []
        var reminders: [Reminder] = []
        for index in 0 ..< 2 {
            let nominalAt = anchor.addingTimeInterval(Double(index) * 604_800)
            let occurrenceKey = "\(plan.id.uuidString):v1:\(index)"
            let event = Event(
                title: "\(title) \(index)",
                startDate: nominalAt,
                eventType: EventType.task.rawValue,
                relatedEntityType: relatedEntity.kind,
                relatedEntityId: relatedEntity.id,
                familyTaskPlanId: plan.id.uuidString,
                familyTaskOccurrenceKey: occurrenceKey
            )
            let reminder = Reminder(event: event, scheduledAt: nominalAt, occurrenceAt: nominalAt)
            reminder.notificationId = "\(plan.id.uuidString)-\(index)"
            event.reminders = [reminder]
            let task = FamilyCollaborationTask(
                title: event.title,
                kind: .householdTask,
                subjectKind: occurrenceSubjectKind,
                subjectId: occurrenceSubjectID?.uuidString,
                relatedEventId: event.id.uuidString,
                relatedReminderId: reminder.id.uuidString,
                planId: plan.id.uuidString,
                occurrenceKey: occurrenceKey,
                nominalAt: nominalAt,
                scheduleVersion: 1,
                createdById: creator.id.uuidString,
                createdByName: creator.name,
                assignedToId: assignee.id.uuidString,
                assignedToName: assignee.name,
                dueAt: nominalAt
            )
            context.insert(event)
            context.insert(reminder)
            context.insert(task)
            events.append(event)
            reminders.append(reminder)
            tasks.append(task)
        }

        let sourceEvent = Event(
            title: "\(title) source",
            startDate: anchor,
            eventType: EventType.task.rawValue,
            relatedEntityType: relatedEntity.kind,
            relatedEntityId: relatedEntity.id
        )
        let sourceReminder = Reminder(event: sourceEvent, scheduledAt: anchor)
        sourceReminder.notificationId = "\(plan.id.uuidString)-source"
        sourceEvent.reminders = [sourceReminder]
        plan.sourceEventId = sourceEvent.id.uuidString
        let activity = FamilyTaskActivity(
            planId: plan.id.uuidString,
            taskId: tasks[0].id.uuidString,
            occurrenceKey: tasks[0].occurrenceKey,
            kind: .edited,
            actorHumanId: creator.id.uuidString,
            actorHumanName: creator.name,
            recipientHumanId: assignee.id.uuidString,
            taskTitleSnapshot: title,
            idempotencyKey: "\(plan.id.uuidString)-activity"
        )
        context.insert(plan)
        context.insert(sourceEvent)
        context.insert(sourceReminder)
        context.insert(activity)
        events.append(sourceEvent)
        reminders.append(sourceReminder)
        return Graph(
            plan: plan,
            tasks: tasks,
            events: events,
            reminders: reminders,
            activities: [activity]
        )
    }

    private func eventEntity(
        subjectKind: FamilyCollaborationTaskSubjectKind,
        subjectID: UUID?
    ) -> (kind: String, id: String) {
        let kind = switch subjectKind {
        case .household: ""
        case .human: EntityKind.human.rawValue
        case .pet: EntityKind.pet.rawValue
        case .plant: EntityKind.plant.rawValue
        }
        return (kind, subjectID?.uuidString ?? "")
    }

    private func expectOnlyGraph(_ graph: Graph, remainsIn context: ModelContext) throws {
        #expect(Set(try context.fetch(FetchDescriptor<FamilyTaskPlan>()).map(\.id)) == Set([graph.plan.id]))
        #expect(Set(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).map(\.id)) == Set(graph.tasks.map(\.id)))
        #expect(Set(try context.fetch(FetchDescriptor<Event>()).map(\.id)) == Set(graph.events.map(\.id)))
        #expect(Set(try context.fetch(FetchDescriptor<Reminder>()).map(\.id)) == Set(graph.reminders.map(\.id)))
        #expect(Set(try context.fetch(FetchDescriptor<FamilyTaskActivity>()).map(\.id)) == Set(graph.activities.map(\.id)))
    }

    private func expectDeletionTombstones(for graph: Graph, context: ModelContext) throws {
        let tombstones = try context.fetch(FetchDescriptor<CloudSyncRecordState>()).filter(\.isDeletionTombstone)
        let tombstoneKeys = Set(tombstones.map(\.recordKey))
        for task in graph.tasks {
            #expect(tombstoneKeys.contains(CloudSyncRecordState.recordKey(
                entityName: String(describing: FamilyCollaborationTask.self),
                localRecordId: task.id
            )))
        }
        for event in graph.events {
            #expect(tombstoneKeys.contains(CloudSyncRecordState.recordKey(
                entityName: String(describing: Event.self),
                localRecordId: event.id
            )))
        }
        for reminder in graph.reminders {
            #expect(tombstoneKeys.contains(CloudSyncRecordState.recordKey(
                entityName: String(describing: Reminder.self),
                localRecordId: reminder.id
            )))
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV95.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
