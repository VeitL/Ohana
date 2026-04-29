//
//  PetExpenseLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import Foundation

enum ExpenseCategory: String, Codable, CaseIterable {
    case food             = "食物"
    case treats           = "零食"
    case medical          = "医疗"
    case grooming         = "美容"
    case toys             = "玩具"
    case insurancePremium = "保险费"   // ArkSchemaV30
    case other            = "其他"
    
    var emoji: String {
        switch self {
        case .food:             return "🍖"
        case .treats:           return "🦴"
        case .medical:          return "🏥"
        case .grooming:         return "✂️"
        case .toys:             return "🧸"
        case .insurancePremium: return "🛡️"
        case .other:            return "📦"
        }
    }

    var systemIconName: String {
        switch self {
        case .food:             return "fork.knife"
        case .treats:           return "star.fill"
        case .medical:          return "cross.fill"
        case .grooming:         return "scissors"
        case .toys:             return "gamecontroller.fill"
        case .insurancePremium: return "shield.checkered"
        case .other:            return "ellipsis.circle.fill"
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
    var executorId: String?  // ArkSchemaV11: 花费支付者的 Human.id.uuidString
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
