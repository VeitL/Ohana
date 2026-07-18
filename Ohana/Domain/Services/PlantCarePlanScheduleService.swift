//
//  PlantCarePlanScheduleService.swift
//  Ohana
//
//  Materializes local plant-care plan snapshots into Calendar events,
//  Reminders, notification scheduling, and future sync metadata.
//

import Foundation
import SwiftData

nonisolated struct PlantCarePlanDefaultWrite: Equatable, Sendable {
    let key: String
    let value: String
}

struct PlantCarePlanScheduleResult: Equatable {
    let plantID: UUID
    let eventIDs: [UUID]
    let reminderIDs: [UUID]
    let removedEventIDs: [UUID]
    let removedReminderIDs: [UUID]
    let scheduledReminderSync: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
    let reminderIDsToSchedule: [UUID]
    let notificationIDsToCancel: [String]
    let defaultWrites: [PlantCarePlanDefaultWrite]
    let defaultRemovals: [String]

    init(
        plantID: UUID,
        eventIDs: [UUID],
        reminderIDs: [UUID],
        removedEventIDs: [UUID],
        removedReminderIDs: [UUID],
        scheduledReminderSync: Bool,
        didPersist: Bool = true,
        persistenceErrorDescription: String? = nil,
        reminderIDsToSchedule: [UUID] = [],
        notificationIDsToCancel: [String] = [],
        defaultWrites: [PlantCarePlanDefaultWrite] = [],
        defaultRemovals: [String] = []
    ) {
        self.plantID = plantID
        self.eventIDs = eventIDs
        self.reminderIDs = reminderIDs
        self.removedEventIDs = removedEventIDs
        self.removedReminderIDs = removedReminderIDs
        self.scheduledReminderSync = scheduledReminderSync
        self.didPersist = didPersist
        self.persistenceErrorDescription = persistenceErrorDescription
        self.reminderIDsToSchedule = reminderIDsToSchedule
        self.notificationIDsToCancel = notificationIDsToCancel
        self.defaultWrites = defaultWrites
        self.defaultRemovals = defaultRemovals
    }

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

    static func persistenceFailed(plantID: UUID, errorDescription: String?) -> PlantCarePlanScheduleResult {
        PlantCarePlanScheduleResult(
            plantID: plantID,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: [],
            removedReminderIDs: [],
            scheduledReminderSync: false,
            didPersist: false,
            persistenceErrorDescription: errorDescription
        )
    }
}

@MainActor
enum PlantCarePlanScheduleService {
    private static let storagePrefix = "ohana_plant_care_plan_event_v1"
    private static let scheduledCareTypes = PlantCareCategory.schedulableCareTypes

    @discardableResult
    static func sync(
        plant: Plant,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard,
        saveChanges: Bool = true
    ) -> PlantCarePlanScheduleResult {
        guard !plant.isArchived else {
            let removed = removeScheduledTasks(
                plant: plant,
                context: context,
                now: now,
                notifications: notifications,
                defaults: defaults
            )
            if saveChanges {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    return .persistenceFailed(plantID: plant.id, errorDescription: saveResult.errorDescription)
                }
                commitSideEffects(for: removed, context: context, notifications: notifications, defaults: defaults)
            }
            return removed
        }

        let enabledScheduledCareTypes = scheduledCareTypes.filter {
            PlantReminderPreferenceStore.isPlanCalendarEnabled(
                forPlantID: plant.id,
                careType: $0,
                fallback: PlantReminderPreferenceStore.planCalendarFallback(
                    for: $0,
                    plantRemindersEnabled: plant.remindersEnabled,
                    defaults: defaults
                ),
                defaults: defaults
            )
        }
        let scheduledRawTypes = Set(enabledScheduledCareTypes.map(\.rawValue))
        let tasks = PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
            .filter { scheduledRawTypes.contains($0.careType.rawValue) }
        let taskRawTypes = Set(tasks.map(\.careType.rawValue))
        var eventIDs: [UUID] = []
        var reminderIDs: [UUID] = []
        var remindersToSchedule: [Reminder] = []
        var removedEventIDs: [UUID] = []
        var removedReminderIDs: [UUID] = []
        var notificationIDsToCancel: [String] = []
        var defaultWrites: [PlantCarePlanDefaultWrite] = []
        var defaultRemovals: [String] = []

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
                notificationIDsToCancel.append(contentsOf: outcome.notificationIDsToCancel)
                defaultWrites.append(contentsOf: outcome.defaultWrites)
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
            notificationIDsToCancel.append(contentsOf: removed.notificationIDsToCancel)
            defaultWrites.append(contentsOf: removed.defaultWrites)
            defaultRemovals.append(contentsOf: removed.defaultRemovals)
        }

        let shouldScheduleReminders = scheduleNotifications && !remindersToSchedule.isEmpty
        let result = PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: eventIDs,
            reminderIDs: reminderIDs,
            removedEventIDs: removedEventIDs,
            removedReminderIDs: removedReminderIDs,
            scheduledReminderSync: shouldScheduleReminders,
            reminderIDsToSchedule: shouldScheduleReminders ? remindersToSchedule.map(\.id) : [],
            notificationIDsToCancel: notificationIDsToCancel,
            defaultWrites: defaultWrites,
            defaultRemovals: defaultRemovals
        )
        if saveChanges {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return .persistenceFailed(plantID: plant.id, errorDescription: saveResult.errorDescription)
            }
            commitSideEffects(
                notificationIDsToCancel: notificationIDsToCancel,
                remindersToSchedule: remindersToSchedule,
                defaultWrites: defaultWrites,
                defaultRemovals: defaultRemovals,
                notifications: notifications,
                defaults: defaults
            )
        }

        return result
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
        var notificationIDsToCancel: [String] = []
        var defaultRemovals: [String] = []
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
            notificationIDsToCancel.append(contentsOf: removed.notificationIDsToCancel)
            defaultRemovals.append(contentsOf: removed.defaultRemovals)
        }
        return PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: removedEventIDs,
            removedReminderIDs: removedReminderIDs,
            scheduledReminderSync: false,
            notificationIDsToCancel: notificationIDsToCancel,
            defaultRemovals: defaultRemovals
        )
    }

    static func commitSideEffects(
        for result: PlantCarePlanScheduleResult,
        context: ModelContext,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) {
        guard result.didPersist else { return }
        commitSideEffects(
            notificationIDsToCancel: result.notificationIDsToCancel,
            remindersToSchedule: fetchReminders(ids: result.reminderIDsToSchedule, context: context),
            defaultWrites: result.defaultWrites,
            defaultRemovals: result.defaultRemovals,
            notifications: notifications,
            defaults: defaults
        )
    }

    /// Automatic plant care projections support the Free core workflow and do
    /// not consume a user-created ordinary-plan slot.
    static func isGeneratedCalendarPlan(_ event: Event) -> Bool {
        event.relatedEntityType == EntityKind.plant.rawValue &&
            event.title.contains(PlantReminderPreferenceStore.generatedPlanTitleMarker)
    }
}

private extension PlantCarePlanScheduleService {
    struct UpsertOutcome {
        let event: Event
        let pendingReminder: Reminder?
        let removedEventIDs: [UUID]
        let removedReminderIDs: [UUID]
        let notificationIDsToCancel: [String]
        let defaultWrites: [PlantCarePlanDefaultWrite]
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
        let systemReminderEnabled = PlantReminderPreferenceStore.isSystemReminderEnabled(
            forPlantID: plant.id,
            careType: task.careType,
            defaults: defaults
        )
        let intent = makeIntent(
            task: task,
            plant: plant,
            now: now,
            calendar: calendar,
            defaults: defaults,
            includesReminder: systemReminderEnabled
        )
        let key = storageKey(plant: plant, type: task.careType)
        let existing = storedPlanEvent(defaults.string(forKey: key), context: context)
            ?? matchingPlanEvent(plant: plant, type: task.careType, context: context)
        let reminderDate = reminderDate(for: task.dueDate, now: now, calendar: calendar, defaults: defaults)

        if let existing {
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

            let reminderOutcome = systemReminderEnabled
                ? ensureSinglePendingReminder(
                    for: existing,
                    scheduledAt: reminderDate,
                    mutation: mutation,
                    context: context,
                    now: now,
                    notifications: notifications
                )
                : removeReminders(
                    for: existing,
                    mutation: mutation,
                    context: context,
                    now: now,
                    notifications: notifications
                )
            return UpsertOutcome(
                event: existing,
                pendingReminder: reminderOutcome.pendingReminder,
                removedEventIDs: [],
                removedReminderIDs: reminderOutcome.removedReminderIDs,
                notificationIDsToCancel: reminderOutcome.notificationIDsToCancel,
                defaultWrites: [PlantCarePlanDefaultWrite(key: key, value: existing.id.uuidString)]
            )
        }

        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }
        let writeResult = DomainScheduleWriter.createEvent(plan: plan, context: context, maxReminderOccurrences: 1)
        CloudSyncMutationRecorder.markModified(writeResult.event, context: context, modifiedAt: now)
        for reminder in writeResult.reminders {
            CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: now)
        }
        return UpsertOutcome(
            event: writeResult.event,
            pendingReminder: writeResult.reminders.first,
            removedEventIDs: [],
            removedReminderIDs: [],
            notificationIDsToCancel: [],
            defaultWrites: [PlantCarePlanDefaultWrite(key: key, value: writeResult.event.id.uuidString)]
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
        guard let event = storedPlanEvent(defaults.string(forKey: key), context: context)
            ?? matchingPlanEvent(plant: plant, type: type, context: context)
        else {
            return PlantCarePlanScheduleResult(
                plantID: plant.id,
                eventIDs: [],
                reminderIDs: [],
                removedEventIDs: [],
                removedReminderIDs: [],
                scheduledReminderSync: false,
                defaultRemovals: [key]
            )
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
        return PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: result.eventID.map { [$0] } ?? [],
            removedReminderIDs: result.reminderIDs,
            scheduledReminderSync: false,
            notificationIDsToCancel: result.notificationIdsToCancel,
            defaultRemovals: [key]
        )
    }

    static func ensureSinglePendingReminder(
        for event: Event,
        scheduledAt reminderDate: Date,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        now: Date,
        notifications: ReminderNotificationScheduling
    ) -> (pendingReminder: Reminder?, removedReminderIDs: [UUID], notificationIDsToCancel: [String]) {
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
        var notificationIDsToCancel: [String] = []
        for extra in pendingReminders.dropFirst() {
            let result = DomainScheduleWriter.deleteReminder(extra, mutation: mutation, context: context, deletedAt: now)
            removedReminderIDs.append(contentsOf: result.reminderIDs)
            notificationIDsToCancel.append(contentsOf: result.notificationIdsToCancel)
        }
        return (pendingReminder, removedReminderIDs, notificationIDsToCancel)
    }

    static func removeReminders(
        for event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        now: Date,
        notifications: ReminderNotificationScheduling
    ) -> (pendingReminder: Reminder?, removedReminderIDs: [UUID], notificationIDsToCancel: [String]) {
        var removedReminderIDs: [UUID] = []
        var notificationIDsToCancel: [String] = []
        for reminder in Array(event.reminders) {
            let result = DomainScheduleWriter.deleteReminder(reminder, mutation: mutation, context: context, deletedAt: now)
            removedReminderIDs.append(contentsOf: result.reminderIDs)
            notificationIDsToCancel.append(contentsOf: result.notificationIdsToCancel)
        }
        return (nil, removedReminderIDs, notificationIDsToCancel)
    }

    static func makeIntent(
        task: PlantCareTaskSnapshot,
        plant: Plant,
        now: Date,
        calendar: Calendar,
        defaults: UserDefaults,
        includesReminder: Bool = true
    ) -> DomainScheduleCreateIntent {
        let dueDay = calendar.startOfDay(for: task.dueDate)
        let leadDays = PlantReminderPreferenceStore.reminderLeadDays(
            forPlantID: plant.id,
            careType: task.careType,
            defaults: defaults
        )
        let recurrenceEndDate = PlantReminderPreferenceStore.recurrenceEndDate(
            forPlantID: plant.id,
            careType: task.careType,
            defaults: defaults
        )
        let l = L10n.current
        return DomainScheduleCreateIntent(
            title: "\(task.careType.emoji) \(plant.name) · \(task.careType.displayName(l: l))\(planTitleMarker)\(safetyReminderSuffix(for: plant, defaults: defaults))",
            startDate: dueDay,
            isAllDay: true,
            eventType: task.careType.eventType.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString,
            recurrenceDays: task.effectiveIntervalDays,
            recurrenceEndDate: recurrenceEndDate,
            reminderDates: includesReminder
                ? [reminderDate(for: dueDay, now: now, calendar: calendar, defaults: defaults, leadDays: leadDays)]
                : [],
            writeKind: .care,
            source: .domainService
        )
    }

    static func reminderDate(
        for dueDate: Date,
        now: Date,
        calendar: Calendar,
        defaults: UserDefaults,
        leadDays: Int = 0
    ) -> Date {
        PlantReminderPreferenceStore.reminderDate(
            for: dueDate,
            now: now,
            calendar: calendar,
            defaults: defaults,
            leadDays: leadDays
        )
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

    static func fetchReminders(ids: [UUID], context: ModelContext) -> [Reminder] {
        ids.compactMap { id in
            var descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.id == id
                }
            )
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor))?.first
        }
    }

    static func commitSideEffects(
        notificationIDsToCancel: [String],
        remindersToSchedule: [Reminder],
        defaultWrites: [PlantCarePlanDefaultWrite],
        defaultRemovals: [String],
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults
    ) {
        for key in Set(defaultRemovals) {
            defaults.removeObject(forKey: key)
        }
        for write in defaultWrites {
            defaults.set(write.value, forKey: write.key)
        }
        DomainRehydrateEffectsDispatcher.cancelNotifications(
            notificationIDsToCancel,
            notifications: notifications
        )
        for reminder in remindersToSchedule {
            notifications.schedule(reminder: reminder)
        }
    }

    static func storageKey(plant: Plant, type: PlantCareType) -> String {
        "\(storagePrefix)_\(plant.id.uuidString)_\(type.rawValue)"
    }

    private static var planTitleMarker: String {
        PlantReminderPreferenceStore.generatedPlanTitleMarker
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
