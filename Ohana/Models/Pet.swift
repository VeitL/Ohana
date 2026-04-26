//
//  Pet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Food Tracking Mode (ArkSchemaV10)
enum FoodTrackingMode: String, Codable, CaseIterable {
    case casual  // 佛系：记录大概能吃多久，不扣克数
    case precise // 精准：精确克数库存倒计时

    var displayName: String {
        switch self {
        case .casual:  return "佛系估算"
        case .precise: return "精准倒数"
        }
    }
}

// MARK: - Pet Theme Color (Go UI palette — used to distinguish pets in charts, calendar, etc.)
enum PetThemeColor: String, Codable, CaseIterable {
    // 16 non-green, distinct, high-contrast colors
    case crimson, vermilion, orange, amber, yellow, brown, rust, burgundy
    case magenta, pink, purple, indigo, violet, navy, blue, skyBlue
    
    var color: Color {
        switch self {
        case .crimson:   return Color.petThemeCrimson
        case .vermilion: return Color.petThemeVermilion
        case .orange:    return Color.petThemeOrange
        case .amber:     return Color.petThemeAmber
        case .yellow:    return Color.petThemeYellow
        case .brown:     return Color.petThemeBrown
        case .rust:      return Color.petThemeRust
        case .burgundy:  return Color.petThemeBurgundy
        case .magenta:   return Color.petThemeMagenta
        case .pink:      return Color.petThemePink
        case .purple:    return Color.petThemePurple
        case .indigo:    return Color.petThemeIndigo
        case .violet:    return Color.petThemeViolet
        case .navy:      return Color.petThemeNavy
        case .blue:      return Color.petThemeBlue
        case .skyBlue:   return Color.petThemeSkyBlue
        }
    }
    
    var hexValue: String {
        switch self {
        case .crimson:   return "FF5252"
        case .vermilion: return "FF793F"
        case .orange:    return "FF9F43"
        case .amber:     return "FDCB6E"
        case .yellow:    return "FFEAA7"
        case .brown:     return "A1887F"
        case .rust:      return "E67E22"
        case .burgundy:  return "B33771"
        case .magenta:   return "FF66CC"
        case .pink:      return "FD79A8"
        case .purple:    return "D980FA"
        case .indigo:    return "575FCF"
        case .violet:    return "686DE0"
        case .navy:      return "273C75"
        case .blue:      return "4DA1FF"
        case .skyBlue:   return "48DBFB"
        }
    }

    var deepColor: Color {
        switch self {
        case .crimson:   return Color(hex: "C23616")
        case .vermilion: return Color(hex: "E15F41")
        case .orange:    return Color(hex: "E67E22")
        case .amber:     return Color(hex: "F39C12")
        case .yellow:    return Color(hex: "F1C40F")
        case .brown:     return Color(hex: "8D6E63")
        case .rust:      return Color(hex: "D35400")
        case .burgundy:  return Color(hex: "833471")
        case .magenta:   return Color(hex: "C71585")
        case .pink:      return Color(hex: "E84393")
        case .purple:    return Color(hex: "8A2BE2")
        case .indigo:    return Color(hex: "3C40C6")
        case .violet:    return Color(hex: "4834D4")
        case .navy:      return Color(hex: "192A56")
        case .blue:      return Color(hex: "007AFF")
        case .skyBlue:   return Color(hex: "0ABDE3")
        }
    }
}

// MARK: - Pet Model
@Model
final class Pet {
    var id: UUID
    var name: String
    var species: String
    var breed: String
    var birthday: Date?
    var gender: String
    var isNeutered: Bool
    var avatarEmoji: String
    @Attribute(.externalStorage) var avatarImageData: Data?
    var microchipID: String
    var vetContact: String      // 向后兼容：存电话号码
    // ArkSchemaV24 兽医联系人结构化
    var vetClinicName: String
    var vetDoctorName: String
    var vetAddress: String
    var allergies: String
    var passportNumber: String
    var passportExpiryDate: Date?
    var formerName: String
    var lineageInfo: String
    var themeColorHex: String
    var homeDate: Date?
    var birthCountry: String
    var birthCity: String
    var foodBrand: String
    var restockDate: Date?
    var restockWeight: Double
    var dailyPortionGrams: Double
    var foodPrice: Double
    var isShared: Bool
    var ckRecordName: String
    var createdAt: Date
    var notes: String
    // Phase 9 扩展字段
    var coatColor: String
    var eyeColor: String
    // Phase 19 羁绊值
    var currentStreak: Int
    var lastCheckInDate: Date?
    // ArkSchemaV10 双轨制粮食追踪
    var foodTrackingModeRaw: String
    var casualOpenDate: Date?      // 佛系：开包日期
    var casualDurationDays: Int    // 佛系：预估能吃多少天（30/60/90/180）
    var foodReminderEnabled: Bool  // 粮仓：是否提醒补粮
    var foodReminderAdvanceDays: Int // 粮仓：断粮前几天提醒
    // ArkSchemaV11 独立椰子账户
    var coconutBalance: Int        // 该宠物的椰子余额
    // ArkSchemaV14 生命周期 — Rainbow Bridge
    var passedAwayDate: Date?      // 离世日期；nil = 在世
    // P2: 卡片风格（"classic" | "minimal"）
    var cardStyleRaw: String
    // ArkSchemaV23 步行周目标（km，0 = 未设置）
    var weeklyWalkGoalKm: Double
    /// ArkSchemaV26：性格标签 id，逗号分隔，最多 3 个（见 `PetPersonalityTag`）
    var personalityTagsRaw: String

    // Relationships
    @Relationship(deleteRule: .cascade) var expenseLogs: [PetExpenseLog]
    @Relationship(deleteRule: .cascade) var foodRecords: [PetFoodRecord]
    @Relationship(deleteRule: .cascade) var pottyLogs: [PetPottyLog]
    @Relationship(deleteRule: .cascade) var walkLogs: [PetWalkLog]
    @Relationship(deleteRule: .cascade) var hygieneLogs: [PetHygieneLog]
    @Relationship(deleteRule: .cascade) var milestones: [PetMilestone]
    @Relationship(deleteRule: .cascade) var weightLogs: [PetWeightLog]
    @Relationship(deleteRule: .cascade) var documents: [PetDocument]
    @Relationship(deleteRule: .cascade) var healthLogs: [PetHealthLog]
    @Relationship(deleteRule: .cascade) var careLogs: [PetCareLog]
    @Relationship(deleteRule: .cascade) var medications: [PetMedication]
    @Relationship(deleteRule: .cascade) var insurances: [PetInsurance]
    @Relationship(deleteRule: .cascade) var photoLogs: [PetPhotoLog]
    @Relationship(deleteRule: .cascade) var symptomLogs: [SymptomLog]
    @Relationship(deleteRule: .cascade) var heatCycleLogs: [HeatCycleLog]
    
    init(
        name: String = "",
        species: String = "狗",
        breed: String = "",
        birthday: Date? = nil,
        gender: String = "unknown",
        isNeutered: Bool = false,
        avatarEmoji: String = "🐾",
        themeColorHex: String = "FF6B6B",
        homeDate: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.breed = breed
        self.birthday = birthday
        self.gender = gender
        self.isNeutered = isNeutered
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = nil
        self.microchipID = ""
        self.vetContact = ""
        self.vetClinicName = ""
        self.vetDoctorName = ""
        self.vetAddress = ""
        self.allergies = ""
        self.passportNumber = ""
        self.passportExpiryDate = nil
        self.formerName = ""
        self.lineageInfo = ""
        self.themeColorHex = themeColorHex
        self.homeDate = homeDate
        self.birthCountry = ""
        self.birthCity = ""
        self.foodBrand = ""
        self.restockDate = nil
        self.restockWeight = 0
        self.dailyPortionGrams = 0
        self.foodPrice = 0
        self.isShared = false
        self.ckRecordName = ""
        self.createdAt = Date()
        self.notes = ""
        self.coatColor = ""
        self.eyeColor = ""
        self.currentStreak = 0
        self.lastCheckInDate = nil
        self.foodTrackingModeRaw = FoodTrackingMode.casual.rawValue
        self.casualOpenDate = nil
        self.casualDurationDays = 0
        self.foodReminderEnabled = false
        self.foodReminderAdvanceDays = 7
        self.coconutBalance = 0
        self.passedAwayDate = nil
        self.cardStyleRaw = "classic"
        self.weeklyWalkGoalKm = 0
        self.personalityTagsRaw = ""
        self.expenseLogs = []
        self.foodRecords = []
        self.pottyLogs = []
        self.walkLogs = []
        self.hygieneLogs = []
        self.milestones = []
        self.weightLogs = []
        self.documents = []
        self.healthLogs = []
        self.careLogs = []
        self.medications = []
        self.insurances = []
        self.photoLogs = []
        self.symptomLogs = []
        self.heatCycleLogs = []
    }
    
    // MARK: - Computed Properties
    
    var themeColor: PetThemeColor {
        PetThemeColor.allCases.first { $0.rawValue == themeColorHex.lowercased() } ?? .orange
    }
    
    var daysTogether: Int {
        guard let homeDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: homeDate, to: Date()).day ?? 0
    }

    /// 已选性格标签 id（有序，与 `personalityTagsRaw` 一致）
    var personalityTagIdList: [String] {
        personalityTagsRaw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// 日历筛选条、添加宠物物种等：SF Symbol 纯色剪影
    static func speciesSilhouetteSymbol(forSpecies species: String) -> String {
        switch species {
        case "狗": return "dog.fill"
        case "猫": return "cat.fill"
        case "兔子": return "hare.fill"
        case "仓鼠": return "circle.fill"
        case "鸟": return "bird.fill"
        default: return "pawprint.fill"
        }
    }

    var speciesSilhouetteSymbol: String { Self.speciesSilhouetteSymbol(forSpecies: species) }

    var ageText: String {
        guard let birthday else { return "未知" }
        let components = Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years > 0 {
            return months > 0 ? "\(years)岁\(months)月" : "\(years)岁"
        } else {
            return "\(months)个月"
        }
    }
    
    var humanEquivalentAge: Int {
        guard let birthday else { return 0 }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        switch species {
        case "狗":
            if years <= 0 { return 0 }
            if years == 1 { return 15 }
            if years == 2 { return 24 }
            return 24 + (years - 2) * 5
        case "猫":
            if years <= 0 { return 0 }
            if years == 1 { return 15 }
            if years == 2 { return 24 }
            return 24 + (years - 2) * 4
        default:
            return years
        }
    }
    
    var foodTrackingMode: FoodTrackingMode {
        get { FoodTrackingMode(rawValue: foodTrackingModeRaw) ?? .casual }
        set { foodTrackingModeRaw = newValue.rawValue }
    }

    // 佛系模式：预估耗尽日期
    var casualEstimatedRunOutDate: Date? {
        guard foodTrackingMode == .casual,
              let openDate = casualOpenDate,
              casualDurationDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: casualDurationDays, to: openDate)
    }

    // 佛系模式：距耗尽剩余天数
    var casualRemainingDays: Int? {
        guard let runOut = casualEstimatedRunOutDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: runOut).day ?? 0
        return max(0, days)
    }

    var remainingFoodGrams: Double {
        guard foodTrackingMode == .precise else { return 0 }
        guard restockWeight > 0 else { return 0 }
        guard let restockDate else { return restockWeight * 1000 }
        return max(0, (restockWeight * 1000) - foodConsumedSinceRestock)
    }

    var foodConsumedSinceRestock: Double {
        guard let restockDate else { return 0 }
        return careLogs
            .filter { $0.careType == .feeding && $0.date >= restockDate }
            .reduce(0) { total, log in
                total + (log.amountGrams > 0 ? log.amountGrams : dailyPortionGrams)
            }
    }
    
    var remainingFoodDays: Int {
        guard dailyPortionGrams > 0 else { return 0 }
        return Int(remainingFoodGrams / dailyPortionGrams)
    }
    
    var remainingFoodPercent: Double {
        guard restockWeight > 0 else { return 0 }
        return min(1.0, remainingFoodGrams / (restockWeight * 1000))
    }
    
    var estimatedRunOutDate: Date? {
        guard remainingFoodDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: remainingFoodDays, to: Date())
    }
    
    var genderSymbol: String {
        switch gender {
        case "male": return "♂"
        case "female": return "♀"
        default: return "⚧"
        }
    }
    
    var speciesEmoji: String {
        switch species {
        case "狗": return "🐕"
        case "猫": return "🐈"
        case "兔子": return "🐇"
        case "仓鼠": return "🐹"
        case "鸟": return "🦜"
        default: return "🐾"
        }
    }

    // MARK: - Rainbow Bridge（离世状态）
    var hasPassedAway: Bool { passedAwayDate != nil }

    /// 离世时的年龄文字（从生日到离世日期）
    var ageAtPassingText: String {
        guard let passed = passedAwayDate else { return ageText }
        guard let bday = birthday else { return "未知" }
        let comps = Calendar.current.dateComponents([.year, .month], from: bday, to: passed)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        if y > 0 { return m > 0 ? "\(y)岁\(m)月" : "\(y)岁" }
        return "\(m)个月"
    }

    /// 相伴天数（离世后固定为在世时的天数）
    var daysTogetherAtPassing: Int {
        guard let passed = passedAwayDate, let home = homeDate else { return daysTogether }
        return Calendar.current.dateComponents([.day], from: home, to: passed).day ?? 0
    }

    // MARK: - 清空活动记录（设置页 / 详情 / 实验室）

    /// 删除该宠物下所有活动类 SwiftData 记录，并移除 `relatedEntityId` 匹配的日历 `Event`（级联其 `Reminder`）。
    /// 保留基础档案字段与 `documents` / `insurances`。删除 Event 前会取消关联的本地通知。
    /// 同步重置连续打卡、清理该宠物的任务冷却与椰子收支明细（仅 `actorId` 匹配的条目）。
    func clearAllActivityRecords(in context: ModelContext) {
        let petIdStr = id.uuidString
        if let events = try? context.fetch(FetchDescriptor<Event>()) {
            for event in events where event.relatedEntityId == petIdStr {
                for reminder in event.reminders {
                    NotificationManager.shared.cancel(notificationId: reminder.notificationId)
                }
                context.delete(event)
            }
        }

        for log in Array(careLogs) { context.delete(log) }
        for log in Array(pottyLogs) { context.delete(log) }
        for log in Array(weightLogs) { context.delete(log) }
        for log in Array(expenseLogs) { context.delete(log) }
        for log in Array(hygieneLogs) { context.delete(log) }
        for log in Array(walkLogs) { context.delete(log) }
        for log in Array(healthLogs) { context.delete(log) }
        for log in Array(foodRecords) { context.delete(log) }
        for log in Array(milestones) { context.delete(log) }
        for log in Array(medications) { context.delete(log) }
        for log in Array(photoLogs) { context.delete(log) }

        currentStreak = 0
        lastCheckInDate = nil
        QuestManager.shared.clearPerPetAuxiliaryState(forPetId: id)
        context.safeSave()
    }
}
