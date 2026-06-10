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
        now: Date = Date(),
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        revisions providedRevisions: DomainRevisionPublishing? = nil
    ) -> EconomyRewardResult? {
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        let revisions: DomainRevisionPublishing = providedRevisions ?? SharedDomainRevisionPublisher()
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let markerKey = "\(rewardMarkerPrefix).\(normalizedUserKey(householdKey)).\(EconomyDailyBudgetStore.dayKey(for: now))"
        guard !UserDefaults.standard.bool(forKey: markerKey) else { return nil }

        let reward = questManager.awardAction(
            type: .dailyFocusCompletion,
            pet: nil,
            context: context,
            quality: .none,
            date: now
        )
        guard let result = questManager.lastEconomyRewardResult else { return nil }

        careLedger.record(
            occurredAt: now,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .household,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "todayFocusDailyCompletion",
            amountValue: 0,
            amountUnit: "",
            note: "Today Focus 全完成",
            source: .service,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: careLedger.rewardDelta(reward),
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: result.metadataJSON,
            context: context,
            save: true
        )
        UserDefaults.standard.set(true, forKey: markerKey)
        revisions.publishTodayFocusDailyCompletion(note: "today_focus.daily_completion_reward")
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
