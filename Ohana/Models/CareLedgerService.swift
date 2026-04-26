//
//  CareLedgerService.swift
//  Ohana
//
//  Write helpers for the canonical care ledger.
//

import Foundation
import SwiftData

enum CareLedgerService {
    @MainActor
    @discardableResult
    static func record(
        occurredAt: Date = Date(),
        actorKind: CareLedgerActorKind = .unknown,
        actorId: String? = nil,
        subjectKind: CareLedgerSubjectKind,
        subjectId: String?,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double = 0,
        amountUnit: String = "",
        note: String = "",
        source: CareLedgerSource = .service,
        sourceEventId: String? = nil,
        sourceReminderId: String? = nil,
        legacyModelName: String? = nil,
        legacyModelId: String? = nil,
        coconutDelta: Int = 0,
        rewardLogId: String? = nil,
        privacyFieldRaw: String? = nil,
        metadataJSON: String = "",
        context: ModelContext,
        save: Bool = true
    ) -> CareLedgerEvent {
        let event = CareLedgerEvent(
            occurredAt: occurredAt,
            actorKind: actorKind,
            actorId: actorId,
            subjectKind: subjectKind,
            subjectId: subjectId,
            eventKind: eventKind,
            actionType: actionType,
            amountValue: amountValue,
            amountUnit: amountUnit,
            note: note,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            coconutDelta: coconutDelta,
            rewardLogId: rewardLogId,
            privacyFieldRaw: privacyFieldRaw,
            metadataJSON: metadataJSON
        )
        context.insert(event)
        if save {
            context.safeSave()
        }
        return event
    }

    @MainActor
    static func recordPetCare(
        log: PetCareLog,
        pet: Pet,
        source: CareLedgerSource,
        sourceEventId: String? = nil,
        sourceReminderId: String? = nil,
        coconutDelta: Int = 0,
        context: ModelContext
    ) {
        let amount: (Double, String) = {
            if log.careType == .feeding { return (log.amountGrams, "g") }
            if log.careType == .watering { return (log.amountMl, "ml") }
            return (0, "")
        }()
        record(
            occurredAt: log.date,
            actorKind: log.executorId == nil ? .unknown : .human,
            actorId: log.executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: log.careType.rawValue,
            amountValue: amount.0,
            amountUnit: amount.1,
            note: log.note,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            context: context
        )
    }

    @MainActor
    static func recordPetPotty(
        log: PetPottyLog,
        pet: Pet,
        source: CareLedgerSource,
        coconutDelta: Int = 0,
        context: ModelContext
    ) {
        record(
            occurredAt: log.date,
            actorKind: log.executorId == nil ? .unknown : .human,
            actorId: log.executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: log.pottyType.rawValue,
            source: source,
            legacyModelName: "PetPottyLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: coconutDelta,
            context: context
        )
    }

    @MainActor
    static func recordReminderState(
        reminder: Reminder,
        actionType: String,
        actorId: String?,
        source: CareLedgerSource,
        context: ModelContext
    ) {
        let subject = subjectInfo(from: reminder.event)
        record(
            occurredAt: Date(),
            actorKind: actorId == nil ? .unknown : .human,
            actorId: actorId,
            subjectKind: subject.kind,
            subjectId: subject.id,
            eventKind: .reminder,
            actionType: actionType,
            note: reminder.event?.title ?? "",
            source: source,
            sourceEventId: reminder.event?.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            legacyModelName: "Reminder",
            legacyModelId: reminder.id.uuidString,
            context: context
        )
    }

    @MainActor
    static func recordCoconut(
        delta: Int,
        title: String,
        actorId: String?,
        actorName: String?,
        source: CareLedgerSource,
        context: ModelContext
    ) {
        record(
            actorKind: actorId == nil ? .system : .human,
            actorId: actorId,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "coconutDelta",
            note: actorName.map { "\($0) · \(title)" } ?? title,
            source: source,
            coconutDelta: delta,
            context: context
        )
    }

    static func subjectInfo(from event: Event?) -> (kind: CareLedgerSubjectKind, id: String?) {
        guard let event else { return (.system, nil) }
        switch event.relatedEntityType.lowercased() {
        case "pet":
            return (.pet, event.relatedEntityId)
        case "human":
            return (.human, event.relatedEntityId)
        case "plant":
            return (.plant, event.relatedEntityId)
        default:
            return (.unknown, event.relatedEntityId.isEmpty ? nil : event.relatedEntityId)
        }
    }

    static func rewardDelta(_ reward: (humanGot: Int, petGot: Int)?) -> Int {
        guard let reward else { return 0 }
        return max(0, reward.humanGot) + max(0, reward.petGot)
    }
}
