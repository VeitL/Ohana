//
//  OasisProgressMilestoneCards.swift
//  Ohana
//
//  Legacy Oasis progress and tree milestone cards kept as pure render components.
//

import SwiftUI

struct OasisProgressCard: View {
    let totalEnergy: Int
    let careGrowthEnergy: Int
    let injectedEnergy: Int
    let nextLevelThreshold: Int
    let progressToNextLevel: CGFloat
    let passiveIncomeAmount: Int
    let memberCount: Int
    let localization: L10n

    private var isMaxLevel: Bool { totalEnergy >= nextLevelThreshold }
    private var nutrientsToNextLevel: Int { max(0, nextLevelThreshold - totalEnergy) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localization.tr(zh: "养分进度", en: "Nutrient progress", de: "Nährstofffortschritt"))
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(isMaxLevel
                    ? localization.tr(zh: "已满级", en: "Max level", de: "Max. Level")
                    : localization.tr(
                        zh: "距下一级还差 \(nutrientsToNextLevel) 养分",
                        en: "\(nutrientsToNextLevel) nutrients to next level",
                        de: "\(nutrientsToNextLevel) Nährstoffe bis zum nächsten Level"
                    ))
                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ohanaControlFill)
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.goPrimary, Color.goTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * progressToNextLevel, height: 8)
                        .shadow(color: Color.goPrimary.opacity(0.5), radius: 6, x: 0, y: 0) // ui-v4: allow Oasis progress shine
                        .animation(GoMotion.page, value: progressToNextLevel)
                }
            }
            .frame(height: 8)

            HStack(spacing: 0) {
                progressStatCell(
                    value: passiveIncomeAmount > 0
                        ? localization.tr(zh: "+\(passiveIncomeAmount)🥥/日", en: "+\(passiveIncomeAmount)🥥/day", de: "+\(passiveIncomeAmount)🥥/Tag")
                        : "—",
                    label: localization.tr(zh: "被动收入", en: "Passive income", de: "Passives Einkommen"),
                    color: passiveIncomeAmount > 0 ? Color.goPrimary : Color.ohanaSecondaryText.opacity(0.6)
                )
                progressStatCell(
                    value: SingleMemberFamilyShapePresentation.familyMemberCountText(
                        memberCount: memberCount,
                        l: localization
                    ),
                    label: localization.tr(zh: "家庭贡献", en: "Family input", de: "Familienbeitrag"),
                    color: Color(hex: "5B6AFF")
                )
                progressStatCell(
                    value: "\(totalEnergy)",
                    label: localization.tr(zh: "养分总量", en: "Total nutrients", de: "Nährstoffe gesamt"),
                    color: Color(hex: "A855F7")
                )
            }

            compositionRow
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private var compositionRow: some View {
        HStack(spacing: 8) {
            compositionChip(
                icon: "heart.fill",
                label: localization.tr(zh: "照护养分", en: "Care nutrients", de: "Pflege-Nährstoffe"),
                value: careGrowthEnergy,
                tint: Color.goPrimary
            )
            compositionChip(
                icon: "bolt.fill",
                label: localization.tr(zh: "喂食养分", en: "Fed nutrients", de: "Zugeführt"),
                value: injectedEnergy,
                tint: Color(hex: "F59E0B")
            )
        }
    }

    private func compositionChip(icon: String, label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon) // a11y: decorative; adjacent label names the nutrient source.
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(label)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text("\(value)")
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func progressStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OasisMilestoneCard: View {
    let treeLevel: TreeLevel
    let localization: L10n

    var body: some View {
        let currentLv = treeLevel.rawValue
        let isMaxLevel = currentLv >= 10
        let nextLv = min(currentLv + 1, 10)
        let nextLevel = TreeLevel(rawValue: nextLv) ?? .lv10

        Button {} label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .fill(Color.goPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "trophy.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isMaxLevel {
                        Text(localization.tr(zh: "已达最高境界", en: "Final level reached", de: "Endstufe erreicht"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(localization.tr(
                            zh: "生命之树已至巅峰，繁荣永续",
                            en: "The Life Tree is fully thriving.",
                            de: "Der Lebensbaum ist vollständig erblüht."
                        ))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    } else {
                        Text("Lv.\(nextLv) · \(nextLevel.displayName)")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(localization.tr(
                            zh: "解锁被动收益 +\(passiveIncomeForLevel(nextLevel))🥥/日",
                            en: "Unlocks +\(passiveIncomeForLevel(nextLevel))🥥/day",
                            de: "Schaltet +\(passiveIncomeForLevel(nextLevel))🥥/Tag frei"
                        ))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.goPrimary.opacity(0.8))
                    }
                }

                Spacer()

                if !isMaxLevel {
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func passiveIncomeForLevel(_ lv: TreeLevel) -> Int {
        switch lv {
        case .lv0: 0
        case .lv1: 1
        case .lv2: 2
        case .lv3: 3
        case .lv4: 5
        case .lv5: 7
        case .lv6: 10
        case .lv7: 14
        case .lv8: 18
        case .lv9: 24
        case .lv10: 30
        }
    }
}
