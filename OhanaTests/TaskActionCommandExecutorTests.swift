import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct TaskActionCommandExecutorTests {
    @Test func linkedCareSubmissionWritesFactThenProjectsReviewExactlyOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let pet = Pet(name: "Momo", species: "cat")
        let dueAt = Date(timeIntervalSince1970: 1_784_000_000)
        let event = Event(
            title: "Scoop litter",
            startDate: dueAt,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: dueAt)
        let task = FamilyCollaborationTask(
            title: "Scoop litter",
            kind: .bounty,
            relatedPetId: pet.id.uuidString,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
        context.insert(creator)
        context.insert(worker)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(worker.id.uuidString)
        defer { restoreSelection() }
        let services = AppServices(modelContainer: container)
        let item = try #require(TaskCenterSnapshotBuilder.make(
            events: [event],
            allEvents: [event],
            pets: [pet],
            humans: [creator, worker],
            plants: [],
            reminders: [reminder],
            familyTasks: [task],
            activeHumanId: worker.id.uuidString,
            now: dueAt,
            calendar: utcCalendar()
        ).allItems.first)
        let command = TaskActionCommand(item: item, action: .submitForReview)
        let executor = TaskActionCommandExecutor(modelContext: context, services: services)

        let first = executor.execute(
            command,
            events: [event],
            familyTasks: [task],
            humans: [creator, worker],
            pets: [pet]
        )
        let replay = executor.execute(
            command,
            events: [event],
            familyTasks: [task],
            humans: [creator, worker],
            pets: [pet]
        )

        #expect(first.disposition == .applied)
        #expect(replay.disposition == .alreadyApplied)
        #expect(event.isOccurrenceMarkedComplete(on: dueAt))
        #expect(reminder.isCompleted)
        #expect(task.status == .pendingReview)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(first.affectedEntityIDs == [event.id, reminder.id, task.id, pet.id])
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(!walletEntries.contains {
            $0.source == .familyTask
        })
    }

    @Test func standaloneTaskCompletionIsIdempotentAndDoesNotInventCareFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let task = FamilyCollaborationTask(
            title: "Take out recycling",
            kind: .householdTask,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name
        )
        context.insert(creator)
        context.insert(worker)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(worker.id.uuidString)
        defer { restoreSelection() }
        let services = AppServices(modelContainer: container)
        let item = try #require(TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [creator, worker],
            plants: [],
            familyTasks: [task],
            activeHumanId: worker.id.uuidString
        ).unscheduled.first)
        let command = TaskActionCommand(item: item, action: .complete)
        let executor = TaskActionCommandExecutor(modelContext: context, services: services)

        let first = executor.execute(
            command,
            events: [],
            familyTasks: [task],
            humans: [creator, worker],
            pets: []
        )
        let replay = executor.execute(
            command,
            events: [],
            familyTasks: [task],
            humans: [creator, worker],
            pets: []
        )

        #expect(first.disposition == .applied)
        #expect(replay.disposition == .alreadyApplied)
        #expect(task.status == .completed)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
    }

    @Test func explicitActionHumanOverridesDeviceDefaultForOneTaskOnly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let current = Human(name: "Current")
        let worker = Human(name: "Worker")
        let task = FamilyCollaborationTask(
            title: "Take out recycling",
            kind: .householdTask,
            createdById: current.id.uuidString,
            createdByName: current.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name
        )
        [current, worker].forEach(context.insert)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(current.id.uuidString)
        defer { restoreSelection() }
        let command = TaskActionCommand(
            item: standaloneItem(task),
            action: .complete,
            actingHumanID: worker.id
        )
        let result = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            command,
            events: [],
            familyTasks: [task],
            humans: [current, worker],
            pets: []
        )

        #expect(result.disposition == .applied)
        #expect(task.completedById == worker.id.uuidString)
        #expect(UserDefaults.standard.string(forKey: "currentActiveHumanId") == current.id.uuidString)
    }

    @Test func invalidExplicitActionHumanNeverFallsBackToDeviceDefault() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let current = Human(name: "Current")
        let task = FamilyCollaborationTask(
            title: "Take out recycling",
            kind: .householdTask,
            createdById: current.id.uuidString,
            createdByName: current.name,
            assignedToId: current.id.uuidString,
            assignedToName: current.name
        )
        context.insert(current)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(current.id.uuidString)
        defer { restoreSelection() }
        let result = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskActionCommand(
                item: standaloneItem(task),
                action: .complete,
                actingHumanID: UUID()
            ),
            events: [],
            familyTasks: [task],
            humans: [current],
            pets: []
        )

        #expect(result.disposition == .rejected)
        #expect(task.status == .active)
        #expect(task.completedById == nil)
    }

    @Test func linkedRecurringPlantSubmissionWritesOneFactAndCompletesItsReminder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let plant = Plant(name: "Fern", wateringIntervalDays: 3)
        let dueAt = Date()
        let event = Event(
            title: "Water fern 植物计划",
            startDate: dueAt,
            isAllDay: true,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        event.recurrenceDays = 3
        let reminder = Reminder(
            event: event,
            scheduledAt: Calendar.current.date(byAdding: .day, value: -1, to: dueAt) ?? dueAt
        )
        let task = FamilyCollaborationTask(
            title: "Water fern",
            kind: .bounty,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
        context.insert(creator)
        context.insert(worker)
        context.insert(plant)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(worker.id.uuidString)
        defer { restoreSelection() }
        let executor = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        )
        let command = TaskActionCommand(
            item: linkedItem(
                event: event,
                reminder: reminder,
                task: task,
                subject: TaskSubjectSnapshot(
                    kind: .plant,
                    id: plant.id,
                    name: plant.name,
                    themeColorHex: nil
                ),
                occurrenceDate: dueAt
            ),
            action: .submitForReview
        )

        let first = executor.execute(
            command,
            events: [event],
            familyTasks: [task],
            humans: [creator, worker],
            pets: []
        )
        let replay = executor.execute(
            command,
            events: [event],
            familyTasks: [task],
            humans: [creator, worker],
            pets: []
        )

        #expect(first.disposition == .applied)
        #expect(replay.disposition == .alreadyApplied)
        #expect(reminder.isCompleted)
        #expect(task.status == .pendingReview)
        let plantLogs = try context.fetch(FetchDescriptor<PlantCareLog>())
        #expect(
            plantLogs.count == 1,
            "Expected one plant fact, got \(plantLogs.count): \(plantLogs.map(\.careTypeRaw))"
        )
    }

    @Test func missingGeneratedPlantTargetCannotCompleteAnyTaskProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let dueAt = Date()
        let missingPlantID = UUID()
        let event = Event(
            title: "Water missing fern 植物计划",
            startDate: dueAt,
            isAllDay: true,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: missingPlantID.uuidString
        )
        event.recurrenceDays = 3
        let reminder = Reminder(event: event, scheduledAt: dueAt)
        let task = FamilyCollaborationTask(
            title: "Water missing fern",
            kind: .bounty,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
        context.insert(creator)
        context.insert(worker)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(worker.id.uuidString)
        defer { restoreSelection() }
        let executor = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        )
        let result = executor.execute(
            TaskActionCommand(
                item: linkedItem(
                    event: event,
                    reminder: reminder,
                    task: task,
                    subject: TaskSubjectSnapshot(
                        kind: .plant,
                        id: missingPlantID,
                        name: "Missing fern",
                        themeColorHex: nil
                    ),
                    occurrenceDate: dueAt
                ),
                action: .submitForReview
            ),
            events: [event],
            familyTasks: [task],
            humans: [creator, worker],
            pets: []
        )

        #expect(result.disposition == .rejected)
        #expect(!event.isOccurrenceMarkedComplete(on: dueAt))
        #expect(reminder.isPending)
        #expect(task.status == .active)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
    }

    @Test func invalidFamilyTaskSubjectPreflightLeavesLinkedCareFactsUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let pet = Pet(name: "Momo", species: "cat")
        let dueAt = Date()
        let event = Event(
            title: "Scoop litter",
            startDate: dueAt,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: dueAt)
        let task = FamilyCollaborationTask(
            title: "Scoop litter",
            kind: .bounty,
            subjectKind: .plant,
            subjectId: UUID().uuidString,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
        context.insert(creator)
        context.insert(worker)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(worker.id.uuidString)
        defer { restoreSelection() }
        let result = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskActionCommand(
                item: linkedItem(
                    event: event,
                    reminder: reminder,
                    task: task,
                    subject: TaskSubjectSnapshot(
                        kind: .pet,
                        id: pet.id,
                        name: pet.name,
                        themeColorHex: nil
                    ),
                    occurrenceDate: dueAt
                ),
                action: .submitForReview
            ),
            events: [event],
            familyTasks: [task],
            humans: [creator, worker],
            pets: [pet]
        )

        #expect(result.disposition == .rejected)
        #expect(!event.isOccurrenceMarkedComplete(on: dueAt))
        #expect(event.completedOccurrences.isEmpty)
        #expect(reminder.isPending)
        #expect(reminder.completedAt == nil)
        #expect(task.status == .active)
        #expect(task.completedAt == nil)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func invalidSoloImplicitClaimPreflightLeavesLinkedCareFactsUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Solo")
        let pet = Pet(name: "Momo", species: "cat")
        let dueAt = Date()
        let event = Event(
            title: "Scoop litter",
            startDate: dueAt,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: dueAt)
        let task = FamilyCollaborationTask(
            title: "Scoop litter",
            kind: .householdTask,
            subjectKind: .plant,
            subjectId: UUID().uuidString,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: human.id.uuidString,
            createdByName: human.name,
            dueAt: dueAt
        )
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(human.id.uuidString)
        defer { restoreSelection() }
        let result = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskActionCommand(
                item: linkedItem(
                    event: event,
                    reminder: reminder,
                    task: task,
                    subject: TaskSubjectSnapshot(
                        kind: .pet,
                        id: pet.id,
                        name: pet.name,
                        themeColorHex: nil
                    ),
                    occurrenceDate: dueAt
                ),
                action: .complete
            ),
            events: [event],
            familyTasks: [task],
            humans: [human],
            pets: [pet]
        )

        #expect(result.disposition == .rejected)
        #expect(!event.isOccurrenceMarkedComplete(on: dueAt))
        #expect(event.completedOccurrences.isEmpty)
        #expect(reminder.isPending)
        #expect(reminder.completedAt == nil)
        #expect(task.status == .active)
        #expect(task.claimedById == nil)
        #expect(task.completedAt == nil)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func singleHumanCanCompleteOpenUnrewardedTaskThroughImplicitClaim() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Solo")
        let task = FamilyCollaborationTask(
            title: "Take out recycling",
            kind: .householdTask,
            createdById: human.id.uuidString,
            createdByName: human.name
        )
        context.insert(human)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(human.id.uuidString)
        defer { restoreSelection() }
        let command = TaskActionCommand(item: standaloneItem(task), action: .complete)
        let executor = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        )

        let first = executor.execute(
            command,
            events: [],
            familyTasks: [task],
            humans: [human],
            pets: []
        )
        let replay = executor.execute(
            command,
            events: [],
            familyTasks: [task],
            humans: [human],
            pets: []
        )

        #expect(first.disposition == .applied)
        #expect(replay.disposition == .alreadyApplied)
        #expect(task.status == .completed)
        #expect(task.claimedById == human.id.uuidString)
        #expect(task.completedById == human.id.uuidString)
    }

    @Test func singleHumanCannotSelfCompleteOpenRewardTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Solo")
        let task = FamilyCollaborationTask(
            title: "Rewarded task",
            kind: .bounty,
            createdById: human.id.uuidString,
            createdByName: human.name,
            rewardCoconuts: 10
        )
        context.insert(human)
        context.insert(task)
        try context.save()

        let restoreSelection = selectActiveHuman(human.id.uuidString)
        defer { restoreSelection() }
        let result = TaskActionCommandExecutor(
            modelContext: context,
            services: AppServices(modelContainer: container)
        ).execute(
            TaskActionCommand(item: standaloneItem(task), action: .complete),
            events: [],
            familyTasks: [task],
            humans: [human],
            pets: []
        )

        #expect(result.disposition == .rejected)
        #expect(task.status == .active)
        #expect(task.claimedById == nil)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func linkedReminderAndAssignmentArePreparedInOneRollbackBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.autosaveEnabled = false
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let pet = Pet(name: "Momo", species: "cat")
        let dueAt = Date(timeIntervalSince1970: 1_784_100_000)
        let event = Event(
            title: "Scoop litter",
            startDate: dueAt,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: dueAt, occurrenceAt: dueAt)
        let task = FamilyCollaborationTask(
            title: "Scoop litter",
            kind: .bounty,
            relatedPetId: pet.id.uuidString,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
        [creator, worker].forEach(context.insert)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let mutation = try #require(DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ))
        #expect(DomainScheduleWriter.completeReminder(
            reminder,
            mutation: mutation,
            completedBy: worker.id.uuidString,
            completedAt: dueAt,
            context: context
        ))
        #expect(FamilyTaskService.prepareCompletedReminder(
            reminder,
            completedBy: worker.id.uuidString,
            context: context
        ) == .prepared)
        #expect(reminder.isCompleted)
        #expect(task.status == .pendingReview)

        context.rollback()

        let reloadedReminder = try #require(context.fetch(FetchDescriptor<Reminder>()).first)
        let reloadedTask = try #require(context.fetch(FetchDescriptor<FamilyCollaborationTask>()).first)
        #expect(reloadedReminder.isPending)
        #expect(reloadedTask.status == .active)
        #expect(reloadedTask.completedAt == nil)
    }

    @Test func explicitOccurrenceCompletionUsesFrozenOccurrenceAfterReminderDrifts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let frozenOccurrence = Date(timeIntervalSince1970: 1_784_160_000)
        let driftedOccurrence = frozenOccurrence.addingTimeInterval(2 * 86400)
        let event = Event(
            title: "Scoop litter",
            startDate: frozenOccurrence,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        let reminder = Reminder(
            event: event,
            scheduledAt: frozenOccurrence,
            occurrenceAt: driftedOccurrence
        )
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let didComplete = ReminderCompletionService.complete(
            reminder,
            by: nil,
            occurrenceDate: frozenOccurrence,
            context: context,
            notifications: ReminderNotificationSchedulerRegistry.disabledScheduler()
        )

        #expect(didComplete)
        #expect(reminder.isCompleted)
        #expect(reminder.occurrenceAt == driftedOccurrence)
        #expect(event.isOccurrenceMarkedComplete(on: frozenOccurrence))
        #expect(!event.isOccurrenceMarkedComplete(on: driftedOccurrence))
    }

    @Test func replayingExplicitOccurrenceDoesNotDuplicateReminderCompletionLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let frozenOccurrence = Date(timeIntervalSince1970: 1_784_160_000)
        let event = Event(
            title: "Scoop litter",
            startDate: frozenOccurrence,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        let reminder = Reminder(
            event: event,
            scheduledAt: frozenOccurrence,
            occurrenceAt: frozenOccurrence
        )
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()
        let notifications = ReminderNotificationSchedulerRegistry.disabledScheduler()

        let first = ReminderCompletionService.complete(
            reminder,
            by: nil,
            occurrenceDate: frozenOccurrence,
            context: context,
            notifications: notifications
        )
        let replay = ReminderCompletionService.complete(
            reminder,
            by: nil,
            occurrenceDate: frozenOccurrence,
            context: context,
            notifications: notifications
        )
        let completionLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.eventKindEnum == .reminder &&
                $0.actionType == "complete" &&
                $0.sourceReminderId == reminder.id.uuidString
        }

        #expect(first)
        #expect(replay)
        #expect(event.isOccurrenceMarkedComplete(on: frozenOccurrence))
        #expect(completionLedgers.count == 1)
    }

    private func linkedItem(
        event: Event,
        reminder: Reminder,
        task: FamilyCollaborationTask,
        subject: TaskSubjectSnapshot,
        occurrenceDate: Date
    ) -> TaskCenterItemSnapshot {
        TaskCenterItemSnapshot(
            id: "linked-\(task.id.uuidString)",
            eventID: event.id,
            reminderID: reminder.id,
            familyTaskID: task.id,
            source: .linked,
            title: task.title,
            subject: subject,
            eventType: EventType(rawValue: event.eventType),
            symbol: "checkmark.circle",
            occurrenceDate: occurrenceDate,
            scheduledAt: occurrenceDate,
            dueAt: occurrenceDate,
            isAllDay: event.isAllDay,
            isRecurring: event.recurrenceDays > 0,
            urgency: .standard,
            workflowStatus: .active,
            availableActions: [.submitForReview],
            participantHumanIDs: [],
            createdByMember: nil,
            assignedToMember: nil,
            claimedByMember: nil,
            completedByMember: nil,
            rewardCoconuts: task.rewardCoconuts
        )
    }

    private func standaloneItem(_ task: FamilyCollaborationTask) -> TaskCenterItemSnapshot {
        TaskCenterItemSnapshot(
            id: "family-\(task.id.uuidString)",
            eventID: nil,
            reminderID: nil,
            familyTaskID: task.id,
            source: .familyTask,
            title: task.title,
            subject: .household,
            eventType: nil,
            symbol: "checkmark.circle",
            occurrenceDate: task.dueAt ?? task.createdAt,
            scheduledAt: task.dueAt ?? task.createdAt,
            dueAt: task.dueAt,
            isAllDay: false,
            isRecurring: false,
            urgency: .standard,
            workflowStatus: .active,
            availableActions: [.complete],
            participantHumanIDs: [],
            createdByMember: nil,
            assignedToMember: nil,
            claimedByMember: nil,
            completedByMember: nil,
            rewardCoconuts: task.rewardCoconuts
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(ArkSchemaV89.models),
            configurations: [configuration]
        )
    }

    private func selectActiveHuman(_ id: String) -> () -> Void {
        let defaults = UserDefaults.standard
        let key = "currentActiveHumanId"
        let previous = defaults.object(forKey: key)
        defaults.set(id, forKey: key)
        return {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
