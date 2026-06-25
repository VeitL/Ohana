//
//  PlantCarePlanScheduleService.swift
//  Ohana
//
//  Materializes local plant-care plan snapshots into Calendar events,
//  Reminders, notification scheduling, and future sync metadata.
//

import Foundation
import SwiftData

struct PlantCarePlanScheduleResult: Equatable {
    let plantID: UUID
    let eventIDs: [UUID]
    let reminderIDs: [UUID]
    let removedEventIDs: [UUID]
    let removedReminderIDs: [UUID]
    let scheduledReminderSync: Bool

    static func empty(plantID: UUID) -> PlantCarePlanScheduleResult {
        PlantCarePlanScheduleResult(
            plantID: plantID,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: [],
            removedReminderIDs: [],
            scheduledReminderSync: false
        )
    }
}

@MainActor
enum PlantCarePlanScheduleService {
    private static let storagePrefix = "ohana_plant_care_plan_event_v1"
    private static let planTitleMarker = "植物计划"
    private static let scheduledCareTypes: [PlantCareType] = [
        .watering,
        .fertilizing,
        .repotting,
        .pruning,
        .misting,
        .rotating,
        .leafCleaning,
        .pestCheck
    ]

    @discardableResult
    static func sync(
        plant: Plant,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantCarePlanScheduleResult {
        guard plant.remindersEnabled else {
            let removed = removeScheduledTasks(
                plant: plant,
                context: context,
                now: now,
                notifications: notifications,
                defaults: defaults
            )
            if !removed.removedEventIDs.isEmpty || !removed.removedReminderIDs.isEmpty {
                context.safeSave()
            }
            return removed
        }

        let scheduledRawTypes = Set(scheduledCareTypes.map(\.rawValue))
        let tasks = PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
            .filter { scheduledRawTypes.contains($0.careType.rawValue) }
        let taskRawTypes = Set(tasks.map(\.careType.rawValue))
        var eventIDs: [UUID] = []
        var reminderIDs: [UUID] = []
        var remindersToSchedule: [Reminder] = []
        var removedEventIDs: [UUID] = []
        var removedReminderIDs: [UUID] = []

        for task in tasks {
            if let outcome = upsertScheduledTask(
                task,
                plant: plant,
                context: context,
                now: now,
                calendar: calendar,
                notifications: notifications,
                defaults: defaults
            ) {
                eventIDs.append(outcome.event.id)
                if let reminder = outcome.pendingReminder {
                    reminderIDs.append(reminder.id)
                    remindersToSchedule.append(reminder)
                }
                removedEventIDs.append(contentsOf: outcome.removedEventIDs)
                removedReminderIDs.append(contentsOf: outcome.removedReminderIDs)
            }
        }

        for type in scheduledCareTypes where !taskRawTypes.contains(type.rawValue) {
            let removed = removeScheduledTask(
                plant: plant,
                type: type,
                context: context,
                now: now,
                notifications: notifications,
                defaults: defaults
            )
            removedEventIDs.append(contentsOf: removed.removedEventIDs)
            removedReminderIDs.append(contentsOf: removed.removedReminderIDs)
        }

        context.safeSave()

        let shouldScheduleReminders = scheduleNotifications && !remindersToSchedule.isEmpty
        if shouldScheduleReminders {
            for reminder in remindersToSchedule {
                notifications.schedule(reminder: reminder)
            }
        }

        return PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: eventIDs,
            reminderIDs: reminderIDs,
            removedEventIDs: removedEventIDs,
            removedReminderIDs: removedReminderIDs,
            scheduledReminderSync: shouldScheduleReminders
        )
    }

    @discardableResult
    static func removeScheduledTasks(
        plant: Plant,
        context: ModelContext,
        now: Date = Date(),
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantCarePlanScheduleResult {
        var removedEventIDs: [UUID] = []
        var removedReminderIDs: [UUID] = []
        for type in scheduledCareTypes {
            let removed = removeScheduledTask(
                plant: plant,
                type: type,
                context: context,
                now: now,
                notifications: notifications,
                defaults: defaults
            )
            removedEventIDs.append(contentsOf: removed.removedEventIDs)
            removedReminderIDs.append(contentsOf: removed.removedReminderIDs)
        }
        return PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: removedEventIDs,
            removedReminderIDs: removedReminderIDs,
            scheduledReminderSync: false
        )
    }
}

private extension PlantCarePlanScheduleService {
    struct UpsertOutcome {
        let event: Event
        let pendingReminder: Reminder?
        let removedEventIDs: [UUID]
        let removedReminderIDs: [UUID]
    }

    static func upsertScheduledTask(
        _ task: PlantCareTaskSnapshot,
        plant: Plant,
        context: ModelContext,
        now: Date,
        calendar: Calendar,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults
    ) -> UpsertOutcome? {
        let intent = makeIntent(task: task, plant: plant, now: now, calendar: calendar, defaults: defaults)
        let key = storageKey(plant: plant, type: task.careType)
        let existing = storedPlanEvent(defaults.string(forKey: key), context: context)
            ?? matchingPlanEvent(plant: plant, type: task.careType, context: context)
        let reminderDate = reminderDate(for: task.dueDate, now: now, calendar: calendar)

        if let existing {
            defaults.set(existing.id.uuidString, forKey: key)
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
                event: existing,
                intent: intent,
                writeKind: .care,
                source: .domainService,
                context: context
            ) else { return nil }

            DomainScheduleWriter.updateEvent(existing, intent: intent, mutation: mutation)
            existing.isCompleted = false
            existing.completedOccurrences.removeAll()
            CloudSyncMutationRecorder.markModified(existing, context: context, modifiedAt: now)

            let reminderOutcome = ensureSinglePendingReminder(
                for: existing,
                scheduledAt: reminderDate,
                mutation: mutation,
                context: context,
                now: now,
                notifications: notifications
            )
            return UpsertOutcome(
                event: existing,
                pendingReminder: reminderOutcome.pendingReminder,
                removedEventIDs: [],
                removedReminderIDs: reminderOutcome.removedReminderIDs
            )
        }

        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }
        let writeResult = DomainScheduleWriter.createEvent(plan: plan, context: context, maxReminderOccurrences: 1)
        defaults.set(writeResult.event.id.uuidString, forKey: key)
        CloudSyncMutationRecorder.markModified(writeResult.event, context: context, modifiedAt: now)
        for reminder in writeResult.reminders {
            CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: now)
        }
        return UpsertOutcome(
            event: writeResult.event,
            pendingReminder: writeResult.reminders.first,
            removedEventIDs: [],
            removedReminderIDs: []
        )
    }

    static func removeScheduledTask(
        plant: Plant,
        type: PlantCareType,
        context: ModelContext,
        now: Date,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults
    ) -> PlantCarePlanScheduleResult {
        let key = storageKey(plant: plant, type: type)
        defer { defaults.removeObject(forKey: key) }
        guard let event = storedPlanEvent(defaults.string(forKey: key), context: context)
            ?? matchingPlanEvent(plant: plant, type: type, context: context)
        else {
            return .empty(plantID: plant.id)
        }
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .lifecycle(.cleanupActiveSchedules),
            source: .domainService,
            context: context
        ) else {
            return .empty(plantID: plant.id)
        }
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context, deletedAt: now)
        DomainScheduleEffectsDispatcher.dispatch(delete: result, notifications: notifications)
        return PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: result.eventID.map { [$0] } ?? [],
            removedReminderIDs: result.reminderIDs,
            scheduledReminderSync: false
        )
    }

    static func ensureSinglePendingReminder(
        for event: Event,
        scheduledAt reminderDate: Date,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        now: Date,
        notifications: ReminderNotificationScheduling
    ) -> (pendingReminder: Reminder?, removedReminderIDs: [UUID]) {
        let pendingReminders = event.reminders
            .filter(\.isPending)
            .sorted { $0.scheduledAt < $1.scheduledAt }

        let pendingReminder: Reminder?
        if let existingPending = pendingReminders.first {
            DomainScheduleWriter.resetReminderToPending(
                existingPending,
                scheduledAt: reminderDate,
                mutation: mutation,
                resetAt: now,
                context: context
            )
            pendingReminder = existingPending
        } else {
            pendingReminder = DomainScheduleWriter.createReminder(
                for: event,
                scheduledAt: reminderDate,
                mutation: mutation,
                context: context
            )
            if let pendingReminder {
                CloudSyncMutationRecorder.markModified(pendingReminder, context: context, modifiedAt: now)
            }
        }

        var removedReminderIDs: [UUID] = []
        for extra in pendingReminders.dropFirst() {
            let result = DomainScheduleWriter.deleteReminder(extra, mutation: mutation, context: context, deletedAt: now)
            DomainScheduleEffectsDispatcher.dispatch(delete: result, notifications: notifications)
            removedReminderIDs.append(contentsOf: result.reminderIDs)
        }
        return (pendingReminder, removedReminderIDs)
    }

    static func makeIntent(
        task: PlantCareTaskSnapshot,
        plant: Plant,
        now: Date,
        calendar: Calendar,
        defaults: UserDefaults
    ) -> DomainScheduleCreateIntent {
        let dueDay = calendar.startOfDay(for: task.dueDate)
        return DomainScheduleCreateIntent(
            title: "\(task.careType.emoji) \(plant.name) · \(task.careType.displayName)\(planTitleMarker)\(safetyReminderSuffix(for: plant, defaults: defaults))",
            startDate: dueDay,
            isAllDay: true,
            eventType: task.careType.eventType.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString,
            recurrenceDays: PlantCarePlanService.intervalDays(for: task.careType, plant: plant),
            reminderDates: [reminderDate(for: dueDay, now: now, calendar: calendar)],
            writeKind: .care,
            source: .domainService
        )
    }

    static func reminderDate(for dueDate: Date, now: Date, calendar: Calendar) -> Date {
        let dueDay = calendar.startOfDay(for: dueDate)
        let preferred = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dueDay) ?? dueDay
        guard preferred <= now else { return preferred }
        return now.addingTimeInterval(5 * 60)
    }

    static func storedPlanEvent(_ rawID: String?, context: ModelContext) -> Event? {
        guard let rawID,
              let id = UUID(uuidString: rawID) else {
            return nil
        }
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.id == id
            }
        )
        descriptor.fetchLimit = 1
        let events = (try? context.fetch(descriptor)) ?? []
        return events.first
    }

    static func matchingPlanEvent(plant: Plant, type: PlantCareType, context: ModelContext) -> Event? {
        let plantID = plant.id.uuidString
        let plantType = EntityKind.plant.rawValue
        let eventType = type.eventType.rawValue
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == plantType &&
                    event.relatedEntityId == plantID &&
                    event.eventType == eventType
            },
            sortBy: [SortDescriptor(\Event.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let events = (try? context.fetch(descriptor)) ?? []
        return events.first { event in
            event.isAllDay && event.title.contains(planTitleMarker)
        }
    }

    static func storageKey(plant: Plant, type: PlantCareType) -> String {
        "\(storagePrefix)_\(plant.id.uuidString)_\(type.rawValue)"
    }

    static func safetyReminderSuffix(for plant: Plant, defaults: UserDefaults) -> String {
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
