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
        let l = L10n.current
        return switch self {
        case .low: l.tr(zh: "弱光", en: "Low light", de: "Schwaches Licht")
        case .medium: l.tr(zh: "中等光", en: "Medium light", de: "Mittleres Licht")
        case .brightIndirect: l.tr(zh: "明亮散射光", en: "Bright indirect light", de: "Helles indirektes Licht")
        case .direct: l.tr(zh: "直射光", en: "Direct sun", de: "Direktes Licht")
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
        let l = L10n.current
        return switch self {
        case .thriving: l.tr(zh: "状态很好", en: "Thriving", de: "Sehr guter Zustand")
        case .stable: l.tr(zh: "稳定", en: "Stable", de: "Stabil")
        case .watching: l.tr(zh: "需要观察", en: "Needs watching", de: "Beobachten")
        case .stressed: l.tr(zh: "状态紧张", en: "Stressed", de: "Gestresst")
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
        let l = L10n.current
        return switch self {
        case .unknown: l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt")
        case .north: l.tr(zh: "北向", en: "North-facing", de: "Nach Norden")
        case .east: l.tr(zh: "东向", en: "East-facing", de: "Nach Osten")
        case .south: l.tr(zh: "南向", en: "South-facing", de: "Nach Süden")
        case .west: l.tr(zh: "西向", en: "West-facing", de: "Nach Westen")
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
        let l = L10n.current
        return switch self {
        case .unknown: l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt")
        case .dry: l.tr(zh: "偏干", en: "Drier", de: "Eher trocken")
        case .standard: l.tr(zh: "普通", en: "Standard", de: "Normal")
        case .humid: l.tr(zh: "偏湿", en: "More humid", de: "Feuchter")
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
        let l = L10n.current
        return switch self {
        case .unknown: l.tr(zh: "未设置", en: "Not set", de: "Nicht festgelegt")
        case .cool: l.tr(zh: "偏凉", en: "Cooler", de: "Eher kühl")
        case .standard: l.tr(zh: "普通", en: "Standard", de: "Normal")
        case .warm: l.tr(zh: "偏暖", en: "Warmer", de: "Eher warm")
        }
    }
}

enum PlantAvatarAttachmentState: String, Codable, Sendable {
    case unknown
    case absent
    case present
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
    var avatarAttachmentStateRaw: String = PlantAvatarAttachmentState.unknown.rawValue
    var avatarImageSignature: String = ""
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
    var archivedAt: Date?
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
        self.avatarAttachmentStateRaw = PlantAvatarAttachmentState.absent.rawValue
        self.avatarImageSignature = ""
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
        self.archivedAt = nil
        self.notes = ""
        self.createdAt = Date()
        self.careLogs = []
    }

    var avatarAttachmentState: PlantAvatarAttachmentState {
        get { PlantAvatarAttachmentState(rawValue: avatarAttachmentStateRaw) ?? .unknown }
        set { avatarAttachmentStateRaw = newValue.rawValue }
    }

    var hasAvatarImageAttachment: Bool {
        canAttemptAvatarImageAttachmentLoad
    }

    var canAttemptAvatarImageAttachmentLoad: Bool {
        avatarAttachmentState != .absent
    }

    var avatarThumbnailSignature: String {
        if !avatarImageSignature.isEmpty {
            return avatarImageSignature
        }
        guard canAttemptAvatarImageAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):avatar:\(createdAt.timeIntervalSince1970)"
    }

    var needsAvatarAttachmentIndexRepair: Bool {
        avatarAttachmentState == .unknown || (hasAvatarImageAttachment && avatarImageSignature.isEmpty)
    }

    func updateAvatarImageData(_ data: Data?) {
        avatarImageData = data
        updateAvatarAttachmentIndex(for: data)
    }

    @discardableResult
    func repairAvatarAttachmentIndexIfNeeded() -> Bool {
        guard needsAvatarAttachmentIndexRepair else { return false }
        updateAvatarAttachmentIndex(for: avatarImageData)
        return true
    }

    @discardableResult
    func backfillAvatarAttachmentPresence(hasData: Bool) -> Bool {
        if hasData {
            guard avatarAttachmentState != .present else { return false }
            avatarAttachmentState = .present
            return true
        }

        guard avatarAttachmentState != .absent || !avatarImageSignature.isEmpty else { return false }
        avatarAttachmentState = .absent
        avatarImageSignature = ""
        return true
    }

    private func updateAvatarAttachmentIndex(for data: Data?) {
        avatarAttachmentState = data == nil ? .absent : .present
        avatarImageSignature = data.map(MediaPayloadSignature.signature(for:)) ?? ""
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

    var isArchived: Bool {
        archivedAt != nil
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
