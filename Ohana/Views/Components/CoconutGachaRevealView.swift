//
//  CoconutGachaRevealView.swift
//  Ohana
//
//  SwiftUI-only prototype for the gacha reveal sequence.
//

import SwiftUI

enum CoconutGachaRevealPhase: String, CaseIterable, Identifiable {
    case idle
    case charging
    case crack
    case reveal
    case settled

    var id: String { rawValue }

    var showsSplitShell: Bool {
        switch self {
        case .idle, .charging:
            return false
        case .crack, .reveal, .settled:
            return true
        }
    }

    var showsPrize: Bool {
        switch self {
        case .idle, .charging, .crack:
            return false
        case .reveal, .settled:
            return true
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .idle:
            return l.tr(zh: "准备敲开", en: "Ready to crack", de: "Bereit zum Öffnen")
        case .charging:
            return l.tr(zh: "蓄力中", en: "Charging", de: "Lädt auf")
        case .crack:
            return l.tr(zh: "咔嚓", en: "Crack", de: "Knack")
        case .reveal:
            return l.tr(zh: "发现奖励", en: "Prize found", de: "Gewinn gefunden")
        case .settled:
            return l.tr(zh: "已收下", en: "Collected", de: "Eingesammelt")
        }
    }

    func subtitle(_ l: L10n, isCollectible: Bool = false) -> String {
        switch self {
        case .idle:
            return l.tr(zh: "可能是款式，也可能是一句小话", en: "A collectible, a tiny reward, or a little note", de: "Eine Figur, eine kleine Belohnung oder eine Notiz")
        case .charging:
            return isCollectible
                ? l.tr(zh: "盲盒里有一张小卡醒来了", en: "A little card wakes inside the box", de: "Eine kleine Karte erwacht in der Box")
                : l.tr(zh: "轻轻摇一摇，听见里面的惊喜", en: "A gentle shake wakes the surprise inside", de: "Ein sanftes Schütteln weckt die Überraschung")
        case .crack:
            return isCollectible
                ? l.tr(zh: "盒子打开了", en: "The box opens", de: "Die Box öffnet sich")
                : l.tr(zh: "椰壳裂开了", en: "The shell is opening", de: "Die Schale öffnet sich")
        case .reveal:
            return isCollectible
                ? l.tr(zh: "剪影卡翻到了眼前", en: "The silhouette card lands up close", de: "Die Silhouettenkarte landet ganz nah")
                : l.tr(zh: "小结果跳出来啦", en: "A little result pops out", de: "Ein kleines Ergebnis springt heraus")
        case .settled:
            return isCollectible
                ? l.tr(zh: "已经放进收藏夹", en: "Added to the collection", de: "Zur Sammlung hinzugefügt")
                : l.tr(zh: "这次结果已经收下", en: "This opening is settled", de: "Dieses Öffnen ist abgeschlossen")
        }
    }
}

enum GachaCollectibleRevealPhase: String, CaseIterable, Identifiable {
    case idle
    case cardPopped
    case flipping
    case revealed
    case secretBurst
    case toyAppearing
    case toyReady
    case cardGone
    case flying
    case settled

    var id: String { rawValue }

    var holdsCollectionUpdate: Bool {
        switch self {
        case .idle, .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying:
            return true
        case .settled:
            return false
        }
    }

    var showsCard: Bool {
        switch self {
        case .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady:
            return true
        case .idle, .cardGone, .flying, .settled:
            return false
        }
    }

    var showsRealAsset: Bool {
        switch self {
        case .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            return true
        case .idle, .cardPopped, .flipping, .revealed:
            return false
        }
    }

    var showsFloatingToy: Bool {
        switch self {
        case .cardGone, .flying:
            return true
        case .idle, .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady, .settled:
            return false
        }
    }
}

struct CoconutGachaRevealView: View {
    let phase: CoconutGachaRevealPhase
    let prizeSymbol: String?
    let rarity: GachaRarity?
    let trigger: Int
    var collectibleItem: GachaItemEntry? = nil
    var revealCardPhase: GachaCollectibleRevealPhase = .idle
    var isNewCollectible: Bool = false
    var onCollectibleCardTap: (() -> Void)? = nil
    var onCollectibleKeepTap: (() -> Void)? = nil

    @AppStorage("appLanguage") private var appLanguage: String = "zh"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color { rarity?.tint ?? Color.goPrimary }
    private var shouldAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldAnimate(isVisible: true)
    }
    private var isCollectibleReveal: Bool { collectibleItem != nil }
    private var stageHeight: CGFloat { isCollectibleReveal ? 304 : 178 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                stageGlow
                if shouldAnimate {
                    CoconutRevealParticles(phase: phase, accent: accent, isCollectible: isCollectibleReveal)
                }
                baseContainerCore
                prizeCore
            }
            .frame(maxWidth: .infinity)
            .frame(height: stageHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAction {
                switch revealCardPhase {
                case .revealed:
                    onCollectibleCardTap?()
                case .toyReady:
                    onCollectibleKeepTap?()
                case .idle, .cardPopped, .flipping, .secretBurst, .toyAppearing, .cardGone, .flying, .settled:
                    break
                }
            }

        }
        .animation(shouldAnimate ? GoMotion.stateChange : GoMotion.reduced, value: phase)
    }

    private var stageGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(phase.showsPrize ? 0.34 : 0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: isCollectibleReveal ? 164 : 132
                    )
                )
                .frame(width: isCollectibleReveal ? 320 : 266, height: isCollectibleReveal ? 320 : 266)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color.ohanaControlFill.opacity(0.42))
                .frame(width: isCollectibleReveal ? 230 : 208, height: 76)
                .offset(y: isCollectibleReveal ? 100 : 64)
                .blur(radius: 14)
        }
        .opacity(phase == .idle ? 0.78 : 1)
    }

    @ViewBuilder
    private var baseContainerCore: some View {
        if let collectibleItem {
            GachaBlindBoxCore(
                assetName: collectibleItem.boxAssetName,
                phase: phase,
                revealCardPhase: revealCardPhase,
                trigger: trigger,
                shouldAnimate: shouldAnimate
            )
        } else {
            coconutCore
        }
    }

    @ViewBuilder
    private var coconutCore: some View {
        if phase.showsSplitShell {
            GachaAssetImage(assetName: "GachaFluffyCoconutOpen", fallbackSymbol: "🥥")
                .frame(width: 168, height: 224)
                .scaleEffect(phase == .crack && shouldAnimate ? 0.94 : 1)
                .offset(y: phase == .crack ? 12 : 10)
                .shadow(color: Color.arkInk.opacity(0.18), radius: 16, x: 0, y: 10) // ui-v4: allow generated coconut asset depth
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            GachaAssetImage(assetName: "GachaFluffyCoconutClosed", fallbackSymbol: "🥥")
                .frame(width: 158, height: 210)
                .rotationEffect(.degrees(phase == .charging && shouldAnimate ? -5 : 0))
                .scaleEffect(phase == .charging && shouldAnimate ? 1.04 : 1)
                .ohanaShake(trigger: trigger, amount: phase == .charging ? 8 : 5, isEnabled: shouldAnimate && phase == .charging)
                .ohanaBreathingGlow(accent: accent, isActive: shouldAnimate && phase == .charging)
                .shadow(color: Color.arkInk.opacity(0.18), radius: 16, x: 0, y: 10) // ui-v4: allow generated coconut asset depth
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    @ViewBuilder
    private var prizeCore: some View {
        if let collectibleItem, phase.showsPrize {
            ZStack {
                GachaCollectibleRevealCardView(
                    item: collectibleItem,
                    phase: revealCardPhase,
                    l: l,
                    shouldAnimate: shouldAnimate,
                    isNewCollectible: isNewCollectible,
                    onTap: onCollectibleCardTap,
                    onKeep: onCollectibleKeepTap
                )

                if revealCardPhase.showsFloatingToy {
                    GachaFloatingCollectibleView(item: collectibleItem, phase: revealCardPhase)
                }
            }
            .transition(.ohanaPop)
        } else if phase.showsPrize {
            VStack(spacing: 6) {
                Text(prizeSymbol ?? "?")
                    .font(.system(size: 58))
                    .frame(width: 94, height: 94)
                    .background(accent.opacity(0.18), in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(accent.opacity(0.36), lineWidth: 1.5)
                    )
                    .shadow(color: accent.opacity(shouldAnimate ? 0.38 : 0.16), radius: 18, x: 0, y: 8) // ui-v4: allow prize pop depth
                    .ohanaPhasePop(trigger: trigger, enabled: shouldAnimate)
                    .ohanaPing(trigger: trigger, accent: accent, isEnabled: shouldAnimate && phase == .reveal)

                Text(rarity?.name(l) ?? l.tr(zh: "奖励", en: "Prize", de: "Gewinn"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.ohanaCardSurface.opacity(0.82), in: Capsule())
                    .ohanaShine(trigger: trigger, cornerRadius: 14, isEnabled: shouldAnimate && phase == .reveal)
            }
            .offset(y: phase == .settled ? -18 : -24)
            .transition(.ohanaPop)
        }
    }

    private var statusText: some View {
        VStack(spacing: 3) {
            Text(phase.title(l))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.opacity)
            Text(subtitleText)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .contentTransition(.opacity)
        }
        .frame(minHeight: 42)
    }

    private var subtitleText: String {
        if isCollectibleReveal, revealCardPhase == .revealed {
            return l.tr(
                zh: "轻点剪影卡，看看真身",
                en: "Tap the silhouette card to reveal the plush",
                de: "Tippe die Silhouettenkarte an, um die Figur zu zeigen"
            )
        }
        if isCollectibleReveal, revealCardPhase == .secretBurst {
            return l.tr(
                zh: "隐藏款的光正在展开",
                en: "The secret glow is unfolding",
                de: "Der geheime Glanz entfaltet sich"
            )
        }
        if isCollectibleReveal, revealCardPhase == .toyAppearing {
            return l.tr(
                zh: "玩偶正在从卡片里出现",
                en: "The plush is appearing from the card",
                de: "Die Figur erscheint aus der Karte"
            )
        }
        if isCollectibleReveal, revealCardPhase == .toyReady {
            return l.tr(
                zh: "点击收下，放进收藏夹",
                en: "Tap collect to add it to your collection",
                de: "Tippe auf Sammeln, um sie abzulegen"
            )
        }
        return phase.subtitle(l, isCollectible: isCollectibleReveal)
    }

    private var accessibilityLabel: String {
        if let collectibleItem, phase.showsPrize {
            if revealCardPhase.showsRealAsset {
                return l.tr(
                    zh: "盲盒开奖，\(phase.title(l))，\(collectibleItem.localizedName(l))",
                    en: "Blind box reveal, \(phase.title(l)), \(collectibleItem.localizedName(l))",
                    de: "Blindbox-Enthüllung, \(phase.title(l)), \(collectibleItem.localizedName(l))"
                )
            }
            return l.tr(
                zh: "盲盒开奖，\(phase.title(l))，剪影卡",
                en: "Blind box reveal, \(phase.title(l)), silhouette card",
                de: "Blindbox-Enthüllung, \(phase.title(l)), Silhouettenkarte"
            )
        }
        if let rarity, let prizeSymbol, phase.showsPrize {
            return l.tr(
                zh: "椰子扭蛋，\(phase.title(l))，奖品 \(prizeSymbol)，\(rarity.name(l))",
                en: "Coconut gacha, \(phase.title(l)), prize \(prizeSymbol), \(rarity.name(l))",
                de: "Kokos-Gacha, \(phase.title(l)), Gewinn \(prizeSymbol), \(rarity.name(l))"
            )
        }
        return l.tr(
            zh: "椰子扭蛋，\(phase.title(l))",
            en: "Coconut gacha, \(phase.title(l))",
            de: "Kokos-Gacha, \(phase.title(l))"
        )
    }

    private var accessibilityHint: String {
        guard isCollectibleReveal else { return "" }
        switch revealCardPhase {
        case .revealed:
            return l.tr(
                zh: "轻点卡片，显示真实玩偶。",
                en: "Tap the card to reveal the plush.",
                de: "Tippe auf die Karte, um die Figur zu zeigen."
            )
        case .toyReady:
            return l.tr(
                zh: "轻点收下按钮，玩偶会进入收藏夹。",
                en: "Tap collect to move the plush into the collection.",
                de: "Tippe auf Sammeln, um die Figur in die Sammlung zu legen."
            )
        case .idle, .cardPopped, .flipping, .secretBurst, .toyAppearing, .cardGone, .flying, .settled:
            return ""
        }
    }
}

struct GachaCollectibleThumbnailView: View {
    let item: GachaItemEntry
    let ownedCount: Int
    var isPulsing: Bool = false

    private var isOwned: Bool { ownedCount > 0 }
    private var assetName: String { isOwned ? item.imageAssetName : item.silhouetteAssetName }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isOwned ? item.rarity.tint.opacity(0.18) : Color.ohanaControlFill)
            GachaAssetImage(assetName: assetName, fallbackSymbol: isOwned ? item.placeholderSymbol : "❔")
                .padding(isOwned ? 3 : 5)
                .saturation(isOwned ? 1 : 0.2)
                .opacity(isOwned ? 1 : 0.68)
            if !isOwned && item.isHidden {
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .shadow(color: Color.arkInk.opacity(0.28), radius: 4, y: 1) // ui-v4: allow mystery placeholder readability
            }
        }
        .frame(width: 52, height: 62)
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(isPulsing ? item.rarity.tint.opacity(0.82) : Color.ohanaCardStroke, lineWidth: isPulsing ? 2 : 1)
        )
        .shadow(color: isPulsing ? item.rarity.tint.opacity(0.32) : Color.clear, radius: 12, y: 5) // ui-v4: allow transient collection target pulse
        .scaleEffect(isPulsing ? 1.08 : 1)
        .ohanaShine(trigger: isPulsing ? item.id : "", cornerRadius: 15, isEnabled: isPulsing)
        .animation(GoMotion.feedback, value: isPulsing)
        .accessibilityHidden(true)
    }
}

private struct GachaBlindBoxCore: View {
    let assetName: String
    let phase: CoconutGachaRevealPhase
    let revealCardPhase: GachaCollectibleRevealPhase
    let trigger: Int
    let shouldAnimate: Bool

    var body: some View {
        GachaAssetImage(assetName: coconutAssetName, fallbackSymbol: "🥥")
            .frame(width: 154, height: 206)
            .scaleEffect(boxScale)
            .offset(y: boxYOffset)
            .opacity(boxOpacity)
            .rotationEffect(.degrees(phase == .charging && shouldAnimate ? -3 : 0))
            .ohanaShake(trigger: trigger, amount: phase == .charging ? 6 : 4, isEnabled: shouldAnimate && phase == .charging)
            .shadow(color: Color.arkInk.opacity(0.18), radius: 16, x: 0, y: 10) // ui-v4: allow fluffy coconut product depth
    }

    private var coconutAssetName: String {
        phase.showsSplitShell || phase.showsPrize ? "GachaFluffyCoconutOpen" : "GachaFluffyCoconutClosed"
    }

    private var boxScale: CGFloat {
        switch revealCardPhase {
        case .idle:
            return phase == .charging ? 1.04 : 1
        case .cardPopped, .flipping:
            return 0.84
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            return 0.72
        }
    }

    private var boxYOffset: CGFloat {
        switch revealCardPhase {
        case .idle:
            return phase.showsPrize ? 74 : 58
        case .cardPopped, .flipping:
            return 96
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            return 108
        }
    }

    private var boxOpacity: Double {
        switch revealCardPhase {
        case .idle:
            return phase == .settled ? 0.28 : 1
        case .cardPopped, .flipping:
            return 0.78
        case .revealed:
            return 0.36
        case .secretBurst, .toyAppearing, .toyReady:
            return 0.20
        case .cardGone, .flying, .settled:
            return 0.12
        }
    }
}

private struct GachaCollectibleRevealCardView: View {
    let item: GachaItemEntry
    let phase: GachaCollectibleRevealPhase
    let l: L10n
    let shouldAnimate: Bool
    let isNewCollectible: Bool
    var onTap: (() -> Void)? = nil
    var onKeep: (() -> Void)? = nil

    @State private var flashlightSweep = false

    private var accent: Color { item.rarity.tint }
    private var isSecretBursting: Bool { phase == .secretBurst }
    private var showsName: Bool { phase.showsRealAsset }
    private var rotation: Double {
        switch phase {
        case .idle, .cardPopped:
            return 0
        case .flipping:
            return 540
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            return 540
        }
    }
    private var scale: CGFloat {
        switch phase {
        case .idle:
            return 0.62
        case .cardPopped:
            return 0.82
        case .flipping:
            return 1.02
        case .revealed:
            return 1.16
        case .secretBurst:
            return 1.26
        case .toyAppearing:
            return 1.20
        case .toyReady:
            return 1.16
        case .cardGone, .flying, .settled:
            return 1.10
        }
    }
    private var yOffset: CGFloat {
        switch phase {
        case .idle:
            return 34
        case .cardPopped:
            return -8
        case .flipping:
            return -16
        case .revealed, .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            return -20
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
                        Button {
                            onKeep?()
                        } label: {
                            Label(l.tr(zh: "收下", en: "Collect", de: "Sammeln"), systemImage: "tray.and.arrow.down.fill")
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.arkInk)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                        .accessibilityLabel(l.tr(zh: "收下玩偶", en: "Collect plush", de: "Figur sammeln"))
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
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        if isNewCollectible && phase.showsCard {
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

                RoundedRectangle(cornerRadius: 30, style: .continuous)
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
        if item.isHidden && (phase == .secretBurst || phase == .toyReady) {
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

                ForEach(0..<18, id: \.self) { index in
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
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                .frame(width: 24, height: 24)
            Circle()
                .fill(Color.goPrimary)
                .frame(width: 8, height: 8)
                .offset(x: 1, y: 1)
        }
        .padding(5)
        .background(Color.arkInk.opacity(0.18), in: Circle())
    }

    @ViewBuilder
    private var newRevealWord: some View {
        if isNewCollectible && phase.showsCard && phase.showsRealAsset {
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
                .ohanaShine(trigger: phase, cornerRadius: 16, isEnabled: shouldAnimate)
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

                ForEach(0..<7, id: \.self) { index in
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
        if shouldAnimate && (phase == .secretBurst || phase == .toyAppearing) {
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

                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var tapCue: some View {
        if isCardTapReady {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(item.isHidden ? Color.arkInk : accent)
                .frame(width: 30, height: 30)
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

private struct GachaFloatingCollectibleView: View {
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
            return 1
        case .flying:
            return 0.42
        case .idle, .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady, .settled:
            return 0.1
        }
    }

    private var xOffset: CGFloat {
        switch phase {
        case .flying:
            return 94
        default:
            return 0
        }
    }

    private var yOffset: CGFloat {
        switch phase {
        case .cardGone:
            return -26
        case .flying:
            return 108
        default:
            return -26
        }
    }

    private var opacity: Double {
        switch phase {
        case .cardGone:
            return 1
        case .flying:
            return 0.72
        default:
            return 0
        }
    }
}

private struct GachaAssetImage: View {
    let assetName: String
    let fallbackSymbol: String

    var body: some View {
        if assetName.isEmpty {
            Text(fallbackSymbol)
                .font(.system(size: 42))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClosedCoconut: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "B7824A"), // ui-v4: allow coconut asset color
                            Color(hex: "6D4325") // ui-v4: allow coconut asset color
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 146, height: 146)
                .shadow(color: Color.arkInk.opacity(0.24), radius: 16, x: 0, y: 12) // ui-v4: allow 2.5d coconut asset depth

            Circle()
                .fill(Color.ohanaPrimaryText.opacity(0.15))
                .frame(width: 50, height: 34)
                .offset(x: -28, y: -36)
                .blur(radius: 4)

            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(Color(hex: "E6C29A").opacity(0.42)) // ui-v4: allow coconut fiber color
                    .frame(width: 3, height: 23)
                    .rotationEffect(.degrees(Double(index) * 30))
                    .offset(y: -68)
            }

            CoconutCrackLine()
                .stroke(Color(hex: "4B2D1B").opacity(0.52), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)) // ui-v4: allow coconut crack ink
                .frame(width: 116, height: 38)
                .offset(y: 2)
        }
    }
}

private enum CoconutShellSide {
    case left
    case right
}

private struct CoconutShellHalf: View {
    let side: CoconutShellSide

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "B7824A"), // ui-v4: allow coconut asset color
                            Color(hex: "5A3621") // ui-v4: allow coconut asset color
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 86, height: 126)

            Capsule()
                .fill(Color(hex: "F3E0C7")) // ui-v4: allow coconut flesh color
                .frame(width: 58, height: 96)
                .offset(x: side == .left ? 10 : -10)

            CoconutCrackLine()
                .stroke(Color(hex: "4B2D1B").opacity(0.42), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)) // ui-v4: allow coconut crack ink
                .frame(width: 44, height: 28)
                .rotationEffect(.degrees(side == .left ? -86 : 86))
                .offset(x: side == .left ? 25 : -25, y: -12)
        }
        .shadow(color: Color.arkInk.opacity(0.18), radius: 12, x: 0, y: 10) // ui-v4: allow 2.5d coconut asset depth
    }
}

private struct CoconutCrackLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.midY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.midY + rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.midY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.midY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.midY - rect.height * 0.02))
        return path
    }
}

private struct CoconutRevealParticles: View {
    let phase: CoconutGachaRevealPhase
    let accent: Color
    var isCollectible: Bool = false

    private var isBursting: Bool {
        phase == .reveal || phase == .settled
    }

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.goYellow : accent)
                    .frame(width: CGFloat(4 + (index % 3)), height: CGFloat(4 + (index % 3)))
                    .offset(
                        x: isBursting ? xOffsets[index] : 0,
                        y: isBursting ? yOffsets[index] + (isCollectible ? -28 : 0) : 24
                    )
                    .opacity(isBursting && phase == .reveal ? 0.82 : 0)
                    .animation(GoMotion.feedback.delay(Double(index) * 0.018), value: phase)
            }
        }
        .allowsHitTesting(false)
    }

    private let xOffsets: [CGFloat] = [-86, -62, -38, -16, 8, 28, 52, 76, -18, 42]
    private let yOffsets: [CGFloat] = [-18, -48, -28, -66, -54, -24, -60, -30, -82, -84]
}

extension GachaRarity {
    var tint: Color {
        switch self {
        case .common:
            return Color.ohanaSecondaryText
        case .rare:
            return Color.goTeal
        case .superRare:
            return Color.goPurple
        case .hidden:
            return Color.goYellow
        }
    }
}

#Preview("Gacha Reveal") {
    let item = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId).commonItems[0]
    let hidden = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId).hiddenItem!

    return VStack(spacing: 18) {
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: item.placeholderSymbol,
            rarity: item.rarity,
            trigger: 1,
            collectibleItem: item,
            revealCardPhase: .revealed,
            isNewCollectible: true
        )
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: hidden.placeholderSymbol,
            rarity: hidden.rarity,
            trigger: 2,
            collectibleItem: hidden,
            revealCardPhase: .secretBurst,
            isNewCollectible: true
        )
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: item.placeholderSymbol,
            rarity: item.rarity,
            trigger: 4,
            collectibleItem: item,
            revealCardPhase: .toyReady
        )
        CoconutGachaRevealView(
            phase: .reveal,
            prizeSymbol: "🥥",
            rarity: .rare,
            trigger: 3
        )
    }
    .padding()
    .background(OhanaAppBackground())
}
