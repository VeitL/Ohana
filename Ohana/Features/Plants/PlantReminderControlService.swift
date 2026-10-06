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
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantReminderToggleResult {
        guard plant.remindersEnabled != enabled else { return .noChange }
        let originalEnabled = plant.remindersEnabled
        plant.remindersEnabled = enabled
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
        let scheduleResult = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications,
            defaults: defaults,
            saveChanges: false
        )
        guard scheduleResult.didPersist else {
            plant.remindersEnabled = originalEnabled
            context.rollback()
            return .failed(scheduleResult.persistenceErrorDescription)
        }
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            plant.remindersEnabled = originalEnabled
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
    static func enableWateringCheck(
        plant: Plant,
        intervalDays: Int,
        context: ModelContext,
        now: Date = Date(),
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantReminderToggleResult {
        guard !plant.remindersEnabled, !plant.isArchived else { return .noChange }
        let originalInterval = plant.wateringIntervalDays
        let types = PlantReminderPreferenceStore.controllableCareTypes
        let previous = types.map { type in
            (
                type,
                PlantReminderPreferenceStore.planCalendarOverride(forPlantID: plant.id, careType: type, defaults: defaults),
                PlantReminderPreferenceStore.systemReminderOverride(forPlantID: plant.id, careType: type, defaults: defaults)
            )
        }
        for type in types {
            PlantReminderPreferenceStore.setPlanCalendarEnabled(type == .watering, forPlantID: plant.id, careType: type, defaults: defaults)
            PlantReminderPreferenceStore.setSystemReminderEnabled(type == .watering, forPlantID: plant.id, careType: type, defaults: defaults)
        }
        plant.wateringIntervalDays = min(max(intervalDays, 1), 90)
        let result = setPlantRemindersEnabled(
            true,
            plant: plant,
            context: context,
            now: now,
            notifications: notifications,
            defaults: defaults
        )
        if !result.didPersist {
            plant.wateringIntervalDays = originalInterval
            for (type, plan, system) in previous {
                PlantReminderPreferenceStore.restorePlanCalendarOverride(plan, forPlantID: plant.id, careType: type, defaults: defaults)
                PlantReminderPreferenceStore.restoreSystemReminderOverride(system, forPlantID: plant.id, careType: type, defaults: defaults)
            }
        }
        return result
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
            let planningHistory: PlantCarePlanningHistory
            do {
                planningHistory = try PlantCarePlanningHistoryQuery.build(
                    plantID: plant.id,
                    context: context
                )
            } catch {
                context.rollback()
                return PlantReminderBulkDeferResult(
                    deferredTaskCount: deferredTaskCount,
                    affectedPlantCount: affectedPlantIDs.count,
                    didPersist: false,
                    persistenceErrorDescription: error.localizedDescription
                )
            }
            let dueTasks = PlantCarePlanService.tasks(
                for: plant,
                history: planningHistory,
                now: now,
                calendar: calendar
            )
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
            guard scheduleResult.didPersist else {
                context.rollback()
                return PlantReminderBulkDeferResult(
                    deferredTaskCount: deferredTaskCount,
                    affectedPlantCount: affectedPlantIDs.count,
                    didPersist: false,
                    persistenceErrorDescription: scheduleResult.persistenceErrorDescription
                )
            }
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

    /// Moving the next check is feedback about the plan, not a completed care action.
    @discardableResult
    static func deferTask(
        plant: Plant,
        careType: PlantCareType,
        until date: Date,
        wetSoil: Bool = false,
        skip: Bool = false,
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> PlantReminderToggleResult {
        guard !plant.isArchived,
              PlantCareCategory.schedulableCareTypes.contains(careType),
              calendar.startOfDay(for: date) > calendar.startOfDay(for: now) else {
            return .noChange
        }
        do {
            let history = try PlantCarePlanningHistoryQuery.build(plantID: plant.id, context: context)
            let hasTask = PlantCarePlanService.tasks(for: plant, history: history, now: now, calendar: calendar)
                .contains { $0.careType == careType }
            guard hasTask else { return .noChange }
            let prefix = "\(skip ? "skip" : "defer"):\(careType.rawValue):"
            let latestActualCare: Date? = switch careType {
            case .watering: plant.lastWateredDate
            case .fertilizing: plant.lastFertilizedDate
            default: history.latestCareDates[careType]
            }
            if let latest = history.recentCustomNotes.first(where: { $0.note.hasPrefix(prefix) }),
               latest.date > (latestActualCare ?? .distantPast),
               let previousDate = ISO8601DateFormatter().date(from: String(latest.note.dropFirst(prefix.count)).components(separatedBy: "|")[0]),
               calendar.isDate(previousDate, inSameDayAs: date),
               latest.note.hasSuffix("|soilWet") == (wetSoil && careType == .watering && !plant.isHydroponic) {
                return .noChange
            }
        } catch {
            return .failed(error.localizedDescription)
        }
        let note = "\(skip ? "skip" : "defer"):\(careType.rawValue):\(ISO8601DateFormatter().string(from: date))" + (wetSoil && careType == .watering && !plant.isHydroponic ? "|soilWet" : "")
        recordDeferFeedback(note, plant: plant, executorId: executorId, context: context, now: now)
        let schedule = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: true,
            notifications: notifications,
            saveChanges: false
        )
        guard schedule.didPersist else {
            context.rollback()
            return .failed(schedule.persistenceErrorDescription)
        }
        let save = context.safeSaveResult(publishFailureEvent: true)
        guard save.didSave else {
            context.rollback()
            return .failed(save.errorDescription)
        }
        PlantCarePlanScheduleService.commitSideEffects(for: schedule, context: context, notifications: notifications)
        return .changed
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
