//
//  TodayFocusCard.swift
//  Ohana
//
//  首页简化 · 岛屿三层重构（P0）
//  替换原先的 HomeHighlightDeck 水平滑动卡组：
//  按优先级智能选出"今天最该做的 1 件事"，单卡呈现 + 微动效。
//
//  优先级：异常趋势/医疗风险 > 未完成委托 > 记忆碎片 > 全部完成庆祝 > 岛屿探访
//
//  v2 实时响应：内部 @Query 监听 PetCareLog / PetWalkLog / PetPottyLog，
//  用户在对应打卡/记录页保存后无需父视图手动刷新。
//

import SwiftUI
import SwiftData

// MARK: - TodayFocusCard

struct TodayFocusCard: View {
    let pets: [Pet]
    let plants: [Plant]
    let quests: [IslandQuest]        // passed from parent; isCompleted may be stale
    let humans: [Human]
    let activePet: Pet?
    var onCompleteQuest: (IslandQuest) -> Void = { _ in }
    var onTapNegativeSignal: (IslandNegativeSignal) -> Void = { _ in }
    var onTapMemory: () -> Void = {}
    var onTapOasis: () -> Void = {}

    // Live @Query arrays — force re-render on any new check-in
    @Query(sort: \PetCareLog.date, order: .reverse) private var liveCare: [PetCareLog]
    @Query(sort: \PetWalkLog.startDate, order: .reverse) private var liveWalks: [PetWalkLog]
    @Query(sort: \PetPottyLog.date, order: .reverse) private var livePotty: [PetPottyLog]
    @Query(sort: \HumanWeightLog.date, order: .reverse) private var liveHumanWeights: [HumanWeightLog]

    @State private var bounceEmoji = false
    @State private var pulse: CGFloat = 0
    @State private var selectedFocusIndex = 0
    @State private var skippedFocusKeys: Set<String> = TodayFocusCard.loadSkippedFocusKeys()

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true

    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    private var refreshedQuests: [IslandQuest] {
        TodayFocusService.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            careLogs: liveCare,
            walkLogs: liveWalks,
            pottyLogs: livePotty,
            humanWeightLogs: liveHumanWeights
        )
    }

    private var pendingQuests: [IslandQuest] {
        refreshedQuests.filter { !$0.isCompleted && !skippedFocusKeys.contains(questSkipKey($0)) }
    }

    private var negativeSignals: [IslandNegativeSignal] {
        IslandNegativeFeedback.signals(pets: pets, plants: plants)
            .filter { !skippedFocusKeys.contains(negativeSkipKey($0)) }
    }

    private var focusCards: [TodayFocusService.Content] {
        if !negativeSignals.isEmpty {
            return negativeSignals.prefix(2).map { .negative($0) } + pendingQuests.map { .quest($0) }
        }
        if !pendingQuests.isEmpty {
            return pendingQuests.map { .quest($0) }
        }
        if !refreshedQuests.isEmpty || !pets.isEmpty || !plants.isEmpty || !humans.isEmpty {
            return [.celebrate(pets: pets)]
        }
        return [.welcome]
    }

    private var content: TodayFocusService.Content {
        let cards = focusCards
        guard !cards.isEmpty else { return .welcome }
        return cards[min(selectedFocusIndex, cards.count - 1)]
    }

    private var focusStatusText: String {
        if case .negative = content {
            return TodayFocusService.statusText(for: content)
        }
        let pending = pendingQuests.count
        if pending > 0 {
            return "\(pending)/\(max(refreshedQuests.count, pending)) 个任务"
        }
        return TodayFocusService.statusText(for: content)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TODAY FOCUS")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(.primary.opacity(0.36))
                        Text("今天要做什么")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                    Spacer()
                    Text(focusStatusText)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.07), in: Capsule())
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
                    .id(contentIdentity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }

        }
        .onAppear {
            guard !shouldReduceWork else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = 1 }
        }
        .onChange(of: focusCards.count) { _, count in
            if selectedFocusIndex >= count {
                selectedFocusIndex = max(0, count - 1)
            }
        }
        .animation(GoMotion.hero, value: contentIdentity)
    }

    // MARK: - Card switcher

    @ViewBuilder
    private var card: some View {
        let cards = focusCards
        if cards.count > 1 {
            VStack(spacing: 4) {
                TabView(selection: $selectedFocusIndex) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { idx, item in
                        cardContent(item)
                            .padding(.horizontal, 2)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 112)

                focusPageIndicator(count: cards.count, selected: selectedFocusIndex)
            }
        } else {
            cardContent(cards.first ?? .welcome)
        }
    }

    @ViewBuilder
    private func cardContent(_ content: TodayFocusService.Content) -> some View {
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

            VStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onCompleteQuest(q)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .black))
                        Text("去完成")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)

                skipButton(for: .quest(q), accent: accent)
            }
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

            VStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTapNegativeSignal(s)
                } label: {
                    Text(s.severity == .critical ? "立即处理" : "去快捷打卡")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)

                skipButton(for: .negative(s), accent: accent)
            }
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
                        guard !shouldReduceWork else { return }
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            bounceEmoji = true
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(skippedFocusKeys.isEmpty ? "今日任务已清空" : "今天已暂时跳过")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(skippedFocusKeys.isEmpty ? "没有需要处理的任务，安心享受今天" : "跳过的卡明天会自动回来")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Button {
                if skippedFocusKeys.isEmpty {
                    onTapOasis()
                } else {
                    restoreSkippedFocusCards()
                }
            } label: {
                Text(skippedFocusKeys.isEmpty ? "去绿洲" : "恢复")
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

    private func focusPageIndicator(count: Int, selected: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(idx == selected ? Color.goPrimary : Color.primary.opacity(0.18))
                    .frame(width: idx == selected ? 16 : 5, height: 5)
                    .animation(GoMotion.feedback, value: selected)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("今日任务 \(min(selected + 1, count)) / \(count)")
    }

    private var contentIdentity: String {
        focusCards.map(contentKey).joined(separator: "|") + "|skipped:\(skippedFocusKeys.sorted().joined(separator: ","))"
    }

    private func contentKey(_ content: TodayFocusService.Content) -> String {
        switch content {
        case .quest(let q): return questSkipKey(q)
        case .negative(let s): return negativeSkipKey(s)
        case .memory(let m): return "memory:\(m.headline)"
        case .celebrate: return "celebrate"
        case .welcome: return "welcome"
        }
    }

    private func questSkipKey(_ quest: IslandQuest) -> String {
        "quest:\(quest.id)"
    }

    private func negativeSkipKey(_ signal: IslandNegativeSignal) -> String {
        if let petId = signal.petId, let alertType = signal.healthAlertType {
            return "negative:health:\(petId.uuidString):\(alertType.rawValue)"
        }
        return "negative:\(signal.title)|\(signal.detail)"
    }

    private func skipButton(for content: TodayFocusService.Content, accent: Color) -> some View {
        Button {
            skipFocusCard(content)
        } label: {
            Text("跳过")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.primary.opacity(0.58))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(accent.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("跳过这张 Today Focus 卡")
    }

    private func skipFocusCard(_ content: TodayFocusService.Content) {
        let key = contentKey(content)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(GoMotion.hero) {
            _ = skippedFocusKeys.insert(key)
        }
        persistSkippedFocusKeys()
        let nextCount = focusCards.count
        if selectedFocusIndex >= nextCount {
            selectedFocusIndex = max(0, nextCount - 1)
        }
    }

    private func restoreSkippedFocusCards() {
        withAnimation(GoMotion.hero) {
            skippedFocusKeys.removeAll()
            selectedFocusIndex = 0
        }
        UserDefaults.standard.removeObject(forKey: Self.skippedStorageKey())
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func persistSkippedFocusKeys() {
        UserDefaults.standard.set(Array(skippedFocusKeys), forKey: Self.skippedStorageKey())
    }

    private static func loadSkippedFocusKeys() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: skippedStorageKey()) ?? [])
    }

    private static func skippedStorageKey() -> String {
        let day = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        return "todayFocus.skipped.\(day)"
    }

    private func cardBackground(_ accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }
}
