//
//  DailyQuestsCard.swift
//  Ohana
//
//  今日岛屿委托：3个动态任务 + 全部完成后解锁椰子盲盒

import SwiftUI
import SwiftData

// MARK: - Quest Model
struct IslandQuest: Identifiable, Equatable {
    let id: String          // 稳定 ID，用于持久化完成状态
    let emoji: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    /// 关联宠物（头像 / 左侧色条）；无则为 nil
    let targetPetId: UUID?
    /// 关联植物（浇水 / 施肥委托）
    let targetPlantId: UUID?
}

// MARK: - Quest Engine
struct IslandQuestEngine {
    static func todayQuests(
        pets: [Pet],
        reminders: [Reminder],
        plants: [Plant] = [],
        events: [Event] = []
    ) -> [IslandQuest] {
        let cal = Calendar.current
        let now = Date()
        var quests: [IslandQuest] = []
        let activePets = pets.filter { !$0.hasPassedAway }

        // ── 用药委托（最高优先级）：今日未达频次的活跃疗程
        for pet in activePets {
            guard quests.count < 3 else { break }
            for med in pet.medications where med.isActiveToday {
                guard quests.count < 3 else { break }
                let need = PetMedicationDoseLogging.requiredDoses(on: now, for: med)
                guard need > 0 else { continue }
                let done = PetMedicationDoseLogging.todayDoseCount(events: events, medicationId: med.id)
                if done >= need { continue }
                let left = need - done
                quests.append(IslandQuest(
                    id: "q_med_\(med.id.uuidString)",
                    emoji: "💊",
                    title: "给 \(pet.name) 喂 \(med.name.isEmpty ? "药" : med.name)",
                    subtitle: "今日还需喂 \(left) 次 · 每次 \(med.dosage.isEmpty ? "按医嘱" : med.dosage)",
                    isCompleted: false,
                    targetPetId: pet.id,
                    targetPlantId: nil
                ))
            }
        }

        // ── 遛狗（仅限狗 & 今日未遛）
        if quests.count < 3, let dog = activePets.first(where: { $0.species == "狗" }) {
            let done = dog.walkLogs.contains { cal.isDateInToday($0.startDate) }
            quests.append(IslandQuest(
                id: "q_walk",
                emoji: done ? "✅" : "🐾",
                title: "带 \(dog.name) 出门巡岛",
                subtitle: done ? "今日已遛，辛苦了！" : "今日未遛狗，出门走走吧",
                isCompleted: done,
                targetPetId: dog.id,
                targetPlantId: nil
            ))
        }

        // ── 喂食（今日未喂任何一只宠物）
        if quests.count < 3, let pet = activePets.first(where: { p in
            !p.careLogs.contains { $0.type == "feeding" && cal.isDateInToday($0.date) }
        }) {
            quests.append(IslandQuest(
                id: "q_feed_\(pet.id.uuidString)",
                emoji: "🍖",
                title: "给 \(pet.name) 喂食",
                subtitle: "今日还未记录喂食，记得填肚子",
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        // ── 饮水（今日未喂水）
        if quests.count < 3, let pet = activePets.first(where: { p in
            !p.careLogs.contains { $0.type == "watering" && cal.isDateInToday($0.date) }
        }) {
            quests.append(IslandQuest(
                id: "q_water_\(pet.id.uuidString)",
                emoji: "💧",
                title: "给 \(pet.name) 换水",
                subtitle: "新鲜饮水很重要，今日还未记录",
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        // ── 便便打卡（今日未记录）
        if quests.count < 3, let pet = activePets.first(where: { p in
            !p.pottyLogs.contains { cal.isDateInToday($0.date) }
        }) {
            quests.append(IslandQuest(
                id: "q_potty",
                emoji: "💩",
                title: "记录 \(pet.name) 今日如厕",
                subtitle: "如厕健康监测，今日尚未记录",
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        // ── 植物浇水（需要浇水的植物）
        if quests.count < 3, let thirstyPlant = plants.first(where: { $0.needsWatering }) {
            quests.append(IslandQuest(
                id: "q_water_plant",
                emoji: "💧",
                title: "给 \(thirstyPlant.name) 浇水",
                subtitle: "植物渴了，快去浇水",
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: thirstyPlant.id
            ))
        }

        // ── 植物施肥（需要施肥的植物）
        if quests.count < 3, let hungryPlant = plants.first(where: { $0.needsFertilizing }) {
            quests.append(IslandQuest(
                id: "q_fertilize_plant",
                emoji: "🌿",
                title: "给 \(hungryPlant.name) 施肥",
                subtitle: "植物需要补充养分",
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: hungryPlant.id
            ))
        }

        // ── 今日提醒（仅在有真实提醒时显示）
        let todayReminders = reminders.filter { cal.isDateInToday($0.scheduledAt) }
        if quests.count < 3, !todayReminders.isEmpty {
            let allDone = todayReminders.allSatisfy { $0.isCompleted }
            let pending = todayReminders.filter { !$0.isCompleted }.count
            quests.append(IslandQuest(
                id: "q_reminder",
                emoji: allDone ? "✅" : "📅",
                title: allDone ? "今日提醒全部完成" : "完成今日 \(pending) 个提醒",
                subtitle: allDone ? "所有提醒已处理" : "查看日历，处理待办提醒",
                isCompleted: allDone,
                targetPetId: activePets.first?.id,
                targetPlantId: nil
            ))
        }

        return Array(quests.prefix(3))
    }

    /// 解析委托 ID 是否为用药打卡（`q_med_<UUID>`）
    static func medicationId(fromQuestId id: String) -> UUID? {
        let prefix = "q_med_"
        guard id.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(id.dropFirst(prefix.count)))
    }

    static func allCompleted(quests: [IslandQuest]) -> Bool {
        !quests.isEmpty && quests.allSatisfy { $0.isCompleted }
    }

    /// 委托完成时椰子粒子数量
    static func coconutReward(forQuestId id: String) -> Int {
        switch id {
        case "q_walk":            return 3
        case "q_potty":           return 1
        case "q_water_plant":     return 1
        case "q_fertilize_plant": return 1
        case "q_reminder":        return 2
        default:
            if id.hasPrefix("q_med_")   { return 2 }
            if id.hasPrefix("q_feed_")  { return 2 }
            if id.hasPrefix("q_water_") { return 1 }
            return 1
        }
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
                            .background(Color.goPrimary, in: Capsule())
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
    var plants: [Plant] = []
    var events: [Event] = []
    let onSelectPet: (Pet) -> Void
    /// 每次完成数量变化时回调：(completedCount, totalCount)
    var onQuestCompleted: ((Int, Int) -> Void)? = nil

    @State private var showCoconut = false
    @State private var coconutClaimed: Bool = {
        let key = "coconut_claimed_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        return UserDefaults.standard.bool(forKey: key)
    }()
    @State private var showRewardToast = false
    @State private var toastMessage = ""
    @State private var lastCompletedCount: Int = -1

    private var quests: [IslandQuest] {
        IslandQuestEngine.todayQuests(pets: pets, reminders: reminders, plants: plants, events: events)
    }

    private var completedCount: Int {
        quests.filter { $0.isCompleted }.count
    }

    private var remaining: Int { quests.count - completedCount }

    private var allDone: Bool {
        IslandQuestEngine.allCompleted(quests: quests)
    }

    /// 每个委托对应的椰子奖励数
    private func coconutReward(for quest: IslandQuest) -> Int {
        IslandQuestEngine.coconutReward(forQuestId: quest.id)
    }

    var body: some View {
        Group {
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
                Text(toastMessage)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(Color.goPrimary, in: Capsule())
                    .shadow(color: Color.goPrimary.opacity(0.45), radius: 12, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.4), value: allDone)
        .animation(.spring(response: 0.4), value: coconutClaimed)
        // 当完成数量提升时触发回调
        .onChange(of: completedCount) { _, newVal in
            if newVal > lastCompletedCount && lastCompletedCount >= 0 {
                onQuestCompleted?(newVal, quests.count)
            }
            lastCompletedCount = newVal
        }
        .onAppear { lastCompletedCount = completedCount }
    }

    // 折叠状态 — 全完成且已领盲盒
    private var collapsedCompletedCard: some View {
        HStack(spacing: 10) {
            Text("✅")
                .font(.system(size: 20))
            Text("今日岛屿委托全部完成！")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.goPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .goTranslucentCard(cornerRadius: 16)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // 展开状态
    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Text("🏝️")
                        .font(.system(size: 16))
                    Text("岛屿委托")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .tracking(1)
                }
                Spacer()
                // 动态进度文案
                Group {
                    if allDone {
                        Text("✅ 今日委托全部完成！")
                            .foregroundStyle(Color.goPrimary)
                    } else if quests.isEmpty {
                        Text("🌴 今天岛上很平静")
                            .foregroundStyle(Color.secondary)
                    } else {
                        Text("⚔️ 还有 \(remaining) 个委托等你")
                            .foregroundStyle(Color.goYellow)
                    }
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

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
                                Text("完成所有委托的专属奖励 · 全勤额外 +5🥥")
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
                        coconutClaimed ? Color.white.opacity(0.05) : Color.goPrimary,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
                .disabled(coconutClaimed)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func questRow(_ quest: IslandQuest) -> some View {
        let reward = coconutReward(for: quest)
        return HStack(spacing: 12) {
            // 复选框
            ZStack {
                Circle()
                    .fill(quest.isCompleted ? Color.goPrimary : .clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(quest.isCompleted ? .clear : Color.primary.opacity(0.35), lineWidth: 2)
                    )
                if quest.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.arkInk)
                }
            }

            Text(quest.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(quest.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(quest.isCompleted, color: Color.secondary.opacity(0.8))

            Spacer()

            // 右侧：已完成显示 ✅，未完成显示椰子奖励
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
        .padding(.vertical, 10)
        .opacity(quest.isCompleted ? 0.4 : 1.0)
        .animation(.easeOut(duration: 0.3), value: quest.isCompleted)
    }
}
