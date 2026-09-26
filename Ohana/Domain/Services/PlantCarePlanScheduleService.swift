//
//  PlantCarePlanScheduleService.swift
//  Ohana
//
//  Materializes local plant-care plan snapshots into Calendar events,
//  Reminders, notification scheduling, and future sync metadata.
//

import Foundation
import SwiftData

typealias PlantCarePlanPersistenceSave = @MainActor (ModelContext) -> ModelContextSaveResult

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
    fileprivate let reminderScheduling: ReminderSchedulingManaging?
    fileprivate(set) var postCommitDispatchHandle: PlantPlanPostCommitDispatchHandle?

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
        defaultRemovals: [String] = [],
        reminderScheduling: ReminderSchedulingManaging? = nil,
        postCommitDispatchHandle: PlantPlanPostCommitDispatchHandle? = nil
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
        self.reminderScheduling = reminderScheduling
        self.postCommitDispatchHandle = postCommitDispatchHandle
    }

    static func == (lhs: PlantCarePlanScheduleResult, rhs: PlantCarePlanScheduleResult) -> Bool {
        lhs.plantID == rhs.plantID &&
            lhs.eventIDs == rhs.eventIDs &&
            lhs.reminderIDs == rhs.reminderIDs &&
            lhs.removedEventIDs == rhs.removedEventIDs &&
            lhs.removedReminderIDs == rhs.removedReminderIDs &&
            lhs.scheduledReminderSync == rhs.scheduledReminderSync &&
            lhs.didPersist == rhs.didPersist &&
            lhs.persistenceErrorDescription == rhs.persistenceErrorDescription &&
            lhs.reminderIDsToSchedule == rhs.reminderIDsToSchedule &&
            lhs.notificationIDsToCancel == rhs.notificationIDsToCancel &&
            lhs.defaultWrites == rhs.defaultWrites &&
            lhs.defaultRemovals == rhs.defaultRemovals
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
    private static let ownedPlanCandidateFetchLimit = 32

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
        saveChanges: Bool = true,
        localization: L10n = .current,
        useRegisteredReminderScheduling: Bool = true,
        postCommitDispatcher: PlantPlanPostCommitDispatching? = nil,
        persistenceSave: PlantCarePlanPersistenceSave = { context in
            context.safeSaveResult(publishFailureEvent: true)
        }
    ) -> PlantCarePlanScheduleResult {
        guard !plant.isArchived else {
            return syncArchivedPlant(
                plant,
                context: context,
                now: now,
                notifications: notifications,
                defaults: defaults,
                saveChanges: saveChanges,
                postCommitDispatcher: postCommitDispatcher,
                persistenceSave: persistenceSave
            )
        }

        let enabledScheduledCareTypes = enabledCareTypes(for: plant, defaults: defaults)
        let scheduledRawTypes = Set(enabledScheduledCareTypes.map(\.rawValue))
        let planningHistory: PlantCarePlanningHistory
        do {
            planningHistory = try PlantCarePlanningHistoryQuery.build(
                plantID: plant.id,
                context: context
            )
        } catch {
            return .persistenceFailed(
                plantID: plant.id,
                errorDescription: error.localizedDescription
            )
        }
        let tasks = PlantCarePlanService.tasks(
            for: plant,
            history: planningHistory,
            now: now,
            calendar: calendar
        )
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
                defaults: defaults,
                localization: localization
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
        let structuredReminderScheduling: ReminderSchedulingManaging? = if let providedReminderScheduling {
            providedReminderScheduling
        } else if useRegisteredReminderScheduling {
            DomainServiceDependencyRegistry.registeredReminderScheduling(
                careLedger: CareLedgerService()
            )
        } else {
            nil
        }
        var result = PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: eventIDs,
            reminderIDs: reminderIDs,
            removedEventIDs: removedEventIDs,
            removedReminderIDs: removedReminderIDs,
            scheduledReminderSync: shouldScheduleReminders,
            reminderIDsToSchedule: shouldScheduleReminders ? remindersToSchedule.map(\.id) : [],
            notificationIDsToCancel: notificationIDsToCancel,
            defaultWrites: defaultWrites,
            defaultRemovals: defaultRemovals,
            reminderScheduling: structuredReminderScheduling
        )
        if saveChanges {
            let saveResult = persistenceSave(context)
            guard saveResult.didSave else {
                context.rollback()
                return .persistenceFailed(plantID: plant.id, errorDescription: saveResult.errorDescription)
            }
            result.postCommitDispatchHandle = commitSideEffects(
                for: result,
                context: context,
                notifications: notifications,
                defaults: defaults,
                postCommitDispatcher: postCommitDispatcher
            )
        }

        return result
    }

    private static func syncArchivedPlant(
        _ plant: Plant,
        context: ModelContext,
        now: Date,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults,
        saveChanges: Bool,
        postCommitDispatcher: PlantPlanPostCommitDispatching?,
        persistenceSave: PlantCarePlanPersistenceSave
    ) -> PlantCarePlanScheduleResult {
        let removed = removeScheduledTasks(
            plant: plant,
            context: context,
            now: now,
            notifications: notifications,
            defaults: defaults
        )
        if saveChanges {
            let saveResult = persistenceSave(context)
            guard saveResult.didSave else {
                context.rollback()
                return .persistenceFailed(plantID: plant.id, errorDescription: saveResult.errorDescription)
            }
            _ = commitSideEffects(
                for: removed,
                context: context,
                notifications: notifications,
                defaults: defaults,
                postCommitDispatcher: postCommitDispatcher
            )
        }
        return removed
    }

    private static func enabledCareTypes(for plant: Plant, defaults: UserDefaults) -> [PlantCareType] {
        scheduledCareTypes.filter {
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

    @discardableResult
    static func commitSideEffects(
        for result: PlantCarePlanScheduleResult,
        context: ModelContext,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard,
        postCommitDispatcher providedPostCommitDispatcher: PlantPlanPostCommitDispatching? = nil
    ) -> PlantPlanPostCommitDispatchHandle? {
        guard result.didPersist else { return nil }
        for key in Set(result.defaultRemovals) {
            defaults.removeObject(forKey: key)
        }
        for write in result.defaultWrites {
            defaults.set(write.value, forKey: write.key)
        }
        DomainRehydrateEffectsDispatcher.cancelNotifications(
            result.notificationIDsToCancel,
            notifications: notifications
        )

        guard !result.reminderIDsToSchedule.isEmpty else { return nil }
        if let reminderScheduling = providedReminderScheduling ?? result.reminderScheduling {
            let postCommitDispatcher = providedPostCommitDispatcher ?? PlantPlanPostCommitDispatcher.shared
            return postCommitDispatcher.dispatch(
                reminderIDs: result.reminderIDsToSchedule,
                context: context,
                reminderScheduling: reminderScheduling,
                source: .service
            )
        }

        for reminder in fetchReminders(ids: result.reminderIDsToSchedule, context: context) {
            notifications.schedule(reminder: reminder)
        }
        return nil
    }

    /// Automatic plant care projections support the Free core workflow and do
    /// not consume a user-created ordinary-plan slot.
    static func isGeneratedCalendarPlan(_ event: Event) -> Bool {
        PlantCarePlanIdentity.isGeneratedPlan(event)
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

    struct AuthorizedOwnedPlanDeletion {
        let event: Event
        let mutation: AuthorizedDomainScheduleMutation
    }

    struct OwnedPlanRemovalEffects {
        var eventIDs: [UUID] = []
        var reminderIDs: [UUID] = []
        var notificationIDsToCancel: [String] = []
    }

    static func migrateOwnedPlans(
        _ ownedEvents: [Event],
        intent: DomainScheduleCreateIntent,
        plant: Plant,
        careType: PlantCareType,
        storageKey: String,
        context: ModelContext,
        now: Date
    ) -> UpsertOutcome? {
        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: careType)
        let ownedIDs = Set(ownedEvents.map(\.id))
        guard !ownedEvents.isEmpty,
              event(id: expectedID, context: context).map({ ownedIDs.contains($0.id) }) ?? true,
              let deletions = authorizedOwnedPlanDeletions(
                  for: ownedEvents,
                  writeKind: .care,
                  context: context
              ),
              let creation = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }

        let removed = deleteOwnedPlans(deletions, context: context, now: now)
        let writeResult = DomainScheduleWriter.createEvent(
            plan: creation,
            context: context,
            maxReminderOccurrences: 1
        )
        writeResult.event.id = expectedID
        CloudSyncMutationRecorder.markModified(writeResult.event, context: context, modifiedAt: now)
        for reminder in writeResult.reminders {
            CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: now)
        }
        return UpsertOutcome(
            event: writeResult.event,
            pendingReminder: writeResult.reminders.first,
            removedEventIDs: removed.eventIDs,
            removedReminderIDs: removed.reminderIDs,
            notificationIDsToCancel: removed.notificationIDsToCancel,
            defaultWrites: [PlantCarePlanDefaultWrite(key: storageKey, value: expectedID.uuidString)]
        )
    }

    static func upsertScheduledTask(
        _ task: PlantCareTaskSnapshot,
        plant: Plant,
        context: ModelContext,
        now: Date,
        calendar: Calendar,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults,
        localization: L10n
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
            localization: localization,
            includesReminder: systemReminderEnabled
        )
        let key = storageKey(plant: plant, type: task.careType)
        let ownedCandidates = ownedPlanCandidates(
            defaults.string(forKey: key),
            plant: plant,
            type: task.careType,
            context: context
        )
        let reminderDate = reminderDate(for: task.dueDate, now: now, calendar: calendar, defaults: defaults)

        if let existing = ownedCandidates.first(where: {
            PlantCarePlanIdentity.isStructuredMatch($0, plantID: plant.id, careType: task.careType)
        }) {
            let duplicates = ownedCandidates.filter { $0.id != existing.id }
            guard let duplicateDeletions = authorizedOwnedPlanDeletions(
                for: duplicates,
                writeKind: .care,
                context: context
            ), let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
                event: existing,
                intent: intent,
                writeKind: .care,
                source: .domainService,
                context: context
            ) else { return nil }

            guard DomainScheduleWriter.updateEvent(existing, intent: intent, mutation: mutation) else {
                return nil
            }
            existing.isCompleted = false
            existing.completedOccurrences.removeAll()
            CloudSyncMutationRecorder.markModified(existing, context: context, modifiedAt: now)
            let duplicateEffects = deleteOwnedPlans(duplicateDeletions, context: context, now: now)

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
                removedEventIDs: duplicateEffects.eventIDs,
                removedReminderIDs: duplicateEffects.reminderIDs + reminderOutcome.removedReminderIDs,
                notificationIDsToCancel: duplicateEffects.notificationIDsToCancel + reminderOutcome.notificationIDsToCancel,
                defaultWrites: [PlantCarePlanDefaultWrite(key: key, value: existing.id.uuidString)]
            )
        }

        if !ownedCandidates.isEmpty {
            return migrateOwnedPlans(
                ownedCandidates,
                intent: intent,
                plant: plant,
                careType: task.careType,
                storageKey: key,
                context: context,
                now: now
            )
        }

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: task.careType)
        guard event(id: expectedID, context: context) == nil,
              let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }
        let writeResult = DomainScheduleWriter.createEvent(plan: plan, context: context, maxReminderOccurrences: 1)
        writeResult.event.id = expectedID
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
        let ownedCandidates = ownedPlanCandidates(
            defaults.string(forKey: key),
            plant: plant,
            type: type,
            context: context
        )
        guard !ownedCandidates.isEmpty else {
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
        guard let deletions = authorizedOwnedPlanDeletions(
            for: ownedCandidates,
            writeKind: .lifecycle(.cleanupActiveSchedules),
            context: context
        ) else {
            return .empty(plantID: plant.id)
        }
        let removed = deleteOwnedPlans(deletions, context: context, now: now)
        return PlantCarePlanScheduleResult(
            plantID: plant.id,
            eventIDs: [],
            reminderIDs: [],
            removedEventIDs: removed.eventIDs,
            removedReminderIDs: removed.reminderIDs,
            scheduledReminderSync: false,
            notificationIDsToCancel: removed.notificationIDsToCancel,
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
        localization l: L10n,
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
        let careKind = TaskCareKind(plantCareType: task.careType)
        return DomainScheduleCreateIntent(
            title: "\(task.careType.emoji) \(plant.name) · \(task.careType.displayName(l: l))\(safetyReminderSuffix(for: plant, defaults: defaults, localization: l))",
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
            taskCareKindRaw: careKind?.rawValue ?? "",
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
        return event(id: id, context: context)
    }

    static func event(id: UUID, context: ModelContext) -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.id == id
            }
        )
        descriptor.fetchLimit = 1
        let events = (try? context.fetch(descriptor)) ?? []
        return events.first
    }

    static func ownedPlanCandidates(
        _ rawID: String?,
        plant: Plant,
        type: PlantCareType,
        context: ModelContext
    ) -> [Event] {
        var candidates: [Event] = []
        var includedIDs: Set<UUID> = []
        func include(_ event: Event) {
            guard includedIDs.insert(event.id).inserted else { return }
            candidates.append(event)
        }

        let expectedID = PlantCarePlanIdentity.expectedEventID(plantID: plant.id, careType: type)
        if let structured = event(id: expectedID, context: context),
           PlantCarePlanIdentity.isStructuredMatch(structured, plantID: plant.id, careType: type) {
            include(structured)
        }

        if let stored = storedPlanEvent(rawID, context: context),
           PlantCarePlanIdentity.isStoredPointerMigrationEvidence(
               stored,
               plantID: plant.id,
               careType: type
           ) {
            include(stored)
        }

        let plantID = plant.id.uuidString
        let plantType = EntityKind.plant.rawValue
        let eventType = type.eventType.rawValue
        let legacyMarker = PlantCarePlanIdentity.legacyTitleMarker
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == plantType &&
                    event.relatedEntityId == plantID &&
                    event.eventType == eventType &&
                    event.title.contains(legacyMarker)
            },
            sortBy: [SortDescriptor(\Event.createdAt)]
        )
        descriptor.fetchLimit = ownedPlanCandidateFetchLimit
        let events = (try? context.fetch(descriptor)) ?? []
        for event in events where PlantCarePlanIdentity.isLegacyMatch(
            event,
            plantID: plant.id,
            careType: type
        ) {
            include(event)
        }
        return candidates
    }

    static func authorizedOwnedPlanDeletions(
        for events: [Event],
        writeKind: MemberWriteKind,
        context: ModelContext
    ) -> [AuthorizedOwnedPlanDeletion]? {
        var deletions: [AuthorizedOwnedPlanDeletion] = []
        deletions.reserveCapacity(events.count)
        for event in events {
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                event: event,
                writeKind: writeKind,
                source: .domainService,
                context: context
            ), mutation.allowsScheduleDeletion else {
                return nil
            }
            deletions.append(AuthorizedOwnedPlanDeletion(event: event, mutation: mutation))
        }
        return deletions
    }

    static func deleteOwnedPlans(
        _ deletions: [AuthorizedOwnedPlanDeletion],
        context: ModelContext,
        now: Date
    ) -> OwnedPlanRemovalEffects {
        var effects = OwnedPlanRemovalEffects()
        for deletion in deletions {
            let result = DomainScheduleWriter.deleteEvent(
                deletion.event,
                mutation: deletion.mutation,
                context: context,
                deletedAt: now
            )
            if let eventID = result.eventID {
                effects.eventIDs.append(eventID)
            }
            effects.reminderIDs.append(contentsOf: result.reminderIDs)
            effects.notificationIDsToCancel.append(contentsOf: result.notificationIdsToCancel)
        }
        return effects
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

    static func storageKey(plant: Plant, type: PlantCareType) -> String {
        "\(storagePrefix)_\(plant.id.uuidString)_\(type.rawValue)"
    }

    static func safetyReminderSuffix(
        for plant: Plant,
        defaults: UserDefaults,
        localization l: L10n
    ) -> String {
        let hasPets = defaults.object(forKey: "ohana_onboarding_has_pets") == nil
            ? true
            : defaults.bool(forKey: "ohana_onboarding_has_pets")
        let hasChildren = defaults.bool(forKey: "ohana_onboarding_has_children")
        if hasPets, plant.isToxicToCats || plant.isToxicToDogs {
            let message = l.tr(
                zh: "放到宠物够不到处",
                en: "Keep out of pets' reach",
                de: "Außer Reichweite von Haustieren",
                es: "Mantener fuera del alcance de las mascotas",
                pt: "Manter fora do alcance dos animais",
                fr: "Garder hors de portée des animaux",
                ja: "ペットの手が届かない場所に置く",
                ko: "반려동물이 닿지 않는 곳에 두기",
                it: "Tenere fuori dalla portata degli animali"
            )
            return " · \(message)"
        }
        if hasChildren, plant.isToxicToChildren {
            let message = l.tr(
                zh: "注意儿童误食",
                en: "Watch for child ingestion",
                de: "Auf Verschlucken durch Kinder achten",
                es: "Evitar que los niños la ingieran",
                pt: "Evitar que crianças a ingiram",
                fr: "Éviter l'ingestion par les enfants",
                ja: "子どもの誤飲に注意",
                ko: "어린이 섭취 주의",
                it: "Evitare l'ingestione da parte dei bambini"
            )
            return " · \(message)"
        }
        return ""
    }
}
