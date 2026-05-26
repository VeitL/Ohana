//
//  OasisUpgradeRewardPresentationView.swift
//  Ohana
//
//  Reward presentation surfaces for Life Tree upgrade coconuts.
//

import SwiftUI

struct OasisStageOpenedRewardCard: View {
    let reward: OasisOpenedUpgradeReward
    let localization: L10n
    let onClose: () -> Void

    var body: some View {
        if reward.isMilestoneCritter,
           let catalogId = reward.critterCatalogId,
           let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) {
            OasisCritterUnlockRewardCard(
                catalogId: catalogId,
                newLabel: localization.tr(zh: "新伙伴", en: "NEW", de: "NEU"),
                rarityText: localization.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de),
                title: entry.name(localization),
                detail: reward.detail(localization),
                confirmTitle: localization.tr(zh: "收下", en: "Keep", de: "Behalten"),
                accent: critterRarityColor(entry.rarity),
                onClose: onClose
            )
        } else {
            HStack(spacing: 12) {
                OasisRewardKindIcon(reward: reward, size: 34)
                    .frame(width: 54, height: 54)
                    .background(Color.goYellow.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(reward.title(localization))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(reward.detail(localization))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 38, height: 38)
                        .background(Color.goPrimary, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(12)
            .background(Color.ohanaCardSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.goPrimary.opacity(0.16), radius: 18, x: 0, y: 9) // ui-v4: allow transient upgrade reward focus
        }
    }

    private func critterRarityColor(_ rarity: OasisElectronicPetRarity) -> Color {
        switch rarity {
        case .common: return Color.goTeal
        case .rare: return Color.goPrimary
        case .epic: return Color.goPurple
        case .legendary: return Color.goYellow
        }
    }
}

struct OasisOpenedUpgradeRewardDockCard: View {
    let reward: OasisOpenedUpgradeReward
    let localization: L10n
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            OasisRewardKindIcon(reward: reward, size: 30)
                .frame(width: 56, height: 56)
                .background(
                    reward.isMilestoneCritter ? Color.goPrimary.opacity(0.22) : Color.goYellow.opacity(0.18),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(reward.title(localization))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(reward.detail(localization))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 38, height: 38)
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(12)
        .background(
            Color.goPrimary.opacity(reward.isMilestoneCritter ? 0.16 : 0.08),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }
}

struct OasisRewardKindIcon: View {
    let reward: OasisOpenedUpgradeReward
    var size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .black))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint)
    }

    private var systemName: String {
        switch reward.kind {
        case .coconuts:
            return "circle.hexagongrid.fill"
        case .treeEnergy:
            return "bolt.fill"
        case .decoration:
            return "sparkles"
        case .fragments:
            return "diamond.fill"
        case .storyStyle:
            return "text.bubble.fill"
        case .temporaryEffect:
            return "wand.and.stars"
        case .electronicPet:
            return "pawprint.fill"
        }
    }

    private var tint: Color {
        switch reward.kind {
        case .coconuts, .treeEnergy:
            return Color.goYellow
        case .decoration, .storyStyle, .temporaryEffect:
            return Color.goPrimary
        case .fragments:
            return Color.goPurple
        case .electronicPet:
            return Color.goTeal
        }
    }
}

private struct OasisCritterUnlockRewardCard: View {
    let catalogId: String
    let newLabel: String
    let rarityText: String
    let title: String
    let detail: String
    let confirmTitle: String
    let accent: Color
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 13) {
            Text(newLabel)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(accent, in: Capsule())
                .scaleEffect(appeared && !reduceMotion ? 1 : 0.82)

            ZStack {
                unlockRing(size: 214, delay: 0)
                unlockRing(size: 174, delay: 0.06)
                unlockSparkles

                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 150, height: 150)
                    .blur(radius: 8)
                    .scaleEffect(appeared ? 1.08 : 0.72)

                OasisCritterIllustration(catalogId: catalogId, locked: false, size: 176)
                    .scaleEffect(appeared && !reduceMotion ? 1 : 0.72)
                    .offset(y: appeared ? 0 : 12)
            }
            .frame(height: 220)

            VStack(spacing: 5) {
                Text(title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(rarityText)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(accent)

                Text(detail)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
            }

            Button(action: onClose) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(confirmTitle)
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: 344)
        .background(Color.ohanaCardSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(accent.opacity(0.32), lineWidth: 1.2)
        }
        .shadow(color: accent.opacity(0.26), radius: 28, x: 0, y: 12) // ui-v4: allow transient electronic-pet unlock focus
        .scaleEffect(appeared && !reduceMotion ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.fab) {
                appeared = true
            }
        }
    }

    private func unlockRing(size: CGFloat, delay: Double) -> some View {
        Circle()
            .stroke(accent.opacity(appeared ? 0 : 0.62), lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(appeared && !reduceMotion ? 1.12 : 0.68)
            .animation((reduceMotion ? GoMotion.reduced : GoMotion.hero).delay(delay), value: appeared)
    }

    private var unlockSparkles: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Angle.degrees(Double(index) * 36)
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 13 : 8, weight: .black))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.goYellow : accent)
                    .offset(
                        x: appeared && !reduceMotion ? cos(angle.radians) * 104 : cos(angle.radians) * 58,
                        y: appeared && !reduceMotion ? sin(angle.radians) * 92 : sin(angle.radians) * 44
                    )
                    .opacity(appeared ? 1 : 0)
                    .animation((reduceMotion ? GoMotion.reduced : GoMotion.fab).delay(0.02 * Double(index)), value: appeared)
            }
        }
        .allowsHitTesting(false)
    }
}
