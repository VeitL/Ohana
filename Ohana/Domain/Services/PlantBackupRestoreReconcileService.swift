//
//  PlantBackupRestoreReconcileService.swift
//  Ohana
//
//  Rebuilds local plant care schedules after backup restore so plant profiles,
//  logs, reminder toggles, and global reminder preferences land as a usable
//  single-device care loop.
//

import Foundation
import SwiftData

struct PlantBackupRestoreReconcileResult: Equatable {
    let plantCount: Int
    let rebuiltEventCount: Int
    let rebuiltReminderCount: Int
    let removedEventCount: Int
    let removedReminderCount: Int
    let scheduledNotificationSyncCount: Int
    let pendingSideEffects: [PlantCarePlanScheduleResult]
}

@MainActor
enum PlantBackupRestoreReconcileService {
    @discardableResult
    static func rebuildPlantCarePlans(
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scheduleNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard,
        saveChanges: Bool = true
    ) throws -> PlantBackupRestoreReconcileResult {
        let descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\Plant.createdAt), SortDescriptor(\Plant.name)]
        )
        let plants = try context.fetch(descriptor)
        var rebuiltEventCount = 0
        var rebuiltReminderCount = 0
        var removedEventCount = 0
        var removedReminderCount = 0
        var scheduledNotificationSyncCount = 0
        var pendingSideEffects: [PlantCarePlanScheduleResult] = []

        for plant in plants {
            let result = PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                calendar: calendar,
                scheduleNotifications: scheduleNotifications,
                notifications: notifications,
                defaults: defaults,
                saveChanges: saveChanges
            )
            guard result.didPersist else {
                throw DataBackupRestorePersistenceError.persistenceFailed(result.persistenceErrorDescription)
            }
            rebuiltEventCount += result.eventIDs.count
            rebuiltReminderCount += result.reminderIDs.count
            removedEventCount += result.removedEventIDs.count
            removedReminderCount += result.removedReminderIDs.count
            if result.scheduledReminderSync {
                scheduledNotificationSyncCount += 1
            }
            if !saveChanges {
                pendingSideEffects.append(result)
            }
        }

        return PlantBackupRestoreReconcileResult(
            plantCount: plants.count,
            rebuiltEventCount: rebuiltEventCount,
            rebuiltReminderCount: rebuiltReminderCount,
            removedEventCount: removedEventCount,
            removedReminderCount: removedReminderCount,
            scheduledNotificationSyncCount: scheduledNotificationSyncCount,
            pendingSideEffects: pendingSideEffects
        )
    }

    static func commitSideEffects(
        _ result: PlantBackupRestoreReconcileResult,
        context: ModelContext,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) {
        for sideEffect in result.pendingSideEffects {
            PlantCarePlanScheduleService.commitSideEffects(
                for: sideEffect,
                context: context,
                notifications: notifications,
                defaults: defaults
            )
        }
    }
}
