//
//  PetPhotoAlbumView.swift
//  Ohana
//
//  ArkSchemaV25：宠物照片回忆相册（可独立展示或嵌入「重要时刻」页）
//

import SwiftUI
import SwiftData
import PhotosUI

struct PetPhotoAlbumView: View {
    let pet: Pet
    /// 嵌入 `PetMomentsHubView` 时传入，由外层工具栏与 onChange 负责选图入库
    var hubPickerSelection: Binding<[PhotosPickerItem]>? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var internalPickerItems: [PhotosPickerItem] = []
    @State private var selectedPhoto: PetPhotoLog? = nil
    @State private var showingPhotoDetail = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var isHubEmbedded: Bool { hubPickerSelection != nil }

    private var pickerBinding: Binding<[PhotosPickerItem]> {
        if let hub = hubPickerSelection { return hub }
        return $internalPickerItems
    }

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    private var sortedPhotos: [PetPhotoLog] {
        pet.photoLogs.sorted { $0.date > $1.date }
    }

    private var grouped: [(String, [PetPhotoLog])] {
        var dict: [String: [PetPhotoLog]] = [:]
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateFormat = AppLanguage.fullMonthYearFormat
        for log in sortedPhotos {
            let key = formatter.string(from: log.date)
            dict[key, default: []].append(log)
        }
        return dict.sorted { a, b in
            let df = DateFormatter()
            df.locale = AppLanguage.effectiveLocale
            df.dateFormat = AppLanguage.fullMonthYearFormat
            let da = df.date(from: a.key) ?? .distantPast
            let db = df.date(from: b.key) ?? .distantPast
            return da > db
        }
    }

    private var albumNavigationTitle: String {
        L10n(AppLanguage.code).tr(
            zh: "\(pet.name)的相册",
            en: "\(pet.name)'s Album",
            de: "\(pet.name)s Album"
        )
    }

    var body: some View {
        Group {
            if isHubEmbedded {
                albumCore
            } else {
                NavigationStack {
                    albumCore
                        .navigationTitle(albumNavigationTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { dismiss() } label: {
                                    Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                        .symbolRenderingMode(.hierarchical).foregroundStyle(Color.ohanaSecondaryText)
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                PhotosPicker(selection: pickerBinding, maxSelectionCount: 12, matching: .images) {
                                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Color.goPrimary)
                                        .font(OhanaFont.title2(.bold))
                                }
                            }
                        }
                }
                .onChange(of: internalPickerItems) { _, newItems in
                    Self.consumePickerItems(newItems, pet: pet, modelContext: modelContext)
                    internalPickerItems = []
                }
            }
        }
        .sheet(isPresented: $showingPhotoDetail) {
            if let photo = selectedPhoto {
                PhotoDetailSheet(photo: photo, pet: pet)
            }
        }
        .onDisappear { commandQueue.cancelAll() }
    }

    /// 供 `PetMomentsHubView` 等外层调用：从 PhotosPicker 项写入相册
    static func consumePickerItem(_ newItem: PhotosPickerItem?, pet: Pet, modelContext: ModelContext) {
        guard let newItem else { return }
        consumePickerItems([newItem], pet: pet, modelContext: modelContext)
    }

    static func consumePickerItems(_ newItems: [PhotosPickerItem], pet: Pet, modelContext: ModelContext) {
        guard !newItems.isEmpty else { return }
        Task { @MainActor in
            var payloads: [Data] = []
            for item in newItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    payloads.append(data)
                }
            }
            let result = PetPhotoAlbumCommandExecutor(context: modelContext).createPhotos(
                data: payloads,
                pet: pet,
                note: "petPhoto.create"
            )
            if !result.photoIDs.isEmpty {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private var albumCore: some View {
        ZStack {
            if !isHubEmbedded {
                OhanaAppBackground()
            }

            if sortedPhotos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(grouped, id: \.0) { month, photos in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(month)
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                                    .padding(.horizontal, 16)

                                LazyVGrid(columns: columns, spacing: 3) {
                                    ForEach(photos) { photo in
                                        Button {
                                            selectedPhoto = photo
                                            showingPhotoDetail = true
                                        } label: {
                                            photoThumbnail(photo)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .contextMenu {
                                            Button {
                                                Task {
                                                    guard let image = await AttachmentImageDecoder.decode(photo.imageData) else { return }
                                                    await MainActor.run {
                                                        shareImage(image)
                                                    }
                                                }
                                            } label: {
                                                Label("分享", systemImage: "square.and.arrow.up")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                deletePhoto(photo)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.metric(size: 56, .medium))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text("暂无照片").font(OhanaFont.title3(.black))
            Text("记录\(pet.name)的每一个精彩瞬间").font(OhanaFont.subheadline(.medium)).foregroundStyle(Color.ohanaSecondaryText)
            PhotosPicker(selection: pickerBinding, maxSelectionCount: 12, matching: .images) {
                Text("添加第一张照片")
                    .font(OhanaFont.body(.black)).foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.goPrimary, in: Capsule())
            }
        }
        .padding(.top, 60)
    }

    private func shareImage(_ image: UIImage) {
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var presenter = root
            while let presented = presenter.presentedViewController { presenter = presented }
            av.popoverPresentationController?.sourceView = presenter.view
            presenter.present(av, animated: true)
        }
    }

    private func deletePhoto(_ photo: PetPhotoLog) {
        let command = DomainCommand.petPhotoDelete(petID: pet.id, photoID: photo.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            PetPhotoAlbumCommandExecutor(context: modelContext).deletePhoto(
                photo,
                pet: pet,
                note: "petPhoto.delete"
            )
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ photo: PetPhotoLog) -> some View {
        let side = (ScreenCompat.width - 6) / 3
        AsyncDecodedImageView(data: photo.imageData) { image in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipped()
        } placeholder: {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: side, height: side)
                .overlay(Image(systemName: "photo").foregroundStyle(Color.ohanaSecondaryText)) // a11y: allow decorative icon covered by surrounding text or control
        }
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let photo: PetPhotoLog
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @State private var isEditingNote = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea() // ui-v4: allow fullScreenPhotoViewer
                VStack(spacing: 0) {
                    AsyncDecodedImageView(data: photo.imageData) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack(spacing: 10) {
                        Text(photo.date.formatted(.dateTime.year().month().day().weekday()))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(.white.opacity(0.6)) // ui-v4: allow fullScreenPhotoViewer

                        if isEditingNote {
                            TextField("添加备注…", text: $noteText, axis: .vertical)
                                .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(.white) // ui-v4: allow fullScreenPhotoViewer
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .onSubmit {
                                    saveNote()
                                }
                        } else {
                            Text(photo.note.isEmpty ? "轻触添加备注" : photo.note)
                                .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(photo.note.isEmpty ? .white.opacity(0.3) : .white.opacity(0.8)) // ui-v4: allow fullScreenPhotoViewer
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    noteText = photo.note
                                    isEditingNote = true
                                }
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .background(.black.opacity(0.6)) // ui-v4: allow fullScreenPhotoViewer
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .symbolRenderingMode(.hierarchical).foregroundStyle(.white.opacity(0.7)) // ui-v4: allow fullScreenPhotoViewer
                    }
                }
            }
        }
        .onAppear { noteText = photo.note }
        .onDisappear { commandQueue.cancelAll() }
    }

    private func saveNote() {
        let command = DomainCommand.petPhotoUpdate(petID: pet.id, photoID: photo.id)
        isEditingNote = false
        commandQueue.enqueue(command) {
            PetPhotoAlbumCommandExecutor(context: modelContext).updateNote(
                noteText,
                photo: photo,
                pet: pet,
                note: "petPhoto.updateNote"
            )
        }
    }
}
