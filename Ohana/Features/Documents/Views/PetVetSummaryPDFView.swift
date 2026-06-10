//
//  PetVetSummaryPDFView.swift
//  Ohana
//
//  任务五：兽医档案 PDF 导出 — A4 优化的只读 SwiftUI 视图 + ImageRenderer 渲染
//

import SwiftUI

// MARK: - PDF 渲染入口
@MainActor
enum PetVetSummaryPDFRenderer {
    /// 渲染 PetVetSummaryPDFView 为 PDF 文件，返回临时文件 URL
    static func render(pet: Pet) async -> URL? {
        let view = PetVetSummaryPDFView(pet: pet)
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
    let pet: Pet

    private var themeColor: Color { pet.themeColor.color }
    private var recentHealthLogs: [PetHealthLog] {
        pet.healthLogs.sorted { $0.date > $1.date }.prefix(8).map { $0 }
    }
    private var activeMedications: [PetMedication] {
        pet.medications.filter(\.isActiveToday).sorted { $0.createdAt > $1.createdAt }
    }
    private var recentSymptoms: [SymptomLog] {
        pet.symptomLogs.sorted { $0.date > $1.date }.prefix(3).map { $0 }
    }
    private var activeInsurance: PetInsurance? {
        pet.insurances.filter(\.isActive).sorted { $0.renewalDate < $1.renewalDate }.first
    }
    private var keyDocuments: [PetDocument] {
        pet.documents
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
            .prefix(3)
            .map { $0 }
    }
    private var weightLogs3Mo: [PetWeightLog] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        return pet.weightLogs.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

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
            if !weightLogs3Mo.isEmpty {
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
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: themeColor,
                size: 56,
                backgroundOpacity: 0.15
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A2E"))
                Text("\(pet.species) · \(pet.breed.isEmpty ? "未知品种" : pet.breed) · \(pet.genderSymbol)")
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
            ("年龄", pet.ageText.isEmpty ? "未知" : pet.ageText),
            ("体重", pet.weightLogs.sorted { $0.date > $1.date }.first.map { String(format: "%.1f kg", $0.weight) } ?? "未记录"),
            ("归家日期", pet.homeDate.map { $0.formatted(.dateTime.year().month().day()) } ?? "未知"),
            ("芯片号", pet.microchipID.isEmpty ? "未登记" : pet.microchipID),
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
                    .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - 过敏 & 备注
    private var pdfAllergyNotes: some View {
        return VStack(alignment: .leading, spacing: 6) {
            Text("就诊速览")
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                pdfSummaryCell("过敏史", pet.allergies.isEmpty ? "无记录" : pet.allergies)
                pdfSummaryCell("用药中", medicationSummaryText)
                pdfSummaryCell("最近症状", symptomSummaryText)
                pdfSummaryCell("保险", insuranceSummaryText)
                pdfSummaryCell("关键文档", documentSummaryText)
                pdfSummaryCell("备注", pet.notes.isEmpty ? "暂无备注" : pet.notes)
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
        .background(Color.gray.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }

    private var medicationSummaryText: String {
        guard !activeMedications.isEmpty else { return "无进行中用药" }
        return activeMedications.prefix(3)
            .map { "\($0.name.isEmpty ? "未命名药品" : $0.name) · \($0.dosage.isEmpty ? "按医嘱" : $0.dosage)" }
            .joined(separator: "；")
    }

    private var symptomSummaryText: String {
        guard !recentSymptoms.isEmpty else { return "近况无症状记录" }
        return recentSymptoms
            .map { "\($0.symptomName)（\($0.severity.label)，\($0.date.formatted(.dateTime.month().day()))）" }
            .joined(separator: "；")
    }

    private var insuranceSummaryText: String {
        guard let activeInsurance else { return "未登记保险" }
        let name = activeInsurance.productName.isEmpty
            ? (activeInsurance.companyName.isEmpty ? "保险" : activeInsurance.companyName)
            : activeInsurance.productName
        let number = activeInsurance.policyNumber.isEmpty ? "" : " · \(activeInsurance.policyNumber)"
        return "\(name)\(number) · \(activeInsurance.renewalStatusLabel)"
    }

    private var documentSummaryText: String {
        guard !keyDocuments.isEmpty else { return "未上传关键文档" }
        return keyDocuments.map { doc in
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

            if recentHealthLogs.isEmpty {
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

                    ForEach(recentHealthLogs) { log in
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
                        .background(recentHealthLogs.firstIndex(where: { $0.id == log.id })?.isMultiple(of: 2) == true
                                    ? Color.gray.opacity(0.025) : Color.clear)

                        Divider().opacity(0.3)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - 3 个月体重图
    private var pdfWeightChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("近3个月体重趋势")
                .font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(.gray).tracking(1)

            OhanaMinimalTrendChart(
                points: weightLogs3Mo.map {
                    OhanaMinimalChartPoint(date: $0.date, value: $0.weight, id: $0.id.uuidString)
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
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
