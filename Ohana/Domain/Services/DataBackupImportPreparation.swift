//
//  DataBackupImportPreparation.swift
//  Ohana
//
//  Read and decrypt an import before entering the live SwiftData transaction.
//

import Foundation

/// The decoded DTO is handed to the main actor once and is never shared back
/// with the preparation task. The resolver contains only immutable file URLs.
nonisolated struct DataBackupPreparedImport: @unchecked Sendable {
    let backup: OhanaBackup
    let mediaResolver: DataBackupMediaResolving?
    let stagingDirectoryURL: URL?

    func removeStagedMedia() async {
        guard let stagingDirectoryURL else { return }
        await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: stagingDirectoryURL)
        }.value
    }
}

nonisolated enum DataBackupImportPreparation {
    static func prepare(from url: URL, password: String?) async throws -> DataBackupPreparedImport {
        try await Task.detached(priority: .userInitiated) {
            try prepareSynchronously(from: url, password: password)
        }.value
    }

    private static func prepareSynchronously(from url: URL, password: String?) throws -> DataBackupPreparedImport {
        try Task.checkCancellation()
        let packageURL = try DataBackupManager.packageURLIfNeeded(url)
        let manifestURL = packageURL?.appendingPathComponent(DataBackupManager.manifestFileName) ?? url
        if packageURL != nil, !FileManager.default.fileExists(atPath: manifestURL.path) {
            throw BackupError.invalidBackupPackage
        }
        try DataBackupPreflightValidator.validateManifestSize(at: manifestURL)
        let encryptedManifest = try Data(contentsOf: manifestURL)
        let manifest = try DataBackupEncryption.decryptIfNeeded(encryptedManifest, password: password)
        guard manifest.count <= DataBackupRestoreLimits.maximumManifestBytes else {
            throw BackupError.invalidRestoreData(.sizeLimit)
        }
        let backup = try JSONDecoder().decode(OhanaBackup.self, from: manifest)
        try Task.checkCancellation()

        let references = mediaReferences(in: backup)
        guard !references.isEmpty else {
            return DataBackupPreparedImport(backup: backup, mediaResolver: nil, stagingDirectoryURL: nil)
        }
        guard let packageURL else { throw BackupError.invalidBackupPackage }
        let reader = DataBackupMediaPackageReader(packageURL: packageURL, password: password)
        let stagingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohana-restore-media-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        do {
            var staged: [String: StagedMedia] = [:]
            var totalBytes = 0
            for reference in references {
                try Task.checkCancellation()
                if let previous = staged[reference.path] {
                    guard previous.byteCount == reference.byteCount else {
                        throw BackupError.invalidRestoreData(.media)
                    }
                    continue
                }
                guard reference.byteCount > 0,
                      reference.byteCount <= DataBackupRestoreLimits.maximumMediaItemBytes,
                      reference.byteCount <= DataBackupRestoreLimits.maximumMediaBytes - totalBytes else {
                    throw BackupError.invalidRestoreData(.sizeLimit)
                }
                let data = try reader.data(for: reference)
                guard let data else { throw BackupError.invalidRestoreData(.media) }
                let stagedURL = stagingDirectoryURL.appendingPathComponent("\(staged.count).bin")
                try data.write(to: stagedURL, options: [.atomic, .completeFileProtection])
                staged[reference.path] = StagedMedia(url: stagedURL, byteCount: reference.byteCount)
                totalBytes += reference.byteCount
            }
            return DataBackupPreparedImport(
                backup: backup,
                mediaResolver: StagedMediaResolver(media: staged),
                stagingDirectoryURL: stagingDirectoryURL
            )
        } catch {
            try? FileManager.default.removeItem(at: stagingDirectoryURL)
            throw error
        }
    }

    private static func mediaReferences(in value: Any) -> [BackupMediaReference] {
        var references: [BackupMediaReference] = []
        collectReferences(in: value, into: &references)
        return references
    }

    private static func collectReferences(in value: Any, into references: inout [BackupMediaReference]) {
        if let reference = value as? BackupMediaReference {
            references.append(reference)
            return
        }
        if value is Data || value is String || value is Date { return }
        for child in Mirror(reflecting: value).children {
            collectReferences(in: child.value, into: &references)
        }
    }
}

private nonisolated struct StagedMedia: Sendable {
    let url: URL
    let byteCount: Int
}

private final nonisolated class StagedMediaResolver: DataBackupMediaResolving {
    private let media: [String: StagedMedia]

    init(media: [String: StagedMedia]) {
        self.media = media
    }

    func data(for reference: BackupMediaReference?) throws -> Data? {
        guard let reference else { return nil }
        guard let staged = media[reference.path], staged.byteCount == reference.byteCount else {
            throw BackupError.invalidRestoreData(.media)
        }
        let data = try Data(contentsOf: staged.url, options: .mappedIfSafe)
        guard data.count == reference.byteCount else { throw BackupError.invalidRestoreData(.media) }
        return data
    }
}
