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
    case lime, orange, primary, teal, yellow, red, purple, blue, mint, pink
    
    var color: Color {
        switch self {
        case .lime:    return Color(hex: "C8FF00")  // goLime
        case .orange:  return Color(hex: "FF8C42")  // goOrange
        case .primary: return Color(hex: "4338FF")  // goPrimary
        case .teal:    return Color(hex: "00D4AA")  // goTeal
        case .yellow:  return Color(hex: "FFF44F")  // goYellow
        case .red:     return Color(hex: "FF4757")  // goRed
        case .purple:  return Color(hex: "A78BFA")  // goPurple
        case .blue:    return Color(hex: "5B6AFF")  // goBlue
        case .mint:    return Color(hex: "80FFEA")  // goMint
        case .pink:    return Color(hex: "FF6B9D")  // goPink
        }
    }
    
    var hexValue: String {
        switch self {
        case .lime:    return "C8FF00"
        case .orange:  return "FF8C42"
        case .primary: return "4338FF"
        case .teal:    return "00D4AA"
        case .yellow:  return "FFF44F"
        case .red:     return "FF4757"
        case .purple:  return "A78BFA"
        case .blue:    return "5B6AFF"
        case .mint:    return "80FFEA"
        case .pink:    return "FF6B9D"
        }
    }

    var deepColor: Color {
        switch self {
        case .lime:    return Color(hex: "8FB800")
        case .orange:  return Color(hex: "CC5500")
        case .primary: return Color(hex: "2218CC")
        case .teal:    return Color(hex: "008870")
        case .yellow:  return Color(hex: "CCB800")
        case .red:     return Color(hex: "CC1A2A")
        case .purple:  return Color(hex: "7C3AED")
        case .blue:    return Color(hex: "3344CC")
        case .mint:    return Color(hex: "44CCAA")
        case .pink:    return Color(hex: "CC3366")
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
    var vetContact: String
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
    // ArkSchemaV11 独立椰子账户
    var coconutBalance: Int        // 该宠物的椰子余额
    // ArkSchemaV14 生命周期 — Rainbow Bridge
    var passedAwayDate: Date?      // 离世日期；nil = 在世
    // P2: 卡片风格（"classic" | "minimal"）
    var cardStyleRaw: String
    
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
        self.coconutBalance = 0
        self.passedAwayDate = nil
        self.cardStyleRaw = "classic"
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
    }
    
    // MARK: - Computed Properties
    
    var themeColor: PetThemeColor {
        PetThemeColor.allCases.first { $0.rawValue == themeColorHex.lowercased() } ?? .orange
    }
    
    var daysTogether: Int {
        guard let homeDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: homeDate, to: Date()).day ?? 0
    }
    
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
        guard dailyPortionGrams > 0, restockWeight > 0 else { return 0 }
        guard let restockDate else { return restockWeight * 1000 }
        let daysSinceRestock = Calendar.current.dateComponents([.day], from: restockDate, to: Date()).day ?? 0
        let consumed = Double(daysSinceRestock) * dailyPortionGrams
        return max(0, (restockWeight * 1000) - consumed)
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
}
