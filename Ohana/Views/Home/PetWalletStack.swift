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
        let base = w * 0.24
        if n <= 6 { return base }
        let ratio = 6.0 / Double(n)
        let softened = pow(ratio, 0.82)
        return max(w * 0.074, base * CGFloat(softened))
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

    var onDraggingChanged: ((Bool) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var activeIndex: Int = 0
    @State private var isDragging = false
    /// 顶部卡片空闲时微漂浮（首页简化 · 可爱化）
    @State private var idleBreath: CGFloat = 0

    private var items: [DeckItem] {
        let petItems = pets.map { DeckItem.pet($0) }
        let humanItems = humans.filter { $0.shouldShowOnHome }.map { DeckItem.human($0) }
        return petItems + humanItems
    }

    private let maxVisible = 3
    private let stackPeek: CGFloat = 30
    private let cardCorner: CGFloat = 24

    private var stackCardHeight: CGFloat {
        (ScreenCompat.width - 48) / 1.586
    }

    /// 最多显示 maxVisible 张，超出部分在栈上方（off-screen）待命
    private var visibleCount: Int { min(items.count, maxVisible) }

    /// 相对深度：0 = 最前，maxVisible-1 = 最后可见，>= maxVisible = 隐藏于栈上方
    private func relativeDepth(for index: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        return (index - activeIndex + items.count) % items.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 所有卡片始终在 ZStack 中，depth >= maxVisible 的卡片位于栈上方待命
                // 当 activeIndex 变化时，各卡片通过 relativeDepth 平滑动画到新位置
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let depth = relativeDepth(for: index)
                    walletCard(item: item, depth: depth)
                }
            }
            .frame(
                height: stackCardHeight + CGFloat(max(0, visibleCount - 1)) * stackPeek
            )
            .contentShape(Rectangle())
            .highPriorityGesture(stackDragGesture)

            // 分页指示器：位于最前方卡片正下方
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(items.count, 6), id: \.self) { idx in
                        Capsule()
                            .fill(idx == activeIndex ? Color.goPrimary : Color.white.opacity(0.35))
                            .frame(width: idx == activeIndex ? 24 : 7, height: 7)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeIndex)
                .padding(.top, 22)
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            if items.indices.contains(activeIndex) {
                onTopCardChanged?(items[activeIndex])
            }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                idleBreath = 1
            }
        }
        .onChange(of: activeIndex) { _, newValue in
            guard items.indices.contains(newValue) else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTopCardChanged?(items[newValue])
        }
    }

    // MARK: - Single Wallet Card
    //
    // 布局：下边的卡片在最前面（zIndex 最高），上边在最后面
    // depth=0 (active) → 最下方 (y最大), zIndex最高, 可交互
    // depth=maxVisible-1 (最后可见) → 最上方 (y=0), zIndex最低
    // depth>=maxVisible → 栈上方隐藏区（y<0），opacity=0，动画时充当"飞出"路径
    @ViewBuilder
    private func walletCard(item: DeckItem, depth: Int) -> some View {
        let isActive = depth == 0
        let isVisible = depth < maxVisible
        // active 在底部，behind 卡片依次在上方；超出可见区的卡片继续上移（负 y）
        let yBase = CGFloat(visibleCount - 1 - depth) * stackPeek
        // 顶部卡片在未拖拽时做轻微呼吸漂浮（±3pt, 6s 往返）
        let idleFloat: CGFloat = (isActive && !isDragging) ? idleBreath * 3 : 0
        let yOffset = yBase + (isActive ? dragOffset : 0) + idleFloat
        let scale = isActive ? 1.0 : max(0.85, 1.0 - CGFloat(min(depth, maxVisible)) * 0.02)
        let brightness = isActive ? 0.0 : -Double(min(depth, maxVisible)) * 0.05

        Group {
            switch item {
            case .pet(let pet):
                WalletPetCardFront(pet: pet, cornerRadius: cardCorner)
                    .frame(height: stackCardHeight)
                    .onTapGesture {
                        guard isActive else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSelectPet(pet)
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
        // depth=0 的卡片 zIndex 最高，depth>=maxVisible 的卡片在最底层（不遮挡可见卡）
        .zIndex(Double(items.count - depth))
        .offset(y: yOffset)
        .scaleEffect(scale, anchor: .bottom)
        .brightness(brightness)
        .opacity(isVisible ? 1 : 0)
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
                onDraggingChanged?(true)
                let clamped = max(-120, min(120, value.translation.height))
                withAnimation(.interactiveSpring()) {
                    dragOffset = clamped
                }
            }
            .onEnded { value in
                isDragging = false
                onDraggingChanged?(false)
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

// MARK: - 钱包卡右侧可读性叠层（材质模糊 + 压暗；全幅绘制 + 软 mask，避免中间竖向硬分界）
struct WalletCardTrailingReadabilityOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let width: CGFloat
    let height: CGFloat

    /// 控制叠层从左到右逐渐显现，与照片做长距离柔和过渡（非矩形裁切左缘）
    private var edgeSoftMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.06), location: 0.34),
                .init(color: .white.opacity(0.42), location: 0.48),
                .init(color: .white.opacity(0.88), location: 0.66),
                .init(color: .white, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// 压暗随横向连续加深，最暗在右缘（文案区），左侧与照片自然衔接
    private var darkenGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(reduceTransparency ? 0.12 : 0.06), location: 0.38),
                .init(color: .black.opacity(reduceTransparency ? 0.52 : 0.28), location: 0.72),
                .init(color: .black.opacity(reduceTransparency ? 0.82 : 0.58), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            if reduceTransparency {
                Rectangle()
                    .fill(Color(UIColor.systemBackground).opacity(0.94))
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            Rectangle()
                .fill(darkenGradient)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .mask(edgeSoftMask)
        .allowsHitTesting(false)
    }
}

struct WalletCardAdaptivePhotoLayer: View {
    enum Mode { case compact, expanded }

    let image: UIImage
    let width: CGFloat
    let height: CGFloat
    var mode: Mode = .compact

    var body: some View {
        ZStack(alignment: .leading) {
            if mode == .expanded {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                WalletCardTrailingReadabilityOverlay(width: width, height: height)
                WalletCardBottomRightTextShadow(width: width, height: height, isExpanded: true)
            } else {
                let photoW = compactPhotoRenderedWidth
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoW, height: height)
                    .clipped()
                    .frame(width: width, height: height, alignment: .leading)
                    .saturation(1.04)
                    .contrast(1.02)
                    .mask(WalletCardCompactPhotoMask(width: width, height: height))
                WalletCardBottomRightTextShadow(width: width, height: height, isExpanded: false)
            }
        }
        .allowsHitTesting(false)
    }

    private var compactPhotoRenderedWidth: CGFloat {
        guard image.size.height > 0 else { return width }
        return max(width, height * image.size.width / image.size.height)
    }
}

private struct WalletCardCompactPhotoMask: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.46),
                .init(color: .white.opacity(0.72), location: 0.60),
                .init(color: .white.opacity(0.18), location: 0.76),
                .init(color: .clear, location: 0.92)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width, height: height)
    }
}

private struct WalletCardBottomRightTextShadow: View {
    let width: CGFloat
    let height: CGFloat
    var isExpanded: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(isExpanded ? 0.18 : 0.10), location: 0.38),
                    .init(color: .black.opacity(isExpanded ? 0.44 : 0.32), location: 0.76),
                    .init(color: .black.opacity(isExpanded ? 0.62 : 0.46), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    .black.opacity(isExpanded ? 0.56 : 0.42),
                    .black.opacity(isExpanded ? 0.28 : 0.20),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 8,
                endRadius: min(width, height) * (isExpanded ? 0.78 : 0.66)
            )
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
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
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent

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
                            colors: [.clear, .black.opacity(usesFullBleedPhoto ? 0.12 : 0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )

                if let img = avatarImage, !isTransparent {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                    .allowsHitTesting(false)
                }

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

                if avatarImage == nil || hasPopout {
                    avatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h, cardTop: cardTop)
                        // alignment: .leading → full-card image left-aligns before clip,
                        // so the subject appears at the same size as in the crop frame (WYSIWYG)
                        .frame(width: w * 0.52, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

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
                // Render at full card dimensions so the subject appears at the same
                // size as in the crop-frame (WYSIWYG). The caller clips to w*0.52
                // with .leading alignment, revealing just the left portion.
                // Single image only — a second 88%-scale copy caused a visible ghost.
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    // Subtle white halo preserves the "pop-out" depth cue
                    .shadow(color: .white.opacity(0.50), radius: 3, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 12)
            } else {
                EmptyView()
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
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent

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
                            colors: [.clear, .black.opacity(usesFullBleedPhoto ? 0.12 : 0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )

                if let img = avatarImage, !isTransparent {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                    .allowsHitTesting(false)
                }

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

                if avatarImage == nil || hasPopout {
                    draftAvatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                        .frame(width: w * 0.52, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

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
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .shadow(color: .white.opacity(0.50), radius: 3, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 12)
            } else {
                EmptyView()
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

// MARK: - Human Silhouette

struct HumanSilhouetteView: View {
    let gender: String
    var accent: Color = .white.opacity(0.8)

    private var isFemale: Bool {
        gender == "女" || gender.lowercased().contains("female")
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w * 0.5
            let head = min(w, h) * 0.26
            let bodyTop = h * 0.43

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: w * 0.56, height: h * 0.08)
                    .blur(radius: 7)
                    .position(x: cx, y: h * 0.91)

                if isFemale {
                    RoundedRectangle(cornerRadius: head * 0.42, style: .continuous)
                        .fill(accent.mix(with: .black, by: 0.22))
                        .frame(width: head * 1.2, height: head * 1.32)
                        .position(x: cx, y: h * 0.25)
                }

                Circle()
                    .fill(accent)
                    .frame(width: head, height: head)
                    .position(x: cx, y: h * 0.24)

                Capsule()
                    .fill(accent.opacity(0.92))
                    .frame(width: w * 0.16, height: h * 0.19)
                    .rotationEffect(.degrees(20))
                    .position(x: w * 0.3, y: h * 0.61)

                Capsule()
                    .fill(accent.opacity(0.92))
                    .frame(width: w * 0.16, height: h * 0.19)
                    .rotationEffect(.degrees(-20))
                    .position(x: w * 0.7, y: h * 0.61)

                if isFemale {
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.34, y: bodyTop))
                        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: bodyTop), control: CGPoint(x: cx, y: h * 0.36))
                        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.82))
                        path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.82), control: CGPoint(x: cx, y: h * 0.9))
                        path.closeSubpath()
                    }
                    .fill(accent)
                } else {
                    RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                        .fill(accent)
                        .frame(width: w * 0.46, height: h * 0.42)
                        .position(x: cx, y: h * 0.63)
                }

                Capsule()
                    .fill(accent.mix(with: .black, by: 0.1))
                    .frame(width: w * 0.16, height: h * 0.28)
                    .position(x: w * 0.42, y: h * 0.83)

                Capsule()
                    .fill(accent.mix(with: .black, by: 0.1))
                    .frame(width: w * 0.16, height: h * 0.28)
                    .position(x: w * 0.58, y: h * 0.83)
            }
            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 8)
        }
        .aspectRatio(0.72, contentMode: .fit)
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

            // ── 透明度检测（与 WalletPetCardFront 完全一致）
            let avatarImage: UIImage? = human.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent = human.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let hasPopout = isTransparent && avatarImage != nil
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent

            ZStack {
                // Layer 1 — 背景渐变
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [baseBlue, deepBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                // Layer 2 — teal 叠色
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.goTeal.opacity(0.15))
                    .blendMode(.plusLighter)

                // Layer 3 — 非透明头像：全幅铺满，右侧材质保证文案可读
                if usesFullBleedPhoto, let img = avatarImage {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                    .allowsHitTesting(false)
                }

                // Layer 4 — 大字背景（与宠物卡一致：在全幅照片之上、抠图主体之下）
                // 全幅照片模式下作为半透明水印；抠图模式下透过主体透明区域可见。
                Text(String(human.name.prefix(4)).uppercased())
                    .font(.system(size: w * 0.22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(usesFullBleedPhoto ? 0.28 : 0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                // Layer 5 — 透明抠图主体（pop-out）或无头像剪影
                if hasPopout || avatarImage == nil {
                    humanAvatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                        .frame(width: w * 0.48, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                // Layer 6 — 右侧信息列
                VStack(alignment: .trailing, spacing: 6) {
                    Spacer()
                    Text(human.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(L10n.current.humanWalletResident)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    let mbtiTrim = human.mbti.trimmingCharacters(in: .whitespaces)
                    let isEn = AppLanguage.isEnglish
                    let hasAgeOrZodiac = human.walletAgeChip(isEnglish: isEn) != nil || human.birthday != nil
                    let hasMbti = !mbtiTrim.isEmpty
                    if hasAgeOrZodiac || hasMbti {
                        HStack(spacing: 6) {
                            if let age = human.walletAgeChip(isEnglish: isEn) {
                                Text(age)
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                            }
                            if let b = human.birthday {
                                Text(Human.westernZodiacDisplay(for: b, isEnglish: isEn))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                            }
                            if hasMbti {
                                Text(mbtiTrim.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                            }
                        }
                    }
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

    @ViewBuilder
    private func humanAvatarLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage, isTransparent {
            // 全卡尺寸渲染，调用侧裁剪左 48%，与裁剪框 WYSIWYG 一致
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .shadow(color: .white.opacity(0.50), radius: 3, x: 0, y: 0)
                .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 12)
        } else if avatarImage == nil {
            HumanSilhouetteView(gender: human.genderRaw, accent: Color.goTeal.opacity(0.72))
                .scaleEffect(0.88)
                .frame(width: w * 0.42, height: h * 0.74)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, w * 0.06)
        }
    }
}

// MARK: - Human Card Front (Wizard Draft — 与 `WalletHumanCardFront` 同构)
/// 添加家庭成员向导顶部固定预览：与宠物 `WalletPetCardDraftFront` 相同比例与层次。
struct WalletHumanCardDraftFront: View {
    var name: String
    var gender: String
    var avatarImageData: Data?
    var decodedAvatar: UIImage?
    var decodedAvatarTransparent: Bool
    var themeColorHex: String
    /// 阳历星座（有生日时由父视图传入）
    var zodiacText: String? = nil
    /// MBTI（可选，由父视图传入）
    var mbtiText: String? = nil
    /// 卡面底部一句摘要（关系 / 国籍 / 现居地 / 年龄等，由父视图拼好）
    var subtitle: String
    let cornerRadius: CGFloat

    private var gradientTop: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).0 }
    private var gradientBottom: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).1 }

    private var headline: String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "OHANA" }
        return t.uppercased()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = decodedAvatar ?? avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent: Bool = {
                if decodedAvatar != nil { return decodedAvatarTransparent }
                return avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            }()
            let hasPopout = isTransparent && avatarImage != nil
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [gradientTop, gradientBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.goTeal.opacity(0.12))
                    .blendMode(.plusLighter)

                Text(String(name.prefix(4)).uppercased())
                    .font(.system(size: w * 0.2, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let img = avatarImage, usesFullBleedPhoto {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                    .allowsHitTesting(false)
                }

                if avatarImage == nil || hasPopout {
                    draftHumanAvatar(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                        .frame(width: w * 0.48, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                VStack(alignment: .trailing, spacing: 6) {
                    Spacer()
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.current.humanWalletNewMember : name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(L10n.current.humanWalletResident)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                    if (zodiacText?.isEmpty == false) || (mbtiText?.isEmpty == false) {
                        HStack(spacing: 6) {
                            if let zodiacText, !zodiacText.isEmpty {
                                Text(zodiacText)
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                            }
                            if let mbtiText, !mbtiText.isEmpty {
                                Text(mbtiText.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                            }
                        }
                    }
                    Text(subtitle.isEmpty ? L10n.current.humanWalletSubtitlePlaceholder : subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.75)
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

    @ViewBuilder
    private func draftHumanAvatar(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage {
            if isTransparent {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .shadow(color: .white.opacity(0.50), radius: 3, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 12)
            } else {
                EmptyView()
            }
        } else {
            HumanSilhouetteView(gender: gender, accent: .white.opacity(0.76))
                .scaleEffect(0.9)
                .frame(width: w * 0.34, height: h * 0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.leading, w * 0.07)
        }
    }
}
