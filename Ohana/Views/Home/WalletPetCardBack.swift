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

    // MARK: - Callbacks
    var onShowSettings:     () -> Void = {}
    var onFlipBack:         () -> Void = {}

    // 健康管理
    var onShowHealth:       () -> Void = {}
    var onShowMedications:  () -> Void = {}
    var onShowWeight:       () -> Void = {}

    // 日常生活
    var onShowFood:         () -> Void = {}
    var onShowHygiene:      () -> Void = {}
    var onShowWalks:        () -> Void = {}
    var onShowPotty:        () -> Void = {}
    var onShowExpenses:     () -> Void = {}

    // 档案与记忆
    var onShowBasicInfo:    () -> Void = {}
    var onShowDocuments:    () -> Void = {}
    var onShowMoments:      () -> Void = {}
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
        pet.species.lowercased().contains("dog") || pet.species.contains("狗")
    }
    private var isFish: Bool { pet.species.contains("鱼") }

    // MARK: - Section data
    private var sections: [FeatureSection] {
        // ── 健康管理 ──────────────────────────
        var healthEntries: [FeatureEntry] = [
            FeatureEntry(id: "health",  symbol: "stethoscope",    title: "健康档案", action: onShowHealth),
            FeatureEntry(id: "weight",  symbol: "scalemass.fill", title: "体重记录", action: onShowWeight),
        ]
        if !isFish {
            healthEntries.append(
                FeatureEntry(id: "meds", symbol: "pills.fill", title: "用药管理", action: onShowMedications)
            )
        }

        // ── 日常生活 ──────────────────────────
        var dailyEntries: [FeatureEntry] = [
            FeatureEntry(id: "food",     symbol: "fork.knife",                  title: "饮食管理", action: onShowFood),
            FeatureEntry(id: "hygiene",  symbol: "bubbles.and.sparkles.fill",   title: "清洁护理", action: onShowHygiene),
            FeatureEntry(id: "potty",    symbol: "drop.fill",                   title: "便便记录", action: onShowPotty),
            FeatureEntry(id: "expenses", symbol: "creditcard.fill",             title: "花费记录", action: onShowExpenses),
        ]
        if isDog {
            dailyEntries.insert(
                FeatureEntry(id: "walks", symbol: "figure.walk", title: "遛狗记录", action: onShowWalks),
                at: 2
            )
        }

        // ── 档案与记忆 ──────────────────────────
        let archiveEntries: [FeatureEntry] = [
            FeatureEntry(id: "basicInfo",    symbol: "person.fill", title: "基本信息", action: onShowBasicInfo),
            FeatureEntry(id: "documents",    symbol: "doc.fill",    title: "证件保障", action: onShowDocuments),
            FeatureEntry(id: "moments",      symbol: "sparkles",    title: "重要时刻", action: onShowMoments),
            FeatureEntry(id: "achievements", symbol: "trophy.fill", title: "成就",     action: onShowAchievements),
        ]

        return [
            FeatureSection(id: "health",  symbol: "cross.fill",   title: "健康管理", entries: healthEntries),
            FeatureSection(id: "daily",   symbol: "sun.max.fill", title: "日常生活", entries: dailyEntries),
            FeatureSection(id: "archive", symbol: "folder.fill",  title: "档案与记忆", entries: archiveEntries),
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
                    SIMD2(0.0, 1.0), SIMD2(0.5,  1.0), SIMD2(1.0, 1.0)
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
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Section view
    private func sectionView(_ section: FeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: section.symbol)
                    .font(.system(size: 7, weight: .bold))
                Text(section.title)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .kerning(0.3)
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 0.5)
            }
            .foregroundStyle(.white.opacity(0.55))

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
                    .font(.system(size: 11, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.95))
                Text(entry.title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(spacing: 6) {
            if let data = pet.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 24, height: 24).clipShape(Circle())
            } else {
                Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: pet.species))
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.15), in: Circle())
            }

            Text(pet.name)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Button { onShowSettings() } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.13), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
