//
//  DataBackupRuntime.swift
//  Ohana
//
//  Backup errors and background export actor.
//

import Foundation
import SwiftData

// MARK: - Error
enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "备份文件版本 v\(v) 不受支持，请更新 App 后重试。"
        }
    }
}

// MARK: - Background Export Actor
//
// Owns a dedicated background SwiftData context. Running the full-table fetch +
// JSON encode here keeps the unbounded export work off the main thread; only the
// resulting Sendable `Data` crosses back to the caller.
@ModelActor
actor DataBackupActor {
    func exportData() throws -> Data {
        let manager = DataBackupManager()
        let backup = try manager.buildBackup(context: modelContext)
        return try manager.encode(backup)
    }
}
