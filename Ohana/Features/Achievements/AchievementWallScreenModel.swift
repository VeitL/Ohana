//
//  AchievementWallScreenModel.swift
//  Ohana
//
//  Snapshot helper for achievement wall business aggregation.
//

import Foundation

struct AchievementWallScreenModel {
    let context: AchievementComputationContext
    let gachaOwnedItems: [GachaOwnedItem]

    func petAchievements(for pet: Pet) -> [Achievement] {
        AchievementManager.compute(for: pet, context: context)
    }

    func completedGachaSeriesCount() -> Int {
        AchievementManager.completedGachaSeriesCount(gachaOwnedItems)
    }

    func isGlobalAchievement(_ achievement: Achievement) -> Bool {
        AchievementManager.isGlobalAchievement(achievement)
    }
}
