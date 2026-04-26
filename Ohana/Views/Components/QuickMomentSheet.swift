//
//  QuickMomentSheet.swift
//  Ohana
//
//  快捷操作「记录」：快速记录当下 Moment，可附带照片，保存到宠物相册（PetPhotoLog）。
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import UIKit
import Combine

struct QuickMomentSheet: View {
    let pet: Pet?
    var onRemove: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var noteText = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera = false
    @State private var manualPlace = ""
    @StateObject private var locationModel = MomentLocationModel()
    @State private var isSaving = false
    @State private var savedSuccess = false
    @State private var showLocationInput = false

    @Query(sort: \PetPhotoLog.date, order: .reverse) private var allPhotos: [PetPhotoLog]

    /// 记录时刻强调色：有宠物时用主题色
    private var momentAccent: Color {
        guard let pet else { return Color.goPrimary }
        let hex = pet.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return Color(hex: hex.isEmpty ? "FF7600" : hex)
    }

    private var petPhotos: [PetPhotoLog] {
        guard let pet else {
            return Array(allPhotos.prefix(12))
        }
        return allPhotos.filter { $0.pet?.id == pet.id }.prefix(12).map { $0 }
    }

    private var canSave: Bool {
        selectedImage != nil || !noteText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        momentHeader

                        photoSection

                        moodAndNoteSection

                        locationCompactSection

                        Spacer().frame(height: 8)

                        saveButton

                        if !petPhotos.isEmpty {
                            recentSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .transaction { $0.disablesAnimations = false }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if onRemove != nil {
                            Menu {
                                Button(role: .destructive) {
                                    onRemove?()
                                    dismiss()
                                } label: {
                                    Label("移除此快捷入口", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.secondary)
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run { selectedImage = img }
                }
            }
        }
        .overlay {
            if savedSuccess {
                successOverlay
            }
        }
        .sheet(isPresented: $showCamera) {
            MomentCameraPicker(image: $selectedImage)
        }
    }

    // MARK: - Header（Scroll 内：为谁记录）

    private var momentHeader: some View {
        HStack(spacing: 10) {
            if let pet {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(momentAccent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    if let data = pet.avatarImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Text(pet.avatarEmoji).font(.system(size: 20))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("记录时刻")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("为 \(pet.name)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("记录时刻")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("照片与文字将保存到相册")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private var resolvedPlaceDisplay: String {
        let m = manualPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        if !m.isEmpty { return m }
        return locationModel.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(momentAccent)
                    .frame(width: 20)

                if !resolvedPlaceDisplay.isEmpty {
                    Text(resolvedPlaceDisplay)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        manualPlace = ""
                        locationModel.reset()
                        showLocationInput = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                } else {
                    Button {
                        showLocationInput.toggle()
                    } label: {
                        Text("添加位置（可选）")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Button {
                        locationModel.requestFix()
                    } label: {
                        Text("定位")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(momentAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(momentAccent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if showLocationInput {
                TextField("输入地点", text: $manualPlace)
                    .font(.system(size: 15, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        Group {
            if let img = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        selectedImage = nil
                        selectedItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding(10)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.35))

                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 28))
                                        .foregroundStyle(momentAccent)
                                    Text("从相册选择")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button { showCamera = true } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color.goTeal)
                                    Text("拍照")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Text("也可以跳过照片，仅写下文字")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                }
                .frame(height: 140)
            }
        }
    }

    // MARK: - 心情标签 + 文字

    private let moodTags = ["😊 开心", "😴 困了", "🎉 有趣", "💕 爱你", "🌟 棒棒"]

    private var moodAndNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(moodTags, id: \.self) { tag in
                        Button { appendMoodTag(tag) } label: {
                            Text(tag)
                                .font(.system(size: 13, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.primary.opacity(0.07)))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("记录此刻的心情、趣事……")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 12)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteText)
                    .font(.system(size: 15, design: .rounded))
                    .frame(minHeight: 100, maxHeight: 140)
                    .padding(.horizontal, 12)
                    .scrollContentBackground(.hidden)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text("\(noteText.count)/140")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
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
                        .font(.system(size: 18))
                }
                Text(
                    isSaving ? "保存中…"
                        : (canSave ? "保存这一刻 🌟" : "写点什么或添加照片")
                )
                .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(canSave ? Color.arkInk : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(canSave ? Color(hex: "C6FF00") : Color.primary.opacity(0.08))
            )
            .animation(.spring(response: 0.3), value: canSave)
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isSaving)
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("近期时刻", systemImage: "photo.stack.fill")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(petPhotos) { photo in
                    if let img = UIImage(data: photo.imageData) {
                        ZStack(alignment: .bottomLeading) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            if !photo.note.isEmpty {
                                LinearGradient(
                                    colors: [.black.opacity(0.6), .clear],
                                    startPoint: .bottom, endPoint: .center
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(photo.note)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .padding(6)
                            }
                        }
                    } else {
                        // 纯文字记录
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(momentAccent.opacity(0.12))
                            .frame(height: 100)
                            .overlay {
                                Text(photo.note)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(4)
                                    .padding(8)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(momentAccent)
            Text("时刻已记录！")
                .font(.system(size: 18, weight: .black, design: .rounded))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .transition(.opacity)
    }

    // MARK: - Save Logic

    private func saveRecord() {
        guard canSave else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let note = noteText.trimmingCharacters(in: .whitespaces)

        let placeName: String = {
            let m = manualPlace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !m.isEmpty { return m }
            return locationModel.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let lat = locationModel.latitude
        let lon = locationModel.longitude
        let hasCoords = lat != 0 || lon != 0
        var savedLog: PetPhotoLog?

        if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.82) {
            let log = PetPhotoLog(
                imageData: data, date: Date(), note: note, pet: pet,
                locationLatitude: hasCoords ? lat : 0,
                locationLongitude: hasCoords ? lon : 0,
                locationPlacename: placeName
            )
            modelContext.insert(log)
            savedLog = log
        } else if !note.isEmpty {
            let placeholder = UIImage()
            let data = placeholder.pngData() ?? Data(count: 1)
            let log = PetPhotoLog(
                imageData: data, date: Date(), note: note, pet: pet,
                locationLatitude: hasCoords ? lat : 0,
                locationLongitude: hasCoords ? lon : 0,
                locationPlacename: placeName
            )
            modelContext.insert(log)
            savedLog = log
        }

        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        QuestManager.shared.addCoconuts(1, emoji: "📸", title: "记录时刻 +1🥥")
        if let savedLog {
            CareLedgerService.record(
                occurredAt: savedLog.date,
                actorKind: .unknown,
                subjectKind: pet == nil ? .system : .pet,
                subjectId: pet?.id.uuidString,
                eventKind: .milestone,
                actionType: "petMoment",
                note: savedLog.note,
                source: .quickAction,
                legacyModelName: "PetPhotoLog",
                legacyModelId: savedLog.id.uuidString,
                coconutDelta: 1,
                context: modelContext
            )
        }

        withAnimation(.spring(response: 0.3)) { savedSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            noteText = ""
            selectedImage = nil
            selectedItem = nil
            manualPlace = ""
            locationModel.reset()
            isSaving = false
            withAnimation(.easeOut(duration: 0.25)) { savedSuccess = false }
        }
    }
}

// MARK: - 定位

private final class MomentLocationModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var statusText = ""
    @Published var latitude = 0.0
    @Published var longitude = 0.0
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func reset() {
        statusText = ""
        latitude = 0
        longitude = 0
    }

    func requestFix() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        latitude = l.coordinate.latitude
        longitude = l.coordinate.longitude
        let geo = CLGeocoder()
        geo.reverseGeocodeLocation(l) { [weak self] marks, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let t = marks?.first {
                    let parts = [t.name, t.thoroughfare, t.locality].compactMap { $0 }
                    self.statusText = parts.isEmpty ? "已获取位置" : parts.joined(separator: " · ")
                } else {
                    self.statusText = "已获取坐标"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusText = "定位不可用"
        }
    }
}

// MARK: - 相机

private struct MomentCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coord { Coord(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MomentCameraPicker
        init(_ p: MomentCameraPicker) { parent = p }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }
    }
}
