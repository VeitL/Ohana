//
//  PetExpenseLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "食物"
    case treats = "零食"
    case medical = "医疗"
    case grooming = "美容"
    case toys = "玩具"
    case other = "其他"
    
    var emoji: String {
        switch self {
        case .food: return "🍖"
        case .treats: return "🦴"
        case .medical: return "🏥"
        case .grooming: return "✂️"
        case .toys: return "🧸"
        case .other: return "📦"
        }
    }
}

@Model
final class PetExpenseLog {
    var id: UUID
    var date: Date
    var amount: Double
    var category: String
    var note: String
    var executorId: String?  // ArkSchemaV11: 执行该动作的 Human.id.uuidString
    var pet: Pet?
    
    init(date: Date = Date(), amount: Double = 0, category: ExpenseCategory = .other, note: String = "", pet: Pet? = nil, executorId: String? = nil) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.category = category.rawValue
        self.note = note
        self.executorId = executorId
        self.pet = pet
    }
    
    var expenseCategory: ExpenseCategory {
        ExpenseCategory(rawValue: category) ?? .other
    }
}
