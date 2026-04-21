//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  实验页：playlist 堆叠卡片 + 全屏 Focus 展开。
//  入口：设置 → 开发者工具 → Focus Stack 实验主页
//

import SwiftUI
import SwiftData

// MARK: - Data model

private struct FocusCard: Identifiable {
    let id: UUID
    let name: String
    let species: String          // 宠物物种 / 人类角色
    let emoji: String
    let color: Color
    let streak: Int
    var avatarImageData: Data?
    // 快捷动作标签（最多4个）
    var actions: [FocusAction]
    var isDummy: Bool = false

    struct FocusAction: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
    }
}

private extension FocusCard {
    static func from(_ pet: Pet) -> FocusCard {
        let isDog = pet.species.localizedCaseInsensitiveContains("狗") || pet.species.localizedCaseInsensitiveContains("dog")
        let isCat = pet.species.localizedCaseInsensitiveContains("猫") || pet.species.localizedCaseInsensitiveContains("cat")
        let isFish = pet.species.localizedCaseInsensitiveContains("鱼") || pet.species.localizedCaseInsensitiveContains("fish")

        var acts: [FocusCard.FocusAction] = [
            .init(label: "FEED", icon: "fork.knife"),
        ]
        if isFish {
            acts += [.init(label: "WATER", icon: "drop.circle.fill"), .init(label: "FILTER", icon: "wrench.and.screwdriver")]
        } else if isDog {
            acts += [.init(label: "WALK", icon: "figure.walk"), .init(label: "WATER", icon: "drop.fill"), .init(label: "POTTY", icon: "allergens")]
        } else if isCat {
            acts += [.init(label: "WATER", icon: "drop.fill"), .init(label: "LITTER", icon: "trash"), .init(label: "PLAY", icon: "sparkles")]
        } else {
            acts += [.init(label: "WATER", icon: "drop.fill"), .init(label: "PLAY", icon: "sparkles")]
        }

        let colorHex = pet.themeColorHex.isEmpty ? "5B6AFF" : pet.themeColorHex
        return FocusCard(
            id: pet.id,
            name: pet.name,
            species: pet.species.isEmpty ? "PET" : pet.species,
            emoji: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
            color: Color(hex: colorHex),
            streak: pet.currentStreak,
            avatarImageData: pet.avatarImageData,
            actions: Array(acts.prefix(4))
        )
    }

    static func from(_ human: Human) -> FocusCard {
        let colorHex = human.themeColorHex.isEmpty ? "4338FF" : human.themeColorHex
        return FocusCard(
            id: human.id,
            name: human.name,
            species: "HUMAN",
            emoji: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji,
            color: Color(hex: colorHex),
            streak: 0,
            avatarImageData: human.avatarImageData,
            actions: [
                .init(label: "WEIGHT", icon: "scalemass"),
                .init(label: "WORKOUT", icon: "figure.run"),
                .init(label: "NOTE", icon: "note.text"),
            ]
        )
    }

    // MARK: Dummies (shown when no real data)
    static let dummies: [FocusCard] = [
        FocusCard(id: UUID(), name: "Mochi", species: "DOG", emoji: "🐶",
                  color: Color(hex: "FFB3C6"), streak: 7,
                  actions: [.init(label: "FEED", icon: "fork.knife"),
                             .init(label: "WALK", icon: "figure.walk"),
                             .init(label: "WATER", icon: "drop.fill"),
                             .init(label: "POTTY", icon: "allergens")], isDummy: true),
        FocusCard(id: UUID(), name: "Luna", species: "CAT", emoji: "🐱",
                  color: Color(hex: "C3B1E1"), streak: 12,
                  actions: [.init(label: "FEED", icon: "fork.knife"),
                             .init(label: "WATER", icon: "drop.fill"),
                             .init(label: "LITTER", icon: "trash"),
                             .init(label: "PLAY", icon: "sparkles")], isDummy: true),
        FocusCard(id: UUID(), name: "Alex", species: "HUMAN", emoji: "🧑‍💻",
                  color: Color(hex: "B5EAD7"), streak: 0,
                  actions: [.init(label: "WEIGHT", icon: "scalemass"),
                             .init(label: "WORKOUT", icon: "figure.run"),
                             .init(label: "NOTE", icon: "note.text")], isDummy: true),
        FocusCard(id: UUID(), name: "Nemo", species: "FISH", emoji: "🐟",
                  color: Color(hex: "AED9E0"), streak: 3,
                  actions: [.init(label: "FEED", icon: "fork.knife"),
                             .init(label: "WATER", icon: "drop.circle.fill"),
                             .init(label: "FILTER", icon: "wrench.and.screwdriver")], isDummy: true),
    ]
}

// MARK: - Layout constants

private enum FSLayout {
    /// iPhone 全面屏圆角：取设备最短边 × 0.12，约 44–52pt
    static func screenCornerRadius() -> CGFloat {
        let m = min(ScreenCompat.width, ScreenCompat.height)
        return max(40, m * 0.115)
    }
    static let hMargin: CGFloat = 0        // 卡片左右贴边（距离屏幕边缘与系统圆角一致）
    static let peekStep: CGFloat = 80      // 每张卡可见高度（叠放偏移量）
    static let heroRatio: CGFloat = 0.55   // 展开后英雄卡占屏幕高度比例
    static let topBarHeight: CGFloat = 36
}

// MARK: - Main view

struct FocusStackHomeTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var questMgr = QuestManager.shared
    @Query(sort: \Pet.createdAt)   private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @Namespace private var heroNS
    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0

    // ── derived card list
    private var cards: [FocusCard] {
        let realPets   = pets.filter { !$0.hasPassedAway }.map { FocusCard.from($0) }
        let realHumans = humans.map { FocusCard.from($0) }
        let real = realPets + realHumans
        return real.isEmpty ? FocusCard.dummies : real
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                canvas.ignoresSafeArea()

                if let id = expandedId, let card = cards.first(where: { $0.id == id }) {
                    expandedScreen(card: card, geo: geo)
                        .offset(y: max(0, dragOffset))
                        .transition(.opacity)
                } else {
                    stackScreen(geo: geo)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.46, dampingFraction: 0.80), value: expandedId)
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
    }

    // MARK: – Canvas

    private var canvas: some View {
        Color(hex: "FAF0E8")   // warm off-white — looks great behind pastel cards
    }

    // MARK: – Stack screen

    private func stackScreen(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // ── top bar
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("(BACK)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.55))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("OHANA CREW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Color(hex: "8B7355").opacity(0.55))

                Spacer()

                HStack(spacing: 3) {
                    Text("🥥")
                    Text("\(questMgr.coconutCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.65))
                }
            }
            .padding(.horizontal, 20)
            .frame(height: FSLayout.topBarHeight)
            .padding(.top, geo.safeAreaInsets.top + 4)

            // ── stacked cards
            ZStack(alignment: .topLeading) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    stackCard(card: card, index: idx, total: cards.count)
                        .offset(y: CGFloat(idx) * FSLayout.peekStep)
                        .zIndex(Double(cards.count - idx))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.46, dampingFraction: 0.80)) {
                                expandedId = card.id
                            }
                        }
                }
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }

    // MARK: – Single stack card (peek strip)

    private func stackCard(card: FocusCard, index: Int, total: Int) -> some View {
        // Height: last card is taller to show more; others show peekStep
        let isLast = index == total - 1
        let height: CGFloat = isLast
            ? FSLayout.peekStep + 40   // last card shows extra
            : FSLayout.peekStep

        return ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: FSLayout.screenCornerRadius(), style: .continuous)
                .fill(card.color.opacity(0.82))
                .frame(height: height)

            // Content row
            HStack(alignment: .center, spacing: 0) {
                // Left tag
                Text(card.species.prefix(5).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(card.color.mix(with: .black, by: 0.45))
                    .frame(width: 48, alignment: .leading)
                    .padding(.leading, 20)

                // Name — large & black
                Text(card.name.uppercased())
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1208").opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Spacer(minLength: 12)

                // Streak badge (right)
                if card.streak >= 3 {
                    HStack(spacing: 2) {
                        Text("🔥")
                            .font(.system(size: 10))
                        Text("\(card.streak)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "3D2B0F").opacity(0.7))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.35), in: Capsule())
                    .padding(.trailing, 18)
                } else {
                    // Chevron hint
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "5C4D3E").opacity(0.25))
                        .padding(.trailing, 18)
                }
            }
            .frame(height: min(FSLayout.peekStep, height))
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        // Subtle top divider except first
        .overlay(alignment: .top) {
            if index > 0 {
                Color.white.opacity(0.2).frame(height: 1)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: – Expanded full-screen

    private func expandedScreen(card: FocusCard, geo: GeometryProxy) -> some View {
        let safeTop = geo.safeAreaInsets.top
        let safeBot = geo.safeAreaInsets.bottom
        let heroH = geo.size.height * FSLayout.heroRatio

        return ZStack(alignment: .top) {
            // Tinted background matching card color
            card.color.opacity(0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── top bar
                expandedTopBar(card: card)
                    .padding(.horizontal, 20)
                    .frame(height: FSLayout.topBarHeight)
                    .padding(.top, safeTop + 4)

                // ── hero card (55% height)
                heroCard(card: card, width: geo.size.width, height: heroH)
                    .padding(.top, 14)

                // ── name + subtitle (below card)
                VStack(spacing: 5) {
                    Text(card.name)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1208").opacity(0.88))

                    Text(card.species.uppercased() + (card.streak > 0 ? "  ·  \(card.streak) day streak" : ""))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "5C4D3E").opacity(0.55))
                }
                .padding(.top, 18)

                // ── quick action buttons
                actionsBar(card: card)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                Spacer(minLength: 0)

                // ── dummy data notice
                if card.isDummy {
                    Text("DEMO DATA")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.3))
                        .padding(.bottom, safeBot + 6)
                }
            }
        }
        // Swipe-down to collapse
        .gesture(
            DragGesture()
                .onChanged { v in
                    if v.translation.height > 0 { dragOffset = v.translation.height }
                }
                .onEnded { v in
                    if v.translation.height > 90 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            expandedId = nil
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: – Top bar (expanded state)

    private func expandedTopBar(card: FocusCard) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: streak
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                    expandedId = nil
                    dragOffset = 0
                }
            } label: {
                Text(card.streak > 0 ? "🔥 \(card.streak)" : "(BACK)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color(hex: "5C4D3E").opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center: name · kind
            Text("\(card.name.uppercased()) · \(card.species.prefix(3).uppercased())")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "5C4D3E").opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)

            // Right: coconuts + more
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    Text("🥥")
                        .font(.system(size: 11))
                    Text("\(questMgr.coconutCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "5C4D3E").opacity(0.65))
                }

                Menu {
                    Button("收起") {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            expandedId = nil; dragOffset = 0
                        }
                    }
                    if card.isDummy {
                        Button("说明") {}
                    }
                } label: {
                    Text("···")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "5C4D3E").opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: – Hero card

    @ViewBuilder
    private func heroCard(card: FocusCard, width: CGFloat, height: CGFloat) -> some View {
        let r = FSLayout.screenCornerRadius()
        // Left, right AND top margins are equal (= hMargin = 0 → edge-to-edge, matching device radius)
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            card.color.opacity(0.95),
                            card.color.mix(with: .black, by: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Avatar / photo
            if let data = card.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            } else {
                Text(card.emoji)
                    .font(.system(size: height * 0.38))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            // Name overlay (top-left)
            VStack(alignment: .leading, spacing: 0) {
                Text(card.name.uppercased())
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1208").opacity(0.65))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        // No shadow — "少用阴影"
    }

    // MARK: – Actions bar

    private func actionsBar(card: FocusCard) -> some View {
        HStack(spacing: 10) {
            ForEach(card.actions) { action in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(action.label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color(hex: "4A3728").opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color(hex: "C4B5A0").opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
