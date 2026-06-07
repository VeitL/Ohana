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
                Image(systemName: "lock.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(hex: status.step.tintHex))
                    .frame(width: 38, height: 38)
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
            Image(systemName: "info.circle.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)

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
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
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
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
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
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
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
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15, weight: .black))
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
                    .font(.system(size: isCompact ? 15 : 17, weight: .black))
                    .foregroundStyle(Color(hex: currentStep.tintHex))
                    .frame(width: isCompact ? 34 : 38, height: isCompact ? 34 : 38)
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
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .frame(width: 34, height: 34)
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

struct GrowthUnlockToastView: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: status.step.icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(hex: status.step.tintHex))
                .frame(width: 38, height: 38)
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

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
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
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(isUnlocked ? Color.goPrimary : Color(hex: step.tintHex))
                .frame(width: 30, height: 30)
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
