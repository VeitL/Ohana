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

struct AchievementComputationContext {
    var allPets: [Pet] = []
    var electronicPets: [OasisElectronicPet] = []
    var critterFragments: [OasisCritterFragmentBalance] = []
    var critterActionLogs: [OasisCritterActionLog] = []
    var gachaOwnedItems: [GachaOwnedItem] = []
    var gachaDrawLogs: [GachaDrawLog] = []

    static let empty = AchievementComputationContext()

    var includesGlobalAchievements: Bool {
        !allPets.isEmpty
            || !electronicPets.isEmpty
            || !critterFragments.isEmpty
            || !critterActionLogs.isEmpty
            || !gachaOwnedItems.isEmpty
            || !gachaDrawLogs.isEmpty
    }
}

// MARK: - Achievement Manager

@Observable
final class AchievementManager {
    var achievements: [Achievement] = []
    var newlyUnlocked: [Achievement] = []

    init() {}

    // 计算给定宠物的所有成就状态（异步，不阻塞主线程）
    func evaluate(for pet: Pet) async {
        let computed = Self.compute(for: pet)

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
            color: Color.goOrange,
            isUnlocked: petTodayDistanceKm > 0.1 && humanDistanceKm >= petTodayDistanceKm * 1.5
        )

        return [bondedWalk, stepChampion]
    }

    static func compute(for pet: Pet, context: AchievementComputationContext = .empty) -> [Achievement] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let allPets = context.allPets.isEmpty ? [pet] : context.allPets
        let livePets = allPets.filter { !$0.hasPassedAway }

        // F5: 预计算 — 只过滤最近 7 天的日志，避免对全量数据做 N 次 isDate(inSameDayAs:)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let recentPottyLogs = pet.pottyLogs.filter { $0.date >= sevenDaysAgo }
        let recentWalkLogs = pet.walkLogs.filter { $0.startDate >= sevenDaysAgo }
        let mainFeedLogs = pet.careLogs.filter { FeedLogMetadata.isMainFoodLog($0) }
        let treatLogs = pet.careLogs.filter { FeedLogMetadata.isTreatLog($0) }
        let waterLogs = pet.careLogs.filter { $0.careType == .watering }
        let waterCareLogs = pet.careLogs.filter { [.watering, .waterChange].contains($0.careType) }
        let playLogs = pet.careLogs.filter { $0.careType == .play }
        let cleaningCareLogs = pet.careLogs.filter {
            [.litter, .waterChange, .filterClean, .cageCleaning, .substrateChange].contains($0.careType)
        }

        // 预计算"今天"标志（用于多个成就复用）
        let hasTodayHealth = pet.healthLogs.contains { calendar.isDateInToday($0.date) }
        let hasTodayHygiene = pet.hygieneLogs.contains { calendar.isDateInToday($0.date) }
        let hasTodayPotty = recentPottyLogs.contains { calendar.isDateInToday($0.date) }
        let hasTodayCare = pet.careLogs.contains { calendar.isDateInToday($0.date) }
        let hasTodayWalk = recentWalkLogs.contains { calendar.isDateInToday($0.startDate) }
        let hasTodayWeight = pet.weightLogs.contains { calendar.isDateInToday($0.date) }
        let allRecordDates = pet.healthLogs.map(\.date)
            + pet.pottyLogs.map(\.date)
            + pet.walkLogs.map(\.startDate)
            + pet.hygieneLogs.map(\.date)
            + pet.careLogs.map(\.date)
            + pet.foodRecords.map(\.startDate)
            + pet.expenseLogs.map(\.date)
            + pet.weightLogs.map(\.date)
            + pet.photoLogs.map(\.date)
            + pet.milestones.map(\.date)

        func hasAnyRecord(on day: Date) -> Bool {
            allRecordDates.contains { calendar.isDate($0, inSameDayAs: day) }
        }

        // 1. 🔥 钢铁肠胃：连续 7 天每天有 perfectPoop
        let ironGut: Achievement = {
            var streak = true
            for i in 0 ..< 7 {
                guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { streak = false
                    break
                }
                let has = recentPottyLogs.contains {
                    calendar.isDate($0.date, inSameDayAs: day) && $0.pottyType == .perfectPoop
                }
                if !has { streak = false
                    break
                }
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
                               color: Color.goTeal, isUnlocked: total >= 100_000)
        }()

        // 3. 📅 连续巡岛：连续 7 天都有 walkLog
        let walkStreak: Achievement = {
            var streak = true
            for i in 0 ..< 7 {
                guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { streak = false
                    break
                }
                let has = recentWalkLogs.contains { calendar.isDate($0.startDate, inSameDayAs: day) }
                if !has { streak = false
                    break
                }
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
            let feedDates = pet.foodRecords.map(\.startDate)
                + pet.careLogs.filter { $0.careType == .feeding }.map(\.date)
            let sorted = feedDates.sorted()
            guard sorted.count >= 2 else {
                return Achievement(id: "nutritionist", emoji: "🍗", title: "营养师",
                                   description: "坚持记录喂食信息超过 14 天",
                                   color: Color.goOrange, isUnlocked: false)
            }
            let first = sorted.first!
            let last = sorted.last!
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
        let hundredDays = Achievement(id: "hundred_days", emoji: "🗓️", title: "相伴百日",
                                      description: "与宠物共同生活超过 100 天",
                                      color: Color.goCardBlue, isUnlocked: pet.daysTogether >= 100)

        // 8. 📝 第一步：拥有至少一条任意记录（健康/排泄/遛狗/护理）
        let firstRecord: Achievement = {
            let hasAny = !pet.healthLogs.isEmpty || !pet.pottyLogs.isEmpty
                || !pet.walkLogs.isEmpty || !pet.hygieneLogs.isEmpty
                || !pet.careLogs.isEmpty || !pet.foodRecords.isEmpty
                || !pet.expenseLogs.isEmpty || !pet.weightLogs.isEmpty
                || !pet.photoLogs.isEmpty || !pet.milestones.isEmpty
            return Achievement(id: "first_record", emoji: "📝", title: "第一步",
                               description: "完成第一条宠物记录",
                               color: Color.goCardCyan, isUnlocked: hasAny)
        }()

        // 9. ✅ 今日全勤：今天完成了至少一次打卡
        let dayOneCheckin = Achievement(id: "day_one_checkin", emoji: "✅", title: "今日全勤",
                                        description: "今天至少完成了一次打卡记录",
                                        color: Color.goTeal,
                                        isUnlocked: hasTodayHealth || hasTodayHygiene || hasTodayPotty || hasTodayCare || hasTodayWalk || hasTodayWeight)

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
                               color: Color.goOrange, isUnlocked: has5km)
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
        let photoEnthusiast = Achievement(id: "photo_enthusiast", emoji: "📸", title: "拍照达人",
                                          description: "为宠物上传了 20 张以上照片",
                                          color: Color.goPrimary, isUnlocked: pet.photoLogs.count >= 20)

        // 14. 💰 记账能手：累计记录 10 条以上花费
        let expenseTracker = Achievement(id: "expense_tracker", emoji: "💰", title: "记账能手",
                                         description: "累计记录了 10 条以上花费",
                                         color: Color.goYellow, isUnlocked: pet.expenseLogs.count >= 10)

        // 15. 🏋️ 体重管理师：累计体重记录 7 条以上
        let weightManager = Achievement(id: "weight_manager", emoji: "🏋️", title: "体重管理师",
                                        description: "坚持记录体重，累计超过 7 条记录",
                                        color: Color.goCardBlue, isUnlocked: pet.weightLogs.count >= 7)

        // 16. 💧 喝水伙伴：累计喂水 14 次
        let hydrationBuddy = Achievement(
            id: "hydration_buddy",
            emoji: "💧",
            title: "喝水伙伴",
            description: "累计完成 14 次喂水记录",
            color: Color.goTeal,
            isUnlocked: waterLogs.count >= 14
        )

        // 17. 🎾 逗玩达人：累计逗玩 20 次
        let playChampion = Achievement(
            id: "play_champion",
            emoji: "🎾",
            title: "逗玩达人",
            description: "累计完成 20 次陪玩或逗玩记录",
            color: Color.goOrange,
            isUnlocked: playLogs.count >= 20
        )

        // 18. 🧹 清洁管家：累计清洁/铲屎/换水/滤芯 20 次
        let cleanKeeper = Achievement(
            id: "clean_keeper",
            emoji: "🧹",
            title: "清洁管家",
            description: "累计完成 20 次清洁类照护",
            color: Color.goMint,
            isUnlocked: pet.hygieneLogs.count + cleaningCareLogs.count >= 20
        )

        // 19. 🦴 零食侦探：累计记录 10 次零食
        let treatScout = Achievement(
            id: "treat_scout",
            emoji: "🦴",
            title: "零食侦探",
            description: "累计记录 10 次零食",
            color: Color.goYellow,
            isUnlocked: treatLogs.count >= 10
        )

        // 20. 🥣 干湿双修：干粮和湿粮都记录过
        let foodKindExplorer = Achievement(
            id: "food_kind_explorer",
            emoji: "🥣",
            title: "干湿双修",
            description: "干粮和湿粮都完成过记录",
            color: Color.goOrange,
            isUnlocked: mainFeedLogs.contains { $0.foodKind == .dry } && mainFeedLogs.contains { $0.foodKind == .wet }
        )

        // 21. 🤖 自动喂养：自动猫粮机生成过记录
        let autoFeederPilot = Achievement(
            id: "auto_feeder_pilot",
            emoji: "🤖",
            title: "自动喂养",
            description: "自动猫粮机完成过 3 次记录",
            color: Color.goTeal,
            isUnlocked: mainFeedLogs.filter(\.isAutoFeedLogEntry).count >= 3
        )

        // 22. 🧺 粮仓管理员：补粮记录达到 2 次
        let stockKeeper = Achievement(
            id: "stock_keeper",
            emoji: "🧺",
            title: "粮仓管理员",
            description: "累计添加 2 次余粮或补粮记录",
            color: Color.goPrimary,
            isUnlocked: pet.foodRecords.count >= 2
        )

        // 23. 🛡️ 证件守护：建立证件或保险
        let protectionReady = Achievement(
            id: "protection_ready",
            emoji: "🛡️",
            title: "证件守护",
            description: "为宠物添加证件或保险保障",
            color: Color.goCardBlue,
            isUnlocked: !pet.documents.isEmpty || !pet.insurances.isEmpty
        )

        // 24. 💉 疫苗本：记录过疫苗
        let vaccineKeeper = Achievement(
            id: "vaccine_keeper",
            emoji: "💉",
            title: "疫苗本",
            description: "在健康模块记录过疫苗",
            color: Color.goMint,
            isUnlocked: pet.healthLogs.contains { $0.type == "vaccine" || $0.type == "vaccination" || $0.note.localizedCaseInsensitiveContains("疫苗") }
        )

        // 25. 🌡️ 异常观察员：记录过 3 次症状/异常
        let symptomWatcher = Achievement(
            id: "symptom_watcher",
            emoji: "🌡️",
            title: "异常观察员",
            description: "累计记录 3 次症状或异常",
            color: Color.goRed,
            isUnlocked: pet.symptomLogs.count >= 3
        )

        // 26. 🧭 照护连线：连续 14 天任意记录
        let careStreakKeeper: Achievement = {
            var streak = true
            for i in 0 ..< 14 {
                guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { streak = false
                    break
                }
                if !hasAnyRecord(on: day) { streak = false
                    break
                }
            }
            return Achievement(
                id: "care_streak_keeper",
                emoji: "🧭",
                title: "照护连线",
                description: "连续 14 天都有任意照护记录",
                color: Color.goMint,
                isUnlocked: streak
            )
        }()

        // 27. 🍽️ 餐桌档案：累计 50 次主食记录
        let mealArchivist = Achievement(
            id: "meal_archivist",
            emoji: "🍽️",
            title: "餐桌档案",
            description: "累计完成 50 次主食喂养记录",
            color: Color.goOrange,
            isUnlocked: mainFeedLogs.count >= 50
        )

        // 28. 🚰 清泉守卫：累计 50 次喂水记录
        let waterGuardian = Achievement(
            id: "water_guardian",
            emoji: "🚰",
            title: "清泉守卫",
            description: "累计完成 50 次喂水或换水记录",
            color: Color.goTeal,
            isUnlocked: waterCareLogs.count >= 50
        )

        // 29. 🖼️ 记忆相册：累计 50 张照片
        let memoryCollector = Achievement(
            id: "memory_collector",
            emoji: "🖼️",
            title: "记忆相册",
            description: "为宠物留下 50 张照片记录",
            color: Color.goCardBlue,
            isUnlocked: pet.photoLogs.count >= 50
        )

        // 30. 📊 体重节奏：累计 14 条体重记录
        let weightRhythm = Achievement(
            id: "weight_rhythm",
            emoji: "📊",
            title: "体重节奏",
            description: "累计记录 14 次体重变化",
            color: Color.goCardCyan,
            isUnlocked: pet.weightLogs.count >= 14
        )

        // 31. 🌿 一年同行：陪伴满 365 天
        let yearCompanion = Achievement(
            id: "year_companion",
            emoji: "🌿",
            title: "一年同行",
            description: "与宠物共同生活超过 365 天",
            color: Color.goPrimary,
            isUnlocked: pet.daysTogether >= 365
        )

        // 32. 🏝️ Ohana 小队：家里有 2 位以上成员/宠物进入卡片宇宙
        let islandCrew = Achievement(
            id: "global_island_crew",
            emoji: "🏝️",
            title: "Ohana 小队",
            description: "至少建立 2 位宠物或家庭成员档案",
            color: Color.goPrimary,
            isUnlocked: livePets.count >= 2
        )

        // 27. 🌳 伙伴初醒：获得第一只电子宠物
        let firstCritter = Achievement(
            id: "global_first_critter",
            emoji: "🌳",
            title: "伙伴初醒",
            description: "在 Oasis 中获得第一只电子宠物",
            color: Color.goMint,
            isUnlocked: !context.electronicPets.isEmpty
        )

        // 28. ✨ 传说伙伴：获得传说电子宠物
        let legendaryCritter = Achievement(
            id: "global_legendary_critter",
            emoji: "✨",
            title: "传说伙伴",
            description: "获得一只传说级电子宠物",
            color: Color.goYellow,
            isUnlocked: context.electronicPets.contains { $0.rarity == .legendary }
        )

        // 29. 🐾 电子宠物图鉴：收集 3 只电子宠物
        let critterCollector = Achievement(
            id: "global_critter_collector",
            emoji: "🐾",
            title: "电子宠物图鉴",
            description: "收集 3 只电子宠物",
            color: Color.goTeal,
            isUnlocked: Set(context.electronicPets.map(\.catalogId)).count >= 3
        )

        // 30. ⭐ 星级伙伴：任意电子宠物升到 2 星
        let critterStar = Achievement(
            id: "global_critter_star",
            emoji: "⭐",
            title: "星级伙伴",
            description: "将任意电子宠物升到 2 星",
            color: Color.goYellow,
            isUnlocked: context.electronicPets.contains { $0.starLevel >= 2 }
        )

        // 31. 🤲 轻养成：完成 10 次电子宠物互动
        let critterCaretaker = Achievement(
            id: "global_critter_caretaker",
            emoji: "🤲",
            title: "轻养成",
            description: "累计完成 10 次电子宠物互动",
            color: Color.goCardBlue,
            isUnlocked: context.critterActionLogs.count(where: { $0.action != .careEcho }) >= 10
        )

        // 32. 🎁 第一颗盲盒：完成第一次扭蛋
        let firstBlindBox = Achievement(
            id: "global_first_blind_box",
            emoji: "🎁",
            title: "第一颗盲盒",
            description: "完成第一次扭蛋抽取",
            color: Color.goOrange,
            isUnlocked: !context.gachaDrawLogs.isEmpty
        )

        // 33. 🧸 盲盒收藏家：拥有 8 个盲盒款式
        let blindBoxCollector = Achievement(
            id: "global_blind_box_collector",
            emoji: "🧸",
            title: "盲盒收藏家",
            description: "累计拥有 8 个不同盲盒款式",
            color: Color.goPrimary,
            isUnlocked: Set(context.gachaOwnedItems.map { "\($0.seriesId)#\($0.itemId)" }).count >= 8
        )

        // 34. 🌘 隐藏款！：抽中任意隐藏款
        let secretBlindBox = Achievement(
            id: "global_secret_blind_box",
            emoji: "🌘",
            title: "隐藏款！",
            description: "抽中任意系列的隐藏款",
            color: Color.goYellow,
            isUnlocked: context.gachaOwnedItems.contains(where: \.isHidden)
        )

        // 35. 🧩 系列完成：集齐任意系列的普通款
        let seriesComplete = Achievement(
            id: "global_gacha_series_complete",
            emoji: "🧩",
            title: "系列完成",
            description: "集齐任意盲盒系列的全部普通款",
            color: Color.goTeal,
            isUnlocked: Self.completedGachaSeriesCount(context.gachaOwnedItems) >= 1
        )

        // 36. 🥥 欧气爆棚：扭蛋抽到椰子大礼包
        let gachaJackpot = Achievement(
            id: "global_gacha_jackpot",
            emoji: "🥥",
            title: "欧气爆棚",
            description: "在扭蛋中抽到 500 椰子大礼包",
            color: Color.goYellow,
            isUnlocked: context.gachaDrawLogs.contains { $0.instantCoconutDelta >= 500 }
        )

        let petAchievements = [ironGut, ironPaw, walkStreak, healthHero, nutritionist, happyBirthday, hundredDays,
                               firstRecord, dayOneCheckin, oldFriend,
                               longRunner, medicationComplete, photoEnthusiast, expenseTracker, weightManager,
                               hydrationBuddy, playChampion, cleanKeeper, treatScout, foodKindExplorer, autoFeederPilot,
                               stockKeeper, protectionReady, vaccineKeeper, symptomWatcher,
                               careStreakKeeper, mealArchivist, waterGuardian, memoryCollector, weightRhythm, yearCompanion]

        guard context.includesGlobalAchievements else {
            return petAchievements
        }

        let globalAchievements = [islandCrew, firstCritter, legendaryCritter, critterCollector, critterStar, critterCaretaker,
                                  firstBlindBox, blindBoxCollector, secretBlindBox, seriesComplete, gachaJackpot]
        return petAchievements + globalAchievements
    }

    static func isGlobalAchievement(_ badge: Achievement) -> Bool {
        badge.id.hasPrefix("global_")
    }

    static func completedGachaSeriesCount(_ ownedItems: [GachaOwnedItem]) -> Int {
        let ownedBySeries = Dictionary(grouping: ownedItems, by: \.seriesId)
        return GachaSeriesCatalog.allSeries.reduce(0) { count, series in
            let ownedIDs = Set((ownedBySeries[series.id] ?? []).map(\.itemId))
            let regularIDs = Set(series.items.filter { !$0.isHidden }.map(\.id))
            return count + (regularIDs.isEmpty ? 0 : (regularIDs.isSubset(of: ownedIDs) ? 1 : 0))
        }
    }
}
