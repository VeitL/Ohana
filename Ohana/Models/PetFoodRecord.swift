//
//  PetFoodRecord.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

@Model
final class PetFoodRecord {
    var id: UUID
    var brand: String
    var dailyGrams: Double
    var totalGrams: Double = 0
    var foodKindRaw: String = FeedFoodKind.dry.rawValue
    var purchaseDate: Date?
    var startDate: Date
    var remainingCorrectionGrams: Double?
    var remainingCorrectionDate: Date?
    var notes: String
    var expenseId: UUID?
    var calculationModeRaw: String = FeedStockCalculationMode.manualOrPlan.rawValue
    var executorId: String? // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var pet: Pet?
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    init(
        brand: String = "",
        dailyGrams: Double = 0,
        totalGrams: Double = 0,
        foodKind: FeedFoodKind = .dry,
        purchaseDate: Date? = nil,
        startDate: Date = Date(),
        pet: Pet? = nil,
        executorId: String? = nil,
        expenseId: UUID? = nil,
        calculationMode: FeedStockCalculationMode = .manualOrPlan
    ) {
        self.id = UUID()
        self.brand = brand
        self.dailyGrams = dailyGrams
        self.totalGrams = totalGrams
        self.foodKindRaw = foodKind.rawValue
        self.purchaseDate = purchaseDate
        self.startDate = startDate
        self.remainingCorrectionGrams = nil
        self.remainingCorrectionDate = nil
        self.notes = ""
        self.expenseId = expenseId
        self.calculationModeRaw = calculationMode.rawValue
        self.executorId = executorId
        self.pet = pet
    }

    var foodKind: FeedFoodKind { FeedFoodKind(rawValue: foodKindRaw) ?? .dry }
}
