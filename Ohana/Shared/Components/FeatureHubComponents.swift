//
//  FeatureHubComponents.swift
//  Ohana
//
//  Shared V4 feature hub components and memorial-mode visuals.
//

import SwiftData
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
    var showsNewFeature: Bool = false
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
    let imageCacheID: String?
    let imageSignature: String
    private let imageDataProvider: (@MainActor () -> Data?)?
    private let asyncImageDataProvider: (@Sendable () async -> Data?)?
    private let imageBlobSource: FeatureHubAvatarBlobSource?
    let emoji: String
    let fallback: String
    let tint: Color

    @Environment(\.modelContext) private var modelContext

    @State private var lazyImage: UIImage?
    @State private var lazyImageIsTransparent = false
    @State private var loadedLazyImageKey: MediaThumbnailKey?

    init(
        image: UIImage? = nil,
        imageData: Data?,
        emoji: String,
        fallback: String,
        tint: Color
    ) {
        self.image = image
        self.imageData = imageData
        self.imageCacheID = nil
        self.imageSignature = imageData.map(MediaPayloadSignature.signature(for:)) ?? ""
        self.imageDataProvider = nil
        self.asyncImageDataProvider = nil
        self.imageBlobSource = nil
        self.emoji = emoji
        self.fallback = fallback
        self.tint = tint
    }

    init(
        image: UIImage? = nil,
        imageCacheID: String,
        imageSignature: String,
        imageDataProvider: @escaping @MainActor () -> Data?,
        emoji: String,
        fallback: String,
        tint: Color
    ) {
        self.image = image
        self.imageData = nil
        self.imageCacheID = imageCacheID
        self.imageSignature = imageSignature
        self.imageDataProvider = imageDataProvider
        self.asyncImageDataProvider = nil
        self.imageBlobSource = nil
        self.emoji = emoji
        self.fallback = fallback
        self.tint = tint
    }

    init(
        image: UIImage? = nil,
        imageCacheID: String,
        imageSignature: String,
        asyncImageDataProvider: @escaping @Sendable () async -> Data?,
        emoji: String,
        fallback: String,
        tint: Color
    ) {
        self.image = image
        self.imageData = nil
        self.imageCacheID = imageCacheID
        self.imageSignature = imageSignature
        self.imageDataProvider = nil
        self.asyncImageDataProvider = asyncImageDataProvider
        self.imageBlobSource = nil
        self.emoji = emoji
        self.fallback = fallback
        self.tint = tint
    }

    init(
        image: UIImage? = nil,
        imageCacheID: String,
        imageSignature: String,
        petModelID: PersistentIdentifier,
        emoji: String,
        fallback: String,
        tint: Color
    ) {
        self.image = image
        self.imageData = nil
        self.imageCacheID = imageCacheID
        self.imageSignature = imageSignature
        self.imageDataProvider = nil
        self.asyncImageDataProvider = nil
        self.imageBlobSource = .pet(petModelID)
        self.emoji = emoji
        self.fallback = fallback
        self.tint = tint
    }

    init(
        image: UIImage? = nil,
        imageCacheID: String,
        imageSignature: String,
        humanModelID: PersistentIdentifier,
        emoji: String,
        fallback: String,
        tint: Color
    ) {
        self.image = image
        self.imageData = nil
        self.imageCacheID = imageCacheID
        self.imageSignature = imageSignature
        self.imageDataProvider = nil
        self.asyncImageDataProvider = nil
        self.imageBlobSource = .human(humanModelID)
        self.emoji = emoji
        self.fallback = fallback
        self.tint = tint
    }

    init(
        image: UIImage? = nil,
        imageCacheID: String,
        imageSignature: String,
        plantModelID: PersistentIdentifier,
        emoji: String,
        fallback: String,
        tint: Color
    ) {
        self.image = image
        self.imageData = nil
        self.imageCacheID = imageCacheID
        self.imageSignature = imageSignature
        self.imageDataProvider = nil
        self.asyncImageDataProvider = nil
        self.imageBlobSource = .plant(plantModelID)
        self.emoji = emoji
        self.fallback = fallback
        self.tint = tint
    }

    private var lazyThumbnailKey: MediaThumbnailKey {
        MediaThumbnailKey(
            id: imageCacheID ?? "feature-hub-avatar-\(imageSignature)",
            sourceSignature: imageSignature,
            maxPixel: 160
        )
    }

    var body: some View {
        let hasLazyDataSource = imageDataProvider != nil || asyncImageDataProvider != nil || imageBlobSource != nil

        ZStack {
            if let image {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
            } else if hasLazyDataSource, !imageSignature.isEmpty {
                lazyAvatar
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

    @ViewBuilder
    private var lazyAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .fill(tint.opacity(0.18))

            if let image = resolvedLazyImage {
                lazyAvatarImage(image, isTransparent: lazyImageIsTransparent)
            } else {
                Text((emoji.isEmpty ? fallback : emoji).isEmpty ? "🐾" : (emoji.isEmpty ? fallback : emoji))
                    .font(.system(size: 58 * 0.52)) // a11y: allow decorative avatar emoji inside fixed avatar frame.
                    .minimumScaleFactor(0.5)
            }
        }
        .task(id: lazyThumbnailKey) {
            await loadLazyAvatarImage(for: lazyThumbnailKey)
        }
    }

    private var resolvedLazyImage: UIImage? {
        if loadedLazyImageKey == lazyThumbnailKey, let lazyImage {
            return lazyImage
        }
        return MediaThumbnailProvider.cachedImage(for: lazyThumbnailKey)
    }

    @ViewBuilder
    private func lazyAvatarImage(_ image: UIImage, isTransparent: Bool) -> some View {
        if isTransparent {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 58 * 0.84, height: 58 * 1.18, alignment: .top)
                .offset(y: 58 * 0.12)
                .frame(width: 58, height: 58)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
        }
    }

    @MainActor
    private func loadLazyAvatarImage(for key: MediaThumbnailKey) async {
        let resolvedAsyncImageDataProvider = resolvedAsyncImageDataProvider
        let result: MediaThumbnailProvider.Result? = if let resolvedAsyncImageDataProvider {
            await MediaThumbnailProvider.imageWithTransparency(for: key, asyncDataProvider: resolvedAsyncImageDataProvider)
        } else if let asyncImageDataProvider {
            await MediaThumbnailProvider.imageWithTransparency(for: key, asyncDataProvider: asyncImageDataProvider)
        } else if let imageDataProvider {
            await MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: imageDataProvider)
        } else {
            nil
        }

        guard let result, !Task.isCancelled else {
            lazyImage = nil
            loadedLazyImageKey = key
            lazyImageIsTransparent = false
            return
        }

        lazyImage = result.image
        lazyImageIsTransparent = result.isTransparent
        loadedLazyImageKey = key
    }

    private var resolvedAsyncImageDataProvider: (@Sendable () async -> Data?)? {
        guard let imageBlobSource else {
            return nil
        }
        let container = modelContext.container
        return {
            let loader = SwiftDataMediaBlobLoader(modelContainer: container)
            switch imageBlobSource {
            case let .pet(modelID):
                return await loader.petAvatarImageData(modelID: modelID)
            case let .human(modelID):
                return await loader.humanAvatarImageData(modelID: modelID)
            case let .plant(modelID):
                return await loader.plantAvatarImageData(modelID: modelID)
            }
        }
    }
}

private enum FeatureHubAvatarBlobSource: Sendable {
    case pet(PersistentIdentifier)
    case human(PersistentIdentifier)
    case plant(PersistentIdentifier)
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
                    .accessibilityIdentifier("feature-hub-\(section.id)-\(item.id)")
                }
            }
        }
    }
}

private struct FeatureHubTile: View {
    let data: FeatureHubTileData

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            if data.showsNewFeature {
                GrowthNewFeatureDot()
                    .offset(x: 4, y: -4)
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
