//
//  AchievementWallContentView+Progress.swift
//  Ohana
//

import SwiftUI

extension AchievementWallContentView {
    func humanAchievements(for human: Human) -> [Achievement] {
        let profileScore = humanProfileScore(human)
        let medicationCount = medications(for: human).count
        let takenMedicationCount = medicationLogs(for: human).count(where: { $0.status == .taken })
        let expenseCount = expenses(for: human).count
        let accountDays = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0
        let coconutBalance = appServices.coconutWallet.balance(for: human, context: modelContext)

        return [
            Achievement(
                id: "human_profile_ready",
                emoji: "👤",
                title: "身份卡完成",
                description: "补全本人档案，让 Ohana 的任务和隐私边界更准确",
                color: Color.goCardBlue,
                isUnlocked: profileScore >= 3
            ),
            Achievement(
                id: "human_first_record",
                emoji: "📝",
                title: "第一条记录",
                description: "完成任意一条体重、花费、运动或用药记录",
                color: Color.goCardCyan,
                isUnlocked: hasAnyHumanRecord(human)
            ),
            Achievement(
                id: "human_weight_starter",
                emoji: "⚖️",
                title: "体重起点",
                description: "记录第一条体重，建立自己的身体基线",
                color: Color.goMint,
                isUnlocked: !human.weightLogs.isEmpty
            ),
            Achievement(
                id: "human_weight_keeper",
                emoji: "📈",
                title: "趋势观察员",
                description: "累计记录 7 次体重，看见真实变化",
                color: Color.goTeal,
                isUnlocked: human.weightLogs.count >= 7
            ),
            Achievement(
                id: "human_expense_tracker",
                emoji: "💳",
                title: "记账上手",
                description: "记录 5 笔家庭或宠物相关花费",
                color: Color.goOrange,
                isUnlocked: expenseCount >= 5
            ),
            Achievement(
                id: "human_medication_setup",
                emoji: "💊",
                title: "用药计划",
                description: "建立至少一个用药计划",
                color: Color.goPurple,
                isUnlocked: medicationCount >= 1
            ),
            Achievement(
                id: "human_medication_keeper",
                emoji: "✅",
                title: "按时吃药",
                description: "累计完成 7 次用药打卡",
                color: Color.goLime,
                isUnlocked: takenMedicationCount >= 7
            ),
            Achievement(
                id: "human_workout_starter",
                emoji: "🏃",
                title: "开始活动",
                description: "记录第一条运动",
                color: Color.goYellow,
                isUnlocked: !human.workoutLogs.isEmpty
            ),
            Achievement(
                id: "human_workout_rhythm",
                emoji: "🔥",
                title: "运动节奏",
                description: "累计记录 10 次运动",
                color: Color.goRed,
                isUnlocked: human.workoutLogs.count >= 10
            ),
            Achievement(
                id: "human_workout_hero",
                emoji: "🏅",
                title: "运动成形",
                description: "累计记录 30 次运动",
                color: Color.goOrange,
                isUnlocked: human.workoutLogs.count >= 30
            ),
            Achievement(
                id: "human_coconut_saver",
                emoji: "🥥",
                title: "椰子小金库",
                description: "个人椰子余额达到 500",
                color: Color.goYellow,
                isUnlocked: coconutBalance >= 500
            ),
            Achievement(
                id: "human_coconut_elite",
                emoji: "🏦",
                title: "椰子金库",
                description: "个人椰子余额达到 2000",
                color: Color.goLime,
                isUnlocked: coconutBalance >= 2000
            ),
            Achievement(
                id: "human_old_friend",
                emoji: "🤝",
                title: "Ohana 老朋友",
                description: "本人档案建立满 7 天",
                color: Color.goPrimary,
                isUnlocked: accountDays >= 7
            ),
            Achievement(
                id: "human_year_friend",
                emoji: "🌿",
                title: "自我同行",
                description: "本人档案建立满 365 天",
                color: Color.goMint,
                isUnlocked: accountDays >= 365
            )
        ]
    }

    func progress(for badge: Achievement) -> ProgressInfo {
        if let human = activeHuman {
            return humanProgress(for: badge, human: human)
        }
        switch badge.id {
        case "iron_gut":
            return .init(current: Double(consecutivePerfectPoopDays()), target: 7, unit: "天", actionTitle: "连续记录完美便便")
        case "iron_paw":
            return .init(current: totalWalkKm(), target: 100, unit: "km", actionTitle: "累计遛狗距离")
        case "walk_streak":
            return .init(current: Double(consecutiveWalkDays()), target: 7, unit: "天", actionTitle: "连续遛狗记录")
        case "health_hero":
            let hasHealth = !activeCareLedgerSummary.healthEvents.isEmpty
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
            let hasRecentEmergency = activeCareLedgerSummary.hasRecentEmergencyOrSurgery(since: cutoff)
            return .init(current: hasHealth && !hasRecentEmergency ? 1 : 0, target: 1, unit: "项", actionTitle: "添加健康记录并保持稳定")
        case "nutritionist":
            return .init(current: Double(feedingSpanDays()), target: 14, unit: "天", actionTitle: "持续记录饮食")
        case "happy_birthday":
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "次", actionTitle: "生日当天打开 Ohana")
        case "hundred_days":
            return .init(current: Double(max(0, activePet.daysTogether)), target: 100, unit: "天", actionTitle: "共同生活天数")
        case "first_record":
            return .init(current: hasAnyRecord() ? 1 : 0, target: 1, unit: "条", actionTitle: "完成任意一条记录")
        case "day_one_checkin":
            return .init(current: hasAnyTodayRecord() ? 1 : 0, target: 1, unit: "次", actionTitle: "今天完成一次打卡")
        case "old_friend":
            let days = Calendar.current.dateComponents([.day], from: activePet.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 7, unit: "天", actionTitle: "使用 Ohana 的天数")
        case "long_runner":
            return .init(current: maxSingleWalkKm(), target: 5, unit: "km", actionTitle: "单次遛狗距离")
        case "medication_complete":
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "个疗程", actionTitle: "完成一个用药疗程")
        case "photo_enthusiast":
            return .init(current: Double(activePetActivitySummary.photoCount), target: 20, unit: "张", actionTitle: "添加宠物照片")
        case "expense_tracker":
            return .init(current: Double(activeCareLedgerSummary.expenseEvents.count), target: 10, unit: "条", actionTitle: "记录宠物花费")
        case "weight_manager":
            return .init(current: Double(activeCareLedgerSummary.weightEvents.count), target: 7, unit: "条", actionTitle: "记录体重")
        case "hydration_buddy":
            return .init(current: Double(activeCareLedgerSummary.wateringEvents.count), target: 14, unit: "次", actionTitle: "累计喂水")
        case "play_champion":
            return .init(current: Double(activeCareLedgerSummary.playEvents.count), target: 20, unit: "次", actionTitle: "累计陪玩")
        case "clean_keeper":
            return .init(current: Double(cleaningRecordCount()), target: 20, unit: "次", actionTitle: "累计清洁照护")
        case "treat_scout":
            return .init(current: Double(activeCareLedgerSummary.treatEvents.count), target: 10, unit: "次", actionTitle: "累计记录零食")
        case "food_kind_explorer":
            return .init(current: Double(recordedFoodKindCount()), target: 2, unit: "种", actionTitle: "干粮湿粮都记录")
        case "auto_feeder_pilot":
            return .init(current: Double(autoMainFeedCount()), target: 3, unit: "次", actionTitle: "自动猫粮机记录")
        case "stock_keeper":
            return .init(current: Double(activePetActivitySummary.foodRecordCount), target: 2, unit: "次", actionTitle: "添加余粮")
        case "protection_ready":
            return .init(current: activePetActivitySummary.hasProtectionRecord ? 1 : 0, target: 1, unit: "项", actionTitle: "添加证件或保险")
        case "vaccine_keeper":
            return .init(current: hasVaccineRecord() ? 1 : 0, target: 1, unit: "针", actionTitle: "记录疫苗")
        case "symptom_watcher":
            return .init(current: Double(activePetActivitySummary.symptomCount), target: 3, unit: "次", actionTitle: "记录症状")
        case "care_streak_keeper":
            return .init(current: Double(consecutiveAnyRecordDays()), target: 14, unit: "天", actionTitle: "连续照护记录")
        case "meal_archivist":
            return .init(current: Double(mainFeedCount()), target: 50, unit: "次", actionTitle: "累计主食记录")
        case "water_guardian":
            return .init(current: Double(waterCareRecordDates().count), target: 50, unit: "次", actionTitle: "累计喂水/换水")
        case "memory_collector":
            return .init(current: Double(activePetActivitySummary.photoCount), target: 50, unit: "张", actionTitle: "添加宠物照片")
        case "weight_rhythm":
            return .init(current: Double(activeCareLedgerSummary.weightEvents.count), target: 14, unit: "条", actionTitle: "记录体重")
        case "year_companion":
            return .init(current: Double(max(0, activePet.daysTogether)), target: 365, unit: "天", actionTitle: "共同生活天数")
        case "global_island_crew":
            return .init(current: Double(pets.count), target: 2, unit: "位", actionTitle: "建立成员档案")
        case "global_first_critter":
            return .init(current: Double(electronicPets.count), target: 1, unit: "只", actionTitle: "获得电子宠物")
        case "global_legendary_critter":
            return .init(current: electronicPets.contains { $0.rarity == .legendary } ? 1 : 0, target: 1, unit: "只", actionTitle: "获得传说电子宠物")
        case "global_critter_collector":
            return .init(current: Double(Set(electronicPets.map(\.catalogId)).count), target: 3, unit: "只", actionTitle: "收集电子宠物")
        case "global_critter_star":
            return .init(current: Double(electronicPets.map(\.starLevel).max() ?? 0), target: 2, unit: "星", actionTitle: "电子宠物升星")
        case "global_critter_caretaker":
            return .init(current: Double(critterActionLogs.count(where: { $0.action != .careEcho })), target: 10, unit: "次", actionTitle: "电子宠物互动")
        case "global_first_blind_box":
            return .init(current: Double(gachaDrawLogs.count), target: 1, unit: "抽", actionTitle: "使用扭蛋机")
        case "global_blind_box_collector":
            return .init(current: Double(uniqueGachaItemCount()), target: 8, unit: "款", actionTitle: "收集盲盒款式")
        case "global_secret_blind_box":
            return .init(current: gachaOwnedItems.contains(where: \.isHidden) ? 1 : 0, target: 1, unit: "款", actionTitle: "抽中隐藏款")
        case "global_gacha_series_complete":
            return .init(current: Double(screenModel.completedGachaSeriesCount()), target: 1, unit: "套", actionTitle: "集齐盲盒系列")
        case "global_gacha_jackpot":
            return .init(current: gachaDrawLogs.contains { $0.instantCoconutDelta >= 500 } ? 1 : 0, target: 1, unit: "次", actionTitle: "抽到椰子大礼包")
        default:
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "项", actionTitle: "完成条件")
        }
    }

    func humanProgress(for badge: Achievement, human: Human) -> ProgressInfo {
        switch badge.id {
        case "human_profile_ready":
            return .init(current: Double(humanProfileScore(human)), target: 3, unit: "项", actionTitle: "补全本人档案")
        case "human_first_record":
            return .init(current: hasAnyHumanRecord(human) ? 1 : 0, target: 1, unit: "条", actionTitle: "完成任意记录")
        case "human_weight_starter":
            return .init(current: Double(human.weightLogs.count), target: 1, unit: "条", actionTitle: "记录体重")
        case "human_weight_keeper":
            return .init(current: Double(human.weightLogs.count), target: 7, unit: "条", actionTitle: "累计体重记录")
        case "human_expense_tracker":
            return .init(current: Double(expenses(for: human).count), target: 5, unit: "笔", actionTitle: "记录花费")
        case "human_medication_setup":
            return .init(current: Double(medications(for: human).count), target: 1, unit: "个", actionTitle: "添加用药计划")
        case "human_medication_keeper":
            return .init(current: Double(medicationLogs(for: human).count(where: { $0.status == .taken })), target: 7, unit: "次", actionTitle: "完成用药打卡")
        case "human_workout_starter":
            return .init(current: Double(human.workoutLogs.count), target: 1, unit: "条", actionTitle: "记录运动")
        case "human_workout_rhythm":
            return .init(current: Double(human.workoutLogs.count), target: 10, unit: "次", actionTitle: "累计运动记录")
        case "human_workout_hero":
            return .init(current: Double(human.workoutLogs.count), target: 30, unit: "次", actionTitle: "累计运动记录")
        case "human_coconut_saver":
            return .init(current: Double(human.coconutBalance), target: 500, unit: "🥥", actionTitle: "积累个人椰子")
        case "human_coconut_elite":
            return .init(current: Double(human.coconutBalance), target: 2000, unit: "🥥", actionTitle: "积累个人椰子")
        case "human_old_friend":
            let days = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 7, unit: "天", actionTitle: "使用 Ohana 的天数")
        case "human_year_friend":
            let days = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 365, unit: "天", actionTitle: "使用 Ohana 的天数")
        default:
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: "项", actionTitle: "完成条件")
        }
    }

    func consecutivePerfectPoopDays() -> Int {
        let calendar = Calendar.current
        return activeCareLedgerSummary.consecutivePerfectPoopDays(
            calendar: calendar,
            today: calendar.startOfDay(for: Date())
        )
    }

    func consecutiveWalkDays() -> Int {
        let calendar = Calendar.current
        return activeCareLedgerSummary.consecutiveWalkDays(
            calendar: calendar,
            today: calendar.startOfDay(for: Date())
        )
    }

    func consecutiveAnyRecordDays() -> Int {
        let dates = petRecordDates()
        return consecutiveDays { day in
            dates.contains { Calendar.current.isDate($0, inSameDayAs: day) }
        }
    }

    func consecutiveDays(hasRecord: (Date) -> Bool) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var count = 0
        for offset in 0 ..< 30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if hasRecord(day) { count += 1 } else { break }
        }
        return count
    }

    func totalWalkKm() -> Double {
        activeCareLedgerSummary.totalWalkMeters() / 1000.0
    }

    func maxSingleWalkKm() -> Double {
        activeCareLedgerSummary.maxSingleWalkMeters() / 1000.0
    }

    func feedingSpanDays() -> Int {
        let dates = activePetActivitySummary.foodRecordDates
            + activeCareLedgerSummary.mainFeedEvents.map(\.occurredAt)
        guard let first = dates.min(), let last = dates.max() else { return 0 }
        return Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
    }

    func hasAnyRecord() -> Bool {
        activeCareLedgerSummary.hasAnyRecord || activePetActivitySummary.hasArchiveRecord
    }

    func hasAnyTodayRecord() -> Bool {
        let calendar = Calendar.current
        return activeCareLedgerSummary.hasTodayRecord(kind: .health, calendar: calendar, now: Date())
            || activeCareLedgerSummary.hasTodayRecord(kind: .hygiene, calendar: calendar, now: Date())
            || activeCareLedgerSummary.hasTodayRecord(kind: .potty, calendar: calendar, now: Date())
            || activeCareLedgerSummary.hasTodayRecord(kind: .walk, calendar: calendar, now: Date())
            || activeCareLedgerSummary.hasTodayCareRecord(calendar: calendar, now: Date())
            || activeCareLedgerSummary.hasTodayRecord(kind: .weight, calendar: calendar, now: Date())
    }

    func cleaningRecordCount() -> Int {
        activeCareLedgerSummary.hygieneEvents.count + activeCareLedgerSummary.cleaningCareEvents.count
    }

    func recordedFoodKindCount() -> Int {
        activeCareLedgerSummary.recordedFoodKindCount()
    }

    func mainFeedCount() -> Int {
        activeCareLedgerSummary.mainFeedEvents.count
    }

    func autoMainFeedCount() -> Int {
        activeCareLedgerSummary.autoMainFeedCount()
    }

    func hasVaccineRecord() -> Bool {
        activeCareLedgerSummary.hasVaccineRecord()
    }

    func uniqueGachaItemCount() -> Int {
        Set(gachaOwnedItems.map { "\($0.seriesId)#\($0.itemId)" }).count
    }

    func humanProfileScore(_ human: Human) -> Int {
        [
            human.birthday != nil,
            human.heightCm > 0,
            !human.bloodType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !human.mbti.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !human.nationality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !human.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ].count(where: { $0 })
    }

    func medications(for human: Human) -> [HumanMedication] {
        humanActivityIndex.medications(for: human)
    }

    func medicationLogs(for human: Human) -> [HumanMedicationLog] {
        humanActivityIndex.medicationLogs(for: human)
    }

    func expenses(for human: Human) -> [PetExpenseLog] {
        humanActivityIndex.expenses(for: human)
    }

    func hasAnyHumanRecord(_ human: Human) -> Bool {
        !human.weightLogs.isEmpty
            || !human.workoutLogs.isEmpty
            || !medications(for: human).isEmpty
            || !medicationLogs(for: human).isEmpty
            || !expenses(for: human).isEmpty
    }
}
