//
//  PetVetSummaryPDFView.swift
//  Ohana
//
//  任务五：兽医档案 PDF 导出 — A4 优化的只读 SwiftUI 视图 + ImageRenderer 渲染
//

import SwiftData
import SwiftUI

// MARK: - PDF Snapshot
struct PetVetSummaryPDFSnapshot: Equatable {
    struct HealthRow: Identifiable, Equatable {
        let id: UUID
        let date: Date
        let type: String
        let note: String
        let expirationDate: Date?
    }

    struct MedicationRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        let dosage: String
    }

    struct SymptomRow: Identifiable, Equatable {
        let id: UUID
        let date: Date
        let symptomName: String
        let severityLabel: String
    }

    struct InsuranceRow: Identifiable, Equatable {
        let id: UUID
        let companyName: String
        let productName: String
        let policyNumber: String
        let renewalStatusLabel: String
    }

    struct DocumentRow: Identifiable, Equatable {
        let id: UUID
        let title: String
        let category: String
        let expiryDate: Date?
    }

    struct WeightPoint: Identifiable, Equatable {
        let id: String
        let date: Date
        let weightKg: Double
    }

    let petID: UUID
    let name: String
    let species: String
    let breed: String
    let genderSymbol: String
    let ageText: String
    let homeDate: Date?
    let microchipID: String
    let allergies: String
    let notes: String
    let avatarImageData: Data?
    let avatarEmoji: String
    let themeColorHex: String
    let recentHealthLogs: [HealthRow]
    let activeMedications: [MedicationRow]
    let recentSymptoms: [SymptomRow]
    let activeInsurance: InsuranceRow?
    let keyDocuments: [DocumentRow]
    let latestWeightKg: Double?
    let weightPoints3Mo: [WeightPoint]
    let languageCode: String

    var latestWeightText: String {
        let l = L10n(languageCode)
        return latestWeightKg.map { String(format: "%.1f kg", $0) } ?? l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag")
    }

    @MainActor
    static func load(pet: Pet, context: ModelContext, now: Date = Date()) -> PetVetSummaryPDFSnapshot {
        let petID = pet.id
        let languageCode = AppLanguage.code
        let l = L10n(languageCode)
        let healthRows = fetchRecentHealthRows(petID: petID, context: context, l: l)
        let medicationRows = fetchActiveMedicationRows(petID: petID, context: context, now: now)
        let symptomRows = fetchRecentSymptomRows(petID: petID, context: context, l: l)
        let insuranceRow = fetchActiveInsuranceRow(petID: petID, context: context, l: l)
        let documentRows = fetchKeyDocumentRows(petID: petID, context: context, l: l)
        let latestWeightKg = fetchLatestWeightKg(petID: petID, context: context)
        let weightPoints = fetchWeightPoints3Mo(petID: petID, context: context, now: now)

        return PetVetSummaryPDFSnapshot(
            petID: petID,
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            genderSymbol: pet.genderSymbol,
            ageText: pet.ageText,
            homeDate: pet.homeDate,
            microchipID: pet.microchipID,
            allergies: pet.allergies,
            notes: pet.notes,
            avatarImageData: pet.hasAvatarImageAttachment ? pet.avatarImageData : nil,
            avatarEmoji: pet.avatarEmoji,
            themeColorHex: pet.safeThemeColorHex,
            recentHealthLogs: healthRows,
            activeMedications: medicationRows,
            recentSymptoms: symptomRows,
            activeInsurance: insuranceRow,
            keyDocuments: documentRows,
            latestWeightKg: latestWeightKg,
            weightPoints3Mo: weightPoints,
            languageCode: languageCode
        )
    }

    @MainActor
    private static func fetchRecentHealthRows(petID: UUID, context: ModelContext, l: L10n) -> [HealthRow] {
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        do {
            return try context.fetch(descriptor).map {
                HealthRow(
                    id: $0.id,
                    date: $0.date,
                    type: $0.healthLogType.localizedLabel(l),
                    note: $0.note,
                    expirationDate: $0.expirationDate
                )
            }
        } catch {
            OhanaLog.warning("Vet PDF health fetch failed: \(error.localizedDescription)", category: "Documents")
            return []
        }
    }

    @MainActor
    private static func fetchActiveMedicationRows(petID: UUID, context: ModelContext, now: Date) -> [MedicationRow] {
        var descriptor = FetchDescriptor<PetMedication>(
            predicate: #Predicate<PetMedication> { medication in
                medication.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 24
        do {
            return try context.fetch(descriptor)
                .filter { $0.isActive(on: now) }
                .map { MedicationRow(id: $0.id, name: $0.name, dosage: $0.dosage) }
        } catch {
            OhanaLog.warning("Vet PDF medication fetch failed: \(error.localizedDescription)", category: "Documents")
            return []
        }
    }

    @MainActor
    private static func fetchRecentSymptomRows(petID: UUID, context: ModelContext, l: L10n) -> [SymptomRow] {
        var descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { symptom in
                symptom.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        do {
            return try context.fetch(descriptor).map {
                SymptomRow(id: $0.id, date: $0.date, symptomName: $0.symptomName, severityLabel: $0.severity.localizedLabel(l))
            }
        } catch {
            OhanaLog.warning("Vet PDF symptom fetch failed: \(error.localizedDescription)", category: "Documents")
            return []
        }
    }

    @MainActor
    private static func fetchActiveInsuranceRow(petID: UUID, context: ModelContext, l: L10n) -> InsuranceRow? {
        var descriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { insurance in
                insurance.pet?.id == petID && insurance.isActive
            },
            sortBy: [SortDescriptor(\.renewalDate)]
        )
        descriptor.fetchLimit = 1
        do {
            guard let insurance = try context.fetch(descriptor).first else { return nil }
            return InsuranceRow(
                id: insurance.id,
                companyName: insurance.companyName,
                productName: insurance.productName,
                policyNumber: insurance.policyNumber,
                renewalStatusLabel: renewalStatusLabel(for: insurance, l: l)
            )
        } catch {
            OhanaLog.warning("Vet PDF insurance fetch failed: \(error.localizedDescription)", category: "Documents")
            return nil
        }
    }

    @MainActor
    private static func fetchKeyDocumentRows(petID: UUID, context: ModelContext, l: L10n) -> [DocumentRow] {
        let descriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> { document in
                document.pet?.id == petID
            }
        )
        do {
            return try context.fetch(descriptor)
                .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
                .prefix(3)
                .map {
                    DocumentRow(id: $0.id, title: $0.title, category: $0.documentCategory.localizedLabel(l), expiryDate: $0.expiryDate)
                }
        } catch {
            OhanaLog.warning("Vet PDF document fetch failed: \(error.localizedDescription)", category: "Documents")
            return []
        }
    }

    @MainActor
    private static func fetchLatestWeightKg(petID: UUID, context: ModelContext) -> Double? {
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
            return try context.fetch(descriptor).first { $0.amountValue > 0 }?.amountValue
        } catch {
            OhanaLog.warning("Vet PDF latest weight fetch failed: \(error.localizedDescription)", category: "Documents")
            return nil
        }
    }

    @MainActor
    private static func fetchWeightPoints3Mo(petID: UUID, context: ModelContext, now: Date) -> [WeightPoint] {
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        let subjectID = petID.uuidString
        let weightKind = CareLedgerEventKind.weight.rawValue
        let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubjectKind &&
                    event.subjectId == subjectID &&
                    event.eventKind == weightKind &&
                    event.occurredAt >= cutoff
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        descriptor.fetchLimit = 128
        do {
            return try context.fetch(descriptor)
                .filter { $0.amountValue > 0 }
                .map { WeightPoint(id: $0.id.uuidString, date: $0.occurredAt, weightKg: $0.amountValue) }
        } catch {
            OhanaLog.warning("Vet PDF weight trend fetch failed: \(error.localizedDescription)", category: "Documents")
            return []
        }
    }

    private static func renewalStatusLabel(for insurance: PetInsurance, l: L10n) -> String {
        let days = insurance.daysUntilRenewal
        if days < 0 {
            return l.tr(zh: "已过期", en: "Expired", de: "Abgelaufen")
        }
        if days <= 30 {
            return l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig")
        }
        return l.tr(zh: "保障中", en: "Covered", de: "Aktiv")
    }
}

// MARK: - PDF 渲染入口
@MainActor
enum PetVetSummaryPDFRenderer {
    /// 渲染 PetVetSummaryPDFView 为 PDF 文件，返回临时文件 URL
    static func render(pet: Pet, context: ModelContext) async -> URL? {
        let snapshot = PetVetSummaryPDFSnapshot.load(pet: pet, context: context)
        let view = PetVetSummaryPDFView(snapshot: snapshot)
            .frame(width: 595, height: 842) // A4 @ 72 dpi
            .background(Color.white) // ui-v4: allow PDF export uses white paper

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // Retina

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(pet.name)_\(Self.localizedFilenameStem())_\(Self.datestamp()).pdf")

        // iOS 16+ native PDF rendering via ImageRenderer
        renderer.render { size, context in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let pdfCtx = CGContext(tmpURL as CFURL, mediaBox: &mediaBox, nil) else { return }
            pdfCtx.beginPDFPage(nil)
            context(pdfCtx)
            pdfCtx.endPDFPage()
            pdfCtx.closePDF()
        }

        return FileManager.default.fileExists(atPath: tmpURL.path) ? tmpURL : nil
    }

    private static func datestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }

    private static func localizedFilenameStem() -> String {
        L10n(AppLanguage.code).tr(zh: "兽医档案", en: "VetSummary", de: "Tierarztakte")
    }
}

// MARK: - A4 PDF 内容视图
struct PetVetSummaryPDFView: View {
    let snapshot: PetVetSummaryPDFSnapshot

    private var themeColor: Color { Color(hex: snapshot.themeColorHex) }
    private var l: L10n { L10n(snapshot.languageCode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header 条
            pdfHeader
            // ── 基础信息
            pdfBasicInfo.padding(.horizontal, 24).padding(.top, 16)
            // ── 分割线
            pdfDivider
            // ── 过敏 & 备注
            pdfAllergyNotes.padding(.horizontal, 24).padding(.top, 12)
            // ── 分割线
            pdfDivider
            // ── 健康记录表
            pdfHealthLogsTable.padding(.horizontal, 24).padding(.top, 12)
            // ── 分割线
            if !snapshot.weightPoints3Mo.isEmpty {
                pdfDivider
                // ── 3 个月体重图
                pdfWeightChart.padding(.horizontal, 24).padding(.top, 12)
            }
            Spacer()
            // ── Footer
            pdfFooter.padding(.horizontal, 24).padding(.bottom, 12)
        }
        .frame(width: 595, height: 842)
        .background(Color.white) // ui-v4: allow PDF export uses white paper
    }

    // MARK: - Header
    private var pdfHeader: some View {
        HStack(spacing: 14) {
            // 头像
            PetAvatarPortraitView(
                imageData: snapshot.avatarImageData,
                fallbackText: snapshot.avatarEmoji,
                themeColor: themeColor,
                size: 56,
                backgroundOpacity: 0.15
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.name)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A2E"))
                Text("\(snapshot.species) · \(snapshot.breed.isEmpty ? l.tr(zh: "未知品种", en: "Unknown breed", de: "Unbekannte Rasse") : snapshot.breed) · \(snapshot.genderSymbol)")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.gray.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(l.tr(zh: "兽医档案", en: "Vet summary", de: "Tierarztakte"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(themeColor)
                Text(Date().formatted(.dateTime.year().month().day()))
                    .font(OhanaFont.adaptive(size: 10, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.6))
                Text("Ohana App")
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(themeColor.opacity(0.08))
    }

    // MARK: - 基础信息
    private var pdfBasicInfo: some View {
        let cols: [(String, String)] = [
            (l.tr(zh: "年龄", en: "Age", de: "Alter"), snapshot.ageText.isEmpty ? l.tr(zh: "未知", en: "Unknown", de: "Unbekannt") : snapshot.ageText),
            (l.tr(zh: "体重", en: "Weight", de: "Gewicht"), snapshot.latestWeightText),
            (l.tr(zh: "归家日期", en: "Home date", de: "Einzug"), snapshot.homeDate.map { $0.formatted(.dateTime.year().month().day()) } ?? l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")),
            (l.tr(zh: "芯片号", en: "Microchip", de: "Chipnummer"), snapshot.microchipID.isEmpty ? l.tr(zh: "未登记", en: "Not registered", de: "Nicht eingetragen") : snapshot.microchipID)
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text(l.tr(zh: "基础信息", en: "Basic info", de: "Basisdaten"))
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 6) {
                ForEach(cols, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(OhanaFont.adaptive(size: 9, weight: .semibold)).foregroundStyle(.gray.opacity(0.6))
                        Text(value)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold)).foregroundStyle(Color(hex: "1A1A2E"))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: OhanaRadius.icon))
                }
            }
        }
    }

    // MARK: - 过敏 & 备注
    private var pdfAllergyNotes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.tr(zh: "就诊速览", en: "Vet visit overview", de: "Tierarzt-Überblick"))
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                pdfSummaryCell(l.tr(zh: "过敏史", en: "Allergies", de: "Allergien"), snapshot.allergies.isEmpty ? l.tr(zh: "无记录", en: "No record", de: "Kein Eintrag") : snapshot.allergies)
                pdfSummaryCell(l.tr(zh: "用药中", en: "Active medication", de: "Aktive Medikation"), medicationSummaryText)
                pdfSummaryCell(l.tr(zh: "最近症状", en: "Recent symptoms", de: "Aktuelle Symptome"), symptomSummaryText)
                pdfSummaryCell(l.tr(zh: "保险", en: "Insurance", de: "Versicherung"), insuranceSummaryText)
                pdfSummaryCell(l.tr(zh: "关键文档", en: "Key documents", de: "Wichtige Dokumente"), documentSummaryText)
                pdfSummaryCell(l.tr(zh: "备注", en: "Notes", de: "Notizen"), snapshot.notes.isEmpty ? l.tr(zh: "暂无备注", en: "No notes", de: "Keine Notizen") : snapshot.notes)
            }
        }
    }

    private func pdfSummaryCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(OhanaFont.adaptive(size: 8, weight: .semibold))
                .foregroundStyle(.gray.opacity(0.65))
            Text(value)
                .font(OhanaFont.adaptive(size: 9.5, weight: .medium))
                .foregroundStyle(Color(hex: "1A1A2E").opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
        .padding(7)
        .background(Color.gray.opacity(0.045), in: RoundedRectangle(cornerRadius: OhanaRadius.icon))
    }

    private var medicationSummaryText: String {
        guard !snapshot.activeMedications.isEmpty else { return l.tr(zh: "无进行中用药", en: "No active medication", de: "Keine aktive Medikation") }
        return snapshot.activeMedications.prefix(3)
            .map { "\($0.name.isEmpty ? l.tr(zh: "未命名药品", en: "Unnamed medication", de: "Unbenanntes Medikament") : $0.name) · \($0.dosage.isEmpty ? l.tr(zh: "按医嘱", en: "As prescribed", de: "Nach Anweisung") : $0.dosage)" }
            .joined(separator: l.tr(zh: "；", en: "; ", de: "; "))
    }

    private var symptomSummaryText: String {
        guard !snapshot.recentSymptoms.isEmpty else { return l.tr(zh: "近况无症状记录", en: "No recent symptom records", de: "Keine aktuellen Symptome") }
        return snapshot.recentSymptoms
            .map { "\($0.symptomName)（\($0.severityLabel)，\($0.date.formatted(.dateTime.month().day()))）" }
            .joined(separator: l.tr(zh: "；", en: "; ", de: "; "))
    }

    private var insuranceSummaryText: String {
        guard let activeInsurance = snapshot.activeInsurance else { return l.tr(zh: "未登记保险", en: "No insurance", de: "Keine Versicherung") }
        let name = activeInsurance.productName.isEmpty
            ? (activeInsurance.companyName.isEmpty ? l.tr(zh: "保险", en: "Insurance", de: "Versicherung") : activeInsurance.companyName)
            : activeInsurance.productName
        let number = activeInsurance.policyNumber.isEmpty ? "" : " · \(activeInsurance.policyNumber)"
        return "\(name)\(number) · \(activeInsurance.renewalStatusLabel)"
    }

    private var documentSummaryText: String {
        guard !snapshot.keyDocuments.isEmpty else { return l.tr(zh: "未上传关键文档", en: "No key documents", de: "Keine wichtigen Dokumente") }
        return snapshot.keyDocuments.map { doc in
            let title = doc.title.isEmpty ? doc.category : doc.title
            if let expiry = doc.expiryDate {
                return l.tr(zh: "\(title) 至 \(expiry.formatted(.dateTime.year().month().day()))", en: "\(title) until \(expiry.formatted(.dateTime.year().month().day()))", de: "\(title) bis \(expiry.formatted(.dateTime.year().month().day()))")
            }
            return title
        }.joined(separator: l.tr(zh: "；", en: "; ", de: "; "))
    }

    // MARK: - 健康记录表
    private var pdfHealthLogsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.tr(zh: "近期健康记录（最近8条）", en: "Recent health records (latest 8)", de: "Aktuelle Gesundheitsdaten (letzte 8)"))
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)

            if snapshot.recentHealthLogs.isEmpty {
                Text(l.tr(zh: "暂无健康记录", en: "No health records", de: "Keine Gesundheitsdaten"))
                    .font(OhanaFont.adaptive(size: 11)).foregroundStyle(.gray.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    // 表头
                    HStack {
                        Text(l.tr(zh: "日期", en: "Date", de: "Datum")).frame(width: 80, alignment: .leading)
                        Text(l.tr(zh: "类型", en: "Type", de: "Typ")).frame(width: 100, alignment: .leading)
                        Text(l.tr(zh: "备注", en: "Notes", de: "Notizen")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(l.tr(zh: "有效期", en: "Expires", de: "Gültig bis")).frame(width: 90, alignment: .trailing)
                    }
                    .font(OhanaFont.adaptive(size: 9, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.gray.opacity(0.06))

                    ForEach(snapshot.recentHealthLogs) { log in
                        HStack {
                            Text(log.date.formatted(.dateTime.year().month().day()))
                                .frame(width: 80, alignment: .leading)
                            Text(log.type)
                                .frame(width: 100, alignment: .leading)
                            Text(log.note.isEmpty ? "—" : log.note)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            if let exp = log.expirationDate {
                                Text(exp.formatted(.dateTime.year().month().day()))
                                    .frame(width: 90, alignment: .trailing)
                            } else {
                                Text("—").frame(width: 90, alignment: .trailing)
                            }
                        }
                        .font(OhanaFont.adaptive(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "1A1A2E").opacity(0.8))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(snapshot.recentHealthLogs.firstIndex(where: { $0.id == log.id })?.isMultiple(of: 2) == true
                            ? Color.gray.opacity(0.025) : Color.clear)

                        Divider().opacity(0.3)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: OhanaRadius.icon)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.icon))
            }
        }
    }

    // MARK: - 3 个月体重图
    private var pdfWeightChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.tr(zh: "近3个月体重趋势", en: "Weight trend, last 3 months", de: "Gewichtstrend, 3 Monate"))
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)

            OhanaMinimalTrendChart(
                points: snapshot.weightPoints3Mo.map {
                    OhanaMinimalChartPoint(date: $0.date, value: $0.weightKg, id: $0.id)
                },
                tint: themeColor
            )
            .frame(height: 100)
        }
    }

    // MARK: - Divider
    private var pdfDivider: some View {
        Divider().opacity(0.3).padding(.horizontal, 24).padding(.top, 12)
    }

    // MARK: - Footer
    private var pdfFooter: some View {
        HStack {
            Text(l.tr(zh: "由 Ohana App 生成 · 仅供参考，非正式医疗文件", en: "Generated by Ohana App · For reference only, not an official medical document", de: "Erstellt von Ohana App · Nur zur Referenz, kein offizielles medizinisches Dokument"))
                .font(OhanaFont.adaptive(size: 8, weight: .medium))
                .foregroundStyle(.gray.opacity(0.4))
            Spacer()
            Text("ohana.app")
                .font(OhanaFont.adaptive(size: 8, weight: .semibold))
                .foregroundStyle(themeColor.opacity(0.5))
        }
    }
}

// MARK: - PDF 分享 Sheet
struct PetVetPDFShareSheet: View {
    let pdfURL: URL
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                VStack(spacing: 20) {
                    // 预览缩略图
                    ZStack {
                        RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                            .fill(Color.ohanaCardSurface)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                        VStack(spacing: 8) {
                            Image(systemName: "doc.richtext.fill").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 48))
                                .foregroundStyle(pet.themeColor.color.opacity(0.8))
                            Text("\(pet.name)_\(l.tr(zh: "兽医档案", en: "VetSummary", de: "Tierarztakte")).pdf")
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                            Text(l.tr(zh: "A4 · 兽医健康档案", en: "A4 · Vet health summary", de: "A4 · Tierarztakte"))
                                .font(OhanaFont.adaptive(size: 11))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 20)

                    // 分享按钮
                    ShareLink(item: pdfURL, subject: Text(l.tr(zh: "\(pet.name) 兽医档案", en: "\(pet.name) vet summary", de: "Tierarztakte von \(pet.name)")),
                              message: Text(l.tr(zh: "由 Ohana App 生成的宠物健康档案", en: "Pet health summary generated by Ohana App", de: "Mit Ohana App erstellte Gesundheitsakte"))) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 15, weight: .bold))
                            Text(l.tr(zh: "分享 / 保存 PDF", en: "Share / save PDF", de: "PDF teilen / sichern"))
                                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.black) // ui-v4: allow ink on PDF action preview
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(l.tr(zh: "导出健康档案", en: "Export health summary", de: "Gesundheitsakte exportieren"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) { dismiss() }
                }
            }
        }
    }
}
