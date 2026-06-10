//
//  QuestManager+Awards.swift
//  Ohana
//

import Foundation
import SwiftData
import UIKit

extension QuestManager {
    // MARK: - 核心分发方法（新版，接受 OhanaActionType）
    /// - Parameters:
    ///   - type: OhanaActionType，携带奖励规则
    ///   - pet: 关联宠物（可空）
    ///   - context: ModelContext，用于 fetch Human 并 save
    @discardableResult
    func awardAction(
        type: OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QualityBonus = .none,
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        if pet?.hasPassedAway == true {
            lastEconomyRewardResult = .empty
            return (0, 0)
        }

        // ── 1. 人类账户（从 context fetch，安全降级）
        let human = currentActiveHuman(context: context)
        let consumesBoost = isDoubleRewardBoostActive()
        let isCoolingDown = isOnCooldown(petId: pet?.id, type: type)
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: pet)
        let result = CoconutEconomyPolicyV2.reward(
            for: type,
            quality: quality,
            isOnCooldown: isCoolingDown,
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            hasPetAccount: pet != nil,
            date: date,
            forcedLuck: consumesBoost ? .golden : nil
        )
        lastEconomyRewardResult = result

        let finalHuman = result.humanCoconuts
        let finalPet = result.petCoconuts
        // ── 2. 钱包流水（拆分：宠物和人类各生成独立条目）
        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        var baseTitle = type.title(pet: pet)
        if let badge = quality.badgeLabel {
            baseTitle += " · \(badge)"
        }
        if result.luck != .none {
            baseTitle += result.luck == .golden ? " · 金色幸运" : " · 小幸运"
        }

        var walletDeltas: [CoconutWalletDelta] = []
        if let p = pet, finalPet > 0 {
            walletDeltas.append(.pet(
                p,
                delta: finalPet,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: logEmoji,
                actorId: p.id.uuidString,
                actorName: p.name,
                subjectKind: .pet,
                subjectId: p.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }
        if let h = human, finalHuman > 0 {
            walletDeltas.append(.human(
                h,
                delta: finalHuman,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: "🥥",
                actorId: h.id.uuidString,
                actorName: h.name,
                subjectKind: .human,
                subjectId: h.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

        // ── 3. 持久化（同一个 ModelContext 事务）
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
            postEconomyFeedback(result, type: type, title: baseTitle, actorId: pet?.id.uuidString ?? human?.id.uuidString, actorName: pet?.name ?? human?.name)
            if case .walk = type, let humanId = human?.id.uuidString {
                recordWalkRewardToday(finalHuman, humanId: humanId)
            }
            // 记录冷却时间戳（持久化成功后才记录；冷却内补记不延长窗口）
            if !isCoolingDown {
                recordCooldown(petId: pet?.id, type: type)
            }
            // TASK C: 检查 Streak 里程碑奖励
            if let pet { streakRewards.checkAndAward(pet: pet, questManager: self) }
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] SwiftData save failed; rolled back: \(error.localizedDescription)", category: "Economy")
            #endif
        }
        return (finalHuman, finalPet)
    }

    /// 多宠共同照护奖励：人类奖励只发一次，每只在世目标宠物各自获得成长椰子。
    @MainActor
    @discardableResult
    func awardSharedCareAction(
        type: OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QualityBonus = .none,
        title: String? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let livePets = pets.filter { !$0.hasPassedAway }
        guard !livePets.isEmpty else { return (0, 0) }

        let human = currentActiveHuman(context: context)
        let consumesBoost = isDoubleRewardBoostActive()
        let isCoolingDown = livePets.allSatisfy { isOnCooldown(petId: $0.id, type: type) }
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: livePets)
        let result = CoconutEconomyPolicyV2.sharedReward(
            for: type,
            targetCount: livePets.count,
            quality: quality,
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

        let petTotal = petAwards.reduce(0, +)
        let humanTotal = human == nil ? 0 : result.humanCoconuts

        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        let petNames = livePets.prefix(3).map(\.name).joined(separator: "、") + (livePets.count > 3 ? " 等\(livePets.count)只" : "")
        var sharedTitle = title ?? "共同照护 · \(petNames)"
        if result.luck != .none {
            sharedTitle += result.luck == .golden ? " · 金色幸运" : " · 小幸运"
        }

        var walletDeltas: [CoconutWalletDelta] = []
        for (index, pet) in livePets.enumerated() where petAwards[index] > 0 {
            walletDeltas.append(.pet(
                pet,
                delta: petAwards[index],
                entryKind: .reward,
                source: .careEvent,
                title: sharedTitle,
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
                title: result.luck == .golden ? "金色幸运共同照护奖励" : "共同照护奖励",
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

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
            postEconomyFeedback(
                result,
                type: type,
                title: sharedTitle,
                actorId: human?.id.uuidString ?? livePets.first?.id.uuidString,
                actorName: human?.name ?? livePets.first?.name
            )
            for pet in livePets {
                if !isOnCooldown(petId: pet.id, type: type) {
                    recordCooldown(petId: pet.id, type: type)
                }
                streakRewards.checkAndAward(pet: pet, questManager: self)
            }
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] shared care save failed: \(error.localizedDescription)", category: "Economy")
            #endif
        }

        return (humanTotal, petTotal)
    }
}
