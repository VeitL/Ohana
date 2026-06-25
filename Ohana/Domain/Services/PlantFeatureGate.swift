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
    nonisolated static let lockedTitleZh = "家庭树冠 Lv.4 解锁植物照护"
    nonisolated static let lockedDetailZh = "先完成宠物核心照护习惯，岛屿稳定后再把植物也搬进 Ohana。"
    nonisolated static let unlockedToastZh = "你的家庭树冠展开了，现在可以照顾家里的植物。"

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
