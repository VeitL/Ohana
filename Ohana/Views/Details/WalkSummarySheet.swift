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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWalk: PetWalkLog? = nil
    @State private var showingGoalSetter = false
    @State private var goalDraft: Double = 0
    // P1: 本次巡岛心情备注
    @State private var draftMoodRating: Int = 0
    @State private var draftNotes: String = ""
    @State private var moodSaved = false

    private var sortedWalks: [PetWalkLog] {
        pet.walkLogs.sorted(by: { $0.startDate > $1.startDate })
    }
    
    private var totalDistance: Double {
        pet.walkLogs.reduce(0) { $0 + $1.distanceMeters }
    }
    
    private var totalDuration: TimeInterval {
        pet.walkLogs.reduce(0) { $0 + $1.durationSeconds }
    }

    // MARK: - 本周步行距离
    private var weekStartDate: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // 周一为周首
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
    }

    private var thisWeekDistanceKm: Double {
        let start = weekStartDate
        return pet.walkLogs
            .filter { $0.startDate >= start }
            .reduce(0) { $0 + $1.distanceMeters } / 1000.0
    }

    private var weeklyProgress: Double {
        guard pet.weeklyWalkGoalKm > 0 else { return 0 }
        return min(thisWeekDistanceKm / pet.weeklyWalkGoalKm, 1.0)
    }

    private var weeklyGoalColor: Color {
        weeklyProgress >= 1.0 ? Color.goPrimary : Color.goTeal
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 本次心情备注（仅最近一次步行完成后显示）
                        if let latest = sortedWalks.first, isFreshWalk(latest), !moodSaved {
                            walkMoodCard(walk: latest)
                        }

                        // 本周目标卡
                        weeklyGoalCard

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
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Fresh Walk Helpers

    private func isFreshWalk(_ walk: PetWalkLog) -> Bool {
        Date().timeIntervalSince(walk.startDate) < 600 // 10 分钟内完成的步行
    }

    private func walkMoodCard(walk: PetWalkLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🐾 本次巡岛心情")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            // 星级评分
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.2)) { draftMoodRating = star }
                    } label: {
                        Image(systemName: star <= draftMoodRating ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundStyle(star <= draftMoodRating ? Color.goYellow : Color.primary.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if draftMoodRating > 0 {
                    let labels = ["", "一般", "还行", "不错", "很好", "超棒！"]
                    Text(labels[draftMoodRating])
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
            }

            // 备注输入
            TextField("记录今天发生的趣事... (可选)", text: $draftNotes, axis: .vertical)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(1...3)
                .padding(10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 保存按钮
            Button {
                walk.moodRating = draftMoodRating
                walk.behaviorNotes = draftNotes.isEmpty ? nil : draftNotes
                modelContext.safeSave()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { moodSaved = true }
            } label: {
                Text("保存")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(draftMoodRating == 0 && draftNotes.isEmpty)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    // MARK: - Weekly Goal Card
    private var weeklyGoalCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(.primary.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: pet.weeklyWalkGoalKm > 0 ? weeklyProgress : 0)
                        .stroke(weeklyGoalColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.6), value: weeklyProgress)
                    if pet.weeklyWalkGoalKm > 0 {
                        Text("\(Int(weeklyProgress * 100))%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(weeklyGoalColor)
                    } else {
                        Image(systemName: "flag")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("本周目标")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                    if pet.weeklyWalkGoalKm > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", thisWeekDistanceKm))
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(String(format: "/ %.0f km", pet.weeklyWalkGoalKm))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        if weeklyProgress >= 1.0 {
                            Label("本周目标完成！", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.goPrimary)
                        } else {
                            Text(String(format: "还差 %.1f km", pet.weeklyWalkGoalKm - thisWeekDistanceKm))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                    } else {
                        Text("尚未设定目标")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                Spacer()

                Button {
                    goalDraft = pet.weeklyWalkGoalKm
                    showingGoalSetter = true
                } label: {
                    Text(pet.weeklyWalkGoalKm > 0 ? "修改" : "设定目标")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
        .sheet(isPresented: $showingGoalSetter) {
            goalSetterSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
    }

    private var goalSetterSheet: some View {
        VStack(spacing: 24) {
            Text("设定每周步行目标")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .padding(.top, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.0f", goalDraft))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .animation(.spring(duration: 0.2), value: goalDraft)
                Text("km / 周")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Stepper 控制
            HStack(spacing: 20) {
                ForEach([1.0, 3.0, 5.0, 7.0, 10.0], id: \.self) { preset in
                    Button {
                        goalDraft = preset
                    } label: {
                        Text(String(format: "%.0f", preset))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(goalDraft == preset ? .black : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(goalDraft == preset ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                pet.weeklyWalkGoalKm = goalDraft
                modelContext.safeSave()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingGoalSetter = false
            } label: {
                Text(goalDraft == 0 ? "清除目标" : "保存目标")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer()
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
                            .foregroundStyle(Color.goPrimary)
                    }

                    Label(walk.durationText, systemImage: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                // 心情 + 备注
                if walk.moodRating > 0 || walk.behaviorNotes != nil {
                    HStack(spacing: 4) {
                        if walk.moodRating > 0 {
                            Text(String(repeating: "★", count: walk.moodRating))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.goYellow)
                        }
                        if let notes = walk.behaviorNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
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
