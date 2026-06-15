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
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> PlantCareCommandResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let eventIntent = DomainScheduleCreateIntent(
            title: "\(type.emoji) 给 \(plant.name)\(type.displayName)",
            startDate: now,
            isAllDay: false,
            eventType: type == .watering ? EventType.watering.rawValue : EventType.fertilizing.rawValue,
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
                careType: type
            )
        }
        let authorizedExecutorId = plan.intent.assigneeId
        switch type {
        case .watering:
            plant.lastWateredDate = now
        case .fertilizing:
            plant.lastFertilizedDate = now
        }

        let log = PlantCareLog(date: now, careType: type, executorId: authorizedExecutorId)
        log.plant = plant
        context.insert(log)

        let event = DomainScheduleWriter.createEvent(plan: plan, context: context).event

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
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "",
            context: context,
            save: false
        )
        context.safeSave()

        return PlantCareCommandResult(
            plantID: plant.id,
            logID: log.id,
            eventID: event.id,
            ledgerEventID: ledgerEvent.id,
            careType: type
        )
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

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        location: String,
        avatarEmoji: String,
        wateringIntervalDays: Int,
        fertilizingIntervalDays: Int
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
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
        context: ModelContext
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
            fertilizingIntervalDays: input.fertilizingIntervalDays
        )
        plant.id = input.id
        context.insert(plant)
        context.safeSave()

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
        note: String
    ) -> PlantCreationCommandResult {
        let result = PlantCreationCommandService.createPlant(input: input, context: context)
        revisions.publishMemberCreation(result, note: note)
        return result
    }
}
