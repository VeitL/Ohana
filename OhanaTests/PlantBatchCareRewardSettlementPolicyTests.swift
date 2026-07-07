import Foundation
import Testing
@testable import Ohana

struct PlantBatchCareRewardSettlementPolicyTests {
    @Test func schedulesForAllPlantPendingRewardRevisionActions() {
        let batchID = UUID()
        var dueBatchRevision = HomeRevision()
        dueBatchRevision.advance(for: .plantBatchCare(
            batchID: batchID,
            action: "batchCarePendingRewardsChanged",
            count: 1
        ))
        var quickRecordRevision = HomeRevision()
        quickRecordRevision.advance(for: .plantBatchCare(
            batchID: batchID,
            action: "batchQuickRecordPendingRewardsChanged",
            count: 1
        ))
        var rewardCommitRevision = HomeRevision()
        rewardCommitRevision.advance(for: .plantBatchCare(
            batchID: batchID,
            action: "batchCareRewardCommit",
            count: 1
        ))
        var petRevision = HomeRevision()
        petRevision.advance(for: .quickCare(entityID: batchID, action: "feed"))

        #expect(PlantBatchCareRewardSettlementPolicy.shouldSchedule(for: dueBatchRevision))
        #expect(PlantBatchCareRewardSettlementPolicy.shouldSchedule(for: quickRecordRevision))
        #expect(!PlantBatchCareRewardSettlementPolicy.shouldSchedule(for: rewardCommitRevision))
        #expect(!PlantBatchCareRewardSettlementPolicy.shouldSchedule(for: petRevision))
    }

    @Test func keepsPendingTokenWhenRewardCommitDoesNotPersist() {
        let batchID = UUID()
        let persisted = PlantBatchCareRewardCommitResult(
            batchID: batchID,
            didCommit: false,
            awardedCoconutDelta: 0,
            ledgerEventIDs: [],
            walletEntryIDs: [],
            budgetUsageIDs: [],
            didPersist: true,
            persistenceErrorDescription: nil
        )
        let failed = PlantBatchCareRewardCommitResult(
            batchID: batchID,
            didCommit: false,
            awardedCoconutDelta: 0,
            ledgerEventIDs: [],
            walletEntryIDs: [],
            budgetUsageIDs: [],
            didPersist: false,
            persistenceErrorDescription: "disk full"
        )

        #expect(PlantBatchCareRewardSettlementPolicy.shouldRemovePendingToken(after: persisted))
        #expect(!PlantBatchCareRewardSettlementPolicy.shouldRemovePendingToken(after: failed))
    }

    @Test func failedCommitRetryBacksOffExpiredTokenSettlement() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let retryAfter = PlantBatchCareRewardSettlementPolicy.retryAfterFailedCommit(now: now)
        let immediate = PlantBatchCareRewardSettlementPolicy.nextRunDate(
            now: now,
            hasExpiredTokens: true,
            nextSettlementDate: nil,
            retryAfterFailure: nil
        )
        let backedOff = PlantBatchCareRewardSettlementPolicy.nextRunDate(
            now: now,
            hasExpiredTokens: true,
            nextSettlementDate: nil,
            retryAfterFailure: retryAfter
        )
        let futureSettlement = now.addingTimeInterval(90)
        let scheduled = PlantBatchCareRewardSettlementPolicy.nextRunDate(
            now: now,
            hasExpiredTokens: false,
            nextSettlementDate: futureSettlement,
            retryAfterFailure: nil
        )

        #expect(immediate == now.addingTimeInterval(PlantBatchCareRewardSettlementPolicy.immediateRetryDelay))
        #expect(backedOff == retryAfter)
        #expect(retryAfter == now.addingTimeInterval(PlantBatchCareRewardSettlementPolicy.failedCommitRetryDelay))
        #expect(scheduled == futureSettlement)
    }
}
