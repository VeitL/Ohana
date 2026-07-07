//
//  HumanDetailView+Stats.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension HumanDetailView {
    var statsBento: some View {
        HStack(spacing: 8) {
            bentoStatMini(
                icon: "scalemass.fill",
                value: {
                    guard !human.isPrivate(.weight, viewedBy: activeHumanId) else { return "—" }
                    guard let latest = human.weightLogs.sorted(by: { $0.date > $1.date }).first,
                          latest.weight.isFinite else { return "—" }
                    return String(format: "%.1f", latest.weight)
                }(),
                unit: human.isPrivate(.weight, viewedBy: activeHumanId) || human.weightLogs.isEmpty ? "" : "kg",
                label: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                color: Color.goPrimary
            )
            bentoStatMini(
                icon: "pills.fill",
                value: human.isPrivate(.medication, viewedBy: activeHumanId) ? "—" : "\(myMeds.count)",
                unit: human.isPrivate(.medication, viewedBy: activeHumanId) ? "" : l.tr(zh: "种", en: "meds", de: "Meds"),
                label: l.tr(zh: "用药", en: "Meds", de: "Meds"),
                color: Color.goRed
            )
            bentoStatMini(
                icon: "bell.badge.fill",
                value: "\(humanReminders.count)",
                unit: l.tr(zh: "条", en: "items", de: "Einträge"),
                label: l.tr(zh: "待办", en: "To-dos", de: "To-dos"),
                color: Color.goOrange
            )
            bentoStatMini(
                icon: "leaf.fill",
                value: human.isPrivate(.wishlist, viewedBy: activeHumanId) ? "—" : "\(human.coconutBalance)",
                unit: human.isPrivate(.wishlist, viewedBy: activeHumanId) ? "" : "🥥",
                label: l.tr(zh: "椰子", en: "Coconuts", de: "Kokosnüsse"),
                color: Color.goYellow
            )
        }
        .padding(.horizontal, 16)
    }

    func bentoStatMini(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 18, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(color)
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(color.opacity(0.15), in: Circle())
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(OhanaFont.metric(size: 18))
                    .foregroundStyle(Color(light: Color(hex: "1E3A8A"), dark: .primary))
                if !unit.isEmpty {
                    Text(unit)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color(light: Color(hex: "6B82C4"), dark: .secondary))
                }
            }
            Text(label)
                .font(OhanaFont.caption2(.medium))
                .foregroundStyle(Color(light: Color(hex: "6B82C4"), dark: .secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04), lineWidth: 1)
        )
    }

    // MARK: - Badges Card
    var badgesCard: some View {
        let badges = human.dynamicBadges(allPets: allPets, allHumans: allHumans)
        return Group {
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.goYellow)
                        Text(l.tr(zh: "动态称号", en: "Dynamic Badges", de: "Dynamische Abzeichen"))
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color(hex: "1E3A8A"))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(badges) { badge in
                                HStack(spacing: 6) {
                                    Text(badge.emoji).font(OhanaFont.callout())
                                    Text(badge.title)
                                        .font(OhanaFont.caption(.bold))
                                        .foregroundStyle(Color(hex: badge.color))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(hex: badge.color).opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: badge.color).opacity(0.35), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
                .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Medication Card (NEW)
}
