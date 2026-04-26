//
//  CareLedgerBackfillService.swift
//  Ohana
//
//  Idempotent backfill from legacy models into CareLedgerEvent.
//

import Foundation
import SwiftData

enum CareLedgerBackfillService {
    @MainActor
    static func backfill(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        var keys = Set(existing.compactMap { event -> String? in
            guard let model = event.legacyModelName, let id = event.legacyModelId else { return nil }
            return key(model, id)
        })

        func remember(_ model: String, _ id: String) -> Bool {
            let value = key(model, id)
            guard !keys.contains(value) else { return false }
            keys.insert(value)
            return true
        }

        for log in try context.fetch(FetchDescriptor<PetCareLog>()) {
            guard remember("PetCareLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .pet,
                subjectId: log.pet?.id.uuidString,
                eventKind: .care,
                actionType: log.careType.rawValue,
                amountValue: log.careType == .feeding ? log.amountGrams : log.amountMl,
                amountUnit: log.careType == .feeding ? "g" : (log.careType == .watering ? "ml" : ""),
                note: log.note,
                source: .backfill,
                legacyModelName: "PetCareLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        for log in try context.fetch(FetchDescriptor<PetPottyLog>()) {
            guard remember("PetPottyLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .pet,
                subjectId: log.pet?.id.uuidString,
                eventKind: .potty,
                actionType: log.pottyType.rawValue,
                source: .backfill,
                legacyModelName: "PetPottyLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        for log in try context.fetch(FetchDescriptor<PetWalkLog>()) {
            guard remember("PetWalkLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.startDate,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .pet,
                subjectId: log.pet?.id.uuidString,
                eventKind: .walk,
                actionType: "walk",
                amountValue: log.distanceMeters,
                amountUnit: "m",
                note: log.behaviorNotes ?? "",
                source: .backfill,
                legacyModelName: "PetWalkLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: log.coconutsEarned,
                context: context,
                save: false
            )
        }

        for log in try context.fetch(FetchDescriptor<PetExpenseLog>()) {
            guard remember("PetExpenseLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .pet,
                subjectId: log.pet?.id.uuidString,
                eventKind: .expense,
                actionType: log.category,
                amountValue: log.amount,
                amountUnit: "currency",
                note: log.note,
                source: .backfill,
                legacyModelName: "PetExpenseLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        for log in try context.fetch(FetchDescriptor<HumanWeightLog>()) {
            guard remember("HumanWeightLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: .human,
                actorId: log.human?.id.uuidString,
                subjectKind: .human,
                subjectId: log.human?.id.uuidString,
                eventKind: .weight,
                actionType: "humanWeight",
                amountValue: log.weight,
                amountUnit: "kg",
                source: .backfill,
                legacyModelName: "HumanWeightLog",
                legacyModelId: log.id.uuidString,
                privacyFieldRaw: HumanPrivateField.weight.rawValue,
                context: context,
                save: false
            )
        }

        for log in try context.fetch(FetchDescriptor<HumanWorkoutLog>()) {
            guard remember("HumanWorkoutLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: .human,
                actorId: log.human?.id.uuidString,
                subjectKind: .human,
                subjectId: log.human?.id.uuidString,
                eventKind: .workout,
                actionType: log.typeRaw,
                amountValue: Double(log.durationMinutes),
                amountUnit: "min",
                note: log.notes,
                source: .backfill,
                legacyModelName: "HumanWorkoutLog",
                legacyModelId: log.id.uuidString,
                privacyFieldRaw: HumanPrivateField.workout.rawValue,
                context: context,
                save: false
            )
        }

        for log in try context.fetch(FetchDescriptor<PlantCareLog>()) {
            guard remember("PlantCareLog", log.id.uuidString) else { continue }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .plant,
                subjectId: log.plant?.id.uuidString,
                eventKind: .plantCare,
                actionType: log.careTypeRaw,
                note: log.note,
                source: .backfill,
                legacyModelName: "PlantCareLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        for reminder in try context.fetch(FetchDescriptor<Reminder>()) {
            guard remember("Reminder", reminder.id.uuidString) else { continue }
            let subject = CareLedgerService.subjectInfo(from: reminder.event)
            CareLedgerService.record(
                occurredAt: reminder.completedAt ?? reminder.scheduledAt,
                actorKind: reminder.completedBy.isEmpty ? .unknown : .human,
                actorId: reminder.completedBy.isEmpty ? nil : reminder.completedBy,
                subjectKind: subject.kind,
                subjectId: subject.id,
                eventKind: .reminder,
                actionType: reminder.status,
                note: reminder.event?.title ?? "",
                source: .backfill,
                sourceEventId: reminder.event?.id.uuidString,
                sourceReminderId: reminder.id.uuidString,
                legacyModelName: "Reminder",
                legacyModelId: reminder.id.uuidString,
                context: context,
                save: false
            )
        }

        context.safeSave()
    }

    private static func key(_ model: String, _ id: String) -> String {
        "\(model):\(id)"
    }
}
