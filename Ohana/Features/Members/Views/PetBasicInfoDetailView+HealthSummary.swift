//
//  PetBasicInfoDetailView+HealthSummary.swift
//  Ohana
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation

extension PetBasicInfoDetailView {
    var vetVisitSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goRed)
                Text("就诊卡片")
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                ShareLink(item: vetVisitSummaryText) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up") // a11y: allow decorative icon covered by surrounding text or control
                        Text("给兽医")
                    }
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.goPrimary, in: Capsule())
                }
            }

            VStack(spacing: 8) {
                compactSummaryRow("疫苗", vaccineSummaryText)
                compactSummaryRow("过敏", pet.allergies.isEmpty ? "无记录" : pet.allergies)
                compactSummaryRow("用药中", activeMedicationSummaryText)
                compactSummaryRow("近期症状", recentSymptomSummaryText)
                compactSummaryRow("保险", insuranceSummaryText)
                compactSummaryRow("最近体重", recentWeightSummaryText)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    func compactSummaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.46))
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    var vaccineSummaryText: String {
        let latest = pet.healthLogs
            .filter { $0.healthLogType == .vaccine }
            .sorted { $0.date > $1.date }
            .first
        guard let latest else { return "未记录" }
        let name = latest.note.isEmpty ? "疫苗" : latest.note
        if let expiry = latest.expirationDate {
            return "\(name) · 有效至 \(expiry.formatted(.dateTime.year().month().day()))"
        }
        return "\(name) · \(latest.date.formatted(.dateTime.year().month().day()))"
    }

    var activeMedicationSummaryText: String {
        let meds = pet.medications.filter(\.isActiveToday)
        guard !meds.isEmpty else { return "无进行中用药" }
        return meds.prefix(3)
            .map { "\($0.name.isEmpty ? "未命名药品" : $0.name)（\($0.dosage.isEmpty ? "按医嘱" : $0.dosage)）" }
            .joined(separator: "、")
    }

    var recentSymptomSummaryText: String {
        let recent = pet.symptomLogs
            .sorted { $0.date > $1.date }
            .prefix(3)
        guard !recent.isEmpty else { return "近况无症状记录" }
        return recent
            .map { "\($0.symptomName)（\($0.severity.label)）" }
            .joined(separator: "、")
    }

    var insuranceSummaryText: String {
        let active = pet.insurances.filter(\.isActive)
        guard let first = active.sorted(by: { $0.renewalDate < $1.renewalDate }).first else { return "未登记保险" }
        let name = first.productName.isEmpty ? (first.companyName.isEmpty ? "保险" : first.companyName) : first.productName
        return "\(name) · \(first.renewalStatusLabel)"
    }

    var recentWeightSummaryText: String {
        guard let latest = pet.weightLogs.sorted(by: { $0.date > $1.date }).first else { return "未记录体重" }
        let value = latest.weightUnit == "g"
            ? "\(Int(latest.weight))g"
            : String(format: "%.2fkg", latest.weight)
        return "\(value) · \(latest.date.formatted(.dateTime.year().month().day()))"
    }

    var vetVisitSummaryText: String {
        """
        \(pet.name) 就诊摘要
        物种/品种：\(pet.species) / \(pet.breed.isEmpty ? "未填写" : pet.breed)
        年龄：\(pet.ageText)
        过敏：\(pet.allergies.isEmpty ? "无记录" : pet.allergies)
        疫苗：\(vaccineSummaryText)
        用药中：\(activeMedicationSummaryText)
        近期症状：\(recentSymptomSummaryText)
        保险：\(insuranceSummaryText)
        最近体重：\(recentWeightSummaryText)
        芯片号：\(pet.microchipID.isEmpty ? "未登记" : pet.microchipID)
        """
    }
}
