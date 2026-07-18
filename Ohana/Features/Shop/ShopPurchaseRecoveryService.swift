//
//  ShopPurchaseRecoveryService.swift
//  Ohana
//
//  Bounded settlement for purchases whose fulfillment crosses SwiftData and
//  device-local state such as inventory preferences or the system app icon.

import Foundation
import SwiftData

nonisolated enum ShopPurchaseRecoveryDisposition: Equatable, Sendable {
    case fulfilled
    case refunded
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
    case refunded
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
    /// new purchase or debit. The entry only leaves manual review after the
    /// exact prerequisite that previously blocked fulfillment or refund is
    /// available again.
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
        guard let item = ShopCatalog.item(id: attempt.itemId) else {
            return manualRecoveryBlocked(attempt, reason: "catalogItemMissing")
        }
        guard attempt.price == item.cost else {
            return manualRecoveryBlocked(attempt, reason: "catalogPriceChanged")
        }

        let nextState: ShopPurchaseAttemptState
        switch manualRecoveryIntent(for: attempt.lastError) {
        case .fulfillment:
            guard item.isConsumable || item.appIcon != nil else {
                return manualRecoveryBlocked(attempt, reason: "unsupportedFulfillmentKind")
            }
            nextState = .purchased
        case .refund:
            var refundBlockReason = refundPreflightBlockReason(attempt, context: context)
            if refundBlockReason == "missingFundingSnapshot" || refundBlockReason == "invalidFundingSnapshot",
               let recovered = recoverFundingContributions(attempt, context: context) {
                attempt.fundingContributionsJSON = encode(recovered)
                refundBlockReason = refundPreflightBlockReason(attempt, context: context)
            }
            guard let refundBlockReason else {
                nextState = .refundPending
                break
            }
            return manualRecoveryBlocked(attempt, reason: refundBlockReason)
        case .unknown:
            return manualRecoveryBlocked(attempt, reason: "unrecognizedManualReviewReason")
        }

        attempt.state = nextState
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
        case .refunded: .refunded
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
                let outcome = try refund(
                    item: item,
                    purchase: purchase,
                    context: context,
                    services: services,
                    reason: "recoveryRefund",
                    now: now
                )
                return result(attempt, outcome.didRefund ? .refunded : .manualReview)
            }

            if item.appIcon != nil {
                if services.appIcons.currentDescriptor.itemId == item.id,
                   try fulfillment.completeAppIconPurchase(
                       item: item,
                       purchase: purchase,
                       context: context
                   ) {
                    return result(attempt, .fulfilled)
                }
                let outcome = try refund(
                    item: item,
                    purchase: purchase,
                    context: context,
                    services: services,
                    reason: "appIconRecoveryMismatch",
                    now: now
                )
                return result(attempt, outcome.didRefund ? .refunded : .manualReview)
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
                let outcome = try refund(
                    item: item,
                    purchase: purchase,
                    context: context,
                    services: services,
                    reason: "recoveryFulfillmentRejected",
                    now: now
                )
                return result(attempt, outcome.didRefund ? .refunded : .manualReview)
            }

            markManualReview(attempt, reason: "unsupportedFulfillmentKind", context: context, now: now)
            return result(attempt, .manualReview)
        } catch {
            scheduleRetry(attempt, error: error, context: context, now: now)
            return result(attempt, .retryScheduled)
        }
    }

    private static func refund(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        context: ModelContext,
        services: AppServices,
        reason: String,
        now: Date
    ) throws -> ShopPurchaseRefundOutcome {
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        let l = L10n()
        let title = l.tr(
            zh: "退回「\(item.name(l))」",
            en: "Refunded \(item.name(l))",
            de: "\(item.name(l)) erstattet"
        )
        return try services.shopPurchaseFulfillment.refundPurchaseOutcome(
            item: item,
            purchase: purchase,
            humans: humans,
            context: context,
            services: services,
            title: title,
            reason: reason,
            now: now
        )
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

    private enum ManualRecoveryIntent {
        case fulfillment
        case refund
        case unknown
    }

    private static func manualRecoveryIntent(for reason: String?) -> ManualRecoveryIntent {
        switch reason {
        case "catalogItemMissing", "unsupportedFulfillmentKind":
            .fulfillment
        case "missingFundingSnapshot", "invalidFundingSnapshot", "missingOrFrozenRefundRecipient":
            .refund
        default:
            .unknown
        }
    }

    private static func refundPreflightBlockReason(
        _ attempt: ShopPurchaseAttempt,
        context: ModelContext
    ) -> String? {
        guard let data = attempt.fundingContributionsJSON.data(using: .utf8),
              let contributions = try? JSONDecoder().decode(
                  [ShopPurchaseFundingContribution].self,
                  from: data
              ),
              ShopPurchaseFundingSnapshotValidator.isValid(
                  contributions,
                  expectedTotal: attempt.price
              ) else {
            return dataIsMissingOrEmpty(attempt.fundingContributionsJSON)
                ? "missingFundingSnapshot"
                : "invalidFundingSnapshot"
        }
        for contribution in contributions {
            let id = contribution.humanID
            var descriptor = FetchDescriptor<Human>(
                predicate: #Predicate<Human> { human in human.id == id }
            )
            descriptor.fetchLimit = 1
            guard let human = try? context.fetch(descriptor).first,
                  EconomyWalletWritePolicy.canWrite(human) else {
                return "missingOrFrozenRefundRecipient"
            }
        }
        return nil
    }

    private static func recoverFundingContributions(
        _ attempt: ShopPurchaseAttempt,
        context: ModelContext
    ) -> [ShopPurchaseFundingContribution]? {
        guard let purchaseLedgerEventID = attempt.purchaseLedgerEventId?.uuidString else { return nil }
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { entry in
                entry.careLedgerEventId == purchaseLedgerEventID
            }
        )
        descriptor.fetchLimit = 32
        guard let entries = try? context.fetch(descriptor) else { return nil }

        let debitEntries = entries.filter { entry in
            let expectedTransactionKey = entry.ownerId.isEmpty
                ? attempt.transactionKey
                : "\(attempt.transactionKey):\(entry.ownerId)"
            return entry.affectsBalance &&
                entry.ownerKind == .human &&
                entry.source == .shop &&
                entry.sourceModelName == "ShopCatalog" &&
                entry.sourceModelId == attempt.itemId &&
                entry.delta < 0 &&
                (entry.entryKind == .spend || entry.entryKind == .transferOut) &&
                (entry.transactionKey == attempt.transactionKey || entry.transactionKey == expectedTransactionKey)
        }
        let contributions = debitEntries.compactMap { entry -> ShopPurchaseFundingContribution? in
            guard let humanID = UUID(uuidString: entry.ownerId), entry.delta != Int.min else { return nil }
            return ShopPurchaseFundingContribution(humanID: humanID, amount: -entry.delta)
        }
        guard contributions.count == debitEntries.count,
              ShopPurchaseFundingSnapshotValidator.isValid(
                  contributions,
                  expectedTotal: attempt.price
              ) else { return nil }
        return contributions
    }

    private static func dataIsMissingOrEmpty(_ raw: String) -> Bool {
        guard let data = raw.data(using: .utf8),
              let contributions = try? JSONDecoder().decode(
                  [ShopPurchaseFundingContribution].self,
                  from: data
              ) else { return true }
        return contributions.isEmpty
    }

    private static func encode(_ contributions: [ShopPurchaseFundingContribution]) -> String {
        guard let data = try? JSONEncoder().encode(contributions),
              let raw = String(data: data, encoding: .utf8) else { return "[]" }
        return raw
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
        attempt.attemptCount += 1
        attempt.lastError = error.localizedDescription
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
