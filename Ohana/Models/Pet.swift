//
//  Pet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Food Tracking Mode (ArkSchemaV10)
enum FoodTrackingMode: String, Codable, CaseIterable {
    case casual // 佛系：记录大概能吃多久，不扣克数
    case precise // 精准：精确克数库存倒计时

    var displayName: String {
        switch self {
        case .casual: "佛系估算"
        case .precise: "精准倒数"
        }
    }
}

// MARK: - Pet Theme Color (member palette — never reuse global primary lime/blue)
enum PetThemeColor: String, Codable, CaseIterable {
    // 16 non-primary, distinct, high-contrast colors
    case crimson, vermilion, orange, amber, yellow, brown, rust, burgundy
    case magenta, pink, purple, indigo, violet, navy, blue, skyBlue

    var color: Color {
        switch self {
        case .crimson: Color.petThemeCrimson
        case .vermilion: Color.petThemeVermilion
        case .orange: Color.petThemeOrange
        case .amber: Color.petThemeAmber
        case .yellow: Color.petThemeYellow
        case .brown: Color.petThemeBrown
        case .rust: Color.petThemeRust
        case .burgundy: Color.petThemeBurgundy
        case .magenta: Color.petThemeMagenta
        case .pink: Color.petThemePink
        case .purple: Color.petThemePurple
        case .indigo: Color.petThemeIndigo
        case .violet: Color.petThemeViolet
        case .navy: Color.petThemeNavy
        case .blue: Color.petThemeBlue
        case .skyBlue: Color.petThemeSkyBlue
        }
    }

    var hexValue: String {
        switch self {
        case .crimson: "FF5252"
        case .vermilion: "FF793F"
        case .orange: "FF9F43"
        case .amber: "FDCB6E"
        case .yellow: "FFEAA7"
        case .brown: "A1887F"
        case .rust: "E67E22"
        case .burgundy: "B33771"
        case .magenta: "FF66CC"
        case .pink: "FD79A8"
        case .purple: "D980FA"
        case .indigo: "575FCF"
        case .violet: "686DE0"
        case .navy: "273C75"
        case .blue: "94A3B8"
        case .skyBlue: "F472B6"
        }
    }

    var deepColor: Color {
        switch self {
        case .crimson: Color(hex: "C23616")
        case .vermilion: Color(hex: "E15F41")
        case .orange: Color(hex: "E67E22")
        case .amber: Color(hex: "F39C12")
        case .yellow: Color(hex: "F1C40F")
        case .brown: Color(hex: "8D6E63")
        case .rust: Color(hex: "D35400")
        case .burgundy: Color(hex: "833471")
        case .magenta: Color(hex: "C71585")
        case .pink: Color(hex: "E84393")
        case .purple: Color(hex: "8A2BE2")
        case .indigo: Color(hex: "3C40C6")
        case .violet: Color(hex: "4834D4")
        case .navy: Color(hex: "192A56")
        case .blue: Color(hex: "475569")
        case .skyBlue: Color(hex: "BE185D")
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
    var vetContact: String // 向后兼容：存电话号码
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
    // ArkSchemaV41：当前主粮类型，用于喂食打卡和计划默认值
    var mainFoodKindRaw: String = FeedFoodKind.dry.rawValue
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
    var casualOpenDate: Date? // 佛系：开包日期
    var casualDurationDays: Int // 佛系：预估能吃多少天（30/60/90/180）
    var foodReminderEnabled: Bool // 粮仓：是否提醒补粮
    var foodReminderAdvanceDays: Int // 粮仓：断粮前几天提醒
    // ArkSchemaV11 独立椰子账户
    var coconutBalance: Int // 该宠物的椰子余额
    // ArkSchemaV14 生命周期 — Rainbow Bridge
    var passedAwayDate: Date? // 离世日期；nil = 在世
    // P2: 卡片风格（"classic" | "minimal"）
    var cardStyleRaw: String
    // ArkSchemaV51：3D 破框卡片专用主体图，独立于全局头像
    @Attribute(.externalStorage) var cardPopoutImageData: Data?
    var cardPopoutSourceRaw: String?
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
        self.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            themeColorHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        self.homeDate = homeDate
        self.birthCountry = ""
        self.birthCity = ""
        self.foodBrand = ""
        self.restockDate = nil
        self.restockWeight = 0
        self.dailyPortionGrams = 0
        self.mainFoodKindRaw = FeedFoodKind.dry.rawValue
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
        self.cardPopoutImageData = nil
        self.cardPopoutSourceRaw = nil
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

    var safeThemeColorHex: String {
        OhanaThemeColorPolicy.normalizedMemberThemeHex(themeColorHex, fallback: OhanaThemeColorPolicy.petFallbackHex)
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
        case "狗": "dog.fill"
        case "猫": "cat.fill"
        case "兔子": "hare.fill"
        case "鱼": "fish.fill"
        case "爬宠": "lizard.fill"
        case "仓鼠": "circle.fill"
        case "鸟": "bird.fill"
        default: "pawprint.fill"
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

    var mainFoodKind: FeedFoodKind {
        get { FeedFoodKind(rawValue: mainFoodKindRaw) ?? .dry }
        set { mainFoodKindRaw = newValue.rawValue }
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
        feedStockSnapshotWithSharedSessions.remainingGrams
    }

    var foodConsumedSinceRestock: Double {
        FeedStockCalculator.mainConsumedSinceRestock(for: self, sharedCareSessions: feedStockSharedSessions)
    }

    var remainingFoodDays: Int {
        feedStockSnapshotWithSharedSessions.remainingDays
    }

    var remainingFoodPercent: Double {
        guard restockWeight > 0 else { return 0 }
        return min(1.0, remainingFoodGrams / (restockWeight * 1000))
    }

    var estimatedRunOutDate: Date? {
        feedStockSnapshotWithSharedSessions.runOutDate
    }

    private var feedStockSnapshotWithSharedSessions: FeedStockSnapshot {
        FeedStockCalculator.snapshot(for: self, sharedCareSessions: feedStockSharedSessions)
    }

    private var feedStockSharedSessions: [SharedCareSession]? {
        guard let context = modelContext else { return nil }
        let sessionIDs = Set(careLogs.compactMap { log -> UUID? in
            guard log.careType == .feeding else { return nil }
            return UUID(uuidString: log.sharedSessionId)
        })
        guard !sessionIDs.isEmpty else { return [] }

        let ids = Array(sessionIDs)
        let descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                ids.contains(session.id)
            }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[Pet] failed to fetch shared feed sessions for petId=\(id.uuidString): \(error.localizedDescription)",
                category: "Care"
            )
            return nil
        }
    }

    var genderSymbol: String {
        switch gender {
        case "male": "♂"
        case "female": "♀"
        default: "⚧"
        }
    }

    var speciesEmoji: String {
        switch species {
        case "狗": "🐕"
        case "猫": "🐈"
        case "鱼": "🐟"
        case "兔子": "🐇"
        case "爬宠": "🦎"
        case "仓鼠": "🐹"
        case "鸟": "🦜"
        default: "🐾"
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
}
