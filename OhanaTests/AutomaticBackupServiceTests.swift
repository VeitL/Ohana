import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct AutomaticBackupServiceTests {
    @Test func statusDefaultsOnAndIsDueUntilDisabled() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let initial = store.snapshot(now: now)
        #expect(initial.isEnabled)
        #expect(initial.isDue(now: now))

        store.setEnabled(false, now: now)
        let disabled = store.snapshot(now: now.addingTimeInterval(AutomaticBackupPolicy.dailyInterval * 2))
        #expect(!disabled.isEnabled)
        #expect(!disabled.isDue(now: now.addingTimeInterval(AutomaticBackupPolicy.dailyInterval * 2)))
    }

    @Test func disabledAutomaticBackupDoesNotExportOrWrite() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try FakeAutomaticBackupExporter(data: Data("{}".utf8))
        let fileStore = FakeAutomaticBackupFileStore()
        let service = AutomaticBackupService(
            statusStore: store,
            exporter: exporter,
            fileStore: fileStore,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
        store.setEnabled(false, now: Date(timeIntervalSince1970: 1_800_000_000))

        let result = try await service.runIfDue(
            container: makeInMemoryContainer(),
            trigger: .lifecycle("test")
        )

        #expect(result == .skipped(.disabled))
        #expect(exporter.callCount == 0)
        #expect(fileStore.writeCount == 0)
    }

    @Test func successfulAutomaticBackupWritesFileAndUpdatesStatus() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try FakeAutomaticBackupExporter(data: Data("{\"schemaVersion\":1}".utf8))
        let fileStore = FakeAutomaticBackupFileStore()
        let service = AutomaticBackupService(
            statusStore: store,
            exporter: exporter,
            fileStore: fileStore,
            now: { now }
        )

        let result = try await service.runIfDue(
            container: makeInMemoryContainer(),
            trigger: .lifecycle("test")
        )

        guard case let .success(reference) = result else {
            Issue.record("Expected automatic backup success, got \(result)")
            return
        }
        #expect(reference.fileName == "Ohana Automatic Backup.ohanabackup")
        #expect(exporter.callCount == 1)
        #expect(fileStore.writeCount == 1)

        let status = store.snapshot(now: now)
        #expect(status.lastAttemptAt == now)
        #expect(status.lastSuccessAt == now)
        #expect(status.consecutiveFailureCount == 0)
        #expect(status.fileName == "Ohana Automatic Backup.ohanabackup")
        #expect(!status.isDue(now: now.addingTimeInterval(AutomaticBackupPolicy.dailyInterval - 1)))
        #expect(status.isDue(now: now.addingTimeInterval(AutomaticBackupPolicy.dailyInterval)))
    }

    @Test func iCloudUnavailableFailureIsPersistedAndReminderIsRateLimited() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try FakeAutomaticBackupExporter(data: Data("{\"schemaVersion\":1}".utf8))
        let fileStore = FakeAutomaticBackupFileStore(error: AutomaticBackupFileStoreError.iCloudUnavailable)
        let service = AutomaticBackupService(
            statusStore: store,
            exporter: exporter,
            fileStore: fileStore,
            now: { now }
        )

        let first = try await service.runNow(container: makeInMemoryContainer(), trigger: .settingsManual)
        let second = try await service.runNow(container: makeInMemoryContainer(), trigger: .settingsManual)

        #expect(first.isFailure)
        #expect(second.isFailure)
        let failed = store.snapshot(now: now)
        #expect(failed.lastFailureKind == .iCloudUnavailable)
        #expect(failed.consecutiveFailureCount == 2)
        #expect(failed.shouldShowGentleReminder(now: now))

        store.markReminderShown(now: now)
        #expect(!store.snapshot(now: now.addingTimeInterval(60 * 60 * 12)).shouldShowGentleReminder(now: now.addingTimeInterval(60 * 60 * 12)))
        #expect(store.snapshot(now: now.addingTimeInterval(60 * 60 * 25)).shouldShowGentleReminder(now: now.addingTimeInterval(60 * 60 * 25)))
    }

    @Test func concurrentAutomaticBackupTriggersStartOnlyOneExport() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try FakeAutomaticBackupExporter(
            data: Data("{\"schemaVersion\":1}".utf8),
            delayNanoseconds: 50_000_000
        )
        let fileStore = FakeAutomaticBackupFileStore()
        let service = AutomaticBackupService(
            statusStore: store,
            exporter: exporter,
            fileStore: fileStore,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
        let container = try makeInMemoryContainer()

        let first = Task { @MainActor in
            await service.runNow(container: container, trigger: .settingsManual)
        }
        await Task.yield()
        let second = await service.runNow(container: container, trigger: .settingsManual)
        _ = await first.value

        #expect(second == .skipped(.alreadyRunning))
        #expect(exporter.callCount == 1)
        #expect(fileStore.writeCount == 1)
    }

    @Test func automaticBackupUsesManualProjectionAndRestoresAfterWipe() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = try makeInMemoryContainer()
        let context = source.mainContext
        let human = Human(name: "Backup Guardian")
        try HumanPasscodeService.setPasscode("2468", for: human)
        let pet = Pet(name: "Backup Miso")
        let careLog = PetCareLog(type: .feeding, amountGrams: 28, pet: pet, executorId: human.id.uuidString)
        let purchase = ShopPurchaseRecord(
            transactionKey: "shop:fx_lime_glow:\(human.id.uuidString)",
            itemId: "fx_lime_glow",
            buyerHumanId: human.id.uuidString,
            purchasedAt: now
        )
        context.insert(human)
        context.insert(pet)
        context.insert(careLog)
        context.insert(purchase)
        try context.save()

        let store = AutomaticBackupStatusStore(defaults: defaults)
        let fileStore = FakeAutomaticBackupFileStore(writeToTemporaryFile: true)
        let service = AutomaticBackupService(
            statusStore: store,
            exporter: LiveAutomaticBackupExporter(),
            fileStore: fileStore,
            now: { now }
        )

        let result = await service.runNow(container: source, trigger: .settingsManual)
        guard case .success = result, let url = fileStore.lastWrittenURL else {
            Issue.record("Expected automatic backup to write a temporary file, got \(result)")
            return
        }

        let data = try Data(contentsOf: url.appendingPathComponent(DataBackupManager.manifestFileName, isDirectory: false))
        let exported = try #require(String(data: data, encoding: .utf8))
        #expect(url.pathExtension == DataBackupManager.packageFileExtension)
        #expect(!exported.contains("pinHash"))
        #expect(!exported.contains("pinSalt"))
        #expect(!exported.contains(human.pinHash))

        try AppResetService.reset(
            context: context,
            defaults: defaults,
            options: AppResetService.Options(
                cancelPendingNotifications: false,
                deleteCustomBackground: false,
                resetSharedRuntimeState: false,
                cleanUpAutomaticBackups: false
            )
        )
        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)

        try await DataBackupManager().importJSON(from: url, context: context)
        #expect(try context.fetch(FetchDescriptor<Human>()).first?.name == "Backup Guardian")
        #expect(try context.fetch(FetchDescriptor<Pet>()).first?.name == "Backup Miso")
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).first?.amountGrams == 28)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).first?.itemId == "fx_lime_glow")
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let suiteName = "AutomaticBackupServiceTests.\(UUID().uuidString)"
        return try (suiteName, #require(UserDefaults(suiteName: suiteName)))
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

@MainActor
private final class FakeAutomaticBackupExporter: AutomaticBackupExporting {
    private let packageURL: URL
    private let delayNanoseconds: UInt64
    private(set) var callCount = 0

    init(data: Data, delayNanoseconds: UInt64 = 0) throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutomaticBackupExporter.\(UUID().uuidString).\(DataBackupManager.packageFileExtension)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try data.write(
            to: packageURL.appendingPathComponent(DataBackupManager.manifestFileName, isDirectory: false),
            options: [.atomic, .completeFileProtection]
        )
        self.packageURL = packageURL
        self.delayNanoseconds = delayNanoseconds
    }

    func exportBackupPackage(container _: ModelContainer) async throws -> URL {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return packageURL
    }
}

@MainActor
private final class FakeAutomaticBackupFileStore: AutomaticBackupFileStoring {
    private let error: Error?
    private let writeToTemporaryFile: Bool
    private(set) var writeCount = 0
    private(set) var cleanupCount = 0
    private(set) var lastWrittenURL: URL?

    init(error: Error? = nil, writeToTemporaryFile: Bool = false) {
        self.error = error
        self.writeToTemporaryFile = writeToTemporaryFile
    }

    func writeAutomaticBackup(packageURL: URL, now _: Date) async throws -> AutomaticBackupFileReference {
        writeCount += 1
        if let error {
            throw error
        }
        if writeToTemporaryFile {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("AutomaticBackupServiceTests.\(UUID().uuidString).\(DataBackupManager.packageFileExtension)", isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.copyItem(at: packageURL, to: url)
            lastWrittenURL = url
            return AutomaticBackupFileReference(
                fileName: "Ohana Automatic Backup.ohanabackup",
                path: url.path,
                byteCount: try packageByteCount(url)
            )
        }
        return AutomaticBackupFileReference(
            fileName: "Ohana Automatic Backup.ohanabackup",
            path: "/tmp/Ohana Automatic Backup.ohanabackup",
            byteCount: try packageByteCount(packageURL)
        )
    }

    func removeManagedAutomaticBackups() async throws {
        cleanupCount += 1
    }

    private func packageByteCount(_ packageURL: URL) throws -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: packageURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            total += values.fileSize ?? 0
        }
        return total
    }
}
