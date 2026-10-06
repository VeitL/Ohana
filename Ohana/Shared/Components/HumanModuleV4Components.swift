//
//  HumanModuleV4Components.swift
//  Ohana
//
//  Shared V4 chrome for human module pages.
//

import SwiftData
import SwiftUI

struct HumanModulePageHeader<Trailing: View>: View {
    let human: Human
    let title: String
    let subtitle: String
    var showsCloseButton = true
    let onClose: () -> Void
    @ViewBuilder var trailing: Trailing

    init(
        human: Human,
        title: String,
        subtitle: String,
        showsCloseButton: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.human = human
        self.title = title
        self.subtitle = subtitle
        self.showsCloseButton = showsCloseButton
        self.onClose = onClose
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            FeatureHubAvatar(
                imageCacheID: "human-module-\(human.id.uuidString)",
                imageSignature: human.avatarThumbnailSignature,
                humanModelID: human.persistentModelID,
                emoji: human.avatarEmoji,
                fallback: "👤",
                tint: Color(hex: human.safeThemeColorHex)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.title2(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            trailing


        }
        .toolbar {
            if showsCloseButton {
                OhanaModalToolbar(onClose: onClose, closeIdentifier: "human-module-close-action")
            }
        }

    }
}

extension HumanModulePageHeader where Trailing == EmptyView {
    init(
        human: Human,
        title: String,
        subtitle: String,
        showsCloseButton: Bool = true,
        onClose: @escaping () -> Void
    ) {
        self.init(
            human: human,
            title: title,
            subtitle: subtitle,
            showsCloseButton: showsCloseButton,
            onClose: onClose
        ) {
            EmptyView()
        }
    }
}

struct HumanModuleMetricStrip: View {
    let metrics: [FeatureHubMetric]

    var body: some View {
        FeatureHubMetricStrip(metrics: metrics)
    }
}

struct HumanModulePrivacyLockedView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 34, weight: .semibold))
                .foregroundStyle(Color.goYellow)
            Text(title)
                .font(OhanaFont.title3(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }
}

struct HumanModuleFloatingActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .semibold))
                Text(title)
                    .font(OhanaFont.callout(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(minHeight: 54)
        }
        .ohanaGlassProminentButton()
    }
}
