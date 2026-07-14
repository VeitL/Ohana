//
//  PlantBatchCareCommands.swift
//  Ohana
//
//  Batch write boundary for completing multiple plant-care tasks with one
//  persistence save and one domain revision.
//

import Foundation
import SwiftData

nonisolated struct PlantBatchCareSelection: Hashable, Sendable {
    let plantID: UUID
    let careType: PlantCareType
    let taskID: String?

    init(plantID: UUID, careType: PlantCareType, taskID: String? = nil) {
        self.plantID = plantID
        self.careType = careType
        self.taskID = taskID
    }
}

nonisolated struct PlantBatchCareRestorePoint: Codable, Equatable, Sendable {
    let plantID: UUID
    let lastWateredDate: Date?
    let lastFertilizedDate: Date?
    let lastHealthCheckDate: Date?
    let healthStatusRaw: String
}

nonisolated struct PlantBatchCareUndoItem: Codable, Equatable, Sendable {
    let plantID: UUID
    let careType: PlantCareType
    let logID: UUID
    let eventID: UUID
    let ledgerEventID: UUID
    let occurredAt: Date
    let wasRewardEligible: Bool
}

nonisolated struct PlantBatchCareUndoToken: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let expiresAt: Date
    let executorId: String?
    let items: [PlantBatchCareUndoItem]
    let restorePoints: [PlantBatchCareRestorePoint]

    var affectedEntityIDs: Set<UUID> {
        var ids = Set(restorePoints.map(\.plantID))
        for item in items {
            ids.insert(item.logID)
            ids.insert(item.eventID)
            ids.insert(item.ledgerEventID)
        }
        return ids
    }
}

nonisolated enum PlantBatchCarePendingRewardStore {
    private static let key = "ohana_pending_plant_batch_care_reward_tokens_v1"

    static func upsert(_ token: PlantBatchCareUndoToken, defaults: UserDefaults = .standard) {
        var tokens = load(defaults: defaults).filter { $0.batchID != token.batchID }
        tokens.append(token)
        save(tokens, defaults: defaults)
    }

    static func remove(batchID: UUID, defaults: UserDefaults = .standard) {
        let tokens = load(defaults: defaults).filter { $0.batchID != batchID }
        save(tokens, defaults: defaults)
    }

    static func expiredTokens(now: Date = Date(), defaults: UserDefaults = .standard) -> [PlantBatchCareUndoToken] {
        load(defaults: defaults)
            .filter { $0.expiresAt <= now }
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    static func nextSettlementDate(now: Date = Date(), defaults: UserDefaults = .standard) -> Date? {
        load(defaults: defaults)
            .map(\.expiresAt)
            .filter { $0 >= now }
            .min()
    }

    static func load(defaults: UserDefaults = .standard) -> [PlantBatchCareUndoToken] {
        guard let data = defaults.data(forKey: key),
              let tokens = try? JSONDecoder().decode([PlantBatchCareUndoToken].self, from: data) else {
            return []
        }
        return tokens
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    private static func save(_ tokens: [PlantBatchCareUndoToken], defaults: UserDefaults) {
        if tokens.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        defaults.set(data, forKey: key)
    }
}

nonisolated struct PlantBatchCareSkippedSelection: Equatable, Sendable {
    enum Reason: String, Sendable {
        case duplicate
        case missingPlant
        case notDue
        case unsupportedCareType
        case archivedPlant
        case commandRejected
    }

    let selection: PlantBatchCareSelection
    let reason: Reason
}

nonisolated struct PlantBatchCareCommandResult: Equatable, Sendable {
    let batchID: UUID
    let items: [PlantBatchCareUndoItem]
    let skipped: [PlantBatchCareSkippedSelection]
    let undoToken: PlantBatchCareUndoToken?
    let estimatedCoconutDelta: Int
    let didPersist: Bool
    let persistenceErrorDescription: String?

    var completedCount: Int { items.count }
    var affectedEntityIDs: Set<UUID> { didPersist ? undoToken?.affectedEntityIDs ?? [] : [] }
    var didWrite: Bool { didPersist && !items.isEmpty }
}

nonisolated struct PlantBatchCareUndoResult: Equatable, Sendable {
    let batchID: UUID
    let didUndo: Bool
    let removedLogIDs: [UUID]
    let removedEventIDs: [UUID]
    let removedLedgerEventIDs: [UUID]
    let restoredPlantIDs: [UUID]
    let didPersist: Bool
    let persistenceErrorDescription: String?

    var affectedEntityIDs: Set<UUID> {
        didPersist ? Set(removedLogIDs + removedEventIDs + removedLedgerEventIDs + restoredPlantIDs) : []
    }
}

nonisolated struct PlantBatchCareRewardCommitResult: Equatable, Sendable {
    let batchID: UUID
    let didCommit: Bool
    let awardedCoconutDelta: Int
    let ledgerEventIDs: [UUID]
    let walletEntryIDs: [UUID]
    let budgetUsageIDs: [UUID]
    let didPersist: Bool
    let persistenceErrorDescription: String?

    var affectedEntityIDs: Set<UUID> {
        didPersist ? Set(ledgerEventIDs + walletEntryIDs + budgetUsageIDs) : []
    }
}

@MainActor
enum PlantBatchCareCommandService {
    private static let undoWindowSeconds: TimeInterval = 6

    nonisolated static let supportedQuickCareTypes: [PlantCareType] = [
        .watering,
        .fertilizing,
        .misting,
        .repotting,
        .pruning,
        .leafCleaning,
        .rotating,
        .pestCheck
    ]

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

    @discardableResult
    static func completeDueCare(
        selections rawSelections: [PlantBatchCareSelection],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current,
        syncCarePlan: Bool = true,
        scheduleNotifications: Bool = false
    ) -> PlantBatchCareCommandResult {
        recordBatchCare(
            selections: rawSelections,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar,
            requiresDueTask: true,
            syncCarePlan: syncCarePlan,
            scheduleNotifications: scheduleNotifications
        )
    }

    @discardableResult
    static func recordQuickCare(
        selections rawSelections: [PlantBatchCareSelection],
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        calendar: Calendar = .current,
        syncCarePlan: Bool = true,
        scheduleNotifications: Bool = false
    ) -> PlantBatchCareCommandResult {
        recordBatchCare(
            selections: rawSelections,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar,
            requiresDueTask: false,
            syncCarePlan: syncCarePlan,
            scheduleNotifications: scheduleNotifications
        )
    }

    @discardableResult
    private static func recordBatchCare(
        selections rawSelections: [PlantBatchCareSelection],
        context: ModelContext,
        executorId: String?,
        now: Date,
        calendar: Calendar,
        requiresDueTask: Bool,
        syncCarePlan: Bool,
        scheduleNotifications: Bool
    ) -> PlantBatchCareCommandResult {
        let preparation = batchPreparation(rawSelections, now: now, requiresDueTask: requiresDueTask, calendar: calendar)
        if let replay = persistedReplay(for: preparation, context: context) { return replay }
        let batchID = preparation.id
        let selections = preparation.selections
        let preflight = preflight(
            selections: selections,
            context: context,
            now: now,
            calendar: calendar,
            requiresDueTask: requiresDueTask
        )
        let preflightSkips = preparation.duplicateSkips + preflight.failures
        guard preflight.failures.isEmpty else {
            return emptyBatchResult(
                batchID: batchID,
                skipped: preflightSkips,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        var skipped = preparation.duplicateSkips
        var items: [PlantBatchCareUndoItem] = []
        var restorePointsByPlantID: [UUID: PlantBatchCareRestorePoint] = [:]
        var touchedPlants: [Plant] = []
        var scheduleResults: [PlantCarePlanScheduleResult] = []
        var estimatedCoconutDelta = 0
        let deferredEconomy = PlantBatchCareDeferredEconomyAwarder()

        for validatedSelection in preflight.selections {
            let selection = validatedSelection.selection
            let plant = validatedSelection.plant
            let existingRestorePoint = restorePointsByPlantID[plant.id]
            let restorePointBeforeCommand = existingRestorePoint ?? restorePoint(for: plant)

            let result = recordCare(
                selection: selection,
                plant: plant,
                executorId: executorId,
                now: now,
                careTransactionId: batchID.uuidString,
                economy: deferredEconomy,
                context: context
            )
            guard result.didPersist else {
                skipped.append(PlantBatchCareSkippedSelection(selection: selection, reason: .commandRejected))
                context.rollback()
                return emptyBatchResult(
                    batchID: batchID,
                    skipped: skipped,
                    didPersist: false,
                    persistenceErrorDescription: result.persistenceError
                )
            }
            if existingRestorePoint == nil {
                restorePointsByPlantID[plant.id] = restorePointBeforeCommand
                touchedPlants.append(plant)
            }
            let wasRewardEligible = validatedSelection.wasDue && PlantCareCommandService.rewardAction(for: selection.careType) != nil
            if wasRewardEligible, let action = PlantCareCommandService.rewardAction(for: selection.careType) {
                let rewards = action.baseRewards
                estimatedCoconutDelta += max(0, rewards.human) + max(0, rewards.pet)
            }
            items.append(
                PlantBatchCareUndoItem(
                    plantID: result.plantID,
                    careType: result.careType,
                    logID: result.logID,
                    eventID: result.eventID,
                    ledgerEventID: result.ledgerEventID,
                    occurredAt: now,
                    wasRewardEligible: wasRewardEligible
                )
            )
        }

        if syncCarePlan {
            for plant in touchedPlants {
                let scheduleResult = PlantCarePlanScheduleService.sync(
                    plant: plant,
                    context: context,
                    now: now,
                    calendar: calendar,
                    scheduleNotifications: scheduleNotifications,
                    saveChanges: false
                )
                scheduleResults.append(scheduleResult)
            }
        }
        if !items.isEmpty {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return emptyBatchResult(
                    batchID: batchID,
                    skipped: skipped,
                    didPersist: false,
                    persistenceErrorDescription: saveResult.errorDescription
                )
            }
        }
        for scheduleResult in scheduleResults {
            PlantCarePlanScheduleService.commitSideEffects(for: scheduleResult, context: context)
        }

        let restorePoints = Array(restorePointsByPlantID.values)
            .sorted { $0.plantID.uuidString < $1.plantID.uuidString }
        let token = items.isEmpty ? nil : PlantBatchCareUndoToken(
            id: batchID,
            batchID: batchID,
            createdAt: now,
            expiresAt: now.addingTimeInterval(undoWindowSeconds),
            executorId: executorId,
            items: items,
            restorePoints: restorePoints
        )
        return PlantBatchCareCommandResult(
            batchID: batchID,
            items: items,
            skipped: skipped,
            undoToken: token,
            estimatedCoconutDelta: estimatedCoconutDelta,
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
            now: now
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
        allowExpired: Bool = false
    ) -> PlantBatchCareUndoResult {
        guard allowExpired || now <= token.expiresAt else {
            return PlantBatchCareUndoResult(
                batchID: token.batchID,
                didUndo: false,
                removedLogIDs: [],
                removedEventIDs: [],
                removedLedgerEventIDs: [],
                restoredPlantIDs: [],
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        var removedLogIDs: [UUID] = []
        var removedEventIDs: [UUID] = []
        var removedLedgerEventIDs: [UUID] = []
        var restoredPlantIDs: [UUID] = []
        var notificationIDsToCancel: [String] = []
        var scheduleResults: [PlantCarePlanScheduleResult] = []

        for item in token.items {
            if let event = fetchEvent(id: item.eventID, context: context),
               let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                   event: event,
                   writeKind: .care,
                   source: .userCommand,
                   context: context
               ) {
                let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context, deletedAt: now, deletedByHumanId: token.executorId)
                if result.didDelete {
                    removedEventIDs.append(item.eventID)
                }
                notificationIDsToCancel.append(contentsOf: result.notificationIdsToCancel)
            }

            if let ledger = fetchLedgerEvent(id: item.ledgerEventID, context: context) {
                CloudSyncMutationRecorder.markDeleted(ledger, context: context, deletedAt: now, deletedByHumanId: token.executorId)
                context.delete(ledger)
                removedLedgerEventIDs.append(item.ledgerEventID)
            }

            if let log = fetchPlantCareLog(id: item.logID, context: context) {
                context.delete(log)
                removedLogIDs.append(item.logID)
            }
        }

        for point in token.restorePoints {
            guard let plant = fetchPlant(id: point.plantID, context: context) else { continue }
            plant.lastWateredDate = point.lastWateredDate
            plant.lastFertilizedDate = point.lastFertilizedDate
            plant.lastHealthCheckDate = point.lastHealthCheckDate
            plant.healthStatusRaw = point.healthStatusRaw
            CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
            let scheduleResult = PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                calendar: calendar,
                scheduleNotifications: false,
                saveChanges: false
            )
            scheduleResults.append(scheduleResult)
            restoredPlantIDs.append(point.plantID)
        }

        let didChange = !removedLogIDs.isEmpty || !removedEventIDs.isEmpty || !removedLedgerEventIDs.isEmpty || !restoredPlantIDs.isEmpty
        if didChange {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
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
        DomainRehydrateEffectsDispatcher.cancelNotifications(notificationIDsToCancel)
        for scheduleResult in scheduleResults {
            PlantCarePlanScheduleService.commitSideEffects(for: scheduleResult, context: context)
        }

        return PlantBatchCareUndoResult(
            batchID: token.batchID,
            didUndo: didChange,
            removedLogIDs: removedLogIDs,
            removedEventIDs: removedEventIDs,
            removedLedgerEventIDs: removedLedgerEventIDs,
            restoredPlantIDs: restoredPlantIDs,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    static func commitRewards(
        for token: PlantBatchCareUndoToken,
        context: ModelContext,
        now: Date = Date(),
        economy providedEconomy: CareEventEconomyAwarding? = nil
    ) -> PlantBatchCareRewardCommitResult {
        let economy = providedEconomy ?? DomainServiceDependencyRegistry.careEventEconomy()
        var awardedCoconutDelta = 0
        var ledgerEventIDs: [UUID] = []
        var walletEntryIDs: [UUID] = []
        var budgetUsageIDs: [UUID] = []

        for item in token.items where item.wasRewardEligible {
            guard let action = PlantCareCommandService.rewardAction(for: item.careType),
                  let ledger = fetchLedgerEvent(id: item.ledgerEventID, context: context),
                  ledger.coconutDelta == 0 else {
                continue
            }
            let walletBefore = Set(fetchAll(CoconutLedgerEntry.self, context: context).map(\.id))
            let budgetBefore = Set(fetchAll(EconomyBudgetUsageEvent.self, context: context).map(\.id))
            let reward = economy.awardCareAction(
                type: action,
                pet: nil,
                context: context,
                quality: .none,
                date: item.occurredAt,
                executorId: token.executorId,
                careObjectKey: item.plantID
            )
            let newWalletEntries = fetchAll(CoconutLedgerEntry.self, context: context)
                .filter { !walletBefore.contains($0.id) }
            let newBudgetEvents = fetchAll(EconomyBudgetUsageEvent.self, context: context)
                .filter { !budgetBefore.contains($0.id) }
            let delta = max(0, reward.humanGot) + max(0, reward.petGot)
            ledger.coconutDelta = delta
            ledger.metadataJSON = rewardMetadata(
                batchID: token.batchID,
                existingMetadata: ledger.metadataJSON,
                rewardMetadata: economy.rewardMetadata(for: reward),
                walletEntries: newWalletEntries,
                budgetEvents: newBudgetEvents
            )
            CloudSyncMutationRecorder.markModified(ledger, context: context, modifiedAt: now)
            awardedCoconutDelta += delta
            ledgerEventIDs.append(ledger.id)
            walletEntryIDs.append(contentsOf: newWalletEntries.map(\.id))
            budgetUsageIDs.append(contentsOf: newBudgetEvents.map(\.id))
        }

        if !ledgerEventIDs.isEmpty {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return PlantBatchCareRewardCommitResult(
                    batchID: token.batchID,
                    didCommit: false,
                    awardedCoconutDelta: 0,
                    ledgerEventIDs: [],
                    walletEntryIDs: [],
                    budgetUsageIDs: [],
                    didPersist: false,
                    persistenceErrorDescription: saveResult.errorDescription
                )
            }
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

    private nonisolated static let supportedBatchCareTypes = Set(supportedQuickCareTypes)

    private static func preflight(
        selections: [PlantBatchCareSelection],
        context: ModelContext,
        now: Date,
        calendar: Calendar,
        requiresDueTask: Bool
    ) -> PreflightResult {
        var validatedSelections: [PreflightSelection] = []
        var failures: [PlantBatchCareSkippedSelection] = []

        for selection in selections {
            guard supportedBatchCareTypes.contains(selection.careType) else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .unsupportedCareType))
                continue
            }
            guard let plant = fetchPlant(id: selection.plantID, context: context) else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .missingPlant))
                continue
            }
            guard !plant.isArchived else {
                failures.append(PlantBatchCareSkippedSelection(selection: selection, reason: .archivedPlant))
                continue
            }
            let due = isDue(selection.careType, for: plant, now: now, calendar: calendar)
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

    private static func normalizedSelections(_ selections: [PlantBatchCareSelection]) -> [PlantBatchCareSelection] {
        var seen: Set<String> = []
        var result: [PlantBatchCareSelection] = []
        for selection in selections {
            let key = "\(selection.plantID.uuidString):\(selection.careType.rawValue)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(selection)
        }
        return result
    }

    private static func skippedDuplicates(in selections: [PlantBatchCareSelection]) -> [PlantBatchCareSkippedSelection] {
        var seen: Set<String> = []
        var skipped: [PlantBatchCareSkippedSelection] = []
        for selection in selections {
            let key = "\(selection.plantID.uuidString):\(selection.careType.rawValue)"
            if seen.contains(key) {
                skipped.append(PlantBatchCareSkippedSelection(selection: selection, reason: .duplicate))
            } else {
                seen.insert(key)
            }
        }
        return skipped
    }

    private static func isDue(
        _ type: PlantCareType,
        for plant: Plant,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
            .contains { $0.careType == type && $0.daysUntilDue <= 0 }
    }

    private static func restorePoint(for plant: Plant) -> PlantBatchCareRestorePoint {
        PlantBatchCareRestorePoint(
            plantID: plant.id,
            lastWateredDate: plant.lastWateredDate,
            lastFertilizedDate: plant.lastFertilizedDate,
            lastHealthCheckDate: plant.lastHealthCheckDate,
            healthStatusRaw: plant.healthStatusRaw
        )
    }

    private static func rewardMetadata(
        batchID: UUID,
        existingMetadata: String,
        rewardMetadata: String,
        walletEntries: [CoconutLedgerEntry],
        budgetEvents: [EconomyBudgetUsageEvent]
    ) -> String {
        var object = CalendarTaskCompletionSyncService.metadataDictionary(from: existingMetadata)
        let rewardObject = CalendarTaskCompletionSyncService.metadataDictionary(from: rewardMetadata)
        object.merge(rewardObject) { _, rewardValue in rewardValue }
        object[CareLedgerMetadata.careTransactionId] = batchID.uuidString
        object[CareLedgerMetadata.batchID] = batchID.uuidString
        object["walletEntryIds"] = walletEntries.map(\.id.uuidString)
        object["budgetUsageIds"] = budgetEvents.map(\.id.uuidString)
        object["generatedBy"] = "PlantBatchCareCommandService"
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"batchID\":\"\(batchID.uuidString)\",\"careTransactionId\":\"\(batchID.uuidString)\"}"
        }
        return json
    }

    private static func fetchPlant(id: UUID, context: ModelContext) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(predicate: #Predicate<Plant> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrEmpty(descriptor, context: context).first
    }

    private static func fetchEvent(id: UUID, context: ModelContext) -> Event? {
        var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrEmpty(descriptor, context: context).first
    }

    private static func fetchPlantCareLog(id: UUID, context: ModelContext) -> PlantCareLog? {
        var descriptor = FetchDescriptor<PlantCareLog>(predicate: #Predicate<PlantCareLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrEmpty(descriptor, context: context).first
    }

    private static func hasPersistedBatch(_ batchID: UUID, context: ModelContext) -> Bool {
        let transactionID = batchID.uuidString
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { $0.careTransactionId == transactionID }
        )
        descriptor.fetchLimit = 1
        return !fetchOrEmpty(descriptor, context: context).isEmpty
    }

    private static func batchPreparation(
        _ rawSelections: [PlantBatchCareSelection],
        now: Date,
        requiresDueTask: Bool,
        calendar: Calendar
    ) -> BatchPreparation {
        let selections = normalizedSelections(rawSelections)
        return BatchPreparation(
            id: stableBatchID(
                selections: selections,
                occurrenceDate: now,
                requiresDueTask: requiresDueTask,
                calendar: calendar
            ),
            selections: selections,
            duplicateSkips: skippedDuplicates(in: rawSelections)
        )
    }

    private static func persistedReplay(
        for preparation: BatchPreparation,
        context: ModelContext
    ) -> PlantBatchCareCommandResult? {
        guard hasPersistedBatch(preparation.id, context: context) else { return nil }
        return emptyBatchResult(
            batchID: preparation.id,
            skipped: preparation.duplicateSkips,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private static func stableBatchID(
        selections: [PlantBatchCareSelection],
        occurrenceDate: Date,
        requiresDueTask: Bool,
        calendar: Calendar
    ) -> UUID {
        let day = calendar.dateComponents([.year, .month, .day], from: occurrenceDate)
        let targetKey = selections
            .map { "\($0.plantID.uuidString):\($0.careType.rawValue)" }
            .sorted()
            .joined(separator: "|")
        let seed = [
            requiresDueTask ? "due" : "quick",
            String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0),
            targetKey
        ].joined(separator: ":")
        var hash = UInt64(1_469_598_103_934_665_603)
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let a = UInt32(truncatingIfNeeded: hash)
        let b = UInt16(truncatingIfNeeded: hash >> 32)
        let c = UInt16(truncatingIfNeeded: hash >> 48)
        let d = UInt16(truncatingIfNeeded: hash ^ 0xBA7C)
        let e = UInt64(truncatingIfNeeded: hash ^ 0x0B47_C4A3_5EED_F00D)
        let value = String(
            format: "%08X-%04X-%04X-%04X-%012llX",
            a,
            b,
            c,
            d,
            e & 0x0000_FFFF_FFFF_FFFF
        )
        return UUID(uuidString: value) ?? UUID()
    }

    private static func fetchLedgerEvent(id: UUID, context: ModelContext) -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(predicate: #Predicate<CareLedgerEvent> { $0.id == id })
        descriptor.fetchLimit = 1
        return fetchOrEmpty(descriptor, context: context).first
    }

    private static func fetchAll<T: PersistentModel>(_ model: T.Type, context: ModelContext) -> [T] {
        fetchOrEmpty(FetchDescriptor<T>(), context: context)
    }

    private static func fetchOrEmpty<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, context: ModelContext) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning("PlantBatchCareCommandService fetch failed: \(error.localizedDescription)", category: "Plants")
            return []
        }
    }
}

@MainActor
private final class PlantBatchCareDeferredEconomyAwarder: CareEventEconomyAwarding {
    func awardCareAction(
        type _: DomainCareRewardAction,
        pet _: Pet?,
        context _: ModelContext,
        quality _: DomainCareRewardQuality,
        date _: Date,
        executorId _: String?,
        careObjectKey _: UUID?
    ) -> (humanGot: Int, petGot: Int) {
        (0, 0)
    }

    func awardSharedCareAction(
        type _: DomainCareRewardAction,
        pets _: [Pet],
        context _: ModelContext,
        quality _: DomainCareRewardQuality,
        title _: String?,
        executorId _: String?
    ) -> (humanGot: Int, petGot: Int) {
        (0, 0)
    }

    func rewardMetadata(for _: (humanGot: Int, petGot: Int)?) -> String { "" }
    func recordFirstMeal(actorId _: String?, context _: ModelContext) {}
    func clearCooldown(petId _: UUID?, type _: DomainCareRewardAction) {}
    func refreshProjectionAfterRollback(context _: ModelContext) {}
}
