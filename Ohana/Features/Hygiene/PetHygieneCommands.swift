//
//  PetHygieneCommands.swift
//  Ohana
//
//  Domain write boundaries for pet hygiene check-ins and hygiene plans.
//

import Foundation
import SwiftData

struct PetHygienePlanCommandInput: Equatable {
    let startDate: Date
    let isAllDay: Bool
    let startTime: Date
    let hasEndDate: Bool
    let endDate: Date
    let repeatDays: Int
    let customNote: String

    init(
        startDate: Date,
        isAllDay: Bool,
        startTime: Date,
        hasEndDate: Bool,
        endDate: Date,
        repeatDays: Int,
        customNote: String
    ) {
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.hasEndDate = hasEndDate
        self.endDate = endDate
        self.repeatDays = max(0, repeatDays)
        self.customNote = customNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PetHygieneCheckInCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let hygieneType: HygieneType
    let coconutDelta: Int
    let occurredAt: Date
    let disposition: CareFactWriteDisposition
    let didPersist: Bool
    let persistenceErrorDescription: String?

    var didRecord: Bool {
        didPersist && disposition.didWriteFact
    }

    var allowsDerivedEffects: Bool {
        didPersist && disposition.allowsDerivedEffects
    }
}

struct PetHygieneDeleteCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let didDelete: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
    let removedLedgerEventIDs: [UUID]
}

struct PetHygienePlanCommandResult: Equatable {
    let eventID: UUID
    let reminderID: UUID
    let subjectID: UUID
    let hygieneType: HygieneType
    let didCreate: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

@MainActor
private func fetchPetHygieneCommandModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "PetHygieneCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

enum PetHygieneCommandService {
    @discardableResult
    @MainActor
    static func record(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        careEvents providedCareEvents: CareEventRecording? = nil
    ) -> (result: PetHygieneCheckInCommandResult, log: PetHygieneLog) {
        let careEvents = providedCareEvents ?? CareEventService()
        let recorded = careEvents.recordHygieneFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
        guard recorded.result.didWriteFact else {
            return (
                PetHygieneCheckInCommandResult(
                    logID: recorded.result.logID,
                    subjectID: recorded.result.subjectID,
                    hygieneType: recorded.result.hygieneType,
                    coconutDelta: 0,
                    occurredAt: date,
                    disposition: recorded.result.disposition,
                    didPersist: recorded.result.didPersist,
                    persistenceErrorDescription: recorded.result.persistenceErrorDescription
                ),
                recorded.log
            )
        }
        return (
            PetHygieneCheckInCommandResult(
                logID: recorded.result.logID,
                subjectID: recorded.result.subjectID,
                hygieneType: recorded.result.hygieneType,
                coconutDelta: recorded.result.coconutDelta,
                occurredAt: date,
                disposition: recorded.result.disposition,
                didPersist: recorded.result.didPersist,
                persistenceErrorDescription: recorded.result.persistenceErrorDescription
            ),
            recorded.log
        )
    }

    @discardableResult
    @MainActor
    static func delete(
        _ log: PetHygieneLog,
        pet: Pet,
        context: ModelContext
    ) -> PetHygieneDeleteCommandResult {
        let logID = log.id
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsDerivedEffects else {
            return PetHygieneDeleteCommandResult(
                logID: logID,
                subjectID: pet.id,
                didDelete: false,
                didPersist: true,
                persistenceErrorDescription: nil,
                removedLedgerEventIDs: []
            )
        }
        let ledgerEvents = ledgerEvents(for: logID, context: context)
        for event in ledgerEvents {
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context)
        context.delete(log)
        SharedCareSessionMaintenance.reconcileAfterDeletingHygieneChild(
            logID: logID,
            ledgerEvents: ledgerEvents,
            context: context
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetHygieneDeleteCommandResult(
                logID: logID,
                subjectID: pet.id,
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription,
                removedLedgerEventIDs: []
            )
        }
        return PetHygieneDeleteCommandResult(
            logID: logID,
            subjectID: pet.id,
            didDelete: true,
            didPersist: true,
            persistenceErrorDescription: nil,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(for logID: UUID, context: ModelContext) -> [CareLedgerEvent] {
        let idString = logID.uuidString
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == "PetHygieneLog" && event.legacyModelId == idString
            }
        )
        return fetchPetHygieneCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch ledger events for PetHygieneLog"
        )
    }

    @discardableResult
    @MainActor
    static func createPlan(
        pet: Pet,
        type: HygieneType,
        input: PetHygienePlanCommandInput,
        context: ModelContext,
        scheduleNotification: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PetHygienePlanCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return PetHygienePlanCommandResult(
                eventID: UUID(),
                reminderID: UUID(),
                subjectID: pet.id,
                hygieneType: type,
                didCreate: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        let calendar = Calendar.current
        let title = "\(pet.name) — \(type.rawValue)"
        let fullTitle = input.customNote.isEmpty ? title : "\(title) — \(input.customNote)"

        let dayStart = calendar.startOfDay(for: input.startDate)
        let time = calendar.dateComponents([.hour, .minute], from: input.startTime)
        let eventStart = input.isAllDay
            ? dayStart
            : (calendar.date(
                bySettingHour: time.hour ?? 9,
                minute: time.minute ?? 0,
                second: 0,
                of: dayStart
            ) ?? dayStart)
        let reminderTime = input.isAllDay
            ? (calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart)
            : eventStart

        let eventEndDate: Date?
        if input.hasEndDate {
            let endDay = calendar.startOfDay(for: input.endDate)
            eventEndDate = input.isAllDay
                ? endDay
                : (calendar.date(
                    bySettingHour: time.hour ?? 9,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: endDay
                ) ?? endDay)
        } else {
            eventEndDate = nil
        }

        let intent = DomainScheduleCreateIntent(
            title: fullTitle,
            startDate: eventStart,
            endDate: eventEndDate,
            isAllDay: input.isAllDay,
            eventType: EventType.grooming.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            recurrenceDays: input.repeatDays,
            recurrenceEndDate: input.hasEndDate
                ? calendar.startOfDay(for: input.endDate)
                : (input.repeatDays > 0 ? calendar.date(byAdding: .year, value: 1, to: dayStart) : nil),
            reminderDates: [reminderTime],
            writeKind: .care,
            source: .userCommand
        )

        if input.repeatDays > 0 {
            CarePlanCalendarSync.suppressDefaultPlan(kind: "groom", pet: pet, context: context)
        }
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return PetHygienePlanCommandResult(
                eventID: UUID(),
                reminderID: UUID(),
                subjectID: pet.id,
                hygieneType: type,
                didCreate: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let result = DomainScheduleWriter.createEvent(plan: plan, context: context)
        let event = result.event
        guard let reminder = result.reminders.first else {
            if let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                event: event,
                writeKind: .care,
                source: .userCommand,
                context: context
            ) {
                let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
                DomainScheduleEffectsDispatcher.dispatch(delete: result)
            }
            return PetHygienePlanCommandResult(
                eventID: UUID(),
                reminderID: UUID(),
                subjectID: pet.id,
                hygieneType: type,
                didCreate: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PetHygienePlanCommandResult(
                eventID: event.id,
                reminderID: reminder.id,
                subjectID: pet.id,
                hygieneType: type,
                didCreate: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }

        if input.repeatDays > 0 {
            HygieneType.setCustomCycleDays(input.repeatDays, for: type, petId: pet.id)
        }

        if scheduleNotification {
            let reminderScheduling = providedReminderScheduling ?? ReminderSchedulingManager()
            Task { @MainActor in
                await reminderScheduling.scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: .detail,
                    existingNotificationIds: nil,
                    operation: "schedule",
                    saveLedger: true
                )
            }
        }

        return PetHygienePlanCommandResult(
            eventID: event.id,
            reminderID: reminder.id,
            subjectID: pet.id,
            hygieneType: type,
            didCreate: true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }
}

@MainActor
struct PetHygieneCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    private let derivations: CareDerivationExecutor
    let reminderScheduling: ReminderSchedulingManaging

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            reminderScheduling: ReminderSchedulingManager()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            reminderScheduling: ReminderSchedulingManager()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            reminderScheduling: services.reminderScheduling
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        reminderScheduling: ReminderSchedulingManaging
    ) {
        self.context = context
        self.revisions = revisions
        self.derivations = CareDerivationExecutor(revisions: revisions)
        self.reminderScheduling = reminderScheduling
    }

    @discardableResult
    func record(
        pet: Pet,
        type: HygieneType,
        executorId: String?,
        date: Date = Date(),
        note: String
    ) -> (result: PetHygieneCheckInCommandResult, log: PetHygieneLog) {
        let recorded = PetHygieneCommandService.record(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        )
        guard recorded.result.didPersist else { return recorded }
        deriveRecord(recorded.result, note: note)
        return recorded
    }

    @discardableResult
    func delete(
        _ log: PetHygieneLog,
        pet: Pet,
        note: String
    ) -> PetHygieneDeleteCommandResult {
        let result = PetHygieneCommandService.delete(log, pet: pet, context: context)
        if result.didPersist {
            revisions.publishPetHygieneDelete(result, note: note)
        }
        return result
    }

    func hygieneLog(id: UUID) -> PetHygieneLog? {
        var descriptor = FetchDescriptor<PetHygieneLog>(
            predicate: #Predicate<PetHygieneLog> { log in
                log.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchPetHygieneCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch hygiene log by id"
        ).first
    }

    @discardableResult
    func createPlan(
        pet: Pet,
        type: HygieneType,
        input: PetHygienePlanCommandInput,
        scheduleNotification: Bool = true,
        note: String
    ) -> PetHygienePlanCommandResult {
        let result = PetHygieneCommandService.createPlan(
            pet: pet,
            type: type,
            input: input,
            context: context,
            scheduleNotification: scheduleNotification,
            reminderScheduling: reminderScheduling
        )
        if result.didPersist && result.didCreate {
            revisions.publishPetHygienePlan(result, note: note)
        }
        return result
    }

    private func deriveRecord(_ result: PetHygieneCheckInCommandResult, note: String) {
        let command = DomainCommand.petHygieneRecord(
            petID: result.subjectID,
            type: result.hygieneType.rawValue
        )
        guard result.didRecord else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [result.subjectID],
                    note: note
                )
            )
            return
        }
        derivations.derive(
            .active(
                disposition: result.disposition,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: result.subjectID,
                    logIDs: [result.logID],
                    factDate: result.occurredAt,
                    operationDate: result.occurredAt
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: command,
                    affectedEntityIDs: [result.subjectID, result.logID],
                    note: note
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: result.coconutDelta,
                    petDelta: 0
                ),
                noopNote: "\(note).factOnly"
            )
        )
    }
}
