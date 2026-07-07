//
//  PetPhotoAlbumView.swift
//  Ohana
//
//  ArkSchemaV25：宠物照片回忆相册（可独立展示或嵌入「重要时刻」页）
//

import PhotosUI
import SwiftData
import SwiftUI

struct PetPhotoAlbumView: View {
    let pet: Pet
    let renderData: PetPhotoAlbumRenderData
    /// 嵌入 `PetMomentsHubView` 时传入，由外层工具栏与 onChange 负责选图入库
    var hubPickerSelection: Binding<[PhotosPickerItem]>?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @State private var internalPickerItems: [PhotosPickerItem] = []
    @State private var selectedPhoto: PetPhotoAlbumPhotoItem? = nil
    @State private var showingPhotoDetail = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        pet: Pet,
        renderData: PetPhotoAlbumRenderData,
        hubPickerSelection: Binding<[PhotosPickerItem]>? = nil
    ) {
        self.pet = pet
        self.renderData = renderData
        self.hubPickerSelection = hubPickerSelection
    }

    private var isHubEmbedded: Bool { hubPickerSelection != nil }

    private var pickerBinding: Binding<[PhotosPickerItem]> {
        if let hub = hubPickerSelection { return hub }
        return $internalPickerItems
    }

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

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
                    Self.consumePickerItems(newItems, pet: pet, modelContext: modelContext, services: appServices)
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
    static func consumePickerItem(_ newItem: PhotosPickerItem?, pet: Pet, modelContext: ModelContext, services: AppServices) {
        guard let newItem else { return }
        consumePickerItems([newItem], pet: pet, modelContext: modelContext, services: services)
    }

    static func consumePickerItems(_ newItems: [PhotosPickerItem], pet: Pet, modelContext: ModelContext, services: AppServices) {
        guard !newItems.isEmpty else { return }
        Task { @MainActor in
            var payloads: [Data] = []
            for item in newItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    payloads.append(data)
                }
            }
            let command = DomainCommand.petPhotoCreate(petID: pet.id)
            do {
                let result = try PetPhotoAlbumCommandExecutor(context: modelContext, services: services).createPhotos(
                    data: payloads,
                    pet: pet,
                    note: "petPhoto.create"
                )
                if !result.photoIDs.isEmpty {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } catch {
                services.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    private var albumCore: some View {
        ZStack {
            if !isHubEmbedded {
                OhanaAppBackground()
            }

            if renderData.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(renderData.groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title)
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                                    .padding(.horizontal, 16)

                                LazyVGrid(columns: columns, spacing: 3) {
                                    ForEach(group.photos) { photo in
                                        Button {
                                            selectedPhoto = photo
                                            showingPhotoDetail = true
                                        } label: {
                                            photoThumbnail(photo)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .contextMenu {
                                            Button {
                                                sharePhoto(photo)
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
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            av.popoverPresentationController?.sourceView = presenter.view
            presenter.present(av, animated: true)
        }
    }

    private func sharePhoto(_ photo: PetPhotoAlbumPhotoItem) {
        let key = MediaThumbnailKey(
            id: "pet-photo-share-\(photo.id.uuidString)",
            sourceSignature: photo.imageSignature,
            maxPixel: 2400
        )
        Task { @MainActor in
            guard let image = await MediaThumbnailProvider.image(
                for: key,
                asyncDataProvider: { await imageData(for: photo) }
            ) else { return }
            shareImage(image)
        }
    }

    private func deletePhoto(_ photo: PetPhotoAlbumPhotoItem) {
        let command = DomainCommand.petPhotoDelete(petID: pet.id, photoID: photo.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            guard let photoLog = photoLog(for: photo) else { return }
            do {
                try PetPhotoAlbumCommandExecutor(context: modelContext, services: appServices).deletePhoto(
                    photoLog,
                    pet: pet,
                    note: "petPhoto.delete"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ photo: PetPhotoAlbumPhotoItem) -> some View {
        let side = (ScreenCompat.width - 6) / 3
        AsyncDecodedImageView(
            cacheID: "pet-photo-thumbnail-\(photo.id.uuidString)",
            sourceSignature: photo.imageSignature,
            maxPixel: side * 2,
            asyncDataProvider: {
                await imageData(for: photo)
            }
        ) { image in
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

    private func imageData(for photo: PetPhotoAlbumPhotoItem) async -> Data? {
        guard photo.canAttemptImageAttachmentLoad else {
            return nil
        }
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        return await loader.petPhotoLogImageData(modelID: photo.modelID)
    }

    private func photoLog(for photo: PetPhotoAlbumPhotoItem) -> PetPhotoLog? {
        modelContext.model(for: photo.modelID) as? PetPhotoLog
    }
}

nonisolated struct PetPhotoAlbumPhotoItem: Identifiable, Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let date: Date
    let note: String
    let imageSignature: String
    let canAttemptImageAttachmentLoad: Bool

    init(log: PetPhotoLog) {
        id = log.id
        modelID = log.persistentModelID
        date = log.date
        note = log.note
        imageSignature = log.imageThumbnailSignature
        canAttemptImageAttachmentLoad = log.canAttemptImageAttachmentLoad
    }
}

nonisolated struct PetPhotoAlbumRenderData: Sendable {
    struct MonthGroup: Identifiable, Sendable {
        let monthStart: Date
        let title: String
        let photos: [PetPhotoAlbumPhotoItem]

        var id: TimeInterval { monthStart.timeIntervalSinceReferenceDate }
    }

    static let empty = PetPhotoAlbumRenderData(groups: [])

    let groups: [MonthGroup]

    var isEmpty: Bool {
        groups.allSatisfy(\.photos.isEmpty)
    }

    static func build(photoLogs: [PetPhotoLog], languageCode: String = AppLanguage.code) -> PetPhotoAlbumRenderData {
        guard !photoLogs.isEmpty else { return .empty }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        let normalizedLanguageCode = AppLanguage.normalize(languageCode)
        formatter.locale = Locale(identifier: AppLanguage.option(for: normalizedLanguageCode).localeIdentifier)
        formatter.dateFormat = normalizedLanguageCode == "zh" ? "yyyy年 M月" : "MMMM yyyy"

        var grouped: [Date: [PetPhotoAlbumPhotoItem]] = [:]
        for log in photoLogs {
            let components = calendar.dateComponents([.year, .month], from: log.date)
            let monthStart = calendar.date(from: components) ?? calendar.startOfDay(for: log.date)
            grouped[monthStart, default: []].append(PetPhotoAlbumPhotoItem(log: log))
        }

        let groups = grouped
            .map { monthStart, logs in
                MonthGroup(
                    monthStart: monthStart,
                    title: formatter.string(from: monthStart),
                    photos: logs.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.monthStart > $1.monthStart }

        return PetPhotoAlbumRenderData(groups: groups)
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let photo: PetPhotoAlbumPhotoItem
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @State private var noteText: String = ""
    @State private var displayedNote: String = ""
    @State private var isEditingNote = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea() // ui-v4: allow fullScreenPhotoViewer
                VStack(spacing: 0) {
                    AsyncDecodedImageView(
                        cacheID: "pet-photo-detail-\(photo.id.uuidString)",
                        sourceSignature: photo.imageSignature,
                        maxPixel: 2400,
                        asyncDataProvider: {
                            await imageData()
                        }
                    ) { image in
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
                            TextField("添加备注…", text: $noteText, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                                .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(.white) // ui-v4: allow fullScreenPhotoViewer
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .onSubmit {
                                    saveNote()
                                }
                        } else {
                            Text(displayedNote.isEmpty ? "轻触添加备注" : displayedNote)
                                .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(displayedNote.isEmpty ? .white.opacity(0.3) : .white.opacity(0.8)) // ui-v4: allow fullScreenPhotoViewer
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    noteText = displayedNote
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
        .onAppear {
            displayedNote = photo.note
            noteText = photo.note
        }
        .onDisappear { commandQueue.cancelAll() }
    }

    private func saveNote() {
        let command = DomainCommand.petPhotoUpdate(petID: pet.id, photoID: photo.id)
        isEditingNote = false
        let cleanNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        displayedNote = cleanNote
        commandQueue.enqueue(command) {
            guard let photoLog else { return }
            do {
                try PetPhotoAlbumCommandExecutor(context: modelContext, services: appServices).updateNote(
                    cleanNote,
                    photo: photoLog,
                    pet: pet,
                    note: "petPhoto.updateNote"
                )
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    private func imageData() async -> Data? {
        guard photo.canAttemptImageAttachmentLoad else {
            return nil
        }
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        return await loader.petPhotoLogImageData(modelID: photo.modelID)
    }

    private var photoLog: PetPhotoLog? {
        modelContext.model(for: photo.modelID) as? PetPhotoLog
    }
}
