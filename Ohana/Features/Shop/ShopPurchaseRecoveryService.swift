//
//  ShopPurchaseRecoveryService.swift
//  Ohana
//
//  Bounded settlement for final-sale purchases whose application crosses
//  SwiftData and device-local state such as inventory or the system app icon.

import Foundation
import SwiftData

nonisolated enum ShopPurchaseRecoveryDisposition: Equatable, Sendable {
    case fulfilled
    case retryScheduled
    case manualReview
}

nonisolated struct ShopPurchaseRecoveryResult: Equatable, Sendable {
    let attemptID: UUID
    let itemID: String
    let disposition: ShopPurchaseRecoveryDisposition
}

nonisolated enum ShopPurchaseManualRecoveryDisposition: Equatable, Sendable {
    case fulfilled
    case retryScheduled
    case stillNeedsAttention
}

nonisolated struct ShopPurchaseManualRecoveryResult: Equatable, Sendable {
    let itemID: String
    let disposition: ShopPurchaseManualRecoveryDisposition
    let reasonCode: String?
}

@MainActor
enum ShopPurchaseRecoveryService {
    nonisolated static let maximumBatchSize = 16

    static func settleRecoverable(
        context: ModelContext,
        services: AppServices,
        now: Date = Date(),
        maximumCount: Int = maximumBatchSize
    ) -> [ShopPurchaseRecoveryResult] {
        services.oasisTree.reconcilePurchasedEnergyBoostMarkers(modelContext: context)
        let attempts = recoverableAttempts(
            context: context,
            now: now,
            maximumCount: min(maximumBatchSize, max(1, maximumCount))
        )
        return attempts.map { attempt in
            settle(attempt: attempt, context: context, services: services, now: now)
        }
    }

    /// Re-evaluates one durable manual-review outbox entry without creating a
    /// new purchase or debit. Final-sale recovery only continues fulfillment;
    /// it never creates a compensating wallet refund.
    static func retryManualReview(
        itemID: String,
        context: ModelContext,
        services: AppServices,
        now: Date = Date()
    ) -> ShopPurchaseManualRecoveryResult {
        guard let attempt = latestManualReviewAttempt(itemID: itemID, context: context) else {
            return ShopPurchaseManualRecoveryResult(
                itemID: itemID,
                disposition: .stillNeedsAttention,
                reasonCode: "manualReviewAttemptUnavailable"
            )
        }
        guard ShopCatalog.item(id: attempt.itemId) != nil else {
            return manualRecoveryBlocked(attempt, reason: "catalogItemMissing")
        }
        guard allowsManualFulfillmentRetry(reason: attempt.lastError) else {
            return manualRecoveryBlocked(attempt, reason: "unrecognizedManualReviewReason")
        }

        attempt.state = .purchased
        attempt.lastError = nil
        attempt.nextRetryAt = nil
        attempt.updatedAt = now
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return manualRecoveryBlocked(attempt, reason: "manualRecoveryPersistenceFailed")
        }

        let recovery = settle(
            attempt: attempt,
            context: context,
            services: services,
            now: now
        )
        let disposition: ShopPurchaseManualRecoveryDisposition = switch recovery.disposition {
        case .fulfilled: .fulfilled
        case .retryScheduled: .retryScheduled
        case .manualReview: .stillNeedsAttention
        }
        return ShopPurchaseManualRecoveryResult(
            itemID: recovery.itemID,
            disposition: disposition,
            reasonCode: recovery.disposition == .manualReview ? attempt.lastError : nil
        )
    }

    private static func settle(
        attempt: ShopPurchaseAttempt,
        context: ModelContext,
        services: AppServices,
        now: Date
    ) -> ShopPurchaseRecoveryResult {
        if let nextRetryAt = attempt.nextRetryAt, nextRetryAt > now {
            return result(attempt, .retryScheduled)
        }
        guard let item = ShopCatalog.item(id: attempt.itemId) else {
            markManualReview(attempt, reason: "catalogItemMissing", context: context, now: now)
            return result(attempt, .manualReview)
        }
        let purchase = commandResult(attempt)
        let fulfillment = services.shopPurchaseFulfillment

        do {
            if attempt.state == .refundPending {
                attempt.state = .purchased
                attempt.lastError = "legacyRefundConvertedToFulfillment"
                attempt.nextRetryAt = nil
                attempt.updatedAt = now
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    return result(attempt, .retryScheduled)
                }
            }

            if item.appIcon != nil {
                if try fulfillment.completeAppIconPurchase(
                       item: item,
                       purchase: purchase,
                       context: context
                   ) {
                    return result(attempt, .fulfilled)
                }
                scheduleRetry(
                    attempt,
                    reason: "appIconOwnershipPending",
                    context: context,
                    now: now
                )
                return result(attempt, .retryScheduled)
            }

            if item.isConsumable {
                if fulfillment.fulfillConsumable(
                    item: item,
                    attemptID: attempt.id,
                    context: context,
                    services: services
                ) {
                    return result(attempt, .fulfilled)
                }
                if attempt.state == .manualReview {
                    return result(attempt, .manualReview)
                }
                if attempt.nextRetryAt == nil {
                    scheduleRetry(
                        attempt,
                        reason: "recoveryFulfillmentPending",
                        context: context,
                        now: now
                    )
                }
                return result(attempt, .retryScheduled)
            }

            if try fulfillment.completeOwnershipPurchase(
                item: item,
                purchase: purchase,
                context: context
            ) {
                return result(attempt, .fulfilled)
            }
            markManualReview(attempt, reason: "unsupportedFulfillmentKind", context: context, now: now)
            return result(attempt, .manualReview)
        } catch {
            scheduleRetry(attempt, error: error, context: context, now: now)
            return result(attempt, .retryScheduled)
        }
    }

    private static func recoverableAttempts(
        context: ModelContext,
        now: Date,
        maximumCount: Int
    ) -> [ShopPurchaseAttempt] {
        let fulfilled = ShopPurchaseAttemptState.fulfilled.rawValue
        let refunded = ShopPurchaseAttemptState.refunded.rawValue
        let manualReview = ShopPurchaseAttemptState.manualReview.rawValue
        var descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.stateRaw != fulfilled &&
                    attempt.stateRaw != refunded &&
                    attempt.stateRaw != manualReview
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = max(maximumCount * 4, maximumCount)
        guard let attempts = try? context.fetch(descriptor) else { return [] }
        let due = attempts.filter { $0.nextRetryAt.map { $0 <= now } ?? true }
        let waiting = attempts.filter { $0.nextRetryAt.map { $0 > now } ?? false }
        return Array((due + waiting).prefix(maximumCount))
    }

    private static func latestManualReviewAttempt(
        itemID: String,
        context: ModelContext
    ) -> ShopPurchaseAttempt? {
        let manualReview = ShopPurchaseAttemptState.manualReview.rawValue
        var descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.itemId == itemID && attempt.stateRaw == manualReview
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func allowsManualFulfillmentRetry(reason: String?) -> Bool {
        switch reason {
        case "catalogItemMissing",
             "catalogPriceChanged",
             "unsupportedFulfillmentKind",
             "missingFundingSnapshot",
             "invalidFundingSnapshot",
             "missingOrFrozenRefundRecipient",
             "invalidPurchaseSnapshot",
             "fulfillmentRejected",
             "streakFulfillmentExpired",
             "appIconApplyFailed",
             "appIconRecoveryMismatch",
             "legacyRefundConvertedToFulfillment",
             "manualRecoveryPersistenceFailed":
            true
        default:
            false
        }
    }

    private static func manualRecoveryBlocked(
        _ attempt: ShopPurchaseAttempt,
        reason: String
    ) -> ShopPurchaseManualRecoveryResult {
        ShopPurchaseManualRecoveryResult(
            itemID: attempt.itemId,
            disposition: .stillNeedsAttention,
            reasonCode: reason
        )
    }

    private static func commandResult(_ attempt: ShopPurchaseAttempt) -> ShopPurchaseCommandResult {
        let contributions: [ShopPurchaseFundingContribution] = if let data = attempt.fundingContributionsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ShopPurchaseFundingContribution].self, from: data) {
            decoded
        } else {
            []
        }
        return ShopPurchaseCommandResult(
            attemptID: attempt.id,
            humanID: UUID(uuidString: attempt.buyerHumanId),
            itemID: attempt.itemId,
            cost: attempt.price,
            didPurchase: true,
            failure: nil,
            ledgerEventID: attempt.purchaseLedgerEventId,
            transactionKey: attempt.transactionKey,
            fundingContributions: contributions
        )
    }

    private static func scheduleRetry(
        _ attempt: ShopPurchaseAttempt,
        error: Error,
        context: ModelContext,
        now: Date
    ) {
        scheduleRetry(
            attempt,
            reason: error.localizedDescription,
            context: context,
            now: now
        )
    }

    private static func scheduleRetry(
        _ attempt: ShopPurchaseAttempt,
        reason: String,
        context: ModelContext,
        now: Date
    ) {
        attempt.state = .purchased
        attempt.attemptCount += 1
        attempt.lastError = reason
        attempt.updatedAt = now
        attempt.nextRetryAt = now.addingTimeInterval(
            min(300, Double(max(1, attempt.attemptCount)) * 10)
        )
        _ = context.safeSaveResult(publishFailureEvent: true)
    }

    private static func markManualReview(
        _ attempt: ShopPurchaseAttempt,
        reason: String,
        context: ModelContext,
        now: Date
    ) {
        attempt.state = .manualReview
        attempt.lastError = reason
        attempt.updatedAt = now
        attempt.nextRetryAt = nil
        _ = context.safeSaveResult(publishFailureEvent: true)
    }

    private static func result(
        _ attempt: ShopPurchaseAttempt,
        _ disposition: ShopPurchaseRecoveryDisposition
    ) -> ShopPurchaseRecoveryResult {
        ShopPurchaseRecoveryResult(
            attemptID: attempt.id,
            itemID: attempt.itemId,
            disposition: disposition
        )
    }
}
