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
    nonisolated static let maximumDocumentAttachmentBytes = 16 * 1024 * 1024

    enum DocumentImportError: LocalizedError {
        case invalidFile
        case tooLarge

        var errorDescription: String? {
            let l = L10n.current
            switch self {
            case .invalidFile:
                return l.tr(zh: "无法读取所选文件。", en: "The selected file could not be read.", de: "Die ausgewählte Datei konnte nicht gelesen werden.")
            case .tooLarge:
                return l.tr(zh: "附件不能超过 16 MB。", en: "Attachments must be 16 MB or smaller.", de: "Anhänge dürfen höchstens 16 MB groß sein.")
            }
        }
    }

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

    static func readSanitizedDocument(
        _ url: URL,
        isImage: Bool,
        fallbackFilename: String
    ) async throws -> SanitizedAttachmentPayload {
        let worker = Task.detached(priority: .utility) {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            try Task.checkCancellation()
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let byteCount = values.fileSize,
                  byteCount >= 0 else {
                throw DocumentImportError.invalidFile
            }
            guard byteCount <= maximumDocumentAttachmentBytes else { throw DocumentImportError.tooLarge }
            let data = try Data(contentsOf: url) // smoothness: allow bounded read in a cancellable utility worker
            try Task.checkCancellation()
            guard data.count <= maximumDocumentAttachmentBytes else { throw DocumentImportError.tooLarge }
            let payload = AttachmentPrivacySanitizer.sanitizedAttachment(
                data,
                filename: url.lastPathComponent,
                isImage: isImage,
                fallbackFilename: fallbackFilename
            )
            try Task.checkCancellation()
            return payload
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
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
