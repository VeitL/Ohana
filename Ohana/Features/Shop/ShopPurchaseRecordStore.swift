//
//  ShopPurchaseRecordStore.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
enum ShopPurchaseRecordStore {
    static let legacyDefaultsKey = "purchasedShopItems"
    static let legacyMigrationDefaultsKey = "shop_purchase_records_migrated_from_defaults_v1"

    nonisolated static func ownedItemIDs(from records: [ShopPurchaseRecord]) -> Set<String> {
        Set(records.map(\.itemId))
    }

    nonisolated static func legacyPurchasedItemIDs(raw: String) -> [String] {
        Array(Set(raw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
            .sorted()
    }

    nonisolated static func isOwned(itemID: String, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<ShopPurchaseRecord>(
            predicate: #Predicate<ShopPurchaseRecord> { record in
                record.itemId == itemID
            }
        )
        return try !context.fetch(descriptor).isEmpty
    }

    @discardableResult
    static func insertOwnershipRecordIfNeeded(
        item: ShopItem,
        buyer: Human?,
        transactionKey: String,
        context: ModelContext,
        purchasedAt: Date = Date(),
        sourceRaw: String = "shop"
    ) throws -> ShopPurchaseRecord? {
        guard shouldPersistOwnership(for: item) else { return nil }
        guard try !isOwned(itemID: item.id, context: context) else { return nil }
        let record = ShopPurchaseRecord(
            transactionKey: transactionKey,
            itemId: item.id,
            buyerHumanId: buyer?.id.uuidString,
            purchasedAt: purchasedAt,
            sourceRaw: sourceRaw
        )
        context.insert(record)
        CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: purchasedAt)
        return record
    }

    @discardableResult
    static func migrateLegacyDefaultsIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) throws -> Int {
        guard !defaults.bool(forKey: legacyMigrationDefaultsKey) else { return 0 }
        let ids = legacyPurchasedItemIDs(raw: defaults.string(forKey: legacyDefaultsKey) ?? "")
        var inserted = 0
        for itemID in ids {
            guard let item = ShopCatalog.item(id: itemID), shouldPersistOwnership(for: item) else { continue }
            guard try !isOwned(itemID: itemID, context: context) else { continue }
            let record = ShopPurchaseRecord(
                transactionKey: "legacy:\(itemID)",
                itemId: itemID,
                buyerHumanId: nil,
                purchasedAt: now,
                sourceRaw: "legacyDefaults",
                isLegacyImport: true,
                createdAt: now
            )
            context.insert(record)
            CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: now)
            inserted += 1
        }
        try saveRecordStoreChanges(context: context)
        defaults.set(true, forKey: legacyMigrationDefaultsKey)
        return inserted
    }

    @discardableResult
    static func deleteOwnershipRecord(
        itemID: String,
        transactionKey: String?,
        context: ModelContext,
        deletedAt: Date = Date()
    ) throws -> Bool {
        guard let transactionKey else { return false }
        let descriptor = FetchDescriptor<ShopPurchaseRecord>(
            predicate: #Predicate<ShopPurchaseRecord> { record in
                record.transactionKey == transactionKey
            }
        )
        let records = try context.fetch(descriptor)
        guard let record = records.first else { return false }
        CloudSyncMutationRecorder.markDeleted(record, context: context, deletedAt: deletedAt)
        context.delete(record)
        return true
    }

    private nonisolated static func shouldPersistOwnership(for item: ShopItem) -> Bool {
        !item.isConsumable && item.id != AppIconCatalog.defaultItemId
    }

    private static func saveRecordStoreChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw ShopPurchaseRecordStoreError.persistenceFailed(saveResult.errorDescription)
        }
    }
}

enum ShopPurchaseRecordStoreError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "shop.purchase.record.persistence.failed",
                defaultValue: "Unable to save shop purchase records.",
                comment: "Shown when shop purchase ownership persistence fails."
            )
        }
    }
}
