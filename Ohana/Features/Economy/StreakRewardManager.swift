//
//  StreakRewardManager.swift
//  Ohana
//
//  TASK C — Streak 质量奖励系统
//  连续打卡里程碑（7/30/100/365天）发放椰子，防重复领取
//

import Foundation
import Observation
import SwiftData

@Observable
final class StreakRewardManager {
    // 里程碑配置：(连续天数, 奖励椰子)
    static let milestones: [(days: Int, reward: Int)] = [
        (7, 20),
        (30, 100),
        (100, 500),
        (365, 2000)
    ]

    // 触发回调：UI 可监听此值来显示 Toast
    var lastMilestone: (days: Int, reward: Int)?

    private static let defaults = UserDefaults.standard
    private static let rewardsKey = "streakRewards_claimed" // { "petId_days": timestamp }

    init() {}

    // MARK: - 检查并发放 Streak 里程碑奖励

    /// 每次打卡成功后调用
    func checkAndAward(pet: Pet, questManager: QuestManager, context: ModelContext) {
        let streak = pet.currentStreak
        var claimed = Self.defaults.dictionary(forKey: Self.rewardsKey) ?? [:]
        for milestone in Self.milestones {
            guard streak >= milestone.days else { continue }
            let key = Self.familyClaimKey(days: milestone.days)
            if Self.hasClaimed(milestone.days, in: claimed) { continue }

            let awarded = questManager.awardStreakMilestone(
                days: milestone.days,
                requestedReward: milestone.reward,
                pet: pet,
                context: context
            )
            guard awarded > 0 else { continue }

            // 记录领取：家庭级去重，旧版 petId_days 领取记录也视为已领取。
            claimed[key] = Date().timeIntervalSince1970
            Self.defaults.set(claimed, forKey: Self.rewardsKey)

            DispatchQueue.main.async {
                self.lastMilestone = (milestone.days, awarded)
                // 3 秒后自动清除
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.lastMilestone = nil
                }
            }
        }
    }

    // MARK: - 下一个里程碑（用于 UI 提示）

    func nextMilestone(currentStreak: Int) -> (days: Int, reward: Int, remaining: Int)? {
        for milestone in Self.milestones {
            if currentStreak < milestone.days {
                return (milestone.days, milestone.reward, milestone.days - currentStreak)
            }
        }
        return nil
    }

    private static func familyClaimKey(days: Int) -> String {
        "family_\(days)"
    }

    private static func hasClaimed(_ days: Int, in claimed: [String: Any]) -> Bool {
        claimed[familyClaimKey(days: days)] != nil || claimed.keys.contains { $0.hasSuffix("_\(days)") }
    }
}

extension QuestManager {
    @discardableResult
    func awardStreakMilestone(
        days: Int,
        requestedReward: Int,
        pet: Pet,
        context: ModelContext,
        date: Date = Date()
    ) -> Int {
        guard requestedReward > 0 else { return 0 }
        let human = currentActiveHuman(context: context)
        let awarded = requestedReward
        let title = "\(days) 天连击！+\(awarded)🥥"
        let result = EconomyRewardResult(
            growthXP: 0,
            humanCoconuts: awarded,
            petCoconuts: 0,
            bonusCoconuts: 0,
            luckyCoconuts: 0,
            budgetMultiplier: 1,
            budgetStage: .normal,
            reason: "specialEvent",
            actionKey: "streak_\(days)",
            isOnCooldown: false,
            baseGrowthXP: 0,
            baseCoconuts: awarded,
            luck: .none
        )
        let delta: CoconutWalletDelta = if let human {
            .human(
                human,
                delta: awarded,
                entryKind: .reward,
                source: .service,
                title: title,
                emoji: "🔥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                sourceModelName: "StreakRewardManager",
                sourceModelId: "family_\(days)",
                metadataJSON: result.metadataJSON,
                transactionKey: "streak:family:\(days)"
            )
        } else {
            .system(
                delta: awarded,
                entryKind: .reward,
                source: .service,
                title: title,
                emoji: "🔥",
                actorId: pet.id.uuidString,
                actorName: pet.name,
                sourceModelName: "StreakRewardManager",
                sourceModelId: "family_\(days)",
                metadataJSON: result.metadataJSON,
                transactionKey: "streak:family:\(days)"
            )
        }

        do {
            try wallet.apply(
                deltas: [delta],
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: true,
                projectionManager: self
            )
            try context.save()
            postEconomyFeedback(
                result,
                type: .general(humanReward: awarded, petReward: 0, emoji: "🔥", title: title),
                title: title,
                actorId: human?.id.uuidString ?? pet.id.uuidString,
                actorName: human?.name ?? pet.name
            )
            return awarded
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] streak milestone save failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return 0
        }
    }
}
