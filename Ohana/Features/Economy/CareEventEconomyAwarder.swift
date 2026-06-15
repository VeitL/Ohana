//
//  CareEventEconomyAwarder.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
final class StaticCareEventEconomyAwarder: CareEventEconomyAwarding {
    private let questManager: QuestManager
    private let oasisRewards: OasisRewardManaging

    init(questManager: QuestManager, oasisRewards: OasisRewardManaging? = nil) {
        self.questManager = questManager
        self.oasisRewards = oasisRewards ?? StaticOasisRewardManager(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: questManager
        )
    }

    func awardCareAction(
        type: DomainCareRewardAction,
        pet: Pet?,
        context: ModelContext,
        quality: DomainCareRewardQuality,
        date: Date,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int) {
        let reward = EconomyRewardDiscipline.awardCareAction(
            type: type,
            pet: pet,
            context: context,
            quality: quality,
            date: date,
            executorId: executorId,
            questManager: questManager
        )
        oasisRewards.rewardFeaturedCritterFromCare(type: type, context: context)
        return reward
    }

    func awardSharedCareAction(
        type: DomainCareRewardAction,
        pets: [Pet],
        context: ModelContext,
        quality: DomainCareRewardQuality,
        title: String?,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int) {
        let reward = EconomyRewardDiscipline.awardSharedCareAction(
            type: type,
            pets: pets,
            context: context,
            quality: quality,
            title: title,
            executorId: executorId,
            questManager: questManager
        )
        oasisRewards.rewardFeaturedCritterFromCare(type: type, context: context)
        return reward
    }

    func rewardMetadata(for reward: (humanGot: Int, petGot: Int)?) -> String {
        guard let reward else { return "" }
        if let result = questManager.lastEconomyRewardResult,
           result.humanCoconuts == max(0, reward.humanGot),
           result.petCoconuts == max(0, reward.petGot) {
            return result.metadataJSON
        }
        return ""
    }

    func recordFirstMeal(actorId: String?, context: ModelContext) {
        questManager.recordFirstMeal(actorId: actorId, context: context)
    }

    func clearCooldown(petId: UUID?, type: DomainCareRewardAction) {
        questManager.clearCooldown(petId: petId, type: type)
    }

    func refreshProjectionAfterRollback(context: ModelContext) {
        questManager.wallet.refreshQuestProjection(context: context, manager: questManager)
    }
}
