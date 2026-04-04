//
//  AddDocumentSheet.swift
//  Ohana
//
//  R10: 添加/编辑证件 — ArkBackgroundView + glassEffect 字段卡；导航栏磨砂；Sheet presentationBackground(.bar)
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 附件数据模型
private struct DocAttachment: Identifiable {
    let id = UUID()
    var data: Data
    var filename: String
    var isImage: Bool
}

struct AddDocumentSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @State private var title: String = ""
    @State private var selectedCategory: DocumentCategory = .other
    @State private var hasIssueDate = false
    @State private var issueDate: Date = Date()
    @State private var hasExpiryDate = false
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var issuingAuthority: String = ""
    @State private var notes: String = ""
    @State private var documentNumber: String = ""
    // B4: 多附件
    @State private var attachments: [DocAttachment] = []
    @State private var showingCamera = false
    @State private var showingFilePicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    // B4: 拍照暂存（避免 sheet dismiss 冲突）
    @State private var pendingCapturedImage: UIImage? = nil
    // F3: 附件预览
    @State private var previewAttachment: DocAttachment? = nil
    // N3: 所有类型都可记录花费
    @State private var costText: String = ""
    @State private var hasCost: Bool = false
    @State private var selectedPayerId: String? = nil
    // N2: 保险月付标记
    @State private var isMonthlyInsurance: Bool = false
    // B4: 自动预填名称
    private var autoTitle: String { "\(pet.name)\(selectedCategory.rawValue)" }
    private var showDocumentNumber: Bool { selectedCategory == .passport || selectedCategory == .registration }
    private var petThemeColor: Color {
        Color(hex: pet.themeColorHex.isEmpty ? "C8FF00" : pet.themeColorHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(petThemeColor.opacity(0.28))
                                    .frame(width: 48, height: 48)
                                if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable().scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                } else {
                                    Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                                        .font(.system(size: 24))
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                Text(selectedCategory.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(petThemeColor)
                            }
                            Spacer()
                            Text(selectedCategory.emoji)
                                .font(.system(size: 36))
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // ── 证件类型（Chip 横滚）
                    fieldCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(petThemeColor)
                                Text("证件类型")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(DocumentCategory.allCases, id: \.rawValue) { cat in
                                        Button { selectedCategory = cat } label: {
                                            HStack(spacing: 5) {
                                                Text(cat.emoji)
                                                Text(cat.rawValue)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                            }
                                            .foregroundStyle(selectedCategory == cat ? Color.arkInk : .primary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(
                                                selectedCategory == cat ? petThemeColor : Color.primary.opacity(0.08),
                                                in: Capsule()
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // ── 证件名称
                    docRow(icon: "doc.text.fill", iconColor: .goTeal, label: "证件名称") {
                        TextField(autoTitle, text: $title)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .tint(Color.goTeal)
                    }

                    // ── 颁发机构
                    docRow(icon: "building.2.fill", iconColor: .goCardCyan, label: "颁发机构") {
                        TextField("动物检疫站、宠物医院…", text: $issuingAuthority)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .tint(Color.goCardCyan)
                    }

                    // ── 签发日期
                    docRow(icon: "calendar.badge.checkmark", iconColor: .goPrimary, label: "签发日期") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $hasIssueDate).tint(Color.goPrimary).labelsHidden()
                            if hasIssueDate {
                                DatePicker("", selection: $issueDate, displayedComponents: .date)
                                    .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                            }
                        }
                    }

                    // ── 有效期
                    docRow(icon: "clock.badge.exclamationmark", iconColor: Color(hex: "FF3B30"), label: "有效期至") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $hasExpiryDate).tint(Color(hex: "FF3B30")).labelsHidden()
                            if hasExpiryDate {
                                DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                    .datePickerStyle(.compact).tint(Color(hex: "FF3B30")).labelsHidden()
                            }
                        }
                    }

                    docRow(icon: "yensign.circle.fill", iconColor: .goPrimary, label: "花费记账") {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $hasCost).tint(Color.goPrimary).labelsHidden()
                            if hasCost {
                                Text("¥").foregroundStyle(.secondary)
                                TextField("0.00", text: $costText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .tint(Color.goPrimary)
                                    .frame(maxWidth: 80)
                            }
                        }
                    }

                    // Payer picker (when cost is enabled)
                    if hasCost && !humans.isEmpty {
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(petThemeColor.opacity(0.85))
                                    Text("谁付的款")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        Button { selectedPayerId = nil } label: {
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    Circle()
                                                        .fill(selectedPayerId == nil ? petThemeColor : Color.primary.opacity(0.08))
                                                        .frame(width: 40, height: 40)
                                                    Image(systemName: "questionmark")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundStyle(selectedPayerId == nil ? Color.arkInk : .primary.opacity(0.5))
                                                }
                                                Text("未指定")
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        ForEach(humans) { human in
                                            let hid = human.id.uuidString
                                            let isSelected = selectedPayerId == hid
                                            let themeColor = Color(hex: human.themeColorHex.count == 6 ? human.themeColorHex : "C8FF00")
                                            Button { selectedPayerId = hid } label: {
                                                VStack(spacing: 4) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(isSelected ? themeColor : themeColor.opacity(0.2))
                                                            .frame(width: 40, height: 40)
                                                        if let data = human.avatarImageData, let img = UIImage(data: data) {
                                                            Image(uiImage: img)
                                                                .resizable().scaledToFill()
                                                                .frame(width: 40, height: 40).clipShape(Circle())
                                                        } else {
                                                            Text(human.avatarEmoji)
                                                                .font(.system(size: 20))
                                                        }
                                                        if isSelected {
                                                            Circle()
                                                                .strokeBorder(.white, lineWidth: 2)
                                                                .frame(width: 40, height: 40)
                                                        }
                                                    }
                                                    Text(human.name)
                                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                                        .foregroundStyle(isSelected ? .primary : .secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if hasCost && selectedCategory == .insurance {
                        docRow(icon: "repeat", iconColor: .goPrimary, label: "按月付款") {
                            Toggle("", isOn: $isMonthlyInsurance).tint(Color.goPrimary).labelsHidden()
                        }
                    }

                    // ── 附件区域
                    fieldCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("附件" + (attachments.isEmpty ? "" : " (\(attachments.count))"))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 4)

                            if !attachments.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(attachments) { att in
                                        HStack(spacing: 10) {
                                            if att.isImage, let ui = UIImage(data: att.data) {
                                                Button { previewAttachment = att } label: {
                                                    Image(uiImage: ui).resizable().scaledToFill()
                                                        .frame(width: 40, height: 40)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }.buttonStyle(.plain)
                                            } else {
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(Color.goTeal)
                                                    .frame(width: 40, height: 40)
                                                    .background(Color.goTeal.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                            }
                                            Text(att.filename.isEmpty ? (att.isImage ? "图片" : "文件") : att.filename)
                                                .font(.system(size: 14, weight: .medium)).lineLimit(1)
                                            Spacer()
                                            Button { attachments.removeAll { $0.id == att.id } } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary.opacity(0.6))
                                            }
                                        }
                                        .padding(10)
                                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                attachmentBtn(icon: "camera.fill", label: "拍照", color: petThemeColor) { showingCamera = true }
                                PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 10, matching: .images) {
                                    attachmentBtnLabel(icon: "photo.fill", label: "相册", color: petThemeColor.opacity(0.85))
                                }
                                .onChange(of: photoPickerItems) { _, items in
                                    Task {
                                        for item in items {
                                            if let data = try? await item.loadTransferable(type: Data.self) {
                                                let att = DocAttachment(data: data, filename: "", isImage: true)
                                                await MainActor.run { attachments.append(att) }
                                            }
                                        }
                                        await MainActor.run { photoPickerItems = [] }
                                    }
                                }
                                attachmentBtn(icon: "doc.fill", label: "文件", color: Color.goOrange) { showingFilePicker = true }
                            }
                        }
                    }

                    // ── 备注
                    docRow(icon: "note.text", iconColor: .secondary, label: "备注") {
                        TextField("编号、附加信息…", text: $notes, axis: .vertical)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tint(Color.goPrimary)
                            .lineLimit(2...4)
                    }

                    // ── 证件号码 (护照/登记证)
                    if showDocumentNumber {
                        docRow(icon: "number.circle.fill", iconColor: .goCardCyan, label: selectedCategory == .passport ? "护照号码" : "证件号码") {
                            TextField("编号", text: $documentNumber)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .tint(Color.goCardCyan)
                        }
                    }

                    Spacer(minLength: 28)

                    Button { saveDocument(); dismiss() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("保存证件")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(petThemeColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            }
            .navigationTitle("添加证件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.bar)
        // B4: 拍照 sheet — onDismiss 后处理 pending image，避免 sheet 嵌套冲突
        .sheet(isPresented: $showingCamera, onDismiss: {
            if let img = pendingCapturedImage {
                let data = img.jpegData(compressionQuality: 0.85) ?? Data()
                attachments.append(DocAttachment(data: data, filename: "photo_\(attachments.count + 1).jpg", isImage: true))
                pendingCapturedImage = nil
            }
        }) {
            PetCameraPickerView { img in
                pendingCapturedImage = img
                // 不在此处操作 attachments，等 onDismiss 处理
            }
        }
        // F3: 附件图片全屏预览
        .fullScreenCover(item: $previewAttachment) { att in
            if let ui = UIImage(data: att.data) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                    VStack {
                        HStack {
                            Spacer()
                            Button { previewAttachment = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.primary)
                                    .shadow(radius: 4)
                            }
                            .padding(16)
                        }
                        Spacer()
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingFilePicker,
                      allowedContentTypes: [UTType.pdf, UTType.image, UTType.data]) { result in
            if case .success(let url) = result {
                _ = url.startAccessingSecurityScopedResource()
                if let data = try? Data(contentsOf: url) {
                    let att = DocAttachment(data: data, filename: url.lastPathComponent, isImage: false)
                    attachments.append(att)
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: - 附件按钮辅助
    private func attachmentBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { attachmentBtnLabel(icon: icon, label: label, color: color) }
    }

    private func attachmentBtnLabel(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func docRow<Content: View>(icon: String, iconColor: Color, label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        fieldCard {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                content()
            }
        }
    }

    private func saveDocument() {
        // B4: 自动预填名称
        let finalTitle = title.isEmpty ? autoTitle : title
        let doc = PetDocument(
            title: finalTitle,
            category: selectedCategory,
            pet: pet
        )
        doc.issuingAuthority = issuingAuthority
        doc.notes = notes
        if hasIssueDate { doc.issueDate = issueDate }
        if hasExpiryDate { doc.expiryDate = expiryDate }
        // B4: 存储第一个附件（PetDocument 单附件字段）
        if let first = attachments.first {
            doc.attachmentData = first.data
            doc.attachmentFilename = first.filename.isEmpty
                ? (first.isImage ? "image.jpg" : "attachment")
                : first.filename
        }
        // N3: 费用同步（所有类型可选）
        let amount = hasCost ? (Double(costText) ?? 0) : 0
        doc.cost = amount
        let expenseDate = issueDate.isAfterToday ? Date() : (hasIssueDate ? issueDate : Date())
        if amount > 0 {
            let expCat: ExpenseCategory = selectedCategory == .insurance ? .other : .medical
            if selectedCategory == .insurance && isMonthlyInsurance {
                // N2: 保险月付 — 生成未来12个月支出记录
                for i in 0..<12 {
                    if let monthDate = Calendar.current.date(byAdding: .month, value: i, to: expenseDate) {
                        let expense = PetExpenseLog(date: monthDate, amount: amount,
                                                    category: expCat, note: "\(doc.title)（月付）", pet: pet)
                        modelContext.insert(expense)
                    }
                }
            } else {
                let expense = PetExpenseLog(date: expenseDate, amount: amount,
                                            category: expCat, note: doc.title, pet: pet)
                modelContext.insert(expense)
            }
        }
        modelContext.insert(doc)
        modelContext.safeSave()
        // Sync document number to Pet fields
        if !documentNumber.isEmpty {
            if selectedCategory == .passport { pet.passportNumber = documentNumber }
            else if selectedCategory == .registration { /* could sync to microchip if field exists */ }
            modelContext.safeSave()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private extension Date {
    var isAfterToday: Bool { self > Date() }
}

// MARK: - P7: 编辑证件 Sheet（预填数据）
struct EditDocumentSheet: View {
    let doc: PetDocument
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedCategory: DocumentCategory
    @State private var hasIssueDate: Bool
    @State private var issueDate: Date
    @State private var hasExpiryDate: Bool
    @State private var expiryDate: Date
    @State private var issuingAuthority: String
    @State private var notes: String
    @State private var costText: String
    @State private var hasCost: Bool
    @State private var attachmentImage: UIImage? = nil
    @State private var showingDelete = false
    @State private var showingPreview = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var pendingCapturedImage: UIImage? = nil

    init(doc: PetDocument, pet: Pet) {
        self.doc = doc
        self.pet = pet
        _title = State(initialValue: doc.title)
        _selectedCategory = State(initialValue: DocumentCategory(rawValue: doc.category) ?? .other)
        _hasIssueDate = State(initialValue: doc.issueDate != nil)
        _issueDate = State(initialValue: doc.issueDate ?? Date())
        _hasExpiryDate = State(initialValue: doc.expiryDate != nil)
        _expiryDate = State(initialValue: doc.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
        _issuingAuthority = State(initialValue: doc.issuingAuthority)
        _notes = State(initialValue: doc.notes)
        _costText = State(initialValue: doc.cost > 0 ? String(format: "%.0f", doc.cost) : "")
        _hasCost = State(initialValue: doc.cost > 0)
        if let data = doc.attachmentData { _attachmentImage = State(initialValue: UIImage(data: data)) }
    }

    private var petThemeColor: Color {
        Color(hex: pet.themeColorHex.isEmpty ? "C8FF00" : pet.themeColorHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(petThemeColor.opacity(0.28))
                                    .frame(width: 48, height: 48)
                                if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable().scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                } else {
                                    Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                                        .font(.system(size: 24))
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                Text(selectedCategory.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(petThemeColor)
                            }
                            Spacer()
                            Text(selectedCategory.emoji)
                                .font(.system(size: 36))
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // 证件类型
                    editFieldCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(petThemeColor)
                                Text("证件类型")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(DocumentCategory.allCases, id: \.rawValue) { cat in
                                        Button { selectedCategory = cat } label: {
                                            HStack(spacing: 5) {
                                                Text(cat.emoji)
                                                Text(cat.rawValue)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                            }
                                            .foregroundStyle(selectedCategory == cat ? Color.arkInk : .primary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(
                                                selectedCategory == cat ? petThemeColor : Color.primary.opacity(0.08),
                                                in: Capsule()
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    editRow(icon: "doc.text.fill", iconColor: .goTeal, label: "证件名称") {
                        TextField("证件名称", text: $title).font(.system(size: 15, weight: .medium, design: .rounded)).tint(Color.goTeal)
                    }
                    editRow(icon: "building.2.fill", iconColor: .goCardCyan, label: "颁发机构") {
                        TextField("颁发机构", text: $issuingAuthority).font(.system(size: 15, weight: .medium, design: .rounded)).tint(Color.goCardCyan)
                    }
                    editRow(icon: "calendar.badge.checkmark", iconColor: .goPrimary, label: "签发日期") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $hasIssueDate).tint(Color.goPrimary).labelsHidden()
                            if hasIssueDate {
                                DatePicker("", selection: $issueDate, displayedComponents: .date)
                                    .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                            }
                        }
                    }
                    editRow(icon: "clock.badge.exclamationmark", iconColor: Color(hex: "FF3B30"), label: "有效期至") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $hasExpiryDate).tint(Color(hex: "FF3B30")).labelsHidden()
                            if hasExpiryDate {
                                DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                    .datePickerStyle(.compact).tint(Color(hex: "FF3B30")).labelsHidden()
                            }
                        }
                    }
                    editRow(icon: "yensign.circle.fill", iconColor: .goPrimary, label: "花费") {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $hasCost).tint(Color.goPrimary).labelsHidden()
                            if hasCost {
                                Text("¥").foregroundStyle(.secondary)
                                TextField("0", text: $costText).keyboardType(.decimalPad)
                                    .font(.system(size: 15, weight: .semibold)).tint(Color.goPrimary).frame(maxWidth: 80)
                            }
                        }
                    }
                    editRow(icon: "note.text", iconColor: .secondary, label: "备注") {
                        TextField("备注…", text: $notes, axis: .vertical)
                            .font(.system(size: 14, weight: .medium)).tint(Color.goPrimary).lineLimit(2...4)
                    }

                    // 附件预览/更换
                    editFieldCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("附件")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 4)
                            if let img = attachmentImage {
                                Button { showingPreview = true } label: {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(maxWidth: .infinity).frame(height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .topTrailing) {
                                            Button { attachmentImage = nil } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20)).foregroundStyle(.primary).padding(6)
                                            }
                                        }
                                }.buttonStyle(.plain)
                            } else {
                                HStack(spacing: 10) {
                                    Button { showingCamera = true } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: "camera.fill").font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(petThemeColor)
                                                .frame(width: 44, height: 44)
                                                .background(petThemeColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                                            Text("拍照")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }.frame(maxWidth: .infinity)
                                    }.buttonStyle(.plain)
                                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                                        VStack(spacing: 6) {
                                            Image(systemName: "photo.fill").font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(petThemeColor.opacity(0.9))
                                                .frame(width: 44, height: 44)
                                                .background(petThemeColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                            Text("相册")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }.frame(maxWidth: .infinity)
                                    }
                                    .onChange(of: photoPickerItem) { _, item in
                                        Task {
                                            if let data = try? await item?.loadTransferable(type: Data.self),
                                               let img = UIImage(data: data) {
                                                await MainActor.run { attachmentImage = img }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 28)

                    Button { saveChanges(); dismiss() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("保存修改")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(petThemeColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            }
            .navigationTitle("编辑证件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingDelete = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.goRed)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.bar)
        .sheet(isPresented: $showingCamera, onDismiss: {
            if let img = pendingCapturedImage { attachmentImage = img; pendingCapturedImage = nil }
        }) {
            PetCameraPickerView { img in pendingCapturedImage = img }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let img = attachmentImage {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: img).resizable().scaledToFit().ignoresSafeArea()
                    VStack { HStack { Spacer(); Button { showingPreview = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(.primary).padding(16)
                    }}; Spacer() }
                }
            }
        }
        .alert("删除「\(doc.title.isEmpty ? doc.category : doc.title)」？", isPresented: $showingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                modelContext.delete(doc)
                modelContext.safeSave()
                dismiss()
            }
        } message: { Text("此操作不可撤销。") }
    }

    private func editFieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func editRow<Content: View>(icon: String, iconColor: Color, label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        editFieldCard {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(iconColor).frame(width: 22)
                Text(label).font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                content()
            }
        }
    }

    private func saveChanges() {
        doc.title = title.isEmpty ? "\(pet.name)\(selectedCategory.rawValue)" : title
        doc.category = selectedCategory.rawValue
        doc.issuingAuthority = issuingAuthority
        doc.notes = notes
        doc.issueDate = hasIssueDate ? issueDate : nil
        doc.expiryDate = hasExpiryDate ? expiryDate : nil
        doc.cost = hasCost ? (Double(costText) ?? 0) : 0
        if let img = attachmentImage {
            doc.attachmentData = img.jpegData(compressionQuality: 0.85)
            if doc.attachmentFilename.isEmpty { doc.attachmentFilename = "image.jpg" }
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
