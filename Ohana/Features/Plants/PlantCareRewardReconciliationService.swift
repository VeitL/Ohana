//
//  PlantCareRewardReconciliationService.swift
//  Ohana
//
//  Bounded recovery for plant-care rewards whose owning fact committed first.
//

import Foundation
import SwiftData

nonisolated struct PlantCareRewardReconciliationCursor: Codable, Equatable, Sendable {
    let sweepID: UUID

    static func fresh() -> PlantCareRewardReconciliationCursor {
        PlantCareRewardReconciliationCursor(sweepID: UUID())
    }
}

nonisolated struct PlantCareRewardReconciliationResult: Equatable, Sendable {
    let inspectedCount: Int
    let inspectedLedgerIDs: Set<UUID>
    let settledCount: Int
    let pendingCount: Int
    let skippedCount: Int
    let hasMoreWork: Bool
    let didCompleteSweep: Bool
    let checkpointPersisted: Bool
}

@MainActor
struct PlantCareRewardReconciliationOptions {
    let sweepID: UUID
    let now: Date
    let defaults: UserDefaults
    var persistCheckpoint: (ModelContext) -> ModelContextSaveResult

    init(
        sweepID: UUID,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        self.sweepID = sweepID
        self.now = now
        self.defaults = defaults
        persistCheckpoint = { context in
            context.safeSaveResult(publishFailureEvent: true)
        }
    }

    init(
        sweepID: UUID,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        persistCheckpoint: @escaping (ModelContext) -> ModelContextSaveResult
    ) {
        self.sweepID = sweepID
        self.now = now
        self.defaults = defaults
        self.persistCheckpoint = persistCheckpoint
    }
}

@MainActor
enum PlantCareRewardReconciliationService {
    static let sweepMetadataKey = "plantCareRewardSweepId"

    static func reconcile(
        context: ModelContext,
        economy: CareEventEconomyAwarding,
        maximumCount: Int = 16,
        excludingLedgerIDs: Set<UUID> = []
    ) -> PlantCareRewardReconciliationResult {
        reconcile(
            context: context,
            economy: economy,
            maximumCount: maximumCount,
            excludingLedgerIDs: excludingLedgerIDs,
            options: PlantCareRewardReconciliationOptions(sweepID: UUID())
        )
    }

    static func reconcile(
        context: ModelContext,
        economy: CareEventEconomyAwarding,
        maximumCount: Int = 16,
        sweepID: UUID
    ) -> PlantCareRewardReconciliationResult {
        reconcile(
            context: context,
            economy: economy,
            maximumCount: maximumCount,
            excludingLedgerIDs: [],
            options: PlantCareRewardReconciliationOptions(sweepID: sweepID)
        )
    }

    static func reconcile(
        context: ModelContext,
        economy: CareEventEconomyAwarding,
        maximumCount: Int = 16,
        options: PlantCareRewardReconciliationOptions
    ) -> PlantCareRewardReconciliationResult {
        reconcile(
            context: context,
            economy: economy,
            maximumCount: maximumCount,
            excludingLedgerIDs: [],
            options: options
        )
    }

    private static func reconcile(
        context: ModelContext,
        economy: CareEventEconomyAwarding,
        maximumCount: Int,
        excludingLedgerIDs: Set<UUID>,
        options: PlantCareRewardReconciliationOptions
    ) -> PlantCareRewardReconciliationResult {
        let boundedCount = max(1, min(maximumCount, 64))
        let eventKind = CareLedgerEventKind.plantCare.rawValue
        let modelName = String(describing: PlantCareLog.self)
        let pendingFragment = "\"plantCareRewardState\":\"pending\""
        let sweepFragment = "\"\(sweepMetadataKey)\":\"\(options.sweepID.uuidString)\""
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.eventKind == eventKind &&
                    ledger.legacyModelName == modelName &&
                    ledger.metadataJSON.contains(pendingFragment) &&
                    !ledger.metadataJSON.contains(sweepFragment)
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.createdAt)]
        )
        let scanLimit = min(256, boundedCount + excludingLedgerIDs.count + 1)
        descriptor.fetchLimit = scanLimit
        let fetched: [CareLedgerEvent]
        do {
            fetched = try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Plant care reward reconciliation fetch failed: \(error.localizedDescription)",
                category: "Plants"
            )
            return PlantCareRewardReconciliationResult(
                inspectedCount: 0,
                inspectedLedgerIDs: [],
                settledCount: 0,
                pendingCount: 0,
                skippedCount: 0,
                hasMoreWork: true,
                didCompleteSweep: false,
                checkpointPersisted: false
            )
        }
        let unseen = fetched.filter { !excludingLedgerIDs.contains($0.id) }
        let candidates = Array(unseen.prefix(boundedCount))
        let hasAdditionalCandidates = unseen.count > candidates.count || fetched.count == scanLimit

        let processed = processCandidates(candidates, context: context, economy: economy, options: options)
        let settledCount = processed.settledCount
        let pendingCount = processed.pendingCount
        let skippedCount = processed.skippedCount
        let invalidCandidates = processed.invalidCandidates
        let pendingCandidateIDs = processed.pendingCandidateIDs

        let requiresCheckpoint = !invalidCandidates.isEmpty || !pendingCandidateIDs.isEmpty
        if requiresCheckpoint {
            do {
                for candidate in invalidCandidates {
                    guard let ledger = try fetchLedger(id: candidate.ledgerID, context: context) else { continue }
                    guard rewardState(of: ledger) == PlantCareCommandService.rewardStatePending else { continue }
                    var metadata = CareLedgerMetadata.addingString(
                        PlantCareCommandService.rewardStateMetadataKey,
                        value: PlantCareCommandService.rewardStateInvalid,
                        to: ledger.metadataJSON
                    )
                    metadata = CareLedgerMetadata.addingString(
                        "plantCareRewardInvalidReason",
                        value: candidate.reason,
                        to: metadata
                    )
                    ledger.metadataJSON = metadata
                    CloudSyncMutationRecorder.markModified(
                        ledger,
                        context: context,
                        modifiedAt: Date()
                    )
                }
                for ledgerID in pendingCandidateIDs {
                    guard let ledger = try fetchLedger(id: ledgerID, context: context) else { continue }
                    guard rewardState(of: ledger) == PlantCareCommandService.rewardStatePending else { continue }
                    ledger.metadataJSON = CareLedgerMetadata.addingString(
                        sweepMetadataKey,
                        value: options.sweepID.uuidString,
                        to: ledger.metadataJSON
                    )
                    CloudSyncMutationRecorder.markModified(
                        ledger,
                        context: context,
                        modifiedAt: Date()
                    )
                }
            } catch {
                context.rollback()
                return checkpointFailureResult(
                    candidates: candidates,
                    settledCount: settledCount,
                    pendingCount: pendingCount,
                    skippedCount: skippedCount,
                    invalidCandidateCount: invalidCandidates.count
                )
            }

            let checkpointSave = options.persistCheckpoint(context)
            guard checkpointSave.didSave else {
                context.rollback()
                return checkpointFailureResult(
                    candidates: candidates,
                    settledCount: settledCount,
                    pendingCount: pendingCount,
                    skippedCount: skippedCount,
                    invalidCandidateCount: invalidCandidates.count
                )
            }
        }

        return PlantCareRewardReconciliationResult(
            inspectedCount: candidates.count,
            inspectedLedgerIDs: Set(candidates.map(\.id)),
            settledCount: settledCount,
            pendingCount: pendingCount,
            skippedCount: skippedCount,
            hasMoreWork: hasAdditionalCandidates,
            didCompleteSweep: !hasAdditionalCandidates,
            checkpointPersisted: true
        )
    }

    private struct CandidateProcessing {
        var settledCount = 0
        var pendingCount = 0
        var skippedCount = 0
        var invalidCandidates: [(ledgerID: UUID, reason: String)] = []
        var pendingCandidateIDs = Set<UUID>()
    }

    private static func processCandidates(
        _ candidates: [CareLedgerEvent],
        context: ModelContext,
        economy: CareEventEconomyAwarding,
        options: PlantCareRewardReconciliationOptions
    ) -> CandidateProcessing {
        var batch = CandidateProcessing()
        let activePendingBatchIDs = Set(
            PlantBatchCarePendingRewardStore.load(defaults: options.defaults)
                .filter { $0.expiresAt > options.now }
                .map(\.batchID)
        )
        for ledger in candidates {
            guard CareLedgerMetadata.stringValue(
                named: PlantCareCommandService.rewardStateMetadataKey,
                in: ledger.metadataJSON
            ) == PlantCareCommandService.rewardStatePending,
            let legacyModelID = ledger.legacyModelId,
            let logID = UUID(uuidString: legacyModelID) else {
                batch.invalidCandidates.append((ledger.id, "invalidLogReference"))
                batch.skippedCount += 1
                continue
            }
            let fetchedLog: PlantCareLog?
            do {
                fetchedLog = try fetchLog(id: logID, context: context)
            } catch {
                batch.pendingCount += 1
                batch.pendingCandidateIDs.insert(ledger.id)
                continue
            }
            guard let log = fetchedLog, let plant = log.plant else {
                batch.invalidCandidates.append((ledger.id, "missingPlantCareFact"))
                batch.skippedCount += 1
                continue
            }
            guard let operationID = UUID(uuidString: log.careTransactionId) else {
                batch.invalidCandidates.append((ledger.id, "invalidOperationID"))
                batch.skippedCount += 1
                continue
            }
            let rewardOperationDate = PlantCareCommandService.rewardOperationDate(
                in: ledger,
                fallback: ledger.createdAt
            )

            if isBatchRewardLedger(ledger) {
                if activePendingBatchIDs.contains(operationID) {
                    batch.pendingCount += 1
                    batch.pendingCandidateIDs.insert(ledger.id)
                    continue
                }
                // Reward settlement never mutates the source Event. A legacy or
                // partially repaired ledger can therefore still settle safely
                // when that observability link is absent.
                let sourceEventID = ledger.sourceEventId.flatMap(UUID.init(uuidString:)) ?? ledger.id
                let token = PlantBatchCareUndoToken(
                    id: operationID,
                    batchID: operationID,
                    createdAt: ledger.createdAt,
                    // No durable pending token means the UI undo handle was
                    // never stored (for example, the app terminated after the
                    // core save). There is no user-reachable undo window to
                    // preserve, so recovery may settle this exact-once reward
                    // immediately. Active stored tokens were filtered above.
                    expiresAt: .distantPast,
                    executorId: ledger.actorId,
                    items: [PlantBatchCareUndoItem(
                        plantID: plant.id,
                        careType: log.careType,
                        logID: log.id,
                        eventID: sourceEventID,
                        ledgerEventID: ledger.id,
                        occurredAt: log.date,
                        wasRewardEligible: true
                    )],
                    restorePoints: []
                )
                let batchResult = PlantBatchCareCommandService.commitRewards(
                    for: token,
                    context: context,
                    now: options.now,
                    economy: economy
                )
                if batchResult.didPersist {
                    batch.settledCount += 1
                } else {
                    batch.pendingCount += 1
                    batch.pendingCandidateIDs.insert(ledger.id)
                }
                continue
            }

            let request = PlantCareCommandRequest(
                careType: log.careType,
                plant: plant,
                executorID: ledger.actorId,
                now: log.date,
                careNote: log.note,
                photoData: log.photoData,
                healthStatus: log.healthStatus,
                operationID: operationID,
                rewardOperationDate: rewardOperationDate
            )
            let result = PlantCareCommandService.recordCare(
                request,
                context: context,
                options: PlantCareCommandOptions(
                    careLedger: CareLedgerService(),
                    economy: economy,
                    syncCarePlan: false,
                    scheduleNotifications: false,
                    saveChanges: true,
                    awardRewards: true
                )
            )
            if result.didPersist, result.wasReplay, !result.rewardFinalizationPending {
                batch.settledCount += 1
            } else {
                batch.pendingCount += 1
                batch.pendingCandidateIDs.insert(ledger.id)
            }
        }

        return batch
    }

    private static func checkpointFailureResult(
        candidates: [CareLedgerEvent],
        settledCount: Int,
        pendingCount: Int,
        skippedCount: Int,
        invalidCandidateCount: Int
    ) -> PlantCareRewardReconciliationResult {
        PlantCareRewardReconciliationResult(
            inspectedCount: candidates.count,
            inspectedLedgerIDs: Set(candidates.map(\.id)),
            settledCount: settledCount,
            pendingCount: pendingCount + invalidCandidateCount,
            skippedCount: max(0, skippedCount - invalidCandidateCount),
            hasMoreWork: true,
            didCompleteSweep: false,
            checkpointPersisted: false
        )
    }

    private static func rewardState(of ledger: CareLedgerEvent) -> String? {
        CareLedgerMetadata.stringValue(
            named: PlantCareCommandService.rewardStateMetadataKey,
            in: ledger.metadataJSON
        )
    }

    private static func isBatchRewardLedger(_ ledger: CareLedgerEvent) -> Bool {
        CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.batchID,
            in: ledger.metadataJSON
        ) != nil && CalendarTaskCompletionSyncService.metadataDictionary(
            from: ledger.metadataJSON
        )["generatedBy"] as? String == "PlantBatchCareCommandService"
    }

    private static func fetchLedger(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchLog(id: UUID, context: ModelContext) throws -> PlantCareLog? {
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
