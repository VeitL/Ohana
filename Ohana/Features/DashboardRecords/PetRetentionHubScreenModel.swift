//
//  PetRetentionHubScreenModel.swift
//  Ohana
//
//  Snapshot builder for the pet retention hub.
//

import Foundation

struct PetRetentionHubScreenModel {
    let pet: Pet

    var achievementProgress: (unlocked: Int, total: Int) {
        let achievements = AchievementManager.compute(for: pet)
        return (achievements.filter(\.isUnlocked).count, achievements.count)
    }
}
