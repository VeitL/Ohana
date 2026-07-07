//
//  PlantLifecycleService.swift
//  Ohana
//
//  Non-destructive lifecycle transitions for plants.
//

import Foundation
import SwiftData

struct PlantLifecycleTransitionResult: Equatable, Sendable {
    let plantID: UUID
    let action: String
    let didWrite: Bool
    let didPersist: Bool
    let persistenceError: String?
    let removedEventIDs: [UUID]
    let removedReminderIDs: [UUID]
}

@MainActor
enum PlantLifecycleService {
    @discardableResult
    static func archive(
        _ plant: Plant,
        archivedAt: Date = Date(),
        context: ModelContext,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantLifecycleTransitionResult {
        guard !plant.isArchived else {
            return PlantLifecycleTransitionResult(
                plantID: plant.id,
                action: "archive.no-op",
                didWrite: false,
                didPersist: true,
                persistenceError: nil,
                removedEventIDs: [],
                removedReminderIDs: []
            )
        }

        plant.archivedAt = archivedAt
        let removed = PlantCarePlanScheduleService.removeScheduledTasks(
            plant: plant,
            context: context,
            now: archivedAt,
            notifications: notifications,
            defaults: defaults
        )
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: archivedAt)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PlantLifecycleTransitionResult(
                plantID: plant.id,
                action: "archive.failed",
                didWrite: false,
                didPersist: false,
                persistenceError: saveResult.errorDescription,
                removedEventIDs: [],
                removedReminderIDs: []
            )
        }
        PlantCarePlanScheduleService.commitSideEffects(
            for: removed,
            context: context,
            notifications: notifications,
            defaults: defaults
        )
        return PlantLifecycleTransitionResult(
            plantID: plant.id,
            action: "archive.mark",
            didWrite: true,
            didPersist: true,
            persistenceError: nil,
            removedEventIDs: removed.removedEventIDs,
            removedReminderIDs: removed.removedReminderIDs
        )
    }

    @discardableResult
    static func restore(
        _ plant: Plant,
        restoredAt: Date = Date(),
        context: ModelContext,
        scheduleNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantLifecycleTransitionResult {
        guard plant.isArchived else {
            return PlantLifecycleTransitionResult(
                plantID: plant.id,
                action: "archive.restore.no-op",
                didWrite: false,
                didPersist: true,
                persistenceError: nil,
                removedEventIDs: [],
                removedReminderIDs: []
            )
        }

        plant.archivedAt = nil
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: restoredAt)
        let synced = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: restoredAt,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications,
            defaults: defaults,
            saveChanges: false
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PlantLifecycleTransitionResult(
                plantID: plant.id,
                action: "archive.restore.failed",
                didWrite: false,
                didPersist: false,
                persistenceError: saveResult.errorDescription,
                removedEventIDs: [],
                removedReminderIDs: []
            )
        }
        PlantCarePlanScheduleService.commitSideEffects(
            for: synced,
            context: context,
            notifications: notifications,
            defaults: defaults
        )
        return PlantLifecycleTransitionResult(
            plantID: plant.id,
            action: "archive.restore",
            didWrite: true,
            didPersist: true,
            persistenceError: nil,
            removedEventIDs: synced.removedEventIDs,
            removedReminderIDs: synced.removedReminderIDs
        )
    }
}
