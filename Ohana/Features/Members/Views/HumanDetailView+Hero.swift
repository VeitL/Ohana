//
//  HumanDetailView+Hero.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension HumanDetailView {
    var heroCard: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
                .frame(maxWidth: .infinity)

            ZStack {
                humanAvatar(size: 100)
            }

            VStack(spacing: 10) {
                Text(human.name)
                    .font(OhanaFont.metric(size: 34))
                    .foregroundStyle(Color(hex: "1E3A8A"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        humanChip(human.roleText, color: themeColor)
                        if human.birthday != nil { humanChip(human.ageText, color: Color(hex: "6B82C4")) }
                        if !human.bloodType.isEmpty { humanChip("血型 \(human.bloodType)", color: Color.goRed) }
                        if !human.nationality.isEmpty { humanChip("🌍 \(human.nationality)", color: Color(hex: "6B82C4")) }
                        if !human.city.isEmpty { humanChip("📍 \(human.city)", color: Color(hex: "6B82C4")) }
                        if human.heightCm > 0 && human.heightCm.isFinite { humanChip(String(format: "%.0f cm", human.heightCm), color: Color.goTeal) }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
        .goIslandModuleCard(cornerRadius: 28)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func humanAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "EEF2FF"))
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(themeColor.opacity(0.2), lineWidth: 1.5))

            if !avatarSignature.isEmpty,
               let image = avatarPipeline.cachedImage(for: human.id, signature: avatarSignature) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(OhanaFont.metric(size: size * 0.5))
                    .minimumScaleFactor(0.55)
            }
        }
        .overlay(Circle().strokeBorder(themeColor.opacity(0.35), lineWidth: 2.5))
    }

    var avatarSourceKey: String {
        "\(human.id.uuidString):\(human.avatarImageData?.count ?? 0)"
    }

    func prepareAvatar() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        guard let data = human.avatarImageData else {
            avatarPipeline.cancel(key: avatarCacheKey)
            avatarSignature = ""
            avatarCacheKey = "human-detail-avatar-empty"
            return
        }

        let signature = FocusWalletAvatarCache.signature(for: data)
        let nextKey = "human-detail-avatar-\(human.id.uuidString)-\(data.count)"
        if avatarCacheKey != nextKey {
            avatarPipeline.cancel(key: avatarCacheKey)
            avatarCacheKey = nextKey
        }
        avatarSignature = signature
        let payload = FocusWalletAvatarCache.Payload(id: human.id, data: data)
        avatarPipeline.seedPreviewEntries([payload])
        avatarPipeline.preload(
            payloads: [payload],
            key: nextKey,
            delayMilliseconds: 48
        )
    }

    func presentCoconutLog() {
        onPresentCoconutLog(.human(human.id))
    }

    // MARK: - Stats Bento（与 GO「岛屿统计」小卡同款：白底 + 轻阴影）
}
