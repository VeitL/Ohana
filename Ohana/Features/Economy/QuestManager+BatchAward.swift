//
//  QuestManager+BatchAward.swift
//  Ohana
//

import Foundation
import SwiftData
import UIKit

extension QuestManager {
    // MARK: - 批量打卡（任务三）

    /// 对多只宠物执行同一类型的打卡，合并计算椰子奖励，统一写一次 CoconutLogEntry
    /// - Parameters:
    ///   - type:    打卡类型（如 .feed / .water / .potty(isLitter:false) 等）
    ///   - pets:    目标宠物数组（跳过已离世的宠物）
    ///   - context: ModelContext，用于写 PetCareLog 和 save
    /// - Returns:   (totalHuman, totalPet) 合并后的总发放椰子数
    @MainActor
    @discardableResult
    func batchAward(
        type: OhanaActionType,
        pets: [Pet],
        context: ModelContext
    ) -> (totalHuman: Int, totalPet: Int) {
        guard !pets.isEmpty else { return (0, 0) }

        let livePets = pets.filter { !$0.hasPassedAway }
        guard !livePets.isEmpty else { return (0, 0) }

        let executorId = activeHumanSelection.currentHumanId
        var human: Human? = nil
        if let executorId {
            human = (try? context.fetch(FetchDescriptor<Human>()))?.first(where: { $0.id.uuidString == executorId })
        }
        let consumesBoost = isDoubleRewardBoostActive()
        let isCoolingDown = livePets.allSatisfy { isOnCooldown(petId: $0.id, type: type) }
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: livePets)
        let result = CoconutEconomyPolicyV2.sharedReward(
            for: type,
            targetCount: livePets.count,
            quality: .none,
            isOnCooldown: isCoolingDown,
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            forcedLuck: consumesBoost ? .golden : nil
        )
        lastEconomyRewardResult = result
        let petAwards = Self.distribute(result.petCoconuts, count: livePets.count)
        let humanTotal = human == nil ? 0 : result.humanCoconuts

        // ── 1. 写 PetCareLog（每只宠物独立一条）
        let careTypeEnum: CareType?
        switch type {
        case .feed:   careTypeEnum = .feeding
        case .water:  careTypeEnum = .watering
        case .general(_, _, _, let t) where t.contains("铲砂") || t.contains("铲屎"):
            careTypeEnum = .litter
        case .general(_, _, _, let t) where t.contains("陪玩") || t.contains("逗玩"):
            careTypeEnum = .play
        default:      careTypeEnum = nil
        }

        for pet in livePets {
            if let ct = careTypeEnum {
                let log = PetCareLog(type: ct, pet: pet, executorId: executorId)
                context.insert(log)
            } else if case .potty = type {
                let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: executorId)
                context.insert(log)
            }
        }

        // ── 2. 钱包账户（人类只发一次，不乘以宠物数量）
        let petTotal = petAwards.reduce(0, +)

        // ── 3. 钱包流水
        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        let petNames = livePets.prefix(3).map(\.name).joined(separator: "、")
            + (livePets.count > 3 ? " 等\(livePets.count)只" : "")
        var baseTitle = "一键全家\(type.emoji) · \(petNames)"
        if result.luck != .none {
            baseTitle += result.luck == .golden ? " · 金色幸运" : " · 小幸运"
        }
        var walletDeltas: [CoconutWalletDelta] = []
        for (index, pet) in livePets.enumerated() where petAwards[index] > 0 {
            walletDeltas.append(.pet(
                pet,
                delta: petAwards[index],
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: logEmoji,
                actorId: pet.id.uuidString,
                actorName: pet.name,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }
        if let human, humanTotal > 0 {
            walletDeltas.append(.human(
                human,
                delta: humanTotal,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

        // ── 4. 持久化
        do {
            try wallet.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: true,
                projectionManager: self
            )
            try context.save()
            if consumesBoost {
                clearDoubleRewardBoost()
            }
            EconomyDailyBudgetStore.commit(result, householdKey: budgetKeys.household, memberKey: budgetKeys.member, careObjectKeys: objectKeys)
            livePets.forEach { pet in
                if !isOnCooldown(petId: pet.id, type: type) {
                    recordCooldown(petId: pet.id, type: type)
                }
                streakRewards.checkAndAward(pet: pet, questManager: self)
            }
            postEconomyFeedback(
                result,
                type: type,
                title: baseTitle,
                actorId: human?.id.uuidString ?? "batch",
                actorName: human?.name ?? "全家打卡"
            )
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
            print("❌ [batchAward] save 失败: \(error)")
            #endif
        }

        // 震动反馈
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return (humanTotal, petTotal)
    }
}
