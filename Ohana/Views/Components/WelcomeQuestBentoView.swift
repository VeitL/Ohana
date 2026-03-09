//
//  WelcomeQuestBentoView.swift
//  Ohana
//
//  欧哈纳岛屿拓荒指南 — 首页横向任务面板
//

import SwiftUI

struct WelcomeQuestBentoView: View {
    @State private var manager = QuestManager.shared
    @State private var showReward = false
    @State private var rewardAmount = 0
    @State private var rewardLabel = ""
    @State private var rewardTriggerCount = 0
    @State private var isAnimating = false

    private struct QuestCard: Identifiable {
        let id: String
        let emoji: String
        let title: String
        let reward: Int
        let isCompleted: Bool
    }

    private var quests: [QuestCard] {
        [
            QuestCard(
                id: "pet",
                emoji: "🐾",
                title: "迎接第一位家人",
                reward: 50,
                isCompleted: manager.isPetWizardCompleted
            ),
            QuestCard(
                id: "meal",
                emoji: "🍗",
                title: "记录第一顿美餐",
                reward: 15,
                isCompleted: manager.isFirstMealRecorded
            ),
            QuestCard(
                id: "theme",
                emoji: "🎨",
                title: "设置主题颜色",
                reward: 10,
                isCompleted: manager.isThemeColorSet
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── 头部
            HStack {
                Text("🌱 建设欧哈纳岛屿")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                // 椰子总数
                HStack(spacing: 4) {
                    Text("🥥")
                        .font(.system(size: 13))
                    Text("\(manager.coconutCount)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: manager.coconutCount)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.goYellow.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.goYellow.opacity(0.3), lineWidth: 1))
                // 进度
                Text("\(manager.completedCount)/\(manager.totalQuestCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 16)

            // ── 横向任务卡片
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quests) { quest in
                        questCard(quest)
                            .onTapGesture { handleQuestTap(quest) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
        .coconutRewardOverlay(trigger: $showReward, amount: rewardAmount, label: rewardLabel)
        .onChange(of: rewardTriggerCount) { _, _ in
            guard !isAnimating else { return }
            isAnimating = true
            showReward = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                isAnimating = false
            }
        }
    }

    /// 外部调用此方法触发椰子奖励动效
    func triggerReward(amount: Int, label: String = "") {
        rewardAmount = amount
        rewardLabel = label
        rewardTriggerCount += 1
    }

    private func handleQuestTap(_ quest: QuestCard) {
        if quest.isCompleted {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            triggerReward(amount: quest.reward, label: "已完成 ✅")
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    @ViewBuilder
    private func questCard(_ quest: QuestCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(quest.emoji)
                    .font(.system(size: 22))
                Spacer()
                if quest.isCompleted {
                    Text("✅")
                        .font(.system(size: 14))
                } else {
                    Text("+\(quest.reward) 🥥")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.goYellow.opacity(0.15), in: Capsule())
                }
            }

            Text(quest.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(quest.isCompleted ? .white.opacity(0.35) : .white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // 底部进度指示
            RoundedRectangle(cornerRadius: 3)
                .fill(quest.isCompleted ? Color.goLime : Color.white.opacity(0.1))
                .frame(height: 3)
        }
        .padding(14)
        .frame(width: 148, height: 110)
        .goTranslucentCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    quest.isCompleted
                        ? Color.goLime.opacity(0.15)
                        : Color.goLime.opacity(0.45),
                    lineWidth: 1
                )
        )
        .opacity(quest.isCompleted ? 0.55 : 1.0)
        .animation(.spring(response: 0.35), value: quest.isCompleted)
    }
}
