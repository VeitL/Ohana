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
        },
        settleShopPurchases: (() -> Void)? = nil
    ) async throws {
        try ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: { throw BackupError.pendingShopPurchase },
            operation: {
                settleShopPurchases?()
                try importJSONWhileFenced(
                    from: url,
                    context: context,
                    projectionManager: projectionManager,
                    password: password,
                    schedulePlantNotifications: schedulePlantNotifications,
                    plantNotifications: plantNotifications,
                    restoreFaultInjector: restoreFaultInjector,
                    restoreTransaction: restoreTransaction
                )
            }
        )
    }

    @MainActor
    private func importJSONWhileFenced(
        from url: URL,
        context: ModelContext,
        projectionManager: CoconutProjectionManaging?,
        password: String?,
        schedulePlantNotifications: Bool,
        plantNotifications: ReminderNotificationScheduling,
        restoreFaultInjector: DataBackupRestoreFaultInjector?,
        restoreTransaction: DataBackupRestoreTransaction
    ) throws {
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

        try applyBackupWhileFenced(
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
}

extension DataBackupManager {
    private struct BackupSource {
        let pets: [Pet]
        let humans: [Human]
        let events: [Event]
        let reminders: [Reminder]
        let households: [Household]
        let plants: [Plant]
        let petRelationships: [PetRelationship]
        let plantCareLogs: [PlantCareLog]
        let careLogs: [PetCareLog]
        let pottyLogs: [PetPottyLog]
        let walkLogs: [PetWalkLog]
        let weightLogs: [PetWeightLog]
        let expLogs: [PetExpenseLog]
        let healthLogs: [PetHealthLog]
        let hygLogs: [PetHygieneLog]
        let foodRecs: [PetFoodRecord]
        let docs: [PetDocument]
        let milestones: [PetMilestone]
        let photos: [PetPhotoLog]
        let insurances: [PetInsurance]
        let claims: [InsuranceClaim]
        let petMeds: [PetMedication]
        let symptoms: [SymptomLog]
        let heatCycles: [HeatCycleLog]
        let hWeightLogs: [HumanWeightLog]
        let hWorkouts: [HumanWorkoutLog]
        let humanMeds: [HumanMedication]
        let humanMedLogs: [HumanMedicationLog]
        let humanHealthMetricLogs: [HumanHealthMetricLog]
        let humanHealthRecords: (reports: [HumanHealthReport], noteRecords: [HumanNoteRecordBackup])
        let waterLogs: [WaterLog]
        let wishlist: [WishlistItem]
        let ledger: [CareLedgerEvent]
        let coconutAccounts: [CoconutAccount]
        let coconutLedgerEntries: [CoconutLedgerEntry]
        let economyBudgetUsageEvents: [EconomyBudgetUsageEvent]
        let familyTasks: [FamilyCollaborationTask]
        let sharedCareSessions: [SharedCareSession]
        let exchanges: [CoconutExchangeRequest]
        let oasisUpgradeCoconuts: [OasisUpgradeCoconut]
        let oasisElectronicPets: [OasisElectronicPet]
        let oasisFragments: [OasisCritterFragmentBalance]
        let oasisUnlocks: [OasisUnlock]
        let oasisCritterActionLogs: [OasisCritterActionLog]
        let gachaOwnedItems: [GachaOwnedItem]
        let gachaDrawLogs: [GachaDrawLog]
        let shopPurchaseRecords: [ShopPurchaseRecord]
        let presenceCheckIns: [PresenceCheckIn]
        let presenceParticipationPeriods: [PresenceParticipationPeriod]
        let presenceRewardReceipts: [PresenceRewardReceipt]
        let achievementUnlocks: [AchievementUnlock]
        let achievementRewardReceipts: [AchievementRewardReceipt]
    }

    // MARK: - Build Backup

    func buildBackup(
        context: ModelContext,
        mediaWriter: DataBackupMediaWriting? = nil,
        mediaPackageEncrypted: Bool = false,
        scope: DataBackupExportScope = .manualExternalRestricted
    ) throws -> OhanaBackup {
        try ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: { throw BackupError.pendingShopPurchase },
            operation: {
                try buildBackupWhileFenced(
                    context: context,
                    mediaWriter: mediaWriter,
                    mediaPackageEncrypted: mediaPackageEncrypted,
                    scope: scope
                )
            }
        )
    }

    private func buildBackupWhileFenced(
        context: ModelContext,
        mediaWriter: DataBackupMediaWriting? = nil,
        mediaPackageEncrypted: Bool = false,
        scope: DataBackupExportScope = .manualExternalRestricted
    ) throws -> OhanaBackup {
        // Purchase attempts coordinate SwiftData wallet facts with local device
        // effects and are deliberately excluded from external backup. Never
        // export the debited wallet while that coordination is still live.
        try ensureNoUnresolvedShopPurchases(context: context)

        let source = try fetchBackupSource(context: context, scope: scope)

        let backupEvents = scope.excludesHumanHealthData
            ? source.events.filter { !Self.isHumanHealthEvent($0) }
            : source.events
        let backupEventIDs = Set(backupEvents.map(\.id))
        let backupReminders = scope.excludesHumanHealthData
            ? source.reminders.filter { reminder in
                guard let event = reminder.event else { return true }
                return backupEventIDs.contains(event.id)
            }
            : source.reminders
        let backupLedger = scope.excludesHumanHealthData
            ? source.ledger.filter { !Self.isHumanHealthLedgerEvent($0) }
            : source.ledger
        // Wallet and budget records carry free-form titles and metadata. Their
        // historical schema has no complete, durable health-source link, so a
        // restricted external package omits the entire derived economy sidecar
        // instead of trying to infer which records might repeat health facts.
        let backupCoconutLedgerEntries = scope.excludesHumanHealthData
            ? []
            : source.coconutLedgerEntries
        let backupEconomyBudgetUsageEvents = scope.excludesHumanHealthData
            ? []
            : source.economyBudgetUsageEvents
        // Family-task titles and notes are free-form and older tasks can have
        // no durable event/reminder link at all. A restricted external package
        // therefore omits the full task sidecar rather than inferring whether
        // a personal-health fact was written into the task text.
        let backupFamilyTasks = scope.excludesHumanHealthData
            ? []
            : source.familyTasks
        // Human health/movement achievement IDs can reveal private weight,
        // medication, or workout facts. Restricted exports omit those exact
        // categories while retaining privacy-safe profile, economy, and tenure
        // receipts so a restore cannot make a claimed reward claimable again.
        // Unknown Human-scoped IDs fail closed in the privacy filter.
        let achievementFacts = filteredAchievementFacts(
            source.achievementUnlocks, source.achievementRewardReceipts, scope
        )
        let appState = makeAppStateBackup(
            source.shopPurchaseRecords, source.coconutAccounts, backupCoconutLedgerEntries, source.plants
        )

        let petBackups = try source.pets.map { try encodePet($0, mediaWriter: mediaWriter) }
        let humanBackups = try source.humans.map {
            try encodeHuman(
                $0,
                mediaWriter: mediaWriter,
                redactingHealthData: scope.excludesHumanHealthData
            )
        }
        let plantBackups = try source.plants.map { try encodePlant($0, mediaWriter: mediaWriter) }
        let plantCareLogBackups = try source.plantCareLogs.map { try encodePlantCareLog($0, mediaWriter: mediaWriter) }
        let petWalkLogBackups = try source.walkLogs.map { try encodeWalkLog($0, mediaWriter: mediaWriter) }
        let petDocumentBackups = try source.docs.map { try encodeDocument($0, mediaWriter: mediaWriter) }
        let petDocumentAttachmentBackups = try source.docs.flatMap { try encodeDocumentAttachments($0, mediaWriter: mediaWriter) }
        let petMilestoneBackups = try source.milestones.map { try encodeMilestone($0, mediaWriter: mediaWriter) }
        let petPhotoLogBackups = try source.photos.map { try encodePhotoLog($0, mediaWriter: mediaWriter) }
        let symptomLogBackups = try source.symptoms.map { try encodeSymptomLog($0, mediaWriter: mediaWriter) }
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
            households: source.households.map(encodeHousehold),
            plants: plantBackups,
            petRelationships: source.petRelationships.map(encodePetRelationship),
            plantCareLogs: plantCareLogBackups,
            petCareLogs: source.careLogs.map(encodeCareLog),
            petPottyLogs: source.pottyLogs.map(encodePottyLog),
            petWalkLogs: petWalkLogBackups,
            petWeightLogs: source.weightLogs.map(encodeWeightLog),
            petExpenseLogs: source.expLogs.map(encodeExpenseLog),
            petHealthLogs: source.healthLogs.map(encodeHealthLog),
            petHygieneLogs: source.hygLogs.map(encodeHygieneLog),
            petFoodRecords: source.foodRecs.map(encodeFoodRecord),
            petDocuments: petDocumentBackups,
            petDocumentAttachments: petDocumentAttachmentBackups,
            petMilestones: petMilestoneBackups,
            petPhotoLogs: petPhotoLogBackups,
            petInsurances: source.insurances.map(encodeInsurance),
            insuranceClaims: source.claims.map(encodeInsuranceClaim),
            petMedications: source.petMeds.map(encodePetMedication),
            symptomLogs: symptomLogBackups,
            heatCycleLogs: source.heatCycles.map(encodeHeatCycleLog),
            humanWeightLogs: source.hWeightLogs.map(encodeHumanWeight),
            humanWorkoutLogs: source.hWorkouts.map(encodeHumanWorkout),
            humanMedications: source.humanMeds.map(encodeHumanMedication),
            humanMedicationLogs: source.humanMedLogs.map(encodeHumanMedicationLog),
            humanHealthMetricLogs: source.humanHealthMetricLogs.map(encodeHumanHealthMetricLog),
            humanHealthReports: source.humanHealthRecords.reports.map(encodeHumanHealthReport),
            humanNoteRecords: source.humanHealthRecords.noteRecords,
            waterLogs: source.waterLogs.map(encodeWaterLog),
            wishlistItems: source.wishlist.map(encodeWishlist),
            careLedgerEvents: backupLedger.map(encodeCareLedgerEvent),
            coconutAccounts: source.coconutAccounts.map(encodeCoconutAccount),
            coconutLedgerEntries: backupCoconutLedgerEntries.map(encodeCoconutLedgerEntry),
            economyBudgetUsageEvents: backupEconomyBudgetUsageEvents.map(encodeEconomyBudgetUsageEvent),
            familyCollaborationTasks: backupFamilyTasks.map(encodeFamilyCollaborationTask),
            sharedCareSessions: source.sharedCareSessions.map(encodeSharedCareSession),
            coconutExchangeRequests: source.exchanges.map(encodeCoconutExchangeRequest),
            oasisUpgradeCoconuts: source.oasisUpgradeCoconuts.map(encodeOasisUpgradeCoconut),
            oasisElectronicPets: source.oasisElectronicPets.map(encodeOasisElectronicPet),
            oasisCritterFragments: source.oasisFragments.map(encodeOasisCritterFragment),
            oasisUnlocks: source.oasisUnlocks.map(encodeOasisUnlock),
            oasisCritterActionLogs: source.oasisCritterActionLogs.map(encodeOasisCritterActionLog),
            gachaOwnedItems: source.gachaOwnedItems.map(encodeGachaOwnedItem),
            gachaDrawLogs: source.gachaDrawLogs.map(encodeGachaDrawLog),
            shopPurchaseRecords: source.shopPurchaseRecords.map(encodeShopPurchaseRecord),
            presenceCheckIns: source.presenceCheckIns.map { encodePresenceCheckIn($0) },
            presenceParticipationPeriods: source.presenceParticipationPeriods.map {
                encodePresenceParticipationPeriod($0)
            },
            presenceRewardReceipts: source.presenceRewardReceipts.map {
                encodePresenceRewardReceipt($0)
            },
            achievementUnlocks: achievementFacts.unlocks.map(encodeAchievementUnlock),
            achievementRewardReceipts: achievementFacts.receipts.map(encodeAchievementRewardReceipt),
            appState: appState
        )
    }

    private func filteredAchievementFacts(
        _ unlocks: [AchievementUnlock],
        _ receipts: [AchievementRewardReceipt],
        _ scope: DataBackupExportScope
    ) -> (unlocks: [AchievementUnlock], receipts: [AchievementRewardReceipt]) {
        guard scope.excludesHumanHealthData else { return (unlocks, receipts) }
        return (
            unlocks.filter {
                !Self.isHumanHealthAchievement(
                    scopeKindRaw: $0.scopeKindRaw,
                    achievementID: $0.achievementID
                )
            },
            receipts.filter {
                !Self.isHumanHealthAchievement(
                    scopeKindRaw: $0.scopeKindRaw,
                    achievementID: $0.achievementID
                )
            }
        )
    }

    private func fetchBackupSource(
        context: ModelContext,
        scope: DataBackupExportScope
    ) throws -> BackupSource {
        BackupSource(
            pets: try context.fetch(FetchDescriptor<Pet>()),
            humans: try context.fetch(FetchDescriptor<Human>()),
            events: try context.fetch(FetchDescriptor<Event>()),
            reminders: try context.fetch(FetchDescriptor<Reminder>()),
            households: try context.fetch(FetchDescriptor<Household>()),
            plants: try context.fetch(FetchDescriptor<Plant>()),
            petRelationships: try context.fetch(FetchDescriptor<PetRelationship>()),
            plantCareLogs: try context.fetch(FetchDescriptor<PlantCareLog>()),
            careLogs: try context.fetch(FetchDescriptor<PetCareLog>()),
            pottyLogs: try context.fetch(FetchDescriptor<PetPottyLog>()),
            walkLogs: try context.fetch(FetchDescriptor<PetWalkLog>()),
            weightLogs: try context.fetch(FetchDescriptor<PetWeightLog>()),
            expLogs: try context.fetch(FetchDescriptor<PetExpenseLog>()),
            healthLogs: try context.fetch(FetchDescriptor<PetHealthLog>()),
            hygLogs: try context.fetch(FetchDescriptor<PetHygieneLog>()),
            foodRecs: try context.fetch(FetchDescriptor<PetFoodRecord>()),
            docs: try context.fetch(FetchDescriptor<PetDocument>()),
            milestones: try context.fetch(FetchDescriptor<PetMilestone>()),
            photos: try context.fetch(FetchDescriptor<PetPhotoLog>()),
            insurances: try context.fetch(FetchDescriptor<PetInsurance>()),
            claims: try context.fetch(FetchDescriptor<InsuranceClaim>()),
            petMeds: try context.fetch(FetchDescriptor<PetMedication>()),
            symptoms: try context.fetch(FetchDescriptor<SymptomLog>()),
            heatCycles: try context.fetch(FetchDescriptor<HeatCycleLog>()),
            hWeightLogs: scope.excludesHumanHealthData ? [] : try context.fetch(FetchDescriptor<HumanWeightLog>()),
            hWorkouts: scope.excludesHumanHealthData ? [] : try context.fetch(FetchDescriptor<HumanWorkoutLog>()),
            humanMeds: scope.excludesHumanHealthData ? [] : try context.fetch(FetchDescriptor<HumanMedication>()),
            humanMedLogs: scope.excludesHumanHealthData ? [] : try context.fetch(FetchDescriptor<HumanMedicationLog>()),
            humanHealthMetricLogs: scope.excludesHumanHealthData ? [] : try context.fetch(FetchDescriptor<HumanHealthMetricLog>()),
            humanHealthRecords: try backupHumanHealthRecords(context: context, scope: scope),
            waterLogs: try context.fetch(FetchDescriptor<WaterLog>()),
            wishlist: try context.fetch(FetchDescriptor<WishlistItem>()),
            ledger: try context.fetch(FetchDescriptor<CareLedgerEvent>()),
            coconutAccounts: try context.fetch(FetchDescriptor<CoconutAccount>()),
            coconutLedgerEntries: try context.fetch(FetchDescriptor<CoconutLedgerEntry>()),
            economyBudgetUsageEvents: try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()),
            familyTasks: try context.fetch(FetchDescriptor<FamilyCollaborationTask>()),
            sharedCareSessions: try context.fetch(FetchDescriptor<SharedCareSession>()),
            exchanges: try context.fetch(FetchDescriptor<CoconutExchangeRequest>()),
            oasisUpgradeCoconuts: try context.fetch(FetchDescriptor<OasisUpgradeCoconut>()),
            oasisElectronicPets: try context.fetch(FetchDescriptor<OasisElectronicPet>()),
            oasisFragments: try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()),
            oasisUnlocks: try context.fetch(FetchDescriptor<OasisUnlock>()),
            oasisCritterActionLogs: try context.fetch(FetchDescriptor<OasisCritterActionLog>()),
            gachaOwnedItems: try context.fetch(FetchDescriptor<GachaOwnedItem>()),
            gachaDrawLogs: try context.fetch(FetchDescriptor<GachaDrawLog>()),
            shopPurchaseRecords: try context.fetch(FetchDescriptor<ShopPurchaseRecord>()),
            presenceCheckIns: try context.fetch(FetchDescriptor<PresenceCheckIn>()),
            presenceParticipationPeriods: try context.fetch(FetchDescriptor<PresenceParticipationPeriod>()),
            presenceRewardReceipts: try context.fetch(FetchDescriptor<PresenceRewardReceipt>()),
            achievementUnlocks: try context.fetch(FetchDescriptor<AchievementUnlock>()),
            achievementRewardReceipts: try context.fetch(FetchDescriptor<AchievementRewardReceipt>())
        )
    }

    private func makeAppStateBackup(
        _ shopPurchaseRecords: [ShopPurchaseRecord],
        _ coconutAccounts: [CoconutAccount],
        _ coconutLedgerEntries: [CoconutLedgerEntry],
        _ plants: [Plant]
    ) -> AppStateBackup {
        let coconutLogProjection = coconutLedgerEntries
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
        let shopInventorySnapshot = ShopInventoryStateStore.snapshot(defaults: defaults)
        return AppStateBackup(
            coconutCount: coconutAccounts.reduce(0) { $0 + $1.balance },
            coconutLogsJSON: coconutLogsJSON,
            bountyTasksJSON: defaults.string(forKey: "bountyTasks") ?? "[]",
            purchasedShopItems: ShopPurchaseRecordStore.ownedItemIDs(from: shopPurchaseRecords).sorted().joined(separator: ","),
            selectedAppIcon: defaults.string(forKey: AppIconCatalog.selectedIconKey),
            gachaHistoryJSON: defaults.string(forKey: "gachaHistory") ?? "[]",
            celebratedMilestoneDays: defaults.string(forKey: "celebratedMilestoneDays") ?? "",
            shopConsumableInventory: ShopConsumableInventoryBackup(
                backdatePassCount: shopInventorySnapshot.backdatePassCount,
                avatar2DExtraPassCount: shopInventorySnapshot.avatar2DExtraPassCount,
                doubleRewardBoostActive: shopInventorySnapshot.isDoubleRewardBoostActive,
                streakShieldExpiry: d(shopInventorySnapshot.streakShieldExpiry)
            ),
            plantReminderPreferences: makePlantReminderPreferencesBackup(defaults: defaults, plants: plants)
        )
    }

    // MARK: - Apply Backup

    private func ensureNoUnresolvedShopPurchases(context: ModelContext) throws {
        let fulfilledAttempt = ShopPurchaseAttemptState.fulfilled.rawValue
        let refundedAttempt = ShopPurchaseAttemptState.refunded.rawValue
        var descriptor = FetchDescriptor<ShopPurchaseAttempt>(
            predicate: #Predicate<ShopPurchaseAttempt> { attempt in
                attempt.stateRaw != fulfilledAttempt &&
                    attempt.stateRaw != refundedAttempt
            }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else {
            throw BackupError.pendingShopPurchase
        }
    }

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
        try ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: { throw BackupError.pendingShopPurchase },
            operation: {
                try applyBackupWhileFenced(
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
        )
    }

    @MainActor
    private func applyBackupWhileFenced(
        _ backup: OhanaBackup,
        context: ModelContext,
        projectionManager: CoconutProjectionManaging?,
        schedulePlantNotifications: Bool,
        plantNotifications: ReminderNotificationScheduling,
        mediaResolver: DataBackupMediaResolving?,
        restoreFaultInjector: DataBackupRestoreFaultInjector?,
        restoreTransaction: DataBackupRestoreTransaction
    ) throws {
        try ensureNoUnresolvedShopPurchases(context: context)
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
        try restoreHumanNoteRecordsAfterMemberScheduleBoundary(backup, context: context, boundary: restoreBoundary)

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
        try restorePresenceAndAchievementFacts(backup, context: context)
        try restoreBoundary(.extendedDataPrepared)
        _ = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(context: context, persistChanges: false)

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

    private func restorePresenceAndAchievementFacts(
        _ backup: OhanaBackup,
        context: ModelContext
    ) throws {
        // Facts only: restore must never invoke live commands or mint rewards.
        for dto in backup.presenceCheckIns ?? [] {
            try PresenceRehydrateWriter.upsert(
                try decodePresenceCheckInSnapshot(dto),
                context: context
            )
        }
        for dto in backup.presenceParticipationPeriods ?? [] {
            guard let exportedAt = iso.date(from: backup.exportedAt) else {
                throw BackupError.invalidRestoreData(.date)
            }
            try PresenceRehydrateWriter.upsert(
                normalizeActivePresenceParticipationForRestore(
                    try decodePresenceParticipationPeriodSnapshot(dto),
                    exportedAt: exportedAt,
                    checkIns: backup.presenceCheckIns ?? []
                ),
                context: context
            )
        }
        for dto in backup.presenceRewardReceipts ?? [] {
            try PresenceRehydrateWriter.upsert(
                try decodePresenceRewardReceiptSnapshot(dto),
                context: context
            )
        }
        for dto in backup.achievementUnlocks ?? [] {
            try AchievementFactRehydrateWriter.upsertUnlock(dto, context: context, iso: iso)
        }
        for dto in backup.achievementRewardReceipts ?? [] {
            try AchievementFactRehydrateWriter.upsertReceipt(dto, context: context, iso: iso)
        }
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
