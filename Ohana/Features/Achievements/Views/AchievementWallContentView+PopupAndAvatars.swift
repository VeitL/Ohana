//
//  AchievementWallContentView+PopupAndAvatars.swift
//  Ohana
//

import SwiftUI
import UIKit

extension AchievementWallContentView {
    var achievementProgressFill: LinearGradient {
        LinearGradient(
            colors: [Color.goPrimaryLight, Color.goPrimary, Color.goPrimaryDark],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    func progressBar(_ value: Double, tint _: Color, track: Color = Color.ohanaControlFill) -> some View {
        let progress = min(max(value, 0), 1)

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if progress > 0 {
                    Capsule()
                        .fill(achievementProgressFill)
                        .frame(width: max(6, proxy.size.width * progress))
                        .overlay {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.ohanaPrimaryActionText.opacity(0.24), Color.ohanaPrimaryActionText.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                }
            }
        }
        .frame(height: 8)
        .animation(GoMotion.stateChange, value: progress)
    }

    func achievementPopup(_ badge: Achievement) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    achievementDownloadCard(for: badge)
                    if rewardState(for: badge) == .claimable {
                        Button(l.tr(zh: "领取 +\(rewardPerAchievement)🥥", en: "Claim +\(rewardPerAchievement)🥥", de: "+\(rewardPerAchievement)🥥 abholen")) {
                            pendingClaimAchievement = badge
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
            }
            .navigationTitle(badge.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                OhanaModalToolbar(onClose: closePopup)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await renderAndShareAchievement(badge) }
                    } label: {
                        Label(l.tr(zh: "分享", en: "Share", de: "Teilen"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(isRenderingAchievementShareImage)
                }
            }
            .confirmationDialog(
                l.tr(zh: "领取成就奖励", en: "Claim badge reward", de: "Abzeichen-Belohnung abholen"),
                isPresented: Binding(get: { pendingClaimAchievement != nil }, set: { if !$0 { pendingClaimAchievement = nil } }),
                titleVisibility: .visible
            ) {
                Button(l.tr(zh: "确认", en: "Claim", de: "Abholen")) {
                    guard let pending = pendingClaimAchievement else { return }
                    pendingClaimAchievement = nil
                    claimReward(for: pending)
                }
                Button(l.cancel, role: .cancel) { pendingClaimAchievement = nil }
            }
            .sheet(isPresented: $showingAchievementShareSheet) {
                if let achievementShareImage { ShareSheet(image: achievementShareImage) }
            }
        }
    }

    @ViewBuilder
    func achievementPopupArtwork(for badge: Achievement, state: AchievementRewardState) -> some View {
        let backgroundName = achievementBackgroundName(for: badge)

        ZStack(alignment: .bottomLeading) {
            if let backgroundName {
                Image(backgroundName)
                    .resizable()
                    .scaledToFill()
                    .saturation(state == .locked ? 0.34 : 1)
            } else {
                badge.color
            }
        }
        .aspectRatio(achievementArtworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
    }



    @MainActor
    func renderAndShareAchievement(_ badge: Achievement) async {
        guard !isRenderingAchievementShareImage else { return }
        isRenderingAchievementShareImage = true
        defer { isRenderingAchievementShareImage = false }

        let renderer = ImageRenderer(
            content: achievementDownloadCard(for: badge)
                .frame(width: achievementPopupMaxImageWidth, height: achievementPopupMaxImageWidth / achievementArtworkAspectRatio)
        )
        renderer.scale = 2
        if let image = renderer.uiImage {
            achievementShareImage = image
            showingAchievementShareSheet = true
        }
    }

    func achievementDownloadCard(for badge: Achievement) -> some View {
        let state = rewardState(for: badge)
        let completionText = achievementCompletionText(for: badge, state: state)

        return ZStack(alignment: .bottomLeading) {
            achievementPopupArtwork(for: badge, state: state)

            VStack(alignment: .leading, spacing: 8) {
                Text(badge.title)
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite)

                Text(statusTitle(for: state))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite.opacity(0.82))

                Text(achievementMomentLine(for: badge))
                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite.opacity(0.92))
                    .lineLimit(2)

                Text(completionText)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite.opacity(0.78))
            }
            .padding(22)
            .shadow(color: Color.arkInk.opacity(0.48), radius: 6, x: 0, y: 2) // ui-v4: allow exported artwork text readability without image wash
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
    }

    func closePopup() {
        selectedAchievement = nil
        pendingClaimAchievement = nil
    }

    @ViewBuilder
    func activeMemberAvatar(size: CGFloat) -> some View {
        switch activeSubject {
        case let .human(id):
            if let human = humans.first(where: { $0.id == id }) {
                humanAvatar(human, size: size, isSelected: true)
            }
        case .pet:
            PetAvatarPortraitView(
                pet: activePet,
                size: size,
                backgroundOpacity: 0.16,
                transparentScale: 0.76,
                transparentYOffset: 0.04
            )
        }
    }

    @ViewBuilder
    func memberAvatar(for subject: AchievementSubject, size: CGFloat, isSelected: Bool) -> some View {
        switch subject {
        case let .pet(id):
            if let item = pets.first(where: { $0.id == id }) {
                PetAvatarPortraitView(
                    pet: item,
                    size: size,
                    backgroundOpacity: isSelected ? 0.22 : 0.12,
                    transparentScale: 0.76,
                    transparentYOffset: 0.04
                )
            }
        case let .human(id):
            if let human = humans.first(where: { $0.id == id }) {
                humanAvatar(human, size: size, isSelected: isSelected)
            }
        }
    }

    func memberName(for subject: AchievementSubject) -> String {
        switch subject {
        case let .pet(id):
            pets.first(where: { $0.id == id })?.name ?? ""
        case let .human(id):
            humans.first(where: { $0.id == id })?.name ?? ""
        }
    }

    @ViewBuilder
    func humanAvatar(_ human: Human, size: CGFloat, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                .fill(Color(hex: human.safeThemeColorHex).opacity(isSelected ? 0.24 : 0.14))

            if let signature = humanAvatarSignatures[human.id],
               let image = avatarPipeline.cachedImage(for: human.id, signature: signature) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.82, height: size * 0.82)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else {
                Text(String(human.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
        .frame(width: size, height: size)
    }

    @MainActor
    func prepareHumanAvatars() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
        guard !Task.isCancelled else { return }

        var signatures: [UUID: String] = [:]
        var payloads: [FocusWalletAvatarCache.Payload] = []
        for human in humans {
            guard human.hasAvatarImageAttachment,
                  let data = human.avatarImageData else { continue }
            let signature = human.avatarThumbnailSignature
            signatures[human.id] = signature
            payloads.append(FocusWalletAvatarCache.Payload(id: human.id, data: data))
        }

        let nextKey = payloads
            .map { "\($0.id.uuidString):\(signatures[$0.id] ?? "")" }
            .joined(separator: "|")
        let cacheKey = nextKey.isEmpty ? "achievement-wall-human-avatar-empty" : "achievement-wall-\(nextKey)"
        if humanAvatarCacheKey != cacheKey {
            avatarPipeline.cancel(key: humanAvatarCacheKey)
            humanAvatarCacheKey = cacheKey
        }
        humanAvatarSignatures = signatures
        guard !payloads.isEmpty else { return }
        avatarPipeline.seedPreviewEntries(payloads, key: cacheKey)
        avatarPipeline.preload(
            payloads: payloads,
            key: cacheKey,
            delayMilliseconds: 56
        )
    }

    @MainActor
    func prepareHumanActivityIndex() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
        guard !Task.isCancelled else { return }
        humanActivityIndex = AchievementHumanActivityIndex.make(
            medications: humanMedications,
            medicationLogs: humanMedicationLogs,
            expenses: allExpenseLogs
        )
    }

    struct ProgressInfo {
        let current: Double
        let target: Double
        let unit: String
        let actionTitle: String

        var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1, max(0, current / target))
        }

        var summary: String {
            "\(formatted(current))/\(formatted(target))\(unit)"
        }

        func formatted(_ value: Double) -> String {
            if value.rounded() == value { return "\(Int(value))" }
            return String(format: "%.1f", value)
        }
    }
}
