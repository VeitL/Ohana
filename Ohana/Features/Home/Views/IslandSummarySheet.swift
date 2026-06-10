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
    @Environment(AppServices.self) private var appServices

    private var signals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(
            pets: pets,
            plants: plants,
            healthAlerts: appServices.healthAlerts
        )
    }

    private var mood: IslandMood {
        IslandMoodCalculator.calculate(
            pets: pets,
            pendingReminders: pendingReminders,
            plants: plants,
            healthAlerts: appServices.healthAlerts
        )
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
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
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
                        Image(systemName: "xmark.circle.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 22, weight: .semibold))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    }
                }
            }
        }
    }

    private var moodCard: some View {
        HStack(spacing: 14) {
            Text(moodEmoji)
                .font(OhanaFont.adaptive(size: 44))
            VStack(alignment: .leading, spacing: 4) {
                Text(moodText)
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ohanaCardSurface)
        )
    }

    private var streakCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(checkInStreak >= 7 ? Color.orange.opacity(0.2) : Color.goPrimary.opacity(0.16))
                    .frame(width: 40, height: 40) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(systemName: "flame.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 18, weight: .bold))
                    .foregroundStyle(checkInStreak >= 7 ? Color.orange : Color.goPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("连续打卡 \(checkInStreak) 天")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ohanaCardSurface)
        )
    }

    private func signalRow(_ s: IslandNegativeSignal) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(s.severity == .critical ? Color.goRed.opacity(0.18) : Color.goYellow.opacity(0.18))
                    .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(systemName: s.iconName)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold))
                    .foregroundStyle(s.severity == .critical ? Color.goRed : Color.goYellow)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(s.detail)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 11, weight: .bold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ohanaCardSurface)
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
            Text("🎉").font(OhanaFont.adaptive(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text("一切安好")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
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
