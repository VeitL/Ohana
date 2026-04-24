//
//  TodayFocusCard.swift
//  Ohana
//
//  首页简化 · 岛屿三层重构（P0）
//  替换原先的 HomeHighlightDeck 水平滑动卡组：
//  按优先级智能选出"今天最该做的 1 件事"，单卡呈现 + 微动效。
//
//  优先级：未完成委托 > 负反馈（警告） > 记忆碎片 > 全部完成庆祝 > 岛屿探访
//
//  v2 实时响应：内部 @Query 监听 PetCareLog / PetWalkLog / PetPottyLog，
//  打卡后无需父视图手动刷新；完成时粒子爆破消失。
//

import SwiftUI
import SwiftData

// MARK: - Particle data

private struct Particle: Identifiable {
    let id = UUID()
    var offset: CGSize
    var scale: CGFloat
    var opacity: Double
    var color: Color
    var angle: Double      // radians
    var speed: CGFloat     // distance to travel
}

// MARK: - TodayFocusCard

struct TodayFocusCard: View {
    let pets: [Pet]
    let plants: [Plant]
    let quests: [IslandQuest]        // passed from parent; isCompleted may be stale
    let activePet: Pet?
    var onCompleteQuest: (IslandQuest) -> Void = { _ in }
    var onTapMemory: () -> Void = {}
    var onTapOasis: () -> Void = {}

    // Live @Query arrays — force re-render on any new check-in
    @Query(sort: \PetCareLog.date, order: .reverse) private var liveCare: [PetCareLog]
    @Query(sort: \PetWalkLog.startDate, order: .reverse) private var liveWalks: [PetWalkLog]
    @Query(sort: \PetPottyLog.date, order: .reverse) private var livePotty: [PetPottyLog]

    @State private var bounceEmoji = false
    @State private var pulse: CGFloat = 0
    @State private var particles: [Particle] = []
    @State private var burstActive = false

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Focus Decision

    private enum FocusContent {
        case quest(IslandQuest)
        case negative(IslandNegativeSignal)
        case memory(MemoryFragment)
        case celebrate(pets: [Pet])
        case welcome
    }

    /// Recomputes `isCompleted` for each quest using live @Query arrays so it
    /// updates immediately after a check-in without waiting for relationship propagation.
    private var refreshedQuests: [IslandQuest] {
        let cal = Calendar.current
        return quests.map { q in
            if q.isCompleted { return q }   // already marked done upstream
            var done = false
            if q.id.hasPrefix("q_feed_"), let pid = q.targetPetId {
                done = liveCare.contains { $0.careType == .feeding && $0.pet?.id == pid && cal.isDateInToday($0.date) }
            } else if q.id.hasPrefix("q_water_") && !q.id.hasPrefix("q_water_plant"), let pid = q.targetPetId {
                done = liveCare.contains { $0.careType == .watering && $0.pet?.id == pid && cal.isDateInToday($0.date) }
            } else if q.id == "q_walk", let pid = q.targetPetId {
                done = liveWalks.contains { $0.pet?.id == pid && cal.isDateInToday($0.startDate) }
            } else if q.id == "q_potty", let pid = q.targetPetId {
                done = livePotty.contains { $0.pet?.id == pid && cal.isDateInToday($0.date) }
            }
            guard done else { return q }
            return IslandQuest(id: q.id, emoji: "✅", title: q.title, subtitle: q.subtitle,
                               isCompleted: true, targetPetId: q.targetPetId, targetPlantId: q.targetPlantId)
        }
    }

    private var content: FocusContent {
        let pending = refreshedQuests.filter { !$0.isCompleted }
        if let first = pending.first { return .quest(first) }
        let signals = IslandNegativeFeedback.signals(pets: pets, plants: plants)
        if let sig = signals.first(where: { $0.severity == .critical }) ?? signals.first { return .negative(sig) }
        if let memory = MemoryEngine.pickFragment(pets: pets, plants: plants) { return .memory(memory) }
        if !refreshedQuests.isEmpty { return .celebrate(pets: pets) }
        return .welcome
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("今日聚焦")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.primary.opacity(0.42))
                    Spacer()
                    if case .quest(let q) = content {
                        rewardChip(IslandQuestEngine.coconutReward(forQuestId: q.id))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 4)

                card
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
            }

            // Particle burst overlay
            if burstActive {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 8 * p.scale, height: 8 * p.scale)
                        .offset(p.offset)
                        .opacity(p.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = 1 }
        }
    }

    // MARK: - Card switcher

    @ViewBuilder
    private var card: some View {
        switch content {
        case .quest(let q):      questCard(q)
        case .negative(let s):   negativeCard(s)
        case .memory(let m):     memoryCard(m)
        case .celebrate:         celebrateCard
        case .welcome:           welcomeCard
        }
    }

    // MARK: - Quest card

    private func questCard(_ q: IslandQuest) -> some View {
        let accent = Color.goPrimary
        return HStack(spacing: 14) {
            iconBubble(emoji: q.emoji, accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(q.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(q.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                fireBurst(accent: accent)
                onCompleteQuest(q)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                    Text("完成")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Negative signal card

    private func negativeCard(_ s: IslandNegativeSignal) -> some View {
        let accent = s.severity == .critical ? Color.goRed : Color.goYellow
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + pulse * 0.08)
                Image(systemName: s.iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(s.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(s.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer(minLength: 6)
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Memory fragment card

    private func memoryCard(_ m: MemoryFragment) -> some View {
        let accent = m.accentColor
        return HStack(spacing: 14) {
            iconBubble(emoji: m.emoji, accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(m.headline)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(m.subline)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Button { onTapMemory() } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Celebrate card

    private var celebrateCard: some View {
        let accent = Color.goYellow
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + pulse * 0.1)
                Text("🎉")
                    .font(.system(size: 30))
                    .scaleEffect(bounceEmoji ? 1.1 : 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            bounceEmoji = true
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("今日任务全部完成")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("岛屿风和日丽，去绿洲领取椰子盲盒吧")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Button { onTapOasis() } label: {
                Text("去绿洲")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Welcome card

    private var welcomeCard: some View {
        let accent = Color.goPrimary
        return HStack(spacing: 14) {
            iconBubble(emoji: "🏝️", accent: accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("岛屿欢迎你")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("添加第一位家人，开启 Ohana 之旅")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
            }
            Spacer()
        }
        .padding(14)
        .background(cardBackground(accent))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func iconBubble(emoji: String, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 52, height: 52)
                .scaleEffect(1 + pulse * 0.06)
            Text(emoji)
                .font(.system(size: 28))
                .offset(y: pulse * 0.8 - 0.4)
        }
    }

    private func rewardChip(_ amount: Int) -> some View {
        HStack(spacing: 3) {
            Text("+\(amount)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.goYellow)
            Text("🥥")
                .font(.system(size: 10))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.goYellow.opacity(0.15), in: Capsule())
    }

    private func cardBackground(_ accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: - Particle burst

    private func fireBurst(accent: Color) {
        let colors: [Color] = [accent, .goYellow, .goLime, .white, accent.opacity(0.6)]
        let count = 18
        particles = (0..<count).map { i in
            let angle = Double(i) * (2 * .pi / Double(count)) + Double.random(in: -0.3...0.3)
            let speed = CGFloat.random(in: 55...130)
            return Particle(
                offset: .zero,
                scale: CGFloat.random(in: 0.7...1.6),
                opacity: 1,
                color: colors[i % colors.count],
                angle: angle,
                speed: speed
            )
        }
        burstActive = true

        withAnimation(.easeOut(duration: 0.55)) {
            for i in particles.indices {
                particles[i].offset = CGSize(
                    width: cos(particles[i].angle) * particles[i].speed,
                    height: sin(particles[i].angle) * particles[i].speed
                )
                particles[i].opacity = 0
                particles[i].scale = 0.2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            burstActive = false
            particles = []
        }
    }
}
