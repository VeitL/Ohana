//
//  DataBackupRuntime.swift
//  Ohana
//
//  Backup errors and background export actor.
//

import Foundation
import SwiftData

// MARK: - Error
nonisolated enum BackupRestoreValidationCategory: String, Equatable, Sendable {
    case identity
    case duplicateIdentity
    case date
    case relationship
    case businessValue
    case media
    case sizeLimit
    case pendingChanges
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case missingPassword
    case weakPassword(minimum: Int)
    case passwordMismatch
    case invalidBackupPassword
    case invalidEncryptedBackup
    case encryptionUnavailable
    case invalidBackupPackage
    case invalidRestoreData(BackupRestoreValidationCategory)

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
        case .invalidBackupPackage:
            l.tr(
                zh: "备份包格式无效或媒体文件缺失，请重新选择备份。",
                en: "The backup package is invalid or missing media files. Choose the backup again.",
                de: "Das Backup-Paket ist ungültig oder Mediendateien fehlen. Wähle das Backup erneut aus."
            )
        case let .invalidRestoreData(category):
            switch category {
            case .identity:
                l.tr(
                    zh: "备份包含无效的记录身份，未对现有数据进行任何更改。",
                    en: "The backup contains an invalid record identity. Existing data was not changed.",
                    de: "Das Backup enthält eine ungültige Datensatz-ID. Vorhandene Daten wurden nicht geändert."
                )
            case .duplicateIdentity:
                l.tr(
                    zh: "备份包含重复的记录身份，未对现有数据进行任何更改。",
                    en: "The backup contains duplicate record identities. Existing data was not changed.",
                    de: "Das Backup enthält doppelte Datensatz-IDs. Vorhandene Daten wurden nicht geändert."
                )
            case .date:
                l.tr(
                    zh: "备份包含无效的必要日期，未对现有数据进行任何更改。",
                    en: "The backup contains an invalid required date. Existing data was not changed.",
                    de: "Das Backup enthält ein ungültiges erforderliches Datum. Vorhandene Daten wurden nicht geändert."
                )
            case .relationship:
                l.tr(
                    zh: "备份包含断开的必要关系，未对现有数据进行任何更改。",
                    en: "The backup contains a broken required relationship. Existing data was not changed.",
                    de: "Das Backup enthält eine unterbrochene erforderliche Beziehung. Vorhandene Daten wurden nicht geändert."
                )
            case .businessValue:
                l.tr(
                    zh: "备份包含无效的费用金额，未对现有数据进行任何更改。请检查备份来源后重试。",
                    en: "The backup contains an invalid expense amount. Existing data was not changed. Check the backup source and try again.",
                    de: "Das Backup enthält einen ungültigen Ausgabenbetrag. Vorhandene Daten wurden nicht geändert. Prüfe die Backup-Quelle und versuche es erneut."
                )
            case .media:
                l.tr(
                    zh: "备份中的媒体引用无效，未对现有数据进行任何更改。",
                    en: "The backup contains an invalid media reference. Existing data was not changed.",
                    de: "Das Backup enthält einen ungültigen Medienverweis. Vorhandene Daten wurden nicht geändert."
                )
            case .sizeLimit:
                l.tr(
                    zh: "备份超出安全恢复限制，未对现有数据进行任何更改。",
                    en: "The backup exceeds the safe restore limit. Existing data was not changed.",
                    de: "Das Backup überschreitet das sichere Wiederherstellungslimit. Vorhandene Daten wurden nicht geändert."
                )
            case .pendingChanges:
                l.tr(
                    zh: "仍有尚未保存的数据，请稍后重新恢复备份。",
                    en: "Some changes are still pending. Try restoring the backup again shortly.",
                    de: "Einige Änderungen stehen noch aus. Versuche die Wiederherstellung in Kürze erneut."
                )
            }
        }
    }
}

// MARK: - Background Export Actor
//
// Owns a dedicated background SwiftData context. Running the full-table fetch +
// manifest/media package export here keeps the unbounded backup work off the
// main thread; only small package metadata crosses back to the caller.
@ModelActor
actor DataBackupActor {
    func exportPackage(
        to packageURL: URL,
        encryptMedia: Bool,
        password: String?,
        scope: DataBackupExportScope
    ) throws -> DataBackupPackageBuildResult {
        let mediaWriter = DataBackupMediaPackageWriter(
            packageURL: packageURL,
            encryptMedia: encryptMedia,
            password: password
        )
        try mediaWriter.preparePackageDirectory()
        let manager = DataBackupManager()
        let backup = try manager.buildBackup(
            context: modelContext,
            mediaWriter: mediaWriter,
            mediaPackageEncrypted: encryptMedia,
            scope: scope
        )
        return DataBackupPackageBuildResult(
            manifestData: try manager.encode(backup),
            mediaCount: mediaWriter.mediaCount,
            mediaBytes: mediaWriter.mediaBytes
        )
    }
}
