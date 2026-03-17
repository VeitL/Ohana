//
//  WalkSummarySheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct WalkSummarySheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWalk: PetWalkLog? = nil
    
    private var sortedWalks: [PetWalkLog] {
        pet.walkLogs.sorted(by: { $0.startDate > $1.startDate })
    }
    
    private var totalDistance: Double {
        pet.walkLogs.reduce(0) { $0 + $1.distanceMeters }
    }
    
    private var totalDuration: TimeInterval {
        pet.walkLogs.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 总览卡
                        summaryCard
                        
                        // 记录列表
                        walkListSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("🏝️ 巡岛日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(sortedWalks.count)", label: "总次数", emoji: "🚶")
            
            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(width: 1, height: 40)
            
            statColumn(value: distanceFormatted(totalDistance), label: "总距离", emoji: "📏")
            
            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(width: 1, height: 40)
            
            statColumn(value: durationFormatted(totalDuration), label: "总时长", emoji: "⏱️")
        }
        .padding(.vertical, 24)
        .goTranslucentCard(cornerRadius: 24)
    }
    
    private func statColumn(value: String, label: String, emoji: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 20))
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Walk List
    private var walkListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史记录")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
                Spacer()
            }
            
            ForEach(sortedWalks) { walk in
                Button { selectedWalk = walk } label: {
                    walkRow(walk)
                }
                .buttonStyle(.plain)
            }
            
            if sortedWalks.isEmpty {
                Text("还没有巡岛记录")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
        .sheet(item: $selectedWalk) { walk in
            WalkDetailView(walk: walk, pet: pet)
        }
    }
    
    private func walkRow(_ walk: PetWalkLog) -> some View {
        HStack(spacing: 12) {
            // 地图缩略图
            if let data = walk.mapSnapshotData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    Image(systemName: "map")
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .frame(width: 56, height: 56)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            // 右侧箭头提示
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.25))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(walk.startDate, format: .dateTime.month().day().weekday(.abbreviated))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Label(walk.distanceText, systemImage: "arrow.triangle.swap")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                    
                    if walk.coconutsEarned > 0 {
                        Text("+\(walk.coconutsEarned)🥥")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }

                    Label(walk.durationText, systemImage: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
            
            Spacer()
            
            Text(walk.startDate, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Formatters
    private func distanceFormatted(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return String(format: "%.0fm", meters)
    }
    
    private func durationFormatted(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h\(minutes % 60)m"
        }
        return "\(minutes)min"
    }
}
