//
//  WalletPetCardBack.swift
//  Ohana
//
//  宠物卡片背面 — 2×4 功能枢纽，全部功能入口，物种感知
//

import SwiftUI

struct WalletPetCardBack: View {
    let pet: Pet
    let cornerRadius: CGFloat

    // MARK: - Callbacks (existing)
    var onShowSettings:     () -> Void = {}
    var onShowDocuments:    () -> Void = {}
    var onShowMoments:      () -> Void = {}
    var onShowAchievements: () -> Void = {}
    var onShowHealth:       () -> Void = {}
    var onFlipBack:         () -> Void = {}

    // MARK: - Callbacks (new)
    var onShowCalendar:    () -> Void = {}
    var onShowMedications: () -> Void = {}
    var onShowFood:        () -> Void = {}
    var onShowEdit:        () -> Void = {}

    // MARK: - Feature entry definition
    private struct FeatureEntry: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let action: () -> Void
    }

    /// 8 入口，2 行 × 4 列，根据物种过滤用药格
    private var backEntries: [FeatureEntry] {
        var entries: [FeatureEntry] = [
            FeatureEntry(id: "edit",         symbol: "pencil",           title: "编辑信息", action: onShowEdit),
            FeatureEntry(id: "calendar",     symbol: "calendar",         title: "日历",   action: onShowCalendar),
            FeatureEntry(id: "health",       symbol: "stethoscope",      title: "健康档案", action: onShowHealth),
            FeatureEntry(id: "documents",    symbol: "doc.fill",         title: "证件保障", action: onShowDocuments),
            FeatureEntry(id: "moments",      symbol: "sparkles",         title: "重要时刻", action: onShowMoments),
            FeatureEntry(id: "achievements", symbol: "trophy.fill",      title: "成就",   action: onShowAchievements),
            FeatureEntry(id: "food",         symbol: "fork.knife",       title: "饮食管理", action: onShowFood),
        ]
        // 用药：鱼类/非哺乳类宠物一般不需要，可扩展过滤
        let noMedSpecies: Set<String> = ["鱼"]
        if !noMedSpecies.contains(pet.species) {
            entries.append(FeatureEntry(id: "medications", symbol: "pills.fill", title: "用药管理", action: onShowMedications))
        }
        return entries
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            // MeshGradient 背景（与 WalletPetCardDraftFront 一致的主题色渐变）
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

            // 顶部暗渐变遮罩，提升顶栏可读性
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            VStack(spacing: 6) {
                topBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                LazyVGrid(columns: gridColumns, spacing: 7) {
                    ForEach(backEntries) { entry in
                        featureTile(entry: entry)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Feature Tile
    private func featureTile(entry: FeatureEntry) -> some View {
        Button { entry.action() } label: {
            VStack(spacing: 4) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(height: 20)
                Text(entry.title)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 6) {
            // Avatar
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

            // Settings gear
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
