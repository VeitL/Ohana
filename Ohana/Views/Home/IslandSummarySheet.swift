//
//  IslandSummarySheet.swift
//  Ohana
//
//  首页岛屿顶图点开后的"岛屿近况"抽屉：
//  展示所有负反馈信号、连击状态、今日全家族活跃家人列表。
//

import SwiftUI
import SwiftData

struct IslandSummarySheet: View {
    let pets: [Pet]
    let plants: [Plant]
    let pendingReminders: [Reminder]
    let checkInStreak: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var signals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(pets: pets, plants: plants)
    }

    private var mood: IslandMood {
        IslandMoodCalculator.calculate(pets: pets, pendingReminders: pendingReminders, plants: plants)
    }

    private var moodEmoji: String {
        switch mood {
        case .celebrate: return "🎉"
        case .plantBreeze: return "🌿"
        case .breezy: return "🌤"
        case .calm: return "☀️"
        case .cloudy: return "⛅"
        case .storm: return "⛈"
        }
    }

    private var moodText: String {
        switch mood {
        case .celebrate:   return "岛屿庆典日"
        case .plantBreeze: return "植物刚喝饱水"
        case .breezy:      return "岛屿微风"
        case .calm:        return "岛屿晴朗"
        case .cloudy:      return "岛屿阴天"
        case .storm:       return "岛屿风暴 · 注意紧急事项"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 天气主图
                    moodCard
                    // 连击卡
                    streakCard
                    // 负反馈列表
                    if !signals.isEmpty {
                        Text("需要关心")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.primary.opacity(0.4))
                            .padding(.top, 4)
                        VStack(spacing: 10) {
                            ForEach(signals) { s in
                                signalRow(s)
                            }
                        }
                    } else {
                        allGoodCard
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("岛屿近况")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }
            }
        }
    }

    private var moodCard: some View {
        HStack(spacing: 14) {
            Text(moodEmoji)
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 4) {
                Text(moodText)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("根据今日喂食/用药/连击/植物护理综合判断")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var streakCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(checkInStreak >= 7 ? Color.orange.opacity(0.2) : Color.goPrimary.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(checkInStreak >= 7 ? Color.orange : Color.goPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("连续打卡 \(checkInStreak) 天")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(checkInStreak >= 7 ? "火苗燃烧中，继续保持 🔥" : "每天至少 1 次打卡维持连击")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func signalRow(_ s: IslandNegativeSignal) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(s.severity == .critical ? Color.goRed.opacity(0.18) : Color.goYellow.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: s.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(s.severity == .critical ? Color.goRed : Color.goYellow)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(s.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    s.severity == .critical ? Color.goRed.opacity(0.3) : Color.goYellow.opacity(0.28),
                    lineWidth: 1
                )
        )
    }

    private var allGoodCard: some View {
        HStack(spacing: 12) {
            Text("🎉").font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text("一切安好")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("当前没有需要关注的信号，继续享受岛屿生活吧")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.goPrimary.opacity(0.1))
        )
    }
}
