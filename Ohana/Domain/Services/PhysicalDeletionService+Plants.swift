//
//  PhysicalDeletionService+Plants.swift
//  Ohana
//
//  Irreversible local plant deletes and derived-row cleanup.
//

import Foundation
import SwiftData

extension PhysicalDeletionService {
    static func deletePlant(
        _ plant: Plant,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) {
        let plantId = plant.id.uuidString
        _ = deletePlantRelatedEvents(
            plantId: plantId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        deletePlantCareRows(
            plant,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        deletePlantCareLedgerEvents(
            plantId: plantId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        CloudSyncMutationRecorder.markDeleted(
            plant,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(plant)
    }

    @discardableResult
    private static func deletePlantCareRows(
        _ plant: Plant,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        let plantId = plant.id
        let logs = fetchAll(PlantCareLog.self, context: context).filter { log in
            log.plant?.id == plantId
        }
        return deleteRows(unique(logs, by: \.id), context: context) { log in
            deleteCareLedgerEvents(
                legacyModelName: String(describing: PlantCareLog.self),
                legacyModelId: log.id.uuidString,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            CloudSyncMutationRecorder.markDeleted(
                log,
                plant: plant,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    private static func deletePlantCareLedgerEvents(
        plantId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        _ = deleteRows(fetchAll(CareLedgerEvent.self, context: context).filter { event in
            event.subjectKind == CareLedgerSubjectKind.plant.rawValue && idsMatch(event.subjectId, plantId)
        }, context: context) {
            CloudSyncMutationRecorder.markDeleted(
                $0,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    @discardableResult
    private static func deletePlantRelatedEvents(
        plantId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let events = fetchAll(Event.self, context: context).filter { event in
            eventBelongsToPlant(event, plantId: plantId)
        }
        return deleteEvents(
            events,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
    }

    private static func eventBelongsToPlant(_ event: Event, plantId: String) -> Bool {
        let link = DomainEntityLink(event: event)
        guard DomainEntityLinkRegistry.plantId(for: link)?.uuidString == plantId else { return false }
        let role = DomainEntityLinkRegistry.role(for: link)
        return role.isPlantScoped || role == .unscoped
    }
}
