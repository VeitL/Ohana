//
//  AttachmentImageDecoder.swift
//  Ohana
//
//  Async helpers for user-imported attachment data.
//

import Foundation
import UIKit

enum AttachmentImageDecoder {
    static func decode(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
    }

    static func decodeFile(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let data = SecurityScopedFileDataReader.read(url) else { return nil }
            return UIImage(data: data)
        }.value
    }

    static func readFileData(_ url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            SecurityScopedFileDataReader.read(url)
        }.value
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
        return try? Data(contentsOf: url)
    }
}
