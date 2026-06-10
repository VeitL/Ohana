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
nonisolated final class DataBackupManager: @unchecked Sendable {
    init() {}

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

            let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"
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
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(OhanaBackup.self, from: data)

        guard backup.schemaVersion <= 23 else {
            throw BackupError.unsupportedVersion(backup.schemaVersion)
        }

        try applyBackup(backup, context: context, projectionManager: projectionManager)
    }

    // MARK: - Build Backup

    func buildBackup(context: ModelContext) throws -> OhanaBackup {
        let pets        = try context.fetch(FetchDescriptor<Pet>())
        let humans      = try context.fetch(FetchDescriptor<Human>())
        let events      = try context.fetch(FetchDescriptor<Event>())
        let reminders   = try context.fetch(FetchDescriptor<Reminder>())
        let households  = try context.fetch(FetchDescriptor<Household>())
        let plants      = try context.fetch(FetchDescriptor<Plant>())
        let careLogs    = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs   = try context.fetch(FetchDescriptor<PetPottyLog>())
        let walkLogs    = try context.fetch(FetchDescriptor<PetWalkLog>())
        let weightLogs  = try context.fetch(FetchDescriptor<PetWeightLog>())
        let expLogs     = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let healthLogs  = try context.fetch(FetchDescriptor<PetHealthLog>())
        let hygLogs     = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let foodRecs    = try context.fetch(FetchDescriptor<PetFoodRecord>())
        let docs        = try context.fetch(FetchDescriptor<PetDocument>())
        let milestones  = try context.fetch(FetchDescriptor<PetMilestone>())
        let photos      = try context.fetch(FetchDescriptor<PetPhotoLog>())
        let insurances  = try context.fetch(FetchDescriptor<PetInsurance>())
        let claims      = try context.fetch(FetchDescriptor<InsuranceClaim>())
        let petMeds     = try context.fetch(FetchDescriptor<PetMedication>())
        let symptoms    = try context.fetch(FetchDescriptor<SymptomLog>())
        let heatCycles  = try context.fetch(FetchDescriptor<HeatCycleLog>())
        let hWeightLogs = try context.fetch(FetchDescriptor<HumanWeightLog>())
        let hWorkouts   = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let humanMeds   = try context.fetch(FetchDescriptor<HumanMedication>())
        let humanMedLogs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        let humanHealthMetricLogs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        let waterLogs   = try context.fetch(FetchDescriptor<WaterLog>())
        let wishlist    = try context.fetch(FetchDescriptor<WishlistItem>())
        let ledger      = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let coconutAccounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let coconutLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let familyTasks = try context.fetch(FetchDescriptor<FamilyCollaborationTask>())
        let sharedCareSessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let exchanges   = try context.fetch(FetchDescriptor<CoconutExchangeRequest>())
        let oasisUpgradeCoconuts = try context.fetch(FetchDescriptor<OasisUpgradeCoconut>())
        let oasisElectronicPets = try context.fetch(FetchDescriptor<OasisElectronicPet>())
        let oasisFragments = try context.fetch(FetchDescriptor<OasisCritterFragmentBalance>())
        let oasisUnlocks = try context.fetch(FetchDescriptor<OasisUnlock>())
        let oasisCritterActionLogs = try context.fetch(FetchDescriptor<OasisCritterActionLog>())
        let gachaOwnedItems = try context.fetch(FetchDescriptor<GachaOwnedItem>())
        let gachaDrawLogs = try context.fetch(FetchDescriptor<GachaDrawLog>())

        let ud = UserDefaults.standard
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
            coconutCount:           coconutAccounts.reduce(0) { $0 + $1.balance },
            coconutLogsJSON:        coconutLogsJSON,
            bountyTasksJSON:        ud.string(forKey: "bountyTasks") ?? "[]",
            purchasedShopItems:     ud.string(forKey: "purchasedShopItems") ?? "",
            selectedAppIcon:        ud.string(forKey: AppIconCatalog.selectedIconKey),
            gachaHistoryJSON:       ud.string(forKey: "gachaHistory") ?? "[]",
            celebratedMilestoneDays: ud.string(forKey: "celebratedMilestoneDays") ?? ""
        )

        return OhanaBackup(
            exportedAt:       iso.string(from: Date()),
            pets:             pets.map(encodePet),
            humans:           humans.map(encodeHuman),
            events:           events.map(encodeEvent),
            reminders:        reminders.map(encodeReminder),
            households:       households.map(encodeHousehold),
            plants:           plants.map(encodePlant),
            petCareLogs:      careLogs.map(encodeCareLog),
            petPottyLogs:     pottyLogs.map(encodePottyLog),
            petWalkLogs:      walkLogs.map(encodeWalkLog),
            petWeightLogs:    weightLogs.map(encodeWeightLog),
            petExpenseLogs:   expLogs.map(encodeExpenseLog),
            petHealthLogs:    healthLogs.map(encodeHealthLog),
            petHygieneLogs:   hygLogs.map(encodeHygieneLog),
            petFoodRecords:   foodRecs.map(encodeFoodRecord),
            petDocuments:     docs.map(encodeDocument),
            petDocumentAttachments: docs.flatMap(encodeDocumentAttachments),
            petMilestones:    milestones.map(encodeMilestone),
            petPhotoLogs:      photos.map(encodePhotoLog),
            petInsurances:     insurances.map(encodeInsurance),
            insuranceClaims:   claims.map(encodeInsuranceClaim),
            petMedications:    petMeds.map(encodePetMedication),
            symptomLogs:       symptoms.map(encodeSymptomLog),
            heatCycleLogs:     heatCycles.map(encodeHeatCycleLog),
            humanWeightLogs:  hWeightLogs.map(encodeHumanWeight),
            humanWorkoutLogs: hWorkouts.map(encodeHumanWorkout),
            humanMedications:  humanMeds.map(encodeHumanMedication),
            humanMedicationLogs: humanMedLogs.map(encodeHumanMedicationLog),
            humanHealthMetricLogs: humanHealthMetricLogs.map(encodeHumanHealthMetricLog),
            waterLogs:        waterLogs.map(encodeWaterLog),
            wishlistItems:    wishlist.map(encodeWishlist),
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
            appState:         appState
        )
    }

    // MARK: - Apply Backup

    @MainActor
    func applyBackup(_ backup: OhanaBackup, context: ModelContext, projectionManager: QuestManager?) throws {
        // 以 UUID 为主键去重：先构建现有 ID 集合，再 upsert
        let existingPetIds   = Set((try? context.fetch(FetchDescriptor<Pet>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanIds = Set((try? context.fetch(FetchDescriptor<Human>()))?.map { $0.id.uuidString } ?? [])
        let existingPlantIds = Set((try? context.fetch(FetchDescriptor<Plant>()))?.map { $0.id.uuidString } ?? [])
        let existingHouseholdIds = Set((try? context.fetch(FetchDescriptor<Household>()))?.map { $0.id.uuidString } ?? [])
        let existingEventIds = Set((try? context.fetch(FetchDescriptor<Event>()))?.map { $0.id.uuidString } ?? [])
        let existingReminderIds = Set((try? context.fetch(FetchDescriptor<Reminder>()))?.map { $0.id.uuidString } ?? [])
        let existingLedgerIds = Set((try? context.fetch(FetchDescriptor<CareLedgerEvent>()))?.map { $0.id.uuidString } ?? [])
        let existingCoconutAccountIds = Set((try? context.fetch(FetchDescriptor<CoconutAccount>()))?.map { $0.id.uuidString } ?? [])
        let existingCoconutLedgerEntryIds = Set((try? context.fetch(FetchDescriptor<CoconutLedgerEntry>()))?.map { $0.id.uuidString } ?? [])
        let existingFamilyTaskIds = Set((try? context.fetch(FetchDescriptor<FamilyCollaborationTask>()))?.map { $0.id.uuidString } ?? [])
        let existingSharedCareSessionIds = Set((try? context.fetch(FetchDescriptor<SharedCareSession>()))?.map { $0.id.uuidString } ?? [])
        let existingExchangeIds = Set((try? context.fetch(FetchDescriptor<CoconutExchangeRequest>()))?.map { $0.id.uuidString } ?? [])
        let existingOasisCoconutIds = Set((try? context.fetch(FetchDescriptor<OasisUpgradeCoconut>()))?.map { $0.id.uuidString } ?? [])
        let existingOasisCritterIds = Set((try? context.fetch(FetchDescriptor<OasisElectronicPet>()))?.map { $0.id.uuidString } ?? [])
        let existingOasisFragmentIds = Set((try? context.fetch(FetchDescriptor<OasisCritterFragmentBalance>()))?.map { $0.id.uuidString } ?? [])
        let existingOasisUnlockIds = Set((try? context.fetch(FetchDescriptor<OasisUnlock>()))?.map { $0.id.uuidString } ?? [])
        let existingOasisActionLogIds = Set((try? context.fetch(FetchDescriptor<OasisCritterActionLog>()))?.map { $0.id.uuidString } ?? [])
        let existingGachaOwnedIds = Set((try? context.fetch(FetchDescriptor<GachaOwnedItem>()))?.map { $0.id.uuidString } ?? [])
        let existingGachaDrawLogIds = Set((try? context.fetch(FetchDescriptor<GachaDrawLog>()))?.map { $0.id.uuidString } ?? [])
        let existingDocumentAttachmentIds = Set((try? context.fetch(FetchDescriptor<PetDocumentAttachment>()))?.map { $0.id.uuidString } ?? [])
        let existingPhotoIds = Set((try? context.fetch(FetchDescriptor<PetPhotoLog>()))?.map { $0.id.uuidString } ?? [])
        let existingInsuranceIds = Set((try? context.fetch(FetchDescriptor<PetInsurance>()))?.map { $0.id.uuidString } ?? [])
        let existingClaimIds = Set((try? context.fetch(FetchDescriptor<InsuranceClaim>()))?.map { $0.id.uuidString } ?? [])
        let existingPetMedicationIds = Set((try? context.fetch(FetchDescriptor<PetMedication>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanMedicationIds = Set((try? context.fetch(FetchDescriptor<HumanMedication>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanMedicationLogIds = Set((try? context.fetch(FetchDescriptor<HumanMedicationLog>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanHealthMetricLogIds = Set((try? context.fetch(FetchDescriptor<HumanHealthMetricLog>()))?.map { $0.id.uuidString } ?? [])
        let existingSymptomIds = Set((try? context.fetch(FetchDescriptor<SymptomLog>()))?.map { $0.id.uuidString } ?? [])
        let existingHeatCycleIds = Set((try? context.fetch(FetchDescriptor<HeatCycleLog>()))?.map { $0.id.uuidString } ?? [])

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

        let petById = Dictionary(
            uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Pet>())).map { ($0.id.uuidString, $0) }
        )
        let humanById = Dictionary(
            uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Human>())).map { ($0.id.uuidString, $0) }
        )
        let eventById = Dictionary(
            uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Event>())).map { ($0.id.uuidString, $0) }
        )

        for dto in backup.reminders where !existingReminderIds.contains(dto.id) {
            context.insert(decodeReminder(dto, events: eventById))
        }

        // 日志类直接插入（不去重，避免重复计算可由调用方在 import 前清空）
        for dto in backup.petCareLogs   { context.insert(decodeCareLog(dto, pets: petById)) }
        for dto in backup.petPottyLogs  { context.insert(decodePottyLog(dto, pets: petById)) }
        for dto in backup.petWalkLogs   { context.insert(decodeWalkLog(dto, pets: petById)) }
        for dto in backup.petWeightLogs { context.insert(decodeWeightLog(dto, pets: petById)) }
        for dto in backup.petExpenseLogs { context.insert(decodeExpenseLog(dto, pets: petById)) }
        for dto in backup.petHealthLogs { context.insert(decodeHealthLog(dto, pets: petById)) }
        for dto in backup.petHygieneLogs { context.insert(decodeHygieneLog(dto, pets: petById)) }
        for dto in backup.petFoodRecords { context.insert(decodeFoodRecord(dto, pets: petById)) }
        for dto in backup.petDocuments  { context.insert(decodeDocument(dto, pets: petById)) }
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

        let documentById = Dictionary(
            uniqueKeysWithValues: (try context.fetch(FetchDescriptor<PetDocument>())).map { ($0.id.uuidString, $0) }
        )
        let insuranceById = Dictionary(
            uniqueKeysWithValues: (try context.fetch(FetchDescriptor<PetInsurance>())).map { ($0.id.uuidString, $0) }
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
        for dto in backup.petMilestones { context.insert(decodeMilestone(dto, pets: petById)) }
        for dto in backup.humanWeightLogs { context.insert(decodeHumanWeight(dto, humans: humanById)) }
        for dto in backup.humanWorkoutLogs { context.insert(decodeHumanWorkout(dto, humans: humanById)) }
        for dto in backup.waterLogs     { context.insert(decodeWaterLog(dto)) }
        for dto in backup.wishlistItems { context.insert(decodeWishlist(dto)) }
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
        let ud = UserDefaults.standard
        let s = backup.appState
        let isLegacyCoconutBackup = backup.coconutAccounts?.isEmpty != false
        if !s.bountyTasksJSON.isEmpty    { ud.set(s.bountyTasksJSON,    forKey: "bountyTasks") }
        if !s.purchasedShopItems.isEmpty { ud.set(s.purchasedShopItems, forKey: "purchasedShopItems") }
        if let selectedAppIcon = s.selectedAppIcon, !selectedAppIcon.isEmpty {
            ud.set(selectedAppIcon, forKey: AppIconCatalog.selectedIconKey)
        }
        if !s.gachaHistoryJSON.isEmpty   { ud.set(s.gachaHistoryJSON,   forKey: "gachaHistory") }
        if !s.celebratedMilestoneDays.isEmpty { ud.set(s.celebratedMilestoneDays, forKey: "celebratedMilestoneDays") }
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
