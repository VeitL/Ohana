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
    case weakPassword(minimum: Int)
    case passwordMismatch
    case invalidBackupPassword
    case invalidEncryptedBackup
    case encryptionUnavailable

    var errorDescription: String? {
        localizedMessage(l: .current)
    }

    func localizedMessage(l: L10n) -> String {
        switch self {
        case let .unsupportedVersion(v):
            l.tr(
                zh: "备份文件版本 v\(v) 不受支持，请更新 App 后重试。",
                en: "Backup file version v\(v) is not supported. Update Ohana and try again.",
                de: "Backup-Dateiversion v\(v) wird nicht unterstützt. Aktualisiere Ohana und versuche es erneut."
            )
        case .missingPassword:
            l.tr(
                zh: "请输入备份密码后重试。",
                en: "Enter a backup password and try again.",
                de: "Gib ein Backup-Passwort ein und versuche es erneut."
            )
        case let .weakPassword(minimum):
            l.tr(
                zh: "备份密码至少需要 \(minimum) 个字符。",
                en: "Backup password must be at least \(minimum) characters.",
                de: "Das Backup-Passwort muss mindestens \(minimum) Zeichen lang sein."
            )
        case .passwordMismatch:
            l.tr(
                zh: "两次输入的备份密码不一致。",
                en: "The two backup passwords do not match.",
                de: "Die beiden Backup-Passwörter stimmen nicht überein."
            )
        case .invalidBackupPassword:
            l.tr(
                zh: "备份密码不正确，或加密备份已损坏。",
                en: "The backup password is incorrect, or the encrypted backup is damaged.",
                de: "Das Backup-Passwort ist falsch oder das verschlüsselte Backup ist beschädigt."
            )
        case .invalidEncryptedBackup:
            l.tr(
                zh: "加密备份格式无效，请重新选择文件。",
                en: "The encrypted backup format is invalid. Choose the file again.",
                de: "Das verschlüsselte Backup-Format ist ungültig. Wähle die Datei erneut aus."
            )
        case .encryptionUnavailable:
            l.tr(
                zh: "当前设备无法生成安全随机数，请稍后重试。",
                en: "This device cannot generate secure random data right now. Try again later.",
                de: "Dieses Gerät kann derzeit keine sicheren Zufallsdaten erzeugen. Versuche es später erneut."
            )
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
