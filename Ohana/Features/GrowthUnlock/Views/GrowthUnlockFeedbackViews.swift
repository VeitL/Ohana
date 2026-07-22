import SwiftUI

struct StarterGiftHomePreparationRecoveryOverlay: View {
    let appLanguage: String
    let message: String
    let onRetry: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.ohanaPrimaryText.opacity(0.34)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.clockwise.circle.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 30, weight: .black))
                            .foregroundStyle(Color.goPrimary)

                        Text(localized(
                            zh: "重新准备首页",
                            en: "Refresh Home",
                            de: "Home aktualisieren"
                        ))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)

                        Text(message)
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: onRetry) {
                            Text(localized(zh: "重试", en: "Try again", de: "Erneut versuchen"))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("starter-gift-home-preparation-retry")
                    }
                    .padding(20)
                    .frame(maxWidth: 340)
                    .background(
                        Color.ohanaCardSurface,
                        in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, max(16, proxy.safeAreaInsets.top))
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom))
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func localized(zh: String, en: String, de: String) -> String {
        switch appLanguage {
        case "en": en
        case "de": de
        default: zh
        }
    }
}

struct StarterGiftCeremonyOverlay: View {
    let appLanguage: String
    let amount: Int
    var isClaiming = false
    var isClaimCommitted = false
    var errorMessage: String?
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
                        levelBadge("Lv0", isActive: true)
                        Image(systemName: "plus").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        levelBadge("+\(amount)🥥", isActive: false)
                    }
                    .frame(maxWidth: .infinity)

                    Text(localized(
                        zh: "首宠奖励已经准备好。领取后会解锁底部的 Oasis；每次注入 \(OasisTreeEnergyInjectionPolicy.starterPackageXP) 能量，注入 5 次会升到 Lv1。",
                        en: "Your first-pet reward is ready. Claim it to unlock Oasis; each injection adds \(OasisTreeEnergyInjectionPolicy.starterPackageXP) energy, and 5 injections reach Lv1.",
                        de: "Deine Belohnung für das erste Haustier ist bereit. Hole sie ab, um Oasis freizuschalten; jede Einspeisung gibt \(OasisTreeEnergyInjectionPolicy.starterPackageXP) Energie, 5 Einspeisungen erreichen Lv1."
                    ))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: onFinish) {
                        HStack(spacing: 8) {
                            if isClaiming {
                                ProgressView()
                                    .tint(Color.arkInk)
                                    .controlSize(.small)
                            }
                            Text(actionTitle)
                                .font(OhanaFont.callout(.black))
                        }
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isClaiming)
                    .accessibilityIdentifier("starter-gift-finish-action")
                    .accessibilityLabel(actionAccessibilityLabel)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.goRed)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("starter-gift-claim-error")
                    }
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
        .accessibilityAddTraits(.isModal)
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

    private var actionTitle: String {
        if isClaiming {
            return isClaimCommitted
                ? localized(zh: "正在刷新首页", en: "Refreshing Home", de: "Home wird aktualisiert")
                : localized(zh: "正在领取", en: "Claiming", de: "Wird abgeholt")
        }
        return isClaimCommitted
            ? localized(zh: "刷新并继续", en: "Refresh and continue", de: "Aktualisieren und fortfahren")
            : localized(zh: "领取 \(amount) 椰子", en: "Claim \(amount) coconuts", de: "\(amount) Kokosnüsse abholen")
    }

    private var actionAccessibilityLabel: String {
        if isClaimCommitted {
            return localized(
                zh: "刷新首页并解锁 Oasis",
                en: "Refresh Home and unlock Oasis",
                de: "Home aktualisieren und Oasis freischalten"
            )
        }
        return localized(
            zh: "领取 \(amount) 椰子并解锁 Oasis",
            en: "Claim \(amount) coconuts and unlock Oasis",
            de: "\(amount) Kokosnüsse abholen und Oasis freischalten"
        )
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

struct GrowthUnlockPopupView: View {
    let status: GrowthUnlockStatus
    let appLanguage: String
    let onDismiss: () -> Void
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.18) // ui-v4: allow modal scrim behind centered unlock glass popup
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            popupCard
                .padding(.horizontal, 30)
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96)))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("growth-unlock-popup")
    }

    private var popupCard: some View {
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: status.step.icon)
                    .font(OhanaFont.title3(.black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color(hex: status.step.tintHex))
                    .frame(width: 48, height: 48)
                    .background(Color.ohanaControlFill, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(localized(zh: "新功能已解锁", en: "New feature unlocked", de: "Neue Funktion frei"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                        .lineLimit(1)

                    Text(unlockedTitle)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(stageLabel)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark") // a11y: allow close button has localized accessibilityLabel
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(localized(zh: "关闭", en: "Close", de: "Schließen"))
                .accessibilityIdentifier("growth-unlock-close-action")
            }

            Text(featureSummary)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(featureBullets, id: \.self) { text in
                    featureBullet(text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entryHint)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Text(localized(zh: "稍后", en: "Later", de: "Später"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("growth-unlock-later-action")

                Button(action: onOpen) {
                    Text(openTitle)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(openAccessibilityLabel)
                .accessibilityIdentifier("growth-unlock-open-action")
            }
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial, in: shape) // ui-v4: allow requested medium centered glass popup
        .background(Color.ohanaPopupSurfaceFill, in: shape)
        .overlay {
            shape.strokeBorder(Color.ohanaPopupSurfaceStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.26), radius: 26, x: 0, y: 16) // ui-v4: allow centered glass popup lift
    }

    private func featureBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative bullet marker hidden from VoiceOver
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color(hex: status.step.tintHex))
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featureTitle: String {
        GrowthUnlockPolicy.primaryDestinationTitle(for: status.step, language: appLanguage)
    }

    private var unlockedTitle: String {
        localized(
            zh: "\(featureTitle)已开放",
            en: "\(featureTitle) is now open",
            de: "\(featureTitle) ist jetzt frei"
        )
    }

    private var stageLabel: String {
        localized(
            zh: "生命树 Lv.\(status.step.requiredLevel) · \(status.step.title(language: appLanguage))",
            en: "Life Tree Lv.\(status.step.requiredLevel) · \(status.step.title(language: appLanguage))",
            de: "Lebensbaum Lv.\(status.step.requiredLevel) · \(status.step.title(language: appLanguage))"
        )
    }

    private var featureSummary: String {
        switch status.step.id {
        case .dailyCare:
            localized(
                zh: "基础管理入口已经就绪，先把每天必须记录的照护放在手边。",
                en: "Core care tools are ready, keeping must-log daily care close at hand.",
                de: "Die wichtigsten Pflegewerkzeuge sind bereit und bleiben griffbereit."
            )
        case .bodyHealth:
            localized(
                zh: "健康与身体记录升级成可浏览的管理面板。",
                en: "Health and body records now become a scannable management panel.",
                de: "Gesundheits- und Körperdaten werden zu einer übersichtlichen Ansicht."
            )
        case .memory:
            localized(
                zh: "成长档案开放，可以把运动、互动和重要瞬间沉淀下来。",
                en: "Growth archive is open, so walks, play, and moments can become a lasting record.",
                de: "Das Wachstumsarchiv ist offen und sammelt Spaziergänge, Spiel und Momente."
            )
        case .household:
            localized(
                zh: PlantUnlockPolicy.unlockedToastZh,
                en: "Your life canopy has opened. You can now care for the plants at home.",
                de: "Deine Lebenskrone hat sich geöffnet. Du kannst jetzt Pflanzen zu Hause pflegen."
            )
        case .oasisPlants:
            localized(
                zh: "绿洲收益开放，生命树开始把成长反馈成可领取的椰子。",
                en: "Oasis yield is open, turning tree growth into collectable coconuts.",
                de: "Oasis-Erträge sind offen und wandeln Wachstum in Kokosnüsse um."
            )
        case .rewards:
            localized(
                zh: "椰子商店和标准家庭周报开放，照护成果开始变得可消费、可回看。",
                en: "The coconut shop and standard weekly report are open, making care progress spendable and easy to review.",
                de: "Kokos-Shop und Standard-Wochenbericht sind offen: Pflegefortschritt wird nutzbar und gut rückblickbar."
            )
        case .advancedPlay:
            localized(
                zh: "扭蛋玩法开放，奖励层收集内容现在可以开始抽取。",
                en: "Gacha play is open, adding a collectible reward layer.",
                de: "Gacha ist offen und ergänzt eine sammelbare Belohnungsebene."
            )
        case .advancedInsights:
            localized(
                zh: "深度照护分析和完整提醒诊断开放；安全告警始终可见。",
                en: "Deep care analysis and full reminder diagnostics are open; safety alerts always remain visible.",
                de: "Tiefe Pflegeanalyse und vollständige Erinnerungsdiagnose sind offen; Sicherheitswarnungen bleiben sichtbar."
            )
        case .memoryReview:
            localized(
                zh: "长期家庭回顾开放，按月份整理重要照护和回忆，不重复周报。",
                en: "Long-term household review is open, organizing meaningful care and memories by month without repeating the weekly report.",
                de: "Der Langzeitrückblick ordnet wichtige Pflege und Erinnerungen monatlich, ohne den Wochenbericht zu wiederholen."
            )
        case .mastery:
            localized(
                zh: "大师树冠开放，长期荣誉、外观和顶级收益已经到位。",
                en: "Master canopy is open with long-term honors, styling, and top yield.",
                de: "Die Meister-Krone ist offen mit Ehren, Stil und höchsten Erträgen."
            )
        }
    }

    private var featureBullets: [String] {
        switch status.step.id {
        case .dailyCare:
            [
                localized(zh: "成员、宠物档案、基础日历、体重和花费统一开放", en: "Profiles, the basic calendar, Weight, and Expenses are available", de: "Profile, Basiskalender, Gewicht und Ausgaben sind verfügbar"),
                localized(zh: "日常照护及单个对象的健康、用药记录可直接使用", en: "Daily care and individual health and medication records are ready", de: "Tägliche Pflege sowie einzelne Gesundheits- und Medikamenteneinträge sind bereit")
            ]
        case .bodyHealth:
            [
                localized(zh: "查看健康与用药的家庭聚合面板和基础趋势", en: "View household health and medication summaries with basic trends", de: "Gesundheits- und Medikamentenübersichten mit Basistrends ansehen"),
                localized(zh: "原始健康与用药记录仍属于 Lv.1", en: "Raw health and medication records remain a Lv.1 ability", de: "Einzelne Gesundheits- und Medikamenteneinträge bleiben eine Lv.1-Funktion")
            ]
        case .memory:
            [
                localized(zh: "记录遛狗距离、互动玩耍和成长时刻", en: "Log walks, play, and growth moments", de: "Spaziergänge, Spiel und Wachstumsmomente erfassen"),
                localized(zh: "在记忆墙里回看长期陪伴变化", en: "Review long-term changes on the memory wall", de: "Langzeitveränderungen auf der Erinnerungswand ansehen")
            ]
        case .household:
            [
                localized(zh: "添加植物、查看植物 Dashboard 和详情页", en: "Add plants and open the plant dashboard and detail pages", de: "Pflanzen hinzufügen sowie Dashboard und Detailseiten öffnen"),
                localized(zh: "使用护理计划、日志、照片、资料库和本地提醒", en: "Use care plans, logs, photos, catalog, and local reminders", de: "Pflegepläne, Protokolle, Fotos, Katalog und lokale Erinnerungen nutzen")
            ]
        case .oasisPlants:
            [
                localized(zh: "领取生命树产生的椰子收益", en: "Collect coconuts produced by the Life Tree", de: "Kokosnüsse vom Lebensbaum einsammeln"),
                localized(zh: "从 Oasis 查看成长进度和下一阶段", en: "Use Oasis to see growth progress and the next stage", de: "In Oasis Wachstum und nächste Stufe ansehen")
            ]
        case .rewards:
            [
                localized(zh: "购买装饰、树能量包和实用消耗品", en: "Buy cosmetics, tree energy packs, and consumables", de: "Dekoration, Baumenergie und Verbrauchsartikel kaufen"),
                localized(zh: "在家庭洞察查看标准周报", en: "Open the standard weekly report in Household Insights", de: "Standard-Wochenbericht in den Haushaltseinblicken öffnen")
            ]
        case .advancedPlay:
            [
                localized(zh: "用椰子抽取盲盒与收集奖励", en: "Spend coconuts on blind boxes and collection rewards", de: "Kokosnüsse für Blindboxen und Sammlung nutzen"),
                localized(zh: "入口：Oasis 盲盒卡片与功能菜单", en: "Entry: Oasis blind box card and the feature menu", de: "Einstieg: Oasis-Blindbox und Funktionsmenü")
            ]
        case .advancedInsights:
            [
                localized(zh: "查看深度照护事件分析", en: "Review deep care-event analysis", de: "Tiefe Pflegeereignis-Analysen ansehen"),
                localized(zh: "查看完整提醒调度诊断；安全状态此前也始终可见", en: "Review full reminder diagnostics; safety states were always visible", de: "Vollständige Erinnerungsdiagnose ansehen; Sicherheitsstatus war stets sichtbar")
            ]
        case .memoryReview:
            [
                localized(zh: "按月份整理长期照护事件与回忆", en: "Organize long-term care events and memories by month", de: "Langfristige Pflegeereignisse und Erinnerungen monatlich ordnen"),
                localized(zh: "把长期记录变成独立于周报的家庭故事", en: "Turn long-term records into a household story distinct from weekly reports", de: "Langzeitdaten in eine vom Wochenbericht getrennte Familiengeschichte verwandeln")
            ]
        case .mastery:
            [
                localized(zh: "解锁电子宠物、大师树外观和长期荣誉", en: "Unlock the e-critter, master tree styling, and long-term honors", de: "E-Critter, Meisterbaum und Langzeit-Ehren freischalten"),
                localized(zh: "获得当前成长线的顶级被动收益", en: "Receive the top passive yield for the growth path", de: "Höchste passive Erträge dieser Wachstumslinie erhalten")
            ]
        }
    }

    private var entryHint: String {
        localized(
            zh: "相关入口会显示红点，直到你第一次打开\(featureTitle)。",
            en: "Related entries show a red dot until you open \(featureTitle) once.",
            de: "Zugehörige Einstiege zeigen einen Punkt, bis du \(featureTitle) einmal öffnest."
        )
    }

    private var openTitle: String {
        localized(
            zh: "进入\(featureTitle)",
            en: "Open \(featureTitle)",
            de: "\(featureTitle) öffnen"
        )
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
