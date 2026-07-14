import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct TodayFocusTaskProjectionTests {
    @Test func familyTaskProjectionOnlyKeepsOverdueTodayAndPendingReview() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let reviewer = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let overdue = task(
            title: "Overdue",
            creator: reviewer,
            assignee: worker,
            dueAt: now.addingTimeInterval(-86400)
        )
        let today = task(
            title: "Today",
            creator: reviewer,
            assignee: worker,
            dueAt: now.addingTimeInterval(3600)
        )
        let future = task(
            title: "Future",
            creator: reviewer,
            assignee: worker,
            dueAt: now.addingTimeInterval(3 * 86400)
        )
        let unscheduled = task(
            title: "Unscheduled",
            creator: reviewer,
            assignee: worker,
            dueAt: nil
        )
        let pendingReview = FamilyCollaborationTask(
            title: "Review",
            kind: .bounty,
            status: .pendingReview,
            createdById: reviewer.id.uuidString,
            createdByName: reviewer.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: future.dueAt
        )

        let workerSnapshot = snapshot(
            activeHuman: worker,
            humans: [reviewer, worker],
            tasks: [overdue, today, future, unscheduled, pendingReview],
            now: now
        )
        let reviewerSnapshot = snapshot(
            activeHuman: reviewer,
            humans: [reviewer, worker],
            tasks: [overdue, today, future, unscheduled, pendingReview],
            now: now
        )

        #expect(Set(workerSnapshot.assignedFamilyTasks.map(\.id)) == [
            "family-\(overdue.id.uuidString)",
            "family-\(today.id.uuidString)"
        ])
        #expect(reviewerSnapshot.assignedFamilyTasks.map(\.id) == [
            "family-\(pendingReview.id.uuidString)"
        ])
        #expect(workerSnapshot.assignedFamilyTasks.allSatisfy { $0.primaryAction != nil })
        #expect(reviewerSnapshot.assignedFamilyTasks.first?.primaryAction == .approve)
    }

    @Test func eventProjectionPreservesTaskCenterIdentityForRoutingAndActions() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let human = Human(name: "Owner")
        let overdueEvent = Event(
            title: "Water bowl",
            startDate: now.addingTimeInterval(-3600),
            eventType: EventType.task.rawValue
        )
        let futureEvent = Event(
            title: "Future task",
            startDate: now.addingTimeInterval(3 * 86400),
            eventType: EventType.task.rawValue
        )

        let unified = TaskCenterSnapshotBuilder.make(
            events: [overdueEvent, futureEvent],
            allEvents: [overdueEvent, futureEvent],
            pets: [],
            humans: [human],
            plants: [],
            activeHumanId: human.id.uuidString,
            now: now
        )
        let projected = snapshot(
            activeHuman: human,
            humans: [human],
            events: [overdueEvent, futureEvent],
            tasks: [],
            now: now
        )

        let unifiedItem = try #require(unified.allItems.first { $0.eventID == overdueEvent.id })
        let focusItem = try #require(projected.assignedFamilyTasks.first)
        #expect(projected.assignedFamilyTasks.count == 1)
        #expect(focusItem.id == unifiedItem.id)
        #expect(focusItem.taskCenterItem == unifiedItem)
        #expect(focusItem.primaryAction == .complete)

        let command = TaskActionCommand(item: focusItem.taskCenterItem, action: .complete)
        #expect(command.itemID == focusItem.id)
        #expect(command.eventID == overdueEvent.id)

        let route = TaskCenterRouteContext(
            scope: .all,
            focusedItemID: focusItem.id,
            focusRequestID: UUID()
        )
        #expect(route.focusedItemID == focusItem.id)
        #expect(route.focusRequestID != nil)
    }

    @Test func futureLinkedReviewKeepsTheFullTaskCenterIdentity() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let reviewer = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let futureEvent = Event(
            title: "Review plant care",
            startDate: now.addingTimeInterval(30 * 86400),
            eventType: EventType.task.rawValue
        )
        let reviewTask = FamilyCollaborationTask(
            title: futureEvent.title,
            kind: .bounty,
            status: .pendingReview,
            relatedEventId: futureEvent.id.uuidString,
            createdById: reviewer.id.uuidString,
            createdByName: reviewer.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: futureEvent.startDate
        )
        let unified = TaskCenterSnapshotBuilder.make(
            events: [futureEvent],
            allEvents: [futureEvent],
            pets: [],
            humans: [reviewer, worker],
            plants: [],
            familyTasks: [reviewTask],
            activeHumanId: reviewer.id.uuidString,
            now: now
        )
        let projected = snapshot(
            activeHuman: reviewer,
            humans: [reviewer, worker],
            events: [futureEvent],
            tasks: [reviewTask],
            now: now
        )

        let unifiedItem = try #require(unified.allItems.first { $0.familyTaskID == reviewTask.id })
        let focusItem = try #require(projected.assignedFamilyTasks.first)
        #expect(focusItem.id == unifiedItem.id)
        #expect(focusItem.taskCenterItem == unifiedItem)
        #expect(focusItem.primaryAction == .approve)
    }

    @Test func homeReadModelKeepsFutureLinkedReviewIdentityAlignedWithTaskCenter() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let reviewer = Human(name: "Parent")
        let worker = Human(name: "Kid")
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let futureEvent = Event(
            title: "Review plant care",
            startDate: futureDate,
            eventType: EventType.task.rawValue
        )
        let reviewTask = FamilyCollaborationTask(
            title: futureEvent.title,
            kind: .bounty,
            status: .pendingReview,
            relatedEventId: futureEvent.id.uuidString,
            createdById: reviewer.id.uuidString,
            createdByName: reviewer.name,
            assignedToId: worker.id.uuidString,
            assignedToName: worker.name,
            rewardCoconuts: 10,
            dueAt: futureDate
        )
        context.insert(reviewer)
        context.insert(worker)
        context.insert(futureEvent)
        context.insert(reviewTask)
        try context.save()

        let store = HomeReadModelStore()
        await store.refreshImmediately(
            context: context,
            activeHumanIdRaw: reviewer.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        let matchingProjectedItem = store.payload.snapshot.todayFocus.assignedFamilyTasks.first {
            $0.taskCenterItem.familyTaskID == reviewTask.id
        }
        let projectedItem = try #require(matchingProjectedItem)
        let unified = TaskCenterSnapshotBuilder.make(
            events: [futureEvent],
            allEvents: [futureEvent],
            pets: [],
            humans: [reviewer, worker],
            plants: [],
            familyTasks: [reviewTask],
            activeHumanId: reviewer.id.uuidString,
            now: now
        )
        let unifiedItem = try #require(unified.allItems.first { $0.familyTaskID == reviewTask.id })

        #expect(projectedItem.id == unifiedItem.id)
        #expect(projectedItem.taskCenterItem == unifiedItem)
        #expect(projectedItem.primaryAction == .approve)
    }

    @Test func todayFocusAndHumanDetailUseTheUnifiedTaskEntryPoints() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let homeActionSource = try String(
            contentsOf: root.appendingPathComponent("Ohana/Features/Home/Views/VerticalSolidHomeView+TodayFocus.swift"),
            encoding: .utf8
        )
        let routeSource = try String(
            contentsOf: root.appendingPathComponent("Ohana/Features/Tasks/TaskCenterRouteContainer.swift"),
            encoding: .utf8
        )
        let humanDetailSource = try String(
            contentsOf: root.appendingPathComponent("Ohana/Features/Members/Views/HumanDetailView+RemindersActions.swift"),
            encoding: .utf8
        )
        let appRouteSource = try String(
            contentsOf: root.appendingPathComponent("Ohana/App/RouteContainers/AppRouteDestinationContainers.swift"),
            encoding: .utf8
        )
        let deckSource = try String(
            contentsOf: root.appendingPathComponent("Ohana/Features/TodayFocus/Views/TodayFocusCard+Deck.swift"),
            encoding: .utf8
        )

        #expect(homeActionSource.contains("taskCenterFocusedItemID = task.id"))
        #expect(homeActionSource.contains("TaskActionCommandExecutor("))
        #expect(homeActionSource.contains("TaskActionCommand(item: item, action: action)"))
        #expect(routeSource.contains("routeContext.focusedItemID"))
        #expect(deckSource.contains("IslandQuestEngine.isOasisBuildQuest($0.id)"))
        #expect(humanDetailSource.contains("Button(action: onOpenTasks)"))
        #expect(humanDetailSource.contains("human-detail-open-tasks"))
        #expect(appRouteSource.contains("onPresentTaskCenter?(.human(id))"))
        #expect(!humanDetailSource.contains("ReminderCommandExecutor"))
        #expect(!humanDetailSource.contains("func completeReminder"))
        #expect(!humanDetailSource.contains("func skipReminder"))
    }

    private func task(
        title: String,
        creator: Human,
        assignee: Human,
        dueAt: Date?
    ) -> FamilyCollaborationTask {
        FamilyCollaborationTask(
            title: title,
            kind: .bounty,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 10,
            dueAt: dueAt
        )
    }

    private func snapshot(
        activeHuman: Human,
        humans: [Human],
        events: [Event] = [],
        tasks: [FamilyCollaborationTask],
        now: Date
    ) -> TodayFocusSnapshot {
        TodayFocusSnapshot.make(
            pets: [],
            plants: [],
            reminders: [],
            events: events,
            humans: humans,
            activeHumanId: activeHuman.id.uuidString,
            careLedgerEntries: [],
            humanWeightLogs: [],
            familyTasks: tasks,
            exchangeRequests: [],
            questProgress: TodayFocusQuestProgress(
                isPetWizardCompleted: true,
                isFirstMealRecorded: true,
                isThemeColorSet: true
            ),
            clinicalAlerts: [],
            now: now
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV90.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
