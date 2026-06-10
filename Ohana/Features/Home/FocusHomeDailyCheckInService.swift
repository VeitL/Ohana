//
//  FocusHomeDailyCheckInService.swift
//  Ohana
//
//  Header streak and lightweight daily check-in bookkeeping for the home screen.
//

import Foundation
import SwiftData

@MainActor
enum FocusHomeDailyCheckInService {
    static func ensureTodayCheckIn(
        activeHumanId: String,
        rewardTitle: String,
        questManager: QuestManager,
        revisions: DomainRevisionPublishing,
        context: ModelContext
    ) {
        let today = CheckInStreakStore.dateString(Date())
        var checkedInDates = CheckInStreakStore.checkedInDates(for: activeHumanId)
        guard !checkedInDates.contains(today) else { return }

        do {
            _ = try questManager.stageSpecialCoconutReward(
                amount: 1,
                emoji: "📅",
                title: rewardTitle,
                actorId: activeHumanId,
                source: .service,
                sourceModelName: "CheckInStreakStore",
                sourceModelId: "\(activeHumanId):\(today)",
                metadataJSON: "{\"kind\":\"homeDailyCheckIn\",\"day\":\"\(today)\"}",
                transactionKey: "dailyCheckIn:\(activeHumanId):\(today)",
                context: context
            )
            try context.save()
        } catch {
            context.rollback()
            questManager.wallet.refreshQuestProjection(context: context, manager: questManager)
            #if DEBUG
                OhanaLog.error("[FocusHomeDailyCheckInService] check-in reward save failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return
        }
        checkedInDates.insert(today)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: activeHumanId)
        let affected = UUID(uuidString: activeHumanId).map { Set([$0]) } ?? []
        revisions.publishDomainMutation(
            command: .dailyCheckIn(humanID: activeHumanId),
            affectedEntityIDs: affected,
            wroteBusinessFact: true,
            note: "home.daily_check_in"
        )
    }

    static func currentStreak(activeHumanId: String) -> Int {
        CheckInStreakStore.currentStreak(for: activeHumanId)
    }
}
