// FocusMoodQuestStrip.swift
// GO UI 首页心情 + 任务组合卡片
// 白卡风格，与粉色背景形成对比；多任务时左右滑动切换

import SwiftData
import SwiftUI

struct FocusMoodQuestStrip: View {
    let pets: [Pet]
    let plants: [Plant]
    let pendingReminders: [Reminder]
    let activePet: Pet?
    let checkInStreak: Int
    let quests: [IslandQuest] // already computed by parent engine — trust this
    var onCompleteQuest: (IslandQuest) -> Void = { _ in }
    var onExpand: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppServices.self) private var appServices
    @State private var currentPage = 0
    @State private var completingId: String? = nil // 正在完成动画的任务 id

    private var cardSurface: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }

    private var primaryInk: Color {
        Color(light: Color(hex: "23181A"), dark: .primary)
    }

    // MARK: - Mood

    private var mood: IslandMood {
        IslandMoodCalculator.calculate(
            pets: pets,
            pendingReminders: pendingReminders,
            plants: plants,
            healthAlerts: appServices.healthAlerts
        )
    }

    private var negativeSignals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(
            pets: pets,
            plants: plants,
            healthAlerts: appServices.healthAlerts
        )
    }

    private var moodEmoji: String {
        switch mood {
        case .celebrate: "🎉"
        case .plantBreeze: "🌿"
        case .breezy: "🌤"
        case .calm: "☀️"
        case .cloudy: "⛅"
        case .storm: "⛈"
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
            if pendingQuests.isEmpty, !quests.isEmpty {
                return "今日任务全部完成 🎉"
            }
            if let pet = activePet ?? activePets.first { return "岛屿氛围不错 · \(pet.name) 今天棒" }
            return "岛屿气氛很好"
        case .plantBreeze: return "植物刚喝饱水"
        default: break
        }
        if checkInStreak >= 7 { return "🔥 连续打卡 \(checkInStreak) 天" }
        if checkInStreak >= 3 { return "连击 \(checkInStreak) 天 · 继续加油" }
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
        FocusMoodQuestStripCard(
            moodEmoji: moodEmoji,
            moodText: moodText,
            badgeCount: badgeCount,
            pendingQuests: pendingQuests,
            allDone: allDone,
            pets: pets,
            cardSurface: cardSurface,
            primaryInk: primaryInk,
            borderOpacity: colorScheme == .dark ? 0.12 : 0.04,
            shadowColor: colorScheme == .dark ? Color.black.opacity(0.2) : Color(hex: "23181A").opacity(0.09),
            currentPage: $currentPage,
            completingId: $completingId,
            onExpand: onExpand,
            onCompleteQuest: onCompleteQuest
        )
        .onChange(of: pendingQuests.count) { _, newCount in
            if currentPage >= newCount, newCount > 0 {
                currentPage = newCount - 1
            }
        }
    }
}

private struct FocusMoodQuestStripCard: View {
    let moodEmoji: String
    let moodText: String
    let badgeCount: Int
    let pendingQuests: [IslandQuest]
    let allDone: Bool
    let pets: [Pet]
    let cardSurface: Color
    let primaryInk: Color
    let borderOpacity: Double
    let shadowColor: Color
    @Binding var currentPage: Int
    @Binding var completingId: String?
    let onExpand: () -> Void
    let onCompleteQuest: (IslandQuest) -> Void

    var body: some View {
        VStack(spacing: 0) {
            FocusMoodQuestHeaderButton(
                moodEmoji: moodEmoji,
                moodText: moodText,
                badgeCount: badgeCount,
                primaryInk: primaryInk,
                onExpand: onExpand
            )

            if !pendingQuests.isEmpty || allDone {
                FocusMoodQuestDivider(primaryInk: primaryInk)
            }

            FocusMoodQuestContent(
                pendingQuests: pendingQuests,
                allDone: allDone,
                pets: pets,
                primaryInk: primaryInk,
                currentPage: $currentPage,
                completingId: $completingId,
                onExpand: onExpand,
                onCompleteQuest: onCompleteQuest
            )
        }
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.primary.opacity(borderOpacity), lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 12, y: 4) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }
}

private struct FocusMoodQuestHeaderButton: View {
    let moodEmoji: String
    let moodText: String
    let badgeCount: Int
    let primaryInk: Color
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 8) {
                Text(moodEmoji)
                    .font(OhanaFont.adaptive(size: 17))
                Text(moodText)
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryInk.opacity(0.82))
                    .lineLimit(1)
                Spacer()
                if badgeCount > 0 {
                    FocusMoodQuestBadge(count: badgeCount)
                }
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 10, weight: .semibold))
                    .foregroundStyle(primaryInk.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(moodText)
        .accessibilityHint(badgeCount > 0 ? "有\(badgeCount)条提醒，点击展开详情" : "点击展开详情")
    }
}

private struct FocusMoodQuestBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(OhanaFont.adaptive(size: 11, weight: .bold))
            .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.goRed, in: Capsule())
    }
}

private struct FocusMoodQuestDivider: View {
    let primaryInk: Color

    var body: some View {
        Rectangle()
            .fill(primaryInk.opacity(0.07))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }
}

private struct FocusMoodQuestContent: View {
    let pendingQuests: [IslandQuest]
    let allDone: Bool
    let pets: [Pet]
    let primaryInk: Color
    @Binding var currentPage: Int
    @Binding var completingId: String?
    let onExpand: () -> Void
    let onCompleteQuest: (IslandQuest) -> Void

    var body: some View {
        if !pendingQuests.isEmpty {
            FocusMoodQuestPager(
                pendingQuests: pendingQuests,
                pets: pets,
                primaryInk: primaryInk,
                currentPage: $currentPage,
                completingId: $completingId,
                onCompleteQuest: onCompleteQuest
            )
        } else if allDone {
            FocusMoodQuestAllDoneButton(primaryInk: primaryInk, onExpand: onExpand)
        }
    }
}

private struct FocusMoodQuestPager: View {
    let pendingQuests: [IslandQuest]
    let pets: [Pet]
    let primaryInk: Color
    @Binding var currentPage: Int
    @Binding var completingId: String?
    let onCompleteQuest: (IslandQuest) -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pendingQuests.enumerated()), id: \.offset) { idx, quest in
                FocusMoodQuestRow(
                    quest: quest,
                    pets: pets,
                    primaryInk: primaryInk,
                    completingId: $completingId,
                    onCompleteQuest: onCompleteQuest
                )
                .tag(idx)
                .padding(.horizontal, 16)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 54)
        .accessibilityLabel("今日任务第 \(currentPage + 1) 项，共 \(pendingQuests.count) 项")

        if pendingQuests.count > 1 {
            FocusMoodQuestPageDots(count: pendingQuests.count, currentPage: currentPage)
        } else {
            Spacer().frame(height: 6)
        }
    }
}

private struct FocusMoodQuestPageDots: View {
    let count: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage
                        ? Color(hex: "1A2E8A")
                        : Color(hex: "23181A").opacity(0.18))
                    .frame(width: index == currentPage ? 14 : 5, height: 5)
                    .animation(.spring(response: 0.3), value: currentPage) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            }
        }
        .padding(.bottom, 10)
        .accessibilityHidden(true)
    }
}

private struct FocusMoodQuestAllDoneButton: View {
    let primaryInk: Color
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 8) {
                Text("✅").font(OhanaFont.adaptive(size: 16))
                VStack(alignment: .leading, spacing: 1) {
                    Text("今日任务全部完成")
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryInk.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct FocusMoodQuestRow: View {
    let quest: IslandQuest
    let pets: [Pet]
    let primaryInk: Color
    @Binding var completingId: String?
    let onCompleteQuest: (IslandQuest) -> Void

    private var isCompleting: Bool {
        completingId == quest.id
    }

    private var targetPet: Pet? {
        guard let targetPetId = quest.targetPetId else { return nil }
        return pets.first { $0.id == targetPetId }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let pet = targetPet {
                FocusMoodQuestPetAvatar(pet: pet)
            } else {
                Text(quest.emoji).font(OhanaFont.adaptive(size: 20))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(quest.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
            }
            Spacer()

            Button {
                guard completingId == nil else { return }
                completingId = quest.id
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onCompleteQuest(quest)
                    completingId = nil
                }
            } label: {
                FocusMoodQuestCompleteButtonLabel(isCompleting: isCompleting)
            }
            .buttonStyle(ScaleButtonStyle())
            .scaleEffect(isCompleting ? 0.92 : 1)
            .animation(.spring(response: 0.2), value: isCompleting) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            .accessibilityLabel("完成任务：\(quest.title)")
        }
    }
}

private struct FocusMoodQuestPetAvatar: View {
    let pet: Pet

    private var themeColor: Color {
        Color(hex: pet.themeColorHex.isEmpty ? "B0C4DE" : pet.themeColorHex)
    }

    var body: some View {
        PetAvatarPortraitView(
            imageData: pet.avatarImageData,
            fallbackText: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
            themeColor: themeColor,
            size: 34,
            backgroundOpacity: 0.25
        )
    }
}

private struct FocusMoodQuestCompleteButtonLabel: View {
    let isCompleting: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(isCompleting ? Color.green.opacity(0.85) : Color.goLime)
                .frame(height: 30)
            if isCompleting {
                Image(systemName: "checkmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("完成")
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(.black) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 52)
        .animation(.spring(response: 0.25), value: isCompleting) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }
}
