//
//  OasisBentoGridView.swift
//  Ohana
//
//  Pure render surface for the Oasis embedded action grid.
//

import SwiftUI

enum OasisBentoFeature: String, CaseIterable, Hashable, Identifiable {
    case shop
    case achievements
    case critters
    case gacha

    var id: String { rawValue }

    var systemName: String {
        switch self {
        case .shop: "cart.fill"
        case .achievements: "trophy.fill"
        case .critters: "pawprint.fill"
        case .gacha: "shippingbox.fill"
        }
    }

    func title(_ localization: L10n) -> String {
        switch self {
        case .shop:
            localization.tr(zh: "商店", en: "Shop", de: "Shop")
        case .achievements:
            localization.tr(zh: "成就", en: "Awards", de: "Erfolge")
        case .critters:
            localization.tr(zh: "伙伴", en: "Critters", de: "Critter")
        case .gacha:
            localization.tr(zh: "盲盒", en: "Blind Box", de: "Blind Box")
        }
    }

    func detail(_ localization: L10n) -> String {
        switch self {
        case .shop:
            localization.tr(
                zh: "用椰子兑换装饰、能量包和日常消耗品。",
                en: "Spend coconuts on decor, energy packs, and useful consumables.",
                de: "Tausche Kokosnüsse gegen Deko, Energiepakete und Verbrauchsitems."
            )
        case .achievements:
            localization.tr(
                zh: "查看照护、收集和成长记录达成的徽章。",
                en: "Track badges earned through care, collection, and growth.",
                de: "Verfolge Abzeichen aus Pflege, Sammlung und Wachstum."
            )
        case .critters:
            localization.tr(
                zh: "唤醒并照顾 Oasis 电子宠物，让岛上多一个长期伙伴。",
                en: "Awaken and care for Oasis critters as long-term companions.",
                de: "Wecke Oasis-Begleiter und pflege sie langfristig."
            )
        case .gacha:
            localization.tr(
                zh: "用椰子抽取收藏物和惊喜奖励。",
                en: "Use coconuts to draw collectibles and surprise rewards.",
                de: "Nutze Kokosnüsse für Sammlerstücke und Überraschungen."
            )
        }
    }
}

struct OasisBentoFeatureInfo: Identifiable, Equatable {
    let feature: OasisBentoFeature
    let requiredLevel: Int?
    let unavailableLabel: String?

    var id: String {
        "\(feature.id)-\(requiredLevel.map { String($0) } ?? "none")-\(unavailableLabel ?? "available")"
    }

    func statusText(_ localization: L10n) -> String {
        if let requiredLevel {
            return localization.tr(
                zh: "Lv.\(requiredLevel) 解锁",
                en: "Unlocks at Lv.\(requiredLevel)",
                de: "Ab Lv.\(requiredLevel)"
            )
        }
        if let unavailableLabel {
            return unavailableLabel
        }
        return localization.tr(zh: "暂不可用", en: "Not available yet", de: "Noch nicht verfügbar")
    }
}

struct OasisBentoGridView: View {
    let snapshot: OasisBentoSnapshot
    let localization: L10n
    var shopLockedLevel: Int?
    var achievementsLockedLevel: Int?
    var crittersLockedLevel: Int?
    var gachaLockedLevel: Int?
    var isCompact: Bool = false
    var isInteractive: Bool = true
    var interactiveFeatures: Set<OasisBentoFeature> = Set(OasisBentoFeature.allCases)
    var onShowFeatureInfo: (OasisBentoFeatureInfo) -> Void = { _ in }
    let onOpenShop: () -> Void
    let onOpenAchievements: () -> Void
    let onOpenCritters: () -> Void
    let onOpenGacha: () -> Void
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    var body: some View {
        let showsPendingFeature: (OasisBentoFeature) -> Bool = { feature in
            _ = newFeatureRevision
            return GrowthNewFeatureStore.hasPending(oasisFeature: feature)
        }

        VStack(spacing: isCompact ? 6 : 8) {
            if let nextLockedFeature {
                nextUnlockSummary(feature: nextLockedFeature.feature, level: nextLockedFeature.level)
            }

            HStack(spacing: isCompact ? 6 : 8) {
                bentoMiniCard(
                    feature: .shop,
                    metric: snapshot.shopMetric,
                    accent: Color.goYellow,
                    allowsInteraction: interactiveFeatures.contains(.shop),
                    lockedLevel: shopLockedLevel,
                    isNextUnlock: isNextUnlock(feature: .shop, level: shopLockedLevel),
                    showsNewFeature: showsPendingFeature(.shop),
                    action: onOpenShop
                )
                bentoMiniCard(
                    feature: .achievements,
                    metric: snapshot.achievementMetric,
                    accent: snapshot.achievementsLocked ? Color.ohanaSecondaryText : Color.goTeal,
                    isEnabled: !snapshot.achievementsLocked,
                    allowsInteraction: interactiveFeatures.contains(.achievements),
                    lockedLevel: achievementsLockedLevel,
                    isNextUnlock: isNextUnlock(feature: .achievements, level: achievementsLockedLevel),
                    unavailableLabel: snapshot.achievementsLocked
                        ? localization.tr(zh: "暂无宠物", en: "No pets", de: "Keine Haustiere")
                        : nil,
                    showsNewFeature: showsPendingFeature(.achievements),
                    action: onOpenAchievements
                )
            }

            HStack(spacing: isCompact ? 6 : 8) {
                bentoMiniCard(
                    feature: .critters,
                    metric: snapshot.critterMetric,
                    accent: Color.goTeal,
                    allowsInteraction: interactiveFeatures.contains(.critters),
                    lockedLevel: crittersLockedLevel,
                    isNextUnlock: isNextUnlock(feature: .critters, level: crittersLockedLevel),
                    showsNewFeature: showsPendingFeature(.critters),
                    action: onOpenCritters
                )
                bentoMiniCard(
                    feature: .gacha,
                    metric: "80🥥",
                    accent: Color.goPrimary,
                    allowsInteraction: interactiveFeatures.contains(.gacha),
                    lockedLevel: gachaLockedLevel,
                    isNextUnlock: isNextUnlock(feature: .gacha, level: gachaLockedLevel),
                    showsNewFeature: showsPendingFeature(.gacha),
                    action: onOpenGacha
                )
            }
        }
    }

    private var nextLockedFeature: (feature: OasisBentoFeature, level: Int)? {
        let candidates: [(feature: OasisBentoFeature, level: Int)] = [
            shopLockedLevel.map { (.shop, $0) },
            achievementsLockedLevel.map { (.achievements, $0) },
            crittersLockedLevel.map { (.critters, $0) },
            gachaLockedLevel.map { (.gacha, $0) }
        ].compactMap(\.self)
        return candidates.min { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return (OasisBentoFeature.allCases.firstIndex(of: lhs.feature) ?? 0)
                < (OasisBentoFeature.allCases.firstIndex(of: rhs.feature) ?? 0)
        }
    }

    private func isNextUnlock(feature: OasisBentoFeature, level: Int?) -> Bool {
        guard let level, let nextLockedFeature else { return false }
        return nextLockedFeature.feature == feature && nextLockedFeature.level == level
    }

    private func nextUnlockSummary(feature: OasisBentoFeature, level: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.forward.circle.fill") // a11y: allow decorative status glyph; the combined summary text carries the meaning
                .accessibilityHidden(true)
            Text(localization.tr(zh: "下一解锁", en: "Next unlock", de: "Nächste Freigabe"))
            Text("·")
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(feature.title(localization))
            Spacer(minLength: 6)
            Text("Lv.\(level)")
                .monospacedDigit()
        }
        .font(OhanaFont.caption2(.black))
        .foregroundStyle(Color.goPrimary)
        .padding(.horizontal, 4)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .accessibilityElement(children: .combine)
    }

    private func bentoMiniCard(
        feature: OasisBentoFeature,
        metric: String,
        accent: Color,
        isEnabled: Bool = true,
        allowsInteraction: Bool = true,
        lockedLevel: Int? = nil,
        isNextUnlock: Bool = false,
        unavailableLabel: String? = nil,
        showsNewFeature: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isLocked = lockedLevel != nil
        let isUnavailable = isLocked || !isEnabled || !isInteractive || !allowsInteraction
        let title = feature.title(localization)
        let iconFrame: CGFloat = isCompact ? 30 : 34
        let iconFontSize: CGFloat = isCompact ? 16 : 18
        let titleFontSize: CGFloat = isCompact ? 11 : 12
        let metricFontSize: CGFloat = isCompact ? 12 : 14
        let contentSpacing: CGFloat = isCompact ? 8 : 10
        let supportingText: String = if let lockedLevel {
            isNextUnlock
                ? localization.tr(
                    zh: "下一目标 · Lv.\(lockedLevel)",
                    en: "Next · Lv.\(lockedLevel)",
                    de: "Als Nächstes · Lv.\(lockedLevel)"
                )
                : localization.tr(
                    zh: "Lv.\(lockedLevel) 解锁",
                    en: "Unlocks at Lv.\(lockedLevel)",
                    de: "Ab Lv.\(lockedLevel)"
                )
        } else if let unavailableLabel, !isEnabled {
            unavailableLabel
        } else {
            metric
        }
        return Button {
            guard isInteractive, allowsInteraction else { return }
            if isLocked || !isEnabled {
                OhanaFeedback.light()
                onShowFeatureInfo(
                    OasisBentoFeatureInfo(
                        feature: feature,
                        requiredLevel: lockedLevel,
                        unavailableLabel: unavailableLabel
                    )
                )
                return
            }
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: contentSpacing) {
                    Image(systemName: feature.systemName)
                        .font(OhanaFont.adaptive(size: iconFontSize, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isNextUnlock ? Color.goPrimary : (isUnavailable ? Color.ohanaSecondaryText : Color.goPrimary))
                        .frame(width: iconFrame, height: iconFrame) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .background(
                            isNextUnlock ? Color.goPrimary.opacity(0.13) : Color.ohanaControlFill.opacity(isUnavailable ? 0.72 : 1),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(OhanaFont.adaptive(size: titleFontSize, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(supportingText)
                            .font(OhanaFont.adaptive(size: metricFontSize, weight: .black, design: .rounded))
                            .foregroundStyle(isNextUnlock ? Color.goPrimary : (isUnavailable ? Color.ohanaSecondaryText : accent))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isLocked ? "info.circle" : "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: isLocked ? 12 : 10, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isNextUnlock ? Color.goPrimary : Color.ohanaSecondaryText)
                }
                .opacity(isNextUnlock ? 1 : (isUnavailable ? 0.72 : 1))

                if showsNewFeature, isInteractive, !isLocked {
                    GrowthNewFeatureDot(size: isCompact ? 8 : 9)
                        .offset(x: 4, y: -4)
                }
            }
            .padding(.horizontal, isCompact ? 10 : 14)
            .padding(.vertical, isCompact ? 7 : 11)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 0)
            .background(
                isNextUnlock
                    ? Color.goPrimary.opacity(0.10)
                    : (isUnavailable ? Color.ohanaControlFill.opacity(0.72) : Color.ohanaCardSurface),
                in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(isNextUnlock ? Color.goPrimary.opacity(0.42) : Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isInteractive || !allowsInteraction)
        .opacity(isInteractive ? 1 : 0.55)
        .saturation(isNextUnlock ? 0.72 : (isUnavailable ? 0.12 : 1))
        .accessibilityLabel(accessibilityLabel(title: title, lockedLevel: lockedLevel, unavailableLabel: unavailableLabel))
        .accessibilityHint(isLocked
            ? localization.tr(
                zh: "轻点查看功能说明",
                en: "Tap to preview this feature",
                de: "Tippen, um die Funktion anzusehen"
            )
            : "")
        .accessibilityIdentifier("oasis-bento-\(feature.id)")
    }

    private func accessibilityLabel(title: String, lockedLevel: Int?, unavailableLabel: String?) -> String {
        if let lockedLevel {
            return "\(title), \(localization.tr(zh: "Lv.\(lockedLevel) 解锁", en: "unlocks at level \(lockedLevel)", de: "ab Level \(lockedLevel)"))"
        }
        if let unavailableLabel {
            return "\(title), \(unavailableLabel)"
        }
        return title
    }
}

struct OasisBentoFeatureInfoOverlay: View {
    let info: OasisBentoFeatureInfo
    let localization: L10n
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.18) // ui-v4: allow modal scrim for centered glass popup
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            popupCard
                .padding(.horizontal, 30)
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96)))
        }
        .accessibilityElement(children: .contain)
    }

    private var popupCard: some View {
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: info.feature.systemName)
                    .font(OhanaFont.title3(.black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 46, height: 46)
                    .background(Color.ohanaControlFill, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(info.feature.title(localization))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(info.statusText(localization))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(localization.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }

            Text(info.feature.detail(localization))
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            Text(helperText)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Button {
                onDismiss()
            } label: {
                Text(localization.tr(zh: "知道了", en: "Got it", de: "Verstanden"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: 330)
        .background(.ultraThinMaterial, in: shape) // ui-v4: allow requested centered glass popup
        .background(Color.ohanaPopupSurfaceFill, in: shape)
        .overlay {
            shape.strokeBorder(Color.ohanaPopupSurfaceStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.26), radius: 26, x: 0, y: 16) // ui-v4: allow centered glass popup lift
    }

    private var helperText: String {
        if info.requiredLevel != nil {
            return localization.tr(
                zh: "继续完成真实照护，椰子树升级后会自动开放。",
                en: "Keep completing real care. It opens automatically as the tree levels up.",
                de: "Bleib bei echter Pflege. Es öffnet sich automatisch mit Baum-Leveln."
            )
        }
        if info.feature == .achievements, info.unavailableLabel != nil {
            return localization.tr(
                zh: "添加宠物后，这里会显示它们的成就进度。",
                en: "Add a pet and this will show their badge progress.",
                de: "Füge ein Tier hinzu, dann erscheint hier der Abzeichen-Fortschritt."
            )
        }
        return localization.tr(
            zh: "满足条件后会自动开放。",
            en: "It opens automatically once the requirements are met.",
            de: "Es öffnet sich automatisch, sobald die Bedingungen erfüllt sind."
        )
    }
}
