//
//  PetWalletStack.swift
//  Ohana
//
//  iOS Wallet 堆叠 + App Store Today 展开动效
//  使用 matchedTransitionSource + navigationTransition(.zoom) 实现原生英雄过渡
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - 钱包宠物卡共享视觉（向导草稿卡 + 首页持久化卡保持一致）
enum WalletPetCardTheme {
    /// 与 `WalletPetCardDraftFront` 一致：由 `themeColorHex` 推导顶/底渐变
    static func gradientPair(for hex: String) -> (Color, Color) {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let tc = PetThemeColor.allCases.first(where: { $0.hexValue.uppercased() == normalized }) {
            return (tc.color, tc.deepColor)
        }
        let c = Color(hex: hex)
        let ui = UIColor(c)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        guard ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else {
            return (Color(hex: "233BFF"), Color(hex: "141FAE"))
        }
        let topB = min(1.0, bri * 1.1)
        let botB = max(0.12, bri * 0.4)
        let top = Color(UIColor(hue: hue, saturation: min(1, sat * 0.92), brightness: topB, alpha: alpha))
        let bottom = Color(UIColor(hue: hue, saturation: min(1, sat * 1.02), brightness: botB, alpha: alpha))
        return (top, bottom)
    }

    /// 与草稿卡一致：约 6 字内满幅，更长则缩小
    static func headlinePointSize(cardWidth w: CGFloat, headlineCount: Int) -> CGFloat {
        let n = max(1, headlineCount)
        let base = w * 0.28
        if n <= 6 { return base }
        let ratio = 6.0 / Double(n)
        let softened = pow(ratio, 0.82)
        return max(w * 0.085, base * CGFloat(softened))
    }

    /// 与添加向导 `resolvedCoatColor` 一致，供首页剪影（`pet.coatColor` 存展示名而非 hex）
    static func silhouetteCoatColor(for pet: Pet) -> Color {
        let name = pet.coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return Color(hex: "E8C49A") }
        if name == "自定义" { return Color(hex: "E8C49A") }
        if let pattern = PetCoatPattern.allCases.first(where: { $0.displayName == name }) {
            switch pattern {
            case .calico: return Color(hex: "D4B896")
            case .silverChinchilla: return Color(hex: "C8C8C8")
            case .tortoiseshell: return Color(hex: "6E2C00")
            case .cowPattern: return .white
            case .bicolor: return Color(hex: "95ADBE")
            }
        }
        let bi = PetBreedDatabase.breeds(for: pet.species).first { $0.name == pet.breed }
        let coatItems = bi?.coatColors ?? PetBreedDatabase.genericCoatColors
        if let found = coatItems.first(where: { $0.name == name }) { return found.color }
        if name.count == 6, name.allSatisfy({ $0.isHexDigit }) { return Color(hex: name) }
        return Color(hex: "E8C49A")
    }

    static func silhouetteEyeColor(for pet: Pet) -> Color {
        let name = pet.eyeColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return Color(hex: "6B3A2A") }
        if name == "自定义" { return Color(hex: "6B3A2A") }
        let bi = PetBreedDatabase.breeds(for: pet.species).first { $0.name == pet.breed }
        let eyeItems = bi?.eyeColors ?? PetBreedDatabase.genericEyeColors
        if let found = eyeItems.first(where: { $0.name == name }) { return found.color }
        if name.count == 6, name.allSatisfy({ $0.isHexDigit }) { return Color(hex: name) }
        return Color(hex: "6B3A2A")
    }

    static func coatPatternName(for pet: Pet) -> String? {
        PetCoatPattern.allCases.first { $0.displayName == pet.coatColor }?.displayName
    }

    /// Generate 3x3 mesh gradient colors derived from themeColorHex
    static func meshColors(for hex: String) -> [Color] {
        let (top, bottom) = gradientPair(for: hex)
        let ui = UIColor(top)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return Array(repeating: top, count: 9)
        }
        let lighter = Color(UIColor(hue: h, saturation: max(0, s * 0.68), brightness: min(1.0, b * 1.22), alpha: a))
        let light   = Color(UIColor(hue: h, saturation: s, brightness: min(1.0, b * 1.06), alpha: a))
        let darker  = Color(UIColor(hue: h, saturation: min(1.0, s * 1.12), brightness: max(0.08, b * 0.22), alpha: a))
        return [
            lighter, light,  top,
            light,   top,    bottom,
            top,     bottom, darker
        ]
    }
}

// MARK: - Wallet Stack Container
struct PetWalletStack: View {
    let pets: [Pet]
    let humans: [Human]
    var heroNS: Namespace.ID
    var onSelectPet: (Pet) -> Void
    var onSelectHuman: ((Human) -> Void)? = nil
    var onTopCardChanged: ((DeckItem) -> Void)? = nil

    var onShowDocuments: ((Pet) -> Void)? = nil
    var onShowMoments: ((Pet) -> Void)? = nil
    var onShowAchievements: ((Pet) -> Void)? = nil
    var onShowHealth: ((Pet) -> Void)? = nil
    var onShowBackSettings: ((Pet) -> Void)? = nil
    // New feature hub callbacks
    var onShowCalendar: ((Pet) -> Void)? = nil
    var onShowMedications: ((Pet) -> Void)? = nil
    var onShowFood: ((Pet) -> Void)? = nil
    var onShowEdit: ((Pet) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var activeIndex: Int = 0
    @State private var isDragging = false
    @State private var flippedPetIds: Set<UUID> = []

    private var items: [DeckItem] {
        let petItems = pets.map { DeckItem.pet($0) }
        let humanItems = humans.filter { $0.shouldShowOnHome }.map { DeckItem.human($0) }
        return petItems + humanItems
    }

    private let maxVisible = 4
    private let stackPeek: CGFloat = 56
    private let cardCorner: CGFloat = 24

    private var stackCardHeight: CGFloat {
        (ScreenCompat.width - 48) / 1.586
    }

    // visibleItems[0] = active card (front, bottom)
    // visibleItems[1..n] = behind cards (back, peeking from top)
    private var visibleItems: [DeckItem] {
        guard !items.isEmpty else { return [] }
        var result: [DeckItem] = []
        for i in 0..<min(items.count, maxVisible) {
            let idx = (activeIndex + i) % items.count
            result.append(items[idx])
        }
        return result
    }

    private var visibleCount: Int { visibleItems.count }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { depth, item in
                    walletCard(item: item, depth: depth)
                }
            }
            .frame(
                height: stackCardHeight + CGFloat(max(0, visibleCount - 1)) * stackPeek
            )
            .contentShape(Rectangle())
            .highPriorityGesture(flippedPetIds.isEmpty ? stackDragGesture : nil)

            // 分页指示器
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(items.count, 6), id: \.self) { idx in
                        Capsule()
                            .fill(idx == activeIndex ? Color.goPrimary : Color.white.opacity(0.35))
                            .frame(width: idx == activeIndex ? 24 : 7, height: 7)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeIndex)
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            if items.indices.contains(activeIndex) {
                onTopCardChanged?(items[activeIndex])
            }
        }
        .onChange(of: activeIndex) { _, newValue in
            guard items.indices.contains(newValue) else { return }
            flippedPetIds.removeAll()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTopCardChanged?(items[newValue])
        }
    }

    // MARK: - Single Wallet Card
    //
    // 布局：下边的卡片在最前面（zIndex 最高），上边在最后面
    // depth=0 (active) → 最下方 (y最大), zIndex最高, 可交互
    // depth=n (furthest behind) → 最上方 (y=0), zIndex最低, 仅露出名字
    @ViewBuilder
    private func walletCard(item: DeckItem, depth: Int) -> some View {
        let isActive = depth == 0
        // active 在底部，behind 卡片依次在上方
        let yBase = CGFloat(visibleCount - 1 - depth) * stackPeek
        let yOffset = yBase + (isActive ? dragOffset : 0)
        let scale = isActive ? 1.0 : (1.0 - CGFloat(depth) * 0.02)
        let brightness = isActive ? 0.0 : -Double(depth) * 0.05

        Group {
            switch item {
            case .pet(let pet):
                let isFlipped = flippedPetIds.contains(pet.id)
                ZStack {
                    WalletPetCardFront(pet: pet, cornerRadius: cardCorner)
                        .frame(height: stackCardHeight)
                        .opacity(isFlipped ? 0 : 1)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                    WalletPetCardBack(
                        pet: pet,
                        cornerRadius: cardCorner,
                        onShowSettings:     { onShowBackSettings?(pet) },
                        onShowDocuments:    { onShowDocuments?(pet) },
                        onShowMoments:      { onShowMoments?(pet) },
                        onShowAchievements: { onShowAchievements?(pet) },
                        onShowHealth:       { onShowHealth?(pet) },
                        onFlipBack:         { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { _ = flippedPetIds.remove(pet.id) } },
                        onShowCalendar:     { onShowCalendar?(pet) },
                        onShowMedications:  { onShowMedications?(pet) },
                        onShowFood:         { onShowFood?(pet) },
                        onShowEdit:         { onShowEdit?(pet) }
                    )
                    .frame(height: stackCardHeight)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 1 : 0)
                }
                .onTapGesture {
                    guard isActive else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if isFlipped {
                            _ = flippedPetIds.remove(pet.id)
                        } else {
                            flippedPetIds.insert(pet.id)
                        }
                    }
                }
                .matchedTransitionSource(id: pet.id as UUID, in: heroNS) { cfg in
                    cfg.clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
                }

            case .human(let human):
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelectHuman?(human)
                } label: {
                    WalletHumanCardFront(human: human, cornerRadius: cardCorner)
                        .frame(height: stackCardHeight)
                }
                .buttonStyle(.plain)
            }
        }
        // active 卡片 zIndex 最高（在最前面）
        .zIndex(Double(visibleCount - depth))
        .offset(y: yOffset)
        .scaleEffect(scale, anchor: .bottom)
        .brightness(brightness)
        .compositingGroup()
        .shadow(color: .black.opacity(isActive ? 0.35 : 0.15), radius: isActive ? 24 : 12, y: isActive ? 8 : 4)
        .allowsHitTesting(isActive)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: activeIndex)
    }

    // MARK: - Drag to Cycle (highPriorityGesture 避免与页面 ScrollView 冲突)
    private var stackDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                isDragging = true
                let clamped = max(-120, min(120, value.translation.height))
                withAnimation(.interactiveSpring()) {
                    dragOffset = clamped
                }
            }
            .onEnded { value in
                isDragging = false
                let threshold: CGFloat = 50
                if (value.translation.height < -threshold || value.translation.height > threshold) && items.count > 1 {
                    // 上滑 / 下滑 → 当前卡放到最后，显示下一张
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
                        activeIndex = (activeIndex + 1) % items.count
                        dragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Pet Card Front（与 `WalletPetCardDraftFront` 同构：主题渐变 + 全名大字 + 剪影配色/图案）
struct WalletPetCardFront: View {
    let pet: Pet
    let cornerRadius: CGFloat

    private let accent = Color(hex: "FF5A3D")

    private var headlineText: String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return trimmed.uppercased()
    }

    private var footnote: String {
        var parts: [String] = []
        if !pet.ageText.isEmpty { parts.append(pet.ageText) }
        if !pet.breed.isEmpty { parts.append(pet.breed) }
        else if !pet.species.isEmpty { parts.append(pet.species) }
        if parts.isEmpty { parts.append("Ohana PET ID") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let (cardTop, cardBottom) = WalletPetCardTheme.gradientPair(for: pet.themeColorHex)
            let avatarImage: UIImage? = pet.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let hasPopout = isTransparent && avatarImage != nil

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cardTop, cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text(headlineText)
                    .font(.system(size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: headlineText.count), weight: .black, design: .rounded))
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                avatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h, cardTop: cardTop)
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                // ── 右半：信息列
                VStack(alignment: .trailing, spacing: 5) {
                    if pet.currentStreak > 1 {
                        Text("🔥 \(pet.currentStreak)天连续")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.goPrimary, in: Capsule())
                    }

                    Spacer()

                    Text(pet.homeDate == nil ? "—" : "\(pet.daysTogether)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("Days Together")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))

                    Text(footnote)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    barcode
                        .padding(.top, 8)
                }
                .padding(.trailing, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // ── 彩虹桥覆盖
                if pet.hasPassedAway {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.6), Color(hex: pet.themeColorHex).opacity(0.3)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                        
                        VStack(spacing: 8) {
                            Text("✨")
                                .font(.system(size: 32))
                                .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                            Text("化作星星，守护着你")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                            if let d = pet.passedAwayDate {
                                let years = Calendar.current.dateComponents([.year], from: d, to: Date()).year ?? 0
                                Text("相伴 \(pet.daysTogetherAtPassing) 天" + (years > 0 ? " · 离开 \(years) 年" : ""))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Avatar Layer
    @ViewBuilder
    private func avatarLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat, cardTop: Color) -> some View {
        if let img = avatarImage {
            if isTransparent {
                ZStack(alignment: .bottom) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(0.88)
                        .colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
            } else {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.08),
                                .clear,
                                cardTop.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
            }
        } else {
            let species = pet.species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let silSpecies = (species == "dog" || pet.species == "狗") ? "狗" :
                             (species == "cat" || pet.species == "猫") ? "猫" : pet.species
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 10)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: WalletPetCardTheme.silhouetteCoatColor(for: pet),
                    eyeColor: WalletPetCardTheme.silhouetteEyeColor(for: pet),
                    patternName: WalletPetCardTheme.coatPatternName(for: pet),
                    isAnimationEnabled: false
                )
                .scaleEffect(0.92)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Barcode
    private var barcode: some View {
        let pattern: [CGFloat] = [18, 6, 10, 14, 5, 12, 8, 16, 7, 10, 13, 6]
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(.white.opacity(0.95))
                        .frame(width: 2, height: height)
                }
            }
            Text("O H A N A   P E T")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .tracking(1.2)
        }
    }
}

// MARK: - Pet Card Front (Wizard Draft — 与首页 WalletPetCardFront 视觉一致)
/// 添加宠物向导顶部固定预览：数据随表单逐步填充，不依赖 SwiftData `Pet`。
struct WalletPetCardDraftFront: View {
    var name: String
    var species: String
    /// 脚注用品种文案（已解析「其他」+ 自定义）
    var breedFootnote: String
    var avatarImageData: Data?
    /// 父视图异步解码，避免每次重绘时重复 `UIImage(data:)` / 透明检测
    var decodedAvatar: UIImage? = nil
    var decodedAvatarIsTransparent: Bool = false
    var coatColor: Color
    var eyeColor: Color
    var coatPatternName: String?
    var hasBirthday: Bool
    /// 与 `Pet.ageText` 风格一致的一句年龄（空则脚注省略年龄）
    var ageFootnote: String
    var hasHomeDate: Bool
    var daysTogether: Int
    /// 与主题色选择同步的卡面渐变（与 `Pet.themeColorHex` 一致）
    var themeColorHex: String
    let cornerRadius: CGFloat

    private let accent = Color(hex: "FF5A3D")

    private var cardGradientTop: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).0 }
    private var cardGradientBottom: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).1 }

    private var headlineText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return trimmed.uppercased()
    }

    private var footnote: String {
        var parts: [String] = []
        if hasBirthday, !ageFootnote.isEmpty { parts.append(ageFootnote) }
        if !breedFootnote.isEmpty { parts.append(breedFootnote) }
        else if !species.isEmpty { parts.append(species) }
        if parts.isEmpty { parts.append("Ohana PET ID") }
        return parts.joined(separator: " · ")
    }

    private var daysTogetherLabel: String {
        guard hasHomeDate else { return "—" }
        let d = daysTogether
        if d < 0 { return "\(abs(d))" }
        return "\(d)"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = decodedAvatar ?? avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent: Bool = {
                if decodedAvatar != nil { return decodedAvatarIsTransparent }
                return avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            }()
            let hasPopout = isTransparent && avatarImage != nil

            ZStack {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                        SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                        SIMD2(0.0, 1.0), SIMD2(0.5,  1.0), SIMD2(1.0, 1.0)
                    ],
                    colors: WalletPetCardTheme.meshColors(for: themeColorHex)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text(headlineText)
                    .font(.system(size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: headlineText.count), weight: .black, design: .rounded))
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                draftAvatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                VStack(alignment: .trailing, spacing: 5) {
                    Spacer()

                    Text(daysTogetherLabel)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("Days Together")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))

                    Text(footnote)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    draftBarcode
                        .padding(.top, 8)
                }
                .padding(.trailing, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func draftAvatarLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage {
            if isTransparent {
                ZStack(alignment: .bottom) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(0.88)
                        .colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
            } else {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.08),
                                .clear,
                                cardGradientTop.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
            }
        } else {
            let sp = species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let silSpecies = (sp == "dog" || species == "狗") ? "狗" :
                (sp == "cat" || species == "猫") ? "猫" : species
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 10)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: coatColor,
                    eyeColor: eyeColor,
                    patternName: coatPatternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(0.92)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var draftBarcode: some View {
        let pattern: [CGFloat] = [18, 6, 10, 14, 5, 12, 8, 16, 7, 10, 13, 6]
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(.white.opacity(0.95))
                        .frame(width: 2, height: height)
                }
            }
            Text("O H A N A   P E T")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .tracking(1.2)
        }
    }
}

// MARK: - Human Card Front
struct WalletHumanCardFront: View {
    let human: Human
    let cornerRadius: CGFloat

    private let baseBlue = Color(hex: "233BFF")
    private let deepBlue = Color(hex: "141FAE")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [baseBlue, deepBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.goTeal.opacity(0.15))
                    .blendMode(.plusLighter)

                // 大字背景（顶部，堆叠时漏出）
                Text(String(human.name.prefix(4)).uppercased())
                    .font(.system(size: w * 0.22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // 头像
                if let data = human.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: w * 0.48, height: h)
                        .clipped()
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.6),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color.goTeal.opacity(0.5))
                        .frame(width: w * 0.48, height: h)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }

                // 右侧信息
                VStack(alignment: .trailing, spacing: 6) {
                    Spacer()
                    Text(human.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("岛民")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    // 条码
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach([14, 8, 12, 6, 10, 16, 5, 11, 9, 13], id: \.self) { bh in
                            RoundedRectangle(cornerRadius: 1.2)
                                .fill(.white.opacity(0.85))
                                .frame(width: 2, height: CGFloat(bh))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }
}
