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
    var schemaVersion: Int = 14
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
    var petMilestones: [PetMilestoneBackup]
    var humanWeightLogs: [HumanWeightLogBackup]
    var humanWorkoutLogs: [HumanWorkoutLogBackup]
    var waterLogs: [WaterLogBackup]
    var wishlistItems: [WishlistItemBackup]
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
    var coconutBalance: Int; var passedAwayDate: String?
}

struct HumanBackup: Codable {
    var id: String; var name: String; var birthday: String?; var bloodType: String
    var avatarEmoji: String; var role: String; var appleUserIdentifier: String
    var notes: String; var createdAt: String; var nationality: String; var city: String
    var coconutBalance: Int; var shouldShowOnHome: Bool
}

struct EventBackup: Codable {
    var id: String; var title: String; var startDate: String; var endDate: String?
    var isAllDay: Bool; var eventType: String
    var relatedEntityId: String; var relatedEntityType: String
    var recurrenceDays: Int; var recurrenceEndDate: String?
    var isCompleted: Bool; var createdAt: String
}

struct ReminderBackup: Codable {
    var id: String; var scheduledAt: String; var status: String
    var notificationId: String; var eventId: String?
}

struct HouseholdBackup: Codable {
    var id: String; var name: String; var createdAt: String; var totalProsperity: Int
}

struct PlantBackup: Codable {
    var id: String; var name: String; var species: String; var avatarEmoji: String
    var location: String; var notes: String; var createdAt: String
    var lastWateredDate: String?; var wateringIntervalDays: Int
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
}

struct PetDocumentBackup: Codable {
    var id: String; var title: String; var categoryRaw: String
    var expiryDate: String?; var petId: String?
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

struct WaterLogBackup: Codable {
    var id: String; var date: String; var amountMl: Double; var note: String
}

struct WishlistItemBackup: Codable {
    var id: String; var title: String; var cost: Int; var creatorId: String
    var isRedeemed: Bool; var createdAt: String
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

        guard backup.schemaVersion <= 14 else {
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
        let hWeightLogs = try context.fetch(FetchDescriptor<HumanWeightLog>())
        let hWorkouts   = try context.fetch(FetchDescriptor<HumanWorkoutLog>())
        let waterLogs   = try context.fetch(FetchDescriptor<WaterLog>())
        let wishlist    = try context.fetch(FetchDescriptor<WishlistItem>())

        let ud = UserDefaults.standard
        let appState = AppStateBackup(
            coconutCount:           ud.integer(forKey: "coconutCount"),
            coconutLogsJSON:        ud.string(forKey: "coconutLogs") ?? "[]",
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
            petMilestones:    milestones.map(encodeMilestone),
            humanWeightLogs:  hWeightLogs.map(encodeHumanWeight),
            humanWorkoutLogs: hWorkouts.map(encodeHumanWorkout),
            waterLogs:        waterLogs.map(encodeWaterLog),
            wishlistItems:    wishlist.map(encodeWishlist),
            appState:         appState
        )
    }

    // MARK: - Apply Backup

    private func applyBackup(_ backup: OhanaBackup, context: ModelContext) throws {
        // 以 UUID 为主键去重：先构建现有 ID 集合，再 upsert
        let existingPetIds   = Set((try? context.fetch(FetchDescriptor<Pet>()))?.map { $0.id.uuidString } ?? [])
        let existingHumanIds = Set((try? context.fetch(FetchDescriptor<Human>()))?.map { $0.id.uuidString } ?? [])

        for dto in backup.pets where !existingPetIds.contains(dto.id) {
            context.insert(decodePet(dto))
        }
        for dto in backup.humans where !existingHumanIds.contains(dto.id) {
            context.insert(decodeHuman(dto))
        }

        // 日志类直接插入（不去重，避免重复计算可由调用方在 import 前清空）
        for dto in backup.petCareLogs   { context.insert(decodeCareLog(dto)) }
        for dto in backup.petPottyLogs  { context.insert(decodePottyLog(dto)) }
        for dto in backup.petWalkLogs   { context.insert(decodeWalkLog(dto)) }
        for dto in backup.petWeightLogs { context.insert(decodeWeightLog(dto)) }
        for dto in backup.petExpenseLogs { context.insert(decodeExpenseLog(dto)) }
        for dto in backup.petHealthLogs { context.insert(decodeHealthLog(dto)) }
        for dto in backup.petHygieneLogs { context.insert(decodeHygieneLog(dto)) }
        for dto in backup.petFoodRecords { context.insert(decodeFoodRecord(dto)) }
        for dto in backup.petDocuments  { context.insert(decodeDocument(dto)) }
        for dto in backup.petMilestones { context.insert(decodeMilestone(dto)) }
        for dto in backup.humanWeightLogs { context.insert(decodeHumanWeight(dto)) }
        for dto in backup.humanWorkoutLogs { context.insert(decodeHumanWorkout(dto)) }
        for dto in backup.waterLogs     { context.insert(decodeWaterLog(dto)) }
        for dto in backup.wishlistItems { context.insert(decodeWishlist(dto)) }

        try context.save()

        // 恢复 UserDefaults appState
        let ud = UserDefaults.standard
        let s = backup.appState
        if s.coconutCount > 0 { ud.set(s.coconutCount, forKey: "coconutCount") }
        if !s.coconutLogsJSON.isEmpty    { ud.set(s.coconutLogsJSON,    forKey: "coconutLogs") }
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
            casualDurationDays: p.casualDurationDays, coconutBalance: p.coconutBalance,
            passedAwayDate: d(p.passedAwayDate)
        )
    }

    private func encodeHuman(_ h: Human) -> HumanBackup {
        HumanBackup(
            id: h.id.uuidString, name: h.name, birthday: d(h.birthday),
            bloodType: h.bloodType, avatarEmoji: h.avatarEmoji, role: h.role,
            appleUserIdentifier: h.appleUserIdentifier, notes: h.notes,
            createdAt: d(h.createdAt), nationality: h.nationality, city: h.city,
            coconutBalance: h.coconutBalance, shouldShowOnHome: h.shouldShowOnHome
        )
    }

    private func encodeEvent(_ e: Event) -> EventBackup {
        EventBackup(
            id: e.id.uuidString, title: e.title, startDate: d(e.startDate),
            endDate: d(e.endDate), isAllDay: e.isAllDay, eventType: e.eventType,
            relatedEntityId: e.relatedEntityId, relatedEntityType: e.relatedEntityType,
            recurrenceDays: e.recurrenceDays, recurrenceEndDate: d(e.recurrenceEndDate),
            isCompleted: e.isCompleted, createdAt: d(e.createdAt)
        )
    }

    private func encodeReminder(_ r: Reminder) -> ReminderBackup {
        ReminderBackup(
            id: r.id.uuidString, scheduledAt: d(r.scheduledAt),
            status: r.status, notificationId: r.notificationId,
            eventId: r.event?.id.uuidString
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
            lastWateredDate: d(p.lastWateredDate), wateringIntervalDays: p.wateringIntervalDays
        )
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
            petId: l.pet?.id.uuidString)
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
            dailyGrams: r.dailyGrams, petId: r.pet?.id.uuidString)
    }

    private func encodeDocument(_ doc: PetDocument) -> PetDocumentBackup {
        PetDocumentBackup(id: doc.id.uuidString, title: doc.title, categoryRaw: doc.category,
            expiryDate: d(doc.expiryDate), petId: doc.pet?.id.uuidString)
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

    private func encodeWishlist(_ w: WishlistItem) -> WishlistItemBackup {
        WishlistItemBackup(id: w.id.uuidString, title: w.title, cost: w.cost,
            creatorId: w.creatorId, isRedeemed: w.isRedeemed, createdAt: d(w.createdAt))
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
        p.coconutBalance = dto.coconutBalance
        p.passedAwayDate = parseDate(dto.passedAwayDate)
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
        return h
    }

    private func decodeCareLog(_ dto: PetCareLogBackup) -> PetCareLog {
        let l = PetCareLog(date: parseDate(dto.date) ?? Date(),
                           type: CareType(rawValue: dto.type) ?? .feeding,
                           amountGrams: dto.amountGrams, amountMl: dto.amountMl, note: dto.note,
                           executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodePottyLog(_ dto: PetPottyLogBackup) -> PetPottyLog {
        let l = PetPottyLog(date: parseDate(dto.date) ?? Date(),
                            type: PottyType(rawValue: dto.type) ?? .perfectPoop,
                            executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeWalkLog(_ dto: PetWalkLogBackup) -> PetWalkLog {
        let l = PetWalkLog(startDate: parseDate(dto.startDate) ?? Date(),
                           pet: nil, executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.endDate = parseDate(dto.endDate)
        l.distanceMeters = dto.distanceMeters
        l.coconutsEarned = dto.coconutsEarned
        return l
    }

    private func decodeWeightLog(_ dto: PetWeightLogBackup) -> PetWeightLog {
        let l = PetWeightLog(date: parseDate(dto.date) ?? Date(), weight: dto.weight)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeExpenseLog(_ dto: PetExpenseLogBackup) -> PetExpenseLog {
        let l = PetExpenseLog(date: parseDate(dto.date) ?? Date(),
                              amount: dto.amount,
                              category: ExpenseCategory(rawValue: dto.category) ?? .other,
                              note: dto.note)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHealthLog(_ dto: PetHealthLogBackup) -> PetHealthLog {
        let l = PetHealthLog(date: parseDate(dto.date) ?? Date(),
                             type: HealthLogType(rawValue: dto.type) ?? .general,
                             note: dto.note)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.vetName = dto.vetName
        l.cost = dto.cost
        l.expirationDate = parseDate(dto.expirationDate)
        return l
    }

    private func decodeHygieneLog(_ dto: PetHygieneLogBackup) -> PetHygieneLog {
        let l = PetHygieneLog(date: parseDate(dto.date) ?? Date(),
                              type: HygieneType(rawValue: dto.type) ?? .bath)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeFoodRecord(_ dto: PetFoodRecordBackup) -> PetFoodRecord {
        let l = PetFoodRecord(brand: dto.brand, dailyGrams: dto.dailyGrams,
                              startDate: parseDate(dto.date) ?? Date())
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeDocument(_ dto: PetDocumentBackup) -> PetDocument {
        let l = PetDocument(title: dto.title,
                            category: DocumentCategory(rawValue: dto.categoryRaw) ?? .other)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.expiryDate = parseDate(dto.expiryDate)
        return l
    }

    private func decodeMilestone(_ dto: PetMilestoneBackup) -> PetMilestone {
        let l = PetMilestone(date: parseDate(dto.date) ?? Date(),
                             title: dto.title, emoji: dto.emoji, notes: dto.notes)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHumanWeight(_ dto: HumanWeightLogBackup) -> HumanWeightLog {
        let l = HumanWeightLog(date: parseDate(dto.date) ?? Date(), weight: dto.weight)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeHumanWorkout(_ dto: HumanWorkoutLogBackup) -> HumanWorkoutLog {
        let l = HumanWorkoutLog(date: parseDate(dto.date) ?? Date(),
                                type: WorkoutType(rawValue: dto.typeRaw) ?? .walking,
                                durationMinutes: dto.durationMinutes,
                                notes: dto.notes)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    private func decodeWaterLog(_ dto: WaterLogBackup) -> WaterLog {
        let l = WaterLog(date: parseDate(dto.date) ?? Date(), amountMl: dto.amountMl,
                         note: dto.note)
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
