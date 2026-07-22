import SwiftUI

enum GrowthUnlockStageDisplayState: Equatable {
    case unlocked
    case next(missingLevels: Int)
    case locked(missingLevels: Int)
}

enum GrowthUnlockStageExplorerPolicy {
    static func defaultStageID(
        currentLevel: Int,
        preferredStageID: GrowthUnlockStageID? = nil
    ) -> GrowthUnlockStageID {
        if let preferredStageID,
           GrowthUnlockPolicy.stages.contains(where: { $0.id == preferredStageID }) {
            return preferredStageID
        }
        return GrowthUnlockPolicy.nextLockedStep(currentLevel: currentLevel)?.id
            ?? GrowthUnlockPolicy.currentStep(currentLevel: currentLevel).id
    }

    static func displayState(
        for step: GrowthUnlockStep,
        currentLevel: Int
    ) -> GrowthUnlockStageDisplayState {
        if currentLevel >= step.requiredLevel {
            return .unlocked
        }

        let missingLevels = max(0, step.requiredLevel - currentLevel)
        if GrowthUnlockPolicy.nextLockedStep(currentLevel: currentLevel)?.id == step.id {
            return .next(missingLevels: missingLevels)
        }
        return .locked(missingLevels: missingLevels)
    }

    static func unlockedStageCount(currentLevel: Int) -> Int {
        GrowthUnlockPolicy.stages.count(where: { currentLevel >= $0.requiredLevel })
    }
}

struct GrowthUnlockLoopCard: View {
    let currentLevel: Int
    let appLanguage: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var l: L10n { L10n(appLanguage) }
    private var steps: [LoopStep] {
        [
            LoopStep(
                id: 0,
                icon: "checkmark.circle.fill",
                title: l.tr(
                    zh: "照护",
                    en: "Care",
                    de: "Pflegen",
                    es: "Cuidar",
                    pt: "Cuidar",
                    fr: "Prendre soin",
                    ja: "お世話",
                    ko: "돌보기",
                    it: "Cura"
                ),
                subtitle: l.tr(
                    zh: "赚椰子",
                    en: "Earn coconuts",
                    de: "Kokos sammeln",
                    es: "Gana cocos",
                    pt: "Ganhe cocos",
                    fr: "Gagner des cocos",
                    ja: "ココナッツ獲得",
                    ko: "코코넛 모으기",
                    it: "Ottieni cocchi"
                )
            ),
            LoopStep(
                id: 1,
                icon: "bolt.fill",
                title: l.tr(
                    zh: "注入",
                    en: "Feed",
                    de: "Speisen",
                    es: "Inyectar",
                    pt: "Injetar",
                    fr: "Nourrir",
                    ja: "注入",
                    ko: "주입",
                    it: "Inietta"
                ),
                subtitle: l.tr(
                    zh: "树能量",
                    en: "Tree energy",
                    de: "Baumenergie",
                    es: "Energía del árbol",
                    pt: "Energia da árvore",
                    fr: "Énergie de l’arbre",
                    ja: "木のエネルギー",
                    ko: "나무 에너지",
                    it: "Energia dell’albero"
                )
            ),
            LoopStep(
                id: 2,
                icon: "sparkles",
                title: l.tr(
                    zh: "点亮",
                    en: "Unlock",
                    de: "Freischalten",
                    es: "Desbloquear",
                    pt: "Desbloquear",
                    fr: "Débloquer",
                    ja: "解放",
                    ko: "해금",
                    it: "Sblocca"
                ),
                subtitle: l.tr(
                    zh: "新玩法",
                    en: "New play",
                    de: "Neues entdecken",
                    es: "Nuevas funciones",
                    pt: "Novos recursos",
                    fr: "Nouveautés",
                    ja: "新しい機能",
                    ko: "새 기능",
                    it: "Nuove funzioni"
                )
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l.tr(
                    zh: "照护，让树长大",
                    en: "Care. Grow. Unlock.",
                    de: "Pflegen. Wachsen. Öffnen.",
                    es: "Cuida. Crece. Desbloquea.",
                    pt: "Cuide. Cresça. Desbloqueie.",
                    fr: "Soignez. Grandissez. Débloquez.",
                    ja: "お世話して、育てて、解放。",
                    ko: "돌보고, 키우고, 열어 보세요.",
                    it: "Cura. Cresci. Sblocca."
                ))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

                Spacer(minLength: 8)

                Text("Lv.\(currentLevel)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.ohanaControlFill, in: Capsule())
            }

            if dynamicTypeSize.isAccessibilitySize {
                verticalLoop
            } else {
                horizontalLoop
            }

            Label(footerText, systemImage: currentLevel == 0 ? "gift.fill" : "bolt.circle.fill")
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.goPrimary.opacity(0.12), Color.ohanaCardSurface, Color.ohanaCardSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var horizontalLoop: some View {
        HStack(spacing: 7) {
            ForEach(steps) { step in
                loopNode(step, horizontal: true)

                if step.id < steps.count - 1 {
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 9, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
            }
        }
    }

    private var verticalLoop: some View {
        VStack(spacing: 7) {
            ForEach(steps) { step in
                loopNode(step, horizontal: false)

                if step.id < steps.count - 1 {
                    Image(systemName: "chevron.down").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 9, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
            }
        }
    }

    private func loopNode(_ step: LoopStep, horizontal: Bool) -> some View {
        Group {
            if horizontal {
                VStack(spacing: 6) {
                    loopIcon(step)
                    loopText(step, alignment: .center)
                }
            } else {
                HStack(spacing: 10) {
                    loopIcon(step)
                    loopText(step, alignment: .leading)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: horizontal ? .center : .leading)
        .padding(.horizontal, horizontal ? 6 : 12)
        .padding(.vertical, 8)
        .background(
            Color.ohanaControlFill.opacity(0.72),
            in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func loopIcon(_ step: LoopStep) -> some View {
        Image(systemName: step.icon)
            .font(OhanaFont.adaptive(size: 13, weight: .black))
            .foregroundStyle(Color.goPrimary)
            .frame(width: 30, height: 30) // a11y: allow non-interactive diagram glyph
            .background(Color.goPrimary.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }

    private func loopText(_ step: LoopStep, alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 1) {
            Text(step.title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(step.subtitle)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(alignment)
                .lineLimit(horizontalLineLimit(for: alignment))
                .minimumScaleFactor(0.72)
        }
    }

    private func horizontalLineLimit(for alignment: TextAlignment) -> Int? {
        alignment == .center ? 2 : nil
    }

    private var footerText: String {
        if currentLevel == 0 {
            return l.tr(
                zh: "起步礼正好够 5 次注入：\(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                en: "The starter gift covers 5 feeds: \(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                de: "Das Startgeschenk reicht für 5 Einspeisungen: \(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                es: "El regalo inicial cubre 5 inyecciones: \(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                pt: "O presente inicial cobre 5 injeções: \(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                fr: "Le cadeau de départ couvre 5 apports : \(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                ja: "スタートギフトで5回注入：\(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                ko: "시작 선물로 5회 주입: \(StarterGiftPolicy.giftAmount)🥥 → Lv.1",
                it: "Il regalo iniziale copre 5 iniezioni: \(StarterGiftPolicy.giftAmount)🥥 → Lv.1"
            )
        }

        return l.tr(
            zh: "每次 \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) 能量；到级自动开放。",
            en: "Each feed: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) energy. Levels open automatically.",
            de: "Je Einspeisung: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) Energie. Stufen öffnen automatisch.",
            es: "Cada inyección: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) de energía. Se abre automáticamente.",
            pt: "Cada injeção: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) de energia. Abre automaticamente.",
            fr: "Chaque apport : \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) d’énergie. Ouverture automatique.",
            ja: "1回：\(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP)エネルギー。到達時に自動解放。",
            ko: "1회: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → 에너지 \(OasisTreeEnergyInjectionPolicy.starterPackageXP). 레벨 도달 시 자동 해금.",
            it: "Ogni iniezione: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 → \(OasisTreeEnergyInjectionPolicy.starterPackageXP) energia. Apertura automatica."
        )
    }
}

struct GrowthUnlockStageExplorer: View {
    let currentLevel: Int
    let appLanguage: String
    let showsHeader: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var selectedStageID: GrowthUnlockStageID

    private var l: L10n { L10n(appLanguage) }
    private var stages: [GrowthUnlockStep] { GrowthUnlockPolicy.roadmapStages() }
    private var selectedStep: GrowthUnlockStep {
        stages.first(where: { $0.id == selectedStageID }) ?? stages[0]
    }
    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    init(
        currentLevel: Int,
        appLanguage: String,
        initialStageID: GrowthUnlockStageID? = nil,
        showsHeader: Bool = true
    ) {
        self.currentLevel = currentLevel
        self.appLanguage = appLanguage
        self.showsHeader = showsHeader
        _selectedStageID = State(initialValue: GrowthUnlockStageExplorerPolicy.defaultStageID(
            currentLevel: currentLevel,
            preferredStageID: initialStageID
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                explorerHeader
            }

            levelRail
            selectedStageCard
                .ohanaContextHandoff(selectedStageID, direction: .fromTrailing)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .accessibilityIdentifier("growth-unlock-stage-explorer")
    }

    private var explorerHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(
                    zh: "点亮成长路线",
                    en: "Light up the path",
                    de: "Wachstumsweg erhellen",
                    es: "Ilumina el camino",
                    pt: "Ilumine o caminho",
                    fr: "Éclairez le parcours",
                    ja: "成長ルートを灯す",
                    ko: "성장 경로 밝히기",
                    it: "Illumina il percorso"
                ))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "左右滑动，点一级看看",
                    en: "Swipe, then tap a level",
                    de: "Wischen und Stufe antippen",
                    es: "Desliza y toca un nivel",
                    pt: "Deslize e toque em um nível",
                    fr: "Balayez puis touchez un niveau",
                    ja: "スワイプしてレベルをタップ",
                    ko: "밀어서 레벨을 탭하세요",
                    it: "Scorri e tocca un livello"
                ))
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 8)

            Text("\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel))/\(stages.count)")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.goPrimary.opacity(0.12), in: Capsule())
                .accessibilityLabel(l.tr(
                    zh: "已开放 \(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) 个，共 \(stages.count) 个",
                    en: "\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) of \(stages.count) open",
                    de: "\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) von \(stages.count) offen",
                    es: "\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) de \(stages.count) abiertos",
                    pt: "\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) de \(stages.count) abertos",
                    fr: "\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) sur \(stages.count) ouverts",
                    ja: "\(stages.count)個中\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel))個が解放済み",
                    ko: "\(stages.count)개 중 \(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel))개 해금",
                    it: "\(GrowthUnlockStageExplorerPolicy.unlockedStageCount(currentLevel: currentLevel)) di \(stages.count) aperti"
                ))
        }
    }

    private var levelRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, step in
                        levelButton(step)
                            .id(step.id)

                        if index < stages.count - 1 {
                            levelConnector(after: step, before: stages[index + 1])
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
            .accessibilityIdentifier("growth-unlock-level-rail")
            .onAppear {
                proxy.scrollTo(selectedStageID, anchor: .center)
            }
            .onChange(of: selectedStageID) { _, nextID in
                if canAnimate {
                    withAnimation(GoMotion.selection) {
                        proxy.scrollTo(nextID, anchor: .center)
                    }
                } else {
                    proxy.scrollTo(nextID, anchor: .center)
                }
            }
        }
    }

    private func levelButton(_ step: GrowthUnlockStep) -> some View {
        let isSelected = selectedStageID == step.id
        let accent = Color(hex: step.tintHex)
        let state = GrowthUnlockStageExplorerPolicy.displayState(for: step, currentLevel: currentLevel)

        return Button {
            guard selectedStageID != step.id else { return }
            OhanaFeedback.selection()
            if canAnimate {
                withAnimation(GoMotion.selection) {
                    selectedStageID = step.id
                }
            } else {
                selectedStageID = step.id
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: levelIcon(for: state))
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : accent)
                    .frame(width: 34, height: 34) // a11y: allow glyph sits inside a 58x68 button target
                    .background(isSelected ? accent : Color.ohanaControlFill, in: Circle())
                    .ohanaPhasePop(trigger: selectedStageID, enabled: isSelected && canAnimate)
                    .accessibilityHidden(true)

                Text("Lv.\(step.requiredLevel)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(isSelected ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
            }
            .frame(width: 58)
            .frame(minHeight: 68)
            .background(
                isSelected ? accent.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.48) : Color.clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(levelAccessibilityLabel(step, state: state))
        .accessibilityHint(l.tr(
            zh: "显示这一级的内容",
            en: "Show this level",
            de: "Diese Stufe anzeigen",
            es: "Mostrar este nivel",
            pt: "Mostrar este nível",
            fr: "Afficher ce niveau",
            ja: "このレベルを表示",
            ko: "이 레벨 보기",
            it: "Mostra questo livello"
        ))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("growth-unlock-level-\(step.requiredLevel)")
    }

    private func levelConnector(after step: GrowthUnlockStep, before nextStep: GrowthUnlockStep) -> some View {
        let isReached = currentLevel >= nextStep.requiredLevel
        return Capsule()
            .fill(isReached ? Color(hex: step.tintHex).opacity(0.72) : Color.ohanaDivider)
            .frame(width: 12, height: 2) // a11y: allow non-interactive level connector
            .accessibilityHidden(true)
    }

    private var selectedStageCard: some View {
        let step = selectedStep
        let accent = Color(hex: step.tintHex)
        let state = GrowthUnlockStageExplorerPolicy.displayState(for: step, currentLevel: currentLevel)

        return ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [accent.opacity(0.20), accent.opacity(0.055), Color.ohanaControlFill.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: step.icon)
                .font(OhanaFont.adaptive(size: 66, weight: .black))
                .foregroundStyle(accent.opacity(0.08))
                .offset(x: 12, y: -8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: step.icon)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(accent)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaCardSurface.opacity(0.84), in: Circle())
                        .ohanaPhasePop(trigger: selectedStageID, enabled: canAnimate)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lv.\(step.requiredLevel)")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(accent)
                        Text(step.title(language: appLanguage))
                            .font(OhanaFont.title3(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    Label(stateLabel(for: state), systemImage: levelIcon(for: state))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.ohanaCardSurface.opacity(0.82), in: Capsule())
                        .labelStyle(.titleAndIcon)
                }

                Text(step.detail(language: appLanguage))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    l.tr(
                        zh: "等级只控制入口，已有记录始终保留",
                        en: "Levels pace entry; existing records always stay",
                        de: "Stufen steuern den Zugang; bestehende Daten bleiben",
                        es: "Los niveles regulan el acceso; tus datos permanecen",
                        pt: "Os níveis regulam o acesso; seus dados permanecem",
                        fr: "Les niveaux rythment l’accès ; vos données restent",
                        ja: "レベルは入口だけを制御し、既存記録は常に残ります",
                        ko: "레벨은 진입만 조절하며 기존 기록은 항상 유지됩니다",
                        it: "I livelli regolano l’accesso; i dati esistenti restano"
                    ),
                    systemImage: "lock.open.fill"
                )
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("growth-unlock-stage-detail")
    }

    private func levelIcon(for state: GrowthUnlockStageDisplayState) -> String {
        switch state {
        case .unlocked:
            "checkmark"
        case .next:
            "sparkles"
        case .locked:
            "lock.fill"
        }
    }

    private func stateLabel(for state: GrowthUnlockStageDisplayState) -> String {
        switch state {
        case .unlocked:
            l.tr(
                zh: "已开放",
                en: "Open",
                de: "Offen",
                es: "Abierto",
                pt: "Aberto",
                fr: "Ouvert",
                ja: "解放済み",
                ko: "해금됨",
                it: "Aperto"
            )
        case .next:
            l.tr(
                zh: "下一站",
                en: "Next",
                de: "Nächste",
                es: "Siguiente",
                pt: "Próximo",
                fr: "Prochain",
                ja: "次",
                ko: "다음",
                it: "Prossimo"
            )
        case let .locked(missingLevels):
            l.tr(
                zh: "\(missingLevels) 级后",
                en: "\(missingLevels) away",
                de: "Noch \(missingLevels)",
                es: "Faltan \(missingLevels)",
                pt: "Faltam \(missingLevels)",
                fr: "Encore \(missingLevels)",
                ja: "あと\(missingLevels)",
                ko: "\(missingLevels) 남음",
                it: "Mancano \(missingLevels)"
            )
        }
    }

    private func levelAccessibilityLabel(
        _ step: GrowthUnlockStep,
        state: GrowthUnlockStageDisplayState
    ) -> String {
        "Lv.\(step.requiredLevel), \(step.title(language: appLanguage)), \(stateLabel(for: state))"
    }
}

private struct LoopStep: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
}
