import SwiftUI
import UIKit

/// Visual preview for an app-icon asset set. SwiftUI has no semantic system
/// control for previewing alternate app icons, so this view renders the actual
/// Asset Catalog artwork and keeps the fallback limited to unavailable assets.
struct AppIconArtwork: View {
    let descriptor: AppIconShopDescriptor

    var body: some View {
        Group {
            if let image = UIImage(named: descriptor.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackArtwork
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .accessibilityHidden(true)
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: descriptor.gradientHex.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: descriptor.previewSymbol)
                .font(OhanaFont.adaptive(size: 34, weight: .black))
                .foregroundStyle(descriptor.itemId == "appicon_minimal_o" ? Color.arkInk : Color.ohanaPrimaryActionText)
        }
    }
}
