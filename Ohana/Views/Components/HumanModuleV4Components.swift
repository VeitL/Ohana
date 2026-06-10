//
//  HumanModuleV4Components.swift
//  Ohana
//
//  Shared V4 chrome for human module pages.
//

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
                imageData: human.avatarImageData,
                emoji: human.avatarEmoji,
                fallback: "👤",
                tint: Color(hex: human.safeThemeColorHex)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)
            trailing

            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
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
                .font(OhanaFont.adaptive(size: 34, weight: .black))
                .foregroundStyle(Color.goYellow)
            Text(title)
                .font(OhanaFont.title3(.black))
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
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                Text(title)
                    .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 22)
            .frame(height: 54)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
