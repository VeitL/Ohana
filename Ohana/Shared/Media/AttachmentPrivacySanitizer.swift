//
//  AttachmentPrivacySanitizer.swift
//  Ohana
//
//  Normalizes user-supplied attachment images before persistence so source
//  metadata such as EXIF GPS coordinates does not remain in SwiftData backups.
//

import Foundation
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

        // smoothness: allow persistence-side privacy scrub before saving attachments; not a view render path
        guard let image = UIImage(data: data) else {
            OhanaLog.warning(
                "Attachment sanitizer could not decode image bytes; preserving original data",
                category: "Privacy"
            )
            return data
        }

        guard let sanitized = image.jpegData(compressionQuality: jpegCompressionQuality) else {
            OhanaLog.warning(
                "Attachment sanitizer could not re-encode image bytes; preserving original data",
                category: "Privacy"
            )
            return data
        }

        return sanitized
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
}
