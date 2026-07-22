//
//  PlantFeatureGate.swift
//  Ohana
//
//  Product/build gate and growth unlock policy for the plant feature surface.
//

import Foundation

enum PlantFeature: String, CaseIterable, Sendable {
    case plants
}

enum PlantFeatureGate {
    nonisolated static func allows(_ feature: PlantFeature) -> Bool {
        switch feature {
        case .plants:
            true
        }
    }
}

enum PlantUnlockPolicy {
    nonisolated static let requiredLevel = 4
    nonisolated static let requiredEnergy = 500
    nonisolated static let lockedTitleZh = "生命树冠 Lv.4 解锁植物照护"
    nonisolated static let lockedDetailZh = "先完成宠物核心照护习惯，岛屿稳定后再把植物也搬进 Ohana。"
    nonisolated static let unlockedToastZh = "你的生命树冠展开了，现在可以照顾家里的植物。"

    private nonisolated static let existingPlantDataKey = "ohana_existing_plant_data_v1"

    nonisolated static func isUnlocked(
        currentLevel: Int,
        defaults: UserDefaults = .standard
    ) -> Bool {
        PlantFeatureGate.allows(.plants) &&
            (currentLevel >= requiredLevel || hasExistingPlantData(defaults: defaults))
    }

    nonisolated static func hasExistingPlantData(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: existingPlantDataKey)
    }

    nonisolated static func noteExistingPlantData(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: existingPlantDataKey)
    }

    nonisolated static func clearExistingPlantData(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: existingPlantDataKey)
    }
}

enum PlantLockedPreviewPolicy {
    nonisolated static let onboardingHasPlantsKey = "ohana_onboarding_has_plants"

    nonisolated static func shouldShowLockedPreview(
        currentLevel: Int,
        defaults: UserDefaults = .standard
    ) -> Bool {
        PlantFeatureGate.allows(.plants) &&
            hasOnboardingPlantInterest(defaults: defaults) &&
            !PlantUnlockPolicy.isUnlocked(currentLevel: currentLevel, defaults: defaults)
    }

    nonisolated static func hasOnboardingPlantInterest(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: onboardingHasPlantsKey)
    }

    nonisolated static func noteOnboardingPlantInterest(
        _ hasPlants: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(hasPlants, forKey: onboardingHasPlantsKey)
    }

    nonisolated static func clearOnboardingPlantInterest(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: onboardingHasPlantsKey)
    }

    nonisolated static func levelsRemaining(currentLevel: Int) -> Int {
        max(0, PlantUnlockPolicy.requiredLevel - max(0, currentLevel))
    }

    nonisolated static func energyRemainingForUnlock(currentEnergy: Int) -> Int {
        max(0, PlantUnlockPolicy.requiredEnergy - max(0, currentEnergy))
    }
}
