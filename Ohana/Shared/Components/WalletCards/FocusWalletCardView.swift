//
//  FocusWalletCardView.swift
//  Ohana
//
//  Wallet card rendering for the GO Focus home stack.
//

import SwiftUI

enum FocusWalletCardPresentation {
    case home
    case rosterMember
}

struct FocusWalletCardView: View {
    let card: FocusCard
    let namespace: Namespace.ID
    let heroNS: Namespace.ID
    let expandedId: UUID?
    let isHeroExpanded: Bool
    let heroProgress: CGFloat
    let avatarCacheRevision: Int
    var usesMatchedGeometry: Bool = true
    var presentation: FocusWalletCardPresentation = .home
    var expandedCardHeight: CGFloat = K.expandedCardH
    var cardCornerRadius: CGFloat = HeroAnim.stackCardCorner
    var equipFxLimeGlow: Bool = false
    var equipFxPopoutCard: Bool = true

    private let accent = Color(hex: "FF5A3D")
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: true) != .full
    }

    private var showsCardTextBadges: Bool {
        presentation == .home
    }

    private var showsHomeVisibilityStatusBadge: Bool {
        presentation == .home
    }

    private var walletAnimation: Animation {
        shouldReduceWork ? .easeOut(duration: 0.16) : HeroAnim.walletSpring
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let visualProgress = isHeroExpanded ? HomeHeroTransitionProgress(value: heroProgress).clamped : 0
            let avatarVisualProgress = shouldReduceWork ? visualProgress : HomeWalletHeroTimeline.avatarProgress(progress: visualProgress)
            let renderH = OhanaHeroGeometry.lerp(K.cardH, h, progress: visualProgress)
            let avatarEntry = FocusWalletAvatarCache.cachedEntry(for: card.id, signature: card.avatarImageSignature)
                ?? FocusWalletAvatarCache.Entry(
                    image: nil,
                    isTransparent: false,
                    signature: card.avatarImageSignature,
                    isFinal: false
                )
            let avatarImage = avatarEntry.image
            let hasPopout = avatarEntry.isTransparent && avatarImage != nil
            let popoutImage = equipFxPopoutCard
                ? FocusPopoutImageCache.cachedImage(for: card.id, signature: card.cardPopoutImageSignature)
                : nil
            let usesPopoutOverlay = equipFxPopoutCard && avatarVisualProgress > 0.12 && !card.isHuman && card.cardStyleRaw == "popout" && popoutImage != nil
            let usesFullBleed = avatarImage != nil && !avatarEntry.isTransparent && !usesPopoutOverlay

            ZStack(alignment: .topLeading) {
                cardBackground(usesFullBleed: usesFullBleed, progress: visualProgress)

                if card.isElectronicPet {
                    electronicPetCardEffects(w: w, h: renderH, progress: visualProgress)
                        .allowsHitTesting(false)
                }

                maybeMatchedShell(Color.clear)
                    .allowsHitTesting(false)

                if usesFullBleed, let img = avatarImage {
                    cardPhotoLayer(img, w: w, h: renderH, progress: visualProgress)
                        .allowsHitTesting(false)
                }

                backgroundHeadlineLayer(w: w, progress: visualProgress)
                    .opacity(Double(WalletHeroTimeline.smooth(visualProgress, 0.02, 0.16)))

                if !usesFullBleed, !usesPopoutOverlay {
                    leftAvatarContent(
                        avatarImage: avatarImage,
                        hasPopout: hasPopout,
                        avatarProgress: avatarVisualProgress,
                        w: w,
                        h: renderH
                    )
                    .modifier(OptionalHeroArtMatch(
                        cardId: card.id,
                        namespace: namespace,
                        expandedId: expandedId,
                        isEnabled: usesMatchedGeometry
                    ))
                    .frame(
                        width: w * avatarContentWidthRatio(
                            hasPopout: hasPopout,
                            avatarProgress: avatarVisualProgress,
                            contentProgress: visualProgress
                        ),
                        height: h,
                        alignment: .leading
                    )
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                }

                rightInfoColumn(h: renderH, usesFullBleed: usesFullBleed, progress: visualProgress)

                topIdentityBar(usesFullBleed: usesFullBleed)
                    .opacity(1 - Double(WalletHeroTimeline.smooth(visualProgress, 0, 0.12)))
            }
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .petMemorialTone(isActive: card.hasPassedAway)
            .overlay(alignment: .topLeading) {
                if usesPopoutOverlay, let popoutImage {
                    popoutHeroSubject(popoutImage, w: w, h: h, progress: avatarVisualProgress)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomLeading)))
                        .zIndex(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if card.hasPassedAway, showsCardTextBadges {
                    PetMemorialBadge(
                        passedAwayDate: card.passedAwayDate,
                        daysTogether: card.daysTogetherAtPassing
                    )
                    .padding(.top, OhanaHeroGeometry.lerp(12, 16, progress: visualProgress))
                    .padding(.trailing, OhanaHeroGeometry.lerp(12, 16, progress: visualProgress))
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                }
            }
            .animation(GoMotion.page, value: card.hasPassedAway)
        }
        .frame(height: OhanaHeroGeometry.lerp(
            K.cardH,
            expandedCardHeight,
            progress: isHeroExpanded ? HomeHeroTransitionProgress(value: heroProgress).clamped : 0
        ))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: cardBorderWidth)
        )
        .shadow(color: cardBorderShadow, radius: cardBorderShadowRadius, y: 0) // ui-v4: allow equipped/pet-bond card border glow
    }

    @ViewBuilder
    private func maybeMatchedShell(_ content: some View) -> some View {
        if usesMatchedGeometry, expandedId != nil {
            content.matchedGeometryEffect(
                id: HeroShellID(cardId: card.id),
                in: namespace,
                isSource: !(expandedId == card.id)
            )
        } else {
            content
        }
    }

    private var petBondBorderActive: Bool {
        card.petBondCardBorderActive
    }

    private var petBondNameplateActive: Bool {
        card.petBondNameplateActive
    }

    private var cardBorderColor: Color {
        if card.isElectronicPet { return electronicPetTint.opacity(electronicPetNeedsCare ? 0.90 : 0.72) }
        if petBondBorderActive { return Color.goYellow.opacity(0.78) }
        if equipFxLimeGlow { return Color.goPrimary.opacity(0.72) }
        return .white.opacity(0.15)
    }

    private var cardBorderWidth: CGFloat {
        if card.isElectronicPet { return electronicPetNeedsCare ? 1.8 : 1.25 }
        return petBondBorderActive ? 1.8 : (equipFxLimeGlow ? 1.4 : 0.5)
    }

    private var cardBorderShadow: Color {
        if card.isElectronicPet { return electronicPetTint.opacity(electronicPetNeedsCare ? 0.46 : 0.30) }
        if petBondBorderActive { return Color.goYellow.opacity(0.32) }
        if equipFxLimeGlow { return Color.goPrimary.opacity(0.34) }
        return .clear
    }

    private var cardBorderShadowRadius: CGFloat {
        if card.isElectronicPet { return electronicPetNeedsCare ? 24 : 18 }
        return (petBondBorderActive || equipFxLimeGlow) ? 18 : 0
    }

    private var electronicPetState: OasisCritterLifeState {
        OasisCritterLifeState(rawValue: card.critterLifeStateRaw) ?? .healthy
    }

    private var electronicPetNeedsCare: Bool {
        switch electronicPetState {
        case .healthy, .dead:
            false
        case .needsCare, .atRisk, .sick, .critical:
            true
        }
    }

    private var electronicPetTint: Color {
        switch electronicPetState {
        case .healthy:
            Color.goPrimary
        case .dead:
            Color.ohanaTertiaryText
        case .needsCare, .atRisk, .sick, .critical:
            Color.goRed
        }
    }

    private func avatarContentWidthRatio(hasPopout: Bool, avatarProgress: CGFloat, contentProgress: CGFloat) -> CGFloat {
        let collapsed: CGFloat = if hasPopout, !card.isHuman {
            1.0
        } else {
            0.52
        }
        let expanded: CGFloat = card.isHuman ? 0.76 : 0.98
        let progress = hasPopout ? avatarProgress : contentProgress
        return OhanaHeroGeometry.lerp(collapsed, expanded, progress: progress)
    }

    private func backgroundHeadlineLayer(w: CGFloat, progress: CGFloat) -> some View {
        let headlineSize = WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: card.name.count)
        let textScale = OhanaHeroGeometry.lerp(0.24, 1, progress: WalletHeroTimeline.smooth(progress, 0, 1))
        return VStack(spacing: 4) {
            Text(card.name.uppercased())
                .font(.system(
                    size: headlineSize,
                    weight: .black, design: .rounded
                ))
                .foregroundStyle(accent.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.22)
                .frame(maxWidth: .infinity, alignment: .center)
                .scaleEffect(textScale, anchor: .top)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cardBackground(usesFullBleed: Bool, progress: CGFloat) -> some View {
        if !card.themeColorHex.isEmpty {
            let palette = WalletPetCardTheme.meshColors(for: card.themeColorHex)
            if shouldReduceWork {
                LinearGradient(
                    colors: [palette[0], palette[4], palette[8]],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                        SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                    ],
                    colors: palette
                )
            }
        } else {
            LinearGradient(
                colors: [
                    card.color.mix(with: .white, by: 0.22),
                    card.color,
                    card.color.mix(with: .black, by: 0.12)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        let useDarkText = !usesFullBleed && WalletPetCardTheme.prefersDarkForeground(for: card.themeColorHex)
        LinearGradient(
            colors: [
                .clear,
                useDarkText
                    ? Color.goCardWhite.opacity(Double(OhanaHeroGeometry.lerp(0.20, 0.30, progress: progress)))
                    : Color.arkInk.opacity(usesFullBleed ? 0.12 : 0.28)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cardPhotoLayer(_ img: UIImage, w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ZStack {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                WalletCardTrailingReadabilityOverlay(width: w, height: h)
                bottomRightTextShadow(width: w, height: h, isExpanded: true)
            }
            .opacity(Double(progress))

            let photoW = compactPhotoRenderedWidth(img, h: h, cardW: w)
            ZStack(alignment: .leading) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoW, height: h)
                    .clipped()
                    .frame(width: w, height: h, alignment: .leading)
                    .saturation(1.04)
                    .contrast(1.02)
                    .mask(compactPhotoSoftMask(width: w, height: h))
                bottomRightTextShadow(width: w, height: h, isExpanded: false)
            }
            .opacity(Double(1 - progress))
        }
    }

    private func compactPhotoRenderedWidth(_ img: UIImage, h: CGFloat, cardW: CGFloat) -> CGFloat {
        guard img.size.height > 0 else { return cardW }
        return max(cardW, h * img.size.width / img.size.height)
    }

    private func compactPhotoSoftMask(width: CGFloat, height: CGFloat) -> some View {
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

    private func bottomRightTextShadow(width: CGFloat, height: CGFloat, isExpanded: Bool) -> some View {
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

    @ViewBuilder
    private func leftAvatarContent(avatarImage: UIImage?, hasPopout: Bool, avatarProgress: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage, hasPopout {
            transparentAvatar(img, avatarProgress: avatarProgress, w: w, h: h)
        } else if card.isElectronicPet, let catalogId = card.critterCatalogId {
            electronicPetAvatar(catalogId: catalogId, avatarProgress: avatarProgress, w: w, h: h)
        } else if !card.isHuman, let species = card.petSpecies {
            let silSpecies = FocusWalletCardView.normalizeSpecies(species)
            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.16))
                    .frame(
                        width: w * OhanaHeroGeometry.lerp(0.28, 0.32, progress: avatarProgress),
                        height: OhanaHeroGeometry.lerp(24, 26, progress: avatarProgress)
                    )
                    .blur(radius: 10)
                    .offset(y: h * OhanaHeroGeometry.lerp(0.14, 0.18, progress: avatarProgress))
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: card.coatColor,
                    eyeColor: card.eyeColor,
                    patternName: card.patternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(OhanaHeroGeometry.lerp(0.92, 1.0, progress: avatarProgress))
                .frame(
                    width: w * OhanaHeroGeometry.lerp(0.38, 0.78, progress: avatarProgress),
                    height: h * OhanaHeroGeometry.lerp(0.68, 0.90, progress: avatarProgress)
                )
                .offset(
                    x: OhanaHeroGeometry.lerp(0, -w * 0.03, progress: avatarProgress),
                    y: OhanaHeroGeometry.lerp(0, h * 0.04, progress: avatarProgress)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if card.isHuman {
            HumanSilhouetteView(gender: card.humanGender ?? "", accent: .white.opacity(0.78))
                .scaleEffect(0.9)
                .frame(width: w * 0.34, height: h * 0.68)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            Text(card.emoji.isEmpty ? "👤" : card.emoji)
                .font(.system(size: min(w * 0.22, 60)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func transparentAvatar(_ image: UIImage, avatarProgress: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let expandedColumnRatio: CGFloat = card.isHuman ? 0.70 : 0.72
        let collapsedColumnRatio: CGFloat = card.isHuman ? 0.50 : 0.68
        let columnWidth = w * OhanaHeroGeometry.lerp(collapsedColumnRatio, expandedColumnRatio, progress: avatarProgress)
        let avatarOffsetX = OhanaHeroGeometry.lerp(
            w * (card.isHuman ? 0.015 : 0.01),
            w * (card.isHuman ? 0.04 : 0.06),
            progress: avatarProgress
        )
        let avatarHeight: CGFloat
        let avatarOffsetY: CGFloat
        if card.isHuman {
            avatarHeight = h
            avatarOffsetY = 0
        } else {
            avatarHeight = OhanaHeroGeometry.lerp(h * 1.42, h * 0.94, progress: avatarProgress)
            avatarOffsetY = OhanaHeroGeometry.lerp(h * 0.42, -h * 0.02, progress: avatarProgress)
        }

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: columnWidth, height: avatarHeight, alignment: .bottom)
            .frame(width: w, height: h, alignment: .bottomLeading)
            .offset(x: avatarOffsetX, y: avatarOffsetY)
            .allowsHitTesting(false)
            .shadow(color: Color.arkInk.opacity(0.28), radius: 18, x: 0, y: 12) // ui-v4: allow transparent avatar grounding
    }

    private func electronicPetAvatar(catalogId: String, avatarProgress: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let state = electronicPetState
        let tint = electronicPetTint
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(state == .healthy ? 0.38 : 0.58), tint.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: w * 0.24
                    )
                )
                .frame(width: w * 0.46, height: w * 0.46)
                .blur(radius: 10)
            electronicPetOrbitRings(tint: tint, state: state, avatarProgress: avatarProgress, w: w)
            OasisCritterIllustration(
                catalogId: catalogId,
                locked: false,
                size: min(w * OhanaHeroGeometry.lerp(0.36, 0.62, progress: avatarProgress), h * 0.72),
                critter: nil,
                appearanceStageOverride: card.critterAppearanceStage
            )
            .scaleEffect(OhanaHeroGeometry.lerp(0.94, 1.06, progress: avatarProgress))
        }
        .frame(width: w * 0.66, height: h, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .offset(x: w * OhanaHeroGeometry.lerp(0.02, 0.05, progress: avatarProgress))
        .allowsHitTesting(false)
    }

    private func electronicPetCardEffects(w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        let tint = electronicPetTint
        let needsCare = electronicPetNeedsCare
        let leftCenterX = w * OhanaHeroGeometry.lerp(0.24, 0.36, progress: progress)
        let leftCenterY = h * OhanaHeroGeometry.lerp(0.54, 0.48, progress: progress)
        return ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [
                    tint.opacity(needsCare ? 0.42 : 0.30),
                    tint.opacity(needsCare ? 0.18 : 0.12),
                    .clear
                ],
                center: .center,
                startRadius: 6,
                endRadius: min(w, h) * OhanaHeroGeometry.lerp(0.42, 0.62, progress: progress)
            )
            .frame(width: w * 0.82, height: h * 0.98)
            .position(x: leftCenterX, y: leftCenterY)
            .blur(radius: needsCare ? 8 : 12)

            electronicPetConstellation(tint: tint, needsCare: needsCare, w: w, h: h)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.goCardWhite.opacity(needsCare ? 0.18 : 0.24),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: w * 0.70, height: 14)
                .rotationEffect(.degrees(-18))
                .offset(
                    x: w * OhanaHeroGeometry.lerp(-0.20, 0.02, progress: progress),
                    y: h * OhanaHeroGeometry.lerp(0.18, 0.12, progress: progress)
                )
                .opacity(needsCare ? 0.46 : 0.68)
                .blur(radius: 1.5)

            if needsCare {
                RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner - 2, style: .continuous)
                    .strokeBorder(tint.opacity(0.38), style: StrokeStyle(lineWidth: 2, dash: [9, 8], dashPhase: progress * 18))
                    .padding(5)
                    .shadow(color: tint.opacity(0.34), radius: 14, y: 0) // ui-v4: allow critter attention glow
            }
        }
        .frame(width: w, height: h)
        .opacity(card.hasPassedAway ? 0.42 : 1)
    }

    private func electronicPetOrbitRings(tint: Color, state: OasisCritterLifeState, avatarProgress: CGFloat, w: CGFloat) -> some View {
        let isAttention = state != .healthy && state != .dead
        return ZStack {
            Ellipse()
                .strokeBorder(tint.opacity(isAttention ? 0.46 : 0.30), lineWidth: isAttention ? 1.7 : 1.1)
                .frame(width: w * 0.40, height: w * 0.18)
                .rotationEffect(.degrees(OhanaHeroGeometry.lerp(-16, -8, progress: avatarProgress)))
            Ellipse()
                .strokeBorder(Color.goCardWhite.opacity(isAttention ? 0.22 : 0.18), lineWidth: 0.8)
                .frame(width: w * 0.34, height: w * 0.14)
                .rotationEffect(.degrees(OhanaHeroGeometry.lerp(18, 10, progress: avatarProgress)))
            if isAttention {
                Image(systemName: "exclamationmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 22, height: 22) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(tint, in: Circle())
                    .offset(x: w * 0.15, y: -w * 0.12)
                    .shadow(color: tint.opacity(0.46), radius: 10, y: 0) // ui-v4: allow critter alert badge glow
            }
        }
        .opacity(state == .dead ? 0.28 : 1)
    }

    private func electronicPetConstellation(tint: Color, needsCare: Bool, w: CGFloat, h: CGFloat) -> some View {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.12, 0.25, 3.0),
            (0.20, 0.70, 2.4),
            (0.34, 0.18, 2.8),
            (0.44, 0.82, 2.2),
            (0.58, 0.26, 2.6),
            (0.72, 0.62, 2.0)
        ]
        return ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill((needsCare ? tint : Color.goCardWhite).opacity(needsCare ? 0.54 : 0.38))
                    .frame(width: point.2, height: point.2)
                    .position(x: w * point.0, y: h * point.1)
                    .shadow(color: tint.opacity(needsCare ? 0.36 : 0.22), radius: 8, y: 0) // ui-v4: allow critter ambient particles
            }
        }
        .frame(width: w, height: h)
    }

    private func popoutHeroSubject(_ image: UIImage, w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        let artHeight = h * 1.18
        let artWidth = w * 0.70
        let liftedY = OhanaHeroGeometry.lerp(h * 0.10, -h * 0.16, progress: progress)
        let subjectScale = OhanaHeroGeometry.lerp(0.92, shouldReduceWork ? 1.0 : 1.035, progress: progress)
        return ZStack(alignment: .bottomLeading) {
            Ellipse()
                .fill(Color.arkInk.opacity(0.30))
                .frame(width: w * 0.42, height: 34)
                .blur(radius: 18)
                .offset(x: w * 0.08, y: h * 0.88)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: artWidth, height: artHeight, alignment: .bottom)
                .rotation3DEffect(
                    .degrees(shouldReduceWork ? 0 : -4),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .bottomLeading,
                    perspective: 0.54
                )
                .scaleEffect(subjectScale, anchor: .bottomLeading)
                .offset(x: w * 0.015, y: liftedY)
                .shadow(color: Color.arkInk.opacity(0.36), radius: 22, x: 0, y: 16) // ui-v4: allow popout subject depth
        }
        .frame(width: w, height: h, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func rightInfoColumn(h _: CGFloat, usesFullBleed: Bool, progress: CGFloat) -> some View {
        let spacing = OhanaHeroGeometry.lerp(3, 5, progress: progress)
        if presentation == .rosterMember {
            VStack(alignment: .trailing, spacing: spacing) {
                if card.isHuman {
                    humanInfoStack(usesFullBleed: usesFullBleed, progress: progress)
                } else if card.isElectronicPet {
                    electronicPetInfoStack(usesFullBleed: usesFullBleed, progress: progress)
                } else {
                    petInfoStack(usesFullBleed: usesFullBleed, progress: progress)
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 74)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        } else {
            VStack(alignment: .trailing, spacing: spacing) {
                if showsCardTextBadges, card.streak > 1 {
                    Text("🔥 \(card.streak)天连续")
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.goPrimary, in: Capsule())
                }
                Spacer(minLength: 4)
                if card.isHuman {
                    humanInfoStack(usesFullBleed: usesFullBleed, progress: progress)
                } else if card.isElectronicPet {
                    electronicPetInfoStack(usesFullBleed: usesFullBleed, progress: progress)
                } else {
                    petInfoStack(usesFullBleed: usesFullBleed, progress: progress)
                }
                if showsHomeVisibilityStatusBadge {
                    homeVisibilityStatusBadge
                        .padding(.top, 8)
                        .opacity(Double(WalletHeroTimeline.smooth(progress, 0.72, 1)))
                }
            }
            .padding(.trailing, 16).padding(.top, 18).padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func humanInfoStack(usesFullBleed: Bool, progress: CGFloat) -> some View {
        let details = [card.zodiacText, card.mbtiText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let spacing = OhanaHeroGeometry.lerp(3, 5, progress: progress)

        return VStack(alignment: .trailing, spacing: spacing) {
            if showsCardTextBadges, let title = equippedTitleBadge {
                Text(title)
                    .font(.system(size: OhanaHeroGeometry.lerp(9, 11, progress: progress), weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.goPrimary, in: Capsule())
            }
            Text(details.first ?? "OHANA MEMBER")
                .font(.system(size: OhanaHeroGeometry.lerp(15, 20, progress: progress), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if details.count > 1 {
                Text(details.dropFirst().joined(separator: " · "))
                    .font(.system(size: OhanaHeroGeometry.lerp(9, 11, progress: progress), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func petInfoStack(usesFullBleed: Bool, progress: CGFloat) -> some View {
        let meta = [card.ageText, card.humanEquivalentAgeText, card.zodiacText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "未知" }
        let spacing = OhanaHeroGeometry.lerp(3, 5, progress: progress)

        return VStack(alignment: .trailing, spacing: spacing) {
            Text(petTogetherHeadline)
                .font(.system(size: OhanaHeroGeometry.lerp(15, 20, progress: progress), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty {
                Text(hint)
                    .font(.system(size: OhanaHeroGeometry.lerp(8.5, 10.5, progress: progress), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.82))
                    .lineLimit(progress > 0.72 ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
            }

            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(.system(size: OhanaHeroGeometry.lerp(8.5, 10, progress: progress), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.76))
                    .lineLimit(progress > 0.72 ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
            }
        }
    }

    private func electronicPetInfoStack(usesFullBleed: Bool, progress: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: OhanaHeroGeometry.lerp(3, 5, progress: progress)) {
            Text(card.kind.isEmpty ? "Critter" : card.kind)
                .font(.system(size: OhanaHeroGeometry.lerp(15, 20, progress: progress), weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed))
                .lineLimit(1)

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty {
                Text(hint)
                    .font(.system(size: OhanaHeroGeometry.lerp(8.5, 10.5, progress: progress), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if let ageText = card.ageText {
                Text(ageText)
                    .font(.system(size: OhanaHeroGeometry.lerp(8.5, 10, progress: progress), weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.76))
                    .lineLimit(1)
            }
        }
    }

    private var petTogetherHeadline: String {
        card.togetherHeadlineText ?? card.daysTogetherText ?? ""
    }

    private var homeVisibilityStatusBadge: some View {
        let isShown = card.isShownOnHome
        return HStack(spacing: 6) {
            Image(systemName: isShown ? "house.fill" : "house.slash.fill")
                .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(isShown ? "首页显示中" : "未显示在首页")
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(isShown ? Color.arkInk : Color.goCardWhite.opacity(0.74))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isShown ? Color.goLime : Color.arkInk.opacity(0.26), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(isShown ? Color.clear : Color.goCardWhite.opacity(0.16), lineWidth: 0.6)
        )
    }

    private func topIdentityBar(usesFullBleed: Bool) -> some View {
        HStack(spacing: 8) {
            Text(card.name)
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed).opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if showsCardTextBadges, petBondNameplateActive, let nameplate = card.petBondNameplateText {
                Text(nameplate)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.goYellow, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
            if showsCardTextBadges, let title = equippedTitleBadge {
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.goPrimary, in: Capsule())
            }
        }
        .padding(.horizontal, 18)
        .frame(height: K.stackPeekH, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: topIdentityScrimColors(usesFullBleed: usesFullBleed),
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: K.stackPeekH + 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        )
    }

    private var equippedTitleBadge: String? {
        card.isHuman ? card.equippedTitleBadgeText : nil
    }

    private func useDarkCardText(usesFullBleed: Bool) -> Bool {
        !usesFullBleed && WalletPetCardTheme.prefersDarkForeground(for: card.themeColorHex)
    }

    private func cardPrimaryText(usesFullBleed: Bool) -> Color {
        useDarkCardText(usesFullBleed: usesFullBleed) ? Color.arkInk : Color.goCardWhite
    }

    private func cardSecondaryText(usesFullBleed: Bool, opacity: Double) -> Color {
        cardPrimaryText(usesFullBleed: usesFullBleed).opacity(opacity)
    }

    private func topIdentityScrimColors(usesFullBleed: Bool) -> [Color] {
        useDarkCardText(usesFullBleed: usesFullBleed)
            ? [Color.goCardWhite.opacity(0.34), Color.goCardWhite.opacity(0.10), .clear]
            : [Color.arkInk.opacity(0.22), Color.arkInk.opacity(0.06), .clear]
    }

    private static func normalizeSpecies(_ s: String) -> String {
        let l = s.lowercased()
        if s.contains("猫") || l.contains("cat") { return "猫" }
        if s.contains("狗") || l.contains("dog") { return "狗" }
        if s.contains("兔") || l.contains("rabbit") { return "兔子" }
        if s.contains("仓鼠") || l.contains("hamster") { return "仓鼠" }
        if s.contains("鸟") || l.contains("bird") { return "鸟" }
        return s
    }
}

private struct OptionalHeroArtMatch: ViewModifier {
    let cardId: UUID
    let namespace: Namespace.ID
    let expandedId: UUID?
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled, expandedId != nil {
            content.matchedGeometryEffect(
                id: HeroArtID(cardId: cardId),
                in: namespace,
                isSource: !(expandedId == cardId)
            )
        } else {
            content
        }
    }
}
