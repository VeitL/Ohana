//
//  DomainCommandPipeline.swift
//  Ohana
//
//  Shared write-command contract and read-model revision publishing.
//

import Combine
import Foundation

enum DomainCommand: Hashable {
    case quickCare(entityID: UUID, action: String)
    case todayFocus(entityID: UUID, action: String)
    case medicationDose(petID: UUID, medicationID: UUID)
    case plantCare(plantID: UUID, action: String)
    case reminderCompletion(reminderID: UUID)
    case coconutExchange(requestID: UUID)
    case unknown(action: String)
}

struct DomainMutationResult: Identifiable, Hashable {
    let id = UUID()
    let command: DomainCommand
    let affectedEntityIDs: Set<UUID>
    let wroteBusinessFact: Bool
    let occurredAt: Date
    let note: String?

    init(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID> = [],
        wroteBusinessFact: Bool = true,
        occurredAt: Date = Date(),
        note: String? = nil
    ) {
        self.command = command
        self.affectedEntityIDs = affectedEntityIDs
        self.wroteBusinessFact = wroteBusinessFact
        self.occurredAt = occurredAt
        self.note = note
    }
}

struct HomeRevision: Equatable, Hashable {
    var value: Int = 0
    var changedAt: Date = .distantPast
    var lastCommand: DomainCommand?

    mutating func advance(for command: DomainCommand) {
        value &+= 1
        changedAt = Date()
        lastCommand = command
    }
}

@MainActor
final class ReadModelRevisionCenter: ObservableObject {
    static let shared = ReadModelRevisionCenter()

    @Published private(set) var homeRevision = HomeRevision()
    @Published private(set) var lastMutation: DomainMutationResult?

    private init() {}

    func publish(_ result: DomainMutationResult) {
        lastMutation = result
        homeRevision.advance(for: result.command)
        AppPerformanceMonitor.shared.record(
            result.wroteBusinessFact ? "domain_command_success" : "domain_command_noop",
            valueMS: 0,
            note: result.note ?? "\(result.command)"
        )
    }

    func publishFailure(command: DomainCommand, error: Error) {
        AppPerformanceMonitor.shared.record(
            "domain_command_failure",
            valueMS: 0,
            note: "\(command): \(error.localizedDescription)"
        )
    }
}

@MainActor
final class DeferredDomainCommandQueue: ObservableObject {
    @Published private(set) var pendingCount = 0

    private var tasks: [UUID: Task<Void, Never>] = [:]

    @discardableResult
    func enqueue(
        _ command: DomainCommand,
        delayMilliseconds: UInt64 = 0,
        operation: @escaping @MainActor () -> Void
    ) -> UUID {
        let id = UUID()
        AppPerformanceMonitor.shared.record(
            "domain_command_deferred",
            valueMS: 0,
            note: "\(command)"
        )
        tasks[id]?.cancel()
        tasks[id] = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                self.finish(id)
                return
            }
            operation()
            self.finish(id)
        }
        pendingCount = tasks.count
        return id
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        pendingCount = 0
    }

    private func finish(_ id: UUID) {
        tasks[id] = nil
        pendingCount = tasks.count
    }
}
