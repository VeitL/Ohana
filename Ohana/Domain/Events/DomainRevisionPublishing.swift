import Combine
import Foundation

@MainActor
protocol DomainRevisionPublishing {
    var homeRevision: HomeRevision { get }
    var homeSurfaceInvalidation: HomeSurfaceInvalidationToken { get }
    var walletProjectionRevision: HomeRevision { get }
    var lastMutation: DomainMutationResult? { get }
    var homeRevisionUpdates: AnyPublisher<HomeRevision, Never> { get }
    var homeSurfaceInvalidationUpdates: AnyPublisher<HomeSurfaceInvalidationToken, Never> { get }
    var walletProjectionUpdates: AnyPublisher<HomeRevision, Never> { get }
    var coconutRewardEvents: AnyPublisher<OhanaCoconutRewardEvent, Never> { get }

    func publish(_ result: DomainMutationResult)
    func publish(_ result: DomainMutationResult, token: CareDerivationToken)
    func publishDomainMutation(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool,
        note: String,
        token: CareDerivationToken
    )
    func publishWalletProjection(affectedEntityIDs: Set<UUID>, note: String)
    func publishCoconutRewardFeedback(_ event: OhanaCoconutRewardEvent)
    func publishFailure(command: DomainCommand, error: Error)
}

@MainActor
final class SharedDomainRevisionPublisher: DomainRevisionPublishing {
    private let center: ReadModelRevisionCenter

    init() {
        // Converge on the app-wide center: a fresh center here would swallow every
        // publish from convenience-constructed executors (wallet spends went dark this way).
        center = .shared
    }

    init(center: ReadModelRevisionCenter) {
        self.center = center
    }

    var homeRevision: HomeRevision {
        center.homeRevision
    }

    var homeSurfaceInvalidation: HomeSurfaceInvalidationToken {
        center.homeSurfaceInvalidation
    }

    var walletProjectionRevision: HomeRevision {
        center.walletProjectionRevision
    }

    var lastMutation: DomainMutationResult? {
        center.lastMutation
    }

    var homeRevisionUpdates: AnyPublisher<HomeRevision, Never> {
        center.homeRevisionUpdates
    }

    var homeSurfaceInvalidationUpdates: AnyPublisher<HomeSurfaceInvalidationToken, Never> {
        center.homeSurfaceInvalidationUpdates
    }

    var walletProjectionUpdates: AnyPublisher<HomeRevision, Never> {
        center.walletProjectionUpdates
    }

    var coconutRewardEvents: AnyPublisher<OhanaCoconutRewardEvent, Never> {
        center.coconutRewardEvents
    }

    func publish(_ result: DomainMutationResult) {
        center.publish(result)
    }

    func publish(_ result: DomainMutationResult, token _: CareDerivationToken) {
        publish(result)
    }

    func publishDomainMutation(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool,
        note: String,
        token _: CareDerivationToken
    ) {
        center.publishDomainMutation(
            command: command,
            affectedEntityIDs: affectedEntityIDs,
            wroteBusinessFact: wroteBusinessFact,
            note: note
        )
    }

    func publishCoconutRewardFeedback(_ event: OhanaCoconutRewardEvent) {
        center.publishCoconutRewardFeedback(event)
    }

    func publishWalletProjection(affectedEntityIDs: Set<UUID>, note: String) {
        center.publishWalletProjection(affectedEntityIDs: affectedEntityIDs, note: note)
    }

    func publishFailure(command: DomainCommand, error: Error) {
        center.publishFailure(command: command, error: error)
    }
}
