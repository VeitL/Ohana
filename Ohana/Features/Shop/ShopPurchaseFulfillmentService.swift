//
//  ShopPurchaseFulfillmentService.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
protocol ShopPurchaseFulfilling {
    @discardableResult
    func fulfillConsumable(
        item: ShopItem,
        context: ModelContext,
        services: AppServices
    ) -> Bool

    @discardableResult
    func refundPurchase(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        humans: [Human],
        context: ModelContext,
        services: AppServices,
        title: String,
        reason: String,
        now: Date
    ) throws -> Bool
}

extension ShopPurchaseFulfilling {
    @discardableResult
    func refundPurchase(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        humans: [Human],
        context: ModelContext,
        services: AppServices,
        title: String,
        reason: String
    ) throws -> Bool {
        try refundPurchase(
            item: item,
            purchase: purchase,
            humans: humans,
            context: context,
            services: services,
            title: title,
            reason: reason,
            now: Date()
        )
    }
}

@MainActor
struct ShopPurchaseFulfillmentService: ShopPurchaseFulfilling {
    @discardableResult
    func fulfillConsumable(
        item: ShopItem,
        context: ModelContext,
        services: AppServices
    ) -> Bool {
        switch item.id {
        case "boost_tree", "boost_tree_large":
            return services.oasisTree.applyPurchasedEnergyBoost(cost: item.cost, modelContext: context)
        case "boost_double":
            services.shopInventory.activateDoubleRewardBoost()
            return true
        case "boost_streak":
            services.shopInventory.activateStreakShield(until: Date().addingTimeInterval(172_800))
            return true
        case "boost_backdate_single", "boost_backdate_pack":
            services.shopInventory.addBackdatePasses(item.id == "boost_backdate_pack" ? 3 : 1)
            return true
        case Avatar2DAccess.shopItemId:
            Avatar2DAccess.addExtraPasses(1)
            return true
        default:
            return true
        }
    }

    @discardableResult
    func refundPurchase(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        humans: [Human],
        context: ModelContext,
        services: AppServices,
        title: String,
        reason: String,
        now: Date = Date()
    ) throws -> Bool {
        if !item.isConsumable, purchase.transactionKey != nil {
            try ShopPurchaseRecordStore.deleteOwnershipRecord(
                itemID: item.id,
                transactionKey: purchase.transactionKey,
                context: context,
                deletedAt: now
            )
        }
        let contributions = refundContributions(
            item: item,
            purchase: purchase,
            humans: humans
        )
        guard !contributions.isEmpty else {
            try saveFulfillmentChanges(context: context)
            return true
        }

        let refundSource = purchase.transactionKey
            ?? purchase.ledgerEventID?.uuidString
            ?? UUID().uuidString
        let refundDeltas: [CoconutWalletDelta] = contributions.compactMap { contribution in
            guard contribution.amount > 0 else { return nil }
            guard let recipient = humans.first(where: { $0.id == contribution.humanID }) else { return nil }
            return .human(
                recipient,
                delta: contribution.amount,
                entryKind: .refund,
                source: .shop,
                title: title,
                emoji: item.emoji,
                actorId: recipient.id.uuidString,
                actorName: recipient.name,
                subjectKind: .system,
                subjectId: nil,
                sourceModelName: "ShopCatalog",
                sourceModelId: item.id,
                careLedgerEventId: purchase.ledgerEventID?.uuidString,
                metadataJSON: "{\"shopItemId\":\"\(item.id)\",\"refund\":true,\"reason\":\"\(reason)\",\"purchaseTransactionKey\":\"\(refundSource)\"}",
                transactionKey: "shop:\(item.id):refund:\(recipient.id.uuidString):\(reason):\(refundSource)"
            )
        }
        guard !refundDeltas.isEmpty else {
            try saveFulfillmentChanges(context: context)
            return true
        }
        try services.coconutWallet.apply(
            deltas: refundDeltas,
            context: context,
            save: false,
            postsRewardFeedback: true,
            updatesProjection: true,
            projectionManager: services.questManager
        )
        try saveFulfillmentChanges(context: context)
        return true
    }

    private func refundContributions(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        humans: [Human]
    ) -> [ShopPurchaseFundingContribution] {
        guard item.cost > 0 else { return [] }
        if !purchase.fundingContributions.isEmpty {
            return purchase.fundingContributions
        }
        guard let humanID = purchase.humanID,
              purchase.transactionKey != nil || purchase.ledgerEventID != nil,
              humans.contains(where: { $0.id == humanID })
        else {
            return []
        }
        return [ShopPurchaseFundingContribution(humanID: humanID, amount: item.cost)]
    }

    private func saveFulfillmentChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw ShopPurchaseFulfillmentError.persistenceFailed(saveResult.errorDescription)
        }
    }
}

enum ShopPurchaseFulfillmentError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "shop.purchase.fulfillment.persistence.failed",
                defaultValue: "Unable to save the shop purchase update.",
                comment: "Shown when a shop purchase fulfillment or refund fails to save."
            )
        }
    }
}
