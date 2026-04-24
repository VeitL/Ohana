//
//  IslandMoodHeaderStrip.swift
//  Ohana
//
//  首页简化 · 岛屿三层重构（P0）
//  把原先独立成行的「家庭活动条 / 负反馈 Banner / HighlightDeck 头部问候」
//  汇总为一条 60pt 的可爱胶囊，作为首页第一视觉锚点：
//      ☀️ 岛屿晴朗 · 小咪今早已加餐  →
//  点击展开完整摘要 Sheet。
//

import SwiftUI
import SwiftData

struct IslandMoodHeaderStrip: View {
    let pets: [Pet]
    let plants: [Plant]
    let pendingReminders: [Reminder]
    let activePet: Pet?
    let checkInStreak: Int
    var onExpand: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @State private var cloudOffsetA: CGFloat = -8
    @State private var cloudOffsetB: CGFloat = 8
    @State private var breath: CGFloat = 0

    // MARK: - 计算综合状态

    private var mood: IslandMood {
        IslandMoodCalculator.calculate(pets: pets, pendingReminders: pendingReminders, plants: plants)
    }

    private var negativeSignals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(pets: pets, plants: plants)
    }

    /// 显示的 emoji（跟天气/情绪映射）
    private var moodEmoji: String {
        switch mood {
        case .celebrate:   return "🎉"
        case .plantBreeze: return "🌿"
        case .breezy:      return "🌤"
        case .calm:        return "☀️"
        case .cloudy:      return "⛅"
        case .storm:       return "⛈"
        }
    }

    /// 主色（与严重度/情绪联动）
    private var accentColor: Color {
        switch mood {
        case .celebrate:   return Color.goYellow
        case .plantBreeze: return Color.goLime
        case .breezy:      return Color.goPrimary
        case .calm:        return Color.goPrimary
        case .cloudy:      return Color.goYellow
        case .storm:       return Color.goRed
        }
    }

    /// 一行核心信息（严重级 > 庆祝级 > 连击 > 轻度提醒 > 问候）
    private var primaryMessage: (title: String, detail: String?) {
        let activePets = pets.filter { !$0.hasPassedAway }

        // 1. 紧急负反馈（红色）
        if let critical = negativeSignals.first(where: { $0.severity == .critical }) {
            return (critical.title, critical.detail)
        }

        // 2. 庆祝（里程碑 / 全部完成）
        switch mood {
        case .celebrate:
            return (celebrateTitle(), nil)
        case .plantBreeze:
            return ("岛屿微风 · 植物刚喝饱水", nil)
        default: break
        }

        // 3. 连击高亮（≥ 3 天）
        if checkInStreak >= 7 {
            return ("🔥 已连续打卡 \(checkInStreak) 天", "岛屿风和日丽")
        } else if checkInStreak >= 3 {
            return ("连击 \(checkInStreak) 天 · 继续加油", nil)
        }

        // 4. 温和提醒
        if let warning = negativeSignals.first {
            return (warning.title, warning.detail)
        }

        // 5. 默认问候
        if let pet = activePet ?? activePets.first {
            return ("岛屿晴朗 · \(pet.name) 正在享受今天", nil)
        }
        return ("岛屿等待你的第一位家人", nil)
    }

    private func celebrateTitle() -> String {
        let actives = pets.filter { !$0.hasPassedAway }
        if let milestonePet = actives.first(where: {
            [100, 365, 500, 730, 1000, 1095].contains($0.daysTogether)
        }) {
            return "🎉 陪伴 \(milestonePet.name) 第 \(milestonePet.daysTogether) 天"
        }
        return "岛屿庆祝 · 今日任务全部完成"
    }

    /// 角标数量（红点：需要关注的信号数）
    private var badgeCount: Int {
        negativeSignals.count
    }

    // MARK: - Body

    var body: some View {
        Button(action: onExpand) {
            HStack(alignment: .center, spacing: 12) {
                // 左：情绪天气图（带动画）
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16))
                        .frame(width: 40, height: 40)
                        .scaleEffect(1 + breath * 0.06)

                    Text(moodEmoji)
                        .font(.system(size: 22))
                        .offset(y: breath * 0.8)

                    // 两片飘云（仅在 breezy/cloudy/calm 展示）
                    if mood == .breezy || mood == .cloudy || mood == .calm {
                        Text("☁️")
                            .font(.system(size: 9))
                            .opacity(0.55)
                            .offset(x: cloudOffsetA, y: -14)
                        Text("☁️")
                            .font(.system(size: 7))
                            .opacity(0.35)
                            .offset(x: cloudOffsetB, y: 12)
                    }
                }

                // 中：标题 + 副标题
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryMessage.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let detail = primaryMessage.detail {
                        Text(detail)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.55))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                // 右：badge + 展开箭头
                HStack(spacing: 6) {
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(.horizontal, 4)
                            .background(Color.goRed, in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.35))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                cloudOffsetA = 10
            }
            withAnimation(.easeInOut(duration: 6.2).repeatForever(autoreverses: true)) {
                cloudOffsetB = -10
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breath = 1
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        IslandMoodHeaderStrip(
            pets: [],
            plants: [],
            pendingReminders: [],
            activePet: nil,
            checkInStreak: 7
        )
    }
}
#endif
