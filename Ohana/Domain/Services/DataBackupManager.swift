//
//  DataBackupManager.swift
//  Ohana
//
//  TASK 1: 全量 JSON 数据备份与恢复
//  覆盖 21 个 SwiftData 模型 + 关键 UserDefaults appState
//

import Foundation
import SwiftData

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
    static let backupFilePrefix = "ohana_backup_"
    static let staleExportAge: TimeInterval = 60 * 60

    /// Builds and writes a full backup. The unbounded full-table fetch + JSON
    /// encode run on a dedicated background SwiftData context (`DataBackupActor`)
    /// so the main thread is never blocked; only the final file write happens
    /// here.
    func exportJSON(container: ModelContainer, password: String? = nil) async throws -> URL {
        let flowStartedAt = await MainActor.run {
            AppFlowPerformance.start(AppPerformanceFlows.backupExport)
        }
        do {
            let data = try await DataBackupActor(modelContainer: container).exportData()
            let trimmedPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let shouldEncrypt = !trimmedPassword.isEmpty
            let exportData: Data = if shouldEncrypt {
                try DataBackupEncryption.encrypt(data, password: trimmedPassword)
            } else {
                data
            }
            await MainActor.run {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.backupExport,
                    AppPerformancePhases.dataReady,
                    startedAt: flowStartedAt,
                    note: ["bytes": "\(exportData.count)", "encrypted": "\(shouldEncrypt)"]
                )
            }

            // The export contains full plaintext health / medication / insurance /
            // document / location data, so it must be written atomically and with
            // complete file protection (encrypted at rest while the device is
            // locked). Old exports are purged by age so concurrent export/import
            // flows cannot delete each other's active backup files.
            Self.purgeStaleExports()

            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd_HHmmss"
            let stamp = f.string(from: Date())
            let uniqueId = UUID().uuidString
            let suffix = shouldEncrypt ? "encrypted.json" : "json"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.backupFilePrefix)\(stamp)_\(uniqueId).\(suffix)")
            try exportData.write(to: url, options: [.atomic, .completeFileProtection])
            await MainActor.run {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.backupExport,
                    AppPerformancePhases.writeSuccess,
                    startedAt: flowStartedAt,
                    note: ["bytes": "\(exportData.count)", "encrypted": "\(shouldEncrypt)"]
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

    // MARK: - Import

    /// Import stays on the main context so SwiftData @Query-backed UI refreshes
    /// immediately after a restore.
    @MainActor
    func importJSON(
        from url: URL,
        context: ModelContext,
        projectionManager: CoconutProjectionManaging? = nil,
        password: String? = nil
    ) async throws {
        let fileData = try Data(contentsOf: url) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        let data = try DataBackupEncryption.decryptIfNeeded(fileData, password: password)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(OhanaBackup.self, from: data)

        guard backup.schemaVersion <= 27 else {
            throw BackupError.unsupportedVersion(backup.schemaVersion)
        }

        try applyBackup(backup, context: context, projectionManager: projectionManager)
    }

    // MARK: - Build Backup

    func buildBackup(context: ModelContext) throws -> OhanaBackup {
        let pets = try context.fetch(FetchDescriptor<Pet>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let humans = try context.fetch(FetchDescriptor<Human>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let events = try context.fetch(FetchDescriptor<Event>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let reminders = try context.fetch(FetchDescriptor<Reminder>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let households = try context.fetch(FetchDescriptor<Household>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let plants = try context.fetch(FetchDescriptor<Plant>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
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
        let hWeightLogs = try context.fetch(FetchDescriptor<HumanWeightLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let hWorkouts = try context.fetch(FetchDescriptor<HumanWorkoutLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let humanMeds = try context.fetch(FetchDescriptor<HumanMedication>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let humanMedLogs = try context.fetch(FetchDescriptor<HumanMedicationLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let humanHealthMetricLogs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let waterLogs = try context.fetch(FetchDescriptor<WaterLog>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let wishlist = try context.fetch(FetchDescriptor<WishlistItem>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let coconutAccounts = try context.fetch(FetchDescriptor<CoconutAccount>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let coconutLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
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
            )
        )

        return OhanaBackup(
            exportedAt: iso.string(from: Date()),
            pets: pets.map(encodePet),
            humans: humans.map(encodeHuman),
            events: events.map(encodeEvent),
            reminders: reminders.map(encodeReminder),
            households: households.map(encodeHousehold),
            plants: plants.map(encodePlant),
            plantCareLogs: plantCareLogs.map(encodePlantCareLog),
            petCareLogs: careLogs.map(encodeCareLog),
            petPottyLogs: pottyLogs.map(encodePottyLog),
            petWalkLogs: walkLogs.map(encodeWalkLog),
            petWeightLogs: weightLogs.map(encodeWeightLog),
            petExpenseLogs: expLogs.map(encodeExpenseLog),
            petHealthLogs: healthLogs.map(encodeHealthLog),
            petHygieneLogs: hygLogs.map(encodeHygieneLog),
            petFoodRecords: foodRecs.map(encodeFoodRecord),
            petDocuments: docs.map(encodeDocument),
            petDocumentAttachments: docs.flatMap(encodeDocumentAttachments),
            petMilestones: milestones.map(encodeMilestone),
            petPhotoLogs: photos.map(encodePhotoLog),
            petInsurances: insurances.map(encodeInsurance),
            insuranceClaims: claims.map(encodeInsuranceClaim),
            petMedications: petMeds.map(encodePetMedication),
            symptomLogs: symptoms.map(encodeSymptomLog),
            heatCycleLogs: heatCycles.map(encodeHeatCycleLog),
            humanWeightLogs: hWeightLogs.map(encodeHumanWeight),
            humanWorkoutLogs: hWorkouts.map(encodeHumanWorkout),
            humanMedications: humanMeds.map(encodeHumanMedication),
            humanMedicationLogs: humanMedLogs.map(encodeHumanMedicationLog),
            humanHealthMetricLogs: humanHealthMetricLogs.map(encodeHumanHealthMetricLog),
            waterLogs: waterLogs.map(encodeWaterLog),
            wishlistItems: wishlist.map(encodeWishlist),
            careLedgerEvents: ledger.map(encodeCareLedgerEvent),
            coconutAccounts: coconutAccounts.map(encodeCoconutAccount),
            coconutLedgerEntries: coconutLedgerEntries.map(encodeCoconutLedgerEntry),
            familyCollaborationTasks: familyTasks.map(encodeFamilyCollaborationTask),
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
    func applyBackup(_ backup: OhanaBackup, context: ModelContext, projectionManager: CoconutProjectionManaging?) throws {
        // 以 UUID 为主键去重：先构建现有 ID 集合，再 upsert。
        // Event/Reminder 不能在 writer 前过滤；rehydrate writer 必须重新解析已有 schedule aggregate。
        var rehydrateNotificationIdsToCancel: [String] = []
        let existingLedgerIds = try existingIds(FetchDescriptor<CareLedgerEvent>(), context: context, id: \.id, operation: "fetch existing care ledger events before restore")
        let existingSharedCareSessionIds = try existingIds(FetchDescriptor<SharedCareSession>(), context: context, id: \.id, operation: "fetch existing shared care sessions before restore")
        for dto in backup.pets {
            try DomainGeneralRehydrateWriter.upsertPet(
                snapshot: decodePetSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.humans {
            try DomainGeneralRehydrateWriter.upsertHuman(
                snapshot: decodeHumanSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.plants {
            try DomainGeneralRehydrateWriter.insertPlantIfNeeded(
                snapshot: decodePlantSnapshot(dto),
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
        for dto in backup.events {
            let result = try DomainScheduleRehydrateWriter.upsertEvent(
                snapshot: decodeEventSnapshot(dto),
                source: .backupRestore,
                context: context
            )
            rehydrateNotificationIdsToCancel.append(contentsOf: result.notificationIdsToCancel)
        }
        try context.save()

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
                snapshot: decodePlantCareLogSnapshot(dto),
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
                snapshot: decodeWalkLogSnapshot(dto),
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
                snapshot: decodeDocumentSnapshot(dto),
                source: .backupRestore,
                context: context
            )
        }
        for dto in backup.petPhotoLogs ?? [] {
            try DomainMemberContentRehydrateWriter.insertPetPhotoLogIfNeeded(
                snapshot: decodePhotoLogSnapshot(dto),
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
                snapshot: decodeSymptomLogSnapshot(dto),
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
        try context.save()

        for dto in backup.petDocumentAttachments ?? [] {
            try DomainMemberContentRehydrateWriter.insertPetDocumentAttachmentIfNeeded(
                snapshot: decodeDocumentAttachmentSnapshot(dto),
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
        for dto in backup.petMilestones {
            try DomainMemberContentRehydrateWriter.insertPetMilestoneIfNeeded(
                snapshot: decodeMilestoneSnapshot(dto),
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
        try context.save()
        SharedCareSessionMaintenance.cleanLegacyNoteMetadata(context: context)
        DomainRehydrateEffectsDispatcher.cancelNotifications(rehydrateNotificationIdsToCancel)

        // 恢复 UserDefaults appState
        let ud = defaults
        let s = backup.appState
        let isLegacyCoconutBackup = backup.coconutAccounts?.isEmpty != false
        if !s.bountyTasksJSON.isEmpty { ud.set(s.bountyTasksJSON, forKey: "bountyTasks") }
        if !s.purchasedShopItems.isEmpty { ud.set(s.purchasedShopItems, forKey: "purchasedShopItems") }
        if let selectedAppIcon = s.selectedAppIcon, !selectedAppIcon.isEmpty {
            ud.set(selectedAppIcon, forKey: AppIconCatalog.selectedIconKey)
        }
        if !s.gachaHistoryJSON.isEmpty { ud.set(s.gachaHistoryJSON, forKey: "gachaHistory") }
        if !s.celebratedMilestoneDays.isEmpty { ud.set(s.celebratedMilestoneDays, forKey: "celebratedMilestoneDays") }
        if let inventory = s.shopConsumableInventory {
            ud.set(max(0, inventory.backdatePassCount), forKey: CheckInStreakStore.makeupPackKey)
            ud.set(max(0, inventory.avatar2DExtraPassCount), forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)
            ud.set(inventory.doubleRewardBoostActive, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
            if let expiry = parseDate(inventory.streakShieldExpiry) {
                ud.set(expiry, forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            } else {
                ud.removeObject(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            }
        }
        if isLegacyCoconutBackup {
            try? CoconutEconomyBootstrapService.bootstrapIfNeeded(
                context: context,
                legacyIslandCount: s.coconutCount,
                legacyLogsJSON: s.coconutLogsJSON,
                projectionManager: projectionManager
            )
        } else {
            CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
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
}
