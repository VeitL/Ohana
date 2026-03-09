//
//  StreakRewardManager.swift
//  Ohana
//
//  TASK C — Streak 质量奖励系统
//  连续打卡里程碑（7/30/100/365天）发放椰子，防重复领取
//

import Foundation
import SwiftData
import Observation

@Observable
final class StreakRewardManager {
    static let shared = StreakRewardManager()

    // 里程碑配置：(连续天数, 奖励椰子)
    static let milestones: [(days: Int, reward: Int)] = [
        (7,   20),
        (30,  100),
        (100, 500),
        (365, 2000),
    ]

    // 触发回调：UI 可监听此值来显示 Toast
    var lastMilestone: (days: Int, reward: Int)? = nil

    private static let defaults = UserDefaults.standard
    private static let rewardsKey = "streakRewards_claimed"  // { "petId_days": timestamp }

    private init() {}

    // MARK: - 检查并发放 Streak 里程碑奖励

    /// 每次打卡成功后调用
    func checkAndAward(pet: Pet) {
        let streak = pet.currentStreak
        for milestone in Self.milestones {
            guard streak >= milestone.days else { continue }
            let key = "\(pet.id.uuidString)_\(milestone.days)"
            var claimed = Self.defaults.dictionary(forKey: Self.rewardsKey) ?? [:]
            if claimed[key] != nil { continue }  // 已领取

            // 记录领取
            claimed[key] = Date().timeIntervalSince1970
            Self.defaults.set(claimed, forKey: Self.rewardsKey)

            // 发放椰子
            QuestManager.shared.addCoconuts(
                milestone.reward,
                emoji: "🔥",
                title: "\(milestone.days) 天连击！+\(milestone.reward)🥥",
                actorId: pet.id.uuidString,
                actorName: pet.name
            )

            DispatchQueue.main.async {
                self.lastMilestone = milestone
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
}
