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
    ) -> Bool

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
    func setPlantRemindersEnabled(_ enabled: Bool, plant: Plant, context: ModelContext) -> Bool {
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
    ) -> Bool {
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
            PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                scheduleNotifications: scheduleNotifications,
                notifications: notifications
            )
            count += 1
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
    ) -> Bool {
        guard plant.remindersEnabled != enabled else { return false }
        plant.remindersEnabled = enabled
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
        context.safeSave()
        PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications
        )
        return true
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

        for plant in plants {
            let dueTasks = PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
                .filter { $0.daysUntilDue <= 0 }
            guard !dueTasks.isEmpty else { continue }
            affectedPlantIDs.insert(plant.id)
            for task in dueTasks {
                let note = "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))"
                PlantCareCommandService.recordCare(
                    .customNote,
                    plant: plant,
                    executorId: executorId,
                    context: context,
                    now: now,
                    careNote: note,
                    syncCarePlan: false,
                    scheduleNotifications: false
                )
                deferredTaskCount += 1
            }
            PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                scheduleNotifications: scheduleNotifications,
                notifications: notifications
            )
        }

        return PlantReminderBulkDeferResult(
            deferredTaskCount: deferredTaskCount,
            affectedPlantCount: affectedPlantIDs.count
        )
    }
}
