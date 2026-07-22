import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct FamilyTaskPlanMaterializationTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func repeatedMaterializationIsIdempotentForTasksAndEvents() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container, creatorBalance: 100)
        let now = date(2026, 7, 22, 12)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let first = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creatorID,
                assigneeID: members.assigneeID,
                reward: 0,
                anchorAt: date(2026, 7, 22, 9),
                endsAt: date(2026, 7, 24, 23, 59)
            ),
            now: now
        )
        let planID = try #require(first.planID)

        let replay = try await actor.materialize(planID: planID, now: now)
        let context = ModelContext(container)
        let tasks = try tasks(planID: planID, context: context)
        let events = try events(planID: planID, context: context)

        #expect(first.insertedOccurrenceCount == 3)
        #expect(replay.insertedOccurrenceCount == 0)
        #expect(replay.skippedExistingCount == 3)
        #expect(tasks.count == 3)
        #expect(events.count == 3)
        #expect(Set(tasks.compactMap(\.occurrenceKey)).count == 3)
        #expect(Set(events.compactMap(\.familyTaskOccurrenceKey)) == Set(tasks.compactMap(\.occurrenceKey)))
    }

    @Test func postponingOccurrenceKeepsNominalIdentityAndDoesNotRematerializeIt() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container, creatorBalance: 0)
        let now = date(2026, 7, 22, 12)
        let anchor = date(2026, 7, 23, 9)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let created = try await actor.createPlan(
            FamilyTaskPlanDraft(
                title: "Water plants",
                creatorID: members.creatorID,
                assigneeID: members.assigneeID,
                recurrenceRule: .once,
                anchorAt: anchor,
                startsAt: date(2026, 7, 23),
                endsAt: date(2026, 7, 23, 23, 59),
                timeZoneIdentifier: utc.identifier
            ),
            now: now
        )
        let planID = try #require(created.planID)
        let context = ModelContext(container)
        let task = try #require(try tasks(planID: planID, context: context).first)
        let assignee = try human(id: members.assigneeID, context: context)
        let originalKey = try #require(task.occurrenceKey)
        let originalNominalAt = try #require(task.nominalAt)
        let newDueAt = date(2026, 7, 24, 10)

        let postponed = FamilyTaskService.postponeOccurrence(
            task,
            to: newDueAt,
            by: assignee,
            context: context,
            now: now
        )
        let replay = try await actor.materialize(planID: planID, now: now)
        let linkedEvent = try event(id: task.relatedEventId, context: context)

        #expect(postponed)
        #expect(task.dueAt == newDueAt)
        #expect(task.nominalAt == originalNominalAt)
        #expect(task.occurrenceKey == originalKey)
        #expect(linkedEvent.startDate == newDueAt)
        #expect(linkedEvent.familyTaskOccurrenceKey == originalKey)
        #expect(replay.insertedOccurrenceCount == 0)
        #expect(try tasks(planID: planID, context: context).count == 1)
    }

    @Test func noReminderOccurrenceCompletionAndRedoKeepLinkedEventInSync() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container, creatorBalance: 30)
        let now = date(2026, 7, 22, 8)
        let anchor = date(2026, 7, 23, 9)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let created = try await actor.createPlan(
            FamilyTaskPlanDraft(
                title: "Review kitchen duty",
                creatorID: members.creatorID,
                assigneeID: members.assigneeID,
                rewardCoconuts: 10,
                recurrenceRule: .once,
                anchorAt: anchor,
                startsAt: startOfDay(anchor),
                endsAt: date(2026, 7, 23, 23, 59),
                timeZoneIdentifier: utc.identifier,
                reminderLeadMinutes: nil
            ),
            now: now
        )
        let planID = try #require(created.planID)
        let context = ModelContext(container)
        let task = try #require(try tasks(planID: planID, context: context).first)
        let event = try event(id: task.relatedEventId, context: context)
        let creator = try human(id: members.creatorID, context: context)
        let assignee = try human(id: members.assigneeID, context: context)

        #expect(task.relatedReminderId == nil)
        #expect(!event.isCompleted)
        #expect(FamilyTaskService.complete(task, by: assignee, context: context))
        #expect(task.status == .pendingReview)
        #expect(event.isCompleted)

        #expect(FamilyTaskService.rejectCompletion(task, by: creator, context: context))
        #expect(task.status == .active)
        #expect(!event.isCompleted)
    }

    @Test func separatePlansOnTheSameCivilDayRemainSeparateInstances() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container, creatorBalance: 0)
        let now = date(2026, 7, 22, 8)
        let anchor = date(2026, 7, 23, 9)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let draft = FamilyTaskPlanDraft(
            title: "Same title",
            creatorID: members.creatorID,
            assigneeID: members.assigneeID,
            recurrenceRule: .once,
            anchorAt: anchor,
            startsAt: date(2026, 7, 23),
            endsAt: date(2026, 7, 23, 23, 59),
            timeZoneIdentifier: utc.identifier
        )

        let first = try await actor.createPlan(draft, now: now)
        let second = try await actor.createPlan(draft, now: now)
        let firstPlanID = try #require(first.planID)
        let secondPlanID = try #require(second.planID)
        let context = ModelContext(container)
        let allTasks = try context.fetch(FetchDescriptor<FamilyCollaborationTask>())
            .filter { $0.planId == firstPlanID.uuidString || $0.planId == secondPlanID.uuidString }
        let allEvents = try context.fetch(FetchDescriptor<Event>())
            .filter { $0.familyTaskPlanId == firstPlanID.uuidString || $0.familyTaskPlanId == secondPlanID.uuidString }

        #expect(firstPlanID != secondPlanID)
        #expect(allTasks.count == 2)
        #expect(allEvents.count == 2)
        #expect(Set(allTasks.map(\.id)).count == 2)
        #expect(Set(allTasks.compactMap(\.planId)).count == 2)
        #expect(Set(allTasks.compactMap(\.occurrenceKey)).count == 2)
        #expect(Set(allTasks.compactMap(\.nominalAt)).count == 1)
    }

    @Test func everyMaterializedOccurrenceCanTransferItsOwnReward() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container, creatorBalance: 100)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let result = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creatorID,
                assigneeID: members.assigneeID,
                reward: 30,
                anchorAt: date(2026, 7, 22, 9),
                endsAt: date(2026, 7, 23, 23, 59)
            ),
            now: date(2026, 7, 22, 8)
        )
        let planID = try #require(result.planID)
        let context = ModelContext(container)
        let creator = try human(id: members.creatorID, context: context)
        let assignee = try human(id: members.assigneeID, context: context)
        let occurrences = try tasks(planID: planID, context: context)
        #expect(occurrences.count == 2)

        for task in occurrences {
            #expect(FamilyTaskService.complete(task, by: assignee, context: context))
            #expect(task.status == .pendingReview)
            #expect(FamilyTaskService.confirmCompletion(task, by: creator, context: context))
            #expect(task.status == .completed)
        }

        let taskIDs = Set(occurrences.map(\.id.uuidString))
        let rewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .familyTask && taskIDs.contains($0.sourceModelId) }

        #expect(CoconutWalletService.balance(for: creator, context: context) == 40)
        #expect(CoconutWalletService.balance(for: assignee, context: context) == 60)
        #expect(rewardEntries.count == 4)
        #expect(Set(rewardEntries.map(\.transactionKey)).count == 4)
        #expect(Set(rewardEntries.map(\.sourceModelId)) == taskIDs)
    }

    @Test func insufficientBalanceForLaterOccurrenceLeavesNoHalfTransfer() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container, creatorBalance: 30)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let result = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creatorID,
                assigneeID: members.assigneeID,
                reward: 30,
                anchorAt: date(2026, 7, 22, 9),
                endsAt: date(2026, 7, 23, 23, 59)
            ),
            now: date(2026, 7, 22, 8)
        )
        let planID = try #require(result.planID)
        let context = ModelContext(container)
        let creator = try human(id: members.creatorID, context: context)
        let assignee = try human(id: members.assigneeID, context: context)
        let occurrences = try tasks(planID: planID, context: context)
        let first = try #require(occurrences.first)
        let second = try #require(occurrences.dropFirst().first)

        #expect(FamilyTaskService.complete(first, by: assignee, context: context))
        #expect(FamilyTaskService.confirmCompletion(first, by: creator, context: context))
        #expect(FamilyTaskService.complete(second, by: assignee, context: context))
        #expect(!FamilyTaskService.confirmCompletion(second, by: creator, context: context))

        let rewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .familyTask }
        let rewardLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
            .filter { $0.metadataJSON.hasPrefix("familyTaskRewardTransfer:") }
        let persistedSecond = try #require(try tasks(planID: planID, context: context).first { $0.id == second.id })

        #expect(first.status == .completed)
        #expect(persistedSecond.status == .pendingReview)
        #expect(CoconutWalletService.balance(for: creator, context: context) == 0)
        #expect(CoconutWalletService.balance(for: assignee, context: context) == 30)
        #expect(rewardEntries.count == 2)
        #expect(rewardEntries.allSatisfy { $0.sourceModelId == first.id.uuidString })
        #expect(rewardLedgerEvents.count == 2)
        #expect(rewardLedgerEvents.allSatisfy { $0.metadataJSON.contains(first.id.uuidString) })
    }

    @Test func v95RegistersOnlyPlanAndActivityAndKeepsLegacyProvenanceNullable() throws {
        let v94 = Set(ArkSchemaV94.models.map { String(describing: $0) })
        let v95 = Set(ArkSchemaV95.models.map { String(describing: $0) })

        #expect(v95.subtracting(v94) == [
            String(describing: FamilyTaskPlan.self),
            String(describing: FamilyTaskActivity.self)
        ])
        #expect(v94.subtracting(v95).isEmpty)
        #expect(ObjectIdentifier(ArkMigrationPlan.schemas.last!) == ObjectIdentifier(ArkSchemaV96.self))
        #expect(ArkMigrationPlan.stages.isEmpty)

        let container = try makeContainer()
        let context = container.mainContext
        let firstLegacyTask = FamilyCollaborationTask(
            title: "Legacy one",
            kind: .householdTask,
            createdById: UUID().uuidString,
            createdByName: "Creator"
        )
        let secondLegacyTask = FamilyCollaborationTask(
            title: "Legacy two",
            kind: .householdTask,
            createdById: UUID().uuidString,
            createdByName: "Creator"
        )
        let legacyEvent = Event(title: "Legacy event")
        context.insert(firstLegacyTask)
        context.insert(secondLegacyTask)
        context.insert(legacyEvent)
        try context.save()

        #expect(firstLegacyTask.planId == nil)
        #expect(firstLegacyTask.occurrenceKey == nil)
        #expect(firstLegacyTask.nominalAt == nil)
        #expect(firstLegacyTask.scheduleVersion == 0)
        #expect(secondLegacyTask.occurrenceKey == nil)
        #expect(legacyEvent.familyTaskPlanId == nil)
        #expect(legacyEvent.familyTaskOccurrenceKey == nil)
        #expect(try context.fetchCount(FetchDescriptor<FamilyCollaborationTask>()) == 2)
    }

    private func dailyDraft(
        creatorID: UUID,
        assigneeID: UUID,
        reward: Int,
        anchorAt: Date,
        endsAt: Date
    ) -> FamilyTaskPlanDraft {
        FamilyTaskPlanDraft(
            title: "Daily family task",
            creatorID: creatorID,
            assigneeID: assigneeID,
            rewardCoconuts: reward,
            recurrenceRule: .everyNDays(1),
            anchorAt: anchorAt,
            startsAt: startOfDay(anchorAt),
            endsAt: endsAt,
            timeZoneIdentifier: utc.identifier
        )
    }

    private func seedMembers(
        in container: ModelContainer,
        creatorBalance: Int
    ) throws -> (creatorID: UUID, assigneeID: UUID) {
        let context = container.mainContext
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        creator.coconutBalance = creatorBalance
        context.insert(creator)
        context.insert(assignee)
        try context.save()
        return (creator.id, assignee.id)
    }

    private func tasks(
        planID: UUID,
        context: ModelContext
    ) throws -> [FamilyCollaborationTask] {
        let rawPlanID = planID.uuidString
        return try context.fetch(
            FetchDescriptor<FamilyCollaborationTask>(
                predicate: #Predicate<FamilyCollaborationTask> { $0.planId == rawPlanID }
            )
        ).sorted {
            ($0.nominalAt ?? .distantPast) < ($1.nominalAt ?? .distantPast)
        }
    }

    private func events(
        planID: UUID,
        context: ModelContext
    ) throws -> [Event] {
        let rawPlanID = planID.uuidString
        return try context.fetch(
            FetchDescriptor<Event>(
                predicate: #Predicate<Event> { $0.familyTaskPlanId == rawPlanID }
            )
        )
    }

    private func human(id: UUID, context: ModelContext) throws -> Human {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try #require(try context.fetch(descriptor).first)
    }

    private func event(id rawID: String?, context: ModelContext) throws -> Event {
        let id = try #require(rawID.flatMap(UUID.init(uuidString:)))
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return try #require(try context.fetch(descriptor).first)
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

    private func startOfDay(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.startOfDay(for: date)
    }
}
