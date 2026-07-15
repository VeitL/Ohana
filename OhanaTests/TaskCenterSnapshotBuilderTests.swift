import Foundation
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
        #expect(workerView.resolvedMemberFilter(explicitSelection: nil) == .currentMember)
        #expect(workerView.resolvedMemberFilter(explicitSelection: .all) == .all)
        #expect(try #require(workerItems["Open chore"]).availableActions == [.claim])
        #expect(try #require(workerItems["Assigned bounty"]).availableActions == [.submitForReview])

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

    @Test func memberFiltersComposeWithObjectScopeAndKeepReviewSeparate() {
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
        let events = [currentFirst, otherFirst, currentSecond]

        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: [firstPet, secondPet],
            humans: [current, other],
            plants: [],
            familyTasks: [review],
            activeHumanId: current.id.uuidString,
            now: now,
            calendar: calendar
        )

        #expect(Set(snapshot.filtered(for: .currentMember).allItems.map(\.title)) == [
            "Momo care by Ava", "Luna care by Ava", "Review Kai task"
        ])
        #expect(snapshot.filtered(for: .waitingForOthers).allItems.map(\.title) == ["Momo care by Kai"])
        #expect(snapshot.filtered(for: .pendingReview).allItems.map(\.title) == ["Review Kai task"])

        let scopeThenMember = snapshot
            .filtered(for: .pet(firstPet.id))
            .filtered(for: .currentMember)
        let memberThenScope = snapshot
            .filtered(for: .currentMember)
            .filtered(for: .pet(firstPet.id))
        #expect(scopeThenMember.allItems.map(\.title) == ["Momo care by Ava"])
        #expect(memberThenScope.allItems.map(\.title) == scopeThenMember.allItems.map(\.title))
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

        #expect(avaSnapshot.resolvedMemberFilter(explicitSelection: nil) == .currentMember)
        #expect(avaSnapshot.filtered(for: .currentMember).allItems.map(\.title) == ["Ava assignment"])
        #expect(kaiSnapshot.filtered(for: .currentMember).allItems.map(\.title) == ["Kai assignment"])
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

    private func allItems(_ snapshot: TaskCenterSnapshot) -> [TaskCenterItemSnapshot] {
        snapshot.overdue + snapshot.today + snapshot.upcoming + snapshot.unscheduled
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
