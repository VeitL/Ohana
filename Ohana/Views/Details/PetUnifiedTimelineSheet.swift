//
//  PetUnifiedTimelineSheet.swift
//  Ohana
//
//  岁月史书 — 独立 Sheet 版（从 PetDetailView 提取）
//

import SwiftUI
import SwiftData

struct PetUnifiedTimelineSheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss

    private var items: [UnifiedLogItem] {
        PetTimelineItemsBuilder.items(for: pet, limit: nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        petHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        summaryRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        if items.isEmpty {
                            emptyState
                        } else {
                            timelineList
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("岁月史书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var petHeader: some View {
        HStack(spacing: 10) {
            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 36, height: 36).clipShape(Circle())
            } else {
                Text(pet.avatarEmoji).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("共 \(items.count) 条记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var summaryRow: some View {
        let typeGroups = Dictionary(grouping: items, by: \.type)
        return HStack(spacing: 12) {
            summaryPill(icon: "figure.walk", count: typeGroups["walk"]?.count ?? 0, color: .goPrimary)
            summaryPill(icon: "drop.fill", count: typeGroups["potty"]?.count ?? 0, color: .goOrange)
            summaryPill(icon: "heart.text.clipboard", count: typeGroups["health"]?.count ?? 0, color: .goTeal)
            summaryPill(icon: "yensign.circle.fill", count: typeGroups["expense"]?.count ?? 0, color: .goYellow)
            summaryPill(icon: "scalemass.fill", count: typeGroups["weight"]?.count ?? 0, color: .goTeal)
        }
    }

    private func summaryPill(icon: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.primary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .goGlassBackground(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("还没有任何记录")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var timelineList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(item.color.opacity(0.18)).frame(width: 34, height: 34)
                            Image(systemName: item.iconName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(item.color)
                        }
                        if idx < items.count - 1 {
                            Rectangle()
                                .fill(.primary.opacity(0.08))
                                .frame(width: 1)
                                .frame(minHeight: 20)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                                .lineLimit(1)
                        }
                        Text(item.date, format: .dateTime.year().month().day().hour().minute())
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                    .padding(.top, 6)
                    .padding(.bottom, idx < items.count - 1 ? 16 : 0)

                    Spacer()
                }
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
