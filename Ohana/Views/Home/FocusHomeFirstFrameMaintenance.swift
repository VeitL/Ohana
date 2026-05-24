//
//  FocusHomeFirstFrameMaintenance.swift
//  Ohana
//
//  Defers non-visual startup bookkeeping until after the first home frame.
//

import Foundation

@MainActor
enum FocusHomeFirstFrameMaintenance {
    static func runAfterFirstFrame(
        activeHumanId: String,
        rewardTitle: String,
        updateHeaderStreak: @escaping (Int) -> Void,
        syncWalkSurfaceVisibility: @escaping () -> Void,
        prepareWalletTapFeedback: @escaping () -> Void
    ) {
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            refreshDailyCheckIn(
                activeHumanId: activeHumanId,
                rewardTitle: rewardTitle,
                updateHeaderStreak: updateHeaderStreak
            )
            syncWalkSurfaceVisibility()
            prepareWalletTapFeedback()
        }
    }

    static func refreshDailyCheckIn(
        activeHumanId: String,
        rewardTitle: String,
        updateHeaderStreak: (Int) -> Void
    ) {
        FocusHomeDailyCheckInService.ensureTodayCheckIn(
            activeHumanId: activeHumanId,
            rewardTitle: rewardTitle
        )
        updateHeaderStreak(FocusHomeDailyCheckInService.currentStreak(activeHumanId: activeHumanId))
    }

    static func currentStreak(activeHumanId: String) -> Int {
        FocusHomeDailyCheckInService.currentStreak(activeHumanId: activeHumanId)
    }
}
