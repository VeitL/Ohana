//
//  FocusHomeDailyCheckInService.swift
//  Ohana
//
//  Header streak helpers for the home screen.
//

import Foundation

@MainActor
enum FocusHomeDailyCheckInService {
    static func currentStreak(activeHumanId: String) -> Int {
        CheckInStreakStore.currentStreak(for: activeHumanId)
    }
}
