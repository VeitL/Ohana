//
//  PetExpenseLog.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

nonisolated enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "食物"
    case treats = "零食"
    case medical = "医疗"
    case grooming = "美容"
    case toys = "玩具"
    case insurancePremium = "保险费" // ArkSchemaV30
    case other = "其他"

    var emoji: String {
        switch self {
        case .food: "🍖"
        case .treats: "🦴"
        case .medical: "🏥"
        case .grooming: "✂️"
        case .toys: "🧸"
        case .insurancePremium: "🛡️"
        case .other: "📦"
        }
    }

    var systemIconName: String {
        switch self {
        case .food: "fork.knife"
        case .treats: "star.fill"
        case .medical: "cross.fill"
        case .grooming: "scissors"
        case .toys: "gamecontroller.fill"
        case .insurancePremium: "shield.checkered"
        case .other: "ellipsis.circle.fill"
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
    var sharedSessionId: String = ""
    var executorId: String? // ArkSchemaV11: 花费支付者的 Human.id.uuidString
    var recordedByHumanId: String? // ArkSchemaV91: 本次录入者；与付款人分开
    /// ArkSchemaV99: versioned, exact payer amounts for a single expense fact.
    /// `executorId` remains the primary payer and legacy fallback.
    var payerContributionsJSON: String = ""
    var pet: Pet?
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""

    init(
        date: Date = Date(),
        amount: Double = 0,
        category: ExpenseCategory = .other,
        note: String = "",
        pet: Pet? = nil,
        executorId: String? = nil,
        recordedByHumanId: String? = nil,
        payerContributionsJSON: String = "",
        sharedSessionId: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.category = category.rawValue
        self.note = note
        self.sharedSessionId = sharedSessionId
        self.executorId = executorId
        self.recordedByHumanId = recordedByHumanId
        self.payerContributionsJSON = payerContributionsJSON
        self.pet = pet
    }

    var expenseCategory: ExpenseCategory {
        ExpenseCategory(rawValue: category) ?? .other
    }

    var payerContributions: [ExpensePayerContribution] {
        ExpensePayerContributionPolicy.effectiveContributions(
            raw: payerContributionsJSON,
            executorID: executorId,
            total: amount
        )
    }

    var payerIDs: [String] {
        payerContributions.compactMap { $0.humanID?.uuidString }
    }

    func amountPaid(by humanID: String) -> Double {
        payerContributions
            .filter { $0.humanID?.uuidString == humanID }
            .reduce(0) { $0 + $1.amount }
    }

    func setPayerContributions(_ contributions: [ExpensePayerContribution]) {
        payerContributionsJSON = ExpensePayerContributionPolicy.encode(contributions)
        if let primary = contributions.compactMap(\.humanID).first {
            executorId = primary.uuidString
        }
    }

    @discardableResult
    func anonymizePayer(_ humanID: UUID) -> Bool {
        guard payerContributionsJSON.localizedCaseInsensitiveContains(humanID.uuidString) else {
            return false
        }
        guard let decoded = ExpensePayerContributionPolicy.decode(payerContributionsJSON),
              decoded.contains(where: { $0.humanID == humanID }),
              let anonymized = try? ExpensePayerContributionPolicy.anonymized(
                  decoded,
                  removing: humanID,
                  total: amount
              ) else {
            // Fail closed if a locally corrupt snapshot still contains the
            // deleted identifier. Keep the snapshot structured so reads do
            // not reattribute the whole bill to the legacy primary payer.
            if let totalUnits = ExpensePayerContributionPolicy.minorUnits(amount), totalUnits > 0 {
                payerContributionsJSON = ExpensePayerContributionPolicy.encode([
                    ExpensePayerContribution(humanID: nil, minorUnits: totalUnits)
                ])
            } else {
                payerContributionsJSON = "{}"
            }
            executorId = nil
            return true
        }
        payerContributionsJSON = ExpensePayerContributionPolicy.encode(anonymized)
        executorId = anonymized.compactMap(\.humanID).first?.uuidString
        return true
    }
}
