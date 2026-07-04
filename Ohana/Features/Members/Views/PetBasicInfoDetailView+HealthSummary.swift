//
//  PetBasicInfoDetailView+HealthSummary.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

struct PetProfileLatestWeight: Equatable {
    let kg: Double
    let occurredAt: Date

    func compactText(fractionDigits: Int = 2, unitSpacing: String = "") -> String {
        let value = String(format: "%.\(fractionDigits)f\(unitSpacing)kg", kg)
        return "\(value) · \(occurredAt.formatted(.dateTime.year().month().day()))"
    }
}

struct PetBasicInfoHealthSummary: Equatable {
    var vaccineSummaryText: String = "未记录"
    var activeMedicationSummaryText: String = "无进行中用药"
    var recentSymptomSummaryText: String = "近况无症状记录"
    var insuranceSummaryText: String = "未登记保险"
    var recentWeightSummaryText: String = "未记录体重"
    var latestWeight: PetProfileLatestWeight?

    static let empty = PetBasicInfoHealthSummary()

    @MainActor
    static func load(petID: UUID, context: ModelContext, now: Date = Date()) -> PetBasicInfoHealthSummary {
        let latestWeight = latestWeight(petID: petID, context: context)
        return PetBasicInfoHealthSummary(
            vaccineSummaryText: vaccineSummary(petID: petID, context: context),
            activeMedicationSummaryText: activeMedicationSummary(petID: petID, context: context, now: now),
            recentSymptomSummaryText: recentSymptomSummary(petID: petID, context: context),
            insuranceSummaryText: insuranceSummary(petID: petID, context: context),
            recentWeightSummaryText: latestWeight?.compactText() ?? "未记录体重",
            latestWeight: latestWeight
        )
    }

    @MainActor
    static func latestWeight(petID: UUID, context: ModelContext) -> PetProfileLatestWeight? {
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        let subjectID = petID.uuidString
        let weightKind = CareLedgerEventKind.weight.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubjectKind &&
                    event.subjectId == subjectID &&
                    event.eventKind == weightKind
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        do {
            guard let event = try context.fetch(descriptor).first(where: { $0.amountValue > 0 }) else {
                return nil
            }
            return PetProfileLatestWeight(kg: event.amountValue, occurredAt: event.occurredAt)
        } catch {
            OhanaLog.warning(
                "Pet profile latest weight fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return nil
        }
    }

    @MainActor
    private static func vaccineSummary(petID: UUID, context: ModelContext) -> String {
        let vaccineType = HealthLogType.vaccine.rawValue
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { log in
                log.pet?.id == petID &&
                    log.type == vaccineType
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            guard let latest = try context.fetch(descriptor).first else { return "未记录" }
            let name = latest.note.isEmpty ? "疫苗" : latest.note
            if let expiry = latest.expirationDate {
                return "\(name) · 有效至 \(expiry.formatted(.dateTime.year().month().day()))"
            }
            return "\(name) · \(latest.date.formatted(.dateTime.year().month().day()))"
        } catch {
            OhanaLog.warning(
                "Pet profile vaccine summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return "未记录"
        }
    }

    @MainActor
    private static func activeMedicationSummary(petID: UUID, context: ModelContext, now: Date) -> String {
        var descriptor = FetchDescriptor<PetMedication>(
            predicate: #Predicate<PetMedication> { medication in
                medication.pet?.id == petID &&
                    medication.isActive
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 12
        do {
            let medications = try context.fetch(descriptor)
                .filter { $0.isActive(on: now) }
            guard !medications.isEmpty else { return "无进行中用药" }
            return medications.prefix(3)
                .map { "\($0.name.isEmpty ? "未命名药品" : $0.name)（\($0.dosage.isEmpty ? "按医嘱" : $0.dosage)）" }
                .joined(separator: "、")
        } catch {
            OhanaLog.warning(
                "Pet profile medication summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return "无进行中用药"
        }
    }

    @MainActor
    private static func recentSymptomSummary(petID: UUID, context: ModelContext) -> String {
        var descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        do {
            let recent = try context.fetch(descriptor)
            guard !recent.isEmpty else { return "近况无症状记录" }
            return recent
                .map { "\($0.symptomName)（\($0.severity.label)）" }
                .joined(separator: "、")
        } catch {
            OhanaLog.warning(
                "Pet profile symptom summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return "近况无症状记录"
        }
    }

    @MainActor
    private static func insuranceSummary(petID: UUID, context: ModelContext) -> String {
        var descriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { insurance in
                insurance.pet?.id == petID &&
                    insurance.isActive
            },
            sortBy: [SortDescriptor(\.renewalDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            guard let first = try context.fetch(descriptor).first else { return "未登记保险" }
            let name = first.productName.isEmpty ? (first.companyName.isEmpty ? "保险" : first.companyName) : first.productName
            return "\(name) · \(first.renewalStatusLabel)"
        } catch {
            OhanaLog.warning(
                "Pet profile insurance summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return "未登记保险"
        }
    }
}

extension PetBasicInfoDetailView {
    func scheduleHealthSummaryLoad() {
        healthSummaryLoadTask?.cancel()
        let petID = pet.id
        healthSummaryLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            healthSummary = PetBasicInfoHealthSummary.load(petID: petID, context: modelContext)
            healthSummaryLoadTask = nil
        }
    }

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
                if let preparedVetVisitSummaryText {
                    ShareLink(item: preparedVetVisitSummaryText) { // smoothness: allow prepared export payload built after visual handoff
                        vetVisitSummaryShareLabel
                    }
                } else {
                    Button {} label: {
                        vetVisitSummaryShareLabel
                    }
                    .disabled(true)
                    .accessibilityLabel("就诊摘要准备中")
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
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    var vetVisitSummaryShareLabel: some View {
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
        healthSummary.vaccineSummaryText
    }

    var activeMedicationSummaryText: String {
        healthSummary.activeMedicationSummaryText
    }

    var recentSymptomSummaryText: String {
        healthSummary.recentSymptomSummaryText
    }

    var insuranceSummaryText: String {
        healthSummary.insuranceSummaryText
    }

    var recentWeightSummaryText: String {
        healthSummary.recentWeightSummaryText
    }

    var vetVisitSummaryPreparationSignature: String {
        [
            pet.id.uuidString,
            pet.name,
            pet.species,
            pet.breed,
            pet.ageText,
            pet.allergies,
            pet.microchipID,
            vaccineSummaryText,
            activeMedicationSummaryText,
            recentSymptomSummaryText,
            insuranceSummaryText,
            recentWeightSummaryText
        ].joined(separator: "|")
    }

    @MainActor
    func prepareVetVisitSummaryText() async {
        preparedVetVisitSummaryText = nil
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        preparedVetVisitSummaryText = vetVisitSummaryText
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
