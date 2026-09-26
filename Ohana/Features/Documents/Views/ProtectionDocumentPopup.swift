//
//  ProtectionDocumentPopup.swift
//  Ohana
//
//  Native sheet form for creating pet protection documents.
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ProtectionDocumentContentPopup: View {
    let pet: Pet
    let humans: [Human]
    var existing: PetDocument?
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
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
    @State private var fileImportTask: Task<Void, Never>?
    @State private var showingCamera = false
    @State private var attachmentData: Data?
    @State private var attachmentFilename = ""
    @State private var attachmentIsImage = false
    @State private var hasNewAttachment = false
    @State private var isSaving = false
    @State private var importErrorMessage: String?
    @State private var showImportErrorAlert = false

    private var isEdit: Bool { existing != nil }
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
        _attachmentData = State(initialValue: nil)
        _attachmentFilename = State(initialValue: Self.initialAttachmentFilename(for: existing))
        _attachmentIsImage = State(initialValue: {
            if let first = existing?.attachments.first { return first.isImage }
            guard let filename = existing?.attachmentFilename, !filename.isEmpty else { return false }
            return UTType(filenameExtension: (filename as NSString).pathExtension)?.conforms(to: .image) == true
        }())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(l.tr(zh: "证件类型", en: "Document type", de: "Dokumenttyp"), selection: $category) {
                        ForEach(DocumentCategory.protectionDocumentCases, id: \.rawValue) { option in
                            Text("\(option.emoji) \(option.localizedLabel(l))").tag(option)
                        }
                    }
                    .accessibilityIdentifier("protection-document-category-picker")

                    if !formSpec.quickTitles.isEmpty {
                        Menu(l.tr(zh: "快速标题", en: "Quick title", de: "Schnelltitel")) {
                            ForEach(formSpec.quickTitles, id: \.self) { option in
                                Button(option) { title = option }
                            }
                        }
                    }

                    TextField(formSpec.titlePlaceholder, text: $title)
                        .accessibilityIdentifier("protection-document-title-input")
                    TextField(formSpec.authorityPlaceholder, text: $issuingAuthority)
                        .accessibilityIdentifier("protection-document-authority-input")
                    TextField(formSpec.notesPlaceholder, text: $notes, axis: .vertical)
                        .lineLimit(2 ... 4)
                        .accessibilityIdentifier("protection-document-notes-input")
                } header: {
                    Text(formSpec.sectionTitle)
                }

                Section {
                    Toggle(formSpec.issueDateLabel, isOn: $hasIssueDate)
                        .tint(Color.goPrimary)
                    if hasIssueDate {
                        DatePicker(formSpec.issueDateLabel, selection: $issueDate, displayedComponents: .date)
                    }
                    Toggle(formSpec.expiryDateLabel, isOn: $hasExpiryDate)
                        .tint(Color.goPrimary)
                    if hasExpiryDate {
                        DatePicker(formSpec.expiryDateLabel, selection: $expiryDate, displayedComponents: .date)
                    }
                } header: {
                    Text(l.tr(zh: "日期", en: "Dates", de: "Daten"))
                }

                Section {
                    Button {
                        presentCamera()
                    } label: {
                        Label(l.tr(zh: "拍照", en: "Take photo", de: "Foto aufnehmen"), systemImage: "camera.fill")
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(l.tr(zh: "从相册选择", en: "Choose photo", de: "Foto auswählen"), systemImage: "photo.fill")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label(l.tr(zh: "选择文件", en: "Choose file", de: "Datei auswählen"), systemImage: "paperclip")
                    }
                    if attachmentData != nil || !attachmentFilename.isEmpty {
                        Label(attachmentFilename, systemImage: attachmentIsImage ? "photo.fill" : "doc.fill")
                            .lineLimit(1)
                    }
                } header: {
                    Text(l.tr(zh: "附件", en: "Attachment", de: "Anhang"))
                }

                Section {
                    TextField(
                        l.tr(zh: "费用", en: "Cost", de: "Kosten"),
                        text: $costText
                    )
                    .keyboardType(.decimalPad)
                    if humans.count > 1 {
                        Picker(l.tr(zh: "支付人", en: "Payer", de: "Zahler"), selection: Binding(
                            get: { selectedPayerId ?? currentPayerId ?? "" },
                            set: { selectedPayerId = $0 }
                        )) {
                            ForEach(humans) { human in
                                Text(human.name).tag(human.id.uuidString)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEdit
                ? l.tr(zh: "编辑证件", en: "Edit Document", de: "Dokument bearbeiten")
                : l.tr(zh: "添加证件", en: "Add Document", de: "Dokument hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel, action: close)
                        .accessibilityIdentifier("protection-document-cancel-action")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Sichern"), action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("protection-document-save-action")
                }
            }
        }
        .accessibilityIdentifier("protection-document-editor")
        .onAppear {
            selectedPayerId = currentPayerId
            if !isEdit {
                applyCategoryDefaults(force: true)
            }
        }
        .onChange(of: category) { oldValue, newValue in
            let previousSpec = ProtectionDocumentFormSpec.spec(for: oldValue, petName: pet.name, l: l)
            let replaceTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                title == previousSpec.defaultTitle || previousSpec.quickTitles.contains(title)
            applyCategoryDefaults(for: newValue, replaceTitle: replaceTitle, resetDates: true)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let sanitized = AttachmentPrivacySanitizer.sanitizedData(
                        data,
                        filename: "document.jpg",
                        isImage: true
                    )
                    await MainActor.run {
                        attachmentData = sanitized
                        attachmentFilename = "document.jpg"
                        attachmentIsImage = true
                        hasNewAttachment = true
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType.pdf, UTType.image, UTType.data]) { result in
            guard case let .success(url) = result else { return }
            fileImportTask?.cancel()
            fileImportTask = Task {
                do {
                    let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
                    let payload = try await AttachmentImageDecoder.readSanitizedDocument(
                        url,
                        isImage: isImage,
                        fallbackFilename: "document.jpg"
                    )
                    try Task.checkCancellation()
                    attachmentData = payload.data
                    attachmentFilename = payload.filename
                    attachmentIsImage = payload.isImage
                    hasNewAttachment = true
                } catch is CancellationError {
                    return
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportErrorAlert = true
                }
            }
        }
        .alert(l.tr(zh: "无法导入附件", en: "Attachment import failed", de: "Anhang konnte nicht importiert werden"), isPresented: $showImportErrorAlert) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
        .sheet(isPresented: $showingCamera) {
            PetCameraPickerView(maxPixel: 1600) { image in
                attachmentData = AttachmentPrivacySanitizer.sanitizedImageData(
                    from: image,
                    compressionQuality: 0.82
                )
                attachmentFilename = "camera.jpg"
                attachmentIsImage = true
                hasNewAttachment = true
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
        }
        .onDisappear {
            fileImportTask?.cancel()
            fileImportTask = nil
        }
    }

    private var currentPayerId: String? {
        let stored = appServices.activeHumanSelection.currentHumanIdRaw
        return humans.first(where: { $0.id.uuidString == stored })?.id.uuidString ?? humans.first?.id.uuidString
    }

    private static func initialAttachmentFilename(for existing: PetDocument?) -> String {
        if let filename = existing?.attachments.first?.filename, !filename.isEmpty {
            return filename
        }
        if let filename = existing?.attachmentFilename, !filename.isEmpty {
            return filename
        }
        if existing?.shouldDisplayLegacyAttachmentSlot == true {
            return "attachment"
        }
        return ""
    }

    private func presentCamera() {
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {}
    }

    private func close() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        onClose()
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
            let command = DomainCommand.petDocumentUpdate(petID: pet.id, documentID: existing.id)
            commandQueue.enqueue(command) {
                do {
                    try PetDocumentCommandExecutor(context: modelContext, services: appServices).updateDocument(
                        existing,
                        pet: pet,
                        input: input,
                        note: "petDocument.update"
                    )
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    close()
                } catch {
                    isSaving = false
                    appServices.domainRevisions.publishFailure(command: command, error: error)
                }
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
        let command = DomainCommand.petDocumentCreate(petID: pet.id, category: category.rawValue)
        commandQueue.enqueue(command) {
            do {
                try PetDocumentCommandExecutor(context: modelContext, services: appServices).createDocument(
                    input: input,
                    pet: pet,
                    note: "petDocument.create"
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                close()
            } catch {
                isSaving = false
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
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
            ProtectionDocumentFormSpec(
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
            ProtectionDocumentFormSpec(
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
            ProtectionDocumentFormSpec(
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
            ProtectionDocumentFormSpec(
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
