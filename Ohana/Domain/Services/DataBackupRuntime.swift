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
    case missingPassword
    case passwordMismatch
    case invalidBackupPassword
    case invalidEncryptedBackup
    case encryptionUnavailable

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(v):
            "备份文件版本 v\(v) 不受支持，请更新 App 后重试。"
        case .missingPassword:
            "请输入备份密码后重试。"
        case .passwordMismatch:
            "两次输入的备份密码不一致。"
        case .invalidBackupPassword:
            "备份密码不正确，或加密备份已损坏。"
        case .invalidEncryptedBackup:
            "加密备份格式无效，请重新选择文件。"
        case .encryptionUnavailable:
            "当前设备无法生成安全随机数，请稍后重试。"
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
