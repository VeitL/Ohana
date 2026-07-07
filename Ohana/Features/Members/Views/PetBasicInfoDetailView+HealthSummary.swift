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

struct PetProfileVaccineSummary: Equatable {
    let name: String
    let date: Date
    let expirationDate: Date?
}

struct PetProfileMedicationSummary: Equatable {
    let name: String
    let dosage: String
}

struct PetProfileSymptomSummary: Equatable {
    let name: String
    let severity: SymptomSeverity
}

struct PetProfileInsuranceSummary: Equatable {
    let name: String
    let daysUntilRenewal: Int
}

struct PetBasicInfoHealthSummary: Equatable {
    var vaccine: PetProfileVaccineSummary?
    var activeMedications: [PetProfileMedicationSummary] = []
    var recentSymptoms: [PetProfileSymptomSummary] = []
    var insurance: PetProfileInsuranceSummary?
    var latestWeight: PetProfileLatestWeight?

    static let empty = PetBasicInfoHealthSummary()

    @MainActor
    static func load(petID: UUID, context: ModelContext, now: Date = Date()) -> PetBasicInfoHealthSummary {
        PetBasicInfoHealthSummary(
            vaccine: vaccineSummary(petID: petID, context: context),
            activeMedications: activeMedicationSummary(petID: petID, context: context, now: now),
            recentSymptoms: recentSymptomSummary(petID: petID, context: context),
            insurance: insuranceSummary(petID: petID, context: context),
            latestWeight: latestWeight(petID: petID, context: context)
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
    private static func vaccineSummary(petID: UUID, context: ModelContext) -> PetProfileVaccineSummary? {
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
            guard let latest = try context.fetch(descriptor).first else { return nil }
            return PetProfileVaccineSummary(
                name: latest.note,
                date: latest.date,
                expirationDate: latest.expirationDate
            )
        } catch {
            OhanaLog.warning(
                "Pet profile vaccine summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return nil
        }
    }

    @MainActor
    private static func activeMedicationSummary(petID: UUID, context: ModelContext, now: Date) -> [PetProfileMedicationSummary] {
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
            return medications.prefix(3)
                .map { PetProfileMedicationSummary(name: $0.name, dosage: $0.dosage) }
        } catch {
            OhanaLog.warning(
                "Pet profile medication summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }

    @MainActor
    private static func recentSymptomSummary(petID: UUID, context: ModelContext) -> [PetProfileSymptomSummary] {
        var descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        do {
            let recent = try context.fetch(descriptor)
            return recent
                .map { PetProfileSymptomSummary(name: $0.symptomName, severity: $0.severity) }
        } catch {
            OhanaLog.warning(
                "Pet profile symptom summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }

    @MainActor
    private static func insuranceSummary(petID: UUID, context: ModelContext) -> PetProfileInsuranceSummary? {
        var descriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { insurance in
                insurance.pet?.id == petID &&
                    insurance.isActive
            },
            sortBy: [SortDescriptor(\.renewalDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            guard let first = try context.fetch(descriptor).first else { return nil }
            return PetProfileInsuranceSummary(
                name: first.productName.isEmpty ? first.companyName : first.productName,
                daysUntilRenewal: first.daysUntilRenewal
            )
        } catch {
            OhanaLog.warning(
                "Pet profile insurance summary fetch failed: \(error.localizedDescription)",
                category: "Members"
            )
            return nil
        }
    }
}

extension PetBasicInfoHealthSummary {
    func localizedVaccineSummary(l: L10n) -> String {
        guard let vaccine else {
            return l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag")
        }
        let name = vaccine.name.isEmpty ? l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung") : vaccine.name
        if let expirationDate = vaccine.expirationDate {
            return l.tr(
                zh: "\(name) · 有效至 \(expirationDate.formatted(.dateTime.year().month().day()))",
                en: "\(name) · valid until \(expirationDate.formatted(.dateTime.year().month().day()))",
                de: "\(name) · gültig bis \(expirationDate.formatted(.dateTime.year().month().day()))"
            )
        }
        return "\(name) · \(vaccine.date.formatted(.dateTime.year().month().day()))"
    }

    func localizedMedicationSummary(l: L10n) -> String {
        guard !activeMedications.isEmpty else {
            return l.tr(zh: "无进行中用药", en: "No active medication", de: "Keine aktive Medikation")
        }
        return activeMedications
            .map { medication in
                let name = medication.name.isEmpty ? l.tr(zh: "未命名药品", en: "Unnamed medicine", de: "Unbenanntes Medikament") : medication.name
                let dosage = medication.dosage.isEmpty ? l.tr(zh: "按医嘱", en: "As directed", de: "Nach Anweisung") : medication.dosage
                return l.tr(zh: "\(name)（\(dosage)）", en: "\(name) (\(dosage))", de: "\(name) (\(dosage))")
            }
            .joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
    }

    func localizedSymptomSummary(l: L10n) -> String {
        guard !recentSymptoms.isEmpty else {
            return l.tr(zh: "近况无症状记录", en: "No recent symptom records", de: "Keine aktuellen Symptome")
        }
        return recentSymptoms
            .map { symptom in
                let severity = symptom.severity.localizedLabel(l)
                let name = symptom.name.isEmpty ? severity : symptom.name
                return l.tr(zh: "\(name)（\(severity)）", en: "\(name) (\(severity))", de: "\(name) (\(severity))")
            }
            .joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
    }

    func localizedInsuranceSummary(l: L10n) -> String {
        guard let insurance else {
            return l.tr(zh: "未登记保险", en: "No insurance registered", de: "Keine Versicherung hinterlegt")
        }
        let name = insurance.name.isEmpty ? l.tr(zh: "保险", en: "Insurance", de: "Versicherung") : insurance.name
        return "\(name) · \(localizedRenewalStatus(daysUntilRenewal: insurance.daysUntilRenewal, l: l))"
    }

    func localizedWeightSummary(l: L10n) -> String {
        latestWeight?.compactText() ?? l.tr(zh: "未记录体重", en: "No weight recorded", de: "Kein Gewicht erfasst")
    }

    private func localizedRenewalStatus(daysUntilRenewal: Int, l: L10n) -> String {
        if daysUntilRenewal < 0 {
            return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
        if daysUntilRenewal <= 30 {
            return l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig")
        }
        return l.tr(zh: "保障中", en: "Covered", de: "Aktiv")
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
                Text(l.tr(zh: "就诊卡片", en: "Vet visit card", de: "Tierarztkarte"))
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
                    .accessibilityLabel(l.tr(zh: "就诊摘要准备中", en: "Vet summary is being prepared", de: "Tierarztzusammenfassung wird vorbereitet"))
                }
            }

            VStack(spacing: 8) {
                compactSummaryRow(l.tr(zh: "疫苗", en: "Vaccines", de: "Impfungen"), vaccineSummaryText)
                compactSummaryRow(l.tr(zh: "过敏", en: "Allergies", de: "Allergien"), pet.allergies.isEmpty ? l.tr(zh: "无记录", en: "No records", de: "Keine Eintraege") : pet.allergies)
                compactSummaryRow(l.tr(zh: "用药中", en: "Medication", de: "Medikation"), activeMedicationSummaryText)
                compactSummaryRow(l.tr(zh: "近期症状", en: "Recent symptoms", de: "Aktuelle Symptome"), recentSymptomSummaryText)
                compactSummaryRow(l.tr(zh: "保险", en: "Insurance", de: "Versicherung"), insuranceSummaryText)
                compactSummaryRow(l.tr(zh: "最近体重", en: "Latest weight", de: "Letztes Gewicht"), recentWeightSummaryText)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    var vetVisitSummaryShareLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.and.arrow.up") // a11y: allow decorative icon covered by surrounding text or control
            Text(l.tr(zh: "给兽医", en: "For vet", de: "Fuer Tierarzt"))
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
        healthSummary.localizedVaccineSummary(l: l)
    }

    var activeMedicationSummaryText: String {
        healthSummary.localizedMedicationSummary(l: l)
    }

    var recentSymptomSummaryText: String {
        healthSummary.localizedSymptomSummary(l: l)
    }

    var insuranceSummaryText: String {
        healthSummary.localizedInsuranceSummary(l: l)
    }

    var recentWeightSummaryText: String {
        healthSummary.localizedWeightSummary(l: l)
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
        let speciesBreed = Pet.localizedSpeciesBreedSummary(species: pet.species, breed: pet.breed, l: l)
        let ageText = pet.hasPassedAway
            ? pet.ageAtPassingText
            : pet.birthday.map { pet.localizedAgeTextForWallet(birthday: $0, l: l) } ?? l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")
        let allergies = pet.allergies.isEmpty ? l.tr(zh: "无记录", en: "No record", de: "Kein Eintrag") : pet.allergies
        let microchip = pet.microchipID.isEmpty ? l.tr(zh: "未登记", en: "Not registered", de: "Nicht registriert") : pet.microchipID
        return l.tr(
            zh: """
            \(pet.name) 就诊摘要
            物种/品种：\(speciesBreed.isEmpty ? "未填写" : speciesBreed)
            年龄：\(ageText)
            过敏：\(allergies)
            疫苗：\(vaccineSummaryText)
            用药中：\(activeMedicationSummaryText)
            近期症状：\(recentSymptomSummaryText)
            保险：\(insuranceSummaryText)
            最近体重：\(recentWeightSummaryText)
            芯片号：\(microchip)
            """,
            en: """
            \(pet.name) vet visit summary
            Species/Breed: \(speciesBreed.isEmpty ? "Not set" : speciesBreed)
            Age: \(ageText)
            Allergies: \(allergies)
            Vaccines: \(vaccineSummaryText)
            Active medication: \(activeMedicationSummaryText)
            Recent symptoms: \(recentSymptomSummaryText)
            Insurance: \(insuranceSummaryText)
            Latest weight: \(recentWeightSummaryText)
            Microchip: \(microchip)
            """,
            de: """
            \(pet.name) Tierarzt-Zusammenfassung
            Art/Rasse: \(speciesBreed.isEmpty ? "Nicht festgelegt" : speciesBreed)
            Alter: \(ageText)
            Allergien: \(allergies)
            Impfungen: \(vaccineSummaryText)
            Aktive Medikamente: \(activeMedicationSummaryText)
            Aktuelle Symptome: \(recentSymptomSummaryText)
            Versicherung: \(insuranceSummaryText)
            Letztes Gewicht: \(recentWeightSummaryText)
            Mikrochip: \(microchip)
            """
        )
    }
}
