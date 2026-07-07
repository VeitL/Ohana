//
//  CatCareCommands.swift
//  Ohana
//
//  Cat care station write boundary.
//

import Foundation
import SwiftData

struct CatCareCommandInput: Equatable {
    let actionRaw: String
    let emoji: String
    let recordsHygiene: Bool
    let occurredAt: Date
    let executorId: String?

    init(
        actionRaw: String,
        emoji: String,
        recordsHygiene: Bool,
        occurredAt: Date = Date(),
        executorId: String? = nil
    ) {
        self.actionRaw = actionRaw
        self.emoji = emoji
        self.recordsHygiene = recordsHygiene
        self.occurredAt = occurredAt
        self.executorId = executorId
    }
}

struct CatCareCommandResult: Equatable {
    let petID: UUID
    let actionRaw: String
    let eventID: UUID
    let hygieneLogID: UUID?
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

struct CatCareUndoCommandResult: Equatable {
    let petID: UUID
    let eventID: UUID
    let hygieneLogID: UUID?
    let removedLedgerEventIDs: [UUID]
    let didDelete: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

enum CatCareCommandService {
    @discardableResult
    @MainActor
    static func record(
        pet: Pet,
        input: CatCareCommandInput,
        context: ModelContext,
        careEvents providedCareEvents: CareEventRecording? = nil
    ) -> CatCareCommandResult {
        let careEvents = providedCareEvents ?? CareEventService()
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: input.occurredAt,
            executorId: input.executorId,
            context: context
        )
        guard disposition.didWriteFact else {
            return CatCareCommandResult(
                petID: pet.id,
                actionRaw: input.actionRaw,
                eventID: UUID(),
                hygieneLogID: nil,
                occurredAt: input.occurredAt,
                disposition: disposition,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        let eventIntent = DomainScheduleCreateIntent(
            title: "\(input.emoji) \(input.actionRaw)",
            startDate: input.occurredAt,
            isAllDay: false,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            writeKind: .care,
            source: .userCommand
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: eventIntent,
            context: context
        ) else {
            return CatCareCommandResult(
                petID: pet.id,
                actionRaw: input.actionRaw,
                eventID: UUID(),
                hygieneLogID: nil,
                occurredAt: input.occurredAt,
                disposition: .noOp,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let event = DomainScheduleWriter.createEvent(plan: plan, context: context).event
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: input.occurredAt)

        let hygieneLog: PetHygieneLog?
        let resultDisposition: CareFactWriteDisposition
        if input.recordsHygiene {
            let recorded = careEvents.recordHygieneFact(
                pet: pet,
                type: .bath,
                context: context,
                executorId: input.executorId,
                date: input.occurredAt
            )
            guard recorded.result.didPersist else {
                context.rollback()
                return CatCareCommandResult(
                    petID: pet.id,
                    actionRaw: input.actionRaw,
                    eventID: event.id,
                    hygieneLogID: recorded.log.id,
                    occurredAt: input.occurredAt,
                    disposition: recorded.result.disposition,
                    didPersist: false,
                    persistenceErrorDescription: recorded.result.persistenceErrorDescription
                )
            }
            hygieneLog = recorded.log
            resultDisposition = recorded.result.disposition
        } else {
            hygieneLog = nil
            resultDisposition = disposition
        }
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return CatCareCommandResult(
                petID: pet.id,
                actionRaw: input.actionRaw,
                eventID: event.id,
                hygieneLogID: hygieneLog?.id,
                occurredAt: input.occurredAt,
                disposition: resultDisposition,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }

        return CatCareCommandResult(
            petID: pet.id,
            actionRaw: input.actionRaw,
            eventID: event.id,
            hygieneLogID: hygieneLog?.id,
            occurredAt: input.occurredAt,
            disposition: resultDisposition,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func undo(
        pet: Pet,
        eventID: UUID,
        hygieneLogID: UUID?,
        context: ModelContext
    ) -> CatCareUndoCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsDerivedEffects else {
            return CatCareUndoCommandResult(
                petID: pet.id,
                eventID: eventID,
                hygieneLogID: hygieneLogID,
                removedLedgerEventIDs: [],
                didDelete: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        var removedLedgerEventIDs: [UUID] = []
        var didDelete = false
        if let event = fetchEvent(id: eventID, petID: pet.id, context: context) {
            if let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                event: event,
                writeKind: .care,
                source: .userCommand,
                context: context
            ) {
                let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
                DomainScheduleEffectsDispatcher.dispatch(delete: result)
                didDelete = result.didDelete
            }
        }
        if let hygieneLogID,
           let log = fetchHygieneLog(id: hygieneLogID, petID: pet.id, context: context) {
            let ledgerEvents = fetchLedgerEvents(for: hygieneLogID, context: context)
            removedLedgerEventIDs = ledgerEvents.map(\.id)
            for ledger in ledgerEvents {
                CloudSyncMutationRecorder.markDeleted(ledger, context: context)
                context.delete(ledger)
            }
            CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context)
            context.delete(log)
            didDelete = true
        }
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return CatCareUndoCommandResult(
                petID: pet.id,
                eventID: eventID,
                hygieneLogID: hygieneLogID,
                removedLedgerEventIDs: [],
                didDelete: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return CatCareUndoCommandResult(
            petID: pet.id,
            eventID: eventID,
            hygieneLogID: hygieneLogID,
            removedLedgerEventIDs: removedLedgerEventIDs,
            didDelete: didDelete,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @MainActor
    private static func fetchEvent(id: UUID, petID: UUID, context: ModelContext) -> Event? {
        let eventType = EventType.litterBox.rawValue
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.id == id &&
                    event.eventType == eventType
            }
        )
        descriptor.fetchLimit = 1
        return fetchCatCareModelsOrLog(descriptor, context: context, operation: "fetch cat care event")
            .first {
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet($0, petId: petID.uuidString)
            }
    }

    @MainActor
    private static func fetchHygieneLog(id: UUID, petID: UUID, context: ModelContext) -> PetHygieneLog? {
        var descriptor = FetchDescriptor<PetHygieneLog>(
            predicate: #Predicate<PetHygieneLog> { log in
                log.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchCatCareModelsOrLog(descriptor, context: context, operation: "fetch cat hygiene log")
            .first { $0.pet?.id == petID }
    }

    @MainActor
    private static func fetchLedgerEvents(for hygieneLogID: UUID, context: ModelContext) -> [CareLedgerEvent] {
        let idString = hygieneLogID.uuidString
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == "PetHygieneLog" && event.legacyModelId == idString
            }
        )
        return fetchCatCareModelsOrLog(descriptor, context: context, operation: "fetch cat hygiene ledger events")
    }

    @MainActor
    private static func fetchCatCareModelsOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "CatCareCommandService failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }
}
