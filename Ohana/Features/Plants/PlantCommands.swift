//
//  PlantCommands.swift
//  Ohana
//
//  Domain write boundaries for plant creation and plant care.
//

import Foundation
import SwiftData

struct PlantCareCommandResult: Equatable {
    let plantID: UUID
    let logID: UUID
    let eventID: UUID
    let ledgerEventID: UUID
    let careType: PlantCareType
    let coconutDelta: Int
}

enum PlantCareCommandService {
    @discardableResult
    @MainActor
    static func recordCare(
        _ type: PlantCareType,
        plant: Plant,
        executorId: String?,
        context: ModelContext,
        now: Date = Date(),
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        economy providedEconomy: CareEventEconomyAwarding? = nil,
        syncCarePlan: Bool = true,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PlantCareCommandResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let l = L10n.current
        let careTypeName = type.displayName(l: l)
        let eventIntent = DomainScheduleCreateIntent(
            title: "\(type.emoji) \(l.tr(zh: "给 \(plant.name)\(careTypeName)", en: "\(careTypeName) for \(plant.name)", de: "\(careTypeName) für \(plant.name)"))\(safetyReminderSuffix(for: plant))",
            startDate: now,
            isAllDay: false,
            eventType: type.eventType.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString,
            assigneeId: executorId,
            writeKind: .care,
            source: .userCommand
        )
        let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: eventIntent, context: context)
            ?? DomainScheduleWriteAuthorizer.authorizeCreate(
                intent: DomainScheduleCreateIntent(
                    title: eventIntent.title,
                    startDate: eventIntent.startDate,
                    isAllDay: eventIntent.isAllDay,
                    eventType: eventIntent.eventType,
                    relatedEntityType: eventIntent.relatedLink.rawType,
                    relatedEntityId: eventIntent.relatedLink.rawId,
                    writeKind: eventIntent.writeKind,
                    source: eventIntent.source
                ),
                context: context
            )
        guard let plan else {
            return PlantCareCommandResult(
                plantID: plant.id,
                logID: UUID(),
                eventID: UUID(),
                ledgerEventID: UUID(),
                careType: type,
                coconutDelta: 0
            )
        }
        let authorizedExecutorId = plan.intent.assigneeId
        let wasRewardEligible = isRewardEligible(type, for: plant, now: now)
        switch type {
        case .watering:
            plant.lastWateredDate = now
        case .fertilizing:
            plant.lastFertilizedDate = now
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            plant.lastHealthCheckDate = now
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            break
        }
        if let healthStatus {
            plant.healthStatus = healthStatus
        }

        let log = PlantCareLog(
            date: now,
            careType: type,
            note: careNote,
            executorId: authorizedExecutorId,
            photoData: photoData,
            healthStatus: healthStatus
        )
        log.plant = plant
        context.insert(log)
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)

        let event = DomainScheduleWriter.createEvent(plan: plan, context: context).event
        context.safeSave()
        let rewardAction = rewardAction(for: type)
        let reward: (humanGot: Int, petGot: Int)
        let rewardMetadata: String
        if wasRewardEligible, let rewardAction {
            let economy = providedEconomy ?? DomainServiceDependencyRegistry.careEventEconomy()
            reward = economy.awardCareAction(
                type: rewardAction,
                pet: nil,
                context: context,
                quality: DomainCareRewardQuality.compose(
                    precise: false,
                    hasNote: !careNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    hasPhoto: photoData != nil
                ),
                date: now,
                executorId: authorizedExecutorId,
                careObjectKey: plant.id
            )
            rewardMetadata = economy.rewardMetadata(for: reward)
        } else {
            reward = (0, 0)
            rewardMetadata = ""
        }
        let coconutDelta = max(0, reward.humanGot) + max(0, reward.petGot)

        let ledgerEvent = careLedger.record(
            occurredAt: log.date,
            actorKind: authorizedExecutorId == nil ? .unknown : .human,
            actorId: authorizedExecutorId,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: type.rawValue,
            amountValue: 0,
            amountUnit: "",
            note: log.note,
            source: .detail,
            sourceEventId: event.id.uuidString,
            sourceReminderId: nil,
            legacyModelName: "PlantCareLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: rewardMetadata,
            context: context,
            save: false
        )
        context.safeSave()
        if syncCarePlan {
            PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                scheduleNotifications: scheduleNotifications,
                reminderScheduling: providedReminderScheduling
            )
        }

        return PlantCareCommandResult(
            plantID: plant.id,
            logID: log.id,
            eventID: event.id,
            ledgerEventID: ledgerEvent.id,
            careType: type,
            coconutDelta: coconutDelta
        )
    }

    private static func rewardAction(for type: PlantCareType) -> DomainCareRewardAction? {
        switch type {
        case .watering:
            .plantWatering
        case .fertilizing:
            .plantFertilizing
        default:
            nil
        }
    }

    private static func isRewardEligible(_ type: PlantCareType, for plant: Plant, now: Date) -> Bool {
        switch type {
        case .watering, .fertilizing:
            PlantCarePlanService.tasks(for: plant, now: now).contains { task in
                task.careType == type && task.daysUntilDue <= 0
            }
        default:
            false
        }
    }

    private static func safetyReminderSuffix(for plant: Plant, defaults: UserDefaults = .standard) -> String {
        let hasPets = defaults.object(forKey: "ohana_onboarding_has_pets") == nil
            ? true
            : defaults.bool(forKey: "ohana_onboarding_has_pets")
        let hasChildren = defaults.bool(forKey: "ohana_onboarding_has_children")
        if hasPets, plant.isToxicToCats || plant.isToxicToDogs {
            return " · \(L10n.current.tr(zh: "放到宠物够不到处", en: "Keep out of pets' reach", de: "Außer Reichweite von Haustieren"))"
        }
        if hasChildren, plant.isToxicToChildren {
            return " · \(L10n.current.tr(zh: "注意儿童误食", en: "Watch for child ingestion", de: "Auf Verschlucken durch Kinder achten"))"
        }
        return ""
    }
}

struct PlantCreationCommandInput: Equatable {
    let id: UUID
    let name: String
    let species: String
    let location: String
    let avatarEmoji: String
    let avatarImageData: Data?
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let roomNameRaw: String
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
    let lastLightMeasurementLux: Int
    let lastLightMeasurementDate: Date?
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let isNearClimateSource: Bool
    let potHasDrainage: Bool
    let acquiredDate: Date?
    let acquisitionSourceRaw: String
    let currentHeightCm: Double
    let currentSpreadCm: Double
    let isHydroponic: Bool
    let isSucculent: Bool
    let healthStatus: PlantHealthStatus
    let catalogSpeciesId: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
    let remindersEnabled: Bool
    let notes: String

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        location: String,
        avatarEmoji: String,
        avatarImageData: Data? = nil,
        wateringIntervalDays: Int,
        fertilizingIntervalDays: Int,
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
        remindersEnabled: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = avatarImageData
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.roomNameRaw = roomNameRaw
        self.potDiameterCm = potDiameterCm
        self.potMaterialRaw = potMaterialRaw
        self.soilTypeRaw = soilTypeRaw
        self.isIndoor = isIndoor
        self.windowDirection = windowDirection
        self.lightLevel = lightLevel
        self.lastLightMeasurementLux = lastLightMeasurementLux
        self.lastLightMeasurementDate = lastLightMeasurementDate
        self.humidityPreference = humidityPreference
        self.temperaturePreference = temperaturePreference
        self.isNearClimateSource = isNearClimateSource
        self.potHasDrainage = potHasDrainage
        self.acquiredDate = acquiredDate
        self.acquisitionSourceRaw = acquisitionSourceRaw
        self.currentHeightCm = currentHeightCm
        self.currentSpreadCm = currentSpreadCm
        self.isHydroponic = isHydroponic
        self.isSucculent = isSucculent
        self.healthStatus = healthStatus
        self.catalogSpeciesId = catalogSpeciesId
        self.isToxicToCats = isToxicToCats
        self.isToxicToDogs = isToxicToDogs
        self.isToxicToChildren = isToxicToChildren
        self.isIndoorSuitable = isIndoorSuitable
        self.remindersEnabled = remindersEnabled
        self.notes = notes
    }
}

struct PlantCreationCommandResult: Equatable {
    let plantID: UUID
    let kind: String
}

nonisolated struct PlantDuplicateScanDraft: Equatable, Sendable {
    let name: String
    let species: String
    let roomName: String
    let location: String
    let catalogSpeciesId: String
}

nonisolated struct PlantDuplicateScanSnapshot: Equatable, Sendable {
    let id: UUID
    let name: String
    let species: String
    let roomName: String
    let location: String
    let catalogSpeciesId: String
}

nonisolated struct PlantDuplicateCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let reason: String
}

nonisolated struct PlantCatalogProfileDefaults: Equatable, Sendable {
    let name: String
    let species: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let lightLevel: PlantLightLevel
    let soilTypeRaw: String
    let isIndoor: Bool
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let potHasDrainage: Bool
    let isHydroponic: Bool
    let isSucculent: Bool
}

nonisolated struct PlantCarePlanRecalculationSnapshot: Equatable, Sendable {
    let roomName: String
    let location: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
    let lastLightMeasurementLux: Int
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let isNearClimateSource: Bool
    let potHasDrainage: Bool
    let currentHeightCm: Double
    let currentSpreadCm: Double
    let isHydroponic: Bool
    let isSucculent: Bool
    let healthStatus: PlantHealthStatus
    let catalogSpeciesId: String
    let remindersEnabled: Bool
}

nonisolated enum PlantCarePlanRecalculationImpact: String, CaseIterable, Identifiable, Sendable {
    case remindersOff
    case remindersOn
    case watering
    case fertilizing
    case misting
    case rotation
    case repotting
    case location

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .remindersOff, .remindersOn: "bell.badge"
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .misting: "humidity.fill"
        case .rotation: "rotate.3d"
        case .repotting: "shippingbox.fill"
        case .location: "house.fill"
        }
    }

    var title: String {
        let l = L10n.current
        return switch self {
        case .remindersOff: l.tr(zh: "关闭植物提醒", en: "Turn off plant reminders", de: "Pflanzenerinnerungen ausschalten")
        case .remindersOn: l.tr(zh: "重新打开提醒", en: "Turn reminders back on", de: "Erinnerungen wieder einschalten")
        case .watering: l.tr(zh: "浇水日期会重算", en: "Watering date will recalculate", de: "Gießdatum wird neu berechnet")
        case .fertilizing: l.tr(zh: "施肥日期会重算", en: "Fertilizing date will recalculate", de: "Düngedatum wird neu berechnet")
        case .misting: l.tr(zh: "喷雾任务可能变化", en: "Misting tasks may change", de: "Sprühaufgaben können sich ändern")
        case .rotation: l.tr(zh: "转盆节奏可能变化", en: "Rotation cadence may change", de: "Drehrhythmus kann sich ändern")
        case .repotting: l.tr(zh: "换盆检查会重算", en: "Repotting check will recalculate", de: "Umtopfprüfung wird neu berechnet")
        case .location: l.tr(zh: "房间/位置筛选会更新", en: "Room/location filters will update", de: "Raum-/Standortfilter werden aktualisiert")
        }
    }

    var detail: String {
        let l = L10n.current
        return switch self {
        case .remindersOff: l.tr(zh: "保存后会清理这株植物未完成的本地植物计划提醒。", en: "After saving, unfinished local care reminders for this plant will be cleared.", de: "Nach dem Speichern werden offene lokale Pflegeerinnerungen für diese Pflanze bereinigt.")
        case .remindersOn: l.tr(zh: "保存后会重新生成这株植物后续的本地护理计划。", en: "After saving, future local care plans for this plant will be regenerated.", de: "Nach dem Speichern werden zukünftige lokale Pflegepläne für diese Pflanze neu erzeugt.")
        case .watering: l.tr(zh: "水培、多肉、光照、盆径、盆材质或排水信息会影响下一次浇水。", en: "Hydroponics, succulent type, light, pot size, pot material, or drainage can affect the next watering.", de: "Hydrokultur, Sukkulentenart, Licht, Topfgröße, Material oder Drainage können das nächste Gießen beeinflussen.")
        case .fertilizing: l.tr(zh: "施肥频率、健康状态、水培或多肉类型会影响下一次施肥。", en: "Fertilizing frequency, health status, hydroponics, or succulent type can affect the next fertilizing task.", de: "Düngefrequenz, Zustand, Hydrokultur oder Sukkulentenart können die nächste Düngung beeinflussen.")
        case .misting: l.tr(zh: "湿度偏好或空调/暖气位置会影响是否安排喷雾。", en: "Humidity preference or AC/heater placement can affect whether misting is scheduled.", de: "Luftfeuchte und Nähe zu Klimaanlage/Heizung können beeinflussen, ob Sprühen geplant wird.")
        case .rotation: l.tr(zh: "窗向、光照强度和实测 lux 会影响转盆提醒。", en: "Window direction, light level, and measured lux can affect rotation reminders.", de: "Fensterausrichtung, Lichtstärke und gemessene Lux können Dreherinnerungen beeinflussen.")
        case .repotting: l.tr(zh: "盆径、株高、水培和排水孔会影响换盆复查节奏。", en: "Pot diameter, plant height, hydroponics, and drainage holes can affect repotting checks.", de: "Topfdurchmesser, Pflanzenhöhe, Hydrokultur und Abzugslöcher können Umtopfkontrollen beeinflussen.")
        case .location: l.tr(zh: "房间和具体位置会影响植物列表、筛选和卡片展示。", en: "Room and exact spot affect plant lists, filters, and card display.", de: "Raum und genauer Standort beeinflussen Pflanzenlisten, Filter und Kartenanzeige.")
        }
    }
}

nonisolated enum PlantProfileUXPolicy {
    static func duplicateAcknowledgementKey(for draft: PlantDuplicateScanDraft) -> String {
        [
            normalized(draft.name),
            normalized(draft.species),
            normalized(draft.roomName),
            normalized(draft.location),
            normalized(draft.catalogSpeciesId)
        ].joined(separator: "|")
    }

    static func duplicateCandidates(
        draft: PlantDuplicateScanDraft,
        existingPlants: [PlantDuplicateScanSnapshot]
    ) -> [PlantDuplicateCandidate] {
        let draftName = normalized(draft.name)
        let draftSpecies = normalized(draft.species)
        let draftRoom = normalized(draft.roomName)
        let draftLocation = normalized(draft.location)
        let draftCatalog = normalized(draft.catalogSpeciesId)
        guard !draftName.isEmpty || !draftSpecies.isEmpty || !draftCatalog.isEmpty else { return [] }

        var candidates: [PlantDuplicateCandidate] = []
        var seenIds = Set<UUID>()
        for plant in existingPlants {
            let plantName = normalized(plant.name)
            let plantSpecies = normalized(plant.species)
            let plantRoom = normalized(plant.roomName)
            let plantLocation = normalized(plant.location)
            let plantCatalog = normalized(plant.catalogSpeciesId)
            let l = L10n.current
            let reason: String? = if !draftCatalog.isEmpty, draftCatalog == plantCatalog, !draftRoom.isEmpty, draftRoom == plantRoom {
                l.tr(zh: "资料库物种和房间相同", en: "Same catalog species and room", de: "Gleiche Katalogart und gleicher Raum")
            } else if !draftName.isEmpty, draftName == plantName {
                l.tr(zh: "昵称相同", en: "Same nickname", de: "Gleicher Spitzname")
            } else if !draftSpecies.isEmpty, draftSpecies == plantSpecies, !draftRoom.isEmpty, draftRoom == plantRoom {
                l.tr(zh: "物种和房间相同", en: "Same species and room", de: "Gleiche Art und gleicher Raum")
            } else if !draftSpecies.isEmpty, draftSpecies == plantSpecies, !draftLocation.isEmpty, draftLocation == plantLocation {
                l.tr(zh: "物种和具体位置相同", en: "Same species and exact spot", de: "Gleiche Art und gleicher Standort")
            } else {
                nil
            }
            guard let reason, !seenIds.contains(plant.id) else { continue }
            seenIds.insert(plant.id)
            let roomDetail = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
            let locationDetail = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = [roomDetail, locationDetail].filter { !$0.isEmpty }.joined(separator: " · ")
            candidates.append(PlantDuplicateCandidate(
                id: plant.id,
                title: plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.current.tr(zh: "未命名植物", en: "Unnamed plant", de: "Unbenannte Pflanze") : plant.name,
                detail: detail.isEmpty ? L10n.current.tr(zh: "没有位置记录", en: "No location recorded", de: "Kein Standort erfasst") : detail,
                reason: reason
            ))
        }
        return Array(candidates.prefix(3))
    }

    static func catalogDefaults(for entry: PlantCatalogEntry) -> PlantCatalogProfileDefaults {
        PlantCatalogProfileDefaults(
            name: entry.localizedCommonName,
            species: entry.latinName,
            wateringIntervalDays: entry.defaultWateringDays,
            fertilizingIntervalDays: entry.defaultFertilizingDays,
            lightLevel: entry.lightRequirement,
            soilTypeRaw: entry.localizedSoil,
            isIndoor: entry.isIndoorSuitable,
            humidityPreference: humidityPreference(from: entry.humidity),
            temperaturePreference: temperaturePreference(from: entry.temperature),
            potHasDrainage: true,
            isHydroponic: false,
            isSucculent: isSucculentLike(entry)
        )
    }

    static func recalculationImpacts(
        old: PlantCarePlanRecalculationSnapshot,
        new: PlantCarePlanRecalculationSnapshot
    ) -> [PlantCarePlanRecalculationImpact] {
        var impacts: [PlantCarePlanRecalculationImpact] = []
        if old.remindersEnabled, !new.remindersEnabled {
            impacts.append(.remindersOff)
        } else if !old.remindersEnabled, new.remindersEnabled {
            impacts.append(.remindersOn)
        }
        if old.wateringIntervalDays != new.wateringIntervalDays ||
            old.potDiameterCm != new.potDiameterCm ||
            normalized(old.potMaterialRaw) != normalized(new.potMaterialRaw) ||
            old.isIndoor != new.isIndoor ||
            old.lightLevel != new.lightLevel ||
            old.windowDirection != new.windowDirection ||
            old.lastLightMeasurementLux != new.lastLightMeasurementLux ||
            old.isNearClimateSource != new.isNearClimateSource ||
            old.potHasDrainage != new.potHasDrainage ||
            old.isHydroponic != new.isHydroponic ||
            old.isSucculent != new.isSucculent ||
            old.catalogSpeciesId != new.catalogSpeciesId {
            impacts.append(.watering)
        }
        if old.fertilizingIntervalDays != new.fertilizingIntervalDays ||
            old.healthStatus != new.healthStatus ||
            old.isHydroponic != new.isHydroponic ||
            old.isSucculent != new.isSucculent ||
            old.catalogSpeciesId != new.catalogSpeciesId {
            impacts.append(.fertilizing)
        }
        if old.humidityPreference != new.humidityPreference ||
            old.isNearClimateSource != new.isNearClimateSource {
            impacts.append(.misting)
        }
        if old.windowDirection != new.windowDirection ||
            old.lightLevel != new.lightLevel ||
            old.lastLightMeasurementLux != new.lastLightMeasurementLux {
            impacts.append(.rotation)
        }
        if old.potDiameterCm != new.potDiameterCm ||
            old.currentHeightCm != new.currentHeightCm ||
            old.potHasDrainage != new.potHasDrainage ||
            old.isHydroponic != new.isHydroponic {
            impacts.append(.repotting)
        }
        if normalized(old.roomName) != normalized(new.roomName) ||
            normalized(old.location) != normalized(new.location) {
            impacts.append(.location)
        }
        return impacts
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private static func humidityPreference(from text: String) -> PlantHumidityPreference {
        let value = normalized(text)
        if value.contains("高湿") || value.contains("偏高") || value.contains("中高") || value.contains("humid") {
            return .humid
        }
        if value.contains("偏干") || value.contains("耐干") || value.contains("dry") {
            return .dry
        }
        return .standard
    }

    private static func temperaturePreference(from text: String) -> PlantTemperaturePreference {
        let value = normalized(text)
        if value.contains("冷") || value.contains("凉") || value.contains("cool") {
            return .cool
        }
        if value.contains("暖") || value.contains("warm") {
            return .warm
        }
        return .standard
    }

    private static func isSucculentLike(_ entry: PlantCatalogEntry) -> Bool {
        let searchableText = ([entry.commonName, entry.latinName, entry.soil, entry.wateringPreference] + entry.aliases)
            .map(normalized)
            .joined(separator: " ")
        return searchableText.contains("多肉") ||
            searchableText.contains("仙人掌") ||
            searchableText.contains("succulent") ||
            searchableText.contains("cactus") ||
            searchableText.contains("snake plant")
    }
}

enum PlantCreationCommandService {
    @discardableResult
    @MainActor
    static func createPlant(
        input: PlantCreationCommandInput,
        context: ModelContext,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PlantCreationCommandResult {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let plant = Plant(
            name: trimmedName.isEmpty ? "Plant" : trimmedName,
            species: input.species.trimmingCharacters(in: .whitespacesAndNewlines),
            location: input.location.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarEmoji: input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "🌱"
                : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
            wateringIntervalDays: input.wateringIntervalDays,
            fertilizingIntervalDays: input.fertilizingIntervalDays,
            roomNameRaw: input.roomNameRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            potDiameterCm: input.potDiameterCm,
            potMaterialRaw: input.potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            soilTypeRaw: input.soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            isIndoor: input.isIndoor,
            windowDirection: input.windowDirection,
            lightLevel: input.lightLevel,
            lastLightMeasurementLux: max(0, input.lastLightMeasurementLux),
            lastLightMeasurementDate: input.lastLightMeasurementDate,
            humidityPreference: input.humidityPreference,
            temperaturePreference: input.temperaturePreference,
            isNearClimateSource: input.isNearClimateSource,
            potHasDrainage: input.potHasDrainage,
            acquiredDate: input.acquiredDate,
            acquisitionSourceRaw: input.acquisitionSourceRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            currentHeightCm: input.currentHeightCm,
            currentSpreadCm: input.currentSpreadCm,
            isHydroponic: input.isHydroponic,
            isSucculent: input.isSucculent,
            healthStatus: input.healthStatus,
            catalogSpeciesId: input.catalogSpeciesId,
            isToxicToCats: input.isToxicToCats,
            isToxicToDogs: input.isToxicToDogs,
            isToxicToChildren: input.isToxicToChildren,
            isIndoorSuitable: input.isIndoorSuitable,
            remindersEnabled: input.remindersEnabled
        )
        plant.id = input.id
        plant.updateAvatarImageData(input.avatarImageData)
        plant.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(plant)
        PlantUnlockPolicy.noteExistingPlantData()
        CloudSyncMutationRecorder.markModified(plant, context: context)
        context.safeSave()
        PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            scheduleNotifications: scheduleNotifications,
            reminderScheduling: providedReminderScheduling
        )

        return PlantCreationCommandResult(
            plantID: plant.id,
            kind: EntityKind.plant.rawValue
        )
    }
}

@MainActor
struct PlantCreationCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func createPlant(
        input: PlantCreationCommandInput,
        note: String,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PlantCreationCommandResult {
        let result = PlantCreationCommandService.createPlant(
            input: input,
            context: context,
            scheduleNotifications: scheduleNotifications,
            reminderScheduling: providedReminderScheduling
        )
        revisions.publishMemberCreation(result, note: note)
        return result
    }
}
