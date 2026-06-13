//
//  ShopPurchaseRecord.swift
//  Ohana
//

import Foundation
import SwiftData

@Model
final class ShopPurchaseRecord {
    #Index<ShopPurchaseRecord>([\.itemId], [\.buyerHumanId], [\.purchasedAt])

    @Attribute(.unique) var transactionKey: String = ""
    var id: UUID = UUID()
    var itemId: String = ""
    var buyerHumanId: String = ""
    var purchasedAt: Date = Date()
    var sourceRaw: String = "shop"
    var isLegacyImport: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        transactionKey: String,
        itemId: String,
        buyerHumanId: String? = nil,
        purchasedAt: Date = Date(),
        sourceRaw: String = "shop",
        isLegacyImport: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.transactionKey = transactionKey
        self.itemId = itemId
        self.buyerHumanId = buyerHumanId ?? ""
        self.purchasedAt = purchasedAt
        self.sourceRaw = sourceRaw
        self.isLegacyImport = isLegacyImport
        self.createdAt = createdAt
    }
}
