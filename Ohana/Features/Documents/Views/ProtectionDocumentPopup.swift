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

struct ProtectionDocumentContentPopup: View {
    let pet: Pet
    let humans: [Human]
    var existing: PetDocument?
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var visible = false
    @State private var dragOffset: CGFloat = 0
    @State private var title = ""
    @State private var category: DocumentCategory = .passport
    @State private var hasIssueDate = false
    @State private var issueDate = Date()
    @State private var hasExpiryDate = true
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var issuingAuthority = ""
    @State private var notes = ""
    @State private var costText = ""
    @State private var selectedPayerId: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showingCamera = false
    @State private var attachmentData: Data?
    @State private var attachmentFilename = ""
    @State private var attachmentIsImage = false
    @State private var hasNewAttachment = false
    @State private var isSaving = false

    private var isEdit: Bool { existing != nil }
    private var animation: Animation { GoMotion.page }
    private var hiddenOffset: CGFloat { 760 }
    private var canSave: Bool { !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var l: L10n { L10n(appLanguage) }
    private var formSpec: ProtectionDocumentFormSpec { ProtectionDocumentFormSpec.spec(for: category, petName: pet.name, l: l) }

    init(pet: Pet, humans: [Human], existing: PetDocument? = nil, onClose: @escaping () -> Void) {
        self.pet = pet
        self.humans = humans
        self.existing = existing
        self.onClose = onClose
        _title = State(initialValue: existing?.title ?? "")
        _category = State(initialValue: existing?.documentCategory ?? .passport)
        _hasIssueDate = State(initialValue: existing?.issueDate != nil)
        _issueDate = State(initialValue: existing?.issueDate ?? Date())
        _hasExpiryDate = State(initialValue: existing?.expiryDate != nil)
        _expiryDate = State(initialValue: existing?.expiryDate ?? (Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()))
        _issuingAuthority = State(initialValue: existing?.issuingAuthority ?? "")
        _notes = State(initialValue: ExpenseReceiptMetadata.visibleNotes(from: existing?.notes ?? ""))
        _costText = State(initialValue: (existing?.cost ?? 0) > 0 ? CountryDecimalInput.format(existing?.cost ?? 0, countryCode: AppCountry.code, maxFractionDigits: 2) : "")
        _attachmentData = State(initialValue: existing?.attachmentData ?? existing?.attachments.first?.data)
        _attachmentFilename = State(initialValue: existing?.attachmentFilename ?? existing?.attachments.first?.filename ?? "")
        _attachmentIsImage = State(initialValue: {
            if let first = existing?.attachments.first { return first.isImage }
            guard let filename = existing?.attachmentFilename, !filename.isEmpty else { return false }
            return UTType(filenameExtension: (filename as NSString).pathExtension)?.conforms(to: .image) == true
        }())
    }

    var body: some View {
        GeometryReader { proxy in
            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: visible) {
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
                        Image(systemName: "doc.badge.plus") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 48, height: 48)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEdit
                                 ? l.tr(zh: "编辑证件", en: "Edit Document", de: "Dokument bearbeiten")
                                 : l.tr(zh: "添加证件", en: "Add Document", de: "Dokument hinzufügen"))
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
                            keyFieldsSection
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
                        Text(l.tr(zh: "保存", en: "Save", de: "Sichern"))
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
            .animation(animation, value: dragOffset)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            selectedPayerId = currentPayerId
            if !isEdit {
                applyCategoryDefaults(force: true)
            }
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
                        hasNewAttachment = true
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType.pdf, UTType.image, UTType.data]) { result in
            guard case .success(let url) = result else { return }
            Task {
                let data = await AttachmentImageDecoder.readFileData(url)
                let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
                await MainActor.run {
                    if let data {
                        attachmentData = data
                        attachmentFilename = url.lastPathComponent
                        attachmentIsImage = isImage
                        hasNewAttachment = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            PetCameraPickerView(maxPixel: 1_600) { image in
                attachmentData = image.jpegData(compressionQuality: 0.82)
                attachmentFilename = "camera.jpg"
                attachmentIsImage = true
                hasNewAttachment = true
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
        let stored = appServices.activeHumanSelection.currentHumanIdRaw
        return humans.first(where: { $0.id.uuidString == stored })?.id.uuidString ?? humans.first?.id.uuidString
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DocumentCategory.protectionDocumentCases, id: \.rawValue) { option in
                    Button {
                        let previousSpec = formSpec
                        let shouldReplaceTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            title == previousSpec.defaultTitle ||
                            previousSpec.quickTitles.contains(title)
                        withAnimation(GoMotion.feedback) {
                            category = option
                            applyCategoryDefaults(for: option, replaceTitle: shouldReplaceTitle, resetDates: true)
                        }
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

    private var keyFieldsSection: some View {
        popupBlock {
            VStack(alignment: .leading, spacing: 12) {
                Text(formSpec.sectionTitle)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)

                if !formSpec.quickTitles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(formSpec.quickTitles, id: \.self) { option in
                                Button {
                                    withAnimation(GoMotion.feedback) { title = option }
                                } label: {
                                    Text(option)
                                        .font(OhanaFont.caption2(.black))
                                        .foregroundStyle(title == option ? Color.arkInk : Color.ohanaPrimaryText)
                                        .padding(.horizontal, 10)
                                        .frame(height: 30)
                                        .background(title == option ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    formTextField(
                        label: formSpec.titleLabel,
                        placeholder: formSpec.titlePlaceholder,
                        text: $title,
                        icon: formSpec.titleIcon
                    )
                    formTextField(
                        label: formSpec.authorityLabel,
                        placeholder: formSpec.authorityPlaceholder,
                        text: $issuingAuthority,
                        icon: formSpec.authorityIcon
                    )
                    formTextField(
                        label: formSpec.notesLabel,
                        placeholder: formSpec.notesPlaceholder,
                        text: $notes,
                        icon: "text.alignleft"
                    )
                }
            }
        }
    }

    private func formTextField(label: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                TextField(placeholder, text: text, axis: .vertical)
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1...3)
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dateRows: some View {
        VStack(spacing: 10) {
            optionalDateBlock(
                icon: "calendar.badge.checkmark",
                title: formSpec.issueDateLabel,
                isEnabled: $hasIssueDate,
                date: $issueDate
            )
            optionalDateBlock(
                icon: "clock.badge.checkmark",
                title: formSpec.expiryDateLabel,
                isEnabled: $hasExpiryDate,
                date: $expiryDate
            )
        }
    }

    private func optionalDateBlock(
        icon: String,
        title: String,
        isEnabled: Binding<Bool>,
        date: Binding<Date>
    ) -> some View {
        popupBlock {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(isEnabled.wrappedValue
                             ? date.wrappedValue.formatted(.dateTime.year().month().day())
                             : l.tr(zh: "可选", en: "Optional", de: "Optional"))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button {
                        withAnimation(GoMotion.feedback) {
                            isEnabled.wrappedValue.toggle()
                        }
                    } label: {
                        Text(isEnabled.wrappedValue ? l.tr(zh: "清除", en: "Clear", de: "Leeren") : l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(isEnabled.wrappedValue ? Color.ohanaPrimaryText : Color.arkInk)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(isEnabled.wrappedValue ? Color.ohanaCardSurfaceElevated : Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                if isEnabled.wrappedValue {
                    DatePicker("", selection: date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                }
            }
        }
    }

    private var attachmentSection: some View {
        popupBlock {
            VStack(alignment: .leading, spacing: 10) {
                Text(l.tr(zh: "附件", en: "Attachment", de: "Anhang"))
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
                if attachmentData != nil || !attachmentFilename.isEmpty {
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
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                Text(l.tr(zh: "费用", en: "Cost", de: "Kosten"))
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
                    Picker(l.tr(zh: "支付人", en: "Payer", de: "Zahler"), selection: Binding(
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(animation) {
            visible = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        let amount = CountryDecimalInput.parse(costText, countryCode: AppCountry.code) ?? 0
        let payerId = selectedPayerId.flatMap { id in humans.contains(where: { $0.id.uuidString == id }) ? id : nil }
        let attachments: [PetDocumentAttachmentCommandInput] = {
            guard hasNewAttachment, let attachmentData else { return [] }
            return [
                PetDocumentAttachmentCommandInput(
                    data: attachmentData,
                    filename: attachmentFilename.isEmpty ? "attachment" : attachmentFilename,
                    isImage: attachmentIsImage
                )
            ]
        }()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if let existing {
            let input = PetDocumentUpdateCommandInput(
                title: title,
                category: category,
                issuingAuthority: issuingAuthority,
                notes: notes,
                issueDate: hasIssueDate ? issueDate : nil,
                expiryDate: hasExpiryDate ? expiryDate : nil,
                cost: amount,
                attachmentData: nil,
                clearsAttachment: false,
                attachments: attachments
            )
            commandQueue.enqueue(.petDocumentUpdate(petID: pet.id, documentID: existing.id)) {
                PetDocumentCommandExecutor(context: modelContext, services: appServices).updateDocument(
                    existing,
                    pet: pet,
                    input: input,
                    note: "petDocument.update"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                close()
            }
            return
        }

        let input = PetDocumentCreateCommandInput(
            title: title,
            category: category,
            issuingAuthority: issuingAuthority,
            notes: notes,
            issueDate: hasIssueDate ? issueDate : nil,
            expiryDate: hasExpiryDate ? expiryDate : nil,
            cost: amount,
            payerId: payerId,
            documentNumber: "",
            attachments: attachments
        )
        commandQueue.enqueue(.petDocumentCreate(petID: pet.id, category: category.rawValue)) {
            PetDocumentCommandExecutor(context: modelContext, services: appServices).createDocument(
                input: input,
                pet: pet,
                note: "petDocument.create"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            close()
        }
    }

    private func applyCategoryDefaults(
        for category: DocumentCategory? = nil,
        replaceTitle: Bool = false,
        resetDates: Bool = false,
        force: Bool = false
    ) {
        let spec = ProtectionDocumentFormSpec.spec(for: category ?? self.category, petName: pet.name, l: l)
        if force || replaceTitle || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = spec.defaultTitle
        }
        if force || resetDates {
            hasIssueDate = spec.defaultHasIssueDate
            hasExpiryDate = spec.defaultHasExpiryDate
        }
    }
}

private struct ProtectionDocumentFormSpec {
    let sectionTitle: String
    let titleLabel: String
    let titlePlaceholder: String
    let titleIcon: String
    let authorityLabel: String
    let authorityPlaceholder: String
    let authorityIcon: String
    let notesLabel: String
    let notesPlaceholder: String
    let issueDateLabel: String
    let expiryDateLabel: String
    let quickTitles: [String]
    let defaultTitle: String
    let defaultHasIssueDate: Bool
    let defaultHasExpiryDate: Bool

    static func spec(for category: DocumentCategory, petName: String, l: L10n) -> ProtectionDocumentFormSpec {
        switch category {
        case .passport:
            return ProtectionDocumentFormSpec(
                sectionTitle: l.tr(zh: "护照信息", en: "Passport Info", de: "Passdaten"),
                titleLabel: l.tr(zh: "护照编号 / 名称", en: "Passport No. / Name", de: "Passnummer / Name"),
                titlePlaceholder: l.tr(zh: "例如 \(petName) 护照", en: "e.g. \(petName) Passport", de: "z. B. \(petName) Pass"),
                titleIcon: "number",
                authorityLabel: l.tr(zh: "签发机关 / 国家", en: "Authority / Country", de: "Behörde / Land"),
                authorityPlaceholder: l.tr(zh: "例如 宠物出入境办公室", en: "e.g. Pet travel office", de: "z. B. Haustier-Reisebehörde"),
                authorityIcon: "building.columns.fill",
                notesLabel: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                notesPlaceholder: l.tr(zh: "芯片号、旅行备注等", en: "Chip number, travel notes", de: "Chipnummer, Reisenotizen"),
                issueDateLabel: l.tr(zh: "签发日期（可选）", en: "Issue Date (optional)", de: "Ausstellungsdatum (optional)"),
                expiryDateLabel: l.tr(zh: "到期日期（可选）", en: "Expiry Date (optional)", de: "Ablaufdatum (optional)"),
                quickTitles: [l.tr(zh: "\(petName) 护照", en: "\(petName) Passport", de: "\(petName) Pass"), l.tr(zh: "出入境证件", en: "Travel Document", de: "Reisedokument")],
                defaultTitle: l.tr(zh: "\(petName) 护照", en: "\(petName) Passport", de: "\(petName) Pass"),
                defaultHasIssueDate: false,
                defaultHasExpiryDate: true
            )
        case .medical:
            return ProtectionDocumentFormSpec(
                sectionTitle: l.tr(zh: "病历信息", en: "Medical Record Info", de: "Krankenakte"),
                titleLabel: l.tr(zh: "病历 / 报告名称", en: "Record / Report Name", de: "Akte / Bericht"),
                titlePlaceholder: l.tr(zh: "例如 体检报告", en: "e.g. Checkup Report", de: "z. B. Untersuchungsbericht"),
                titleIcon: "heart.text.clipboard.fill",
                authorityLabel: l.tr(zh: "医院 / 医生", en: "Hospital / Vet", de: "Klinik / Tierarzt"),
                authorityPlaceholder: l.tr(zh: "就诊机构", en: "Care provider", de: "Behandelnde Stelle"),
                authorityIcon: "stethoscope",
                notesLabel: l.tr(zh: "诊断 / 备注", en: "Diagnosis / Notes", de: "Diagnose / Notizen"),
                notesPlaceholder: l.tr(zh: "症状、检查结果、用药建议", en: "Symptoms, results, medication advice", de: "Symptome, Befunde, Medikation"),
                issueDateLabel: l.tr(zh: "就诊日期（可选）", en: "Visit Date (optional)", de: "Besuchsdatum (optional)"),
                expiryDateLabel: l.tr(zh: "复查 / 到期（可选）", en: "Follow-up / Expiry (optional)", de: "Kontrolle / Ablauf (optional)"),
                quickTitles: [l.tr(zh: "体检报告", en: "Checkup Report", de: "Check-up-Bericht"), l.tr(zh: "化验报告", en: "Lab Report", de: "Laborbericht"), l.tr(zh: "诊断证明", en: "Diagnosis", de: "Diagnose")],
                defaultTitle: l.tr(zh: "体检报告", en: "Checkup Report", de: "Check-up-Bericht"),
                defaultHasIssueDate: false,
                defaultHasExpiryDate: false
            )
        case .registration:
            return ProtectionDocumentFormSpec(
                sectionTitle: l.tr(zh: "登记信息", en: "Registration Info", de: "Registrierung"),
                titleLabel: l.tr(zh: "登记编号 / 名称", en: "Registration No. / Name", de: "Registrierungsnummer / Name"),
                titlePlaceholder: l.tr(zh: "例如 犬证", en: "e.g. Dog License", de: "z. B. Hundemarke"),
                titleIcon: "tag.fill",
                authorityLabel: l.tr(zh: "登记机构", en: "Registry", de: "Registerstelle"),
                authorityPlaceholder: l.tr(zh: "城市、协会或登记平台", en: "City, club, or registry", de: "Stadt, Verein oder Register"),
                authorityIcon: "building.2.fill",
                notesLabel: l.tr(zh: "芯片 / 备注", en: "Chip / Notes", de: "Chip / Notizen"),
                notesPlaceholder: l.tr(zh: "芯片号、登记说明等", en: "Chip no., registration notes", de: "Chipnummer, Hinweise"),
                issueDateLabel: l.tr(zh: "登记日期（可选）", en: "Registration Date (optional)", de: "Registrierungsdatum (optional)"),
                expiryDateLabel: l.tr(zh: "续期日期（可选）", en: "Renewal Date (optional)", de: "Verlängerung (optional)"),
                quickTitles: [l.tr(zh: "犬证", en: "Dog License", de: "Hundemarke"), l.tr(zh: "芯片登记", en: "Microchip Registration", de: "Chipregistrierung"), l.tr(zh: "协会登记", en: "Club Registration", de: "Vereinsregistrierung")],
                defaultTitle: l.tr(zh: "登记证", en: "Registration", de: "Registrierung"),
                defaultHasIssueDate: false,
                defaultHasExpiryDate: false
            )
        case .vaccine, .insurance, .other:
            return ProtectionDocumentFormSpec(
                sectionTitle: l.tr(zh: "文件信息", en: "File Info", de: "Dateiinfo"),
                titleLabel: l.tr(zh: "文件名称", en: "File Name", de: "Dateiname"),
                titlePlaceholder: l.tr(zh: "例如 领养协议", en: "e.g. Adoption Paper", de: "z. B. Adoptionsvertrag"),
                titleIcon: "doc.text.fill",
                authorityLabel: l.tr(zh: "来源 / 机构", en: "Source / Organization", de: "Quelle / Organisation"),
                authorityPlaceholder: l.tr(zh: "可留空", en: "Optional", de: "Optional"),
                authorityIcon: "person.text.rectangle.fill",
                notesLabel: l.tr(zh: "备注", en: "Notes", de: "Notizen"),
                notesPlaceholder: l.tr(zh: "补充说明", en: "Extra notes", de: "Zusätzliche Notizen"),
                issueDateLabel: l.tr(zh: "日期（可选）", en: "Date (optional)", de: "Datum (optional)"),
                expiryDateLabel: l.tr(zh: "到期日期（可选）", en: "Expiry Date (optional)", de: "Ablaufdatum (optional)"),
                quickTitles: [l.tr(zh: "领养协议", en: "Adoption Paper", de: "Adoptionsvertrag"), l.tr(zh: "购买合同", en: "Purchase Contract", de: "Kaufvertrag"), l.tr(zh: "其他文件", en: "Other File", de: "Andere Datei")],
                defaultTitle: l.tr(zh: "其他文件", en: "Other File", de: "Andere Datei"),
                defaultHasIssueDate: false,
                defaultHasExpiryDate: false
            )
        }
    }
}
