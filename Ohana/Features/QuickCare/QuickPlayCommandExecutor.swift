//
//  QuickPlayCommandExecutor.swift
//  Ohana
//
//  Write-side boundary for the Quick Play detail flow.
//

import Foundation
import SwiftData

struct QuickPlayCommandResult: Equatable {
    let petID: UUID
    let logID: UUID
    let coconutDelta: Int
    let humanReward: Int
    let petReward: Int
}

@MainActor
private func fetchQuickPlayModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "QuickPlayCommandExecutor failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

@MainActor
struct QuickPlayCommandExecutor {
    private let context: ModelContext
    private let careEvents: CareEventRecording
    private let derivations: CareDerivationExecutor

    init(context: ModelContext) {
        self.init(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter)
        )
    }

    init(
        context: ModelContext,
        careEvents: CareEventRecording,
        revisions: DomainRevisionPublishing
    ) {
        self.context = context
        self.careEvents = careEvents
        derivations = CareDerivationExecutor(revisions: revisions)
    }

    func recordPlay(
        petID: UUID,
        executorId: String?,
        rewardTitle: String,
        date: Date = Date()
    ) -> QuickPlayCommandResult? {
        guard let pet = fetchPet(id: petID), EconomyWalletWritePolicy.canWrite(pet) else {
            derivations.derive(
                .noOp(
                    command: .quickCare(entityID: petID, action: CareType.play.rawValue),
                    affectedEntityIDs: [petID],
                    note: "quickPlay.missingPet"
                )
            )
            return nil
        }

        let reward = QuestManager.OhanaActionType.general(
            humanReward: 3,
            petReward: 2,
            emoji: "🎾",
            title: rewardTitle
        )
        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: .play,
            amountMl: 0,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: .none,
            date: date,
            source: .quickAction,
            createsLinkedPottyLog: false
        )
        guard recorded.result.didWriteFact else {
            derivations.derive(
                .noOp(
                    command: .quickCare(entityID: pet.id, action: CareType.play.rawValue),
                    affectedEntityIDs: [pet.id],
                    note: "quickPlay.factNoop"
                )
            )
            return nil
        }
        let derivation = derivations.derive(
            .active(
                disposition: recorded.result.disposition,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: pet.id,
                    logIDs: [recorded.result.logID],
                    factDate: date,
                    operationDate: date
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: .quickCare(entityID: pet.id, action: CareType.play.rawValue),
                    affectedEntityIDs: [pet.id, recorded.result.logID],
                    note: "quickPlay.record"
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: recorded.reward.humanGot,
                    petDelta: recorded.reward.petGot
                ),
                noopNote: "quickPlay.factOnly"
            )
        )
        guard derivation.isUserVisibleSuccess else { return nil }
        return QuickPlayCommandResult(
            petID: pet.id,
            logID: recorded.result.logID,
            coconutDelta: recorded.result.coconutDelta,
            humanReward: recorded.reward.humanGot,
            petReward: recorded.reward.petGot
        )
    }

    private func fetchPet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchQuickPlayModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch pet"
        ).first
    }
}
