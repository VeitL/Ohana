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
}

struct CatCareUndoCommandResult: Equatable {
    let petID: UUID
    let eventID: UUID
    let hygieneLogID: UUID?
}

enum CatCareCommandService {
    @discardableResult
    @MainActor
    static func record(
        pet: Pet,
        input: CatCareCommandInput,
        context: ModelContext
    ) -> CatCareCommandResult {
        let event = Event(
            title: "\(input.emoji) \(input.actionRaw)",
            startDate: input.occurredAt,
            isAllDay: false,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: pet.id.uuidString
        )
        context.insert(event)

        let hygieneLog: PetHygieneLog?
        if input.recordsHygiene {
            let log = PetHygieneLog(date: input.occurredAt, type: .bath, pet: pet, executorId: input.executorId)
            context.insert(log)
            hygieneLog = log
        } else {
            hygieneLog = nil
        }
        context.safeSave()

        return CatCareCommandResult(
            petID: pet.id,
            actionRaw: input.actionRaw,
            eventID: event.id,
            hygieneLogID: hygieneLog?.id
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
        if let event = fetchEvent(id: eventID, petID: pet.id, context: context) {
            context.delete(event)
        }
        if let hygieneLogID,
           let log = fetchHygieneLog(id: hygieneLogID, petID: pet.id, context: context) {
            context.delete(log)
        }
        context.safeSave()
        return CatCareUndoCommandResult(petID: pet.id, eventID: eventID, hygieneLogID: hygieneLogID)
    }

    @MainActor
    private static func fetchEvent(id: UUID, petID: UUID, context: ModelContext) -> Event? {
        let idString = petID.uuidString
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return events.first {
            $0.id == id &&
            $0.relatedEntityId == idString &&
            $0.eventType == EventType.litterBox.rawValue
        }
    }

    @MainActor
    private static func fetchHygieneLog(id: UUID, petID: UUID, context: ModelContext) -> PetHygieneLog? {
        let logs = (try? context.fetch(FetchDescriptor<PetHygieneLog>())) ?? []
        return logs.first { $0.id == id && $0.pet?.id == petID }
    }
}
