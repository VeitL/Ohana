//
//  CalendarCommands.swift
//  Ohana
//
//  Domain write boundaries for calendar events, event completion, deletion, and reminders.
//

import Foundation
import SwiftData

struct EventCompletionRewardResult: Equatable {
    let awarded: Bool
    let skippedByExistingCare: Bool
    let coconutDelta: Int
}

struct CalendarEventPlanCommandInput: Equatable {
    let title: String
    let startDate: Date
    let isAllDay: Bool
    let eventType: EventType
    let relatedEntityType: String
    let relatedEntityId: String
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let reminderLeadMinutes: Int?
    let assigneeId: String?
    let taskCareKindRaw: String

    init(
        title: String,
        startDate: Date,
        isAllDay: Bool,
        eventType: EventType,
        relatedEntityType: String,
        relatedEntityId: String,
        recurrenceDays: Int,
        recurrenceEndDate: Date?,
        reminderLeadMinutes: Int?,
        assigneeId: String?,
        taskCareKindRaw: String = ""
    ) {
        self.title = title
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.eventType = eventType
        self.relatedEntityType = relatedEntityType
        self.relatedEntityId = relatedEntityId
        self.recurrenceDays = recurrenceDays
        self.recurrenceEndDate = recurrenceEndDate
        self.reminderLeadMinutes = reminderLeadMinutes
        self.assigneeId = assigneeId
        self.taskCareKindRaw = taskCareKindRaw
    }

    var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CalendarEventPlanCommandResult: Equatable {
    let eventID: UUID
    let reminderIDs: [UUID]
    let affectedSubjectIDs: Set<UUID>
    let scheduledReminderSync: Bool
}

enum CalendarCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return "日历保存失败：\(reason)"
            }
            return "日历保存失败，请稍后重试。"
        }
    }
}

enum CalendarEventPlanCommandService {
    private static let maxReminderOccurrences = 500

    @discardableResult
    @MainActor
    static func createEvent(
        input: CalendarEventPlanCommandInput,
        context: ModelContext,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) throws -> CalendarEventPlanCommandResult? {
        guard !input.cleanTitle.isEmpty else { return nil }
        let intent = DomainScheduleCreateIntent(
            title: input.cleanTitle,
            startDate: input.startDate,
            endDate: nil,
            isAllDay: input.isAllDay,
            eventType: input.eventType.rawValue,
            relatedEntityType: input.relatedEntityType,
            relatedEntityId: input.relatedEntityId,
            recurrenceDays: input.recurrenceDays,
            recurrenceEndDate: input.recurrenceEndDate,
            reminderLeadMinutes: input.reminderLeadMinutes,
            assigneeId: input.assigneeId,
            taskCareKindRaw: input.taskCareKindRaw,
            writeKind: writeKind(for: input),
            source: .userCommand
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return nil
        }
        let writeResult = DomainScheduleWriter.createEvent(
            plan: plan,
            context: context,
            maxReminderOccurrences: maxReminderOccurrences
        )
        let event = writeResult.event
        let createdReminders = writeResult.reminders
        try saveCalendarChanges(context: context)

        let shouldScheduleReminders = scheduleNotifications && !createdReminders.isEmpty
        if shouldScheduleReminders {
            let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
            Task { @MainActor in
                await reminderScheduling.scheduleManyIfNeeded(
                    reminders: createdReminders,
                    context: context,
                    source: .calendar
                )
            }
        }

        return CalendarEventPlanCommandResult(
            eventID: event.id,
            reminderIDs: createdReminders.map(\.id),
            affectedSubjectIDs: plan.resolution.affectedEntityIDs,
            scheduledReminderSync: shouldScheduleReminders
        )
    }

    @discardableResult
    @MainActor
    static func updateEvent(
        event: Event,
        input: CalendarEventPlanCommandInput,
        context: ModelContext,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil,
        now: Date = Date()
    ) throws -> CalendarEventPlanCommandResult? {
        guard !input.cleanTitle.isEmpty else { return nil }
        let intent = DomainScheduleCreateIntent(
            title: input.cleanTitle,
            startDate: input.startDate,
            endDate: nil,
            isAllDay: input.isAllDay,
            eventType: input.eventType.rawValue,
            relatedEntityType: input.relatedEntityType,
            relatedEntityId: input.relatedEntityId,
            recurrenceDays: input.recurrenceDays,
            recurrenceEndDate: input.recurrenceEndDate,
            reminderLeadMinutes: input.reminderLeadMinutes,
            assigneeId: input.assigneeId,
            taskCareKindRaw: input.taskCareKindRaw,
            writeKind: writeKind(for: input),
            source: .userCommand
        )
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
            event: event,
            intent: intent,
            writeKind: writeKind(for: input),
            source: .userCommand,
            context: context
        ) else {
            return nil
        }

        guard DomainScheduleWriter.updateEvent(event, intent: intent, mutation: mutation) else {
            return nil
        }
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: now)
        replaceReminders(
            for: event,
            context: context,
            now: now
        )

        let reminderDates = reminderDates(for: input)
        let createdReminders: [Reminder]
        if reminderDates.isEmpty {
            createdReminders = []
        } else if let reminderMutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: writeKind(for: input),
            source: .userCommand,
            context: context
        ) {
            createdReminders = DomainScheduleWriter.createReminders(
                for: event,
                scheduledAt: reminderDates,
                mutation: reminderMutation,
                context: context
            )
            let reminderOccurrenceDates = occurrenceDates(for: input)
            for (index, reminder) in createdReminders.enumerated() {
                reminder.occurrenceAt = reminderOccurrenceDates.indices.contains(index)
                    ? reminderOccurrenceDates[index]
                    : nil
                CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: now)
            }
        } else {
            createdReminders = []
        }
        try saveCalendarChanges(context: context)

        let shouldScheduleReminders = scheduleNotifications && !createdReminders.isEmpty
        if shouldScheduleReminders {
            let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
            Task { @MainActor in
                await reminderScheduling.scheduleManyIfNeeded(
                    reminders: createdReminders,
                    context: context,
                    source: .calendar
                )
            }
        }

        return CalendarEventPlanCommandResult(
            eventID: event.id,
            reminderIDs: createdReminders.map(\.id),
            affectedSubjectIDs: DomainScheduleSubjectResolver.resolve(intent: intent, context: context).affectedEntityIDs,
            scheduledReminderSync: shouldScheduleReminders
        )
    }

    @discardableResult
    @MainActor
    private static func replaceReminders(
        for event: Event,
        context: ModelContext,
        now: Date
    ) -> [DomainScheduleDeleteResult] {
        let existingReminders = event.reminders
        return existingReminders.compactMap { reminder in
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                reminder: reminder,
                writeKind: writeKind(for: event),
                source: .userCommand,
                context: context
            ) else { return nil }
            let result = DomainScheduleWriter.deleteReminder(
                reminder,
                mutation: mutation,
                context: context,
                deletedAt: now
            )
            DomainScheduleEffectsDispatcher.dispatch(delete: result)
            return result
        }
    }

    private static func reminderDates(for input: CalendarEventPlanCommandInput, calendar: Calendar = .current) -> [Date] {
        guard let leadMinutes = input.reminderLeadMinutes else { return [] }
        if input.recurrenceDays >= 1, let recurrenceEndDate = input.recurrenceEndDate {
            var dates: [Date] = []
            var cursor = input.startDate
            var safetyCount = 0
            while cursor <= recurrenceEndDate, safetyCount < maxReminderOccurrences {
                dates.append(calendar.date(byAdding: .minute, value: -leadMinutes, to: cursor) ?? cursor)
                guard let next = calendar.date(byAdding: .day, value: input.recurrenceDays, to: cursor),
                      next > cursor else {
                    break
                }
                cursor = next
                safetyCount += 1
            }
            return dates
        }
        return [calendar.date(byAdding: .minute, value: -leadMinutes, to: input.startDate) ?? input.startDate]
    }

    private static func occurrenceDates(
        for input: CalendarEventPlanCommandInput,
        calendar: Calendar = .current
    ) -> [Date] {
        guard input.reminderLeadMinutes != nil else { return [] }
        guard input.recurrenceDays >= 1,
              let recurrenceEndDate = input.recurrenceEndDate else {
            return [input.startDate]
        }
        var dates: [Date] = []
        var cursor = input.startDate
        while cursor <= recurrenceEndDate, dates.count < maxReminderOccurrences {
            dates.append(cursor)
            guard let next = calendar.date(
                byAdding: .day,
                value: input.recurrenceDays,
                to: cursor
            ), next > cursor else { break }
            cursor = next
        }
        return dates
    }

    private static func writeKind(for input: CalendarEventPlanCommandInput) -> MemberWriteKind {
        switch input.eventType {
        case .birthday, .anniversary:
            .memorialContentWithOptionalDerivations
        case .daily, .health, .task, .shoppingList, .chore, .vaccine, .externalDeworming,
             .internalDeworming, .grooming, .vetVisit, .foodChange, .litterBox, .watering,
             .fertilizing, .plantRepotting, .plantPruning, .plantMisting, .plantRotation,
             .plantLeafCleaning, .plantPestCheck, .plantHealthCheck,
             .medication, .petMedication, .petMedicationDose, .insurancePremium:
            .care
        }
    }

    private static func writeKind(for event: Event) -> MemberWriteKind {
        switch EventType(rawValue: event.eventType) {
        case .birthday, .anniversary:
            .memorialContentWithOptionalDerivations
        case .daily, .health, .task, .shoppingList, .chore, .vaccine, .externalDeworming,
             .internalDeworming, .grooming, .vetVisit, .foodChange, .litterBox, .watering,
             .fertilizing, .plantRepotting, .plantPruning, .plantMisting, .plantRotation,
             .plantLeafCleaning, .plantPestCheck, .plantHealthCheck,
             .medication, .petMedication, .petMedicationDose, .insurancePremium,
             .none:
            .care
        }
    }

    @MainActor
    static func saveCalendarChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw CalendarCommandError.persistenceFailed(saveResult.errorDescription)
        }
    }
}

enum EventCompletionCommandService {
    @discardableResult
    @MainActor
    static func awardCompletionIfEligible(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        executorId: String? = nil,
        now: Date = Date()
    ) -> EventCompletionRewardResult {
        _ = (
            event,
            occurrenceDate,
            context,
            wallet,
            careLedger,
            executorId,
            now
        )
        return EventCompletionRewardResult(awarded: false, skippedByExistingCare: false, coconutDelta: 0)
    }
}

@MainActor
struct EventCompletionCommandExecutor {
    let context: ModelContext
    let wallet: CoconutWalletManaging
    let careLedger: CareLedgerRecording
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter)
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            wallet: services.coconutWallet,
            careLedger: services.careLedger,
            revisions: services.domainRevisions
        )
    }

    init(
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        revisions: DomainRevisionPublishing
    ) {
        self.context = context
        self.wallet = wallet
        self.careLedger = careLedger
        self.revisions = revisions
    }

    @discardableResult
    func awardCompletionIfEligible(
        event: Event,
        occurrenceDate: Date,
        executorId: String?,
        now: Date = Date(),
        note: String
    ) -> EventCompletionRewardResult {
        let result = EventCompletionCommandService.awardCompletionIfEligible(
            event: event,
            occurrenceDate: occurrenceDate,
            context: context,
            wallet: wallet,
            careLedger: careLedger,
            executorId: executorId,
            now: now
        )
        if result.awarded {
            revisions.publishEventCompletionReward(result, eventID: event.id, note: note)
        }
        return result
    }
}

struct CalendarEventCompletionResult: Equatable {
    let eventID: UUID
    let isCompleted: Bool
    let syncedReminderCount: Int
    let affectedSubjectIDs: Set<UUID>
    let didChange: Bool
    let didWriteFact: Bool
    let allowsDerivedEffects: Bool
    let factDate: Date?
    let operationDate: Date

    init(
        eventID: UUID,
        isCompleted: Bool,
        syncedReminderCount: Int,
        affectedSubjectIDs: Set<UUID> = [],
        didChange: Bool = true,
        didWriteFact: Bool? = nil,
        allowsDerivedEffects: Bool? = nil,
        factDate: Date? = nil,
        operationDate: Date = Date()
    ) {
        self.eventID = eventID
        self.isCompleted = isCompleted
        self.syncedReminderCount = syncedReminderCount
        self.affectedSubjectIDs = affectedSubjectIDs
        self.didChange = didChange
        self.didWriteFact = didWriteFact ?? didChange
        self.allowsDerivedEffects = allowsDerivedEffects ?? didChange
        self.factDate = factDate
        self.operationDate = operationDate
    }

    var revisionAffectedEntityIDs: Set<UUID> {
        var affected = affectedSubjectIDs
        affected.insert(eventID)
        return affected
    }
}

nonisolated struct CalendarEventCompletionOptions {
    let reminderCompletion: ReminderCompleting?
    let economy: CareEventEconomyAwarding?
    let schedulePlantCareNotifications: Bool

    init(
        reminderCompletion: ReminderCompleting? = nil,
        economy: CareEventEconomyAwarding? = nil,
        schedulePlantCareNotifications: Bool = true
    ) {
        self.reminderCompletion = reminderCompletion
        self.economy = economy
        self.schedulePlantCareNotifications = schedulePlantCareNotifications
    }
}

enum CalendarEventDeletionScope: Equatable {
    case wholeEvent
    case singleOccurrence
    case thisAndFuture

    var revisionActionKey: String {
        switch self {
        case .wholeEvent:
            "wholeEvent"
        case .singleOccurrence:
            "singleOccurrence"
        case .thisAndFuture:
            "thisAndFuture"
        }
    }
}

enum CalendarEventDeletionOutcome: Equatable {
    case deletedEvent(UUID)
    case advancedStart(UUID)
    case truncated(UUID)
    case split(originalID: UUID, newEventID: UUID)

    var primaryEventID: UUID {
        switch self {
        case let .deletedEvent(id), let .advancedStart(id), let .truncated(id):
            id
        case let .split(originalID, _):
            originalID
        }
    }

    var affectedEventIDs: Set<UUID> {
        switch self {
        case let .deletedEvent(id), let .advancedStart(id), let .truncated(id):
            [id]
        case let .split(originalID, newEventID):
            [originalID, newEventID]
        }
    }
}

enum CalendarEventCommandService {
    private struct PetTaskCompletionPreparation {
        let syncResult: CalendarTaskCompletionSyncService.PetTaskSyncResult?
        let blockedResult: CalendarEventCompletionResult?
    }

    private struct PlantCareCompletionPreparation {
        let syncResult: PlantCareScheduleSyncResult?
        let blockedResult: CalendarEventCompletionResult?
    }

    @discardableResult
    @MainActor
    static func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        options: CalendarEventCompletionOptions = CalendarEventCompletionOptions()
    ) throws -> CalendarEventCompletionResult {
        let reminderCompletion = options.reminderCompletion ?? ReminderCompletionService()
        let shouldComplete = !event.isOccurrenceMarkedComplete(on: occurrenceDate)
        let affectedSubjectIDs = affectedSubjectIDs(for: event, context: context)
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: writeKind(for: event),
            source: .userCommand,
            context: context
        ) else {
            return unchangedCompletionResult(
                event: event,
                occurrenceDate: occurrenceDate,
                affectedSubjectIDs: affectedSubjectIDs,
                now: now
            )
        }
        let petPreparation = preparePetTaskCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            shouldComplete: shouldComplete,
            pets: pets,
            context: context,
            executorID: executorId,
            now: now,
            economy: options.economy,
            affectedSubjectIDs: affectedSubjectIDs
        )
        if let blockedResult = petPreparation.blockedResult { return blockedResult }
        let petTaskSyncResult = petPreparation.syncResult
        let remindersToSync = remindersForCompletionSync(
            event: event,
            occurrenceDate: occurrenceDate
        )
        let plantPreparation = preparePlantCareCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            shouldComplete: shouldComplete,
            reminders: remindersToSync,
            context: context,
            executorID: executorId,
            now: now,
            scheduleNotifications: options.schedulePlantCareNotifications,
            affectedSubjectIDs: affectedSubjectIDs
        )
        if let blockedResult = plantPreparation.blockedResult { return blockedResult }
        let plantCareSyncResult = plantPreparation.syncResult
        guard DomainScheduleWriter.setEventOccurrenceCompletion(
            event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            mutation: mutation,
            context: context,
            modifiedAt: now
        ) else {
            return unchangedCompletionResult(
                event: event,
                occurrenceDate: occurrenceDate,
                affectedSubjectIDs: affectedSubjectIDs,
                now: now
            )
        }

        guard syncReminders(
            remindersToSync,
            shouldComplete: shouldComplete,
            occurrenceDate: occurrenceDate,
            executorID: executorId,
            context: context,
            reminderCompletion: reminderCompletion
        ) else {
            context.rollback()
            return unchangedCompletionResult(
                event: event,
                occurrenceDate: occurrenceDate,
                affectedSubjectIDs: affectedSubjectIDs,
                now: now,
                didWriteFact: petTaskSyncResult?.didWriteFact ?? plantCareSyncResult?.didWriteCareFact ?? false,
                allowsDerivedEffects: false,
                factDate: occurrenceDate
            )
        }
        if remindersToSync.isEmpty {
            try CalendarEventPlanCommandService.saveCalendarChanges(context: context)
            if let plantCareSyncResult {
                PlantCareScheduleSyncService.syncPlanAfterCompletion(
                    plantCareSyncResult,
                    context: context,
                    now: now,
                    scheduleNotifications: options.schedulePlantCareNotifications
                )
            }
        }

        return CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: shouldComplete,
            syncedReminderCount: remindersToSync.count,
            affectedSubjectIDs: affectedSubjectIDs,
            didChange: true,
            didWriteFact: petTaskSyncResult?.didWriteFact ?? plantCareSyncResult?.didWriteCareFact ?? true,
            allowsDerivedEffects: petTaskSyncResult?.allowsDerivedEffects ?? plantCareSyncResult?.allowsScheduleCompletion ?? true,
            factDate: occurrenceDate,
            operationDate: now
        )
    }

    private static func preparePetTaskCompletion(
        event: Event,
        occurrenceDate: Date,
        shouldComplete: Bool,
        pets: [Pet],
        context: ModelContext,
        executorID: String?,
        now: Date,
        economy: CareEventEconomyAwarding?,
        affectedSubjectIDs: Set<UUID>
    ) -> PetTaskCompletionPreparation {
        guard CalendarTaskCompletionSyncService.isPetTask(event: event) else {
            return PetTaskCompletionPreparation(syncResult: nil, blockedResult: nil)
        }
        let syncResult = CalendarTaskCompletionSyncService.syncPetTask(
            event: event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            pets: pets,
            context: context,
            executorId: executorID,
            operationDate: now,
            economy: economy
        )
        if !syncResult.didPersist || (!shouldComplete && syncResult == .noOp) {
            return PetTaskCompletionPreparation(
                syncResult: syncResult,
                blockedResult: unchangedCompletionResult(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    affectedSubjectIDs: affectedSubjectIDs,
                    now: now
                )
            )
        }
        if shouldComplete && !syncResult.shouldCompleteOccurrence {
            return PetTaskCompletionPreparation(
                syncResult: syncResult,
                blockedResult: unchangedCompletionResult(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    affectedSubjectIDs: affectedSubjectIDs,
                    now: now,
                    didWriteFact: syncResult.didWriteFact,
                    allowsDerivedEffects: syncResult.allowsDerivedEffects,
                    factDate: occurrenceDate
                )
            )
        }
        return PetTaskCompletionPreparation(syncResult: syncResult, blockedResult: nil)
    }

    private static func preparePlantCareCompletion(
        event: Event,
        occurrenceDate: Date,
        shouldComplete: Bool,
        reminders: [Reminder],
        context: ModelContext,
        executorID: String?,
        now: Date,
        scheduleNotifications: Bool,
        affectedSubjectIDs: Set<UUID>
    ) -> PlantCareCompletionPreparation {
        guard shouldComplete, PlantCareScheduleSyncService.isPlantCareEvent(event) else {
            return PlantCareCompletionPreparation(syncResult: nil, blockedResult: nil)
        }
        let sourceReminder = reminders.first
        let syncResult = PlantCareScheduleSyncService.syncCompletedEvent(
            event,
            occurrenceDate: occurrenceDate,
            executorId: executorID,
            context: context,
            source: sourceReminder == nil ? .calendar : .reminder,
            sourceReminderId: sourceReminder?.id,
            now: now,
            scheduleNotifications: scheduleNotifications,
            syncPlanSchedule: false
        )
        let blockedResult = syncResult.allowsScheduleCompletion ? nil : unchangedCompletionResult(
            event: event,
            occurrenceDate: occurrenceDate,
            affectedSubjectIDs: affectedSubjectIDs,
            now: now
        )
        return PlantCareCompletionPreparation(syncResult: syncResult, blockedResult: blockedResult)
    }

    private static func syncReminders(
        _ reminders: [Reminder],
        shouldComplete: Bool,
        occurrenceDate: Date,
        executorID: String?,
        context: ModelContext,
        reminderCompletion: ReminderCompleting
    ) -> Bool {
        for reminder in reminders {
            let didSync = shouldComplete
                ? reminderCompletion.complete(
                    reminder,
                    by: executorID,
                    occurrenceDate: occurrenceDate,
                    context: context
                )
                : reminderCompletion.reopen(
                    reminder,
                    by: executorID,
                    context: context,
                    reschedule: true
                )
            guard didSync else { return false }
        }
        return true
    }

    private static func unchangedCompletionResult(
        event: Event,
        occurrenceDate: Date,
        affectedSubjectIDs: Set<UUID>,
        now: Date,
        didWriteFact: Bool = false,
        allowsDerivedEffects: Bool = false,
        factDate: Date? = nil
    ) -> CalendarEventCompletionResult {
        CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
            syncedReminderCount: 0,
            affectedSubjectIDs: affectedSubjectIDs,
            didChange: false,
            didWriteFact: didWriteFact,
            allowsDerivedEffects: allowsDerivedEffects,
            factDate: factDate,
            operationDate: now
        )
    }

    private static func remindersForCompletionSync(event: Event, occurrenceDate: Date) -> [Reminder] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: occurrenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? occurrenceDate
        let sameDay = event.reminders.filter { reminder in
            reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow
        }
        if !sameDay.isEmpty { return sameDay }
        return event.reminders
            .filter { $0.isPending && $0.scheduledAt < tomorrow }
            .sorted { $0.scheduledAt > $1.scheduledAt }
            .prefix(1)
            .map(\.self)
    }

    private static func affectedSubjectIDs(for event: Event, context: ModelContext) -> Set<UUID> {
        DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        ).affectedEntityIDs
    }

    @discardableResult
    @MainActor
    static func delete(
        event: Event,
        occurrenceDate: Date,
        scope: CalendarEventDeletionScope,
        context: ModelContext
    ) throws -> CalendarEventDeletionOutcome {
        let outcome: CalendarEventDeletionOutcome
        switch scope {
        case .wholeEvent:
            outcome = .deletedEvent(event.id)
            tombstoneAndDeleteEvent(event, context: context)
        case .singleOccurrence:
            outcome = deleteSingleOccurrence(event: event, occurrenceDate: occurrenceDate, context: context)
        case .thisAndFuture:
            outcome = deleteThisAndFuture(event: event, occurrenceDate: occurrenceDate, context: context)
        }
        try CalendarEventPlanCommandService.saveCalendarChanges(context: context)
        return outcome
    }

    @MainActor
    private static func deleteSingleOccurrence(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let calendar = Calendar.current
        let occurrenceStart = calendar.startOfDay(for: occurrenceDate)
        let eventStart = calendar.startOfDay(for: event.startDate)

        if occurrenceStart == eventStart {
            guard let next = calendar.date(byAdding: .day, value: event.recurrenceDays, to: eventStart) else {
                tombstoneAndDeleteEvent(event, context: context)
                return .deletedEvent(event.id)
            }
            let hasMore = event.recurrenceEndDate.map { next <= calendar.startOfDay(for: $0) } ?? true
            if hasMore {
                event.startDate = next
                return .advancedStart(event.id)
            }
            tombstoneAndDeleteEvent(event, context: context)
            return .deletedEvent(event.id)
        }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: occurrenceStart) ?? occurrenceStart
        let nextOccurrence = calendar.date(byAdding: .day, value: event.recurrenceDays, to: occurrenceStart) ?? occurrenceStart
        let hasAfter = event.recurrenceEndDate.map { nextOccurrence <= calendar.startOfDay(for: $0) } ?? true

        if hasAfter {
            let splitIntent = DomainScheduleCreateIntent(
                event: event,
                startDate: nextOccurrence,
                writeKind: writeKind(for: event),
                source: .domainService
            )
            guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
                intent: splitIntent,
                context: context
            ) else {
                event.recurrenceEndDate = dayBefore
                return .truncated(event.id)
            }
            let newEvent = DomainScheduleWriter.createEvent(plan: plan, context: context).event
            newEvent.feedRuleKindRaw = event.feedRuleKindRaw
            newEvent.foodKindRaw = event.foodKindRaw
            newEvent.feedAmountGrams = event.feedAmountGrams
            newEvent.feedPlanGroupId = event.feedPlanGroupId
            event.recurrenceEndDate = dayBefore
            return .split(originalID: event.id, newEventID: newEvent.id)
        }

        event.recurrenceEndDate = dayBefore
        return .truncated(event.id)
    }

    private static func writeKind(for event: Event) -> MemberWriteKind {
        switch EventType(rawValue: event.eventType) {
        case .birthday, .anniversary:
            .memorialContentWithOptionalDerivations
        case .daily, .health, .task, .shoppingList, .chore, .vaccine, .externalDeworming,
             .internalDeworming, .grooming, .vetVisit, .foodChange, .litterBox, .watering,
             .fertilizing, .plantRepotting, .plantPruning, .plantMisting, .plantRotation,
             .plantLeafCleaning, .plantPestCheck, .plantHealthCheck,
             .medication, .petMedication, .petMedicationDose, .insurancePremium,
             .none:
            .care
        }
    }

    @MainActor
    private static func deleteThisAndFuture(
        event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> CalendarEventDeletionOutcome {
        let calendar = Calendar.current
        let occurrenceStart = calendar.startOfDay(for: occurrenceDate)
        let eventStart = calendar.startOfDay(for: event.startDate)

        if occurrenceStart <= eventStart {
            tombstoneAndDeleteEvent(event, context: context)
            return .deletedEvent(event.id)
        }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: occurrenceStart) ?? occurrenceStart
        event.recurrenceEndDate = dayBefore
        return .truncated(event.id)
    }
}

@MainActor
struct CalendarCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    private let derivations: CareDerivationExecutor
    let reminderScheduling: ReminderSchedulingManaging
    let reminderCompletion: ReminderCompleting

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            reminderScheduling: ReminderSchedulingManager(),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            reminderScheduling: ReminderSchedulingManager(),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            reminderScheduling: services.reminderScheduling,
            reminderCompletion: services.reminderCompletion
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        reminderScheduling: ReminderSchedulingManaging,
        reminderCompletion: ReminderCompleting
    ) {
        self.context = context
        self.revisions = revisions
        derivations = CareDerivationExecutor(revisions: revisions)
        self.reminderScheduling = reminderScheduling
        self.reminderCompletion = reminderCompletion
    }

    @discardableResult
    func createEvent(input: CalendarEventPlanCommandInput) throws -> CalendarEventPlanCommandResult? {
        let command = DomainCommand.calendarEventPlan(eventID: nil)
        guard let result = try CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            reminderScheduling: reminderScheduling
        ) else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [],
                    note: "calendar.event.create.empty"
                )
            )
            return nil
        }

        revisions.publishCalendarEventPlan(
            result,
            note: result.scheduledReminderSync ? "calendar.event.created.reminders" : "calendar.event.created"
        )
        return result
    }

    @discardableResult
    func updateEvent(event: Event, input: CalendarEventPlanCommandInput) throws -> CalendarEventPlanCommandResult? {
        let command = DomainCommand.calendarEventPlan(eventID: event.id)
        guard let result = try CalendarEventPlanCommandService.updateEvent(
            event: event,
            input: input,
            context: context,
            reminderScheduling: reminderScheduling
        ) else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [event.id],
                    note: "calendar.event.update.noop"
                )
            )
            return nil
        }

        revisions.publishCalendarEventPlan(
            result,
            note: result.scheduledReminderSync ? "calendar.event.updated.reminders" : "calendar.event.updated"
        )
        return result
    }

    @discardableResult
    func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        executorId: String?,
        note: String
    ) throws -> CalendarEventCompletionResult {
        let result = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: pets,
            context: context,
            executorId: executorId,
            options: CalendarEventCompletionOptions(reminderCompletion: reminderCompletion)
        )
        deriveCalendarCompletion(result, occurrenceDate: occurrenceDate, note: note)
        return result
    }

    @discardableResult
    func delete(
        event: Event,
        occurrenceDate: Date,
        scope: CalendarEventDeletionScope,
        note: String
    ) throws -> CalendarEventDeletionOutcome {
        let outcome = try CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: occurrenceDate,
            scope: scope,
            context: context
        )
        revisions.publishCalendarEventDeletion(outcome, scope: scope, note: note)
        return outcome
    }

    @discardableResult
    private func deriveCalendarCompletion(
        _ result: CalendarEventCompletionResult,
        occurrenceDate: Date,
        note: String
    ) -> CareDerivationResult {
        let command = DomainCommand.calendarEventCompletion(eventID: result.eventID, isCompleted: result.isCompleted)
        guard result.didWriteFact || result.didChange else {
            return derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: result.revisionAffectedEntityIDs,
                    note: note
                )
            )
        }

        return derivations.derive(
            .active(
                disposition: result.allowsDerivedEffects ? .active : .noOp,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: result.eventID,
                    logIDs: [result.eventID],
                    factDate: result.factDate ?? occurrenceDate,
                    operationDate: result.operationDate
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: command,
                    affectedEntityIDs: result.revisionAffectedEntityIDs,
                    note: note
                ),
                noopNote: note
            )
        )
    }
}

struct ReminderCommandResult: Equatable {
    let reminderID: UUID
    let eventID: UUID?
    let affectedSubjectIDs: Set<UUID>
    let action: String

    var revisionAffectedEntityIDs: Set<UUID> {
        var affected = affectedSubjectIDs
        affected.insert(reminderID)
        if let eventID {
            affected.insert(eventID)
        }
        return affected
    }
}

@MainActor
struct ReminderCommandExecutor {
    let context: ModelContext
    let wallet: CoconutWalletManaging
    let careLedger: CareLedgerRecording
    let revisions: DomainRevisionPublishing
    let reminderCompletion: ReminderCompleting

    init(context: ModelContext) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            reminderCompletion: ReminderCompletionService()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            wallet: services.coconutWallet,
            careLedger: services.careLedger,
            revisions: services.domainRevisions,
            reminderCompletion: services.reminderCompletion
        )
    }

    init(
        context: ModelContext,
        wallet: CoconutWalletManaging,
        careLedger: CareLedgerRecording,
        revisions: DomainRevisionPublishing,
        reminderCompletion: ReminderCompleting
    ) {
        self.context = context
        self.wallet = wallet
        self.careLedger = careLedger
        self.revisions = revisions
        self.reminderCompletion = reminderCompletion
    }

    @discardableResult
    func complete(_ reminder: Reminder, by humanId: String?, note: String) -> ReminderCommandResult {
        let didComplete = reminderCompletion.complete(reminder, by: humanId, context: context)
        return publish(reminder, action: didComplete ? "complete" : "complete.noop", note: note)
    }

    @discardableResult
    func completeWithCoconutReward(
        _ reminder: Reminder,
        by humanId: String?,
        amount: Int,
        title: String,
        emoji: String = "✅",
        note: String
    ) -> ReminderCommandResult {
        let didComplete = reminderCompletion.complete(reminder, by: humanId, context: context)
        if didComplete, amount != 0, let effectPlan = authorizedReminderEconomyEffect(
            reminder,
            by: humanId,
            logPrefix: "ReminderCommandExecutor.completeWithCoconutReward"
        ) {
            var rewardError: Error?
            var didApplyWalletDelta = false
            DomainEffectDispatcher.runEconomy(plan: effectPlan) { _ in
                do {
                    try wallet.applyActorDelta(
                        amount: amount,
                        emoji: emoji,
                        title: title,
                        actorId: humanId,
                        actorName: nil,
                        entryKind: amount > 0 ? .reward : .spend,
                        source: .service,
                        context: context,
                        save: false,
                        postsRewardFeedback: true
                    )
                    didApplyWalletDelta = true
                } catch {
                    rewardError = error
                }
                if didApplyWalletDelta {
                    careLedger.recordCoconut(
                        delta: amount,
                        title: title,
                        actorId: humanId,
                        actorName: nil,
                        source: .economy,
                        context: context
                    )
                }
            }
            if let rewardError {
                AppPerformanceMonitor.shared.record(
                    "reminder.reward.walletFailed",
                    valueMS: 0,
                    note: rewardError.localizedDescription
                )
            }
        }
        return publish(reminder, action: didComplete ? "complete.reward" : "complete.reward.noop", note: note)
    }

    @discardableResult
    func skip(_ reminder: Reminder, by humanId: String?, note: String) -> ReminderCommandResult {
        let didSkip = reminderCompletion.skip(reminder, by: humanId, context: context)
        return publish(reminder, action: didSkip ? "skip" : "skip.noop", note: note)
    }

    @discardableResult
    func reopen(
        _ reminder: Reminder,
        by humanId: String?,
        reschedule: Bool = true,
        note: String
    ) -> ReminderCommandResult {
        let didReopen = reminderCompletion.reopen(reminder, by: humanId, context: context, reschedule: reschedule)
        return publish(reminder, action: didReopen ? "reopen" : "reopen.noop", note: note)
    }

    @discardableResult
    func snoozeOneDay(
        _ reminder: Reminder,
        by humanId: String?,
        reschedule: Bool = true,
        note: String
    ) -> ReminderCommandResult {
        let didSnooze = reminderCompletion.snoozeOneDay(reminder, by: humanId, context: context, reschedule: reschedule)
        return publish(reminder, action: didSnooze ? "snoozeOneDay" : "snoozeOneDay.noop", note: note)
    }

    @discardableResult
    private func publish(_ reminder: Reminder, action: String, note: String) -> ReminderCommandResult {
        let result = ReminderCommandResult(
            reminderID: reminder.id,
            eventID: reminder.event?.id,
            affectedSubjectIDs: Self.affectedSubjectIDs(for: reminder.event, context: context),
            action: action
        )
        revisions.publishReminderCommand(result, note: note)
        return result
    }

    private static func affectedSubjectIDs(for event: Event?, context: ModelContext) -> Set<UUID> {
        guard let event else { return [] }
        return DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        ).affectedEntityIDs
    }

    private func authorizedReminderEconomyEffect(
        _ reminder: Reminder,
        by humanId: String?,
        logPrefix: String
    ) -> AuthorizedDomainEffectWrite? {
        guard let event = reminder.event else { return nil }
        return DomainEffectWriteAuthorizer.authorizeSubjectEffect(
            subjectRequest: DomainSubjectResolutionRequest(event: event),
            writeKind: .care,
            source: .domainService,
            executorId: humanId,
            unresolvedAssigneePolicy: .drop,
            context: context,
            logPrefix: logPrefix
        )
    }
}
