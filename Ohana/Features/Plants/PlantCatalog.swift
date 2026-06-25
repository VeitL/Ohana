//
//  PlantCatalog.swift
//  Ohana
//
//  Local starter plant knowledge used by the free plant-care launch surface.
//

import Foundation

nonisolated struct PlantCatalogEntry: Identifiable, Equatable, Sendable {
    let id: String
    let commonName: String
    let latinName: String
    let aliases: [String]
    let imageName: String
    let lightRequirement: PlantLightLevel
    let wateringPreference: String
    let humidity: String
    let temperature: String
    let soil: String
    let fertilizing: String
    let propagation: String
    let pruning: String
    let commonIssues: String
    let toxicity: String
    let careDifficulty: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
    let defaultWateringDays: Int
    let defaultFertilizingDays: Int
}

nonisolated enum PlantCatalog {
    static let entries: [PlantCatalogEntry] = [
        PlantCatalogEntry(
            id: "epipremnum-aureum",
            commonName: "绿萝",
            latinName: "Epipremnum aureum",
            aliases: ["pothos", "黄金葛", "devils ivy"],
            imageName: "plant_catalog_pothos",
            lightRequirement: .brightIndirect,
            wateringPreference: "表土 2-3 cm 变干后浇透",
            humidity: "普通室内湿度即可",
            temperature: "18-30 C",
            soil: "疏松排水型通用土",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "带节茎插水培或土培",
            pruning: "修剪过长藤蔓，促进分枝",
            commonIssues: "黄叶常见于过浇、低温或光照突变",
            toxicity: "对猫狗和儿童有刺激性，避免误食",
            careDifficulty: "简单",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: true,
            isIndoorSuitable: true,
            defaultWateringDays: 7,
            defaultFertilizingDays: 35
        ),
        PlantCatalogEntry(
            id: "monstera-deliciosa",
            commonName: "龟背竹",
            latinName: "Monstera deliciosa",
            aliases: ["monstera", "swiss cheese plant"],
            imageName: "plant_catalog_monstera",
            lightRequirement: .brightIndirect,
            wateringPreference: "上层土干后浇透，避免长期积水",
            humidity: "偏高湿度更佳",
            temperature: "18-29 C",
            soil: "粗颗粒、树皮和通用土混合",
            fertilizing: "春夏每月薄肥",
            propagation: "带气根和节位扦插",
            pruning: "剪除老叶和过密枝叶",
            commonIssues: "焦边多与干燥、盐分或直晒有关",
            toxicity: "对猫狗和儿童有刺激性，避免误食",
            careDifficulty: "中等",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: true,
            isIndoorSuitable: true,
            defaultWateringDays: 8,
            defaultFertilizingDays: 30
        ),
        PlantCatalogEntry(
            id: "chlorophytum-comosum",
            commonName: "吊兰",
            latinName: "Chlorophytum comosum",
            aliases: ["spider plant", "airplane plant"],
            imageName: "plant_catalog_spider_plant",
            lightRequirement: .medium,
            wateringPreference: "保持轻微湿润，冬季减少",
            humidity: "普通室内湿度",
            temperature: "15-27 C",
            soil: "排水良好的通用土",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "分株或小吊兰落地",
            pruning: "剪除干尖和老叶",
            commonIssues: "叶尖干枯常见于干燥、盐分或缺水",
            toxicity: "通常对猫狗低风险",
            careDifficulty: "简单",
            isToxicToCats: false,
            isToxicToDogs: false,
            isToxicToChildren: false,
            isIndoorSuitable: true,
            defaultWateringDays: 6,
            defaultFertilizingDays: 40
        ),
        PlantCatalogEntry(
            id: "sansevieria-trifasciata",
            commonName: "虎尾兰",
            latinName: "Dracaena trifasciata",
            aliases: ["snake plant", "虎皮兰"],
            imageName: "plant_catalog_snake_plant",
            lightRequirement: .medium,
            wateringPreference: "土壤完全干透后再浇",
            humidity: "耐普通偏干环境",
            temperature: "16-30 C",
            soil: "多肉或仙人掌型排水土",
            fertilizing: "生长期 6-8 周一次薄肥",
            propagation: "分株或叶插",
            pruning: "剪除受损老叶",
            commonIssues: "根腐多由过浇或盆土不透气导致",
            toxicity: "对猫狗有轻中度风险，避免误食",
            careDifficulty: "简单",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: false,
            isIndoorSuitable: true,
            defaultWateringDays: 18,
            defaultFertilizingDays: 60
        ),
        PlantCatalogEntry(
            id: "ficus-lyrata",
            commonName: "琴叶榕",
            latinName: "Ficus lyrata",
            aliases: ["fiddle leaf fig"],
            imageName: "plant_catalog_fiddle_leaf_fig",
            lightRequirement: .brightIndirect,
            wateringPreference: "表土明显变干后浇透，保持节奏稳定",
            humidity: "中高湿更佳",
            temperature: "18-29 C，避免冷风",
            soil: "排水良好的室内观叶土",
            fertilizing: "生长期每月薄肥",
            propagation: "枝条扦插",
            pruning: "修剪顶部促进分枝",
            commonIssues: "掉叶常见于搬动、冷风、过浇或光照变化",
            toxicity: "对猫狗和儿童有刺激性，避免误食汁液",
            careDifficulty: "进阶",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: true,
            isIndoorSuitable: true,
            defaultWateringDays: 7,
            defaultFertilizingDays: 30
        )
    ]

    static func entry(id: String) -> PlantCatalogEntry? {
        entries.first { $0.id == id }
    }

    static func search(_ query: String) -> [PlantCatalogEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return entries }
        return entries.filter { entry in
            entry.commonName.lowercased().contains(normalized) ||
                entry.latinName.lowercased().contains(normalized) ||
                entry.aliases.contains { $0.lowercased().contains(normalized) }
        }
    }

    static func bestMatch(commonName: String, latinName: String = "") -> PlantCatalogEntry? {
        let name = commonName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let latin = latinName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.first { entry in
            entry.commonName.lowercased() == name ||
                entry.latinName.lowercased() == latin ||
                entry.aliases.contains { $0.lowercased() == name || $0.lowercased() == latin }
        }
    }
}

nonisolated enum PlantCatalogFavoriteStore {
    static let favoritesKey = "ohana_plant_catalog_favorite_ids_v1"

    static func favoriteIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: favoritesKey) ?? [])
    }

    static func isFavorite(id: String, defaults: UserDefaults = .standard) -> Bool {
        favoriteIDs(defaults: defaults).contains(id)
    }

    static func setFavoriteIDs(_ ids: Set<String>, defaults: UserDefaults = .standard) {
        defaults.set(Array(ids).sorted(), forKey: favoritesKey)
    }

    @discardableResult
    static func toggleFavorite(id: String, defaults: UserDefaults = .standard) -> Bool {
        guard PlantCatalog.entry(id: id) != nil else { return false }
        var ids = favoriteIDs(defaults: defaults)
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        setFavoriteIDs(ids, defaults: defaults)
        return ids.contains(id)
    }

    static func clearFavorites(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: favoritesKey)
    }
}
