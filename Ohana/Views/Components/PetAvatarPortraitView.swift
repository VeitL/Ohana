import SwiftUI
import UIKit

struct PetAvatarPortraitView: View {
    var cacheID: UUID? = nil
    let imageData: Data?
    let fallbackText: String
    let themeColor: Color
    let size: CGFloat
    var showsBackground: Bool = true
    var backgroundOpacity: Double = 0.18
    var transparentScale: CGFloat = 0.84
    var transparentYOffset: CGFloat = 0.12

    var body: some View {
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
            } else {
                PetAvatarPortraitFallbackText(text: fallbackText, size: size)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .accessibilityHidden(fallbackText.isEmpty)
    }
}

extension PetAvatarPortraitView {
    init(
        pet: Pet,
        size: CGFloat,
        showsBackground: Bool = true,
        backgroundOpacity: Double = 0.18,
        transparentScale: CGFloat = 0.84,
        transparentYOffset: CGFloat = 0.12
    ) {
        self.init(
            cacheID: pet.id,
            imageData: pet.avatarImageData,
            fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
            themeColor: Color(hex: pet.safeThemeColorHex),
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
    var cacheID: UUID? = nil
    let imageData: Data?
    let fallbackText: String
    let themeColor: Color
    let size: CGFloat
    var cornerRadius: CGFloat = 18
    var backgroundOpacity: Double = 0.18
    var transparentScale: CGFloat = 0.84
    var transparentYOffset: CGFloat = 0.12

    var body: some View {
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
            } else {
                PetAvatarPortraitFallbackText(text: fallbackText, size: size, scale: 0.52)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct PetAvatarPortraitCachedCircleImage: View {
    let cacheID: UUID?
    let imageData: Data
    let fallbackText: String
    let size: CGFloat
    let transparentScale: CGFloat
    let transparentYOffset: CGFloat

    @ObservedObject private var avatarPipeline = AvatarPipeline.shared

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
                    AvatarPipeline.shared.preload(
                        payloads: [FocusWalletAvatarCache.Payload(id: resolvedCacheID, data: imageData)],
                        key: pipelineKey,
                        delayMilliseconds: 24
                    )
                }
                .onDisappear {
                    AvatarPipeline.shared.cancel(key: pipelineKey)
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

    @ObservedObject private var avatarPipeline = AvatarPipeline.shared

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
                    AvatarPipeline.shared.preload(
                        payloads: [FocusWalletAvatarCache.Payload(id: resolvedCacheID, data: imageData)],
                        key: pipelineKey,
                        delayMilliseconds: 24
                    )
                }
                .onDisappear {
                    AvatarPipeline.shared.cancel(key: pipelineKey)
                }
        }
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

enum PetAvatarTransparencyCache {
    private static let cache = NSCache<NSString, NSNumber>()

    static func isTransparentAvatar(_ data: Data) -> Bool {
        let prefix = Data(data.prefix(16)).base64EncodedString()
        let suffix = Data(data.suffix(16)).base64EncodedString()
        let key = "\(data.count)-\(prefix)-\(suffix)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached.boolValue
        }

        let value = ImageCutoutService.isTransparentPNG(data)
        cache.setObject(NSNumber(value: value), forKey: key)
        return value
    }
}
