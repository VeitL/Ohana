import SwiftUI

struct GrowthUnlockRulesSheet: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onClose: () -> Void

    private var accent: Color {
        Color(hex: status.step.tintHex)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        requirementCard
                        methodCard
                        roadmapCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.

            VStack(alignment: .leading, spacing: 2) {
                Text(localized(zh: "解锁规则", en: "Unlock rules", de: "Freischaltregeln"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(status.step.title(language: appLanguage))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(localized(zh: "关闭", en: "Close", de: "Schließen"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var requirementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: status.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(localized(zh: "开放条件", en: "Requirement", de: "Bedingung"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(requirementText)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(status.step.detail(language: appLanguage))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "怎样升级", en: "How to level up", de: "So steigst du auf"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            ruleLine(
                icon: "checklist",
                text: localized(
                    zh: "完成每日照护、Today Focus 和提醒任务，稳定获得成长能量。",
                    en: "Complete daily care, Today Focus, and reminders to earn steady growth energy.",
                    de: "Erledige Pflege, Today Focus und Erinnerungen fuer stetige Energie."
                )
            )
            ruleLine(
                icon: "tree.fill",
                text: localized(
                    zh: "把获得的能量投入生命之树，生命之树达到目标等级后自动开放入口。",
                    en: "Feed that energy into the Life Tree; the entry opens automatically at the target level.",
                    de: "Gib Energie an den Lebensbaum; der Zugang oeffnet sich ab dem Ziellevel."
                )
            )
            ruleLine(
                icon: "lock.open.fill",
                text: localized(
                    zh: "解锁只控制入口节奏，不会删除已有数据，也不会改变照护记录。",
                    en: "Unlocking only controls entry pacing; it never deletes data or changes care records.",
                    de: "Freischalten steuert nur den Zugang und veraendert keine Pflegedaten."
                )
            )
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "完整路线", en: "Full path", de: "Ganzer Pfad"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            VStack(spacing: 8) {
                ForEach(GrowthUnlockPolicy.stages) { step in
                    GrowthUnlockStageRow(
                        step: step,
                        currentLevel: status.currentLevel,
                        appLanguage: appLanguage
                    )
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func ruleLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(Color.ohanaControlFill, in: Circle())

            Text(text)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var requirementText: String {
        if status.isUnlocked {
            return localized(
                zh: "当前生命之树 Lv.\(status.currentLevel)，已达到 Lv.\(status.step.requiredLevel)。",
                en: "Life Tree is Lv.\(status.currentLevel), already at Lv.\(status.step.requiredLevel).",
                de: "Lebensbaum Lv.\(status.currentLevel), bereits bei Lv.\(status.step.requiredLevel)."
            )
        }
        return localized(
            zh: "当前生命之树 Lv.\(status.currentLevel)，还差 \(status.missingLevels) 级；达到 Lv.\(status.step.requiredLevel) 后自动解锁。",
            en: "Life Tree is Lv.\(status.currentLevel); \(status.missingLevels) more level(s) to unlock at Lv.\(status.step.requiredLevel).",
            de: "Lebensbaum Lv.\(status.currentLevel); noch \(status.missingLevels) Level bis Lv.\(status.step.requiredLevel)."
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }
}

struct GrowthUnlockRuleInfoButton: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onTap: () -> Void

    var body: some View {
        Button {
            OhanaFeedback.light()
            onTap()
        } label: {
            Image(systemName: "info.circle.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color(hex: status.step.tintHex))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch appLanguage {
        case "en":
            "Show unlock rules for \(status.step.title(language: appLanguage))"
        case "de":
            "Freischaltregeln fuer \(status.step.title(language: appLanguage)) anzeigen"
        default:
            "查看\(status.step.title(language: appLanguage))解锁规则"
        }
    }
}

struct GrowthUnlockProgressCard: View {
    let currentLevel: Int
    let progressToNextLevel: Double
    let appLanguage: String
    var isCompact = false

    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
    }

    private var nextStep: GrowthUnlockStep? {
        GrowthUnlockPolicy.nextLockedStep(currentLevel: currentLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            HStack(spacing: 10) {
                Image(systemName: currentStep.icon)
                    .font(OhanaFont.adaptive(size: isCompact ? 15 : 17, weight: .black))
                    .foregroundStyle(Color(hex: currentStep.tintHex))
                    .frame(width: isCompact ? 34 : 38, height: isCompact ? 34 : 38) // a11y: allow decorative growth-stage glyph; surrounding card text owns accessibility.
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(zh: "生命之树 Lv.\(currentLevel)", en: "Life Tree Lv.\(currentLevel)", de: "Lebensbaum Lv.\(currentLevel)"))
                        .font(isCompact ? OhanaFont.callout(.black) : OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(currentStep.title(language: appLanguage))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color(hex: currentStep.tintHex))
                }

                Spacer(minLength: 8)

                if let nextStep {
                    Text("Lv.\(nextStep.requiredLevel)")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color(hex: nextStep.tintHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.ohanaControlFill, in: Capsule())
                } else {
                    Image(systemName: "checkmark.seal.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                ProgressView(value: min(1, max(0, progressToNextLevel)))
                    .tint(Color.goPrimary)
                    .background(Color.ohanaControlFill, in: Capsule())
                    .clipShape(Capsule())

                Text(nextText)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isCompact ? 13 : 16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous))
    }

    private var nextText: String {
        guard let nextStep else {
            return localized(
                zh: "全部成长功能已开放，后续成长只保留奖励和长期目标。",
                en: "All growth features are open; future growth keeps rewards and long-term goals.",
                de: "Alle Wachstumsfunktionen sind offen; weiteres Wachstum bleibt Belohnung und Langzeitziel."
            )
        }
        return localized(
            zh: "下一阶段：\(nextStep.title(language: appLanguage))，Lv.\(nextStep.requiredLevel) 解锁。",
            en: "Next: \(nextStep.title(language: appLanguage)), unlocks at Lv.\(nextStep.requiredLevel).",
            de: "Weiter: \(nextStep.title(language: appLanguage)), ab Lv.\(nextStep.requiredLevel)."
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }
}

struct GrowthUnlockRoadmapView: View {
    let currentLevel: Int
    let progressToNextLevel: Double
    let appLanguage: String
    var onClose: (() -> Void)?

    @Environment(AppServices.self) private var appServices
    @AppStorage(PlantLockedPreviewPolicy.onboardingHasPlantsKey) private var onboardingHasPlants = false
    @State private var ruleStatus: GrowthUnlockStatus?
    @State private var appearHandoffTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }
    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
    }

    private var showsPlantLockedPreview: Bool {
        _ = onboardingHasPlants
        return PlantLockedPreviewPolicy.shouldShowLockedPreview(currentLevel: currentLevel)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        starterGiftCard
                        GrowthUnlockProgressCard(
                            currentLevel: currentLevel,
                            progressToNextLevel: progressToNextLevel,
                            appLanguage: appLanguage
                        )
                        if showsPlantLockedPreview {
                            PlantLockedPreviewCard(
                                currentLevel: currentLevel,
                                currentEnergy: appServices.oasisTree.totalEnergy,
                                appLanguage: appLanguage
                            )
                        }
                        levelRulesCard
                        roadmapCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            appearHandoffTask?.cancel()
            appearHandoffTask = OhanaFrameScheduler.runAfterNextFrame {
                appServices.onboardingJourney.markRoadmapPromptSeen()
                AppPerformanceMonitor.shared.record("growth_roadmap_opened", valueMS: 0)
                appearHandoffTask = nil
            }
        }
        .onDisappear {
            appearHandoffTask?.cancel()
            appearHandoffTask = nil
        }
        .sheet(item: $ruleStatus) { status in
            GrowthUnlockRulesSheet(
                status: status,
                appLanguage: appLanguage,
                onClose: { ruleStatus = nil }
            )
            .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tree.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(localized(zh: "椰子树成长路线", en: "Coconut Tree Roadmap", de: "Kokosbaum-Roadmap"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(localized(
                    zh: "Lv.\(currentLevel) · \(currentStep.title(language: appLanguage))",
                    en: "Lv.\(currentLevel) · \(currentStep.title(language: appLanguage))",
                    de: "Lv.\(currentLevel) · \(currentStep.title(language: appLanguage))"
                ))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goPrimary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var starterGiftCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: currentLevel >= 1 ? "gift.fill" : "sparkles")
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(localized(zh: "新人椰子礼包", en: "Starter coconut gift", de: "Starter-Kokosgeschenk"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(localized(
                    zh: "首次建立家庭后获得 \(StarterGiftPolicy.giftAmount)🥥；椰子树保持 Lv0。每次注入 \(OasisTreeEnergyInjectionPolicy.starterPackageXP) 能量，注入 5 次后升到 Lv1。",
                    en: "After the first family setup, you receive \(StarterGiftPolicy.giftAmount)🥥; the tree stays Lv0. Each injection adds \(OasisTreeEnergyInjectionPolicy.starterPackageXP) energy, and 5 injections reach Lv1.",
                    de: "Nach dem ersten Zuhause gibt es \(StarterGiftPolicy.giftAmount)🥥; der Baum bleibt Lv0. Jede Einspeisung gibt \(OasisTreeEnergyInjectionPolicy.starterPackageXP) Energie, 5 Einspeisungen erreichen Lv1."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 76)
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var levelRulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "等级说明", en: "Level guide", de: "Level-Hinweise"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            levelRuleLine(
                icon: "bolt.fill",
                text: localized(
                    zh: "注入能量会消耗当前主人的椰子：\(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 -> \(OasisTreeEnergyInjectionPolicy.starterPackageXP) 能量。",
                    en: "Injecting energy spends the active human's coconuts: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 -> \(OasisTreeEnergyInjectionPolicy.starterPackageXP) energy.",
                    de: "Energieeinspeisung nutzt Kokosnüsse der aktiven Person: \(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 -> \(OasisTreeEnergyInjectionPolicy.starterPackageXP) Energie."
                )
            )
            levelRuleLine(
                icon: "tree.fill",
                text: localized(
                    zh: "Lv1 需要 50 总能量，所以新手礼包足够完成 5 次注入。",
                    en: "Lv1 needs 50 total energy, so the starter gift covers 5 injections.",
                    de: "Lv1 braucht 50 Gesamtenergie; das Startergeschenk reicht fuer 5 Einspeisungen."
                )
            )
            levelRuleLine(
                icon: "circle.hexagongrid.fill",
                text: localized(
                    zh: "Lv5 开始解锁每日椰子收益；到达后这里会显示每天可领取的椰子数。",
                    en: "Lv5 unlocks daily coconut yield; after reaching it, this guide shows the daily amount you can collect.",
                    de: "Ab Lv5 gibt es taegliche Kokos-Ertraege; danach zeigt diese Hilfe die taegliche Menge."
                )
            )
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func levelRuleLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 24, height: 24) // a11y: allow non-interactive level guide glyph; row text carries the content.
                .background(Color.ohanaControlFill, in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localized(zh: "升级会解锁什么", en: "What each level opens", de: "Was jede Stufe öffnet"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(localized(zh: "本地成长节奏", en: "Local growth pace", de: "Lokales Wachstum"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.ohanaControlFill, in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(GrowthUnlockPolicy.roadmapStages()) { step in
                    Button {
                        ruleStatus = GrowthUnlockStatus(step: step, currentLevel: currentLevel)
                    } label: {
                        GrowthUnlockStageRow(
                            step: step,
                            currentLevel: currentLevel,
                            appLanguage: appLanguage
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(step.title(language: appLanguage))
                    .accessibilityHint(localized(zh: "查看解锁规则", en: "Show unlock rules", de: "Freischaltregeln anzeigen"))
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }
}
