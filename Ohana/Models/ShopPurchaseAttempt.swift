//
//  ShopPurchaseAttempt.swift
//  Ohana
//
//  Local-only recovery state for shop purchases with external fulfillment.
//

import Foundation
import SwiftData

nonisolated enum ShopPurchaseAttemptState: String, Codable, CaseIterable, Sendable {
    case purchased
    case fulfilling
    case fulfilled
    case refundPending
    case refunded
    case manualReview
}

@Model
final class ShopPurchaseAttempt {
    #Index<ShopPurchaseAttempt>(
        [\.stateRaw, \.nextRetryAt],
        [\.itemId, \.createdAt],
        [\.buyerHumanId]
    )

    var id: UUID
    @Attribute(.unique) var transactionKey: String
    var itemId: String
    var buyerHumanId: String
    var price: Int
    var stateRaw: String

    /// The immutable ledger fact created by the purchase transaction.
    var purchaseLedgerEventId: UUID?

    /// Versioned, immutable snapshot of the accounts that funded the purchase.
    var fundingContributionsJSON: String

    /// Versioned absolute-value inputs required to replay external fulfillment.
    var fulfillmentPayloadJSON: String

    var attemptCount: Int
    var lastError: String?
    var nextRetryAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var fulfilledAt: Date?
    var refundedAt: Date?

    init(
        id: UUID = UUID(),
        transactionKey: String,
        itemId: String,
        buyerHumanId: String,
        price: Int,
        state: ShopPurchaseAttemptState = .purchased,
        purchaseLedgerEventId: UUID? = nil,
        fundingContributionsJSON: String = "[]",
        fulfillmentPayloadJSON: String = "{}",
        attemptCount: Int = 0,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        fulfilledAt: Date? = nil,
        refundedAt: Date? = nil
    ) {
        self.id = id
        self.transactionKey = transactionKey
        self.itemId = itemId
        self.buyerHumanId = buyerHumanId
        self.price = price
        stateRaw = state.rawValue
        self.purchaseLedgerEventId = purchaseLedgerEventId
        self.fundingContributionsJSON = fundingContributionsJSON
        self.fulfillmentPayloadJSON = fulfillmentPayloadJSON
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.fulfilledAt = fulfilledAt
        self.refundedAt = refundedAt
    }

    var state: ShopPurchaseAttemptState {
        get { ShopPurchaseAttemptState(rawValue: stateRaw) ?? .manualReview }
        set { stateRaw = newValue.rawValue }
    }
}
