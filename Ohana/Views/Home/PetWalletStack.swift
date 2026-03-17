//
//  PetWalletStack.swift
//  Ohana
//
//  iOS Wallet 堆叠 + App Store Today 展开动效
//  使用 matchedTransitionSource + navigationTransition(.zoom) 实现原生英雄过渡
//

import SwiftUI
import SwiftData

// MARK: - Wallet Stack Container
struct PetWalletStack: View {
    let pets: [Pet]
    let humans: [Human]
    var heroNS: Namespace.ID
    var onSelectPet: (Pet) -> Void
    var onSelectHuman: ((Human) -> Void)? = nil
    var onTopCardChanged: ((DeckItem) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var activeIndex: Int = 0
    @State private var isDragging = false

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
            .highPriorityGesture(stackDragGesture)

            // 分页指示器
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(items.count, 6), id: \.self) { idx in
                        Capsule()
                            .fill(idx == activeIndex ? Color.goLime : Color.white.opacity(0.35))
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
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelectPet(pet)
                } label: {
                    WalletPetCardFront(pet: pet, cornerRadius: cardCorner)
                        .frame(height: stackCardHeight)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: pet.id, in: heroNS) { cfg in
                    cfg
                        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
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

// MARK: - Pet Card Front (GO Poster Style)
struct WalletPetCardFront: View {
    let pet: Pet
    let cornerRadius: CGFloat

    private let baseBlue  = Color(hex: "233BFF")
    private let deepBlue  = Color(hex: "141FAE")
    private let accent    = Color(hex: "FF5A3D")

    private var headline: String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return String(trimmed.prefix(6)).uppercased()
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
            let avatarImage: UIImage? = pet.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let hasPopout = isTransparent && avatarImage != nil

            ZStack {
                // ── 背景渐变（GO UI 蓝）
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [baseBlue, deepBlue],
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

                // ── 背景大字（橙色，锚定到卡片顶部——堆叠时漏出的区域）
                Text(headline)
                    .font(.system(size: w * 0.28, weight: .black, design: .rounded))
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                // ── 左半：头像主体层
                avatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
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
                            .background(Color.goLime, in: Capsule())
                    }

                    Spacer()

                    Text("\(pet.daysTogether)")
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
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.black.opacity(0.3))
                    VStack(spacing: 4) {
                        Text("🌈")
                            .font(.system(size: 28))
                        Text("永远的家人")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
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
    private func avatarLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
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
                                baseBlue.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
            }
        } else {
            // 无头像剪影
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
                    coatColor: pet.coatColor.isEmpty ? Color(hex: "E8C49A") : Color(hex: pet.coatColor),
                    eyeColor: pet.eyeColor.isEmpty ? Color(hex: "6B3A2A") : Color(hex: pet.eyeColor)
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
