//
//  CareLedgerBackfillService.swift
//  Ohana
//
//  Idempotent backfill from legacy models into CareLedgerEvent.
//

import Foundation
import SwiftData

nonisolated enum CareLedgerBackfillService {
    static let sourceFetchBatchSize = 64

    /// Isolation-agnostic: operates only on the supplied ModelContext, so it can
    /// run on the main context or inside a background @ModelActor.
    static func backfill(context: ModelContext) throws {
        var stagedKeys: Set<String> = []

        func shouldBackfill(_ model: String, _ id: String) throws -> Bool {
            let value = key(model, id)
            guard !stagedKeys.contains(value) else { return false }
            guard try !legacyLedgerExists(modelName: model, legacyModelId: id, context: context) else {
                stagedKeys.insert(value)
                return false
            }
            stagedKeys.insert(value)
            return true
        }

        try forEachSourceBatch(
            FetchDescriptor<PetCareLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet care logs"
        ) { log in
            guard try shouldBackfill("PetCareLog", log.id.uuidString) else { return }
            let autoFeedDedupKey = log.autoFeedDedupKey.trimmingCharacters(in: .whitespacesAndNewlines)
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
                sourceEventId: autoFeedEventId(fromDedupKey: autoFeedDedupKey),
                legacyModelName: "PetCareLog",
                legacyModelId: log.id.uuidString,
                metadataJSON: CareLedgerMetadata.addingString(
                    CareLedgerMetadata.autoFeedDedupKey,
                    value: autoFeedDedupKey,
                    to: ""
                ),
                context: context,
                save: false
            )
        }

        try forEachSourceBatch(
            FetchDescriptor<PetPottyLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet potty logs"
        ) { log in
            guard try shouldBackfill("PetPottyLog", log.id.uuidString) else { return }
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

        try forEachSourceBatch(
            FetchDescriptor<PetWalkLog>(sortBy: [SortDescriptor(\.startDate)]),
            context: context,
            operation: "fetch pet walk logs"
        ) { log in
            guard try shouldBackfill("PetWalkLog", log.id.uuidString) else { return }
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

        try forEachSourceBatch(
            FetchDescriptor<PetExpenseLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet expense logs"
        ) { log in
            guard try shouldBackfill("PetExpenseLog", log.id.uuidString) else { return }
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

        try forEachSourceBatch(
            FetchDescriptor<PetWeightLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet weight logs"
        ) { log in
            guard try shouldBackfill("PetWeightLog", log.id.uuidString) else { return }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .pet,
                subjectId: log.pet?.id.uuidString,
                eventKind: .weight,
                actionType: "petWeight",
                amountValue: log.weightInKg,
                amountUnit: "kg",
                source: .backfill,
                legacyModelName: "PetWeightLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        try forEachSourceBatch(
            FetchDescriptor<PetHygieneLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet hygiene logs"
        ) { log in
            guard try shouldBackfill("PetHygieneLog", log.id.uuidString) else { return }
            CareLedgerService.record(
                occurredAt: log.date,
                actorKind: log.executorId == nil ? .unknown : .human,
                actorId: log.executorId,
                subjectKind: .pet,
                subjectId: log.pet?.id.uuidString,
                eventKind: .hygiene,
                actionType: log.hygieneType.rawValue,
                source: .backfill,
                legacyModelName: "PetHygieneLog",
                legacyModelId: log.id.uuidString,
                context: context,
                save: false
            )
        }

        try forEachSourceBatch(
            FetchDescriptor<HumanWeightLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch human weight logs"
        ) { log in
            guard try shouldBackfill("HumanWeightLog", log.id.uuidString) else { return }
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

        try forEachSourceBatch(
            FetchDescriptor<HumanWorkoutLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch human workout logs"
        ) { log in
            guard try shouldBackfill("HumanWorkoutLog", log.id.uuidString) else { return }
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

        try forEachSourceBatch(
            FetchDescriptor<PlantCareLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch plant care logs"
        ) { log in
            guard try shouldBackfill("PlantCareLog", log.id.uuidString) else { return }
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

        try forEachSourceBatch(
            FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.scheduledAt)]),
            context: context,
            operation: "fetch reminders"
        ) { reminder in
            guard try shouldBackfill("Reminder", reminder.id.uuidString) else { return }
            let subject = CareLedgerService.subjectInfo(from: reminder.event, context: context)
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

        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        if !saveResult.didSave {
            context.rollback()
        }
    }

    private static func key(_ model: String, _ id: String) -> String {
        "\(model):\(id)"
    }

    private static func autoFeedEventId(fromDedupKey key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let eventId = trimmed.split(separator: ":", maxSplits: 1).first,
              UUID(uuidString: String(eventId)) != nil
        else { return nil }
        return String(eventId)
    }

    private static func forEachSourceBatch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String,
        _ body: (T) throws -> Void
    ) throws {
        var offset = 0
        while true {
            var batchDescriptor = descriptor
            batchDescriptor.fetchLimit = sourceFetchBatchSize
            batchDescriptor.fetchOffset = offset
            let batch: [T]
            do {
                batch = try context.fetch(batchDescriptor)
            } catch {
                OhanaLog.warning(
                    "CareLedgerBackfillService failed to \(operation): \(error.localizedDescription)",
                    category: "Care"
                )
                throw error
            }
            guard !batch.isEmpty else { break }
            for item in batch {
                try body(item)
            }
            guard batch.count == sourceFetchBatchSize else { break }
            offset += batch.count
        }
    }

    private static func legacyLedgerExists(
        modelName: String,
        legacyModelId: String,
        context: ModelContext
    ) throws -> Bool {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == modelName && event.legacyModelId == legacyModelId
            }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}

/// Runs the (potentially large, unbounded) care-ledger backfill on a dedicated
/// background SwiftData context so legacy table scans and inserts never block the
/// main thread. The backfill is idempotent and writes only persistent data, so it
/// has no dependency on main-context live models or UI state.
@ModelActor
actor CareLedgerBackfillActor {
    func run() throws {
        try CareLedgerBackfillService.backfill(context: modelContext)
    }
}
