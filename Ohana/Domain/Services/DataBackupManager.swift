//
//  DataBackupManager.swift
//  Ohana
//
//  TASK 1: 全量 JSON 数据备份与恢复
//  覆盖 21 个 SwiftData 模型 + 关键 UserDefaults appState
//

import Foundation
import SwiftData

nonisolated enum DataBackupPackageFormat {
    static let backupFilePrefix = "ohana_backup_"
    static let packageFileExtension = "ohanabackup"
    static let manifestFileName = "manifest.json"
    static let mediaDirectoryName = "media"
    static let staleExportAge: TimeInterval = 60 * 60
}

/// Defines the data boundary for a backup package that can leave the device.
/// Health data must not be present in any package that can be saved to Files or
/// shared through system providers, including iCloud Drive. The two values keep
/// the delivery path auditable while enforcing the same restricted payload.
nonisolated enum DataBackupExportScope: String, Codable, Equatable, Sendable {
    case manualExternalRestricted
    case automaticICloudDriveRestricted

    var excludesHumanHealthData: Bool {
        true
    }
}

nonisolated enum DataBackupRestorePhase: String, CaseIterable, Equatable, Sendable {
    case preflightCompleted
    case membersAndSchedulesPrepared
    case careFactsPrepared
    case extendedDataPrepared
    case derivedStatePrepared
    case beforeCommit
}

typealias DataBackupRestoreFaultInjector = (DataBackupRestorePhase) throws -> Void
typealias DataBackupRestoreTransaction = (ModelContext, () throws -> Void) throws -> Void

private struct DataBackupRestorePendingEffects {
    let notificationIDsToCancel: [String]
    let plantReconciliation: PlantBackupRestoreReconcileResult?
}

private final class DataBackupRestoreDefaults: UserDefaults {
    private var values: [String: Any]

    init(snapshot: [String: Any]) {
        values = snapshot
        super.init(suiteName: nil)!
    }

    override func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        if let value {
            values[defaultName] = value
        } else {
            values.removeValue(forKey: defaultName)
        }
    }

    override func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] {
        values
    }
}

// MARK: - DataBackupManager
//
// Isolation-agnostic: the build/encode/apply logic only does ModelContext
// reads/writes plus pure value-type mapping, so the type is not @MainActor.
// Export runs on a background @ModelActor (see DataBackupActor) so the
// full-table fetch + JSON encode never blocks the main thread. Import keeps the
// main context (see @MainActor on importJSON) so SwiftData @Query-backed UI
// refreshes immediately after a restore.
final nonisolated class DataBackupManager: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    let iso = ISO8601DateFormatter()

    // MARK: - Export

    /// Filename prefix for exported backups in the temporary directory.
    static let backupFilePrefix = DataBackupPackageFormat.backupFilePrefix
    static let packageFileExtension = DataBackupPackageFormat.packageFileExtension
    static let manifestFileName = DataBackupPackageFormat.manifestFileName
    static let mediaDirectoryName = DataBackupPackageFormat.mediaDirectoryName
    static let staleExportAge: TimeInterval = DataBackupPackageFormat.staleExportAge

    /// Builds and writes a restricted backup package for a user-visible
    /// destination. Both manual export and automatic iCloud Drive backup omit
    /// structured human-health data so no file that can leave the device carries
    /// HealthKit-derived records. The unbounded fetch + JSON encode run on a
    /// dedicated background SwiftData context (`DataBackupActor`) so the main
    /// thread is never blocked; only the final file write happens here.
    func exportJSON(
        container: ModelContainer,
        password: String? = nil,
        scope: DataBackupExportScope = .manualExternalRestricted
    ) async throws -> URL {
        let flowStartedAt = await MainActor.run {
            AppFlowPerformance.start(AppPerformanceFlows.backupExport)
        }
        do {
            let trimmedPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let shouldEncrypt = !trimmedPassword.isEmpty

            // External packages exclude human-health data, but can still contain
            // sensitive household, pet, document, route, and location data. They
            // are written atomically with complete file protection while the
            // device is locked. Old exports are purged by age so concurrent
            // export/import flows cannot delete each other's active backup files.
            Self.purgeStaleExports()

            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd_HHmmss"
            let stamp = f.string(from: Date())
            let uniqueId = UUID().uuidString
            let suffix = shouldEncrypt ? "encrypted.\(Self.packageFileExtension)" : Self.packageFileExtension
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.backupFilePrefix)\(stamp)_\(uniqueId).\(suffix)", isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            let result = try await DataBackupActor(modelContainer: container).exportPackage(
                to: url,
                encryptMedia: shouldEncrypt,
                password: shouldEncrypt ? trimmedPassword : nil,
                scope: scope
            )
            let manifestData = if shouldEncrypt {
                try DataBackupEncryption.encrypt(result.manifestData, password: trimmedPassword)
            } else {
                result.manifestData
            }
            try manifestData.write(
                to: url.appendingPathComponent(Self.manifestFileName, isDirectory: false),
                options: [.atomic, .completeFileProtection]
            )
            await MainActor.run {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.backupExport,
                    AppPerformancePhases.dataReady,
                    startedAt: flowStartedAt,
                    note: [
                        "bytes": "\(result.mediaBytes)",
                        "mediaCount": "\(result.mediaCount)",
                        "encrypted": "\(shouldEncrypt)",
                        "format": "package",
                        "scope": scope.rawValue
                    ]
                )
            }
            await MainActor.run {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.backupExport,
                    AppPerformancePhases.writeSuccess,
                    startedAt: flowStartedAt,
                    note: [
                        "bytes": "\(result.mediaBytes)",
                        "mediaCount": "\(result.mediaCount)",
                        "encrypted": "\(shouldEncrypt)",
                        "format": "package",
                        "scope": scope.rawValue
                    ]
                )
            }
            return url
        } catch {
            await MainActor.run {
                AppFlowPerformance.markFailure(
                    AppPerformanceFlows.backupExport,
                    startedAt: flowStartedAt,
                    error: error
                )
            }
            throw error
        }
    }

    /// Encodes a prepared backup snapshot. Used by `DataBackupActor` on its
    /// background context.
    func encode(_ backup: OhanaBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Removes old exported backup files from the temporary directory so
    /// sensitive plaintext does not accumulate while active share/import flows
    /// keep their current file available.
    static func purgeStaleExports(olderThan maxAge: TimeInterval = staleExportAge, now: Date = Date()) {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let entries = try? fm.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in entries where url.lastPathComponent.hasPrefix(backupFilePrefix) {
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            guard now.timeIntervalSince(modifiedAt) > maxAge else { continue }
            try? fm.removeItem(at: url)
        }
    }

    static func packageURLIfNeeded(_ url: URL) throws -> URL? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = values?.isDirectory == true
        guard isDirectory else { return nil }
        if url.pathExtension == packageFileExtension {
            return url
        }
        let manifestURL = url.appendingPathComponent(manifestFileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: manifestURL.path) ? url : nil
    }

    // MARK: - Import

    /// Import stays on the main context so SwiftData @Query-backed UI refreshes
    /// immediately after a restore.
    @MainActor
    func importJSON(
        from url: URL,
        context: ModelContext,
        projectionManager: CoconutProjectionManaging? = nil,
        password: String? = nil,
        schedulePlantNotifications: Bool = true,
        plantNotifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        restoreFaultInjector: DataBackupRestoreFaultInjector? = nil,
        restoreTransaction: DataBackupRestoreTransaction = { context, changes in
            try context.transaction(block: changes)
        }
    ) async throws {
        let packageURL = try Self.packageURLIfNeeded(url)
        let fileData: Data
        let mediaResolver: DataBackupMediaResolving?
        if let packageURL {
            let manifestURL = packageURL.appendingPathComponent(Self.manifestFileName, isDirectory: false)
            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                throw BackupError.invalidBackupPackage
            }
            try DataBackupPreflightValidator.validateManifestSize(at: manifestURL)
            fileData = try Data(contentsOf: manifestURL) // smoothness: explicit user restore file read
            mediaResolver = DataBackupMediaPackageReader(packageURL: packageURL, password: password)
        } else {
            try DataBackupPreflightValidator.validateManifestSize(at: url)
            fileData = try Data(contentsOf: url) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
            mediaResolver = nil
        }
        let data = try DataBackupEncryption.decryptIfNeeded(fileData, password: password)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(OhanaBackup.self, from: data)

        try applyBackup(
            backup,
            context: context,
            projectionManager: projectionManager,
            schedulePlantNotifications: schedulePlantNotifications,
            plantNotifications: plantNotifications,
            mediaResolver: mediaResolver,
            restoreFaultInjector: restoreFaultInjector,
            restoreTransaction: restoreTransaction
        )
    }

    // MARK: - Build Backup

    func buildBackup(
        context: ModelContext,
        mediaWriter: DataBackupMediaWriting? = nil,
        mediaPackageEncrypted: Bool = false,
        scope: DataBackupExportScope = .manualExternalRestricted
    ) throws -> OhanaBackup {
        let pets = try context.fetch(FetchDescriptor<Pet>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let humans = try context.fetch(FetchDescriptor<Human>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let events = try context.fetch(FetchDescriptor<Event>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let reminders = try context.fetch(FetchDescriptor<Reminder>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let households = try context.fetch(FetchDescriptor<Household>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let plants = try context.fetch(FetchDescriptor<Plant>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let petRelationships = try context.fetch(FetchDescriptor<PetRelationship>()) // smoothness: explicit backup/export scan only
        let plantCareLogs = try context.fetch(FetchDescriptor<PlantCareLog>()) // smoothness: explicit backup/export scan only
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let weightLogs = try context.fetch(FetchDescriptor<PetWeightLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let expLogs = try context.fetch(FetchDescriptor<PetExpenseLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let hygLogs = try context.fetch(FetchDescriptor<PetHygieneLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let foodRecs = try context.fetch(FetchDescriptor<PetFoodRecord>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let docs = try context.fetch(FetchDescriptor<PetDocument>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let milestones = try context.fetch(FetchDescriptor<PetMilestone>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let photos = try context.fetch(FetchDescriptor<PetPhotoLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let insurances = try context.fetch(FetchDescriptor<PetInsurance>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let claims = try context.fetch(FetchDescriptor<InsuranceClaim>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let petMeds = try context.fetch(FetchDescriptor<PetMedication>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let symptoms = try context.fetch(FetchDescriptor<SymptomLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let heatCycles = try context.fetch(FetchDescriptor<HeatCycleLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let hWeightLogs = scope.excludesHumanHealthData
            ? []
            : try context.fetch(FetchDescriptor<HumanWeightLog>()) // smoothness: explicit manual-export scan only
        let hWorkouts = scope.excludesHumanHealthData
            ? []
            : try context.fetch(FetchDescriptor<HumanWorkoutLog>()) // smoothness: explicit manual-export scan only
        let humanMeds = scope.excludesHumanHealthData
            ? []
            : try context.fetch(FetchDescriptor<HumanMedication>()) // smoothness: explicit manual-export scan only
        let humanMedLogs = scope.excludesHumanHealthData
            ? []
            : try context.fetch(FetchDescriptor<HumanMedicationLog>()) // smoothness: explicit manual-export scan only
        let humanHealthMetricLogs = scope.excludesHumanHealthData
            ? []
            : try context.fetch(FetchDescriptor<HumanHealthMetricLog>()) // smoothness: explicit manual-export scan only
        let humanHealthReports = scope.excludesHumanHealthData
            ? []
            : try context.fetch(FetchDescriptor<HumanHealthReport>()) // smoothness: explicit manual-export scan only
        let waterLogs = try context.fetch(FetchDescriptor<WaterLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let wishlist = try context.fetch(FetchDescriptor<WishlistItem>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let coconutAccounts = try context.fetch(FetchDescriptor<CoconutAccount>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let coconutLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let economyBudgetUsageEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()) // smoothness: explicit backup/export scan only
        let familyTasks = try context.fetch(FetchDescriptor<FamilyCollaborationTask>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let sharedCareSessions = try context.fetch(FetchDescriptor<SharedCareSession>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let exchanges = try context.fetch(FetchDescriptor<CoconutExchangeRequest>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let oasisUpgradeCoconuts = try context.fetch(FetchDescriptor<OasisUpgradeCoconut>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let oasisElectronicPets = try context.fetch(FetchDescriptor<OasisElectronicPet>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let oasisFragments = try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let oasisUnlocks = try context.fetch(FetchDescriptor<OasisUnlock>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let oasisCritterActionLogs = try context.fetch(FetchDescriptor<OasisCritterActionLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let gachaOwnedItems = try context.fetch(FetchDescriptor<GachaOwnedItem>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let gachaDrawLogs = try context.fetch(FetchDescriptor<GachaDrawLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let shopPurchaseRecords = try context.fetch(FetchDescriptor<ShopPurchaseRecord>()) // smoothness: explicit backup/export scan only

        let ud = defaults
        let purchasedShopItems = ShopPurchaseRecordStore
            .ownedItemIDs(from: shopPurchaseRecords)
            .sorted()
            .joined(separator: ",")
        let backupEvents = scope.excludesHumanHealthData
            ? events.filter { !Self.isHumanHealthEvent($0) }
            : events
        let backupEventIDs = Set(backupEvents.map(\.id))
        let backupReminders = scope.excludesHumanHealthData
            ? reminders.filter { reminder in
                guard let event = reminder.event else { return true }
                return backupEventIDs.contains(event.id)
            }
            : reminders
        let backupLedger = scope.excludesHumanHealthData
            ? ledger.filter { !Self.isHumanHealthLedgerEvent($0) }
            : ledger
        // Wallet and budget records carry free-form titles and metadata. Their
        // historical schema has no complete, durable health-source link, so a
        // restricted external package omits the entire derived economy sidecar
        // instead of trying to infer which records might repeat health facts.
        let backupCoconutLedgerEntries = scope.excludesHumanHealthData
            ? []
            : coconutLedgerEntries
        let backupEconomyBudgetUsageEvents = scope.excludesHumanHealthData
            ? []
            : economyBudgetUsageEvents
        // Family-task titles and notes are free-form and older tasks can have
        // no durable event/reminder link at all. A restricted external package
        // therefore omits the full task sidecar rather than inferring whether
        // a personal-health fact was written into the task text.
        let backupFamilyTasks = scope.excludesHumanHealthData
            ? []
            : familyTasks
        let coconutLogProjection = backupCoconutLedgerEntries
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(200)
            .filter { $0.delta != 0 }
            .map { $0.asCoconutLogEntry() }
        let coconutLogsJSON: String = {
            guard let data = try? JSONEncoder().encode(Array(coconutLogProjection)),
                  let string = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return string
        }()
        let appState = AppStateBackup(
            coconutCount: coconutAccounts.reduce(0) { $0 + $1.balance },
            coconutLogsJSON: coconutLogsJSON,
            bountyTasksJSON: ud.string(forKey: "bountyTasks") ?? "[]",
            purchasedShopItems: purchasedShopItems,
            selectedAppIcon: ud.string(forKey: AppIconCatalog.selectedIconKey),
            gachaHistoryJSON: ud.string(forKey: "gachaHistory") ?? "[]",
            celebratedMilestoneDays: ud.string(forKey: "celebratedMilestoneDays") ?? "",
            shopConsumableInventory: ShopConsumableInventoryBackup(
                backdatePassCount: ud.integer(forKey: CheckInStreakStore.makeupPackKey),
                avatar2DExtraPassCount: ud.integer(forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory),
                doubleRewardBoostActive: ud.bool(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost),
                streakShieldExpiry: d(ud.object(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry) as? Date)
            ),
            plantReminderPreferences: makePlantReminderPreferencesBackup(defaults: ud, plants: plants)
        )

        let petBackups = try pets.map { try encodePet($0, mediaWriter: mediaWriter) }
        let humanBackups = try humans.map {
            try encodeHuman(
                $0,
                mediaWriter: mediaWriter,
                redactingHealthData: scope.excludesHumanHealthData
            )
        }
        let plantBackups = try plants.map { try encodePlant($0, mediaWriter: mediaWriter) }
        let plantCareLogBackups = try plantCareLogs.map { try encodePlantCareLog($0, mediaWriter: mediaWriter) }
        let petWalkLogBackups = try walkLogs.map { try encodeWalkLog($0, mediaWriter: mediaWriter) }
        let petDocumentBackups = try docs.map { try encodeDocument($0, mediaWriter: mediaWriter) }
        let petDocumentAttachmentBackups = try docs.flatMap { try encodeDocumentAttachments($0, mediaWriter: mediaWriter) }
        let petMilestoneBackups = try milestones.map { try encodeMilestone($0, mediaWriter: mediaWriter) }
        let petPhotoLogBackups = try photos.map { try encodePhotoLog($0, mediaWriter: mediaWriter) }
        let symptomLogBackups = try symptoms.map { try encodeSymptomLog($0, mediaWriter: mediaWriter) }
        let mediaPackage = (mediaWriter as? DataBackupMediaPackageWriter).map {
            BackupMediaPackageInfo(
                format: "com.guanchen.li.ohana.backup.package.v1",
                mediaCount: $0.mediaCount,
                mediaBytes: $0.mediaBytes,
                encrypted: mediaPackageEncrypted
            )
        }

        return OhanaBackup(
            exportedAt: iso.string(from: Date()),
            exportScope: scope.rawValue,
            mediaPackage: mediaPackage,
            pets: petBackups,
            humans: humanBackups,
            events: backupEvents.map(encodeEvent),
            reminders: backupReminders.map(encodeReminder),
            households: households.map(encodeHousehold),
            plants: plantBackups,
            petRelationships: petRelationships.map(encodePetRelationship),
            plantCareLogs: plantCareLogBackups,
            petCareLogs: careLogs.map(encodeCareLog),
            petPottyLogs: pottyLogs.map(encodePottyLog),
            petWalkLogs: petWalkLogBackups,
            petWeightLogs: weightLogs.map(encodeWeightLog),
            petExpenseLogs: expLogs.map(encodeExpenseLog),
            petHealthLogs: healthLogs.map(encodeHealthLog),
            petHygieneLogs: hygLogs.map(encodeHygieneLog),
            petFoodRecords: foodRecs.map(encodeFoodRecord),
            petDocuments: petDocumentBackups,
            petDocumentAttachments: petDocumentAttachmentBackups,
            petMilestones: petMilestoneBackups,
            petPhotoLogs: petPhotoLogBackups,
            petInsurances: insurances.map(encodeInsurance),
            insuranceClaims: claims.map(encodeInsuranceClaim),
            petMedications: petMeds.map(encodePetMedication),
            symptomLogs: symptomLogBackups,
            heatCycleLogs: heatCycles.map(encodeHeatCycleLog),
            humanWeightLogs: hWeightLogs.map(encodeHumanWeight),
            humanWorkoutLogs: hWorkouts.map(encodeHumanWorkout),
            humanMedications: humanMeds.map(encodeHumanMedication),
            humanMedicationLogs: humanMedLogs.map(encodeHumanMedicationLog),
            humanHealthMetricLogs: humanHealthMetricLogs.map(encodeHumanHealthMetricLog),
            humanHealthReports: humanHealthReports.map(encodeHumanHealthReport),
            waterLogs: waterLogs.map(encodeWaterLog),
            wishlistItems: wishlist.map(encodeWishlist),
            careLedgerEvents: backupLedger.map(encodeCareLedgerEvent),
            coconutAccounts: coconutAccounts.map(encodeCoconutAccount),
            coconutLedgerEntries: backupCoconutLedgerEntries.map(encodeCoconutLedgerEntry),
            economyBudgetUsageEvents: backupEconomyBudgetUsageEvents.map(encodeEconomyBudgetUsageEvent),
            familyCollaborationTasks: backupFamilyTasks.map(encodeFamilyCollaborationTask),
            sharedCareSessions: sharedCareSessions.map(encodeSharedCareSession),
            coconutExchangeRequests: exchanges.map(encodeCoconutExchangeRequest),
            oasisUpgradeCoconuts: oasisUpgradeCoconuts.map(encodeOasisUpgradeCoconut),
            oasisElectronicPets: oasisElectronicPets.map(encodeOasisElectronicPet),
            oasisCritterFragments: oasisFragments.map(encodeOasisCritterFragment),
            oasisUnlocks: oasisUnlocks.map(encodeOasisUnlock),
            oasisCritterActionLogs: oasisCritterActionLogs.map(encodeOasisCritterActionLog),
            gachaOwnedItems: gachaOwnedItems.map(encodeGachaOwnedItem),
            gachaDrawLogs: gachaDrawLogs.map(encodeGachaDrawLog),
            shopPurchaseRecords: shopPurchaseRecords.map(encodeShopPurchaseRecord),
            appState: appState
        )
    }

    private static func isHumanHealthEvent(_ event: Event) -> Bool {
        let role = DomainEntityLinkRegistry.role(for: event)
        switch role {
        case .humanMedicationPlan, .humanNote:
            // Medication schedules and free-form human-note reminders can
            // include health data in their title or note body.
            return true
        case .directHuman:
            // A direct-human schedule has free-form text and no reliable
            // health classifier. Preserve only the two structured,
            // non-health lifecycle entries; omit everything else rather than
            // allowing a personal-health reminder to leave the device.
            switch event.eventType {
            case EventType.birthday.rawValue, EventType.anniversary.rawValue:
                return false
            default:
                return true
            }
        case .directPet, .directPlant, .plantScoped, .petFoodStock,
             .petAutoFeeder, .petWaterPlan, .petInsurance,
             .petMedicationPlan, .petMedicationDose, .unscoped, .unknown:
            // `.medication` is the human-only event type. Keeping this check
            // also protects malformed historical records without excluding
            // pet-health plans, which use a direct-pet relation.
            return event.eventType == EventType.medication.rawValue
        }
    }

    private static func isHumanHealthLedgerEvent(_ event: CareLedgerEvent) -> Bool {
        if event.subjectKind == CareLedgerSubjectKind.human.rawValue {
            return true
        }
        guard event.actorKind == CareLedgerActorKind.human.rawValue else { return false }
        switch event.eventKindEnum {
        case .health, .weight, .medication, .workout:
            return true
        default:
            return false
        }
    }

    // MARK: - Apply Backup

    @MainActor
    private func existingIds<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        id: KeyPath<T, UUID>,
        operation: String
    ) throws -> Set<String> {
        do {
            return try Set(context.fetch(descriptor).map { $0[keyPath: id].uuidString })
        } catch {
            OhanaLog.warning(
                "DataBackupManager failed to \(operation): \(error.localizedDescription)",
                category: "Backup"
            )
            throw error
        }
    }

    @MainActor
    func applyBackup(
        _ backup: OhanaBackup,
        context: ModelContext,
        projectionManager: CoconutProjectionManaging?,
        schedulePlantNotifications: Bool = true,
        plantNotifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        mediaResolver: DataBackupMediaResolving? = nil,
        restoreFaultInjector: DataBackupRestoreFaultInjector? = nil,
        restoreTransaction: DataBackupRestoreTransaction = { context, changes in
            try context.transaction(block: changes)
        }
    ) throws {
        guard !context.hasChanges else {
            throw BackupError.invalidRestoreData(.pendingChanges)
        }

        let existingIdentities = try DataBackupRestoreExistingIdentities(context: context)
        try DataBackupPreflightValidator.validate(backup, existing: existingIdentities)
        try runRestoreBoundary(.preflightCompleted, faultInjector: restoreFaultInjector)

        let stagedDefaults = DataBackupRestoreDefaults(snapshot: defaults.dictionaryRepresentation())
        applyAppStateDefaults(backup.appState, to: stagedDefaults)

        let previousAutosaveState = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosaveState }

        var pendingEffects: DataBackupRestorePendingEffects?
        var reachedCommitBoundary = false
        do {
            try restoreTransaction(context) {
                pendingEffects = try prepareBackupChanges(
                    backup,
                    context: context,
                    schedulePlantNotifications: schedulePlantNotifications,
                    plantNotifications: plantNotifications,
                    mediaResolver: mediaResolver,
                    restoreDefaults: stagedDefaults,
                    restoreBoundary: { phase in
                        try self.runRestoreBoundary(phase, faultInjector: restoreFaultInjector)
                    }
                )
                try runRestoreBoundary(.beforeCommit, faultInjector: restoreFaultInjector)
                reachedCommitBoundary = true
            }
        } catch {
            context.rollback()
            if reachedCommitBoundary {
                PersistenceSaveFailureCenter.publish(error: error, file: #file, line: #line)
                throw DataBackupRestorePersistenceError.persistenceFailed(error.localizedDescription)
            }
            throw error
        }

        guard let pendingEffects else {
            context.rollback()
            throw DataBackupRestorePersistenceError.persistenceFailed(nil)
        }

        // Only nonthrowing side effects run after SwiftData's single transaction
        // commits. A failed/cancelled transaction therefore cannot alter
        // UserDefaults, notifications, projections, or the live persistent store.
        applyAppStateDefaults(backup.appState, to: defaults)
        DomainRehydrateEffectsDispatcher.cancelNotifications(
            pendingEffects.notificationIDsToCancel,
            notifications: plantNotifications
        )
        CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
        if let plantReconciliation = pendingEffects.plantReconciliation {
            PlantBackupRestoreReconcileService.commitSideEffects(
                plantReconciliation,
                context: context,
                notifications: plantNotifications,
                defaults: defaults
            )
        }
    }

    @MainActor
    private func prepareBackupChanges(
        _ backup: OhanaBackup,
        context: ModelContext,
        schedulePlantNotifications: Bool,
        plantNotifications: ReminderNotificationScheduling,
        mediaResolver: DataBackupMediaResolving?,
        restoreDefaults: UserDefaults,
        restoreBoundary: (DataBackupRestorePhase) throws -> Void
    ) throws -> DataBackupRestorePendingEffects {
        // 以 UUID 为主键去重：先构建现有 ID 集合，再 upsert。
        // Event/Reminder 不能在 writer 前过滤；rehydrate writer 必须重新解析已有 schedule aggregate。
        var rehydrateNotificationIdsToCancel: [String] = []
        let existingLedgerIds = try existingIds(FetchDescriptor<CareLedgerEvent>(), context: context, id: \.id, operation: "fetch existing care ledger events before restore")
        let existingSharedCareSessionIds = try existingIds(FetchDescriptor<SharedCareSession>(), context: context, id: \.id, operation: "fetch existing shared care sessions before restore")
        for dto in backup.pets {
            try DomainGeneralRehydrateWriter.upsertPet(
                snapshot: try decodePetSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humans {
            try DomainGeneralRehydrateWriter.upsertHuman(
                snapshot: try decodeHumanSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.plants {
            try DomainGeneralRehydrateWriter.insertPlantIfNeeded(
                snapshot: try decodePlantSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.households {
            try DomainGeneralRehydrateWriter.upsertHousehold(
                snapshot: decodeHouseholdSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petRelationships ?? [] {
            try DomainGeneralRehydrateWriter.insertPetRelationshipIfNeeded(
                snapshot: decodePetRelationshipSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.events {
            let result = try DomainScheduleRehydrateWriter.upsertEvent(
                snapshot: decodeEventSnapshot(dto),
                source: .backupRestore,
                context: context
            )
            rehydrateNotificationIdsToCancel.append(contentsOf: result.notificationIdsToCancel)
        }
        try restoreBoundary(.membersAndSchedulesPrepared)

        for dto in backup.reminders {
            let result = try DomainScheduleRehydrateWriter.upsertReminder(
                snapshot: decodeReminderSnapshot(dto),
                source: .backupRestore,
                context: context
            )
            rehydrateNotificationIdsToCancel.append(contentsOf: result.notificationIdsToCancel)
        }

        // 日志类通过 rehydrate writer 插入，避免恢复路径绕过 subject/policy 解析。
        for dto in backup.plantCareLogs ?? [] {
            try DomainCareFactRehydrateWriter.insertPlantCareLogIfNeeded(
                snapshot: try decodePlantCareLogSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petCareLogs {
            try DomainCareFactRehydrateWriter.insertPetCareLogIfNeeded(
                snapshot: decodeCareLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petPottyLogs {
            try DomainCareFactRehydrateWriter.insertPetPottyLogIfNeeded(
                snapshot: decodePottyLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petWalkLogs {
            try DomainCareFactRehydrateWriter.insertPetWalkLogIfNeeded(
                snapshot: try decodeWalkLogSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petWeightLogs {
            try DomainCareFactRehydrateWriter.insertPetWeightLogIfNeeded(
                snapshot: decodeWeightLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petExpenseLogs {
            try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
                snapshot: decodeExpenseLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petHealthLogs {
            try DomainCareFactRehydrateWriter.insertPetHealthLogIfNeeded(
                snapshot: decodeHealthLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petHygieneLogs {
            try DomainCareFactRehydrateWriter.insertPetHygieneLogIfNeeded(
                snapshot: decodeHygieneLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petFoodRecords {
            try DomainCareFactRehydrateWriter.upsertPetFoodRecord(
                snapshot: decodeFoodRecordSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petDocuments {
            try DomainMemberContentRehydrateWriter.insertPetDocumentIfNeeded(
                snapshot: try decodeDocumentSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petPhotoLogs ?? [] {
            try DomainMemberContentRehydrateWriter.insertPetPhotoLogIfNeeded(
                snapshot: try decodePhotoLogSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petInsurances ?? [] {
            try DomainMemberContentRehydrateWriter.insertPetInsuranceIfNeeded(
                snapshot: decodeInsuranceSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petMedications ?? [] {
            try DomainMemberContentRehydrateWriter.insertPetMedicationIfNeeded(
                snapshot: decodePetMedicationSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humanMedications ?? [] {
            try DomainMemberContentRehydrateWriter.insertHumanMedicationIfNeeded(
                snapshot: decodeHumanMedicationSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.symptomLogs ?? [] {
            try DomainMemberContentRehydrateWriter.insertSymptomLogIfNeeded(
                snapshot: try decodeSymptomLogSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.heatCycleLogs ?? [] {
            try DomainMemberContentRehydrateWriter.insertHeatCycleLogIfNeeded(
                snapshot: decodeHeatCycleLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        try restoreBoundary(.careFactsPrepared)

        for dto in backup.petDocumentAttachments ?? [] {
            try DomainMemberContentRehydrateWriter.insertPetDocumentAttachmentIfNeeded(
                snapshot: try decodeDocumentAttachmentSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.insuranceClaims ?? [] {
            try DomainMemberContentRehydrateWriter.insertInsuranceClaimIfNeeded(
                snapshot: decodeInsuranceClaimSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humanMedicationLogs ?? [] {
            try DomainMemberContentRehydrateWriter.insertHumanMedicationLogIfNeeded(
                snapshot: decodeHumanMedicationLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humanHealthMetricLogs ?? [] {
            try DomainMemberContentRehydrateWriter.insertHumanHealthMetricLogIfNeeded(
                snapshot: decodeHumanHealthMetricLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humanHealthReports ?? [] {
            try DomainMemberContentRehydrateWriter.insertHumanHealthReportIfNeeded(
                snapshot: decodeHumanHealthReportSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petMilestones {
            try DomainMemberContentRehydrateWriter.insertPetMilestoneIfNeeded(
                snapshot: try decodeMilestoneSnapshot(dto, mediaResolver: mediaResolver),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humanWeightLogs {
            try DomainMemberContentRehydrateWriter.insertHumanWeightLogIfNeeded(
                snapshot: decodeHumanWeightSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humanWorkoutLogs {
            try DomainMemberContentRehydrateWriter.insertHumanWorkoutLogIfNeeded(
                snapshot: decodeHumanWorkoutSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.waterLogs {
            try DomainGeneralRehydrateWriter.insertWaterLogIfNeeded(
                snapshot: decodeWaterLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.wishlistItems {
            try DomainGeneralRehydrateWriter.insertWishlistItemIfNeeded(
                snapshot: decodeWishlistSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.careLedgerEvents ?? [] where !existingLedgerIds.contains(dto.id) {
            try DomainCareLedgerRehydrateWriter.upsertCareLedgerEvent(
                snapshot: decodeCareLedgerEventSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.coconutAccounts ?? [] {
            try DomainGeneralRehydrateWriter.insertCoconutAccountIfNeeded(
                snapshot: decodeCoconutAccountSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.coconutLedgerEntries ?? [] {
            try DomainGeneralRehydrateWriter.upsertCoconutLedgerEntry(
                snapshot: decodeCoconutLedgerEntrySnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.economyBudgetUsageEvents ?? [] {
            try DomainGeneralRehydrateWriter.insertEconomyBudgetUsageEventIfNeeded(
                snapshot: decodeEconomyBudgetUsageEventSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.familyCollaborationTasks ?? [] {
            try DomainGeneralRehydrateWriter.insertFamilyCollaborationTaskIfNeeded(
                snapshot: decodeFamilyCollaborationTaskSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.sharedCareSessions ?? [] where !existingSharedCareSessionIds.contains(dto.id) {
            try DomainCareFactRehydrateWriter.insertSharedCareSessionIfNeeded(
                snapshot: decodeSharedCareSessionSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.coconutExchangeRequests ?? [] {
            try DomainGeneralRehydrateWriter.insertCoconutExchangeRequestIfNeeded(
                snapshot: decodeCoconutExchangeRequestSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.oasisUpgradeCoconuts ?? [] {
            try DomainGeneralRehydrateWriter.insertOasisUpgradeCoconutIfNeeded(
                snapshot: decodeOasisUpgradeCoconutSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.oasisElectronicPets ?? [] {
            try DomainGeneralRehydrateWriter.insertOasisElectronicPetIfNeeded(
                snapshot: decodeOasisElectronicPetSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.oasisCritterFragments ?? [] {
            try DomainGeneralRehydrateWriter.insertOasisCritterFragmentIfNeeded(
                snapshot: decodeOasisCritterFragmentSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.oasisUnlocks ?? [] {
            try DomainGeneralRehydrateWriter.insertOasisUnlockIfNeeded(
                snapshot: decodeOasisUnlockSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.oasisCritterActionLogs ?? [] {
            try DomainGeneralRehydrateWriter.insertOasisCritterActionLogIfNeeded(
                snapshot: decodeOasisCritterActionLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.gachaOwnedItems ?? [] {
            try DomainGeneralRehydrateWriter.upsertGachaOwnedItem(
                snapshot: decodeGachaOwnedItemSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.gachaDrawLogs ?? [] {
            try DomainGeneralRehydrateWriter.upsertGachaDrawLog(
                snapshot: decodeGachaDrawLogSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.shopPurchaseRecords ?? [] {
            if try !ShopPurchaseRecordStore.isOwned(itemID: dto.itemId, context: context) {
                try DomainGeneralRehydrateWriter.upsertShopPurchaseRecord(
                    snapshot: decodeShopPurchaseRecordSnapshot(dto),
                    source: .backupRestore,
                    context: context
                )
            }
        }
        if backup.shopPurchaseRecords == nil {
            try insertLegacyShopPurchaseRecords(
                purchasedShopItemsRaw: backup.appState.purchasedShopItems,
                context: context
            )
        }
        try restoreBoundary(.extendedDataPrepared)
        _ = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            persistChanges: false
        )

        let s = backup.appState
        let isLegacyCoconutBackup = backup.coconutAccounts?.isEmpty != false
        if isLegacyCoconutBackup {
            try CoconutEconomyBootstrapService.bootstrapIfNeeded(
                context: context,
                legacyIslandCount: s.coconutCount,
                legacyLogsJSON: s.coconutLogsJSON,
                projectionManager: nil,
                saveChanges: false,
                updatesProjection: false
            )
        }

        let plantReconciliation: PlantBackupRestoreReconcileResult? = if !backup.plants.isEmpty || backup.plantCareLogs?.isEmpty == false {
            try PlantBackupRestoreReconcileService.rebuildPlantCarePlans(
                context: context,
                scheduleNotifications: schedulePlantNotifications,
                notifications: plantNotifications,
                defaults: restoreDefaults,
                saveChanges: false
            )
        } else {
            nil
        }
        try restoreBoundary(.derivedStatePrepared)
        return DataBackupRestorePendingEffects(
            notificationIDsToCancel: rehydrateNotificationIdsToCancel,
            plantReconciliation: plantReconciliation
        )
    }

    private func applyAppStateDefaults(_ state: AppStateBackup, to target: UserDefaults) {
        if !state.bountyTasksJSON.isEmpty { target.set(state.bountyTasksJSON, forKey: "bountyTasks") }
        if !state.purchasedShopItems.isEmpty { target.set(state.purchasedShopItems, forKey: "purchasedShopItems") }
        if let selectedAppIcon = state.selectedAppIcon, !selectedAppIcon.isEmpty {
            target.set(selectedAppIcon, forKey: AppIconCatalog.selectedIconKey)
        }
        if !state.gachaHistoryJSON.isEmpty { target.set(state.gachaHistoryJSON, forKey: "gachaHistory") }
        if !state.celebratedMilestoneDays.isEmpty {
            target.set(state.celebratedMilestoneDays, forKey: "celebratedMilestoneDays")
        }
        if let inventory = state.shopConsumableInventory {
            target.set(max(0, inventory.backdatePassCount), forKey: CheckInStreakStore.makeupPackKey)
            target.set(max(0, inventory.avatar2DExtraPassCount), forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)
            target.set(inventory.doubleRewardBoostActive, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
            if let expiry = parseDate(inventory.streakShieldExpiry) {
                target.set(expiry, forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            } else {
                target.removeObject(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            }
        }
        if let plantReminderPreferences = state.plantReminderPreferences {
            applyPlantReminderPreferences(plantReminderPreferences, defaults: target)
        }
    }

    private func makePlantReminderPreferencesBackup(
        defaults: UserDefaults,
        plants: [Plant]
    ) -> PlantReminderPreferencesBackup {
        let disabledCareTypes = PlantReminderPreferenceStore.controllableCareTypes
            .filter { !PlantReminderPreferenceStore.isCareTypeReminderEnabled($0, defaults: defaults) }
            .map(\.rawValue)
        let plantCareOverrides = makePlantCarePreferenceOverrides(defaults: defaults, plants: plants)

        return PlantReminderPreferencesBackup(
            timeWindowRaw: PlantReminderPreferenceStore.timeWindow(defaults: defaults).rawValue,
            weekendQuietEnabled: PlantReminderPreferenceStore.isWeekendQuietEnabled(defaults: defaults),
            travelModeEnabled: PlantReminderPreferenceStore.isTravelModeEnabled(defaults: defaults),
            disabledCareTypesRaw: disabledCareTypes,
            plantCareOverrides: plantCareOverrides.isEmpty ? nil : plantCareOverrides
        )
    }

    private func makePlantCarePreferenceOverrides(
        defaults: UserDefaults,
        plants: [Plant]
    ) -> [PlantCarePreferenceOverrideBackup] {
        plants.flatMap { plant in
            PlantReminderPreferenceStore.controllableCareTypes.compactMap { careType in
                let planCalendarEnabled = PlantReminderPreferenceStore.planCalendarOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let systemReminderEnabled = PlantReminderPreferenceStore.systemReminderOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let completionCalendarEnabled = PlantReminderPreferenceStore.completionCalendarOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let reminderLeadDays = PlantReminderPreferenceStore.reminderLeadDaysOverride(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                let recurrenceEndDate = PlantReminderPreferenceStore.recurrenceEndDate(
                    forPlantID: plant.id,
                    careType: careType,
                    defaults: defaults
                )
                guard planCalendarEnabled != nil ||
                    systemReminderEnabled != nil ||
                    completionCalendarEnabled != nil ||
                    reminderLeadDays != nil ||
                    recurrenceEndDate != nil else {
                    return nil
                }
                return PlantCarePreferenceOverrideBackup(
                    plantID: plant.id.uuidString,
                    careTypeRaw: careType.rawValue,
                    planCalendarEnabled: planCalendarEnabled,
                    systemReminderEnabled: systemReminderEnabled,
                    completionCalendarEnabled: completionCalendarEnabled,
                    reminderLeadDays: reminderLeadDays,
                    recurrenceEndDate: recurrenceEndDate.map { iso.string(from: $0) }
                )
            }
        }
    }

    private func applyPlantReminderPreferences(
        _ preferences: PlantReminderPreferencesBackup,
        defaults: UserDefaults
    ) {
        if let rawValue = preferences.timeWindowRaw,
           let timeWindow = PlantReminderTimeWindow(rawValue: rawValue) {
            PlantReminderPreferenceStore.setTimeWindow(timeWindow, defaults: defaults)
        }
        if let weekendQuietEnabled = preferences.weekendQuietEnabled {
            PlantReminderPreferenceStore.setWeekendQuietEnabled(weekendQuietEnabled, defaults: defaults)
        }
        if let travelModeEnabled = preferences.travelModeEnabled {
            PlantReminderPreferenceStore.setTravelModeEnabled(travelModeEnabled, defaults: defaults)
        }
        if let disabledCareTypesRaw = preferences.disabledCareTypesRaw {
            let disabledCareTypes = Set(disabledCareTypesRaw)
            for careType in PlantReminderPreferenceStore.controllableCareTypes {
                PlantReminderPreferenceStore.setCareTypeReminderEnabled(
                    !disabledCareTypes.contains(careType.rawValue),
                    for: careType,
                    defaults: defaults
                )
            }
        }
        for override in preferences.plantCareOverrides ?? [] {
            applyPlantCarePreferenceOverride(override, defaults: defaults)
        }
    }

    private func applyPlantCarePreferenceOverride(
        _ override: PlantCarePreferenceOverrideBackup,
        defaults: UserDefaults
    ) {
        guard let plantID = UUID(uuidString: override.plantID),
              let careType = PlantCareType(rawValue: override.careTypeRaw) else {
            return
        }
        if let planCalendarEnabled = override.planCalendarEnabled {
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                planCalendarEnabled,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        if let systemReminderEnabled = override.systemReminderEnabled {
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                systemReminderEnabled,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        if let completionCalendarEnabled = override.completionCalendarEnabled {
            PlantReminderPreferenceStore.setCompletionCalendarEnabled(
                completionCalendarEnabled,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        if let reminderLeadDays = override.reminderLeadDays {
            PlantReminderPreferenceStore.setReminderLeadDays(
                reminderLeadDays,
                forPlantID: plantID,
                careType: careType,
                defaults: defaults
            )
        }
        PlantReminderPreferenceStore.setRecurrenceEndDate(
            override.recurrenceEndDate.flatMap { parseDate($0) },
            forPlantID: plantID,
            careType: careType,
            defaults: defaults
        )
    }

    private func insertLegacyShopPurchaseRecords(
        purchasedShopItemsRaw: String,
        context: ModelContext
    ) throws {
        let itemIDs = ShopPurchaseRecordStore.legacyPurchasedItemIDs(raw: purchasedShopItemsRaw)
        for itemID in itemIDs {
            guard isLegacyShopOwnershipItemID(itemID),
                  try !ShopPurchaseRecordStore.isOwned(itemID: itemID, context: context)
            else {
                continue
            }
            try DomainGeneralRehydrateWriter.upsertShopPurchaseRecord(
                snapshot: DomainShopPurchaseRecordRehydrateSnapshot(
                    id: UUID(),
                    transactionKey: "legacyBackup:\(itemID)",
                    itemId: itemID,
                    buyerHumanId: "",
                    purchasedAt: Date(timeIntervalSince1970: 0),
                    sourceRaw: "legacyBackup",
                    isLegacyImport: true,
                    createdAt: Date(timeIntervalSince1970: 0)
                ),
                source: .backupRestore,
                context: context
            )
        }
    }

    private func isLegacyShopOwnershipItemID(_ itemID: String) -> Bool {
        guard itemID != AppIconCatalog.defaultItemId,
              itemID != "boost_avatar2d_extra",
              !itemID.hasPrefix("boost_")
        else {
            return false
        }
        return itemID.hasPrefix("appicon_") ||
            itemID.hasPrefix("fx_") ||
            itemID.hasPrefix("title_")
    }

    private func runRestoreBoundary(
        _ phase: DataBackupRestorePhase,
        faultInjector: DataBackupRestoreFaultInjector?
    ) throws {
        if Task<Never, Never>.isCancelled {
            throw CancellationError()
        }
        try faultInjector?(phase)
    }
}

enum DataBackupRestorePersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "backup.restore.persistence.failed",
                defaultValue: "Unable to save restored data.",
                comment: "Shown when restoring a backup cannot save restored data."
            )
        }
    }
}
