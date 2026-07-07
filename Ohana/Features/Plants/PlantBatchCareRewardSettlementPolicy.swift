//
//  PlantBatchCareRewardSettlementPolicy.swift
//  Ohana
//
//  Pure scheduling/removal rules for delayed plant batch-care rewards.
//

import Foundation

nonisolated enum PlantBatchCareRewardSettlementPolicy {
    static let immediateRetryDelay: TimeInterval = 0.18
    static let failedCommitRetryDelay: TimeInterval = 30

    static func shouldSchedule(for revision: HomeRevision) -> Bool {
        guard let command = revision.lastCommand else { return false }
        return command.feature == "plants"
            && command.action.hasSuffix("PendingRewardsChanged")
    }

    static func shouldRemovePendingToken(after result: PlantBatchCareRewardCommitResult) -> Bool {
        result.didPersist
    }

    static func retryAfterFailedCommit(now: Date = Date()) -> Date {
        now.addingTimeInterval(failedCommitRetryDelay)
    }

    static func nextRunDate(
        now: Date = Date(),
        hasExpiredTokens: Bool,
        nextSettlementDate: Date?,
        retryAfterFailure: Date?
    ) -> Date? {
        if let retryAfterFailure,
           retryAfterFailure > now {
            return retryAfterFailure
        }
        if hasExpiredTokens {
            return now.addingTimeInterval(immediateRetryDelay)
        }
        return nextSettlementDate
    }
}
