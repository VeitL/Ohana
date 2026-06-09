//
//  OasisBentoGridView.swift
//  Ohana
//
//  Pure render surface for the Oasis embedded action grid.
//

import SwiftUI

struct OasisBentoGridView: View {
    let snapshot: OasisBentoSnapshot
    let localization: L10n
    let onOpenShop: () -> Void
    let onOpenAchievements: () -> Void
    let onOpenCritters: () -> Void
    let onOpenGacha: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                bentoMiniCard(
                    systemName: "cart.fill",
                    title: localization.tr(zh: "商店", en: "Shop", de: "Shop"),
                    metric: snapshot.shopMetric,
                    accent: Color.goYellow,
                    action: onOpenShop
                )
                bentoMiniCard(
                    systemName: "trophy.fill",
                    title: localization.tr(zh: "成就", en: "Awards", de: "Erfolge"),
                    metric: snapshot.achievementMetric,
                    accent: snapshot.achievementsLocked ? Color.ohanaSecondaryText : Color.goTeal,
                    isEnabled: !snapshot.achievementsLocked,
                    action: onOpenAchievements
                )
            }

            HStack(spacing: 8) {
                bentoMiniCard(
                    systemName: "pawprint.fill",
                    title: localization.tr(zh: "伙伴", en: "Critters", de: "Critter"),
                    metric: snapshot.critterMetric,
                    accent: Color.goTeal,
                    action: onOpenCritters
                )
                bentoMiniCard(
                    systemName: "shippingbox.fill",
                    title: localization.tr(zh: "盲盒", en: "Blind Box", de: "Blind Box"),
                    metric: "80",
                    accent: Color.goPrimary,
                    action: onOpenGacha
                )
            }
        }
    }

    private func bentoMiniCard(
        systemName: String,
        title: String,
        metric: String,
        accent: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(OhanaFont.adaptive(size: 18, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(metric)
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 10, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}
