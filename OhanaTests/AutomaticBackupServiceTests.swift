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
        #expect(status.lastExportScope == DataBackupExportScope.automaticICloudDriveRestricted.rawValue)
        #expect(!status.requiresRestrictedBackupReplacement)
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

    @Test func resetDuringNonCooperativeExportFencesOldGenerationAndAllowsANewBackup() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let statusStore = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try PausingAutomaticBackupExporter(data: Data("{\"schemaVersion\":1}".utf8))
        let fileStore = FakeAutomaticBackupFileStore()
        let service = AutomaticBackupService(
            statusStore: statusStore,
            exporter: exporter,
            fileStore: fileStore,
            now: { now },
            resetExportCancellationWaitNanoseconds: 1_000_000
        )
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Pet(name: "Miso"))
        try context.save()
        let resetter = StaticAppResetter(
            questManager: QuestManager(),
            automaticBackups: service,
            defaults: defaults
        )

        let oldRun = Task { @MainActor in
            await service.runNow(container: container, trigger: .settingsManual)
        }
        await exporter.waitUntilStarted()

        let resetResult = try await resetter.reset(
            context: context,
            options: resetOptions()
        )

        #expect(resetResult.automaticBackupCleanup == .removed)
        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        #expect(fileStore.cleanupCount == 1)
        #expect(fileStore.writeCount == 0)
        let resetStatus = statusStore.snapshot(now: now)
        #expect(!resetStatus.isEnabled)
        #expect(resetStatus.lastSuccessAt == nil)

        statusStore.setEnabled(true, now: now)
        let newRun = await service.runNow(container: container, trigger: .settingsManual)
        guard case .success = newRun else {
            Issue.record("Expected a new-generation backup to succeed, got \(newRun)")
            return
        }
        #expect(fileStore.writeCount == 1)
        #expect(fileStore.cleanupCount == 1)
        #expect(statusStore.snapshot(now: now).lastSuccessAt == now)

        exporter.release()
        #expect(await oldRun.value == .skipped(.cancelledByReset))
        #expect(fileStore.writeCount == 1)
        #expect(fileStore.cleanupCount == 1)
        #expect(statusStore.snapshot(now: now).lastSuccessAt == now)
    }

    @Test func resetWaitsForAnInFlightManagedWriteThenRemovesItsFileAndStatus() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let statusStore = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try FakeAutomaticBackupExporter(data: Data("{\"schemaVersion\":1}".utf8))
        let fileStore = PausingAutomaticBackupFileStore()
        let service = AutomaticBackupService(
            statusStore: statusStore,
            exporter: exporter,
            fileStore: fileStore,
            now: { now }
        )
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Pet(name: "Miso"))
        try context.save()
        let resetter = StaticAppResetter(
            questManager: QuestManager(),
            automaticBackups: service,
            defaults: defaults
        )

        let oldRun = Task { @MainActor in
            await service.runNow(container: container, trigger: .settingsManual)
        }
        await fileStore.waitUntilWriteStarted()
        let reset = Task { @MainActor in
            try await resetter.reset(context: context, options: resetOptions())
        }

        for _ in 0 ..< 5 {
            await Task.yield()
        }
        #expect(fileStore.cleanupCount == 0)
        #expect(!(try context.fetch(FetchDescriptor<Pet>())).isEmpty)

        fileStore.releaseWrite()
        #expect(await oldRun.value == .skipped(.cancelledByReset))
        let resetResult = try await reset.value

        #expect(resetResult.automaticBackupCleanup == .removed)
        #expect(fileStore.writeCount == 1)
        #expect(fileStore.cleanupCount == 1)
        #expect(!fileStore.managedBackupExists)
        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        let status = statusStore.snapshot(now: now)
        #expect(!status.isEnabled)
        #expect(status.lastSuccessAt == nil)
        #expect(status.fileName == nil)
    }

    @Test func coordinatedResetPersistsManagedBackupCleanupFailure() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let statusStore = AutomaticBackupStatusStore(defaults: defaults)
        let service = AutomaticBackupService(
            statusStore: statusStore,
            exporter: try FakeAutomaticBackupExporter(data: Data("{}".utf8)),
            fileStore: FakeAutomaticBackupFileStore(
                cleanupError: AutomaticBackupFileStoreError.iCloudUnavailable
            ),
            now: { now }
        )
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Pet(name: "Miso"))
        try context.save()
        let resetter = StaticAppResetter(
            questManager: QuestManager(),
            automaticBackups: service,
            defaults: defaults
        )

        let result = try await resetter.reset(context: context, options: resetOptions())

        guard case let .pending(message) = result.automaticBackupCleanup else {
            Issue.record("Expected the automatic backup cleanup failure to remain visible")
            return
        }
        #expect(!message.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        let status = statusStore.snapshot(now: now)
        #expect(!status.isEnabled)
        #expect(status.resetCleanupPending)
        #expect(status.resetCleanupFailureAt == now)
        #expect(status.resetCleanupFailureMessage == message)
    }

    @Test func manualAndAutomaticBackupsExcludeHumanHealthDataAndRestoreRestrictedProjection() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = try makeInMemoryContainer()
        let context = source.mainContext
        let human = Human(name: "Backup Guardian")
        try HumanPasscodeService.setPasscode("2468", for: human)
        human.bloodType = "AB+"
        human.heightCm = 172
        human.notes = "scope-only-private-health-note"
        let pet = Pet(name: "Backup Miso")
        let careLog = PetCareLog(type: .feeding, amountGrams: 28, pet: pet, executorId: human.id.uuidString)
        let purchase = ShopPurchaseRecord(
            transactionKey: "shop:fx_lime_glow:\(human.id.uuidString)",
            itemId: "fx_lime_glow",
            buyerHumanId: human.id.uuidString,
            purchasedAt: now
        )
        let humanMedication = HumanMedication(
            humanId: human.id.uuidString,
            name: "scope-only-medicine",
            dosage: "10 mg"
        )
        let humanMedicationLog = HumanMedicationLog(
            humanId: human.id.uuidString,
            medicationId: humanMedication.id.uuidString,
            scheduledTime: now,
            status: .taken,
            recordedTime: now
        )
        let healthMetric = HumanHealthMetricLog(
            metricKey: "scope-only-metric",
            unitCode: "mg_dL",
            value: 91,
            notes: "scope-only-metric-note",
            human: human
        )
        let healthReport = HumanHealthReport(
            humanId: human.id.uuidString,
            hospitalName: "Scope-only Clinic",
            summary: "scope-only-report-summary"
        )
        let medicationEvent = Event(
            title: "scope-only-medication-event",
            eventType: EventType.medication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString
        )
        let healthEvent = Event(
            title: "scope-only-health-event",
            eventType: EventType.health.rawValue,
            relatedEntityType: "human",
            relatedEntityId: human.id.uuidString
        )
        let unclassifiedHumanReminder = Event(
            title: "scope-only-private-task",
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString
        )
        let petHealthEvent = Event(
            title: "pet-health-plan-stays-local-to-pet-scope",
            eventType: EventType.health.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let medicationReminder = Reminder(event: medicationEvent, scheduledAt: now)
        let healthTask = FamilyCollaborationTask(
            title: "scope-only-medication-task",
            note: "scope-only-medication-task-note",
            kind: .careReminder,
            relatedEventId: medicationEvent.id.uuidString,
            relatedReminderId: medicationReminder.id.uuidString,
            createdById: human.id.uuidString,
            createdByName: human.name
        )
        let unlinkedHealthTask = FamilyCollaborationTask(
            title: "scope-only-unlinked-health-task",
            note: "scope-only-unlinked-health-task-note",
            kind: .careReminder,
            createdById: human.id.uuidString,
            createdByName: human.name
        )
        let healthLedger = CareLedgerEvent(
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .workout,
            actionType: "scopeOnlyHealthLedger",
            amountValue: 1,
            note: "scope-only-ledger-note"
        )
        let healthCoconutLedgerEntry = CoconutLedgerEntry(
            transactionKey: "scope-only-health-wallet-entry",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            delta: 1,
            balanceBefore: 0,
            balanceAfter: 1,
            entryKind: .reward,
            source: .careEvent,
            title: "scope-only-health-wallet-title",
            emoji: "❤️",
            actorId: human.id.uuidString,
            actorName: human.name,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            sourceModelName: String(describing: CareLedgerEvent.self),
            sourceModelId: healthLedger.id.uuidString,
            careLedgerEventId: healthLedger.id.uuidString,
            metadataJSON: #"{"note":"scope-only-health-wallet-metadata"}"#
        )
        let healthBudgetUsage = EconomyBudgetUsageEvent(
            dayKey: "scope-only-health-budget-day",
            householdKey: "scope-only-health-budget-household",
            memberKey: human.id.uuidString,
            careObjectKey: human.id.uuidString,
            scope: .member,
            scopeKey: human.id.uuidString,
            growthXPUsed: 1,
            coconutUsed: 1,
            actionKey: "scope-only-health-budget-action",
            source: "scope-only-health-budget-source",
            metadataJSON: #"{"note":"scope-only-health-budget-metadata"}"#
        )
        context.insert(human)
        context.insert(pet)
        context.insert(careLog)
        context.insert(purchase)
        context.insert(HumanWeightLog(weight: 57, human: human))
        context.insert(HumanWorkoutLog(
            type: .running,
            durationMinutes: 30,
            notes: "scope-only-workout-note",
            sourceHealthKit: true,
            healthKitWorkoutUUID: "scope-only-healthkit-workout",
            human: human
        ))
        context.insert(humanMedication)
        context.insert(humanMedicationLog)
        context.insert(healthMetric)
        context.insert(healthReport)
        context.insert(medicationEvent)
        context.insert(healthEvent)
        context.insert(unclassifiedHumanReminder)
        context.insert(petHealthEvent)
        context.insert(medicationReminder)
        context.insert(healthTask)
        context.insert(unlinkedHealthTask)
        context.insert(healthLedger)
        context.insert(healthCoconutLedgerEntry)
        context.insert(healthBudgetUsage)
        try context.save()

        let manualBackup = try DataBackupManager().buildBackup(context: context)
        #expect(manualBackup.exportScope == DataBackupExportScope.manualExternalRestricted.rawValue)
        #expect(manualBackup.humanWeightLogs.isEmpty)
        #expect(manualBackup.humanWorkoutLogs.isEmpty)
        #expect(manualBackup.humanMedications?.isEmpty == true)
        #expect(manualBackup.humanHealthMetricLogs?.isEmpty == true)
        #expect(manualBackup.humanHealthReports?.isEmpty == true)
        #expect(manualBackup.coconutLedgerEntries?.isEmpty == true)
        #expect(manualBackup.economyBudgetUsageEvents?.isEmpty == true)
        #expect(manualBackup.appState.coconutLogsJSON == "[]")

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
        let restrictedBackup = try JSONDecoder().decode(OhanaBackup.self, from: data)
        #expect(url.pathExtension == DataBackupManager.packageFileExtension)
        #expect(restrictedBackup.exportScope == DataBackupExportScope.automaticICloudDriveRestricted.rawValue)
        #expect(!exported.contains("pinHash"))
        #expect(!exported.contains("pinSalt"))
        #expect(!exported.contains(human.pinHash))
        #expect(!exported.contains("scope-only-private-health-note"))
        #expect(!exported.contains("scope-only-healthkit-workout"))
        #expect(!exported.contains("scope-only-medicine"))
        #expect(!exported.contains("scope-only-metric"))
        #expect(!exported.contains("scope-only-report-summary"))
        #expect(!exported.contains("scope-only-ledger-note"))
        #expect(!exported.contains("scope-only-health-wallet-title"))
        #expect(!exported.contains("scope-only-health-wallet-metadata"))
        #expect(!exported.contains("scope-only-health-budget-action"))
        #expect(!exported.contains("scope-only-health-budget-metadata"))
        #expect(!exported.contains("scope-only-private-task"))
        #expect(!exported.contains("scope-only-medication-task"))
        #expect(!exported.contains("scope-only-unlinked-health-task"))
        #expect(!exported.contains("scope-only-unlinked-health-task-note"))
        #expect(restrictedBackup.humans.first?.bloodType == "")
        #expect(restrictedBackup.humans.first?.heightCm == nil)
        #expect(restrictedBackup.humans.first?.notes == "")
        #expect(restrictedBackup.humanWeightLogs.isEmpty)
        #expect(restrictedBackup.humanWorkoutLogs.isEmpty)
        #expect(restrictedBackup.humanMedications?.isEmpty == true)
        #expect(restrictedBackup.humanMedicationLogs?.isEmpty == true)
        #expect(restrictedBackup.humanHealthMetricLogs?.isEmpty == true)
        #expect(restrictedBackup.humanHealthReports?.isEmpty == true)
        #expect(restrictedBackup.events.allSatisfy {
            $0.id != medicationEvent.id.uuidString &&
                $0.id != healthEvent.id.uuidString &&
                $0.id != unclassifiedHumanReminder.id.uuidString
        })
        #expect(restrictedBackup.events.contains { $0.id == petHealthEvent.id.uuidString })
        #expect(restrictedBackup.reminders.allSatisfy { $0.eventId != medicationEvent.id.uuidString })
        #expect(restrictedBackup.careLedgerEvents?.isEmpty == true)
        #expect(restrictedBackup.coconutLedgerEntries?.isEmpty == true)
        #expect(restrictedBackup.economyBudgetUsageEvents?.isEmpty == true)
        #expect(restrictedBackup.appState.coconutLogsJSON == "[]")
        #expect(restrictedBackup.familyCollaborationTasks?.isEmpty == true)

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
        #expect(try context.fetch(FetchDescriptor<HumanWeightLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
    }

    @Test func resetCleanupFailurePersistsUntilRetrySucceeds() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AutomaticBackupStatusStore(defaults: defaults)
        let exporter = try FakeAutomaticBackupExporter(data: Data("{}".utf8))
        let failingService = AutomaticBackupService(
            statusStore: store,
            exporter: exporter,
            fileStore: FakeAutomaticBackupFileStore(cleanupError: AutomaticBackupFileStoreError.iCloudUnavailable),
            now: { now }
        )

        _ = await failingService.removeManagedAutomaticBackupsForReset()
        let failedStatus = store.snapshot(now: now)
        #expect(!failedStatus.isEnabled)
        #expect(failedStatus.resetCleanupPending)
        #expect(failedStatus.resetCleanupFailureMessage?.contains("iCloud Drive") == true)

        let retryingService = AutomaticBackupService(
            statusStore: store,
            exporter: exporter,
            fileStore: FakeAutomaticBackupFileStore(),
            now: { now }
        )
        let retryResult = await retryingService.retryManagedAutomaticBackupCleanup()
        #expect(retryResult == .removed)
        #expect(!store.snapshot(now: now).resetCleanupPending)
    }

    @Test func legacyAutomaticBackupStatusHasReplacementAndRemovalPath() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Releases before the explicit scope key wrote a last-success status but
        // cannot prove that the managed package excluded human health data.
        defaults.set(now.timeIntervalSinceReferenceDate, forKey: "automaticBackup.lastSuccessAt.v1")
        defaults.set("Ohana Automatic Backup.ohanabackup", forKey: "automaticBackup.fileName.v1")
        let store = AutomaticBackupStatusStore(defaults: defaults)
        #expect(store.snapshot(now: now).requiresRestrictedBackupReplacement)

        let service = AutomaticBackupService(
            statusStore: store,
            exporter: try FakeAutomaticBackupExporter(data: Data("{}".utf8)),
            fileStore: FakeAutomaticBackupFileStore(),
            now: { now }
        )
        let removal = await service.removeLegacyAutomaticBackupForHealthSafety()

        #expect(removal == .removed)
        let status = store.snapshot(now: now)
        #expect(status.lastSuccessAt == nil)
        #expect(status.fileName == nil)
        #expect(!status.requiresRestrictedBackupReplacement)
    }

    @Test func rootViewSurfacesAutomaticBackupFailureReminderOutsideSettings() throws {
        let rootSource = try source("Ohana/App/RootView.swift", rootURL: repositoryRootURL())

        #expect(rootSource.contains("@State private var automaticBackupReminderTask"))
        #expect(rootSource.contains("scheduleAutomaticBackupFailureReminder()"))
        #expect(rootSource.contains("status.shouldShowGentleReminder(now: now)"))
        #expect(rootSource.contains("appServices.islandToasts.show(l.tr("))
        #expect(rootSource.contains("appServices.automaticBackups.markReminderShown(now: now)"))
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let suiteName = "AutomaticBackupServiceTests.\(UUID().uuidString)"
        return try (suiteName, #require(UserDefaults(suiteName: suiteName)))
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func resetOptions() -> AppResetService.Options {
        AppResetService.Options(
            cancelPendingNotifications: false,
            deleteCustomBackground: false,
            resetSharedRuntimeState: false,
            cleanUpAutomaticBackups: true
        )
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
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
private final class PausingAutomaticBackupExporter: AutomaticBackupExporting {
    private let packageURL: URL
    private var didStart = false
    private var isReleased = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    init(data: Data) throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PausingAutomaticBackupExporter.\(UUID().uuidString).\(DataBackupManager.packageFileExtension)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try data.write(
            to: packageURL.appendingPathComponent(DataBackupManager.manifestFileName, isDirectory: false),
            options: [.atomic, .completeFileProtection]
        )
        self.packageURL = packageURL
    }

    func exportBackupPackage(container _: ModelContainer) async throws -> URL {
        callCount += 1
        didStart = true
        startWaiter?.resume()
        startWaiter = nil
        if callCount == 1, !isReleased {
            await withCheckedContinuation { continuation in
                releaseWaiter = continuation
            }
        }
        return packageURL
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func release() {
        guard !isReleased else { return }
        isReleased = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

@MainActor
private final class FakeAutomaticBackupFileStore: AutomaticBackupFileStoring {
    private let error: Error?
    private let cleanupError: Error?
    private let writeToTemporaryFile: Bool
    private(set) var writeCount = 0
    private(set) var cleanupCount = 0
    private(set) var lastWrittenURL: URL?

    init(
        error: Error? = nil,
        cleanupError: Error? = nil,
        writeToTemporaryFile: Bool = false
    ) {
        self.error = error
        self.cleanupError = cleanupError
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
        if let cleanupError {
            throw cleanupError
        }
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

@MainActor
private final class PausingAutomaticBackupFileStore: AutomaticBackupFileStoring {
    private var didStartWrite = false
    private var isWriteReleased = false
    private var writeStartWaiter: CheckedContinuation<Void, Never>?
    private var writeReleaseWaiter: CheckedContinuation<Void, Never>?
    private(set) var writeCount = 0
    private(set) var cleanupCount = 0
    private(set) var managedBackupExists = false

    func writeAutomaticBackup(packageURL _: URL, now _: Date) async throws -> AutomaticBackupFileReference {
        writeCount += 1
        didStartWrite = true
        writeStartWaiter?.resume()
        writeStartWaiter = nil
        if !isWriteReleased {
            await withCheckedContinuation { continuation in
                writeReleaseWaiter = continuation
            }
        }
        managedBackupExists = true
        return AutomaticBackupFileReference(
            fileName: AutomaticBackupPolicy.fileName,
            path: "/tmp/\(AutomaticBackupPolicy.fileName)",
            byteCount: 1
        )
    }

    func removeManagedAutomaticBackups() async throws {
        cleanupCount += 1
        managedBackupExists = false
    }

    func waitUntilWriteStarted() async {
        guard !didStartWrite else { return }
        await withCheckedContinuation { continuation in
            writeStartWaiter = continuation
        }
    }

    func releaseWrite() {
        guard !isWriteReleased else { return }
        isWriteReleased = true
        writeReleaseWaiter?.resume()
        writeReleaseWaiter = nil
    }
}
