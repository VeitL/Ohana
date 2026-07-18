//
//  CoconutGachaRevealCollectibleCard.swift
//  Ohana
//
//  Collectible card reveal surfaces for gacha openings.
//

import SwiftUI

struct GachaCollectibleThumbnailView: View {
    let item: GachaItemEntry
    let ownedCount: Int
    var isPulsing: Bool = false

    private var isOwned: Bool { ownedCount > 0 }
    private var assetName: String { isOwned ? item.imageAssetName : item.silhouetteAssetName }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .fill(isOwned ? item.rarity.tint.opacity(0.18) : Color.ohanaControlFill)
            GachaAssetImage(assetName: assetName, fallbackSymbol: isOwned ? item.placeholderSymbol : "❔")
                .padding(isOwned ? 3 : 5)
                .saturation(isOwned ? 1 : 0.2)
                .opacity(isOwned ? 1 : 0.68)
            if !isOwned, item.isHidden {
                Image(systemName: "questionmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .shadow(color: Color.arkInk.opacity(0.28), radius: 4, y: 1) // ui-v4: allow mystery placeholder readability
            }
        }
        .frame(width: 52, height: 62)
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .strokeBorder(isPulsing ? item.rarity.tint.opacity(0.82) : Color.ohanaCardStroke, lineWidth: isPulsing ? 2 : 1)
        )
        .shadow(color: isPulsing ? item.rarity.tint.opacity(0.32) : Color.clear, radius: 12, y: 5) // ui-v4: allow transient collection target pulse
        .scaleEffect(isPulsing ? 1.08 : 1)
        .ohanaShine(trigger: isPulsing ? item.id : "", cornerRadius: OhanaRadius.control, isEnabled: isPulsing)
        .animation(GoMotion.feedback, value: isPulsing)
        .accessibilityHidden(true)
    }
}

struct GachaBlindBoxCore: View {
    let assetName: String
    let phase: CoconutGachaRevealPhase
    let revealCardPhase: GachaCollectibleRevealPhase
    let trigger: Int
    let shouldAnimate: Bool

    var body: some View {
        GachaAssetImage(assetName: assetName, fallbackSymbol: "🎁")
            .frame(width: 154, height: 206)
            .scaleEffect(boxScale)
            .offset(y: boxYOffset)
            .opacity(boxOpacity)
            .rotationEffect(.degrees(phase == .charging && shouldAnimate ? -3 : 0))
            .ohanaShake(trigger: trigger, amount: phase == .charging ? 6 : 4, isEnabled: shouldAnimate && phase == .charging)
            .shadow(color: Color.arkInk.opacity(0.18), radius: 16, x: 0, y: 10) // ui-v4: allow fluffy coconut product depth
    }

    private var boxScale: CGFloat {
        switch revealCardPhase {
        case .idle:
            phase == .charging ? 1.04 : 1
        case .cardPopped, .flipping:
            0.84
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            0.72
        }
    }

    private var boxYOffset: CGFloat {
        switch revealCardPhase {
        case .idle:
            phase.showsPrize ? 74 : 58
        case .cardPopped, .flipping:
            96
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            108
        }
    }

    private var boxOpacity: Double {
        switch revealCardPhase {
        case .idle:
            phase == .settled ? 0.28 : 1
        case .cardPopped, .flipping:
            0.78
        case .revealed:
            0.36
        case .secretBurst, .toyAppearing, .toyReady:
            0.20
        case .cardGone, .flying, .settled:
            0.12
        }
    }
}

struct GachaCollectibleRevealCardView: View {
    let item: GachaItemEntry
    let phase: GachaCollectibleRevealPhase
    let l: L10n
    let shouldAnimate: Bool
    let isNewCollectible: Bool
    var onTap: (() -> Void)?
    var onKeep: (() -> Void)?
    var onRepeat: (() -> Void)?

    @State private var flashlightSweep = false

    private var accent: Color { item.rarity.tint }
    private var isSecretBursting: Bool { phase == .secretBurst }
    private var showsName: Bool { phase.showsRealAsset }
    private var rotation: Double {
        switch phase {
        case .idle, .cardPopped:
            0
        case .flipping:
            540
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            540
        }
    }

    private var scale: CGFloat {
        switch phase {
        case .idle:
            0.62
        case .cardPopped:
            0.82
        case .flipping:
            1.02
        case .revealed:
            1.10
        case .secretBurst:
            1.10
        case .toyAppearing:
            1.08
        case .toyReady:
            1.06
        case .cardGone, .flying, .settled:
            1.02
        }
    }

    private var yOffset: CGFloat {
        switch phase {
        case .idle:
            34
        case .cardPopped:
            -8
        case .flipping:
            -16
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            -20
        }
    }

    private var isCardTapReady: Bool { phase == .revealed }
    private var isKeepReady: Bool { phase == .toyReady }

    var body: some View {
        ZStack {
            newBackGlow
            secretHalo
            cardSurface
            flashlightReveal
            revealEffect
            VStack(spacing: 8) {
                HStack {
                    rarityBadge
                    Spacer()
                    ohanaBadge
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .scaleEffect(x: rotation > 90 ? -1 : 1)

                Spacer(minLength: 0)

                GachaAssetImage(
                    assetName: phase.showsRealAsset ? item.imageAssetName : item.silhouetteAssetName,
                    fallbackSymbol: phase.showsRealAsset ? item.placeholderSymbol : "❔"
                )
                .id(phase.showsRealAsset ? "real-\(item.id)" : "silhouette-\(item.id)")
                .padding(.horizontal, phase.showsRealAsset ? 8 : 16)
                .padding(.vertical, phase.showsRealAsset ? 0 : 14)
                .scaleEffect(x: rotation > 90 ? -1 : 1)
                .transition(.scale(scale: 0.86).combined(with: .opacity))

                Spacer(minLength: 0)

                VStack(spacing: 5) {
                    if showsName {
                        Text(item.localizedName(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        Color.clear
                            .frame(height: 16)
                    }

                    if isKeepReady {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                collectibleActionButtons
                            }
                            VStack(spacing: 4) {
                                collectibleActionButtons
                            }
                        }
                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, isKeepReady ? 8 : 12)
                .scaleEffect(x: rotation > 90 ? -1 : 1)
            }
            newRevealWord
            tapCue
        }
        .frame(width: 180, height: 248)
        .opacity(phase.showsCard ? 1 : 0)
        .scaleEffect(scale)
        .offset(y: yOffset)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.58)
        .shadow(color: accent.opacity(shouldAnimate ? 0.34 : 0.14), radius: 22, x: 0, y: 12) // ui-v4: allow reward card 3D lift
        .ohanaShake(trigger: phase, amount: item.isHidden ? 5 : 3, isEnabled: shouldAnimate && isSecretBursting)
        .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .onTapGesture {
            guard isCardTapReady else { return }
            onTap?()
        }
        .allowsHitTesting(isCardTapReady || isKeepReady)
        .ohanaBreathingGlow(accent: accent, isActive: shouldAnimate && (isCardTapReady || isKeepReady))
        .onChange(of: phase) { _, newPhase in
            triggerFlashlightIfNeeded(for: newPhase)
        }
        .onAppear {
            triggerFlashlightIfNeeded(for: phase)
        }
    }

    @ViewBuilder
    private var collectibleActionButtons: some View {
        Button {
            onKeep?()
        } label: {
            Label(l.tr(zh: "收下", en: "Collect", de: "Nehmen"), systemImage: "tray.and.arrow.down.fill")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.arkInk)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "收下玩偶", en: "Collect plush", de: "Figur sammeln"))

        Button {
            onRepeat?()
        } label: {
            Label(l.tr(zh: "再来", en: "Again", de: "Nochmal"), systemImage: "sparkles")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "收下并再来一次", en: "Collect and open another", de: "Sammeln und noch einmal öffnen"))
    }

    private func triggerFlashlightIfNeeded(for newPhase: GachaCollectibleRevealPhase) {
        guard shouldAnimate, newPhase == .toyAppearing || newPhase == .secretBurst else {
            flashlightSweep = false
            return
        }
        flashlightSweep = false
        withAnimation(.easeInOut(duration: item.isHidden ? 1.45 : 0.92)) { // ui-v4: allow one-shot flashlight sweep duration matches reveal timeline
            flashlightSweep = true
        }
    }

    @ViewBuilder
    private var newBackGlow: some View {
        if isNewCollectible, phase.showsCard {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (item.isHidden ? Color.goYellow : Color.goPrimary).opacity(shouldAnimate ? 0.44 : 0.24),
                                accent.opacity(0.20),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 138
                        )
                    )
                    .frame(width: 256, height: 256)

                RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(item.isHidden ? 0.44 : 0.30), lineWidth: 2)
                    .frame(width: 204, height: 272)
                    .blur(radius: 7)
            }
            .opacity(phase == .flipping || phase == .revealed ? 1 : 0.72)
            .scaleEffect(phase == .revealed ? 1.08 : 1)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var secretHalo: some View {
        if item.isHidden, phase == .secretBurst || phase == .toyReady {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.goYellow.opacity(phase == .secretBurst ? 0.58 : 0.24),
                                Color.goCardWhite.opacity(phase == .secretBurst ? 0.26 : 0.10),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 172
                        )
                    )
                    .frame(width: 300, height: 300)

                ForEach(0 ..< 18, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "diamond.fill")
                        .font(.system(size: index.isMultiple(of: 3) ? 18 : 8, weight: .black))
                        .foregroundStyle(index.isMultiple(of: 2) ? Color.goYellow : Color.goCardWhite)
                        .offset(
                            x: secretXOffsets[index],
                            y: secretYOffsets[index]
                        )
                        .opacity(phase == .secretBurst ? 0.94 : 0.20)
                        .scaleEffect(phase == .secretBurst ? 1.22 : 0.72)
                }
            }
            .scaleEffect(phase == .secretBurst ? 1.04 : 0.92)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.62).combined(with: .opacity))
        }
    }

    private var cardSurface: some View {
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [
                        Color.ohanaCardSurface,
                        accent.opacity(item.isHidden ? 0.20 : 0.10),
                        Color.ohanaControlFill
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .strokeBorder(item.isHidden ? Color.goYellow.opacity(0.74) : accent.opacity(0.42), lineWidth: item.isHidden ? 2 : 1.2)
            }
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color.goCardWhite.opacity(0.24),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .clipShape(shape)
                .allowsHitTesting(false)
            }
    }

    private var rarityBadge: some View {
        Text(item.rarity.name(l))
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(item.isHidden ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(item.isHidden ? Color.goYellow : accent.opacity(0.24), in: Capsule())
    }

    private var ohanaBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .strokeBorder(Color.goCardWhite.opacity(0.9), lineWidth: 4)
                .frame(width: 24, height: 24) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            Circle()
                .fill(Color.goPrimary)
                .frame(width: 8, height: 8) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .offset(x: 1, y: 1)
        }
        .padding(5)
        .background(Color.arkInk.opacity(0.18), in: Circle())
    }

    @ViewBuilder
    private var newRevealWord: some View {
        if isNewCollectible, phase.showsCard, phase.showsRealAsset {
            Text("NEW")
                .font(.system(size: item.isHidden ? 58 : 48, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: item.isHidden
                            ? [Color.goYellow, Color.goCardWhite, Color.goYellow]
                            : [Color.goPrimary, Color.goCardWhite, accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Text("NEW")
                        .font(.system(size: item.isHidden ? 58 : 48, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.18))
                        .offset(x: 0, y: 2)
                        .blendMode(.multiply)
                }
                .shadow(color: (item.isHidden ? Color.goYellow : Color.goPrimary).opacity(0.48), radius: 16, x: 0, y: 8) // ui-v4: allow one-shot NEW reveal glow
                .offset(y: item.isHidden ? 50 : 58)
                .scaleEffect(phase == .toyAppearing ? 1.22 : (phase == .secretBurst ? 1.34 : 1.0))
                .opacity(phase == .cardGone || phase == .flying || phase == .settled ? 0 : 0.92)
                .scaleEffect(x: rotation > 90 ? -1 : 1)
                .ohanaPhasePop(trigger: phase, enabled: shouldAnimate)
                .ohanaShine(trigger: phase, cornerRadius: OhanaRadius.control, isEnabled: shouldAnimate)
                .accessibilityLabel("NEW")
        }
    }

    @ViewBuilder
    private var revealEffect: some View {
        if phase == .secretBurst || phase == .toyAppearing || phase == .toyReady {
            ZStack {
                Circle()
                    .strokeBorder(item.isHidden ? Color.goYellow.opacity(0.68) : accent.opacity(0.46), lineWidth: item.isHidden ? 2 : 1.4)
                    .frame(width: phase == .secretBurst ? 176 : (phase == .toyAppearing ? 126 : 148), height: phase == .secretBurst ? 176 : (phase == .toyAppearing ? 126 : 148))
                    .opacity(phase == .secretBurst ? 0.88 : (phase == .toyAppearing ? 0.72 : 0.22))

                ForEach(0 ..< 7, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "plus")
                        .font(.system(size: index.isMultiple(of: 2) ? 12 : 8, weight: .black))
                        .foregroundStyle(item.isHidden ? Color.goYellow : accent)
                        .offset(
                            x: CGFloat([-58, -34, 4, 40, 62, -8, 24][index]),
                            y: CGFloat([-42, 20, -64, -28, 24, 54, 48][index])
                        )
                        .opacity(phase == .secretBurst ? 1 : (phase == .toyAppearing ? 0.88 : 0.28))
                        .scaleEffect(phase == .secretBurst ? 1.42 : (phase == .toyAppearing ? 1.12 : 0.86))
                }
            }
            .scaleEffect(x: rotation > 90 ? -1 : 1)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.72).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var flashlightReveal: some View {
        if shouldAnimate, phase == .secretBurst || phase == .toyAppearing {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.goCardWhite.opacity(item.isHidden ? 0.72 : 0.50),
                                (item.isHidden ? Color.goYellow : accent).opacity(item.isHidden ? 0.44 : 0.28),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: item.isHidden ? 138 : 112
                        )
                    )
                    .frame(width: item.isHidden ? 230 : 190, height: item.isHidden ? 230 : 190)
                    .scaleEffect(flashlightSweep ? 1.10 : 0.58)
                    .opacity(flashlightSweep ? 0.24 : 0.88)

                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.goCardWhite.opacity(item.isHidden ? 0.88 : 0.70),
                                (item.isHidden ? Color.goYellow : accent).opacity(item.isHidden ? 0.38 : 0.24),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: item.isHidden ? 70 : 54, height: 340)
                    .rotationEffect(.degrees(-32))
                    .blur(radius: item.isHidden ? 7 : 6)
                    .offset(
                        x: flashlightSweep ? 118 : -124,
                        y: flashlightSweep ? 24 : -34
                    )
                    .opacity(flashlightSweep ? 0.06 : 0.92)
                    .blendMode(.screen)

                Circle()
                    .strokeBorder(Color.goCardWhite.opacity(item.isHidden ? 0.62 : 0.42), lineWidth: item.isHidden ? 2.2 : 1.4)
                    .frame(width: flashlightSweep ? 172 : 62, height: flashlightSweep ? 172 : 62)
                    .opacity(flashlightSweep ? 0.12 : 0.82)
            }
            .scaleEffect(x: rotation > 90 ? -1 : 1)
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var tapCue: some View {
        if isCardTapReady {
            Image(systemName: "hand.tap.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(item.isHidden ? Color.arkInk : accent)
                .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .background(item.isHidden ? Color.goYellow.opacity(0.92) : Color.ohanaCardSurface.opacity(0.88), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(accent.opacity(0.34), lineWidth: 1)
                }
                .offset(x: 68, y: 98)
                .scaleEffect(shouldAnimate ? 1.04 : 1)
                .accessibilityHidden(true)
        }
    }

    private let secretXOffsets: [CGFloat] = [-98, -76, -48, -18, 18, 52, 82, 102, -92, -62, -24, 10, 44, 74, 96, -42, 0, 36]
    private let secretYOffsets: [CGFloat] = [-78, -34, -96, -56, -106, -72, -28, -86, 34, 78, 48, 92, 54, 24, 76, 106, -128, 118]
}

struct GachaFloatingCollectibleView: View {
    let item: GachaItemEntry
    let phase: GachaCollectibleRevealPhase

    var body: some View {
        GachaAssetImage(assetName: item.imageAssetName, fallbackSymbol: item.placeholderSymbol)
            .frame(width: 146, height: 194)
            .scaleEffect(scale)
            .offset(x: xOffset, y: yOffset)
            .opacity(opacity)
            .shadow(color: item.rarity.tint.opacity(0.26), radius: 18, x: 0, y: 10) // ui-v4: allow flying collectible reward depth
            .allowsHitTesting(false)
    }

    private var scale: CGFloat {
        switch phase {
        case .cardGone:
            1
        case .flying:
            0.42
        case .idle, .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady, .settled:
            0.1
        }
    }

    private var xOffset: CGFloat {
        switch phase {
        case .flying:
            94
        default:
            0
        }
    }

    private var yOffset: CGFloat {
        switch phase {
        case .cardGone:
            -26
        case .flying:
            108
        default:
            -26
        }
    }

    private var opacity: Double {
        switch phase {
        case .cardGone:
            1
        case .flying:
            0.72
        default:
            0
        }
    }
}
