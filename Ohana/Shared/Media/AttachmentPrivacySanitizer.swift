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

nonisolated enum AttachmentPrivacySanitizer {
    static let jpegCompressionQuality: CGFloat = 0.86

    static func sanitizedData(
        _ data: Data,
        filename: String = "",
        isImage: Bool
    ) -> Data {
        guard shouldSanitize(filename: filename, isImage: isImage) else {
            return data
        }

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetType(source) != nil,
              let image = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions) else {
            OhanaLog.warning(
                "Attachment sanitizer could not decode image bytes; preserving original data",
                category: "Privacy"
            )
            return data
        }

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
            return data
        }

        var destinationProperties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality
        ]
        if let orientation = imageOrientation(from: source) {
            destinationProperties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, image, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            OhanaLog.warning(
                "Attachment sanitizer could not finalize image bytes; preserving original data",
                category: "Privacy"
            )
            return data
        }

        return sanitized as Data
    }

    static func sanitizedImageData(
        from image: UIImage,
        compressionQuality: CGFloat = jpegCompressionQuality
    ) -> Data? {
        image.jpegData(compressionQuality: compressionQuality)
    }

    static func isImageFilename(_ filename: String) -> Bool {
        let pathExtension = (filename as NSString).pathExtension
        guard !pathExtension.isEmpty else { return false }
        return UTType(filenameExtension: pathExtension)?.conforms(to: .image) == true
    }

    private static func shouldSanitize(filename: String, isImage: Bool) -> Bool {
        isImage || isImageFilename(filename)
    }

    private static func imageOrientation(from source: CGImageSource) -> Int? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let value = properties[kCGImagePropertyOrientation] as? NSNumber else {
            return nil
        }
        return value.intValue
    }
}
