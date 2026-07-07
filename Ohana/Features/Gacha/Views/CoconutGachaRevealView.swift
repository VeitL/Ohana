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
            false
        case .crack, .reveal, .settled:
            true
        }
    }

    var showsPrize: Bool {
        switch self {
        case .idle, .charging, .crack:
            false
        case .reveal, .settled:
            true
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .idle:
            l.tr(zh: "准备敲开", en: "Ready to crack", de: "Bereit zum Öffnen")
        case .charging:
            l.tr(zh: "蓄力中", en: "Charging", de: "Lädt auf")
        case .crack:
            l.tr(zh: "咔嚓", en: "Crack", de: "Knack")
        case .reveal:
            l.tr(zh: "发现奖励", en: "Prize found", de: "Gewinn gefunden")
        case .settled:
            l.tr(zh: "已收下", en: "Collected", de: "Eingesammelt")
        }
    }

    func subtitle(_ l: L10n, isCollectible: Bool = false) -> String {
        switch self {
        case .idle:
            l.tr(zh: "可能是款式，也可能是一句小话", en: "A collectible, a tiny reward, or a little note", de: "Eine Figur, eine kleine Belohnung oder eine Notiz")
        case .charging:
            isCollectible
                ? l.tr(zh: "盲盒里有一张小卡醒来了", en: "A little card wakes inside the box", de: "Eine kleine Karte erwacht in der Box")
                : l.tr(zh: "轻轻摇一摇，听见里面的惊喜", en: "A gentle shake wakes the surprise inside", de: "Ein sanftes Schütteln weckt die Überraschung")
        case .crack:
            isCollectible
                ? l.tr(zh: "盒子打开了", en: "The box opens", de: "Die Box öffnet sich")
                : l.tr(zh: "椰壳裂开了", en: "The shell is opening", de: "Die Schale öffnet sich")
        case .reveal:
            isCollectible
                ? l.tr(zh: "剪影卡翻到了眼前", en: "The silhouette card lands up close", de: "Die Silhouettenkarte landet ganz nah")
                : l.tr(zh: "小结果跳出来啦", en: "A little result pops out", de: "Ein kleines Ergebnis springt heraus")
        case .settled:
            isCollectible
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
            true
        case .settled:
            false
        }
    }

    var showsCard: Bool {
        switch self {
        case .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady:
            true
        case .idle, .cardGone, .flying, .settled:
            false
        }
    }

    var showsRealAsset: Bool {
        switch self {
        case .secretBurst, .toyAppearing, .toyReady, .cardGone, .flying, .settled:
            true
        case .idle, .cardPopped, .flipping, .revealed:
            false
        }
    }

    var showsFloatingToy: Bool {
        switch self {
        case .cardGone, .flying:
            true
        case .idle, .cardPopped, .flipping, .revealed, .secretBurst, .toyAppearing, .toyReady, .settled:
            false
        }
    }
}

struct CoconutGachaRevealView: View {
    let phase: CoconutGachaRevealPhase
    let prizeSymbol: String?
    let rarity: GachaRarity?
    let trigger: Int
    var instantCoconutDelta: Int = 0
    var collectibleItem: GachaItemEntry?
    var revealCardPhase: GachaCollectibleRevealPhase = .idle
    var isNewCollectible: Bool = false
    var onCollectibleCardTap: (() -> Void)?
    var onCollectibleKeepTap: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var l: L10n { L10n(appLanguage) }
    private var accent: Color { isCoconutGrandBundle ? Color.goYellow : (rarity?.tint ?? Color.goPrimary) }
    private var shouldAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var isCollectibleReveal: Bool { collectibleItem != nil }
    private var isCoconutGrandBundle: Bool { instantCoconutDelta >= 500 }
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

            RoundedRectangle(cornerRadius: OhanaRadius.sheetLarge, style: .continuous)
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
        } else if phase.showsPrize, isCoconutGrandBundle {
            GachaCoconutGrandBundlePrizeView(
                phase: phase,
                trigger: trigger,
                coconutDelta: instantCoconutDelta,
                shouldAnimate: shouldAnimate,
                l: l
            )
            .offset(y: phase == .settled ? -14 : -20)
            .transition(.ohanaPop)
        } else if phase.showsPrize {
            VStack(spacing: 6) {
                Text(prizeSymbol ?? "?")
                    .font(OhanaFont.adaptive(size: 58))
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
                    .ohanaShine(trigger: trigger, cornerRadius: OhanaRadius.row, isEnabled: shouldAnimate && phase == .reveal)
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
        if isCoconutGrandBundle, phase.showsPrize {
            return l.tr(
                zh: "椰子盲盒，\(phase.title(l))，椰子大礼包，奖励 \(instantCoconutDelta) 颗椰子",
                en: "Coconut blind box, \(phase.title(l)), grand coconut bundle, \(instantCoconutDelta) coconuts",
                de: "Kokos-Blindbox, \(phase.title(l)), großes Kokospaket, \(instantCoconutDelta) Kokosnüsse"
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
