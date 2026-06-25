//
//  PlantCareScheduleSyncService.swift
//  Ohana
//
//  Bridges completed plant calendar events/reminders into durable plant care facts.
//

import Foundation
import SwiftData

struct PlantCareScheduleSyncResult: Equatable {
    enum Action: String, Equatable {
        case wroteCareFact
        case skippedExistingCare
        case noPlantTarget
        case unsupportedCareType
        case unauthorized
    }

    let action: Action
    let plantID: UUID?
    let logID: UUID?
    let ledgerEventID: UUID?
    let careType: PlantCareType?
}

@MainActor
enum PlantCareScheduleSyncService {
    static func careType(for event: Event) -> PlantCareType? {
        switch EventType(rawValue: event.eventType) {
        case .watering:
            .watering
        case .fertilizing:
            .fertilizing
        case .plantRepotting:
            .repotting
        case .plantPruning:
            .pruning
        case .plantMisting:
            .misting
        case .plantRotation:
            .rotating
        case .plantLeafCleaning:
            .leafCleaning
        case .plantPestCheck:
            .pestCheck
        case .plantHealthCheck:
            .customNote
        case .birthday, .anniversary, .daily, .health, .task, .shoppingList, .chore,
             .vaccine, .externalDeworming, .internalDeworming, .grooming, .vetVisit,
             .foodChange, .litterBox, .medication, .petMedication, .petMedicationDose,
             .insurancePremium, .none:
            nil
        }
    }

    static func isPlantCareEvent(_ event: Event) -> Bool {
        DomainEntityLinkRegistry.plantId(for: event) != nil && careType(for: event) != nil
    }

    @discardableResult
    static func syncCompletedEvent(
        _ event: Event,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext,
        source: CareLedgerSource = .calendar,
        sourceReminderId: UUID? = nil,
        now: Date = Date(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        scheduleNotifications: Bool = true
    ) -> PlantCareScheduleSyncResult {
        guard let type = careType(for: event) else {
            return PlantCareScheduleSyncResult(
                action: .unsupportedCareType,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        guard let plantID = DomainEntityLinkRegistry.plantId(for: event),
              let plant = fetchPlant(id: plantID, context: context) else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }
        let careDate = Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
        if hasExistingCare(type, plantID: plant.id, on: careDate, context: context) {
            return PlantCareScheduleSyncResult(
                action: .skippedExistingCare,
                plantID: plant.id,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }
        guard let plan = DomainEffectWriteAuthorizer.authorizeSubjectEffect(
            subjectRequest: DomainSubjectResolutionRequest(event: event),
            occurredAt: now,
            writeKind: .care,
            source: .domainService,
            executorId: executorId,
            unresolvedAssigneePolicy: .drop,
            context: context,
            logPrefix: "PlantCareScheduleSync.complete"
        ) else {
            return PlantCareScheduleSyncResult(
                action: .unauthorized,
                plantID: plant.id,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }

        var result = PlantCareScheduleSyncResult(
            action: .unauthorized,
            plantID: plant.id,
            logID: nil,
            ledgerEventID: nil,
            careType: type
        )
        DomainEffectDispatcher.run(plan: plan) { actor in
            applyCareDate(careDate, type: type, to: plant)
            let log = PlantCareLog(
                date: careDate,
                careType: type,
                note: scheduleCompletionNote(for: event),
                executorId: actor.effectiveExecutorId
            )
            log.plant = plant
            context.insert(log)
            CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
            let ledger = (providedCareLedger ?? CareLedgerService()).record(
                occurredAt: careDate,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .plant,
                subjectId: plant.id.uuidString,
                eventKind: .plantCare,
                actionType: type.rawValue,
                amountValue: 0,
                amountUnit: "",
                note: log.note,
                source: source,
                sourceEventId: event.id.uuidString,
                sourceReminderId: sourceReminderId?.uuidString,
                legacyModelName: "PlantCareLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "{\"scheduleCompletion\":true}",
                context: context,
                save: false
            )
            context.safeSave()
            PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                scheduleNotifications: scheduleNotifications
            )
            result = PlantCareScheduleSyncResult(
                action: .wroteCareFact,
                plantID: plant.id,
                logID: log.id,
                ledgerEventID: ledger.id,
                careType: type
            )
        }
        return result
    }

    @discardableResult
    static func syncCompletedReminder(
        _ reminder: Reminder,
        executorId: String?,
        context: ModelContext,
        now: Date = Date(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        scheduleNotifications: Bool = true
    ) -> PlantCareScheduleSyncResult {
        guard let event = reminder.event else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        return syncCompletedEvent(
            event,
            occurrenceDate: reminder.scheduledAt,
            executorId: executorId,
            context: context,
            source: .reminder,
            sourceReminderId: reminder.id,
            now: now,
            careLedger: providedCareLedger,
            scheduleNotifications: scheduleNotifications
        )
    }

    private static func fetchPlant(id: UUID, context: ModelContext) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func hasExistingCare(
        _ type: PlantCareType,
        plantID: UUID,
        on date: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Bool {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        let typeRaw = type.rawValue
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.careTypeRaw == typeRaw && log.date >= start && log.date < end
            }
        )
        descriptor.fetchLimit = 24
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.contains { $0.plant?.id == plantID }
    }

    private static func applyCareDate(_ date: Date, type: PlantCareType, to plant: Plant) {
        switch type {
        case .watering:
            plant.lastWateredDate = date
        case .fertilizing:
            plant.lastFertilizedDate = date
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            plant.lastHealthCheckDate = date
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            break
        }
    }

    private static func scheduleCompletionNote(for event: Event) -> String {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "计划完成" : "计划完成：\(title)"
    }
}
