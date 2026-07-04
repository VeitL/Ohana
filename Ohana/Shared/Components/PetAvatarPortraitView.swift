import SwiftData
import SwiftUI
import UIKit

struct PetAvatarPortraitView: View {
    var cacheID: UUID?
    let imageData: Data?
    let imageSignature: String
    private let petModelID: PersistentIdentifier?
    private let imageDataProvider: (@MainActor () -> Data?)?
    let fallbackText: String
    let themeColor: Color
    let size: CGFloat
    var showsBackground: Bool = true
    var backgroundOpacity: Double = 0.18
    var transparentScale: CGFloat = 0.84
    var transparentYOffset: CGFloat = 0.12

    @Environment(\.modelContext) private var modelContext

    init(
        cacheID: UUID? = nil,
        imageData: Data?,
        fallbackText: String,
        themeColor: Color,
        size: CGFloat,
        showsBackground: Bool = true,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.cacheID = cacheID
        self.imageData = imageData
        self.imageSignature = imageData.map(MediaPayloadSignature.signature(for:)) ?? ""
        petModelID = nil
        self.imageDataProvider = nil
        self.fallbackText = fallbackText
        self.themeColor = themeColor
        self.size = size
        self.showsBackground = showsBackground
        self.backgroundOpacity = backgroundOpacity
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    init(
        cacheID: UUID? = nil,
        imageSignature: String,
        imageDataProvider: @escaping @MainActor () -> Data?,
        fallbackText: String,
        themeColor: Color,
        size: CGFloat,
        showsBackground: Bool = true,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.cacheID = cacheID
        self.imageData = nil
        self.imageSignature = imageSignature
        petModelID = nil
        self.imageDataProvider = imageDataProvider
        self.fallbackText = fallbackText
        self.themeColor = themeColor
        self.size = size
        self.showsBackground = showsBackground
        self.backgroundOpacity = backgroundOpacity
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    init(
        cacheID: UUID? = nil,
        imageSignature: String,
        petModelID: PersistentIdentifier,
        fallbackText: String,
        themeColor: Color,
        size: CGFloat,
        showsBackground: Bool = true,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.cacheID = cacheID
        imageData = nil
        self.imageSignature = imageSignature
        self.petModelID = petModelID
        imageDataProvider = nil
        self.fallbackText = fallbackText
        self.themeColor = themeColor
        self.size = size
        self.showsBackground = showsBackground
        self.backgroundOpacity = backgroundOpacity
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    var body: some View {
        let asyncProvider = resolvedAsyncImageDataProvider

        ZStack {
            if showsBackground {
                Circle()
                    .fill(themeColor.opacity(backgroundOpacity))
            }

            if let imageData {
                PetAvatarPortraitCachedCircleImage(
                    cacheID: cacheID,
                    imageData: imageData,
                    fallbackText: fallbackText,
                    size: size,
                    transparentScale: transparentScale,
                    transparentYOffset: transparentYOffset
                )
            } else if imageDataProvider != nil || asyncProvider != nil, !imageSignature.isEmpty {
                PetAvatarPortraitLazyImage(
                    style: .circle,
                    cacheID: cacheID,
                    imageSignature: imageSignature,
                    imageDataProvider: imageDataProvider,
                    asyncImageDataProvider: asyncProvider,
                    fallbackText: fallbackText,
                    size: size,
                    transparentScale: transparentScale,
                    transparentYOffset: transparentYOffset
                )
            } else {
                PetAvatarPortraitFallbackText(text: fallbackText, size: size)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .accessibilityHidden(fallbackText.isEmpty)
    }

    private var resolvedAsyncImageDataProvider: (@Sendable () async -> Data?)? {
        guard let petModelID else {
            return nil
        }
        let container = modelContext.container
        return {
            let loader = SwiftDataMediaBlobLoader(modelContainer: container)
            return await loader.petAvatarImageData(modelID: petModelID)
        }
    }
}

extension PetAvatarPortraitView {
    init(
        pet: Pet,
        fallbackText: String? = nil,
        themeColor: Color? = nil,
        size: CGFloat,
        showsBackground: Bool = true,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.init(
            cacheID: pet.id,
            imageSignature: pet.avatarThumbnailSignature,
            petModelID: pet.persistentModelID,
            fallbackText: fallbackText ?? (pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji),
            themeColor: themeColor ?? Color(hex: pet.safeThemeColorHex),
            size: size,
            showsBackground: showsBackground,
            backgroundOpacity: backgroundOpacity,
            transparentScale: transparentScale,
            transparentYOffset: transparentYOffset
        )
    }
}

struct PetAvatarPortraitImage: View {
    let image: UIImage
    let isTransparentAvatar: Bool
    let size: CGFloat
    var transparentScale: CGFloat = 0.84
    var transparentYOffset: CGFloat = 0.12

    var body: some View {
        if isTransparentAvatar {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size * transparentScale, height: size * 1.18, alignment: .top)
                .offset(y: size * transparentYOffset)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }
}

struct PetAvatarPortraitRoundedView: View {
    var cacheID: UUID?
    let imageData: Data?
    let imageSignature: String
    private let petModelID: PersistentIdentifier?
    private let imageDataProvider: (@MainActor () -> Data?)?
    let fallbackText: String
    let themeColor: Color
    let size: CGFloat
    var cornerRadius: CGFloat = 18
    var backgroundOpacity: Double = 0.18
    var transparentScale: CGFloat = 0.84
    var transparentYOffset: CGFloat = 0.12

    @Environment(\.modelContext) private var modelContext

    init(
        cacheID: UUID? = nil,
        imageData: Data?,
        fallbackText: String,
        themeColor: Color,
        size: CGFloat,
        cornerRadius: CGFloat = 18,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.cacheID = cacheID
        self.imageData = imageData
        self.imageSignature = imageData.map(MediaPayloadSignature.signature(for:)) ?? ""
        petModelID = nil
        self.imageDataProvider = nil
        self.fallbackText = fallbackText
        self.themeColor = themeColor
        self.size = size
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    init(
        cacheID: UUID? = nil,
        imageSignature: String,
        imageDataProvider: @escaping @MainActor () -> Data?,
        fallbackText: String,
        themeColor: Color,
        size: CGFloat,
        cornerRadius: CGFloat = 18,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.cacheID = cacheID
        self.imageData = nil
        self.imageSignature = imageSignature
        petModelID = nil
        self.imageDataProvider = imageDataProvider
        self.fallbackText = fallbackText
        self.themeColor = themeColor
        self.size = size
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    init(
        cacheID: UUID? = nil,
        imageSignature: String,
        petModelID: PersistentIdentifier,
        fallbackText: String,
        themeColor: Color,
        size: CGFloat,
        cornerRadius: CGFloat = 18,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.cacheID = cacheID
        imageData = nil
        self.imageSignature = imageSignature
        self.petModelID = petModelID
        imageDataProvider = nil
        self.fallbackText = fallbackText
        self.themeColor = themeColor
        self.size = size
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    init(
        pet: Pet,
        fallbackText: String? = nil,
        themeColor: Color? = nil,
        size: CGFloat,
        cornerRadius: CGFloat = 18,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.init(
            cacheID: pet.id,
            imageSignature: pet.avatarThumbnailSignature,
            petModelID: pet.persistentModelID,
            fallbackText: fallbackText ?? (pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji),
            themeColor: themeColor ?? Color(hex: pet.safeThemeColorHex),
            size: size,
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            transparentScale: transparentScale,
            transparentYOffset: transparentYOffset
        )
    }

    var body: some View {
        let asyncProvider = resolvedAsyncImageDataProvider

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(themeColor.opacity(backgroundOpacity))

            if let imageData {
                PetAvatarPortraitCachedRoundedImage(
                    cacheID: cacheID,
                    imageData: imageData,
                    fallbackText: fallbackText,
                    size: size,
                    transparentScale: transparentScale,
                    transparentYOffset: transparentYOffset
                )
            } else if imageDataProvider != nil || asyncProvider != nil, !imageSignature.isEmpty {
                PetAvatarPortraitLazyImage(
                    style: .rounded,
                    cacheID: cacheID,
                    imageSignature: imageSignature,
                    imageDataProvider: imageDataProvider,
                    asyncImageDataProvider: asyncProvider,
                    fallbackText: fallbackText,
                    size: size,
                    transparentScale: transparentScale,
                    transparentYOffset: transparentYOffset
                )
            } else {
                PetAvatarPortraitFallbackText(text: fallbackText, size: size, scale: 0.52)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var resolvedAsyncImageDataProvider: (@Sendable () async -> Data?)? {
        guard let petModelID else {
            return nil
        }
        let container = modelContext.container
        return {
            let loader = SwiftDataMediaBlobLoader(modelContainer: container)
            return await loader.petAvatarImageData(modelID: petModelID)
        }
    }
}

private struct PetAvatarPortraitCachedCircleImage: View {
    let cacheID: UUID?
    let imageData: Data
    let fallbackText: String
    let size: CGFloat
    let transparentScale: CGFloat
    let transparentYOffset: CGFloat

    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current

    private var signature: String {
        FocusWalletAvatarCache.signature(for: imageData)
    }

    private var resolvedCacheID: UUID {
        cacheID ?? PetAvatarPortraitCacheKey.syntheticID(for: signature)
    }

    private var pipelineKey: String {
        "pet-avatar-circle-\(resolvedCacheID.uuidString)-\(signature)"
    }

    var body: some View {
        if let entry = avatarPipeline.cachedEntry(for: resolvedCacheID, signature: signature),
           let image = entry.image {
            PetAvatarPortraitImage(
                image: image,
                isTransparentAvatar: entry.isTransparent,
                size: size,
                transparentScale: transparentScale,
                transparentYOffset: transparentYOffset
            )
        } else {
            PetAvatarPortraitFallbackText(text: fallbackText, size: size)
                .task(id: signature) {
                    AvatarPipelineRegistry.current.preload(
                        payloads: [FocusWalletAvatarCache.Payload(id: resolvedCacheID, data: imageData)],
                        key: pipelineKey,
                        delayMilliseconds: 24
                    )
                }
                .onDisappear {
                    AvatarPipelineRegistry.current.cancel(key: pipelineKey)
                }
        }
    }
}

private struct PetAvatarPortraitCachedRoundedImage: View {
    let cacheID: UUID?
    let imageData: Data
    let fallbackText: String
    let size: CGFloat
    let transparentScale: CGFloat
    let transparentYOffset: CGFloat

    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current

    private var signature: String {
        FocusWalletAvatarCache.signature(for: imageData)
    }

    private var resolvedCacheID: UUID {
        cacheID ?? PetAvatarPortraitCacheKey.syntheticID(for: signature)
    }

    private var pipelineKey: String {
        "pet-avatar-rounded-\(resolvedCacheID.uuidString)-\(signature)"
    }

    var body: some View {
        if let entry = avatarPipeline.cachedEntry(for: resolvedCacheID, signature: signature),
           let image = entry.image {
            PetAvatarPortraitRoundedImage(
                image: image,
                isTransparentAvatar: entry.isTransparent,
                size: size,
                transparentScale: transparentScale,
                transparentYOffset: transparentYOffset
            )
        } else {
            PetAvatarPortraitFallbackText(text: fallbackText, size: size, scale: 0.52)
                .task(id: signature) {
                    AvatarPipelineRegistry.current.preload(
                        payloads: [FocusWalletAvatarCache.Payload(id: resolvedCacheID, data: imageData)],
                        key: pipelineKey,
                        delayMilliseconds: 24
                    )
                }
                .onDisappear {
                    AvatarPipelineRegistry.current.cancel(key: pipelineKey)
                }
        }
    }
}

private enum PetAvatarPortraitLazyStyle {
    case circle
    case rounded
}

private struct PetAvatarPortraitLazyImage: View {
    let style: PetAvatarPortraitLazyStyle
    let cacheID: UUID?
    let imageSignature: String
    let imageDataProvider: (@MainActor () -> Data?)?
    let asyncImageDataProvider: (@Sendable () async -> Data?)?
    let fallbackText: String
    let size: CGFloat
    let transparentScale: CGFloat
    let transparentYOffset: CGFloat

    @State private var image: UIImage?
    @State private var isTransparent = false
    @State private var loadedKey: MediaThumbnailKey?

    init(
        style: PetAvatarPortraitLazyStyle,
        cacheID: UUID?,
        imageSignature: String,
        imageDataProvider: (@MainActor () -> Data?)?,
        asyncImageDataProvider: (@Sendable () async -> Data?)?,
        fallbackText: String,
        size: CGFloat,
        transparentScale: CGFloat,
        transparentYOffset: CGFloat
    ) {
        self.style = style
        self.cacheID = cacheID
        self.imageSignature = imageSignature
        self.imageDataProvider = imageDataProvider
        self.asyncImageDataProvider = asyncImageDataProvider
        self.fallbackText = fallbackText
        self.size = size
        self.transparentScale = transparentScale
        self.transparentYOffset = transparentYOffset
    }

    private var thumbnailKey: MediaThumbnailKey {
        let cacheNamespace: String = switch style {
        case .circle:
            "pet-avatar-circle"
        case .rounded:
            "pet-avatar-rounded"
        }
        return MediaThumbnailKey(
            id: "\(cacheNamespace)-\(cacheID?.uuidString ?? imageSignature)",
            sourceSignature: imageSignature,
            maxPixel: max(160, size * 3)
        )
    }

    var body: some View {
        Group {
            if loadedKey == thumbnailKey, let image {
                avatarImage(image)
            } else {
                fallback
            }
        }
        .task(id: thumbnailKey) {
            await loadImage(for: thumbnailKey)
        }
    }

    @ViewBuilder
    private func avatarImage(_ image: UIImage) -> some View {
        switch style {
        case .circle:
            PetAvatarPortraitImage(
                image: image,
                isTransparentAvatar: isTransparent,
                size: size,
                transparentScale: transparentScale,
                transparentYOffset: transparentYOffset
            )
        case .rounded:
            PetAvatarPortraitRoundedImage(
                image: image,
                isTransparentAvatar: isTransparent,
                size: size,
                transparentScale: transparentScale,
                transparentYOffset: transparentYOffset
            )
        }
    }

    private var fallback: some View {
        PetAvatarPortraitFallbackText(
            text: fallbackText,
            size: size,
            scale: style == .rounded ? 0.52 : 0.48
        )
    }

    @MainActor
    private func loadImage(for key: MediaThumbnailKey) async {
        let result: MediaThumbnailProvider.Result? = if let asyncImageDataProvider {
            await MediaThumbnailProvider.imageWithTransparency(for: key, asyncDataProvider: asyncImageDataProvider)
        } else if let imageDataProvider {
            await MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: imageDataProvider)
        } else {
            nil
        }

        guard let result,
              !Task.isCancelled else {
            image = nil
            loadedKey = key
            isTransparent = false
            return
        }
        image = result.image
        isTransparent = result.isTransparent
        loadedKey = key
    }
}

private struct PetAvatarPortraitRoundedImage: View {
    let image: UIImage
    let isTransparentAvatar: Bool
    let size: CGFloat
    var transparentScale: CGFloat = 0.84
    var transparentYOffset: CGFloat = 0.12

    var body: some View {
        if isTransparentAvatar {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size * transparentScale, height: size * 1.18, alignment: .top)
                .offset(y: size * transparentYOffset)
                .frame(width: size, height: size)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
        }
    }
}

private struct PetAvatarPortraitFallbackText: View {
    let text: String
    let size: CGFloat
    var scale: CGFloat = 0.48

    var body: some View {
        Text(text.isEmpty ? "🐾" : text)
            .font(.system(size: size * scale))
            .minimumScaleFactor(0.5)
    }
}

private enum PetAvatarPortraitCacheKey {
    static func syntheticID(for signature: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in signature.utf8.enumerated() {
            let slot = index % bytes.count
            bytes[slot] = bytes[slot] &* 31 &+ byte &+ UInt8(truncatingIfNeeded: index)
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
