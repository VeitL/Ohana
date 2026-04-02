//
//  PetInsurance.swift
//  Ohana
//
//  ArkSchemaV25：宠物保险记录模型
//

import SwiftData
import Foundation

@Model
final class PetInsurance {
    var id: UUID
    var companyName: String           // 保险公司
    var policyNumber: String          // 保单号
    var productName: String           // 产品名称（如"平安宠物险"）
    var annualPremium: Double         // 年费（元）
    var coverageAmount: Double        // 保额（元）
    var startDate: Date               // 生效日期
    var renewalDate: Date             // 续期日期
    var notes: String                 // 备注（承保范围、排除项等）
    var isActive: Bool
    var createdAt: Date
    var paymentFrequencyRaw: String   // ArkSchemaV30: InsurancePaymentFrequency.rawValue，默认"按年"
    // ArkSchemaV31：必须在属性上写默认值，否则旧库轻量迁移会失败 → 容器回退内存库、数据「丢失」
    var paymentDayOfMonth: Int = 1
    var showInCalendar: Bool = false
    var otherFeeAmount: Double = 0
    var otherFeeNote: String = ""
    // ArkSchemaV32：首期保费缴费日（可选）
    var firstPremiumPaymentDate: Date? = nil

    @Relationship(inverse: \Pet.insurances) var pet: Pet?
    @Relationship(deleteRule: .cascade) var claims: [InsuranceClaim]  // ArkSchemaV30

    init(
        companyName: String = "",
        policyNumber: String = "",
        productName: String = "",
        annualPremium: Double = 0,
        coverageAmount: Double = 0,
        startDate: Date = Date(),
        renewalDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
        notes: String = "",
        paymentFrequency: InsurancePaymentFrequency = .annual,
        paymentDayOfMonth: Int = 1,
        showInCalendar: Bool = false,
        otherFeeAmount: Double = 0,
        otherFeeNote: String = "",
        firstPremiumPaymentDate: Date? = nil,
        pet: Pet? = nil
    ) {
        self.id = UUID()
        self.companyName = companyName
        self.policyNumber = policyNumber
        self.productName = productName
        self.annualPremium = annualPremium
        self.coverageAmount = coverageAmount
        self.startDate = startDate
        self.renewalDate = renewalDate
        self.notes = notes
        self.isActive = true
        self.createdAt = Date()
        self.paymentFrequencyRaw = paymentFrequency.rawValue
        self.paymentDayOfMonth = max(1, min(28, paymentDayOfMonth))
        self.showInCalendar = showInCalendar
        self.otherFeeAmount = otherFeeAmount
        self.otherFeeNote = otherFeeNote
        self.firstPremiumPaymentDate = firstPremiumPaymentDate
        self.claims = []
        self.pet = pet
    }

    var paymentFrequency: InsurancePaymentFrequency {
        InsurancePaymentFrequency(rawValue: paymentFrequencyRaw) ?? .annual
    }

    /// 每期保费（不含其他费用）
    var premiumPerPeriod: Double {
        paymentFrequency.periodAmount(fromAnnual: annualPremium)
    }

    /// 每期总费用（保费 + 其他费用）
    var totalPerPeriod: Double {
        premiumPerPeriod + otherFeeAmount
    }

    /// 已批准报销总额
    var totalApprovedReimbursement: Double {
        claims.filter { $0.claimStatus == .approved }.reduce(0) { $0 + $1.approvedAmount }
    }

    /// 距续期还剩天数（负数表示已过期）
    var daysUntilRenewal: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: renewalDate).day ?? 0
    }

    var renewalStatusLabel: String {
        let d = daysUntilRenewal
        if d < 0    { return "已过期" }
        if d <= 30  { return "即将到期" }
        return "保障中"
    }

    var renewalStatusColor: String {
        let d = daysUntilRenewal
        if d < 0   { return "FF6B6B" }
        if d <= 30 { return "FFD93D" }
        return "4ECDC4"
    }
}
