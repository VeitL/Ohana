//
//  OasisPlantAmbiencePolicy.swift
//  Ohana
//

import Foundation

enum OasisPlantDecorSlot: String {
    case scene
    case potSkin
}

nonisolated enum OasisPlantDecorID {
    static let greenhouseCorner = "plant_decor_greenhouse_corner"
    static let balconyPlanters = "plant_decor_balcony_planters"
    static let seasonalMiniScape = "plant_decor_seasonal_mini_scape"
    static let mossPath = "plant_decor_moss_path"
    static let hangingVines = "plant_decor_hanging_vines"
    static let ceramicPotSkin = "plant_decor_ceramic_pot_skin"
    static let terracottaPotSkin = "plant_decor_terracotta_pot_skin"
    static let glassTerrariumSkin = "plant_decor_glass_terrarium_skin"

    static let sceneIDs: Set<String> = [
        greenhouseCorner,
        balconyPlanters,
        seasonalMiniScape,
        mossPath,
        hangingVines
    ]

    static let potSkinIDs: Set<String> = [
        ceramicPotSkin,
        terracottaPotSkin,
        glassTerrariumSkin
    ]

    static func slot(for itemID: String) -> OasisPlantDecorSlot? {
        if sceneIDs.contains(itemID) { return .scene }
        if potSkinIDs.contains(itemID) { return .potSkin }
        return nil
    }

    static func isPlantDecor(_ itemID: String) -> Bool {
        slot(for: itemID) != nil
    }

    static func symbolName(for itemID: String) -> String {
        switch itemID {
        case greenhouseCorner:
            "house.fill"
        case balconyPlanters:
            "rectangle.split.3x1.fill"
        case seasonalMiniScape:
            "camera.macro"
        case mossPath:
            "leaf.arrow.triangle.circlepath"
        case hangingVines:
            "curtains.closed"
        case ceramicPotSkin:
            "circle.hexagongrid.fill"
        case terracottaPotSkin:
            "circle.grid.cross.fill"
        case glassTerrariumSkin:
            "circle.dotted.circle.fill"
        default:
            "leaf.fill"
        }
    }
}

nonisolated enum OasisPlantDecorStore {
    static let equippedSceneKey = "shop_equipped_plant_decor_scene"
    static let equippedPotSkinKey = "shop_equipped_plant_pot_skin"

    static func isEquipped(
        _ itemID: String,
        equippedSceneID: String,
        equippedPotSkinID: String
    ) -> Bool {
        switch OasisPlantDecorID.slot(for: itemID) {
        case .scene:
            equippedSceneID == itemID
        case .potSkin:
            equippedPotSkinID == itemID
        case nil:
            false
        }
    }
}

nonisolated struct OasisPlantAmbienceSnapshot: Equatable {
    let plantCareEventCount: Int
    let lushnessLevel: Int
    let isYieldAmbienceUnlocked: Bool
    let equippedSceneID: String
    let equippedPotSkinID: String

    var hasAnyVisual: Bool {
        lushnessLevel > 0 || !equippedSceneID.isEmpty || !equippedPotSkinID.isEmpty
    }
}

nonisolated enum OasisPlantAmbiencePolicy {
    static func snapshot(
        plantCareEventCount: Int,
        currentLevel: Int,
        equippedSceneID: String,
        equippedPotSkinID: String,
        defaults: UserDefaults = .standard
    ) -> OasisPlantAmbienceSnapshot {
        let isUnlocked = PlantUnlockPolicy.isUnlocked(currentLevel: currentLevel, defaults: defaults)
        let yieldUnlocked = currentLevel >= 5
        return OasisPlantAmbienceSnapshot(
            plantCareEventCount: max(0, plantCareEventCount),
            lushnessLevel: lushnessLevel(
                plantCareEventCount: plantCareEventCount,
                isPlantUnlocked: isUnlocked,
                isYieldAmbienceUnlocked: yieldUnlocked
            ),
            isYieldAmbienceUnlocked: yieldUnlocked,
            equippedSceneID: OasisPlantDecorID.slot(for: equippedSceneID) == .scene ? equippedSceneID : "",
            equippedPotSkinID: OasisPlantDecorID.slot(for: equippedPotSkinID) == .potSkin ? equippedPotSkinID : ""
        )
    }

    static func lushnessLevel(
        plantCareEventCount: Int,
        isPlantUnlocked: Bool,
        isYieldAmbienceUnlocked: Bool
    ) -> Int {
        guard PlantFeatureGate.allows(.plants), isPlantUnlocked else { return 0 }
        let baseLevel: Int = switch max(0, plantCareEventCount) {
        case 0:
            0
        case 1 ... 2:
            1
        case 3 ... 5:
            2
        case 6 ... 10:
            3
        default:
            4
        }
        guard baseLevel > 0, isYieldAmbienceUnlocked else { return baseLevel }
        return min(5, baseLevel + 1)
    }
}
