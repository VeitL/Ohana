import SwiftUI
import UIKit

struct PetAvatarPortraitView: View {
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

            if let imageData, let image = UIImage(data: imageData) {
                PetAvatarPortraitImage(
                    image: image,
                    isTransparentAvatar: PetAvatarTransparencyCache.isTransparentAvatar(imageData),
                    size: size,
                    transparentScale: transparentScale,
                    transparentYOffset: transparentYOffset
                )
            } else {
                Text(fallbackText.isEmpty ? "🐾" : fallbackText)
                    .font(.system(size: size * 0.48))
                    .minimumScaleFactor(0.5)
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

            if let imageData, let image = UIImage(data: imageData) {
                if PetAvatarTransparencyCache.isTransparentAvatar(imageData) {
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
            } else {
                Text(fallbackText.isEmpty ? "🐾" : fallbackText)
                    .font(.system(size: size * 0.52))
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
