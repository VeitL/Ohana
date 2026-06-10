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
        await Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
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
