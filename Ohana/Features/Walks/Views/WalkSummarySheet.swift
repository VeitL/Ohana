//
//  WalkSummarySheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct WalkSummarySheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var selectedWalk: PetWalkLog? = nil
    @State private var showingGoalSetter = false
    @State private var goalDraft: Double = 0
    // P1: 本次巡岛心情备注
    @State private var draftMoodRating: Int = 0
    @State private var draftNotes: String = ""
    @State private var moodSaved = false

    private let weeklyGoalStepKm: Double = 0.5
    private let weeklyGoalMaxKm: Double = 100

    private var activeWalks: [PetWalkLog] {
        WalkFeaturePolicy.activeWalkLogs(for: pet)
    }

    private var sortedWalks: [PetWalkLog] {
        activeWalks.sorted(by: { $0.startDate > $1.startDate })
    }

    private var totalDistance: Double {
        activeWalks.reduce(0) { $0 + $1.distanceMeters }
    }

    private var totalDuration: TimeInterval {
        activeWalks.reduce(0) { $0 + $1.durationSeconds }
    }

    // MARK: - 本周步行距离
    private var weekStartDate: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 周一为周首
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
    }

    private var thisWeekDistanceKm: Double {
        let start = weekStartDate
        return activeWalks
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
                OhanaAppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        petHeader

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
        }
    }

    private var petHeader: some View {
        HStack(spacing: 14) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 54,
                backgroundOpacity: 0.16
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("遛狗详情")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .tracking(1.2)
                Text("\(pet.name) 的路线记录")
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("目标、总览和历史轨迹")
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardLarge)
    }

    // MARK: - Fresh Walk Helpers

    private func isFreshWalk(_ walk: PetWalkLog) -> Bool {
        Date().timeIntervalSince(walk.startDate) < 600 // 10 分钟内完成的步行
    }

    private func walkMoodCard(walk: PetWalkLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "circle") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text("本次心情")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
            }

            // 星级评分
            HStack(spacing: 10) {
                ForEach(1 ... 5, id: \.self) { star in
                    Button {
                        withAnimation(GoMotion.feedback) { draftMoodRating = star }
                    } label: {
                        Image(systemName: star <= draftMoodRating ? "star.fill" : "star")
                            .font(OhanaFont.adaptive(size: 22)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(star <= draftMoodRating ? Color.goYellow : Color.primary.opacity(0.25))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                Spacer()
                if draftMoodRating > 0 {
                    let labels = ["", "一般", "还行", "不错", "很好", "超棒！"]
                    Text(labels[draftMoodRating])
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goYellow)
                }
            }

            // 备注输入
            TextField("记录今天发生的趣事... (可选)", text: $draftNotes, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .lineLimit(1 ... 3)
                .padding(10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))

            // 保存按钮
            Button {
                let rating = draftMoodRating
                let notes = draftNotes
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { moodSaved = true }
                commandQueue.enqueue(.petWalkSummary(petID: pet.id, walkID: walk.id)) {
                    PetWalkCommandExecutor(context: modelContext, services: appServices).saveSummary(
                        for: walk,
                        pet: pet,
                        moodRating: rating,
                        notes: notes,
                        note: "walk.summary.mood"
                    )
                }
            } label: {
                Text("保存")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(draftMoodRating == 0 && draftNotes.isEmpty)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
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
                        .animation(GoMotion.feedback, value: weeklyProgress)
                    if pet.weeklyWalkGoalKm > 0 {
                        Text("\(Int(weeklyProgress * 100))%")
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(weeklyGoalColor)
                    } else {
                        Image(systemName: "flag") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("本周目标")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                    if pet.weeklyWalkGoalKm > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", thisWeekDistanceKm))
                                .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(String(format: "/ %.0f km", pet.weeklyWalkGoalKm))
                                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }
                        if weeklyProgress >= 1.0 {
                            Label("本周目标完成！", systemImage: "checkmark.circle.fill")
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goPrimary)
                        } else {
                            Text(String(format: "还差 %.1f km", pet.weeklyWalkGoalKm - thisWeekDistanceKm))
                                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }
                    } else {
                        Text("尚未设定目标")
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    }
                }
                Spacer()

                Button {
                    goalDraft = pet.weeklyWalkGoalKm
                    showingGoalSetter = true
                } label: {
                    Text(pet.weeklyWalkGoalKm > 0 ? "修改" : "设定目标")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
        .sheet(isPresented: $showingGoalSetter) {
            goalSetterSheet
                .ohanaCompactSheetPresentation(detents: [.height(320)])
        }
    }

    private var goalSetterSheet: some View {
        VStack(spacing: 20) {
            Text("设定每周步行目标")
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .padding(.top, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weeklyGoalDisplay(goalDraft))
                    .font(OhanaFont.adaptive(size: 52, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .contentTransition(.numericText())
                    .animation(GoMotion.feedback, value: goalDraft)
                Text("km / 周")
                    .font(OhanaFont.adaptive(size: 18, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            // 加减步进（0.5 km），替代固定档位
            HStack(spacing: 28) {
                Button {
                    adjustWeeklyGoal(-weeklyGoalStepKm)
                } label: {
                    Image(systemName: "minus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 40, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft <= 0 ? Color.secondary.opacity(0.35) : Color.goPrimary, Color.primary.opacity(0.12))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(goalDraft <= 0)

                Text("每次 ±\(weeklyGoalStepKm == floor(weeklyGoalStepKm) ? String(format: "%.0f", weeklyGoalStepKm) : String(format: "%.1f", weeklyGoalStepKm)) km")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)

                Button {
                    adjustWeeklyGoal(weeklyGoalStepKm)
                } label: {
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 40, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft >= weeklyGoalMaxKm ? Color.secondary.opacity(0.35) : Color.goPrimary, Color.primary.opacity(0.12))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(goalDraft >= weeklyGoalMaxKm)
            }

            Button {
                let goal = goalDraft
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingGoalSetter = false
                commandQueue.enqueue(.petWalkGoal(petID: pet.id)) {
                    PetWalkCommandExecutor(context: modelContext, services: appServices).saveWeeklyGoal(
                        goal,
                        for: pet,
                        note: "walk.summary.goal"
                    )
                }
            } label: {
                Text(goalDraft == 0 ? "清除目标" : "保存目标")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.row))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)

            Spacer(minLength: 8)
        }
    }

    private func weeklyGoalDisplay(_ km: Double) -> String {
        if km <= 0 { return "0" }
        let rounded = (km * 2).rounded() / 2
        if rounded.truncatingRemainder(dividingBy: 1) < 0.01 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    private func adjustWeeklyGoal(_ delta: Double) {
        let next = min(weeklyGoalMaxKm, max(0, goalDraft + delta))
        guard next != goalDraft else { return }
        goalDraft = (next * 2).rounded() / 2
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overview")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(thisWeekDistanceKm > 0 ? String(format: "本周 %.1f km", thisWeekDistanceKm) : "本周暂无记录")
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.goPrimary.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                statColumn(value: "\(sortedWalks.count)", label: "总次数", icon: "number", accent: Color.goPrimary)
                statColumn(value: distanceFormatted(totalDistance), label: "总距离", icon: "arrow.left.and.right", accent: Color.goTeal)
                statColumn(value: durationFormatted(totalDuration), label: "总时长", icon: "clock", accent: Color.goYellow)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardLarge)
    }

    private func statColumn(value: String, label: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(width: 26, height: 26) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(accent.opacity(0.12), in: Circle())
            Text(value)
                .font(OhanaFont.adaptive(size: 20, weight: .heavy, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    // MARK: - Walk List
    private var walkListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史记录")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(sortedWalks.count)")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }

            ForEach(Array(sortedWalks.enumerated()), id: \.element.id) { index, walk in
                Button { selectedWalk = walk } label: {
                    walkRow(walk)
                }
                .buttonStyle(ScaleButtonStyle())
                .ohanaSmoothAppear(index: index)
            }

            if sortedWalks.isEmpty {
                Text("还没有巡岛记录")
                    .font(OhanaFont.adaptive(size: 14)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
            }
        }
        .sheet(item: $selectedWalk) { walk in
            WalkDetailView(walk: walk, pet: pet)
        }
    }

    private func walkRow(_ walk: PetWalkLog) -> some View {
        HStack(spacing: 0) {
            routeArtwork(for: walk)
                .frame(width: 132, height: 104)
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [
                            .clear,
                            blendedCardSurface.opacity(colorScheme == .dark ? 0.74 : 0.90)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 54)
                }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(walk.startDate, format: .dateTime.month().day().weekday(.abbreviated))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer(minLength: 8)
                    Text(walk.startDate, format: .dateTime.hour().minute())
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                HStack(spacing: 12) {
                    compactMetric(icon: "arrow.left.and.right", text: walk.distanceText)
                    compactMetric(icon: "clock", text: walk.durationText)
                }

                HStack(spacing: 8) {
                    if walk.coconutsEarned > 0 {
                        compactBadge(icon: "plus", text: "\(walk.coconutsEarned)")
                    }
                    if walk.moodRating > 0 {
                        compactBadge(icon: "star", text: "\(walk.moodRating)/5")
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.55))
                }

                if let notes = walk.behaviorNotes, !notes.isEmpty {
                    Text(notes)
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 13)
            .padding(.leading, 14)
            .padding(.trailing, 14)
        }
        .frame(height: 104)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var blendedCardSurface: Color {
        colorScheme == .dark ? Color.ohanaCardSurface.opacity(0.86) : Color.ohanaCardSurface
    }

    @ViewBuilder
    private func routeArtwork(for walk: PetWalkLog) -> some View {
        WalkSummaryRouteArtwork(
            snapshotData: walk.mapSnapshotData,
            isDark: colorScheme == .dark
        )
    }

    private func compactMetric(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func compactBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(Color.goPrimary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.goPrimary.opacity(0.12), in: Capsule())
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

private struct WalkSummaryRouteArtwork: View {
    let snapshotData: Data?
    let isDark: Bool

    @State private var image: UIImage?

    private var imageKey: String {
        guard let snapshotData else { return "none" }
        return "\(snapshotData.count)-\(snapshotData.hashValue)"
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.ohanaPrimaryText.opacity(isDark ? 0.08 : 0.02))
                    .clipped()
            } else {
                placeholder
            }
        }
        .task(id: imageKey) {
            await decodeImage()
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.goPrimary.opacity(isDark ? 0.28 : 0.18),
                    Color.goTeal.opacity(isDark ? 0.18 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RoutePlaceholderPath()
                .stroke(
                    Color.primary.opacity(isDark ? 0.55 : 0.28),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .padding(20)
        }
    }

    @MainActor
    private func decodeImage() async {
        guard let snapshotData else {
            image = nil
            return
        }
        image = await MapSnapshotImageDecoder.decode(snapshotData)
    }
}

private struct RoutePlaceholderPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.18))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY - rect.height * 0.12),
            control2: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.20),
            control1: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.maxY - rect.height * 0.08),
            control2: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.20)
        )
        return path
    }
}
