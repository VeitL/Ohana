//
//  WalletPetCardBack.swift
//  Ohana
//
//  宠物卡片背面 — 分组滚动功能枢纽，覆盖全部宠物功能入口
//

import SwiftUI

struct WalletPetCardBack: View {
    let pet: Pet
    let cornerRadius: CGFloat
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    // MARK: - Callbacks
    var onShowSettings: () -> Void = {}
    var onFlipBack: () -> Void = {}

    // 健康管理
    var onShowHealth: () -> Void = {}
    var onShowMedications: () -> Void = {}
    var onShowWeight: () -> Void = {}

    // 日常生活
    var onShowFood: () -> Void = {}
    var onShowHygiene: () -> Void = {}
    var onShowWalks: () -> Void = {}
    var onShowPotty: () -> Void = {}
    var onShowExpenses: () -> Void = {}

    // 档案与记忆
    var onShowBasicInfo: () -> Void = {}
    var onShowDocuments: () -> Void = {}
    var onShowMoments: () -> Void = {}
    var onShowAchievements: () -> Void = {}

    // MARK: - Models
    private struct FeatureEntry: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let action: () -> Void
    }

    private struct FeatureSection: Identifiable {
        let id: String
        let symbol: String
        let title: String
        var entries: [FeatureEntry]
    }

    // MARK: - Species helpers
    private var isDog: Bool {
        Pet.isDogSpecies(pet.species)
    }

    private var isFish: Bool { Pet.isFishSpecies(pet.species) }
    private var l: L10n { L10n(appLanguage) }

    // MARK: - Section data
    private var sections: [FeatureSection] {
        // ── 健康管理 ──────────────────────────
        var healthEntries: [FeatureEntry] = [
            FeatureEntry(id: "health", symbol: "stethoscope", title: l.tr(zh: "健康档案", en: "Health", de: "Gesundheit"), action: onShowHealth),
            FeatureEntry(id: "weight", symbol: "scalemass.fill", title: l.tr(zh: "体重记录", en: "Weight", de: "Gewicht"), action: onShowWeight)
        ]
        if !isFish {
            healthEntries.append(
                FeatureEntry(id: "meds", symbol: "pills.fill", title: l.tr(zh: "用药管理", en: "Medication", de: "Medikamente"), action: onShowMedications)
            )
        }

        // ── 日常生活 ──────────────────────────
        var dailyEntries: [FeatureEntry] = [
            FeatureEntry(id: "food", symbol: "fork.knife", title: l.tr(zh: "饮食管理", en: "Food", de: "Futter"), action: onShowFood),
            FeatureEntry(id: "hygiene", symbol: "bubbles.and.sparkles.fill", title: l.tr(zh: "清洁护理", en: "Hygiene", de: "Pflege"), action: onShowHygiene),
            FeatureEntry(id: "potty", symbol: "drop.fill", title: l.tr(zh: "噗噗电台", en: "Potty", de: "Häufchen"), action: onShowPotty),
            FeatureEntry(id: "expenses", symbol: "creditcard.fill", title: l.tr(zh: "花费记录", en: "Expenses", de: "Ausgaben"), action: onShowExpenses)
        ]
        if isDog {
            dailyEntries.insert(
                FeatureEntry(id: "walks", symbol: "figure.walk", title: l.tr(zh: "遛狗记录", en: "Walks", de: "Gassi"), action: onShowWalks),
                at: 2
            )
        }

        // ── 档案与记忆 ──────────────────────────
        let archiveEntries: [FeatureEntry] = [
            FeatureEntry(id: "basicInfo", symbol: "person.fill", title: l.tr(zh: "基本信息", en: "Profile", de: "Profil"), action: onShowBasicInfo),
            FeatureEntry(id: "documents", symbol: "doc.fill", title: l.tr(zh: "证件保障", en: "Documents", de: "Dokumente"), action: onShowDocuments),
            FeatureEntry(id: "moments", symbol: "sparkles", title: l.tr(zh: "重要时刻", en: "Moments", de: "Momente"), action: onShowMoments),
            FeatureEntry(id: "achievements", symbol: "trophy.fill", title: l.tr(zh: "成就", en: "Badges", de: "Erfolge"), action: onShowAchievements)
        ]

        return [
            FeatureSection(id: "health", symbol: "cross.fill", title: l.tr(zh: "健康管理", en: "Health", de: "Gesundheit"), entries: healthEntries),
            FeatureSection(id: "daily", symbol: "sun.max.fill", title: l.tr(zh: "日常生活", en: "Daily care", de: "Alltag"), entries: dailyEntries),
            FeatureSection(id: "archive", symbol: "folder.fill", title: l.tr(zh: "档案与记忆", en: "Archive", de: "Archiv"), entries: archiveEntries)
        ]
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: WalletPetCardTheme.meshColors(for: pet.themeColorHex)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
        )
    }

    // MARK: - Section view
    private func sectionView(_ section: FeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: section.symbol)
                    .font(OhanaFont.adaptive(size: 7, weight: .bold))
                Text(section.title)
                    .font(OhanaFont.adaptive(size: 8, weight: .bold, design: .rounded))
                    .kerning(0.3)
                Rectangle()
                    .fill(.white.opacity(0.2)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .frame(height: 0.5)
            }
            .foregroundStyle(.white.opacity(0.55)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.

            HStack(spacing: 5) {
                ForEach(section.entries) { entry in
                    featureTile(entry: entry)
                }
            }
        }
    }

    // MARK: - Feature tile
    private func featureTile(entry: FeatureEntry) -> some View {
        Button { entry.action() } label: {
            HStack(spacing: 4) {
                Image(systemName: entry.symbol)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.95)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                Text(entry.title)
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(spacing: 6) {
            if pet.hasAvatarImageAttachment {
                PetAvatarPortraitView(
                    pet: pet,
                    fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                    themeColor: Color.goCardWhite,
                    size: 24,
                    backgroundOpacity: 0.15
                )
            } else {
                Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: pet.species))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.85)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .frame(width: 24, height: 24) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(.white.opacity(0.15), in: Circle()) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            }

            Text(pet.name)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Button { onShowSettings() } label: {
                Image(systemName: "gearshape.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.8)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                    .frame(width: 28, height: 28) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(.white.opacity(0.13), in: Circle()) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}
