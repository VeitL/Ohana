//
//  QuestManager+FeedbackAndMilestones.swift
//  Ohana
//

import Foundation
import SwiftData
import UIKit

extension QuestManager {
    func postEconomyFeedback(
        _ result: EconomyRewardResult,
        type: OhanaActionType,
        title: String,
        actorId: String?,
        actorName: String?
    ) {
        guard result.growthXP > 0 || result.totalCoconuts > 0 else { return }
        let entry = CoconutLogEntry(
            emoji: result.luck == .golden ? "🎁" : type.emoji,
            title: result.feedbackMessage.isEmpty ? title : result.feedbackMessage,
            amount: result.totalCoconuts,
            actorId: actorId,
            actorName: actorName,
            growthXP: result.growthXP,
            economyReason: result.reason,
            budgetStage: result.budgetStage.rawValue,
            feedbackMessage: result.feedbackMessage
        )
        publishCoconutRewardFeedback(for: entry)
    }

    func appendLog(_ entry: CoconutLogEntry, postsRewardFeedback: Bool = true) {
        coconutLogs.insert(entry, at: 0)
        if coconutLogs.count > 200 { coconutLogs = Array(coconutLogs.prefix(200)) }
        if entry.amount > 0 || (entry.growthXP ?? 0) > 0, postsRewardFeedback {
            publishCoconutRewardFeedback(for: entry)
        }
        publishCoconutProjectionRevision(note: "questManager.coconutLog.append")
        // Wallet history persistence is handled by CoconutLedgerEntry.
    }

    func publishCoconutRewardFeedback(for entry: CoconutLogEntry) {
        revisions.publishCoconutRewardFeedback(OhanaCoconutRewardEvent(entry: entry))
    }

    func publishCoconutProjectionRevision(note: String) {
        revisions.publishNoop(
            command: .settingsCoconutBalance(humanID: nil, amount: coconutCount),
            affectedEntityIDs: [],
            note: note
        )
    }

    static func distribute(_ total: Int, count: Int) -> [Int] {
        guard total > 0, count > 0 else { return Array(repeating: 0, count: max(0, count)) }
        let base = total / count
        let remainder = total % count
        return (0 ..< count).map { index in
            base + (index < remainder ? 1 : 0)
        }
    }

    func makeLedgerAudit(pets: [Pet], humans: [Human]) -> CoconutLedgerAudit {
        CoconutLedgerAudit.evaluate(
            islandCount: coconutCount,
            logs: coconutLogs,
            petBalances: pets.map(\.coconutBalance),
            humanBalances: humans.map(\.coconutBalance)
        )
    }

    /// 完成喂食任务时调用（第一次记录喂食）
    func recordFirstMeal(actorId: String? = nil, actorName: String? = nil, context: ModelContext? = nil) {
        guard !isFirstMealRecorded else { return }
        guard recordSpecialCoconutReward(
            15,
            emoji: "🍖",
            title: "首次喜食打卡奖励",
            actorId: actorId,
            actorName: actorName,
            rewardKey: "welcome:firstMeal",
            context: context
        ) else { return }
        isFirstMealRecorded = true
        persistQuestFlags()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 完成主题颜色设置任务时调用
    func recordThemeColorSet(actorId: String? = nil, actorName: String? = nil, context: ModelContext? = nil) {
        guard !isThemeColorSet else { return }
        guard recordSpecialCoconutReward(
            10,
            emoji: "🎨",
            title: "设置家人主题色",
            actorId: actorId,
            actorName: actorName,
            rewardKey: "welcome:themeColor",
            context: context
        ) else { return }
        isThemeColorSet = true
        persistQuestFlags()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - 人宠联动奖励

    /// 主人每日步数达标奖励（≥8000步 → +10椰子）
    /// 幂等：同一天只发放一次
    /// 返回值：是否成功发放（true 表示本次触发了奖励）
    @discardableResult
    func recordDailyStepGoal(
        steps: Int,
        goal: Int = 8000,
        actorId: String? = nil,
        actorName: String? = nil,
        context: ModelContext? = nil
    ) -> Bool {
        guard steps >= goal else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = Self.defaults.object(forKey: Keys.stepRewardDate) as? Date
        if let last = lastDate, Calendar.current.isDate(last, inSameDayAs: today) {
            return false // 今天已发放
        }
        guard recordSpecialCoconutReward(
            10,
            emoji: "🚶",
            title: "今日步数达标奖励",
            actorId: actorId,
            actorName: actorName,
            rewardKey: "dailyStepGoal:\(EconomyDailyBudgetStore.dayKey(for: today))",
            context: context
        ) else { return false }
        Self.defaults.set(today, forKey: Keys.stepRewardDate)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    /// 人宠同步行走联动奖励（主人步数距离 ≥ 宠物当日遛狗距离，解锁「同甘共苦」）
    /// 幂等：同一天只发放一次
    /// - Parameter humanDistanceKm: 主人今日 HealthKit 步行距离
    /// - Parameter petWalkDistanceKm: 宠物今日遛狗距离之和
    /// 返回值：是否成功触发联动
    @discardableResult
    func recordBondedWalk(
        humanDistanceKm: Double,
        petWalkDistanceKm: Double,
        actorId: String? = nil,
        actorName: String? = nil,
        context: ModelContext? = nil
    ) -> Bool {
        guard petWalkDistanceKm > 0.1, humanDistanceKm >= petWalkDistanceKm else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = Self.defaults.object(forKey: Keys.bondedDate) as? Date
        if let last = lastDate, Calendar.current.isDate(last, inSameDayAs: today) {
            return false // 今天已触发
        }
        guard recordSpecialCoconutReward(
            5,
            emoji: "🐾",
            title: "人宠同行奖励",
            actorId: actorId,
            actorName: actorName,
            rewardKey: "bondedWalk:\(EconomyDailyBudgetStore.dayKey(for: today))",
            context: context
        ) else { return false }
        Self.defaults.set(today, forKey: Keys.bondedDate)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        return true
    }

    @discardableResult
    private func recordSpecialCoconutReward(
        _ amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        rewardKey: String,
        context: ModelContext?
    ) -> Bool {
        let writeContext = context ?? ModelContext(SharedModelContainer.make())
        do {
            let awarded = try stageSpecialCoconutReward(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
                source: .service,
                sourceModelName: "QuestSpecialReward",
                sourceModelId: rewardKey,
                metadataJSON: "{\"kind\":\"questSpecialReward\",\"rewardKey\":\"\(rewardKey)\"}",
                transactionKey: "questSpecial:\(rewardKey):\(actorId ?? "system")",
                context: writeContext
            )
            guard awarded == amount else { return false }
            try writeContext.save()
            return true
        } catch {
            writeContext.rollback()
            wallet.refreshQuestProjection(context: writeContext, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] special coconut reward save failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return false
        }
    }

    // MARK: - task38: 打卡 → 自动完成今日同类型 Reminder（不重复发椰子）

    /// 打卡后调用：在 modelContext 里查找今日该宠物匹配类型的 pending Reminder，标记为 completed
    /// - Parameters:
    ///   - petId: 宠物 UUID
    ///   - careType: 打卡类型关键词（如 "喂食" "喂水" "铲屎" "遛"）
    ///   - context: SwiftData ModelContext
    func autoCompleteReminders(petId: UUID, careKeyword: String, context: ModelContext) {
        let petIdStr = petId.uuidString
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        // 查找今日所有 Reminder
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { r in
                r.status == "pending" &&
                    r.scheduledAt >= today &&
                    r.scheduledAt < tomorrow
            }
        )
        let reminders: [Reminder]
        do {
            reminders = try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[QuestManager] failed to fetch reminders for reward auto-complete: \(error.localizedDescription)",
                category: "Economy"
            )
            return
        }
        // 找到关联该宠物且标题包含关键词的 Event -> Reminder
        for reminder in reminders {
            guard let event = reminder.event,
                  event.relatedEntityId == petIdStr,
                  event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet" else { continue }
            let title = event.title
            let keyword = careKeyword
            guard title.contains(keyword) else { continue }
            reminder.statusEnum = .completed
            reminder.completedAt = Date()
        }
        do {
            try context.save()
        } catch {
            OhanaLog.warning(
                "[QuestManager] failed to save reward auto-completed reminders: \(error.localizedDescription)",
                category: "Economy"
            )
        }
    }

    /// 查询今日步数奖励是否已领取
    var hasReceivedStepRewardToday: Bool {
        guard let lastDate = Self.defaults.object(forKey: Keys.stepRewardDate) as? Date else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// 查询今日人宠联动奖励是否已领取
    var hasReceivedBondedRewardToday: Bool {
        guard let lastDate = Self.defaults.object(forKey: Keys.bondedDate) as? Date else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }
}
