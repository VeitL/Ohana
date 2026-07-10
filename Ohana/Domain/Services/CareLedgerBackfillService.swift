//
//  CareLedgerBackfillService.swift
//  Ohana
//
//  Idempotent backfill from legacy models into CareLedgerEvent.
//

import Foundation
import SwiftData

/// Durable position for the legacy-to-ledger migration. The offset is scoped to
/// one immutable legacy source table; backfill writes only `CareLedgerEvent`, so
/// advancing it cannot be invalidated by the work this service performs.
nonisolated struct CareLedgerBackfillCursor: Codable, Equatable, Sendable {
    var sourceIndex: Int
    var sourceOffset: Int

    static let initial = CareLedgerBackfillCursor(sourceIndex: 0, sourceOffset: 0)
}

nonisolated struct CareLedgerBackfillBatchResult: Equatable, Sendable {
    let nextCursor: CareLedgerBackfillCursor
    let processedSourceRecordCount: Int
    let didComplete: Bool
}

private nonisolated enum CareLedgerBackfillSource: Int, CaseIterable {
    case petCare
    case petPotty
    case petWalk
    case petExpense
    case petWeight
    case petHygiene
    case humanWeight
    case humanWorkout
    case plantCare
    case reminder
}

private nonisolated struct CareLedgerBackfillYield: Error {}

private nonisolated struct CareLedgerBackfillPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

/// A reference control object keeps one bounded, cooperative migration batch
/// inside a `@ModelActor`. It never crosses the actor boundary.
private final nonisolated class CareLedgerBackfillBatchControl {
    private let maximumSourceRecordCount: Int
    private let deadline: Date
    private(set) var sourceIndex: Int
    private(set) var sourceOffset: Int
    private(set) var processedSourceRecordCount = 0

    init(
        cursor: CareLedgerBackfillCursor,
        maximumSourceRecordCount: Int,
        deadline: Date
    ) {
        self.maximumSourceRecordCount = max(1, maximumSourceRecordCount)
        self.deadline = deadline
        sourceIndex = min(max(0, cursor.sourceIndex), CareLedgerBackfillSource.allCases.count)
        sourceOffset = max(0, cursor.sourceOffset)
    }

    var isComplete: Bool {
        sourceIndex >= CareLedgerBackfillSource.allCases.count
    }

    var nextCursor: CareLedgerBackfillCursor {
        CareLedgerBackfillCursor(sourceIndex: sourceIndex, sourceOffset: sourceOffset)
    }

    func shouldProcess(_ source: CareLedgerBackfillSource) -> Bool {
        source.rawValue == sourceIndex
    }

    func checkpoint() throws {
        try Task.checkCancellation()
        guard processedSourceRecordCount < maximumSourceRecordCount,
              Date() < deadline
        else {
            throw CareLedgerBackfillYield()
        }
    }

    func recordProcessedSourceRecord() {
        processedSourceRecordCount += 1
        sourceOffset += 1
    }

    func complete(_ source: CareLedgerBackfillSource) {
        guard shouldProcess(source) else { return }
        sourceIndex += 1
        sourceOffset = 0
    }
}

nonisolated enum CareLedgerBackfillService {
    static let sourceFetchBatchSize = 64

    /// Isolation-agnostic: operates only on the supplied ModelContext, so it can
    /// run on the main context or inside a background @ModelActor.
    static func backfill(context: ModelContext) throws {
        var cursor = CareLedgerBackfillCursor.initial
        while true {
            let result = try backfillBatch(
                context: context,
                cursor: cursor,
                maximumSourceRecordCount: .max,
                deadline: .distantFuture
            )
            guard !result.didComplete else { return }
            cursor = result.nextCursor
        }
    }

    /// Processes a finite migration slice, persists the slice atomically, and
    /// returns the durable continuation point. Cancellation rolls the slice
    /// back; a persistence failure is thrown so callers never mark it complete.
    static func backfillBatch(
        context: ModelContext,
        cursor: CareLedgerBackfillCursor,
        maximumSourceRecordCount: Int,
        deadline: Date
    ) throws -> CareLedgerBackfillBatchResult {
        let control = CareLedgerBackfillBatchControl(
            cursor: cursor,
            maximumSourceRecordCount: maximumSourceRecordCount,
            deadline: deadline
        )
        var stagedKeys: Set<String> = []

        func shouldBackfill(_ model: String, _ id: String) throws -> Bool {
            let value = key(model, id)
            guard !stagedKeys.contains(value) else { return false }
            guard try !legacyLedgerExists(
                modelName: model,
                legacyModelId: id,
                context: context
            ) else {
                stagedKeys.insert(value)
                return false
            }
            stagedKeys.insert(value)
            return true
        }

        do {
            if control.shouldProcess(.petCare) {
                try forEachSourceBatch(
            FetchDescriptor<PetCareLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet care logs",
            control: control
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
                control.complete(.petCare)
            }

            if control.shouldProcess(.petPotty) {
                try forEachSourceBatch(
            FetchDescriptor<PetPottyLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet potty logs",
            control: control
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
                control.complete(.petPotty)
            }

            if control.shouldProcess(.petWalk) {
                try forEachSourceBatch(
            FetchDescriptor<PetWalkLog>(sortBy: [SortDescriptor(\.startDate)]),
            context: context,
            operation: "fetch pet walk logs",
            control: control
        ) { log in
            guard !log.isRecoveryCheckpoint else { return }
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
                control.complete(.petWalk)
            }

            if control.shouldProcess(.petExpense) {
                try forEachSourceBatch(
            FetchDescriptor<PetExpenseLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet expense logs",
            control: control
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
                control.complete(.petExpense)
            }

            if control.shouldProcess(.petWeight) {
                try forEachSourceBatch(
            FetchDescriptor<PetWeightLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet weight logs",
            control: control
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
                control.complete(.petWeight)
            }

            if control.shouldProcess(.petHygiene) {
                try forEachSourceBatch(
            FetchDescriptor<PetHygieneLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch pet hygiene logs",
            control: control
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
                control.complete(.petHygiene)
            }

            if control.shouldProcess(.humanWeight) {
                try forEachSourceBatch(
            FetchDescriptor<HumanWeightLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch human weight logs",
            control: control
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
                control.complete(.humanWeight)
            }

            if control.shouldProcess(.humanWorkout) {
                try forEachSourceBatch(
            FetchDescriptor<HumanWorkoutLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch human workout logs",
            control: control
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
                control.complete(.humanWorkout)
            }

            if control.shouldProcess(.plantCare) {
                try forEachSourceBatch(
            FetchDescriptor<PlantCareLog>(sortBy: [SortDescriptor(\.date)]),
            context: context,
            operation: "fetch plant care logs",
            control: control
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
                control.complete(.plantCare)
            }

            if control.shouldProcess(.reminder) {
                try forEachSourceBatch(
            FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.scheduledAt)]),
            context: context,
            operation: "fetch reminders",
            control: control
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
                control.complete(.reminder)
            }
        } catch is CareLedgerBackfillYield {
            return try persistBatch(context: context, control: control)
        } catch is CancellationError {
            context.rollback()
            throw CancellationError()
        }

        return try persistBatch(context: context, control: control)
    }

    private static func persistBatch(
        context: ModelContext,
        control: CareLedgerBackfillBatchControl
    ) throws -> CareLedgerBackfillBatchResult {
        try Task.checkCancellation()
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw CareLedgerBackfillPersistenceFailure(errorDescription: saveResult.errorDescription)
        }
        return CareLedgerBackfillBatchResult(
            nextCursor: control.nextCursor,
            processedSourceRecordCount: control.processedSourceRecordCount,
            didComplete: control.isComplete
        )
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
        control: CareLedgerBackfillBatchControl,
        _ body: (T) throws -> Void
    ) throws {
        var offset = control.nextCursor.sourceOffset
        while true {
            try control.checkpoint()
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
                try control.checkpoint()
                try body(item)
                control.recordProcessedSourceRecord()
            }
            guard batch.count == sourceFetchBatchSize else { break }
            offset += batch.count
        }
    }

    /// The legacy-model fields are indexed together. An exact bounded lookup
    /// avoids materializing every existing ledger key before a small startup
    /// page can start, while keeping the write path idempotent.
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

/// Runs a bounded, cancellable care-ledger migration slice on a dedicated
/// background SwiftData context. The actor returns values only, never live
/// SwiftData models, so the startup coordinator can persist the next cursor.
@ModelActor
actor CareLedgerBackfillActor {
    func runBatch(
        cursor: CareLedgerBackfillCursor,
        maximumSourceRecordCount: Int,
        deadline: Date
    ) throws -> CareLedgerBackfillBatchResult {
        try CareLedgerBackfillService.backfillBatch(
            context: modelContext,
            cursor: cursor,
            maximumSourceRecordCount: maximumSourceRecordCount,
            deadline: deadline
        )
    }

    /// Compatibility helper for deterministic unit tests and explicit manual
    /// migration. Startup never calls this unbounded convenience method.
    func run() throws {
        try CareLedgerBackfillService.backfill(context: modelContext)
    }
}
