//
//  TodayFocusEconomyService.swift
//  Ohana
//
//  V2 economy reward for clearing the daily Today Focus list.
//

import Foundation
import SwiftData

@MainActor
enum TodayFocusEconomyService {
    private static let rewardMarkerPrefix = "economyV2.todayFocusCompletion"

    @discardableResult
    static func awardDailyCompletionIfNeeded(
        context: ModelContext,
        executorId: String?,
        now: Date = Date()
    ) -> EconomyRewardResult? {
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let markerKey = "\(rewardMarkerPrefix).\(normalizedUserKey(householdKey)).\(EconomyDailyBudgetStore.dayKey(for: now))"
        guard !UserDefaults.standard.bool(forKey: markerKey) else { return nil }

        let reward = QuestManager.shared.awardAction(
            type: .dailyFocusCompletion,
            pet: nil,
            context: context,
            quality: .none
        )
        guard let result = QuestManager.shared.lastEconomyRewardResult else { return nil }

        CareLedgerService.record(
            occurredAt: now,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .household,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "todayFocusDailyCompletion",
            note: "Today Focus 全完成",
            source: .service,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: result.metadataJSON,
            context: context
        )
        UserDefaults.standard.set(true, forKey: markerKey)
        ReadModelRevisionCenter.shared.publishDomainMutation(
            command: .todayFocus(entityID: UUID(), action: "dailyCompletionReward"),
            affectedEntityIDs: [],
            wroteBusinessFact: true,
            note: "today_focus.daily_completion_reward"
        )
        return result
    }

    static func resetDailyCompletionMarker(userKey: String, date: Date = Date()) {
        let day = EconomyDailyBudgetStore.dayKey(for: date)
        UserDefaults.standard.removeObject(
            forKey: "\(rewardMarkerPrefix).\(normalizedUserKey(userKey)).\(day)"
        )
        UserDefaults.standard.removeObject(
            forKey: "\(rewardMarkerPrefix).\(normalizedUserKey(CoconutEconomyPolicyV2.householdBudgetKey())).\(day)"
        )
    }

    private static func normalizedUserKey(_ value: String) -> String {
        value.isEmpty ? "system" : value
    }
}
