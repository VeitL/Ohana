//
//  AddDocumentSheet.swift
//  Ohana
//
//  R10: 添加/编辑证件 — ArkBackgroundView + glassEffect 字段卡；导航栏磨砂；Sheet presentationBackground(.bar)
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 附件数据模型
private struct DocAttachment: Identifiable {
    let id = UUID()
    var data: Data
    var filename: String
    var isImage: Bool
}

private struct AttachmentFullScreenPreview: View {
    let data: Data
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Color.arkInk.ignoresSafeArea()
            AsyncDecodedImageView(data: data) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } placeholder: {
                ProgressView()
                    .tint(Color.ohanaPrimaryText)
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.title(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
    }
}

struct AddDocumentContentSheet: View {
    let pet: Pet
    let humans: [Human]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @State private var title: String = ""
    @State private var selectedCategory: DocumentCategory = .other
    @State private var hasIssueDate = false
    @State private var issueDate: Date = .init()
    @State private var hasExpiryDate = false
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var issuingAuthority: String = ""
    @State private var notes: String = ""
    @State private var documentNumber: String = ""
    // B4: 多附件
    @State private var attachments: [DocAttachment] = []
    @State private var showingCamera = false
    @State private var showCameraPermissionAlert = false
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
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    // B4: 自动预填名称
    private var autoTitle: String { "\(pet.name)\(selectedCategory.rawValue)" }
    private var showDocumentNumber: Bool { selectedCategory == .passport || selectedCategory == .registration }
    private var petThemeColor: Color {
        Color(hex: pet.safeThemeColorHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            PetAvatarPortraitView(
                                pet: pet,
                                fallbackText: pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji,
                                themeColor: petThemeColor,
                                size: 48,
                                backgroundOpacity: 0.28
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                Text(selectedCategory.rawValue)
                                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(petThemeColor)
                            }
                            Spacer()
                            Text(selectedCategory.emoji)
                                .font(OhanaFont.adaptive(size: 36)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        }
                        .padding(16)
                        .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                        // ── 证件类型（Chip 横滚）
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag.fill") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(petThemeColor)
                                    Text("证件类型")
                                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(DocumentCategory.protectionDocumentCases, id: \.rawValue) { cat in
                                            Button { selectedCategory = cat } label: {
                                                HStack(spacing: 5) {
                                                    Text(cat.emoji)
                                                    Text(cat.rawValue)
                                                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                }
                                                .foregroundStyle(selectedCategory == cat ? Color.arkInk : .primary)
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(
                                                    selectedCategory == cat ? petThemeColor : Color.primary.opacity(0.08),
                                                    in: Capsule()
                                                )
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                }
                            }
                        }

                        // ── 证件名称
                        docRow(icon: "doc.text.fill", iconColor: .goTeal, label: "证件名称") {
                            GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                autoTitle,
                                text: $title,
                                capitalization: .words
                            )
                            .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .tint(Color.goTeal)
                        }

                        // ── 颁发机构
                        docRow(icon: "building.2.fill", iconColor: .goCardCyan, label: "颁发机构") {
                            GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                "动物检疫站、宠物医院…",
                                text: $issuingAuthority,
                                capitalization: .words
                            )
                            .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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

                        docRow(icon: "\(AppCurrency.systemIconName).fill", iconColor: .goPrimary, label: "花费记账") {
                            HStack(spacing: 8) {
                                Toggle("", isOn: $hasCost).tint(Color.goPrimary).labelsHidden()
                                if hasCost {
                                    Text(AppCurrency.symbol).foregroundStyle(Color.ohanaSecondaryText)
                                    GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                        "0.00",
                                        text: $costText,
                                        keyboardType: .decimalPad,
                                        capitalization: .never
                                    )
                                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .tint(Color.goPrimary)
                                    .frame(maxWidth: 80)
                                }
                            }
                        }

                        // Payer picker (when cost is enabled)
                        if hasCost, !humans.isEmpty {
                            fieldCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "creditcard.fill") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(petThemeColor.opacity(0.85))
                                        Text("谁付的款")
                                            .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            Button { selectedPayerId = nil } label: {
                                                VStack(spacing: 4) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(selectedPayerId == nil ? petThemeColor : Color.primary.opacity(0.08))
                                                            .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                        Image(systemName: "questionmark") // a11y: allow decorative icon covered by surrounding text or control
                                                            .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                            .foregroundStyle(selectedPayerId == nil ? Color.arkInk : .primary.opacity(0.5))
                                                    }
                                                    Text("未指定")
                                                        .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                        .foregroundStyle(Color.ohanaSecondaryText)
                                                }
                                            }
                                            .buttonStyle(ScaleButtonStyle())

                                            ForEach(humans) { human in
                                                let hid = human.id.uuidString
                                                let isSelected = selectedPayerId == hid
                                                let themeColor = Color(hex: human.safeThemeColorHex)
                                                Button { selectedPayerId = hid } label: {
                                                    VStack(spacing: 4) {
                                                        ZStack {
                                                            Circle()
                                                                .fill(isSelected ? themeColor : themeColor.opacity(0.2))
                                                                .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                            HumanAvatarPipelineView(
                                                                human: human,
                                                                size: 40,
                                                                showsBackground: false
                                                            )
                                                            if isSelected {
                                                                Circle()
                                                                    .strokeBorder(Color.arkInk, lineWidth: 2)
                                                                    .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                            }
                                                        }
                                                        Text(human.name)
                                                            .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                            .foregroundStyle(isSelected ? .primary : .secondary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                .buttonStyle(ScaleButtonStyle())
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── 附件区域
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "paperclip") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaSecondaryText)
                                    Text("附件" + (attachments.isEmpty ? "" : " (\(attachments.count))"))
                                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                }
                                .padding(.horizontal, 4)

                                if !attachments.isEmpty {
                                    VStack(spacing: 6) {
                                        ForEach(attachments) { att in
                                            HStack(spacing: 10) {
                                                if att.isImage {
                                                    Button { previewAttachment = att } label: {
                                                        AsyncDecodedImageView(data: att.data) { image in
                                                            Image(uiImage: image).resizable().scaledToFill()
                                                        } placeholder: {
                                                            Image(systemName: "photo.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                                .font(OhanaFont.title3(.bold))
                                                                .foregroundStyle(Color.goTeal)
                                                        }
                                                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.icon))
                                                    }.buttonStyle(ScaleButtonStyle())
                                                } else {
                                                    Image(systemName: "doc.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                        .font(OhanaFont.adaptive(size: 18)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                        .foregroundStyle(Color.goTeal)
                                                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                        .background(Color.goTeal.opacity(0.1), in: RoundedRectangle(cornerRadius: OhanaRadius.icon))
                                                }
                                                Text(att.filename.isEmpty ? (att.isImage ? "图片" : "文件") : att.filename)
                                                    .font(OhanaFont.adaptive(size: 14, weight: .medium)).lineLimit(1) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                Spacer()
                                                Button { attachments.removeAll { $0.id == att.id } } label: {
                                                    Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.6))
                                                }
                                            }
                                            .padding(10)
                                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
                                        }
                                    }
                                }

                                HStack(spacing: 10) {
                                    attachmentBtn(icon: "camera.fill", label: "拍照", color: petThemeColor) { presentCamera() }
                                    PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 10, matching: .images) {
                                        attachmentBtnLabel(icon: "photo.fill", label: "相册", color: petThemeColor.opacity(0.85))
                                    }
                                    .onChange(of: photoPickerItems) { _, items in
                                        Task {
                                            for item in items {
                                                if let data = try? await item.loadTransferable(type: Data.self) {
                                                    let att = DocAttachment(
                                                        data: AttachmentPrivacySanitizer.sanitizedData(
                                                            data,
                                                            filename: "photo.jpg",
                                                            isImage: true
                                                        ),
                                                        filename: "",
                                                        isImage: true
                                                    )
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
                            GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                "编号、附加信息…",
                                text: $notes,
                                axis: .vertical
                            )
                            .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .tint(Color.goPrimary)
                            .lineLimit(2 ... 4)
                        }

                        // ── 证件号码 (护照/登记证)
                        if showDocumentNumber {
                            docRow(icon: "number.circle.fill", iconColor: .goCardCyan, label: selectedCategory == .passport ? "护照号码" : "证件号码") {
                                GoDraftTextField( // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                    "编号",
                                    text: $documentNumber
                                )
                                .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .tint(Color.goCardCyan)
                            }
                        }

                        Spacer(minLength: 28)

                        Button {
                            GoKeyboard.dismiss()
                            saveDocument()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                                Text("保存证件")
                            }
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(petThemeColor, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("添加证件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ohanaCardSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        GoKeyboard.dismiss()
                    }
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .ohanaSheetPagePresentation() // ui-v4: allow long document editor
        // B4: 拍照 sheet — onDismiss 后处理 pending image，避免 sheet 嵌套冲突
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            if let img = pendingCapturedImage {
                let data = AttachmentPrivacySanitizer.sanitizedImageData(
                    from: img,
                    compressionQuality: 0.85
                ) ?? Data()
                attachments.append(DocAttachment(data: data, filename: "photo_\(attachments.count + 1).jpg", isImage: true))
                pendingCapturedImage = nil
            }
        }) {
            PetCameraPickerView { img in
                pendingCapturedImage = img
                showingCamera = false
                // 不在此处操作 attachments，等 onDismiss 处理
            } onCancel: {
                showingCamera = false
            }
        }
        .alert("无法打开相机", isPresented: $showCameraPermissionAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请在系统设置中允许 Ohana 访问相机。")
        }
        // F3: 附件图片全屏预览
        .fullScreenCover(item: $previewAttachment) { att in
            AttachmentFullScreenPreview(data: att.data) {
                previewAttachment = nil
            }
        }
        .fileImporter(isPresented: $showingFilePicker,
                      allowedContentTypes: [UTType.pdf, UTType.image, UTType.data]) { result in
            if case let .success(url) = result {
                Task {
                    if let data = await AttachmentImageDecoder.readFileData(url) {
                        let isImage = AttachmentPrivacySanitizer.isImageFilename(url.lastPathComponent)
                        let att = DocAttachment(
                            data: AttachmentPrivacySanitizer.sanitizedData(
                                data,
                                filename: url.lastPathComponent,
                                isImage: isImage
                            ),
                            filename: url.lastPathComponent,
                            isImage: isImage
                        )
                        await MainActor.run {
                            attachments.append(att)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard selectedPayerId == nil else { return }
            let stored = appServices.activeHumanSelection.currentHumanIdRaw
            selectedPayerId = humans.contains(where: { $0.id.uuidString == stored }) ? stored : humans.first?.id.uuidString
        }
    }

    // MARK: - 附件按钮辅助
    private func attachmentBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { attachmentBtnLabel(icon: icon, label: label, color: color) }
    }

    private func presentCamera() {
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {
            showCameraPermissionAlert = true
        }
    }

    private func attachmentBtnLabel(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 20, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
            Text(label)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .goGlassBackground(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func docRow(icon: String, iconColor: Color, label: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        fieldCard {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                Text(label)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Spacer()
                content()
            }
        }
    }

    private func saveDocument() {
        let input = PetDocumentCreateCommandInput(
            title: title,
            category: selectedCategory,
            issuingAuthority: issuingAuthority,
            notes: notes,
            issueDate: hasIssueDate ? issueDate : nil,
            expiryDate: hasExpiryDate ? expiryDate : nil,
            cost: hasCost ? (Double(costText) ?? 0) : 0,
            payerId: selectedPayerId,
            documentNumber: documentNumber,
            attachments: attachments.map {
                PetDocumentAttachmentCommandInput(data: $0.data, filename: $0.filename, isImage: $0.isImage)
            }
        )
        let command = DomainCommand.petDocumentCreate(petID: pet.id, category: selectedCategory.rawValue)
        commandQueue.enqueue(command) {
            do {
                try PetDocumentCommandExecutor(context: modelContext, services: appServices).createDocument(
                    input: input,
                    pet: pet,
                    note: "petDocument.create"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }
}
