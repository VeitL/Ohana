//
//  AttachmentImageDecoder.swift
//  Ohana
//
//  Async helpers for user-imported attachment data.
//

import Foundation
import ImageIO
import UIKit

enum AttachmentImageDecoder {
    static func decode(_ data: Data, maxPixel: CGFloat? = nil) async -> UIImage? {
        await Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            image(from: data, maxPixel: maxPixel)
        }.value
    }

    static func decodeFile(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            guard let data = SecurityScopedFileDataReader.read(url) else { return nil }
            return UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }.value
    }

    static func readFileData(_ url: URL) async -> Data? {
        await Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            SecurityScopedFileDataReader.read(url)
        }.value
    }

    nonisolated static func image(from data: Data, maxPixel: CGFloat?) -> UIImage? {
        guard let maxPixel, maxPixel > 0 else {
            return UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        return UIImage(cgImage: cgImage)
    }
}

enum SecurityScopedFileDataReader {
    nonisolated static func read(_ url: URL) -> Data? {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? Data(contentsOf: url) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
    }
}
