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
struct QuickPlayCommandExecutor {
    private let context: ModelContext
    private let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.context = context
        revisionCenter = ReadModelRevisionCenter.shared
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    func recordPlay(
        petID: UUID,
        executorId: String?,
        rewardTitle: String,
        date: Date = Date()
    ) -> QuickPlayCommandResult? {
        guard let pet = fetchPet(id: petID), !pet.hasPassedAway else {
            revisionCenter.publish(
                DomainMutationResult(
                    command: .quickCare(entityID: petID, action: CareType.play.rawValue),
                    affectedEntityIDs: [petID],
                    wroteBusinessFact: false,
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
        let recorded = CareEventService.recordCareFact(
            pet: pet,
            type: .play,
            context: context,
            executorId: executorId,
            reward: reward,
            date: date
        )
        revisionCenter.publish(
            DomainMutationResult(
                command: .quickCare(entityID: pet.id, action: CareType.play.rawValue),
                affectedEntityIDs: [pet.id],
                wroteBusinessFact: true,
                note: "quickPlay.record"
            )
        )
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
        return (try? context.fetch(descriptor))?.first
    }
}
