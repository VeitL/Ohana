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

            if snapshot.isReady, snapshot.starterGiftState == .claimed {
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
            } else if snapshot.isReady {
                dormantTree
            } else {
                loadingContent
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

    private var dormantTree: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.08))
                    .frame(width: 190, height: 190)
                Circle()
                    .fill(Color.ohanaCardSurfaceElevated)
                    .frame(width: 126, height: 126)
                Image(systemName: "leaf.fill") // a11y: allow decorative dormant-seed icon; the following text names the state
                    .font(OhanaFont.adaptive(size: 48, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.goPrimary)
                    .rotationEffect(.degrees(-28))
                    .accessibilityHidden(true)
            }

            VStack(spacing: 7) {
                Text(l.tr(
                    zh: "一颗休眠的种子",
                    en: "A sleeping seed",
                    de: "Ein schlafender Samen",
                    es: "Una semilla dormida",
                    pt: "Uma semente adormecida",
                    fr: "Une graine endormie",
                    ja: "眠っている種",
                    ko: "잠든 씨앗",
                    it: "Un seme addormentato"
                ))
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "领取新人礼包后，Lv.0 椰子树会在这里醒来。",
                    en: "Claim the welcome gift and your Lv.0 coconut tree will wake here.",
                    de: "Nach dem Willkommensgeschenk erwacht hier dein Kokosbaum auf Lv. 0.",
                    es: "Reclama el regalo y tu cocotero de Nv. 0 despertará aquí.",
                    pt: "Resgate o presente e seu coqueiro Nv. 0 despertará aqui.",
                    fr: "Récupérez le cadeau et votre cocotier niv. 0 s’éveillera ici.",
                    ja: "ウェルカムギフトを受け取ると、Lv.0の木がここで目覚めます。",
                    ko: "환영 선물을 받으면 Lv.0 코코넛 나무가 여기서 깨어나요.",
                    it: "Riscatta il regalo e l’albero di Lv. 0 si risveglierà qui."
                ))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                OhanaFeedback.light()
                actions.onOpenStarterJourney()
            } label: {
                Label(
                    l.tr(
                        zh: "查看新手任务",
                        en: "View starter tasks",
                        de: "Starter-Aufgaben ansehen",
                        es: "Ver tareas iniciales",
                        pt: "Ver tarefas iniciais",
                        fr: "Voir les tâches de départ",
                        ja: "はじめのタスクを見る",
                        ko: "시작 과제 보기",
                        it: "Vedi attività iniziali"
                    ),
                    systemImage: "sparkles"
                )
                .font(OhanaFont.callout(.black))
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .accessibilityIdentifier("zen-oasis-open-starter-journey")
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-oasis-dormant-tree")
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
}
