//
//  LocalBackupExclusionPolicy.swift
//  Ohana
//
//  Keeps local persistence and private attachment roots out of OS-managed
//  device backups. Approved user-controlled recovery uses Ohana's restricted
//  backup package instead.
//

import Foundation

nonisolated enum LocalBackupExclusionPolicy {
    enum PolicyError: LocalizedError {
        case applicationSupportDirectoryUnavailable
        case exclusionVerificationFailed

        var errorDescription: String? {
            switch self {
            case .applicationSupportDirectoryUnavailable:
                "Application Support directory is unavailable."
            case .exclusionVerificationFailed:
                "The local persistence path could not be verified as excluded from device backup."
            }
        }
    }

    @discardableResult
    static func prepareApplicationSupportDirectory() throws -> URL {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw PolicyError.applicationSupportDirectoryUnavailable
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try excludeFromDeviceBackup(directory)
        return directory
    }

    static func excludeFromDeviceBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)

        let persisted = try mutableURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup
        guard persisted == true else {
            throw PolicyError.exclusionVerificationFailed
        }
    }
}
