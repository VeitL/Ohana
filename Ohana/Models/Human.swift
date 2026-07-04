//
//  Human.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Foundation
import SwiftData

enum HumanPrivateField: String, CaseIterable, Identifiable {
    case weight
    case workout
    case medication
    case wishlist
    case expense
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "体重"
        case .workout: "运动"
        case .medication: "吃药提醒"
        case .wishlist: "椰子资产与心愿"
        case .expense: "花费"
        case .note: "备注"
        }
    }
}

nonisolated enum HumanLocalPrivacyPolicy {
    // First release is local-first and single-device oriented. Human privacy/PIN
    // remains stored for future multi-device identity work, but is not enforced
    // or surfaced in the ordinary local account switch flow.
    static let isEnabled = false
}

nonisolated enum HumanProfileOptions {
    static let permissionRoles: [(key: String, title: String, description: String, icon: String)] = [
        ("owner", "管理者", "可管理家庭资料与核心设置", "crown.fill"),
        ("member", "成员", "可进行日常记录与照护打卡", "person.fill")
    ]

    static let genderOptions: [(key: String, icon: String)] = [
        ("女", "♀"),
        ("男", "♂"),
        ("非二元", "⚧"),
        ("不透露", "•")
    ]

    static func normalizedRole(_ raw: String) -> String {
        raw == "owner" ? "owner" : "member"
    }

    static func normalizedGender(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "male", "man", "boy", "男":
            "男"
        case "female", "woman", "girl", "女":
            "女"
        case "nonbinary", "non-binary", "nb", "非二元":
            "非二元"
        case "prefer not to say", "private", "unknown", "不透露", "未知":
            "不透露"
        case "":
            ""
        default:
            raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func storedGenderIdentity(_ raw: String) -> String? {
        let normalized = normalizedGender(raw)
        return normalized.isEmpty ? nil : normalized
    }

    static func visibleNoteParts(from notes: String) -> [String] {
        notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.hasPrefix("性别:") && !$0.hasPrefix("关系:") }
    }

    static func genderMetadata(from notes: String) -> String {
        metadataValue(prefix: "性别:", from: notes).map(normalizedGender) ?? ""
    }

    private static func metadataValue(prefix: String, from notes: String) -> String? {
        guard let range = notes.range(of: prefix) else { return nil }
        let tail = notes[range.upperBound...]
        let value = tail.split(separator: "｜", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum HumanPermissionRole {
    static func title(for raw: String) -> String {
        switch HumanProfileOptions.normalizedRole(raw) {
        case "owner":
            "管理者"
        default:
            "成员"
        }
    }

    static func description(for raw: String) -> String {
        switch HumanProfileOptions.normalizedRole(raw) {
        case "owner":
            "可管理家庭资料与核心设置"
        default:
            "可进行日常记录与照护打卡"
        }
    }

    static func icon(for raw: String) -> String {
        switch HumanProfileOptions.normalizedRole(raw) {
        case "owner":
            "crown.fill"
        default:
            "person.fill"
        }
    }
}

nonisolated enum HumanGenderIdentity {
    static func title(for raw: String) -> String {
        let normalized = HumanProfileOptions.normalizedGender(raw)
        switch normalized {
        case "女", "男", "非二元", "不透露":
            return normalized
        default:
            return normalized.isEmpty ? "未填写" : normalized
        }
    }

    static func icon(for raw: String) -> String {
        switch HumanProfileOptions.normalizedGender(raw) {
        case "女":
            "♀"
        case "男":
            "♂"
        case "非二元":
            "⚧"
        default:
            "•"
        }
    }

    static func fallbackAvatarEmoji(for raw: String) -> String {
        switch HumanProfileOptions.normalizedGender(raw) {
        case "女":
            "👩"
        case "男":
            "👨"
        default:
            "👤"
        }
    }
}

@Model
final class Human {
    var id: UUID
    var name: String
    var birthday: Date?
    var bloodType: String
    var avatarEmoji: String
    @Attribute(.externalStorage) var avatarImageData: Data?
    var avatarAttachmentStateRaw: String = MemberAvatarAttachmentState.unknown.rawValue
    var avatarImageSignature: String = ""
    var role: String
    // Legacy local field retained for lightweight store compatibility. No Sign in with Apple flow writes it,
    // and new backups intentionally omit it.
    var appleUserIdentifier: String
    var notes: String
    var createdAt: Date
    // Legacy recycle-bin columns kept only for stores that already migrated through the retired deletion model.
    // Active product code must not read or write these fields.
    var trashedAt: Date?
    var trashExpiresAt: Date?
    var trashBatchId: String = ""
    var trashedByHumanId: String = ""
    // U13: 国籍 / 城市字段
    var nationality: String
    var city: String
    // ArkSchemaV11 独立椰子账户
    var coconutBalance: Int // 该人类成员的椰子余额
    // ArkSchemaV13 首页卡堆显示开关
    var shouldShowOnHome: Bool
    // ArkSchemaV15：正式主题色字段（迁移自 notes 字段 hack）
    var themeColorHex: String
    // ArkSchemaV61：正式性别/身份字段（兼容读取旧 notes 中的 "性别:" 元数据）
    var genderIdentityRaw: String?
    // ArkSchemaV16：隐私控制字段 + 身体数据
    var privateFieldsRaw: String
    var heightCm: Double
    // ArkSchemaV35：MBTI（可选，空字符串表示未设置）
    var mbti: String = ""
    // ArkSchemaV40：本地人类账户 4 位 PIN（只存 salted hash，不存明文）
    var pinHash: String = ""
    var pinSalt: String = ""
    var pinFailedAttempts: Int = 0
    var pinLockedUntil: Date?
    // ArkSchemaV43：人类纪念模式生命周期；nil = 在世
    var passedAwayDate: Date?
    // Relationships
    @Relationship(deleteRule: .cascade) var weightLogs: [HumanWeightLog]
    @Relationship(deleteRule: .cascade) var workoutLogs: [HumanWorkoutLog]
    // ArkSchemaV56：人类体检指标追踪（TSH/HbA1c/血压等单项数值时间序列）
    @Relationship(deleteRule: .cascade) var healthMetricLogs: [HumanHealthMetricLog] = []

    init(
        name: String = "",
        birthday: Date? = nil,
        bloodType: String = "",
        avatarEmoji: String = "👤",
        role: String = "owner",
        genderIdentityRaw: String = "",
        nationality: String = "",
        city: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.birthday = birthday
        self.bloodType = bloodType
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = nil
        self.avatarAttachmentStateRaw = MemberAvatarAttachmentState.absent.rawValue
        self.avatarImageSignature = ""
        self.role = HumanProfileOptions.normalizedRole(role)
        self.appleUserIdentifier = ""
        self.notes = ""
        self.createdAt = Date()
        self.nationality = nationality
        self.city = city
        self.coconutBalance = 0
        self.shouldShowOnHome = true
        self.themeColorHex = OhanaThemeColorPolicy.humanFallbackHex
        self.genderIdentityRaw = HumanProfileOptions.storedGenderIdentity(genderIdentityRaw)
        self.privateFieldsRaw = ""
        self.heightCm = 0
        self.mbti = ""
        self.pinHash = ""
        self.pinSalt = ""
        self.pinFailedAttempts = 0
        self.pinLockedUntil = nil
        self.passedAwayDate = nil
        self.weightLogs = []
        self.workoutLogs = []
    }

    var safeThemeColorHex: String {
        OhanaThemeColorPolicy.normalizedMemberThemeHex(themeColorHex, fallback: OhanaThemeColorPolicy.humanFallbackHex)
    }

    var avatarAttachmentState: MemberAvatarAttachmentState {
        get { MemberAvatarAttachmentState(rawValue: avatarAttachmentStateRaw) ?? .unknown }
        set { avatarAttachmentStateRaw = newValue.rawValue }
    }

    var hasAvatarImageAttachment: Bool {
        canAttemptAvatarImageAttachmentLoad
    }

    var canAttemptAvatarImageAttachmentLoad: Bool {
        avatarAttachmentState != .absent
    }

    var avatarThumbnailSignature: String {
        if !avatarImageSignature.isEmpty {
            return avatarImageSignature
        }
        guard canAttemptAvatarImageAttachmentLoad else { return "" }
        return "legacy:\(id.uuidString):avatar:\(createdAt.timeIntervalSince1970)"
    }

    var needsAvatarAttachmentIndexRepair: Bool {
        avatarAttachmentState == .unknown || (hasAvatarImageAttachment && avatarImageSignature.isEmpty)
    }

    func updateAvatarImageData(_ data: Data?) {
        avatarImageData = data
        updateAvatarAttachmentIndex(for: data)
    }

    @discardableResult
    func repairAvatarAttachmentIndexIfNeeded() -> Bool {
        guard needsAvatarAttachmentIndexRepair else { return false }
        updateAvatarAttachmentIndex(for: avatarImageData)
        return true
    }

    @discardableResult
    func backfillAvatarAttachmentPresence(hasData: Bool) -> Bool {
        if hasData {
            guard avatarAttachmentState != .present else { return false }
            avatarAttachmentState = .present
            return true
        }

        guard avatarAttachmentState != .absent || !avatarImageSignature.isEmpty else { return false }
        avatarAttachmentState = .absent
        avatarImageSignature = ""
        return true
    }

    private func updateAvatarAttachmentIndex(for data: Data?) {
        avatarAttachmentState = data == nil ? .absent : .present
        avatarImageSignature = data.map(MediaPayloadSignature.signature(for:)) ?? ""
    }

    var ageText: String {
        guard let birthday else { return "未知" }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return "\(years)岁"
    }

    /// 有生日时用于首页钱包等胶囊（语言由 `isEnglish` 决定）
    func walletAgeChip(isEnglish: Bool) -> String? {
        guard let b = birthday else { return nil }
        let years = Calendar.current.dateComponents([.year], from: b, to: Date()).year ?? 0
        if isEnglish {
            if years >= 1 { return "\(years) yrs young" }
            return "Under 1 ✨"
        }
        if years >= 1 { return "\(years)岁" }
        return "不满1岁"
    }

    func walletAgeChip(l: L10n) -> String? {
        guard let b = birthday else { return nil }
        let years = Calendar.current.dateComponents([.year], from: b, to: Date()).year ?? 0
        if years >= 1 {
            return l.tr(zh: "\(years)岁", en: "\(years) yrs young", de: "\(years) J. jung")
        }
        return l.tr(zh: "不满1岁", en: "Under 1 ✨", de: "Unter 1 ✨")
    }

    /// 阳历十二星座（与 `AddHumanWizardView` 向导一致）
    static func westernZodiacChinese(for date: Date) -> String {
        let c = Calendar.current
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        if (m == 12 && d >= 22) || (m == 1 && d <= 19) { return "摩羯座" }
        if (m == 1 && d >= 20) || (m == 2 && d <= 18) { return "水瓶座" }
        if (m == 2 && d >= 19) || (m == 3 && d <= 20) { return "双鱼座" }
        if (m == 3 && d >= 21) || (m == 4 && d <= 19) { return "白羊座" }
        if (m == 4 && d >= 20) || (m == 5 && d <= 20) { return "金牛座" }
        if (m == 5 && d >= 21) || (m == 6 && d <= 21) { return "双子座" }
        if (m == 6 && d >= 22) || (m == 7 && d <= 22) { return "巨蟹座" }
        if (m == 7 && d >= 23) || (m == 8 && d <= 22) { return "狮子座" }
        if (m == 8 && d >= 23) || (m == 9 && d <= 22) { return "处女座" }
        if (m == 9 && d >= 23) || (m == 10 && d <= 23) { return "天秤座" }
        if (m == 10 && d >= 24) || (m == 11 && d <= 21) { return "天蝎座" }
        if (m == 11 && d >= 22) || (m == 12 && d <= 21) { return "射手座" }
        return "摩羯座"
    }

    /// 英文星座名（与 `westernZodiacChinese` 分界一致）
    static func westernZodiacEnglish(for date: Date) -> String {
        let c = Calendar.current
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        if (m == 12 && d >= 22) || (m == 1 && d <= 19) { return "Capricorn" }
        if (m == 1 && d >= 20) || (m == 2 && d <= 18) { return "Aquarius" }
        if (m == 2 && d >= 19) || (m == 3 && d <= 20) { return "Pisces" }
        if (m == 3 && d >= 21) || (m == 4 && d <= 19) { return "Aries" }
        if (m == 4 && d >= 20) || (m == 5 && d <= 20) { return "Taurus" }
        if (m == 5 && d >= 21) || (m == 6 && d <= 21) { return "Gemini" }
        if (m == 6 && d >= 22) || (m == 7 && d <= 22) { return "Cancer" }
        if (m == 7 && d >= 23) || (m == 8 && d <= 22) { return "Leo" }
        if (m == 8 && d >= 23) || (m == 9 && d <= 22) { return "Virgo" }
        if (m == 9 && d >= 23) || (m == 10 && d <= 23) { return "Libra" }
        if (m == 10 && d >= 24) || (m == 11 && d <= 21) { return "Scorpio" }
        if (m == 11 && d >= 22) || (m == 12 && d <= 21) { return "Sagittarius" }
        return "Capricorn"
    }

    static func westernZodiacGerman(for date: Date) -> String {
        let c = Calendar.current
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        if (m == 12 && d >= 22) || (m == 1 && d <= 19) { return "Steinbock" }
        if (m == 1 && d >= 20) || (m == 2 && d <= 18) { return "Wassermann" }
        if (m == 2 && d >= 19) || (m == 3 && d <= 20) { return "Fische" }
        if (m == 3 && d >= 21) || (m == 4 && d <= 19) { return "Widder" }
        if (m == 4 && d >= 20) || (m == 5 && d <= 20) { return "Stier" }
        if (m == 5 && d >= 21) || (m == 6 && d <= 21) { return "Zwillinge" }
        if (m == 6 && d >= 22) || (m == 7 && d <= 22) { return "Krebs" }
        if (m == 7 && d >= 23) || (m == 8 && d <= 22) { return "Löwe" }
        if (m == 8 && d >= 23) || (m == 9 && d <= 22) { return "Jungfrau" }
        if (m == 9 && d >= 23) || (m == 10 && d <= 23) { return "Waage" }
        if (m == 10 && d >= 24) || (m == 11 && d <= 21) { return "Skorpion" }
        if (m == 11 && d >= 22) || (m == 12 && d <= 21) { return "Schütze" }
        return "Steinbock"
    }

    static func westernZodiacDisplay(for date: Date, isEnglish: Bool) -> String {
        isEnglish ? westernZodiacEnglish(for: date) : westernZodiacChinese(for: date)
    }

    static func westernZodiacDisplay(for date: Date, l: L10n) -> String {
        switch l.languageCode {
        case "de":
            westernZodiacGerman(for: date)
        case "en":
            westernZodiacEnglish(for: date)
        default:
            westernZodiacChinese(for: date)
        }
    }

    var roleText: String {
        HumanPermissionRole.title(for: role)
    }

    // MARK: - Memorial Mode
    var hasPassedAway: Bool { passedAwayDate != nil }

    var ageAtPassingText: String {
        guard let passedAwayDate else { return ageText }
        guard let birthday else { return "未知" }
        let years = max(0, Calendar.current.dateComponents([.year], from: birthday, to: passedAwayDate).year ?? 0)
        if years >= 1 { return "\(years)岁" }
        return "不满1岁"
    }

    var daysTogetherAtPassing: Int {
        guard let passedAwayDate else {
            return max(0, Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0)
        }
        return max(0, Calendar.current.dateComponents([.day], from: createdAt, to: passedAwayDate).day ?? 0)
    }

    var genderRaw: String {
        let stored = HumanProfileOptions.normalizedGender(genderIdentityRaw ?? "")
        return stored.isEmpty ? HumanProfileOptions.genderMetadata(from: notes) : stored
    }

    // MARK: - 隐私控制（FIX 1）
    var privateFields: Set<String> {
        get { Set(privateFieldsRaw.split(separator: ",").map(String.init)) }
        set { privateFieldsRaw = newValue.sorted().joined(separator: ",") }
    }

    /// 判断某字段是否对非本人隐藏
    /// - Parameter currentActiveHumanId: 当前查看者的 Human.id（来自 @AppStorage）
    func isPrivate(_ field: String, viewedBy currentId: UUID?) -> Bool {
        guard HumanLocalPrivacyPolicy.isEnabled else { return false }
        guard let privateField = HumanPrivateField(rawValue: field) else {
            guard currentId != self.id else { return false }
            return privateFields.contains(field)
        }
        return isPrivate(privateField, viewedBy: currentId)
    }

    func isPrivate(_ field: HumanPrivateField, viewedBy currentId: UUID?) -> Bool {
        guard HumanLocalPrivacyPolicy.isEnabled else { return false }
        guard currentId != self.id else { return false }
        return privateFields.contains(field.rawValue)
    }

    func setPrivate(_ field: HumanPrivateField, _ isPrivate: Bool) {
        var fields = privateFields
        if isPrivate {
            fields.insert(field.rawValue)
        } else {
            fields.remove(field.rawValue)
        }
        privateFields = fields
    }
}
