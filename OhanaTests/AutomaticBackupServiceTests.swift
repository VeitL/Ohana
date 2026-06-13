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
        let exporter = FakeAutomaticBackupExporter(data: Data("{}".utf8))
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
        let exporter = FakeAutomaticBackupExporter(data: Data("{\"schemaVersion\":1}".utf8))
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
        #expect(reference.fileName == "Ohana Automatic Backup.json")
        #expect(exporter.callCount == 1)
        #expect(fileStore.writeCount == 1)

        let status = store.snapshot(now: now)
        #expect(status.lastAttemptAt == now)
        #expect(status.lastSuccessAt == now)
        #expect(status.consecutiveFailureCount == 0)
        #expect(status.fileName == "Ohana Automatic Backup.json")
        #expect(!status.isDue(now: now.addingTimeInterval(AutomaticBackupPolicy.dailyInterval - 1)))
        #expect(status.isDue(now: now.addingTimeInterval(AutomaticBackupPolicy.dailyInterval)))
    }

    @Test func iCloudUnavailableFailureIsPersistedAndReminderIsRateLimited() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = FakeAutomaticBackupExporter(data: Data("{\"schemaVersion\":1}".utf8))
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
        let exporter = FakeAutomaticBackupExporter(
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

        let data = try Data(contentsOf: url)
        let exported = try #require(String(data: data, encoding: .utf8))
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
    private let data: Data
    private let delayNanoseconds: UInt64
    private(set) var callCount = 0

    init(data: Data, delayNanoseconds: UInt64 = 0) {
        self.data = data
        self.delayNanoseconds = delayNanoseconds
    }

    func exportPlainJSON(container _: ModelContainer) async throws -> Data {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return data
    }
}

@MainActor
private final class FakeAutomaticBackupFileStore: AutomaticBackupFileStoring {
    private let error: Error?
    private let writeToTemporaryFile: Bool
    private(set) var writeCount = 0
    private(set) var cleanupCount = 0
    private(set) var lastWrittenData: Data?
    private(set) var lastWrittenURL: URL?

    init(error: Error? = nil, writeToTemporaryFile: Bool = false) {
        self.error = error
        self.writeToTemporaryFile = writeToTemporaryFile
    }

    func writeAutomaticBackup(data: Data, now _: Date) async throws -> AutomaticBackupFileReference {
        writeCount += 1
        if let error {
            throw error
        }
        lastWrittenData = data
        if writeToTemporaryFile {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("AutomaticBackupServiceTests.\(UUID().uuidString).json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            lastWrittenURL = url
            return AutomaticBackupFileReference(fileName: "Ohana Automatic Backup.json", path: url.path, byteCount: data.count)
        }
        return AutomaticBackupFileReference(fileName: "Ohana Automatic Backup.json", path: "/tmp/Ohana Automatic Backup.json", byteCount: data.count)
    }

    func removeManagedAutomaticBackups() async throws {
        cleanupCount += 1
    }
}
