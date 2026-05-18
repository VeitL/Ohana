//
//  ProtectionDocumentPopup.swift
//  Ohana
//
//  Inline V4 popup for creating pet protection documents.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct ProtectionDocumentPopup: View {
    let pet: Pet
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @State private var visible = false
    @State private var dragOffset: CGFloat = 0
    @State private var title = ""
    @State private var category: DocumentCategory = .passport
    @State private var hasIssueDate = false
    @State private var issueDate = Date()
    @State private var hasExpiryDate = true
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var issuingAuthority = ""
    @State private var costText = ""
    @State private var selectedPayerId: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showingCamera = false
    @State private var attachmentData: Data?
    @State private var attachmentFilename = ""
    @State private var attachmentIsImage = false

    private var animation: Animation { GoMotion.page }
    private var hiddenOffset: CGFloat { 760 }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.black.opacity(0.34)], // ui-v4: allow popup scrimGradient
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .padding(.top, 8)
                        .gesture(handleDrag)

                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 48, height: 48)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加证件")
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(pet.name)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText, action: close)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            categoryPicker
                            popupBlock {
                                TextField("证件名称", text: $title)
                                    .font(OhanaFont.subheadline(.bold))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                            popupBlock {
                                TextField("机构 / 编号", text: $issuingAuthority)
                                    .font(OhanaFont.subheadline(.bold))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                            }
                            dateRows
                            attachmentSection
                            costSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxHeight: min(proxy.size.height * 0.58, 560))

                    Button(action: save) {
                        Text("保存")
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                }
                .frame(maxWidth: .infinity)
                .background { OhanaPopupGlassSurface(cornerRadius: 52) }
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .shadow(color: Color.black.opacity(0.54), radius: 46, x: 0, y: -16) // ui-v4: allow popup liftedAlert shadow
                .shadow(color: Color(hex: "0B102C").opacity(0.38), radius: 26, x: 0, y: 12) // ui-v4: allow popup liftedAlert shadow
                .padding(.horizontal, 6)
                .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 2))
                .offset(y: visible ? dragOffset : hiddenOffset)
            }
            .animation(animation, value: visible)
            .animation(animation, value: dragOffset)
        }
        .onAppear {
            selectedPayerId = currentPayerId
            withAnimation(animation) { visible = true }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        attachmentData = data
                        attachmentFilename = "document.jpg"
                        attachmentIsImage = true
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType.pdf, UTType.image, UTType.data]) { result in
            guard case .success(let url) = result else { return }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                attachmentData = data
                attachmentFilename = url.lastPathComponent
                attachmentIsImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
            }
        }
        .sheet(isPresented: $showingCamera) {
            PetCameraPickerView(maxPixel: 1_600) { image in
                attachmentData = image.jpegData(compressionQuality: 0.82)
                attachmentFilename = "camera.jpg"
                attachmentIsImage = true
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
        }
    }

    private var handleDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 54 {
                    close()
                } else {
                    withAnimation(animation) { dragOffset = 0 }
                }
            }
    }

    private var currentPayerId: String? {
        let stored = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        return humans.first(where: { $0.id.uuidString == stored })?.id.uuidString ?? humans.first?.id.uuidString
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DocumentCategory.allCases, id: \.rawValue) { option in
                    Button {
                        withAnimation(GoMotion.feedback) { category = option }
                        if title.isEmpty { title = "\(pet.name)\(option.rawValue)" }
                    } label: {
                        Text("\(option.emoji) \(option.rawValue)")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(category == option ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(category == option ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var dateRows: some View {
        VStack(spacing: 10) {
            popupBlock {
                Toggle("签发日期", isOn: $hasIssueDate)
                    .font(OhanaFont.subheadline(.bold))
                    .tint(Color.goPrimary)
                if hasIssueDate {
                    DatePicker("", selection: $issueDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                }
            }
            popupBlock {
                Toggle("到期日期", isOn: $hasExpiryDate)
                    .font(OhanaFont.subheadline(.bold))
                    .tint(Color.goPrimary)
                if hasExpiryDate {
                    DatePicker("", selection: $expiryDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                }
            }
        }
    }

    private var attachmentSection: some View {
        popupBlock {
            VStack(alignment: .leading, spacing: 10) {
                Text("附件")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                HStack(spacing: 10) {
                    Button { presentCamera() } label: {
                        attachmentButtonLabel("camera.fill", "拍照")
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        attachmentButtonLabel("photo.fill", "相册")
                    }
                    Button { showingFileImporter = true } label: {
                        attachmentButtonLabel("paperclip", "文件")
                    }
                }
                if !attachmentFilename.isEmpty {
                    Label(attachmentFilename, systemImage: attachmentIsImage ? "photo.fill" : "doc.fill")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private func attachmentButtonLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
            Text(title)
                .font(OhanaFont.caption2(.black))
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var costSection: some View {
        popupBlock {
            VStack(alignment: .leading, spacing: 10) {
                Text("费用")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                InlineNumericInput(
                    text: $costText,
                    placeholder: CountryDecimalInput.placeholder(fractionDigits: 2, countryCode: AppCountry.code),
                    unit: AppCurrency.symbol,
                    countryCode: AppCountry.code,
                    maxFractionDigits: 2,
                    accent: Color.goPrimary,
                    valueAlignment: .leading,
                    fill: Color.ohanaCardSurfaceElevated,
                    usesMiniKeypad: true
                )
                if humans.count > 1 {
                    Picker("支付人", selection: Binding(
                        get: { selectedPayerId ?? currentPayerId ?? "" },
                        set: { selectedPayerId = $0 }
                    )) {
                        ForEach(humans) { human in
                            Text(human.name).tag(human.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.goPrimary)
                }
            }
        }
    }

    private func popupBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func presentCamera() {
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {}
    }

    private func close() {
        withAnimation(animation) {
            visible = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }

    private func save() {
        let document = PetDocument(title: title.trimmingCharacters(in: .whitespacesAndNewlines), category: category, pet: pet)
        document.issuingAuthority = issuingAuthority
        if hasIssueDate { document.issueDate = issueDate }
        if hasExpiryDate { document.expiryDate = expiryDate }
        let amount = CountryDecimalInput.parse(costText, countryCode: AppCountry.code) ?? 0
        document.cost = amount
        if let attachmentData {
            document.attachmentData = attachmentData
            document.attachmentFilename = attachmentFilename.isEmpty ? "attachment" : attachmentFilename
            let attachment = PetDocumentAttachment(
                data: attachmentData,
                filename: document.attachmentFilename,
                isImage: attachmentIsImage
            )
            document.attachments.append(attachment)
        }
        modelContext.insert(document)

        if amount > 0 {
            let payerId = selectedPayerId.flatMap { id in humans.contains(where: { $0.id.uuidString == id }) ? id : nil }
            let expenseDate = hasIssueDate ? issueDate : Date()
            for plan in DocumentExpenseSyncPlanner.plannedExpenses(
                documentCategory: category,
                amount: amount,
                date: expenseDate,
                note: document.title,
                payerId: payerId
            ) {
                modelContext.insert(PetExpenseLog(date: plan.date, amount: plan.amount, category: plan.category, note: plan.note, pet: pet, executorId: plan.payerId))
            }
        }

        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        close()
    }
}
