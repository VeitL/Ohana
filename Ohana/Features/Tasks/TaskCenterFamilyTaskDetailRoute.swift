//
//  TaskCenterFamilyTaskDetailRoute.swift
//  Ohana
//

import SwiftData
import SwiftUI

// MARK: - Family task detail

extension TaskCenterRouteContainer {
    func familyTaskDetail(_ route: TaskCenterFamilyTaskDetailRoute) -> some View {
        FamilyTaskDetailView(
            snapshot: route.snapshot,
            onEdit: route.snapshot.capabilities.canEdit ? {
                presentFamilyTaskEditorAfterDetail(taskID: route.snapshot.taskID)
            } : nil,
            onTaskAction: { action in
                performFamilyTaskDetailAction(taskID: route.snapshot.taskID, action: action)
            },
            onDecline: { reason in
                declineFamilyTask(taskID: route.snapshot.taskID, reason: reason)
            },
            onPostpone: { dueAt in
                postponeFamilyTask(taskID: route.snapshot.taskID, to: dueAt)
            },
            onComment: { body in
                commentOnFamilyTask(taskID: route.snapshot.taskID, body: body)
            },
            onCancel: { scope in
                await cancelFamilyTask(taskID: route.snapshot.taskID, scope: scope)
            }
        )
    }

    func presentFamilyTaskDetail(
        taskID: UUID,
        preferredItem: TaskCenterItemSnapshot? = nil
    ) {
        guard let task = familyTaskModel(id: taskID) else { return }
        familyTaskDetailRoute = makeFamilyTaskDetailRoute(task: task, preferredItem: preferredItem)
    }

    func makeFamilyTaskDetailRoute(
        task: FamilyCollaborationTask,
        preferredItem: TaskCenterItemSnapshot?
    ) -> TaskCenterFamilyTaskDetailRoute {
        let latestItem = preferredItem.flatMap { preferred in
            routeData.snapshot.allItems.first(where: { $0.id == preferred.id }) ?? preferred
        } ?? routeData.snapshot.allItems.first(where: { $0.familyTaskID == task.id })
        let capabilities = FamilyTaskCapabilities.resolve(
            task: task,
            currentHumanID: selectedActiveHumanID
        )
        var actions: Set<TaskCenterAvailableAction> = []
        if capabilities.canComplete {
            actions.insert(task.hasReward ? .submitForReview : .complete)
        }
        if capabilities.canApprove { actions.insert(.approve) }
        if capabilities.canReturnForRedo { actions.insert(.reject) }
        if task.status == .active,
           task.isOpen,
           selectedActiveHumanID != nil,
           latestItem?.availableActions.contains(.claim) == true {
            actions.insert(.claim)
        }

        return TaskCenterFamilyTaskDetailRoute(
            snapshot: TaskCenterFamilyTaskDetailSnapshot(
                taskID: task.id,
                title: task.title,
                note: task.note,
                emoji: task.emoji,
                creatorName: task.createdByName,
                assigneeName: task.claimedByName ?? task.assignedToName,
                viewerRole: familyTaskViewerRole(for: task),
                capabilities: capabilities,
                status: task.status,
                dueAt: task.dueAt ?? latestItem?.dueAt,
                isAllDay: latestItem?.isAllDay ?? false,
                isRecurring: latestItem?.isRecurring == true || task.planId != nil,
                allowsThisAndFutureCancellation: task.planId != nil && task.nominalAt != nil,
                rewardCoconuts: task.rewardCoconuts,
                availableActions: actions,
                isLinkedToCalendar: latestItem?.eventID != nil || task.relatedEventId != nil,
                activities: FamilyTaskActivityService.occurrenceTimeline(
                    taskID: task.id,
                    context: modelContext
                )
            )
        )
    }

    func familyTaskViewerRole(
        for task: FamilyCollaborationTask
    ) -> TaskCenterFamilyTaskViewerRole {
        guard let selectedHumanID = selectedActiveHumanID else {
            return .familyMember
        }
        if UUID(uuidString: task.createdById) == selectedHumanID {
            return .creator
        }
        if task.claimedById.flatMap(UUID.init(uuidString:)) == selectedHumanID ||
            task.assignedToId.flatMap(UUID.init(uuidString:)) == selectedHumanID {
            return .assignee
        }
        return .familyMember
    }

    func canSelectedHumanEdit(_ task: FamilyCollaborationTask) -> Bool {
        FamilyTaskCapabilities.resolve(
            task: task,
            currentHumanID: selectedActiveHumanID
        ).canEdit
    }

    func presentFamilyTaskEditorAfterDetail(taskID: UUID) {
        familyTaskDetailRoute = nil
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            guard let task = familyTaskModel(id: taskID),
                  canSelectedHumanEdit(task) else { return }
            if !routeData.familyTasks.contains(where: { $0.id == taskID }) {
                routeData.familyTasks.append(task)
            }
            familyTaskEditorRoute = .editTask(taskID)
        }
    }

    func performFamilyTaskDetailAction(
        taskID: UUID,
        action: TaskCenterAvailableAction
    ) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand() else { return false }
        let capabilities = FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id)
        let didSucceed: Bool
        switch action {
        case .complete, .submitForReview:
            guard capabilities.canComplete else { return false }
            didSucceed = familyTaskCommandExecutor.complete(task, by: human)
        case .claim:
            didSucceed = familyTaskCommandExecutor.claim(task, by: human)
        case .approve:
            guard capabilities.canApprove else { return false }
            didSucceed = familyTaskCommandExecutor.confirmCompletion(task, by: human)
        case .reject:
            guard capabilities.canReturnForRedo else { return false }
            didSucceed = familyTaskCommandExecutor.rejectCompletion(task, by: human)
        }
        return finishFamilyTaskMutation(didSucceed, taskID: taskID)
    }

    func declineFamilyTask(taskID: UUID, reason: String) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canDecline else {
            return false
        }
        return finishFamilyTaskMutation(
            familyTaskCommandExecutor.declineAssignment(task, by: human, reason: reason),
            taskID: taskID
        )
    }

    func postponeFamilyTask(taskID: UUID, to dueAt: Date) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canPostpone else {
            return false
        }
        return finishFamilyTaskMutation(
            familyTaskCommandExecutor.postponeOccurrence(task, to: dueAt, by: human),
            taskID: taskID
        )
    }

    func commentOnFamilyTask(taskID: UUID, body: String) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canComment else {
            return false
        }
        let idempotencyKey = "family-task:\(taskID.uuidString):comment:\(human.id.uuidString):\(UUID().uuidString)"
        return finishFamilyTaskMutation(
            familyTaskCommandExecutor.addComment(
                task,
                body: body,
                by: human,
                idempotencyKey: idempotencyKey
            ),
            taskID: taskID
        )
    }

    func cancelFamilyTask(
        taskID: UUID,
        scope: FamilyTaskEditScope
    ) async -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canCancel else {
            return false
        }
        switch scope {
        case .onlyThis:
            return finishFamilyTaskMutation(
                familyTaskCommandExecutor.cancelTask(task, by: human),
                taskID: taskID
            )
        case .thisAndFuture:
            guard let rawPlanID = task.planId,
                  let planID = UUID(uuidString: rawPlanID),
                  let nominalAt = task.nominalAt else { return false }
            let didSucceed = await familyTaskCommandExecutor.cancelThisAndFuture(
                planID: planID,
                from: nominalAt,
                by: human
            )
            guard didSucceed else { return false }
            refreshFamilyTaskActivities()
            scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
            return true
        }
    }

    func finishFamilyTaskMutation(_ didSucceed: Bool, taskID: UUID) -> Bool {
        guard didSucceed else { return false }
        if familyTaskDetailRoute?.snapshot.taskID == taskID,
           let task = familyTaskModel(id: taskID) {
            familyTaskDetailRoute = makeFamilyTaskDetailRoute(task: task, preferredItem: nil)
        }
        refreshFamilyTaskActivities()
        scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        return true
    }

    var familyTaskCommandExecutor: FamilyCollaborationCommandExecutor {
        FamilyCollaborationCommandExecutor(
            modelContext: modelContext,
            familyTasks: appServices.familyTasks,
            revisions: appServices.domainRevisions
        )
    }

    var selectedActiveHumanID: UUID? {
        appServices.activeHumanSelection.currentHumanId.flatMap(UUID.init(uuidString:))
    }

    func selectedHumanForFamilyTaskCommand() -> Human? {
        guard let selectedActiveHumanID else { return nil }
        return routeData.humans.first { $0.id == selectedActiveHumanID && !$0.hasPassedAway }
    }

    func familyTaskModel(id: UUID) -> FamilyCollaborationTask? {
        routeData.familyTasks.first { $0.id == id }
    }
}
