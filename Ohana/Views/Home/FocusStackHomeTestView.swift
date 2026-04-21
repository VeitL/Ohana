//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  实验页：playlist 堆叠 + 单卡全屏 Focus（Bloom 动画）。
//  入口：设置 → 开发者工具 → Focus Stack 实验主页
//

import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────
// MARK: – Data model
// ─────────────────────────────────────────────────

private struct FocusCard: Identifiable {
    let id: UUID
    let name: String
    let kind: String          // species / role display text
    let emoji: String
    let color: Color
    let streak: Int
    let coconutBalance: Int
    var avatarImageData: Data?
    var petSpecies: String?
    var coatColor:   Color = Color(hex: "E8C49A")
    var eyeColor:    Color = Color(hex: "6B3A2A")
    var patternName: String?
    var isHuman:  Bool = false
    var isDummy:  Bool = false
    var actions: [Action]

    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let colorHex: String
    }
}

private extension FocusCard {

    // MARK: from Pet
    static func from(_ pet: Pet) -> FocusCard {
        let isDog  = pet.species.contains("狗") || pet.species.lowercased().contains("dog")
        let isCat  = pet.species.contains("猫") || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼") || pet.species.lowercased().contains("fish")

        var acts: [Action] = [.init(label: "FEED", icon: "fork.knife", colorHex: "FFDD44")]
        if isFish {
            acts += [.init(label: "WATER",  icon: "drop.circle",             colorHex: "00D4AA"),
                     .init(label: "FILTER", icon: "wrench.and.screwdriver",  colorHex: "A78BFA")]
        } else if isDog {
            acts += [.init(label: "WALK",  icon: "figure.walk", colorHex: "C8FF00"),
                     .init(label: "WATER", icon: "drop",         colorHex: "00D4AA"),
                     .init(label: "POTTY", icon: "allergens",    colorHex: "A78BFA")]
        } else if isCat {
            acts += [.init(label: "WATER",  icon: "drop",     colorHex: "00D4AA"),
                     .init(label: "LITTER", icon: "trash",     colorHex: "5B6AFF"),
                     .init(label: "PLAY",   icon: "sparkles",  colorHex: "F472B6")]
        } else {
            acts += [.init(label: "WATER", icon: "drop",     colorHex: "00D4AA"),
                     .init(label: "PLAY",  icon: "sparkles",  colorHex: "F472B6")]
        }

        let hex = pet.themeColorHex.isEmpty ? "FFB3C6" : pet.themeColorHex
        return FocusCard(
            id: pet.id,
            name: pet.name.isEmpty ? "Unnamed" : pet.name,
            kind: pet.species.isEmpty ? "PET" : pet.species,
            emoji: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
            color: Color(hex: hex),
            streak: pet.currentStreak,
            coconutBalance: pet.coconutBalance,
            avatarImageData: pet.avatarImageData,
            petSpecies: pet.species,
            coatColor: WalletPetCardTheme.silhouetteCoatColor(for: pet),
            eyeColor:  WalletPetCardTheme.silhouetteEyeColor(for: pet),
            patternName: WalletPetCardTheme.coatPatternName(for: pet),
            actions: Array(acts.prefix(4))
        )
    }

    // MARK: from Human
    static func from(_ human: Human) -> FocusCard {
        let hex = human.themeColorHex.isEmpty ? "B9E8D2" : human.themeColorHex
        return FocusCard(
            id: human.id,
            name: human.name.isEmpty ? "Human" : human.name,
            kind: human.roleText.isEmpty ? "HUMAN" : human.roleText,
            emoji: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji,
            color: Color(hex: hex),
            streak: 0,
            coconutBalance: human.coconutBalance,
            avatarImageData: human.avatarImageData,
            isHuman: true,
            actions: [.init(label: "WEIGHT",  icon: "scalemass",  colorHex: "80FFEA"),
                      .init(label: "WORKOUT", icon: "figure.run",  colorHex: "C8FF00"),
                      .init(label: "NOTE",    icon: "note.text",   colorHex: "5B6AFF")]
        )
    }

    // MARK: Dummy cards — always shown in test mode so stacking is visible
    static let dummies: [FocusCard] = [
        FocusCard(id: UUID(), name: "Mochi", kind: "DOG", emoji: "🐶",
                  color: Color(hex: "F4A7B9"), streak: 7, coconutBalance: 42,
                  petSpecies: "狗", coatColor: Color(hex: "D7A76D"), eyeColor: Color(hex: "57341E"),
                  isDummy: true,
                  actions: [.init(label: "FEED",  icon: "fork.knife",  colorHex: "FFDD44"),
                             .init(label: "WALK",  icon: "figure.walk", colorHex: "C8FF00"),
                             .init(label: "WATER", icon: "drop",        colorHex: "00D4AA"),
                             .init(label: "POTTY", icon: "allergens",   colorHex: "A78BFA")]),

        FocusCard(id: UUID(), name: "Luna", kind: "CAT", emoji: "🐱",
                  color: Color(hex: "C9B6E4"), streak: 12, coconutBalance: 66,
                  petSpecies: "猫", coatColor: Color(hex: "9CA7B2"), eyeColor: Color(hex: "7A4E20"),
                  isDummy: true,
                  actions: [.init(label: "FEED",   icon: "fork.knife", colorHex: "FFDD44"),
                             .init(label: "WATER",  icon: "drop",        colorHex: "00D4AA"),
                             .init(label: "LITTER", icon: "trash",       colorHex: "5B6AFF"),
                             .init(label: "PLAY",   icon: "sparkles",    colorHex: "F472B6")]),

        FocusCard(id: UUID(), name: "Alex", kind: "HUMAN", emoji: "🧑‍💻",
                  color: Color(hex: "B9E8D2"), streak: 3, coconutBalance: 18,
                  isHuman: true, isDummy: true,
                  actions: [.init(label: "WEIGHT",  icon: "scalemass",  colorHex: "80FFEA"),
                             .init(label: "WORKOUT", icon: "figure.run", colorHex: "C8FF00"),
                             .init(label: "NOTE",    icon: "note.text",  colorHex: "5B6AFF")]),

        FocusCard(id: UUID(), name: "Nemo", kind: "FISH", emoji: "🐟",
                  color: Color(hex: "C7E7F1"), streak: 4, coconutBalance: 24,
                  petSpecies: "鱼", isDummy: true,
                  actions: [.init(label: "FEED",   icon: "fork.knife",             colorHex: "FFDD44"),
                             .init(label: "WATER",  icon: "drop.circle",            colorHex: "00D4AA"),
                             .init(label: "FILTER", icon: "wrench.and.screwdriver", colorHex: "A78BFA")]),
    ]
}

// ─────────────────────────────────────────────────
// MARK: – Layout constants
// ─────────────────────────────────────────────────

private enum K {
    /// Page background — soft pink
    static let bg    = Color(hex: "F8D8DF")
    static let ink   = Color(hex: "23181A")
    static let muted = Color(hex: "8B6E74")

    /// Horizontal screen margin for the stack
    static let hPad: CGFloat = 20

    /// Full height of each stack card (≈ GO UI wallet card)
    static let cardH: CGFloat = 200
    /// Visible peek height of cards stacked behind the top card
    static let peekH: CGFloat = 76
    /// Negative VStack spacing that produces the peek overlap
    static var stackSpacing: CGFloat { -(cardH - peekH) }   // –124

    /// Equal margin from expanded background to hero card (top / left / right)
    static let heroMargin: CGFloat = 16

    /// Corner radius matching the device's physical screen corner
    static func screenR(_ size: CGSize) -> CGFloat {
        max(44, min(size.width, size.height) * 0.115)
    }
    /// Concentric inner radius for the hero card (screenR – margin)
    static func heroR(_ size: CGSize) -> CGFloat {
        max(16, screenR(size) - heroMargin)
    }
}

// ─────────────────────────────────────────────────
// MARK: – Main view
// ─────────────────────────────────────────────────

struct FocusStackHomeTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var questMgr = QuestManager.shared
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @Namespace private var ns
    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0

    /// Test-mode card list: up to 2 real entries, rest filled with dummies
    private var cards: [FocusCard] {
        let real = pets.filter { !$0.hasPassedAway }.map { FocusCard.from($0) }
                 + humans.map { FocusCard.from($0) }
        let realSlice  = Array(real.prefix(2))
        let usedNames  = Set(realSlice.map { $0.name })
        let extras     = FocusCard.dummies.filter { !usedNames.contains($0.name) }
        return realSlice + extras
    }

    var body: some View {
        GeometryReader { geo in
            let screenR = K.screenR(geo.size)

            ZStack {
                // ① Always-visible page background
                K.bg.ignoresSafeArea()

                // ② Stack layer — always rendered so MGE sources stay alive;
                //    opacity/pointer-events toggled when a card is expanded
                stackLayer(geo: geo, screenR: screenR)
                    .opacity(expandedId == nil ? 1 : 0)
                    .allowsHitTesting(expandedId == nil)

                // ③ Expanded bloom overlay for the tapped card
                if let id = expandedId,
                   let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo, screenR: screenR)
                }
            }
            .animation(.spring(response: 0.52, dampingFraction: 0.80), value: expandedId)
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
    }
}

// ─────────────────────────────────────────────────
// MARK: – Stack layer
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    private func stackLayer(geo: GeometryProxy, screenR: CGFloat) -> some View {
        let safeT = geo.safeAreaInsets.top

        return VStack(spacing: 0) {
            // ── Top navigation bar
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("← BACK")
                        .fcMicro(weight: .semibold)
                        .foregroundStyle(K.muted)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("OHANA CREW")
                    .fcMicro(weight: .bold)
                    .foregroundStyle(K.ink.opacity(0.38))

                Spacer()

                HStack(spacing: 4) {
                    Text("🥥")
                    Text("\(questMgr.coconutCount)")
                        .fcMicro()
                        .foregroundStyle(K.muted)
                }
            }
            .padding(.horizontal, K.hPad + 4)
            .padding(.top, safeT + 12)
            .frame(height: safeT + 52)

            // ── Stacked cards (VStack with negative spacing = peek overlap)
            VStack(spacing: K.stackSpacing) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    stackCard(card: card, r: screenR)
                        .zIndex(Double(cards.count - idx))  // first card on top
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.52, dampingFraction: 0.80)) {
                                expandedId = card.id
                            }
                        }
                }
            }
            .padding(.horizontal, K.hPad)
            .padding(.top, 24)

            Spacer()
        }
    }

    // MARK: Single stack card

    private func stackCard(card: FocusCard, r: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // ── Card background — matchedGeometryEffect SOURCE
            //    This is the frame SwiftUI blooms from when expanding.
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(card.color)
                .matchedGeometryEffect(id: card.id, in: ns)

            // Top-gloss gradient (decorative)
            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.50)
            )
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            .allowsHitTesting(false)

            // Upper illustration area (emoji — fully visible for top card)
            Text(card.emoji)
                .font(.system(size: 56))
                .frame(maxWidth: .infinity)
                .frame(height: K.cardH - K.peekH - 8, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 18)
                .allowsHitTesting(false)

            // ── Bottom info strip (= peekH; always visible in the stacked peek)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.kind.prefix(6).uppercased())
                        .fcMicro()
                        .foregroundStyle(K.ink.opacity(0.38))
                    Text(card.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(K.ink.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)
                }

                Spacer(minLength: 8)

                if card.streak > 0 {
                    HStack(spacing: 3) {
                        Text("🔥")
                        Text("\(card.streak)")
                            .fcMicro(weight: .bold)
                            .foregroundStyle(K.ink.opacity(0.55))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.32), in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(height: K.peekH)
        }
        .frame(height: K.cardH)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }
}

// ─────────────────────────────────────────────────
// MARK: – Expanded layer (bloom)
// ─────────────────────────────────────────────────

extension FocusStackHomeTestView {

    private func expandedLayer(card: FocusCard,
                               geo: GeometryProxy,
                               screenR: CGFloat) -> some View {
        let heroR     = K.heroR(geo.size)
        let safeT     = geo.safeAreaInsets.top
        let safeB     = geo.safeAreaInsets.bottom
        let topBarH:  CGFloat = 44
        let heroW     = geo.size.width  - K.heroMargin * 2
        // Hero height: fills from (topBar + heroMargin) down to ≈ 58% of screen
        let heroH     = max(180, geo.size.height * 0.55 - (safeT + topBarH + K.heroMargin * 2))
        let bgColor   = card.color.mix(with: K.bg, by: 0.18)

        return ZStack(alignment: .top) {
            // ── Bloom background — matchedGeometryEffect DESTINATION
            //    Starts at the source card's frame, then animates to fill screen.
            RoundedRectangle(cornerRadius: screenR, style: .continuous)
                .fill(bgColor)
                .matchedGeometryEffect(id: card.id, in: ns, isSource: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // ── Content column on top of the background
            VStack(spacing: 0) {
                // Status bar spacer
                Color.clear.frame(height: safeT)

                // Top bar: back (streak) | coconuts | more
                expandedTopBar(card: card)
                    .padding(.horizontal, K.heroMargin + 6)
                    .frame(height: topBarH)

                // Hero card — equal heroMargin on top / left / right
                heroCardView(card: card, width: heroW, height: heroH, r: heroR)
                    .frame(width: heroW, height: heroH)
                    .padding(.horizontal, K.heroMargin)
                    .padding(.top, K.heroMargin)

                // Name + species / role
                VStack(spacing: 4) {
                    Text(card.name)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(K.ink.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(card.kind.uppercased())
                        .fcMicro()
                        .foregroundStyle(K.ink.opacity(0.28))
                }
                .padding(.top, 18)
                .padding(.horizontal, K.heroMargin)

                // Quick actions — floating buttons with K.bg background + shadow
                goStyleActions(card: card)
                    .padding(.horizontal, K.heroMargin)
                    .padding(.top, 18)

                Spacer(minLength: 0)

                if card.isDummy {
                    Text("DEMO DATA")
                        .fcMicro()
                        .foregroundStyle(K.ink.opacity(0.16))
                        .padding(.bottom, safeB + 6)
                }
            }
        }
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { v in
                    if v.translation.height > 0 { dragOffset = v.translation.height }
                }
                .onEnded { v in
                    if v.translation.height > 80 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                            expandedId = nil
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: Expanded top bar

    private func expandedTopBar(card: FocusCard) -> some View {
        HStack(spacing: 0) {
            // Left: back button (doubles as streak badge when streak > 0)
            Button {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                    expandedId = nil
                    dragOffset = 0
                }
            } label: {
                Group {
                    if card.streak > 0 {
                        HStack(spacing: 4) {
                            Text("🔥")
                            Text("\(card.streak)")
                                .fcMicro(weight: .bold)
                                .foregroundStyle(K.ink.opacity(0.65))
                        }
                    } else {
                        Text("← BACK")
                            .fcMicro(weight: .semibold)
                            .foregroundStyle(K.ink.opacity(0.45))
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center: coconuts
            HStack(spacing: 4) {
                Text("🥥")
                Text("\(questMgr.coconutCount)")
                    .fcMicro(weight: .bold)
                    .foregroundStyle(K.ink.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Right: more menu
            Menu {
                Button("收起") {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                        expandedId = nil
                        dragOffset = 0
                    }
                }
            } label: {
                Text("•••")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(K.ink.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: Hero card (no top bar overlay — just illustration + gradient)

    private func heroCardView(card: FocusCard,
                              width: CGFloat,
                              height: CGFloat,
                              r: CGFloat) -> some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [card.color.mix(with: .white, by: 0.28),
                                 card.color,
                                 card.color.mix(with: .black, by: 0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Avatar / illustration
            Group {
                if let data = card.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                } else if card.isHuman {
                    FocusHumanPortrait(emoji: card.emoji, color: card.color)
                } else if let sp = card.petSpecies {
                    PetSilhouetteView(
                        species: normalizeSpecies(sp),
                        coatColor: card.coatColor,
                        eyeColor: card.eyeColor,
                        patternName: card.patternName,
                        isAnimationEnabled: false
                    )
                    .scaleEffect(1.55)
                    .offset(y: 12)
                } else {
                    Text(card.emoji)
                        .font(.system(size: height * 0.40))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Bottom readability gradient
            LinearGradient(
                colors: [.clear, card.color.mix(with: .black, by: 0.10).opacity(0.50)],
                startPoint: UnitPoint(x: 0.5, y: 0.45),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    // MARK: Quick action grid — buttons float above page bg with shadow

    private func goStyleActions(card: FocusCard) -> some View {
        let acts = card.actions
        let cols = min(acts.count, 4)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols),
            spacing: 0
        ) {
            ForEach(acts) { goActionCell(action: $0) }
        }
    }

    private func goActionCell(action: FocusCard.Action) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: action.colorHex))
                    .frame(width: 46, height: 46)
                    .background(Color(hex: action.colorHex).opacity(0.16), in: Circle())

                Text(action.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(K.ink.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            // Background = same as page bg, shadow creates the "floating" feel
            .background(K.bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: K.ink.opacity(0.11), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func normalizeSpecies(_ s: String) -> String {
        let l = s.lowercased()
        if s.contains("猫") || l.contains("cat")     { return "猫"  }
        if s.contains("狗") || l.contains("dog")     { return "狗"  }
        if s.contains("兔") || l.contains("rabbit")  { return "兔子" }
        if s.contains("仓鼠") || l.contains("hamster") { return "仓鼠" }
        if s.contains("鸟") || l.contains("bird")    { return "鸟"  }
        return s
    }
}

// ─────────────────────────────────────────────────
// MARK: – Human portrait placeholder
// ─────────────────────────────────────────────────

private struct FocusHumanPortrait: View {
    let emoji: String
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle()
                    .fill(color.mix(with: .white, by: 0.45).opacity(0.30))
                    .frame(width: g.size.width * 0.65)
                    .offset(x: -g.size.width * 0.18, y: -g.size.height * 0.14)
                Text(emoji)
                    .font(.system(size: g.size.height * 0.44))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -g.size.height * 0.04)
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Text style helper (monospaced micro-label)
// ─────────────────────────────────────────────────

private extension Text {
    /// Compact monospaced all-caps label used throughout this view.
    func fcMicro(weight: Font.Weight = .medium) -> some View {
        self
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
