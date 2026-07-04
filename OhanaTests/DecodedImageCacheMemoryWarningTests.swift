import Foundation
import Testing
import UIKit
@testable import Ohana

@MainActor
@Suite(.serialized)
struct DecodedImageCacheMemoryWarningTests {
    @Test func focusWalletAvatarCacheEvictsAndRebuildsOnMemoryWarning() async throws {
        FocusWalletAvatarCache.resetForTesting()
        FocusPopoutImageCache.resetForTesting()
        MediaThumbnailProvider.resetForTesting()

        let id = UUID()
        let data = try Self.makePNGData()
        let signature = FocusWalletAvatarCache.signature(for: data)
        let payload = FocusWalletAvatarCache.Payload(id: id, data: data)

        #expect(await FocusWalletAvatarCache.preload(payloads: [payload]))
        #expect(FocusWalletAvatarCache.cachedEntry(for: id, signature: signature)?.image != nil)

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await Task.yield()
        await Task.yield()

        #expect(FocusWalletAvatarCache.cachedEntry(for: id, signature: signature) == nil)
        #expect(await FocusWalletAvatarCache.preload(payloads: [payload]))
        #expect(FocusWalletAvatarCache.cachedEntry(for: id, signature: signature)?.image != nil)
    }

    @Test func focusPopoutImageCacheEvictsAndRebuildsOnMemoryWarning() async throws {
        FocusWalletAvatarCache.resetForTesting()
        FocusPopoutImageCache.resetForTesting()
        MediaThumbnailProvider.resetForTesting()

        let id = UUID()
        let data = try Self.makePNGData()
        let signature = FocusWalletAvatarCache.signature(for: data)
        let payload = FocusWalletAvatarCache.Payload(id: id, data: data)

        #expect(await FocusPopoutImageCache.preload(payloads: [payload]))
        #expect(FocusPopoutImageCache.cachedImage(for: id, signature: signature) != nil)

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await Task.yield()
        await Task.yield()

        #expect(FocusPopoutImageCache.cachedImage(for: id, signature: signature) == nil)
        #expect(await FocusPopoutImageCache.preload(payloads: [payload]))
        #expect(FocusPopoutImageCache.cachedImage(for: id, signature: signature) != nil)
    }

    @Test func mediaThumbnailProviderEvictsAndRebuildsOnMemoryWarning() async throws {
        FocusWalletAvatarCache.resetForTesting()
        FocusPopoutImageCache.resetForTesting()
        MediaThumbnailProvider.resetForTesting()

        let data = try Self.makeTransparentPNGData()
        let signature = MediaThumbnailProvider.signature(for: data)
        let key = MediaThumbnailKey(id: "test-photo", sourceSignature: signature, maxPixel: 48)

        #expect(MediaThumbnailProvider.cachedImage(for: key) == nil)
        let result = try #require(await MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: { data }))
        #expect(result.isTransparent == true)
        #expect(MediaThumbnailProvider.cachedImage(for: key) != nil)

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await Task.yield()
        await Task.yield()

        #expect(MediaThumbnailProvider.cachedImage(for: key) == nil)
        let rebuilt = try #require(await MediaThumbnailProvider.imageWithTransparency(for: key, dataProvider: { data }))
        #expect(rebuilt.isTransparent == true)
        #expect(MediaThumbnailProvider.cachedImage(for: key) != nil)
    }

    @Test func asyncDecodedImageViewDefersBlobLoadToThumbnailProvider() throws {
        let source = try Self.source("Ohana/Shared/Components/AsyncDecodedImageView.swift")

        #expect(source.contains("asyncDataProvider: @escaping @Sendable () async -> Data?"))
        #expect(source.contains("MediaThumbnailProvider.image(for: key, asyncDataProvider: asyncDataProvider)"))
        #expect(source.contains("MediaThumbnailProvider.image(for: key, dataProvider: dataProvider)"))
        #expect(!source.contains("guard let data = dataProvider()"))
        #expect(!source.contains("dataProvider: { data }"))
    }

    private static func makePNGData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return try #require(image.pngData())
    }

    private static func makeTransparentPNGData() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: format)
        let image = renderer.image { _ in }
        return try #require(image.pngData())
    }

    private static func source(_ path: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let rootURL = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}
