import SwiftUI

struct StarterGiftCeremonyOverlay: View {
    let appLanguage: String
    let amount: Int
    let onFinish: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                Color.ohanaPrimaryText.opacity(0.34)
                    .ignoresSafeArea()

                VStack(alignment: .center, spacing: 16) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: onFinish) {
                        Text(localized(zh: "开始使用", en: "Start using Ohana", de: "Ohana starten"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(localized(zh: "完成新人礼包仪式", en: "Finish starter gift ceremony", de: "Startergeschenk abschließen"))
                }
                .padding(18)
                .frame(maxWidth: 340)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.top, max(16, proxy.safeAreaInsets.top))
                .padding(.bottom, max(16, proxy.safeAreaInsets.bottom))
                .transition(.scale(scale: 0.96).combined(with: .opacity))
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
        case "en": en
        case "de": de
        default: zh
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
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
        case "en": en
        case "de": de
        default: zh
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
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
        case "en": en
        case "de": de
        default: zh
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
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
        case "en": en
        case "de": de
        default: zh
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
