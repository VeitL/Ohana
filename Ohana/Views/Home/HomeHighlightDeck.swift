//
//  HomeHighlightDeck.swift
//  Ohana
//
//  首页横滑高亮甲板：将 PetWellnessCard + IslandEnergyBar + IslandQuestCarousel
//  三块内容合并成一条 130pt 高的横向可滑动卡片组，节省约 270pt 垂直空间。
//

import SwiftUI
import SwiftData

// MARK: - Main Deck

struct HomeHighlightDeck: View {
    // 当前顶牌宠物（nil = 无宠物 / 顶牌为人类）
    var activePet: Pet?
    let pets: [Pet]
    let plants: [Plant]
    let quests: [IslandQuest]
    /// 全岛每日打开打卡连击（与 `oasis_checkedIn_dates` 一致）
    var checkInStreak: Int = 0
    var onStreakTap: (() -> Void)? = nil

    let onCompleteQuest: (IslandQuest) -> Void
    let onSkipQuest: (IslandQuest) -> Void
    var onQuestProgress: ((Int, Int) -> Void)? = nil
    var onOasisTap: (() -> Void)? = nil

    // MARK: - Internal state
    @State private var skippedIds: Set<String> = []
    @State private var showCoconut = false
    @State private var coconutClaimed: Bool = {
        let key = "coconut_claimed_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        return UserDefaults.standard.bool(forKey: key)
    }()
    @State private var showRewardToast = false
    @State private var toastMessage = ""
    @State private var lastCompletedCount: Int = -1
    @State private var deckScrollTarget: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    private let deckVirtualMultiplier = 20

    // MARK: - Computed

    private var visibleQuests: [IslandQuest] {
        quests.filter { !$0.isCompleted && !skippedIds.contains($0.id) }
    }
    private var completedCount: Int { quests.filter(\.isCompleted).count }
    private var allQuestsDone: Bool { IslandQuestEngine.allCompleted(quests: quests) }

    // MARK: - Slot kinds

    private enum DeckSlotKind: Equatable {
        case petStatus
        case checkInStreak
        case quest(String)
        case questDone
        case coconutCall
        case questEmpty
        case level
    }

    private var baseSlotKinds: [DeckSlotKind] {
        var slots: [DeckSlotKind] = []
        if activePet != nil { slots.append(.petStatus) }
        slots.append(.checkInStreak)
        if !quests.isEmpty {
            if allQuestsDone && coconutClaimed {
                slots.append(.questDone)
            } else if allQuestsDone {
                slots.append(.coconutCall)
            } else if visibleQuests.isEmpty {
                slots.append(.questEmpty)
            } else {
                for quest in visibleQuests { slots.append(.quest(quest.id)) }
            }
        }
        slots.append(.level)
        return slots
    }

    @ViewBuilder
    private func cardView(for slot: DeckSlotKind) -> some View {
        switch slot {
        case .petStatus:
            if let pet = activePet { DeckPetStatusCard(pet: pet) } else { Color.clear }
        case .checkInStreak:
            DeckCheckInStreakCard(streak: checkInStreak, onTap: { onStreakTap?() })
        case .quest(let id):
            if let quest = visibleQuests.first(where: { $0.id == id }) {
                DeckQuestCard(
                    quest: quest,
                    pets: pets,
                    plants: plants,
                    onSkip: {
                        let qid = quest.id
                        _ = withAnimation(.spring(response: 0.3)) { skippedIds.insert(qid) }
                        onSkipQuest(quest)
                    }
                )
            } else { Color.clear }
        case .questDone:
            DeckQuestDoneCard()
        case .coconutCall:
            DeckCoconutCallCard(claimed: coconutClaimed) {
                if !coconutClaimed { showCoconut = true }
            }
        case .questEmpty:
            DeckQuestEmptyCard()
        case .level:
            DeckLevelCard(onTap: onOasisTap)
        }
    }

    // MARK: - Body

    var body: some View {
        let slots = baseSlotKinds
        let n = max(1, slots.count)
        let virtualN = n * deckVirtualMultiplier
        let startVIdx = n * (deckVirtualMultiplier / 2)

        ZStack(alignment: .top) {
            GeometryReader { geo in
                let cardW = geo.size.width * 0.88
                let margin = (geo.size.width - cardW) / 2   // 居中磁吸边距

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(0..<virtualN, id: \.self) { vIdx in
                            cardView(for: slots[vIdx % n])
                                .id("vdeck_\(vIdx)")
                                .frame(width: cardW, height: 130)
                                .scrollTransition(.animated(.bouncy)) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.85)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.97)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                .scrollPosition(id: $deckScrollTarget)
                .background(.clear)
                .onAppear {
                    if deckScrollTarget == nil {
                        deckScrollTarget = "vdeck_\(startVIdx)"
                    }
                }
                .onChange(of: slots.count) { _, newCount in
                    let newN = max(1, newCount)
                    deckScrollTarget = "vdeck_\(newN * (deckVirtualMultiplier / 2))"
                }
            }
            .frame(height: 130)
            .background(.clear)

            // Reward toast
            if showRewardToast {
                Text(toastMessage)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Color.goPrimary, in: Capsule())
                    .shadow(color: Color.goPrimary.opacity(0.45), radius: 10, y: 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
                    .allowsHitTesting(false)
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
        .onAppear { lastCompletedCount = completedCount }
        .onChange(of: completedCount) { _, newVal in
            if newVal > lastCompletedCount && lastCompletedCount >= 0 {
                onQuestProgress?(newVal, quests.count)
            }
            lastCompletedCount = newVal
        }
    }
}

// MARK: - Card: 全岛打卡连击（原 HomeBentoBoxes 打卡卡，迁入横滑甲板）

private struct DeckCheckInStreakCard: View {
    let streak: Int
    let onTap: () -> Void

    private var accentColor: Color { .goOrange }
    private var trendText: String { streak >= 7 ? "🔥 火热连击！" : "继续保持！" }
    private var filledBars: Int { min(7, streak) }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text("打卡连击")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.55))
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(streak)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("天")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Text(trendText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < filledBars ? accentColor : accentColor.opacity(0.18))
                            .frame(maxWidth: .infinity)
                            .frame(height: 4)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card: Pet Status

private struct DeckPetStatusCard: View {
    let pet: Pet
    @Environment(\.colorScheme) private var colorScheme

    private let cal = Calendar.current

    private var todayFeedCount: Int {
        pet.careLogs.filter { $0.type == "feeding" && cal.isDateInToday($0.date) }.count
    }
    private var todayWaterCount: Int {
        pet.careLogs.filter { $0.type == "watering" && cal.isDateInToday($0.date) }.count
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
    private var todaySummaryText: String {
        let total = todayFeedCount + todayWaterCount + todayWalkCount + todayPottyCount
        return total == 0 ? "今天还没有打卡记录" : "今日已完成 \(total) 项打卡"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Text(pet.avatarEmoji)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 1) {
                    Text(pet.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(todaySummaryText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if pet.currentStreak > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(pet.currentStreak)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
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

            // Status row (food + alert)
            HStack(spacing: 6) {
                if let days = foodDaysLeft {
                    let urgent = days <= 3
                    HStack(spacing: 3) {
                        Image(systemName: "bag.fill").font(.system(size: 9, weight: .bold))
                        Text("粮仓 \(days) 天").font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(urgent ? .white : .primary.opacity(0.65))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(urgent ? Color.red.opacity(0.8) : Color.primary.opacity(0.06)))
                }
                if let a = urgentAlert {
                    HStack(spacing: 2) {
                        Text(a.emoji).font(.system(size: 9))
                        Text(a.title).font(.system(size: 10, weight: .medium, design: .rounded)).lineLimit(1)
                    }
                    .foregroundStyle(a.severity == .urgent ? .white : .primary.opacity(0.65))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(a.severity == .urgent ? Color.red.opacity(0.75) : Color.orange.opacity(0.15)))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(height: 130)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(themeColor.opacity(0.18), lineWidth: 1)
        )
    }

    private func pillChip(icon: String, count: Int) -> some View {
        let done = count > 0
        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(done ? themeColor : .secondary.opacity(0.5))
            if count > 1 {
                Text("\(count)").font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(done ? themeColor : .secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(done ? themeColor.opacity(0.12) : Color.primary.opacity(0.04)))
        .overlay(Capsule().stroke(done ? themeColor.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 0.5))
        .opacity(done ? 1 : 0.55)
    }
}

// MARK: - Card: Quest (compact)

private struct DeckQuestCard: View {
    let quest: IslandQuest
    let pets: [Pet]
    let plants: [Plant]
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
    private var typeCapsule: String {
        switch quest.id {
        case "q_walk": return "遛狗"
        case "q_potty": return "噗噗"
        case "q_water_plant": return "浇水"
        case "q_fertilize_plant": return "施肥"
        case "q_visit": return "探望"
        case "q_reminder": return "提醒"
        default: return "委托"
        }
    }
    private var reward: Int { IslandQuestEngine.coconutReward(forQuestId: quest.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: avatar + badge + skip
            HStack(spacing: 8) {
                avatarView
                Text(typeCapsule)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.goPrimary.opacity(0.22), in: Capsule())
                Spacer()
                Button { onSkip() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Title
            Text(quest.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)

            Spacer(minLength: 0)

            // Reward hint
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text("完成任务自动获得")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                Spacer()
                Text("+\(reward)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text("🥥").font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(height: 130)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
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
                    Text(p.speciesEmoji).font(.system(size: 16))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(stripColor.opacity(0.2))
                }
            }
            .frame(width: sz, height: sz).clipShape(Circle())
        } else if let pl = relatedPlant {
            Text(pl.avatarEmoji).font(.system(size: 16))
                .frame(width: sz, height: sz)
                .background(stripColor.opacity(0.2), in: Circle())
        } else {
            Text(quest.emoji).font(.system(size: 16))
                .frame(width: sz, height: sz)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
    }
}

// MARK: - Card: All Quests Done (collapsed)

private struct DeckQuestDoneCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text("今日委托全部完成！")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("岛屿很平静，居民们很满足 🌴")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.goPrimary)
        }
        .padding(14)
        .frame(height: 130)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Card: Coconut Callout (collect reward)

private struct DeckCoconutCallCard: View {
    let claimed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("🥥").font(.system(size: 32))
                VStack(alignment: .leading, spacing: 4) {
                    Text(claimed ? "今日盲盒已领取" : "领取今日椰子盲盒！")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(claimed ? .secondary : Color.arkInk)
                    if !claimed {
                        Text("全勤奖励 · 全勤额外 +5🥥")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.arkInk.opacity(0.6))
                    }
                }
                Spacer()
                if !claimed {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.arkInk.opacity(0.4))
                }
            }
            .padding(14)
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(claimed ? Color.primary.opacity(0.06) : Color.goPrimary)
            )
        }
        .buttonStyle(.plain)
        .disabled(claimed)
    }
}

// MARK: - Card: Empty quests placeholder

private struct DeckQuestEmptyCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("🌴").font(.system(size: 32))
            VStack(alignment: .leading, spacing: 3) {
                Text("暂无委托")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("今日委托已跳过或暂无任务")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(height: 130)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Card: Island Level (合并 EnergyBar + OasisTree)

private struct DeckLevelCard: View {
    var onTap: (() -> Void)? = nil
    private let mgr = OasisTreeManager.shared
    @State private var animatedProgress: Double = 0

    private var levelLabel: String {
        "Lv.\(mgr.treeLevel.rawValue) \(mgr.treeLevel.displayName)"
    }
    private var nextHint: String {
        guard mgr.treeLevel < .lv10 else { return "🎉 生命之树已达满级！" }
        return "还需 \(mgr.nextLevelThreshold - mgr.totalEnergy) 点能量升级"
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("🌿")
                        .font(.system(size: 13))
                    Text("岛屿成长")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))
                    Spacer()
                    Text("\(Int(mgr.progressToNextLevel * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(levelLabel)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 7)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.goPrimary.opacity(0.75), Color.goPrimary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * animatedProgress, height: 7)
                            .shadow(color: Color.goPrimary.opacity(0.4), radius: 3, y: 0)
                    }
                }
                .frame(height: 7)

                Text(nextHint)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(14)
            .frame(height: 130)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.18), lineWidth: 0.5)
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
