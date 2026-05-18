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

    private var l10n: L10n { L10n(AppLanguage.code) }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return l10n.goodMorning
        case 12..<18: return l10n.goodAfternoon
        default:      return l10n.goodEvening
        }
    }

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.locale = AppLanguage.effectiveLocale
        fmt.dateFormat = AppLanguage.dailyReportDateFormat
        return fmt.string(from: Date())
    }

    private func coconutReward(for quest: IslandQuest) -> Int {
        IslandQuestEngine.coconutReward(forQuestId: quest.id)
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.6).ignoresSafeArea() // ui-v4: allow launch report modal scrim
                .background(Color.ohanaCardSurface)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // 顶部 emoji + 标题
                    VStack(spacing: 10) {
                        Text("🏝️")
                            .font(.system(size: 64))
                            .scaleEffect(islandBounce ? 1.15 : 1.0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.5)
                                    .repeatCount(2, autoreverses: true),
                                value: islandBounce
                            )

                        Text("今日任务盘")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)

                        Text("\(dateText) · \(greetingText)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }

                    // 分隔
                    HStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1)
                        Text("今日")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize()
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // 任务列表（staggered 入场）
                    if quests.isEmpty {
                        Text("🌴 已清空")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
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
                            Text("+5 🥥")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
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
                                Text("开始")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text("⚔️")
                                    .font(.system(size: 16))
                            }
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Button {
                            isPresented = false
                        } label: {
                            Text("跳过")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.ohanaCardSurface)
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
                    withAnimation(GoMotion.quick) {
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
