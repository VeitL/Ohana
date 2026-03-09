//
//  PetFoodRecord.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

@Model
final class PetFoodRecord {
    var id: UUID
    var brand: String
    var dailyGrams: Double
    var startDate: Date
    var notes: String
    var executorId: String?  // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var pet: Pet?
    
    init(brand: String = "", dailyGrams: Double = 0, startDate: Date = Date(), pet: Pet? = nil, executorId: String? = nil) {
        self.id = UUID()
        self.brand = brand
        self.dailyGrams = dailyGrams
        self.startDate = startDate
        self.notes = ""
        self.executorId = executorId
        self.pet = pet
    }
}
