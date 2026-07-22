import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct FamilyTaskPlanSeriesTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func omittedStartBeginsWithFirstMatchingOccurrenceAfterCreation() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let createdAt = date(2026, 7, 22, 12)
        let created = try await actor.createPlan(
            FamilyTaskPlanDraft(
                title: "Starts after creation",
                creatorID: members.creator.id,
                assigneeID: members.assignee.id,
                recurrenceRule: .everyNDays(1),
                anchorAt: date(2026, 7, 22, 9),
                startsAt: nil,
                endsAt: date(2026, 7, 24, 23, 59),
                timeZoneIdentifier: utc.identifier
            ),
            now: createdAt
        )
        let planID = try #require(created.planID)
        let context = ModelContext(container)
        let occurrences = try tasks(planID: planID, context: context)

        #expect(occurrences.count == 2)
        #expect(occurrences.allSatisfy { ($0.nominalAt ?? .distantPast) > createdAt })
        #expect(occurrences.first?.nominalAt == date(2026, 7, 23, 9))
    }

    @Test func editingThisAndFutureVersionsTheScheduleAndPreservesCompletedHistory() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let created = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creator.id,
                assigneeID: members.assignee.id,
                anchorAt: date(2026, 7, 22, 9),
                endsAt: date(2026, 7, 25, 23, 59)
            ),
            now: date(2026, 7, 22, 8)
        )
        let planID = try #require(created.planID)
        let context = ModelContext(container)
        let creator = try human(id: members.creator.id, context: context)
        let assignee = try human(id: members.assignee.id, context: context)
        let original = try tasks(planID: planID, context: context)
        let completed = try #require(original.first)
        let cutoff = try #require(original.dropFirst().first?.nominalAt)

        #expect(FamilyTaskService.complete(completed, by: assignee, context: context))
        #expect(completed.status == .completed)

        let result = try await actor.updateThisAndFuture(
            planID: planID,
            from: cutoff,
            draft: FamilyTaskPlanDraft(
                title: "Every other day",
                creatorID: creator.id,
                assigneeID: assignee.id,
                recurrenceRule: .everyNDays(2),
                anchorAt: cutoff,
                startsAt: cutoff,
                endsAt: date(2026, 7, 28, 23, 59),
                timeZoneIdentifier: utc.identifier,
                expectedScheduleVersion: 1
            ),
            editorID: creator.id,
            now: date(2026, 7, 22, 12)
        )

        let plan = try #require(try plan(id: planID, context: context))
        let allTasks = try tasks(planID: planID, context: context)
        let oldFuture = allTasks.filter { $0.scheduleVersion == 1 && ($0.nominalAt ?? .distantPast) >= cutoff }
        let newFuture = allTasks.filter { $0.scheduleVersion == 2 }
        let editActivities = try context.fetch(FetchDescriptor<FamilyTaskActivity>()).filter {
            $0.planId == planID.uuidString && $0.kind == .edited
        }

        #expect(plan.scheduleVersion == 2)
        #expect(plan.recurrenceRule == .everyNDays(2))
        #expect(completed.status == .completed)
        #expect(completed.scheduleVersion == 1)
        #expect(oldFuture.count == result.cancelledOccurrenceCount)
        #expect(oldFuture.allSatisfy { $0.status == .cancelled })
        #expect(!newFuture.isEmpty)
        #expect(newFuture.allSatisfy { $0.status == .active })
        #expect(newFuture.allSatisfy { $0.occurrenceKey?.contains(":v2:") == true })
        #expect(editActivities.count == 1)
        #expect(editActivities.first?.recipientHumanId == assignee.id.uuidString)
    }

    @Test func cancellingThisAndFutureKeepsCompletedOccurrenceImmutable() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let created = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creator.id,
                assigneeID: members.assignee.id,
                anchorAt: date(2026, 7, 22, 9),
                endsAt: date(2026, 7, 24, 23, 59)
            ),
            now: date(2026, 7, 22, 8)
        )
        let planID = try #require(created.planID)
        let context = ModelContext(container)
        let creator = try human(id: members.creator.id, context: context)
        let assignee = try human(id: members.assignee.id, context: context)
        let original = try tasks(planID: planID, context: context)
        let completed = try #require(original.first)
        let cutoff = try #require(completed.nominalAt)
        #expect(FamilyTaskService.complete(completed, by: assignee, context: context))

        let result = try await actor.cancelThisAndFuture(
            planID: planID,
            from: cutoff,
            editorID: creator.id,
            now: date(2026, 7, 22, 12)
        )

        let plan = try #require(try plan(id: planID, context: context))
        let allTasks = try tasks(planID: planID, context: context)
        let cancellationActivities = try context.fetch(FetchDescriptor<FamilyTaskActivity>()).filter {
            $0.planId == planID.uuidString && $0.kind == .cancelled
        }

        #expect(plan.status == .cancelled)
        #expect(completed.status == .completed)
        #expect(result.cancelledOccurrenceCount == allTasks.count - 1)
        #expect(allTasks.filter { $0.id != completed.id }.allSatisfy { $0.status == .cancelled })
        #expect(cancellationActivities.count == 1)
        await #expect(throws: FamilyTaskPlanCommandError.planUnavailable) {
            try await actor.materialize(planID: planID, now: date(2026, 7, 23, 8))
        }
    }

    @Test func postponingOntoNextNominalDayKeepsTwoIndependentOccurrences() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let created = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creator.id,
                assigneeID: members.assignee.id,
                anchorAt: date(2026, 7, 22, 9),
                endsAt: date(2026, 7, 23, 23, 59)
            ),
            now: date(2026, 7, 22, 8)
        )
        let planID = try #require(created.planID)
        let context = ModelContext(container)
        let assignee = try human(id: members.assignee.id, context: context)
        let before = try tasks(planID: planID, context: context)
        let first = try #require(before.first)
        let second = try #require(before.dropFirst().first)
        let secondNominal = try #require(second.nominalAt)

        #expect(FamilyTaskService.postponeOccurrence(
            first,
            to: secondNominal,
            by: assignee,
            context: context,
            now: date(2026, 7, 22, 8)
        ))
        let replay = try await actor.materialize(planID: planID, now: date(2026, 7, 22, 8))
        let after = try tasks(planID: planID, context: context)

        #expect(replay.insertedOccurrenceCount == 0)
        #expect(after.count == 2)
        #expect(after.map(\.dueAt) == [secondNominal, secondNominal])
        #expect(Set(after.compactMap(\.occurrenceKey)).count == 2)
        #expect(Set(after.compactMap(\.nominalAt)).count == 2)
    }

    @Test func longInactivityCreatesOneIdempotentMissedSummary() async throws {
        let container = try makeContainer()
        let members = try seedMembers(in: container)
        let actor = FamilyTaskPlanMaterializationActor(modelContainer: container)
        let created = try await actor.createPlan(
            dailyDraft(
                creatorID: members.creator.id,
                assigneeID: members.assignee.id,
                anchorAt: date(2026, 1, 1, 9),
                endsAt: nil
            ),
            now: date(2026, 1, 1, 8)
        )
        let planID = try #require(created.planID)

        let firstCatchUp = try await actor.materialize(planID: planID, now: date(2026, 3, 1, 8))
        let replay = try await actor.materialize(planID: planID, now: date(2026, 3, 1, 8))
        let context = ModelContext(container)
        let summaries = try context.fetch(FetchDescriptor<FamilyTaskActivity>()).filter {
            $0.planId == planID.uuidString && $0.kind == .missedSummary
        }
        #expect(firstCatchUp.summarizedMissedCount > 0)
        #expect(firstCatchUp.insertedOccurrenceCount <= FamilyTaskPlanMaterializationActor.maximumOccurrencesPerPlan)
        #expect(replay.summarizedMissedCount == 0)
        #expect(summaries.count == 1)
        #expect(summaries.first?.countValue == firstCatchUp.summarizedMissedCount)
    }

    private func dailyDraft(
        creatorID: UUID,
        assigneeID: UUID,
        anchorAt: Date,
        endsAt: Date?
    ) -> FamilyTaskPlanDraft {
        FamilyTaskPlanDraft(
            title: "Daily family task",
            creatorID: creatorID,
            assigneeID: assigneeID,
            recurrenceRule: .everyNDays(1),
            anchorAt: anchorAt,
            startsAt: startOfDay(anchorAt),
            endsAt: endsAt,
            timeZoneIdentifier: utc.identifier
        )
    }

    private func seedMembers(in container: ModelContainer) throws -> (creator: Human, assignee: Human) {
        let context = container.mainContext
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        context.insert(creator)
        context.insert(assignee)
        try context.save()
        return (creator, assignee)
    }

    private func tasks(planID: UUID, context: ModelContext) throws -> [FamilyCollaborationTask] {
        let rawPlanID = planID.uuidString
        return try context.fetch(
            FetchDescriptor<FamilyCollaborationTask>(
                predicate: #Predicate<FamilyCollaborationTask> { $0.planId == rawPlanID },
                sortBy: [SortDescriptor(\.nominalAt), SortDescriptor(\.id)]
            )
        )
    }

    private func plan(id: UUID, context: ModelContext) throws -> FamilyTaskPlan? {
        var descriptor = FetchDescriptor<FamilyTaskPlan>(
            predicate: #Predicate<FamilyTaskPlan> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func human(id: UUID, context: ModelContext) throws -> Human {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try #require(context.fetch(descriptor).first)
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
