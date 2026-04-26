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
struct OhanaBackup: Codable {
    var schemaVersion: Int = 17
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
    var waterLogs: [WaterLogBackup]
    var wishlistItems: [WishlistItemBackup]
    var careLedgerEvents: [CareLedgerEventBackup]?
    // App 状态
    var appState: AppStateBackup
}

// MARK: - AppState
struct AppStateBackup: Codable {
    var coconutCount: Int
    var coconutLogsJSON: String
    var bountyTasksJSON: String
    var purchasedShopItems: String
    var gachaHistoryJSON: String
    var celebratedMilestoneDays: String
}

// MARK: - 实体 Backup DTOs
struct PetBackup: Codable {
    var id: String; var name: String; var species: String; var breed: String
    var birthday: String?; var gender: String; var isNeutered: Bool
    var avatarEmoji: String; var microchipID: String; var vetContact: String
    var allergies: String; var passportNumber: String; var passportExpiryDate: String?
    var formerName: String; var lineageInfo: String; var themeColorHex: String
    var homeDate: String?; var birthCountry: String; var birthCity: String
    var foodBrand: String; var restockDate: String?; var restockWeight: Double
    var dailyPortionGrams: Double; var foodPrice: Double; var isShared: Bool
    var createdAt: String; var notes: String; var coatColor: String; var eyeColor: String
    var currentStreak: Int; var lastCheckInDate: String?
    var foodTrackingModeRaw: String; var casualOpenDate: String?; var casualDurationDays: Int
    var foodReminderEnabled: Bool?; var foodReminderAdvanceDays: Int?
    var coconutBalance: Int; var passedAwayDate: String?
    /// ArkSchemaV26：性格标签 id，逗号分隔；旧备份缺省为 nil
    var personalityTagsRaw: String?
}

struct HumanBackup: Codable {
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
}

struct EventBackup: Codable {
    var id: String; var title: String; var startDate: String; var endDate: String?
    var isAllDay: Bool; var eventType: String
    var relatedEntityId: String; var relatedEntityType: String
    var recurrenceDays: Int; var recurrenceEndDate: String?
    var isCompleted: Bool; var createdAt: String
    var completedOccurrences: [String]?
    var assigneeId: String?
}

struct ReminderBackup: Codable {
    var id: String; var scheduledAt: String; var status: String
    var notificationId: String; var eventId: String?
    var completedAt: String?
    var completedBy: String?
    var createdAt: String?
}

struct HouseholdBackup: Codable {
    var id: String; var name: String; var createdAt: String; var totalProsperity: Int
}

struct PlantBackup: Codable {
    var id: String; var name: String; var species: String; var avatarEmoji: String
    var location: String; var notes: String; var createdAt: String
    var lastWateredDate: String?; var wateringIntervalDays: Int
    var lastFertilizedDate: String?; var fertilizingIntervalDays: Int
    var themeColorHex: String?
}

struct PetCareLogBackup: Codable {
    var id: String; var date: String; var type: String
    var amountGrams: Double; var amountMl: Double; var note: String
    var executorId: String?; var petId: String?
}

struct PetPottyLogBackup: Codable {
    var id: String; var date: String; var type: String
    var executorId: String?; var petId: String?
}

struct PetWalkLogBackup: Codable {
    var id: String; var startDate: String; var endDate: String?
    var distanceMeters: Double; var coconutsEarned: Int
    var executorId: String?; var petId: String?
}

struct PetWeightLogBackup: Codable {
    var id: String; var date: String; var weight: Double; var petId: String?
}

struct PetExpenseLogBackup: Codable {
    var id: String; var date: String; var amount: Double
    var category: String; var note: String; var petId: String?
    var executorId: String?
}

struct PetHealthLogBackup: Codable {
    var id: String; var date: String; var type: String; var note: String
    var expirationDate: String?; var vetName: String; var cost: Double; var petId: String?
}

struct PetHygieneLogBackup: Codable {
    var id: String; var date: String; var type: String; var petId: String?
}

struct PetFoodRecordBackup: Codable {
    var id: String; var date: String; var brand: String
    var dailyGrams: Double; var petId: String?
    var notes: String?; var executorId: String?
}

struct PetDocumentBackup: Codable {
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

struct PetDocumentAttachmentBackup: Codable {
    var id: String; var documentId: String
    var dataBase64: String; var filename: String; var isImage: Bool
}

struct PetMilestoneBackup: Codable {
    var id: String; var date: String; var title: String; var emoji: String; var notes: String; var petId: String?
}

struct HumanWeightLogBackup: Codable {
    var id: String; var date: String; var weight: Double; var humanId: String?
}

struct HumanWorkoutLogBackup: Codable {
    var id: String; var date: String; var typeRaw: String
    var durationMinutes: Int; var notes: String; var humanId: String?
}

struct PetPhotoLogBackup: Codable {
    var id: String; var date: String; var note: String; var createdAt: String
    var imageBase64: String; var petId: String?
    var locationLatitude: Double; var locationLongitude: Double; var locationPlacename: String
}

struct PetInsuranceBackup: Codable {
    var id: String; var companyName: String; var policyNumber: String; var productName: String
    var annualPremium: Double; var coverageAmount: Double
    var startDate: String; var renewalDate: String
    var notes: String; var isActive: Bool; var createdAt: String
    var paymentFrequencyRaw: String; var paymentDayOfMonth: Int
    var showInCalendar: Bool; var otherFeeAmount: Double; var otherFeeNote: String
    var firstPremiumPaymentDate: String?; var petId: String?
}

struct InsuranceClaimBackup: Codable {
    var id: String; var insuranceId: String?
    var claimDate: String; var incidentDate: String
    var totalExpense: Double; var claimedAmount: Double; var approvedAmount: Double
    var statusRaw: String; var note: String; var relatedExpenseLogId: String?
    var approvedAt: String?; var createdAt: String
}

struct PetMedicationBackup: Codable {
    var id: String; var name: String; var dosage: String; var frequencyRaw: String
    var customFrequencyNote: String; var startDate: String; var endDate: String?
    var colorHex: String; var notes: String; var isActive: Bool; var createdAt: String
    var petId: String?
}

struct HumanMedicationBackup: Codable {
    var id: String; var humanId: String; var name: String; var dosage: String
    var frequencyRaw: String; var customFrequencyNote: String
    var firstDoseTime: String; var startDate: String; var endDate: String?
    var colorHex: String; var notes: String; var isActive: Bool; var createdAt: String
}

struct HumanMedicationLogBackup: Codable {
    var id: String; var humanId: String; var medicationId: String
    var scheduledTime: String; var recordedTime: String?
    var statusRaw: String; var createdAt: String
}

struct SymptomLogBackup: Codable {
    var id: String; var date: String; var categoryRaw: String
    var symptomName: String; var severityRaw: Int; var note: String
    var photoBase64: String?; var petId: String?
}

struct HeatCycleLogBackup: Codable {
    var id: String; var startDate: String; var endDate: String?
    var statusRaw: String; var note: String; var isMated: Bool
    var expectedDeliveryDate: String?; var petId: String?
}

struct WaterLogBackup: Codable {
    var id: String; var date: String; var amountMl: Double; var note: String
}

struct WishlistItemBackup: Codable {
    var id: String; var title: String; var cost: Int; var creatorId: String
    var isRedeemed: Bool; var createdAt: String
}

struct CareLedgerEventBackup: Codable {
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

// MARK: - DataBackupManager
@MainActor
final class DataBackupManager {
    static let shared = DataBackupManager()
    private init() {}

    private let iso = ISO8601DateFormatter()

    // MARK: - Export

    func exportJSON(context: ModelContext) async throws -> URL {
        let backup = try buildBackup(context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)

        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = f.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohana_backup_\(stamp).json")
        try data.write(to: url)
        return url
    }

    // MARK: - Import

    func importJSON(from url: URL, context: ModelContext) async throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(OhanaBackup.self, from: data)

        guard backup.schemaVersion <= 17 else {
            throw BackupError.unsupportedVersion(backup.schemaVersion)
        }

        try applyBackup(backup, context: context)
    }

    // MARK: - Build Backup

    private func buildBackup(context: ModelContext) throws -> OhanaBackup {
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
        let waterLogs   = try context.fetch(FetchDescriptor<WaterLog>())
        let wishlist    = try context.fetch(FetchDescriptor<WishlistItem>())
        let ledger      = try context.fetch(FetchDescriptor<CareLedgerEvent>())

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
            waterLogs:        waterLogs.map(encodeWaterLog),
            wishlistItems:    wishlist.map(encodeWishlist),
            careLedgerEvents: ledger.map(encodeCareLedgerEvent),
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
        let existingDocumentAttachmentIds = Set((try? context.fetch(FetchDescriptor<PetDocumentAttachment>()))?.map { $0.id.uuidString } ?? [])
        let existingPhotoIds = Set((try? context.fetch(FetchDescriptor<PetPhotoLog>()))?.map { $0.id.uuidString } ?? [])
        let existingInsuranceIds = Set((try? context.fetch(FetchDescriptor<PetInsurance>()))?.map { $0.id.uuidString } ?? [])
        let existingClaimIds = Set((try? context.fetch(FetchDescriptor<InsuranceClaim>()))?.map { $0.id.uuidString } ?? [])
        let existingPetMedicationIds = Set((try? context.fetch(FetchDescriptor<PetMedication>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanMedicationIds = Set((try? context.fetch(FetchDescriptor<HumanMedication>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanMedicationLogIds = Set((try? context.fetch(FetchDescriptor<HumanMedicationLog>()))?.map { $0.id.uuidString } ?? [])
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
        for dto in backup.petMilestones { context.insert(decodeMilestone(dto, pets: petById)) }
        for dto in backup.humanWeightLogs { context.insert(decodeHumanWeight(dto, humans: humanById)) }
        for dto in backup.humanWorkoutLogs { context.insert(decodeHumanWorkout(dto, humans: humanById)) }
        for dto in backup.waterLogs     { context.insert(decodeWaterLog(dto)) }
        for dto in backup.wishlistItems { context.insert(decodeWishlist(dto)) }
        for dto in backup.careLedgerEvents ?? [] where !existingLedgerIds.contains(dto.id) {
            context.insert(decodeCareLedgerEvent(dto))
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
            avatarImageBase64: h.avatarImageData?.base64EncodedString()
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
            executorId: l.executorId, petId: l.pet?.id.uuidString)
    }

    private func encodePottyLog(_ l: PetPottyLog) -> PetPottyLogBackup {
        PetPottyLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            executorId: l.executorId, petId: l.pet?.id.uuidString)
    }

    private func encodeWalkLog(_ l: PetWalkLog) -> PetWalkLogBackup {
        PetWalkLogBackup(id: l.id.uuidString, startDate: d(l.startDate),
            endDate: d(l.endDate), distanceMeters: l.distanceMeters,
            coconutsEarned: l.coconutsEarned,
            executorId: l.executorId, petId: l.pet?.id.uuidString)
    }

    private func encodeWeightLog(_ l: PetWeightLog) -> PetWeightLogBackup {
        PetWeightLogBackup(id: l.id.uuidString, date: d(l.date),
            weight: l.weight, petId: l.pet?.id.uuidString)
    }

    private func encodeExpenseLog(_ l: PetExpenseLog) -> PetExpenseLogBackup {
        PetExpenseLogBackup(id: l.id.uuidString, date: d(l.date),
            amount: l.amount, category: l.category, note: l.note,
            petId: l.pet?.id.uuidString,
            executorId: l.executorId)
    }

    private func encodeHealthLog(_ l: PetHealthLog) -> PetHealthLogBackup {
        PetHealthLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            note: l.note, expirationDate: d(l.expirationDate), vetName: l.vetName,
            cost: l.cost, petId: l.pet?.id.uuidString)
    }

    private func encodeHygieneLog(_ l: PetHygieneLog) -> PetHygieneLogBackup {
        PetHygieneLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
            petId: l.pet?.id.uuidString)
    }

    private func encodeFoodRecord(_ r: PetFoodRecord) -> PetFoodRecordBackup {
        PetFoodRecordBackup(id: r.id.uuidString, date: d(r.startDate), brand: r.brand,
            dailyGrams: r.dailyGrams, petId: r.pet?.id.uuidString,
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
            weight: l.weight, humanId: l.human?.id.uuidString)
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
        p.themeColorHex = dto.themeColorHex
        p.homeDate = parseDate(dto.homeDate)
        p.birthCountry = dto.birthCountry; p.birthCity = dto.birthCity
        p.foodBrand = dto.foodBrand; p.restockDate = parseDate(dto.restockDate)
        p.restockWeight = dto.restockWeight; p.dailyPortionGrams = dto.dailyPortionGrams
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
        h.themeColorHex = dto.themeColorHex ?? "4338FF"
        h.heightCm = dto.heightCm ?? 0
        h.avatarImageData = dto.avatarImageBase64.flatMap { Data(base64Encoded: $0) }
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
                           pet: dto.petId.flatMap { pets[$0] },
                           executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodePottyLog(_ dto: PetPottyLogBackup, pets: [String: Pet]) -> PetPottyLog {
        let l = PetPottyLog(date: parseDate(dto.date) ?? Date(),
                            type: PottyType(rawValue: dto.type) ?? .perfectPoop,
                            pet: dto.petId.flatMap { pets[$0] },
                            executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeWalkLog(_ dto: PetWalkLogBackup, pets: [String: Pet]) -> PetWalkLog {
        let l = PetWalkLog(startDate: parseDate(dto.startDate) ?? Date(),
                           pet: dto.petId.flatMap { pets[$0] }, executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.endDate = parseDate(dto.endDate)
        l.distanceMeters = dto.distanceMeters
        l.coconutsEarned = dto.coconutsEarned
        return l
    }

    private func decodeWeightLog(_ dto: PetWeightLogBackup, pets: [String: Pet]) -> PetWeightLog {
        let l = PetWeightLog(date: parseDate(dto.date) ?? Date(), weight: dto.weight, pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeExpenseLog(_ dto: PetExpenseLogBackup, pets: [String: Pet]) -> PetExpenseLog {
        let l = PetExpenseLog(date: parseDate(dto.date) ?? Date(),
                              amount: dto.amount,
                              category: ExpenseCategory(rawValue: dto.category) ?? .other,
                              note: dto.note,
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHealthLog(_ dto: PetHealthLogBackup, pets: [String: Pet]) -> PetHealthLog {
        let l = PetHealthLog(date: parseDate(dto.date) ?? Date(),
                             type: HealthLogType(rawValue: dto.type) ?? .general,
                             note: dto.note,
                             pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.vetName = dto.vetName
        l.cost = dto.cost
        l.expirationDate = parseDate(dto.expirationDate)
        return l
    }

    private func decodeHygieneLog(_ dto: PetHygieneLogBackup, pets: [String: Pet]) -> PetHygieneLog {
        let l = PetHygieneLog(date: parseDate(dto.date) ?? Date(),
                              type: HygieneType(rawValue: dto.type) ?? .bath,
                              pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeFoodRecord(_ dto: PetFoodRecordBackup, pets: [String: Pet]) -> PetFoodRecord {
        let l = PetFoodRecord(brand: dto.brand, dailyGrams: dto.dailyGrams,
                              startDate: parseDate(dto.date) ?? Date(),
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
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
            human: dto.humanId.flatMap { humans[$0] }
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
