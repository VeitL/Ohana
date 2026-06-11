//
//  CloudSyncAssetFileStore.swift
//  Ohana
//
//  Temporary CKAsset file storage for CloudKit uploads.
//

import Foundation

nonisolated struct CloudSyncAssetFileStore: @unchecked Sendable {
    static let directoryName = "OhanaCloudSyncAssets"

    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL()
    }

    func assetFileURLProvider() -> CloudSyncRecordPayload.AssetFileURLProvider {
        { fieldName, data in
            try fileURL(fieldName: fieldName, data: data)
        }
    }

    func fileURL(fieldName: String, data: Data) throws -> URL {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = directoryURL.appendingPathComponent(fileName(fieldName: fieldName))
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func pruneFiles(olderThan cutoff: Date = Date().addingTimeInterval(-24 * 60 * 60)) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls {
            guard let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modifiedAt < cutoff else {
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func defaultDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    private func fileName(fieldName: String) -> String {
        let safeFieldName = fieldName
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
        return "\(safeFieldName)-\(Date().timeIntervalSince1970)-\(UUID().uuidString).asset"
    }
}
