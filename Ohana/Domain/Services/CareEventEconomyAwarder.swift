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
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus,
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
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus,
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
}
