import SwiftUI
import UIKit

struct AsyncDecodedImageView<Content: View, Placeholder: View>: View {
    let cacheID: String
    let sourceSignature: String
    let maxPixel: CGFloat
    private let dataProvider: @MainActor () -> Data?
    private let asyncDataProvider: (@Sendable () async -> Data?)?
    private let content: (UIImage) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadedKey: MediaThumbnailKey?

    init(
        data: Data?,
        cacheID: String = "async-decoded-image",
        maxPixel: CGFloat = 1400,
        @ViewBuilder content: @escaping (UIImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.cacheID = cacheID
        self.sourceSignature = data.map(MediaThumbnailProvider.signature(for:)) ?? ""
        self.maxPixel = maxPixel
        self.dataProvider = { data }
        self.asyncDataProvider = nil
        self.content = content
        self.placeholder = placeholder
    }

    init(
        cacheID: String,
        sourceSignature: String,
        maxPixel: CGFloat = 1400,
        dataProvider: @escaping @MainActor () -> Data?,
        @ViewBuilder content: @escaping (UIImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.cacheID = cacheID
        self.sourceSignature = sourceSignature
        self.maxPixel = maxPixel
        self.dataProvider = dataProvider
        self.asyncDataProvider = nil
        self.content = content
        self.placeholder = placeholder
    }

    init(
        cacheID: String,
        sourceSignature: String,
        maxPixel: CGFloat = 1400,
        asyncDataProvider: @escaping @Sendable () async -> Data?,
        @ViewBuilder content: @escaping (UIImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.cacheID = cacheID
        self.sourceSignature = sourceSignature
        self.maxPixel = maxPixel
        self.dataProvider = { nil }
        self.asyncDataProvider = asyncDataProvider
        self.content = content
        self.placeholder = placeholder
    }

    private var thumbnailKey: MediaThumbnailKey {
        MediaThumbnailKey(
            id: sourceSignature.isEmpty ? cacheID : "\(cacheID)-\(sourceSignature)",
            sourceSignature: sourceSignature,
            maxPixel: maxPixel
        )
    }

    private var resolvedImage: UIImage? {
        if loadedKey == thumbnailKey, let image {
            return image
        }
        return MediaThumbnailProvider.cachedImage(for: thumbnailKey)
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                content(image)
            } else {
                placeholder()
            }
        }
        .task(id: thumbnailKey) {
            await loadImage(for: thumbnailKey)
        }
    }

    @MainActor
    private func loadImage(for key: MediaThumbnailKey) async {
        if let cached = MediaThumbnailProvider.cachedImage(for: key) {
            image = cached
            loadedKey = key
            return
        }
        let decoded: UIImage? = if let asyncDataProvider {
            await MediaThumbnailProvider.image(for: key, asyncDataProvider: asyncDataProvider)
        } else {
            await MediaThumbnailProvider.image(for: key, dataProvider: dataProvider)
        }
        guard !Task.isCancelled else { return }
        image = decoded
        loadedKey = key
    }
}
