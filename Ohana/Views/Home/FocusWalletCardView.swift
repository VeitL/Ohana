//
//  FocusWalletCardView.swift
//  Ohana
//
//  Wallet card rendering for the GO Focus home stack.
//

import SwiftUI

struct FocusWalletCardView: View {
    let card: FocusCard
    let namespace: Namespace.ID
    let heroNS: Namespace.ID
    let expandedId: UUID?
    let isHeroExpanded: Bool
    let avatarCacheRevision: Int

    private let accent = Color(hex: "FF5A3D")
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow: Bool = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard: Bool = true
    @AppStorage(PetBondVaultStore.revisionKey) private var petBondVaultRevision: Int = 0
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    private var walletAnimation: Animation {
        shouldReduceWork ? .easeOut(duration: 0.16) : HeroAnim.walletSpring
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarEntry = FocusWalletAvatarCache.entry(for: card.id, data: card.avatarImageData)
            let avatarImage = avatarEntry.image
            let hasPopout = avatarEntry.isTransparent && avatarImage != nil
            let avatarExpanded = isHeroExpanded
            let popoutImage = FocusPopoutImageCache.image(
                for: card.id,
                data: equipFxPopoutCard ? (card.cardPopoutImageData ?? (card.cardStyleRaw == "popout" ? card.avatarImageData : nil)) : nil
            )
            let usesPopoutOverlay = equipFxPopoutCard && isHeroExpanded && !card.isHuman && card.cardStyleRaw == "popout" && popoutImage != nil
            let usesFullBleed = avatarImage != nil && !avatarEntry.isTransparent && !usesPopoutOverlay

            ZStack(alignment: .topLeading) {
                cardBackground(usesFullBleed: usesFullBleed)

                Color.clear
                    .matchedGeometryEffect(
                        id: HeroShellID(cardId: card.id),
                        in: namespace,
                        isSource: !(expandedId == card.id)
                    )
                    .allowsHitTesting(false)

                if usesFullBleed, let img = avatarImage {
                    cardPhotoLayer(img, w: w, h: h)
                        .allowsHitTesting(false)
                }

                if isHeroExpanded {
                    backgroundHeadlineLayer(w: w)
                }

                if !usesFullBleed && !usesPopoutOverlay {
                    leftAvatarContent(
                        avatarImage: avatarImage,
                        hasPopout: hasPopout,
                        avatarExpanded: avatarExpanded,
                        w: w,
                        h: h
                    )
                    .matchedGeometryEffect(
                        id: HeroArtID(cardId: card.id),
                        in: namespace,
                        isSource: !(expandedId == card.id)
                    )
                    .frame(
                        width: w * avatarContentWidthRatio(hasPopout: hasPopout, avatarExpanded: avatarExpanded),
                        height: h,
                        alignment: .leading
                    )
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                }

                rightInfoColumn(h: h, usesFullBleed: usesFullBleed)

                topIdentityBar(usesFullBleed: usesFullBleed)
                    .opacity(isHeroExpanded ? 0 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous))
            .petMemorialTone(isActive: card.hasPassedAway)
            .overlay(alignment: .topLeading) {
                if usesPopoutOverlay, let popoutImage {
                    popoutHeroSubject(popoutImage, w: w, h: h)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomLeading)))
                        .zIndex(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if card.hasPassedAway {
                    PetMemorialBadge(
                        passedAwayDate: card.passedAwayDate,
                        daysTogether: card.daysTogetherAtPassing
                    )
                    .padding(.top, isHeroExpanded ? 16 : 12)
                    .padding(.trailing, isHeroExpanded ? 16 : 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                }
            }
            .animation(walletAnimation, value: isHeroExpanded)
            .animation(GoMotion.page, value: card.hasPassedAway)
        }
        .frame(height: isHeroExpanded ? K.expandedCardH : K.cardH)
        .overlay(
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: cardBorderWidth)
        )
        .shadow(color: cardBorderShadow, radius: cardBorderShadowRadius, y: 0) // ui-v4: allow equipped/pet-bond card border glow
        .modifier(RealPetTransitionModifier(card: card, heroNS: heroNS))
    }

    private var petBondBorderActive: Bool {
        !card.isHuman &&
        petBondVaultRevision >= 0 &&
        PetBondVaultStore.isUnlocked(.cardBorder, for: card.id)
    }

    private var petBondNameplateActive: Bool {
        !card.isHuman &&
        petBondVaultRevision >= 0 &&
        PetBondVaultStore.isUnlocked(.nameplate, for: card.id)
    }

    private var cardBorderColor: Color {
        if petBondBorderActive { return Color.goYellow.opacity(0.78) }
        if equipFxLimeGlow { return Color.goPrimary.opacity(0.72) }
        return .white.opacity(0.15)
    }

    private var cardBorderWidth: CGFloat {
        petBondBorderActive ? 1.8 : (equipFxLimeGlow ? 1.4 : 0.5)
    }

    private var cardBorderShadow: Color {
        if petBondBorderActive { return Color.goYellow.opacity(0.32) }
        if equipFxLimeGlow { return Color.goPrimary.opacity(0.34) }
        return .clear
    }

    private var cardBorderShadowRadius: CGFloat {
        (petBondBorderActive || equipFxLimeGlow) ? 18 : 0
    }

    private func avatarContentWidthRatio(hasPopout: Bool, avatarExpanded: Bool) -> CGFloat {
        let shouldUseExpandedWidth = hasPopout ? avatarExpanded : isHeroExpanded
        if shouldUseExpandedWidth {
            return card.isHuman ? 0.76 : 0.98
        }
        if hasPopout && !card.isHuman {
            return 1.0
        }
        return 0.52
    }

    private func backgroundHeadlineLayer(w: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(card.name.uppercased())
                .font(.system(
                    size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: card.name.count),
                    weight: .black, design: .rounded
                ))
                .foregroundStyle(accent.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.22)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cardBackground(usesFullBleed: Bool) -> some View {
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
                        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0),  SIMD2(1.0, 1.0)
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
                    ? Color.goCardWhite.opacity(isHeroExpanded ? 0.30 : 0.20)
                    : Color.arkInk.opacity(usesFullBleed ? 0.12 : 0.28)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cardPhotoLayer(_ img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        if isHeroExpanded {
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
        } else {
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
    private func leftAvatarContent(avatarImage: UIImage?, hasPopout: Bool, avatarExpanded: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage, hasPopout {
            if !card.isHuman && !avatarExpanded {
                compactPetUpperBodyAvatar(img, w: w, h: h)
            } else {
                fullTransparentAvatar(img, avatarExpanded: avatarExpanded, w: w, h: h)
            }
        } else if !card.isHuman, let species = card.petSpecies {
            let silSpecies = FocusWalletCardView.normalizeSpecies(species)
            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.16))
                    .frame(width: w * (isHeroExpanded ? 0.32 : 0.28), height: isHeroExpanded ? 26 : 24)
                    .blur(radius: 10)
                    .offset(y: h * (isHeroExpanded ? 0.18 : 0.14))
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: card.coatColor,
                    eyeColor: card.eyeColor,
                    patternName: card.patternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(isHeroExpanded ? 1.0 : 0.92)
                .frame(
                    width: w * (isHeroExpanded ? 0.78 : 0.38),
                    height: h * (isHeroExpanded ? 0.90 : 0.68)
                )
                .offset(x: isHeroExpanded ? -w * 0.03 : 0, y: isHeroExpanded ? h * 0.04 : 0)
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

    private func compactPetUpperBodyAvatar(_ image: UIImage, w: CGFloat, h: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: w * 0.68, height: h * 1.42, alignment: .bottom)
            .frame(width: w, height: h, alignment: .bottomLeading)
            .offset(x: w * 0.01, y: h * 0.42)
            .allowsHitTesting(false)
            .shadow(color: Color.arkInk.opacity(0.28), radius: 18, x: 0, y: 12) // ui-v4: allow transparent avatar grounding
    }

    private func fullTransparentAvatar(_ image: UIImage, avatarExpanded: Bool, w: CGFloat, h: CGFloat) -> some View {
        let expandedColumnRatio: CGFloat = card.isHuman ? 0.70 : 0.72
        let columnWidth = w * (avatarExpanded ? expandedColumnRatio : 0.50)
        let avatarOffsetX = avatarExpanded ? w * (card.isHuman ? 0.04 : 0.06) : w * 0.015
        let avatarHeight = avatarExpanded && !card.isHuman ? h * 0.94 : h
        let avatarOffsetY = avatarExpanded && !card.isHuman ? -h * 0.02 : 0

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: columnWidth, height: avatarHeight, alignment: .bottom)
            .frame(width: w, height: h, alignment: .bottomLeading)
            .offset(x: avatarOffsetX, y: avatarOffsetY)
            .allowsHitTesting(false)
            .shadow(color: Color.arkInk.opacity(0.28), radius: 18, x: 0, y: 12) // ui-v4: allow transparent avatar grounding
    }

    private func popoutHeroSubject(_ image: UIImage, w: CGFloat, h: CGFloat) -> some View {
        let artHeight = h * 1.18
        let artWidth = w * 0.70
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
                .scaleEffect(shouldReduceWork ? 1.0 : 1.035, anchor: .bottomLeading)
                .offset(x: w * 0.015, y: -h * 0.16)
                .shadow(color: Color.arkInk.opacity(0.36), radius: 22, x: 0, y: 16) // ui-v4: allow popout subject depth
        }
        .frame(width: w, height: h, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }

    private func rightInfoColumn(h: CGFloat, usesFullBleed: Bool) -> some View {
        return VStack(alignment: .trailing, spacing: isHeroExpanded ? 5 : 3) {
            if card.streak > 1 {
                Text("🔥 \(card.streak)天连续")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.goPrimary, in: Capsule())
            }
            Spacer(minLength: 4)
            if card.isHuman {
                humanInfoStack(usesFullBleed: usesFullBleed)
            } else {
                petInfoStack(usesFullBleed: usesFullBleed)
            }
            if isHeroExpanded {
                homeVisibilityStatusBadge.padding(.top, 8)
            }
        }
        .padding(.trailing, 16).padding(.top, 18).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func humanInfoStack(usesFullBleed: Bool) -> some View {
        let details = [card.zodiacText, card.mbtiText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .trailing, spacing: isHeroExpanded ? 5 : 3) {
            if let title = equippedTitleBadge {
                Text(title)
                    .font(.system(size: isHeroExpanded ? 11 : 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.goPrimary, in: Capsule())
            }
            Text(details.first ?? "OHANA MEMBER")
                .font(.system(size: isHeroExpanded ? 20 : 15, weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if details.count > 1 {
                Text(details.dropFirst().joined(separator: " · "))
                    .font(.system(size: isHeroExpanded ? 11 : 9, weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func petInfoStack(usesFullBleed: Bool) -> some View {
        let meta = [card.ageText, card.humanEquivalentAgeText, card.zodiacText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "未知" }

        return VStack(alignment: .trailing, spacing: isHeroExpanded ? 5 : 3) {
            Text(petTogetherHeadline)
                .font(.system(size: isHeroExpanded ? 20 : 15, weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let hint = card.personalityHint?.trimmingCharacters(in: .whitespacesAndNewlines),
               !hint.isEmpty {
                Text(hint)
                    .font(.system(size: isHeroExpanded ? 10.5 : 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.82))
                    .lineLimit(isHeroExpanded ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
            }

            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(.system(size: isHeroExpanded ? 10 : 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(cardSecondaryText(usesFullBleed: usesFullBleed, opacity: 0.76))
                    .lineLimit(isHeroExpanded ? 2 : 1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.62)
            }
        }
    }

    private var petTogetherHeadline: String {
        let l = L10n(AppLanguage.code)
        guard card.daysTogetherText != nil else {
            return l.tr(zh: "新成员", en: "New Family", de: "Neue Familie")
        }
        if card.daysTogether < 0 {
            let days = abs(card.daysTogether)
            return l.tr(zh: "\(days) 天后到家", en: "\(days) Days Until Home", de: "\(days) Tage bis Zuhause")
        }
        return l.tr(zh: "相伴 \(card.daysTogether) 天", en: "\(card.daysTogether) Days Together", de: "\(card.daysTogether) Tage zusammen")
    }

    private var homeVisibilityStatusBadge: some View {
        let isShown = card.isHuman
            ? card.isShownOnHome
            : HomeCardVisibility.isPetIDVisible(card.id, raw: hiddenHomePetIDsRaw)
        return HStack(spacing: 6) {
            Image(systemName: isShown ? "house.fill" : "house.slash.fill")
                .font(.system(size: 10, weight: .black))
            Text(isShown ? "首页显示中" : "未显示在首页")
                .font(.system(size: 10, weight: .black, design: .rounded))
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
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(cardPrimaryText(usesFullBleed: usesFullBleed).opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if petBondNameplateActive {
                Text(L10n(AppLanguage.code).tr(zh: "羁绊", en: "Bond", de: "Bindung"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.goYellow, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
            if let title = equippedTitleBadge {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
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
        guard card.isHuman,
              card.id.uuidString == activeHumanId,
              !equippedTitle.isEmpty else { return nil }
        switch equippedTitle {
        case "title_guardian": return "🛡️ 守护者"
        case "title_pioneer": return "🚀 先行者"
        case "title_chef": return "👨‍🍳 首席厨师"
        default: return nil
        }
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
        if s.contains("猫") || l.contains("cat")       { return "猫" }
        if s.contains("狗") || l.contains("dog")       { return "狗" }
        if s.contains("兔") || l.contains("rabbit")    { return "兔子" }
        if s.contains("仓鼠") || l.contains("hamster") { return "仓鼠" }
        if s.contains("鸟") || l.contains("bird")      { return "鸟" }
        return s
    }
}

@MainActor
private enum FocusPopoutImageCache {
    private struct Entry {
        let signature: String
        let image: UIImage?
    }

    private static var entries: [UUID: Entry] = [:]

    static func image(for id: UUID, data: Data?) -> UIImage? {
        guard let data, !data.isEmpty else {
            entries.removeValue(forKey: id)
            return nil
        }
        let signature = FocusWalletAvatarCache.signature(for: data)
        if let cached = entries[id], cached.signature == signature {
            return cached.image
        }
        let raw = UIImage(data: data)
        let image = raw.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? raw
        entries[id] = Entry(signature: signature, image: image)
        return image
    }
}

private struct RealPetTransitionModifier: ViewModifier {
    let card: FocusCard
    let heroNS: Namespace.ID

    func body(content: Content) -> some View {
        if card.isReal && !card.isDummy {
            content
                .matchedTransitionSource(id: card.id as UUID, in: heroNS) { cfg in
                    cfg.clipShape(RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner,
                                                   style: .continuous))
                }
        } else {
            content
        }
    }
}
