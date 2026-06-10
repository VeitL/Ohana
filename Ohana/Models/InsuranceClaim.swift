//
//  InsuranceClaim.swift
//  Ohana
//
//  ArkSchemaV30：保险报销记录模型
//

import Foundation
import SwiftData

// MARK: - 付款频次枚举

enum InsurancePaymentFrequency: String, Codable, CaseIterable {
    case monthly = "按月"
    case quarterly = "按季"
    case annual = "按年"
    case once = "一次性"

    var displayIcon: String {
        switch self {
        case .monthly: "1️⃣"
        case .quarterly: "3️⃣"
        case .annual: "📅"
        case .once: "🔖"
        }
    }

    /// 每期保费 = annualPremium / 期数
    func periodAmount(fromAnnual annual: Double) -> Double {
        switch self {
        case .monthly: annual / 12
        case .quarterly: annual / 4
        case .annual: annual
        case .once: annual
        }
    }

    /// 对应的 Calendar.Component（用于生成下次扣款日期）
    var calendarComponent: Calendar.Component {
        switch self {
        case .monthly: .month
        case .quarterly: .month // value = 3
        case .annual: .year
        case .once: .year
        }
    }

    var componentValue: Int {
        switch self {
        case .quarterly: 3
        default: 1
        }
    }
}

// MARK: - 报销状态枚举

enum ClaimStatus: String, Codable, CaseIterable {
    case submitted = "已提交"
    case processing = "处理中"
    case approved = "已报销"
    case rejected = "已拒绝"

    var colorHex: String {
        switch self {
        case .submitted: "FFD93D"
        case .processing: "FF9F43"
        case .approved: "4ECDC4"
        case .rejected: "FF6B6B"
        }
    }

    var sfSymbol: String {
        switch self {
        case .submitted: "paperplane.fill"
        case .processing: "clock.fill"
        case .approved: "checkmark.seal.fill"
        case .rejected: "xmark.seal.fill"
        }
    }
}

// MARK: - InsuranceClaim 模型

@Model
final class InsuranceClaim {
    var id: UUID
    var claimDate: Date // 提交申请日期
    var incidentDate: Date // 就诊 / 事故日期
    var totalExpense: Double // 本次总花费（元）
    var claimedAmount: Double // 申请报销金额（元）
    var approvedAmount: Double // 实际到账金额（0 = 待处理）
    var statusRaw: String // ClaimStatus.rawValue
    var note: String
    var relatedExpenseLogId: String? // PetExpenseLog.id.uuidString（可选关联）
    var approvedAt: Date? // 审批完成日期
    var createdAt: Date

    @Relationship(inverse: \PetInsurance.claims) var insurance: PetInsurance?

    init(
        claimDate: Date = Date(),
        incidentDate: Date = Date(),
        totalExpense: Double = 0,
        claimedAmount: Double = 0,
        approvedAmount: Double = 0,
        status: ClaimStatus = .submitted,
        note: String = "",
        relatedExpenseLogId: String? = nil,
        insurance: PetInsurance? = nil
    ) {
        self.id = UUID()
        self.claimDate = claimDate
        self.incidentDate = incidentDate
        self.totalExpense = totalExpense
        self.claimedAmount = claimedAmount
        self.approvedAmount = approvedAmount
        self.statusRaw = status.rawValue
        self.note = note
        self.relatedExpenseLogId = relatedExpenseLogId
        self.approvedAt = nil
        self.createdAt = Date()
        self.insurance = insurance
    }

    var claimStatus: ClaimStatus {
        ClaimStatus(rawValue: statusRaw) ?? .submitted
    }

    /// 报销率（0–1）
    var reimbursementRate: Double {
        guard totalExpense > 0 else { return 0 }
        return approvedAmount / totalExpense
    }
}
