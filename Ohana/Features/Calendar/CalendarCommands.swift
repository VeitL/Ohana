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

enum CalendarEventPlanCommandService {
    private static let maxReminderOccurrences = 500

    @discardableResult
    @MainActor
    static func createEvent(
        input: CalendarEventPlanCommandInput,
        context: ModelContext,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> CalendarEventPlanCommandResult? {
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
        context.safeSave()

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
    ) -> CalendarEventPlanCommandResult? {
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
            for reminder in createdReminders {
                CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: now)
            }
        } else {
            createdReminders = []
        }
        context.safeSave()

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
    @discardableResult
    @MainActor
    static func toggleCompletion(
        event: Event,
        occurrenceDate: Date,
        pets: [Pet],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        reminderCompletion providedReminderCompletion: ReminderCompleting? = nil,
        schedulePlantCareNotifications: Bool = true
    ) -> CalendarEventCompletionResult {
        let reminderCompletion = providedReminderCompletion ?? ReminderCompletionService()
        let shouldComplete = !event.isOccurrenceMarkedComplete(on: occurrenceDate)
        let affectedSubjectIDs = affectedSubjectIDs(for: event, context: context)
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: writeKind(for: event),
            source: .userCommand,
            context: context
        ) else {
            return CalendarEventCompletionResult(
                eventID: event.id,
                isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
                syncedReminderCount: 0,
                affectedSubjectIDs: affectedSubjectIDs,
                didChange: false,
                didWriteFact: false,
                allowsDerivedEffects: false,
                factDate: nil,
                operationDate: now
            )
        }
        var petTaskSyncResult: CalendarTaskCompletionSyncService.PetTaskSyncResult?
        if CalendarTaskCompletionSyncService.isPetTask(event: event) {
            let syncResult = CalendarTaskCompletionSyncService.syncPetTask(
                event: event,
                occurrenceDate: occurrenceDate,
                isCompleted: shouldComplete,
                pets: pets,
                context: context,
                executorId: executorId,
                operationDate: now
            )
            petTaskSyncResult = syncResult
            guard syncResult.didPersist else {
                return CalendarEventCompletionResult(
                    eventID: event.id,
                    isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
                    syncedReminderCount: 0,
                    affectedSubjectIDs: affectedSubjectIDs,
                    didChange: false,
                    didWriteFact: false,
                    allowsDerivedEffects: false,
                    factDate: nil,
                    operationDate: now
                )
            }
            if !shouldComplete && syncResult == .noOp {
                return CalendarEventCompletionResult(
                    eventID: event.id,
                    isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
                    syncedReminderCount: 0,
                    affectedSubjectIDs: affectedSubjectIDs,
                    didChange: false,
                    didWriteFact: false,
                    allowsDerivedEffects: false,
                    factDate: nil,
                    operationDate: now
                )
            }
            if shouldComplete && !syncResult.shouldCompleteOccurrence {
                return CalendarEventCompletionResult(
                    eventID: event.id,
                    isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
                    syncedReminderCount: 0,
                    affectedSubjectIDs: affectedSubjectIDs,
                    didChange: false,
                    didWriteFact: syncResult.didWriteFact,
                    allowsDerivedEffects: syncResult.allowsDerivedEffects,
                    factDate: occurrenceDate,
                    operationDate: now
                )
            }
        }
        guard DomainScheduleWriter.setEventOccurrenceCompletion(
            event,
            occurrenceDate: occurrenceDate,
            isCompleted: shouldComplete,
            mutation: mutation,
            context: context,
            modifiedAt: now
        ) else {
            return CalendarEventCompletionResult(
                eventID: event.id,
                isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: occurrenceDate),
                syncedReminderCount: 0,
                affectedSubjectIDs: affectedSubjectIDs,
                didChange: false,
                didWriteFact: false,
                allowsDerivedEffects: false,
                factDate: nil,
                operationDate: now
            )
        }

        let remindersToSync = remindersForCompletionSync(event: event, now: now)
        for reminder in remindersToSync {
            if shouldComplete {
                reminderCompletion.complete(reminder, by: executorId, context: context)
            } else {
                reminderCompletion.reopen(reminder, by: executorId, context: context, reschedule: true)
            }
        }
        if shouldComplete, remindersToSync.isEmpty {
            PlantCareScheduleSyncService.syncCompletedEvent(
                event,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context,
                source: .calendar,
                now: now,
                scheduleNotifications: schedulePlantCareNotifications
            )
        }
        if remindersToSync.isEmpty {
            context.safeSave()
        }

        return CalendarEventCompletionResult(
            eventID: event.id,
            isCompleted: shouldComplete,
            syncedReminderCount: remindersToSync.count,
            affectedSubjectIDs: affectedSubjectIDs,
            didChange: true,
            didWriteFact: petTaskSyncResult?.didWriteFact ?? true,
            allowsDerivedEffects: petTaskSyncResult?.allowsDerivedEffects ?? true,
            factDate: occurrenceDate,
            operationDate: now
        )
    }

    private static func remindersForCompletionSync(event: Event, now: Date) -> [Reminder] {
        guard event.recurrenceDays == 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return event.reminders.filter { reminder in
            reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow
        }
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
    ) -> CalendarEventDeletionOutcome {
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
        context.safeSave()
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
    func createEvent(input: CalendarEventPlanCommandInput) -> CalendarEventPlanCommandResult? {
        let command = DomainCommand.calendarEventPlan(eventID: nil)
        guard let result = CalendarEventPlanCommandService.createEvent(
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
    func updateEvent(event: Event, input: CalendarEventPlanCommandInput) -> CalendarEventPlanCommandResult? {
        let command = DomainCommand.calendarEventPlan(eventID: event.id)
        guard let result = CalendarEventPlanCommandService.updateEvent(
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
    ) -> CalendarEventCompletionResult {
        let result = CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: pets,
            context: context,
            executorId: executorId,
            reminderCompletion: reminderCompletion
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
    ) -> CalendarEventDeletionOutcome {
        let outcome = CalendarEventCommandService.delete(
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
