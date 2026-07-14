//
//  HomeWalletCardSupport.swift
//  Ohana
//
//  Shared home wallet card theme, visibility, photo, and creation-preview support.
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Member Hero Card (Figma theme atmosphere + native glass)

/// Shared semantic palette for pet, human, and plant identity cards.
/// The member theme stays concentrated in the middle of the card; the top is
/// deliberately near-white and the bottom deliberately near-black so text
/// contrast is location-based instead of inferred from theme luminance.
struct WalletMemberHeroPalette {
    let highlight: Color
    let light: Color
    let accent: Color
    let deep: Color
    let ink: Color

    init(themeColorHex: String, fallbackColor: Color) {
        let normalized = themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let theme = normalized.isEmpty ? fallbackColor : Color(hex: normalized)
        highlight = theme.mix(with: .white, by: 0.92)
        light = theme.mix(with: .white, by: 0.58)
        accent = theme
        deep = theme.mix(with: .black, by: 0.56)
        ink = theme.mix(with: .black, by: 0.94)
    }

    var border: Color {
        Color.goCardWhite.opacity(0.30)
    }
}

/// One native glass surface sits beneath one static Canvas that reproduces the
/// five oversized theme light fields from the approved Figma Member Hero Card.
/// This keeps the identity card visibly refractive without stacking five live
/// blur views in scrolling and hero-motion surfaces.
struct WalletMemberHeroBackground: View {
    let themeColorHex: String
    var fallbackColor: Color = Color(hex: "D95D55")
    var reducesEffects = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WalletMemberHeroPalette {
        WalletMemberHeroPalette(themeColorHex: themeColorHex, fallbackColor: fallbackColor)
    }

    var body: some View {
        if reducesEffects || reduceTransparency {
            opaqueFallback
        } else {
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(
                        .regular
                            .tint(palette.accent.opacity(colorScheme == .dark ? 0.18 : 0.11))
                            .interactive(false),
                        in: Rectangle()
                    )

                themeAtmosphere

                LinearGradient(
                    stops: [
                        .init(color: Color.goCardWhite.opacity(colorScheme == .dark ? 0.24 : 0.42), location: 0.00),
                        .init(color: Color.clear, location: 0.38),
                        .init(color: Color.arkInk.opacity(colorScheme == .dark ? 0.18 : 0.10), location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var opaqueFallback: some View {
        LinearGradient(
            stops: [
                .init(color: palette.highlight, location: 0.00),
                .init(color: palette.light, location: 0.27),
                .init(color: palette.accent, location: 0.49),
                .init(color: palette.deep, location: 0.69),
                .init(color: palette.ink, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var themeAtmosphere: some View {
        Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: false) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(palette.highlight.opacity(colorScheme == .dark ? 0.62 : 0.74))
            )

            drawLightField(
                context: context,
                size: size,
                rect: CGRect(x: -0.129, y: 0.115, width: 1.261, height: 1.767),
                top: Color.goCardWhite.opacity(0.76),
                bottom: palette.light.opacity(0.74),
                bottomLocation: 0.45
            )
            drawLightField(
                context: context,
                size: size,
                rect: CGRect(x: -0.043, y: 0.316, width: 1.086, height: 1.523),
                top: palette.light.opacity(0.72),
                bottom: palette.accent.opacity(0.78),
                bottomLocation: 0.146467
            )
            drawLightField(
                context: context,
                size: size,
                rect: CGRect(x: 0.096, y: 0.338, width: 0.807, height: 1.273),
                top: palette.light.opacity(0.66),
                bottom: palette.accent.opacity(0.72),
                bottomLocation: 0.226293
            )
            drawLightField(
                context: context,
                size: size,
                rect: CGRect(x: 0.179, y: 0.383, width: 0.643, height: 1.011),
                top: palette.accent.opacity(0.72),
                bottom: palette.deep.opacity(0.80),
                bottomLocation: 0.226293
            )
            drawLightField(
                context: context,
                size: size,
                rect: CGRect(x: -0.286, y: 0.633, width: 1.564, height: 1.523),
                top: palette.deep.opacity(0.78),
                bottom: palette.ink.opacity(0.88),
                bottomLocation: 0.146467
            )
        }
    }

    private func drawLightField(
        context: GraphicsContext,
        size: CGSize,
        rect normalizedRect: CGRect,
        top: Color,
        bottom: Color,
        bottomLocation: CGFloat
    ) {
        let rect = CGRect(
            x: normalizedRect.minX * size.width,
            y: normalizedRect.minY * size.height,
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )
        var layer = context
        layer.addFilter(.blur(radius: max(24, size.width * 0.125)))
        layer.fill(
            Path(ellipseIn: rect),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: top, location: 0),
                    .init(color: bottom, location: min(max(bottomLocation, 0.01), 1))
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
    }
}

/// Plant-card surface based on Figma's "Light Blue Card" reference.
/// The caller owns the card's existing size and corner radius; this view only
/// supplies one noninteractive native glass layer plus the cool-white tint.
struct WalletPlantLightBlueGlassBackground: View {
    var reducesEffects = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    static let rimColor = Color.goCardWhite.opacity(0.92)
    static let rimWidth: CGFloat = 3

    var body: some View {
        if reducesEffects || reduceTransparency {
            opaqueFallback
        } else {
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(
                        .regular
                            .tint(Color(hex: "DCEEFF").opacity(colorScheme == .dark ? 0.24 : 0.18))
                            .interactive(false),
                        in: Rectangle()
                    )

                LinearGradient(
                    stops: [
                        .init(color: Color.goCardWhite.opacity(colorScheme == .dark ? 0.48 : 0.62), location: 0.00),
                        .init(color: Color(hex: "F4F5F7").opacity(colorScheme == .dark ? 0.56 : 0.68), location: 0.46),
                        .init(color: Color(hex: "DCEEFF").opacity(colorScheme == .dark ? 0.42 : 0.50), location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.goCardWhite.opacity(colorScheme == .dark ? 0.20 : 0.34),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 260
                )
            }
        }
    }

    private var opaqueFallback: some View {
        LinearGradient(
            colors: [
                Color.goCardWhite,
                Color(hex: "F4F5F7"),
                Color(hex: "DCEEFF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    .fill(Color.ohanaCardSurface)
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

struct WalletCardVerticalPhotoBlendLayer: View {
    let image: UIImage
    let width: CGFloat
    let height: CGFloat
    let themeColorHex: String
    var shadowDepth: Double = 1

    private var palette: WalletMemberHeroPalette {
        WalletMemberHeroPalette(
            themeColorHex: themeColorHex,
            fallbackColor: Color(hex: "D95D55")
        )
    }

    private var themeTop: Color { palette.light }
    private var themeBottom: Color { palette.ink }

    var body: some View {
        ZStack(alignment: .top) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: width, height: height, alignment: .top)
                .clipped()
                .saturation(1.03)
                .contrast(1.03)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.00), location: 0.00),
                    .init(color: .black.opacity(0.03 * shadowDepth), location: 0.34),
                    .init(color: .black.opacity(0.14 * shadowDepth), location: 0.52),
                    .init(color: .black.opacity(0.34 * shadowDepth), location: 0.70),
                    .init(color: .black.opacity(0.56 * shadowDepth), location: 0.88),
                    .init(color: .black.opacity(0.70 * shadowDepth), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .clear, location: 0.43),
                    .init(color: themeTop.opacity(0.10), location: 0.54),
                    .init(color: themeTop.opacity(0.34), location: 0.66),
                    .init(color: themeBottom.opacity(0.74), location: 0.82),
                    .init(color: themeBottom, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
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

// MARK: - Pet Card Front (Wizard Draft)

/// 添加宠物向导顶部固定预览：数据随表单逐步填充，不依赖 SwiftData `Pet`。
struct WalletPetCardDraftFront: View {
    var name: String
    var species: String
    /// 脚注用品种文案（已解析「其他」+ 自定义）
    var breedFootnote: String
    var avatarImageData: Data?
    /// 父视图异步解码，避免每次重绘时重复 `UIImage(data:)` / 透明检测 // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
    var decodedAvatar: UIImage?
    var decodedAvatarIsTransparent: Bool = false
    var coatColor: Color
    var coatPatternName: String?
    var hasBirthday: Bool
    /// 与 `Pet.ageText` 风格一致的一句年龄（空则脚注省略年龄）
    var ageFootnote: String
    var hasHomeDate: Bool
    var daysTogether: Int
    /// 与主题色选择同步的卡面渐变（与 `Pet.themeColorHex` 一致）
    var themeColorHex: String
    let cornerRadius: CGFloat

    private var headlineText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return trimmed.uppercased()
    }

    private var footnote: String {
        var parts: [String] = []
        if hasBirthday, !ageFootnote.isEmpty { parts.append(ageFootnote) }
        if !breedFootnote.isEmpty { parts.append(breedFootnote) } else if !species.isEmpty { parts.append(species) }
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
            let avatarImage: UIImage? = decodedAvatar
            let isTransparent: Bool = {
                if decodedAvatar != nil { return decodedAvatarIsTransparent }
                return false
            }()
            let hasPopout = isTransparent && avatarImage != nil
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent
            let headlineTextColor = usesFullBleedPhoto ? Color.goCardWhite : Color.arkInk
            let primaryText = Color.goCardWhite
            let secondaryText = primaryText.opacity(0.72)
            let memberPalette = WalletMemberHeroPalette(
                themeColorHex: themeColorHex,
                fallbackColor: Color(hex: "D95D55")
            )

            ZStack {
                WalletMemberHeroBackground(
                    themeColorHex: themeColorHex,
                    fallbackColor: Color(hex: "D95D55")
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                if usesFullBleedPhoto {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.arkInk.opacity(0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                if let img = avatarImage, !isTransparent {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                        .allowsHitTesting(false)
                }

                Text(headlineText)
                    .font(.system(size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: headlineText.count), weight: .black, design: .rounded))
                    .foregroundStyle(headlineTextColor.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                if avatarImage == nil || hasPopout {
                    draftAvatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                        .frame(width: w, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                VStack(alignment: .trailing, spacing: 5) {
                    Spacer()

                    Text(daysTogetherLabel)
                        .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("Days Together")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText.opacity(0.82))

                    Text(footnote)
                        .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    draftBarcode(foreground: primaryText)
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
                    .strokeBorder(memberPalette.border, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func draftAvatarLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage {
            if isTransparent {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.68, height: h * 1.42, alignment: .bottom)
                    .frame(width: w, height: h, alignment: .bottomLeading)
                    .offset(x: w * 0.01, y: h * 0.42)
                    .shadow(color: Color.goCardWhite.opacity(0.50), radius: 3, x: 0, y: 0) // ui-v4: allow transparent draft avatar halo.
                    .shadow(color: Color.arkInk.opacity(0.30), radius: 18, x: 0, y: 12) // ui-v4: allow transparent draft avatar grounding shadow.
            } else {
                EmptyView()
            }
        } else {
            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.16))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 10)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: Pet.canonicalSpeciesKey(species),
                    coatColor: coatColor,
                    patternName: coatPatternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(0.92)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func draftBarcode(foreground: Color = .white) -> some View {
        let pattern: [CGFloat] = [18, 6, 10, 14, 5, 12, 8, 16, 7, 10, 13, 6]
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: OhanaRadius.hairline, style: .continuous)
                        .fill(foreground.opacity(0.95))
                        .frame(width: 2, height: height)
                }
            }
            Text("O H A N A   P E T")
                .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.82))
                .tracking(1.2)
        }
    }
}

// MARK: - Human Silhouette

struct HumanSilhouetteView: View {
    let gender: String
    var accent: Color = .goCardWhite.opacity(0.8)

    private var normalizedGender: String {
        HumanProfileOptions.normalizedGender(gender)
    }

    private var isFemale: Bool {
        normalizedGender == "女"
    }

    private var isNeutral: Bool {
        normalizedGender != "女" && normalizedGender != "男"
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
                    .fill(Color.arkInk.opacity(0.18))
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
                } else if isNeutral {
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: w * 0.48, height: h * 0.46)
                        .position(x: cx, y: h * 0.64)
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
            .shadow(color: Color.arkInk.opacity(0.22), radius: 12, x: 0, y: 8) // ui-v4: allow silhouette grounding shadow inside wallet art.
        }
        .aspectRatio(0.72, contentMode: .fit)
    }
}
