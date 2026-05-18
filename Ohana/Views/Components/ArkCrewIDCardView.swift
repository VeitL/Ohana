//
//  ArkCrewIDCardView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Charts

struct ArkCrewIDCardView: View {
    let pet: Pet
    let onDetail: () -> Void
    /// 可选的外部翻转状态绑定；不传则内部自管理
    var isFlipped: Binding<Bool>? = nil
    /// 外部健康页跳转回调（C3：避免 NavigationStack push 死锁）
    var onShowHealth: (() -> Void)? = nil
    /// 背面各区域点击回调 (可选)
    var onTapWeightStat: (() -> Void)? = nil
    var onTapWalkStat: (() -> Void)? = nil
    var onTapHealthStat: (() -> Void)? = nil
    var onTapDocStat: (() -> Void)? = nil
    
    @State private var _isFlipped = false
    @State private var glowFlash = false
    @State private var cardScale: CGFloat = 1.0
    @State private var cardRotation: Double = 0
    @State private var showWalkSummaryPanel = false

    @AppStorage("appLanguage") private var appLanguage = "zh"
    private var l: L10n { L10n(appLanguage) }

    private var flipped: Bool {
        isFlipped?.wrappedValue ?? _isFlipped
    }
    
    private func toggleFlip() {
        if let binding = isFlipped {
            binding.wrappedValue.toggle()
        } else {
            _isFlipped.toggle()
        }
    }

    private func setFlipped(_ value: Bool) {
        if let binding = isFlipped {
            binding.wrappedValue = value
        } else {
            _isFlipped = value
        }
    }
    
    var body: some View {
        ZStack {
            cardFrontView
                .opacity(cardRotation < 90 ? 1 : 0)
            cardBackView
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(cardRotation >= 90 ? 1 : 0)
        }
        .frame(width: ScreenCompat.width - 48, height: (ScreenCompat.width - 48) / 1.586)
        .compositingGroup()
        .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.16)
        .shadow(color: glowFlash ? Color.goPrimary.opacity(0.8) : Color.arkInk.opacity(0.15), // ui-v4: allow ID card hero elevation
                radius: glowFlash ? 20 : 24, x: 0, y: glowFlash ? 0 : 12)
        .scaleEffect(cardScale)
        .animation(GoMotion.stateChange, value: glowFlash)
        .onChange(of: flipped) { _, newFlipped in
            withAnimation(GoMotion.page) {
                cardRotation = newFlipped ? 180 : 0
            }
        }
        .onChange(of: PetWalkingManager.shared.phase) { _, newPhase in
            if case .finished = newPhase,
               PetWalkingManager.shared.currentPet?.id == pet.id {
                showWalkSummaryPanel = true
                setFlipped(true)
            } else if case .idle = newPhase {
                showWalkSummaryPanel = false
            }
        }
        .onAppear { cardRotation = flipped ? 180 : 0 }
    }
    
    // Card theme color based on pet's themeColorHex
    private var cardThemeColor: Color {
        pet.themeColorHex.isEmpty ? Color.goCardBlue : Color(hex: pet.themeColorHex)
    }
    private var cardTextColor: Color {
        // light colors need dark text
        let bright = ["C8FF00","E8FFB0","B8FFD0","FFF44F","FFEB3B","FFFFFF"]
        return bright.contains(pet.themeColorHex.uppercased()) ? Color.arkInk : Color.ohanaPrimaryText
    }

    // MARK: - Card Front (Dynamic Visual Strategy)
    private var cardFrontView: some View {
        GeometryReader { geo in
            let avatarImage: UIImage? = pet.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent: Bool = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let isPopout = pet.cardStyleRaw == "popout" && isTransparent && avatarImage != nil
            let isMinimal = pet.cardStyleRaw == "minimal"

            ZStack {
                if isMinimal {
                    minimalFront(geo: geo, avatarImage: avatarImage)
                } else {
                    posterFront(
                        geo: geo,
                        avatarImage: avatarImage,
                        isTransparent: isPopout
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .simultaneousGesture(TapGesture().onEnded { toggleFlip() })
        .shadow(color: pet.hasPassedAway ? Color.purple.opacity(0.35) : cardThemeColor.opacity(0.45), // ui-v4: allow ID card artwork elevation
                radius: 24, x: 0, y: 8)
        .shadow(color: Color.arkInk.opacity(0.28), radius: 40, x: 0, y: 16) // ui-v4: allow ID card artwork elevation
        .shadow(color: Color.arkInk.opacity(0.10), radius: 80, x: 0, y: 32) // ui-v4: allow ID card artwork elevation
    }

    private func posterFront(geo: GeometryProxy, avatarImage: UIImage?, isTransparent: Bool) -> some View {
        let baseBlue = Color(hex: "233BFF")
        let deepBlue = Color(hex: "141FAE")
        let accent = Color(hex: "FF5A3D")
        let w = geo.size.width
        let h = geo.size.height
        return ZStack {
            // 背景渐变
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [baseBlue, deepBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.arkInk.opacity(0.22)], // ui-v4: allow hero readability scrim
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 背景大字 — 卡片上半部分居中
            Text(posterHeadline)
                .font(.system(size: w * 0.28, weight: .black, design: .rounded))
                .foregroundStyle(accent.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.25)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(y: -h * 0.22)
                .allowsHitTesting(false)

            // 左半：头像主体层，贴左/上/下边缘
            posterSubjectLayer(geo: geo, avatarImage: avatarImage, isTransparent: isTransparent)
                .frame(width: w * 0.52, height: h)
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // 右半：文字信息列
            VStack(alignment: .trailing, spacing: 5) {
                if pet.currentStreak > 1 {
                    Text(l.petCardStreak(pet.currentStreak))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.goPrimary, in: Capsule())
                }

                Spacer()

                Text("\(pet.daysTogether)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(cardTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(l.petCardDaysTogetherCaption)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(cardTextColor.opacity(0.92))

                Text(posterFootnote)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(cardTextColor.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                posterBarcode
                    .padding(.top, 8)
            }
            .padding(.trailing, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // 翻转提示 & 彩虹桥
            flipHint
            if pet.hasPassedAway { rainbowBridgeFrontOverlay(geo: geo) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .topTrailing) { posterDetailButton }
    }

    @ViewBuilder
    private func posterSubjectLayer(geo: GeometryProxy, avatarImage: UIImage?, isTransparent: Bool) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        if let avatarImage {
            if isTransparent {
                // 透明抠图：居左贴边
                ZStack(alignment: .bottom) {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(0.88)
                        .colorMultiply(Color.ohanaCardSurface) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: 2, y: 0) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: -2, y: 0) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: 0, y: -2) // ui-v4: allow avatar sticker cutout highlight
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: Color.arkInk.opacity(0.28), radius: 18, x: 0, y: 12) // ui-v4: allow avatar grounding
            } else {
                // 普通照片：填满左半区域，右侧羽化
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: Color.arkInk, location: 0.0), // ui-v4: allow image alpha mask
                                .init(color: Color.arkInk, location: 0.65), // ui-v4: allow image alpha mask
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.ohanaCardSurface.opacity(0.08), // ui-v4: allow image highlight wash
                                .clear,
                                cardThemeColor.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
            }
        } else {
            // 无头像：剪影居中
            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.16))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 10)
                    .offset(y: h * 0.14)

                PetSilhouetteView(
                    species: silhouetteSpecies,
                    coatColor: pet.coatColor.isEmpty ? Color(hex: "E8C49A") : Color(hex: pet.coatColor),
                    eyeColor: pet.eyeColor.isEmpty ? Color(hex: "6B3A2A") : Color(hex: pet.eyeColor)
                )
                .scaleEffect(0.92)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var posterHeadline: String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return String(trimmed.prefix(6)).uppercased()
    }

    private var posterFootnote: String {
        var parts: [String] = []
        if !pet.ageText.isEmpty { parts.append(pet.ageText) }
        if !pet.breed.isEmpty { parts.append(pet.breed) }
        else if !pet.species.isEmpty { parts.append(pet.species) }
        if parts.isEmpty { parts.append("Ohana PET ID") }
        return parts.joined(separator: " · ")
    }

    private var silhouetteSpecies: String {
        let value = pet.species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "dog" || pet.species == "狗" { return "狗" }
        if value == "cat" || pet.species == "猫" { return "猫" }
        return pet.species
    }

    private var posterDetailButton: some View {
        Button(action: onDetail) {
            HStack(spacing: 4) {
                Text(l.petCardDetail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(cardTextColor.opacity(0.95))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(cardTextColor.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(cardTextColor.opacity(0.2), lineWidth: 0.8)
            )
        }
        .padding(.top, 18)
        .padding(.trailing, 16)
    }

    private var posterBarcode: some View {
        let pattern: [CGFloat] = [18, 6, 10, 14, 5, 12, 8, 16, 7, 10, 13, 6]
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(cardTextColor.opacity(0.95))
                        .frame(width: 2, height: height)
                }
            }
            Text("O H A N A   P E T")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(cardTextColor.opacity(0.82))
                .tracking(1.2)
        }
    }

    // MARK: - 简约风格正面
    private func minimalFront(geo: GeometryProxy, avatarImage: UIImage?) -> some View {
        let tc = cardTextColor
        return ZStack {
            // 底层：纯主题色渐变
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(
                    colors: [cardThemeColor, cardThemeColor.mix(with: Color.arkInk, by: 0.35)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // 噪点质感光斑
            Ellipse()
                .fill(RadialGradient(
                    colors: [tc.opacity(0.15), .clear],
                    center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 220, height: 160)
                .offset(x: -geo.size.width * 0.18, y: -geo.size.height * 0.22)
                .allowsHitTesting(false)

            // 品牌水印
            Text("OHANA")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(tc.opacity(0.04))
                .rotationEffect(.degrees(-12))
                .offset(x: geo.size.width * 0.08, y: -geo.size.height * 0.05)
                .allowsHitTesting(false)

            // 居中头像
            VStack(spacing: 0) {
                Spacer()
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.height * 0.52, height: geo.size.height * 0.52)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(tc.opacity(0.25), lineWidth: 2))
                        .shadow(color: Color.arkInk.opacity(0.2), radius: 12, x: 0, y: 6) // ui-v4: allow avatar grounding
                } else {
                    Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                        .font(.system(size: geo.size.height * 0.30))
                }
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // 底部信息条
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pet.name)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(tc)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        // 物种性别已隐藏（数据内存在，但正面不展示）
                    }
                    Spacer()
                    if pet.daysTogether > 0 {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(pet.daysTogether)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(tc)
                            Text(l.petCardDayUnit)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(tc.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.arkInk.opacity(0.20), in: RoundedRectangle(cornerRadius: 0))
                .background(
                    LinearGradient(colors: [.clear, Color.arkInk.opacity(0.30)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }

            flipHint
            if pet.hasPassedAway { rainbowBridgeFrontOverlay(geo: geo) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .topTrailing) { detailButton }
    }

    private func minimalPill(_ text: String, tc: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(tc.opacity(0.8))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(tc.opacity(0.15), in: Capsule())
    }

    // MARK: - 方案三：破框悬浮（透明抠图）
    private func cutoutFloatFront(geo: GeometryProxy, uiImage: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            // ── 层1：主色深底 + 渐变
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(cardThemeColor.mix(with: Color.arkInk, by: 0.30))
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardThemeColor.opacity(0.85),
                            cardThemeColor.mix(with: Color.arkInk, by: 0.45).opacity(0.95)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )

            // ── 层2：右上高光光斑
            Ellipse()
                .fill(RadialGradient(
                    colors: [cardTextColor.opacity(0.18), cardTextColor.opacity(0)],
                    center: .center, startRadius: 0, endRadius: 160))
                .frame(width: 300, height: 220)
                .offset(x: geo.size.width * 0.15, y: -geo.size.height * 0.25)
                .allowsHitTesting(false)

            // ── 层3：品牌水印
            Text("OHANA")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(cardTextColor.opacity(0.035))
                .rotationEffect(.degrees(-12))
                .offset(x: geo.size.width * 0.08, y: -geo.size.height * 0.05)
                .allowsHitTesting(false)

            // ── 层4：右侧信息（在 clipShape 内）
            HStack(alignment: .bottom, spacing: 0) {
                // 左侧空间留给破框图片
                Spacer()
                    .frame(width: geo.size.width * 0.50)
                // 右侧信息
                infoColumn(geo: geo)
            }

            // ── 翻转提示
            flipHint

            // ── 离世遮罩
            if pet.hasPassedAway {
                rainbowBridgeFrontOverlay(geo: geo)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        // ── 破框层：在 clipShape 之外叠加，允许图片向上溢出
        .overlay(alignment: .bottomLeading) {
            ZStack(alignment: .bottom) {
                // 底部地面光晕
                Ellipse()
                    .fill(RadialGradient(
                        colors: [cardThemeColor.opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 36)
                    .blur(radius: 10)
                    .offset(y: 8)

                // 宠物抠图：贴纸白边 + 向上溢出 20pt
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit()
                        .scaleEffect(1.06)
                        .colorMultiply(Color.ohanaCardSurface) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: 2,  y: 0) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: -2, y: 0) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: 0,  y: 2) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 0, x: 0,  y: -2) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 1, x: 2,  y: 2) // ui-v4: allow avatar sticker cutout highlight
                        .shadow(color: Color.ohanaCardSurface, radius: 1, x: -2, y: -2) // ui-v4: allow avatar sticker cutout highlight
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit()
                }
                .frame(width: geo.size.width * 0.52, height: geo.size.height * 1.05)
                .shadow(color: Color.arkInk.opacity(0.15), radius: 10, x: 0, y: 5) // ui-v4: allow avatar grounding
                .offset(y: -20)   // 破框向上溢出
            }
            .frame(width: geo.size.width * 0.52, alignment: .bottom)
            .allowsHitTesting(false)
        }
        // 悬浮详情按钮
        .overlay(alignment: .topTrailing) { detailButton }
    }

    // MARK: - 方案四：动态高斯模糊背景（普通照片）
    private func blurBackgroundFront(geo: GeometryProxy, uiImage: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            // ── 层1：模糊底层（Apple Music 风格）
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .blur(radius: 40)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            // ── 层2：深色蒙版保证文字可读
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.arkInk.opacity(0.28),
                            Color.arkInk.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // ── 层3：ultraThinMaterial 进一步柔化
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.ohanaCardSurface.opacity(0.35))

            // ── 层4：品牌水印
            Text("OHANA")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaCardSurface.opacity(0.04)) // ui-v4: allow poster watermark
                .rotationEffect(.degrees(-12))
                .offset(x: geo.size.width * 0.08, y: -geo.size.height * 0.05)
                .allowsHitTesting(false)

            // ── 层5：左侧原图（右边缘向右渐变消融）
            // 注意：使用 overlay 叠加渐变蒙版而非 .mask，避免 .mask 在 iOS 上引发花屏条纹渲染故障
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width * 0.62, height: geo.size.height)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.45),
                            .init(color: Color.arkInk.opacity(0.5), location: 0.70), // ui-v4: allow image alpha mask
                            .init(color: Color.arkInk, location: 1.0) // ui-v4: allow image alpha mask
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.destinationOut)
                )
                .compositingGroup()
                .allowsHitTesting(false)

            // ── 层6：右侧信息
            HStack(alignment: .bottom, spacing: 0) {
                Spacer().frame(width: geo.size.width * 0.46)
                infoColumn(geo: geo, textColor: Color.ohanaPrimaryText)
            }

            // ── 翻转提示
            flipHint

            // ── 离世遮罩
            if pet.hasPassedAway {
                rainbowBridgeFrontOverlay(geo: geo)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .topTrailing) { detailButton }
    }

    // MARK: - fallback：纯色 + emoji（大幅升级）
    private func emojiFallbackFront(geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            // 层 1: 主色深底
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(cardThemeColor.mix(with: Color.arkInk, by: 0.30))

            // 层 2: 对角渐变 - 左上亮、右下深
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        cardThemeColor.opacity(0.9),
                        cardThemeColor.mix(with: Color.arkInk, by: 0.55).opacity(0.95)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            // 层 3: 右上角高光光斑
            Ellipse()
                .fill(RadialGradient(
                    colors: [cardTextColor.opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 180)
                .offset(x: geo.size.width * 0.22, y: -geo.size.height * 0.28)
                .allowsHitTesting(false)

            // 层 4: 左下角暗角光斑
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color.arkInk.opacity(0.35), .clear],
                    center: .center, startRadius: 0, endRadius: 100))
                .frame(width: 200, height: 150)
                .offset(x: -geo.size.width * 0.20, y: geo.size.height * 0.25)
                .allowsHitTesting(false)

            // 层 5: 旋转装饰圆 (类似苹果卡片马赛克圈面)
            Circle()
                .strokeBorder(cardTextColor.opacity(0.06), lineWidth: 44)
                .frame(width: 220)
                .offset(x: -geo.size.width * 0.28, y: geo.size.height * 0.15)
                .allowsHitTesting(false)

            Circle()
                .strokeBorder(cardTextColor.opacity(0.04), lineWidth: 28)
                .frame(width: 160)
                .offset(x: geo.size.width * 0.30, y: -geo.size.height * 0.1)
                .allowsHitTesting(false)

            // 层 6: 品牌水印
            Text("OHANA")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(cardTextColor.opacity(0.04))
                .rotationEffect(.degrees(-12))
                .offset(x: geo.size.width * 0.05, y: -geo.size.height * 0.06)
                .allowsHitTesting(false)

            // 层 7: 左侧 emoji 主角 - 加大、加轻微阴影让它“浮”起来
            Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                .font(.system(size: geo.size.height * 0.60))
                .minimumScaleFactor(0.4)
                .shadow(color: Color.arkInk.opacity(0.25), radius: 16, x: 4, y: 8) // ui-v4: allow emoji avatar grounding
                .frame(width: geo.size.width * 0.52, height: geo.size.height * 0.92, alignment: .center)
                .allowsHitTesting(false)

            // 层 8: 右侧信息列
            HStack(alignment: .bottom, spacing: 0) {
                Spacer().frame(width: geo.size.width * 0.50)
                infoColumn(geo: geo)
            }


            flipHint
            if pet.hasPassedAway { rainbowBridgeFrontOverlay(geo: geo) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .topTrailing) { detailButton }
    }

    // MARK: - 共享右侧信息列
    private func infoColumn(geo: GeometryProxy, textColor: Color? = nil) -> some View {
        let tc = textColor ?? cardTextColor
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)

            // 相伴天数 — "一起度过了xx天"
            if pet.daysTogether > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(l.petCardTogetherPrefix)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tc.opacity(0.55))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(pet.daysTogether)")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(tc)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(l.petCardDayUnit)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(tc.opacity(0.6))
                    }
                }
                .padding(.bottom, 8)
            }

            // 大名字
            Text(pet.name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(tc)
                .lineLimit(1).minimumScaleFactor(0.45)
                .padding(.bottom, 7)

            // 年龄 / streak
            let humanAge = pet.humanEquivalentAge
            if humanAge > 0 {
                frontPillScalable(humanAgeLabel(pet: pet, humanAge: humanAge), textColor: tc)
                    .padding(.bottom, pet.currentStreak > 1 ? 5 : 10)
            } else if !pet.ageText.isEmpty {
                frontPillScalable(pet.ageText, textColor: tc)
                    .padding(.bottom, pet.currentStreak > 1 ? 5 : 10)
            }

            // 连续打卡 streak
            if pet.currentStreak > 1 {
                Text(l.petCardStreak(pet.currentStreak))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.goPrimary.opacity(0.15), in: Capsule())
                    .padding(.bottom, 10)
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
        .frame(width: geo.size.width * 0.48, alignment: .trailing)
    }

    // MARK: - 共享子组件
    private var detailButton: some View {
        Button(action: onDetail) {
            HStack(spacing: 4) {
                Text(l.petCardDetail).font(.system(size: 11, weight: .bold, design: .rounded))
                Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(cardTextColor.opacity(0.85))
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(cardTextColor.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(cardTextColor.opacity(0.2), lineWidth: 0.5))
        }
        .padding(.top, 18).padding(.trailing, 16)
    }

    private var flipHint: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(cardTextColor.opacity(0.35))
                    .padding(.leading, 18).padding(.bottom, 14)
                    .allowsHitTesting(false)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func rainbowBridgeFrontOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            // 星空蒙版
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.arkInk.opacity(0.65), Color(hex: pet.themeColorHex).opacity(0.35)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 36))
                    .shadow(color: Color.ohanaCardSurface.opacity(0.8), radius: 10, x: 0, y: 0) // ui-v4: allow memorial star glow
                Text(l.petCardRainbowTitle)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.95))
                if let d = pet.passedAwayDate {
                    let years = Calendar.current.dateComponents([.year], from: d, to: Date()).year ?? 0
                    Text(d.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.petCardRainbowTogether(days: pet.daysTogetherAtPassing, yearsApart: years))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func frontPill(_ text: String, textColor: Color? = nil) -> some View {
        let tc = textColor ?? cardTextColor
        return Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tc.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(tc.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tc.opacity(0.15), lineWidth: 0.5))
    }

    /// 支持缩小的胶囊（用于人类等效年龄，防止文字拥挤）
    private func frontPillScalable(_ text: String, textColor: Color? = nil) -> some View {
        let tc = textColor ?? cardTextColor
        return Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tc.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(tc.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tc.opacity(0.15), lineWidth: 0.5))
    }

    /// 带宠物自然年龄前缀的情感称号，区分性别
    private func humanAgeLabel(pet: Pet, humanAge: Int) -> String {
        let petAge = pet.ageText  // e.g. "1岁" / "3岁"
        let isFemale = pet.gender == "female"
        let prefix = petAge.isEmpty ? "" : "\(petAge) | "
        return prefix + l.petCardHumanEquivBody(humanAge: humanAge, isFemale: isFemale)
    }
    
    private func goStatPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.ohanaControlFill, in: Capsule())
    }
    
    // MARK: - Walk Live Panel (背面遛狗中替换内容)
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var cardHouseholds: [Household]

    private var isActiveWalk: Bool {
        let mgr = PetWalkingManager.shared
        guard case .running = mgr.phase else {
            if case .paused = mgr.phase { return mgr.currentPet?.id == pet.id }
            return false
        }
        return mgr.currentPet?.id == pet.id
    }

    @ViewBuilder
    private var walkLivePanel: some View {
        let mgr = PetWalkingManager.shared
        VStack(spacing: 0) {
            // 顶部标题
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                    Text(l.petCardWalkPatrolling)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                // 实时计时器
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(formatElapsed(mgr.elapsedTime))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.goPrimary)
                }
            }
            .padding(.horizontal, 24).padding(.top, 22)

            GoDashedDivider().padding(.horizontal, 24).padding(.top, 10)

            // 距离 + 便便数
            HStack(spacing: 0) {
                walkStatCell(
                    value: String(format: "%.2f", LocationManager.shared.totalDistance / 1000),
                    unit: "km", label: l.petCardWalkDistanceLabel, accent: .goTeal)
                Divider().frame(height: 36).opacity(0.15)
                walkStatCell(
                    value: "\(mgr.poopCount)",
                    unit: "💩", label: l.petCardWalkPoopLabel, accent: .goYellow)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)

            GoDashedDivider().padding(.horizontal, 24)

            // 控制按钮行
            HStack(spacing: 12) {
                // 暂停 / 继续
                if case .running = mgr.phase {
                    Button {
                        mgr.pause()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(l.petCardPause, systemImage: "pause.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.goYellow, in: RoundedRectangle(cornerRadius: 14))
                    }
                } else if case .paused = mgr.phase {
                    Button {
                        mgr.resume()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(l.petCardResume, systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.goTeal, in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                // 停止
                Button {
                    mgr.stop(modelContext: modelContext, household: cardHouseholds.first)
                    showWalkSummaryPanel = true
                    setFlipped(true)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    Label(l.petCardEndWalk, systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.goRed, in: RoundedRectangle(cornerRadius: 14))
                }

                // 便便 +1
                Button {
                    mgr.addPoop()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("💩")
                        .font(.system(size: 20))
                        .frame(width: 46, height: 46)
                        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20).padding(.vertical, 12)

            Spacer(minLength: 0)
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func walkStatCell(value: String, unit: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(unit)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var walkSummaryPanel: some View {
        let elapsed = walkSummaryElapsed
        let distance = walkSummaryDistance
        let poop = walkSummaryPoopCount
        let coconuts = walkSummaryCoconuts

        return ZStack {
            LinearGradient(
                colors: [Color(hex: "12264A"), Color(hex: "07111F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.goPrimary.opacity(0.16))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("遛狗完成")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                        Text("\(pet.name) 到家啦")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button { closeWalkSummaryPanel() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("关闭遛狗总结")
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                HStack(spacing: 8) {
                    walkSummaryStatCell(value: formatElapsed(elapsed), label: "时长", accent: .goPrimary)
                    walkSummaryStatCell(value: walkSummaryDistanceText(distance), label: "距离", accent: .goTeal)
                    walkSummaryStatCell(value: "\(poop)次", label: "便便", accent: .goYellow)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                HStack(spacing: 10) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.goBlue)
                        .frame(width: 30, height: 30)
                        .background(Color.goBlue.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("本次记录已保存")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(coconuts > 0 ? "奖励 +\(coconuts)🥥 已入账" : "距离不足 20m，保留记录不发奖励")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer(minLength: 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func walkSummaryStatCell(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var latestWalkSummaryLog: PetWalkLog? {
        pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
    }

    private var walkSummaryElapsed: TimeInterval {
        if case .finished(let elapsed, _) = PetWalkingManager.shared.phase,
           PetWalkingManager.shared.currentPet?.id == pet.id {
            return elapsed
        }
        return latestWalkSummaryLog?.durationSeconds ?? 0
    }

    private var walkSummaryDistance: Double {
        if let log = latestWalkSummaryLog, log.distanceMeters > 0 {
            return log.distanceMeters
        }
        return LocationManager.shared.totalDistance
    }

    private var walkSummaryPoopCount: Int {
        if case .finished(_, let poopCount) = PetWalkingManager.shared.phase,
           PetWalkingManager.shared.currentPet?.id == pet.id {
            return poopCount
        }
        return PetWalkingManager.shared.poopCount
    }

    private var walkSummaryCoconuts: Int {
        latestWalkSummaryLog?.coconutsEarned ?? 0
    }

    private func walkSummaryDistanceText(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.2f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    private func closeWalkSummaryPanel() {
        withAnimation(GoMotion.feedback) {
            setFlipped(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            showWalkSummaryPanel = false
            PetWalkingManager.shared.reset()
        }
    }

    // MARK: - Card Back（Read-Only Dashboard）
    // Sheet 状态（仅保留长按详情跳转）
    @State private var showWeightSheet  = false
    @State private var showWalkSheet    = false
    @State private var showHealthSheet  = false
    @State private var showCareSheet    = false
    @State private var showFoodSheet    = false
    @State private var showTodoDetail   = false

    // 待办查询（背面底部唯一交互来源）
    @Query(sort: \Event.startDate) private var allEvents: [Event]

    private var todoPetEvent: Event? {
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        let now  = Date()
        return allEvents.first {
            $0.isActionableTask &&
            !$0.isCompleted &&
            $0.relatedEntityId == petIdStr &&
            (cal.isDateInToday($0.startDate) ||
             ($0.startDate <= now && ($0.endDate == nil || $0.endDate! >= now)))
        }
    }

    private var cardBackView: some View {
        ZStack {
            // 背面底层：点击翻回正面（透明 hitTest 层）
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.clear)
                .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .onTapGesture {
                    if showWalkSummaryPanel {
                        closeWalkSummaryPanel()
                    } else {
                        toggleFlip()
                    }
                }

            if showWalkSummaryPanel && PetWalkingManager.shared.currentPet?.id == pet.id {
                walkSummaryPanel
            } else if isActiveWalk {
                // ── 遛狗活动中：使用 walkLivePanel 替换普通仪表盘
                walkLivePanel
            } else {
                // 顶部主题色渐变光晕
                VStack {
                    LinearGradient(
                        colors: [cardThemeColor.opacity(0.30), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // ── 顶栏：宠物名 + 详情按钮
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DATA DASHBOARD")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .tracking(3)
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                            Text(pet.name)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                        Spacer()
                        Button(action: onDetail) {
                            HStack(spacing: 4) {
                                Text(l.petCardDetail)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.75))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .goGlassBackground(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)

                    Spacer()

                    // ── 区域 1：核心数据摘要（居中）
                    backCoreMetrics
                        .padding(.horizontal, 16)
                        .allowsHitTesting(true)

                    Spacer()

                    // ── 区域 2：底部待办 Banner
                    backTodoBanner
                        .padding(.horizontal, 12)
                        .padding(.bottom, 14)
                }
            }
        }
        .goGlassBackground(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .transaction { tx in
            tx.animation = nil
        }
        // sheet 路由（由长按手势触发，非单击）
        .sheet(isPresented: $showWeightSheet) {
            WeightHistoryView(pet: pet)
                .presentationDetents([.large]) // ui-v4: allow long history sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWalkSheet) {
            WalkSummarySheet(pet: pet)
                .presentationDetents([.medium, .large]) // ui-v4: allow long walk summary sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHealthSheet) {
            NavigationStack { PetHealthDetailView(pet: pet, isModal: true) }
                .presentationDetents([.large]) // ui-v4: allow long health detail sheet
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showHealthSheet) { _, newVal in
            // C3: 若有外部回调，优先使用外部 modal（关闭内部 sheet 再调用）
            if newVal, let ext = onShowHealth {
                showHealthSheet = false
                ext()
            }
        }
        .sheet(isPresented: $showCareSheet) {
            CareTrackingDetailSheet(pet: pet)
                .presentationDetents([.large]) // ui-v4: allow long care detail sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFoodSheet) {
            NavigationStack { PetFoodManagementView(pet: pet) }
                .presentationDetents([.large]) // ui-v4: allow long food management sheet
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 区域1：核心数据摘要（物种感知，无单击，仅长按）
    @ViewBuilder
    private var backCoreMetrics: some View {
        HStack(spacing: 0) {
            if pet.species == "狗" {
                // Dog: 今日里程 / 今日便便 / 下次驱虫或疫苗
                let todayDist = pet.walkLogs
                    .filter { Calendar.current.isDateInToday($0.startDate) }
                    .reduce(0.0) { $0 + $1.distanceMeters }
                let todayPoop = pet.pottyLogs
                    .filter { Calendar.current.isDateInToday($0.date) }.count

                floatingMetric(
                    value: todayDist >= 1000
                        ? String(format: "%.1f", todayDist / 1000)
                        : String(format: "%.0f", todayDist),
                    unit: todayDist >= 1000 ? "km" : "m",
                    label: "今日里程",
                    accent: Color.goPrimary
                )
                .onLongPressGesture { showWalkSheet = true }

                metricDivider

                floatingMetric(
                    value: "\(todayPoop)",
                    unit: "次",
                    label: "今日便便",
                    accent: Color.goYellow
                )
                .onLongPressGesture { showCareSheet = true }

                metricDivider

                floatingMetric(
                    value: nextVaccineDaysText,
                    unit: "",
                    label: "下次疫苗",
                    accent: nextVaccineDaysColor
                )
                .onLongPressGesture { showHealthSheet = true }

            } else {
                // Cat/Other: 今日铲屎 / 今日饮水 / 最新体重
                let todayLitter = pet.careLogs
                    .filter { $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date) }.count
                let todayWater = pet.careLogs
                    .filter { $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date) }.count
                let latestWeight = pet.weightLogs
                    .sorted { $0.date > $1.date }.first?.weight

                floatingMetric(
                    value: "\(todayLitter)",
                    unit: "次",
                    label: "今日铲屎",
                    accent: Color.goYellow
                )
                .onLongPressGesture { showCareSheet = true }

                metricDivider

                floatingMetric(
                    value: "\(todayWater)",
                    unit: "次",
                    label: "今日饮水",
                    accent: Color.goTeal
                )
                .onLongPressGesture { showCareSheet = true }

                metricDivider

                floatingMetric(
                    value: latestWeight.map { String(format: "%.1f", $0) } ?? "--",
                    unit: latestWeight != nil ? "kg" : "",
                    label: "最新体重",
                    accent: Color.goTeal
                )
                .onLongPressGesture { showWeightSheet = true }
            }
        }
    }

    private func floatingMetric(value: String, unit: String, label: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.1))
            .frame(width: 1, height: 44)
    }

    // MARK: - 区域2：悬浮微型图表（透明背景）
    @ViewBuilder
    private var backSparklines: some View {
        HStack(spacing: 20) {
            // 图表 A：体重走势
            VStack(alignment: .leading, spacing: 6) {
                Text("体重走势")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)

                let wData = weightSparklineData
                if wData.count < 2 {
                    HStack {
                        Spacer()
                        Text("暂无数据")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.ohanaTertiaryText.opacity(0.7))
                        Spacer()
                    }
                    .frame(height: 36)
                } else {
                    Chart(wData) { pt in
                        AreaMark(
                            x: .value("i", pt.index),
                            y: .value("kg", pt.weight)
                        )
                        .interpolationMethod(OhanaChartStyle.trendInterpolation)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [cardThemeColor.opacity(0.25), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("i", pt.index),
                            y: .value("kg", pt.weight)
                        )
                        .interpolationMethod(OhanaChartStyle.trendInterpolation)
                        .foregroundStyle(cardThemeColor.opacity(0.9))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { val in
                            AxisValueLabel {
                                if let v = val.as(Double.self) {
                                    Text(String(format: "%.1f", v))
                                        .font(.system(size: 7, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ohanaTertiaryText)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { $0.background(.clear) }
                    .frame(height: 36)
                }
            }
            .frame(maxWidth: .infinity)

            // 图表 B：本周活跃
            VStack(alignment: .leading, spacing: 6) {
                Text("本周活跃")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)

                let aData = activitySparklineData
                if aData.allSatisfy({ $0.count == 0 }) {
                    HStack {
                        Spacer()
                        Text("暂无数据")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.ohanaTertiaryText.opacity(0.7))
                        Spacer()
                    }
                    .frame(height: 36)
                } else {
                    let maxCount = aData.map(\.count).max() ?? 1
                    Chart(aData) { pt in
                        BarMark(
                            x: .value("day", pt.dayOffset),
                            y: .value("n", pt.count),
                            width: .fixed(4)
                        )
                        .foregroundStyle(pt.isToday ? Color.goPrimary : Color.ohanaTertiaryText.opacity(0.55))
                        .cornerRadius(2)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6]) { val in
                            AxisValueLabel {
                                if let d = val.as(Int.self) {
                                    Text(d == 0 ? "7天前" : "今")
                                        .font(.system(size: 7, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ohanaTertiaryText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, maxCount]) { val in
                            AxisValueLabel {
                                if let v = val.as(Int.self), v > 0 {
                                    Text("\(v)")
                                        .font(.system(size: 7, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ohanaTertiaryText)
                                }
                            }
                            AxisGridLine().foregroundStyle(Color.ohanaDivider.opacity(0.5))
                        }
                    }
                    .chartPlotStyle { $0.background(.clear) }
                    .frame(height: 36)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 区域3：底部待办 Banner（唯一可点击修改数据区）
    @ViewBuilder
    private var backTodoBanner: some View {
        if let event = todoPetEvent {
            HStack(spacing: 10) {
                Text(event.emoji)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
                        .lineLimit(1)
                    if !event.isAllDay, Calendar.current.isDateInToday(event.startDate) {
                        Text(event.startDate, format: .dateTime.hour().minute())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    } else {
                        Text("今日待办")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    }
                }
                Spacer()
                // 唯一允许修改数据的按钮
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    event.isCompleted = true
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.goPrimary.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .goGlassBackground(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.3), lineWidth: 1)
            )
        } else {
            HStack(spacing: 8) {
                Text("✅")
                    .font(.system(size: 14))
                Text("\(pet.name) 今天没有待完成的事项")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Achievement Sticker Row (单行横滚，仅已解锁)
    private var achievementStickerWall: some View {
        let allAchievements = AchievementManager.compute(for: pet)
        let unlocked = allAchievements.filter { $0.isUnlocked }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("🏅")
                    .font(.system(size: 11))
                Text("岛屿纪念品")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text("\(unlocked.count)/\(allAchievements.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(unlocked.count == allAchievements.count ? Color.goPrimary : Color.ohanaTertiaryText)
            }

            if unlocked.isEmpty {
                Text("完成挑战后解锁纪念品 ✨")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(unlocked) { badge in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.ohanaControlFill)
                                Text(badge.emoji)
                                    .font(.system(size: 20))
                            }
                            .frame(width: 44, height: 44)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Micro-Charts Row（底部体重走势 + 本周活跃）

    private struct WeightPoint: Identifiable {
        let id = UUID()
        let index: Int
        let weight: Double
    }

    private struct ActivityPoint: Identifiable {
        let id = UUID()
        let dayOffset: Int   // 0 = 今天, 1 = 昨天 … 6 = 6天前
        let count: Int
        let isToday: Bool
    }

    private var weightSparklineData: [WeightPoint] {
        let sorted = pet.weightLogs.sorted { $0.date < $1.date }.suffix(12)
        return sorted.enumerated().map { WeightPoint(index: $0.offset, weight: $0.element.weight) }
    }

    private var activitySparklineData: [ActivityPoint] {
        let cal = Calendar.current
        let now = Date()
        return (0..<7).reversed().enumerated().map { enumIdx, dayBack in
            guard let day = cal.date(byAdding: .day, value: -dayBack, to: now) else {
                return ActivityPoint(dayOffset: enumIdx, count: 0, isToday: dayBack == 0)
            }
            let count = pet.careLogs.filter { cal.isDate($0.date, inSameDayAs: day) }.count
                + pet.hygieneLogs.filter { cal.isDate($0.date, inSameDayAs: day) }.count
                + pet.walkLogs.filter { cal.isDate($0.startDate, inSameDayAs: day) }.count
            return ActivityPoint(dayOffset: enumIdx, count: count, isToday: dayBack == 0)
        }
    }

    @ViewBuilder
    private var microChartsRow: some View {
        HStack(spacing: 12) {
            // ── 图表 A：体重走势
            VStack(alignment: .leading, spacing: 4) {
                Text("体重走势")
                    .font(.caption)
                    .foregroundStyle(Color.ohanaSecondaryText)

                let data = weightSparklineData
                if data.count < 2 {
                    // 空数据占位符
                    Rectangle()
                        .fill(Color.ohanaControlFill)
                        .frame(height: 44)
                        .overlay(
                            Text("暂无数据")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.ohanaTertiaryText)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Chart(data) { pt in
                        AreaMark(
                            x: .value("idx", pt.index),
                            y: .value("kg", pt.weight)
                        )
                        .interpolationMethod(OhanaChartStyle.trendInterpolation)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [cardThemeColor.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("idx", pt.index),
                            y: .value("kg", pt.weight)
                        )
                        .interpolationMethod(OhanaChartStyle.trendInterpolation)
                        .foregroundStyle(cardThemeColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 44)
                }
            }
            .frame(maxWidth: .infinity)

            // ── 图表 B：本周照料活跃度
            VStack(alignment: .leading, spacing: 4) {
                Text("本周活跃")
                    .font(.caption)
                    .foregroundStyle(Color.ohanaSecondaryText)

                let data = activitySparklineData
                let allZero = data.allSatisfy { $0.count == 0 }
                if allZero {
                    Rectangle()
                        .fill(Color.ohanaControlFill)
                        .frame(height: 44)
                        .overlay(
                            Text("暂无数据")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.ohanaTertiaryText)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Chart(data) { pt in
                        BarMark(
                            x: .value("day", pt.dayOffset),
                            y: .value("次", pt.count),
                            width: .fixed(4)
                        )
                        .foregroundStyle(pt.isToday ? Color.goPrimary : Color.ohanaTertiaryText.opacity(0.65))
                        .cornerRadius(2)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 44)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Back stat helpers
    private var nextVaccineDaysText: String {
        let lastVaccine = pet.healthLogs
            .filter { $0.type == HealthLogType.vaccine.rawValue }
            .sorted(by: { $0.date > $1.date }).first
        guard let last = lastVaccine,
              let due = Calendar.current.date(byAdding: .year, value: 1, to: last.date) else { return "--" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        return l.petCardVaccineCountdown(daysUntilDue: days)
    }
    
    private var nextVaccineDaysColor: Color {
        let lastVaccine = pet.healthLogs
            .filter { $0.type == HealthLogType.vaccine.rawValue }
            .sorted(by: { $0.date > $1.date }).first
        guard let last = lastVaccine,
              let due = Calendar.current.date(byAdding: .year, value: 1, to: last.date) else { return Color.ohanaTertiaryText }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        if days < 0 { return Color.goRed }
        if days <= 30 { return Color.goYellow }
        return Color.goTeal
    }
    
    private func backStatCell(value: String, unit: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func goBentoItem(icon: String, title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.ohanaGlassStroke.opacity(0.8), lineWidth: 1)
        }
    }
}

// MARK: - Mini QR Code View (chip 号转伪二维码图案)
