//
//  ZenOasisView.swift
//  Ohana
//
//  The small Oasis surface keeps the coconut loop useful without mounting the
//  full reward dashboard, reports, achievements, or streak sheet.
//

import SwiftUI

@MainActor
struct ZenOasisView: View {
    let snapshot: ZenOasisSnapshot
    let actions: ZenShellActions

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var isInjectingEnergy = false
    @State private var isClaimingStarterGift = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if snapshot.starterGiftState == .claimable {
                        starterGiftCard
                    }

                    if snapshot.isReady {
                        treeCard
                        routeGrid
                    } else {
                        loadingContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(l.tr(
            zh: "Oasis",
            en: "Oasis",
            de: "Oasis",
            es: "Oasis",
            pt: "Oásis",
            fr: "Oasis",
            ja: "オアシス",
            ko: "오아시스",
            it: "Oasi"
        ))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await actions.onLoadOasis()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CoconutBalanceCapsule(
                    balance: snapshot.coconutBalance,
                    showsDeltaAnimation: true,
                    deltaAnimationContext: "zen-oasis"
                )
                .accessibilityLabel(l.tr(
                    zh: "椰子余额 \(snapshot.coconutBalance)",
                    en: "Coconut balance \(snapshot.coconutBalance)",
                    de: "Kokosnuss-Guthaben \(snapshot.coconutBalance)",
                    es: "Saldo de cocos \(snapshot.coconutBalance)",
                    pt: "Saldo de cocos \(snapshot.coconutBalance)",
                    fr: "Solde de noix de coco : \(snapshot.coconutBalance)",
                    ja: "ココナッツ残高 \(snapshot.coconutBalance)",
                    ko: "코코넛 잔액 \(snapshot.coconutBalance)",
                    it: "Saldo noci di cocco \(snapshot.coconutBalance)"
                ))
                .accessibilityIdentifier("zen-oasis-coconut-balance")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-oasis-screen")
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

    private var treeCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(
                        zh: "生命之树",
                        en: "Tree of Life",
                        de: "Baum des Lebens",
                        es: "Árbol de la vida",
                        pt: "Árvore da Vida",
                        fr: "Arbre de vie",
                        ja: "生命の木",
                        ko: "생명의 나무",
                        it: "Albero della vita"
                    ))
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(treeProgressTitle)
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(l.tr(
                    zh: "等级 \(snapshot.level)",
                    en: "Lv. \(snapshot.level)",
                    de: "Stufe \(snapshot.level)",
                    es: "Nivel \(snapshot.level)",
                    pt: "Nível \(snapshot.level)",
                    fr: "Niveau \(snapshot.level)",
                    ja: "レベル \(snapshot.level)",
                    ko: "레벨 \(snapshot.level)",
                    it: "Livello \(snapshot.level)"
                ))
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.goPrimary, in: Capsule())
            }

            BeautifulCoconutTree(
                level: snapshot.level,
                isInjecting: isInjectingEnergy,
                growthProgress: snapshot.progressToNextLevel,
                injectionPulseToken: isInjectingEnergy ? 1 : 0,
                pendingUpgradeCoconutCount: 0,
                dailyCoconutCount: 0,
                allowsAmbientMotion: false,
                harvestedCoconuts: []
            )
            .frame(height: 212)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            ProgressView(value: snapshot.progressToNextLevel)
                .tint(Color.goPrimary)
                .accessibilityLabel(l.tr(
                    zh: "成长进度",
                    en: "Growth progress",
                    de: "Wachstumsfortschritt",
                    es: "Progreso de crecimiento",
                    pt: "Progresso de crescimento",
                    fr: "Progression de la croissance",
                    ja: "成長の進み具合",
                    ko: "성장 진행도",
                    it: "Progresso di crescita"
                ))
                .accessibilityValue("\(Int(snapshot.progressToNextLevel * 100))%")

            Button {
                injectEnergy()
            } label: {
                HStack(spacing: 8) {
                    if isInjectingEnergy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.ohanaPrimaryActionText)
                    } else {
                        Image(systemName: "bolt.fill") // a11y: allow adjacent text labels the energy Button
                    }
                    Text(l.tr(
                        zh: "注入能量 · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) 椰子",
                        en: "Inject energy · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) coconuts",
                        de: "Energie · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) Kokosnüsse",
                        es: "Inyectar energía · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) cocos",
                        pt: "Injetar energia · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) cocos",
                        fr: "Injecter de l’énergie · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) noix de coco",
                        ja: "エネルギーを注入 · ココナッツ\(OasisTreeEnergyInjectionPolicy.starterPackageCost)個",
                        ko: "에너지 주입 · 코코넛 \(OasisTreeEnergyInjectionPolicy.starterPackageCost)개",
                        it: "Inietta energia · \(OasisTreeEnergyInjectionPolicy.starterPackageCost) noci di cocco"
                    ))
                    .font(OhanaFont.callout(.bold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.goPrimary)
            .disabled(!snapshot.canInjectEnergy || isInjectingEnergy)
            .accessibilityIdentifier("zen-oasis-inject-energy-action")
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-oasis-tree-card")
    }

    private var routeGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            routeButton(
                title: l.tr(
                    zh: "商店",
                    en: "Shop",
                    de: "Shop",
                    es: "Tienda",
                    pt: "Loja",
                    fr: "Boutique",
                    ja: "ショップ",
                    ko: "상점",
                    it: "Negozio"
                ),
                icon: "bag.fill",
                identifier: "shop",
                lockedLevel: snapshot.shopLockedLevel,
                action: actions.onOpenShop
            )
            routeButton(
                title: l.tr(
                    zh: "扭蛋",
                    en: "Gacha",
                    de: "Gacha",
                    es: "Gacha",
                    pt: "Gacha",
                    fr: "Gacha",
                    ja: "ガチャ",
                    ko: "뽑기",
                    it: "Gacha"
                ),
                icon: "capsule.fill",
                identifier: "gacha",
                lockedLevel: snapshot.gachaLockedLevel,
                action: actions.onOpenGacha
            )
            routeButton(
                title: l.tr(
                    zh: "电子宠物",
                    en: "Critters",
                    de: "Critter",
                    es: "Mascotas virtuales",
                    pt: "Bichinhos virtuais",
                    fr: "Compagnons virtuels",
                    ja: "電子ペット",
                    ko: "전자 펫",
                    it: "Cuccioli virtuali"
                ),
                icon: "pawprint.fill",
                identifier: "critters",
                lockedLevel: snapshot.crittersLockedLevel,
                action: actions.onOpenCritters
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zen-oasis-route-grid")
    }

    private func routeButton(
        title: String,
        icon: String,
        identifier: String,
        lockedLevel: Int?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: lockedLevel == nil ? icon : "lock.fill")
                    .font(OhanaFont.adaptive(size: 23, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                    .frame(height: 28)
                Text(title)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(lockedLevel.map {
                    l.tr(
                        zh: "Lv.\($0) 解锁",
                        en: "Unlocks at Lv.\($0)",
                        de: "Ab Lv.\($0)",
                        es: "Se desbloquea en Nv.\($0)",
                        pt: "Desbloqueia no Nv.\($0)",
                        fr: "Débloqué au niv. \($0)",
                        ja: "レベル\($0)で解放",
                        ko: "레벨 \($0)에서 잠금 해제",
                        it: "Si sblocca al liv. \($0)"
                    )
                } ?? l.tr(
                    zh: "打开",
                    en: "Open",
                    de: "Öffnen",
                    es: "Abrir",
                    pt: "Abrir",
                    fr: "Ouvrir",
                    ja: "開く",
                    ko: "열기",
                    it: "Apri"
                ))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(lockedLevel != nil)
        .accessibilityLabel(title)
        .accessibilityHint(lockedLevel.map {
            l.tr(
                zh: "等级 \($0) 解锁",
                en: "Unlocks at level \($0)",
                de: "Wird auf Level \($0) freigeschaltet",
                es: "Se desbloquea en el nivel \($0)",
                pt: "Desbloqueia no nível \($0)",
                fr: "Se débloque au niveau \($0)",
                ja: "レベル\($0)で解放されます",
                ko: "레벨 \($0)에서 잠금 해제",
                it: "Si sblocca al livello \($0)"
            )
        } ?? l.tr(
            zh: "打开 \(title)",
            en: "Open \(title)",
            de: "\(title) öffnen",
            es: "Abrir \(title)",
            pt: "Abrir \(title)",
            fr: "Ouvrir \(title)",
            ja: "\(title)を開く",
            ko: "\(title) 열기",
            it: "Apri \(title)"
        ))
        .accessibilityIdentifier("zen-oasis-\(identifier)-action")
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
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    private var treeProgressTitle: String {
        if snapshot.level >= 10 {
            return l.tr(
                zh: "已达到最高等级",
                en: "Maximum level reached",
                de: "Maximale Stufe erreicht",
                es: "Nivel máximo alcanzado",
                pt: "Nível máximo alcançado",
                fr: "Niveau maximal atteint",
                ja: "最高レベルに達しました",
                ko: "최고 레벨에 도달했어요",
                it: "Livello massimo raggiunto"
            )
        }
        if snapshot.nextLevelThreshold > 0 {
            return l.tr(
                zh: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) 能量",
                en: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) energy",
                de: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) Energie",
                es: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) de energía",
                pt: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) de energia",
                fr: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) d’énergie",
                ja: "エネルギー \(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold)",
                ko: "에너지 \(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold)",
                it: "\(snapshot.totalEnergy) / \(snapshot.nextLevelThreshold) di energia"
            )
        }
        return "\(Int(snapshot.progressToNextLevel * 100))%"
    }

    private func injectEnergy() {
        guard snapshot.canInjectEnergy, !isInjectingEnergy else { return }
        isInjectingEnergy = true
        Task {
            await OhanaFrameScheduler.waitAfterNextFrame()
            await actions.onInjectEnergy()
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
