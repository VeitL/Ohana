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
    let didChange: Bool
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
        steps: Int = 0,
        notes: String = "",
        sourceHealthKit: Bool = false,
        healthKitWorkoutUUID: String = "",
        healthKitSourceBundleID: String = "",
        healthKitSourceName: String = "",
        sourcePetWalkLogID: String = "",
        source: CareLedgerSource = .quickAction,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> WorkoutCommandResult {
        let cleanHealthKitUUID = healthKitWorkoutUUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHealthKitSourceBundleID = healthKitSourceBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHealthKitSourceName = healthKitSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPetWalkLogID = sourcePetWalkLogID.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeDistanceKm = max(0, distanceKm.isFinite ? distanceKm : 0)
        let safeCalories = max(0, calories)
        let safeSteps = max(0, steps)

        if !cleanPetWalkLogID.isEmpty,
           let existing = existingPetWalkWorkout(
               human: human,
               sourcePetWalkLogID: cleanPetWalkLogID,
               context: context
           ) {
            attachSourceMetadataIfNeeded(
                to: existing,
                human: human,
                sourceHealthKit: sourceHealthKit,
                healthKitWorkoutUUID: cleanHealthKitUUID,
                healthKitSourceBundleID: cleanHealthKitSourceBundleID,
                healthKitSourceName: cleanHealthKitSourceName,
                sourcePetWalkLogID: cleanPetWalkLogID,
                context: context
            )
            let existingLedgerID = ledgerEvents(for: existing.id, context: context).first?.id
            return WorkoutCommandResult(logID: existing.id, subjectID: human.id, ledgerEventID: existingLedgerID)
        }

        if sourceHealthKit, !cleanHealthKitUUID.isEmpty,
           let existing = existingHealthKitWorkout(
               human: human,
               healthKitWorkoutUUID: cleanHealthKitUUID,
               context: context
           ) {
            attachSourceMetadataIfNeeded(
                to: existing,
                human: human,
                sourceHealthKit: sourceHealthKit,
                healthKitWorkoutUUID: cleanHealthKitUUID,
                healthKitSourceBundleID: cleanHealthKitSourceBundleID,
                healthKitSourceName: cleanHealthKitSourceName,
                sourcePetWalkLogID: cleanPetWalkLogID,
                context: context
            )
            let existingLedgerID = ledgerEvents(for: existing.id, context: context).first?.id
            return WorkoutCommandResult(logID: existing.id, subjectID: human.id, ledgerEventID: existingLedgerID)
        }

        if let existing = existingOverlappingSourceWorkout(
            human: human,
            type: type,
            date: date,
            durationMinutes: durationMinutes,
            distanceKm: safeDistanceKm,
            needsHealthKitSource: sourceHealthKit && !cleanHealthKitUUID.isEmpty,
            needsPetWalkSource: !cleanPetWalkLogID.isEmpty,
            context: context
        ) {
            attachSourceMetadataIfNeeded(
                to: existing,
                human: human,
                sourceHealthKit: sourceHealthKit,
                healthKitWorkoutUUID: cleanHealthKitUUID,
                healthKitSourceBundleID: cleanHealthKitSourceBundleID,
                healthKitSourceName: cleanHealthKitSourceName,
                sourcePetWalkLogID: cleanPetWalkLogID,
                context: context
            )
            let existingLedgerID = ledgerEvents(for: existing.id, context: context).first?.id
            return WorkoutCommandResult(logID: existing.id, subjectID: human.id, ledgerEventID: existingLedgerID)
        }

        guard let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: date,
            writeKind: .care,
            context: context,
            logPrefix: "WorkoutCommandService.recordHumanWorkout"
        ) else {
            return WorkoutCommandResult(logID: UUID(), subjectID: human.id, ledgerEventID: nil)
        }
        let careLedger = providedCareLedger ?? CareLedgerService()
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = DomainMemberFactWriter.createHumanWorkoutLog(
            plan: write,
            human: human,
            type: type,
            durationMinutes: durationMinutes,
            distanceKm: safeDistanceKm,
            calories: safeCalories,
            steps: safeSteps,
            notes: cleanNotes,
            sourceHealthKit: sourceHealthKit,
            healthKitWorkoutUUID: cleanHealthKitUUID,
            healthKitSourceBundleID: cleanHealthKitSourceBundleID,
            healthKitSourceName: cleanHealthKitSourceName,
            sourcePetWalkLogID: cleanPetWalkLogID,
            context: context
        )
        var ledgerEvent: CareLedgerEvent?
        DomainMemberFactEffectsDispatcher.run(plan: write) { actor in
            ledgerEvent = careLedger.record(
                occurredAt: log.date,
                actorKind: .human,
                actorId: actor.effectiveExecutorId,
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
                metadataJSON: workoutMetadataJSON(for: log),
                context: context,
                save: false
            )
        }
        context.safeSave()
        return WorkoutCommandResult(logID: log.id, subjectID: human.id, ledgerEventID: ledgerEvent?.id)
    }

    @discardableResult
    @MainActor
    static func deleteHumanWorkout(
        _ log: HumanWorkoutLog,
        human: Human,
        context: ModelContext
    ) -> WorkoutDeleteCommandResult {
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return WorkoutDeleteCommandResult(
                logID: log.id,
                subjectID: human.id,
                removedLedgerEventIDs: [],
                didChange: false
            )
        }
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
            removedLedgerEventIDs: ledgerEvents.map(\.id),
            didChange: true
        )
    }

    @MainActor
    private static func existingHealthKitWorkout(
        human: Human,
        healthKitWorkoutUUID: String,
        context: ModelContext
    ) -> HumanWorkoutLog? {
        let descriptor = FetchDescriptor<HumanWorkoutLog>(
            predicate: #Predicate<HumanWorkoutLog> { log in
                log.healthKitWorkoutUUID == healthKitWorkoutUUID
            }
        )
        return fetchWorkoutCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch existing HealthKit workout"
        )
        .first { $0.human?.id == human.id }
    }

    @MainActor
    private static func existingPetWalkWorkout(
        human: Human,
        sourcePetWalkLogID: String,
        context: ModelContext
    ) -> HumanWorkoutLog? {
        let descriptor = FetchDescriptor<HumanWorkoutLog>(
            predicate: #Predicate<HumanWorkoutLog> { log in
                log.sourcePetWalkLogID == sourcePetWalkLogID
            }
        )
        return fetchWorkoutCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch existing pet walk workout"
        )
        .first { $0.human?.id == human.id }
    }

    @MainActor
    private static func existingOverlappingSourceWorkout(
        human: Human,
        type: WorkoutType,
        date: Date,
        durationMinutes: Int,
        distanceKm: Double,
        needsHealthKitSource: Bool,
        needsPetWalkSource: Bool,
        context: ModelContext
    ) -> HumanWorkoutLog? {
        guard type.isWalkingLike, needsHealthKitSource || needsPetWalkSource else { return nil }
        let descriptor = FetchDescriptor<HumanWorkoutLog>()
        return fetchWorkoutCommandModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch overlapping workout sources"
        )
        .filter { log in
            log.human?.id == human.id
                && log.workoutType.isWalkingLike
                && (log.sourceHealthKit || !log.sourcePetWalkLogID.isEmpty)
        }
        .first { log in
            isLikelySameWorkout(
                existing: log,
                date: date,
                durationMinutes: durationMinutes,
                distanceKm: distanceKm
            )
        }
    }

    @MainActor
    private static func attachSourceMetadataIfNeeded(
        to log: HumanWorkoutLog,
        human: Human,
        sourceHealthKit: Bool,
        healthKitWorkoutUUID: String,
        healthKitSourceBundleID: String,
        healthKitSourceName: String,
        sourcePetWalkLogID: String,
        context: ModelContext
    ) {
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return
        }
        var changed = false
        if sourceHealthKit, !log.sourceHealthKit {
            log.sourceHealthKit = true
            changed = true
        }
        if !healthKitWorkoutUUID.isEmpty, log.healthKitWorkoutUUID.isEmpty {
            log.healthKitWorkoutUUID = healthKitWorkoutUUID
            changed = true
        }
        if !healthKitSourceBundleID.isEmpty, log.healthKitSourceBundleID.isEmpty {
            log.healthKitSourceBundleID = healthKitSourceBundleID
            changed = true
        }
        if !healthKitSourceName.isEmpty, log.healthKitSourceName.isEmpty {
            log.healthKitSourceName = healthKitSourceName
            changed = true
        }
        if !sourcePetWalkLogID.isEmpty, log.sourcePetWalkLogID.isEmpty {
            log.sourcePetWalkLogID = sourcePetWalkLogID
            changed = true
        }
        guard changed else { return }
        CloudSyncMutationRecorder.markModified(log, context: context)
        for event in ledgerEvents(for: log.id, context: context) {
            event.metadataJSON = workoutMetadataJSON(for: log)
            CloudSyncMutationRecorder.markModified(event, context: context)
        }
        context.safeSave()
    }

    private static func workoutMetadataJSON(for log: HumanWorkoutLog) -> String {
        if log.healthKitWorkoutUUID.isEmpty,
           log.healthKitSourceBundleID.isEmpty,
           log.healthKitSourceName.isEmpty,
           log.sourcePetWalkLogID.isEmpty {
            return "{\"distanceKm\":\(log.distanceKm),\"calories\":\(log.calories),\"steps\":\(log.steps)}"
        }

        let payload: [String: Any] = [
            "calories": log.calories,
            "distanceKm": log.distanceKm,
            "healthKitSourceBundleID": log.healthKitSourceBundleID,
            "healthKitSourceName": log.healthKitSourceName,
            "healthKitWorkoutUUID": log.healthKitWorkoutUUID,
            "sourcePetWalkLogID": log.sourcePetWalkLogID,
            "sourceHealthKit": log.sourceHealthKit,
            "steps": log.steps
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"distanceKm\":\(log.distanceKm),\"calories\":\(log.calories),\"steps\":\(log.steps)}"
        }
        return string
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

    private static func isLikelySameWorkout(
        existing: HumanWorkoutLog,
        date: Date,
        durationMinutes: Int,
        distanceKm: Double
    ) -> Bool {
        let durationDelta = abs(existing.durationMinutes - durationMinutes)
        let durationThreshold = max(10, Int(Double(max(existing.durationMinutes, durationMinutes)) * 0.2))
        let distanceDelta = abs(existing.distanceKm - distanceKm)
        let distanceThreshold = max(0.3, max(existing.distanceKm, distanceKm) * 0.18)
        let startsClose = abs(existing.date.timeIntervalSince(date)) <= 10 * 60
        return startsClose && durationDelta <= durationThreshold && distanceDelta <= distanceThreshold
    }
}

private extension WorkoutType {
    var isWalkingLike: Bool {
        switch self {
        case .walking, .hiking, .running:
            true
        case .cycling, .swimming, .gym, .yoga, .other:
            false
        }
    }
}
