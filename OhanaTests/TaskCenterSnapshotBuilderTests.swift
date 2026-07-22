import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct TaskCenterSnapshotBuilderTests {
    @Test func groupsOnlyActionablePendingEventsAndUsesRedForOverdueMedication() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)

        let overdue = Event(
            title: "Water fern",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 12, hour: 10),
            eventType: EventType.watering.rawValue
        )
        let medication = Event(
            title: "Morning medication",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 9),
            eventType: EventType.medication.rawValue
        )
        let today = Event(
            title: "Evening walk",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 18),
            eventType: EventType.daily.rawValue
        )
        let upcoming = Event(
            title: "Vet follow-up",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 14, hour: 11),
            eventType: EventType.vetVisit.rawValue
        )
        let birthday = Event(
            title: "Birthday",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 8),
            eventType: EventType.birthday.rawValue
        )
        let completed = Event(
            title: "Completed task",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 10),
            eventType: EventType.task.rawValue
        )
        completed.isCompleted = true
        let events = [overdue, medication, today, upcoming, birthday, completed]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [],
            humans: [],
            plants: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.overdue.map(\.title) == ["Water fern", "Morning medication"])
        #expect(snapshot.overdue.map(\.urgency) == [.overdue, .critical])
        #expect(snapshot.today.map(\.title) == ["Evening walk"])
        #expect(snapshot.upcoming.map(\.title) == ["Vet follow-up"])
        #expect(snapshot.pendingCount == 4)
        #expect(snapshot.criticalCount == 1)
        #expect(snapshot.todayCompletedCount == 1)
        #expect(snapshot.todayTotalCount == 3)
        #expect(!snapshot.overdue.contains { $0.title == "Birthday" })
    }

    @Test func recurringScheduleExposesOneCurrentOccurrenceWithinBoundedLookback() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let recurring = Event(
            title: "Daily care",
            startDate: makeDate(calendar, year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue
        )
        recurring.recurrenceDays = 1
        recurring.recurrenceEndDate = makeDate(calendar, year: 2026, month: 7, day: 20, hour: 8)

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [recurring],
            allEvents: [recurring],
            pets: [],
            humans: [],
            plants: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.pendingCount == 1)
        #expect(snapshot.overdue.count == 1)
        #expect(calendar.isDate(
            snapshot.overdue[0].occurrenceDate,
            inSameDayAs: makeDate(calendar, year: 2026, month: 6, day: 29)
        ))
        #expect(snapshot.overdue[0].isRecurring)
    }

    @Test func ordinaryHealthEventsRemainOrangeWhileFutureMedicationIsStandard() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let overdueHealth = Event(
            title: "Health check",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 12, hour: 9),
            eventType: EventType.health.rawValue
        )
        let futureMedication = Event(
            title: "Evening medication",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 19),
            eventType: EventType.medication.rawValue
        )
        let events = [overdueHealth, futureMedication]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [],
            humans: [],
            plants: [],
            now: now,
            calendar: calendar
        )

        #expect(snapshot.overdue.first?.urgency == .overdue)
        #expect(snapshot.today.first?.urgency == .standard)
        #expect(snapshot.criticalCount == 0)
    }

    @Test func linkedPendingReviewDeduplicatesCompletedEventAndKeepsReviewActions() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let dueAt = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 10)
        let creator = Human(name: "Parent")
        let assignee = Human(name: "Kid")
        let pet = Pet(name: "Momo", species: "cat")
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
            status: .pendingReview,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
        task.completedById = assignee.id.uuidString
        event.setOccurrenceMarkedComplete(true, on: dueAt)

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [event],
            allEvents: [event],
            pets: [pet],
            humans: [creator, assignee],
            plants: [],
            reminders: [reminder],
            familyTasks: [task],
            activeHumanId: creator.id.uuidString,
            now: now,
            calendar: calendar
        )

        let items = allItems(snapshot)
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(snapshot.pendingCount == 1)
        #expect(snapshot.todayTotalCount == 1)
        #expect(snapshot.todayCompletedCount == 0)
        #expect(item.source == .linked)
        #expect(item.eventID == event.id)
        #expect(item.reminderID == reminder.id)
        #expect(item.familyTaskID == task.id)
        #expect(item.workflowStatus == .pendingReview)
        #expect(item.availableActions == [.approve, .reject])
        #expect(item.subject.kind == .pet)
        #expect(item.subject.id == pet.id)
        #expect(item.subjectName == "Momo")
        #expect(item.participantHumanIDs == [creator.id, assignee.id])
        #expect(item.createdByMember == TaskMemberSnapshot(id: creator.id, name: creator.name))
        #expect(item.assignedToMember == TaskMemberSnapshot(id: assignee.id, name: assignee.name))
        #expect(item.completedByMember == TaskMemberSnapshot(id: assignee.id, name: assignee.name))
        #expect(item.rewardCoconuts == 10)
    }

    @Test func standaloneFamilyTasksUseDateAndUnscheduledGroupsWithHouseholdSubject() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let creator = Human(name: "Parent")
        let assignee = Human(name: "Kid")
        let scheduled = FamilyCollaborationTask(
            title: "Take out recycling",
            kind: .bounty,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 8,
            dueAt: makeDate(calendar, year: 2026, month: 7, day: 14, hour: 18)
        )
        let unscheduled = FamilyCollaborationTask(
            title: "Sort the cupboard",
            kind: .householdTask,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name
        )

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [creator, assignee],
            plants: [],
            familyTasks: [scheduled, unscheduled],
            activeHumanId: assignee.id.uuidString,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.upcoming.count == 1)
        #expect(snapshot.unscheduled.count == 1)
        let scheduledItem = try #require(snapshot.upcoming.first)
        let unscheduledItem = try #require(snapshot.unscheduled.first)
        #expect(snapshot.pendingCount == 2)
        #expect(scheduledItem.source == .familyTask)
        #expect(scheduledItem.eventID == nil)
        #expect(scheduledItem.familyTaskID == scheduled.id)
        #expect(scheduledItem.subject == .household)
        #expect(scheduledItem.availableActions == [.submitForReview])
        #expect(unscheduledItem.dueAt == nil)
        #expect(unscheduledItem.subject.kind == .household)
        #expect(unscheduledItem.availableActions == [.complete])
    }

    @Test func linkedEventsResolveHouseholdHumanPetAndPlantSubjects() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let dueAt = makeDate(calendar, year: 2026, month: 7, day: 14, hour: 12)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        let plant = Plant(name: "Fern")
        let household = Event(title: "Buy detergent", startDate: dueAt, eventType: EventType.shoppingList.rawValue)
        let humanEvent = Event(
            title: "Human task",
            startDate: dueAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString
        )
        let petEvent = Event(
            title: "Pet task",
            startDate: dueAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let plantEvent = Event(
            title: "Plant task",
            startDate: dueAt,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        let events = [household, humanEvent, petEvent, plantEvent]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [pet],
            humans: [human],
            plants: [plant],
            now: now,
            calendar: calendar
        )
        let itemsByTitle = Dictionary(uniqueKeysWithValues: snapshot.upcoming.map { ($0.title, $0) })

        #expect(try #require(itemsByTitle["Buy detergent"]).subject.kind == .household)
        #expect(try #require(itemsByTitle["Human task"]).subject.name == "Ava")
        #expect(try #require(itemsByTitle["Human task"]).subject.kind == .human)
        #expect(try #require(itemsByTitle["Pet task"]).subject.name == "Momo")
        #expect(try #require(itemsByTitle["Pet task"]).subject.kind == .pet)
        #expect(try #require(itemsByTitle["Plant task"]).subject.name == "Fern")
        #expect(try #require(itemsByTitle["Plant task"]).subject.kind == .plant)
    }

    @Test func standaloneFamilyTasksResolveAndFilterAllSubjectKindsWithValueOnlyRoles() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let dueAt = makeDate(calendar, year: 2026, month: 7, day: 14, hour: 12)
        let creator = Human(name: "Publisher")
        let assignee = Human(name: "Assignee")
        let claimant = Human(name: "Claimant")
        let completer = Human(name: "Completer")
        let humanSubject = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        let plant = Plant(name: "Fern")

        let householdTask = FamilyCollaborationTask(
            title: "Household",
            kind: .householdTask,
            createdById: "legacy-publisher",
            createdByName: "Legacy Publisher",
            dueAt: dueAt
        )
        let humanTask = FamilyCollaborationTask(
            title: "Human",
            kind: .householdTask,
            subjectKind: .human,
            subjectId: humanSubject.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: "Old Publisher Name",
            dueAt: dueAt
        )
        let legacyPetTask = FamilyCollaborationTask(
            title: "Pet",
            kind: .householdTask,
            relatedPetId: pet.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            dueAt: dueAt
        )
        let plantTask = FamilyCollaborationTask(
            title: "Plant",
            kind: .bounty,
            status: .pendingReview,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 12,
            dueAt: dueAt
        )
        plantTask.claimedById = claimant.id.uuidString
        plantTask.claimedByName = claimant.name
        plantTask.completedById = completer.id.uuidString
        plantTask.completedByName = completer.name

        let humans = [creator, assignee, claimant, completer, humanSubject]
        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [pet],
            humans: humans,
            plants: [plant],
            familyTasks: [householdTask, humanTask, legacyPetTask, plantTask],
            activeHumanId: creator.id.uuidString,
            now: now,
            calendar: calendar
        )
        let items = Dictionary(uniqueKeysWithValues: snapshot.upcoming.map { ($0.title, $0) })

        #expect(try #require(items["Household"]).subject == .household)
        #expect(try #require(items["Human"]).subject == TaskSubjectSnapshot(
            kind: .human,
            id: humanSubject.id,
            name: humanSubject.name,
            themeColorHex: humanSubject.themeColorHex
        ))
        #expect(try #require(items["Pet"]).subject == TaskSubjectSnapshot(
            kind: .pet,
            id: pet.id,
            name: pet.name,
            themeColorHex: pet.themeColorHex
        ))
        let plantItem = try #require(items["Plant"])
        #expect(plantItem.subject == TaskSubjectSnapshot(
            kind: .plant,
            id: plant.id,
            name: plant.name,
            themeColorHex: plant.themeColorHex
        ))
        #expect(try #require(items["Household"]).createdByMember == TaskMemberSnapshot(
            id: nil,
            name: "Legacy Publisher"
        ))
        #expect(try #require(items["Human"]).createdByMember == TaskMemberSnapshot(
            id: creator.id,
            name: creator.name
        ))
        #expect(plantItem.assignedToMember == TaskMemberSnapshot(id: assignee.id, name: assignee.name))
        #expect(plantItem.claimedByMember == TaskMemberSnapshot(id: claimant.id, name: claimant.name))
        #expect(plantItem.completedByMember == TaskMemberSnapshot(id: completer.id, name: completer.name))
        #expect(plantItem.rewardCoconuts == 12)
        #expect(snapshot.filtered(for: .human(humanSubject.id)).allItems.map(\.title) == ["Human"])
        #expect(snapshot.filtered(for: .pet(pet.id)).allItems.map(\.title) == ["Pet"])
        #expect(snapshot.filtered(for: .plant(plant.id)).allItems.map(\.title) == ["Plant"])
    }

    @Test func multipleOpenFamilyTasksForOneEventKeepStableCollisionFreeProjection() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let dueAt = makeDate(calendar, year: 2026, month: 7, day: 14, hour: 12)
        let createdAt = makeDate(calendar, year: 2026, month: 7, day: 1, hour: 12)
        let creator = Human(name: "Publisher")
        let assignee = Human(name: "Assignee")
        let event = Event(
            title: "Water fern",
            startDate: dueAt,
            eventType: EventType.watering.rawValue
        )
        let ids = [
            try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000001")),
            try #require(UUID(uuidString: "20000000-0000-4000-8000-000000000002")),
            try #require(UUID(uuidString: "30000000-0000-4000-8000-000000000003"))
        ]
        let tasks = ids.map { id in
            FamilyCollaborationTask(
                id: id,
                title: "Water fern",
                kind: .bounty,
                relatedEventId: event.id.uuidString,
                createdById: creator.id.uuidString,
                createdByName: creator.name,
                assignedToId: assignee.id.uuidString,
                assignedToName: assignee.name,
                rewardCoconuts: 5,
                dueAt: dueAt,
                createdAt: createdAt
            )
        }

        func make(_ familyTasks: [FamilyCollaborationTask]) -> TaskCenterSnapshot {
            TaskCenterSnapshotBuilder.make(
                events: [event],
                allEvents: [event],
                pets: [],
                humans: [creator, assignee],
                plants: [],
                familyTasks: familyTasks,
                activeHumanId: assignee.id.uuidString,
                now: now,
                calendar: calendar
            )
        }

        let forward = make(tasks)
        let reversed = make(Array(tasks.reversed()))
        let forwardItems = forward.allItems
        let reversedItems = reversed.allItems
        let itemIDs = forwardItems.map(\.id)

        #expect(forwardItems.count == 3)
        #expect(Set(itemIDs).count == forwardItems.count)
        #expect(itemIDs == reversedItems.map(\.id))
        #expect(forwardItems.map(\.familyTaskID) == reversedItems.map(\.familyTaskID))
        #expect(forwardItems.first(where: { !$0.id.hasPrefix("family-") })?.familyTaskID == ids[0])
        #expect(Set(itemIDs.filter { $0.hasPrefix("family-") }) == Set(ids.dropFirst().map {
            "family-\($0.uuidString)"
        }))
    }

    @Test func capabilitiesHideCollaborationActionsForSingleHumanAndRespectActiveActor() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let openTask = FamilyCollaborationTask(
            title: "Open chore",
            kind: .householdTask,
            createdById: creator.id.uuidString,
            createdByName: creator.name
        )
        let assignedTask = FamilyCollaborationTask(
            title: "Assigned bounty",
            kind: .bounty,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 5
        )
        let pendingReview = FamilyCollaborationTask(
            title: "Review bounty",
            kind: .bounty,
            status: .pendingReview,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 5
        )

        let singleHuman = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [creator],
            plants: [],
            familyTasks: [openTask, pendingReview],
            activeHumanId: creator.id.uuidString,
            now: now,
            calendar: calendar
        )
        let singleHumanItems = Dictionary(uniqueKeysWithValues: allItems(singleHuman).map { ($0.title, $0) })
        #expect(!singleHuman.showsMemberFilters)
        #expect(singleHuman.resolvedMemberFilter(explicitSelection: nil) == .all)
        #expect(singleHuman.resolvedMemberFilter(explicitSelection: .waitingForOthers) == .all)
        #expect(singleHuman.memberFilterSummary.allCount == 2)
        #expect(try #require(singleHumanItems["Open chore"]).availableActions == [.complete])
        #expect(try #require(singleHumanItems["Review bounty"]).availableActions.isEmpty)

        let workerView = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [creator, worker],
            plants: [],
            familyTasks: [openTask, assignedTask],
            activeHumanId: worker.id.uuidString,
            now: now,
            calendar: calendar
        )
        let workerItems = Dictionary(uniqueKeysWithValues: allItems(workerView).map { ($0.title, $0) })
        #expect(workerView.showsMemberFilters)
        #expect(workerView.memberFilterContext.activeHumanName == worker.name)
        #expect(workerView.resolvedMemberFilter(explicitSelection: nil) == .actionRequired)
        #expect(workerView.resolvedMemberFilter(explicitSelection: .all) == .all)
        #expect(try #require(workerItems["Open chore"]).availableActions == [.claim])
        #expect(try #require(workerItems["Assigned bounty"]).availableActions == [.submitForReview])
        #expect(Set(workerView.filtered(for: .actionRequired).allItems.map(\.title)) == [
            "Open chore", "Assigned bounty"
        ])
        #expect(workerView.filtered(for: .waitingForFamily).allItems.isEmpty)

        let creatorView = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [creator, worker],
            plants: [],
            familyTasks: [assignedTask, pendingReview],
            activeHumanId: creator.id.uuidString,
            now: now,
            calendar: calendar
        )
        let creatorItems = Dictionary(uniqueKeysWithValues: allItems(creatorView).map { ($0.title, $0) })
        #expect(try #require(creatorItems["Assigned bounty"]).availableActions.isEmpty)
        #expect(try #require(creatorItems["Review bounty"]).availableActions == [.approve, .reject])
        #expect(creatorView.filtered(for: .actionRequired).allItems.map(\.title) == ["Review bounty"])
        #expect(creatorView.filtered(for: .waitingForFamily).allItems.map(\.title) == ["Assigned bounty"])
    }

    @Test func linkedPendingReviewUsesEventDayInsteadOfLeadReminderDay() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let occurrenceDate = makeDate(calendar, year: 2026, month: 7, day: 14, hour: 10)
        let creator = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let event = Event(
            title: "Water fern",
            startDate: occurrenceDate,
            eventType: EventType.watering.rawValue
        )
        let reminder = Reminder(
            event: event,
            scheduledAt: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 10)
        )
        let task = FamilyCollaborationTask(
            title: "Water fern",
            kind: .bounty,
            status: .pendingReview,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 5
        )
        event.setOccurrenceMarkedComplete(true, on: occurrenceDate)

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [event],
            allEvents: [event],
            pets: [],
            humans: [creator, worker],
            plants: [],
            reminders: [reminder],
            familyTasks: [task],
            activeHumanId: creator.id.uuidString,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.today.isEmpty)
        let item = try #require(snapshot.upcoming.first)
        #expect(calendar.isDate(item.occurrenceDate, inSameDayAs: occurrenceDate))
        #expect(item.dueAt.map { calendar.isDate($0, inSameDayAs: occurrenceDate) } == true)
    }

    @Test func reviewAndDeclineRouteToActorQueuesWithoutExposingThirdPartyTasks() {
        #expect(TaskCenterMemberFilter.allCases == [.actionRequired, .waitingForFamily, .all])
        #expect(TaskCenterMemberFilter.allCases.map(\.id) == [
            "actionRequired", "waitingForFamily", "all"
        ])

        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let creator = Human(name: "Ava")
        let assignee = Human(name: "Kai")
        let unrelated = Human(name: "Mina")
        let review = FamilyCollaborationTask(
            title: "Confirm completed chore",
            kind: .bounty,
            status: .pendingReview,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 5,
            dueAt: makeDate(calendar, year: 2026, month: 7, day: 14, hour: 10)
        )
        review.completedById = assignee.id.uuidString
        review.completedByName = assignee.name
        let declined = FamilyCollaborationTask(
            title: "Reassign declined chore",
            kind: .householdTask,
            status: .declined,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            dueAt: makeDate(calendar, year: 2026, month: 7, day: 14, hour: 11)
        )
        let humans = [creator, assignee, unrelated]

        func snapshot(for human: Human) -> TaskCenterSnapshot {
            TaskCenterSnapshotBuilder.make(
                events: [],
                allEvents: [],
                pets: [],
                humans: humans,
                plants: [],
                familyTasks: [review, declined],
                activeHumanId: human.id.uuidString,
                now: now,
                calendar: calendar
            )
        }

        let creatorSnapshot = snapshot(for: creator)
        #expect(Set(creatorSnapshot.filtered(for: .actionRequired).allItems.map(\.title)) == [
            review.title, declined.title
        ])
        #expect(creatorSnapshot.filtered(for: .waitingForFamily).allItems.isEmpty)
        #expect(creatorSnapshot.memberFilterSummary.actionRequiredCount == 2)
        #expect(creatorSnapshot.allItems.first { $0.familyTaskID == declined.id }?.workflowStatus == .declined)

        let assigneeSnapshot = snapshot(for: assignee)
        #expect(assigneeSnapshot.filtered(for: .actionRequired).allItems.isEmpty)
        #expect(Set(assigneeSnapshot.filtered(for: .waitingForFamily).allItems.map(\.title)) == [
            review.title, declined.title
        ])
        #expect(assigneeSnapshot.memberFilterSummary.waitingForFamilyCount == 2)

        let unrelatedSnapshot = snapshot(for: unrelated)
        #expect(unrelatedSnapshot.filtered(for: .actionRequired).allItems.isEmpty)
        #expect(unrelatedSnapshot.filtered(for: .waitingForFamily).allItems.isEmpty)
        #expect(Set(unrelatedSnapshot.filtered(for: TaskCenterMemberFilter.all).allItems.map(\.title)) == [
            review.title, declined.title
        ])
        #expect(unrelatedSnapshot.memberFilterSummary.otherCount == 2)
    }

    @Test func actionQueuesComposeWithObjectScopeAndExposeScopedSummaries() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let dueAt = makeDate(calendar, year: 2026, month: 7, day: 14, hour: 10)
        let current = Human(name: "Ava")
        let other = Human(name: "Kai")
        let firstPet = Pet(name: "Momo", species: "cat")
        let secondPet = Pet(name: "Luna", species: "cat")
        let currentFirst = assignedEvent(
            title: "Momo care by Ava",
            dueAt: dueAt,
            human: current,
            pet: firstPet
        )
        let otherFirst = assignedEvent(
            title: "Momo care by Kai",
            dueAt: dueAt,
            human: other,
            pet: firstPet
        )
        let currentSecond = assignedEvent(
            title: "Luna care by Ava",
            dueAt: dueAt,
            human: current,
            pet: secondPet
        )
        let review = FamilyCollaborationTask(
            title: "Review Kai task",
            kind: .bounty,
            status: .pendingReview,
            createdById: current.id.uuidString,
            createdByName: current.name,
            assignedToId: other.id.uuidString,
            assignedToName: other.name,
            rewardCoconuts: 5,
            dueAt: dueAt
        )
        let delegated = FamilyCollaborationTask(
            title: "Delegated to Kai",
            kind: .householdTask,
            createdById: current.id.uuidString,
            createdByName: current.name,
            assignedToId: other.id.uuidString,
            assignedToName: other.name,
            dueAt: dueAt
        )
        let events = [currentFirst, otherFirst, currentSecond]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [firstPet, secondPet],
            humans: [current, other],
            plants: [],
            familyTasks: [review, delegated],
            activeHumanId: current.id.uuidString,
            now: now,
            calendar: calendar
        )

        #expect(Set(snapshot.filtered(for: .actionRequired).allItems.map(\.title)) == [
            "Momo care by Ava", "Luna care by Ava", "Review Kai task"
        ])
        #expect(snapshot.filtered(for: .waitingForFamily).allItems.map(\.title) == ["Delegated to Kai"])
        #expect(Set(snapshot.filtered(for: TaskCenterMemberFilter.all).allItems.map(\.title)) == [
            "Momo care by Ava", "Momo care by Kai", "Luna care by Ava",
            "Review Kai task", "Delegated to Kai"
        ])
        #expect(snapshot.filtered(for: .pendingReview) == snapshot.filtered(for: .actionRequired))
        #expect(snapshot.memberFilterSummary == TaskCenterMemberFilterSummary(
            actionRequiredCount: 3,
            waitingForFamilyCount: 1,
            allCount: 5,
            systemJourneyCount: 0
        ))
        #expect(snapshot.memberFilterSummary.otherCount == 1)

        let scopeThenMember = snapshot
            .filtered(for: .pet(firstPet.id))
            .filtered(for: .actionRequired)
        let memberThenScope = snapshot
            .filtered(for: .actionRequired)
            .filtered(for: .pet(firstPet.id))
        #expect(scopeThenMember.allItems.map(\.title) == ["Momo care by Ava"])
        #expect(memberThenScope.allItems.map(\.title) == scopeThenMember.allItems.map(\.title))
        let petScope = snapshot.filtered(for: .pet(firstPet.id))
        #expect(petScope.memberFilterSummary.actionRequiredCount == 1)
        #expect(petScope.memberFilterSummary.waitingForFamilyCount == 0)
        #expect(petScope.memberFilterSummary.allCount == 2)
        #expect(petScope.memberFilterSummary.otherCount == 1)
    }

    @Test func currentMemberFilterRebuildsForActiveHumanWithoutTreatingHumanSubjectAsResponsibility() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let dueAt = makeDate(calendar, year: 2026, month: 7, day: 14, hour: 10)
        let ava = Human(name: "Ava")
        let kai = Human(name: "Kai")
        let avaTask = Event(title: "Ava assignment", startDate: dueAt, eventType: EventType.task.rawValue)
        avaTask.assigneeId = ava.id.uuidString
        let kaiTask = Event(title: "Kai assignment", startDate: dueAt, eventType: EventType.task.rawValue)
        kaiTask.assigneeId = kai.id.uuidString
        let avaSubjectOnly = Event(
            title: "Ava appointment",
            startDate: dueAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: ava.id.uuidString
        )
        let events = [avaTask, kaiTask, avaSubjectOnly]

        func make(activeHumanID: UUID) -> TaskCenterSnapshot {
            TaskCenterSnapshotBuilder.make(
                events: events,
                allEvents: events,
                pets: [],
                humans: [ava, kai],
                plants: [],
                activeHumanId: activeHumanID.uuidString,
                now: now,
                calendar: calendar
            )
        }

        let avaSnapshot = make(activeHumanID: ava.id)
        let kaiSnapshot = make(activeHumanID: kai.id)

        #expect(avaSnapshot.resolvedMemberFilter(explicitSelection: nil) == .actionRequired)
        #expect(avaSnapshot.filtered(for: .actionRequired).allItems.map(\.title) == ["Ava assignment"])
        #expect(kaiSnapshot.filtered(for: .actionRequired).allItems.map(\.title) == ["Kai assignment"])
        #expect(avaSnapshot.filtered(for: TaskCenterScope.all).allItems.contains { $0.title == "Ava appointment" })
    }

    @Test func humanScopeFiltersItemsAndDoesNotReuseWholeHouseholdTodayMetrics() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let first = Human(name: "Ava")
        let second = Human(name: "Kai")
        let firstEvent = Event(
            title: "Ava task",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 15),
            eventType: EventType.task.rawValue
        )
        firstEvent.assigneeId = first.id.uuidString
        let secondEvent = Event(
            title: "Kai task",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 16),
            eventType: EventType.task.rawValue
        )
        secondEvent.assigneeId = second.id.uuidString

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [firstEvent, secondEvent],
            allEvents: [firstEvent, secondEvent],
            pets: [],
            humans: [first, second],
            plants: [],
            now: now,
            calendar: calendar
        )
        let scoped = snapshot.filtered(for: .human(first.id))

        #expect(snapshot.todayTotalCount == 2)
        #expect(scoped.today.map(\.title) == ["Ava task"])
        #expect(scoped.todayTotalCount == 1)
        #expect(scoped.todayCompletedCount == 0)
    }

    @Test func completedStandaloneFamilyTaskCountsTodayWithoutReappearingAsPending() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let human = Human(name: "Ava")
        let completedAt = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 10)
        let task = FamilyCollaborationTask(
            title: "Take out recycling",
            kind: .householdTask,
            status: .completed,
            createdById: human.id.uuidString,
            createdByName: human.name,
            assignedToId: human.id.uuidString,
            assignedToName: human.name,
            dueAt: completedAt
        )
        task.completedAt = completedAt
        task.completedById = human.id.uuidString

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [human],
            plants: [],
            familyTasks: [task],
            activeHumanId: human.id.uuidString,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.pendingCount == 0)
        #expect(snapshot.todayTotalCount == 1)
        #expect(snapshot.todayCompletedCount == 1)
    }

    @Test func createFirstPetSystemJourneyIsStableUnscheduledAndIndependentOfMemberQueues() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let current = Human(name: "Ava")
        let other = Human(name: "Kai")

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [],
            humans: [current, other],
            plants: [],
            systemDestinations: [.createFirstPet],
            activeHumanId: current.id.uuidString,
            now: now,
            calendar: calendar
        )

        let item = try #require(snapshot.unscheduled.first)
        #expect(snapshot.allItems.count == 1)
        #expect(item.id == "system-journey-create-first-pet")
        #expect(item.source == .systemJourney)
        #expect(item.systemDestination == .createFirstPet)
        #expect(item.subject == .household)
        #expect(item.eventID == nil)
        #expect(item.reminderID == nil)
        #expect(item.familyTaskID == nil)
        #expect(item.dueAt == nil)
        #expect(item.availableActions.isEmpty)
        #expect(item.rewardCoconuts == 50)
        #expect(snapshot.filtered(for: .actionRequired).systemJourneyItems.map(\.id) == [item.id])
        #expect(snapshot.filtered(for: .waitingForFamily).systemJourneyItems.map(\.id) == [item.id])
        #expect(snapshot.memberFilterContext.actionRequiredItemIDs.isEmpty)
        #expect(snapshot.memberFilterContext.waitingForFamilyItemIDs.isEmpty)
        #expect(snapshot.filtered(for: TaskCenterMemberFilter.all).allItems.map(\.id) == [item.id])
        #expect(snapshot.memberFilterSummary == TaskCenterMemberFilterSummary(
            actionRequiredCount: 0,
            waitingForFamilyCount: 0,
            allCount: 1,
            systemJourneyCount: 1
        ))
        #expect(TaskCenterBadgeSnapshot(snapshot: snapshot).attentionCount == 1)
    }

    @Test func routeDataKeepsMemorialSchedulesStoredButExcludesTheirActiveTaskProjection() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = now.addingTimeInterval(-60)
        let event = Event(
            title: "Memorial future care",
            startDate: now.addingTimeInterval(3600),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        let task = FamilyCollaborationTask(
            title: event.title,
            kind: .careReminder,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            relatedPetId: pet.id.uuidString,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: human.id.uuidString,
            createdByName: human.name,
            assignedToId: human.id.uuidString,
            assignedToName: human.name,
            dueAt: event.startDate
        )
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let reference = try await TaskCenterRouteDataActor(modelContainer: container).load(
            loadPlants: false,
            activeHumanID: human.id.uuidString,
            now: now
        )

        #expect(!reference.eventModelIDs.contains(event.persistentModelID))
        #expect(!reference.reminderModelIDs.contains(reminder.persistentModelID))
        #expect(!reference.familyTaskModelIDs.contains(task.persistentModelID))
        #expect(allItems(reference.snapshot).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).contains { $0.id == event.id })
        #expect(try context.fetch(FetchDescriptor<Reminder>()).contains { $0.id == reminder.id })
    }

    @Test func createFirstPetSystemJourneyRequiresAnActiveHumanAndNoActivePet() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let human = Human(name: "Ava")
        let activePet = Pet(name: "Momo", species: "cat")
        let memorialPet = Pet(name: "Luna", species: "cat")
        memorialPet.passedAwayDate = now

        func snapshot(humans: [Human], pets: [Pet]) -> TaskCenterSnapshot {
            TaskCenterSnapshotBuilder.make(
                events: [],
                allEvents: [],
                pets: pets,
                humans: humans,
                plants: [],
                systemDestinations: [.createFirstPet],
                now: now,
                calendar: calendar
            )
        }

        #expect(snapshot(humans: [], pets: []).allItems.isEmpty)
        #expect(snapshot(humans: [human], pets: [activePet]).allItems.isEmpty)
        #expect(snapshot(humans: [human], pets: [memorialPet]).allItems.map(\.source) == [.systemJourney])
    }

    @Test func firstPetReplacesCreationJourneyWithUnscheduledGiftClaim() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat", breed: "布偶猫")

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [pet],
            humans: [human],
            plants: [],
            systemDestinations: [.createFirstPet, .claimStarterGift],
            activeHumanId: human.id.uuidString,
            now: now,
            calendar: calendar
        )

        let item = try #require(snapshot.unscheduled.first)
        #expect(snapshot.allItems.count == 1)
        #expect(item.id == "system-journey-claim-starter-gift")
        #expect(item.systemDestination == .claimStarterGift)
        #expect(item.rewardCoconuts == 50)
        #expect(item.dueAt == nil)
        #expect(snapshot.resolvedMemberFilter(explicitSelection: .actionRequired) == .all)
        #expect(snapshot.filtered(for: TaskCenterMemberFilter.all).allItems.map(\.id) == [item.id])
        #expect(snapshot.memberFilterSummary.systemJourneyCount == 1)
        #expect(TaskCenterBadgeSnapshot(snapshot: snapshot).attentionCount == 1)
    }

    @Test func badgeAttentionCountDeduplicatesTodayReviewAndIncludesSystemJourney() {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 13, hour: 12)
        let current = Human(name: "Ava")
        let other = Human(name: "Kai")
        let overdue = Event(
            title: "Overdue task",
            startDate: makeDate(calendar, year: 2026, month: 7, day: 12, hour: 10),
            eventType: EventType.task.rawValue
        )
        let review = FamilyCollaborationTask(
            title: "Review task",
            kind: .bounty,
            status: .pendingReview,
            createdById: current.id.uuidString,
            createdByName: current.name,
            assignedToId: other.id.uuidString,
            assignedToName: other.name,
            rewardCoconuts: 5,
            dueAt: makeDate(calendar, year: 2026, month: 7, day: 13, hour: 15)
        )

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [overdue],
            allEvents: [overdue],
            pets: [],
            humans: [current, other],
            plants: [],
            familyTasks: [review],
            systemDestinations: [.createFirstPet],
            activeHumanId: current.id.uuidString,
            now: now,
            calendar: calendar
        )
        let badge = TaskCenterBadgeSnapshot(snapshot: snapshot)

        #expect(snapshot.overdueCount == 1)
        #expect(snapshot.today.count == 1)
        #expect(snapshot.today.first?.workflowStatus == .pendingReview)
        #expect(snapshot.unscheduled.first?.source == .systemJourney)
        #expect(badge.overdueCount == 1)
        #expect(badge.attentionCount == 3)
    }

    @Test func starterJourneyProjectsAtMostThreeStableTypedItemsWithSummary() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 15, hour: 12)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat", breed: "Ragdoll")
        let states = HouseholdStarterJourneyTask.allCases.map { task in
            HouseholdStarterJourneyTaskState(
                task: task,
                status: task == .petProfile ? .claimable : .actionRequired,
                rewardCoconuts: task.rewardCoconuts,
                completedCheckpointCount: task == .petProfile ? 3 : 0,
                requiredCheckpointCount: HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task),
                targetID: task == .humanProfile ? human.id : pet.id,
                completedCheckpoints: [],
                checkpointResolutions: [:]
            )
        }
        let journey = HouseholdStarterJourneySnapshot(
            isEnabled: true,
            activeHumanID: human.id,
            taskStates: states,
            // The Task Center remains defensive even if a future producer
            // accidentally hands it a wider presentation frontier.
            visibleTaskStates: states
        )

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [pet],
            humans: [human],
            plants: [],
            starterJourney: journey,
            activeHumanId: human.id.uuidString,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.starterJourney == journey)
        #expect(snapshot.systemJourneyItems.count == 3)
        #expect(snapshot.ordinaryUnscheduledItems.isEmpty)
        #expect(Set(snapshot.systemJourneyItems.map(\.id)) == Set([
            HouseholdStarterJourneyTask.humanProfile.id,
            HouseholdStarterJourneyTask.petProfile.id,
            HouseholdStarterJourneyTask.identityProtection.id
        ]))
        let humanItem = try #require(snapshot.systemJourneyItems.first {
            $0.systemDestination == .completeHumanProfile
        })
        #expect(humanItem.subject.kind == .human)
        #expect(humanItem.subject.id == human.id)
        #expect(humanItem.rewardCoconuts == 100)
        #expect(humanItem.systemJourneyPresentationState == .actionRequired)
        let petItem = try #require(snapshot.systemJourneyItems.first {
            $0.systemDestination == .completeFirstPetProfile
        })
        #expect(petItem.subject.kind == .pet)
        #expect(petItem.subject.id == pet.id)
        #expect(petItem.rewardCoconuts == 100)
        #expect(petItem.systemJourneyPresentationState == .rewardReady)
        #expect(TaskCenterBadgeSnapshot(snapshot: snapshot).attentionCount == 3)
    }

    @Test func pendingStarterGiftSuppressesFourHundredCoconutJourneyFrontier() throws {
        let calendar = utcCalendar()
        let now = makeDate(calendar, year: 2026, month: 7, day: 15, hour: 12)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "dog", breed: "Mixed")
        let state = HouseholdStarterJourneyTaskState(
            task: .humanProfile,
            status: .actionRequired,
            rewardCoconuts: HouseholdStarterJourneyTask.humanProfile.rewardCoconuts,
            completedCheckpointCount: 0,
            requiredCheckpointCount: HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: .humanProfile),
            targetID: human.id,
            completedCheckpoints: [],
            checkpointResolutions: [:]
        )
        let journey = HouseholdStarterJourneySnapshot(
            isEnabled: true,
            activeHumanID: human.id,
            taskStates: [state],
            visibleTaskStates: [state]
        )

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: [],
            allEvents: [],
            pets: [pet],
            humans: [human],
            plants: [],
            systemDestinations: [.createFirstPet, .claimStarterGift],
            starterJourney: journey,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.systemJourneyItems.count == 1)
        let item = try #require(snapshot.systemJourneyItems.first)
        #expect(item.id == "system-journey-claim-starter-gift")
        #expect(item.systemDestination == .claimStarterGift)
        #expect(item.systemJourneyPresentationState == .rewardReady)
    }

    @Test func recurringBirthdayReminderDoesNotQualifyAsCarePlan() {
        let pet = Pet(name: "Momo", species: "cat", breed: "Ragdoll")
        let birthday = Event(
            title: "Momo birthday",
            eventType: EventType.birthday.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        birthday.recurrenceDays = 365

        let qualification = HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: [birthday],
            reminderEventIDs: [birthday.id]
        )

        #expect(!qualification.hasExplicitCarePlan)
        #expect(!qualification.hasDefaultRecommendedCarePlan)
    }

    @Test func typedReminderBackedRecurringPetCareEventQualifiesAsExplicitPlan() {
        let pet = Pet(name: "Momo", species: "cat", breed: "Ragdoll")
        let care = Event(
            title: "Momo evening care",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            taskCareKindRaw: TaskCareKind.petFeeding.rawValue
        )
        care.recurrenceDays = 1

        let qualification = HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: [care],
            reminderEventIDs: [care.id]
        )

        #expect(qualification.hasExplicitCarePlan)
        #expect(!qualification.hasDefaultRecommendedCarePlan)
    }

    @Test func genericDailyReminderDoesNotQualifyAsCarePlan() {
        let pet = Pet(name: "Momo", species: "cat", breed: "Ragdoll")
        let generic = Event(
            title: "Momo generic reminder",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        generic.recurrenceDays = 1

        let qualification = HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: pet,
            events: [generic],
            reminderEventIDs: [generic.id]
        )

        #expect(!qualification.hasExplicitCarePlan)
        #expect(!qualification.hasDefaultRecommendedCarePlan)
    }

    @Test func carePlanResolutionIsOfferedOnlyForAnExistingDefaultPlan() throws {
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "cat", breed: "Ragdoll")
        let noPlan = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: HouseholdStarterJourneyQualificationFacts(
                targetPetID: pet.id,
                hasProtectionDocument: false,
                hasInsurance: false,
                hasPreventiveHealthRecord: false,
                hasExplicitCarePlan: false,
                hasDefaultRecommendedCarePlan: false
            ),
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )
        let noPlanState = try #require(noPlan.state(for: .carePlan))
        #expect(noPlanState.availableResolutionCheckpoints.isEmpty)
        #expect(noPlan.state(for: .firstCare)?.targetID == pet.id)

        let recommendedPlan = HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: human.id.uuidString,
            humans: [human],
            pets: [pet],
            qualificationFacts: HouseholdStarterJourneyQualificationFacts(
                targetPetID: pet.id,
                hasProtectionDocument: false,
                hasInsurance: false,
                hasPreventiveHealthRecord: false,
                hasExplicitCarePlan: false,
                hasDefaultRecommendedCarePlan: true
            ),
            careLedgerEvents: [],
            coconutLedgerEntries: []
        )
        let recommendedState = try #require(recommendedPlan.state(for: .carePlan))
        #expect(recommendedState.availableResolutionCheckpoints == [.acceptedRecommendedCarePlan])
        #expect(recommendedState.status == .actionRequired)
    }

    private func allItems(_ snapshot: TaskCenterSnapshot) -> [TaskCenterItemSnapshot] {
        snapshot.overdue + snapshot.today + snapshot.upcoming + snapshot.unscheduled
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func assignedEvent(
        title: String,
        dueAt: Date,
        human: Human,
        pet: Pet
    ) -> Event {
        let event = Event(
            title: title,
            startDate: dueAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.assigneeId = human.id.uuidString
        return event
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(
        _ calendar: Calendar,
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )) ?? Date()
    }
}
