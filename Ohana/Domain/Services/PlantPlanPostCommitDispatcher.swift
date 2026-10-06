//
//  PlantPlanPostCommitDispatcher.swift
//  Ohana
//
//  Owns asynchronous reminder registration started after plant-plan persistence.
//

import Foundation
import SwiftData

nonisolated struct PlantPlanPostCommitDispatchOutcome: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case dispatched
        case cancelled
    }

    let requestID: UUID
    let requestedReminderIDs: [UUID]
    let resolvedReminderIDs: [UUID]
    let state: State
}

@MainActor
final class PlantPlanPostCommitDispatchHandle {
    let id: UUID
    private let task: Task<PlantPlanPostCommitDispatchOutcome, Never>

    fileprivate init(
        id: UUID,
        task: Task<PlantPlanPostCommitDispatchOutcome, Never>
    ) {
        self.id = id
        self.task = task
    }

    func wait() async -> PlantPlanPostCommitDispatchOutcome {
        await task.value
    }

    func cancel() {
        task.cancel()
    }

    var isCancelled: Bool {
        task.isCancelled
    }
}

@MainActor
protocol PlantPlanPostCommitDispatching: AnyObject {
    @discardableResult
    func dispatch(
        reminderIDs: [UUID],
        context: ModelContext,
        reminderScheduling: ReminderSchedulingManaging,
        source: CareLedgerSource
    ) -> PlantPlanPostCommitDispatchHandle
}

@MainActor
private final class PlantPlanPostCommitStoreLease {
    let context: ModelContext
    private let retainedContainer: ModelContainer

    init(context: ModelContext) {
        self.context = context
        retainedContainer = context.container
    }
}

@MainActor
final class PlantPlanPostCommitDispatcher: PlantPlanPostCommitDispatching {
    static let shared = PlantPlanPostCommitDispatcher()

    private var activeTasks: [UUID: Task<PlantPlanPostCommitDispatchOutcome, Never>] = [:]

    var activeDispatchCount: Int {
        activeTasks.count
    }

    @discardableResult
    func dispatch(
        reminderIDs rawReminderIDs: [UUID],
        context: ModelContext,
        reminderScheduling: ReminderSchedulingManaging,
        source: CareLedgerSource = .service
    ) -> PlantPlanPostCommitDispatchHandle {
        let requestID = UUID()
        let reminderIDs = Array(Set(rawReminderIDs)).sorted { $0.uuidString < $1.uuidString }
        let storeLease = PlantPlanPostCommitStoreLease(context: context)
        let task = Task { @MainActor [weak self, storeLease] in
            defer { self?.finish(requestID) }
            guard !Task.isCancelled else {
                return PlantPlanPostCommitDispatchOutcome(
                    requestID: requestID,
                    requestedReminderIDs: reminderIDs,
                    resolvedReminderIDs: [],
                    state: .cancelled
                )
            }

            let reminders = Self.fetchReminders(ids: reminderIDs, context: storeLease.context)
            guard !Task.isCancelled else {
                return PlantPlanPostCommitDispatchOutcome(
                    requestID: requestID,
                    requestedReminderIDs: reminderIDs,
                    resolvedReminderIDs: reminders.map(\.id),
                    state: .cancelled
                )
            }
            await reminderScheduling.scheduleManyIfNeeded(
                reminders: reminders,
                context: storeLease.context,
                source: source
            )
            return PlantPlanPostCommitDispatchOutcome(
                requestID: requestID,
                requestedReminderIDs: reminderIDs,
                resolvedReminderIDs: reminders.map(\.id),
                state: Task.isCancelled ? .cancelled : .dispatched
            )
        }
        activeTasks[requestID] = task
        return PlantPlanPostCommitDispatchHandle(id: requestID, task: task)
    }

    func cancelAll() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    private func finish(_ requestID: UUID) {
        activeTasks[requestID] = nil
    }

    private static func fetchReminders(ids: [UUID], context: ModelContext) -> [Reminder] {
        ids.compactMap { id in
            var descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.id == id
                }
            )
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor))?.first
        }
    }
}
