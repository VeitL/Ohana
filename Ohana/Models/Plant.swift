//
//  Plant.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

enum PlantExperienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner
    case intermediate
    case experienced

    var id: String { rawValue }
}

enum PlantCareScene: String, Codable, CaseIterable, Identifiable, Sendable {
    case indoor
    case balcony
    case garden

    var id: String { rawValue }
}

enum PlantLightLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case brightIndirect
    case direct

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .low: "弱光"
        case .medium: "中等光"
        case .brightIndirect: "明亮散射光"
        case .direct: "直射光"
        }
    }
}

enum PlantHealthStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case thriving
    case stable
    case watching
    case stressed

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .thriving: "状态很好"
        case .stable: "稳定"
        case .watching: "需要观察"
        case .stressed: "状态紧张"
        }
    }
}

enum PlantWindowDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknown
    case north
    case east
    case south
    case west

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .unknown: "未设置"
        case .north: "北向"
        case .east: "东向"
        case .south: "南向"
        case .west: "西向"
        }
    }
}

enum PlantHumidityPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknown
    case dry
    case standard
    case humid

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .unknown: "未设置"
        case .dry: "偏干"
        case .standard: "普通"
        case .humid: "偏湿"
        }
    }
}

enum PlantTemperaturePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknown
    case cool
    case standard
    case warm

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .unknown: "未设置"
        case .cool: "偏凉"
        case .standard: "普通"
        case .warm: "偏暖"
        }
    }
}

@Model
final class Plant {
    var id: UUID
    var name: String
    var species: String
    var location: String
    var avatarEmoji: String
    var themeColorHex: String
    @Attribute(.externalStorage) var avatarImageData: Data?
    var wateringIntervalDays: Int
    var fertilizingIntervalDays: Int
    var lastWateredDate: Date?
    var lastFertilizedDate: Date?
    var lastHealthCheckDate: Date?
    var roomNameRaw: String = ""
    var potDiameterCm: Double = 0
    var potMaterialRaw: String = ""
    var soilTypeRaw: String = ""
    var isIndoor: Bool = true
    var windowDirectionRaw: String = PlantWindowDirection.unknown.rawValue
    var lightLevelRaw: String = PlantLightLevel.medium.rawValue
    var lastLightMeasurementLux: Int = 0
    var lastLightMeasurementDate: Date?
    var humidityPreferenceRaw: String = PlantHumidityPreference.standard.rawValue
    var temperaturePreferenceRaw: String = PlantTemperaturePreference.standard.rawValue
    var isNearClimateSource: Bool = false
    var potHasDrainage: Bool = true
    var acquiredDate: Date?
    var acquisitionSourceRaw: String = ""
    var currentHeightCm: Double = 0
    var currentSpreadCm: Double = 0
    var isHydroponic: Bool = false
    var isSucculent: Bool = false
    var healthStatusRaw: String = PlantHealthStatus.stable.rawValue
    var catalogSpeciesId: String = ""
    var isToxicToCats: Bool = false
    var isToxicToDogs: Bool = false
    var isToxicToChildren: Bool = false
    var isIndoorSuitable: Bool = true
    var remindersEnabled: Bool = true
    var notes: String
    var createdAt: Date
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    @Relationship(deleteRule: .cascade) var careLogs: [PlantCareLog]

    init(
        name: String = "",
        species: String = "",
        location: String = "",
        avatarEmoji: String = "🌱",
        wateringIntervalDays: Int = 7,
        fertilizingIntervalDays: Int = 30,
        themeColorHex: String = "4CAF50",
        roomNameRaw: String = "",
        potDiameterCm: Double = 0,
        potMaterialRaw: String = "",
        soilTypeRaw: String = "",
        isIndoor: Bool = true,
        windowDirection: PlantWindowDirection = .unknown,
        lightLevel: PlantLightLevel = .medium,
        lastLightMeasurementLux: Int = 0,
        lastLightMeasurementDate: Date? = nil,
        humidityPreference: PlantHumidityPreference = .standard,
        temperaturePreference: PlantTemperaturePreference = .standard,
        isNearClimateSource: Bool = false,
        potHasDrainage: Bool = true,
        acquiredDate: Date? = nil,
        acquisitionSourceRaw: String = "",
        currentHeightCm: Double = 0,
        currentSpreadCm: Double = 0,
        isHydroponic: Bool = false,
        isSucculent: Bool = false,
        healthStatus: PlantHealthStatus = .stable,
        catalogSpeciesId: String = "",
        isToxicToCats: Bool = false,
        isToxicToDogs: Bool = false,
        isToxicToChildren: Bool = false,
        isIndoorSuitable: Bool = true,
        remindersEnabled: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.themeColorHex = themeColorHex
        self.avatarImageData = nil
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.lastWateredDate = nil
        self.lastFertilizedDate = nil
        self.lastHealthCheckDate = nil
        self.roomNameRaw = roomNameRaw
        self.potDiameterCm = potDiameterCm
        self.potMaterialRaw = potMaterialRaw
        self.soilTypeRaw = soilTypeRaw
        self.isIndoor = isIndoor
        self.windowDirectionRaw = windowDirection.rawValue
        self.lightLevelRaw = lightLevel.rawValue
        self.lastLightMeasurementLux = lastLightMeasurementLux
        self.lastLightMeasurementDate = lastLightMeasurementDate
        self.humidityPreferenceRaw = humidityPreference.rawValue
        self.temperaturePreferenceRaw = temperaturePreference.rawValue
        self.isNearClimateSource = isNearClimateSource
        self.potHasDrainage = potHasDrainage
        self.acquiredDate = acquiredDate
        self.acquisitionSourceRaw = acquisitionSourceRaw
        self.currentHeightCm = currentHeightCm
        self.currentSpreadCm = currentSpreadCm
        self.isHydroponic = isHydroponic
        self.isSucculent = isSucculent
        self.healthStatusRaw = healthStatus.rawValue
        self.catalogSpeciesId = catalogSpeciesId
        self.isToxicToCats = isToxicToCats
        self.isToxicToDogs = isToxicToDogs
        self.isToxicToChildren = isToxicToChildren
        self.isIndoorSuitable = isIndoorSuitable
        self.remindersEnabled = remindersEnabled
        self.notes = ""
        self.createdAt = Date()
        self.careLogs = []
    }

    var lightLevel: PlantLightLevel {
        get { PlantLightLevel(rawValue: lightLevelRaw) ?? .medium }
        set { lightLevelRaw = newValue.rawValue }
    }

    var healthStatus: PlantHealthStatus {
        get { PlantHealthStatus(rawValue: healthStatusRaw) ?? .stable }
        set { healthStatusRaw = newValue.rawValue }
    }

    var windowDirection: PlantWindowDirection {
        get { PlantWindowDirection(rawValue: windowDirectionRaw) ?? .unknown }
        set { windowDirectionRaw = newValue.rawValue }
    }

    var humidityPreference: PlantHumidityPreference {
        get { PlantHumidityPreference(rawValue: humidityPreferenceRaw) ?? .standard }
        set { humidityPreferenceRaw = newValue.rawValue }
    }

    var temperaturePreference: PlantTemperaturePreference {
        get { PlantTemperaturePreference(rawValue: temperaturePreferenceRaw) ?? .standard }
        set { temperaturePreferenceRaw = newValue.rawValue }
    }

    var roomName: String {
        let room = roomNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return room.isEmpty ? location.trimmingCharacters(in: .whitespacesAndNewlines) : room
    }

    var potMaterial: String {
        potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var soilType: String {
        soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var acquisitionSource: String {
        acquisitionSourceRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var daysSinceWatered: Int? {
        daysSinceWatered(on: Date())
    }

    func daysSinceWatered(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let lastWateredDate else { return nil }
        return calendar.dateComponents([.day], from: lastWateredDate, to: date).day
    }

    var daysSinceFertilized: Int? {
        daysSinceFertilized(on: Date())
    }

    func daysSinceFertilized(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let lastFertilizedDate else { return nil }
        return calendar.dateComponents([.day], from: lastFertilizedDate, to: date).day
    }

    var needsWatering: Bool {
        needsWatering(on: Date())
    }

    func needsWatering(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let days = daysSinceWatered(on: date, calendar: calendar) else { return true }
        return days >= wateringIntervalDays
    }

    var needsFertilizing: Bool {
        needsFertilizing(on: Date())
    }

    func needsFertilizing(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let days = daysSinceFertilized(on: date, calendar: calendar) else { return true }
        return days >= fertilizingIntervalDays
    }
}
