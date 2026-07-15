//
//  TaskActionCommands.swift
//  Ohana
//
//  Stable, value-only task intents and the single write adapter used by every
//  Task Center entry point.
//

import Foundation
import SwiftData

nonisolated struct TaskActionCommand: Equatable, Sendable {
    let itemID: String
    let action: TaskCenterAvailableAction
    let eventID: UUID?
    let reminderID: UUID?
    let familyTaskID: UUID?
    let subjectID: UUID?
    let actingHumanID: UUID?
    let occurrenceDate: Date
    let idempotencyKey: String

    init(
        item: TaskCenterItemSnapshot,
        action: TaskCenterAvailableAction,
        actingHumanID: UUID? = nil
    ) {
        itemID = item.id
        self.action = action
        eventID = item.eventID
        reminderID = item.reminderID
        familyTaskID = item.familyTaskID
        subjectID = item.subject.id
        self.actingHumanID = actingHumanID
        occurrenceDate = item.occurrenceDate
        idempotencyKey = Self.idempotencyKey(
            item: item,
            action: action
        )
    }

    private static func idempotencyKey(
        item: TaskCenterItemSnapshot,
        action: TaskCenterAvailableAction
    ) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            in: TimeZone(secondsFromGMT: 0) ?? .gmt,
            from: item.occurrenceDate
        )
        let occurrenceKey = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        let sourceKey = item.familyTaskID?.uuidString
            ?? item.reminderID?.uuidString
            ?? item.eventID?.uuidString
            ?? item.id
        let subjectKey = item.subject.id?.uuidString ?? item.subject.kind.rawValue
        return "task-action:\(sourceKey):\(occurrenceKey):\(subjectKey):\(action.rawValue)"
    }
}

nonisolated struct TaskActionResult: Equatable, Sendable {
    enum Disposition: String, Equatable, Sendable {
        case applied
        case alreadyApplied
        case rejected
    }

    let command: TaskActionCommand
    let disposition: Disposition
    let affectedEntityIDs: Set<UUID>
    let resultingWorkflowStatus: TaskCenterWorkflowStatus?

    var didSucceed: Bool {
        disposition != .rejected
    }
}

@MainActor
struct TaskActionCommandExecutor {
    let modelContext: ModelContext
    let services: AppServices

    /// Loads only the live models needed for a value-only command. UI callers
    /// use this boundary instead of reaching into SwiftData themselves.
    func execute(_ command: TaskActionCommand) throws -> TaskActionResult {
        let events: [Event] = if let eventID = command.eventID {
            [try fetchEvent(id: eventID)]
        } else {
            []
        }
        let familyTasks: [FamilyCollaborationTask] = if let familyTaskID = command.familyTaskID {
            [try fetchFamilyTask(id: familyTaskID)]
        } else {
            []
        }
        var humanDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.passedAwayDate == nil }
        )
        humanDescriptor.fetchLimit = 64
        let humans = try modelContext.fetch(humanDescriptor)
        let pets = try fetchRelevantPets(events: events)
        return execute(
            command,
            events: events,
            familyTasks: familyTasks,
            humans: humans,
            pets: pets
        )
    }

    func execute(
        _ command: TaskActionCommand,
        events: [Event],
        familyTasks: [FamilyCollaborationTask],
        humans: [Human],
        pets: [Pet]
    ) -> TaskActionResult {
        let event = command.eventID.flatMap { id in
            events.first { $0.id == id }
        }
        let familyTask = command.familyTaskID.flatMap { id in
            familyTasks.first { $0.id == id }
        }
        let activeHuman = activeHuman(in: humans, explicitID: command.actingHumanID)

        switch command.action {
        case .complete, .submitForReview:
            return complete(
                command,
                event: event,
                familyTask: familyTask,
                activeHuman: activeHuman,
                humans: humans,
                pets: pets
            )
        case .claim:
            guard let familyTask, let activeHuman else {
                return rejected(command, event: event, familyTask: familyTask)
            }
            if familyTask.claimedById == activeHuman.id.uuidString ||
                familyTask.assignedToId == activeHuman.id.uuidString,
                familyTask.status == .claimed {
                return success(command, disposition: .alreadyApplied, event: event, familyTask: familyTask)
            }
            let didApply = collaborationExecutor.claim(familyTask, by: activeHuman)
            return didApply
                ? success(command, event: event, familyTask: familyTask)
                : rejected(command, event: event, familyTask: familyTask)
        case .approve:
            guard let familyTask, familyTask.status == .pendingReview else {
                return familyTask?.status == .completed
                    ? success(command, disposition: .alreadyApplied, event: event, familyTask: familyTask)
                    : rejected(command, event: event, familyTask: familyTask)
            }
            let didApply = collaborationExecutor.confirmCompletion(familyTask, by: activeHuman)
            return didApply
                ? success(command, event: event, familyTask: familyTask)
                : rejected(command, event: event, familyTask: familyTask)
        case .reject:
            guard let familyTask, familyTask.status == .pendingReview else {
                return rejected(command, event: event, familyTask: familyTask)
            }
            let didApply = collaborationExecutor.rejectCompletion(familyTask, by: activeHuman)
            return didApply
                ? success(command, event: event, familyTask: familyTask)
                : rejected(command, event: event, familyTask: familyTask)
        }
    }

    private func complete(
        _ command: TaskActionCommand,
        event: Event?,
        familyTask: FamilyCollaborationTask?,
        activeHuman: Human?,
        humans: [Human],
        pets: [Pet]
    ) -> TaskActionResult {
        var didApply = false

        let implicitlyClaimableTask = familyTask.map {
            canImplicitlyClaim($0, activeHuman: activeHuman, humans: humans)
        } ?? false
        if let familyTask,
           familyTask.status != .completed,
           familyTask.status != .pendingReview {
            guard let activeHuman else {
                return rejected(command, event: event, familyTask: familyTask)
            }
            if implicitlyClaimableTask {
                guard services.familyTasks.canClaim(
                    familyTask,
                    by: activeHuman,
                    context: modelContext
                ) else {
                    return rejected(command, event: event, familyTask: familyTask)
                }
            } else {
                let passesPreflight = switch command.action {
                case .complete:
                    services.familyTasks.canComplete(
                        familyTask,
                        by: activeHuman,
                        context: modelContext
                    )
                case .submitForReview:
                    services.familyTasks.canSubmitForReview(
                        familyTask,
                        by: activeHuman,
                        context: modelContext
                    )
                case .claim, .approve, .reject:
                    false
                }
                guard passesPreflight else {
                    return rejected(command, event: event, familyTask: familyTask)
                }
            }
        }

        // After the read-only FamilyTask preflight, Event-backed care runs
        // through the Calendar chokepoint. That path records the care fact
        // before projecting Reminder/FamilyTask state and owns derived effects.
        let hadCompletedPlantFact = event.map {
            PlantCareScheduleSyncService.hasCompletedCareFact(
                for: $0,
                occurrenceDate: command.occurrenceDate,
                context: modelContext
            )
        } == true
        if let event,
           !event.isOccurrenceMarkedComplete(on: command.occurrenceDate) {
            do {
                let completion = try CalendarCommandExecutor(
                    context: modelContext,
                    services: services
                ).toggleCompletion(
                    event: event,
                    occurrenceDate: command.occurrenceDate,
                    pets: pets,
                    executorId: activeHuman?.id.uuidString,
                    note: "task_center.unified_action.\(command.idempotencyKey)"
                )
                guard completion.isCompleted else {
                    return rejected(command, event: event, familyTask: familyTask)
                }
                didApply = completion.didWriteFact || (completion.didChange && !hadCompletedPlantFact)
            } catch {
                services.domainRevisions.publishFailure(
                    command: .calendarEventCompletion(eventID: event.id, isCompleted: true),
                    error: error
                )
                return rejected(command, event: event, familyTask: familyTask)
            }
        }

        if let familyTask,
           familyTask.status != .completed,
           familyTask.status != .pendingReview {
            let collaboration = collaborationExecutor
            if implicitlyClaimableTask,
               let activeHuman,
               familyTask.isOpen {
                guard collaboration.claim(familyTask, by: activeHuman) else {
                    return rejected(command, event: event, familyTask: familyTask)
                }
                didApply = true
            }
            let taskDidApply = collaboration.complete(familyTask, by: activeHuman)
            guard taskDidApply else {
                return rejected(command, event: event, familyTask: familyTask)
            }
            didApply = true
        }

        guard event != nil || familyTask != nil else {
            return rejected(command, event: nil, familyTask: nil)
        }
        return success(
            command,
            disposition: didApply ? .applied : .alreadyApplied,
            event: event,
            familyTask: familyTask
        )
    }

    private func activeHuman(in humans: [Human], explicitID: UUID?) -> Human? {
        if let explicitID {
            return humans.first(where: { $0.id == explicitID && !$0.hasPassedAway })
        }
        if let activeID = services.activeHumanSelection.currentHumanId,
           let match = humans.first(where: { $0.id.uuidString == activeID && !$0.hasPassedAway }) {
            return match
        }
        let activeHumans = humans.filter { !$0.hasPassedAway }
        return activeHumans.count == 1 ? activeHumans[0] : nil
    }

    private var collaborationExecutor: FamilyCollaborationCommandExecutor {
        FamilyCollaborationCommandExecutor(
            modelContext: modelContext,
            familyTasks: services.familyTasks,
            revisions: services.domainRevisions
        )
    }

    private func fetchEvent(id: UUID) throws -> Event {
        let eventID = id
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.id == eventID }
        )
        descriptor.fetchLimit = 1
        guard let event = try modelContext.fetch(descriptor).first else {
            throw TaskActionLookupError.eventUnavailable
        }
        return event
    }

    private func fetchFamilyTask(id: UUID) throws -> FamilyCollaborationTask {
        let taskID = id
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { $0.id == taskID }
        )
        descriptor.fetchLimit = 1
        guard let task = try modelContext.fetch(descriptor).first else {
            throw TaskActionLookupError.familyTaskUnavailable
        }
        return task
    }

    private func fetchRelevantPets(events: [Event]) throws -> [Pet] {
        guard let petID = events.first.flatMap({ event -> UUID? in
            guard event.relatedEntityType == EntityKind.pet.rawValue else { return nil }
            return UUID(uuidString: event.relatedEntityId)
        }) else { return [] }
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == petID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func canImplicitlyClaim(
        _ task: FamilyCollaborationTask,
        activeHuman: Human?,
        humans: [Human]
    ) -> Bool {
        !task.hasReward &&
            task.isOpen &&
            activeHuman != nil &&
            humans.count(where: { !$0.hasPassedAway }) == 1
    }

    private func success(
        _ command: TaskActionCommand,
        disposition: TaskActionResult.Disposition = .applied,
        event: Event?,
        familyTask: FamilyCollaborationTask?
    ) -> TaskActionResult {
        var affectedIDs: Set<UUID> = []
        if let event { affectedIDs.insert(event.id) }
        if let familyTask { affectedIDs.insert(familyTask.id) }
        if let reminderID = command.reminderID { affectedIDs.insert(reminderID) }
        if let subjectID = command.subjectID { affectedIDs.insert(subjectID) }
        return TaskActionResult(
            command: command,
            disposition: disposition,
            affectedEntityIDs: affectedIDs,
            resultingWorkflowStatus: familyTask.map(workflowStatus)
        )
    }

    private func rejected(
        _ command: TaskActionCommand,
        event: Event?,
        familyTask: FamilyCollaborationTask?
    ) -> TaskActionResult {
        var affectedIDs: Set<UUID> = []
        if let event { affectedIDs.insert(event.id) }
        if let familyTask { affectedIDs.insert(familyTask.id) }
        if let reminderID = command.reminderID { affectedIDs.insert(reminderID) }
        if let subjectID = command.subjectID { affectedIDs.insert(subjectID) }
        return TaskActionResult(
            command: command,
            disposition: .rejected,
            affectedEntityIDs: affectedIDs,
            resultingWorkflowStatus: familyTask.map(workflowStatus)
        )
    }

    private func workflowStatus(_ task: FamilyCollaborationTask) -> TaskCenterWorkflowStatus {
        switch task.status {
        case .active: .active
        case .claimed: .claimed
        case .pendingReview: .pendingReview
        case .completed: .completed
        case .cancelled: .cancelled
        }
    }
}

nonisolated enum TaskActionLookupError: Error, Equatable, Sendable {
    case eventUnavailable
    case familyTaskUnavailable
}
