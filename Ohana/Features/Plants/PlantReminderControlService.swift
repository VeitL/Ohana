//
//  PlantReminderControlService.swift
//  Ohana
//
//  User-facing controls for plant reminder schedules.
//

import Foundation
import SwiftData

struct PlantReminderBulkDeferResult: Equatable {
    let deferredTaskCount: Int
    let affectedPlantCount: Int
    let didPersist: Bool
    let persistenceErrorDescription: String?

    init(
        deferredTaskCount: Int,
        affectedPlantCount: Int,
        didPersist: Bool = true,
        persistenceErrorDescription: String? = nil
    ) {
        self.deferredTaskCount = deferredTaskCount
        self.affectedPlantCount = affectedPlantCount
        self.didPersist = didPersist
        self.persistenceErrorDescription = persistenceErrorDescription
    }
}

struct PlantReminderToggleResult: Equatable {
    let didChange: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?

    static let noChange = PlantReminderToggleResult(
        didChange: false,
        didPersist: true,
        persistenceErrorDescription: nil
    )

    static let changed = PlantReminderToggleResult(
        didChange: true,
        didPersist: true,
        persistenceErrorDescription: nil
    )

    static func failed(_ errorDescription: String?) -> PlantReminderToggleResult {
        PlantReminderToggleResult(
            didChange: false,
            didPersist: false,
            persistenceErrorDescription: errorDescription
        )
    }
}

@MainActor
protocol PlantReminderControlling {
    @discardableResult
    func resyncPlans(
        plants: [Plant],
        context: ModelContext,
        now: Date,
        scheduleNotifications: Bool,
        notifications: ReminderNotificationScheduling
    ) -> Int

    @discardableResult
    func setPlantRemindersEnabled(
        _ enabled: Bool,
        plant: Plant,
        context: ModelContext,
        now: Date,
        scheduleNotifications: Bool,
        notifications: ReminderNotificationScheduling
    ) -> PlantReminderToggleResult

    @discardableResult
    func deferDueTasksOneDay(
        plants: [Plant],
        context: ModelContext,
        executorId: String?,
        now: Date,
        calendar: Calendar,
        scheduleNotifications: Bool,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults
    ) -> PlantReminderBulkDeferResult
}

@MainActor
extension PlantReminderControlling {
    @discardableResult
    func resyncPlans(plants: [Plant], context: ModelContext) -> Int {
        resyncPlans(
            plants: plants,
            context: context,
            now: Date(),
            scheduleNotifications: true,
            notifications: ReminderNotificationSchedulerRegistry.current
        )
    }

    @discardableResult
    func setPlantRemindersEnabled(_ enabled: Bool, plant: Plant, context: ModelContext) -> PlantReminderToggleResult {
        setPlantRemindersEnabled(
            enabled,
            plant: plant,
            context: context,
            now: Date(),
            scheduleNotifications: true,
            notifications: ReminderNotificationSchedulerRegistry.current
        )
    }

    @discardableResult
    func deferDueTasksOneDay(
        plants: [Plant],
        context: ModelContext,
        executorId: String?
    ) -> PlantReminderBulkDeferResult {
        deferDueTasksOneDay(
            plants: plants,
            context: context,
            executorId: executorId,
            now: Date(),
            calendar: .current,
            scheduleNotifications: true,
            notifications: ReminderNotificationSchedulerRegistry.current,
            defaults: .standard
        )
    }
}

struct StaticPlantReminderController: PlantReminderControlling {
    @discardableResult
    func resyncPlans(
        plants: [Plant],
        context: ModelContext,
        now: Date,
        scheduleNotifications: Bool,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        PlantReminderControlService.resyncPlans(
            plants: plants,
            context: context,
            now: now,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications
        )
    }

    @discardableResult
    func setPlantRemindersEnabled(
        _ enabled: Bool,
        plant: Plant,
        context: ModelContext,
        now: Date,
        scheduleNotifications: Bool,
        notifications: ReminderNotificationScheduling
    ) -> PlantReminderToggleResult {
        PlantReminderControlService.setPlantRemindersEnabled(
            enabled,
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications
        )
    }

    @discardableResult
    func deferDueTasksOneDay(
        plants: [Plant],
        context: ModelContext,
        executorId: String?,
        now: Date,
        calendar: Calendar,
        scheduleNotifications: Bool,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults
    ) -> PlantReminderBulkDeferResult {
        PlantReminderControlService.deferDueTasksOneDay(
            plants: plants,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications,
            defaults: defaults
        )
    }
}

@MainActor
enum PlantReminderControlService {
    @discardableResult
    static func resyncPlans(
        plants: [Plant],
        context: ModelContext,
        now: Date = Date(),
        scheduleNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> Int {
        var count = 0
        for plant in plants {
            let result = PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                scheduleNotifications: scheduleNotifications,
                notifications: notifications
            )
            if result.didPersist {
                count += 1
            }
        }
        return count
    }

    @discardableResult
    static func setPlantRemindersEnabled(
        _ enabled: Bool,
        plant: Plant,
        context: ModelContext,
        now: Date = Date(),
        scheduleNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> PlantReminderToggleResult {
        guard plant.remindersEnabled != enabled else { return .noChange }
        plant.remindersEnabled = enabled
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
        let scheduleResult = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications,
            saveChanges: false
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return .failed(saveResult.errorDescription)
        }
        PlantCarePlanScheduleService.commitSideEffects(
            for: scheduleResult,
            context: context,
            notifications: notifications
        )
        return .changed
    }

    @discardableResult
    static func deferDueTasksOneDay(
        plants: [Plant],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current,
        scheduleNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantReminderBulkDeferResult {
        let formatter = ISO8601DateFormatter()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        var deferredTaskCount = 0
        var affectedPlantIDs = Set<UUID>()
        var touchedPlants: [Plant] = []
        var scheduleResults: [PlantCarePlanScheduleResult] = []

        for plant in plants {
            let dueTasks = PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
                .filter { $0.daysUntilDue <= 0 }
            guard !dueTasks.isEmpty else { continue }
            affectedPlantIDs.insert(plant.id)
            touchedPlants.append(plant)
            for task in dueTasks {
                let note = "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))"
                recordDeferFeedback(
                    note,
                    plant: plant,
                    executorId: executorId,
                    context: context,
                    now: now
                )
                deferredTaskCount += 1
            }
        }

        guard deferredTaskCount > 0 else {
            return PlantReminderBulkDeferResult(
                deferredTaskCount: 0,
                affectedPlantCount: 0
            )
        }

        for plant in touchedPlants {
            let scheduleResult = PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                scheduleNotifications: scheduleNotifications,
                notifications: notifications,
                saveChanges: false
            )
            scheduleResults.append(scheduleResult)
        }
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PlantReminderBulkDeferResult(
                deferredTaskCount: deferredTaskCount,
                affectedPlantCount: affectedPlantIDs.count,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        for scheduleResult in scheduleResults {
            PlantCarePlanScheduleService.commitSideEffects(
                for: scheduleResult,
                context: context,
                notifications: notifications
            )
        }

        return PlantReminderBulkDeferResult(
            deferredTaskCount: deferredTaskCount,
            affectedPlantCount: affectedPlantIDs.count
        )
    }

    private static func recordDeferFeedback(
        _ note: String,
        plant: Plant,
        executorId: String?,
        context: ModelContext,
        now: Date
    ) {
        let log = PlantCareLog(
            date: now,
            careType: .customNote,
            note: note,
            executorId: executorId
        )
        log.plant = plant
        context.insert(log)
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
    }
}
