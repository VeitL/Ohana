//
//  DataBackupManager.swift
//  Ohana
//
//  TASK 1: 全量 JSON 数据备份与恢复
//  覆盖 21 个 SwiftData 模型 + 关键 UserDefaults appState
//

import Foundation
import SwiftData

// MARK: - 顶层备份结构
nonisolated struct OhanaBackup: Codable {
    var schemaVersion: Int = 22
    var exportedAt: String
    // 核心实体
    var pets: [PetBackup]
    var humans: [HumanBackup]
    var events: [EventBackup]
    var reminders: [ReminderBackup]
    var households: [HouseholdBackup]
    var plants: [PlantBackup]
    // 日志
    var petCareLogs: [PetCareLogBackup]
    var petPottyLogs: [PetPottyLogBackup]
    var petWalkLogs: [PetWalkLogBackup]
    var petWeightLogs: [PetWeightLogBackup]
    var petExpenseLogs: [PetExpenseLogBackup]
    var petHealthLogs: [PetHealthLogBackup]
    var petHygieneLogs: [PetHygieneLogBackup]
    var petFoodRecords: [PetFoodRecordBackup]
    var petDocuments: [PetDocumentBackup]
    var petDocumentAttachments: [PetDocumentAttachmentBackup]?
    var petMilestones: [PetMilestoneBackup]
    var petPhotoLogs: [PetPhotoLogBackup]?
    var petInsurances: [PetInsuranceBackup]?
    var insuranceClaims: [InsuranceClaimBackup]?
    var petMedications: [PetMedicationBackup]?
    var symptomLogs: [SymptomLogBackup]?
    var heatCycleLogs: [HeatCycleLogBackup]?
    var humanWeightLogs: [HumanWeightLogBackup]
    var humanWorkoutLogs: [HumanWorkoutLogBackup]
    var humanMedications: [HumanMedicationBackup]?
    var humanMedicationLogs: [HumanMedicationLogBackup]?
    var humanHealthMetricLogs: [HumanHealthMetricLogBackup]?
    var waterLogs: [WaterLogBackup]
    var wishlistItems: [WishlistItemBackup]
    var careLedgerEvents: [CareLedgerEventBackup]?
    var familyCollaborationTasks: [FamilyCollaborationTaskBackup]?
    var sharedCareSessions: [SharedCareSessionBackup]?
    var coconutExchangeRequests: [CoconutExchangeRequestBackup]?
    var oasisUpgradeCoconuts: [OasisUpgradeCoconutBackup]?
    var oasisElectronicPets: [OasisElectronicPetBackup]?
    var oasisCritterFragments: [OasisCritterFragmentBackup]?
    var oasisUnlocks: [OasisUnlockBackup]?
    var oasisCritterActionLogs: [OasisCritterActionLogBackup]?
    var gachaOwnedItems: [GachaOwnedItemBackup]?
    var gachaDrawLogs: [GachaDrawLogBackup]?
    // App 状态
    var appState: AppStateBackup
}

// MARK: - AppState
nonisolated struct AppStateBackup: Codable {
    var coconutCount: Int
    var coconutLogsJSON: String
    var bountyTasksJSON: String
    var purchasedShopItems: String
    var selectedAppIcon: String?
    var gachaHistoryJSON: String
    var celebratedMilestoneDays: String
}

// MARK: - 实体 Backup DTOs
nonisolated struct PetBackup: Codable {
    var id: String; var name: String; var species: String; var breed: String
    var birthday: String?; var gender: String; var isNeutered: Bool
    var avatarEmoji: String; var microchipID: String; var vetContact: String
    var allergies: String; var passportNumber: String; var passportExpiryDate: String?
    var formerName: String; var lineageInfo: String; var themeColorHex: String
    var homeDate: String?; var birthCountry: String; var birthCity: String
    var foodBrand: String; var restockDate: String?; var restockWeight: Double
    var dailyPortionGrams: Double; var mainFoodKindRaw: String?; var foodPrice: Double; var isShared: Bool
    var createdAt: String; var notes: String; var coatColor: String; var eyeColor: String
    var currentStreak: Int; var lastCheckInDate: String?
    var foodTrackingModeRaw: String; var casualOpenDate: String?; var casualDurationDays: Int
    var foodReminderEnabled: Bool?; var foodReminderAdvanceDays: Int?
    var coconutBalance: Int; var passedAwayDate: String?
    var cardStyleRaw: String?
    var cardPopoutImageBase64: String?
    var cardPopoutSourceRaw: String?
    /// ArkSchemaV26：性格标签 id，逗号分隔；旧备份缺省为 nil
    var personalityTagsRaw: String?
}

nonisolated struct HumanBackup: Codable {
    var id: String; var name: String; var birthday: String?; var bloodType: String
    var avatarEmoji: String; var role: String; var appleUserIdentifier: String
    var notes: String; var createdAt: String; var nationality: String; var city: String
    var coconutBalance: Int; var shouldShowOnHome: Bool
    /// ArkSchemaV35：旧备份缺省为 nil
    var mbti: String?
    var privateFieldsRaw: String?
    var themeColorHex: String?
    var heightCm: Double?
    var avatarImageBase64: String?
    var passedAwayDate: String?
    // Intentionally excluded from backups: pinHash, pinSalt, pinFailedAttempts, pinLockedUntil.
}

nonisolated struct EventBackup: Codable {
    var id: String; var title: String; var startDate: String; var endDate: String?
    var isAllDay: Bool; var eventType: String
    var relatedEntityId: String; var relatedEntityType: String
    var recurrenceDays: Int; var recurrenceEndDate: String?
    var isCompleted: Bool; var createdAt: String
    var completedOccurrences: [String]?
    var assigneeId: String?
}

nonisolated struct ReminderBackup: Codable {
    var id: String; var scheduledAt: String; var status: String
    var notificationId: String; var eventId: String?
    var completedAt: String?
    var completedBy: String?
    var createdAt: String?
}

nonisolated struct GachaOwnedItemBackup: Codable {
    var id: String
    var ownerHumanId: String
    var seriesId: String
    var itemId: String
    var rarityRaw: String
    var isHidden: Bool
    var ownedCount: Int
    var firstObtainedAt: String
    var latestObtainedAt: String
    var createdAt: String
}

nonisolated struct GachaDrawLogBackup: Codable {
    var id: String
    var ownerHumanId: String
    var ownerName: String
    var seriesId: String
    var itemId: String
    var rarityRaw: String
    var isHidden: Bool
    var isNew: Bool
    var outcomeKindRaw: String?
    var instantResultId: String?
    var instantTitleZh: String?
    var instantTitleEn: String?
    var instantTitleDe: String?
    var instantDetailZh: String?
    var instantDetailEn: String?
    var instantDetailDe: String?
    var instantSymbol: String?
    var instantCoconutDelta: Int?
    var costCoconuts: Int
    var dailySequence: Int
    var drawDate: String
    var createdAt: String
}

nonisolated struct HouseholdBackup: Codable {
    var id: String; var name: String; var createdAt: String; var totalProsperity: Int
}

nonisolated struct PlantBackup: Codable {
    var id: String; var name: String; var species: String; var avatarEmoji: String
    var location: String; var notes: String; var createdAt: String
    var lastWateredDate: String?; var wateringIntervalDays: Int
    var lastFertilizedDate: String?; var fertilizingIntervalDays: Int
    var themeColorHex: String?
}

nonisolated struct PetCareLogBackup: Codable {
    var id: String; var date: String; var type: String
    var amountGrams: Double; var amountMl: Double; var note: String
    var foodKindRaw: String?; var treatKindRaw: String?
    var sharedSessionId: String?; var executorId: String?; var petId: String?
}

nonisolated struct PetPottyLogBackup: Codable {
    var id: String; var date: String; var type: String
    var executorId: String?; var petId: String?
    var latitude: Double?; var longitude: Double?
    var locationAccuracyMeters: Double?; var walkLogId: String?
    var sharedSessionId: String?
}

nonisolated struct SharedCareSessionBackup: Codable {
    var id: String
    var date: String
    var actionKindRaw: String
    var executorId: String?
    var sourcePetId: String
    var targetPetIdsRaw: String
    var speciesRaw: String
    var totalAmountGrams: Double
    var totalAmountMl: Double
    var totalExpenseAmount: Double?
    var expenseCategoryRaw: String?
    var currencyCode: String?
    var allocationModeRaw: String
    var foodKindRaw: String
    var stockOwnerPetId: String
    var primaryLegacyModelName: String?
    var primaryLegacyModelId: String?
    var note: String
    var createdAt: String
}

nonisolated struct PetWalkLogBackup: Codable {
    var id: String; var startDate: String; var endDate: String?
    var distanceMeters: Double; var coconutsEarned: Int
    var executorId: String?; var petId: String?
    var sharedSessionId: String?
}

nonisolated struct PetWeightLogBackup: Codable {
    var id: String; var date: String; var weight: Double; var petId: String?
    var executorId: String?
}

nonisolated struct PetExpenseLogBackup: Codable {
    var id: String; var date: String; var amount: Double
    var category: String; var note: String; var petId: String?
    var executorId: String?
    var sharedSessionId: String?
}

nonisolated struct PetHealthLogBackup: Codable {
    var id: String; var date: String; var type: String; var note: String
    var expirationDate: String?; var vetName: String; var cost: Double; var petId: String?
    var executorId: String?
}

nonisolated struct PetHygieneLogBackup: Codable {
    var id: String; var date: String; var type: String; var petId: String?
    var executorId: String?
}

nonisolated struct PetFoodRecordBackup: Codable {
    var id: String; var date: String; var brand: String
    var dailyGrams: Double; var totalGrams: Double?; var foodKindRaw: String?; var petId: String?
    var purchaseDate: String?; var remainingCorrectionGrams: Double?; var remainingCorrectionDate: String?
    var notes: String?; var executorId: String?
}

nonisolated struct PetDocumentBackup: Codable {
    var id: String; var title: String; var categoryRaw: String
    var expiryDate: String?; var petId: String?
    var issueDate: String?
    var issuingAuthority: String?
    var notes: String?
    var reminderDate: String?
    var cost: Double?
    var attachmentBase64: String?
    var attachmentFilename: String?
}

nonisolated struct PetDocumentAttachmentBackup: Codable {
    var id: String; var documentId: String
    var dataBase64: String; var filename: String; var isImage: Bool
}

nonisolated struct PetMilestoneBackup: Codable {
    var id: String; var date: String; var title: String; var emoji: String; var notes: String; var petId: String?
}

nonisolated struct HumanWeightLogBackup: Codable {
    var id: String; var date: String; var weight: Double; var humanId: String?
    var executorId: String?
}

nonisolated struct HumanWorkoutLogBackup: Codable {
    var id: String; var date: String; var typeRaw: String
    var durationMinutes: Int; var notes: String; var humanId: String?
}

nonisolated struct PetPhotoLogBackup: Codable {
    var id: String; var date: String; var note: String; var createdAt: String
    var imageBase64: String; var petId: String?
    var locationLatitude: Double; var locationLongitude: Double; var locationPlacename: String
}

nonisolated struct PetInsuranceBackup: Codable {
    var id: String; var companyName: String; var policyNumber: String; var productName: String
    var annualPremium: Double; var coverageAmount: Double
    var startDate: String; var renewalDate: String
    var notes: String; var isActive: Bool; var createdAt: String
    var paymentFrequencyRaw: String; var paymentDayOfMonth: Int
    var showInCalendar: Bool; var otherFeeAmount: Double; var otherFeeNote: String
    var firstPremiumPaymentDate: String?; var petId: String?
}

nonisolated struct InsuranceClaimBackup: Codable {
    var id: String; var insuranceId: String?
    var claimDate: String; var incidentDate: String
    var totalExpense: Double; var claimedAmount: Double; var approvedAmount: Double
    var statusRaw: String; var note: String; var relatedExpenseLogId: String?
    var approvedAt: String?; var createdAt: String
}

nonisolated struct PetMedicationBackup: Codable {
    var id: String; var name: String; var dosage: String; var frequencyRaw: String
    var customFrequencyNote: String; var startDate: String; var endDate: String?
    var colorHex: String; var notes: String; var isActive: Bool; var createdAt: String
    var petId: String?
}

nonisolated struct HumanMedicationBackup: Codable {
    var id: String; var humanId: String; var name: String; var dosage: String
    var frequencyRaw: String; var customFrequencyNote: String
    var firstDoseTime: String; var startDate: String; var endDate: String?
    var colorHex: String; var notes: String; var isActive: Bool; var createdAt: String
}

nonisolated struct HumanMedicationLogBackup: Codable {
    var id: String; var humanId: String; var medicationId: String
    var scheduledTime: String; var recordedTime: String?
    var statusRaw: String; var createdAt: String
}

nonisolated struct HumanHealthMetricLogBackup: Codable {
    var id: String
    var metricKey: String
    var unitCode: String
    var value: Double
    var date: String
    var notes: String
    var humanId: String?
    var createdAt: String
}

nonisolated struct SymptomLogBackup: Codable {
    var id: String; var date: String; var categoryRaw: String
    var symptomName: String; var severityRaw: Int; var note: String
    var photoBase64: String?; var petId: String?
}

nonisolated struct HeatCycleLogBackup: Codable {
    var id: String; var startDate: String; var endDate: String?
    var statusRaw: String; var note: String; var isMated: Bool
    var expectedDeliveryDate: String?; var petId: String?
}

nonisolated struct WaterLogBackup: Codable {
    var id: String; var date: String; var amountMl: Double; var note: String
}

nonisolated struct WishlistItemBackup: Codable {
    var id: String; var title: String; var cost: Int; var creatorId: String
    var isRedeemed: Bool; var createdAt: String
}

nonisolated struct CareLedgerEventBackup: Codable {
    var id: String
    var occurredAt: String
    var actorKind: String
    var actorId: String?
    var subjectKind: String
    var subjectId: String?
    var eventKind: String
    var actionType: String
    var amountValue: Double
    var amountUnit: String
    var note: String
    var source: String
    var sourceEventId: String?
    var sourceReminderId: String?
    var legacyModelName: String?
    var legacyModelId: String?
    var coconutDelta: Int
    var rewardLogId: String?
    var privacyFieldRaw: String?
    var metadataJSON: String
    var createdAt: String
}

nonisolated struct FamilyCollaborationTaskBackup: Codable {
    var id: String
    var title: String
    var note: String
    var kindRaw: String
    var statusRaw: String
    var relatedPetId: String?
    var relatedEventId: String?
    var relatedReminderId: String?
    var createdById: String
    var createdByName: String
    var assignedToId: String?
    var assignedToName: String?
    var claimedById: String?
    var claimedByName: String?
    var completedById: String?
    var completedByName: String?
    var rewardCoconuts: Int
    var dueAt: String?
    var completedAt: String?
    var createdAt: String
    var updatedAt: String
    var emoji: String
}

nonisolated struct CoconutExchangeRequestBackup: Codable {
    var id: String
    var senderId: String
    var senderName: String
    var receiverId: String
    var receiverName: String
    var coconutCost: Int
    var currencyCode: String
    var localAmount: Double
    var statusRaw: String
    var createdAt: String
    var confirmedAt: String?
    var cancelledAt: String?
    var updatedAt: String
    var note: String
}

nonisolated struct OasisUpgradeCoconutBackup: Codable {
    var id: String
    var level: Int
    var createdAt: String
    var openedAt: String?
    var rewardKindRaw: String
    var rewardCatalogId: String
    var guaranteedCritterId: String?
    var coconutAmount: Int
    var treeEnergyAmount: Int
    var fragmentAmount: Int
    var decorUnlockId: String?
    var storyStyleUnlockId: String?
    var temporaryEffectId: String?
    var titleZh: String
    var titleEn: String
    var titleDe: String
    var descriptionZh: String
    var descriptionEn: String
    var descriptionDe: String
}

nonisolated struct OasisElectronicPetBackup: Codable {
    var id: String
    var catalogId: String
    var nameZh: String
    var nameEn: String
    var nameDe: String
    var emoji: String
    var rarityRaw: String
    var nickname: String
    var level: Int
    var starLevel: Int
    var xp: Int
    var hunger: Int
    var mood: Int
    var health: Int?
    var bond: Int
    var appearanceStage: Int
    var isFeaturedOnOasis: Bool?
    var habitatSlot: Int?
    var equippedDecorId: String?
    var favoriteItemId: String?
    var personalityRaw: String?
    var featuredPoseRaw: String?
    var sourceLevel: Int
    var obtainedAt: String
    var lastInteractionAt: String
    var lastStateRefreshAt: String?
    var lifeStateRaw: String?
    var deathReasonRaw: String?
    var riskStartedAt: String?
    var criticalStartedAt: String?
    var diedAt: String?
    var lastGentlePromptAt: String?
    var isArchived: Bool
}

nonisolated struct OasisCritterFragmentBackup: Codable {
    var id: String
    var catalogId: String
    var amount: Int
    var updatedAt: String
}

nonisolated struct OasisUnlockBackup: Codable {
    var id: String
    var unlockId: String
    var unlockKindRaw: String
    var sourceLevel: Int
    var createdAt: String
    var metadataJSON: String
}

nonisolated struct OasisCritterActionLogBackup: Codable {
    var id: String
    var critterId: String?
    var critterCatalogId: String
    var actionRaw: String
    var createdAt: String
    var coconutDelta: Int
    var fragmentDelta: Int
    var xpDelta: Int
    var sourceLevel: Int
    var noteZh: String
    var noteEn: String
    var noteDe: String
}

// MARK: - DataBackupManager
//
// Isolation-agnostic: the build/encode/apply logic only does ModelContext
// reads/writes plus pure value-type mapping, so the type is not @MainActor.
// Export runs on a background @ModelActor (see DataBackupActor) so the
// full-table fetch + JSON encode never blocks the main thread. Import keeps the
// main context (see @MainActor on importJSON) so SwiftData @Query-backed UI
// refreshes immediately after a restore.
nonisolated final class DataBackupManager: @unchecked Sendable {
    static let shared = DataBackupManager()
    private init() {}

    private let iso = ISO8601DateFormatter()

    // MARK: - Export

    /// Filename prefix for exported backups in the temporary directory.
    private static let backupFilePrefix = "ohana_backup_"
    private static let staleExportAge: TimeInterval = 60 * 60

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
    func importJSON(from url: URL, context: ModelContext) async throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(OhanaBackup.self, from: data)

        guard backup.schemaVersion <= 22 else {
            throw BackupError.unsupportedVersion(backup.schemaVersion)
        }

        try applyBackup(backup, context: context)
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
        let coconutLogsJSON: String = {
            if let data = ud.data(forKey: "quest_coconutLogs"),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return ud.string(forKey: "coconutLogs") ?? "[]"
        }()
        let appState = AppStateBackup(
            coconutCount:           ud.integer(forKey: "quest_coconutCount"),
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

    private func applyBackup(_ backup: OhanaBackup, context: ModelContext) throws {
        // 以 UUID 为主键去重：先构建现有 ID 集合，再 upsert
        let existingPetIds   = Set((try? context.fetch(FetchDescriptor<Pet>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanIds = Set((try? context.fetch(FetchDescriptor<Human>()))?.map { $0.id.uuidString } ?? [])
        let existingPlantIds = Set((try? context.fetch(FetchDescriptor<Plant>()))?.map { $0.id.uuidString } ?? [])
        let existingHouseholdIds = Set((try? context.fetch(FetchDescriptor<Household>()))?.map { $0.id.uuidString } ?? [])
        let existingEventIds = Set((try? context.fetch(FetchDescriptor<Event>()))?.map { $0.id.uuidString } ?? [])
        let existingReminderIds = Set((try? context.fetch(FetchDescriptor<Reminder>()))?.map { $0.id.uuidString } ?? [])
        let existingLedgerIds = Set((try? context.fetch(FetchDescriptor<CareLedgerEvent>()))?.map { $0.id.uuidString } ?? [])
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
        if s.coconutCount > 0 {
            ud.set(s.coconutCount, forKey: "quest_coconutCount")
            ud.set(s.coconutCount, forKey: "coconutCount")
        }
        if !s.coconutLogsJSON.isEmpty {
            ud.set(Data(s.coconutLogsJSON.utf8), forKey: "quest_coconutLogs")
            ud.set(s.coconutLogsJSON, forKey: "coconutLogs")
        }
        if !s.bountyTasksJSON.isEmpty    { ud.set(s.bountyTasksJSON,    forKey: "bountyTasks") }
        if !s.purchasedShopItems.isEmpty { ud.set(s.purchasedShopItems, forKey: "purchasedShopItems") }
        if let selectedAppIcon = s.selectedAppIcon, !selectedAppIcon.isEmpty {
            ud.set(selectedAppIcon, forKey: AppIconCatalog.selectedIconKey)
        }
        if !s.gachaHistoryJSON.isEmpty   { ud.set(s.gachaHistoryJSON,   forKey: "gachaHistory") }
        if !s.celebratedMilestoneDays.isEmpty { ud.set(s.celebratedMilestoneDays, forKey: "celebratedMilestoneDays") }
    }

    // MARK: - Encode helpers

    private func d(_ date: Date?) -> String? { date.map { iso.string(from: $0) } }
    private func d(_ date: Date) -> String   { iso.string(from: date) }

    private func encodePet(_ p: Pet) -> PetBackup {
        PetBackup(
            id: p.id.uuidString, name: p.name, species: p.species, breed: p.breed,
            birthday: d(p.birthday), gender: p.gender, isNeutered: p.isNeutered,
            avatarEmoji: p.avatarEmoji, microchipID: p.microchipID, vetContact: p.vetContact,
            allergies: p.allergies, passportNumber: p.passportNumber,
            passportExpiryDate: d(p.passportExpiryDate), formerName: p.formerName,
            lineageInfo: p.lineageInfo, themeColorHex: p.themeColorHex,
            homeDate: d(p.homeDate), birthCountry: p.birthCountry, birthCity: p.birthCity,
            foodBrand: p.foodBrand, restockDate: d(p.restockDate),
            restockWeight: p.restockWeight, dailyPortionGrams: p.dailyPortionGrams,
            mainFoodKindRaw: p.mainFoodKindRaw,
            foodPrice: p.foodPrice, isShared: p.isShared,
            createdAt: d(p.createdAt), notes: p.notes, coatColor: p.coatColor,
            eyeColor: p.eyeColor, currentStreak: p.currentStreak,
            lastCheckInDate: d(p.lastCheckInDate),
            foodTrackingModeRaw: p.foodTrackingModeRaw, casualOpenDate: d(p.casualOpenDate),
            casualDurationDays: p.casualDurationDays,
            foodReminderEnabled: p.foodReminderEnabled,
            foodReminderAdvanceDays: p.foodReminderAdvanceDays,
            coconutBalance: p.coconutBalance,
            passedAwayDate: d(p.passedAwayDate),
            cardStyleRaw: p.cardStyleRaw.isEmpty ? nil : p.cardStyleRaw,
            cardPopoutImageBase64: p.cardPopoutImageData?.base64EncodedString(),
            cardPopoutSourceRaw: (p.cardPopoutSourceRaw ?? "").isEmpty ? nil : p.cardPopoutSourceRaw,
            personalityTagsRaw: p.personalityTagsRaw.isEmpty ? nil : p.personalityTagsRaw
        )
    }

    private func encodeHuman(_ h: Human) -> HumanBackup {
        HumanBackup(
            id: h.id.uuidString, name: h.name, birthday: d(h.birthday),
            bloodType: h.bloodType, avatarEmoji: h.avatarEmoji, role: h.role,
            appleUserIdentifier: h.appleUserIdentifier, notes: h.notes,
            createdAt: d(h.createdAt), nationality: h.nationality, city: h.city,
            coconutBalance: h.coconutBalance, shouldShowOnHome: h.shouldShowOnHome,
            mbti: h.mbti.isEmpty ? nil : h.mbti,
            privateFieldsRaw: h.privateFieldsRaw.isEmpty ? nil : h.privateFieldsRaw,
            themeColorHex: h.themeColorHex,
            heightCm: h.heightCm,
            avatarImageBase64: h.avatarImageData?.base64EncodedString(),
            passedAwayDate: d(h.passedAwayDate)
        )
    }

    private func encodeEvent(_ e: Event) -> EventBackup {
        EventBackup(
            id: e.id.uuidString, title: e.title, startDate: d(e.startDate),
            endDate: d(e.endDate), isAllDay: e.isAllDay, eventType: e.eventType,
            relatedEntityId: e.relatedEntityId, relatedEntityType: e.relatedEntityType,
            recurrenceDays: e.recurrenceDays, recurrenceEndDate: d(e.recurrenceEndDate),
            isCompleted: e.isCompleted, createdAt: d(e.createdAt),
            completedOccurrences: e.completedOccurrences,
            assigneeId: e.assigneeId
        )
    }

    private func encodeReminder(_ r: Reminder) -> ReminderBackup {
        ReminderBackup(
            id: r.id.uuidString, scheduledAt: d(r.scheduledAt),
            status: r.status, notificationId: r.notificationId,
            eventId: r.event?.id.uuidString,
            completedAt: d(r.completedAt),
            completedBy: r.completedBy.isEmpty ? nil : r.completedBy,
            createdAt: d(r.createdAt)
        )
    }

    private func encodeHousehold(_ h: Household) -> HouseholdBackup {
        HouseholdBackup(id: h.id.uuidString, name: h.name,
                        createdAt: d(h.createdAt), totalProsperity: h.totalProsperity)
    }

    private func encodePlant(_ p: Plant) -> PlantBackup {
        PlantBackup(
            id: p.id.uuidString, name: p.name, species: p.species, avatarEmoji: p.avatarEmoji,
            location: p.location, notes: p.notes, createdAt: d(p.createdAt),
            lastWateredDate: d(p.lastWateredDate), wateringIntervalDays: p.wateringIntervalDays,
            lastFertilizedDate: d(p.lastFertilizedDate), fertilizingIntervalDays: p.fertilizingIntervalDays,
            themeColorHex: p.themeColorHex
        )
    }

    private func decodePlant(_ dto: PlantBackup) -> Plant {
        let p = Plant(
            name: dto.name, species: dto.species, location: dto.location,
            avatarEmoji: dto.avatarEmoji,
            wateringIntervalDays: dto.wateringIntervalDays,
            fertilizingIntervalDays: dto.fertilizingIntervalDays,
            themeColorHex: dto.themeColorHex ?? "4CAF50"
        )
        p.id = UUID(uuidString: dto.id) ?? UUID()
        p.notes = dto.notes
        p.createdAt = iso.date(from: dto.createdAt) ?? Date()
        p.lastWateredDate = dto.lastWateredDate.flatMap { iso.date(from: $0) }
        p.lastFertilizedDate = dto.lastFertilizedDate.flatMap { iso.date(from: $0) }
        return p
    }

    private func encodeCareLog(_ l: PetCareLog) -> PetCareLogBackup {
        PetCareLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            amountGrams: l.amountGrams, amountMl: l.amountMl, note: l.note,
            foodKindRaw: l.foodKindRaw, treatKindRaw: l.treatKindRaw,
            sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId,
            executorId: l.executorId, petId: l.pet?.id.uuidString)
    }

    private func encodePottyLog(_ l: PetPottyLog) -> PetPottyLogBackup {
        PetPottyLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            executorId: l.executorId, petId: l.pet?.id.uuidString,
            latitude: l.latitude, longitude: l.longitude,
            locationAccuracyMeters: l.locationAccuracyMeters, walkLogId: l.walkLogId,
            sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId)
    }

    private func encodeSharedCareSession(_ session: SharedCareSession) -> SharedCareSessionBackup {
        SharedCareSessionBackup(
            id: session.id.uuidString,
            date: d(session.date),
            actionKindRaw: session.actionKindRaw,
            executorId: session.executorId,
            sourcePetId: session.sourcePetId,
            targetPetIdsRaw: session.targetPetIdsRaw,
            speciesRaw: session.speciesRaw,
            totalAmountGrams: session.totalAmountGrams,
            totalAmountMl: session.totalAmountMl,
            totalExpenseAmount: session.totalExpenseAmount,
            expenseCategoryRaw: session.expenseCategoryRaw,
            currencyCode: session.currencyCode.isEmpty ? nil : session.currencyCode,
            allocationModeRaw: session.allocationModeRaw,
            foodKindRaw: session.foodKindRaw,
            stockOwnerPetId: session.stockOwnerPetId,
            primaryLegacyModelName: session.primaryLegacyModelName.isEmpty ? nil : session.primaryLegacyModelName,
            primaryLegacyModelId: session.primaryLegacyModelId.isEmpty ? nil : session.primaryLegacyModelId,
            note: session.note,
            createdAt: d(session.createdAt)
        )
    }

    private func encodeWalkLog(_ l: PetWalkLog) -> PetWalkLogBackup {
        PetWalkLogBackup(id: l.id.uuidString, startDate: d(l.startDate),
            endDate: d(l.endDate), distanceMeters: l.distanceMeters,
            coconutsEarned: l.coconutsEarned,
            executorId: l.executorId, petId: l.pet?.id.uuidString,
            sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId)
    }

    private func encodeWeightLog(_ l: PetWeightLog) -> PetWeightLogBackup {
        PetWeightLogBackup(id: l.id.uuidString, date: d(l.date),
            weight: l.weight, petId: l.pet?.id.uuidString,
            executorId: l.executorId)
    }

    private func encodeExpenseLog(_ l: PetExpenseLog) -> PetExpenseLogBackup {
        PetExpenseLogBackup(id: l.id.uuidString, date: d(l.date),
            amount: l.amount, category: l.category, note: l.note,
            petId: l.pet?.id.uuidString,
            executorId: l.executorId,
            sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId)
    }

    private func encodeHealthLog(_ l: PetHealthLog) -> PetHealthLogBackup {
        PetHealthLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            note: l.note, expirationDate: d(l.expirationDate), vetName: l.vetName,
            cost: l.cost, petId: l.pet?.id.uuidString,
            executorId: l.executorId)
    }

    private func encodeHygieneLog(_ l: PetHygieneLog) -> PetHygieneLogBackup {
        PetHygieneLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            petId: l.pet?.id.uuidString,
            executorId: l.executorId)
    }

    private func encodeFoodRecord(_ r: PetFoodRecord) -> PetFoodRecordBackup {
        PetFoodRecordBackup(id: r.id.uuidString, date: d(r.startDate), brand: r.brand,
            dailyGrams: r.dailyGrams, totalGrams: r.totalGrams, foodKindRaw: r.foodKindRaw,
            petId: r.pet?.id.uuidString,
            purchaseDate: d(r.purchaseDate),
            remainingCorrectionGrams: r.remainingCorrectionGrams,
            remainingCorrectionDate: d(r.remainingCorrectionDate),
            notes: r.notes, executorId: r.executorId)
    }

    private func encodeDocument(_ doc: PetDocument) -> PetDocumentBackup {
        PetDocumentBackup(id: doc.id.uuidString, title: doc.title, categoryRaw: doc.category,
            expiryDate: d(doc.expiryDate), petId: doc.pet?.id.uuidString,
            issueDate: d(doc.issueDate),
            issuingAuthority: doc.issuingAuthority,
            notes: doc.notes,
            reminderDate: d(doc.reminderDate),
            cost: doc.cost,
            attachmentBase64: doc.attachmentData?.base64EncodedString(),
            attachmentFilename: doc.attachmentFilename.isEmpty ? nil : doc.attachmentFilename)
    }

    private func encodeDocumentAttachments(_ doc: PetDocument) -> [PetDocumentAttachmentBackup] {
        doc.attachments.map {
            PetDocumentAttachmentBackup(
                id: $0.id.uuidString,
                documentId: doc.id.uuidString,
                dataBase64: $0.data.base64EncodedString(),
                filename: $0.filename,
                isImage: $0.isImage
            )
        }
    }

    private func encodeMilestone(_ m: PetMilestone) -> PetMilestoneBackup {
        PetMilestoneBackup(id: m.id.uuidString, date: d(m.date), title: m.title,
            emoji: m.emoji, notes: m.notes, petId: m.pet?.id.uuidString)
    }

    private func encodeHumanWeight(_ l: HumanWeightLog) -> HumanWeightLogBackup {
        HumanWeightLogBackup(id: l.id.uuidString, date: d(l.date),
            weight: l.weight, humanId: l.human?.id.uuidString,
            executorId: l.executorId)
    }

    private func encodeHumanWorkout(_ l: HumanWorkoutLog) -> HumanWorkoutLogBackup {
        HumanWorkoutLogBackup(id: l.id.uuidString, date: d(l.date), typeRaw: l.typeRaw,
            durationMinutes: l.durationMinutes, notes: l.notes,
            humanId: l.human?.id.uuidString)
    }

    private func encodeWaterLog(_ l: WaterLog) -> WaterLogBackup {
        WaterLogBackup(id: l.id.uuidString, date: d(l.date),
            amountMl: l.amountMl, note: l.note)
    }

    private func encodePhotoLog(_ l: PetPhotoLog) -> PetPhotoLogBackup {
        PetPhotoLogBackup(
            id: l.id.uuidString,
            date: d(l.date),
            note: l.note,
            createdAt: d(l.createdAt),
            imageBase64: l.imageData.base64EncodedString(),
            petId: l.pet?.id.uuidString,
            locationLatitude: l.locationLatitude,
            locationLongitude: l.locationLongitude,
            locationPlacename: l.locationPlacename
        )
    }

    private func encodeInsurance(_ i: PetInsurance) -> PetInsuranceBackup {
        PetInsuranceBackup(
            id: i.id.uuidString,
            companyName: i.companyName,
            policyNumber: i.policyNumber,
            productName: i.productName,
            annualPremium: i.annualPremium,
            coverageAmount: i.coverageAmount,
            startDate: d(i.startDate),
            renewalDate: d(i.renewalDate),
            notes: i.notes,
            isActive: i.isActive,
            createdAt: d(i.createdAt),
            paymentFrequencyRaw: i.paymentFrequencyRaw,
            paymentDayOfMonth: i.paymentDayOfMonth,
            showInCalendar: i.showInCalendar,
            otherFeeAmount: i.otherFeeAmount,
            otherFeeNote: i.otherFeeNote,
            firstPremiumPaymentDate: d(i.firstPremiumPaymentDate),
            petId: i.pet?.id.uuidString
        )
    }

    private func encodeInsuranceClaim(_ c: InsuranceClaim) -> InsuranceClaimBackup {
        InsuranceClaimBackup(
            id: c.id.uuidString,
            insuranceId: c.insurance?.id.uuidString,
            claimDate: d(c.claimDate),
            incidentDate: d(c.incidentDate),
            totalExpense: c.totalExpense,
            claimedAmount: c.claimedAmount,
            approvedAmount: c.approvedAmount,
            statusRaw: c.statusRaw,
            note: c.note,
            relatedExpenseLogId: c.relatedExpenseLogId,
            approvedAt: d(c.approvedAt),
            createdAt: d(c.createdAt)
        )
    }

    private func encodePetMedication(_ m: PetMedication) -> PetMedicationBackup {
        PetMedicationBackup(
            id: m.id.uuidString,
            name: m.name,
            dosage: m.dosage,
            frequencyRaw: m.frequencyRaw,
            customFrequencyNote: m.customFrequencyNote,
            startDate: d(m.startDate),
            endDate: d(m.endDate),
            colorHex: m.colorHex,
            notes: m.notes,
            isActive: m.isActive,
            createdAt: d(m.createdAt),
            petId: m.pet?.id.uuidString
        )
    }

    private func encodeHumanMedication(_ m: HumanMedication) -> HumanMedicationBackup {
        HumanMedicationBackup(
            id: m.id.uuidString,
            humanId: m.humanId,
            name: m.name,
            dosage: m.dosage,
            frequencyRaw: m.frequencyRaw,
            customFrequencyNote: m.customFrequencyNote,
            firstDoseTime: d(m.firstDoseTime),
            startDate: d(m.startDate),
            endDate: d(m.endDate),
            colorHex: m.colorHex,
            notes: m.notes,
            isActive: m.isActive,
            createdAt: d(m.createdAt)
        )
    }

    private func encodeHumanMedicationLog(_ l: HumanMedicationLog) -> HumanMedicationLogBackup {
        HumanMedicationLogBackup(
            id: l.id.uuidString,
            humanId: l.humanId,
            medicationId: l.medicationId,
            scheduledTime: d(l.scheduledTime),
            recordedTime: d(l.recordedTime),
            statusRaw: l.statusRaw,
            createdAt: d(l.createdAt)
        )
    }

    private func encodeHumanHealthMetricLog(_ l: HumanHealthMetricLog) -> HumanHealthMetricLogBackup {
        HumanHealthMetricLogBackup(
            id: l.id.uuidString,
            metricKey: l.metricKey,
            unitCode: l.unitCode,
            value: l.value,
            date: d(l.date),
            notes: l.notes,
            humanId: l.human?.id.uuidString,
            createdAt: d(l.createdAt)
        )
    }

    private func encodeSymptomLog(_ l: SymptomLog) -> SymptomLogBackup {
        SymptomLogBackup(
            id: l.id.uuidString,
            date: d(l.date),
            categoryRaw: l.categoryRaw,
            symptomName: l.symptomName,
            severityRaw: l.severityRaw,
            note: l.note,
            photoBase64: l.photoData?.base64EncodedString(),
            petId: l.pet?.id.uuidString
        )
    }

    private func encodeHeatCycleLog(_ l: HeatCycleLog) -> HeatCycleLogBackup {
        HeatCycleLogBackup(
            id: l.id.uuidString,
            startDate: d(l.startDate),
            endDate: d(l.endDate),
            statusRaw: l.statusRaw,
            note: l.note,
            isMated: l.isMated,
            expectedDeliveryDate: d(l.expectedDeliveryDate),
            petId: l.pet?.id.uuidString
        )
    }

    private func encodeWishlist(_ w: WishlistItem) -> WishlistItemBackup {
        WishlistItemBackup(id: w.id.uuidString, title: w.title, cost: w.cost,
            creatorId: w.creatorId, isRedeemed: w.isRedeemed, createdAt: d(w.createdAt))
    }

    private func encodeCareLedgerEvent(_ e: CareLedgerEvent) -> CareLedgerEventBackup {
        CareLedgerEventBackup(
            id: e.id.uuidString,
            occurredAt: d(e.occurredAt),
            actorKind: e.actorKind,
            actorId: e.actorId,
            subjectKind: e.subjectKind,
            subjectId: e.subjectId,
            eventKind: e.eventKind,
            actionType: e.actionType,
            amountValue: e.amountValue,
            amountUnit: e.amountUnit,
            note: e.note,
            source: e.source,
            sourceEventId: e.sourceEventId,
            sourceReminderId: e.sourceReminderId,
            legacyModelName: e.legacyModelName,
            legacyModelId: e.legacyModelId,
            coconutDelta: e.coconutDelta,
            rewardLogId: e.rewardLogId,
            privacyFieldRaw: e.privacyFieldRaw,
            metadataJSON: e.metadataJSON,
            createdAt: d(e.createdAt)
        )
    }

    private func encodeFamilyCollaborationTask(_ task: FamilyCollaborationTask) -> FamilyCollaborationTaskBackup {
        FamilyCollaborationTaskBackup(
            id: task.id.uuidString,
            title: task.title,
            note: task.note,
            kindRaw: task.kindRaw,
            statusRaw: task.statusRaw,
            relatedPetId: task.relatedPetId,
            relatedEventId: task.relatedEventId,
            relatedReminderId: task.relatedReminderId,
            createdById: task.createdById,
            createdByName: task.createdByName,
            assignedToId: task.assignedToId,
            assignedToName: task.assignedToName,
            claimedById: task.claimedById,
            claimedByName: task.claimedByName,
            completedById: task.completedById,
            completedByName: task.completedByName,
            rewardCoconuts: task.rewardCoconuts,
            dueAt: d(task.dueAt),
            completedAt: d(task.completedAt),
            createdAt: d(task.createdAt),
            updatedAt: d(task.updatedAt),
            emoji: task.emoji
        )
    }

    private func encodeCoconutExchangeRequest(_ request: CoconutExchangeRequest) -> CoconutExchangeRequestBackup {
        CoconutExchangeRequestBackup(
            id: request.id.uuidString,
            senderId: request.senderId,
            senderName: request.senderName,
            receiverId: request.receiverId,
            receiverName: request.receiverName,
            coconutCost: request.coconutCost,
            currencyCode: request.currencyCode,
            localAmount: request.localAmount,
            statusRaw: request.statusRaw,
            createdAt: d(request.createdAt),
            confirmedAt: d(request.confirmedAt),
            cancelledAt: d(request.cancelledAt),
            updatedAt: d(request.updatedAt),
            note: request.note
        )
    }

    private func encodeOasisUpgradeCoconut(_ coconut: OasisUpgradeCoconut) -> OasisUpgradeCoconutBackup {
        OasisUpgradeCoconutBackup(
            id: coconut.id.uuidString,
            level: coconut.level,
            createdAt: d(coconut.createdAt),
            openedAt: d(coconut.openedAt),
            rewardKindRaw: coconut.rewardKindRaw,
            rewardCatalogId: coconut.rewardCatalogId,
            guaranteedCritterId: coconut.guaranteedCritterId,
            coconutAmount: coconut.coconutAmount,
            treeEnergyAmount: coconut.treeEnergyAmount,
            fragmentAmount: coconut.fragmentAmount,
            decorUnlockId: coconut.decorUnlockId,
            storyStyleUnlockId: coconut.storyStyleUnlockId,
            temporaryEffectId: coconut.temporaryEffectId,
            titleZh: coconut.titleZh,
            titleEn: coconut.titleEn,
            titleDe: coconut.titleDe,
            descriptionZh: coconut.descriptionZh,
            descriptionEn: coconut.descriptionEn,
            descriptionDe: coconut.descriptionDe
        )
    }

    private func encodeOasisElectronicPet(_ critter: OasisElectronicPet) -> OasisElectronicPetBackup {
        OasisElectronicPetBackup(
            id: critter.id.uuidString,
            catalogId: critter.catalogId,
            nameZh: critter.nameZh,
            nameEn: critter.nameEn,
            nameDe: critter.nameDe,
            emoji: critter.emoji,
            rarityRaw: critter.rarityRaw,
            nickname: critter.nickname,
            level: critter.level,
            starLevel: critter.starLevel,
            xp: critter.xp,
            hunger: critter.hunger,
            mood: critter.mood,
            health: critter.health,
            bond: critter.bond,
            appearanceStage: critter.appearanceStage,
            isFeaturedOnOasis: critter.isFeaturedOnOasis,
            habitatSlot: critter.habitatSlot,
            equippedDecorId: critter.equippedDecorId,
            favoriteItemId: critter.favoriteItemId,
            personalityRaw: critter.personalityRaw,
            featuredPoseRaw: critter.featuredPoseRaw,
            sourceLevel: critter.sourceLevel,
            obtainedAt: d(critter.obtainedAt),
            lastInteractionAt: d(critter.lastInteractionAt),
            lastStateRefreshAt: d(critter.lastStateRefreshAt),
            lifeStateRaw: critter.lifeStateRaw,
            deathReasonRaw: critter.deathReasonRaw,
            riskStartedAt: d(critter.riskStartedAt),
            criticalStartedAt: d(critter.criticalStartedAt),
            diedAt: d(critter.diedAt),
            lastGentlePromptAt: d(critter.lastGentlePromptAt),
            isArchived: critter.isArchived
        )
    }

    private func encodeOasisCritterFragment(_ fragment: OasisCritterFragmentBalance) -> OasisCritterFragmentBackup {
        OasisCritterFragmentBackup(
            id: fragment.id.uuidString,
            catalogId: fragment.catalogId,
            amount: fragment.amount,
            updatedAt: d(fragment.updatedAt)
        )
    }

    private func encodeOasisUnlock(_ unlock: OasisUnlock) -> OasisUnlockBackup {
        OasisUnlockBackup(
            id: unlock.id.uuidString,
            unlockId: unlock.unlockId,
            unlockKindRaw: unlock.unlockKindRaw,
            sourceLevel: unlock.sourceLevel,
            createdAt: d(unlock.createdAt),
            metadataJSON: unlock.metadataJSON
        )
    }

    private func encodeOasisCritterActionLog(_ log: OasisCritterActionLog) -> OasisCritterActionLogBackup {
        OasisCritterActionLogBackup(
            id: log.id.uuidString,
            critterId: log.critterId?.uuidString,
            critterCatalogId: log.critterCatalogId,
            actionRaw: log.actionRaw,
            createdAt: d(log.createdAt),
            coconutDelta: log.coconutDelta,
            fragmentDelta: log.fragmentDelta,
            xpDelta: log.xpDelta,
            sourceLevel: log.sourceLevel,
            noteZh: log.noteZh,
            noteEn: log.noteEn,
            noteDe: log.noteDe
        )
    }

    private func encodeGachaOwnedItem(_ item: GachaOwnedItem) -> GachaOwnedItemBackup {
        GachaOwnedItemBackup(
            id: item.id.uuidString,
            ownerHumanId: item.ownerHumanId,
            seriesId: item.seriesId,
            itemId: item.itemId,
            rarityRaw: item.rarityRaw,
            isHidden: item.isHidden,
            ownedCount: item.ownedCount,
            firstObtainedAt: d(item.firstObtainedAt),
            latestObtainedAt: d(item.latestObtainedAt),
            createdAt: d(item.createdAt)
        )
    }

    private func encodeGachaDrawLog(_ log: GachaDrawLog) -> GachaDrawLogBackup {
        GachaDrawLogBackup(
            id: log.id.uuidString,
            ownerHumanId: log.ownerHumanId,
            ownerName: log.ownerName,
            seriesId: log.seriesId,
            itemId: log.itemId,
            rarityRaw: log.rarityRaw,
            isHidden: log.isHidden,
            isNew: log.isNew,
            outcomeKindRaw: log.outcomeKindRaw,
            instantResultId: log.instantResultId,
            instantTitleZh: log.instantTitleZh,
            instantTitleEn: log.instantTitleEn,
            instantTitleDe: log.instantTitleDe,
            instantDetailZh: log.instantDetailZh,
            instantDetailEn: log.instantDetailEn,
            instantDetailDe: log.instantDetailDe,
            instantSymbol: log.instantSymbol,
            instantCoconutDelta: log.instantCoconutDelta,
            costCoconuts: log.costCoconuts,
            dailySequence: log.dailySequence,
            drawDate: d(log.drawDate),
            createdAt: d(log.createdAt)
        )
    }

    // MARK: - Decode helpers

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s)
    }

    private func decodePet(_ dto: PetBackup) -> Pet {
        let p = Pet(name: dto.name, species: dto.species, breed: dto.breed,
                    birthday: parseDate(dto.birthday), gender: dto.gender,
                    isNeutered: dto.isNeutered)
        if let uuid = UUID(uuidString: dto.id) { p.id = uuid }
        p.avatarEmoji = dto.avatarEmoji
        p.microchipID = dto.microchipID; p.vetContact = dto.vetContact
        p.allergies = dto.allergies; p.passportNumber = dto.passportNumber
        p.passportExpiryDate = parseDate(dto.passportExpiryDate)
        p.formerName = dto.formerName; p.lineageInfo = dto.lineageInfo
        p.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            dto.themeColorHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        p.homeDate = parseDate(dto.homeDate)
        p.birthCountry = dto.birthCountry; p.birthCity = dto.birthCity
        p.foodBrand = dto.foodBrand; p.restockDate = parseDate(dto.restockDate)
        p.restockWeight = dto.restockWeight; p.dailyPortionGrams = dto.dailyPortionGrams
        p.mainFoodKindRaw = dto.mainFoodKindRaw ?? FeedFoodKind.dry.rawValue
        p.foodPrice = dto.foodPrice; p.isShared = dto.isShared
        p.createdAt = parseDate(dto.createdAt) ?? Date()
        p.notes = dto.notes; p.coatColor = dto.coatColor; p.eyeColor = dto.eyeColor
        p.currentStreak = dto.currentStreak
        p.lastCheckInDate = parseDate(dto.lastCheckInDate)
        p.foodTrackingModeRaw = dto.foodTrackingModeRaw
        p.casualOpenDate = parseDate(dto.casualOpenDate)
        p.casualDurationDays = dto.casualDurationDays
        p.foodReminderEnabled = dto.foodReminderEnabled ?? false
        p.foodReminderAdvanceDays = dto.foodReminderAdvanceDays ?? 7
        p.coconutBalance = dto.coconutBalance
        p.passedAwayDate = parseDate(dto.passedAwayDate)
        p.cardStyleRaw = dto.cardStyleRaw ?? "classic"
        if let raw = dto.cardPopoutImageBase64, let data = Data(base64Encoded: raw) {
            p.cardPopoutImageData = data
        }
        p.cardPopoutSourceRaw = dto.cardPopoutSourceRaw
        p.personalityTagsRaw = dto.personalityTagsRaw ?? ""
        return p
    }

    private func decodeHuman(_ dto: HumanBackup) -> Human {
        let h = Human(name: dto.name, birthday: parseDate(dto.birthday),
                      bloodType: dto.bloodType, avatarEmoji: dto.avatarEmoji,
                      role: dto.role, nationality: dto.nationality, city: dto.city)
        if let uuid = UUID(uuidString: dto.id) { h.id = uuid }
        h.appleUserIdentifier = dto.appleUserIdentifier
        h.notes = dto.notes
        h.createdAt = parseDate(dto.createdAt) ?? Date()
        h.coconutBalance = dto.coconutBalance
        h.shouldShowOnHome = dto.shouldShowOnHome
        h.mbti = dto.mbti ?? ""
        h.privateFieldsRaw = dto.privateFieldsRaw ?? ""
        h.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            dto.themeColorHex ?? "",
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )
        h.heightCm = dto.heightCm ?? 0
        h.avatarImageData = dto.avatarImageBase64.flatMap { Data(base64Encoded: $0) }
        h.passedAwayDate = parseDate(dto.passedAwayDate)
        return h
    }

    private func decodeHousehold(_ dto: HouseholdBackup) -> Household {
        let h = Household(name: dto.name)
        if let uuid = UUID(uuidString: dto.id) { h.id = uuid }
        h.createdAt = parseDate(dto.createdAt) ?? Date()
        h.totalProsperity = dto.totalProsperity
        return h
    }

    private func decodeEvent(_ dto: EventBackup) -> Event {
        let e = Event(
            title: dto.title,
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            isAllDay: dto.isAllDay,
            eventType: dto.eventType,
            relatedEntityType: dto.relatedEntityType,
            relatedEntityId: dto.relatedEntityId
        )
        if let uuid = UUID(uuidString: dto.id) { e.id = uuid }
        e.recurrenceDays = dto.recurrenceDays
        e.recurrenceEndDate = parseDate(dto.recurrenceEndDate)
        e.isCompleted = dto.isCompleted
        e.completedOccurrences = dto.completedOccurrences ?? []
        e.createdAt = parseDate(dto.createdAt) ?? Date()
        e.assigneeId = dto.assigneeId
        return e
    }

    private func decodeReminder(_ dto: ReminderBackup, events: [String: Event]) -> Reminder {
        let r = Reminder(
            event: dto.eventId.flatMap { events[$0] },
            scheduledAt: parseDate(dto.scheduledAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { r.id = uuid }
        r.status = dto.status
        r.notificationId = dto.notificationId
        r.completedAt = parseDate(dto.completedAt)
        r.completedBy = dto.completedBy ?? ""
        r.createdAt = parseDate(dto.createdAt) ?? Date()
        return r
    }

    private func decodeCareLog(_ dto: PetCareLogBackup, pets: [String: Pet]) -> PetCareLog {
        let l = PetCareLog(date: parseDate(dto.date) ?? Date(),
                           type: CareType(rawValue: dto.type) ?? .feeding,
                           amountGrams: dto.amountGrams, amountMl: dto.amountMl, note: dto.note,
                           foodKind: FeedFoodKind(rawValue: dto.foodKindRaw ?? "") ?? .dry,
                           treatKind: dto.treatKindRaw.flatMap(FeedTreatKind.init(rawValue:)),
                           sharedSessionId: dto.sharedSessionId ?? "",
                           pet: dto.petId.flatMap { pets[$0] },
                           executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodePottyLog(_ dto: PetPottyLogBackup, pets: [String: Pet]) -> PetPottyLog {
        let l = PetPottyLog(date: parseDate(dto.date) ?? Date(),
                            type: PottyType(rawValue: dto.type) ?? .perfectPoop,
                            pet: dto.petId.flatMap { pets[$0] },
                            executorId: dto.executorId,
                            latitude: dto.latitude,
                            longitude: dto.longitude,
                            locationAccuracyMeters: dto.locationAccuracyMeters,
                            walkLogId: dto.walkLogId,
                            sharedSessionId: dto.sharedSessionId ?? "")
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeSharedCareSession(_ dto: SharedCareSessionBackup) -> SharedCareSession {
        let session = SharedCareSession(
            date: parseDate(dto.date) ?? Date(),
            actionKind: SharedCareActionKind(rawValue: dto.actionKindRaw) ?? .feeding,
            executorId: dto.executorId,
            sourcePetId: dto.sourcePetId,
            targetPetIds: dto.targetPetIdsRaw.split(separator: "|").map(String.init),
            species: dto.speciesRaw,
            totalAmountGrams: dto.totalAmountGrams,
            totalAmountMl: dto.totalAmountMl,
            totalExpenseAmount: dto.totalExpenseAmount ?? 0,
            expenseCategory: ExpenseCategory(rawValue: dto.expenseCategoryRaw ?? "") ?? .other,
            currencyCode: dto.currencyCode ?? "",
            allocationMode: SharedCareAllocationMode(rawValue: dto.allocationModeRaw) ?? .equal,
            foodKind: FeedFoodKind(rawValue: dto.foodKindRaw) ?? .dry,
            stockOwnerPetId: dto.stockOwnerPetId,
            primaryLegacyModelName: dto.primaryLegacyModelName ?? "",
            primaryLegacyModelId: dto.primaryLegacyModelId ?? "",
            note: dto.note
        )
        if let uuid = UUID(uuidString: dto.id) { session.id = uuid }
        session.createdAt = parseDate(dto.createdAt) ?? session.createdAt
        return session
    }

    private func decodeWalkLog(_ dto: PetWalkLogBackup, pets: [String: Pet]) -> PetWalkLog {
        let l = PetWalkLog(startDate: parseDate(dto.startDate) ?? Date(),
                           pet: dto.petId.flatMap { pets[$0] },
                           executorId: dto.executorId,
                           sharedSessionId: dto.sharedSessionId ?? "")
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.endDate = parseDate(dto.endDate)
        l.distanceMeters = dto.distanceMeters
        l.coconutsEarned = dto.coconutsEarned
        return l
    }

    private func decodeWeightLog(_ dto: PetWeightLogBackup, pets: [String: Pet]) -> PetWeightLog {
        let l = PetWeightLog(date: parseDate(dto.date) ?? Date(), weight: dto.weight, pet: dto.petId.flatMap { pets[$0] }, executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeExpenseLog(_ dto: PetExpenseLogBackup, pets: [String: Pet]) -> PetExpenseLog {
        let l = PetExpenseLog(date: parseDate(dto.date) ?? Date(),
                              amount: dto.amount,
                              category: ExpenseCategory(rawValue: dto.category) ?? .other,
                              note: dto.note,
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId,
                              sharedSessionId: dto.sharedSessionId ?? "")
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHealthLog(_ dto: PetHealthLogBackup, pets: [String: Pet]) -> PetHealthLog {
        let l = PetHealthLog(date: parseDate(dto.date) ?? Date(),
                             type: HealthLogType(rawValue: dto.type) ?? .general,
                             note: dto.note,
                             pet: dto.petId.flatMap { pets[$0] },
                             executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.vetName = dto.vetName
        l.cost = dto.cost
        l.expirationDate = parseDate(dto.expirationDate)
        return l
    }

    private func decodeHygieneLog(_ dto: PetHygieneLogBackup, pets: [String: Pet]) -> PetHygieneLog {
        let l = PetHygieneLog(date: parseDate(dto.date) ?? Date(),
                              type: HygieneType(rawValue: dto.type) ?? .bath,
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeFoodRecord(_ dto: PetFoodRecordBackup, pets: [String: Pet]) -> PetFoodRecord {
        let l = PetFoodRecord(brand: dto.brand, dailyGrams: dto.dailyGrams,
                              totalGrams: dto.totalGrams ?? 0,
                              foodKind: FeedFoodKind(rawValue: dto.foodKindRaw ?? "") ?? .dry,
                              purchaseDate: parseDate(dto.purchaseDate ?? ""),
                              startDate: parseDate(dto.date) ?? Date(),
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.remainingCorrectionGrams = dto.remainingCorrectionGrams
        l.remainingCorrectionDate = parseDate(dto.remainingCorrectionDate ?? "")
        l.notes = dto.notes ?? ""
        return l
    }

    private func decodeDocument(_ dto: PetDocumentBackup, pets: [String: Pet]) -> PetDocument {
        let l = PetDocument(title: dto.title,
                            category: DocumentCategory(rawValue: dto.categoryRaw) ?? .other,
                            pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.expiryDate = parseDate(dto.expiryDate)
        l.issueDate = parseDate(dto.issueDate)
        l.issuingAuthority = dto.issuingAuthority ?? ""
        l.notes = dto.notes ?? ""
        l.reminderDate = parseDate(dto.reminderDate)
        l.cost = dto.cost ?? 0
        l.attachmentData = dto.attachmentBase64.flatMap { Data(base64Encoded: $0) }
        l.attachmentFilename = dto.attachmentFilename ?? ""
        return l
    }

    private func decodeDocumentAttachment(_ dto: PetDocumentAttachmentBackup) -> PetDocumentAttachment? {
        guard let data = Data(base64Encoded: dto.dataBase64) else { return nil }
        let l = PetDocumentAttachment(data: data, filename: dto.filename, isImage: dto.isImage)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeMilestone(_ dto: PetMilestoneBackup, pets: [String: Pet]) -> PetMilestone {
        let l = PetMilestone(date: parseDate(dto.date) ?? Date(),
                             title: dto.title, emoji: dto.emoji, notes: dto.notes,
                             pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHumanWeight(_ dto: HumanWeightLogBackup, humans: [String: Human]) -> HumanWeightLog {
        let l = HumanWeightLog(
            date: parseDate(dto.date) ?? Date(),
            weight: dto.weight,
            human: dto.humanId.flatMap { humans[$0] },
            executorId: dto.executorId
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHumanWorkout(_ dto: HumanWorkoutLogBackup, humans: [String: Human]) -> HumanWorkoutLog {
        let l = HumanWorkoutLog(date: parseDate(dto.date) ?? Date(),
                                type: WorkoutType(rawValue: dto.typeRaw) ?? .walking,
                                durationMinutes: dto.durationMinutes,
                                notes: dto.notes,
                                human: dto.humanId.flatMap { humans[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeWaterLog(_ dto: WaterLogBackup) -> WaterLog {
        let l = WaterLog(date: parseDate(dto.date) ?? Date(), amountMl: dto.amountMl,
                         note: dto.note)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodePhotoLog(_ dto: PetPhotoLogBackup, pets: [String: Pet]) -> PetPhotoLog {
        let l = PetPhotoLog(
            imageData: Data(base64Encoded: dto.imageBase64) ?? Data(),
            date: parseDate(dto.date) ?? Date(),
            note: dto.note,
            pet: dto.petId.flatMap { pets[$0] },
            locationLatitude: dto.locationLatitude,
            locationLongitude: dto.locationLongitude,
            locationPlacename: dto.locationPlacename
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodeInsurance(_ dto: PetInsuranceBackup, pets: [String: Pet]) -> PetInsurance {
        let l = PetInsurance(
            companyName: dto.companyName,
            policyNumber: dto.policyNumber,
            productName: dto.productName,
            annualPremium: dto.annualPremium,
            coverageAmount: dto.coverageAmount,
            startDate: parseDate(dto.startDate) ?? Date(),
            renewalDate: parseDate(dto.renewalDate) ?? Date(),
            notes: dto.notes,
            paymentFrequency: InsurancePaymentFrequency(rawValue: dto.paymentFrequencyRaw) ?? .annual,
            paymentDayOfMonth: dto.paymentDayOfMonth,
            showInCalendar: dto.showInCalendar,
            otherFeeAmount: dto.otherFeeAmount,
            otherFeeNote: dto.otherFeeNote,
            firstPremiumPaymentDate: parseDate(dto.firstPremiumPaymentDate),
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.isActive = dto.isActive
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodeInsuranceClaim(_ dto: InsuranceClaimBackup, insurances: [String: PetInsurance]) -> InsuranceClaim {
        let l = InsuranceClaim(
            claimDate: parseDate(dto.claimDate) ?? Date(),
            incidentDate: parseDate(dto.incidentDate) ?? Date(),
            totalExpense: dto.totalExpense,
            claimedAmount: dto.claimedAmount,
            approvedAmount: dto.approvedAmount,
            status: ClaimStatus(rawValue: dto.statusRaw) ?? .submitted,
            note: dto.note,
            relatedExpenseLogId: dto.relatedExpenseLogId,
            insurance: dto.insuranceId.flatMap { insurances[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.approvedAt = parseDate(dto.approvedAt)
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodePetMedication(_ dto: PetMedicationBackup, pets: [String: Pet]) -> PetMedication {
        let l = PetMedication(
            name: dto.name,
            dosage: dto.dosage,
            frequency: PetMedicationFrequency(rawValue: dto.frequencyRaw) ?? .daily,
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            colorHex: dto.colorHex,
            notes: dto.notes,
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.customFrequencyNote = dto.customFrequencyNote
        l.isActive = dto.isActive
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodeHumanMedication(_ dto: HumanMedicationBackup) -> HumanMedication {
        let l = HumanMedication(
            humanId: dto.humanId,
            name: dto.name,
            dosage: dto.dosage,
            frequency: MedicationFrequency(rawValue: dto.frequencyRaw) ?? .daily,
            firstDoseTime: parseDate(dto.firstDoseTime) ?? Date(),
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            colorHex: dto.colorHex,
            notes: dto.notes
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.customFrequencyNote = dto.customFrequencyNote
        l.isActive = dto.isActive
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodeHumanMedicationLog(_ dto: HumanMedicationLogBackup) -> HumanMedicationLog {
        let l = HumanMedicationLog(
            humanId: dto.humanId,
            medicationId: dto.medicationId,
            scheduledTime: parseDate(dto.scheduledTime) ?? Date(),
            status: HumanMedicationStatus(rawValue: dto.statusRaw) ?? .pending,
            recordedTime: parseDate(dto.recordedTime)
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodeHumanHealthMetricLog(_ dto: HumanHealthMetricLogBackup, humans: [String: Human]) -> HumanHealthMetricLog {
        let log = HumanHealthMetricLog(
            metricKey: dto.metricKey,
            unitCode: dto.unitCode,
            value: dto.value,
            date: parseDate(dto.date) ?? Date(),
            notes: dto.notes,
            human: dto.humanId.flatMap { humans[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        log.createdAt = parseDate(dto.createdAt) ?? Date()
        return log
    }

    private func decodeSymptomLog(_ dto: SymptomLogBackup, pets: [String: Pet]) -> SymptomLog {
        let l = SymptomLog(
            date: parseDate(dto.date) ?? Date(),
            category: SymptomCategory(rawValue: dto.categoryRaw) ?? .other,
            symptomName: dto.symptomName,
            severity: SymptomSeverity(rawValue: dto.severityRaw) ?? .mild,
            note: dto.note,
            photoData: dto.photoBase64.flatMap { Data(base64Encoded: $0) },
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHeatCycleLog(_ dto: HeatCycleLogBackup, pets: [String: Pet]) -> HeatCycleLog {
        let l = HeatCycleLog(
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            status: HeatCycleStatus(rawValue: dto.statusRaw) ?? .proestrus,
            note: dto.note,
            isMated: dto.isMated,
            expectedDeliveryDate: parseDate(dto.expectedDeliveryDate),
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeWishlist(_ dto: WishlistItemBackup) -> WishlistItem {
        let l = WishlistItem(title: dto.title, cost: dto.cost, creatorId: dto.creatorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.isRedeemed = dto.isRedeemed
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    private func decodeCareLedgerEvent(_ dto: CareLedgerEventBackup) -> CareLedgerEvent {
        let event = CareLedgerEvent(
            occurredAt: parseDate(dto.occurredAt) ?? Date(),
            actorKind: CareLedgerActorKind(rawValue: dto.actorKind) ?? .unknown,
            actorId: dto.actorId,
            subjectKind: CareLedgerSubjectKind(rawValue: dto.subjectKind) ?? .unknown,
            subjectId: dto.subjectId,
            eventKind: CareLedgerEventKind(rawValue: dto.eventKind) ?? .unknown,
            actionType: dto.actionType,
            amountValue: dto.amountValue,
            amountUnit: dto.amountUnit,
            note: dto.note,
            source: CareLedgerSource(rawValue: dto.source) ?? .importData,
            sourceEventId: dto.sourceEventId,
            sourceReminderId: dto.sourceReminderId,
            legacyModelName: dto.legacyModelName,
            legacyModelId: dto.legacyModelId,
            coconutDelta: dto.coconutDelta,
            rewardLogId: dto.rewardLogId,
            privacyFieldRaw: dto.privacyFieldRaw,
            metadataJSON: dto.metadataJSON,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { event.id = uuid }
        return event
    }

    private func decodeFamilyCollaborationTask(_ dto: FamilyCollaborationTaskBackup) -> FamilyCollaborationTask {
        let task = FamilyCollaborationTask(
            title: dto.title,
            note: dto.note,
            kind: FamilyCollaborationTaskKind(rawValue: dto.kindRaw) ?? .householdTask,
            status: FamilyCollaborationTaskStatus(rawValue: dto.statusRaw) ?? .active,
            relatedPetId: dto.relatedPetId,
            relatedEventId: dto.relatedEventId,
            relatedReminderId: dto.relatedReminderId,
            createdById: dto.createdById,
            createdByName: dto.createdByName,
            assignedToId: dto.assignedToId,
            assignedToName: dto.assignedToName,
            rewardCoconuts: dto.rewardCoconuts,
            dueAt: parseDate(dto.dueAt),
            emoji: dto.emoji,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { task.id = uuid }
        task.claimedById = dto.claimedById
        task.claimedByName = dto.claimedByName
        task.completedById = dto.completedById
        task.completedByName = dto.completedByName
        task.completedAt = parseDate(dto.completedAt)
        task.updatedAt = parseDate(dto.updatedAt) ?? task.createdAt
        return task
    }

    private func decodeCoconutExchangeRequest(_ dto: CoconutExchangeRequestBackup) -> CoconutExchangeRequest {
        let request = CoconutExchangeRequest(
            senderId: dto.senderId,
            senderName: dto.senderName,
            receiverId: dto.receiverId,
            receiverName: dto.receiverName,
            coconutCost: dto.coconutCost,
            currencyCode: dto.currencyCode,
            localAmount: dto.localAmount,
            status: CoconutExchangeRequestStatus(rawValue: dto.statusRaw) ?? .pending,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            confirmedAt: parseDate(dto.confirmedAt),
            cancelledAt: parseDate(dto.cancelledAt),
            updatedAt: parseDate(dto.updatedAt) ?? Date(),
            note: dto.note
        )
        if let uuid = UUID(uuidString: dto.id) { request.id = uuid }
        return request
    }

    private func decodeOasisUpgradeCoconut(_ dto: OasisUpgradeCoconutBackup) -> OasisUpgradeCoconut {
        let coconut = OasisUpgradeCoconut(
            level: dto.level,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            openedAt: parseDate(dto.openedAt),
            rewardKind: OasisUpgradeRewardKind(rawValue: dto.rewardKindRaw) ?? .coconuts,
            rewardCatalogId: dto.rewardCatalogId,
            guaranteedCritterId: dto.guaranteedCritterId,
            coconutAmount: dto.coconutAmount,
            treeEnergyAmount: dto.treeEnergyAmount,
            fragmentAmount: dto.fragmentAmount,
            decorUnlockId: dto.decorUnlockId,
            storyStyleUnlockId: dto.storyStyleUnlockId,
            temporaryEffectId: dto.temporaryEffectId,
            titleZh: dto.titleZh,
            titleEn: dto.titleEn,
            titleDe: dto.titleDe,
            descriptionZh: dto.descriptionZh,
            descriptionEn: dto.descriptionEn,
            descriptionDe: dto.descriptionDe
        )
        if let uuid = UUID(uuidString: dto.id) { coconut.id = uuid }
        return coconut
    }

    private func decodeOasisElectronicPet(_ dto: OasisElectronicPetBackup) -> OasisElectronicPet {
        let critter = OasisElectronicPet(
            catalogId: dto.catalogId,
            nameZh: dto.nameZh,
            nameEn: dto.nameEn,
            nameDe: dto.nameDe,
            emoji: dto.emoji,
            rarity: OasisElectronicPetRarity(rawValue: dto.rarityRaw) ?? .common,
            nickname: dto.nickname,
            level: dto.level,
            starLevel: dto.starLevel,
            xp: dto.xp,
            hunger: dto.hunger,
            mood: dto.mood,
            health: dto.health ?? 100,
            bond: dto.bond,
            appearanceStage: dto.appearanceStage,
            isFeaturedOnOasis: dto.isFeaturedOnOasis ?? false,
            habitatSlot: dto.habitatSlot ?? 0,
            equippedDecorId: dto.equippedDecorId ?? "",
            favoriteItemId: dto.favoriteItemId ?? "",
            personalityRaw: dto.personalityRaw ?? "gentle",
            featuredPoseRaw: dto.featuredPoseRaw ?? "idle",
            sourceLevel: dto.sourceLevel,
            obtainedAt: parseDate(dto.obtainedAt) ?? Date(),
            lastInteractionAt: parseDate(dto.lastInteractionAt) ?? Date(),
            lastStateRefreshAt: parseDate(dto.lastStateRefreshAt) ?? parseDate(dto.lastInteractionAt) ?? Date(),
            lifeStateRaw: dto.lifeStateRaw ?? OasisCritterLifeState.healthy.rawValue,
            deathReasonRaw: dto.deathReasonRaw ?? "",
            riskStartedAt: parseDate(dto.riskStartedAt),
            criticalStartedAt: parseDate(dto.criticalStartedAt),
            diedAt: parseDate(dto.diedAt),
            lastGentlePromptAt: parseDate(dto.lastGentlePromptAt),
            isArchived: dto.isArchived
        )
        if let uuid = UUID(uuidString: dto.id) { critter.id = uuid }
        return critter
    }

    private func decodeOasisCritterFragment(_ dto: OasisCritterFragmentBackup) -> OasisCritterFragmentBalance {
        let fragment = OasisCritterFragmentBalance(
            catalogId: dto.catalogId,
            amount: dto.amount,
            updatedAt: parseDate(dto.updatedAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { fragment.id = uuid }
        return fragment
    }

    private func decodeOasisUnlock(_ dto: OasisUnlockBackup) -> OasisUnlock {
        let unlock = OasisUnlock(
            unlockId: dto.unlockId,
            unlockKind: OasisUpgradeRewardKind(rawValue: dto.unlockKindRaw) ?? .decoration,
            sourceLevel: dto.sourceLevel,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            metadataJSON: dto.metadataJSON
        )
        if let uuid = UUID(uuidString: dto.id) { unlock.id = uuid }
        return unlock
    }

    private func decodeOasisCritterActionLog(_ dto: OasisCritterActionLogBackup) -> OasisCritterActionLog {
        let log = OasisCritterActionLog(
            critterId: dto.critterId.flatMap(UUID.init(uuidString:)),
            critterCatalogId: dto.critterCatalogId,
            action: OasisCritterAction(rawValue: dto.actionRaw) ?? .rest,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            coconutDelta: dto.coconutDelta,
            fragmentDelta: dto.fragmentDelta,
            xpDelta: dto.xpDelta,
            sourceLevel: dto.sourceLevel,
            noteZh: dto.noteZh,
            noteEn: dto.noteEn,
            noteDe: dto.noteDe
        )
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        return log
    }

    private func decodeGachaOwnedItem(_ dto: GachaOwnedItemBackup) -> GachaOwnedItem {
        let item = GachaOwnedItem(
            ownerHumanId: dto.ownerHumanId,
            seriesId: dto.seriesId,
            itemId: dto.itemId,
            rarity: GachaRarity(rawValue: dto.rarityRaw) ?? .common,
            isHidden: dto.isHidden,
            ownedCount: dto.ownedCount,
            firstObtainedAt: parseDate(dto.firstObtainedAt) ?? Date(),
            latestObtainedAt: parseDate(dto.latestObtainedAt) ?? Date()
        )
        item.createdAt = parseDate(dto.createdAt) ?? item.firstObtainedAt
        if let uuid = UUID(uuidString: dto.id) { item.id = uuid }
        return item
    }

    private func decodeGachaDrawLog(_ dto: GachaDrawLogBackup) -> GachaDrawLog {
        let log = GachaDrawLog(
            ownerHumanId: dto.ownerHumanId,
            ownerName: dto.ownerName,
            seriesId: dto.seriesId,
            itemId: dto.itemId,
            rarity: GachaRarity(rawValue: dto.rarityRaw) ?? .common,
            isHidden: dto.isHidden,
            isNew: dto.isNew,
            outcomeKind: GachaOutcomeKind(rawValue: dto.outcomeKindRaw ?? "") ?? .collectible,
            costCoconuts: dto.costCoconuts,
            dailySequence: dto.dailySequence,
            drawDate: parseDate(dto.drawDate) ?? Date()
        )
        log.instantResultId = dto.instantResultId ?? ""
        log.instantTitleZh = dto.instantTitleZh ?? ""
        log.instantTitleEn = dto.instantTitleEn ?? ""
        log.instantTitleDe = dto.instantTitleDe ?? ""
        log.instantDetailZh = dto.instantDetailZh ?? ""
        log.instantDetailEn = dto.instantDetailEn ?? ""
        log.instantDetailDe = dto.instantDetailDe ?? ""
        log.instantSymbol = dto.instantSymbol ?? ""
        log.instantCoconutDelta = dto.instantCoconutDelta ?? 0
        log.createdAt = parseDate(dto.createdAt) ?? log.drawDate
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        return log
    }
}

// MARK: - Error
enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "备份文件版本 v\(v) 不受支持，请更新 App 后重试。"
        }
    }
}

// MARK: - Background Export Actor
//
// Owns a dedicated background SwiftData context. Running the full-table fetch +
// JSON encode here keeps the unbounded export work off the main thread; only the
// resulting Sendable `Data` crosses back to the caller.
@ModelActor
actor DataBackupActor {
    func exportData() throws -> Data {
        let backup = try DataBackupManager.shared.buildBackup(context: modelContext)
        return try DataBackupManager.shared.encode(backup)
    }
}
