import SwiftUI

struct GrowthLockedFeatureView: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    var showsFullRoadmap = true

    @State private var ruleStatus: GrowthUnlockStatus?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                lockedHeader

                if showsFullRoadmap {
                    roadmap
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 34)
        }
        .background(OhanaAppBackground().ignoresSafeArea())
        .sheet(item: $ruleStatus) { status in
            GrowthUnlockRulesSheet(
                status: status,
                appLanguage: appLanguage,
                onClose: { ruleStatus = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var lockedHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(Color(hex: status.step.tintHex))
                    .frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.step.title(language: appLanguage))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(levelText)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color(hex: status.step.tintHex))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                if !status.isUnlocked {
                    GrowthUnlockRuleInfoButton(
                        status: status,
                        appLanguage: appLanguage,
                        onTap: { ruleStatus = status }
                    )
                }
            }

            Text(status.step.detail(language: appLanguage))
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var roadmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(zh: "成长路线", en: "Growth Path", de: "Wachstumspfad"))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var levelText: String {
        if status.isUnlocked {
            return localized(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        }
        return localized(
            zh: "生命之树 Lv.\(status.step.requiredLevel) 解锁",
            en: "Unlocks at Life Tree Lv.\(status.step.requiredLevel)",
            de: "Ab Lebensbaum Lv.\(status.step.requiredLevel)"
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        case "en": return en
        case "de": return de
        default: return zh
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
            return "Show unlock rules for \(status.step.title(language: appLanguage))"
        case "de":
            return "Freischaltregeln fuer \(status.step.title(language: appLanguage)) anzeigen"
        default:
            return "查看\(status.step.title(language: appLanguage))解锁规则"
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
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct GrowthUnlockRoadmapView: View {
    let currentLevel: Int
    let progressToNextLevel: Double
    let appLanguage: String
    var onClose: (() -> Void)?

    @State private var ruleStatus: GrowthUnlockStatus?

    private var l: L10n { L10n(appLanguage) }
    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
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
                        roadmapCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            OnboardingJourneyCoordinator.markRoadmapPromptSeen()
            AppPerformanceMonitor.shared.record("growth_roadmap_opened", valueMS: 0)
        }
        .sheet(item: $ruleStatus) { status in
            GrowthUnlockRulesSheet(
                status: status,
                appLanguage: appLanguage,
                onClose: { ruleStatus = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tree.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 38, height: 38)
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
                    zh: "首次建立家庭后获得 50🥥，播放 Lv0 到 Lv1 的欢迎仪式；它不会直接购买等级。",
                    en: "After the first family setup, you receive 50🥥 and a Lv0 to Lv1 welcome ceremony; it does not buy levels.",
                    de: "Nach dem ersten Zuhause gibt es 50🥥 und eine Lv0-zu-Lv1-Begrüßung; es kauft keine Level."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 76)
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localized(zh: "升级会解锁什么", en: "What each level opens", de: "Was jede Stufe öffnet"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(localized(zh: "植物暂不开放", en: "Plants hidden for now", de: "Pflanzen vorerst verborgen"))
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct StarterGiftCeremonyOverlay: View {
    let appLanguage: String
    let amount: Int
    let onFinish: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.ohanaPrimaryText.opacity(0.34)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 11) {
                        Image(systemName: "gift.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 18, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.ohanaControlFill, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized(zh: "新人椰子礼包", en: "Starter coconut gift", de: "Starter-Kokosgeschenk"))
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text("+\(amount)🥥")
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.goPrimary)
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: 9) {
                        levelBadge("Lv0", isActive: false)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        levelBadge("Lv1", isActive: true)
                    }
                    .frame(maxWidth: .infinity)

                    Text(localized(
                        zh: "椰子树丛已经发芽。基础照护、档案和日历先开放，后续功能会随着椰子树升级逐步出现。",
                        en: "Your coconut grove has sprouted. Essentials, profiles, and calendar open first; more tools appear as the tree levels up.",
                        de: "Dein Kokoshain sprießt. Pflege, Profile und Kalender starten zuerst; weitere Werkzeuge erscheinen mit höheren Baumstufen."
                    ))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: onFinish) {
                        Text(localized(zh: "开始照护", en: "Start caring", de: "Pflege starten"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(localized(zh: "完成新人礼包仪式", en: "Finish starter gift ceremony", de: "Startergeschenk abschließen"))
                }
                .padding(18)
                .padding(.bottom, max(8, proxy.safeAreaInsets.bottom + 6))
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func levelBadge(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(OhanaFont.callout(.black))
            .foregroundStyle(isActive ? Color.arkInk : Color.ohanaSecondaryText)
            .frame(minWidth: 72, minHeight: 44)
            .background(isActive ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct GrowthDailyLoopStrip: View {
    let currentLevel: Int
    let progressToNextLevel: Double
    let pendingFocusCount: Int
    let hasAnyMember: Bool
    let appLanguage: String
    let onPrimaryAction: () -> Void

    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: currentLevel)
    }

    private var nextStep: GrowthUnlockStep? {
        GrowthUnlockPolicy.nextLockedStep(currentLevel: currentLevel)
    }

    private var accent: Color {
        Color(hex: nextStep?.tintHex ?? currentStep.tintHex)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(detailText)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: primaryAction) {
                    HStack(spacing: 5) {
                        Text(actionText)
                            .font(OhanaFont.caption(.black))
                            .lineLimit(1)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 10, weight: .black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(minWidth: 76, minHeight: 44)
                    .padding(.horizontal, 2)
                    .background(Color.goPrimary, in: Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(actionAccessibilityLabel)
            }

            ProgressView(value: min(1, max(0, progressToNextLevel)))
                .tint(accent)
                .background(Color.ohanaControlFill, in: Capsule())
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var iconName: String {
        if !hasAnyMember { return "person.badge.plus.fill" }
        if pendingFocusCount > 0 { return "checklist.checked" }
        return nextStep == nil ? "checkmark.seal.fill" : "tree.fill"
    }

    private var titleText: String {
        if !hasAnyMember {
            return localized(zh: "先建立小家", en: "Start your home", de: "Zuhause anlegen")
        }
        if pendingFocusCount > 0 {
            return localized(
                zh: "今日还有 \(pendingFocusCount) 项照护",
                en: "\(pendingFocusCount) care item(s) today",
                de: "\(pendingFocusCount) Pflegepunkt(e) heute"
            )
        }
        return localized(zh: "今日主线已稳定", en: "Daily loop is steady", de: "Tagesrunde stabil")
    }

    private var detailText: String {
        if !hasAnyMember {
            return localized(
                zh: "添加家人或宠物后，先开放最基础的照护与日历。",
                en: "Add a family member or pet to open essentials and calendar first.",
                de: "Füge Familie oder Tiere hinzu, dann starten Pflege und Kalender."
            )
        }

        guard let nextStep else {
            return localized(
                zh: "全部功能已开放；每天照护继续转化为奖励和长期记录。",
                en: "All features are open; daily care keeps feeding rewards and records.",
                de: "Alle Funktionen sind offen; Pflege stärkt Belohnungen und Verlauf."
            )
        }

        return localized(
            zh: "下一步 \(nextStep.title(language: appLanguage))，生命之树 Lv.\(nextStep.requiredLevel) 解锁。",
            en: "Next: \(nextStep.title(language: appLanguage)), unlocks at Life Tree Lv.\(nextStep.requiredLevel).",
            de: "Weiter: \(nextStep.title(language: appLanguage)), ab Lebensbaum Lv.\(nextStep.requiredLevel)."
        )
    }

    private var actionText: String {
        if !hasAnyMember {
            return localized(zh: "添加", en: "Add", de: "Hinzufügen")
        }
        if pendingFocusCount > 0 {
            return localized(zh: "去处理", en: "Do it", de: "Erledigen")
        }
        return localized(zh: "探索", en: "Open", de: "Öffnen")
    }

    private var actionAccessibilityLabel: String {
        if !hasAnyMember {
            return localized(zh: "添加家庭成员或宠物", en: "Add a family member or pet", de: "Familie oder Tier hinzufügen")
        }
        if pendingFocusCount == 0 {
            return localized(
                zh: "打开当前成长阶段推荐入口",
                en: "Open the recommended entry for the current growth stage",
                de: "Empfohlenen Einstieg der aktuellen Wachstumsstufe öffnen"
            )
        }
        return localized(zh: "打开每日照护入口", en: "Open daily care", de: "Tägliche Pflege öffnen")
    }

    private func primaryAction() {
        OhanaFeedback.light()
        onPrimaryAction()
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct GrowthLoopPulseStatus: Identifiable, Equatable {
    let id = UUID()
    let currentLevel: Int
    let energyDelta: Int
    let progressPercent: Int
}

struct GrowthLoopPulseToastView: View {
    let status: GrowthLoopPulseStatus
    let appLanguage: String

    private var currentStep: GrowthUnlockStep {
        GrowthUnlockPolicy.currentStep(currentLevel: status.currentLevel)
    }

    private var nextStep: GrowthUnlockStep? {
        GrowthUnlockPolicy.nextLockedStep(currentLevel: status.currentLevel)
    }

    private var accent: Color {
        Color(hex: nextStep?.tintHex ?? currentStep.tintHex)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tree.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(localized(zh: "成长能量已同步", en: "Growth synced", de: "Wachstum synchronisiert"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                    .lineLimit(1)
                Text(localized(
                    zh: "生命之树 Lv.\(status.currentLevel) · +\(status.energyDelta) 能量",
                    en: "Life Tree Lv.\(status.currentLevel) · +\(status.energyDelta) energy",
                    de: "Lebensbaum Lv.\(status.currentLevel) · +\(status.energyDelta) Energie"
                ))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(detailText)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 4)

            Text("\(status.progressPercent)%")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.arkInk)
                .frame(minWidth: 48, minHeight: 44)
                .background(Color.goPrimary, in: Capsule())
        }
        .frame(minHeight: 72)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        guard let nextStep else {
            return localized(
                zh: "全部功能已开放，继续积累长期记录。",
                en: "All features are open; keep building long-term records.",
                de: "Alle Funktionen sind offen; baue weiter Verlauf auf."
            )
        }
        return localized(
            zh: "下一步 \(nextStep.title(language: appLanguage)) Lv.\(nextStep.requiredLevel)",
            en: "Next: \(nextStep.title(language: appLanguage)) Lv.\(nextStep.requiredLevel)",
            de: "Weiter: \(nextStep.title(language: appLanguage)) Lv.\(nextStep.requiredLevel)"
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct GrowthUnlockToastView: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onDismiss: () -> Void
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: status.step.icon)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color(hex: status.step.tintHex))
                .frame(width: 38, height: 38) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(localized(zh: "新功能已解锁", en: "New tools unlocked", de: "Neue Funktionen frei"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goPrimary)
                Text(status.step.title(language: appLanguage))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(status.step.detail(language: appLanguage))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            if let onOpen {
                Button(action: onOpen) {
                    Text(localized(zh: "去看看", en: "Open", de: "Öffnen"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .frame(minWidth: 64, minHeight: 44)
                        .padding(.horizontal, 4)
                        .background(Color.goPrimary, in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(openAccessibilityLabel)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(localized(zh: "关闭", en: "Close", de: "Schließen"))
        }
        .frame(minHeight: 76)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.ohanaPrimaryText.opacity(0.14), radius: 18, x: 0, y: 8) // ui-v4: allow short unlock toast liftedAlert overlay
    }

    private var openAccessibilityLabel: String {
        localized(
            zh: "打开\(GrowthUnlockPolicy.primaryDestinationTitle(for: status.step, language: appLanguage))",
            en: "Open \(GrowthUnlockPolicy.primaryDestinationTitle(for: status.step, language: appLanguage))",
            de: "\(GrowthUnlockPolicy.primaryDestinationTitle(for: status.step, language: appLanguage)) öffnen"
        )
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": return en
        case "de": return de
        default: return zh
        }
    }
}

struct GrowthUnlockStageRow: View {
    let step: GrowthUnlockStep
    let currentLevel: Int
    let appLanguage: String

    private var isUnlocked: Bool {
        currentLevel >= step.requiredLevel
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isUnlocked ? "checkmark.circle.fill" : step.icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(isUnlocked ? Color.goPrimary : Color(hex: step.tintHex))
                .frame(width: 30, height: 30) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title(language: appLanguage))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(step.detail(language: appLanguage))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text("Lv.\(step.requiredLevel)")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(isUnlocked ? Color.arkInk : Color(hex: step.tintHex))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isUnlocked ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .frame(minHeight: 44)
    }
}
