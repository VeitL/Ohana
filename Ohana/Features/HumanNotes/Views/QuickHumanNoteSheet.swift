//
//  QuickHumanNoteSheet.swift
//  Ohana
//
//  V4 quick human record popup.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct QuickHumanNoteContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct QuickHumanFileAttachmentDraft: Identifiable {
    let id = UUID()
    let fileName: String
    let data: Data
    let isImage: Bool
}

struct QuickHumanNoteSheet: View {
    let human: Human
    var onSaved: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var noteText = ""
    @State private var date = Date()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var capturedImage: UIImage? = nil
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var showFileImporter = false
    @State private var attachedFiles: [QuickHumanFileAttachmentDraft] = []
    @State private var reminderEnabled = false
    @State private var reminderDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()
    @State private var selectedRecorderID: UUID?
    @State private var requiresRecorderSelection = false
    @State private var adaptiveSheetHeight: CGFloat = 560
    @State private var contentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var isSaving = false
    @State private var popupDragOffset: CGFloat = 0
    @State private var personalUpgradePrompt: PersonalUpgradePrompt?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var trimmedNote: String { noteText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasAttachment: Bool { !selectedImages.isEmpty || !attachedFiles.isEmpty }
    private var canSave: Bool {
        (!trimmedNote.isEmpty || hasAttachment || reminderEnabled) && !requiresRecorderSelection
    }
    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(human.name)
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    noteBlock
                    attachmentBlock
                    reminderBlock
                    dateBlock
                    QuickCareActionHumanPickerContainer(
                        selectedHumanID: $selectedRecorderID,
                        requiresSelection: $requiresRecorderSelection,
                        role: .recorder,
                        tint: .goPrimary
                    )
                    .padding(.horizontal, 22)
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("quick-human-note-sheet")
            .navigationTitle(l.tr(zh: "添加记录", en: "Add Record", de: "Eintrag hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { close() }
                        .accessibilityIdentifier("ohana-sheet-close-action")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { save() }
                        .disabled(!canSave || isSaving)
                        .accessibilityIdentifier("quick-human-note-save-action")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var loaded: [UIImage] = []
                for item in newItems {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    let signature = MediaThumbnailProvider.signature(for: data)
                    let key = MediaThumbnailKey(
                        id: "quick-human-note-import-\(signature)",
                        sourceSignature: signature,
                        maxPixel: 1800
                    )
                    if let image = await MediaThumbnailProvider.image(for: key, dataProvider: { data }) {
                        loaded.append(image)
                    }
                }
                await MainActor.run {
                    selectedImages.append(contentsOf: loaded)
                    selectedItems = []
                }
            }
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            selectedImages.append(image)
            capturedImage = nil
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .fullScreenCover(isPresented: $showCamera) {
            PetCameraPickerView { image in
                capturedImage = image
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.pdf, UTType.image, UTType.data],
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result {
                attachedFiles.append(contentsOf: loadFileDrafts(from: urls))
            }
        }
        .alert(l.tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar"), isPresented: $showCameraPermissionAlert) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(l.tr(zh: "请在系统设置中允许 Ohana 访问相机。", en: "Allow Ohana to access the camera in system settings.", de: "Erlaube Ohana den Kamerazugriff in den Systemeinstellungen."))
        }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
        }
    }

    private var popupBackdrop: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.06), // ui-v4: allow short popup scrimGradient token
                Color.black.opacity(0.30) // ui-v4: allow short popup scrimGradient token
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { close() }
    }

    private var popupDragHandle: some View {
        OhanaPopupDragHandle()
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        popupDragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 70 || value.predictedEndTranslation.height > 130 {
                            close()
                        } else {
                            withAnimation(popupAnimation) { popupDragOffset = 0 }
                        }
                    }
            )
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(Color.goPrimary.opacity(0.18))
                Image(systemName: "note.text") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "添加记录", en: "Add Record", de: "Eintrag hinzufügen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(human.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            OhanaPopupCloseButton { close() }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "内容", en: "Note", de: "Notiz"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextEditor(text: $noteText)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(12)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
                .accessibilityIdentifier("quick-human-note-input")
                .overlay(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text(l.tr(zh: "记录此刻、想法或要跟进的事……", en: "Write a thought, moment, or follow-up…", de: "Gedanke, Moment oder To-do notieren…"))
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal, 22)
    }

    private var attachmentBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 6, matching: .images) {
                    attachmentButton(icon: "photo.on.rectangle.angled", title: l.tr(zh: "相册", en: "Album", de: "Album"), color: Color.goPrimary)
                }
                .buttonStyle(ScaleButtonStyle())

                Button { presentCamera() } label: {
                    attachmentButton(icon: "camera.fill", title: l.tr(zh: "拍照", en: "Camera", de: "Kamera"), color: Color.goTeal)
                }
                .buttonStyle(ScaleButtonStyle())

                Button { showFileImporter = true } label: {
                    attachmentButton(icon: "paperclip", title: l.tr(zh: "文件", en: "File", de: "Datei"), color: Color.goPurple)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if hasAttachment {
                attachmentPreview
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .padding(.horizontal, 22)
    }

    private func attachmentButton(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(title)
                .font(OhanaFont.caption(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(color, in: Capsule())
    }

    private var attachmentPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        selectedImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 8, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(Color.arkInk)
                                            .frame(width: 18, height: 18) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                            .background(Color.goRed, in: Circle())
                                    }
                                    .offset(x: 5, y: -5)
                                }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            ForEach(attachedFiles) { file in
                HStack(spacing: 8) {
                    Image(systemName: file.isImage ? "photo.fill" : "doc.fill")
                        .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPurple)
                    Text(file.fileName)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        attachedFiles.removeAll { $0.id == file.id }
                    } label: {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color.ohanaControlFill, in: Capsule())
            }
        }
    }

    private var reminderBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $reminderEnabled.animation(GoMotion.feedback)) {
                Label(l.tr(zh: "添加提醒", en: "Add Reminder", de: "Erinnerung hinzufügen"), systemImage: "bell.badge.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(Color.goPrimary)

            if reminderEnabled {
                HStack {
                    Text(l.tr(zh: "提醒时间", en: "Reminder time", de: "Erinnerungszeit"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    DatePicker("", selection: $reminderDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .tint(Color.goPrimary)
                }
                .padding(14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .padding(.horizontal, 22)
    }

    private var dateBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
            Text(l.tr(zh: "记录日期", en: "Record date", de: "Eintragsdatum"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .padding(.horizontal, 22)
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(isSaving
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : l.tr(zh: "保存记录", en: "Save Record", de: "Eintrag speichern")
                )
                .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canSave && !isSaving ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave || isSaving)
        .accessibilityIdentifier("quick-human-note-save-action")
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraPermissionAlert = true
            return
        }
        showCamera = true
    }

    private func loadFileDrafts(from urls: [URL]) -> [QuickHumanFileAttachmentDraft] {
        urls.compactMap { url in
            guard let data = SecurityScopedFileDataReader.read(url) else { return nil }
            let isImage = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .image)) ?? false
            return QuickHumanFileAttachmentDraft(
                fileName: url.lastPathComponent.isEmpty ? "attachment" : url.lastPathComponent,
                data: data,
                isImage: isImage
            )
        }
    }

    private func close() {
        guard !isClosing, !isSaving else { return }
        isClosing = true
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func save() {
        guard !isSaving, canSave else { return }
        isSaving = true
        let savedNote = noteText
        let savedDate = date
        let savedImages = selectedImages
        let savedFiles = attachedFiles.map {
            HumanNoteFileAttachmentPayload(fileName: $0.fileName, data: $0.data, isImage: $0.isImage)
        }
        let savedReminderDate = reminderEnabled ? reminderDate : nil
        let languageCode = appLanguage
        let savedRecorderID = selectedRecorderID?.uuidString
        let command = DomainCommand.humanNote(humanID: human.id)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(command) {
            do {
                guard try HumanCareCommandExecutor(
                    context: modelContext,
                    services: appServices
                ).recordNoteEnforcingPersonalAccess(
                    human: human,
                    noteText: savedNote,
                    date: savedDate,
                    imageAttachments: savedImages,
                    fileAttachments: savedFiles,
                    reminderDate: savedReminderDate,
                    appLanguage: languageCode,
                    recordedByHumanId: savedRecorderID,
                    note: "human.note"
                ) != nil else {
                    isSaving = false
                    return
                }
            } catch let PersonalPlanQuotaCommandError.personalUpgradeRequired(denial) {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                return
            } catch {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                appServices.domainRevisions.publishFailure(command: command, error: error)
                return
            }
            onSaved?()
            isSaving = false
            close()
        }
    }
}
