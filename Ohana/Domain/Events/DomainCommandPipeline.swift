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

/// Identifies the read-model surface that owns a targeted invalidation token.
///
/// `homeRevision` remains the legacy broad publisher for existing route
/// containers. New high-frequency Home work must use the scoped token below so
/// an unrelated mutation does not restart the Home SwiftData aggregation.
nonisolated enum ReadModelInvalidationSurface: String, Equatable, Hashable, Sendable {
    case home
    case walletProjection
}

/// Domains represented by the Home read model. Keep this intentionally small:
/// it describes aggregate inputs to the Home snapshot, not every feature in
/// the app.
nonisolated enum HomeInvalidationDomain: String, CaseIterable, Equatable, Hashable, Sendable {
    case membership
    case care
    case schedule
    case plants
    case health
    case economy
    case appearance
    case records
    case unknown
}

/// A value token for one visible read-model surface.
///
/// The token retains the affected domains and entity IDs so a consumer can
/// reject a presentation-only change for an entity that is not on screen. An
/// aggregate change is explicitly marked as a full refresh; callers must not
/// guess from an empty entity set.
nonisolated struct HomeSurfaceInvalidationToken: Equatable, Sendable {
    static let empty = HomeSurfaceInvalidationToken(
        surface: .home,
        value: 0,
        domains: [],
        domainRevisions: [:],
        affectedEntityIDs: [],
        requiresFullRefresh: false,
        changedAt: .distantPast,
        lastCommand: nil
    )

    let surface: ReadModelInvalidationSurface
    let value: Int
    let domains: Set<HomeInvalidationDomain>
    /// Independent monotonic values for the domains carried by this token.
    /// They let a surface compare only the domains it renders as its read model
    /// becomes more granular, instead of recreating a global home revision.
    let domainRevisions: [HomeInvalidationDomain: Int]
    let affectedEntityIDs: Set<UUID>
    let requiresFullRefresh: Bool
    let changedAt: Date
    let lastCommand: DomainCommand?

    init(
        surface: ReadModelInvalidationSurface,
        value: Int,
        domains: Set<HomeInvalidationDomain>,
        domainRevisions: [HomeInvalidationDomain: Int]? = nil,
        affectedEntityIDs: Set<UUID>,
        requiresFullRefresh: Bool,
        changedAt: Date = Date(),
        lastCommand: DomainCommand? = nil
    ) {
        self.surface = surface
        self.value = value
        self.domains = domains
        self.domainRevisions = domainRevisions
            ?? Dictionary(uniqueKeysWithValues: domains.map { ($0, value) })
        self.affectedEntityIDs = affectedEntityIDs
        self.requiresFullRefresh = requiresFullRefresh
        self.changedAt = changedAt
        self.lastCommand = lastCommand
    }

    var revision: HomeRevision {
        HomeRevision(
            value: value,
            changedAt: changedAt,
            lastCommand: lastCommand
        )
    }

    /// Coalesces covered-surface mutations into one eventual read-model pass.
    /// If the ID set becomes too broad, deliberately fall back to a full
    /// refresh instead of retaining an unbounded queue while a sheet is open.
    func merging(_ newer: HomeSurfaceInvalidationToken) -> HomeSurfaceInvalidationToken {
        guard surface == newer.surface else { return newer }

        let mergedIDs = affectedEntityIDs.union(newer.affectedEntityIDs)
        let canRetainEntityScope = mergedIDs.count <= Self.maximumMergedEntityIDs
        var mergedDomainRevisions = domainRevisions
        for (domain, revision) in newer.domainRevisions {
            mergedDomainRevisions[domain] = max(mergedDomainRevisions[domain] ?? 0, revision)
        }
        return HomeSurfaceInvalidationToken(
            surface: surface,
            value: max(value, newer.value),
            domains: domains.union(newer.domains),
            domainRevisions: mergedDomainRevisions,
            affectedEntityIDs: canRetainEntityScope ? mergedIDs : [],
            requiresFullRefresh: requiresFullRefresh || newer.requiresFullRefresh || !canRetainEntityScope,
            changedAt: newer.changedAt,
            lastCommand: newer.lastCommand
        )
    }

    /// Entity-scoped appearance updates can be ignored when their target is
    /// absent from the visible Home snapshot. Aggregate data must always win.
    func isRelevant(toVisibleEntityIDs visibleEntityIDs: Set<UUID>) -> Bool {
        guard surface == .home, value > 0 else { return false }
        guard !requiresFullRefresh,
              !affectedEntityIDs.isEmpty,
              !visibleEntityIDs.isEmpty else {
            return true
        }
        return !affectedEntityIDs.isDisjoint(with: visibleEntityIDs)
    }

    private static let maximumMergedEntityIDs = 96
}

private nonisolated struct HomeSurfaceInvalidationScope: Sendable {
    let domains: Set<HomeInvalidationDomain>
    let requiresFullRefresh: Bool

    static func aggregate(_ domains: Set<HomeInvalidationDomain>) -> HomeSurfaceInvalidationScope {
        HomeSurfaceInvalidationScope(domains: domains, requiresFullRefresh: true)
    }

    static func entityScoped(_ domains: Set<HomeInvalidationDomain>) -> HomeSurfaceInvalidationScope {
        HomeSurfaceInvalidationScope(domains: domains, requiresFullRefresh: false)
    }
}

private nonisolated enum HomeSurfaceInvalidationRouting {
    static func scope(for result: DomainMutationResult) -> HomeSurfaceInvalidationScope? {
        guard result.wroteBusinessFact else { return nil }

        switch result.command.feature {
        case "members":
            switch result.command.action {
            case "profile", "homeVisibility":
                return .entityScoped([.appearance])
            default:
                return .aggregate([.membership])
            }
        case "settings", "privacy":
            return .aggregate([.membership, .economy])
        case "avatar", "petCard":
            return .entityScoped([.appearance])
        case "quickCare", "feeding", "water", "petCare", "petPotty", "catCare", "hygiene", "walks", "weight":
            return .aggregate([.care, .health])
        case "todayFocus", "calendar", "reminders":
            return .aggregate([.schedule])
        case "plants":
            return .aggregate([.plants, .schedule])
        case "petHealth", "petMedication", "humanMedication", "humanHealth", "documents":
            return .aggregate([.health])
        case "expenses", "moments":
            return .aggregate([.records])
        case "economy", "shop", "achievements", "wishlist", "bondVault", "familyTasks":
            return .aggregate([.economy])
        case "photos", "milestones", "insurance", "workouts", "humanNotes":
            // None of these values are consumed by the current Home snapshot.
            return nil
        default:
            // Unknown commands are intentionally conservative. New features
            // must either declare a Home domain above or trigger one safe pass.
            return .aggregate([.unknown])
        }
    }
}

@MainActor
final class ReadModelRevisionCenter: ObservableObject {
    /// App-wide default center. Default-constructed publishers must converge here;
    /// a publisher wrapping any other ad-hoc center is invisible to UI observers.
    static let shared = ReadModelRevisionCenter()

    @Published private(set) var homeRevision = HomeRevision()
    @Published private(set) var homeSurfaceInvalidation = HomeSurfaceInvalidationToken.empty
    @Published private(set) var walletProjectionRevision = HomeRevision()
    @Published private(set) var lastMutation: DomainMutationResult?
    private(set) var lastCoconutRewardEvent: OhanaCoconutRewardEvent?

    private let domainMutationSubject = PassthroughSubject<DomainMutationResult, Never>()
    private let coconutRewardSubject = PassthroughSubject<OhanaCoconutRewardEvent, Never>()
    private var nextHomeSurfaceInvalidationValue = 0
    private var homeDomainInvalidationValues: [HomeInvalidationDomain: Int] = [:]

    init() {}

    var homeRevisionUpdates: AnyPublisher<HomeRevision, Never> {
        $homeRevision.eraseToAnyPublisher()
    }

    var homeSurfaceInvalidationUpdates: AnyPublisher<HomeSurfaceInvalidationToken, Never> {
        $homeSurfaceInvalidation.eraseToAnyPublisher()
    }

    var walletProjectionUpdates: AnyPublisher<HomeRevision, Never> {
        $walletProjectionRevision.eraseToAnyPublisher()
    }

    var domainMutationEvents: AnyPublisher<DomainMutationResult, Never> {
        domainMutationSubject.eraseToAnyPublisher()
    }

    var coconutRewardEvents: AnyPublisher<OhanaCoconutRewardEvent, Never> {
        coconutRewardSubject.eraseToAnyPublisher()
    }

    func publish(_ result: DomainMutationResult) {
        lastMutation = result
        domainMutationSubject.send(result)
        homeRevision.advance(for: result.command)
        if let scope = HomeSurfaceInvalidationRouting.scope(for: result) {
            nextHomeSurfaceInvalidationValue &+= 1
            let domainRevisions = nextHomeDomainInvalidationValues(for: scope.domains)
            homeSurfaceInvalidation = HomeSurfaceInvalidationToken(
                surface: .home,
                value: nextHomeSurfaceInvalidationValue,
                domains: scope.domains,
                domainRevisions: domainRevisions,
                affectedEntityIDs: result.affectedEntityIDs,
                requiresFullRefresh: scope.requiresFullRefresh,
                changedAt: result.occurredAt,
                lastCommand: result.command
            )
        }
        AppPerformanceMonitor.shared.record(
            result.wroteBusinessFact ? "domain_command_success" : "domain_command_noop",
            valueMS: 0,
            note: result.note ?? "\(result.command)"
        )
    }

    private func nextHomeDomainInvalidationValues(
        for domains: Set<HomeInvalidationDomain>
    ) -> [HomeInvalidationDomain: Int] {
        var values: [HomeInvalidationDomain: Int] = [:]
        for domain in domains {
            let nextValue = (homeDomainInvalidationValues[domain] ?? 0) &+ 1
            homeDomainInvalidationValues[domain] = nextValue
            values[domain] = nextValue
        }
        return values
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

    func publishWalletProjection(affectedEntityIDs: Set<UUID>, note: String) {
        walletProjectionRevision.advance(
            for: .command(
                "economy",
                "walletProjection",
                ["affected": String(affectedEntityIDs.count)]
            )
        )
        AppPerformanceMonitor.shared.record(
            "wallet_projection_update",
            valueMS: 0,
            note: note
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
