//
//  AttachmentPrivacySanitizer.swift
//  Ohana
//
//  Normalizes user-supplied attachment images before persistence so source
//  metadata such as EXIF GPS coordinates does not remain in SwiftData backups.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

nonisolated struct SanitizedAttachmentPayload: Equatable {
    let data: Data
    let filename: String
    let isImage: Bool
}

nonisolated enum AttachmentPrivacySanitizer {
    static let jpegCompressionQuality: CGFloat = 0.86
    static let maxPersistedImagePixel: CGFloat = 2048

    static func sanitizedData(
        _ data: Data,
        filename: String = "",
        isImage: Bool
    ) -> Data {
        sanitizedAttachment(
            data,
            filename: filename,
            isImage: isImage
        ).data
    }

    static func sanitizedAttachment(
        _ data: Data,
        filename: String = "",
        isImage: Bool,
        fallbackFilename: String = "image.jpg"
    ) -> SanitizedAttachmentPayload {
        let cleanedFilename = trimmedFilename(filename)
        guard shouldSanitize(filename: filename, isImage: isImage) else {
            return SanitizedAttachmentPayload(
                data: data,
                filename: cleanedFilename,
                isImage: isImage
            )
        }

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetType(source) != nil,
              let image = downsampledImage(from: source, maxPixel: maxPersistedImagePixel) else {
            OhanaLog.warning(
                "Attachment sanitizer could not decode image bytes; preserving original data",
                category: "Privacy"
            )
            return SanitizedAttachmentPayload(
                data: data,
                filename: cleanedFilename,
                isImage: isImage
            )
        }

        guard let sanitized = jpegData(from: image, compressionQuality: jpegCompressionQuality) else {
            OhanaLog.warning(
                "Attachment sanitizer could not re-encode image bytes; preserving original data",
                category: "Privacy"
            )
            return SanitizedAttachmentPayload(
                data: data,
                filename: cleanedFilename,
                isImage: isImage
            )
        }
        return SanitizedAttachmentPayload(
            data: sanitized,
            filename: normalizedJPEGFilename(cleanedFilename, fallbackFilename: fallbackFilename),
            isImage: true
        )
    }

    private static func downsampledImage(from source: CGImageSource, maxPixel: CGFloat) -> CGImage? {
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(1, maxPixel))
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    }

    private static func jpegData(from image: CGImage, compressionQuality: CGFloat) -> Data? {
        let sanitized = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            sanitized,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            OhanaLog.warning(
                "Attachment sanitizer could not re-encode image bytes; preserving original data",
                category: "Privacy"
            )
            return nil
        }

        let destinationProperties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, image, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            OhanaLog.warning(
                "Attachment sanitizer could not finalize image bytes; preserving original data",
                category: "Privacy"
            )
            return nil
        }

        return sanitized as Data
    }

    static func sanitizedImageData(
        from image: UIImage,
        compressionQuality: CGFloat = jpegCompressionQuality,
        maxPixel: CGFloat = maxPersistedImagePixel
    ) -> Data? {
        let longestPixel = max(image.size.width * image.scale, image.size.height * image.scale)
        guard longestPixel > maxPixel, maxPixel > 0 else {
            return image.jpegData(compressionQuality: compressionQuality)
        }

        let ratio = maxPixel / longestPixel
        let targetSize = CGSize(
            width: max(1, image.size.width * image.scale * ratio),
            height: max(1, image.size.height * image.scale * ratio)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    static func isImageFilename(_ filename: String) -> Bool {
        let pathExtension = (filename as NSString).pathExtension
        guard !pathExtension.isEmpty else { return false }
        return UTType(filenameExtension: pathExtension)?.conforms(to: .image) == true
    }

    static func normalizedJPEGFilename(_ filename: String, fallbackFilename: String = "image.jpg") -> String {
        let cleaned = trimmedFilename(filename)
        let fallback = trimmedFilename(fallbackFilename).isEmpty ? "image.jpg" : trimmedFilename(fallbackFilename)
        let source = cleaned.isEmpty ? fallback : cleaned
        let base = (source as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBase = base.isEmpty ? "image" : base
        return (safeBase as NSString).appendingPathExtension("jpg") ?? "\(safeBase).jpg"
    }

    private static func shouldSanitize(filename: String, isImage: Bool) -> Bool {
        isImage || isImageFilename(filename)
    }

    private static func trimmedFilename(_ filename: String) -> String {
        filename.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
