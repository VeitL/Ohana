//
//  DailyQuestsCard.swift
//  Ohana
//
//  今日岛屿委托：3个动态任务 + 全部完成后解锁椰子盲盒

import SwiftUI
import SwiftData

// MARK: - Quest Model
struct IslandQuest: Identifiable {
    let id: String          // 稳定 ID，用于持久化完成状态
    let emoji: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
}

// MARK: - Quest Engine
struct IslandQuestEngine {
    static func todayQuests(pets: [Pet], reminders: [Reminder]) -> [IslandQuest] {
        let cal = Calendar.current
        let now = Date()
        var quests: [IslandQuest] = []

        // 任务1: 遛狗（仅限有狗的家庭）
        if let dog = pets.first(where: { $0.species == "狗" }) {
            let done = dog.walkLogs.contains { cal.isDateInToday($0.startDate) }
            quests.append(IslandQuest(
                id: "q_walk",
                emoji: done ? "✅" : "🐾",
                title: "带 \(dog.name) 巡岛一次",
                subtitle: done ? "已完成！辛苦了" : "出门走走，活力满满",
                isCompleted: done
            ))
        }

        // 任务2: 便便打卡
        if let pet = pets.first {
            let done = pet.pottyLogs.contains { cal.isDateInToday($0.date) }
            quests.append(IslandQuest(
                id: "q_potty",
                emoji: done ? "✅" : "💩",
                title: "记录 \(pet.name) 今日排泄",
                subtitle: done ? "已完成！噗噗电台已更新" : "健康监测从如厕开始",
                isCompleted: done
            ))
        }

        // 任务3: 探访宠物（点进详情页算完成，用 UserDefaults 今日访问标记）
        let visitKey = "quest_visit_\(cal.startOfDay(for: now).timeIntervalSince1970)"
        let visited = UserDefaults.standard.bool(forKey: visitKey)
        if let pet = pets.first {
            quests.append(IslandQuest(
                id: "q_visit",
                emoji: visited ? "✅" : "🏝️",
                title: "探望 \(pet.name)",
                subtitle: visited ? "已完成！感情升温中" : "点击查看宠物详情",
                isCompleted: visited
            ))
        }

        // 兜底：如果宠物少，补充通用任务
        if quests.count < 3 {
            let done = reminders.contains { cal.isDateInToday($0.scheduledAt) && $0.isCompleted }
            quests.append(IslandQuest(
                id: "q_reminder",
                emoji: done ? "✅" : "📅",
                title: "完成今日提醒",
                subtitle: done ? "所有提醒已完成" : "查看今日日历",
                isCompleted: done
            ))
        }

        return Array(quests.prefix(3))
    }

    static func allCompleted(quests: [IslandQuest]) -> Bool {
        !quests.isEmpty && quests.allSatisfy { $0.isCompleted }
    }

    // 标记「探访」任务已完成
    static func markVisited() {
        let key = "quest_visit_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        UserDefaults.standard.set(true, forKey: key)
    }
}

// MARK: - Coconut Drop Sheet
struct CoconutDropSheet: View {
    @Binding var isPresented: Bool
    @State private var revealed = false
    @State private var bounce = false

    private let rewards: [(emoji: String, text: String)] = [
        ("🥥", "今日解锁：椰子咖啡主题"),
        ("🦜", "冷知识：狗狗能识别 250 个单词！"),
        ("🌺", "今日解锁：繁花岛限定卡片"),
        ("⭐️", "你的宠物今天特别可爱"),
        ("🍀", "幸运签：今天出门一定艳阳天"),
        ("🐠", "冷知识：猫咪平均每天睡 14 小时"),
    ]
    private var reward: (emoji: String, text: String) {
        // 用今日日期做种子，保证同天拿到同一个奖励
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return rewards[day % rewards.count]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 椰子
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        revealed = true
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(hex: "A8711A"), Color(hex: "5C3A0A")],
                                    center: .topLeading,
                                    startRadius: 10,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(hex: "A8711A").opacity(0.5), radius: 20, y: 8)
                            .scaleEffect(bounce ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bounce)
                            .onAppear { bounce = true }

                        Text(revealed ? reward.emoji : "🥥")
                            .font(.system(size: 52))
                            .scaleEffect(revealed ? 1.3 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: revealed)
                    }
                }
                .buttonStyle(.plain)
                .disabled(revealed)

                VStack(spacing: 12) {
                    Text(revealed ? "今日盲盒已开启！" : "敲开你的椰子")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(revealed ? reward.text : "完成所有委托换取的神秘礼物")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if revealed {
                    Button {
                        isPresented = false
                    } label: {
                        Text("收下！")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goLime, in: Capsule())
                            .padding(.horizontal, 48)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
        }
    }
}

// MARK: - Daily Quests Card
struct DailyQuestsCard: View {
    let pets: [Pet]
    let reminders: [Reminder]
    let onSelectPet: (Pet) -> Void

    @State private var showCoconut = false
    @State private var coconutClaimed: Bool = {
        let key = "coconut_claimed_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        return UserDefaults.standard.bool(forKey: key)
    }()
    @State private var showRewardToast = false
    @State private var toastMessage = ""

    private var quests: [IslandQuest] {
        IslandQuestEngine.todayQuests(pets: pets, reminders: reminders)
    }

    private var completedCount: Int {
        quests.filter { $0.isCompleted }.count
    }

    private var allDone: Bool {
        IslandQuestEngine.allCompleted(quests: quests)
    }

    var body: some View {
        Group {
            // U2: 全完成且已领盲盒 → 折叠为紧凑单行
            if allDone && coconutClaimed {
                collapsedCompletedCard
            } else {
                expandedCard
            }
        }
        .sheet(isPresented: $showCoconut, onDismiss: {
            let key = "coconut_claimed_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
            UserDefaults.standard.set(true, forKey: key)
            coconutClaimed = true
            // Toast 反馈
            toastMessage = "🥥 今日椰子盲盒已领取！"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showRewardToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.3)) { showRewardToast = false }
            }
        }) {
            CoconutDropSheet(isPresented: $showCoconut)
        }
        .overlay(alignment: .top) {
            if showRewardToast {
                HStack(spacing: 8) {
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                }
                .padding(.horizontal, 20).padding(.vertical, 11)
                .background(Color.goLime, in: Capsule())
                .shadow(color: Color.goLime.opacity(0.45), radius: 12, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.4), value: allDone)
        .animation(.spring(response: 0.4), value: coconutClaimed)
    }

    // U2: 折叠状态 — 全完成后显示紧凑卡片
    private var collapsedCompletedCard: some View {
        HStack(spacing: 10) {
            Text("🥥")
                .font(.system(size: 22))
            Text("今日岛屿委托已全部完成")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.6))
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.goLime)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .goTranslucentCard(cornerRadius: 16)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // 展开状态 — 正常显示任务列表
    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scroll.fill")
                        .foregroundStyle(Color.goYellow)
                        .font(.system(size: 14, weight: .bold))
                    Text("今日岛屿委托")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                // 进度 pill
                Text("\(completedCount)/\(quests.count)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(allDone ? Color.arkInk : .white.opacity(0.5))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(allDone ? Color.goLime : Color.white.opacity(0.1), in: Capsule())
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.goLime, Color.goTeal],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: quests.isEmpty ? 0 : geo.size.width * CGFloat(completedCount) / CGFloat(quests.count))
                        .animation(.spring(response: 0.5), value: completedCount)
                }
            }
            .frame(height: 5)

            // 任务列表
            ForEach(quests) { quest in
                questRow(quest)
            }

            // 全部完成 → 椰子盲盒
            if allDone {
                Button {
                    if !coconutClaimed { showCoconut = true }
                } label: {
                    HStack(spacing: 10) {
                        Text("🥥")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(coconutClaimed ? "今日盲盒已领取" : "领取今日椰子盲盒！")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(coconutClaimed ? .white.opacity(0.4) : Color.arkInk)
                            if !coconutClaimed {
                                Text("完成所有委托的专属奖励")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.arkInk.opacity(0.6))
                            }
                        }
                        Spacer()
                        if !coconutClaimed {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.arkInk.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        coconutClaimed
                            ? Color.white.opacity(0.05)
                            : Color.goLime,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
                .disabled(coconutClaimed)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private func questRow(_ quest: IslandQuest) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(quest.isCompleted ? Color.goLime.opacity(0.15) : Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                Text(quest.emoji)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(quest.isCompleted ? .white.opacity(0.4) : .white)
                    .strikethrough(quest.isCompleted, color: .white.opacity(0.3))
                Text(quest.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
            }
            Spacer()
            if quest.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.goLime)
                    .font(.system(size: 18))
            }
        }
    }
}
