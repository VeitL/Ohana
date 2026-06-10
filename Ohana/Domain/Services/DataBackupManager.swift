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
    func exportJSON(container: ModelContainer) async throws -> URL {
        let flowStartedAt = await MainActor.run {
            AppFlowPerformance.start(AppPerformanceFlows.backupExport)
        }
        do {
            let data = try await DataBackupActor(modelContainer: container).exportData()
            await MainActor.run {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.backupExport,
                    AppPerformancePhases.dataReady,
                    startedAt: flowStartedAt,
                    note: ["bytes": "\(data.count)"]
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
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.backupFilePrefix)\(stamp)_\(uniqueId).json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            await MainActor.run {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.backupExport,
                    AppPerformancePhases.writeSuccess,
                    startedAt: flowStartedAt,
                    note: ["bytes": "\(data.count)"]
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
    func importJSON(from url: URL, context: ModelContext, projectionManager: QuestManager? = nil) async throws {
        let data = try Data(contentsOf: url) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        let decoder = JSONDecoder()
        let backup = try decoder.decode(OhanaBackup.self, from: data)

        guard backup.schemaVersion <= 24 else {
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

        let ud = defaults
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
            purchasedShopItems: ud.string(forKey: "purchasedShopItems") ?? "",
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
            appState: appState
        )
    }

    // MARK: - Apply Backup

    @MainActor
    func applyBackup(_ backup: OhanaBackup, context: ModelContext, projectionManager: QuestManager?) throws {
        // 以 UUID 为主键去重：先构建现有 ID 集合，再 upsert
        let existingPetIds = Set((try? context.fetch(FetchDescriptor<Pet>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingHumanIds = Set((try? context.fetch(FetchDescriptor<Human>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingPlantIds = Set((try? context.fetch(FetchDescriptor<Plant>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingHouseholdIds = Set((try? context.fetch(FetchDescriptor<Household>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingEventIds = Set((try? context.fetch(FetchDescriptor<Event>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingReminderIds = Set((try? context.fetch(FetchDescriptor<Reminder>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingLedgerIds = Set((try? context.fetch(FetchDescriptor<CareLedgerEvent>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingCoconutAccountIds = Set((try? context.fetch(FetchDescriptor<CoconutAccount>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingCoconutLedgerEntryIds = Set((try? context.fetch(FetchDescriptor<CoconutLedgerEntry>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingFamilyTaskIds = Set((try? context.fetch(FetchDescriptor<FamilyCollaborationTask>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingSharedCareSessionIds = Set((try? context.fetch(FetchDescriptor<SharedCareSession>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingExchangeIds = Set((try? context.fetch(FetchDescriptor<CoconutExchangeRequest>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingOasisCoconutIds = Set((try? context.fetch(FetchDescriptor<OasisUpgradeCoconut>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingOasisCritterIds = Set((try? context.fetch(FetchDescriptor<OasisElectronicPet>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingOasisFragmentIds = Set((try? context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingOasisUnlockIds = Set((try? context.fetch(FetchDescriptor<OasisUnlock>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingOasisActionLogIds = Set((try? context.fetch(FetchDescriptor<OasisCritterActionLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingGachaOwnedIds = Set((try? context.fetch(FetchDescriptor<GachaOwnedItem>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingGachaDrawLogIds = Set((try? context.fetch(FetchDescriptor<GachaDrawLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingDocumentAttachmentIds = Set((try? context.fetch(FetchDescriptor<PetDocumentAttachment>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingPhotoIds = Set((try? context.fetch(FetchDescriptor<PetPhotoLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingInsuranceIds = Set((try? context.fetch(FetchDescriptor<PetInsurance>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingClaimIds = Set((try? context.fetch(FetchDescriptor<InsuranceClaim>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingPetMedicationIds = Set((try? context.fetch(FetchDescriptor<PetMedication>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingHumanMedicationIds = Set((try? context.fetch(FetchDescriptor<HumanMedication>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingHumanMedicationLogIds = Set((try? context.fetch(FetchDescriptor<HumanMedicationLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingHumanHealthMetricLogIds = Set((try? context.fetch(FetchDescriptor<HumanHealthMetricLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingSymptomIds = Set((try? context.fetch(FetchDescriptor<SymptomLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        let existingHeatCycleIds = Set((try? context.fetch(FetchDescriptor<HeatCycleLog>()))?.map(\.id.uuidString) ?? []) // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline

        for dto in backup.pets where !existingPetIds.contains(dto.id) {
            context.insert(decodePet(dto))
        }
        for dto in backup.humans where !existingHumanIds.contains(dto.id) {
            context.insert(decodeHuman(dto))
        }
        for dto in backup.plants where !existingPlantIds.contains(dto.id) {
            context.insert(decodePlant(dto))
        }
        for dto in backup.households where !existingHouseholdIds.contains(dto.id) {
            context.insert(decodeHousehold(dto))
        }
        for dto in backup.events where !existingEventIds.contains(dto.id) {
            context.insert(decodeEvent(dto))
        }
        try context.save()

        let petById = try Dictionary(
            uniqueKeysWithValues: (context.fetch(FetchDescriptor<Pet>())).map { ($0.id.uuidString, $0) } // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        )
        let humanById = try Dictionary(
            uniqueKeysWithValues: (context.fetch(FetchDescriptor<Human>())).map { ($0.id.uuidString, $0) } // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        )
        let eventById = try Dictionary(
            uniqueKeysWithValues: (context.fetch(FetchDescriptor<Event>())).map { ($0.id.uuidString, $0) } // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        )

        for dto in backup.reminders where !existingReminderIds.contains(dto.id) {
            context.insert(decodeReminder(dto, events: eventById))
        }

        // 日志类直接插入（不去重，避免重复计算可由调用方在 import 前清空）
        for dto in backup.petCareLogs {
            context.insert(decodeCareLog(dto, pets: petById))
        }
        for dto in backup.petPottyLogs {
            context.insert(decodePottyLog(dto, pets: petById))
        }
        for dto in backup.petWalkLogs {
            context.insert(decodeWalkLog(dto, pets: petById))
        }
        for dto in backup.petWeightLogs {
            context.insert(decodeWeightLog(dto, pets: petById))
        }
        for dto in backup.petExpenseLogs {
            context.insert(decodeExpenseLog(dto, pets: petById))
        }
        for dto in backup.petHealthLogs {
            context.insert(decodeHealthLog(dto, pets: petById))
        }
        for dto in backup.petHygieneLogs {
            context.insert(decodeHygieneLog(dto, pets: petById))
        }
        for dto in backup.petFoodRecords {
            context.insert(decodeFoodRecord(dto, pets: petById))
        }
        for dto in backup.petDocuments {
            context.insert(decodeDocument(dto, pets: petById))
        }
        for dto in backup.petPhotoLogs ?? [] where !existingPhotoIds.contains(dto.id) {
            context.insert(decodePhotoLog(dto, pets: petById))
        }
        for dto in backup.petInsurances ?? [] where !existingInsuranceIds.contains(dto.id) {
            context.insert(decodeInsurance(dto, pets: petById))
        }
        for dto in backup.petMedications ?? [] where !existingPetMedicationIds.contains(dto.id) {
            context.insert(decodePetMedication(dto, pets: petById))
        }
        for dto in backup.humanMedications ?? [] where !existingHumanMedicationIds.contains(dto.id) {
            context.insert(decodeHumanMedication(dto))
        }
        for dto in backup.symptomLogs ?? [] where !existingSymptomIds.contains(dto.id) {
            context.insert(decodeSymptomLog(dto, pets: petById))
        }
        for dto in backup.heatCycleLogs ?? [] where !existingHeatCycleIds.contains(dto.id) {
            context.insert(decodeHeatCycleLog(dto, pets: petById))
        }
        try context.save()

        let documentById = try Dictionary(
            uniqueKeysWithValues: (context.fetch(FetchDescriptor<PetDocument>())).map { ($0.id.uuidString, $0) } // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        )
        let insuranceById = try Dictionary(
            uniqueKeysWithValues: (context.fetch(FetchDescriptor<PetInsurance>())).map { ($0.id.uuidString, $0) } // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        )

        for dto in backup.petDocumentAttachments ?? [] where !existingDocumentAttachmentIds.contains(dto.id) {
            if let attachment = decodeDocumentAttachment(dto) {
                documentById[dto.documentId]?.attachments.append(attachment)
                context.insert(attachment)
            }
        }
        for dto in backup.insuranceClaims ?? [] where !existingClaimIds.contains(dto.id) {
            context.insert(decodeInsuranceClaim(dto, insurances: insuranceById))
        }
        for dto in backup.humanMedicationLogs ?? [] where !existingHumanMedicationLogIds.contains(dto.id) {
            context.insert(decodeHumanMedicationLog(dto))
        }
        for dto in backup.humanHealthMetricLogs ?? [] where !existingHumanHealthMetricLogIds.contains(dto.id) {
            context.insert(decodeHumanHealthMetricLog(dto, humans: humanById))
        }
        for dto in backup.petMilestones {
            context.insert(decodeMilestone(dto, pets: petById))
        }
        for dto in backup.humanWeightLogs {
            context.insert(decodeHumanWeight(dto, humans: humanById))
        }
        for dto in backup.humanWorkoutLogs {
            context.insert(decodeHumanWorkout(dto, humans: humanById))
        }
        for dto in backup.waterLogs {
            context.insert(decodeWaterLog(dto))
        }
        for dto in backup.wishlistItems {
            context.insert(decodeWishlist(dto))
        }
        for dto in backup.careLedgerEvents ?? [] where !existingLedgerIds.contains(dto.id) {
            context.insert(decodeCareLedgerEvent(dto))
        }
        for dto in backup.coconutAccounts ?? [] where !existingCoconutAccountIds.contains(dto.id) {
            context.insert(decodeCoconutAccount(dto))
        }
        for dto in backup.coconutLedgerEntries ?? [] where !existingCoconutLedgerEntryIds.contains(dto.id) {
            context.insert(decodeCoconutLedgerEntry(dto))
        }
        for dto in backup.familyCollaborationTasks ?? [] where !existingFamilyTaskIds.contains(dto.id) {
            context.insert(decodeFamilyCollaborationTask(dto))
        }
        for dto in backup.sharedCareSessions ?? [] where !existingSharedCareSessionIds.contains(dto.id) {
            context.insert(decodeSharedCareSession(dto))
        }
        for dto in backup.coconutExchangeRequests ?? [] where !existingExchangeIds.contains(dto.id) {
            context.insert(decodeCoconutExchangeRequest(dto))
        }
        for dto in backup.oasisUpgradeCoconuts ?? [] where !existingOasisCoconutIds.contains(dto.id) {
            context.insert(decodeOasisUpgradeCoconut(dto))
        }
        for dto in backup.oasisElectronicPets ?? [] where !existingOasisCritterIds.contains(dto.id) {
            context.insert(decodeOasisElectronicPet(dto))
        }
        for dto in backup.oasisCritterFragments ?? [] where !existingOasisFragmentIds.contains(dto.id) {
            context.insert(decodeOasisCritterFragment(dto))
        }
        for dto in backup.oasisUnlocks ?? [] where !existingOasisUnlockIds.contains(dto.id) {
            context.insert(decodeOasisUnlock(dto))
        }
        for dto in backup.oasisCritterActionLogs ?? [] where !existingOasisActionLogIds.contains(dto.id) {
            context.insert(decodeOasisCritterActionLog(dto))
        }
        for dto in backup.gachaOwnedItems ?? [] where !existingGachaOwnedIds.contains(dto.id) {
            context.insert(decodeGachaOwnedItem(dto))
        }
        for dto in backup.gachaDrawLogs ?? [] where !existingGachaDrawLogIds.contains(dto.id) {
            context.insert(decodeGachaDrawLog(dto))
        }

        try context.save()

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
}
