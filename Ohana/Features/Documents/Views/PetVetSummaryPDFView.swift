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

    var latestWeightText: String {
        latestWeightKg.map { String(format: "%.1f kg", $0) } ?? "未记录"
    }

    @MainActor
    static func load(pet: Pet, context: ModelContext, now: Date = Date()) -> PetVetSummaryPDFSnapshot {
        let petID = pet.id
        let healthRows = fetchRecentHealthRows(petID: petID, context: context)
        let medicationRows = fetchActiveMedicationRows(petID: petID, context: context, now: now)
        let symptomRows = fetchRecentSymptomRows(petID: petID, context: context)
        let insuranceRow = fetchActiveInsuranceRow(petID: petID, context: context)
        let documentRows = fetchKeyDocumentRows(petID: petID, context: context)
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
            avatarImageData: pet.avatarImageData,
            avatarEmoji: pet.avatarEmoji,
            themeColorHex: pet.safeThemeColorHex,
            recentHealthLogs: healthRows,
            activeMedications: medicationRows,
            recentSymptoms: symptomRows,
            activeInsurance: insuranceRow,
            keyDocuments: documentRows,
            latestWeightKg: latestWeightKg,
            weightPoints3Mo: weightPoints
        )
    }

    @MainActor
    private static func fetchRecentHealthRows(petID: UUID, context: ModelContext) -> [HealthRow] {
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { log in
                log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        do {
            return try context.fetch(descriptor).map {
                HealthRow(id: $0.id, date: $0.date, type: $0.type, note: $0.note, expirationDate: $0.expirationDate)
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
    private static func fetchRecentSymptomRows(petID: UUID, context: ModelContext) -> [SymptomRow] {
        var descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { symptom in
                symptom.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        do {
            return try context.fetch(descriptor).map {
                SymptomRow(id: $0.id, date: $0.date, symptomName: $0.symptomName, severityLabel: $0.severity.label)
            }
        } catch {
            OhanaLog.warning("Vet PDF symptom fetch failed: \(error.localizedDescription)", category: "Documents")
            return []
        }
    }

    @MainActor
    private static func fetchActiveInsuranceRow(petID: UUID, context: ModelContext) -> InsuranceRow? {
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
                renewalStatusLabel: insurance.renewalStatusLabel
            )
        } catch {
            OhanaLog.warning("Vet PDF insurance fetch failed: \(error.localizedDescription)", category: "Documents")
            return nil
        }
    }

    @MainActor
    private static func fetchKeyDocumentRows(petID: UUID, context: ModelContext) -> [DocumentRow] {
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
                    DocumentRow(id: $0.id, title: $0.title, category: $0.category, expiryDate: $0.expiryDate)
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
            .appendingPathComponent("\(pet.name)_兽医档案_\(Self.datestamp()).pdf")

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
}

// MARK: - A4 PDF 内容视图
struct PetVetSummaryPDFView: View {
    let snapshot: PetVetSummaryPDFSnapshot

    private var themeColor: Color { Color(hex: snapshot.themeColorHex) }

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
                Text("\(snapshot.species) · \(snapshot.breed.isEmpty ? "未知品种" : snapshot.breed) · \(snapshot.genderSymbol)")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.gray.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("兽医档案")
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
            ("年龄", snapshot.ageText.isEmpty ? "未知" : snapshot.ageText),
            ("体重", snapshot.latestWeightText),
            ("归家日期", snapshot.homeDate.map { $0.formatted(.dateTime.year().month().day()) } ?? "未知"),
            ("芯片号", snapshot.microchipID.isEmpty ? "未登记" : snapshot.microchipID)
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text("基础信息")
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
            Text("就诊速览")
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                pdfSummaryCell("过敏史", snapshot.allergies.isEmpty ? "无记录" : snapshot.allergies)
                pdfSummaryCell("用药中", medicationSummaryText)
                pdfSummaryCell("最近症状", symptomSummaryText)
                pdfSummaryCell("保险", insuranceSummaryText)
                pdfSummaryCell("关键文档", documentSummaryText)
                pdfSummaryCell("备注", snapshot.notes.isEmpty ? "暂无备注" : snapshot.notes)
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
        guard !snapshot.activeMedications.isEmpty else { return "无进行中用药" }
        return snapshot.activeMedications.prefix(3)
            .map { "\($0.name.isEmpty ? "未命名药品" : $0.name) · \($0.dosage.isEmpty ? "按医嘱" : $0.dosage)" }
            .joined(separator: "；")
    }

    private var symptomSummaryText: String {
        guard !snapshot.recentSymptoms.isEmpty else { return "近况无症状记录" }
        return snapshot.recentSymptoms
            .map { "\($0.symptomName)（\($0.severityLabel)，\($0.date.formatted(.dateTime.month().day()))）" }
            .joined(separator: "；")
    }

    private var insuranceSummaryText: String {
        guard let activeInsurance = snapshot.activeInsurance else { return "未登记保险" }
        let name = activeInsurance.productName.isEmpty
            ? (activeInsurance.companyName.isEmpty ? "保险" : activeInsurance.companyName)
            : activeInsurance.productName
        let number = activeInsurance.policyNumber.isEmpty ? "" : " · \(activeInsurance.policyNumber)"
        return "\(name)\(number) · \(activeInsurance.renewalStatusLabel)"
    }

    private var documentSummaryText: String {
        guard !snapshot.keyDocuments.isEmpty else { return "未上传关键文档" }
        return snapshot.keyDocuments.map { doc in
            let title = doc.title.isEmpty ? doc.category : doc.title
            if let expiry = doc.expiryDate {
                return "\(title) 至 \(expiry.formatted(.dateTime.year().month().day()))"
            }
            return title
        }.joined(separator: "；")
    }

    // MARK: - 健康记录表
    private var pdfHealthLogsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("近期健康记录（最近8条）")
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)

            if snapshot.recentHealthLogs.isEmpty {
                Text("暂无健康记录")
                    .font(OhanaFont.adaptive(size: 11)).foregroundStyle(.gray.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    // 表头
                    HStack {
                        Text("日期").frame(width: 80, alignment: .leading)
                        Text("类型").frame(width: 100, alignment: .leading)
                        Text("备注").frame(maxWidth: .infinity, alignment: .leading)
                        Text("有效期").frame(width: 90, alignment: .trailing)
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
            Text("近3个月体重趋势")
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
            Text("由 Ohana App 生成 · 仅供参考，非正式医疗文件")
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
                            Text("\(pet.name)_兽医档案.pdf")
                                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                            Text("A4 · 兽医健康档案")
                                .font(OhanaFont.adaptive(size: 11))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 20)

                    // 分享按钮
                    ShareLink(item: pdfURL, subject: Text("\(pet.name) 兽医档案"),
                              message: Text("由 Ohana App 生成的宠物健康档案")) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 15, weight: .bold))
                            Text("分享 / 保存 PDF")
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
            .navigationTitle("导出健康档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
