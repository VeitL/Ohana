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
    let kind: String
    let emoji: String
    let color: Color
    let streak: Int
    let coconutBalance: Int
    var avatarImageData: Data?
    var petSpecies: String?
    var coatColor: Color = Color(hex: "E8C49A")
    var eyeColor:  Color = Color(hex: "6B3A2A")
    var patternName: String?
    var isHuman: Bool = false
    var isDummy: Bool = false
    var actions: [Action]

    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let colorHex: String
    }
}

private extension FocusCard {
    // MARK: Pet
    static func from(_ pet: Pet) -> FocusCard {
        let isDog  = pet.species.contains("狗")  || pet.species.lowercased().contains("dog")
        let isCat  = pet.species.contains("猫")  || pet.species.lowercased().contains("cat")
        let isFish = pet.species.contains("鱼")  || pet.species.lowercased().contains("fish")
        var acts: [Action] = [.init(label: "FEED",  icon: "fork.knife",   colorHex: "FFDD44")]
        if isFish {
            acts += [.init(label: "WATER",  icon: "drop.circle",            colorHex: "00D4AA"),
                     .init(label: "FILTER", icon: "wrench.and.screwdriver", colorHex: "A78BFA")]
        } else if isDog {
            acts += [.init(label: "WALK",  icon: "figure.walk", colorHex: "C8FF00"),
                     .init(label: "WATER", icon: "drop",         colorHex: "00D4AA"),
                     .init(label: "POTTY", icon: "allergens",    colorHex: "A78BFA")]
        } else if isCat {
            acts += [.init(label: "WATER",  icon: "drop",   colorHex: "00D4AA"),
                     .init(label: "LITTER", icon: "trash",  colorHex: "5B6AFF"),
                     .init(label: "PLAY",   icon: "sparkles", colorHex: "F472B6")]
        } else {
            acts += [.init(label: "WATER", icon: "drop",    colorHex: "00D4AA"),
                     .init(label: "PLAY",  icon: "sparkles", colorHex: "F472B6")]
        }
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

    // MARK: Human
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
            actions: [.init(label: "WEIGHT",  icon: "scalemass",    colorHex: "80FFEA"),
                      .init(label: "WORKOUT", icon: "figure.run",   colorHex: "C8FF00"),
                      .init(label: "NOTE",    icon: "note.text",    colorHex: "5B6AFF")]
        )
    }

    // MARK: Dummies (always appended in test mode)
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
                  actions: [.init(label: "FEED",   icon: "fork.knife",            colorHex: "FFDD44"),
                             .init(label: "WATER",  icon: "drop.circle",           colorHex: "00D4AA"),
                             .init(label: "FILTER", icon: "wrench.and.screwdriver",colorHex: "A78BFA")]),
    ]
}

// MARK: - Layout constants

private enum K {
    static let bg     = Color(hex: "F8D8DF")
    static let ink    = Color(hex: "23181A")
    static let muted  = Color(hex: "8B6E74")

    /// Side inset for stack cards (equal left/right margin from screen)
    static let hPad:  CGFloat = 16
    /// Each visible stack row height (= card height when no overlap)
    static let rowH:  CGFloat = 90
    /// How much each card's bottom overlaps the next card's top (creates layered effect)
    static let overlap: CGFloat = 10
    /// Full card height in the stack
    static var cardH: CGFloat { rowH + overlap }

    /// Device screen corner radius — used for stack cards
    static func screenR(_ size: CGSize) -> CGFloat { max(44, min(size.width, size.height) * 0.115) }
    /// Hero card corner radius = screenR − hero margin (concentric)
    static let heroMargin: CGFloat = 16
}

// MARK: - Main view

struct FocusStackHomeTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var questMgr = QuestManager.shared
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @State private var expandedId: UUID?
    @State private var dragOffset: CGFloat = 0

    // ── TEST MODE: real cards + dummies so stacking is always visible
    private var cards: [FocusCard] {
        let real = pets.filter { !$0.hasPassedAway }.map { FocusCard.from($0) }
                 + humans.map { FocusCard.from($0) }
        // Keep up to 2 real entries, fill remainder from dummies
        let realSlice = Array(real.prefix(2))
        let usedNames = Set(realSlice.map { $0.name })
        let extras = FocusCard.dummies.filter { !usedNames.contains($0.name) }
        return realSlice + extras
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                K.bg.ignoresSafeArea()

                // Stack layer — always present (opacity/scale toggled)
                stackLayer(geo: geo)
                    .opacity(expandedId == nil ? 1 : 0)
                    .scaleEffect(expandedId == nil ? 1 : 0.93, anchor: .center)
                    .allowsHitTesting(expandedId == nil)

                // Expanded overlay
                if let id = expandedId, let card = cards.first(where: { $0.id == id }) {
                    expandedLayer(card: card, geo: geo)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.90, anchor: UnitPoint(x: 0.5, y: 0.2))
                                        .combined(with: .opacity),
                            removal:   .scale(scale: 0.90, anchor: UnitPoint(x: 0.5, y: 0.2))
                                        .combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.80), value: expandedId)
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
    }

    // MARK: – Stack layer

    private func stackLayer(geo: GeometryProxy) -> some View {
        let r = K.screenR(geo.size)
        let safeT = geo.safeAreaInsets.top

        return VStack(spacing: 0) {
            // top bar
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("(BACK)")
                        .microLabel()
                        .foregroundStyle(K.muted)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("OHANA CREW")
                    .microLabel(weight: .bold)
                    .foregroundStyle(K.ink.opacity(0.50))
                Spacer()
                HStack(spacing: 3) {
                    Text("🥥")
                    Text("\(questMgr.coconutCount)")
                        .microLabel()
                        .foregroundStyle(K.muted)
                }
            }
            .padding(.horizontal, K.hPad + 6)
            .padding(.top, safeT + 14)
            .frame(height: safeT + 52)

            // ── stacked cards (VStack with negative spacing = overlap effect)
            VStack(spacing: -K.overlap) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    stackCard(card: card, r: r)
                        .zIndex(Double(cards.count - idx)) // first card = highest z
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
                                expandedId = card.id
                            }
                        }
                }
            }
            .padding(.horizontal, K.hPad)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: One stack card

    private func stackCard(card: FocusCard, r: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(card.color.opacity(0.90))

            // Subtle gradient overlay (top highlight)
            LinearGradient(
                colors: [Color.white.opacity(0.16), Color.clear],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))

            // Content row (visible in both peek and full-height regions)
            HStack(spacing: 0) {
                // Left: species / role tag
                Text(card.kind.prefix(5).uppercased())
                    .microLabel(weight: .semibold)
                    .foregroundStyle(K.ink.opacity(0.38))
                    .frame(width: 50, alignment: .leading)
                    .padding(.leading, 20)

                // Center: name — large, dominant
                Text(card.name)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(K.ink.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Spacer(minLength: 10)

                // Right: streak or chevron
                Group {
                    if card.streak > 0 {
                        HStack(spacing: 2) {
                            Text("🔥")
                            Text("\(card.streak)")
                                .microLabel(weight: .bold)
                                .foregroundStyle(K.ink.opacity(0.55))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.28), in: Capsule())
                    } else {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(K.ink.opacity(0.18))
                    }
                }
                .padding(.trailing, 20)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: K.cardH)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    // MARK: – Expanded layer

    private func expandedLayer(card: FocusCard, geo: GeometryProxy) -> some View {
        let screenR = K.screenR(geo.size)
        let heroR   = max(16, screenR - K.heroMargin)   // concentric corner radius
        let safeT   = geo.safeAreaInsets.top
        let safeB   = geo.safeAreaInsets.bottom
        // Hero height: 55% of screen, minus top-bar space
        let topBarH: CGFloat = safeT + 44
        let heroH   = geo.size.height * 0.55
        let heroW   = geo.size.width - K.heroMargin * 2

        return ZStack(alignment: .top) {
            // ── Full-bleed tinted background (same screenR corner = "expanded card" look)
            // Page bg fills device corners; card color fills the rounded rect
            card.color.mix(with: K.bg, by: 0.30)
                .clipShape(RoundedRectangle(cornerRadius: screenR, style: .continuous))
                .ignoresSafeArea()

            // Content column
            VStack(spacing: 0) {
                // Space for top bar
                Color.clear.frame(height: topBarH)

                // ── Hero card — inset K.heroMargin on left, right and below top bar
                heroCardView(card: card, width: heroW, height: heroH, r: heroR)
                    .frame(width: heroW, height: heroH)
                    .padding(.horizontal, K.heroMargin)

                // ── Name + kind
                VStack(spacing: 5) {
                    Text(card.name)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(K.ink.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(card.kind.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(K.ink.opacity(0.28))
                }
                .padding(.top, 18)
                .padding(.horizontal, K.heroMargin)

                // ── Quick actions (GO UI style)
                goStyleActions(card: card)
                    .padding(.horizontal, K.heroMargin)
                    .padding(.top, 20)

                Spacer(minLength: 0)

                if card.isDummy {
                    Text("DEMO DATA")
                        .microLabel()
                        .foregroundStyle(K.ink.opacity(0.16))
                        .padding(.bottom, safeB + 8)
                }
            }

            // ── Top bar overlaid (white text on card-color bg)
            expandedTopBar(card: card)
                .padding(.horizontal, K.heroMargin + 4)
                .padding(.top, safeT + 8)
                .frame(maxWidth: .infinity)
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
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) { dragOffset = 0 }
                    }
                }
        )
    }

    // MARK: Top bar (overlaid on hero card)

    private func expandedTopBar(card: FocusCard) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                    expandedId = nil; dragOffset = 0
                }
            } label: {
                Text(card.streak > 0 ? "🔥 \(card.streak)" : "(BACK)")
                    .microLabel(weight: .bold)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 3) {
                Text("🥥")
                Text("\(questMgr.coconutCount)")
                    .microLabel(weight: .bold)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Menu {
                Button("收起") {
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                        expandedId = nil; dragOffset = 0
                    }
                }
            } label: {
                Text("(MORE)")
                    .microLabel(weight: .bold)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: Hero card

    private func heroCardView(card: FocusCard, width: CGFloat, height: CGFloat, r: CGFloat) -> some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [card.color.mix(with: .white, by: 0.25),
                                 card.color,
                                 card.color.mix(with: .black, by: 0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // Illustration / photo
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
                        coatColor: card.coatColor, eyeColor: card.eyeColor,
                        patternName: card.patternName, isAnimationEnabled: false
                    )
                    .scaleEffect(1.55)
                    .offset(y: 12)
                } else {
                    Text(card.emoji)
                        .font(.system(size: height * 0.40))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Bottom-fade for readability
            LinearGradient(
                colors: [.clear, card.color.mix(with: .black, by: 0.08).opacity(0.55)],
                startPoint: UnitPoint(x: 0.5, y: 0.48), endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    // MARK: GO-style quick action grid

    private func goStyleActions(card: FocusCard) -> some View {
        let acts = card.actions
        let cols = min(acts.count, 4)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols),
            spacing: 0
        ) {
            ForEach(acts) { action in
                goActionCell(action: action)
            }
        }
    }

    private func goActionCell(action: FocusCard.Action) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                // Icon circle
                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: action.colorHex))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: action.colorHex).opacity(0.16), in: Circle())

                // Label
                Text(action.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(K.ink.opacity(0.60))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(K.ink.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func normalizeSpecies(_ s: String) -> String {
        let l = s.lowercased()
        if s.contains("猫")  || l.contains("cat")    { return "猫" }
        if s.contains("狗")  || l.contains("dog")    { return "狗" }
        if s.contains("兔")  || l.contains("rabbit") { return "兔子" }
        if s.contains("仓鼠") || l.contains("hamster"){ return "仓鼠" }
        if s.contains("鸟")  || l.contains("bird")   { return "鸟" }
        return s
    }
}

// MARK: - Human portrait (flat, no shadow)

private struct FocusHumanPortrait: View {
    let emoji: String
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle()
                    .fill(color.mix(with: .white, by: 0.45).opacity(0.35))
                    .frame(width: g.size.width * 0.65)
                    .offset(x: -g.size.width * 0.20, y: -g.size.height * 0.16)
                Text(emoji)
                    .font(.system(size: g.size.height * 0.44))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -g.size.height * 0.04)
            }
        }
    }
}

// MARK: - Text helper

private extension Text {
    func microLabel(weight: Font.Weight = .medium) -> some View {
        self
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
