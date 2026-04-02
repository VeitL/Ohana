//
//  WishlistItem.swift
//  Ohana
//
//  模块1：椰子心愿单数据模型

import SwiftData
import Foundation

@Model
final class WishlistItem {
    var id: UUID
    var title: String
    var cost: Int
    var creatorId: String          // Human.id.uuidString
    var isRedeemed: Bool
    var redeemedById: String?      // 兑换人
    var createdAt: Date

    init(title: String = "", cost: Int = 10, creatorId: String = "") {
        self.id = UUID()
        self.title = title
        self.cost = cost
        self.creatorId = creatorId
        self.isRedeemed = false
        self.redeemedById = nil
        self.createdAt = Date()
    }
}
