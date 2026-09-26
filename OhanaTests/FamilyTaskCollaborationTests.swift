import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct FamilyTaskCollaborationTests {
    @Test func recurringCancellationPresentationRequiresExplicitScopeAndConfirmation() {
        let recurringPending = FamilyTaskCancellationPresentationPolicy.resolve(
            allowsThisAndFuture: true,
            status: .pendingReview
        )
        #expect(recurringPending.availableScopes == [.onlyThis, .thisAndFuture])
        #expect(recurringPending.requiresDestructiveConfirmation)
        #expect(recurringPending.showsPendingReviewWarning)

        let oneOffActive = FamilyTaskCancellationPresentationPolicy.resolve(
            allowsThisAndFuture: false,
            status: .active
        )
        #expect(oneOffActive.availableScopes == [.onlyThis])
        #expect(oneOffActive.requiresDestructiveConfirmation)
        #expect(!oneOffActive.showsPendingReviewWarning)
    }

    @Test func occurrenceTimelineIsTaskScopedNewestFirstAndBounded() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let taskID = UUID()
        let otherTaskID = UUID()
        let recipientID = UUID()
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        for offset in 0 ..< 105 {
            context.insert(FamilyTaskActivity(
                taskId: taskID.uuidString,
                kind: .commented,
                actorHumanId: UUID().uuidString,
                actorHumanName: "Member",
                recipientHumanId: recipientID.uuidString,
                taskTitleSnapshot: "Kitchen duty",
                idempotencyKey: "timeline-\(offset)",
                createdAt: start.addingTimeInterval(Double(offset))
            ))
        }
        context.insert(FamilyTaskActivity(
            taskId: otherTaskID.uuidString,
            kind: .commented,
            actorHumanId: UUID().uuidString,
            actorHumanName: "Member",
            recipientHumanId: recipientID.uuidString,
            taskTitleSnapshot: "Other task",
            idempotencyKey: "timeline-other",
            createdAt: start.addingTimeInterval(1000)
        ))
        try context.save()

        let timeline = FamilyTaskActivityService.occurrenceTimeline(
            taskID: taskID,
            context: context
        )

        #expect(timeline.count == FamilyTaskActivityService.defaultOccurrenceTimelineLimit)
        #expect(timeline.first?.createdAt == start.addingTimeInterval(104))
        #expect(timeline.last?.createdAt == start.addingTimeInterval(5))
        #expect(timeline.allSatisfy { $0.taskID == taskID })
    }

    @Test func capabilitiesAreRoleAndStateScoped() {
        let creatorID = UUID()
        let assigneeID = UUID()
        let outsiderID = UUID()
        let task = makeTask(
            creatorID: creatorID,
            assigneeID: assigneeID,
            reward: 10,
            dueAt: Date(timeIntervalSince1970: 2_000_000_000)
        )

        let creator = FamilyTaskCapabilities.resolve(task: task, currentHumanID: creatorID)
        #expect(creator.canEdit)
        #expect(creator.canCancel)
        #expect(!creator.canDecline)
        #expect(!creator.canComplete)
        #expect(!creator.canPostpone)
        #expect(!creator.canComment)
        #expect(!creator.canApprove)
        #expect(!creator.canReturnForRedo)

        let assignee = FamilyTaskCapabilities.resolve(task: task, currentHumanID: assigneeID)
        #expect(!assignee.canEdit)
        #expect(!assignee.canCancel)
        #expect(assignee.canDecline)
        #expect(assignee.canComplete)
        #expect(assignee.canPostpone)
        #expect(assignee.canComment)
        #expect(!assignee.canApprove)
        #expect(!assignee.canReturnForRedo)

        #expect(FamilyTaskCapabilities.resolve(task: task, currentHumanID: outsiderID) == .readOnly)
        #expect(FamilyTaskCapabilities.resolve(task: task, currentHumanID: nil) == .readOnly)

        task.status = .pendingReview
        let pendingCreator = FamilyTaskCapabilities.resolve(task: task, currentHumanID: creatorID)
        let pendingAssignee = FamilyTaskCapabilities.resolve(task: task, currentHumanID: assigneeID)
        #expect(pendingCreator.canEdit)
        #expect(pendingCreator.canCancel)
        #expect(pendingCreator.canApprove)
        #expect(pendingCreator.canReturnForRedo)
        #expect(!pendingCreator.canComplete)
        #expect(!pendingAssignee.canEdit)
        #expect(!pendingAssignee.canComplete)
        #expect(pendingAssignee.canComment)

        task.status = .declined
        let declinedCreator = FamilyTaskCapabilities.resolve(task: task, currentHumanID: creatorID)
        #expect(declinedCreator.canEdit)
        #expect(declinedCreator.canCancel)
        #expect(!declinedCreator.canApprove)
        #expect(FamilyTaskCapabilities.resolve(task: task, currentHumanID: assigneeID) == .readOnly)

        task.status = .completed
        #expect(FamilyTaskCapabilities.resolve(task: task, currentHumanID: creatorID) == .readOnly)
        #expect(FamilyTaskCapabilities.resolve(task: task, currentHumanID: assigneeID) == .readOnly)
    }

    @Test func performerActionsCreateExactlyOneCreatorActivityAndNoEconomyFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let members = try seedMembers(in: context, creatorBalance: 100)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let originalDueAt = now.addingTimeInterval(86400)
        let postponedDueAt = originalDueAt.addingTimeInterval(86400)
        let declinedTask = makeTask(
            title: "Decline me",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            dueAt: originalDueAt
        )
        let postponedTask = makeTask(
            title: "Postpone me",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            dueAt: originalDueAt
        )
        let commentedTask = makeTask(
            title: "Comment me",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            dueAt: originalDueAt
        )
        context.insert(declinedTask)
        context.insert(postponedTask)
        context.insert(commentedTask)
        try context.save()

        #expect(FamilyTaskService.declineAssignment(
            declinedTask,
            by: members.assignee,
            reason: "  Cannot do this one  ",
            context: context
        ))
        #expect(!FamilyTaskService.declineAssignment(
            declinedTask,
            by: members.assignee,
            reason: "retry",
            context: context
        ))
        #expect(FamilyTaskService.postponeOccurrence(
            postponedTask,
            to: postponedDueAt,
            by: members.assignee,
            context: context,
            now: now
        ))
        #expect(!FamilyTaskService.postponeOccurrence(
            postponedTask,
            to: postponedDueAt,
            by: members.assignee,
            context: context,
            now: now
        ))
        let commentKey = "test-comment:\(commentedTask.id.uuidString)"
        #expect(FamilyTaskService.addComment(
            commentedTask,
            body: "  Please use the side door.  ",
            by: members.assignee,
            idempotencyKey: commentKey,
            context: context
        ))
        #expect(!FamilyTaskService.addComment(
            commentedTask,
            body: "duplicate",
            by: members.assignee,
            idempotencyKey: commentKey,
            context: context
        ))

        let activities = FamilyTaskActivityService.inbox(
            recipientHumanID: members.creator.id,
            context: context
        )
        let byKind = Dictionary(grouping: activities, by: \FamilyTaskActivitySnapshot.kind)

        #expect(declinedTask.status == .declined)
        #expect(postponedTask.status == .active)
        #expect(postponedTask.dueAt == postponedDueAt)
        #expect(commentedTask.status == .active)
        #expect(activities.count == 3)
        #expect(byKind[.declined]?.count == 1)
        #expect(byKind[.postponed]?.count == 1)
        #expect(byKind[.commented]?.count == 1)
        #expect(byKind[.declined]?.first?.body == "Cannot do this one")
        #expect(byKind[.postponed]?.first?.oldDueAt == originalDueAt)
        #expect(byKind[.postponed]?.first?.newDueAt == postponedDueAt)
        #expect(byKind[.commented]?.first?.body == "Please use the side door.")
        #expect(activities.allSatisfy { $0.actorHumanID == members.assignee.id })
        #expect(activities.allSatisfy { $0.recipientHumanID == members.creator.id })
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 0)
    }

    @Test func activityInboxIsRecipientScopedIdempotentAndReadOneAtATime() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let creatorID = UUID()
        let assigneeID = UUID()
        let planID = UUID()
        let taskID = UUID()
        let firstCreatedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let secondCreatedAt = firstCreatedAt.addingTimeInterval(1)

        #expect(FamilyTaskActivityService.stage(
            kind: .commented,
            planID: planID.uuidString,
            taskID: taskID.uuidString,
            occurrenceKey: "v1:2026-07-22",
            actorHumanID: assigneeID.uuidString,
            actorHumanName: "Assignee",
            recipientHumanID: creatorID.uuidString,
            taskTitle: "Water plants",
            body: "First note",
            idempotencyKey: "activity:first",
            createdAt: firstCreatedAt,
            context: context
        ))
        #expect(FamilyTaskActivityService.stage(
            kind: .postponed,
            actorHumanID: assigneeID.uuidString,
            actorHumanName: "Assignee",
            recipientHumanID: creatorID.uuidString,
            taskTitle: "Water plants",
            idempotencyKey: "activity:second",
            createdAt: secondCreatedAt,
            context: context
        ))
        #expect(FamilyTaskActivityService.stage(
            kind: .assigned,
            actorHumanID: creatorID.uuidString,
            actorHumanName: "Creator",
            recipientHumanID: assigneeID.uuidString,
            taskTitle: "Other inbox",
            idempotencyKey: "activity:other-recipient",
            createdAt: secondCreatedAt,
            context: context
        ))
        try context.save()
        #expect(!FamilyTaskActivityService.stage(
            kind: .commented,
            recipientHumanID: creatorID.uuidString,
            taskTitle: "Duplicate",
            idempotencyKey: "activity:first",
            context: context
        ))

        let creatorInbox = FamilyTaskActivityService.inbox(
            recipientHumanID: creatorID,
            context: context
        )
        let first = try #require(creatorInbox.first { $0.taskID == taskID })

        #expect(creatorInbox.count == 2)
        #expect(creatorInbox.first?.createdAt == secondCreatedAt)
        #expect(first.planID == planID)
        #expect(first.occurrenceKey == "v1:2026-07-22")
        #expect(FamilyTaskActivityService.unreadCount(recipientHumanID: creatorID, context: context) == 2)
        #expect(FamilyTaskActivityService.unreadCount(recipientHumanID: assigneeID, context: context) == 1)
        #expect(!FamilyTaskActivityService.markRead(
            activityID: first.id,
            recipientHumanID: assigneeID,
            context: context,
            now: secondCreatedAt
        ))
        #expect(FamilyTaskActivityService.markRead(
            activityID: first.id,
            recipientHumanID: creatorID,
            context: context,
            now: secondCreatedAt
        ))
        #expect(FamilyTaskActivityService.markRead(
            activityID: first.id,
            recipientHumanID: creatorID,
            context: context,
            now: secondCreatedAt.addingTimeInterval(1)
        ))
        #expect(FamilyTaskActivityService.unreadCount(recipientHumanID: creatorID, context: context) == 1)
        #expect(FamilyTaskActivityService.markAllRead(
            recipientHumanID: creatorID,
            context: context,
            now: secondCreatedAt.addingTimeInterval(2)
        ) == 1)
        #expect(FamilyTaskActivityService.unreadCount(recipientHumanID: creatorID, context: context) == 0)
        #expect(FamilyTaskActivityService.unreadCount(recipientHumanID: assigneeID, context: context) == 1)
    }

    @Test func zeroAndPositiveRewardsFollowDifferentCompletionPathsAndNotifyBothRoles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let members = try seedMembers(in: context, creatorBalance: 20)
        let zeroReward = makeTask(
            title: "Zero reward",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id
        )
        zeroReward.kind = .bounty
        let rewarded = makeTask(
            title: "Rewarded",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            reward: 20
        )
        context.insert(zeroReward)
        context.insert(rewarded)
        try context.save()

        #expect(FamilyTaskService.complete(zeroReward, by: members.assignee, context: context))
        #expect(!FamilyTaskService.complete(zeroReward, by: members.assignee, context: context))
        #expect(zeroReward.status == .completed)

        #expect(FamilyTaskService.complete(rewarded, by: members.assignee, context: context))
        #expect(rewarded.status == .pendingReview)
        #expect(FamilyTaskService.confirmCompletion(rewarded, by: members.creator, context: context))
        #expect(!FamilyTaskService.confirmCompletion(rewarded, by: members.creator, context: context))
        #expect(rewarded.status == .completed)

        let creatorInbox = FamilyTaskActivityService.inbox(
            recipientHumanID: members.creator.id,
            context: context
        )
        let assigneeInbox = FamilyTaskActivityService.inbox(
            recipientHumanID: members.assignee.id,
            context: context
        )
        let rewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .familyTask && $0.sourceModelId == rewarded.id.uuidString }

        #expect(creatorInbox.count(where: { $0.taskID == zeroReward.id && $0.kind == .completed }) == 1)
        #expect(creatorInbox.count(where: { $0.taskID == rewarded.id && $0.kind == .submittedForReview }) == 1)
        #expect(assigneeInbox.count(where: { $0.taskID == rewarded.id && $0.kind == .rewarded }) == 1)
        #expect(CoconutWalletService.balance(for: members.creator, context: context) == 0)
        #expect(CoconutWalletService.balance(for: members.assignee, context: context) == 20)
        #expect(rewardEntries.count == 2)
        #expect(Set(rewardEntries.map(\.transactionKey)).count == 2)
    }

    @Test func returnForRedoReopensTheSameOccurrenceWithoutRewarding() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let members = try seedMembers(in: context, creatorBalance: 25)
        let task = makeTask(
            title: "Try again",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            reward: 25
        )
        let originalPlanID = task.planId
        let originalOccurrenceKey = task.occurrenceKey
        let originalNominalAt = task.nominalAt
        context.insert(task)
        try context.save()

        #expect(FamilyTaskService.complete(task, by: members.assignee, context: context))
        #expect(FamilyTaskService.rejectCompletion(task, by: members.creator, context: context))

        let assigneeInbox = FamilyTaskActivityService.inbox(
            recipientHumanID: members.assignee.id,
            context: context
        )
        let rewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .familyTask }

        #expect(task.status == .active)
        #expect(task.completedAt == nil)
        #expect(task.completedById == nil)
        #expect(task.planId == originalPlanID)
        #expect(task.occurrenceKey == originalOccurrenceKey)
        #expect(task.nominalAt == originalNominalAt)
        #expect(assigneeInbox.count(where: { $0.taskID == task.id && $0.kind == .returnedForRedo }) == 1)
        #expect(CoconutWalletService.balance(for: members.creator, context: context) == 25)
        #expect(CoconutWalletService.balance(for: members.assignee, context: context) == 0)
        #expect(rewardEntries.isEmpty)
        #expect(FamilyTaskCapabilities.resolve(task: task, currentHumanID: members.assignee.id).canComplete)
    }

    @Test func insufficientApprovalKeepsReviewPendingAndCreatesNoRecipientMessageOrTransfer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let members = try seedMembers(in: context, creatorBalance: 0)
        let task = makeTask(
            title: "Await funds",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            reward: 10
        )
        context.insert(task)
        try context.save()

        #expect(FamilyTaskService.complete(task, by: members.assignee, context: context))
        #expect(!FamilyTaskService.confirmCompletion(task, by: members.creator, context: context))

        let creatorInbox = FamilyTaskActivityService.inbox(
            recipientHumanID: members.creator.id,
            context: context
        )
        let assigneeInbox = FamilyTaskActivityService.inbox(
            recipientHumanID: members.assignee.id,
            context: context
        )
        let rewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.source == .familyTask }

        #expect(task.status == .pendingReview)
        #expect(creatorInbox.count(where: { $0.taskID == task.id && $0.kind == .submittedForReview }) == 1)
        #expect(assigneeInbox.allSatisfy { $0.taskID != task.id })
        #expect(CoconutWalletService.balance(for: members.creator, context: context) == 0)
        #expect(CoconutWalletService.balance(for: members.assignee, context: context) == 0)
        #expect(rewardEntries.isEmpty)
    }

    @Test func duplicateCompletionActivityRollsBackTheOccurrenceMutation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let members = try seedMembers(in: context, creatorBalance: 0)
        let task = makeTask(
            title: "Atomic completion",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id
        )
        context.insert(task)
        try context.save()

        let duplicateKey = FamilyTaskActivityService.transitionKey(
            task: task,
            action: "completed",
            priorUpdatedAt: task.updatedAt
        )
        context.insert(FamilyTaskActivity(
            taskId: task.id.uuidString,
            kind: .completed,
            actorHumanId: members.assignee.id.uuidString,
            actorHumanName: members.assignee.name,
            recipientHumanId: members.creator.id.uuidString,
            taskTitleSnapshot: task.title,
            idempotencyKey: duplicateKey
        ))
        try context.save()

        #expect(!FamilyTaskService.complete(task, by: members.assignee, context: context))
        #expect(task.status == .active)
        #expect(task.completedAt == nil)
        #expect(task.completedById == nil)
        #expect(try context.fetchCount(FetchDescriptor<FamilyTaskActivity>()) == 1)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func duplicateRewardActivityRollsBackApprovalAndWalletFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let members = try seedMembers(in: context, creatorBalance: 10)
        let task = makeTask(
            title: "Atomic reward",
            creatorID: members.creator.id,
            assigneeID: members.assignee.id,
            reward: 10
        )
        context.insert(task)
        try context.save()
        #expect(FamilyTaskService.complete(task, by: members.assignee, context: context))

        let baselineCareLedgerCount = try context.fetchCount(FetchDescriptor<CareLedgerEvent>())
        let duplicateKey = FamilyTaskActivityService.transitionKey(
            task: task,
            action: "rewarded",
            priorUpdatedAt: task.updatedAt
        )
        context.insert(FamilyTaskActivity(
            taskId: task.id.uuidString,
            kind: .rewarded,
            actorHumanId: members.creator.id.uuidString,
            actorHumanName: members.creator.name,
            recipientHumanId: members.assignee.id.uuidString,
            taskTitleSnapshot: task.title,
            idempotencyKey: duplicateKey
        ))
        try context.save()

        #expect(!FamilyTaskService.confirmCompletion(task, by: members.creator, context: context))
        #expect(task.status == .pendingReview)
        #expect(CoconutWalletService.balance(for: members.creator, context: context) == 10)
        #expect(CoconutWalletService.balance(for: members.assignee, context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<CareLedgerEvent>()) == baselineCareLedgerCount)
        #expect(try context.fetchCount(FetchDescriptor<FamilyTaskActivity>()) == 2)
    }

    private func makeTask(
        title: String = "Family task",
        creatorID: UUID,
        assigneeID: UUID,
        reward: Int = 0,
        dueAt: Date? = nil
    ) -> FamilyCollaborationTask {
        let planID = UUID()
        let nominalAt = Date(timeIntervalSince1970: 1_999_900_000)
        return FamilyCollaborationTask(
            title: title,
            kind: reward > 0 ? .bounty : .householdTask,
            planId: planID.uuidString,
            occurrenceKey: "\(planID.uuidString):v1:2026-07-22",
            nominalAt: nominalAt,
            scheduleVersion: 1,
            createdById: creatorID.uuidString,
            createdByName: "Creator",
            assignedToId: assigneeID.uuidString,
            assignedToName: "Assignee",
            rewardCoconuts: reward,
            dueAt: dueAt
        )
    }

    private func seedMembers(
        in context: ModelContext,
        creatorBalance: Int
    ) throws -> (creator: Human, assignee: Human) {
        let creator = Human(name: "Creator")
        let assignee = Human(name: "Assignee")
        creator.coconutBalance = creatorBalance
        context.insert(creator)
        context.insert(assignee)
        try context.save()
        return (creator, assignee)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV95.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
