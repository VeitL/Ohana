//
//  ZenOasisView.swift
//  Ohana
//
//  Zen and standard mode intentionally share the same Oasis presentation.
//

import SwiftUI

@MainActor
struct ZenOasisView: View {
    let snapshot: ZenOasisSnapshot
    let actions: ZenShellActions

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isInjectingEnergy = false
    @State private var isClaimingStarterGift = false
    @State private var injectionPulseToken = 0
    @State private var isVisible = false

    private var l: L10n { L10n(appLanguage) }

    private var interactionMotionBudget: OhanaMotionBudget {
        workloadPolicy.interactionMotionBudget(isVisible: isVisible)
    }

    private var allowsTreeWind: Bool {
        workloadPolicy.ambientMotionBudget(isVisible: isVisible).allowsMotion
    }

    private var usesLiquidGlassLeaves: Bool {
        !reduceTransparency &&
            workloadPolicy.visualEffectsBudget(isVisible: isVisible).usesFullEffects
    }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            if snapshot.isReady {
                OasisHomeTabHost(
                    lifecycle: activeOasisLifecycle,
                    treeSnapshot: standardTreeSnapshot,
                    injectEnergyTrigger: injectionPulseToken,
                    allowsAmbientMotion: allowsTreeWind,
                    allowsInteractionMotion: interactionMotionBudget.allowsMotion,
                    usesFullVisualEffects: usesLiquidGlassLeaves,
                    treeLayoutStyle: .zen,
                    onInjectEnergy: injectEnergy,
                    onOpenShop: actions.onOpenShop,
                    onOpenAchievements: actions.onOpenAchievements,
                    onOpenCritters: actions.onOpenCritters,
                    onOpenGacha: actions.onOpenGacha,
                    onOpenGrowthRoadmap: actions.onOpenGrowthRoadmap
                )
            } else {
                loadingContent
            }

            if snapshot.starterGiftState == .claimable {
                starterGiftCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task {
            await actions.onLoadOasis()
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-oasis-screen")
    }

    private var activeOasisLifecycle: VerticalSolidHomePageLifecycle {
        VerticalSolidHomePageLifecycle(
            isPrepared: true,
            isPreparingForDisplay: false,
            isVisible: true,
            isLive: true
        )
    }

    private var standardTreeSnapshot: OasisTreeRenderSnapshot {
        OasisTreeRenderSnapshot(
            level: snapshot.level,
            progressToNextLevel: snapshot.progressToNextLevel,
            totalEnergy: snapshot.totalEnergy,
            nextLevelThreshold: snapshot.nextLevelThreshold,
            coconutBalance: snapshot.coconutBalance,
            shopLockedLevel: snapshot.shopLockedLevel,
            shopInitialCategory: snapshot.level >= 5 ? .plantDecor : .effect,
            achievementsLockedLevel: snapshot.achievementsLockedLevel,
            crittersLockedLevel: snapshot.crittersLockedLevel,
            gachaLockedLevel: snapshot.gachaLockedLevel
        )
    }

    private var starterGiftCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill") // a11y: allow decorative gift glyph is hidden below
                .font(OhanaFont.adaptive(size: 24, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(
                    zh: "佛系起航礼",
                    en: "Zen welcome gift",
                    de: "Zen-Willkommensgeschenk",
                    es: "Regalo de bienvenida zen",
                    pt: "Presente de boas-vindas zen",
                    fr: "Cadeau de bienvenue Zen",
                    ja: "佛系スタートギフト",
                    ko: "마음 편한 모드 시작 선물",
                    it: "Regalo di benvenuto Zen"
                ))
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "首次添加宠物或植物 · 50 椰子",
                    en: "First pet or plant · 50 coconuts",
                    de: "Erstes Tier oder erste Pflanze · 50 Kokosnüsse",
                    es: "Primera mascota o planta · 50 cocos",
                    pt: "Primeiro pet ou planta · 50 cocos",
                    fr: "Premier animal ou première plante · 50 noix de coco",
                    ja: "最初のペットまたは植物 · ココナッツ50個",
                    ko: "첫 반려동물 또는 식물 · 코코넛 50개",
                    it: "Primo animale o prima pianta · 50 noci di cocco"
                ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                claimStarterGift()
            } label: {
                if isClaimingStarterGift {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(l.tr(
                        zh: "领取",
                        en: "Claim",
                        de: "Abholen",
                        es: "Reclamar",
                        pt: "Resgatar",
                        fr: "Récupérer",
                        ja: "受け取る",
                        ko: "받기",
                        it: "Riscatta"
                    ))
                        .font(OhanaFont.footnote(.bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .disabled(isClaimingStarterGift)
            .accessibilityIdentifier("zen-oasis-starter-gift-action")
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-oasis-starter-gift")
    }

    private var loadingContent: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .frame(height: 360)
            HStack(spacing: 10) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .fill(Color.ohanaCardSurface)
                        .frame(maxWidth: .infinity, minHeight: 112)
                }
            }
        }
        .padding(16)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    private func injectEnergy() {
        guard snapshot.canInjectEnergy, !isInjectingEnergy else { return }
        let feedbackDelay: UInt64 = interactionMotionBudget.usesFullMotion ? 420 : 120
        injectionPulseToken += 1
        isInjectingEnergy = true
        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onInjectEnergy()
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: feedbackDelay)
            isInjectingEnergy = false
        }
    }

    private func claimStarterGift() {
        guard !isClaimingStarterGift else { return }
        isClaimingStarterGift = true
        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onClaimStarterGift()
            isClaimingStarterGift = false
        }
    }
}
