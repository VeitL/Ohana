//
//  PlantBatchCareSupport.swift
//  Ohana
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

nonisolated enum PlantBatchCarePolicy {
    static let supportedQuickCareTypes: [PlantCareType] = [
        .watering,
        .fertilizing,
        .misting,
        .repotting,
        .pruning,
        .leafCleaning,
        .rotating,
        .pestCheck
    ]
}

@MainActor
extension PlantBatchCareCommandService {
    static func normalizedSelections(_ selections: [PlantBatchCareSelection]) -> [PlantBatchCareSelection] {
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

    static func skippedDuplicates(in selections: [PlantBatchCareSelection]) -> [PlantBatchCareSkippedSelection] {
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

    static func isDue(
        _ type: PlantCareType,
        for plant: Plant,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws -> Bool {
        let history = try PlantCarePlanningHistoryQuery.build(
            plantID: plant.id,
            context: context
        )
        return PlantCarePlanService.tasks(
            for: plant,
            history: history,
            now: now,
            calendar: calendar
        )
            .contains { $0.careType == type && $0.daysUntilDue <= 0 }
    }

    static func restorePoint(for plant: Plant) -> PlantBatchCareRestorePoint {
        PlantBatchCareRestorePoint(
            plantID: plant.id,
            lastWateredDate: plant.lastWateredDate,
            lastFertilizedDate: plant.lastFertilizedDate,
            lastHealthCheckDate: plant.lastHealthCheckDate,
            healthStatusRaw: plant.healthStatusRaw
        )
    }

    static func restoreBatchCareFacts(
        _ restorePoints: [UUID: PlantBatchCareRestorePoint],
        on plants: [Plant]
    ) {
        for plant in plants {
            guard let point = restorePoints[plant.id] else { continue }
            plant.lastWateredDate = point.lastWateredDate
            plant.lastFertilizedDate = point.lastFertilizedDate
            plant.lastHealthCheckDate = point.lastHealthCheckDate
            plant.healthStatusRaw = point.healthStatusRaw
        }
    }

    struct BatchRewardTrace {
        let walletEntryIDs: [UUID]
        let budgetUsageIDs: [UUID]
    }

    static func rewardTrace(
        idempotencyKey: String,
        context: ModelContext
    ) -> BatchRewardTrace {
        do {
            let sourceModelName = QuestManager.careActionFinalizationSourceModelName
            let budgetMetadataFragment = "\"careActionIdempotencyKey\":\"\(idempotencyKey)\""
            var walletDescriptor = FetchDescriptor<CoconutLedgerEntry>(
                predicate: #Predicate<CoconutLedgerEntry> { entry in
                    entry.sourceModelName == sourceModelName && entry.sourceModelId == idempotencyKey
                },
                sortBy: [SortDescriptor(\CoconutLedgerEntry.occurredAt)]
            )
            walletDescriptor.fetchLimit = 4
            var budgetDescriptor = FetchDescriptor<EconomyBudgetUsageEvent>(
                predicate: #Predicate<EconomyBudgetUsageEvent> { event in
                    event.metadataJSON.contains(budgetMetadataFragment)
                },
                sortBy: [SortDescriptor(\EconomyBudgetUsageEvent.createdAt)]
            )
            budgetDescriptor.fetchLimit = 4
            return BatchRewardTrace(
                walletEntryIDs: try context.fetch(walletDescriptor).map(\.id),
                budgetUsageIDs: try context.fetch(budgetDescriptor).map(\.id)
            )
        } catch {
            OhanaLog.warning(
                "Plant batch reward trace lookup failed: \(error.localizedDescription)",
                category: "Plants"
            )
            return BatchRewardTrace(walletEntryIDs: [], budgetUsageIDs: [])
        }
    }

    static func failedRewardCommitResult(batchID: UUID, error: String) -> PlantBatchCareRewardCommitResult {
        PlantBatchCareRewardCommitResult(
            batchID: batchID,
            didCommit: false,
            awardedCoconutDelta: 0,
            ledgerEventIDs: [],
            walletEntryIDs: [],
            budgetUsageIDs: [],
            didPersist: false,
            persistenceErrorDescription: error
        )
    }

    static func emptyUndoResult(batchID: UUID) -> PlantBatchCareUndoResult {
        PlantBatchCareUndoResult(
            batchID: batchID,
            didUndo: false,
            removedLogIDs: [],
            removedEventIDs: [],
            removedLedgerEventIDs: [],
            restoredPlantIDs: [],
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    static func completedUndoResult(
        batchID: UUID,
        didChange: Bool,
        removedLogIDs: [UUID],
        removedEventIDs: [UUID],
        removedLedgerEventIDs: [UUID],
        restoredPlantIDs: [UUID]
    ) -> PlantBatchCareUndoResult {
        PlantBatchCareUndoResult(
            batchID: batchID,
            didUndo: didChange,
            removedLogIDs: removedLogIDs,
            removedEventIDs: removedEventIDs,
            removedLedgerEventIDs: removedLedgerEventIDs,
            restoredPlantIDs: restoredPlantIDs,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    static func commitUndoSideEffects(
        notificationIDs: [String],
        scheduleResults: [PlantCarePlanScheduleResult],
        context: ModelContext
    ) {
        DomainRehydrateEffectsDispatcher.cancelNotifications(notificationIDs)
        for scheduleResult in scheduleResults {
            PlantCarePlanScheduleService.commitSideEffects(for: scheduleResult, context: context)
        }
    }
}

@MainActor
final class PlantBatchCareDeferredEconomyAwarder: CareEventEconomyAwarding {
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
