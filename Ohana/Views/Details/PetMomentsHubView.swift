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
    @State private var photosPickerItem: PhotosPickerItem?

    private var timelineItems: [UnifiedLogItem] {
        PetTimelineItemsBuilder.items(for: pet, limit: nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                VStack(spacing: 0) {
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
                        PetPhotoAlbumView(pet: pet, hubPickerSelection: $photosPickerItem)
                    }
                }
                .onChange(of: photosPickerItem) { _, newItem in
                    PetPhotoAlbumView.consumePickerItem(newItem, pet: pet, modelContext: modelContext)
                    photosPickerItem = nil
                }
            }
            .navigationTitle("\(pet.name) · 重要时刻")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                if tab == .photos {
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goPrimary)
                                .font(.system(size: 22))
                        }
                    }
                }
            }
        }
    }

    private var timelineScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("共 \(timelineItems.count) 条记录")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if timelineItems.isEmpty {
                    Text("还没有任何记录")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    ForEach(Array(timelineItems.enumerated()), id: \.element.id) { idx, item in
                        timelineRow(idx: idx, item: item)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.top, 4)
        }
    }

    private func timelineRow(idx: Int, item: UnifiedLogItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(item.color.opacity(0.18)).frame(width: 34, height: 34)
                    Image(systemName: item.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(item.color)
                }
                if idx < timelineItems.count - 1 {
                    Rectangle()
                        .fill(.primary.opacity(0.08))
                        .frame(width: 1)
                        .frame(minHeight: 20)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(item.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 6)
            .padding(.bottom, idx < timelineItems.count - 1 ? 16 : 0)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
