//
//  SettingsHumanIdentityAvatar.swift
//  Ohana
//

import SwiftUI
import UIKit

struct SettingsHumanIdentityAvatar: View {
    let human: Human
    let isSelected: Bool
    @State var avatarImage: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.goPrimary.opacity(0.20) : Color.ohanaControlFill)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2))

            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
        }
        .task(id: avatarSignature) {
            await loadAvatarImage()
        }
    }

    var avatarSignature: String {
        human.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
    }

    @MainActor
    func loadAvatarImage() async {
        guard !avatarSignature.isEmpty else {
            avatarImage = nil
            return
        }
        if let image = FocusWalletAvatarCache.cachedEntry(for: human.id, signature: avatarSignature)?.image {
            avatarImage = image
            return
        }
        await FocusWalletAvatarCache.preload(payloads: [
            FocusWalletAvatarCache.Payload(id: human.id, data: human.avatarImageData)
        ])
        guard !Task.isCancelled else { return }
        avatarImage = FocusWalletAvatarCache.cachedEntry(for: human.id, signature: avatarSignature)?.image
    }
}
