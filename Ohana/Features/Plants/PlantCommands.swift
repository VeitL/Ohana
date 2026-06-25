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
        let eventIntent = DomainScheduleCreateIntent(
            title: "\(type.emoji) 给 \(plant.name)\(type.displayName)\(safetyReminderSuffix(for: plant))",
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
        case .watering:
            plant.needsWatering(on: now)
        case .fertilizing:
            plant.needsFertilizing(on: now)
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
            return " · 放到宠物够不到处"
        }
        if hasChildren, plant.isToxicToChildren {
            return " · 注意儿童误食"
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
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
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
        wateringIntervalDays: Int,
        fertilizingIntervalDays: Int,
        potDiameterCm: Double = 0,
        potMaterialRaw: String = "",
        soilTypeRaw: String = "",
        isIndoor: Bool = true,
        windowDirection: PlantWindowDirection = .unknown,
        lightLevel: PlantLightLevel = .medium,
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
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.potDiameterCm = potDiameterCm
        self.potMaterialRaw = potMaterialRaw
        self.soilTypeRaw = soilTypeRaw
        self.isIndoor = isIndoor
        self.windowDirection = windowDirection
        self.lightLevel = lightLevel
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
            potDiameterCm: input.potDiameterCm,
            potMaterialRaw: input.potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            soilTypeRaw: input.soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            isIndoor: input.isIndoor,
            windowDirection: input.windowDirection,
            lightLevel: input.lightLevel,
            healthStatus: input.healthStatus,
            catalogSpeciesId: input.catalogSpeciesId,
            isToxicToCats: input.isToxicToCats,
            isToxicToDogs: input.isToxicToDogs,
            isToxicToChildren: input.isToxicToChildren,
            isIndoorSuitable: input.isIndoorSuitable,
            remindersEnabled: input.remindersEnabled
        )
        plant.id = input.id
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
