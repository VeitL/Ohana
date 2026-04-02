//
//  IslandDailyReportSheet.swift
//  Ohana
//
//  每日首次打开 App 时呈现的「岛屿日报」启动弹窗。
//

import SwiftUI
import SwiftData

struct IslandDailyReportSheet: View {
    @Binding var isPresented: Bool
    let pets: [Pet]
    let reminders: [Reminder]
    var plants: [Plant] = []
    var events: [Event] = []
    var onStartTasks: (() -> Void)? = nil

    @State private var islandBounce = false
    @State private var itemsAppeared: [Bool] = []

    private var quests: [IslandQuest] {
        Array(IslandQuestEngine.todayQuests(pets: pets, reminders: reminders, plants: plants, events: events).prefix(5))
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "早上好"
        case 12..<18: return "下午好"
        default:      return "晚上好"
        }
    }

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日 EEEE"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: Date())
    }

    private func coconutReward(for quest: IslandQuest) -> Int {
        switch quest.id {
        case "q_walk":            return 3
        case "q_potty":           return 1
        case "q_water_plant":     return 1
        case "q_fertilize_plant": return 1
        case "q_visit":           return 2
        case "q_reminder":        return 2
        default:                  return 1
        }
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.6).ignoresSafeArea()
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // 顶部 emoji + 标题
                    VStack(spacing: 12) {
                        Text("🏝️")
                            .font(.system(size: 64))
                            .scaleEffect(islandBounce ? 1.15 : 1.0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.5)
                                    .repeatCount(2, autoreverses: true),
                                value: islandBounce
                            )

                        Text("岛屿日报")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("\(dateText) · \(greetingText)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // 分隔
                    HStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1)
                        Text("今天岛上需要你")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // 任务列表（staggered 入场）
                    if quests.isEmpty {
                        Text("🌴 今天岛上很平静，好好休息吧")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(quests.enumerated()), id: \.offset) { idx, quest in
                                questRow(quest: quest, index: idx)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // 全勤奖励提示
                    if !quests.isEmpty {
                        HStack(spacing: 6) {
                            Text("🎁")
                                .font(.system(size: 14))
                            Text("完成全部可额外获得 +5 🥥")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.goPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.goPrimary.opacity(0.25), lineWidth: 1)
                        )
                    }

                    // 按钮区
                    VStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isPresented = false
                            onStartTasks?()
                        } label: {
                            HStack(spacing: 8) {
                                Text("开始今日任务")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text("⚔️")
                                    .font(.system(size: 16))
                            }
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.goPrimary, in: Capsule())
                            .shadow(color: Color.goPrimary.opacity(0.4), radius: 12, y: 4)
                        }
                        .buttonStyle(.plain)

                        Button {
                            isPresented = false
                        } label: {
                            Text("跳过，直接进入")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 30, y: -10)
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 20)
            }
        }
        .onAppear {
            itemsAppeared = Array(repeating: false, count: quests.count)
            // Bounce emoji
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                islandBounce = true
            }
            // Staggered task rows
            for i in 0..<quests.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(i) * 0.08) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        if i < itemsAppeared.count {
                            itemsAppeared[i] = true
                        }
                    }
                }
            }
        }
    }

    private func questRow(quest: IslandQuest, index: Int) -> some View {
        let reward = coconutReward(for: quest)
        let appeared = index < itemsAppeared.count ? itemsAppeared[index] : false
        return HStack(spacing: 12) {
            // 完成状态图标
            ZStack {
                Circle()
                    .fill(quest.isCompleted ? Color.goPrimary : Color.primary.opacity(0.08))
                    .frame(width: 32, height: 32)
                Text(quest.isCompleted ? "✅" : quest.emoji)
                    .font(.system(size: 15))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(quest.isCompleted ? .secondary : .primary)
                    .strikethrough(quest.isCompleted)
                Text(quest.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.7))
            }

            Spacer()

            // 椰子奖励
            if quest.isCompleted {
                Text("✅")
                    .font(.system(size: 14))
            } else {
                HStack(spacing: 3) {
                    Text("+\(reward)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                    Text("🥥")
                        .font(.system(size: 12))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }
}
