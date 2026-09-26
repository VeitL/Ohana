import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantBatchCareRewardAtomicityTests {
    @Test func coreSaveFailureRestoresEveryLivePlantSummaryAndWritesNoFacts() throws {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_786_291_200)
        let previousDate = now.addingTimeInterval(-2 * 86400)
        let first = Plant(name: "Rollback Fern", wateringIntervalDays: 1)
        let second = Plant(name: "Rollback Palm", wateringIntervalDays: 1)
        for plant in [first, second] {
            plant.createdAt = previousDate
            plant.lastWateredDate = previousDate
            context.insert(plant)
        }
        try context.save()

        let result = PlantBatchCareCommandService.completeDueCare(
            selections: [first, second].map {
                PlantBatchCareSelection(plantID: $0.id, careType: .watering)
            },
            context: context,
            executorId: nil,
            now: now,
            syncCarePlan: false,
            persistChanges: { _ in
                ModelContextSaveResult(
                    didSave: false,
                    errorDescription: "injectedBatchCoreSaveFailure"
                )
            }
        )

        #expect(!result.didPersist)
        #expect(!result.didWrite)
        #expect(result.persistenceErrorDescription == "injectedBatchCoreSaveFailure")
        #expect(first.lastWateredDate == previousDate)
        #expect(second.lastWateredDate == previousDate)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func rewardCommitRejectsBatchLogAndTargetTokenConflictsBeforeAnyAward() throws {
        for corruption in 0 ..< 3 {
            let fixture = try makeBatchFixture(plantCount: 2)
            let token = try #require(fixture.result.undoToken)
            var items = token.items
            let original = items[1]
            switch corruption {
            case 0:
                break
            case 1:
                items[1] = PlantBatchCareUndoItem(
                    plantID: original.plantID,
                    careType: original.careType,
                    logID: UUID(),
                    eventID: original.eventID,
                    ledgerEventID: original.ledgerEventID,
                    occurredAt: original.occurredAt,
                    wasRewardEligible: original.wasRewardEligible
                )
            default:
                items[1] = PlantBatchCareUndoItem(
                    plantID: UUID(),
                    careType: original.careType,
                    logID: original.logID,
                    eventID: original.eventID,
                    ledgerEventID: original.ledgerEventID,
                    occurredAt: original.occurredAt,
                    wasRewardEligible: original.wasRewardEligible
                )
            }
            let tampered = PlantBatchCareUndoToken(
                id: token.id,
                batchID: corruption == 0 ? UUID() : token.batchID,
                createdAt: token.createdAt,
                expiresAt: token.expiresAt,
                executorId: token.executorId,
                items: items,
                restorePoints: token.restorePoints
            )
            let economy = IdempotentBatchRewardSpy(reward: (humanGot: 5, petGot: 0))

            let result = PlantBatchCareCommandService.commitRewards(
                for: tampered,
                context: fixture.context,
                now: token.expiresAt.addingTimeInterval(1),
                economy: economy
            )

            #expect(!result.didPersist)
            #expect(!result.didCommit)
            #expect(result.persistenceErrorDescription == "plantBatchCareRewardTokenConflict")
            #expect(economy.idempotentCallCount == 0)
            #expect(economy.actualAwardCount == 0)
            #expect(try fetchLedgers(context: fixture.context).allSatisfy {
                rewardState(of: $0) == PlantCareCommandService.rewardStatePending
            })
        }
    }

    @Test func legacyPendingAndSettledRewardMetadataRemainCompatible() throws {
        do {
            let fixture = try makeBatchFixture(plantCount: 1)
            let token = try #require(fixture.result.undoToken)
            let ledger = try #require(fetchLedgers(context: fixture.context).first)
            ledger.metadataJSON = try metadataJSON(
                removing: [
                    CareLedgerMetadata.batchID,
                    PlantCareCommandService.rewardStateMetadataKey,
                    "generatedBy"
                ],
                from: ledger.metadataJSON
            )
            try fixture.context.save()
            let economy = IdempotentBatchRewardSpy(reward: (humanGot: 4, petGot: 0))

            let result = PlantBatchCareCommandService.commitRewards(
                for: token,
                context: fixture.context,
                now: token.expiresAt.addingTimeInterval(1),
                economy: economy
            )

            #expect(result.didPersist)
            #expect(result.didCommit)
            #expect(economy.actualAwardCount == 1)
        }

        do {
            let fixture = try makeBatchFixture(plantCount: 1)
            let token = try #require(fixture.result.undoToken)
            let firstEconomy = IdempotentBatchRewardSpy(reward: (humanGot: 4, petGot: 0))
            let first = PlantBatchCareCommandService.commitRewards(
                for: token,
                context: fixture.context,
                now: token.expiresAt.addingTimeInterval(1),
                economy: firstEconomy
            )
            #expect(first.didPersist)
            let ledger = try #require(fetchLedgers(context: fixture.context).first)
            ledger.metadataJSON = try metadataJSON(
                removing: [PlantCareCommandService.rewardStateMetadataKey],
                from: ledger.metadataJSON
            )
            try fixture.context.save()
            let retryEconomy = IdempotentBatchRewardSpy(reward: (humanGot: 4, petGot: 0))

            let replay = PlantBatchCareCommandService.commitRewards(
                for: token,
                context: fixture.context,
                now: token.expiresAt.addingTimeInterval(2),
                economy: retryEconomy
            )

            #expect(replay.didPersist)
            #expect(!replay.didCommit)
            #expect(retryEconomy.idempotentCallCount == 0)
            #expect(retryEconomy.actualAwardCount == 0)
        }
    }

    @Test func undoScheduleFailureRestoresLiveSummaryAndLeavesBatchFactsIntact() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let point = try #require(token.restorePoints.first)
        let plant = try #require(try fetchPlant(id: point.plantID, context: fixture.context))
        let liveLastWateredDate = plant.lastWateredDate

        let result = PlantBatchCareCommandService.undo(
            token,
            context: fixture.context,
            now: token.createdAt.addingTimeInterval(1),
            scheduleSync: { plant, _, _, _ in
                plant.lastWateredDate = .distantPast
                return .persistenceFailed(
                    plantID: plant.id,
                    errorDescription: "injectedUndoScheduleFailure"
                )
            }
        )

        #expect(!result.didPersist)
        #expect(!result.didUndo)
        #expect(result.persistenceErrorDescription == "injectedUndoScheduleFailure")
        #expect(plant.lastWateredDate == liveLastWateredDate)
        #expect(try fixture.context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
    }

    @Test func partialMissingUndoFailsClosedWithoutChangingRemainingFactsOrSummary() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let item = try #require(token.items.first)
        let plant = try #require(try fetchPlant(id: item.plantID, context: fixture.context))
        let liveLastWateredDate = plant.lastWateredDate
        let ledger = try #require(try fetchLedger(id: item.ledgerEventID, context: fixture.context))
        fixture.context.delete(ledger)
        try fixture.context.save()

        let result = PlantBatchCareCommandService.undo(
            token,
            context: fixture.context,
            now: token.createdAt.addingTimeInterval(1)
        )

        #expect(!result.didPersist)
        #expect(!result.didUndo)
        #expect(result.persistenceErrorDescription == "plantBatchCareUndoTokenConflict")
        #expect(plant.lastWateredDate == liveLastWateredDate)
        #expect(try fixture.context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func ledgerCheckpointFailureRetriesOneDurableRewardWithoutMintingTwice() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 5, petGot: 0))
        let first = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(1),
            economy: economy,
            persistChanges: { _ in
                ModelContextSaveResult(
                    didSave: false,
                    errorDescription: "injectedBatchRewardLedgerFailure"
                )
            }
        )

        #expect(!first.didPersist)
        #expect(!first.didCommit)
        #expect(economy.idempotentCallCount == 1)
        #expect(economy.actualAwardCount == 1)
        #expect(economy.rollbackRefreshCount == 1)
        let pendingLedger = try #require(fetchLedgers(context: fixture.context).first)
        #expect(rewardState(of: pendingLedger) == PlantCareCommandService.rewardStatePending)

        let retry = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(2),
            economy: economy
        )
        let settledLedger = try #require(fetchLedgers(context: fixture.context).first)

        #expect(retry.didPersist)
        #expect(retry.didCommit)
        #expect(retry.awardedCoconutDelta == 5)
        #expect(economy.idempotentCallCount == 2)
        #expect(economy.actualAwardCount == 1)
        #expect(rewardState(of: settledLedger) == PlantCareCommandService.rewardStateSettled)
        #expect(settledLedger.coconutDelta == 5)

        let replay = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(3),
            economy: economy
        )
        #expect(replay.didPersist)
        #expect(!replay.didCommit)
        #expect(economy.idempotentCallCount == 2)
        #expect(economy.actualAwardCount == 1)
    }

    @Test func legitimateZeroRewardSettlesExplicitlyAndDoesNotRetry() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 0, petGot: 0))

        let first = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(1),
            economy: economy
        )
        let second = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(2),
            economy: economy
        )
        let ledger = try #require(fetchLedgers(context: fixture.context).first)

        #expect(first.didPersist)
        #expect(first.didCommit)
        #expect(first.awardedCoconutDelta == 0)
        #expect(second.didPersist)
        #expect(!second.didCommit)
        #expect(economy.idempotentCallCount == 1)
        #expect(economy.actualAwardCount == 1)
        #expect(ledger.coconutDelta == 0)
        #expect(rewardState(of: ledger) == PlantCareCommandService.rewardStateSettled)
    }

    @Test func rewardSettlementCannotRunBeforeUndoWindowAndFactsRemainUndoable() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 4, petGot: 0))

        let early = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.createdAt.addingTimeInterval(1),
            economy: economy
        )
        let ledgerBeforeUndo = try #require(fetchLedgers(context: fixture.context).first)

        #expect(!early.didPersist)
        #expect(!early.didCommit)
        #expect(early.persistenceErrorDescription == "plantBatchCareUndoWindowActive")
        #expect(economy.idempotentCallCount == 0)
        #expect(rewardState(of: ledgerBeforeUndo) == PlantCareCommandService.rewardStatePending)

        let undo = PlantBatchCareCommandService.undo(
            token,
            context: fixture.context,
            now: token.createdAt.addingTimeInterval(2)
        )
        #expect(undo.didPersist)
        #expect(undo.didUndo)
        #expect(try fixture.context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func multiItemCheckpointFailureKeepsPriorItemDurableAndRetryDoesNotMintAgain() throws {
        let fixture = try makeBatchFixture(plantCount: 2)
        let token = try #require(fixture.result.undoToken)
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 3, petGot: 0))
        var checkpointCount = 0

        let first = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(1),
            economy: economy,
            persistChanges: { context in
                checkpointCount += 1
                if checkpointCount == 2 {
                    return ModelContextSaveResult(
                        didSave: false,
                        errorDescription: "injectedSecondItemCheckpointFailure"
                    )
                }
                return context.safeSaveResult(publishFailureEvent: true)
            }
        )
        let statesAfterFailure = try fetchLedgers(context: fixture.context)
            .compactMap { rewardState(of: $0) }

        #expect(!first.didPersist)
        #expect(first.didCommit)
        #expect(first.ledgerEventIDs.count == 1)
        #expect(statesAfterFailure.count(where: { $0 == PlantCareCommandService.rewardStateSettled }) == 1)
        #expect(statesAfterFailure.count(where: { $0 == PlantCareCommandService.rewardStatePending }) == 1)
        #expect(economy.idempotentCallCount == 2)
        #expect(economy.actualAwardCount == 2)

        let retry = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: fixture.context,
            now: token.expiresAt.addingTimeInterval(2),
            economy: economy
        )
        let statesAfterRetry = try fetchLedgers(context: fixture.context)
            .compactMap { rewardState(of: $0) }

        #expect(retry.didPersist)
        #expect(retry.didCommit)
        #expect(statesAfterRetry.allSatisfy { $0 == PlantCareCommandService.rewardStateSettled })
        #expect(economy.idempotentCallCount == 3)
        #expect(economy.actualAwardCount == 2)
    }

    @Test func realAwarderRetryAfterLedgerCheckpointFailureDoesNotDuplicateDurableEffects() throws {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_786_291_200)
        let previousDate = now.addingTimeInterval(-2 * 86400)
        let human = Human(name: "Batch Reward Keeper")
        let plant = Plant(name: "Exact Once Fern", wateringIntervalDays: 1)
        plant.createdAt = previousDate
        plant.lastWateredDate = previousDate
        let critter = OasisElectronicPet(
            catalogId: OasisUpgradeRewardCatalog.firstCritterId,
            nameZh: "椰灵",
            nameEn: "Coco",
            nameDe: "Coco",
            emoji: "🥥",
            rarity: .rare,
            xp: 0,
            health: 50,
            bond: 0,
            isFeaturedOnOasis: true,
            sourceLevel: 10
        )
        context.insert(human)
        context.insert(plant)
        context.insert(critter)
        try context.save()

        let restoreDefaults = isolateRealEconomyDefaults(
            memberKey: human.id.uuidString,
            plantID: plant.id,
            date: now
        )
        defer { restoreDefaults() }

        let batch = PlantBatchCareCommandService.completeDueCare(
            selections: [PlantBatchCareSelection(plantID: plant.id, careType: .watering)],
            context: context,
            executorId: human.id.uuidString,
            now: now,
            syncCarePlan: false,
            operationID: UUID()
        )
        let token = try #require(batch.undoToken)
        let ledgerID = try #require(token.items.first?.ledgerEventID)
        let idempotencyKey = "plantBatchCareReward:\(token.batchID.uuidString):\(ledgerID.uuidString)"
        let firstAwarder = StaticCareEventEconomyAwarder(questManager: QuestManager())

        let first = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: context,
            now: token.expiresAt.addingTimeInterval(1),
            economy: firstAwarder,
            persistChanges: { _ in
                ModelContextSaveResult(
                    didSave: false,
                    errorDescription: "injectedRealLedgerCheckpointFailure"
                )
            }
        )

        let pendingLedger = try #require(fetchLedgers(context: context).first { $0.id == ledgerID })
        let walletAfterFailure = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter {
            $0.sourceModelName == QuestManager.careActionFinalizationSourceModelName &&
                $0.sourceModelId == idempotencyKey
        }
        let budgetAfterFailure = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).filter {
            CareLedgerMetadata.stringValue(
                named: "careActionIdempotencyKey",
                in: $0.metadataJSON
            ) == idempotencyKey
        }
        let oasisAfterFailure = try context.fetch(FetchDescriptor<OasisCritterActionLog>()).filter {
            $0.id == ledgerID && $0.action == .careEcho
        }
        let critterStateAfterFailure = [critter.xp, critter.bond, critter.mood, critter.health]

        #expect(!first.didPersist)
        #expect(!first.didCommit)
        #expect(first.persistenceErrorDescription == "injectedRealLedgerCheckpointFailure")
        #expect(rewardState(of: pendingLedger) == PlantCareCommandService.rewardStatePending)
        #expect(walletAfterFailure.count == 1)
        let walletReceipt = try #require(walletAfterFailure.first)
        #expect(walletReceipt.delta > 0)
        #expect(budgetAfterFailure.count == 3)
        #expect(Set(budgetAfterFailure.map(\.scopeRaw)) == Set([
            EconomyBudgetUsageScope.household.rawValue,
            EconomyBudgetUsageScope.member.rawValue,
            EconomyBudgetUsageScope.careObject.rawValue
        ]))
        #expect(oasisAfterFailure.count == 1)

        let retryAwarder = StaticCareEventEconomyAwarder(questManager: QuestManager())
        let retry = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: context,
            now: token.expiresAt.addingTimeInterval(2),
            economy: retryAwarder
        )

        let settledLedger = try #require(fetchLedgers(context: context).first { $0.id == ledgerID })
        let walletAfterRetry = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter {
            $0.sourceModelName == QuestManager.careActionFinalizationSourceModelName &&
                $0.sourceModelId == idempotencyKey
        }
        let budgetAfterRetry = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).filter {
            CareLedgerMetadata.stringValue(
                named: "careActionIdempotencyKey",
                in: $0.metadataJSON
            ) == idempotencyKey
        }
        let oasisAfterRetry = try context.fetch(FetchDescriptor<OasisCritterActionLog>()).filter {
            $0.id == ledgerID && $0.action == .careEcho
        }

        #expect(retry.didPersist)
        #expect(retry.didCommit)
        #expect(retry.awardedCoconutDelta == walletReceipt.delta)
        #expect(retry.walletEntryIDs == walletAfterFailure.map(\.id))
        #expect(Set(retry.budgetUsageIDs) == Set(budgetAfterFailure.map(\.id)))
        #expect(rewardState(of: settledLedger) == PlantCareCommandService.rewardStateSettled)
        #expect(settledLedger.coconutDelta == walletReceipt.delta)
        #expect(walletAfterRetry.map(\.id) == walletAfterFailure.map(\.id))
        #expect(Set(budgetAfterRetry.map(\.id)) == Set(budgetAfterFailure.map(\.id)))
        #expect(oasisAfterRetry.map(\.id) == oasisAfterFailure.map(\.id))
        #expect([critter.xp, critter.bond, critter.mood, critter.health] == critterStateAfterFailure)
    }

    @Test func startupReconciliationSettlesEveryPendingBatchLedgerWithoutTokenStore() throws {
        let fixture = try makeBatchFixture(plantCount: 2)
        let token = try #require(fixture.result.undoToken)
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 2, petGot: 0))
        let result = PlantCareRewardReconciliationService.reconcile(
            context: fixture.context,
            economy: economy,
            maximumCount: 8,
            options: PlantCareRewardReconciliationOptions(
                sweepID: UUID(),
                now: token.createdAt.addingTimeInterval(1)
            )
        )
        let ledgers = try fetchLedgers(context: fixture.context)

        #expect(result.inspectedCount == 2)
        #expect(result.settledCount == 2)
        #expect(result.pendingCount == 0)
        #expect(result.didCompleteSweep)
        #expect(result.checkpointPersisted)
        #expect(economy.actualAwardCount == 2)
        #expect(ledgers.count == 2)
        #expect(ledgers.allSatisfy {
            rewardState(of: $0) == PlantCareCommandService.rewardStateSettled
        })
    }

    @Test func startupReconciliationSettlesPendingBatchWithNilSourceEventLink() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let ledger = try #require(fetchLedgers(context: fixture.context).first)
        ledger.sourceEventId = nil
        try fixture.context.save()
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 2, petGot: 0))
        let suiteName = "plant.batch.nil.source.recovery.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let result = PlantCareRewardReconciliationService.reconcile(
            context: fixture.context,
            economy: economy,
            maximumCount: 8,
            options: PlantCareRewardReconciliationOptions(
                sweepID: UUID(),
                now: token.expiresAt.addingTimeInterval(1),
                defaults: defaults
            )
        )

        #expect(result.settledCount == 1)
        #expect(result.pendingCount == 0)
        #expect(economy.actualAwardCount == 1)
        #expect(rewardState(of: ledger) == PlantCareCommandService.rewardStateSettled)
    }

    @Test func startupReconciliationDoesNotBypassAnActiveUndoWindow() throws {
        let fixture = try makeBatchFixture(plantCount: 1)
        let token = try #require(fixture.result.undoToken)
        let economy = IdempotentBatchRewardSpy(reward: (humanGot: 2, petGot: 0))
        let suiteName = "plant.batch.undo.window.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        PlantBatchCarePendingRewardStore.upsert(token, defaults: defaults)

        let result = PlantCareRewardReconciliationService.reconcile(
            context: fixture.context,
            economy: economy,
            maximumCount: 8,
            options: PlantCareRewardReconciliationOptions(
                sweepID: UUID(),
                now: token.createdAt.addingTimeInterval(1),
                defaults: defaults
            )
        )
        let ledger = try #require(fetchLedgers(context: fixture.context).first)

        #expect(result.inspectedCount == 1)
        #expect(result.settledCount == 0)
        #expect(result.pendingCount == 1)
        #expect(economy.actualAwardCount == 0)
        #expect(rewardState(of: ledger) == PlantCareCommandService.rewardStatePending)

        PlantBatchCarePendingRewardStore.remove(batchID: token.batchID, defaults: defaults)
        let afterUndoHandleExpires = PlantCareRewardReconciliationService.reconcile(
            context: fixture.context,
            economy: economy,
            maximumCount: 8,
            options: PlantCareRewardReconciliationOptions(
                sweepID: UUID(),
                now: token.expiresAt.addingTimeInterval(1),
                defaults: defaults
            )
        )
        let settledLedger = try #require(fetchLedgers(context: fixture.context).first)
        #expect(afterUndoHandleExpires.settledCount == 1)
        #expect(afterUndoHandleExpires.pendingCount == 0)
        #expect(economy.actualAwardCount == 1)
        #expect(rewardState(of: settledLedger) == PlantCareCommandService.rewardStateSettled)
    }

    private func makeBatchFixture(plantCount: Int) throws -> BatchFixture {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_786_291_200)
        let previousDate = now.addingTimeInterval(-2 * 86400)
        let plants = (0 ..< plantCount).map { index -> Plant in
            let plant = Plant(name: "Batch Reward Fern \(index)", wateringIntervalDays: 1)
            plant.createdAt = previousDate
            plant.lastWateredDate = previousDate
            context.insert(plant)
            return plant
        }
        try context.save()
        let result = PlantBatchCareCommandService.completeDueCare(
            selections: plants.map {
                PlantBatchCareSelection(plantID: $0.id, careType: .watering)
            },
            context: context,
            executorId: nil,
            now: now,
            syncCarePlan: false
        )
        #expect(result.didPersist)
        #expect(result.completedCount == plantCount)
        #expect(try fetchLedgers(context: context).allSatisfy {
            rewardState(of: $0) == PlantCareCommandService.rewardStatePending
        })
        return BatchFixture(container: container, context: context, result: result)
    }

    private func fetchLedgers(context: ModelContext) throws -> [CareLedgerEvent] {
        try context.fetch(FetchDescriptor<CareLedgerEvent>())
    }

    private func fetchLedger(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPlant(id: UUID, context: ModelContext) throws -> Plant? {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func metadataJSON(removing keys: [String], from raw: String) throws -> String {
        var metadata = CalendarTaskCompletionSyncService.metadataDictionary(from: raw)
        for key in keys {
            metadata.removeValue(forKey: key)
        }
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
        return try #require(String(data: data, encoding: .utf8))
    }

    private func rewardState(of ledger: CareLedgerEvent) -> String? {
        CareLedgerMetadata.stringValue(
            named: PlantCareCommandService.rewardStateMetadataKey,
            in: ledger.metadataJSON
        )
    }

    private func isolateRealEconomyDefaults(
        memberKey: String,
        plantID: UUID,
        date: Date
    ) -> () -> Void {
        let defaults = UserDefaults.standard
        let scalarKeys = [
            "currentActiveHumanId",
            QuestManager.Keys.cooldownLogs,
            ShopInventoryDefaultsKeys.doubleRewardBoost,
            ShopInventoryDefaultsKeys.durableStateV2
        ]
        let originalScalarValues = Dictionary(uniqueKeysWithValues: scalarKeys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })
        let budgetPrefix = "economyV2.dailyBudget."
        let originalBudgetValues = defaults.dictionaryRepresentation().filter {
            $0.key.hasPrefix(budgetPrefix)
        }
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey()
        let careObjectKeys = ["plant.\(plantID.uuidString)"]

        defaults.set(memberKey, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
        defaults.removeObject(forKey: ShopInventoryDefaultsKeys.durableStateV2)
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: careObjectKeys,
            date: date
        )

        return {
            EconomyDailyBudgetStore.reset(
                householdKey: householdKey,
                memberKey: memberKey,
                careObjectKeys: careObjectKeys,
                date: date
            )
            for (key, value) in originalBudgetValues {
                defaults.set(value, forKey: key)
            }
            for key in scalarKeys {
                if let value = originalScalarValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }
}

@MainActor
private struct BatchFixture {
    let container: ModelContainer
    let context: ModelContext
    let result: PlantBatchCareCommandResult
}

@MainActor
private final class IdempotentBatchRewardSpy: CareEventEconomyAwarding {
    let reward: (humanGot: Int, petGot: Int)
    private var receipts: [UUID: (humanGot: Int, petGot: Int)] = [:]
    private(set) var idempotentCallCount = 0
    private(set) var actualAwardCount = 0
    private(set) var rollbackRefreshCount = 0

    init(reward: (humanGot: Int, petGot: Int)) {
        self.reward = reward
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
        idempotentCallCount += 1
        if let receipt = receipts[idempotencyID] {
            return (receipt.humanGot, receipt.petGot, true)
        }
        receipts[idempotencyID] = reward
        actualAwardCount += 1
        return (reward.humanGot, reward.petGot, true)
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
    func refreshProjectionAfterRollback(context _: ModelContext) {
        rollbackRefreshCount += 1
    }
}
