//
//  DomainCommandPipeline.swift
//  Ohana
//
//  Shared write-command contract and read-model revision publishing.
//

import Combine
import Foundation

nonisolated struct DomainCommand: Hashable, CustomStringConvertible, Sendable {
    let feature: String
    let action: String
    let parameters: [String: String]

    init(feature: String, action: String, parameters: [String: String] = [:]) {
        self.feature = feature
        self.action = action
        self.parameters = parameters
    }

    var description: String {
        guard !parameters.isEmpty else {
            return "\(feature).\(action)"
        }
        let payload = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(feature).\(action)(\(payload))"
    }

    static func command(_ feature: String, _ action: String, _ parameters: [String: String] = [:]) -> DomainCommand {
        DomainCommand(feature: feature, action: action, parameters: parameters)
    }
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

nonisolated struct HomeRevision: Equatable, Hashable, Sendable {
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
    @Published private(set) var homeRevision = HomeRevision()
    @Published private(set) var lastMutation: DomainMutationResult?
    private(set) var lastCoconutRewardEvent: OhanaCoconutRewardEvent?

    private let coconutRewardSubject = PassthroughSubject<OhanaCoconutRewardEvent, Never>()

    init() {}

    var homeRevisionUpdates: AnyPublisher<HomeRevision, Never> {
        $homeRevision.eraseToAnyPublisher()
    }

    var coconutRewardEvents: AnyPublisher<OhanaCoconutRewardEvent, Never> {
        coconutRewardSubject.eraseToAnyPublisher()
    }

    func publish(_ result: DomainMutationResult) {
        lastMutation = result
        homeRevision.advance(for: result.command)
        AppPerformanceMonitor.shared.record(
            result.wroteBusinessFact ? "domain_command_success" : "domain_command_noop",
            valueMS: 0,
            note: result.note ?? "\(result.command)"
        )
    }

    func publishDomainMutation(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool,
        note: String
    ) {
        publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affectedEntityIDs,
                wroteBusinessFact: wroteBusinessFact,
                note: note
            )
        )
    }

    func publishFailure(command: DomainCommand, error: Error) {
        AppPerformanceMonitor.shared.record(
            "domain_command_failure",
            valueMS: 0,
            note: "\(command): \(error.localizedDescription)"
        )
    }

    func publishCoconutRewardFeedback(_ event: OhanaCoconutRewardEvent) {
        lastCoconutRewardEvent = event
        coconutRewardSubject.send(event)
    }
}

@MainActor
final class DeferredDomainCommandQueue: ObservableObject {
    static let destructiveRouteDismissDelayMilliseconds: UInt64 = 520

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
