//
//  HomeHighlightDeck.swift
//  Ohana
//
//  首页横滑高亮甲板：宠物状态 + 打卡连击 + 岛屿委托 + 等级成长
//  高度 160pt，真实 ScrollView（无虚拟倍增），含页码指示器。
//

import SwiftUI
import SwiftData

// MARK: - CardKind

private enum CardKind: Hashable {
    case petStatus
    case humanStatus
    case streak
    case quest(String)   // quest.id
    case questDone
    case coconutCall
    case questEmpty
    case level

    var stableId: String {
        switch self {
        case .petStatus:     return "petStatus"
        case .humanStatus:   return "humanStatus"
        case .streak:        return "streak"
        case .quest(let id): return "quest_\(id)"
        case .questDone:     return "questDone"
        case .coconutCall:   return "coconutCall"
        case .questEmpty:    return "questEmpty"
        case .level:         return "level"
        }
    }
}

// MARK: - HomeHighlightDeck

struct HomeHighlightDeck: View {
    var activePet: Pet?
    var activeHuman: Human? = nil
    let pets: [Pet]
    let plants: [Plant]
    let quests: [IslandQuest]
    var checkInStreak: Int = 0
    var onStreakTap: (() -> Void)? = nil

    let onCompleteQuest: (IslandQuest) -> Void
    let onSkipQuest: (IslandQuest) -> Void
    var onQuestProgress: ((Int, Int) -> Void)? = nil
    var onOasisTap: (() -> Void)? = nil

    // MARK: Persistence helpers

    private static func todayKey(_ prefix: String) -> String {
        let ts = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        return "\(prefix)_\(ts)"
    }

    // MARK: State

    @State private var skippedIds: Set<String> = {
        let key = HomeHighlightDeck.todayKey("hd_skip")
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(arr)
    }()

    @State private var coconutClaimed: Bool = {
        UserDefaults.standard.bool(forKey: HomeHighlightDeck.todayKey("coconut_claimed"))
    }()

    @State private var scrollTarget: String? = nil
    @State private var showCoconut = false
    @State private var showRewardToast = false
    @State private var toastMessage = ""
    @State private var lastCompletedCount: Int = -1
    @State private var pendingCompleteQuest: IslandQuest? = nil

    @Environment(\.colorScheme) private var colorScheme

    // MARK: Computed

    private var visibleQuests: [IslandQuest] {
        quests.filter { !$0.isCompleted && !skippedIds.contains($0.id) }
    }
    private var completedCount: Int { quests.filter(\.isCompleted).count }
    private var allQuestsDone: Bool { IslandQuestEngine.allCompleted(quests: quests) }

    private var cards: [CardKind] {
        var result: [CardKind] = []
        if activeHuman != nil { result.append(.humanStatus) }
        else if activePet != nil { result.append(.petStatus) }
        result.append(.streak)
        if !quests.isEmpty {
            if allQuestsDone && coconutClaimed {
                result.append(.questDone)
            } else if allQuestsDone {
                result.append(.coconutCall)
            } else if visibleQuests.isEmpty {
                result.append(.questEmpty)
            } else {
                for q in visibleQuests { result.append(.quest(q.id)) }
            }
        }
        return result
    }

    private var currentIndex: Int {
        guard let target = scrollTarget else { return 0 }
        return cards.firstIndex { $0.stableId == target } ?? 0
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: 0)  // prevents implicit background bleed
            GeometryReader { geo in
                let cardW = geo.size.width * 0.88
                let margin = (geo.size.width - cardW) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(cards, id: \.stableId) { kind in
                            cardView(for: kind)
                                .id(kind.stableId)
                                .frame(width: cardW, height: 160)
                                .scrollTransition(.animated(.spring(response: 0.3, dampingFraction: 0.8))) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.82)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $scrollTarget)
                .background(.clear)
                .onAppear {
                    if scrollTarget == nil, let first = cards.first {
                        scrollTarget = first.stableId
                    }
                }
            }
            .frame(height: 160)

            // Page indicator
            if cards.count > 1 {
                HStack(spacing: 5) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { idx, _ in
                        Capsule()
                            .fill(idx == currentIndex ? Color.goPrimary : Color.primary.opacity(0.18))
                            .frame(width: idx == currentIndex ? 18 : 5, height: 5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                    }
                }
            }
        }
        // Reward toast
        .overlay(alignment: .top) {
            if showRewardToast {
                Text(toastMessage)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Color.goPrimary, in: Capsule())
                    .shadow(color: Color.goPrimary.opacity(0.45), radius: 10, y: 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
        }
        .background(.clear)
        .sheet(item: $pendingCompleteQuest) { quest in
            QuestConfirmationSheet(
                quest: quest,
                pets: pets,
                reward: IslandQuestEngine.coconutReward(forQuestId: quest.id)
            ) {
                withAnimation(.spring(response: 0.3)) {
                    onCompleteQuest(quest)
                }
                pendingCompleteQuest = nil
            } onCancel: {
                pendingCompleteQuest = nil
            }
        }
        .sheet(isPresented: $showCoconut, onDismiss: {
            let key = HomeHighlightDeck.todayKey("coconut_claimed")
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
        .onAppear { lastCompletedCount = completedCount }
        .onChange(of: completedCount) { _, newVal in
            if newVal > lastCompletedCount && lastCompletedCount >= 0 {
                onQuestProgress?(newVal, quests.count)
            }
            lastCompletedCount = newVal
        }
        .onChange(of: skippedIds) { _, newVal in
            let key = HomeHighlightDeck.todayKey("hd_skip")
            UserDefaults.standard.set(Array(newVal), forKey: key)
        }
    }

    // MARK: Card factory

    @ViewBuilder
    private func cardView(for kind: CardKind) -> some View {
        switch kind {
        case .petStatus:
            if let pet = activePet {
                DeckPetStatusCard(pet: pet)
            } else {
                Color.clear
            }
        case .humanStatus:
            if let human = activeHuman {
                DeckHumanStatusCard(human: human)
            } else {
                Color.clear
            }
        case .streak:
            DeckCheckInStreakCard(streak: checkInStreak) { onStreakTap?() }
        case .quest(let id):
            if let quest = visibleQuests.first(where: { $0.id == id }) {
                DeckQuestCard(
                    quest: quest,
                    pets: pets,
                    plants: plants,
                    onComplete: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if quest.id == "q_walk"
                            || quest.id.hasPrefix("q_feed_")
                            || quest.id.hasPrefix("q_play_")
                            || quest.id.hasPrefix("q_weight_")
                            || quest.id.hasPrefix("q_moment_") {
                            onCompleteQuest(quest)
                        } else {
                            pendingCompleteQuest = quest
                        }
                    },
                    onSkip: {
                        let qid = quest.id
                        withAnimation(.spring(response: 0.3)) {
                            skippedIds.insert(qid)
                        }
                        onSkipQuest(quest)
                    }
                )
            } else {
                Color.clear
            }
        case .questDone:
            DeckQuestDoneCard()
        case .coconutCall:
            DeckCoconutCallCard(claimed: coconutClaimed) {
                if !coconutClaimed { showCoconut = true }
            }
        case .questEmpty:
            DeckQuestEmptyCard {
                withAnimation(.spring(response: 0.3)) {
                    skippedIds.removeAll()
                }
                let key = HomeHighlightDeck.todayKey("hd_skip")
                UserDefaults.standard.removeObject(forKey: key)
            }
        case .level:
            DeckLevelCard(onTap: onOasisTap)
        }
    }
}

// MARK: - DeckHumanStatusCard

private struct DeckHumanStatusCard: View {
    let human: Human
    @Environment(\.colorScheme) private var colorScheme

    private var recentWorkoutCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return human.workoutLogs.filter { $0.date >= cutoff }.count
    }

    private var latestWeight: Double? {
        human.weightLogs.max(by: { $0.date < $1.date })?.weight
    }

    private var themeColor: Color { Color(hex: human.themeColorHex.isEmpty ? "233BFF" : human.themeColorHex) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.15))
                    .blendMode(.multiply)

                HStack(spacing: 16) {
                    // 头像
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 60, height: 60)
                        if let data = human.avatarImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                                .font(.system(size: 30))
                        }
                    }

                    // 信息
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(human.name.isEmpty ? "岛民" : human.name)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(human.roleText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                        if let bday = human.birthday {
                            let years = Calendar.current.dateComponents([.year], from: bday, to: Date()).year ?? 0
                            Text("\(years) 岁")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer(minLength: 6)

                        // 数据行
                        HStack(spacing: 14) {
                            statPill(icon: "🥥", value: "\(human.coconutBalance)")
                            statPill(icon: "💪", value: "\(recentWorkoutCount)次")
                            if let w = latestWeight {
                                statPill(icon: "⚖️", value: String(format: "%.1fkg", w))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @ViewBuilder
    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 11))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.white.opacity(0.15), in: Capsule())
    }
}

// MARK: - DeckPetStatusCard

private struct DeckPetStatusCard: View {
    let pet: Pet
    private let cal = Calendar.current

    private var todayFeedCount: Int {
        pet.careLogs.filter { $0.careType == .feeding && cal.isDateInToday($0.date) }.count
    }
    private var todayWaterCount: Int {
        pet.careLogs.filter { $0.careType == .watering && cal.isDateInToday($0.date) }.count
    }
    private var todayWalkCount: Int {
        pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
    }
    private var todayPottyCount: Int {
        pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
    }
    private var foodDaysLeft: Int? {
        if pet.foodTrackingMode == .casual { return pet.casualRemainingDays }
        let d = pet.remainingFoodDays; return d > 0 ? d : nil
    }
    private var urgentAlert: HealthAlert? {
        PetHealthAlertEngine.shared.scanAlerts(pets: [pet])
            .filter { $0.severity >= .warning }.first
    }
    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var streakColor: Color {
        pet.currentStreak >= 30 ? .orange : (pet.currentStreak >= 7 ? Color.goPrimary : .secondary)
    }
    private var totalToday: Int { todayFeedCount + todayWaterCount + todayWalkCount + todayPottyCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Text(pet.avatarEmoji)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(OhanaFont.title3())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(totalToday == 0 ? "今天还没有打卡记录" : "今日已完成 \(totalToday) 项打卡")
                        .font(OhanaFont.caption())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if pet.currentStreak > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(OhanaFont.caption2())
                        Text("\(pet.currentStreak)")
                            .font(OhanaFont.footnote(.black))
                    }
                    .foregroundStyle(streakColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(streakColor.opacity(0.12), in: Capsule())
                }
            }

            // Check-in pills
            HStack(spacing: 6) {
                pillChip(icon: "fork.knife", count: todayFeedCount)
                pillChip(icon: "drop.fill", count: todayWaterCount)
                if pet.species.lowercased().contains("dog") || pet.species.lowercased().contains("狗") {
                    pillChip(icon: "pawprint.fill", count: todayWalkCount)
                }
                pillChip(icon: "oval.fill", count: todayPottyCount)
                Spacer(minLength: 0)
            }

            // Status row
            HStack(spacing: 6) {
                if let days = foodDaysLeft {
                    let urgent = days <= 3
                    HStack(spacing: 3) {
                        Image(systemName: "bag.fill")
                            .font(OhanaFont.caption2())
                        Text("粮仓 \(days) 天")
                            .font(OhanaFont.caption(.bold))
                    }
                    .foregroundStyle(urgent ? .white : .primary.opacity(0.65))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(urgent ? Color.goRed.opacity(0.8) : Color.primary.opacity(0.06)))
                }
                if let a = urgentAlert {
                    HStack(spacing: 2) {
                        Text(a.emoji).font(OhanaFont.caption2())
                        Text(a.title)
                            .font(OhanaFont.caption())
                            .lineLimit(1)
                    }
                    .foregroundStyle(a.severity == .urgent ? .white : .primary.opacity(0.65))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(
                        a.severity == .urgent ? Color.goRed.opacity(0.75) : Color.goOrange.opacity(0.15)
                    ))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(themeColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func pillChip(icon: String, count: Int) -> some View {
        let done = count > 0
        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(OhanaFont.caption2())
                .foregroundStyle(done ? themeColor : .secondary.opacity(0.5))
            if count > 1 {
                Text("\(count)")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(done ? themeColor : .secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(done ? themeColor.opacity(0.12) : Color.primary.opacity(0.04)))
        .overlay(Capsule().stroke(done ? themeColor.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 0.5))
        .opacity(done ? 1 : 0.55)
    }
}

// MARK: - DeckCheckInStreakCard

private struct DeckCheckInStreakCard: View {
    let streak: Int
    let onTap: () -> Void

    private let milestones = [7, 14, 30, 60, 100, 180, 365]

    private var accentColor: Color { .goOrange }

    private var nextMilestone: Int {
        milestones.first { $0 > streak } ?? milestones.last!
    }
    private var prevMilestone: Int {
        milestones.last { $0 <= streak } ?? 0
    }
    private var milestoneProgress: Double {
        let range = Double(nextMilestone - prevMilestone)
        guard range > 0 else { return 1.0 }
        return min(1.0, Double(streak - prevMilestone) / range)
    }
    private var daysToNext: Int { max(0, nextMilestone - streak) }
    private var trendText: String {
        if streak >= 365 { return "🏆 年度守护者！" }
        if streak >= 180 { return "🌟 半年传奇！" }
        if streak >= 100 { return "💎 百日坚持！" }
        if streak >= 30  { return "🔥 三十天火焰！" }
        if streak >= 7   { return "🔥 连击达人！" }
        return "继续加油！"
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(accentColor)
                    Text("打卡连击")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("🎯 下一里程碑 \(nextMilestone) 天")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(.secondary.opacity(0.7))
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(streak)")
                        .font(OhanaFont.metric(size: 32))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("天")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(.primary.opacity(0.4))
                    Spacer()
                    Text(trendText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(accentColor.opacity(0.9))
                }

                // Milestone progress bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(accentColor.opacity(0.12))
                                .frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [accentColor.opacity(0.7), accentColor],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * milestoneProgress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(daysToNext == 0 ? "🎉 里程碑达成！" : "距 \(nextMilestone) 天里程碑还差 \(daysToNext) 天")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(.secondary.opacity(0.65))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .goTranslucentCard(cornerRadius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DeckQuestCard

private struct DeckQuestCard: View {
    let quest: IslandQuest
    let pets: [Pet]
    let plants: [Plant]
    let onComplete: () -> Void
    let onSkip: () -> Void

    private var relatedPet: Pet? {
        guard let pid = quest.targetPetId else { return nil }
        return pets.first { $0.id == pid }
    }
    private var relatedPlant: Plant? {
        guard let pid = quest.targetPlantId else { return nil }
        return plants.first { $0.id == pid }
    }
    private var stripColor: Color {
        if let p = relatedPet { return Color(hex: p.themeColorHex.isEmpty ? "C8FF00" : p.themeColorHex) }
        if let pl = relatedPlant { return Color(hex: pl.themeColorHex.isEmpty ? "4CAF50" : pl.themeColorHex) }
        return Color.goPrimary
    }
    private var typeLabel: String {
        switch quest.id {
        case "q_walk": return "遛狗"
        case "q_potty": return "噗噗"
        case "q_water_plant": return "浇水"
        case "q_fertilize_plant": return "施肥"
        case "q_visit": return "探望"
        case "q_reminder": return "提醒"
        default:
            if quest.id.hasPrefix("q_play_") { return "陪玩" }
            if quest.id.hasPrefix("q_weight_") { return "体重" }
            if quest.id.hasPrefix("q_moment_") { return "日常" }
            return "委托"
        }
    }
    private var reward: Int { IslandQuestEngine.coconutReward(forQuestId: quest.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: avatar + type badge + skip
            HStack(spacing: 8) {
                avatarView
                Text(typeLabel)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.goPrimary.opacity(0.85), in: Capsule())
                Spacer()
                Button { onSkip() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            // Title
            Text(quest.title)
                .font(OhanaFont.body(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            // Bottom row: reward + CTA
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle.fill")
                        .font(OhanaFont.caption2())
                    Text("+\(reward) 🥥")
                        .font(OhanaFont.caption(.bold))
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onComplete()
                } label: {
                    Text("去完成")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(stripColor.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        let sz: CGFloat = 30
        if let p = relatedPet {
            Group {
                if let data = p.avatarImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Text(p.speciesEmoji)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(stripColor.opacity(0.2))
                }
            }
            .frame(width: sz, height: sz).clipShape(Circle())
        } else if let pl = relatedPlant {
            Text(pl.avatarEmoji)
                .font(.system(size: 16))
                .frame(width: sz, height: sz)
                .background(stripColor.opacity(0.2), in: Circle())
        } else {
            Text(quest.emoji)
                .font(.system(size: 16))
                .frame(width: sz, height: sz)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
    }
}

// MARK: - DeckQuestDoneCard

private struct DeckQuestDoneCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.goTeal)
            VStack(spacing: 4) {
                Text("今日委托全部完成！")
                    .font(OhanaFont.body(.bold))
                    .foregroundStyle(.primary)
                Text("岛屿很平静，居民们很满足 🌴")
                    .font(OhanaFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .goTranslucentCard(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goTeal.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - DeckCoconutCallCard

private struct DeckCoconutCallCard: View {
    let claimed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if claimed {
                // Claimed state
                VStack(spacing: 10) {
                    Text("🌴").font(.system(size: 32))
                    VStack(spacing: 4) {
                        Text("今日盲盒已领取！")
                            .font(OhanaFont.body(.bold))
                            .foregroundStyle(.primary)
                        Text("感谢认真照料你的宠物 🌴")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .goTranslucentCard(cornerRadius: 20)
            } else {
                // Unclaimed CTA
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("🥥").font(.system(size: 30))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("领取今日椰子盲盒！")
                                .font(OhanaFont.body(.bold))
                                .foregroundStyle(Color.arkInk)
                            Text("全勤奖励 · 额外 +5 🥥")
                                .font(OhanaFont.caption())
                                .foregroundStyle(Color.arkInk.opacity(0.65))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(Color.arkInk.opacity(0.5))
                    }
                    Text("所有委托已完成，快来领奖吧！")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.arkInk.opacity(0.7))
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.goLime)
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(claimed)
    }
}

// MARK: - DeckQuestEmptyCard

private struct DeckQuestEmptyCard: View {
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("🌴").font(.system(size: 30))
            VStack(spacing: 4) {
                Text("暂无委托")
                    .font(OhanaFont.body(.bold))
                    .foregroundStyle(.primary)
                Text("今日委托已跳过或暂无任务")
                    .font(OhanaFont.caption())
                    .foregroundStyle(.secondary)
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onReset()
            } label: {
                Text("重置今日委托")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.goPrimary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .goTranslucentCard(cornerRadius: 20)
    }
}

// MARK: - DeckLevelCard

private struct DeckLevelCard: View {
    var onTap: (() -> Void)? = nil
    private let mgr = OasisTreeManager.shared
    @State private var animatedProgress: Double = 0

    private var levelLabel: String {
        "Lv.\(mgr.treeLevel.rawValue)  \(mgr.treeLevel.displayName)"
    }
    private var accentColor: Color {
        mgr.treeLevel.glowColor
    }
    private var nextHint: String {
        guard mgr.treeLevel < .lv10 else { return "🎉 生命之树已达满级！" }
        let need = mgr.nextLevelThreshold - mgr.totalEnergy
        return "还需 \(need) 点能量 · 喂食/遛狗均可获得"
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("🌿")
                        .font(.system(size: 13))
                    Text("岛屿成长")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(mgr.progressToNextLevel * 100))%")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(levelLabel)
                    .font(OhanaFont.metric(size: 26))
                    .foregroundStyle(accentColor)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accentColor.opacity(0.12))
                            .frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [accentColor.opacity(0.7), accentColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * animatedProgress, height: 7)
                            .shadow(color: accentColor.opacity(0.45), radius: 4, y: 0)
                    }
                }
                .frame(height: 7)

                Text(nextHint)
                    .font(OhanaFont.caption2())
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .goTranslucentCard(cornerRadius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                animatedProgress = mgr.progressToNextLevel
            }
        }
        .onChange(of: mgr.progressToNextLevel) { _, v in
            withAnimation(.easeOut(duration: 0.5)) { animatedProgress = v }
        }
    }
}

// MARK: - QuestConfirmationSheet

private struct QuestConfirmationSheet: View {
    let quest: IslandQuest
    let pets: [Pet]
    let reward: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var relatedPet: Pet? {
        guard let pid = quest.targetPetId else { return nil }
        return pets.first { $0.id == pid }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(spacing: 24) {
                // Quest preview
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.goPrimary.opacity(0.12))
                            .frame(width: 72, height: 72)
                        if let pet = relatedPet,
                           let data = pet.avatarImageData,
                           let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                        } else {
                            Text(quest.emoji)
                                .font(.system(size: 36))
                        }
                    }

                    VStack(spacing: 6) {
                        Text(quest.title)
                            .font(OhanaFont.title3(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(OhanaFont.footnote())
                            Text("+\(reward) 🥥 椰子奖励")
                                .font(OhanaFont.footnote(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.08), in: Capsule())
                    }
                }
                .padding(.top, 8)

                // Info text
                Text("确认已完成此委托？")
                    .font(OhanaFont.subheadline(.medium))
                    .foregroundStyle(.secondary)

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onConfirm()
                    } label: {
                        Text("确认完成")
                            .font(OhanaFont.body(.bold))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                    } label: {
                        Text("再想想")
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}
