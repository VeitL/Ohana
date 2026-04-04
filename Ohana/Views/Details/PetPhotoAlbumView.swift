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
    var hubPickerSelection: Binding<PhotosPickerItem?>? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var internalPickerItem: PhotosPickerItem? = nil
    @State private var selectedPhoto: PetPhotoLog? = nil
    @State private var showingPhotoDetail = false

    private var isHubEmbedded: Bool { hubPickerSelection != nil }

    private var pickerBinding: Binding<PhotosPickerItem?> {
        if let hub = hubPickerSelection { return hub }
        return $internalPickerItem
    }

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    private var sortedPhotos: [PetPhotoLog] {
        pet.photoLogs.sorted { $0.date > $1.date }
    }

    private var grouped: [(String, [PetPhotoLog])] {
        var dict: [String: [PetPhotoLog]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 M 月"
        for log in sortedPhotos {
            let key = formatter.string(from: log.date)
            dict[key, default: []].append(log)
        }
        return dict.sorted { a, b in
            let df = DateFormatter(); df.dateFormat = "yyyy 年 M 月"
            let da = df.date(from: a.key) ?? .distantPast
            let db = df.date(from: b.key) ?? .distantPast
            return da > db
        }
    }

    var body: some View {
        Group {
            if isHubEmbedded {
                albumCore
            } else {
                NavigationStack {
                    albumCore
                        .navigationTitle("\(pet.name)的相册")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { dismiss() } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                PhotosPicker(selection: pickerBinding, matching: .images) {
                                    Image(systemName: "plus.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Color.goPrimary)
                                        .font(OhanaFont.title2(.bold))
                                }
                            }
                        }
                }
                .onChange(of: internalPickerItem) { _, newItem in
                    Self.consumePickerItem(newItem, pet: pet, modelContext: modelContext)
                    internalPickerItem = nil
                }
            }
        }
        .sheet(isPresented: $showingPhotoDetail) {
            if let photo = selectedPhoto {
                PhotoDetailSheet(photo: photo)
            }
        }
    }

    /// 供 `PetMomentsHubView` 等外层调用：从 PhotosPicker 项写入相册
    static func consumePickerItem(_ newItem: PhotosPickerItem?, pet: Pet, modelContext: ModelContext) {
        guard let newItem else { return }
        Task { @MainActor in
            if let data = try? await newItem.loadTransferable(type: Data.self) {
                let log = PetPhotoLog(imageData: data, pet: pet)
                modelContext.insert(log)
                modelContext.safeSave()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private var albumCore: some View {
        ZStack {
            if !isHubEmbedded {
                ArkBackgroundView()
            }

            if sortedPhotos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(grouped, id: \.0) { month, photos in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(month)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .padding(.horizontal, 16)

                                LazyVGrid(columns: columns, spacing: 3) {
                                    ForEach(photos) { photo in
                                        Button {
                                            selectedPhoto = photo
                                            showingPhotoDetail = true
                                        } label: {
                                            photoThumbnail(photo)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                if let img = UIImage(data: photo.imageData) {
                                                    shareImage(img)
                                                }
                                            } label: {
                                                Label("分享", systemImage: "square.and.arrow.up")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                modelContext.delete(photo)
                                                modelContext.safeSave()
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
            Image(systemName: "photo.on.rectangle.angled")
                .font(OhanaFont.metric(size: 56, .medium))
                .foregroundStyle(.secondary)
            Text("暂无照片").font(OhanaFont.title3(.black))
            Text("记录\(pet.name)的每一个精彩瞬间").font(OhanaFont.subheadline(.medium)).foregroundStyle(.secondary)
            PhotosPicker(selection: pickerBinding, matching: .images) {
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

    @ViewBuilder
    private func photoThumbnail(_ photo: PetPhotoLog) -> some View {
        let side = (ScreenCompat.width - 6) / 3
        if let img = UIImage(data: photo.imageData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipped()
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: side, height: side)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let photo: PetPhotoLog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @State private var isEditingNote = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    if let img = UIImage(data: photo.imageData) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack(spacing: 10) {
                        Text(photo.date.formatted(.dateTime.year().month().day().weekday()))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))

                        if isEditingNote {
                            TextField("添加备注…", text: $noteText, axis: .vertical)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .onSubmit {
                                    photo.note = noteText
                                    modelContext.safeSave()
                                    isEditingNote = false
                                }
                        } else {
                            Text(photo.note.isEmpty ? "轻触添加备注" : photo.note)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(photo.note.isEmpty ? .white.opacity(0.3) : .white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    noteText = photo.note
                                    isEditingNote = true
                                }
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .background(.black.opacity(0.6))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .onAppear { noteText = photo.note }
    }
}
