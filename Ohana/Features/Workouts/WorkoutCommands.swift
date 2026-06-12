//
//  WorkoutCommands.swift
//  Ohana
//
//  Domain write boundaries for workout records.
//

import Foundation
import SwiftData

@MainActor
private func fetchWorkoutCommandModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "WorkoutCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

struct WorkoutCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let ledgerEventID: UUID?
}

struct WorkoutDeleteCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum WorkoutCommandService {
    @discardableResult
    @MainActor
    static func recordHumanWorkout(
        human: Human,
        type: WorkoutType,
        durationMinutes: Int,
        date: Date,
        context: ModelContext,
        distanceKm: Double = 0,
        calories: Int = 0,
        notes: String = "",
        source: CareLedgerSource = .quickAction,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> WorkoutCommandResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = HumanWorkoutLog(
            date: date,
            type: type,
            durationMinutes: durationMinutes,
            distanceKm: max(0, distanceKm.isFinite ? distanceKm : 0),
            calories: max(0, calories),
            steps: 0,
            notes: cleanNotes,
            sourceHealthKit: false,
            human: human
        )
        context.insert(log)
        let ledgerEvent = careLedger.record(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .workout,
            actionType: log.typeRaw,
            amountValue: Double(log.durationMinutes),
            amountUnit: "min",
            note: log.notes,
            source: source,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "HumanWorkoutLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\"distanceKm\":\(log.distanceKm),\"calories\":\(log.calories),\"steps\":\(log.steps)}",
            context: context,
            save: false
        )
        context.safeSave()
        return WorkoutCommandResult(logID: log.id, subjectID: human.id, ledgerEventID: ledgerEvent.id)
    }

    @discardableResult
    @MainActor
    static func deleteHumanWorkout(
        _ log: HumanWorkoutLog,
        human: Human,
        context: ModelContext
    ) -> WorkoutDeleteCommandResult {
        let ledgerEvents = ledgerEvents(for: log.id, context: context)
        for event in ledgerEvents {
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        let logID = log.id
        CloudSyncMutationRecorder.markDeleted(log, context: context)
        context.delete(log)
        context.safeSave()
        return WorkoutDeleteCommandResult(
            logID: logID,
            subjectID: human.id,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(for logID: UUID, context: ModelContext) -> [CareLedgerEvent] {
        let idString = logID.uuidString
        let modelName = "HumanWorkoutLog"
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == modelName && event.legacyModelId == idString
            }
        )
        return fetchWorkoutCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch workout ledger events"
        )
    }
}
