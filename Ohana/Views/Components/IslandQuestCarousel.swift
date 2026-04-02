//
//  IslandQuestCarousel.swift
//  Ohana
//
//  首页横滑岛屿委托：单卡分页 + 自定义指示器 + 跳过 / 完成（逻辑由父视图复用 Bento 同款打卡）
//

import SwiftUI
import SwiftData

// MARK: - Carousel
struct IslandQuestCarousel: View {
    let pets: [Pet]
    let plants: [Plant]
    let todayQuests: [IslandQuest]
    let onComplete: (IslandQuest) -> Void
    let onSkip: (IslandQuest) -> Void
    var onQuestProgress: ((Int, Int) -> Void)? = nil

    @State private var skippedIds: Set<String> = []
    /// 使用 Int 页码驱动 `TabView`，避免 `Binding<String>` + 动态 `ForEach` 在部分系统上触发无限布局循环导致卡死。
    @State private var pageIndex: Int = 0
    @State private var showCoconut = false
    @State private var coconutClaimed: Bool = {
        let key = "coconut_claimed_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        return UserDefaults.standard.bool(forKey: key)
    }()
    @State private var showRewardToast = false
    @State private var toastMessage = ""
    @State private var lastCompletedCount: Int = -1

    private var visibleQuests: [IslandQuest] {
        todayQuests.filter { !$0.isCompleted && !skippedIds.contains($0.id) }
    }

    private var completedCount: Int {
        todayQuests.filter(\.isCompleted).count
    }

    private var allDone: Bool {
        IslandQuestEngine.allCompleted(quests: todayQuests)
    }

    var body: some View {
        Group {
            if allDone && coconutClaimed {
                collapsedCompletedRow
            } else if visibleQuests.isEmpty && allDone {
                coconutCalloutBlock
            } else if visibleQuests.isEmpty {
                emptyNonAllDonePlaceholder
            } else {
                carouselBlock
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
        .onChange(of: completedCount) { _, newVal in
            if newVal > lastCompletedCount && lastCompletedCount >= 0 {
                onQuestProgress?(newVal, todayQuests.count)
            }
            lastCompletedCount = newVal
        }
        .onAppear {
            lastCompletedCount = completedCount
            clampPageIndex()
        }
        .onChange(of: visibleQuests.map(\.id).joined(separator: "|")) { _, _ in
            clampPageIndex()
        }
    }

    /// 列表变化（完成 / 跳过）后保证 `pageIndex` 在有效范围内，避免 `TabView` 选中越界。
    private func clampPageIndex() {
        guard !visibleQuests.isEmpty else {
            pageIndex = 0
            return
        }
        if pageIndex >= visibleQuests.count {
            pageIndex = visibleQuests.count - 1
        }
        if pageIndex < 0 { pageIndex = 0 }
    }

    private var carouselBlock: some View {
        VStack(spacing: 8) {
            TabView(selection: $pageIndex) {
                ForEach(Array(visibleQuests.enumerated()), id: \.element.id) { index, quest in
                    IslandQuestCarouselCard(
                        quest: quest,
                        pets: pets,
                        plants: plants,
                        onComplete: {
                            onComplete(quest)
                            Task { @MainActor in clampPageIndex() }
                        },
                        onSkip: {
                            skippedIds.insert(quest.id)
                            onSkip(quest)
                            Task { @MainActor in clampPageIndex() }
                        }
                    )
                    .padding(.horizontal, 16)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)

            HStack(spacing: 6) {
                ForEach(Array(visibleQuests.enumerated()), id: \.element.id) { i, _ in
                    Circle()
                        .fill(i == pageIndex ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: i == pageIndex ? 8 : 6, height: i == pageIndex ? 8 : 6)
                        .animation(.spring(response: 0.3), value: pageIndex)
                }
            }
        }
    }

    private var collapsedCompletedRow: some View {
        HStack(spacing: 10) {
            Text("✅").font(.system(size: 20))
            Text("今日岛屿委托全部完成！")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.goPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var coconutCalloutBlock: some View {
        VStack(spacing: 12) {
            Button {
                if !coconutClaimed { showCoconut = true }
            } label: {
                HStack(spacing: 10) {
                    Text("🥥").font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coconutClaimed ? "今日盲盒已领取" : "领取今日椰子盲盒！")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(coconutClaimed ? .secondary : Color.arkInk)
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
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    coconutClaimed ? Color.primary.opacity(0.06) : Color.goPrimary,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(coconutClaimed)
        }
        .padding(.horizontal, 16)
    }

    private var emptyNonAllDonePlaceholder: some View {
        VStack(spacing: 8) {
            Text("🌴")
                .font(.system(size: 40))
            Text("今日委托全部完成！")
                .font(.headline)
            Text("岛屿很平静，居民们很满足")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Single card
private struct IslandQuestCarouselCard: View {
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

    private var reward: Int {
        IslandQuestEngine.coconutReward(forQuestId: quest.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            stripColor
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    avatarView
                    Text(typeCapsule)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.goPrimary.opacity(0.35), in: Capsule())
                    Spacer()
                    Button {
                        onSkip()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(quest.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 6)

                Text(quest.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)

                Spacer(minLength: 4)

                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onComplete()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("完成打卡")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                        Spacer()
                        Text("+\(reward)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text("🥥").font(.system(size: 14))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 36
        if let p = relatedPet {
            Group {
                if let data = p.avatarImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(p.speciesEmoji)
                        .font(.system(size: 20))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(stripColor.opacity(0.2))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else if let pl = relatedPlant {
            Text(pl.avatarEmoji)
                .font(.system(size: 20))
                .frame(width: size, height: size)
                .background(stripColor.opacity(0.2), in: Circle())
        } else {
            Text(quest.emoji)
                .font(.system(size: 20))
                .frame(width: size, height: size)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
    }
}
