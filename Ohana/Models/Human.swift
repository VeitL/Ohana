//
//  Human.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Foundation

@Model
final class Human {
    var id: UUID
    var name: String
    var birthday: Date?
    var bloodType: String
    var avatarEmoji: String
    @Attribute(.externalStorage) var avatarImageData: Data?
    var role: String
    var appleUserIdentifier: String
    var notes: String
    var createdAt: Date
    // U13: 国籍 / 城市字段
    var nationality: String
    var city: String
    // ArkSchemaV11 独立椰子账户
    var coconutBalance: Int        // 该人类成员的椰子余额
    // ArkSchemaV13 首页卡堆显示开关
    var shouldShowOnHome: Bool
    // ArkSchemaV15：正式主题色字段（迁移自 notes 字段 hack）
    var themeColorHex: String
    // ArkSchemaV16：隐私控制字段 + 身体数据
    var privateFieldsRaw: String
    var heightCm: Double
    // Relationships
    @Relationship(deleteRule: .cascade) var weightLogs: [HumanWeightLog]
    @Relationship(deleteRule: .cascade) var workoutLogs: [HumanWorkoutLog]

    init(
        name: String = "",
        birthday: Date? = nil,
        bloodType: String = "",
        avatarEmoji: String = "👤",
        role: String = "owner",
        nationality: String = "",
        city: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.birthday = birthday
        self.bloodType = bloodType
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = nil
        self.role = role
        self.appleUserIdentifier = ""
        self.notes = ""
        self.createdAt = Date()
        self.nationality = nationality
        self.city = city
        self.coconutBalance = 0
        self.shouldShowOnHome = false
        self.themeColorHex = "4338FF"
        self.privateFieldsRaw = ""
        self.heightCm = 0
        self.weightLogs = []
        self.workoutLogs = []
    }
    
    var ageText: String {
        guard let birthday else { return "未知" }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return "\(years)岁"
    }
    
    var roleText: String {
        switch role {
        case "owner": return "主人"
        case "editor": return "编辑"
        case "viewer": return "查看"
        default: return role
        }
    }

    // MARK: - 隐私控制（FIX 1）
    var privateFields: Set<String> {
        get { Set(privateFieldsRaw.split(separator: ",").map(String.init)) }
        set { privateFieldsRaw = newValue.sorted().joined(separator: ",") }
    }

    /// 判断某字段是否对非本人隐藏
    /// - Parameter currentActiveHumanId: 当前查看者的 Human.id（来自 @AppStorage）
    func isPrivate(_ field: String, viewedBy currentId: UUID?) -> Bool {
        guard currentId != self.id else { return false }
        return privateFields.contains(field)
    }
}
