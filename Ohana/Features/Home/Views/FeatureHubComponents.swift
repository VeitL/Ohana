//
//  FeatureHubComponents.swift
//  Ohana
//
//  Shared V4 feature hub components and memorial-mode visuals.
//

import SwiftUI
import UIKit

struct FeatureHubMetric: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
}

struct FeatureHubTileData: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
}

struct FeatureHubDestinationItem<Destination: Hashable>: Identifiable {
    let data: FeatureHubTileData
    let destination: Destination

    var id: String { data.id }
}

struct FeatureHubSectionData<Destination: Hashable>: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let items: [FeatureHubDestinationItem<Destination>]
}

struct FeatureHubScaffold<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    init(@ViewBuilder _ header: () -> Header, @ViewBuilder content: () -> Content) {
        self.header = header()
        self.content = content()
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
    }
}

struct FeatureHubHeader<Avatar: View>: View {
    let title: String
    let subtitle: String
    let eyebrow: String
    let onClose: () -> Void
    @ViewBuilder var avatar: Avatar

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            }
            .buttonStyle(ScaleButtonStyle())
            .contentShape(Circle())
        }
    }
}

struct FeatureHubAvatar: View {
    var image: UIImage?
    let imageData: Data?
    let emoji: String
    let fallback: String
    let tint: Color

    var body: some View {
        ZStack {
            if let image {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
            } else {
                PetAvatarPortraitRoundedView(
                    imageData: imageData,
                    fallbackText: emoji.isEmpty ? fallback : emoji,
                    themeColor: tint,
                    size: 58,
                    cornerRadius: OhanaRadius.controlLarge,
                    backgroundOpacity: 0.18
                )
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }
}

struct FeatureHubMetricStrip: View {
    let metrics: [FeatureHubMetric]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.title)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(metric.value)
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .ohanaNumericMotion(metric.value)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                .ohanaSmoothAppear(index: index)
            }
        }
    }
}

struct FeatureHubDestinationHost<Content: View>: View {
    let onClose: () -> Void
    var showsCloseButton: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OhanaAppBackground().ignoresSafeArea()
            content

            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
                .padding(.top, 10)
                .padding(.trailing, 14)
                .zIndex(30)
            }
        }
    }
}

struct FeatureHubSectionView<Destination: Hashable>: View {
    let section: FeatureHubSectionData<Destination>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item.destination) {
                        FeatureHubTile(data: item.data)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .ohanaSmoothAppear(index: index)
                }
            }
        }
    }
}

struct FeatureHubSectionActionView<Destination: Hashable>: View {
    let section: FeatureHubSectionData<Destination>
    let onSelect: (Destination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(item.destination)
                    } label: {
                        FeatureHubTile(data: item.data)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .ohanaSmoothAppear(index: index)
                }
            }
        }
    }
}

private struct FeatureHubTile: View {
    let data: FeatureHubTileData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: data.icon)
                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaFunctionalIcon)
                    .ohanaSymbolPulse(trigger: data.value)
                Spacer()
                Text(data.value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .ohanaNumericMotion(data.value)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(data.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(data.subtitle)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .ohanaStateMotion(data)
    }
}

struct PetMemorialBanner: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPurple)
                .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPurple.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("彩虹桥纪念模式")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(memorialDetail)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.goPurple.opacity(0.25), lineWidth: 1)
        }
    }

    private var memorialDetail: String {
        let days = pet.daysTogetherAtPassing
        if let date = pet.passedAwayDate {
            return "离世 \(date.formatted(.dateTime.year().month().day())) · 相伴 \(days) 天"
        }
        return "相伴 \(days) 天"
    }
}

struct PetMemorialBadge: View {
    let passedAwayDate: Date?
    let daysTogether: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(daysTogether > 0 ? "\(daysTogether)d" : "纪念")
                .font(OhanaFont.caption2(.black))
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.ohanaControlFill, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let passedAwayDate {
            return "纪念模式，离世日期 \(passedAwayDate.formatted(.dateTime.year().month().day()))"
        }
        return "纪念模式"
    }
}

private struct PetMemorialToneModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .saturation(isActive ? 0.08 : 1)
            .grayscale(isActive ? 0.88 : 0)
            .contrast(isActive ? 0.94 : 1)
            .overlay {
                if isActive {
                    Color.arkInk.opacity(0.05)
                        .allowsHitTesting(false)
                }
            }
            .animation(GoMotion.page, value: isActive)
    }
}

extension View {
    func petMemorialTone(isActive: Bool) -> some View {
        modifier(PetMemorialToneModifier(isActive: isActive))
    }
}
