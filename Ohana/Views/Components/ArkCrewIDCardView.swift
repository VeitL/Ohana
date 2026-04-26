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
        .shadow(color: glowFlash ? Color.goPrimary.opacity(0.8) : Color.black.opacity(0.15),
                radius: glowFlash ? 20 : 24, x: 0, y: glowFlash ? 0 : 12)
        .scaleEffect(cardScale)
        .animation(.easeInOut(duration: 0.8), value: glowFlash)
        .onChange(of: flipped) { _, newFlipped in
            withAnimation(.easeInOut(duration: 0.42)) {
                cardRotation = newFlipped ? 180 : 0
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
        return bright.contains(pet.themeColorHex.uppercased()) ? Color.arkInk : .white
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
        .shadow(color: pet.hasPassedAway ? Color.purple.opacity(0.35) : cardThemeColor.opacity(0.45),
                radius: 24, x: 0, y: 8)
        .shadow(color: .black.opacity(0.28), radius: 40, x: 0, y: 16)
        .shadow(color: .black.opacity(0.10), radius: 80, x: 0, y: 32)
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
                        colors: [.clear, .black.opacity(0.22)],
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
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.goPrimary, in: Capsule())
                }

                Spacer()

                Text("\(pet.daysTogether)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(l.petCardDaysTogetherCaption)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text(posterFootnote)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
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
                        .colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
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
                    .fill(Color.black.opacity(0.16))
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
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.8)
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

    // MARK: - 简约风格正面
    private func minimalFront(geo: GeometryProxy, avatarImage: UIImage?) -> some View {
        let tc = cardTextColor
        return ZStack {
            // 底层：纯主题色渐变
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(
                    colors: [cardThemeColor, cardThemeColor.mix(with: .black, by: 0.35)],
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
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
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
                .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 0))
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.30)],
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
                .fill(cardThemeColor.mix(with: .black, by: 0.30))
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardThemeColor.opacity(0.85),
                            cardThemeColor.mix(with: Color(hex: "000000"), by: 0.45).opacity(0.95)
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
                        .colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2,  y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0,  y: 2)
                        .shadow(color: .white, radius: 0, x: 0,  y: -2)
                        .shadow(color: .white, radius: 1, x: 2,  y: 2)
                        .shadow(color: .white, radius: 1, x: -2, y: -2)
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit()
                }
                .frame(width: geo.size.width * 0.52, height: geo.size.height * 1.05)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
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
                            Color.black.opacity(0.28),
                            Color.black.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // ── 层3：ultraThinMaterial 进一步柔化
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.35))

            // ── 层4：品牌水印
            Text("OHANA")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.04))
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
                            .init(color: .black.opacity(0.5), location: 0.70),
                            .init(color: .black, location: 1.0)
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
                infoColumn(geo: geo, textColor: .white)
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
                .fill(cardThemeColor.mix(with: .black, by: 0.30))

            // 层 2: 对角渐变 - 左上亮、右下深
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        cardThemeColor.opacity(0.9),
                        cardThemeColor.mix(with: .black, by: 0.55).opacity(0.95)
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
                    colors: [.black.opacity(0.35), .clear],
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
                .shadow(color: .black.opacity(0.25), radius: 16, x: 4, y: 8)
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
                        colors: [Color.black.opacity(0.65), Color(hex: pet.themeColorHex).opacity(0.35)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 36))
                    .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                Text(l.petCardRainbowTitle)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                if let d = pet.passedAwayDate {
                    let years = Calendar.current.dateComponents([.year], from: d, to: Date()).year ?? 0
                    Text(d.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(l.petCardRainbowTogether(days: pet.daysTogetherAtPassing, yearsApart: years))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
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
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.1), in: Capsule())
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
                        .foregroundStyle(.white.opacity(0.6))
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
                            .foregroundStyle(.black)
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
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.goTeal, in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                // 停止
                Button {
                    mgr.stop(modelContext: modelContext, household: cardHouseholds.first)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    Label(l.petCardEndWalk, systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
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
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .buttonStyle(.plain)
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
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
                .onTapGesture { toggleFlip() }

            if isActiveWalk {
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
                                .foregroundStyle(.primary.opacity(0.25))
                            Text(pet.name)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Button(action: onDetail) {
                            HStack(spacing: 4) {
                                Text(l.petCardDetail)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.75))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.primary.opacity(0.5))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .glassEffect(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .transaction { tx in
            tx.animation = nil
        }
        // sheet 路由（由长按手势触发，非单击）
        .sheet(isPresented: $showWeightSheet) {
            WeightHistoryView(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWalkSheet) {
            WalkSummarySheet(pet: pet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHealthSheet) {
            NavigationStack { PetHealthDetailView(pet: pet, isModal: true) }
                .presentationDetents([.large])
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFoodSheet) {
            NavigationStack { PetFoodManagementView(pet: pet) }
                .presentationDetents([.large])
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
                .foregroundStyle(.primary.opacity(0.35))
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
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
                    .foregroundStyle(.white.opacity(0.3))
                    .textCase(.uppercase)

                let wData = weightSparklineData
                if wData.count < 2 {
                    HStack {
                        Spacer()
                        Text("暂无数据")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.15))
                        Spacer()
                    }
                    .frame(height: 36)
                } else {
                    Chart(wData) { pt in
                        AreaMark(
                            x: .value("i", pt.index),
                            y: .value("kg", pt.weight)
                        )
                        .interpolationMethod(.catmullRom)
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
                        .interpolationMethod(.catmullRom)
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
                                        .foregroundStyle(.white.opacity(0.3))
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
                    .foregroundStyle(.white.opacity(0.3))
                    .textCase(.uppercase)

                let aData = activitySparklineData
                if aData.allSatisfy({ $0.count == 0 }) {
                    HStack {
                        Spacer()
                        Text("暂无数据")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.15))
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
                        .foregroundStyle(pt.isToday ? Color.goPrimary : Color.white.opacity(0.2))
                        .cornerRadius(2)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6]) { val in
                            AxisValueLabel {
                                if let d = val.as(Int.self) {
                                    Text(d == 0 ? "7天前" : "今")
                                        .font(.system(size: 7, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.25))
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
                                        .foregroundStyle(.white.opacity(0.22))
                                }
                            }
                            AxisGridLine().foregroundStyle(.white.opacity(0.04))
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
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(1)
                    if !event.isAllDay, Calendar.current.isDateInToday(event.startDate) {
                        Text(event.startDate, format: .dateTime.hour().minute())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.45))
                    } else {
                        Text("今日待办")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.4))
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
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .foregroundStyle(.primary.opacity(0.35))
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
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("\(unlocked.count)/\(allAchievements.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(unlocked.count == allAchievements.count ? Color.goPrimary : .white.opacity(0.3))
            }

            if unlocked.isEmpty {
                Text("完成挑战后解锁纪念品 ✨")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(unlocked) { badge in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white.opacity(0.05))
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
                    .foregroundStyle(.secondary)

                let data = weightSparklineData
                if data.count < 2 {
                    // 空数据占位符
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 44)
                        .overlay(
                            Text("暂无数据")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.2))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Chart(data) { pt in
                        AreaMark(
                            x: .value("idx", pt.index),
                            y: .value("kg", pt.weight)
                        )
                        .interpolationMethod(.catmullRom)
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
                        .interpolationMethod(.catmullRom)
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
                    .foregroundStyle(.secondary)

                let data = activitySparklineData
                let allZero = data.allSatisfy { $0.count == 0 }
                if allZero {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 44)
                        .overlay(
                            Text("暂无数据")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.2))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Chart(data) { pt in
                        BarMark(
                            x: .value("day", pt.dayOffset),
                            y: .value("次", pt.count),
                            width: .fixed(4)
                        )
                        .foregroundStyle(pt.isToday ? Color.goPrimary : Color.white.opacity(0.25))
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
              let due = Calendar.current.date(byAdding: .year, value: 1, to: last.date) else { return .white.opacity(0.4) }
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
                    .foregroundStyle(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
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
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Mini QR Code View (chip 号转伪二维码图案)
struct MiniQRCodeView: View {
    let content: String
    let size: CGFloat
    let color: Color

    private var cells: [[Bool]] {
        let seed = content.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        var rng = seed
        var grid = Array(repeating: Array(repeating: false, count: 7), count: 7)
        for r in 0..<7 {
            for c in 0..<7 {
                rng = (rng &* 1103515245 &+ 12345) & 0x7fffffff
                grid[r][c] = rng % 3 != 0
            }
        }
        // Finder pattern corners
        for i in 0..<3 { for j in 0..<3 { grid[i][j] = true; grid[i][6-j] = true; grid[6-i][j] = true } }
        return grid
    }

    var body: some View {
        let cellSize = size / 7
        Canvas { ctx, _ in
            for r in 0..<7 {
                for c in 0..<7 where cells[r][c] {
                    let rect = CGRect(x: CGFloat(c)*cellSize, y: CGFloat(r)*cellSize, width: cellSize-0.5, height: cellSize-0.5)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .foreground)
                }
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
    }
}

// MARK: - Add Reminder Sheet (从打卡格长按触发)
struct AddReminderFromCheckInSheet: View {
    let pet: Pet
    let actionEmoji: String
    let actionLabel: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var recurrenceDays: Int = 0
    @State private var isAllDay: Bool = false

    private let recurrenceOptions: [(label: String, days: Int)] = [
        ("不重复", 0), ("每天", 1), ("每2天", 2), ("每3天", 3),
        ("每周", 7), ("每两周", 14), ("每月", 30)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 40, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 标题
                    HStack(spacing: 10) {
                        Text(actionEmoji).font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加待办")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            Text("\(pet.name) · \(actionLabel)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    // 全天开关
                    HStack {
                        Label("全天", systemImage: "sun.max.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                        Spacer()
                        Toggle("", isOn: $isAllDay)
                            .tint(Color.goPrimary)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    // 开始时间
                    VStack(alignment: .leading, spacing: 8) {
                        Text("开始时间")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        DatePicker("", selection: $startDate,
                                   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .tint(Color.goPrimary)
                            .labelsHidden()
                            .padding(.horizontal, 24)
                    }

                    // 结束时间
                    if !isAllDay {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("结束时间")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                            DatePicker("", selection: $endDate, in: startDate...,
                                       displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(Color.goPrimary)
                                .labelsHidden()
                                .padding(.horizontal, 24)
                        }
                    }

                    // 重复频率
                    VStack(alignment: .leading, spacing: 10) {
                        Text("重复频率")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recurrenceOptions, id: \.days) { opt in
                                    Button { recurrenceDays = opt.days } label: {
                                        Text(opt.label)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(recurrenceDays == opt.days ? .black : Color(.label))
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(
                                                recurrenceDays == opt.days ? Color.goPrimary : Color(.systemGray5),
                                                in: Capsule()
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // 保存按钮
                    Button {
                        saveReminder()
                        dismiss()
                    } label: {
                        Text("添加到日历")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func saveReminder() {
        let title = "\(actionEmoji) \(pet.name) · \(actionLabel)"
        let event = Event(
            title: title,
            startDate: startDate,
            endDate: isAllDay ? nil : endDate,
            isAllDay: isAllDay,
            eventType: EventType.task.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = recurrenceDays
        modelContext.insert(event)

        let reminder = Reminder(event: event, scheduledAt: startDate)
        reminder.status = "pending"
        modelContext.insert(reminder)

        // 如果有重复，创建多个提醒（最多生成 12 个）
        if recurrenceDays > 0 {
            for i in 1...12 {
                guard let nextDate = Calendar.current.date(byAdding: .day, value: recurrenceDays * i, to: startDate) else { break }
                if let end = event.recurrenceEndDate, nextDate > end { break }
                let r = Reminder(event: event, scheduledAt: nextDate)
                r.status = "pending"
                modelContext.insert(r)
            }
        }

        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Back Bento Dashboard（Task1 重构：生命体征情报局）
// 职能：状态展示 + 待办情报。打卡动作已全部交由首页 Quick Access 负责。
private struct BackBentoDashboard: View {
    let pet: Pet
    var onShowCare: (() -> Void)? = nil
    var onShowFood: (() -> Void)? = nil
    var onShowHealth: (() -> Void)? = nil
    var onShowWeight: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledAt) private var allReminders: [Reminder]

    // 椰子浮字特效（仅保留用于完成待办奖励）
    @State private var coconutFloats: [CoconutFloat] = []
    
    @State private var glowFlash = false
    @State private var cardScale: CGFloat = 1.0

    private struct CoconutFloat: Identifiable {
        let id = UUID()
        let amount: Int
        var offset: CGFloat = 0
        var opacity: Double = 1
    }

    // MARK: - Computed vitals

    private var todayWalkDistance: Double {
        let cal = Calendar.current
        return pet.walkLogs.filter { cal.isDateInToday($0.startDate) }
            .reduce(0.0) { $0 + $1.distanceMeters }
    }
    private var todayWalkCount: Int {
        pet.walkLogs.filter { Calendar.current.isDateInToday($0.startDate) }.count
    }
    // 运动进度：以 3000m 为每日目标
    private var exerciseGoalMeters: Double { 3000 }
    private var exerciseProgress: Double { min(1.0, todayWalkDistance / exerciseGoalMeters) }

    // 余粮进度（最多 30 天满格）
    private var foodProgress: Double {
        guard pet.remainingFoodDays > 0 else { return 0 }
        return min(1.0, Double(pet.remainingFoodDays) / 30.0)
    }
    private var foodAccent: Color { pet.remainingFoodDays <= 3 ? .goRed : pet.remainingFoodDays <= 7 ? .goOrange : .goPrimary }

    // 最近一次排泄时间差
    private var lastPottyText: String {
        let isLitter = ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
        let lastDate: Date?
        if isLitter {
            lastDate = pet.careLogs.filter { $0.type == CareType.litter.rawValue }
                .sorted { $0.date > $1.date }.first?.date
        } else {
            lastDate = pet.pottyLogs.sorted { $0.date > $1.date }.first?.date
        }
        guard let d = lastDate else { return "暂无记录" }
        let mins = Int(Date().timeIntervalSince(d) / 60)
        if mins < 60 { return "\(mins)分钟前" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)小时前" }
        return "\(hrs / 24)天前"
    }

    // Bug6: 有效期 < 7 天的最紧急健康记录
    private var urgentExpiringHealthLog: PetHealthLog? {
        let now = Date()
        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return pet.healthLogs
            .filter { log in
                guard let exp = log.expirationDate else { return false }
                return exp <= sevenDaysLater
            }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
            .first
    }

    // 最高优先级待办（当日，该宠物）
    private var topReminder: Reminder? {
        let petIdStr = pet.id.uuidString
        let cal = Calendar.current
        return allReminders.first {
            $0.statusEnum == .pending &&
            cal.isDateInToday($0.scheduledAt) &&
            $0.event?.relatedEntityId == petIdStr
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 8) {
                // ── 行1：物种感知 — 犬类显示遛狗进度环，其他物种显示日常照料摘要
                if pet.species == "狗" {
                    dogActivityRow
                } else {
                    careActivityRow
                }

                // ── 行2：余粮进度条
                if pet.remainingFoodGrams > 0 || pet.dailyPortionGrams > 0 {
                    Button { onShowFood?() } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                HStack(spacing: 4) {
                                    Text("🍖").font(.system(size: 12))
                                    Text("余粮")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                if pet.remainingFoodGrams > 0 {
                                    Text(pet.remainingFoodDays > 0 ? "还剩 \(pet.remainingFoodDays) 天" : "即将断粮")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(foodAccent)
                                } else {
                                    Text("未记录余粮")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.08)).frame(height: 5)
                                    Capsule().fill(foodAccent)
                                        .frame(width: max(6, geo.size.width * foodProgress), height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(foodAccent.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // ── 行2.5：Bug6 健康有效期紧急提醒（< 7 天）
                if let urgentLog = urgentExpiringHealthLog {
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: urgentLog.expirationDate!).day ?? 0
                    HStack(spacing: 8) {
                        Text("⚠️").font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(urgentLog.note.isEmpty ? urgentLog.healthLogType.rawValue : urgentLog.note) 即将到期")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goRed)
                                .lineLimit(1)
                            Text(daysLeft <= 0 ? "已逾期" : "还剩 \(daysLeft) 天")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.goRed.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.goRed.opacity(0.5))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.goRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
                }

                // ── 行3：Quick Access 打卡面板（离世后隐藏）
                if pet.hasPassedAway {
                    rainbowBridgeMemorialCard
                } else {
                    SpeciesCheckInGrid(
                        pet: pet,
                        onNavigateToHealth: { onShowHealth?() },
                        onNavigateToWeight: { onShowWeight?() },
                        glowFlash: $glowFlash,
                        cardScale: $cardScale
                    )
                }
            }

            // 椰子浮字叠加层
            ForEach(coconutFloats) { item in
                Text("+\(item.amount)🥥")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .offset(y: item.offset)
                    .opacity(item.opacity)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Rainbow Bridge 纪念碑卡片（背面打卡区替代品）
    private var rainbowBridgeMemorialCard: some View {
        HStack(spacing: 12) {
            Text("🌈").font(.system(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text("彩虹桥彼端 — 永远爱你")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                if let d = pet.passedAwayDate {
                    Text("离世于 \(d.formatted(.dateTime.year().month().day()))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text("相伴 \(pet.daysTogetherAtPassing) 天 · \(pet.ageAtPassingText)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.purple.opacity(0.18), Color.blue.opacity(0.08)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Species-Aware Activity Rows

    private var dogActivityRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.goPrimary.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: exerciseProgress)
                    .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(todayWalkCount == 0 ? "今日未出行" : "今日已遛 \(todayWalkCount) 次")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                let distStr = todayWalkDistance >= 1000
                    ? String(format: "%.1f km", todayWalkDistance / 1000)
                    : String(format: "%.0f m", todayWalkDistance)
                Text(todayWalkDistance > 0 ? "累计 \(distStr)" : "目标 \(Int(exerciseGoalMeters / 1000)) km")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("💩").font(.system(size: 16))
                Text(lastPottyText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private var careActivityRow: some View {
        HStack(spacing: 0) {
            let todayFeed = pet.careLogs.filter {
                $0.type == CareType.feeding.rawValue && Calendar.current.isDateInToday($0.date)
            }.count
            let todayWater = pet.careLogs.filter {
                $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date)
            }.count
            let isLitter = ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
            let todayLitter = isLitter ? pet.careLogs.filter {
                $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date)
            }.count : 0

            careCountCell(emoji: "🍽️", label: "喂食", count: todayFeed, accent: Color.goOrange)
            Divider().frame(height: 28).opacity(0.15)
            careCountCell(emoji: "💧", label: "喂水", count: todayWater, accent: Color.goTeal)
            if isLitter {
                Divider().frame(height: 28).opacity(0.15)
                careCountCell(emoji: "🧹", label: "铲屎", count: todayLitter, accent: Color.goYellow)
            } else {
                Divider().frame(height: 28).opacity(0.15)
                VStack(spacing: 2) {
                    Text("🕐").font(.system(size: 14))
                    Text(lastPottyText)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private func careCountCell(emoji: String, label: String, count: Int, accent: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(emoji).font(.system(size: 14))
                Text("\(count)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(count > 0 ? accent : .white.opacity(0.3))
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Coconut float effect

    private func spawnCoconut(_ amount: Int) {
        let item = CoconutFloat(amount: amount)
        coconutFloats.append(item)
        let id = item.id
        withAnimation(.easeOut(duration: 0.9)) {
            if let idx = coconutFloats.firstIndex(where: { $0.id == id }) {
                coconutFloats[idx].offset  = -60
                coconutFloats[idx].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            coconutFloats.removeAll { $0.id == id }
        }
    }
}

// MARK: - SmartHygieneGrid（意图驱动护理格，废除倒计时变红）
private struct SmartHygieneGrid: View {
    let pet: Pet
    let topReminder: Reminder?
    var onComplete: ((Reminder) -> Void)? = nil
    var onCheckIn: ((HygieneType) -> Void)? = nil

    private let items: [(emoji: String, label: String, type: HygieneType)] = [
        ("🛁", "洗澡", .bath),
        ("🦷", "刷牙", .teeth),
        ("✂️", "剪甲", .nails),
        ("🪮", "梳毛", .brushing)
    ]

    var body: some View {
        if let reminder = topReminder {
            // ── 待办激活状态：显示最高优先级待办 + 护理格微光
            VStack(spacing: 6) {
                Button { onComplete?(reminder) } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().stroke(Color.goPrimary.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.goPrimary)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reminder.event?.title ?? "待办任务")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(reminder.scheduledAt, format: .dateTime.hour().minute())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.goPrimary.opacity(0.7))
                        }
                        Spacer()
                        Text("+2🥥")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.goPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.goPrimary.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                quietHygieneRow(highlightLabel: reminder.event?.title)
            }
        } else {
            // ── 安静状态：统一毛玻璃暗色背景，无倒计时焦虑
            quietHygieneRow(highlightLabel: nil)
        }
    }

    @ViewBuilder
    private func quietHygieneRow(highlightLabel: String?) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.type) { item in
                let isHighlighted = highlightLabel.map {
                    $0.localizedCaseInsensitiveContains(item.label)
                } ?? false

                Button { onCheckIn?(item.type) } label: {
                    VStack(spacing: 2) {
                        Text(item.emoji).font(.system(size: 18))
                        Text(item.label)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(isHighlighted ? Color.goPrimary : .white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        isHighlighted
                            ? Color.goPrimary.opacity(0.12)
                            : .white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isHighlighted
                                    ? Color.goPrimary.opacity(0.45)
                                    : .white.opacity(0.08),
                                lineWidth: isHighlighted ? 1 : 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Identifiable wrapper for sheet(item:)
private struct IdentifiableAction: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let type: String
    init(emoji: String, label: String, type: String) {
        self.id = type + emoji
        self.emoji = emoji
        self.label = label
        self.type = type
    }
}

// MARK: - Quick Access 卡片类型定义
enum QACardType: String, CaseIterable, Codable {
    // 通用
    case walk           = "walk"
    case feed           = "feed"
    case water          = "water"
    case potty          = "potty"
    case litter         = "litter"
    case care           = "care"
    case health         = "health"
    case expense        = "expense"
    case weight         = "weight"
    case play           = "play"
    // 鱼类
    case waterChange    = "waterChange"
    case filterClean    = "filterClean"
    // 鸟类
    case cageCleaning   = "cageCleaning"
    case freeFlight     = "freeFlight"
    // 爬宠
    case misting        = "misting"
    case substrateChange = "substrateChange"

    var emoji: String {
        switch self {
        case .walk:           return "🦮"
        case .feed:           return "🍗"
        case .water:          return "💧"
        case .potty:          return "💩"
        case .litter:         return "🧹"
        case .care:           return "🛁"
        case .health:         return "🏥"
        case .expense:        return "💰"
        case .weight:         return "⚖️"
        case .play:           return "🎾"
        case .waterChange:    return "🪣"
        case .filterClean:    return "🔧"
        case .cageCleaning:   return "🧺"
        case .freeFlight:     return "🕊️"
        case .misting:        return "💦"
        case .substrateChange: return "🪵"
        }
    }

    var label: String {
        switch self {
        case .walk:           return "遛狗"
        case .feed:           return "喂食"
        case .water:          return "喂水"
        case .potty:          return "便便"
        case .litter:         return "铲屎"
        case .care:           return "护理"
        case .health:         return "健康"
        case .expense:        return "花费"
        case .weight:         return "体重"
        case .play:           return "逗玩"
        case .waterChange:    return "换水"
        case .filterClean:    return "清滤材"
        case .cageCleaning:   return "清鸟笼"
        case .freeFlight:     return "放飞"
        case .misting:        return "喷水"
        case .substrateChange: return "换垫材"
        }
    }

    /// 根据物种返回可用的卡片类型
    static func available(for species: String) -> [QACardType] {
        switch species {
        case "狗":
            return [.walk, .feed, .water, .potty, .care, .play, .health, .expense, .weight]
        case "猫":
            return [.litter, .feed, .water, .potty, .play, .care, .health, .expense, .weight]
        case "鱼", "热带鱼", "金鱼", "锦鲤":
            return [.feed, .waterChange, .filterClean, .play, .health, .expense]
        case "鸟", "鹦鹉", "文鸟", "鸽子":
            return [.feed, .water, .cageCleaning, .freeFlight, .play, .health, .expense, .weight]
        case "兔子", "仓鼠", "龙猫", "豚鼠":
            return [.feed, .water, .litter, .care, .play, .health, .expense, .weight]
        case "蜥蜴", "蛇", "龟", "变色龙", "壁虎":
            return [.feed, .misting, .substrateChange, .play, .health, .expense, .weight]
        default:
            return [.feed, .water, .play, .care, .health, .expense, .weight]
        }
    }
}

// MARK: - Quick Access 持久化 Helper（黑名单机制）
// 存储用户「明确排除」的卡片，加载时用 available(for:) - excluded 计算激活列表
// 这样物种新增的卡片类型自动出现，而用户移除的卡片依然保持移除状态
private struct QAConfig {
    static func excludedKey(for petId: UUID) -> String { "qaExcluded_\(petId.uuidString)" }
    // 向下兼容旧版 key（升级时一次性迁移）
    static func legacyKey(for petId: UUID) -> String { "qaCards_\(petId.uuidString)" }

    /// 加载激活列表 = available(for:species) - excluded
    static func load(for petId: UUID, species: String) -> [QACardType] {
        let available = QACardType.available(for: species)
        let rawExcluded = loadExcluded(for: petId, species: species)
        // 安全校验：黑名单只能包含该物种 available 里的卡片
        // 防止历史脏数据把本物种应有的卡片（.play/.potty 等）永久排除
        let cleanedExcluded = rawExcluded.filter { available.contains($0) }
        if cleanedExcluded.count != rawExcluded.count {
            saveExcluded(cleanedExcluded, for: petId)
        }
        var result = available.filter { !cleanedExcluded.contains($0) }
        // ── 核弹级强注入：available 里有但 result 里没有的卡片，强行追加到末尾
        for card in available {
            if !result.contains(card) {
                result.append(card)
            }
        }
        return result
    }

    /// 从黑名单加载已排除卡片（species 用于旧版迁移时确定物种范围）
    static func loadExcluded(for petId: UUID, species: String = "") -> [QACardType] {
        // 若有旧版激活列表，迁移一次
        if let legacyData = UserDefaults.standard.data(forKey: legacyKey(for: petId)),
           let legacyCards = try? JSONDecoder().decode([QACardType].self, from: legacyData) {
            // 迁移修复：只把"该物种 available 里、且旧版激活列表里没有"的卡片加入 excluded
            // 这样新增卡片（potty/play 等）不会被误排除
            let available = species.isEmpty ? QACardType.allCases : QACardType.available(for: species)
            let excluded = available.filter { !legacyCards.contains($0) }
            saveExcluded(excluded, for: petId)
            UserDefaults.standard.removeObject(forKey: legacyKey(for: petId))
            return excluded
        }
        guard let data = UserDefaults.standard.data(forKey: excludedKey(for: petId)),
              let types = try? JSONDecoder().decode([QACardType].self, from: data) else {
            return []
        }
        return types
    }

    /// 将 card 加入黑名单（用户移除时调用）
    static func exclude(_ card: QACardType, for petId: UUID) {
        var excluded = loadExcluded(for: petId)
        if !excluded.contains(card) { excluded.append(card) }
        saveExcluded(excluded, for: petId)
    }

    /// 从黑名单移除 card（用户重新添加时调用）
    static func unexclude(_ card: QACardType, for petId: UUID) {
        var excluded = loadExcluded(for: petId)
        excluded.removeAll { $0 == card }
        saveExcluded(excluded, for: petId)
    }

    private static func saveExcluded(_ cards: [QACardType], for petId: UUID) {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: excludedKey(for: petId))
    }
}

// MARK: - Species-Aware Quick Access Grid
struct SpeciesCheckInGrid: View {
    let pet: Pet
    /// 点击健康卡片时的跳转回调（由父视图决定如何呈现）
    var onNavigateToHealth: (() -> Void)? = nil
    /// 点击体重卡片回调
    var onNavigateToWeight: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    // 已激活的卡片列表（从 UserDefaults 加载）
    @State private var activeCards: [QACardType] = []
    // 显示添加面板
    @State private var showAddPanel = false
    // 护理二级菜单
    @State private var showCareMenu = false
    // 长按护理：添加待办 sheet
    @State private var showCareReminderSheet = false
    // 花费 sheet
    @State private var showExpenseSheet = false
    // 体重 sheet
    @State private var showWeightSheet = false
    // 撤回
    @State private var undoItem: UndoCheckIn? = nil
    @State private var feedAnimating = false
    @Binding var glowFlash: Bool
    @Binding var cardScale: CGFloat
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow: Bool = false

    private struct UndoCheckIn: Identifiable {
        let id = UUID()
        let label: String
        let emoji: String
        let insertedIDs: [PersistentIdentifier]
    }

    var body: some View {
        VStack(spacing: 10) {
            if activeCards.isEmpty {
                emptyPlaceholder
            } else {
                ZStack(alignment: .bottom) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(activeCards, id: \.rawValue) { card in
                            qaCell(for: card)
                        }
                        // + 添加按钮（末尾始终显示）
                        addButton
                    }
                    // 撤回 toast
                    if let undo = undoItem {
                        undoToast(undo)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
        .onAppear { activeCards = QAConfig.load(for: pet.id, species: pet.species) }
        .onChange(of: pet.species) { _, newSpecies in
            activeCards = QAConfig.load(for: pet.id, species: newSpecies)
        }
        // 护理二级菜单（confirmationDialog）
        .confirmationDialog("选择护理项目", isPresented: $showCareMenu, titleVisibility: .visible) {
            Button("🛁 洗澡")   { performHygieneCheckIn(.bath) }
            Button("🦷 刷牙")   { performHygieneCheckIn(.teeth) }
            Button("✂️ 剪甲")   { performHygieneCheckIn(.nails) }
            Button("🪮 梳毛")   { performHygieneCheckIn(.brushing) }
            Button("取消", role: .cancel) {}
        }
        // 花费 sheet
        .sheet(isPresented: $showExpenseSheet) {
            AddExpenseSheet(pet: pet)
        }
        // 体重 sheet
        .sheet(isPresented: $showWeightSheet) {
            QuickWeightSheet(pet: pet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // 护理添加待办 sheet
        .sheet(isPresented: $showCareReminderSheet) {
            AddReminderFromCheckInSheet(pet: pet, actionEmoji: "🛁", actionLabel: "护理")
        }
        // 添加面板 sheet
        .sheet(isPresented: $showAddPanel) {
            QAAddPanel(pet: pet, activeCards: $activeCards)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 空状态占位
    private var emptyPlaceholder: some View {
        Button { showAddPanel = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.3))
                Text("添加快捷操作")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 末尾添加按钮
    private var addButton: some View {
        Button { showAddPanel = true } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Text("添加")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 单个 QA 卡片
    @ViewBuilder
    private func qaCell(for card: QACardType) -> some View {
        let count = todayCount(for: card)
        let subtitle = glanceSubtitle(for: card)

        VStack(spacing: 2) {
            Text(card.emoji).font(.system(size: 22))
            Text(card.label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if count > 0 {
                Text("×\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(count > 0 ? Color.goPrimary.opacity(0.4) : .white.opacity(0.08), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            handleTap(card)
        }
        .contextMenu {
            // 护理卡长按：添加待办
            if card == .care {
                Button {
                    showCareReminderSheet = true
                } label: {
                    Label("添加护理待办", systemImage: "calendar.badge.plus")
                }
            }
            // 所有卡片都有「移除」选项
            Button(role: .destructive) {
                removeCard(card)
            } label: {
                Label("移除此卡片", systemImage: "trash")
            }
        }
    }

    // MARK: - 点击处理
    private func handleTap(_ card: QACardType) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if equipFxLimeGlow {
            withAnimation(.easeOut(duration: 0.15)) {
                glowFlash = true
                cardScale = 1.03
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.5)) {
                    glowFlash = false
                    cardScale = 1.0
                }
            }
        }
        
        switch card {
        case .care:
            showCareMenu = true
        case .health:
            onNavigateToHealth?()
        case .expense:
            showExpenseSheet = true
        case .weight:
            showWeightSheet = true
        case .walk:
            PetWalkingManager.shared.start(pet: pet)
        case .feed:
            performCareCheckIn(type: .feeding)
        case .water:
            performCareCheckIn(type: .watering)
        case .potty:
            performPottyCheckIn()
        case .litter:
            performLitterCheckIn()
        case .play:
            performSpecialCareCheckIn(type: .play)
        case .waterChange:
            performSpecialCareCheckIn(type: .waterChange)
        case .filterClean:
            performSpecialCareCheckIn(type: .filterClean)
        case .cageCleaning:
            performSpecialCareCheckIn(type: .cageCleaning)
        case .freeFlight:
            performSpecialCareCheckIn(type: .freeFlight)
        case .misting:
            performSpecialCareCheckIn(type: .misting)
        case .substrateChange:
            performSpecialCareCheckIn(type: .substrateChange)
        }
    }

    // MARK: - 卡片移除
    private func removeCard(_ card: QACardType) {
        withAnimation(.spring(response: 0.3)) {
            activeCards.removeAll { $0 == card }
            QAConfig.exclude(card, for: pet.id)
        }
    }

    // MARK: - 打卡动作

    private func performCareCheckIn(type: CareType) {
        let now = Date()
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log: PetCareLog
        if type == .feeding {
            log = PetCareLog(date: now, type: .feeding, amountGrams: pet.dailyPortionGrams, pet: pet, executorId: eid)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { feedAnimating = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { feedAnimating = false } }
        } else {
            log = PetCareLog(date: now, type: .watering, amountMl: 250, pet: pet, executorId: eid)
        }
        modelContext.insert(log)
        insertEventAndReminder(emoji: type == .feeding ? "🍗" : "💧",
                               label: type == .feeding ? "喂食" : "喂水",
                               insertedID: log.persistentModelID)
        if type == .feeding { QuestManager.shared.recordFirstMeal() }
        let reward = QuestManager.shared.awardAction(type: type == .feeding ? .feed : .water, pet: pet, context: modelContext)
        CareLedgerService.recordPetCare(log: log, pet: pet, source: .quickAction, coconutDelta: CareLedgerService.rewardDelta(reward), context: modelContext)
    }

    private func performPottyCheckIn() {
        let now = Date()
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let isLitter = ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
        let log = PetPottyLog(date: now, type: .perfectPoop, pet: pet, executorId: eid)
        modelContext.insert(log)
        let label = isLitter ? "铲屎" : "便便"
        let emoji = isLitter ? "🪣" : "💩"
        insertEventAndReminder(emoji: emoji, label: label, insertedID: log.persistentModelID)
        let reward = QuestManager.shared.awardAction(type: .potty(isLitter: isLitter), pet: pet, context: modelContext)
        CareLedgerService.recordPetPotty(log: log, pet: pet, source: .quickAction, coconutDelta: CareLedgerService.rewardDelta(reward), context: modelContext)
    }

    private func performLitterCheckIn() {
        let now = Date()
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetCareLog(date: now, type: .litter, pet: pet, executorId: eid)
        modelContext.insert(log)
        insertEventAndReminder(emoji: "🧹", label: "铲屎", insertedID: log.persistentModelID)
        let reward = QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
        CareLedgerService.recordPetCare(log: log, pet: pet, source: .quickAction, coconutDelta: CareLedgerService.rewardDelta(reward), context: modelContext)
    }

    private func performSpecialCareCheckIn(type: CareType) {
        let now = Date()
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let log = PetCareLog(date: now, type: type, pet: pet, executorId: eid)
        modelContext.insert(log)
        insertEventAndReminder(emoji: type.emoji, label: type.label, insertedID: log.persistentModelID)
        let oat: QuestManager.OhanaActionType
        switch type {
        case .play:            oat = .general(humanReward: 10, petReward: 12, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .waterChange:     oat = .general(humanReward: 15, petReward: 20, emoji: type.emoji, title: "\(pet.name) 换水奖励")
        case .filterClean:     oat = .general(humanReward: 25, petReward: 40, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:    oat = .general(humanReward: 15, petReward: 20, emoji: type.emoji, title: "\(pet.name) 清理鸟笼报酬")
        case .freeFlight:      oat = .general(humanReward: 10, petReward: 12, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:         oat = .general(humanReward: 3, petReward: 4, emoji: type.emoji, title: "\(pet.name) 喷水保湿奖励")
        case .substrateChange: oat = .general(humanReward: 15, petReward: 22, emoji: type.emoji, title: "\(pet.name) 换垫材报酬")
        default:               oat = .general(humanReward: 3, petReward: 3, emoji: type.emoji, title: "\(pet.name) 打卡奖励")
        }
        let reward = QuestManager.shared.awardAction(type: oat, pet: pet, context: modelContext)
        CareLedgerService.recordPetCare(log: log, pet: pet, source: .quickAction, coconutDelta: CareLedgerService.rewardDelta(reward), context: modelContext)
    }

    private func performHygieneCheckIn(_ type: HygieneType) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let now = Date()
        let log = PetHygieneLog(date: now, type: type, pet: pet)
        modelContext.insert(log)
        let emoji: String
        let label: String
        switch type {
        case .bath:     emoji = "🛁"; label = "洗澡"
        case .teeth:    emoji = "🦷"; label = "刷牙"
        case .nails:    emoji = "✂️"; label = "剪甲"
        case .brushing: emoji = "🪮"; label = "梳毛"
        case .ears:     emoji = "👂"; label = "清耳"
        }
        insertEventAndReminder(emoji: emoji, label: label, insertedID: log.persistentModelID)
        let reward = QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
        CareLedgerService.record(
            occurredAt: log.date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: type.rawValue,
            source: .quickAction,
            legacyModelName: "PetHygieneLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            context: modelContext
        )
    }

    private func insertEventAndReminder(emoji: String, label: String, insertedID: PersistentIdentifier) {
        let now = Date()
        let event = Event(
            title: "\(emoji) \(pet.name) · \(label)",
            startDate: now, isAllDay: false,
            eventType: EventType.daily.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: pet.id.uuidString
        )
        modelContext.insert(event)
        let reminder = Reminder(event: event, scheduledAt: now)
        reminder.status = "completed"
        modelContext.insert(reminder)
        modelContext.safeSave()

        let ids: [PersistentIdentifier] = [insertedID, event.persistentModelID, reminder.persistentModelID]
        let newUndo = UndoCheckIn(label: label, emoji: emoji, insertedIDs: ids)
        withAnimation(.spring(response: 0.3)) { undoItem = newUndo }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if undoItem?.id == newUndo.id {
                withAnimation(.spring(response: 0.3)) { undoItem = nil }
            }
        }
    }

    // MARK: - Undo toast
    private func undoToast(_ undo: UndoCheckIn) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Text("\(undo.emoji) \(undo.label) 已打卡")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    for pid in undo.insertedIDs {
                        if let m: PetPottyLog   = modelContext.registeredModel(for: pid) { modelContext.delete(m) }
                        else if let m: PetCareLog    = modelContext.registeredModel(for: pid) { modelContext.delete(m) }
                        else if let m: PetHygieneLog = modelContext.registeredModel(for: pid) { modelContext.delete(m) }
                        else if let m: Event         = modelContext.registeredModel(for: pid) { modelContext.delete(m) }
                        else if let m: Reminder      = modelContext.registeredModel(for: pid) { modelContext.delete(m) }
                    }
                    modelContext.safeSave()
                    withAnimation(.spring(response: 0.3)) { undoItem = nil }
                } label: {
                    Text("撤回")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.black.opacity(0.75), in: Capsule())
        }
    }

    // MARK: - 数据计算
    private func todayCount(for card: QACardType) -> Int {
        let cal = Calendar.current
        switch card {
        case .feed:
            return pet.careLogs.filter { $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) }.count
        case .water:
            return pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
        case .potty:
            return pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
        case .litter:
            return pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
        case .walk:
            return pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
        case .play:
            return pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
        case .waterChange:
            return pet.careLogs.filter { $0.type == CareType.waterChange.rawValue && cal.isDateInToday($0.date) }.count
        case .filterClean:
            return pet.careLogs.filter { $0.type == CareType.filterClean.rawValue && cal.isDateInToday($0.date) }.count
        case .cageCleaning:
            return pet.careLogs.filter { $0.type == CareType.cageCleaning.rawValue && cal.isDateInToday($0.date) }.count
        case .freeFlight:
            return pet.careLogs.filter { $0.type == CareType.freeFlight.rawValue && cal.isDateInToday($0.date) }.count
        case .misting:
            return pet.careLogs.filter { $0.type == CareType.misting.rawValue && cal.isDateInToday($0.date) }.count
        case .substrateChange:
            return pet.careLogs.filter { $0.type == CareType.substrateChange.rawValue && cal.isDateInToday($0.date) }.count
        default:
            return 0
        }
    }

    private func glanceSubtitle(for card: QACardType) -> String {
        let cal = Calendar.current
        let today = Date()
        switch card {
        case .feed:
            let n = pet.careLogs.filter { $0.type == CareType.feeding.rawValue && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未记录"
        case .water:
            let n = pet.careLogs.filter { $0.type == CareType.watering.rawValue && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未记录"
        case .potty:
            let n = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未记录"
        case .walk:
            let distM = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }
                .reduce(0.0) { $0 + $1.distanceMeters }
            if distM > 0 {
                return distM >= 1000 ? String(format: "今日 %.1fkm", distM / 1000) : String(format: "今日 %.0fm", distM)
            }
            return "今日未出发"
        case .care:
            let last = pet.hygieneLogs.sorted { $0.date > $1.date }.first
            if let d = last?.date {
                let days = cal.dateComponents([.day], from: d, to: today).day ?? 0
                return days == 0 ? "今日已做" : "\(days)天前"
            }
            return "未记录"
        case .health:
            let vaccLogs = pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.sorted { $0.date > $1.date }
            if let last = vaccLogs.first, let due = cal.date(byAdding: .year, value: 1, to: last.date) {
                let days = cal.dateComponents([.day], from: today, to: due).day ?? 0
                return days >= 0 ? "疫苗余\(days)天" : "疫苗已逾期"
            }
            return "状态良好"
        case .weight:
            if let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                return String(format: "%.1f kg", w.weight)
            }
            return "未记录"
        case .expense:
            let now = Date()
            let comps = cal.dateComponents([.year, .month], from: now)
            let total = pet.expenseLogs
                .filter {
                    let c = cal.dateComponents([.year, .month], from: $0.date)
                    return c.year == comps.year && c.month == comps.month
                }
                .reduce(0.0) { $0 + $1.amount }
            return total > 0 ? "本月 ¥\(Int(total))" : "暂无支出"
        case .litter:
            let n = pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未铲"
        case .play:
            let n = pet.careLogs.filter { $0.type == CareType.play.rawValue && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未玩"
        case .waterChange:
            let last = pet.careLogs.filter { $0.type == CareType.waterChange.rawValue }.sorted { $0.date > $1.date }.first
            if let d = last?.date {
                let days = cal.dateComponents([.day], from: d, to: today).day ?? 0
                return days == 0 ? "今日已换" : "\(days)天前"
            }
            return "未换水"
        case .filterClean:
            let last = pet.careLogs.filter { $0.type == CareType.filterClean.rawValue }.sorted { $0.date > $1.date }.first
            if let d = last?.date {
                let days = cal.dateComponents([.day], from: d, to: today).day ?? 0
                return days == 0 ? "今日已清" : "\(days)天前"
            }
            return "未清理"
        case .cageCleaning:
            let last = pet.careLogs.filter { $0.type == CareType.cageCleaning.rawValue }.sorted { $0.date > $1.date }.first
            if let d = last?.date {
                let days = cal.dateComponents([.day], from: d, to: today).day ?? 0
                return days == 0 ? "今日已清" : "\(days)天前"
            }
            return "未清笼"
        case .freeFlight:
            let n = pet.careLogs.filter { $0.type == CareType.freeFlight.rawValue && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未放飞"
        case .misting:
            let n = pet.careLogs.filter { $0.type == CareType.misting.rawValue && cal.isDateInToday($0.date) }.count
            return n > 0 ? "今日 \(n) 次" : "今日未喷"
        case .substrateChange:
            let last = pet.careLogs.filter { $0.type == CareType.substrateChange.rawValue }.sorted { $0.date > $1.date }.first
            if let d = last?.date {
                let days = cal.dateComponents([.day], from: d, to: today).day ?? 0
                return days == 0 ? "今日已换" : "\(days)天前"
            }
            return "未换垫材"
        }
    }
}

// MARK: - QA 添加面板
struct QAAddPanel: View {
    let pet: Pet
    @Binding var activeCards: [QACardType]
    @Environment(\.dismiss) private var dismiss

    var availableToAdd: [QACardType] {
        QACardType.available(for: pet.species).filter { !activeCards.contains($0) }
    }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("添加快捷操作")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("点击添加到 \(pet.name) 的卡片")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)

                if availableToAdd.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("✅")
                            .font(.system(size: 40))
                        Text("已添加全部可用卡片")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        ForEach(availableToAdd, id: \.rawValue) { card in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    activeCards.append(card)
                                    QAConfig.unexclude(card, for: pet.id)
                                }
                                if availableToAdd.count <= 1 { dismiss() }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(card.emoji).font(.system(size: 28))
                                    Text(card.label)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Legacy alias for compatibility
typealias UnifiedCheckInGrid = SpeciesCheckInGrid
