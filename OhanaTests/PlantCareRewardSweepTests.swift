import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantCareRewardSweepTests {
    @Test func persistentSweepReachesValidTailAfterSeventyFailuresAndThenRotates() throws {
        let fixture = try makePendingFixture(failingCount: 70, includesSuccessfulTail: true)
        let context = fixture.container.mainContext
        let economy = SelectiveRewardEconomy(successfulOperationIDs: fixture.successfulOperationIDs)
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cursor = PlantCareRewardReconciliationCursorStore.cursor(defaults: defaults)

        let firstLaunch = runStartupBudget(
            context: context,
            economy: economy,
            sweepID: cursor.sweepID,
            defaults: defaults
        )
        let cursorAfterFirstLaunch = PlantCareRewardReconciliationCursorStore.advance(
            checkpointPersisted: firstLaunch.checkpointPersisted,
            didCompleteSweep: firstLaunch.didCompleteSweep,
            defaults: defaults
        )

        #expect(firstLaunch.inspectedLedgerIDs.count == 64)
        #expect(firstLaunch.settledCount == 0)
        #expect(firstLaunch.pendingCount == 64)
        #expect(firstLaunch.hasMoreWork)
        #expect(!firstLaunch.didCompleteSweep)
        #expect(firstLaunch.checkpointPersisted)
        #expect(cursorAfterFirstLaunch == cursor)
        #expect(PlantCareRewardReconciliationCursorStore.cursor(defaults: defaults) == cursor)
        let successfulLedgerID = try #require(fixture.successfulLedgerID)
        let fetchedTailBeforeContinuation = try fetchLedger(id: successfulLedgerID, context: context)
        let tailBeforeContinuation = try #require(fetchedTailBeforeContinuation)
        #expect(rewardState(of: tailBeforeContinuation) == PlantCareCommandService.rewardStatePending)

        let secondLaunch = runStartupBudget(
            context: context,
            economy: economy,
            sweepID: cursorAfterFirstLaunch.sweepID,
            defaults: defaults
        )

        #expect(secondLaunch.inspectedLedgerIDs.count == 7)
        #expect(firstLaunch.inspectedLedgerIDs.isDisjoint(with: secondLaunch.inspectedLedgerIDs))
        #expect(secondLaunch.settledCount == 1)
        #expect(secondLaunch.pendingCount == 6)
        #expect(!secondLaunch.hasMoreWork)
        #expect(secondLaunch.didCompleteSweep)
        #expect(secondLaunch.checkpointPersisted)
        let allVisited = firstLaunch.inspectedLedgerIDs.union(secondLaunch.inspectedLedgerIDs)
        #expect(allVisited.count == 71)
        let fetchedSettledTail = try fetchLedger(id: successfulLedgerID, context: context)
        let settledTail = try #require(fetchedSettledTail)
        #expect(rewardState(of: settledTail) == "settled")
        #expect(settledTail.coconutDelta == 2)

        let failedLedgers = try fixture.failingLedgerIDs.compactMap { ledgerID in
            try fetchLedger(id: ledgerID, context: context)
        }
        #expect(failedLedgers.count == 70)
        #expect(failedLedgers.allSatisfy {
            CareLedgerMetadata.stringValue(
                named: PlantCareRewardReconciliationService.sweepMetadataKey,
                in: $0.metadataJSON
            ) == cursor.sweepID.uuidString
        })

        let rotated = PlantCareRewardReconciliationCursorStore.advance(
            checkpointPersisted: secondLaunch.checkpointPersisted,
            didCompleteSweep: secondLaunch.didCompleteSweep,
            defaults: defaults
        )
        #expect(rotated.sweepID != cursor.sweepID)
        #expect(PlantCareRewardReconciliationCursorStore.cursor(defaults: defaults) == rotated)
        let nextSweep = PlantCareRewardReconciliationService.reconcile(
            context: context,
            economy: economy,
            maximumCount: 1,
            sweepID: rotated.sweepID
        )
        #expect(nextSweep.inspectedCount == 1)
        #expect(nextSweep.pendingCount == 1)
        #expect(nextSweep.checkpointPersisted)
        let retriedLedgerID = try #require(nextSweep.inspectedLedgerIDs.first)
        #expect(fixture.failingLedgerIDs.contains(retriedLedgerID))
    }

    @Test func failedCheckpointKeepsCursorAndSameLedgerEligibleForRetry() throws {
        let fixture = try makePendingFixture(failingCount: 1, includesSuccessfulTail: false)
        let context = fixture.container.mainContext
        let economy = SelectiveRewardEconomy(successfulOperationIDs: [])
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cursor = PlantCareRewardReconciliationCursorStore.cursor(defaults: defaults)
        var checkpointCallCount = 0
        let failingOptions = PlantCareRewardReconciliationOptions(
            sweepID: cursor.sweepID,
            persistCheckpoint: { _ in
                checkpointCallCount += 1
                return ModelContextSaveResult(
                    didSave: false,
                    errorDescription: "injectedRewardSweepCheckpointFailure"
                )
            }
        )

        let failed = PlantCareRewardReconciliationService.reconcile(
            context: context,
            economy: economy,
            maximumCount: 16,
            options: failingOptions
        )

        #expect(failed.inspectedCount == 1)
        #expect(failed.pendingCount == 1)
        #expect(failed.hasMoreWork)
        #expect(!failed.didCompleteSweep)
        #expect(!failed.checkpointPersisted)
        #expect(checkpointCallCount == 1)
        let cursorAfterFailure = PlantCareRewardReconciliationCursorStore.advance(
            checkpointPersisted: failed.checkpointPersisted,
            didCompleteSweep: failed.didCompleteSweep,
            defaults: defaults
        )
        #expect(cursorAfterFailure == cursor)
        #expect(PlantCareRewardReconciliationCursorStore.cursor(defaults: defaults) == cursor)
        let fetchedLedgerAfterFailure = try fetchLedger(id: fixture.failingLedgerIDs[0], context: context)
        let ledgerAfterFailure = try #require(fetchedLedgerAfterFailure)
        #expect(CareLedgerMetadata.stringValue(
            named: PlantCareRewardReconciliationService.sweepMetadataKey,
            in: ledgerAfterFailure.metadataJSON
        ) == nil)

        let retry = PlantCareRewardReconciliationService.reconcile(
            context: context,
            economy: economy,
            maximumCount: 16,
            sweepID: cursor.sweepID
        )

        #expect(retry.inspectedLedgerIDs == failed.inspectedLedgerIDs)
        #expect(retry.pendingCount == 1)
        #expect(!retry.hasMoreWork)
        #expect(retry.didCompleteSweep)
        #expect(retry.checkpointPersisted)
        let cursorAfterRetry = PlantCareRewardReconciliationCursorStore.advance(
            checkpointPersisted: retry.checkpointPersisted,
            didCompleteSweep: retry.didCompleteSweep,
            defaults: defaults
        )
        #expect(cursorAfterRetry.sweepID != cursor.sweepID)
        let fetchedLedgerAfterRetry = try fetchLedger(id: fixture.failingLedgerIDs[0], context: context)
        let ledgerAfterRetry = try #require(fetchedLedgerAfterRetry)
        #expect(CareLedgerMetadata.stringValue(
            named: PlantCareRewardReconciliationService.sweepMetadataKey,
            in: ledgerAfterRetry.metadataJSON
        ) == cursor.sweepID.uuidString)
    }

    private func runStartupBudget(
        context: ModelContext,
        economy: CareEventEconomyAwarding,
        sweepID: UUID,
        defaults: UserDefaults
    ) -> SweepBudgetResult {
        var inspectedLedgerIDs = Set<UUID>()
        var settledCount = 0
        var pendingCount = 0
        var hasMoreWork = false
        var didCompleteSweep = false
        var checkpointPersisted = true
        for _ in 0 ..< 4 {
            let result = PlantCareRewardReconciliationService.reconcile(
                context: context,
                economy: economy,
                maximumCount: 16,
                options: PlantCareRewardReconciliationOptions(
                    sweepID: sweepID,
                    defaults: defaults
                )
            )
            inspectedLedgerIDs.formUnion(result.inspectedLedgerIDs)
            settledCount += result.settledCount
            pendingCount += result.pendingCount
            hasMoreWork = result.hasMoreWork
            didCompleteSweep = result.didCompleteSweep
            checkpointPersisted = result.checkpointPersisted
            guard result.checkpointPersisted, result.hasMoreWork else { break }
        }
        return SweepBudgetResult(
            inspectedLedgerIDs: inspectedLedgerIDs,
            settledCount: settledCount,
            pendingCount: pendingCount,
            hasMoreWork: hasMoreWork,
            didCompleteSweep: didCompleteSweep,
            checkpointPersisted: checkpointPersisted
        )
    }

    private func makePendingFixture(
        failingCount: Int,
        includesSuccessfulTail: Bool
    ) throws -> PendingFixture {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let plant = Plant(name: "Reward Sweep Fern", wateringIntervalDays: 1)
        let baseDate = Date(timeIntervalSince1970: 1_786_252_400)
        context.insert(plant)
        var failingLedgerIDs: [UUID] = []
        var successfulOperationIDs = Set<UUID>()
        var successfulLedgerID: UUID?
        let totalCount = failingCount + (includesSuccessfulTail ? 1 : 0)

        for index in 0 ..< totalCount {
            let operationID = UUID()
            let date = baseDate.addingTimeInterval(Double(index))
            let log = PlantCareLog(
                date: date,
                careType: .watering,
                note: "pending reward \(index)",
                careTransactionId: operationID.uuidString
            )
            log.plant = plant
            context.insert(log)
            let event = Event(
                title: "Water Reward Sweep Fern",
                startDate: date,
                isAllDay: false,
                eventType: PlantCareType.watering.eventType.rawValue,
                relatedEntityType: EntityKind.plant.rawValue,
                relatedEntityId: plant.id.uuidString
            )
            context.insert(event)
            var metadata = CareLedgerMetadata.addingString(
                CareLedgerMetadata.careTransactionId,
                value: operationID.uuidString,
                to: ""
            )
            metadata = CareLedgerMetadata.addingString(
                PlantCareCommandService.rewardOperationDateMetadataKey,
                value: String(date.timeIntervalSince1970),
                to: metadata
            )
            metadata = CareLedgerMetadata.addingString(
                PlantCareCommandService.rewardStateMetadataKey,
                value: PlantCareCommandService.rewardStatePending,
                to: metadata
            )
            let ledger = CareLedgerEvent(
                occurredAt: date,
                subjectKind: .plant,
                subjectId: plant.id.uuidString,
                eventKind: .plantCare,
                actionType: PlantCareType.watering.rawValue,
                note: log.note,
                source: .detail,
                sourceEventId: event.id.uuidString,
                legacyModelName: String(describing: PlantCareLog.self),
                legacyModelId: log.id.uuidString,
                metadataJSON: metadata,
                createdAt: date
            )
            context.insert(ledger)
            if index < failingCount {
                failingLedgerIDs.append(ledger.id)
            } else {
                successfulOperationIDs.insert(operationID)
                successfulLedgerID = ledger.id
            }
        }
        try context.save()

        return PendingFixture(
            container: container,
            failingLedgerIDs: failingLedgerIDs,
            successfulOperationIDs: successfulOperationIDs,
            successfulLedgerID: successfulLedgerID
        )
    }

    private func fetchLedger(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in ledger.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func rewardState(of ledger: CareLedgerEvent) -> String? {
        CareLedgerMetadata.stringValue(
            named: PlantCareCommandService.rewardStateMetadataKey,
            in: ledger.metadataJSON
        )
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "PlantCareRewardSweepTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}

@MainActor
private struct PendingFixture {
    let container: ModelContainer
    let failingLedgerIDs: [UUID]
    let successfulOperationIDs: Set<UUID>
    let successfulLedgerID: UUID?
}

private struct SweepBudgetResult {
    let inspectedLedgerIDs: Set<UUID>
    let settledCount: Int
    let pendingCount: Int
    let hasMoreWork: Bool
    let didCompleteSweep: Bool
    let checkpointPersisted: Bool
}

@MainActor
private final class SelectiveRewardEconomy: CareEventEconomyAwarding {
    private let successfulOperationIDs: Set<UUID>

    init(successfulOperationIDs: Set<UUID>) {
        self.successfulOperationIDs = successfulOperationIDs
    }

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

    func awardIdempotentCareAction(
        type _: DomainCareRewardAction,
        pet _: Pet?,
        context _: ModelContext,
        quality _: DomainCareRewardQuality,
        date _: Date,
        executorId _: String?,
        careObjectKey _: UUID?,
        idempotencyKey _: String,
        idempotencyID: UUID
    ) -> (humanGot: Int, petGot: Int, didPersist: Bool) {
        successfulOperationIDs.contains(idempotencyID)
            ? (humanGot: 2, petGot: 0, didPersist: true)
            : (humanGot: 0, petGot: 0, didPersist: false)
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

    func rewardMetadata(for reward: (humanGot: Int, petGot: Int)?) -> String {
        guard let reward else { return "" }
        return "{\"humanCoconuts\":\(reward.humanGot),\"petCoconuts\":\(reward.petGot)}"
    }

    func recordFirstMeal(actorId _: String?, context _: ModelContext) {}
    func clearCooldown(petId _: UUID?, type _: DomainCareRewardAction) {}
    func refreshProjectionAfterRollback(context _: ModelContext) {}
}
