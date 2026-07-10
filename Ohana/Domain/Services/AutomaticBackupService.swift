//
//  AutomaticBackupService.swift
//  Ohana
//
//  Default-on iCloud Drive file backup. This is deliberately separate from
//  CloudKit sync and collaboration.
//

import Foundation
import SwiftData

enum AutomaticBackupPolicy {
    static let dailyInterval: TimeInterval = 60 * 60 * 24
    static let reminderCooldown: TimeInterval = 60 * 60 * 24
    static let reminderFailureThreshold = 2
    static let ubiquityContainerIdentifier = "iCloud.com.guanchen.li.Ohana"
    static let directoryName = "Ohana Backups"
    static let fileName = "Ohana Automatic Backup.\(DataBackupManager.packageFileExtension)"
    static let legacyFileName = "Ohana Automatic Backup.json"
}

struct AutomaticBackupFileReference: Codable, Equatable, Sendable {
    var fileName: String
    var path: String
    var byteCount: Int
}

enum AutomaticBackupFailureKind: String, Codable, Equatable, Sendable {
    case iCloudUnavailable
    case writeFailed
    case backupFailed
    case cleanupFailed
}

enum AutomaticBackupFileStoreError: LocalizedError, Equatable {
    case iCloudUnavailable
    case writeFailed(String)
    case cleanupFailed(String)

    var errorDescription: String? {
        localizedMessage(l: .current)
    }

    func localizedMessage(l: L10n) -> String {
        switch self {
        case .iCloudUnavailable:
            l.tr(
                zh: "iCloud Drive 暂时不可用。请确认已登录 iCloud，并允许 Ohana 使用 iCloud Drive。",
                en: "iCloud Drive is temporarily unavailable. Make sure you are signed in to iCloud and have allowed Ohana to use iCloud Drive.",
                de: "iCloud Drive ist vorübergehend nicht verfügbar. Stelle sicher, dass du bei iCloud angemeldet bist und Ohana iCloud Drive verwenden darf."
            )
        case let .writeFailed(message):
            l.tr(
                zh: "自动备份写入失败：\(message)",
                en: "Automatic backup failed to write: \(message)",
                de: "Automatisches Backup konnte nicht geschrieben werden: \(message)"
            )
        case let .cleanupFailed(message):
            l.tr(
                zh: "自动备份清理失败：\(message)",
                en: "Automatic backup cleanup failed: \(message)",
                de: "Automatische Backup-Bereinigung fehlgeschlagen: \(message)"
            )
        }
    }

    var failureKind: AutomaticBackupFailureKind {
        switch self {
        case .iCloudUnavailable:
            .iCloudUnavailable
        case .writeFailed:
            .writeFailed
        case .cleanupFailed:
            .cleanupFailed
        }
    }
}

enum AutomaticBackupTrigger: Equatable {
    case lifecycle(String)
    case settingsManual
}

enum AutomaticBackupSkipReason: Equatable {
    case disabled
    case notDue
    case alreadyRunning
}

enum AutomaticBackupRunResult: Equatable {
    case success(AutomaticBackupFileReference)
    case failure(AutomaticBackupFailureKind, String)
    case skipped(AutomaticBackupSkipReason)

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

/// The durable result of removing the app-managed iCloud Drive backup during a
/// privacy reset. A reset must not claim that the remote file disappeared when
/// iCloud is unavailable; a pending result stays visible until the user retries
/// or the next cleanup succeeds.
enum AutomaticBackupResetCleanupResult: Equatable, Sendable {
    case notRequested
    case removed
    case pending(message: String)

    var needsRetry: Bool {
        if case .pending = self { return true }
        return false
    }
}

struct AutomaticBackupStatus: Equatable, Sendable {
    var isEnabled: Bool
    var lastAttemptAt: Date?
    var lastSuccessAt: Date?
    var lastFailureAt: Date?
    var lastFailureKind: AutomaticBackupFailureKind?
    var lastFailureMessage: String?
    var fileName: String?
    var filePath: String?
    var byteCount: Int
    var lastExportScope: String?
    var consecutiveFailureCount: Int
    var lastReminderShownAt: Date?
    var resetCleanupPending: Bool
    var resetCleanupFailureAt: Date?
    var resetCleanupFailureMessage: String?

    /// A pre-scope automatic backup could have been written by an earlier
    /// release. Until it is overwritten by a restricted package or removed, the
    /// managed iCloud file needs a visible remediation path.
    var requiresRestrictedBackupReplacement: Bool {
        guard lastSuccessAt != nil || fileName != nil || filePath != nil else { return false }
        return lastExportScope != DataBackupExportScope.automaticICloudDriveRestricted.rawValue
    }

    func isDue(now: Date) -> Bool {
        guard isEnabled else { return false }
        guard let lastSuccessAt else { return true }
        return now.timeIntervalSince(lastSuccessAt) >= AutomaticBackupPolicy.dailyInterval
    }

    func shouldShowGentleReminder(now: Date) -> Bool {
        guard isEnabled else { return false }
        let repeatedFailure = consecutiveFailureCount >= AutomaticBackupPolicy.reminderFailureThreshold
        let overdueAfterFailure: Bool = if lastFailureAt != nil {
            if let lastSuccessAt {
                now.timeIntervalSince(lastSuccessAt) >= AutomaticBackupPolicy.dailyInterval * 2
            } else {
                true
            }
        } else {
            false
        }
        guard repeatedFailure || overdueAfterFailure else { return false }
        guard let lastReminderShownAt else { return true }
        return now.timeIntervalSince(lastReminderShownAt) >= AutomaticBackupPolicy.reminderCooldown
    }
}

final class AutomaticBackupStatusStore {
    static let enabledKey = "automaticBackup.enabled.v1"
    static let keyPrefix = "automaticBackup."

    private enum Key {
        static let lastAttemptAt = "automaticBackup.lastAttemptAt.v1"
        static let lastSuccessAt = "automaticBackup.lastSuccessAt.v1"
        static let lastFailureAt = "automaticBackup.lastFailureAt.v1"
        static let lastFailureKind = "automaticBackup.lastFailureKind.v1"
        static let lastFailureMessage = "automaticBackup.lastFailureMessage.v1"
        static let fileName = "automaticBackup.fileName.v1"
        static let filePath = "automaticBackup.filePath.v1"
        static let byteCount = "automaticBackup.byteCount.v1"
        static let lastExportScope = "automaticBackup.lastExportScope.v1"
        static let consecutiveFailureCount = "automaticBackup.consecutiveFailureCount.v1"
        static let lastReminderShownAt = "automaticBackup.lastReminderShownAt.v1"
        static let resetCleanupPending = "automaticBackup.resetCleanupPending.v1"
        static let resetCleanupFailureAt = "automaticBackup.resetCleanupFailureAt.v1"
        static let resetCleanupFailureMessage = "automaticBackup.resetCleanupFailureMessage.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func resetAfterAppReset(defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.set(false, forKey: enabledKey)
    }

    func snapshot(now _: Date = Date()) -> AutomaticBackupStatus {
        AutomaticBackupStatus(
            isEnabled: isEnabled,
            lastAttemptAt: date(forKey: Key.lastAttemptAt),
            lastSuccessAt: date(forKey: Key.lastSuccessAt),
            lastFailureAt: date(forKey: Key.lastFailureAt),
            lastFailureKind: failureKind(forKey: Key.lastFailureKind),
            lastFailureMessage: defaults.string(forKey: Key.lastFailureMessage),
            fileName: defaults.string(forKey: Key.fileName),
            filePath: defaults.string(forKey: Key.filePath),
            byteCount: defaults.integer(forKey: Key.byteCount),
            lastExportScope: defaults.string(forKey: Key.lastExportScope),
            consecutiveFailureCount: defaults.integer(forKey: Key.consecutiveFailureCount),
            lastReminderShownAt: date(forKey: Key.lastReminderShownAt),
            resetCleanupPending: defaults.bool(forKey: Key.resetCleanupPending),
            resetCleanupFailureAt: date(forKey: Key.resetCleanupFailureAt),
            resetCleanupFailureMessage: defaults.string(forKey: Key.resetCleanupFailureMessage)
        )
    }

    func setEnabled(_ enabled: Bool, now _: Date = Date()) {
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    func markAttempt(now: Date) {
        setDate(now, forKey: Key.lastAttemptAt)
    }

    func markSuccess(
        reference: AutomaticBackupFileReference,
        scope: DataBackupExportScope,
        now: Date
    ) {
        setDate(now, forKey: Key.lastAttemptAt)
        setDate(now, forKey: Key.lastSuccessAt)
        defaults.removeObject(forKey: Key.lastFailureAt)
        defaults.removeObject(forKey: Key.lastFailureKind)
        defaults.removeObject(forKey: Key.lastFailureMessage)
        defaults.set(reference.fileName, forKey: Key.fileName)
        defaults.set(reference.path, forKey: Key.filePath)
        defaults.set(reference.byteCount, forKey: Key.byteCount)
        defaults.set(scope.rawValue, forKey: Key.lastExportScope)
        defaults.set(0, forKey: Key.consecutiveFailureCount)
        clearResetCleanupFailure()
    }

    func markFailure(kind: AutomaticBackupFailureKind, message: String, now: Date) {
        setDate(now, forKey: Key.lastAttemptAt)
        setDate(now, forKey: Key.lastFailureAt)
        defaults.set(kind.rawValue, forKey: Key.lastFailureKind)
        defaults.set(message, forKey: Key.lastFailureMessage)
        defaults.set(defaults.integer(forKey: Key.consecutiveFailureCount) + 1, forKey: Key.consecutiveFailureCount)
    }

    func markReminderShown(now: Date) {
        setDate(now, forKey: Key.lastReminderShownAt)
    }

    func resetAfterAppReset(now _: Date = Date()) {
        Self.resetAfterAppReset(defaults: defaults)
    }

    func markResetCleanupFailure(message: String, now: Date) {
        defaults.set(true, forKey: Key.resetCleanupPending)
        setDate(now, forKey: Key.resetCleanupFailureAt)
        defaults.set(message, forKey: Key.resetCleanupFailureMessage)
    }

    func clearResetCleanupFailure() {
        defaults.removeObject(forKey: Key.resetCleanupPending)
        defaults.removeObject(forKey: Key.resetCleanupFailureAt)
        defaults.removeObject(forKey: Key.resetCleanupFailureMessage)
    }

    func markManagedBackupRemoved() {
        defaults.removeObject(forKey: Key.lastSuccessAt)
        defaults.removeObject(forKey: Key.fileName)
        defaults.removeObject(forKey: Key.filePath)
        defaults.removeObject(forKey: Key.byteCount)
        defaults.removeObject(forKey: Key.lastExportScope)
        defaults.removeObject(forKey: Key.lastFailureAt)
        defaults.removeObject(forKey: Key.lastFailureKind)
        defaults.removeObject(forKey: Key.lastFailureMessage)
        defaults.set(0, forKey: Key.consecutiveFailureCount)
    }

    private var isEnabled: Bool {
        guard defaults.object(forKey: Self.enabledKey) != nil else { return true }
        return defaults.bool(forKey: Self.enabledKey)
    }

    private func date(forKey key: String) -> Date? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSinceReferenceDate: defaults.double(forKey: key))
    }

    private func setDate(_ date: Date, forKey key: String) {
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: key)
    }

    private func failureKind(forKey key: String) -> AutomaticBackupFailureKind? {
        defaults.string(forKey: key).flatMap(AutomaticBackupFailureKind.init(rawValue:))
    }
}

@MainActor
protocol AutomaticBackupExporting {
    func exportBackupPackage(container: ModelContainer) async throws -> URL
}

@MainActor
struct LiveAutomaticBackupExporter: AutomaticBackupExporting {
    func exportBackupPackage(container: ModelContainer) async throws -> URL {
        try await DataBackupManager().exportJSON(
            container: container,
            scope: .automaticICloudDriveRestricted
        )
    }
}

@MainActor
protocol AutomaticBackupFileStoring {
    func writeAutomaticBackup(packageURL: URL, now: Date) async throws -> AutomaticBackupFileReference
    func removeManagedAutomaticBackups() async throws
}

struct ICloudDriveAutomaticBackupFileStore: AutomaticBackupFileStoring {
    var containerIdentifier = AutomaticBackupPolicy.ubiquityContainerIdentifier
    var directoryName = AutomaticBackupPolicy.directoryName
    var fileName = AutomaticBackupPolicy.fileName
    var legacyFileName = AutomaticBackupPolicy.legacyFileName

    func writeAutomaticBackup(packageURL: URL, now _: Date) async throws -> AutomaticBackupFileReference {
        let containerIdentifier = containerIdentifier
        let directoryName = directoryName
        let fileName = fileName
        let legacyFileName = legacyFileName
        return try await Task.detached(priority: .utility) {
            try Self.write(
                packageURL: packageURL,
                containerIdentifier: containerIdentifier,
                directoryName: directoryName,
                fileName: fileName,
                legacyFileName: legacyFileName
            )
        }.value
    }

    func removeManagedAutomaticBackups() async throws {
        let containerIdentifier = containerIdentifier
        let directoryName = directoryName
        let fileName = fileName
        let legacyFileName = legacyFileName
        try await Task.detached(priority: .utility) {
            try Self.remove(
                containerIdentifier: containerIdentifier,
                directoryName: directoryName,
                fileName: fileName,
                legacyFileName: legacyFileName
            )
        }.value
    }

    func removeManagedAutomaticBackupsSynchronously() throws {
        try Self.remove(
            containerIdentifier: containerIdentifier,
            directoryName: directoryName,
            fileName: fileName,
            legacyFileName: legacyFileName
        )
    }

    private nonisolated static func write(
        packageURL: URL,
        containerIdentifier: String,
        directoryName: String,
        fileName: String,
        legacyFileName: String
    ) throws -> AutomaticBackupFileReference {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw AutomaticBackupFileStoreError.iCloudUnavailable
        }
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let backupDirectoryURL = documentsURL.appendingPathComponent(directoryName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
            let fileURL = backupDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            let legacyURL = backupDirectoryURL.appendingPathComponent(legacyFileName, isDirectory: false)
            if fileManager.fileExists(atPath: legacyURL.path) {
                try fileManager.removeItem(at: legacyURL)
            }
            try fileManager.copyItem(at: packageURL, to: fileURL)
            let byteCount = try packageByteCount(fileURL)
            return AutomaticBackupFileReference(fileName: fileName, path: fileURL.path, byteCount: byteCount)
        } catch let error as AutomaticBackupFileStoreError {
            throw error
        } catch {
            throw AutomaticBackupFileStoreError.writeFailed(error.localizedDescription)
        }
    }

    private nonisolated static func remove(
        containerIdentifier: String,
        directoryName: String,
        fileName: String,
        legacyFileName: String
    ) throws {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw AutomaticBackupFileStoreError.iCloudUnavailable
        }
        let directoryURL = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        let managedURLs = [
            directoryURL.appendingPathComponent(fileName, isDirectory: false),
            directoryURL.appendingPathComponent(legacyFileName, isDirectory: false)
        ]
        do {
            for fileURL in managedURLs where fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw AutomaticBackupFileStoreError.cleanupFailed(error.localizedDescription)
        }
    }

    private nonisolated static func packageByteCount(_ packageURL: URL) throws -> Int {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: packageURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AutomaticBackupFileStoreError.writeFailed("Unable to enumerate backup package.")
        }
        var total = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            total += values.fileSize ?? 0
        }
        return total
    }
}

/// Lets the synchronous privacy-reset boundary be tested without accessing a
/// real iCloud account. The asynchronous service path continues to use
/// `AutomaticBackupFileStoring`.
protocol AutomaticBackupResetCleaning {
    func removeManagedAutomaticBackupsSynchronously() throws
}

extension ICloudDriveAutomaticBackupFileStore: AutomaticBackupResetCleaning {}

@MainActor
protocol AutomaticBackupManaging {
    func snapshot(now: Date) -> AutomaticBackupStatus
    func setEnabled(_ enabled: Bool, now: Date)
    func markReminderShown(now: Date)
    func runIfDue(container: ModelContainer, trigger: AutomaticBackupTrigger) async -> AutomaticBackupRunResult
    func runNow(container: ModelContainer, trigger: AutomaticBackupTrigger) async -> AutomaticBackupRunResult
    func removeManagedAutomaticBackupsForReset() async
    func retryManagedAutomaticBackupCleanup() async -> AutomaticBackupResetCleanupResult
    func removeLegacyAutomaticBackupForHealthSafety() async -> AutomaticBackupResetCleanupResult
}

@MainActor
final class AutomaticBackupService: AutomaticBackupManaging {
    private let statusStore: AutomaticBackupStatusStore
    private let exporter: AutomaticBackupExporting
    private let fileStore: AutomaticBackupFileStoring
    private let now: () -> Date
    private var isRunning = false

    convenience init(now: @escaping () -> Date = Date.init) {
        self.init(
            statusStore: AutomaticBackupStatusStore(),
            exporter: LiveAutomaticBackupExporter(),
            fileStore: ICloudDriveAutomaticBackupFileStore(),
            now: now
        )
    }

    init(
        statusStore: AutomaticBackupStatusStore,
        exporter: AutomaticBackupExporting,
        fileStore: AutomaticBackupFileStoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.statusStore = statusStore
        self.exporter = exporter
        self.fileStore = fileStore
        self.now = now
    }

    func snapshot(now: Date = Date()) -> AutomaticBackupStatus {
        statusStore.snapshot(now: now)
    }

    func setEnabled(_ enabled: Bool, now: Date = Date()) {
        statusStore.setEnabled(enabled, now: now)
    }

    func markReminderShown(now: Date = Date()) {
        statusStore.markReminderShown(now: now)
    }

    func runIfDue(container: ModelContainer, trigger: AutomaticBackupTrigger) async -> AutomaticBackupRunResult {
        let currentDate = now()
        let status = statusStore.snapshot(now: currentDate)
        guard status.isEnabled else { return .skipped(.disabled) }
        guard status.isDue(now: currentDate) else { return .skipped(.notDue) }
        return await runNow(container: container, trigger: trigger)
    }

    func runNow(container: ModelContainer, trigger _: AutomaticBackupTrigger) async -> AutomaticBackupRunResult {
        let currentDate = now()
        guard statusStore.snapshot(now: currentDate).isEnabled else { return .skipped(.disabled) }
        guard !isRunning else { return .skipped(.alreadyRunning) }
        isRunning = true
        defer { isRunning = false }

        statusStore.markAttempt(now: currentDate)
        do {
            let packageURL = try await exporter.exportBackupPackage(container: container)
            let reference = try await fileStore.writeAutomaticBackup(packageURL: packageURL, now: currentDate)
            statusStore.markSuccess(
                reference: reference,
                scope: .automaticICloudDriveRestricted,
                now: currentDate
            )
            return .success(reference)
        } catch {
            let failure = classify(error)
            statusStore.markFailure(kind: failure.kind, message: failure.message, now: currentDate)
            return .failure(failure.kind, failure.message)
        }
    }

    func removeManagedAutomaticBackupsForReset() async {
        statusStore.resetAfterAppReset(now: now())
        _ = await retryManagedAutomaticBackupCleanup()
    }

    func retryManagedAutomaticBackupCleanup() async -> AutomaticBackupResetCleanupResult {
        do {
            try await fileStore.removeManagedAutomaticBackups()
            statusStore.clearResetCleanupFailure()
            return .removed
        } catch {
            let failure = classify(error)
            statusStore.markResetCleanupFailure(message: failure.message, now: now())
            return .pending(message: failure.message)
        }
    }

    func removeLegacyAutomaticBackupForHealthSafety() async -> AutomaticBackupResetCleanupResult {
        do {
            try await fileStore.removeManagedAutomaticBackups()
            statusStore.markManagedBackupRemoved()
            statusStore.clearResetCleanupFailure()
            return .removed
        } catch {
            let failure = classify(error)
            statusStore.markFailure(kind: .cleanupFailed, message: failure.message, now: now())
            return .pending(message: failure.message)
        }
    }

    private func classify(_ error: Error) -> (kind: AutomaticBackupFailureKind, message: String) {
        if let fileError = error as? AutomaticBackupFileStoreError {
            return (fileError.failureKind, fileError.localizedDescription)
        }
        return (.backupFailed, error.localizedDescription)
    }
}
