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
    func fulfillConsumable(
        item: ShopItem,
        attemptID: UUID,
        context: ModelContext,
        services: AppServices
    ) -> Bool

    @discardableResult
    func fulfillInventoryConsumable(
        item: ShopItem,
        attemptID: UUID,
        context: ModelContext,
        inventory: ShopInventoryManaging
    ) -> Bool

    @discardableResult
    func completeAppIconPurchase(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        context: ModelContext
    ) throws -> Bool

    @discardableResult
    func completeOwnershipPurchase(
        item: ShopItem,
        purchase: ShopPurchaseCommandResult,
        context: ModelContext
    ) throws -> Bool
}

@MainActor
struct ShopPurchaseFulfillmentService: ShopPurchaseFulfilling {
    @discardableResult
    func fulfillConsumable(
        item: ShopItem,
        context: ModelContext,
        services: AppServices
    ) -> Bool {
        guard let attempt = latestRecoverableAttempt(itemID: item.id, context: context) else {
            return false
        }
        return fulfillConsumable(
            item: item,
            attemptID: attempt.id,
            context: context,
            services: services
        )
    }

    @discardableResult
    func fulfillConsumable(
        item submittedItem: ShopItem,
        attemptID: UUID,
        context: ModelContext,
        services: AppServices
    ) -> Bool {
        guard let item = ShopCatalog.item(id: submittedItem.id),
              normalized(item) == normalized(submittedItem),
              item.isConsumable else {
            return false
        }
        if isInventoryConsumable(item.id) {
            return fulfillInventoryConsumable(
                item: item,
                attemptID: attemptID,
                context: context,
                inventory: services.shopInventory
            )
        }
        guard let attempt = fetchAttempt(id: attemptID, context: context),
              attempt.itemId == item.id else { return false }
        let startingState = attempt.state
        switch attempt.state {
        case .fulfilled:
            if isTreeEnergyItem(item.id) {
                services.oasisTree.finalizePurchasedEnergyBoost(
                    purchaseID: attempt.id,
                    modelContext: context
                )
            }
            return true
        case .refunded, .manualReview, .refundPending:
            return false
        case .purchased, .fulfilling:
            break
        }

        let decodedPayload = decodePayload(attempt.fulfillmentPayloadJSON)
        if startingState == .fulfilling,
           decodedPayload?.version != ShopPurchaseFulfillmentPayload.currentVersion {
            return markLegacyFulfillmentForReview(attempt, context: context)
        }
        var payload = decodedPayload ?? ShopPurchaseFulfillmentPayload(purchasedAt: attempt.createdAt)
        if isTreeEnergyItem(item.id) {
            let xp = item.id == "boost_tree_large"
                ? OasisTreeEnergyInjectionPolicy.largePackageXP
                : OasisTreeEnergyInjectionPolicy.starterPackageXP
            if startingState == .fulfilling, payload.treeEnergyXP == nil {
                return markLegacyFulfillmentForReview(attempt, context: context)
            }
            if payload.treeEnergyXP == nil {
                payload.treeEnergyXP = xp
            }
        }
        attempt.state = .fulfilling
        attempt.attemptCount += 1
        attempt.lastError = nil
        attempt.nextRetryAt = nil
        attempt.updatedAt = Date()
        attempt.fulfillmentPayloadJSON = encode(payload)
        do {
            try save(context: context)
        } catch {
            return false
        }

        let didApply: Bool
        switch item.id {
        case "boost_tree", "boost_tree_large":
            guard let xp = payload.treeEnergyXP else { return false }
            didApply = services.oasisTree.applyPurchasedEnergyBoost(
                cost: item.cost,
                injectedXP: xp,
                purchaseID: attempt.id,
                modelContext: context
            )
        default:
            didApply = false
        }

        guard didApply else {
            markFulfillmentPending(
                attempt,
                reason: "fulfillmentRejected",
                context: context
            )
            return false
        }

        attempt.state = .fulfilled
        attempt.fulfilledAt = Date()
        attempt.updatedAt = attempt.fulfilledAt ?? Date()
        attempt.lastError = nil
        attempt.nextRetryAt = nil
        do {
            try save(context: context)
            if isTreeEnergyItem(item.id) {
                services.oasisTree.finalizePurchasedEnergyBoost(
                    purchaseID: attempt.id,
                    modelContext: context
                )
            }
        } catch {
            // The external effect is already idempotently checkpointed. Keep
            // the durable attempt at `fulfilling`; startup recovery will only
            // finish its SwiftData checkpoint and must not trigger a refund.
            context.rollback()
        }
        return true
    }

    @discardableResult
    func fulfillInventoryConsumable(
        item submittedItem: ShopItem,
        attemptID: UUID,
        context: ModelContext,
        inventory: ShopInventoryManaging
    ) -> Bool {
        guard let item = ShopCatalog.item(id: submittedItem.id),
              normalized(item) == normalized(submittedItem),
              isInventoryConsumable(item.id),
              let attempt = fetchAttempt(id: attemptID, context: context),
              attempt.itemId == item.id else {
            return false
        }
        let startingState = attempt.state
        switch attempt.state {
        case .fulfilled:
            return true
        case .refunded, .manualReview, .refundPending:
            return false
        case .purchased, .fulfilling:
            break
        }

        let decodedPayload = decodePayload(attempt.fulfillmentPayloadJSON)
        if startingState == .fulfilling,
           decodedPayload?.version != ShopPurchaseFulfillmentPayload.currentVersion {
            return markLegacyFulfillmentForReview(attempt, context: context)
        }
        let payload = decodedPayload ?? ShopPurchaseFulfillmentPayload(purchasedAt: attempt.createdAt)
        attempt.state = .fulfilling
        attempt.attemptCount += 1
        attempt.lastError = nil
        attempt.nextRetryAt = nil
        attempt.updatedAt = Date()
        attempt.fulfillmentPayloadJSON = encode(payload)
        do {
            try save(context: context)
        } catch {
            return false
        }

        guard inventory.fulfillPurchase(
            itemID: item.id,
            attemptID: attempt.id,
            purchasedAt: payload.purchasedAt
        ) else {
            markFulfillmentPending(
                attempt,
                reason: "fulfillmentRejected",
                context: context
            )
            return false
        }

        attempt.state = .fulfilled
        attempt.fulfilledAt = Date()
        attempt.updatedAt = attempt.fulfilledAt ?? Date()
        attempt.lastError = nil
        attempt.nextRetryAt = nil
        do {
            try save(context: context)
        } catch {
            // The durable inventory value contains this attempt's marker.
            // Recovery can safely finish the SwiftData checkpoint later.
            context.rollback()
        }
        return true
    }

    @discardableResult
    func completeAppIconPurchase(
        item submittedItem: ShopItem,
        purchase: ShopPurchaseCommandResult,
        context: ModelContext
    ) throws -> Bool {
        guard let item = ShopCatalog.item(id: submittedItem.id),
              item.appIcon != nil else {
            return false
        }
        return try completeOwnershipPurchase(
            item: item,
            purchase: purchase,
            context: context
        )
    }

    @discardableResult
    func completeOwnershipPurchase(
        item submittedItem: ShopItem,
        purchase: ShopPurchaseCommandResult,
        context: ModelContext
    ) throws -> Bool {
        guard let item = ShopCatalog.item(id: submittedItem.id),
              normalized(item) == normalized(submittedItem),
              !item.isConsumable,
              item.id != AppIconCatalog.defaultItemId,
              let attemptID = purchase.attemptID,
              let attempt = fetchAttempt(id: attemptID, context: context),
              attempt.itemId == item.id else {
            return false
        }
        if attempt.state == .fulfilled { return true }
        guard attempt.state != .refunded, attempt.state != .manualReview else { return false }

        let buyer = fetchHuman(id: attempt.buyerHumanId, context: context)
        try ShopPurchaseRecordStore.insertOwnershipRecordIfNeeded(
            item: item,
            buyer: buyer,
            transactionKey: attempt.transactionKey,
            context: context,
            purchasedAt: attempt.createdAt
        )
        attempt.state = .fulfilled
        attempt.fulfilledAt = Date()
        attempt.updatedAt = attempt.fulfilledAt ?? Date()
        attempt.lastError = nil
        attempt.nextRetryAt = nil
        try save(context: context)
        return true
    }

    private func latestRecoverableAttempt(itemID: String, context: ModelContext) -> ShopPurchaseAttempt? {
        let purchased = ShopPurchaseAttemptState.purchased.rawValue
        let fulfilling = ShopPurchaseAttemptState.fulfilling.rawValue
        var descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.itemId == itemID &&
                    (attempt.stateRaw == purchased || attempt.stateRaw == fulfilling)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchAttempt(id: UUID, context: ModelContext) -> ShopPurchaseAttempt? {
        var descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchHuman(id rawID: String, context: ModelContext) -> Human? {
        guard let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func markLegacyFulfillmentForReview(
        _ attempt: ShopPurchaseAttempt,
        context: ModelContext
    ) -> Bool {
        attempt.state = .manualReview
        attempt.lastError = "legacyFulfillmentUnverifiable"
        attempt.updatedAt = Date()
        attempt.nextRetryAt = nil
        _ = context.safeSaveResult(publishFailureEvent: true)
        return false
    }

    private func markFulfillmentPending(
        _ attempt: ShopPurchaseAttempt,
        reason: String,
        context: ModelContext
    ) {
        let now = Date()
        attempt.state = .purchased
        attempt.lastError = reason
        attempt.updatedAt = now
        attempt.nextRetryAt = now.addingTimeInterval(
            min(300, Double(max(1, attempt.attemptCount)) * 10)
        )
        _ = context.safeSaveResult(publishFailureEvent: true)
    }

    private func isTreeEnergyItem(_ itemID: String) -> Bool {
        itemID == "boost_tree" || itemID == "boost_tree_large"
    }

    private func save(context: ModelContext) throws {
        let result = context.safeSaveResult(publishFailureEvent: true)
        guard result.didSave else {
            context.rollback()
            throw ShopPurchaseFulfillmentError.persistenceFailed(result.errorDescription)
        }
    }

    private func decodePayload(_ raw: String) -> ShopPurchaseFulfillmentPayload? {
        decode(ShopPurchaseFulfillmentPayload.self, from: raw)
    }

    private func decode<Value: Decodable>(_: Value.Type, from raw: String) -> Value? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func encode(_ value: some Encodable) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let raw = String(data: data, encoding: .utf8) else { return "{}" }
        return raw
    }

    private func normalized(_ item: ShopItem) -> ShopItem {
        var copy = item
        copy.isPurchased = false
        return copy
    }

    private func isInventoryConsumable(_ itemID: String) -> Bool {
        ShopProductApplicationCatalog.application(for: itemID).isInventoryConsumable
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
                comment: "Shown when a shop purchase fulfillment update fails to save."
            )
        }
    }
}
