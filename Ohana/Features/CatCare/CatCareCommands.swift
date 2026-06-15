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

    var didRecord: Bool {
        disposition.didWriteFact
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }
}

struct CatCareUndoCommandResult: Equatable {
    let petID: UUID
    let eventID: UUID
    let hygieneLogID: UUID?
    let removedLedgerEventIDs: [UUID]
    let didDelete: Bool
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
                disposition: disposition
            )
        }

        let event = Event(
            title: "\(input.emoji) \(input.actionRaw)",
            startDate: input.occurredAt,
            isAllDay: false,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(event)
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
            hygieneLog = recorded.log
            resultDisposition = recorded.result.disposition
        } else {
            hygieneLog = nil
            resultDisposition = disposition
        }
        context.safeSave()

        return CatCareCommandResult(
            petID: pet.id,
            actionRaw: input.actionRaw,
            eventID: event.id,
            hygieneLogID: hygieneLog?.id,
            occurredAt: input.occurredAt,
            disposition: resultDisposition
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
                didDelete: false
            )
        }
        var removedLedgerEventIDs: [UUID] = []
        var didDelete = false
        if let event = fetchEvent(id: eventID, petID: pet.id, context: context) {
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
            didDelete = true
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
        context.safeSave()
        return CatCareUndoCommandResult(
            petID: pet.id,
            eventID: eventID,
            hygieneLogID: hygieneLogID,
            removedLedgerEventIDs: removedLedgerEventIDs,
            didDelete: didDelete
        )
    }

    @MainActor
    private static func fetchEvent(id: UUID, petID: UUID, context: ModelContext) -> Event? {
        let idString = petID.uuidString
        let eventType = EventType.litterBox.rawValue
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.id == id &&
                    event.relatedEntityId == idString &&
                    event.eventType == eventType
            }
        )
        descriptor.fetchLimit = 1
        return fetchCatCareModelsOrLog(descriptor, context: context, operation: "fetch cat care event").first
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
