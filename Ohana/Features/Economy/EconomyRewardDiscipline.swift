//
//  EconomyRewardDiscipline.swift
//  Ohana
//
//  Shared reward primitive for owner resolution, budget, frozen-wallet,
//  wallet ledger, cooldown, and idempotency discipline.
//

import Foundation
import SwiftData

@MainActor
enum EconomyRewardDiscipline {
    @discardableResult
    static func awardCareAction(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        executorId: String? = nil,
        careObjectKey: UUID? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let questManager = providedQuestManager ?? QuestManager()
        return questManager.awardAction(
            type: type,
            pet: pet,
            context: context,
            quality: quality,
            date: date,
            executorId: executorId,
            careObjectKey: careObjectKey
        )
    }

    @discardableResult
    static func awardSharedCareAction(
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none,
        title: String? = nil,
        executorId: String? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let questManager = providedQuestManager ?? QuestManager()
        return questManager.awardSharedCareAction(
            type: type,
            pets: pets,
            context: context,
            quality: quality,
            title: title,
            executorId: executorId
        )
    }

    @discardableResult
    static func awardNonCareReward(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        executorId: String? = nil,
        questManager providedQuestManager: QuestManager? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let questManager = providedQuestManager ?? QuestManager()
        return questManager.awardAction(
            type: type,
            pet: pet,
            context: context,
            quality: quality,
            date: date,
            executorId: executorId
        )
    }
}
