// FocusMoodQuestStrip.swift
// GO UI 首页心情 + 任务组合卡片
// 白卡风格，与粉色背景形成对比；多任务时左右滑动切换

import SwiftUI
import SwiftData

struct FocusMoodQuestStrip: View {
    let pets: [Pet]
    let plants: [Plant]
    let pendingReminders: [Reminder]
    let activePet: Pet?
    let checkInStreak: Int
    let quests: [IslandQuest]          // already computed by parent engine — trust this
    var onCompleteQuest: (IslandQuest) -> Void = { _ in }
    var onExpand: () -> Void = {}

    @State private var currentPage  = 0
    @State private var completingId: String? = nil  // 正在完成动画的任务 id

    // MARK: - Mood

    private var mood: IslandMood {
        IslandMoodCalculator.calculate(pets: pets, pendingReminders: pendingReminders, plants: plants)
    }

    private var negativeSignals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(pets: pets, plants: plants)
    }

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

    private var moodText: String {
        let activePets = pets.filter { !$0.hasPassedAway }
        if let critical = negativeSignals.first(where: { $0.severity == .critical }) {
            return critical.title
        }
        switch mood {
        case .celebrate:
            if let p = activePets.first(where: { [100, 365, 500, 730, 1000, 1095].contains($0.daysTogether) }) {
                return "陪伴 \(p.name) 第 \(p.daysTogether) 天"
            }
            // Only claim "all done" when quests are actually empty; otherwise mood may
            // have been triggered by reminder completion while pet quests still pending.
            if pendingQuests.isEmpty && !quests.isEmpty {
                return "今日任务全部完成 🎉"
            }
            if let pet = activePet ?? activePets.first { return "岛屿氛围不错 · \(pet.name) 今天棒" }
            return "岛屿气氛很好"
        case .plantBreeze: return "植物刚喝饱水"
        default: break
        }
        if checkInStreak >= 7  { return "🔥 连续打卡 \(checkInStreak) 天" }
        if checkInStreak >= 3  { return "连击 \(checkInStreak) 天 · 继续加油" }
        if let w = negativeSignals.first { return w.title }
        if let pet = activePet ?? activePets.first { return "岛屿晴朗 · \(pet.name) 今天不错" }
        return "岛屿等待你的第一位家人"
    }

    private var badgeCount: Int { negativeSignals.count }

    // MARK: - Quests
    // Use the parent-computed quests directly — the engine reruns reactively
    // whenever SwiftData changes, so no secondary live-query check needed here.

    private var pendingQuests: [IslandQuest] {
        quests.filter { !$0.isCompleted }
    }

    private var allDone: Bool {
        !quests.isEmpty && pendingQuests.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // ── Row 1: Mood ──
            Button(action: onExpand) {
                HStack(spacing: 8) {
                    Text(moodEmoji)
                        .font(.system(size: 17))
                    Text(moodText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "23181A").opacity(0.82))
                        .lineLimit(1)
                    Spacer()
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.goRed, in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "23181A").opacity(0.25))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(moodText)
            .accessibilityHint(badgeCount > 0 ? "有\(badgeCount)条提醒，点击展开详情" : "点击展开详情")

            // Divider only when quest row exists below
            if !pendingQuests.isEmpty || allDone {
                Rectangle()
                    .fill(Color(hex: "23181A").opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }

            // ── Row 2: Quest pager ──
            if !pendingQuests.isEmpty {
                TabView(selection: $currentPage) {
                    ForEach(Array(pendingQuests.enumerated()), id: \.offset) { idx, q in
                        questRow(q)
                            .tag(idx)
                            .padding(.horizontal, 16)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 54)
                .accessibilityLabel("今日任务第 \(currentPage + 1) 项，共 \(pendingQuests.count) 项")

                // Page dots
                if pendingQuests.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<pendingQuests.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage
                                      ? Color(hex: "1A2E8A")
                                      : Color(hex: "23181A").opacity(0.18))
                                .frame(width: i == currentPage ? 14 : 5, height: 5)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.bottom, 10)
                    .accessibilityHidden(true)
                } else {
                    Spacer().frame(height: 6)
                }

            } else if allDone {
                Button(action: onExpand) {
                    HStack(spacing: 8) {
                        Text("✅").font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("今日任务全部完成")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "23181A").opacity(0.7))
                            if let pet = activePet ?? pets.first(where: { !$0.hasPassedAway }) {
                                Text("去看看 \(pet.name) 今天的状态 →")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(hex: "1A2E8A").opacity(0.6))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "23181A").opacity(0.09), radius: 12, y: 4)
        .onChange(of: pendingQuests.count) { _, newCount in
            if currentPage >= newCount && newCount > 0 {
                currentPage = newCount - 1
            }
        }
    }

    // MARK: - Quest row

    @ViewBuilder
    private func questRow(_ q: IslandQuest) -> some View {
        let isCompleting = completingId == q.id
        let targetPet = q.targetPetId.flatMap { id in pets.first { $0.id == id } }

        HStack(spacing: 10) {
            // ── 宠物头像（有关联宠物时显示，替换 emoji）──
            if let pet = targetPet {
                petAvatar(pet)
            } else {
                Text(q.emoji).font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(q.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "23181A"))
                    .lineLimit(1)
                if !q.subtitle.isEmpty {
                    Text(q.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "23181A").opacity(0.45))
                        .lineLimit(1)
                }
            }
            Spacer()

            // ── 完成按钮（完成中短暂变为 ✓）──
            Button {
                guard completingId == nil else { return }
                completingId = q.id
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onCompleteQuest(q)
                    completingId = nil
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(isCompleting ? Color.green.opacity(0.85) : Color.goLime)
                        .frame(height: 30)
                    if isCompleting {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("完成")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 52)
                .animation(.spring(response: 0.25), value: isCompleting)
            }
            .buttonStyle(.plain)
            .scaleEffect(isCompleting ? 0.92 : 1)
            .animation(.spring(response: 0.2), value: isCompleting)
            .accessibilityLabel("完成任务：\(q.title)")
        }
    }

    // MARK: - Pet avatar (small, for quest row)

    @ViewBuilder
    private func petAvatar(_ pet: Pet) -> some View {
        let color = Color(hex: pet.themeColorHex.isEmpty ? "B0C4DE" : pet.themeColorHex)
        ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: 34, height: 34)
            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
            } else {
                Text(pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji)
                    .font(.system(size: 18))
            }
        }
    }
}
