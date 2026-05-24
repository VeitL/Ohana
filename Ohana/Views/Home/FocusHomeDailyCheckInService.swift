//
//  FocusHomeDailyCheckInService.swift
//  Ohana
//
//  Header streak and lightweight daily check-in bookkeeping for the home screen.
//

import Foundation

@MainActor
enum FocusHomeDailyCheckInService {
    static func ensureTodayCheckIn(
        activeHumanId: String,
        rewardTitle: String
    ) {
        let today = CheckInStreakStore.dateString(Date())
        var checkedInDates = CheckInStreakStore.checkedInDates(for: activeHumanId)
        guard !checkedInDates.contains(today) else { return }

        checkedInDates.insert(today)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: activeHumanId)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: rewardTitle)
    }

    static func currentStreak(activeHumanId: String) -> Int {
        CheckInStreakStore.currentStreak(for: activeHumanId)
    }
}
