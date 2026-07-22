import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct FamilyTaskV95CompatibilityTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func v94StoreMigratesToV95WithoutRewritingLegacyTaskFacts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaFamilyTaskV95Migration-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let taskID = UUID()
        let creatorID = UUID()
        let assigneeID = UUID()
        let completedAt = date(2026, 7, 20, 10)
        do {
            let schema = Schema(ArkSchemaV94.models)
            let configuration = ModelConfiguration(
                "FamilyTaskV94Source",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let task = FamilyCollaborationTask(
                id: taskID,
                title: "Legacy reviewed task",
                note: "Keep this text",
                kind: .bounty,
                status: .completed,
                createdById: creatorID.uuidString,
                createdByName: "Creator",
                assignedToId: assigneeID.uuidString,
                assignedToName: "Assignee",
                rewardCoconuts: 25,
                dueAt: date(2026, 7, 20, 9)
            )
            task.completedAt = completedAt
            task.completedById = assigneeID.uuidString
            task.completedByName = "Assignee"
            container.mainContext.insert(task)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV95.models)
            let configuration = ModelConfiguration(
                "FamilyTaskV95Target",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            let task = try #require(container.mainContext.fetch(FetchDescriptor<FamilyCollaborationTask>()).first)

            #expect(task.id == taskID)
            #expect(task.status == .completed)
            #expect(task.rewardCoconuts == 25)
            #expect(task.completedAt == completedAt)
            #expect(task.completedById == assigneeID.uuidString)
            #expect(task.planId == nil)
            #expect(task.occurrenceKey == nil)
            #expect(task.nominalAt == nil)
            #expect(task.scheduleVersion == 0)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<FamilyTaskPlan>()) == 0)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<FamilyTaskActivity>()) == 0)
        }
    }

    @Test func legacyUpgradePreservesThirtyCivilDayRuleAndReminderOccurrenceIdentity() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        let event = Event(
            title: "Legacy every 30 days",
            startDate: date(2026, 1, 1, 9),
            eventType: EventType.chore.rawValue
        )
        event.recurrenceDays = 30
        event.recurrenceEndDate = date(2026, 12, 31, 23, 59)
        let reminderOccurrence = date(2026, 1, 31, 9)
        let reminder = Reminder(
            event: event,
            scheduledAt: date(2026, 1, 31, 8),
            occurrenceAt: reminderOccurrence
        )
        event.reminders = [reminder]
        let taskID = UUID()
        let task = FamilyCollaborationTask(
            id: taskID,
            title: "Legacy every 30 days",
            note: "Original note",
            kind: .bounty,
            status: .pendingReview,
            relatedEventId: event.id.uuidString,
            relatedReminderId: reminder.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 30,
            dueAt: date(2026, 1, 31, 10)
        )
        context.insert(creator)
        context.insert(assignee)
        context.insert(event)
        context.insert(reminder)
        context.insert(task)
        try context.save()

        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let result = try await actor.upgradeLegacyRecurringTasks(now: date(2026, 2, 1))
        let replay = try await actor.upgradeLegacyRecurringTasks(now: date(2026, 2, 1))
        let plans = try context.fetch(FetchDescriptor<FamilyTaskPlan>())
        let upgradedTask = try #require(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).first)
        let upgradedEvent = try #require(try context.fetch(FetchDescriptor<Event>()).first)

        #expect(result.upgradedPlanCount == 1)
        #expect(result.adoptedTaskCount == 1)
        #expect(replay.upgradedPlanCount == 0)
        #expect(plans.count == 1)
        #expect(plans.first?.recurrenceRule == .everyNDays(30))
        #expect(upgradedTask.id == taskID)
        #expect(upgradedTask.status == .pendingReview)
        #expect(upgradedTask.rewardCoconuts == 30)
        #expect(upgradedTask.nominalAt == reminderOccurrence)
        #expect(upgradedTask.dueAt == date(2026, 1, 31, 10))
        #expect(upgradedTask.occurrenceKey?.contains(":v1:2026-01-31") == true)
        #expect(upgradedEvent.recurrenceDays == 0)
        #expect(upgradedEvent.recurrenceEndDate == nil)
        #expect(upgradedEvent.familyTaskPlanId == plans.first?.id.uuidString)
    }

    @Test func ambiguousLegacyGroupRemainsLegacyForExplicitFutureConversion() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        let event = Event(title: "Ambiguous legacy", startDate: date(2026, 1, 1, 9))
        event.recurrenceDays = 30
        let first = legacyTask(event: event, creator: creator, assignee: assignee, dueAt: date(2026, 1, 31, 9))
        let second = legacyTask(event: event, creator: creator, assignee: assignee, dueAt: date(2026, 1, 31, 18))
        context.insert(creator)
        context.insert(assignee)
        context.insert(event)
        context.insert(first)
        context.insert(second)
        try context.save()

        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let result = try await actor.upgradeLegacyRecurringTasks(now: date(2026, 2, 1))

        #expect(result.upgradedPlanCount == 0)
        #expect(result.retainedLegacyGroupCount == 1)
        #expect(try context.fetchCount(FetchDescriptor<FamilyTaskPlan>()) == 0)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).allSatisfy { $0.planId == nil })
        #expect(event.recurrenceDays == 30)
    }

    @Test func oneFamilyPlanConsumesOneQuotaSlotRegardlessOfDerivedRows() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        context.insert(creator)
        context.insert(assignee)
        try context.save()
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let result = try await actor.createPlan(
            FamilyTaskPlanDraft(
                title: "Daily quota task",
                creatorID: creator.id,
                assigneeID: assignee.id,
                recurrenceRule: .everyNDays(1),
                anchorAt: date(2026, 7, 22, 9),
                startsAt: date(2026, 7, 22),
                endsAt: date(2026, 7, 28, 23, 59),
                timeZoneIdentifier: utc.identifier
            ),
            now: date(2026, 7, 22, 8)
        )
        let usage = try PersonalUsageSnapshotReader.snapshot(context: context, now: date(2026, 7, 22, 8))
        let derivedEvents = try context.fetch(FetchDescriptor<Event>()).filter { $0.familyTaskPlanId != nil }

        #expect(result.insertedOccurrenceCount > 1)
        #expect(derivedEvents.count == result.insertedOccurrenceCount)
        #expect(usage.ordinaryActivePlanCount == 1)
        #expect(usage.healthCriticalActivePlanCount == 0)
    }

    private func legacyTask(
        event: Event,
        creator: Human,
        assignee: Human,
        dueAt: Date
    ) -> FamilyCollaborationTask {
        FamilyCollaborationTask(
            title: event.title,
            kind: .householdTask,
            relatedEventId: event.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            dueAt: dueAt
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV95.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(
            from: DateComponents(
                timeZone: utc,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
