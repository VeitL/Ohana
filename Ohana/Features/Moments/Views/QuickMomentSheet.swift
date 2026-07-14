//
//  QuickMomentSheet.swift
//  Ohana
//
//  快捷操作「记录」：快速记录当下 Moment，可附带照片，保存到宠物相册（PetPhotoLog）。
//

import Combine
import CoreLocation
import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private struct QuickMomentContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct QuickMomentSheet: View {
    let pet: Pet?
    var onRemove: (() -> Void)?
    var onSaved: (() -> Void)?
    var onClose: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var noteText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedPhotos: [MomentDraftPhoto] = []
    @State private var capturedImage: UIImage? = nil
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var manualPlace = ""
    @StateObject private var locationModel = MomentLocationModel()
    @State private var isSaving = false
    @State private var savedSuccess = false
    @State private var showLocationInput = false
    @State private var adaptiveSheetHeight: CGFloat = 540
    @State private var contentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var popupDragOffset: CGFloat = 0

    /// 记录时刻强调色：有宠物时用主题色
    private var momentAccent: Color {
        guard let pet else { return Color.goPrimary }
        let hex = pet.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return Color(hex: hex.isEmpty ? "FF7600" : hex)
    }

    private var canSave: Bool {
        !selectedPhotos.isEmpty || !trimmedNote.isEmpty
    }

    private let maxDraftPhotos = 9
    private var l: L10n { L10n(appLanguage) }
    private var trimmedNote: String { noteText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    photoSection
                    moodAndNoteSection
                    locationCompactSection
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(l.tr(zh: "快速记录", en: "Quick Moment", de: "Schneller Moment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { close() }
                }
                if onRemove != nil {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(role: .destructive) {
                            onRemove?()
                            close()
                        } label: {
                            Label(l.tr(zh: "删除", en: "Delete", de: "Löschen"), systemImage: "trash")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { saveRecord() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var loaded: [MomentDraftPhoto] = []
                for item in newItems {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    let signature = MediaThumbnailProvider.signature(for: data)
                    let key = MediaThumbnailKey(
                        id: "quick-moment-import-\(signature)",
                        sourceSignature: signature,
                        maxPixel: 1800
                    )
                    if let img = await MediaThumbnailProvider.image(for: key, dataProvider: { data }) {
                        loaded.append(MomentDraftPhoto(image: img))
                    }
                }
                await MainActor.run {
                    appendDraftPhotos(loaded)
                    selectedItems = []
                }
            }
        }
        .onChange(of: capturedImage) { _, img in
            guard let img else { return }
            appendDraftPhotos([MomentDraftPhoto(image: img)])
            capturedImage = nil
        }
        .overlay {
            if savedSuccess {
                successOverlay
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
        .fullScreenCover(isPresented: $showCamera) {
            PetCameraPickerView { img in
                capturedImage = img
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .alert(l.tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar"), isPresented: $showCameraPermissionAlert) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "请在系统设置中允许 Ohana 访问相机。",
                en: "Allow Ohana to access the camera in system settings.",
                de: "Erlaube Ohana den Kamerazugriff in den Systemeinstellungen."
            ))
        }
    }

    // MARK: - Popup Chrome

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

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let pet {
                FeatureHubAvatar(
                    imageCacheID: "quick-moment-pet-\(pet.id.uuidString)",
                    imageSignature: pet.avatarThumbnailSignature,
                    petModelID: pet.persistentModelID,
                    emoji: pet.avatarEmoji,
                    fallback: pet.speciesEmoji,
                    tint: momentAccent
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "快速记录", en: "Quick Moment", de: "Schneller Moment"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pet.name)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "快速记录", en: "Quick Moment", de: "Schneller Moment"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "文字和照片会进入记录中心", en: "Text and photos go to Moments", de: "Text und Fotos landen in Momente"))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            Spacer(minLength: 0)

            if onRemove != nil {
                Button {
                    onRemove?()
                    close()
                } label: {
                    Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed)
                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            OhanaPopupCloseButton { close() }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var resolvedPlaceDisplay: String {
        let m = manualPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        if !m.isEmpty { return m }
        let status = locationModel.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch status {
        case "已获取位置":
            return l.tr(zh: "已获取位置", en: "Place captured", de: "Ort erfasst")
        case "已获取坐标":
            return l.tr(zh: "已获取坐标", en: "Location captured", de: "Standort erfasst")
        case "定位不可用":
            return l.tr(zh: "定位不可用", en: "Location unavailable", de: "Standort nicht verfügbar")
        default:
            return status
        }
    }

    @MainActor
    private func appendMoodTag(_ tag: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let addLen = noteText.isEmpty ? tag.count : tag.count + 1
        if noteText.count + addLen > 140 { return }
        if noteText.isEmpty { noteText = tag } else { noteText += " \(tag)" }
    }

    // MARK: - 位置（单行 + 可选展开输入）

    private var locationCompactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(momentAccent)
                    .frame(width: 20)

                if !resolvedPlaceDisplay.isEmpty {
                    Text(resolvedPlaceDisplay)
                        .font(OhanaFont.adaptive(size: 15, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        manualPlace = ""
                        locationModel.reset()
                        showLocationInput = false
                    } label: {
                        Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .symbolRenderingMode(.hierarchical)
                    }
                } else {
                    Button {
                        withAnimation(GoMotion.quick) {
                            showLocationInput.toggle()
                        }
                    } label: {
                        Text(l.tr(zh: "地点可选", en: "Place optional", de: "Ort optional"))
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    Button {
                        locationModel.requestFix(locationProvider: appServices.location)
                    } label: {
                        Text(l.tr(zh: "定位", en: "Locate", de: "Orten"))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(momentAccent))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }

            if showLocationInput {
                TextField(l.tr(zh: "输入地点", en: "Enter place", de: "Ort eingeben"), text: $manualPlace) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.callout(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                            .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 12) {
            if !selectedPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selectedPhotos) { photo in
                            draftPhotoCard(photo)
                        }
                    }
                    .padding(.horizontal, 2)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: max(1, maxDraftPhotos - selectedPhotos.count), matching: .images) {
                        photoActionLabel(
                            icon: "photo.on.rectangle.angled",
                            title: selectedPhotos.isEmpty
                                ? l.tr(zh: "相册", en: "Album", de: "Album")
                                : l.tr(zh: "继续添加", en: "Add More", de: "Mehr hinzufügen"),
                            color: momentAccent
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(selectedPhotos.count >= maxDraftPhotos)

                    Button { presentMomentCamera() } label: {
                        photoActionLabel(icon: "camera.fill", title: l.tr(zh: "拍照", en: "Camera", de: "Kamera"), color: Color.goTeal)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(selectedPhotos.count >= maxDraftPhotos)
                }

                Text(selectedPhotos.isEmpty
                    ? l.tr(zh: "可以只写文字，不一定要加照片", en: "Text only is fine too", de: "Nur Text ist auch okay")
                    : l.tr(zh: "已添加 \(selectedPhotos.count)/\(maxDraftPhotos) 张", en: "\(selectedPhotos.count)/\(maxDraftPhotos) photos added", de: "\(selectedPhotos.count)/\(maxDraftPhotos) Fotos hinzugefügt"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .padding(.horizontal, 22)
    }

    private func draftPhotoCard(_ photo: MomentDraftPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .overlay {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }

            Button {
                withAnimation(GoMotion.quick) {
                    selectedPhotos.removeAll { $0.id == photo.id }
                }
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goRed, in: Circle())
            }
            .padding(10)
        }
        .frame(width: max(0, min(ScreenCompat.width - 64, 320)), height: 240)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func photoActionLabel(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(title)
                .font(OhanaFont.callout(.black))
        }
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color, in: Capsule())
    }

    // MARK: - 心情标签 + 文字

    private var moodTags: [String] {
        [
            l.tr(zh: "😊 开心", en: "😊 Happy", de: "😊 Glücklich"),
            l.tr(zh: "😴 困了", en: "😴 Sleepy", de: "😴 Müde"),
            l.tr(zh: "🎉 有趣", en: "🎉 Fun", de: "🎉 Lustig"),
            l.tr(zh: "💕 爱你", en: "💕 Love", de: "💕 Liebe"),
            l.tr(zh: "🌟 棒棒", en: "🌟 Great", de: "🌟 Toll")
        ]
    }

    private var moodAndNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(moodTags, id: \.self) { tag in
                        Button { appendMoodTag(tag) } label: {
                            Text(tag)
                                .font(OhanaFont.caption(.black))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.ohanaControlFill))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text(l.tr(zh: "记录此刻的心情、趣事……", en: "Write what happened right now…", de: "Was ist gerade passiert?"))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .padding(.top, 16)
                        .padding(.leading, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteText)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(minHeight: 118, maxHeight: 154)
                    .padding(.horizontal, 12)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }

            Text("\(noteText.count)/140")
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .onChange(of: noteText) { _, new in
            if new.count > 140 {
                noteText = String(new.prefix(140))
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveRecord()
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(Color.arkInk)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: canSave ? "checkmark.circle.fill" : "lock.fill")
                        .font(OhanaFont.adaptive(size: 18)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                Text(isSaving
                    ? l.tr(zh: "保存中…", en: "Saving…", de: "Speichern…")
                    : (canSave
                        ? l.tr(zh: "保存这一刻", en: "Save Moment", de: "Moment speichern")
                        : l.tr(zh: "写点什么或添加照片", en: "Add text or a photo", de: "Text oder Foto hinzufügen")))
                    .font(OhanaFont.body(.black))
            }
            .foregroundStyle(canSave ? Color.arkInk : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(canSave ? Color.goPrimary : Color.ohanaControlFill)
            )
            .animation(GoMotion.quick, value: canSave)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave || isSaving)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 48)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(momentAccent)
            Text(l.tr(zh: "时刻已记录！", en: "Moment saved!", de: "Moment gespeichert!"))
                .font(OhanaFont.title3(.black))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.18)) // ui-v4: allow transient success overlay scrim
    }

    // MARK: - Save Logic

    private func saveRecord() {
        guard canSave else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let note = trimmedNote

        let placeName: String = {
            let m = manualPlace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !m.isEmpty { return m }
            return locationModel.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let lat = locationModel.latitude
        let lon = locationModel.longitude
        let hasCoords = lat != 0 || lon != 0
        let baseDate = Date()
        let draftPhotos = selectedPhotos
        let executorId = activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
        commandQueue.enqueue(.quickMoment(petID: pet?.id)) {
            let photoData = draftPhotos.compactMap { photo in
                photo.image.jpegData(compressionQuality: 0.82) ?? photo.image.pngData()
            }
            _ = MomentCommandExecutor(context: modelContext, services: appServices).recordMoment(
                pet: pet,
                note: note,
                photoData: photoData,
                locationLatitude: hasCoords ? lat : 0,
                locationLongitude: hasCoords ? lon : 0,
                locationPlacename: placeName,
                executorId: executorId,
                date: baseDate,
                revisionNote: "quickMoment.record"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(GoMotion.feedback) { savedSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isSaving = false
                onSaved?()
                close()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                noteText = ""
                selectedPhotos = []
                selectedItems = []
                manualPlace = ""
                locationModel.reset()
                withAnimation(GoMotion.quick) { savedSuccess = false }
            }
        }
    }

    @MainActor
    private func appendDraftPhotos(_ photos: [MomentDraftPhoto]) {
        guard !photos.isEmpty else { return }
        let remaining = max(0, maxDraftPhotos - selectedPhotos.count)
        guard remaining > 0 else { return }
        withAnimation(GoMotion.quick) {
            selectedPhotos.append(contentsOf: photos.prefix(remaining))
        }
    }

    private func presentMomentCamera() {
        requestOhanaCameraAccess {
            showCamera = true
        } onDenied: {
            showCameraPermissionAlert = true
        }
    }
}

private struct MomentDraftPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - 定位

private final class MomentLocationModel: ObservableObject {
    @Published var statusText = ""
    @Published var latitude = 0.0
    @Published var longitude = 0.0

    func reset() {
        statusText = ""
        latitude = 0
        longitude = 0
    }

    func requestFix(locationProvider: LocationProviding) {
        locationProvider.requestOneShotLocation { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case let .success(location):
                    self.latitude = location.coordinate.latitude
                    self.longitude = location.coordinate.longitude
                    self.reverseGeocode(location)
                case .failure:
                    self.statusText = "定位不可用"
                }
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            statusText = "已获取坐标"
            return
        }
        request.getMapItems { [weak self] mapItems, _ in
            guard let self else { return }
            let item = mapItems?.first
            let address = item?.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
            let parts = [item?.name, address].compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            self.statusText = parts.isEmpty ? "已获取坐标" : parts.joined(separator: " · ")
        }
    }
}
