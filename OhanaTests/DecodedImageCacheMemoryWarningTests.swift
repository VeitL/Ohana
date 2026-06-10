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

    private static func makePNGData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return try #require(image.pngData())
    }
}
