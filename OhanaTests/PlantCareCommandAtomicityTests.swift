import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PlantCareCommandAtomicityTests {
    @Test func replayingTheSameOperationWritesOneFactSetAndOneRevision() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 9)
        let previousCareDate = now.addingTimeInterval(-2 * 86400)
        let plant = duePlant(name: "Replay Fern", previousCareDate: previousCareDate)
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let operationID = UUID()
        var request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: nil,
            now: now,
            careNote: "stable payload",
            operationID: operationID
        )
        request.photoData = nil
        let saveCounter = SaveCounter()
        let options = commandOptions(
            syncCarePlan: false,
            awardRewards: false,
            saveCounter: saveCounter
        )
        let executor = PlantCareCommandExecutor(
            context: context,
            revisionCenter: revisionCenter
        )
        let revisionBeforeFirstAttempt = revisionCenter.homeRevision.value

        let first = executor.recordCare(
            request,
            note: "test.plant.atomicity.replay",
            options: options
        )
        let revisionAfterFirstAttempt = revisionCenter.homeRevision.value
        let replay = executor.recordCare(
            request,
            note: "test.plant.atomicity.replay",
            options: options
        )

        let logs = try context.fetch(FetchDescriptor<PlantCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(first.didPersist)
        #expect(first.didWrite)
        #expect(!first.wasReplay)
        #expect(replay.didPersist)
        #expect(!replay.didWrite)
        #expect(replay.wasReplay)
        #expect(replay.logID == first.logID)
        #expect(replay.eventID == first.eventID)
        #expect(replay.ledgerEventID == first.ledgerEventID)
        #expect(logs.count == 1)
        #expect(logs.first?.careTransactionId == operationID.uuidString)
        #expect(events.count == 1)
        #expect(ledgerEvents.count == 1)
        #expect(saveCounter.callCount == 1)
        #expect(revisionAfterFirstAttempt == revisionBeforeFirstAttempt + 1)
        #expect(revisionCenter.homeRevision.value == revisionAfterFirstAttempt)
    }

    @Test func reusingAnOperationIDWithDifferentPayloadIsRejected() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 10)
        let plant = duePlant(
            name: "Conflict Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let operationID = UUID()
        let request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: nil,
            now: now,
            careNote: "original payload",
            operationID: operationID
        )
        var conflictingRequest = request
        conflictingRequest.careNote = "changed payload"
        let saveCounter = SaveCounter()
        let options = commandOptions(
            syncCarePlan: false,
            awardRewards: false,
            saveCounter: saveCounter
        )
        let executor = PlantCareCommandExecutor(
            context: context,
            revisionCenter: revisionCenter
        )

        let first = executor.recordCare(
            request,
            note: "test.plant.atomicity.conflict",
            options: options
        )
        let revisionAfterFirstAttempt = revisionCenter.homeRevision.value
        let conflict = executor.recordCare(
            conflictingRequest,
            note: "test.plant.atomicity.conflict",
            options: options
        )

        #expect(first.didPersist)
        #expect(first.didWrite)
        #expect(!conflict.didPersist)
        #expect(!conflict.didWrite)
        #expect(!conflict.wasReplay)
        #expect(conflict.persistenceError == "plantCareOperationConflict")
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(saveCounter.callCount == 1)
        #expect(revisionCenter.homeRevision.value == revisionAfterFirstAttempt)
    }

    @Test func reusingAnOperationIDWithDifferentCanonicalExecutorIsRejected() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 10)
        let plant = duePlant(
            name: "Executor Conflict Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let originalExecutor = Human(name: "Original Keeper")
        let conflictingExecutor = Human(name: "Other Keeper")
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        context.insert(originalExecutor)
        context.insert(conflictingExecutor)
        try context.save()

        let operationID = UUID()
        let rewardOperationDate = now.addingTimeInterval(30)
        let request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: originalExecutor.id.uuidString,
            now: now,
            careNote: "same fact payload",
            operationID: operationID,
            rewardOperationDate: rewardOperationDate
        )
        let conflictingRequest = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: conflictingExecutor.id.uuidString.lowercased(),
            now: now,
            careNote: "same fact payload",
            operationID: operationID,
            rewardOperationDate: rewardOperationDate
        )
        let saveCounter = SaveCounter()
        let options = commandOptions(
            syncCarePlan: false,
            awardRewards: false,
            saveCounter: saveCounter
        )

        let first = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options
        )
        let conflict = PlantCareCommandService.recordCare(
            conflictingRequest,
            context: context,
            options: options
        )

        #expect(first.didPersist)
        #expect(first.didWrite)
        #expect(!conflict.didPersist)
        #expect(!conflict.didWrite)
        #expect(!conflict.wasReplay)
        #expect(conflict.persistenceError == "plantCareOperationConflict")
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(saveCounter.callCount == 1)
    }

    @Test func replayWithDuplicateLinkedLedgerIsIncomplete() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 10)
        let plant = duePlant(
            name: "Duplicate Ledger Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: nil,
            now: now,
            careNote: "stable payload",
            operationID: UUID(),
            rewardOperationDate: now
        )
        let saveCounter = SaveCounter()
        let options = commandOptions(
            syncCarePlan: false,
            awardRewards: false,
            saveCounter: saveCounter
        )
        let first = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options
        )
        #expect(first.didPersist)

        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            source: .detail,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: first.logID.uuidString
        ))
        try context.save()

        let replay = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options
        )

        #expect(!replay.didPersist)
        #expect(!replay.didWrite)
        #expect(!replay.wasReplay)
        #expect(replay.persistenceError == "plantCareOperationIncomplete")
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 2)
        #expect(saveCounter.callCount == 1)
    }

    @Test func replayWithMissingSourceEventIsIncomplete() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 10)
        let plant = duePlant(
            name: "Missing Event Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: nil,
            now: now,
            careNote: "stable payload",
            operationID: UUID(),
            rewardOperationDate: now
        )
        let saveCounter = SaveCounter()
        let options = commandOptions(
            syncCarePlan: false,
            awardRewards: false,
            saveCounter: saveCounter
        )
        let first = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options
        )
        let sourceEvent = try #require(
            try context.fetch(FetchDescriptor<Event>()).first { $0.id == first.eventID }
        )
        context.delete(sourceEvent)
        try context.save()

        let replay = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options
        )

        #expect(first.didPersist)
        #expect(!replay.didPersist)
        #expect(!replay.didWrite)
        #expect(!replay.wasReplay)
        #expect(replay.persistenceError == "plantCareOperationIncomplete")
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
        #expect(saveCounter.callCount == 1)
    }

    @Test func failedCorePersistenceRollsBackCareFactLogEventLedgerAndPlan() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 11)
        let previousCareDate = now.addingTimeInterval(-2 * 86400)
        let plant = duePlant(name: "Rollback Fern", previousCareDate: previousCareDate)
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        configureOnlyWateringPlan(for: plant.id)
        context.insert(plant)
        try context.save()

        let economy = FlakyIdempotentEconomyAwarder()
        let saveCounter = SaveCounter()
        var stagedCounts: CareWriteCounts?
        var options = PlantCareCommandOptions(
            economy: economy,
            syncCarePlan: true,
            scheduleNotifications: false,
            awardRewards: true
        )
        options.persistChanges = { stagedContext in
            saveCounter.callCount += 1
            let stagedEvents = (try? stagedContext.fetch(FetchDescriptor<Event>())) ?? []
            stagedCounts = CareWriteCounts(
                logs: (try? stagedContext.fetch(FetchDescriptor<PlantCareLog>()).count) ?? -1,
                factEvents: stagedEvents.count(where: { !$0.isAllDay }),
                planEvents: stagedEvents.filter(\.isAllDay).count,
                ledgerEvents: (try? stagedContext.fetch(FetchDescriptor<CareLedgerEvent>()).count) ?? -1
            )
            return ModelContextSaveResult(
                didSave: false,
                errorDescription: "forcedCorePersistenceFailure"
            )
        }

        let result = PlantCareCommandService.recordCare(
            PlantCareCommandRequest(
                careType: .watering,
                plant: plant,
                executorID: nil,
                now: now,
                operationID: UUID()
            ),
            context: context,
            options: options
        )

        #expect(stagedCounts?.logs == 1)
        #expect(stagedCounts?.factEvents == 1)
        #expect(stagedCounts?.planEvents == 1)
        #expect(stagedCounts?.ledgerEvents == 1)
        #expect(!result.didPersist)
        #expect(!result.didWrite)
        #expect(result.persistenceError == "forcedCorePersistenceFailure")
        #expect(plant.lastWateredDate == previousCareDate)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(!context.hasChanges)
        #expect(saveCounter.callCount == 1)
        #expect(economy.idempotentCalls.isEmpty)
        #expect(standardPlanKeys(for: plant.id).isEmpty)
    }

    @Test func planSyncAndCareFactsCommitWithOneSaveWhenRewardsAreDisabled() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 12)
        let plant = duePlant(
            name: "Single Save Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        configureOnlyWateringPlan(for: plant.id)
        context.insert(plant)
        try context.save()

        let saveCounter = SaveCounter()
        let result = PlantCareCommandService.recordCare(
            PlantCareCommandRequest(
                careType: .watering,
                plant: plant,
                executorID: nil,
                now: now,
                operationID: UUID()
            ),
            context: context,
            options: commandOptions(
                syncCarePlan: true,
                awardRewards: false,
                saveCounter: saveCounter
            )
        )

        let counts = careWriteCounts(in: context)
        let events = try context.fetch(FetchDescriptor<Event>())
        let planEventCandidate = events.first { event in
            event.isAllDay
        }
        let planEvent = try #require(planEventCandidate)
        #expect(result.didPersist)
        #expect(result.didWrite)
        #expect(result.persistenceError == nil)
        #expect(counts.logs == 1)
        #expect(counts.factEvents == 1)
        #expect(counts.planEvents == 1)
        #expect(counts.ledgerEvents == 1)
        #expect(saveCounter.callCount == 1)
        #expect(UserDefaults.standard.string(forKey: planStorageKey(
            plantID: plant.id,
            careType: .watering
        )) == planEvent.id.uuidString)
    }

    @Test func replayCompletesPendingIdempotentRewardWithoutRepeatingFacts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 13)
        let plant = duePlant(
            name: "Reward Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let operationID = UUID()
        let request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: nil,
            now: now,
            careNote: "reward retry",
            operationID: operationID
        )
        let economy = FlakyIdempotentEconomyAwarder()
        let saveCounter = SaveCounter()
        var options = commandOptions(
            syncCarePlan: false,
            awardRewards: true,
            saveCounter: saveCounter
        )
        options.economy = economy
        let executor = PlantCareCommandExecutor(
            context: context,
            revisionCenter: revisionCenter
        )
        let revisionBeforeFirstAttempt = revisionCenter.homeRevision.value

        let first = executor.recordCare(
            request,
            note: "test.plant.atomicity.reward",
            options: options
        )
        let revisionAfterFirstAttempt = revisionCenter.homeRevision.value
        let countsAfterFirstAttempt = careWriteCounts(in: context)
        let replay = executor.recordCare(
            request,
            note: "test.plant.atomicity.reward",
            options: options
        )

        let countsAfterReplay = careWriteCounts(in: context)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(first.didPersist)
        #expect(first.didWrite)
        #expect(!first.wasReplay)
        #expect(first.rewardFinalizationPending)
        #expect(first.persistenceError == "plantCareRewardFinalizationPending")
        #expect(first.coconutDelta == 0)
        #expect(replay.didPersist)
        #expect(!replay.didWrite)
        #expect(replay.wasReplay)
        #expect(!replay.rewardFinalizationPending)
        #expect(replay.persistenceError == nil)
        #expect(replay.coconutDelta == 3)
        #expect(countsAfterFirstAttempt == CareWriteCounts(
            logs: 1,
            factEvents: 1,
            planEvents: 0,
            ledgerEvents: 1
        ))
        #expect(countsAfterReplay == countsAfterFirstAttempt)
        #expect(ledger.coconutDelta == 3)
        #expect(CareLedgerMetadata.stringValue(
            named: PlantCareCommandService.rewardStateMetadataKey,
            in: ledger.metadataJSON
        ) == "settled")
        #expect(saveCounter.callCount == 2)
        #expect(economy.idempotentCalls.count == 2)
        #expect(economy.idempotentCalls.allSatisfy {
            $0.key == "plantCareReward:\(operationID.uuidString)" &&
                $0.id == operationID &&
                $0.careObjectKey == plant.id
        })
        #expect(revisionAfterFirstAttempt == revisionBeforeFirstAttempt + 1)
        #expect(revisionCenter.homeRevision.value == revisionAfterFirstAttempt)
    }

    @Test func boundedStartupReconciliationSettlesCommittedPendingReward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 14)
        let plant = duePlant(
            name: "Recovery Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let economy = FlakyIdempotentEconomyAwarder()
        let rewardOperationDate = now.addingTimeInterval(2 * 86400)
        let request = PlantCareCommandRequest(
            careType: .watering,
            plant: plant,
            executorID: nil,
            now: now,
            careNote: "recover after launch",
            operationID: UUID(),
            rewardOperationDate: rewardOperationDate
        )
        let first = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: PlantCareCommandOptions(
                economy: economy,
                syncCarePlan: false,
                scheduleNotifications: false
            )
        )

        let recovery = PlantCareRewardReconciliationService.reconcile(
            context: context,
            economy: economy,
            maximumCount: 8
        )
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(first.didPersist)
        #expect(first.rewardFinalizationPending)
        #expect(recovery.inspectedCount == 1)
        #expect(recovery.settledCount == 1)
        #expect(recovery.pendingCount == 0)
        #expect(recovery.skippedCount == 0)
        #expect(!recovery.hasMoreWork)
        #expect(ledger.coconutDelta == 3)
        #expect(CareLedgerMetadata.stringValue(
            named: PlantCareCommandService.rewardStateMetadataKey,
            in: ledger.metadataJSON
        ) == "settled")
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(economy.idempotentCalls.count == 2)
        #expect(economy.idempotentCalls.allSatisfy { $0.date == rewardOperationDate })
        #expect(ledger.occurredAt == now)
        #expect(PlantCareCommandService.rewardOperationDate(in: ledger, fallback: .distantPast) == rewardOperationDate)
    }

    @Test func reconciliationQuarantinesInvalidPrefixAndContinuesToValidPendingFact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let factDate = makeDate(year: 2026, month: 8, day: 1, hour: 8)
        let plant = duePlant(
            name: "Queued Reward Fern",
            previousCareDate: factDate.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()

        let economy = FlakyIdempotentEconomyAwarder()
        let pending = PlantCareCommandService.recordCare(
            PlantCareCommandRequest(
                careType: .watering,
                plant: plant,
                executorID: nil,
                now: factDate,
                operationID: UUID(),
                rewardOperationDate: factDate.addingTimeInterval(86400)
            ),
            context: context,
            options: PlantCareCommandOptions(
                economy: economy,
                syncCarePlan: false,
                scheduleNotifications: false
            )
        )
        #expect(pending.rewardFinalizationPending)
        let pendingLedger = try #require(
            try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
                $0.id == pending.ledgerEventID
            }
        )

        let pendingMetadata = CareLedgerMetadata.addingString(
            PlantCareCommandService.rewardStateMetadataKey,
            value: PlantCareCommandService.rewardStatePending,
            to: ""
        )
        // Reconciliation is oldest-first. Keep this invalid queue strictly
        // ahead of the real pending fact so the test exercises prefix
        // quarantine instead of settling the valid fact in the first page.
        let createdBase = pendingLedger.createdAt.addingTimeInterval(-3600)
        for index in 0 ..< 17 {
            context.insert(CareLedgerEvent(
                occurredAt: factDate,
                subjectKind: .plant,
                subjectId: plant.id.uuidString,
                eventKind: .plantCare,
                actionType: PlantCareType.watering.rawValue,
                source: .service,
                legacyModelName: String(describing: PlantCareLog.self),
                legacyModelId: "invalid-log-\(index)",
                metadataJSON: pendingMetadata,
                createdAt: createdBase.addingTimeInterval(Double(index))
            ))
        }
        try context.save()

        let first = PlantCareRewardReconciliationService.reconcile(
            context: context,
            economy: economy,
            maximumCount: 16
        )
        let second = PlantCareRewardReconciliationService.reconcile(
            context: context,
            economy: economy,
            maximumCount: 16,
            excludingLedgerIDs: first.inspectedLedgerIDs
        )
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let invalidCount = ledgers.count { ledger in
            CareLedgerMetadata.stringValue(
                named: PlantCareCommandService.rewardStateMetadataKey,
                in: ledger.metadataJSON
            ) == PlantCareCommandService.rewardStateInvalid
        }

        #expect(first.inspectedCount == 16)
        #expect(first.skippedCount == 16)
        #expect(first.hasMoreWork)
        #expect(second.inspectedCount == 2)
        #expect(second.skippedCount == 1)
        #expect(second.settledCount == 1)
        #expect(!second.hasMoreWork)
        #expect(invalidCount == 17)
        #expect(economy.idempotentCalls.count == 2)
    }

    @Test func legacyEconomyConformerCannotFailOpenAnIdempotentSettlement() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = makeDate(year: 2026, month: 8, day: 9, hour: 15)
        let plant = duePlant(
            name: "Fail Closed Fern",
            previousCareDate: now.addingTimeInterval(-2 * 86400)
        )
        let restoreDefaults = isolateStandardPlantDefaults(for: plant.id)
        defer { restoreDefaults() }
        context.insert(plant)
        try context.save()
        let legacyEconomy = LegacyOnlyEconomyAwarder()

        let result = PlantCareCommandService.recordCare(
            PlantCareCommandRequest(
                careType: .watering,
                plant: plant,
                executorID: nil,
                now: now,
                rewardOperationDate: now
            ),
            context: context,
            options: PlantCareCommandOptions(
                economy: legacyEconomy,
                syncCarePlan: false,
                scheduleNotifications: false
            )
        )

        #expect(result.didPersist)
        #expect(result.didWrite)
        #expect(result.rewardFinalizationPending)
        #expect(legacyEconomy.legacyAwardCallCount == 0)
    }

    @Test func durableRewardReceiptRepairsCooldownWithoutMovingItBackward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let manager = QuestManager()
        let plantID = UUID()
        let idempotencyKey = "plantCareReward:\(UUID().uuidString)"
        let operationDate = Date()
        let defaults = UserDefaults.standard
        let previousCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defer {
            if let previousCooldownLogs {
                defaults.set(previousCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
        }

        let metadata = """
        {"actionKey":"plantWatering","budgetMultiplier":1,"budgetStage":"normal","consumesBoost":false,"cooldown":false,"coconutBase":2,"coconutBonus":0,"growthXP":1,"humanCoconuts":2,"luck":"none","luckyCoconuts":0,"petCoconuts":0,"reason":"test"}
        """
        context.insert(CoconutLedgerEntry(
            transactionKey: "\(idempotencyKey):marker",
            accountKey: CoconutAccountKey.islandReserve,
            ownerKind: .system,
            ownerId: "island",
            ownerName: "Island",
            delta: 0,
            balanceBefore: 0,
            balanceAfter: 0,
            affectsBalance: false,
            entryKind: .legacyHistory,
            source: .careEvent,
            title: "Plant care receipt",
            emoji: "🧾",
            sourceModelName: "CareActionFinalization",
            sourceModelId: idempotencyKey,
            metadataJSON: metadata,
            occurredAt: operationDate
        ))
        try context.save()

        _ = manager.awardAction(
            type: .plantWatering,
            pet: nil,
            context: context,
            date: operationDate,
            careObjectKey: plantID,
            idempotencyKey: idempotencyKey
        )
        #expect(manager.isOnCooldown(petId: plantID, type: .plantWatering))

        manager.recordCooldown(
            petId: plantID,
            type: .plantWatering,
            occurredAt: operationDate.addingTimeInterval(60)
        )
        let remainingBeforeReplay = manager.cooldownRemaining(petId: plantID, type: .plantWatering)
        _ = manager.awardAction(
            type: .plantWatering,
            pet: nil,
            context: context,
            date: operationDate,
            careObjectKey: plantID,
            idempotencyKey: idempotencyKey
        )
        #expect(manager.cooldownRemaining(petId: plantID, type: .plantWatering) >= remainingBeforeReplay - 1)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func duePlant(name: String, previousCareDate: Date) -> Plant {
        let plant = Plant(name: name, wateringIntervalDays: 1)
        plant.createdAt = previousCareDate
        plant.lastWateredDate = previousCareDate
        return plant
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )) ?? Date(timeIntervalSince1970: 0)
    }

    private func commandOptions(
        syncCarePlan: Bool,
        awardRewards: Bool,
        saveCounter: SaveCounter
    ) -> PlantCareCommandOptions {
        var options = PlantCareCommandOptions(
            syncCarePlan: syncCarePlan,
            scheduleNotifications: false,
            awardRewards: awardRewards
        )
        options.persistChanges = { context in
            saveCounter.callCount += 1
            return context.safeSaveResult(publishFailureEvent: false)
        }
        return options
    }

    private func careWriteCounts(in context: ModelContext) -> CareWriteCounts {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return CareWriteCounts(
            logs: (try? context.fetch(FetchDescriptor<PlantCareLog>()).count) ?? -1,
            factEvents: events.count(where: { !$0.isAllDay }),
            planEvents: events.filter(\.isAllDay).count,
            ledgerEvents: (try? context.fetch(FetchDescriptor<CareLedgerEvent>()).count) ?? -1
        )
    }

    private func configureOnlyWateringPlan(for plantID: UUID) {
        for careType in PlantCareCategory.schedulableCareTypes {
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                careType == .watering,
                forPlantID: plantID,
                careType: careType,
                defaults: .standard
            )
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                false,
                forPlantID: plantID,
                careType: careType,
                defaults: .standard
            )
        }
    }

    private func isolateStandardPlantDefaults(for plantID: UUID) -> () -> Void {
        let defaults = UserDefaults.standard
        let plantIDToken = plantID.uuidString
        var originalValues: [String: Any] = [:]
        for (key, value) in defaults.dictionaryRepresentation()
            where isPlantDefaultKey(key, plantIDToken: plantIDToken) {
            originalValues[key] = value
            defaults.removeObject(forKey: key)
        }
        return {
            for key in defaults.dictionaryRepresentation().keys
                where key.contains(plantIDToken) &&
                    (key.hasPrefix("ohana_plant_care_plan_event_v1_") ||
                        key.hasPrefix("plantReminder.")) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in originalValues {
                defaults.set(value, forKey: key)
            }
        }
    }

    private func standardPlanKeys(for plantID: UUID) -> [String] {
        UserDefaults.standard.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("ohana_plant_care_plan_event_v1_") &&
                $0.contains(plantID.uuidString)
        }
    }

    private func isPlantDefaultKey(_ key: String, plantIDToken: String) -> Bool {
        guard key.contains(plantIDToken) else { return false }
        return key.hasPrefix("ohana_plant_care_plan_event_v1_") ||
            key.hasPrefix("plantReminder.")
    }

    private func planStorageKey(plantID: UUID, careType: PlantCareType) -> String {
        "ohana_plant_care_plan_event_v1_\(plantID.uuidString)_\(careType.rawValue)"
    }

    private struct CareWriteCounts: Equatable {
        let logs: Int
        let factEvents: Int
        let planEvents: Int
        let ledgerEvents: Int
    }

    private final class SaveCounter {
        var callCount = 0
    }

    private final class FlakyIdempotentEconomyAwarder: CareEventEconomyAwarding {
        struct Call {
            let key: String
            let id: UUID
            let careObjectKey: UUID?
            let date: Date
        }

        private(set) var idempotentCalls: [Call] = []

        func awardCareAction(
            type _: DomainCareRewardAction,
            pet _: Pet?,
            context _: ModelContext,
            quality _: DomainCareRewardQuality,
            date: Date,
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
            date: Date,
            executorId _: String?,
            careObjectKey: UUID?,
            idempotencyKey: String,
            idempotencyID: UUID
        ) -> (humanGot: Int, petGot: Int, didPersist: Bool) {
            idempotentCalls.append(Call(
                key: idempotencyKey,
                id: idempotencyID,
                careObjectKey: careObjectKey,
                date: date
            ))
            return idempotentCalls.count == 1
                ? (humanGot: 0, petGot: 0, didPersist: false)
                : (humanGot: 3, petGot: 0, didPersist: true)
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

    private final class LegacyOnlyEconomyAwarder: CareEventEconomyAwarding {
        private(set) var legacyAwardCallCount = 0

        func awardCareAction(
            type _: DomainCareRewardAction,
            pet _: Pet?,
            context _: ModelContext,
            quality _: DomainCareRewardQuality,
            date _: Date,
            executorId _: String?,
            careObjectKey _: UUID?
        ) -> (humanGot: Int, petGot: Int) {
            legacyAwardCallCount += 1
            return (9, 0)
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
}
