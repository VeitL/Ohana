//
//  AchievementManager.swift
//  Ohana
//
//  P1-1: 成就徽章体系 — 7 枚初始成就，纯计算无副作用

import Foundation
import SwiftUI

// MARK: - Achievement Definition

struct Achievement: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    let description: String
    let color: Color
    var isUnlocked: Bool
    var unlockedAt: Date?

    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id && lhs.isUnlocked == rhs.isUnlocked
    }
}

// MARK: - Achievement Manager

@Observable
final class AchievementManager {
    static let shared = AchievementManager()

    var achievements: [Achievement] = []
    var newlyUnlocked: [Achievement] = []

    private init() {}

    // 计算给定宠物的所有成就状态（异步，不阻塞主线程）
    func evaluate(for pet: Pet) async {
        let computed = await Task.detached(priority: .utility) {
            Self.compute(for: pet)
        }.value

        await MainActor.run {
            let prev = self.achievements
            self.achievements = computed
            // 找出本次新解锁的
            self.newlyUnlocked = computed.filter { badge in
                badge.isUnlocked &&
                !(prev.first(where: { $0.id == badge.id })?.isUnlocked ?? false)
            }
        }
    }

    // MARK: - Pure computation

    // MARK: - 人宠联动成就（需要 HealthKit 数据）

    /// 计算跨维度成就（需要人类 HealthKit 数据作为额外输入）
    static func computeBonded(for pet: Pet, humanDistanceKm: Double) -> [Achievement] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 今日宠物遛狗总距离（km）
        let petTodayDistanceKm = pet.walkLogs
            .filter { calendar.isDate($0.startDate, inSameDayAs: today) }
            .reduce(0.0) { $0 + $1.distanceMeters / 1000.0 }

        // 同甘共苦：主人今日步行距离 ≥ 宠物今日遛狗距离（且宠物有遛狗记录）
        let bondedWalk = Achievement(
            id: "bonded_walk",
            emoji: "🤝",
            title: "同甘共苦",
            description: "今天你走的路不比它少 — 与宠物共同完成今日运动",
            color: Color.goYellow,
            isUnlocked: petTodayDistanceKm > 0.1 && humanDistanceKm >= petTodayDistanceKm
        )

        // 步数冠军：主人今日步数距离超过宠物遛狗距离 1.5 倍
        let stepChampion = Achievement(
            id: "step_champion",
            emoji: "👟",
            title: "步数冠军",
            description: "今天你走的路是宠物的 1.5 倍以上",
            color: Color.goLime,
            isUnlocked: petTodayDistanceKm > 0.1 && humanDistanceKm >= petTodayDistanceKm * 1.5
        )

        return [bondedWalk, stepChampion]
    }

    static func compute(for pet: Pet) -> [Achievement] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // F5: 预计算 — 只过滤最近 7 天的日志，避免对全量数据做 N 次 isDate(inSameDayAs:)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let recentPottyLogs = pet.pottyLogs.filter { $0.date >= sevenDaysAgo }
        let recentWalkLogs  = pet.walkLogs.filter  { $0.startDate >= sevenDaysAgo }

        // 预计算"今天"标志（用于多个成就复用）
        let hasTodayHealth  = pet.healthLogs.contains  { calendar.isDateInToday($0.date) }
        let hasTodayHygiene = pet.hygieneLogs.contains  { calendar.isDateInToday($0.date) }
        let hasTodayPotty   = recentPottyLogs.contains  { calendar.isDateInToday($0.date) }

        // 1. 🔥 钢铁肠胃：连续 7 天每天有 perfectPoop
        let ironGut: Achievement = {
            var streak = true
            for i in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { streak = false; break }
                let has = recentPottyLogs.contains {
                    calendar.isDate($0.date, inSameDayAs: day) && $0.pottyType == .perfectPoop
                }
                if !has { streak = false; break }
            }
            return Achievement(id: "iron_gut", emoji: "💪", title: "钢铁肠胃",
                               description: "连续 7 天每天都有完美便便记录",
                               color: Color.goTeal, isUnlocked: streak)
        }()

        // 2. 🏃 铁脚板：累计遛狗 >= 100km
        let ironPaw: Achievement = {
            let total = pet.walkLogs.reduce(0.0) { $0 + $1.distanceMeters }
            return Achievement(id: "iron_paw", emoji: "🏃", title: "铁脚板",
                               description: "累计遛狗总距离达到 100km",
                               color: Color.goLime, isUnlocked: total >= 100_000)
        }()

        // 3. 📅 连续巡岛：连续 7 天都有 walkLog
        let walkStreak: Achievement = {
            var streak = true
            for i in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { streak = false; break }
                let has = recentWalkLogs.contains { calendar.isDate($0.startDate, inSameDayAs: day) }
                if !has { streak = false; break }
            }
            return Achievement(id: "walk_streak", emoji: "📅", title: "连续巡岛",
                               description: "连续 7 天都有遛狗记录",
                               color: Color.goYellow, isUnlocked: streak)
        }()

        // 4. 💎 健康达人：30 天内无 emergency / surgery healthLog
        let healthHero: Achievement = {
            let cutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let hasEmergency = pet.healthLogs.contains {
                $0.date >= cutoff && ($0.type == "emergency" || $0.type == "surgery")
            }
            return Achievement(id: "health_hero", emoji: "💎", title: "健康达人",
                               description: "30 天内无紧急就医或手术记录",
                               color: Color.goMint, isUnlocked: !hasEmergency && !pet.healthLogs.isEmpty)
        }()

        // 5. 🍗 营养师：连续记录喂食 14 天（foodRecords 中最近记录间隔 ≤ 1天）
        let nutritionist: Achievement = {
            let sorted = pet.foodRecords.sorted { $0.startDate < $1.startDate }
            guard sorted.count >= 2 else {
                return Achievement(id: "nutritionist", emoji: "🍗", title: "营养师",
                                   description: "坚持记录喂食信息超过 14 天",
                                   color: Color.goOrange, isUnlocked: false)
            }
            let first = sorted.first!.startDate
            let last = sorted.last!.startDate
            let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
            return Achievement(id: "nutritionist", emoji: "🍗", title: "营养师",
                               description: "坚持记录喂食信息超过 14 天",
                               color: Color.goOrange, isUnlocked: days >= 14)
        }()

        // 6. 🎂 生日快乐：今天是宠物生日
        let happyBirthday: Achievement = {
            var unlocked = false
            if let birthday = pet.birthday {
                let bComp = calendar.dateComponents([.month, .day], from: birthday)
                let tComp = calendar.dateComponents([.month, .day], from: now)
                unlocked = bComp.month == tComp.month && bComp.day == tComp.day
            }
            return Achievement(id: "happy_birthday", emoji: "🎂", title: "生日快乐",
                               description: "在宠物生日当天打开 Ohana",
                               color: Color.goRed, isUnlocked: unlocked)
        }()

        // 7. 🗓️ 相伴百日：daysTogether >= 100
        let hundredDays: Achievement = {
            return Achievement(id: "hundred_days", emoji: "🗓️", title: "相伴百日",
                               description: "与宠物共同生活超过 100 天",
                               color: Color.goCardBlue, isUnlocked: pet.daysTogether >= 100)
        }()

        // 8. 📝 第一步：拥有至少一条任意记录（健康/排泄/遛狗/护理）
        let firstRecord: Achievement = {
            let hasAny = !pet.healthLogs.isEmpty || !pet.pottyLogs.isEmpty
                || !pet.walkLogs.isEmpty || !pet.hygieneLogs.isEmpty
            return Achievement(id: "first_record", emoji: "📝", title: "第一步",
                               description: "完成第一条宠物记录",
                               color: Color.goCardCyan, isUnlocked: hasAny)
        }()

        // 9. ✅ 今日全勤：今天完成了至少一次打卡
        let dayOneCheckin: Achievement = {
            return Achievement(id: "day_one_checkin", emoji: "✅", title: "今日全勤",
                               description: "今天至少完成了一次打卡记录",
                               color: Color.goTeal, isUnlocked: hasTodayHealth || hasTodayHygiene || hasTodayPotty)
        }()

        // 10. 🤝 老朋友：使用 Ohana 超过 7 天（基于 pet.createdAt）
        let oldFriend: Achievement = {
            let daysSinceCreated = calendar.dateComponents([.day], from: pet.createdAt, to: now).day ?? 0
            return Achievement(id: "old_friend", emoji: "🤝", title: "老朋友",
                               description: "与 Ohana 相伴超过 7 天",
                               color: Color.goPrimary, isUnlocked: daysSinceCreated >= 7)
        }()

        // 11. 🐾 长跑健将：单次遛狗超过 5km
        let longRunner: Achievement = {
            let has5km = pet.walkLogs.contains { $0.distanceMeters >= 5000 }
            return Achievement(id: "long_runner", emoji: "🐾", title: "长跑健将",
                               description: "单次遛狗距离超过 5km",
                               color: Color.goLime, isUnlocked: has5km)
        }()

        // 12. 💊 坚持到底：完成至少一个疗程用药（有 endDate 且已过期的药）
        let medicationComplete: Achievement = {
            let completed = pet.medications.contains {
                guard let end = $0.endDate else { return false }
                return end < now && $0.isActive
            }
            return Achievement(id: "medication_complete", emoji: "💊", title: "坚持到底",
                               description: "认真完成了一个完整的用药疗程",
                               color: Color.goTeal, isUnlocked: completed)
        }()

        // 13. 📸 拍照达人：上传 20 张以上照片
        let photoEnthusiast: Achievement = {
            return Achievement(id: "photo_enthusiast", emoji: "📸", title: "拍照达人",
                               description: "为宠物上传了 20 张以上照片",
                               color: Color.goPrimary, isUnlocked: pet.photoLogs.count >= 20)
        }()

        // 14. 💰 记账能手：累计记录 10 条以上花费
        let expenseTracker: Achievement = {
            return Achievement(id: "expense_tracker", emoji: "💰", title: "记账能手",
                               description: "累计记录了 10 条以上花费",
                               color: Color.goYellow, isUnlocked: pet.expenseLogs.count >= 10)
        }()

        // 15. 🏋️ 体重管理师：累计体重记录 7 条以上
        let weightManager: Achievement = {
            return Achievement(id: "weight_manager", emoji: "🏋️", title: "体重管理师",
                               description: "坚持记录体重，累计超过 7 条记录",
                               color: Color.goCardBlue, isUnlocked: pet.weightLogs.count >= 7)
        }()

        return [ironGut, ironPaw, walkStreak, healthHero, nutritionist, happyBirthday, hundredDays,
                firstRecord, dayOneCheckin, oldFriend,
                longRunner, medicationComplete, photoEnthusiast, expenseTracker, weightManager]
    }
}
