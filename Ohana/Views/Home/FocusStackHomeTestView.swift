//
//  FocusStackHomeTestView.swift
//  Ohana
//
//  实验页：playlist 堆叠 + 单卡全屏 Focus。
//  入口：设置 → 开发者工具 → Focus Stack 实验主页
//

import SwiftUI
import SwiftData

// MARK: - Card model

private struct FocusCard: Identifiable {
    let id: UUID
    let name: String
    let kind: String          // species / role
    let emoji: String
    let color: Color
    let streak: Int
    let coconutBalance: Int
    var avatarImageData: Data?
    var petSpecies: String?
    var coatColor: Color = Color(hex: "E8C49A")
    var eyeColor: Color = Color(hex: "6B3A2A")
    var patternName: String?
    var isHuman: Bool = false
    var isDummy: Bool = false
    var actions: [Action]

    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
    }
}

private extension FocusCard {
    // MARK: Pet factory
    static func from(_ pet: Pet) -> FocusCard {
        let isDog  = pet.species.contains("狗")  || pet.species.lowercased().contains("dog")
        let isCat  = pet.species.contains("猫")  || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼")  || pet.species.lowercased().contains("fish")
        var acts: [Action] = [.init(label: "FEED",  icon: "fork.knife")]
        if isFish  { acts += [.init(label: "WATER",  icon: "drop.circle"),
                               .init(label: "FILTER", icon: "wrench.and.screwdriver")] }
        else if isDog { acts += [.init(label: "WALK",  icon: "figure.walk"),
                                  .init(label: "WATER", icon: "drop"),
                                  .init(label: "POTTY", icon: "allergens")] }
        else if isCat { acts += [.init(label: "WATER", icon: "drop"),
                                  .init(label: "LITTER",icon: "trash"),
                                  .init(label: "PLAY",  icon: "sparkles")] }
        else          { acts += [.init(label: "WATER", icon: "drop"),
                                  .init(label: "PLAY",  icon: "sparkles")] }
        let hex = pet.themeColorHex.isEmpty ? "FFB3C6" : pet.themeColorHex
        return FocusCard(
            id: pet.id, name: pet.name.isEmpty ? "Unnamed" : pet.name,
            kind: pet.species.isEmpty ? "PET" : pet.species,
            emoji: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
            color: Color(hex: hex), streak: pet.currentStreak,
            coconutBalance: pet.coconutBalance,
            avatarImageData: pet.avatarImageData,
            petSpecies: pet.species,
            coatColor: WalletPetCardTheme.silhouetteCoatColor(for: pet),
            eyeColor:  WalletPetCardTheme.silhouetteEyeColor(for: pet),
            patternName: WalletPetCardTheme.coatPatternName(for: pet),
            actions: Array(acts.prefix(4))
        )
    }

    // MARK: Human factory
    static func from(_ human: Human) -> FocusCard {
        let hex = human.themeColorHex.isEmpty ? "B9E8D2" : human.themeColorHex
        return FocusCard(
            id: human.id, name: human.name.isEmpty ? "Human" : human.name,
            kind: human.roleText.isEmpty ? "HUMAN" : human.roleText,
            emoji: human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji,
            color: Color(hex: hex), streak: 0,
            coconutBalance: human.coconutBalance,
            avatarImageData: human.avatarImageData,
            isHuman: true,
            actions: [.init(label: "WEIGHT",  icon: "scalemass"),
                      .init(label: "WORKOUT", icon: "figure.run"),
                      .init(label: "NOTE",    icon: "note.text")]
        )
    }

    // MARK: Dummies
    static let dummies: [FocusCard] = [
        FocusCard(id: UUID(), name: "Mochi", kind: "DOG", emoji: "🐶",
                  color: Color(hex: "F4A7B9"), streak: 7, coconutBalance: 42,
                  petSpecies: "狗", coatColor: Color(hex: "D7A76D"), eyeColor: Color(hex: "57341E"),
                  isDummy: true,
                  actions: [.init(label: "FEED",  icon: "fork.knife"),
                             .init(label: "WALK",  icon: "figure.walk"),
                             .init(label: "WATER", icon: "drop"),
                             .init(label: "POTTY", icon: "allergens")]),
        FocusCard(id: UUID(), name: "Luna", kind: "CAT", emoji: "🐱",
                  color: Color(hex: "C9B6E4"), streak: 12, coconutBalance: 66,
                  petSpecies: "猫", coatColor: Color(hex: "9CA7B2"), eyeColor: Color(hex: "7A4E20"),
                  isDummy: true,
                  actions: [.init(label: "FEED",  icon: "fork.knife"),
                             .init(label: "WATER", icon: "drop"),
                             .init(label: "LITTER",icon: "trash"),
                             .init(label: "PLAY",  icon: "sparkles")]),
        FocusCard(id: UUID(), name: "Alex", kind: "HUMAN", emoji: "🧑‍💻",
                  color: Color(hex: "B9E8D2"), streak: 3, coconutBalance: 18,
                  isHuman: true, isDummy: true,
                  actions: [.init(label: "WEIGHT",  icon: "scalemass"),
                             .init(label: "WORKOUT", icon: "figure.run"),
                             .init(label: "NOTE",    icon: "note.text")]),
        FocusCard(id: UUID(), name: "Nemo", kind: "FISH", emoji: "🐟",
                  color: Color(hex: "C7E7F1"), streak: 4, coconutBalance: 24,
                  petSpecies: "鱼", isDummy: true,
                  actions: [.init(label: "FEED",   icon: "fork.knife"),
                             .init(label: "WATER",  icon: "drop.circle"),
                             .init(label: "FILTER", icon: "wrench.and.screwdriver")]),
    ]
}

// MARK: - Constants

private enum K {
    // Stack layout
    /// Full height of each stack card
    static let cardH: CGFloat = 200
    /// How many pt of the BOTTOM of each card peek out below the card above it
    static let peekH: CGFloat = 80
    /// Horizontal padding around stack cards
    static let hPad:  CGFloat = 0

    // Colors
    static let bg     = Color(hex: "F8D8DF")
    static let ink    = Color(hex: "23181A")
    static let muted  = Color(hex: "8B6E74")

    /// Corner radius matching device screen (~44–52 pt on modern iPhones)
    static func screenR(_ size: CGSize) -> CGFloat {
        max(44, min(size.width, size.height) * 0.115)
    }
}

// MARK: - Main

struct FocusStackHomeTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var questMgr = QuestManager.shared
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0

    private var cards: [FocusCard] {
        let r = pets.filter { !$0.hasPassedAway }.map { FocusCard.from($0) }
              + humans.map { FocusCard.from($0) }
        return r.isEmpty ? FocusCard.dummies : r
    }

    // MARK: body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 1. Full-bleed background (always behind everything)
                K.bg.ignoresSafeArea()

                // ── 2. Stack layer — always rendered so geometry is stable
                stackLayer(geo: geo)
                    .opacity(expandedId == nil ? 1 : 0)
                    .scaleEffect(expandedId == nil ? 1 : 0.94, anchor: .center)
                    .allowsHitTesting(expandedId == nil)

                // ── 3. Expanded overlay
                if let id = expandedId, let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92, anchor: UnitPoint(x: 0.5, y: 0.18))
                                .combined(with: .opacity),
                            removal:   .scale(scale: 0.92, anchor: UnitPoint(x: 0.5, y: 0.18))
                                .combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.44, dampingFraction: 0.82), value: expandedId)
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
    }

    // MARK: – Stack layer

    private func stackLayer(geo: GeometryProxy) -> some View {
        let n      = cards.count
        let totalH = K.cardH + CGFloat(max(n - 1, 0)) * K.peekH
        let r      = K.screenR(geo.size)
        let safeT  = geo.safeAreaInsets.top

        return VStack(spacing: 0) {
            // top bar
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("(BACK)")
                        .microCap()
                        .foregroundStyle(K.muted)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("OHANA CREW")
                    .microCap(weight: .bold)
                    .foregroundStyle(K.ink.opacity(0.52))
                Spacer()
                Text("(\(questMgr.coconutCount) 🥥)")
                    .microCap()
                    .foregroundStyle(K.muted)
            }
            .padding(.horizontal, 22)
            .padding(.top, safeT + 14)
            .frame(height: safeT + 50)

            // card stack
            ZStack(alignment: .top) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    stackCard(card: card, r: r)
                        .offset(y: CGFloat(idx) * K.peekH)
                        // ★ FIRST card has HIGHEST z — it covers all others except their peek
                        .zIndex(Double(n - idx))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                                expandedId = card.id
                            }
                        }
                }
            }
            .frame(height: totalH, alignment: .top)
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }

    /// One card in the stack.
    /// The card is `K.cardH` tall. Only the BOTTOM `K.peekH` is visible
    /// for non-first cards (the card above covers the top portion).
    /// → Name text sits within the bottom `K.peekH` zone.
    private func stackCard(card: FocusCard, r: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // background
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(card.color.opacity(0.88))

            // subtle top-shine
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.28)
            )
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))

            // ── content row: always in bottom 80pt (the peek zone)
            HStack(spacing: 0) {
                // left tag
                Text(card.kind.prefix(5).uppercased())
                    .microCap(weight: .semibold)
                    .foregroundStyle(K.ink.opacity(0.42))
                    .frame(width: 52, alignment: .leading)
                    .padding(.leading, 22)

                // name — big, dominant
                Text(card.name)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(K.ink.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Spacer(minLength: 10)

                // right badge
                Group {
                    if card.streak > 0 {
                        Text("🔥 \(card.streak)")
                            .microCap(weight: .bold)
                            .foregroundStyle(K.ink.opacity(0.55))
                    } else {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(K.ink.opacity(0.22))
                    }
                }
                .padding(.trailing, 22)
            }
            .frame(height: K.peekH)   // exactly the peek height
        }
        .frame(height: K.cardH)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    // MARK: – Expanded layer

    private func expandedLayer(card: FocusCard, geo: GeometryProxy) -> some View {
        let r      = K.screenR(geo.size)
        let safeT  = geo.safeAreaInsets.top
        let safeB  = geo.safeAreaInsets.bottom
        let heroH  = geo.size.height * 0.55

        return ZStack(alignment: .top) {
            // Tinted full-screen background
            card.color.mix(with: K.bg, by: 0.55)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Hero card (edge-to-edge, top/left/right margin = 0)
                heroCardView(card: card, width: geo.size.width, height: heroH, r: r)
                    .frame(width: geo.size.width, height: heroH)
                    .padding(.top, 0)

                // ── Name + subtitle
                VStack(spacing: 6) {
                    Text(card.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(K.ink.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(card.kind.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(K.ink.opacity(0.30))
                }
                .padding(.top, 20)
                .padding(.horizontal, 28)

                // ── Quick action buttons
                actionsRow(card: card)
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                Spacer(minLength: 0)

                if card.isDummy {
                    Text("DEMO DATA")
                        .microCap()
                        .foregroundStyle(K.ink.opacity(0.18))
                        .padding(.bottom, safeB + 8)
                }
            }
            .frame(maxWidth: .infinity)

            // ── Top bar overlaid ON the hero card
            expandedTopBar(card: card)
                .padding(.horizontal, 20)
                .padding(.top, safeT + 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            expandedId = nil; dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: Top bar (overlaid on hero card)

    private func expandedTopBar(card: FocusCard) -> some View {
        HStack(spacing: 0) {
            // Left: streak or back
            Button {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                    expandedId = nil; dragOffset = 0
                }
            } label: {
                Text(card.streak > 0 ? "🔥 STREAK \(card.streak)" : "(BACK)")
                    .microCap(weight: .bold)
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center: coconuts
            HStack(spacing: 3) {
                Text("🥥")
                Text("\(questMgr.coconutCount)")
                    .microCap(weight: .bold)
                    .foregroundStyle(Color.white.opacity(0.80))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Right: more menu
            Menu {
                Button("收起") {
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                        expandedId = nil; dragOffset = 0
                    }
                }
            } label: {
                Text("(MORE)")
                    .microCap(weight: .bold)
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: Hero card (full-width, edge-to-edge)

    private func heroCardView(card: FocusCard, width: CGFloat, height: CGFloat, r: CGFloat) -> some View {
        ZStack {
            // background gradient
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            card.color.mix(with: .white, by: 0.28),
                            card.color,
                            card.color.mix(with: .black, by: 0.14)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // avatar / illustration
            if let data = card.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            } else if card.isHuman {
                FocusHumanIllustration(emoji: card.emoji, color: card.color)
            } else if let species = card.petSpecies {
                PetSilhouetteView(
                    species: normalizeSpecies(species),
                    coatColor: card.coatColor,
                    eyeColor:  card.eyeColor,
                    patternName: card.patternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(1.6)
                .offset(y: 14)
                .clipped()
            } else {
                Text(card.emoji)
                    .font(.system(size: height * 0.42))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // bottom fade for readability
            LinearGradient(
                colors: [.clear, card.color.mix(with: .black, by: 0.08).opacity(0.5)],
                startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        // ★ No shadow — "少用阴影"
    }

    // MARK: Action buttons

    private func actionsRow(card: FocusCard) -> some View {
        HStack(spacing: 10) {
            ForEach(card.actions) { action in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(action.label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(K.ink.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.28),
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(K.ink.opacity(0.07), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func normalizeSpecies(_ s: String) -> String {
        if s.contains("猫") || s.lowercased().contains("cat")     { return "猫" }
        if s.contains("狗") || s.lowercased().contains("dog")     { return "狗" }
        if s.contains("兔") || s.lowercased().contains("rabbit")  { return "兔子" }
        if s.contains("仓鼠") || s.lowercased().contains("hamster"){ return "仓鼠" }
        if s.contains("鸟") || s.lowercased().contains("bird")    { return "鸟" }
        return s
    }
}

// MARK: - Human illustration (no shadow, flat)

private struct FocusHumanIllustration: View {
    let emoji: String
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // soft blob
                Circle()
                    .fill(color.mix(with: .white, by: 0.48).opacity(0.38))
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: -geo.size.width * 0.22, y: -geo.size.height * 0.18)

                // emoji centered slightly above midpoint
                Text(emoji)
                    .font(.system(size: geo.size.height * 0.48))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -geo.size.height * 0.04)
            }
        }
    }
}

// MARK: - Text modifier

private extension Text {
    func microCap(weight: Font.Weight = .medium) -> some View {
        self
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
