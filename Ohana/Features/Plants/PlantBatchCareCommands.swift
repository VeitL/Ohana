//
//  PlantBatchCareCommands.swift
//  Ohana
//
//  Batch write boundary for completing multiple plant-care tasks with one
//  persistence save and one domain revision.
//

import Foundation
import SwiftData

@MainActor
enum PlantBatchCareCommandService {
    static let undoWindowSeconds: TimeInterval = 6

    private struct PreflightSelection {
        let selection: PlantBatchCareSelection
        let plant: Plant
        let wasDue: Bool
    }

    private struct PreflightResult {
        let selections: [PreflightSelection]
        let failures: [PlantBatchCareSkippedSelection]
    }

    private struct BatchPreparation {
        let id: UUID
        let selections: [PlantBatchCareSelection]
        let duplicateSkips: [PlantBatchCareSkippedSelection]
    }

    private struct ValidatedBatchRewardItem {
        let item: PlantBatchCareUndoItem
        let action: DomainCareRewardAction
        let ledger: CareLedgerEvent
    }

    private struct ValidatedBatchUndoItem {
        let item: PlantBatchCareUndoItem
        let event: Event
        let ledger: CareLedgerEvent
        let log: PlantCareLog
        let eventMutation: AuthorizedDomainScheduleMutation
    }

    private enum BatchUndoValidation {
        case alreadyUndone
        case ready(items: [ValidatedBatchUndoItem], plantsByID: [UUID: Plant])
    }

    private enum BatchRewardValidationFailure: Error {
        case conflict

        var description: String {
            "plantBatchCareRewardTokenConflict"
        }
    }

    private enum BatchUndoValidationFailure: Error {
        case conflict

        var description: String {
            "plantBatchCareUndoTokenConflict"
        }
    }

    private enum BatchFactValidationPurpose {
        case rewardCommit
        case undo
    }

    private struct BatchRecordingOptions {
        let calendar: Calendar
        let requiresDueTask: Bool
        let syncCarePlan: Bool
        let scheduleNotifications: Bool
        let operationID: UUID
        let clock: () -> Date
        let persistChanges: ((ModelContext) -> ModelContextSaveResult)?
    }

    private struct BatchRecordedFacts {
        var skipped: [PlantBatchCareSkippedSelection]
        var items: [PlantBatchCareUndoItem] = []
        var restorePointsByPlantID: [UUID: PlantBatchCareRestorePoint] = [:]
        var touchedPlants: [Plant] = []
        var estimatedCoconutDelta = 0
    }

    private enum BatchRecordingOutcome {
        case recorded(BatchRecordedFacts)
        case rejected(PlantBatchCareCommandResult)
    }

    @discardableResult
    static func completeDueCare(
        selections rawSelections: [PlantBatchCareSelection],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current,
        syncCarePlan: Bool = true,
        scheduleNotifications: Bool = false,
        operationID: UUID = UUID(),
        clock: () -> Date = Date.init,
        persistChanges: ((ModelContext) -> ModelContextSaveResult)? = nil
    ) -> PlantBatchCareCommandResult {
        withoutActuallyEscaping(clock) { escapingClock in
            recordBatchCare(
                selections: rawSelections,
                context: context,
                executorId: executorId,
                now: now,
                options: BatchRecordingOptions(
                    calendar: calendar,
                    requiresDueTask: true,
                    syncCarePlan: syncCarePlan,
                    scheduleNotifications: scheduleNotifications,
                    operationID: operationID,
                    clock: escapingClock,
                    persistChanges: persistChanges
                )
            )
        }
    }

    @discardableResult
    static func recordQuickCare(
        selections rawSelections: [PlantBatchCareSelection],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current,
        syncCarePlan: Bool = true,
        scheduleNotifications: Bool = false,
        operationID: UUID = UUID(),
        clock: () -> Date = Date.init,
        persistChanges: ((ModelContext) -> ModelContextSaveResult)? = nil
    ) -> PlantBatchCareCommandResult {
        withoutActuallyEscaping(clock) { escapingClock in
            recordBatchCare(
                selections: rawSelections,
                context: context,
                executorId: executorId,
                now: now,
                options: BatchRecordingOptions(
                    calendar: calendar,
                    requiresDueTask: false,
                    syncCarePlan: syncCarePlan,
                    scheduleNotifications: scheduleNotifications,
                    operationID: operationID,
                    clock: escapingClock,
                    persistChanges: persistChanges
                )
            )
        }
    }

    @discardableResult
    private static func recordBatchCare(
        selections rawSelections: [PlantBatchCareSelection],
        context: ModelContext,
        executorId: String?,
        now: Date,
        options: BatchRecordingOptions
    ) -> PlantBatchCareCommandResult {
        let preparation = batchPreparation(rawSelections, operationID: options.operationID)
        let effectiveExecutorID: String?
        do {
            effectiveExecutorID = try resolvedBatchExecutorID(
                executorId,
                context: context
            )
        } catch {
            return emptyBatchResult(
                batchID: preparation.id,
                skipped: preparation.duplicateSkips,
                didPersist: false,
                persistenceErrorDescription: "plantBatchCareExecutorLookupFailed: \(error.localizedDescription)"
            )
        }
        if let replay = persistedReplay(
            for: preparation,
            occurrenceDate: now,
            requestedExecutorID: effectiveExecutorID,
            context: context
        ) {
            return replay
        }
        let batchID = preparation.id
        let selections = preparation.selections
        let preflightResult: PreflightResult
        do {
            preflightResult = try preflight(
                selections: selections,
                context: context,
                now: now,
                calendar: options.calendar,
                requiresDueTask: options.requiresDueTask
            )
        } catch {
            return emptyBatchResult(
                batchID: batchID,
                skipped: preparation.duplicateSkips,
                didPersist: false,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        let preflightSkips = preparation.duplicateSkips + preflightResult.failures
        guard preflightResult.failures.isEmpty else {
            return emptyBatchResult(
                batchID: batchID,
                skipped: preflightSkips,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        let recordedFacts: BatchRecordedFacts
        switch recordValidatedSelections(
            preflightResult.selections,
            batchID: batchID,
            initialSkips: preparation.duplicateSkips,
            executorID: effectiveExecutorID,
            now: now,
            context: context
        ) {
        case let .recorded(facts):
            recordedFacts = facts
        case let .rejected(result):
            return result
        }
        return finishBatchRecording(
            recordedFacts,
            batchID: batchID,
            executorID: effectiveExecutorID,
            now: now,
            context: context,
            options: options
        )
    }

    private static func recordValidatedSelections(
        _ selections: [PreflightSelection],
        batchID: UUID,
        initialSkips: [PlantBatchCareSkippedSelection],
        executorID: String?,
        now: Date,
        context: ModelContext
    ) -> BatchRecordingOutcome {
        var facts = BatchRecordedFacts(skipped: initialSkips)
        let deferredEconomy = PlantBatchCareDeferredEconomyAwarder()
        for validatedSelection in selections {
            let selection = validatedSelection.selection
            let plant = validatedSelection.plant
            if facts.restorePointsByPlantID[plant.id] == nil {
                facts.restorePointsByPlantID[plant.id] = restorePoint(for: plant)
                facts.touchedPlants.append(plant)
            }
            let wasRewardEligible = validatedSelection.wasDue &&
                PlantCareCommandService.rewardAction(for: selection.careType) != nil
            let result = recordCare(
                selection: selection,
                plant: plant,
                executorId: executorID,
                now: now,
                careTransactionId: batchID.uuidString,
                economy: deferredEconomy,
                context: context
            )
            guard result.didPersist else {
                return rejectRecordedSelection(
                    facts,
                    selection: selection,
                    batchID: batchID,
                    error: result.persistenceError,
                    context: context
                )
            }
            let ledger: CareLedgerEvent
            do {
                guard let fetchedLedger = try fetchLedgerEvent(id: result.ledgerEventID, context: context) else {
                    return rejectRecordedSelection(
                        facts,
                        selection: selection,
                        batchID: batchID,
                        error: "plantBatchCareMissingLedger",
                        context: context
                    )
                }
                ledger = fetchedLedger
            } catch {
                return rejectRecordedSelection(
                    facts,
                    selection: selection,
                    batchID: batchID,
                    error: error.localizedDescription,
                    context: context
                )
            }
            ledger.metadataJSON = preparedRewardMetadata(
                batchID: batchID,
                existingMetadata: ledger.metadataJSON,
                wasRewardEligible: wasRewardEligible
            )
            if wasRewardEligible, let action = PlantCareCommandService.rewardAction(for: selection.careType) {
                let rewards = action.baseRewards
                facts.estimatedCoconutDelta += max(0, rewards.human) + max(0, rewards.pet)
            }
            facts.items.append(PlantBatchCareUndoItem(
                plantID: result.plantID,
                careType: result.careType,
                logID: result.logID,
                eventID: result.eventID,
                ledgerEventID: result.ledgerEventID,
                occurredAt: now,
                wasRewardEligible: wasRewardEligible
            ))
        }
        return .recorded(facts)
    }

    private static func rejectRecordedSelection(
        _ facts: BatchRecordedFacts,
        selection: PlantBatchCareSelection,
        batchID: UUID,
        error: String?,
        context: ModelContext
    ) -> BatchRecordingOutcome {
        restoreBatchCareFacts(facts.restorePointsByPlantID, on: facts.touchedPlants)
        context.rollback()
        return .rejected(emptyBatchResult(
            batchID: batchID,
            skipped: facts.skipped + [PlantBatchCareSkippedSelection(selection: selection, reason: .commandRejected)],
            didPersist: false,
            persistenceErrorDescription: error
        ))
    }

    private static func finishBatchRecording(
        _ facts: BatchRecordedFacts,
        batchID: UUID,
        executorID: String?,
        now: Date,
        context: ModelContext,
        options: BatchRecordingOptions
    ) -> PlantBatchCareCommandResult {
        var scheduleResults: [PlantCarePlanScheduleResult] = []
        if options.syncCarePlan {
            for plant in facts.touchedPlants {
                let scheduleResult = PlantCarePlanScheduleService.sync(
                    plant: plant,
                    context: context,
                    now: now,
                    calendar: options.calendar,
                    scheduleNotifications: options.scheduleNotifications,
                    saveChanges: false
                )
                guard scheduleResult.didPersist else {
                    restoreBatchCareFacts(facts.restorePointsByPlantID, on: facts.touchedPlants)
                    context.rollback()
                    return emptyBatchResult(
                        batchID: batchID,
                        skipped: facts.skipped,
                        didPersist: false,
                        persistenceErrorDescription: scheduleResult.persistenceErrorDescription
                    )
                }
                scheduleResults.append(scheduleResult)
            }
        }
        if !facts.items.isEmpty {
            let saveResult = options.persistChanges?(context) ?? context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                restoreBatchCareFacts(facts.restorePointsByPlantID, on: facts.touchedPlants)
                context.rollback()
                return emptyBatchResult(
                    batchID: batchID,
                    skipped: facts.skipped,
                    didPersist: false,
                    persistenceErrorDescription: saveResult.errorDescription
                )
            }
        }
        for scheduleResult in scheduleResults {
            PlantCarePlanScheduleService.commitSideEffects(for: scheduleResult, context: context)
        }

        let restorePoints = Array(facts.restorePointsByPlantID.values)
            .sorted { $0.plantID.uuidString < $1.plantID.uuidString }
        let committedAt = facts.items.isEmpty ? nil : options.clock()
        let token = committedAt.map { committedAt in
            PlantBatchCareUndoToken(
                id: batchID,
                batchID: batchID,
                createdAt: committedAt,
                expiresAt: committedAt.addingTimeInterval(undoWindowSeconds),
                executorId: executorID,
                items: facts.items,
                restorePoints: restorePoints
            )
        }
        return PlantBatchCareCommandResult(
            batchID: batchID,
            items: facts.items,
            skipped: facts.skipped,
            undoToken: token,
            estimatedCoconutDelta: facts.estimatedCoconutDelta,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private static func emptyBatchResult(
        batchID: UUID,
        skipped: [PlantBatchCareSkippedSelection],
        didPersist: Bool,
        persistenceErrorDescription: String?
    ) -> PlantBatchCareCommandResult {
        PlantBatchCareCommandResult(
            batchID: batchID,
            items: [],
            skipped: skipped,
            undoToken: nil,
            estimatedCoconutDelta: 0,
            didPersist: didPersist,
            persistenceErrorDescription: persistenceErrorDescription
        )
    }

    private static func recordCare(
        selection: PlantBatchCareSelection,
        plant: Plant,
        executorId: String?,
        now: Date,
        careTransactionId: String,
        economy: CareEventEconomyAwarding,
        context: ModelContext
    ) -> PlantCareCommandResult {
        let request = PlantCareCommandRequest(
            careType: selection.careType,
            plant: plant,
            executorID: executorId,
            now: now,
            rewardOperationDate: now
        )
        let options = PlantCareCommandOptions(
            careLedger: CareLedgerService(),
            economy: economy,
            syncCarePlan: false,
            scheduleNotifications: false,
            saveChanges: false,
            awardRewards: false
        )
        return PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options,
            careTransactionId: careTransactionId
        )
    }

    @discardableResult
    static func undo(
        _ token: PlantBatchCareUndoToken,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        allowExpired: Bool = false,
        scheduleSync: ((Plant, ModelContext, Date, Calendar) -> PlantCarePlanScheduleResult)? = nil
    ) -> PlantBatchCareUndoResult {
        guard allowExpired || now <= token.expiresAt else {
            return emptyUndoResult(batchID: token.batchID)
        }

        let validation: BatchUndoValidation
        do {
            validation = try validateUndo(token, context: context)
        } catch let failure as BatchUndoValidationFailure {
            return failedUndoResult(
                batchID: token.batchID,
                errorDescription: failure.description
            )
        } catch {
            return failedUndoResult(
                batchID: token.batchID,
                errorDescription: error.localizedDescription
            )
        }
        guard case let .ready(validatedItems, plantsByID) = validation else {
            return emptyUndoResult(batchID: token.batchID)
        }

        var removedLogIDs: [UUID] = []
        var removedEventIDs: [UUID] = []
        var removedLedgerEventIDs: [UUID] = []
        var restoredPlantIDs: [UUID] = []
        var notificationIDsToCancel: [String] = []
        var scheduleResults: [PlantCarePlanScheduleResult] = []
        var liveSummaryRestorePoints: [UUID: PlantBatchCareRestorePoint] = [:]
        var liveSummaryPlants: [Plant] = []

        for point in token.restorePoints {
            guard let plant = plantsByID[point.plantID] else {
                return failedUndoResult(
                    batchID: token.batchID,
                    errorDescription: BatchUndoValidationFailure.conflict.description
                )
            }
            liveSummaryRestorePoints[plant.id] = restorePoint(for: plant)
            liveSummaryPlants.append(plant)
        }

        for validated in validatedItems {
            guard deleteUndoItem(validated, token: token, context: context, now: now, notificationIDsToCancel: &notificationIDsToCancel) else {
                rollbackUndoChanges(
                    context: context,
                    liveSummaryRestorePoints: liveSummaryRestorePoints,
                    liveSummaryPlants: liveSummaryPlants
                )
                return failedUndoResult(
                    batchID: token.batchID,
                    errorDescription: BatchUndoValidationFailure.conflict.description
                )
            }
            removedEventIDs.append(validated.item.eventID)
            removedLedgerEventIDs.append(validated.item.ledgerEventID)
            removedLogIDs.append(validated.item.logID)
        }

        for point in token.restorePoints {
            guard let plant = plantsByID[point.plantID] else { continue }
            plant.lastWateredDate = point.lastWateredDate
            plant.lastFertilizedDate = point.lastFertilizedDate
            plant.lastHealthCheckDate = point.lastHealthCheckDate
            plant.healthStatusRaw = point.healthStatusRaw
            CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
            let scheduleResult = if let scheduleSync {
                scheduleSync(plant, context, now, calendar)
            } else {
                PlantCarePlanScheduleService.sync(
                    plant: plant,
                    context: context,
                    now: now,
                    calendar: calendar,
                    scheduleNotifications: false,
                    saveChanges: false
                )
            }
            guard scheduleResult.didPersist else {
                rollbackUndoChanges(
                    context: context,
                    liveSummaryRestorePoints: liveSummaryRestorePoints,
                    liveSummaryPlants: liveSummaryPlants
                )
                return failedUndoResult(
                    batchID: token.batchID,
                    errorDescription: scheduleResult.persistenceErrorDescription
                )
            }
            scheduleResults.append(scheduleResult)
            restoredPlantIDs.append(point.plantID)
        }

        let didChange = !removedLogIDs.isEmpty || !removedEventIDs.isEmpty || !removedLedgerEventIDs.isEmpty || !restoredPlantIDs.isEmpty
        if didChange {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                rollbackUndoChanges(
                    context: context,
                    liveSummaryRestorePoints: liveSummaryRestorePoints,
                    liveSummaryPlants: liveSummaryPlants
                )
                return PlantBatchCareUndoResult(
                    batchID: token.batchID,
                    didUndo: false,
                    removedLogIDs: [],
                    removedEventIDs: [],
                    removedLedgerEventIDs: [],
                    restoredPlantIDs: [],
                    didPersist: false,
                    persistenceErrorDescription: saveResult.errorDescription
                )
            }
        }
        commitUndoSideEffects(notificationIDs: notificationIDsToCancel, scheduleResults: scheduleResults, context: context)

        return completedUndoResult(
            batchID: token.batchID,
            didChange: didChange,
            removedLogIDs: removedLogIDs,
            removedEventIDs: removedEventIDs,
            removedLedgerEventIDs: removedLedgerEventIDs,
            restoredPlantIDs: restoredPlantIDs
        )
    }

    private static func deleteUndoItem(
        _ validated: ValidatedBatchUndoItem,
        token: PlantBatchCareUndoToken,
        context: ModelContext,
        now: Date,
        notificationIDsToCancel: inout [String]
    ) -> Bool {
        guard DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: validated.event,
            writeKind: .care,
            source: .userCommand,
            context: context
        ) != nil else { return false }
        let result = DomainScheduleWriter.deleteEvent(
            validated.event,
            mutation: validated.eventMutation,
            context: context,
            deletedAt: now,
            deletedByHumanId: token.executorId
        )
        guard result.didDelete else { return false }
        notificationIDsToCancel.append(contentsOf: result.notificationIdsToCancel)
        CloudSyncMutationRecorder.markDeleted(
            validated.ledger,
            context: context,
            deletedAt: now,
            deletedByHumanId: token.executorId
        )
        context.delete(validated.ledger)
        context.delete(validated.log)
        return true
    }

    private static func rollbackUndoChanges(
        context: ModelContext,
        liveSummaryRestorePoints: [UUID: PlantBatchCareRestorePoint],
        liveSummaryPlants: [Plant]
    ) {
        restoreBatchCareFacts(liveSummaryRestorePoints, on: liveSummaryPlants)
        context.rollback()
        restoreBatchCareFacts(liveSummaryRestorePoints, on: liveSummaryPlants)
    }

    private static func failedUndoResult(
        batchID: UUID,
        errorDescription: String?
    ) -> PlantBatchCareUndoResult {
        PlantBatchCareUndoResult(
            batchID: batchID,
            didUndo: false,
            removedLogIDs: [],
            removedEventIDs: [],
            removedLedgerEventIDs: [],
            restoredPlantIDs: [],
            didPersist: false,
            persistenceErrorDescription: errorDescription
        )
    }

    @discardableResult
    static func commitRewards(
        for token: PlantBatchCareUndoToken,
        context: ModelContext,
        now: Date = Date(),
        economy providedEconomy: CareEventEconomyAwarding? = nil,
        persistChanges: (ModelContext) -> ModelContextSaveResult = { context in
            context.safeSaveResult(publishFailureEvent: true)
        }
    ) -> PlantBatchCareRewardCommitResult {
        guard now >= token.expiresAt else {
            return failedRewardCommitResult(batchID: token.batchID, error: "plantBatchCareUndoWindowActive")
        }
        let economy = providedEconomy ?? DomainServiceDependencyRegistry.careEventEconomy()
        var awardedCoconutDelta = 0
        var ledgerEventIDs: [UUID] = []
        var walletEntryIDs: [UUID] = []
        var budgetUsageIDs: [UUID] = []
        var hasPendingFinalization = false
        let validatedRewardItems: [ValidatedBatchRewardItem]
        do {
            validatedRewardItems = try validateRewardItems(in: token, context: context)
        } catch let failure as BatchRewardValidationFailure {
            return failedRewardCommitResult(batchID: token.batchID, error: failure.description)
        } catch {
            return failedRewardCommitResult(batchID: token.batchID, error: error.localizedDescription)
        }

        for validated in validatedRewardItems {
            let item = validated.item
            let action = validated.action
            let ledger = validated.ledger
            guard shouldFinalizeReward(in: ledger) else { continue }
            let idempotencyKey = batchRewardIdempotencyKey(
                batchID: token.batchID,
                ledgerEventID: ledger.id
            )
            let operationDate = PlantCareCommandService.rewardOperationDate(
                in: ledger,
                fallback: item.occurredAt
            )
            let reward = economy.awardIdempotentCareAction(
                type: action,
                pet: nil,
                context: context,
                quality: .none,
                date: operationDate,
                executorId: ledger.actorId ?? token.executorId,
                careObjectKey: item.plantID,
                idempotencyKey: idempotencyKey,
                idempotencyID: ledger.id
            )
            guard reward.didPersist else {
                hasPendingFinalization = true
                continue
            }
            let rewardPair = (humanGot: reward.humanGot, petGot: reward.petGot)
            let rewardJSON = economy.rewardMetadata(for: rewardPair)
            let trace = rewardTrace(
                idempotencyKey: idempotencyKey,
                context: context
            )
            let delta = max(0, reward.humanGot) + max(0, reward.petGot)
            ledger.coconutDelta = delta
            ledger.metadataJSON = rewardMetadata(
                batchID: token.batchID,
                existingMetadata: ledger.metadataJSON,
                rewardMetadata: rewardJSON,
                idempotencyKey: idempotencyKey,
                walletEntryIDs: trace.walletEntryIDs,
                budgetUsageIDs: trace.budgetUsageIDs
            )
            CloudSyncMutationRecorder.markModified(ledger, context: context, modifiedAt: now)
            let checkpoint = persistChanges(context)
            guard checkpoint.didSave else {
                context.rollback()
                economy.refreshProjectionAfterRollback(context: context)
                return PlantBatchCareRewardCommitResult(
                    batchID: token.batchID,
                    didCommit: !ledgerEventIDs.isEmpty,
                    awardedCoconutDelta: awardedCoconutDelta,
                    ledgerEventIDs: ledgerEventIDs,
                    walletEntryIDs: walletEntryIDs,
                    budgetUsageIDs: budgetUsageIDs,
                    didPersist: false,
                    persistenceErrorDescription: checkpoint.errorDescription
                )
            }
            awardedCoconutDelta += delta
            ledgerEventIDs.append(ledger.id)
            walletEntryIDs.append(contentsOf: trace.walletEntryIDs)
            budgetUsageIDs.append(contentsOf: trace.budgetUsageIDs)
        }

        if hasPendingFinalization {
            return PlantBatchCareRewardCommitResult(
                batchID: token.batchID,
                didCommit: !ledgerEventIDs.isEmpty,
                awardedCoconutDelta: awardedCoconutDelta,
                ledgerEventIDs: ledgerEventIDs,
                walletEntryIDs: walletEntryIDs,
                budgetUsageIDs: budgetUsageIDs,
                didPersist: false,
                persistenceErrorDescription: "plantBatchCareRewardFinalizationPending"
            )
        }

        return PlantBatchCareRewardCommitResult(
            batchID: token.batchID,
            didCommit: !ledgerEventIDs.isEmpty,
            awardedCoconutDelta: awardedCoconutDelta,
            ledgerEventIDs: ledgerEventIDs,
            walletEntryIDs: walletEntryIDs,
            budgetUsageIDs: budgetUsageIDs,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }
}

@MainActor
extension PlantBatchCareCommandService {
    private static func validateUndo(
        _ token: PlantBatchCareUndoToken,
        context: ModelContext
    ) throws -> BatchUndoValidation {
        guard tokenEnvelopeIsValid(token, requiresRestorePoints: true) else {
            throw BatchUndoValidationFailure.conflict
        }
        var lookups: [(
            item: PlantBatchCareUndoItem,
            event: Event?,
            ledger: CareLedgerEvent?,
            log: PlantCareLog?
        )] = []
        for item in token.items {
            lookups.append((
                item: item,
                event: try fetchEvent(id: item.eventID, context: context),
                ledger: try fetchLedgerEvent(id: item.ledgerEventID, context: context),
                log: try fetchPlantCareLog(id: item.logID, context: context)
            ))
        }
        if lookups.allSatisfy({ $0.event == nil && $0.ledger == nil && $0.log == nil }) {
            return .alreadyUndone
        }
        guard lookups.allSatisfy({ $0.event != nil && $0.ledger != nil && $0.log != nil }) else {
            throw BatchUndoValidationFailure.conflict
        }

        var plantsByID: [UUID: Plant] = [:]
        for point in token.restorePoints {
            guard let plant = try fetchPlant(id: point.plantID, context: context),
                  !plant.isArchived else {
                throw BatchUndoValidationFailure.conflict
            }
            plantsByID[plant.id] = plant
        }

        let items = try lookups.map { lookup -> ValidatedBatchUndoItem in
            guard let event = lookup.event,
                  let ledger = lookup.ledger,
                  let log = lookup.log,
                  batchFactLinksAreValid(
                      item: lookup.item,
                      token: token,
                      event: event,
                      ledger: ledger,
                      log: log,
                      purpose: .undo
                  ),
                  let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                      event: event,
                      writeKind: .care,
                      source: .userCommand,
                      context: context
                  ) else {
                throw BatchUndoValidationFailure.conflict
            }
            return ValidatedBatchUndoItem(
                item: lookup.item,
                event: event,
                ledger: ledger,
                log: log,
                eventMutation: mutation
            )
        }
        return .ready(items: items, plantsByID: plantsByID)
    }

    private static func validateRewardItems(
        in token: PlantBatchCareUndoToken,
        context: ModelContext
    ) throws -> [ValidatedBatchRewardItem] {
        guard tokenEnvelopeIsValid(token, requiresRestorePoints: false) else {
            throw BatchRewardValidationFailure.conflict
        }
        return try token.items.filter(\.wasRewardEligible).map { item in
            guard let action = PlantCareCommandService.rewardAction(for: item.careType),
                  let ledger = try fetchLedgerEvent(id: item.ledgerEventID, context: context),
                  let log = try fetchPlantCareLog(id: item.logID, context: context),
                  batchFactLinksAreValid(
                      item: item,
                      token: token,
                      event: nil,
                      ledger: ledger,
                      log: log,
                      purpose: .rewardCommit
                  ) else {
                throw BatchRewardValidationFailure.conflict
            }
            return ValidatedBatchRewardItem(item: item, action: action, ledger: ledger)
        }
    }

    private static func tokenEnvelopeIsValid(
        _ token: PlantBatchCareUndoToken,
        requiresRestorePoints: Bool
    ) -> Bool {
        guard token.id == token.batchID,
              !token.items.isEmpty,
              token.executorId == normalizedExecutorID(token.executorId),
              Set(token.items.map(\.ledgerEventID)).count == token.items.count,
              Set(token.items.map(\.logID)).count == token.items.count,
              Set(token.items.map(\.eventID)).count == token.items.count else {
            return false
        }
        let targetKeys = token.items.map {
            "\($0.plantID.uuidString):\($0.careType.rawValue)"
        }
        guard Set(targetKeys).count == targetKeys.count else { return false }
        guard requiresRestorePoints else { return true }
        let restorePointPlantIDs = token.restorePoints.map(\.plantID)
        return !restorePointPlantIDs.isEmpty &&
            Set(restorePointPlantIDs).count == restorePointPlantIDs.count &&
            Set(restorePointPlantIDs) == Set(token.items.map(\.plantID))
    }

    private static func batchFactLinksAreValid(
        item: PlantBatchCareUndoItem,
        token: PlantBatchCareUndoToken,
        event: Event?,
        ledger: CareLedgerEvent,
        log: PlantCareLog,
        purpose: BatchFactValidationPurpose
    ) -> Bool {
        let transactionID = token.batchID.uuidString
        let expectedExecutorID = normalizedExecutorID(token.executorId)
        let expectedActorKind = expectedExecutorID == nil
            ? CareLedgerActorKind.unknown.rawValue
            : CareLedgerActorKind.human.rawValue
        guard log.plant?.id == item.plantID,
              log.careType == item.careType,
              log.careTransactionId == transactionID,
              log.date == item.occurredAt,
              log.executorId == expectedExecutorID,
              ledger.subjectKind == CareLedgerSubjectKind.plant.rawValue,
              ledger.subjectId == item.plantID.uuidString,
              ledger.eventKind == CareLedgerEventKind.plantCare.rawValue,
              ledger.actionType == item.careType.rawValue,
              ledger.occurredAt == item.occurredAt,
              ledger.actorKind == expectedActorKind,
              ledger.actorId == expectedExecutorID,
              ledger.source == CareLedgerSource.detail.rawValue,
              ledger.sourceReminderId == nil,
              ledger.legacyModelName == String(describing: PlantCareLog.self),
              ledger.legacyModelId == item.logID.uuidString,
              CareLedgerMetadata.stringValue(
                  named: CareLedgerMetadata.careTransactionId,
                  in: ledger.metadataJSON
              ) == transactionID else {
            return false
        }

        switch purpose {
        case .rewardCommit:
            let sourceEventMatches = ledger.sourceEventId == item.eventID.uuidString ||
                (ledger.sourceEventId == nil && item.eventID == ledger.id)
            guard sourceEventMatches else { return false }
        case .undo:
            guard ledger.sourceEventId == item.eventID.uuidString,
                  let event,
                  event.relatedEntityType == EntityKind.plant.rawValue,
                  event.relatedEntityId == item.plantID.uuidString,
                  event.eventType == item.careType.eventType.rawValue,
                  event.startDate == item.occurredAt,
                  event.recurrenceDays == 0,
                  !event.isAllDay,
                  event.assigneeId == expectedExecutorID else {
                return false
            }
        }

        let metadata = CalendarTaskCompletionSyncService.metadataDictionary(from: ledger.metadataJSON)
        if let rawBatchID = metadata[CareLedgerMetadata.batchID],
           rawBatchID as? String != transactionID {
            return false
        }
        let generatedBy: String?
        if let rawGeneratedBy = metadata["generatedBy"] {
            guard let value = rawGeneratedBy as? String,
                  value == "PlantBatchCareCommandService" else {
                return false
            }
            generatedBy = value
        } else {
            generatedBy = nil
        }
        let rewardState: String?
        if let rawRewardState = metadata[PlantCareCommandService.rewardStateMetadataKey] {
            guard let value = rawRewardState as? String else { return false }
            rewardState = value
        } else {
            rewardState = nil
        }

        if item.wasRewardEligible {
            guard PlantCareCommandService.rewardAction(for: item.careType) != nil else { return false }
            switch purpose {
            case .rewardCommit:
                if let rewardState {
                    return rewardState == PlantCareCommandService.rewardStatePending ||
                        rewardState == PlantCareCommandService.rewardStateSettled
                }
                // Pre-state tokens are pending when no generated marker exists;
                // a generated marker denotes an already-settled legacy token.
                return generatedBy == nil || generatedBy == "PlantBatchCareCommandService"
            case .undo:
                if let rewardState {
                    return rewardState == PlantCareCommandService.rewardStatePending
                }
                return generatedBy == nil
            }
        }

        switch purpose {
        case .rewardCommit:
            return false
        case .undo:
            if let rewardState {
                return rewardState == PlantCareCommandService.rewardStateNotEligible
            }
            return generatedBy == nil
        }
    }

    private static func normalizedExecutorID(_ raw: String?) -> String? {
        guard let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else { return nil }
        return normalized
    }

    private nonisolated static let supportedBatchCareTypes = Set(PlantBatchCarePolicy.supportedQuickCareTypes)

    private static func preflight(
        selections: [PlantBatchCareSelection],
        context: ModelContext,
        now: Date,
        calendar: Calendar,
        requiresDueTask: Bool
    ) throws -> PreflightResult {
        var validatedSelections: [PreflightSelection] = []
        var failures: [PlantBatchCareSkippedSelection] = []

        for selection in selections {
            guard supportedBatchCareTypes.contains(selection.careType) else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .unsupportedCareType))
                continue
            }
            guard let plant = try fetchPlant(id: selection.plantID, context: context) else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .missingPlant))
                continue
            }
            guard !plant.isArchived else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .archivedPlant))
                continue
            }
            let due = try isDue(
                selection.careType,
                for: plant,
                context: context,
                now: now,
                calendar: calendar
            )
            guard !requiresDueTask || due else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .notDue))
                continue
            }
            validatedSelections.append(
                PreflightSelection(selection: selection, plant: plant, wasDue: due)
            )
        }

        return PreflightResult(selections: validatedSelections, failures: failures)
    }

    private static func rewardMetadata(
        batchID: UUID,
        existingMetadata: String,
        rewardMetadata: String,
        idempotencyKey: String,
        walletEntryIDs: [UUID],
        budgetUsageIDs: [UUID]
    ) -> String {
        var object = CalendarTaskCompletionSyncService.metadataDictionary(from: existingMetadata)
        let rewardObject = CalendarTaskCompletionSyncService.metadataDictionary(from: rewardMetadata)
        object.merge(rewardObject) { _, rewardValue in rewardValue }
        object[CareLedgerMetadata.careTransactionId] = batchID.uuidString
        object[CareLedgerMetadata.batchID] = batchID.uuidString
        object[PlantCareCommandService.rewardStateMetadataKey] = PlantCareCommandService.rewardStateSettled
        object["rewardIdempotencyKey"] = idempotencyKey
        object["walletEntryIds"] = walletEntryIDs.map(\.uuidString)
        object["budgetUsageIds"] = budgetUsageIDs.map(\.uuidString)
        object["generatedBy"] = "PlantBatchCareCommandService"
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"batchID\":\"\(batchID.uuidString)\",\"careTransactionId\":\"\(batchID.uuidString)\"}"
        }
        return json
    }

    private static func preparedRewardMetadata(
        batchID: UUID,
        existingMetadata: String,
        wasRewardEligible: Bool
    ) -> String {
        var object = CalendarTaskCompletionSyncService.metadataDictionary(from: existingMetadata)
        object[CareLedgerMetadata.careTransactionId] = batchID.uuidString
        object[CareLedgerMetadata.batchID] = batchID.uuidString
        object[PlantCareCommandService.rewardStateMetadataKey] = wasRewardEligible
            ? PlantCareCommandService.rewardStatePending
            : PlantCareCommandService.rewardStateNotEligible
        object["generatedBy"] = "PlantBatchCareCommandService"
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return existingMetadata
        }
        return json
    }

    private static func shouldFinalizeReward(in ledger: CareLedgerEvent) -> Bool {
        let metadata = CalendarTaskCompletionSyncService.metadataDictionary(from: ledger.metadataJSON)
        let state = metadata[PlantCareCommandService.rewardStateMetadataKey] as? String
        if state == PlantCareCommandService.rewardStatePending { return true }
        if state == PlantCareCommandService.rewardStateSettled ||
            state == PlantCareCommandService.rewardStateNotEligible ||
            state == PlantCareCommandService.rewardStateInvalid {
            return false
        }
        // Compatibility for tokens written before the explicit reward state:
        // generated batch metadata means settlement already completed, while
        // a bare/disabled care ledger still needs its delayed reward.
        return metadata["generatedBy"] as? String != "PlantBatchCareCommandService"
    }

    private static func batchRewardIdempotencyKey(batchID: UUID, ledgerEventID: UUID) -> String {
        "plantBatchCareReward:\(batchID.uuidString):\(ledgerEventID.uuidString)"
    }

    private static func fetchPlant(id: UUID, context: ModelContext) throws -> Plant? {
        var descriptor = FetchDescriptor<Plant>(predicate: #Predicate<Plant> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchEvent(id: UUID, context: ModelContext) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPlantCareLog(id: UUID, context: ModelContext) throws -> PlantCareLog? {
        var descriptor = FetchDescriptor<PlantCareLog>(predicate: #Predicate<PlantCareLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func batchPreparation(
        _ rawSelections: [PlantBatchCareSelection],
        operationID: UUID
    ) -> BatchPreparation {
        let selections = normalizedSelections(rawSelections)
        return BatchPreparation(
            id: operationID,
            selections: selections,
            duplicateSkips: skippedDuplicates(in: rawSelections)
        )
    }

    private static func persistedReplay(
        for preparation: BatchPreparation,
        occurrenceDate: Date,
        requestedExecutorID: String?,
        context: ModelContext
    ) -> PlantBatchCareCommandResult? {
        let transactionID = preparation.id.uuidString
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { $0.careTransactionId == transactionID }
        )
        descriptor.fetchLimit = max(1, preparation.selections.count + 1)
        let persistedLogs: [PlantCareLog]
        do {
            persistedLogs = try context.fetch(descriptor)
        } catch {
            return emptyBatchResult(
                batchID: preparation.id,
                skipped: preparation.duplicateSkips,
                didPersist: false,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        guard !persistedLogs.isEmpty else { return nil }

        let expectedTargets = Set(preparation.selections.map {
            "\($0.plantID.uuidString):\($0.careType.rawValue)"
        })
        let persistedTargets = Set(persistedLogs.compactMap { log -> String? in
            guard let plantID = log.plant?.id else { return nil }
            return "\(plantID.uuidString):\(log.careType.rawValue)"
        })
        let isExactReplay = persistedLogs.count == preparation.selections.count &&
            persistedTargets == expectedTargets &&
            persistedLogs.allSatisfy { $0.date == occurrenceDate }
        guard isExactReplay else {
            return emptyBatchResult(
                batchID: preparation.id,
                skipped: preparation.duplicateSkips,
                didPersist: false,
                persistenceErrorDescription: "plantBatchCareOperationConflict"
            )
        }
        do {
            try validatePersistedReplayLinks(
                persistedLogs,
                batchID: preparation.id,
                occurrenceDate: occurrenceDate,
                requestedExecutorID: requestedExecutorID,
                context: context
            )
        } catch let failure as PlantBatchReplayValidationFailure {
            return emptyBatchResult(
                batchID: preparation.id,
                skipped: preparation.duplicateSkips,
                didPersist: false,
                persistenceErrorDescription: failure.description
            )
        } catch {
            return emptyBatchResult(
                batchID: preparation.id,
                skipped: preparation.duplicateSkips,
                didPersist: false,
                persistenceErrorDescription: "plantBatchCareOperationLookupFailed: \(error.localizedDescription)"
            )
        }
        return emptyBatchResult(
            batchID: preparation.id,
            skipped: preparation.duplicateSkips,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private enum PlantBatchReplayValidationFailure: Error {
        case incomplete
        case conflict

        var description: String {
            switch self {
            case .incomplete:
                "plantBatchCareOperationIncomplete"
            case .conflict:
                "plantBatchCareOperationConflict"
            }
        }
    }

    private static func validatePersistedReplayLinks(
        _ logs: [PlantCareLog],
        batchID: UUID,
        occurrenceDate: Date,
        requestedExecutorID: String?,
        context: ModelContext
    ) throws {
        let transactionID = batchID.uuidString
        let normalizedRequestedExecutorID = requestedExecutorID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedActorKind = normalizedRequestedExecutorID == nil
            ? CareLedgerActorKind.unknown.rawValue
            : CareLedgerActorKind.human.rawValue
        for log in logs {
            guard let plant = log.plant else {
                throw PlantBatchReplayValidationFailure.incomplete
            }
            guard log.executorId == normalizedRequestedExecutorID else {
                throw PlantBatchReplayValidationFailure.conflict
            }

            let ledgers = try fetchReplayLedgers(logID: log.id, context: context)
            guard ledgers.count == 1, let ledger = ledgers.first else {
                throw PlantBatchReplayValidationFailure.incomplete
            }
            guard ledger.actorKind == expectedActorKind,
                  ledger.actorId == log.executorId,
                  ledger.subjectKind == CareLedgerSubjectKind.plant.rawValue,
                  ledger.subjectId == plant.id.uuidString,
                  ledger.eventKind == CareLedgerEventKind.plantCare.rawValue,
                  ledger.actionType == log.careType.rawValue,
                  ledger.occurredAt == occurrenceDate,
                  ledger.source == CareLedgerSource.detail.rawValue,
                  ledger.sourceReminderId == nil,
                  ledger.legacyModelName == String(describing: PlantCareLog.self),
                  ledger.legacyModelId == log.id.uuidString,
                  CareLedgerMetadata.stringValue(
                      named: CareLedgerMetadata.careTransactionId,
                      in: ledger.metadataJSON
                  ) == transactionID,
                  CareLedgerMetadata.stringValue(
                      named: CareLedgerMetadata.batchID,
                      in: ledger.metadataJSON
                  ) == transactionID,
                  CalendarTaskCompletionSyncService.metadataDictionary(
                      from: ledger.metadataJSON
                  )["generatedBy"] as? String == "PlantBatchCareCommandService" else {
                throw PlantBatchReplayValidationFailure.conflict
            }
            let rewardState = CareLedgerMetadata.stringValue(
                named: PlantCareCommandService.rewardStateMetadataKey,
                in: ledger.metadataJSON
            )
            guard let rewardState, [
                PlantCareCommandService.rewardStatePending,
                PlantCareCommandService.rewardStateSettled,
                PlantCareCommandService.rewardStateNotEligible,
                PlantCareCommandService.rewardStateInvalid
            ].contains(rewardState) else {
                throw PlantBatchReplayValidationFailure.incomplete
            }
            guard let sourceEventID = ledger.sourceEventId.flatMap(UUID.init(uuidString:)),
                  let event = try fetchReplayEvent(id: sourceEventID, context: context) else {
                throw PlantBatchReplayValidationFailure.incomplete
            }
            guard event.relatedEntityType == EntityKind.plant.rawValue,
                  event.relatedEntityId == plant.id.uuidString,
                  event.eventType == log.careType.eventType.rawValue,
                  event.startDate == occurrenceDate,
                  event.recurrenceDays == 0,
                  !event.isAllDay,
                  event.assigneeId == normalizedRequestedExecutorID else {
                throw PlantBatchReplayValidationFailure.conflict
            }
        }
    }

    private static func fetchReplayLedgers(
        logID: UUID,
        context: ModelContext
    ) throws -> [CareLedgerEvent] {
        let modelName = String(describing: PlantCareLog.self)
        let modelID = logID.uuidString
        let eventKind = CareLedgerEventKind.plantCare.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.legacyModelName == modelName &&
                    ledger.legacyModelId == modelID &&
                    ledger.eventKind == eventKind
            }
        )
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }

    private static func fetchReplayEvent(
        id: UUID,
        context: ModelContext
    ) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in event.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func resolvedBatchExecutorID(
        _ requestedExecutorID: String?,
        context: ModelContext
    ) throws -> String? {
        guard let raw = requestedExecutorID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let humanID = UUID(uuidString: raw) else {
            return nil
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in human.id == humanID }
        )
        descriptor.fetchLimit = 1
        guard let human = try context.fetch(descriptor).first,
              !human.hasPassedAway else {
            return nil
        }
        return human.id.uuidString
    }

    private static func fetchLedgerEvent(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(predicate: #Predicate<CareLedgerEvent> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
