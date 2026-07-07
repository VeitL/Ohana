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
        let batchID = UUID()
        let selections = normalizedSelections(rawSelections)
        var skipped = skippedDuplicates(in: rawSelections)
        var items: [PlantBatchCareUndoItem] = []
        var restorePointsByPlantID: [UUID: PlantBatchCareRestorePoint] = [:]
        var touchedPlants: [Plant] = []
        var estimatedCoconutDelta = 0
        let deferredEconomy = PlantBatchCareDeferredEconomyAwarder()

        for selection in selections {
            guard supportedBatchCareTypes.contains(selection.careType) else {
                skipped.append(PlantBatchCareSkippedSelection(selection: selection, reason: .unsupportedCareType))
                continue
            }
            guard let plant = fetchPlant(id: selection.plantID, context: context) else {
                skipped.append(PlantBatchCareSkippedSelection(selection: selection, reason: .missingPlant))
                continue
            }
            let due = isDue(selection.careType, for: plant, now: now, calendar: calendar)
            guard !requiresDueTask || due else {
                skipped.append(PlantBatchCareSkippedSelection(selection: selection, reason: .notDue))
                continue
            }

            if restorePointsByPlantID[plant.id] == nil {
                restorePointsByPlantID[plant.id] = restorePoint(for: plant)
                touchedPlants.append(plant)
            }

            let result = PlantCareCommandService.recordCare(
                selection.careType,
                plant: plant,
                executorId: executorId,
                context: context,
                now: now,
                careLedger: CareLedgerService(),
                economy: deferredEconomy,
                syncCarePlan: false,
                scheduleNotifications: false,
                saveChanges: false,
                awardRewards: false
            )
            let wasRewardEligible = due && PlantCareCommandService.rewardAction(for: selection.careType) != nil
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
                PlantCarePlanScheduleService.sync(
                    plant: plant,
                    context: context,
                    now: now,
                    calendar: calendar,
                    scheduleNotifications: scheduleNotifications,
                    saveChanges: false
                )
            }
        }
        if !items.isEmpty {
            let saveResult = context.safeSaveResult()
            guard saveResult.didSave else {
                context.rollback()
                return PlantBatchCareCommandResult(
                    batchID: batchID,
                    items: [],
                    skipped: skipped,
                    undoToken: nil,
                    estimatedCoconutDelta: 0,
                    didPersist: false,
                    persistenceErrorDescription: saveResult.errorDescription
                )
            }
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

        for item in token.items {
            if let event = fetchEvent(id: item.eventID, context: context),
               let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                   event: event,
                   writeKind: .care,
                   source: .userCommand,
                   context: context
               ) {
                let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context, deletedAt: now, deletedByHumanId: token.executorId)
                DomainScheduleEffectsDispatcher.dispatch(delete: result)
                if result.didDelete {
                    removedEventIDs.append(item.eventID)
                }
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
            PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: now,
                calendar: calendar,
                scheduleNotifications: false,
                saveChanges: false
            )
            restoredPlantIDs.append(point.plantID)
        }

        let didChange = !removedLogIDs.isEmpty || !removedEventIDs.isEmpty || !removedLedgerEventIDs.isEmpty || !restoredPlantIDs.isEmpty
        if didChange {
            let saveResult = context.safeSaveResult()
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
            let saveResult = context.safeSaveResult()
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

    private static var supportedBatchCareTypes: Set<PlantCareType> {
        [.watering, .fertilizing, .pestCheck, .leafCleaning, .rotating, .pruning, .repotting, .misting]
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
        rewardMetadata: String,
        walletEntries: [CoconutLedgerEntry],
        budgetEvents: [EconomyBudgetUsageEvent]
    ) -> String {
        var object = CalendarTaskCompletionSyncService.metadataDictionary(from: rewardMetadata)
        object["batchID"] = batchID.uuidString
        object["walletEntryIds"] = walletEntries.map(\.id.uuidString)
        object["budgetUsageIds"] = budgetEvents.map(\.id.uuidString)
        object["generatedBy"] = "PlantBatchCareCommandService"
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"batchID\":\"\(batchID.uuidString)\"}"
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
