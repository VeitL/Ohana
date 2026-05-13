//
//  PetMomentsHubView.swift
//  Ohana
//
//  岁月史书 + 相册：统一「重要时刻」记录与查看
//

import SwiftUI
import SwiftData
import PhotosUI

private enum PetMomentsTab: String, CaseIterable {
    case timeline = "时光"
    case photos = "相册"
}

struct PetMomentsHubView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var tab: PetMomentsTab = .timeline
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showingQuickMoment = false

    private var timelineItems: [UnifiedLogItem] {
        PetTimelineItemsBuilder.items(for: pet, limit: nil)
    }

    private var momentPhotos: [PetPhotoLog] {
        pet.photoLogs.sorted { $0.date > $1.date }
    }

    private var thisMonthMomentCount: Int {
        let calendar = Calendar.current
        return momentPhotos.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }

    private var notedMomentCount: Int {
        momentPhotos.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()
                VStack(spacing: 0) {
                    memoryOverview
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    Picker("", selection: $tab) {
                        ForEach(PetMomentsTab.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if tab == .timeline {
                        timelineScroll
                    } else {
                        PetPhotoAlbumView(pet: pet, hubPickerSelection: $photosPickerItems)
                    }
                }
                .onChange(of: photosPickerItems) { _, newItems in
                    PetPhotoAlbumView.consumePickerItems(newItems, pet: pet, modelContext: modelContext)
                    photosPickerItems = []
                }
            }
            .navigationTitle("\(pet.name) · 记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if tab == .photos {
                        PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 12, matching: .images) {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goPrimary)
                                .font(.system(size: 22))
                        }
                    } else {
                        Button {
                            showingQuickMoment = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goPrimary)
                                .font(.system(size: 22))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingQuickMoment) {
                QuickMomentSheet(pet: pet, onRemove: nil)
            }
        }
    }

    private var memoryOverview: some View {
        HStack(spacing: 14) {
            ZStack {
                ForEach(Array(momentPhotos.prefix(3).enumerated()), id: \.element.id) { index, photo in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: pet.themeColorHex).opacity(0.16))
                        .overlay {
                            if let img = UIImage(data: photo.imageData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "note.text")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(Color(hex: pet.themeColorHex))
                            }
                        }
                        .frame(width: 70, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .rotationEffect(.degrees(Double(index - 1) * 8))
                        .offset(x: CGFloat(index - 1) * 16, y: CGFloat(index) * 3)
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                }
                if momentPhotos.isEmpty {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 78, height: 88)
                        .overlay {
                            Text(pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji)
                                .font(.system(size: 34))
                        }
                }
            }
            .frame(width: 112, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                Text("记忆胶卷")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(momentPhotos.isEmpty ? "还没有记录，先留下今天的一句话或照片。" : "这个月新增 \(thisMonthMomentCount) 条 · \(notedMomentCount) 条有备注")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    overviewPill("\(momentPhotos.count)", "照片")
                    overviewPill("\(timelineItems.count)", "全部")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func overviewPill(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 13, weight: .black, design: .rounded))
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.goPrimary, in: Capsule())
    }

    private var timelineScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("共 \(timelineItems.count) 条记录")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                }
                .padding(.horizontal, 20)

                if timelineItems.isEmpty {
                    emptyMemoryCard
                } else {
                    if !momentPhotos.isEmpty {
                        recentMemoryStrip
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(timelineItems.enumerated()), id: \.element.id) { idx, item in
                        timelineRow(idx: idx, item: item)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.top, 4)
        }
    }

    private var emptyMemoryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text("还没有任何记录")
                .font(.system(size: 17, weight: .black, design: .rounded))
            Button {
                showingQuickMoment = true
            } label: {
                Text("记录第一刻")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var recentMemoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(momentPhotos.prefix(8)) { photo in
                    memoryStripCard(photo)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func memoryStripCard(_ photo: PetPhotoLog) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: pet.themeColorHex).opacity(0.18))
            if let img = UIImage(data: photo.imageData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            }
            LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .bottom, endPoint: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(photo.date, format: .dateTime.month().day())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                if !photo.note.isEmpty {
                    Text(photo.note)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                }
            }
            .foregroundStyle(.white)
            .padding(10)
        }
        .frame(width: 132, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func timelineRow(idx: Int, item: UnifiedLogItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(item.color.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: item.iconName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(item.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Text(item.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 6)
            Spacer()
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
}
