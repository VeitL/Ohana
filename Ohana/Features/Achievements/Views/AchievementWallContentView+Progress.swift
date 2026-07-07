//
//  AchievementWallContentView+Progress.swift
//  Ohana
//

import SwiftUI

private enum AchievementProgressUnit {
    case days
    case items
    case records
    case times
    case course
    case photos
    case kinds
    case shots
    case members
    case pets
    case stars
    case draws
    case styles
    case set
    case vaccine
    case kilometers
    case coconuts
}

private enum AchievementProgressAction {
    case perfectPoopStreak
    case totalWalkDistance
    case walkStreak
    case stableHealthRecord
    case foodRecordStreak
    case openOnBirthday
    case daysTogether
    case anyRecord
    case todayCheckIn
    case daysUsingOhana
    case singleWalkDistance
    case medicationCourse
    case petPhotos
    case petExpenses
    case petWeight
    case waterLogs
    case playLogs
    case cleaningLogs
    case treatLogs
    case dryAndWetFood
    case autoFeeder
    case foodStock
    case protectionRecord
    case vaccineRecord
    case symptomRecord
    case careStreak
    case mainFoodLogs
    case waterAndChangeLogs
    case memberProfiles
    case firstCritter
    case legendaryCritter
    case collectCritters
    case critterStar
    case critterInteractions
    case gachaDraw
    case collectGachaItems
    case hiddenGachaItem
    case completeGachaSeries
    case gachaJackpot
    case completeCondition
    case humanProfile
    case humanAnyRecord
    case humanWeight
    case humanWeightHistory
    case humanExpenses
    case humanMedicationPlan
    case humanMedicationCheckIns
    case humanWorkout
    case humanWorkoutHistory
    case humanCoconuts
}

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
                title: l.tr(zh: "身份卡完成", en: "Profile ready", de: "Profil bereit"),
                description: l.tr(
                    zh: "补全本人档案，让 Ohana 的任务和隐私边界更准确",
                    en: "Complete your profile so tasks and privacy boundaries work more accurately.",
                    de: "Vervollständige dein Profil, damit Aufgaben und Privatsphäre genauer passen."
                ),
                color: Color.goCardBlue,
                isUnlocked: profileScore >= 3
            ),
            Achievement(
                id: "human_first_record",
                emoji: "📝",
                title: l.tr(zh: "第一条记录", en: "First record", de: "Erster Eintrag"),
                description: l.tr(
                    zh: "完成任意一条体重、花费、运动或用药记录",
                    en: "Log any weight, expense, workout, or medication record.",
                    de: "Erfasse einen Gewichts-, Ausgaben-, Sport- oder Medikamenteneintrag."
                ),
                color: Color.goCardCyan,
                isUnlocked: hasAnyHumanRecord(human)
            ),
            Achievement(
                id: "human_weight_starter",
                emoji: "⚖️",
                title: l.tr(zh: "体重起点", en: "Weight baseline", de: "Gewichtsbasis"),
                description: l.tr(
                    zh: "记录第一条体重，建立自己的身体基线",
                    en: "Log the first weight entry to create your baseline.",
                    de: "Erfasse dein erstes Gewicht als persönliche Basislinie."
                ),
                color: Color.goMint,
                isUnlocked: !human.weightLogs.isEmpty
            ),
            Achievement(
                id: "human_weight_keeper",
                emoji: "📈",
                title: l.tr(zh: "趋势观察员", en: "Trend watcher", de: "Trendbeobachter"),
                description: l.tr(
                    zh: "累计记录 7 次体重，看见真实变化",
                    en: "Log weight 7 times to see the real trend.",
                    de: "Erfasse 7 Gewichtswerte, um echte Veränderungen zu sehen."
                ),
                color: Color.goTeal,
                isUnlocked: human.weightLogs.count >= 7
            ),
            Achievement(
                id: "human_expense_tracker",
                emoji: "💳",
                title: l.tr(zh: "记账上手", en: "Expense starter", de: "Ausgabenstart"),
                description: l.tr(
                    zh: "记录 5 笔家庭或宠物相关花费",
                    en: "Log 5 family or pet-related expenses.",
                    de: "Erfasse 5 Familien- oder Haustierausgaben."
                ),
                color: Color.goOrange,
                isUnlocked: expenseCount >= 5
            ),
            Achievement(
                id: "human_medication_setup",
                emoji: "💊",
                title: l.tr(zh: "用药计划", en: "Medication plan", de: "Medikamentenplan"),
                description: l.tr(
                    zh: "建立至少一个用药计划",
                    en: "Create at least one medication plan.",
                    de: "Lege mindestens einen Medikamentenplan an."
                ),
                color: Color.goPurple,
                isUnlocked: medicationCount >= 1
            ),
            Achievement(
                id: "human_medication_keeper",
                emoji: "✅",
                title: l.tr(zh: "按时吃药", en: "Medication streak", de: "Medikamente im Takt"),
                description: l.tr(
                    zh: "累计完成 7 次用药打卡",
                    en: "Complete 7 medication check-ins.",
                    de: "Schließe 7 Medikamenten-Check-ins ab."
                ),
                color: Color.goPrimary,
                isUnlocked: takenMedicationCount >= 7
            ),
            Achievement(
                id: "human_workout_starter",
                emoji: "🏃",
                title: l.tr(zh: "开始活动", en: "First workout", de: "Erstes Workout"),
                description: l.tr(
                    zh: "记录第一条运动",
                    en: "Log your first workout.",
                    de: "Erfasse dein erstes Workout."
                ),
                color: Color.goYellow,
                isUnlocked: !human.workoutLogs.isEmpty
            ),
            Achievement(
                id: "human_workout_rhythm",
                emoji: "🔥",
                title: l.tr(zh: "运动节奏", en: "Workout rhythm", de: "Workout-Rhythmus"),
                description: l.tr(
                    zh: "累计记录 10 次运动",
                    en: "Log 10 workouts.",
                    de: "Erfasse 10 Workouts."
                ),
                color: Color.goRed,
                isUnlocked: human.workoutLogs.count >= 10
            ),
            Achievement(
                id: "human_workout_hero",
                emoji: "🏅",
                title: l.tr(zh: "运动成形", en: "Workout habit", de: "Workout-Gewohnheit"),
                description: l.tr(
                    zh: "累计记录 30 次运动",
                    en: "Log 30 workouts.",
                    de: "Erfasse 30 Workouts."
                ),
                color: Color.goOrange,
                isUnlocked: human.workoutLogs.count >= 30
            ),
            Achievement(
                id: "human_coconut_saver",
                emoji: "🥥",
                title: l.tr(zh: "椰子小金库", en: "Coconut stash", de: "Kokos-Vorrat"),
                description: l.tr(
                    zh: "个人椰子余额达到 500",
                    en: "Reach a personal balance of 500 coconuts.",
                    de: "Erreiche ein persönliches Guthaben von 500 Kokosnüssen."
                ),
                color: Color.goYellow,
                isUnlocked: coconutBalance >= 500
            ),
            Achievement(
                id: "human_coconut_elite",
                emoji: "🏦",
                title: l.tr(zh: "椰子金库", en: "Coconut vault", de: "Kokos-Tresor"),
                description: l.tr(
                    zh: "个人椰子余额达到 2000",
                    en: "Reach a personal balance of 2000 coconuts.",
                    de: "Erreiche ein persönliches Guthaben von 2000 Kokosnüssen."
                ),
                color: Color.goPrimary,
                isUnlocked: coconutBalance >= 2000
            ),
            Achievement(
                id: "human_old_friend",
                emoji: "🤝",
                title: l.tr(zh: "Ohana 老朋友", en: "Ohana regular", de: "Ohana Stammgast"),
                description: l.tr(
                    zh: "本人档案建立满 7 天",
                    en: "Keep your profile for 7 days.",
                    de: "Behalte dein Profil 7 Tage lang."
                ),
                color: Color.goPrimary,
                isUnlocked: accountDays >= 7
            ),
            Achievement(
                id: "human_year_friend",
                emoji: "🌿",
                title: l.tr(zh: "自我同行", en: "A year with yourself", de: "Ein Jahr mit dir"),
                description: l.tr(
                    zh: "本人档案建立满 365 天",
                    en: "Keep your profile for 365 days.",
                    de: "Behalte dein Profil 365 Tage lang."
                ),
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
            return .init(current: Double(consecutivePerfectPoopDays()), target: 7, unit: progressUnit(.days), actionTitle: progressAction(.perfectPoopStreak))
        case "iron_paw":
            return .init(current: totalWalkKm(), target: 100, unit: progressUnit(.kilometers), actionTitle: progressAction(.totalWalkDistance))
        case "walk_streak":
            return .init(current: Double(consecutiveWalkDays()), target: 7, unit: progressUnit(.days), actionTitle: progressAction(.walkStreak))
        case "health_hero":
            let hasHealth = !activeCareLedgerSummary.healthEvents.isEmpty
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
            let hasRecentEmergency = activeCareLedgerSummary.hasRecentEmergencyOrSurgery(since: cutoff)
            return .init(current: hasHealth && !hasRecentEmergency ? 1 : 0, target: 1, unit: progressUnit(.items), actionTitle: progressAction(.stableHealthRecord))
        case "nutritionist":
            return .init(current: Double(feedingSpanDays()), target: 14, unit: progressUnit(.days), actionTitle: progressAction(.foodRecordStreak))
        case "happy_birthday":
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: progressUnit(.times), actionTitle: progressAction(.openOnBirthday))
        case "hundred_days":
            return .init(current: Double(max(0, activePet.daysTogether)), target: 100, unit: progressUnit(.days), actionTitle: progressAction(.daysTogether))
        case "first_record":
            return .init(current: hasAnyRecord() ? 1 : 0, target: 1, unit: progressUnit(.records), actionTitle: progressAction(.anyRecord))
        case "day_one_checkin":
            return .init(current: hasAnyTodayRecord() ? 1 : 0, target: 1, unit: progressUnit(.times), actionTitle: progressAction(.todayCheckIn))
        case "old_friend":
            let days = Calendar.current.dateComponents([.day], from: activePet.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 7, unit: progressUnit(.days), actionTitle: progressAction(.daysUsingOhana))
        case "long_runner":
            return .init(current: maxSingleWalkKm(), target: 5, unit: progressUnit(.kilometers), actionTitle: progressAction(.singleWalkDistance))
        case "medication_complete":
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: progressUnit(.course), actionTitle: progressAction(.medicationCourse))
        case "photo_enthusiast":
            return .init(current: Double(activePetActivitySummary.photoCount), target: 20, unit: progressUnit(.photos), actionTitle: progressAction(.petPhotos))
        case "expense_tracker":
            return .init(current: Double(activeCareLedgerSummary.expenseEvents.count), target: 10, unit: progressUnit(.records), actionTitle: progressAction(.petExpenses))
        case "weight_manager":
            return .init(current: Double(activeCareLedgerSummary.weightEvents.count), target: 7, unit: progressUnit(.records), actionTitle: progressAction(.petWeight))
        case "hydration_buddy":
            return .init(current: Double(activeCareLedgerSummary.wateringEvents.count), target: 14, unit: progressUnit(.times), actionTitle: progressAction(.waterLogs))
        case "play_champion":
            return .init(current: Double(activeCareLedgerSummary.playEvents.count), target: 20, unit: progressUnit(.times), actionTitle: progressAction(.playLogs))
        case "clean_keeper":
            return .init(current: Double(cleaningRecordCount()), target: 20, unit: progressUnit(.times), actionTitle: progressAction(.cleaningLogs))
        case "treat_scout":
            return .init(current: Double(activeCareLedgerSummary.treatEvents.count), target: 10, unit: progressUnit(.times), actionTitle: progressAction(.treatLogs))
        case "food_kind_explorer":
            return .init(current: Double(recordedFoodKindCount()), target: 2, unit: progressUnit(.kinds), actionTitle: progressAction(.dryAndWetFood))
        case "auto_feeder_pilot":
            return .init(current: Double(autoMainFeedCount()), target: 3, unit: progressUnit(.times), actionTitle: progressAction(.autoFeeder))
        case "stock_keeper":
            return .init(current: Double(activePetActivitySummary.foodRecordCount), target: 2, unit: progressUnit(.times), actionTitle: progressAction(.foodStock))
        case "protection_ready":
            return .init(current: activePetActivitySummary.hasProtectionRecord ? 1 : 0, target: 1, unit: progressUnit(.items), actionTitle: progressAction(.protectionRecord))
        case "vaccine_keeper":
            return .init(current: hasVaccineRecord() ? 1 : 0, target: 1, unit: progressUnit(.vaccine), actionTitle: progressAction(.vaccineRecord))
        case "symptom_watcher":
            return .init(current: Double(activePetActivitySummary.symptomCount), target: 3, unit: progressUnit(.times), actionTitle: progressAction(.symptomRecord))
        case "care_streak_keeper":
            return .init(current: Double(consecutiveAnyRecordDays()), target: 14, unit: progressUnit(.days), actionTitle: progressAction(.careStreak))
        case "meal_archivist":
            return .init(current: Double(mainFeedCount()), target: 50, unit: progressUnit(.times), actionTitle: progressAction(.mainFoodLogs))
        case "water_guardian":
            return .init(current: Double(waterCareRecordDates().count), target: 50, unit: progressUnit(.times), actionTitle: progressAction(.waterAndChangeLogs))
        case "memory_collector":
            return .init(current: Double(activePetActivitySummary.photoCount), target: 50, unit: progressUnit(.photos), actionTitle: progressAction(.petPhotos))
        case "weight_rhythm":
            return .init(current: Double(activeCareLedgerSummary.weightEvents.count), target: 14, unit: progressUnit(.records), actionTitle: progressAction(.petWeight))
        case "year_companion":
            return .init(current: Double(max(0, activePet.daysTogether)), target: 365, unit: progressUnit(.days), actionTitle: progressAction(.daysTogether))
        case "global_island_crew":
            return .init(current: Double(pets.count), target: 2, unit: progressUnit(.members), actionTitle: progressAction(.memberProfiles))
        case "global_first_critter":
            return .init(current: Double(electronicPets.count), target: 1, unit: progressUnit(.pets), actionTitle: progressAction(.firstCritter))
        case "global_legendary_critter":
            return .init(current: electronicPets.contains { $0.rarity == .legendary } ? 1 : 0, target: 1, unit: progressUnit(.pets), actionTitle: progressAction(.legendaryCritter))
        case "global_critter_collector":
            return .init(current: Double(Set(electronicPets.map(\.catalogId)).count), target: 3, unit: progressUnit(.pets), actionTitle: progressAction(.collectCritters))
        case "global_critter_star":
            return .init(current: Double(electronicPets.map(\.starLevel).max() ?? 0), target: 2, unit: progressUnit(.stars), actionTitle: progressAction(.critterStar))
        case "global_critter_caretaker":
            return .init(current: Double(critterActionLogs.count(where: { $0.action != .careEcho })), target: 10, unit: progressUnit(.times), actionTitle: progressAction(.critterInteractions))
        case "global_first_blind_box":
            return .init(current: Double(gachaDrawLogs.count), target: 1, unit: progressUnit(.draws), actionTitle: progressAction(.gachaDraw))
        case "global_blind_box_collector":
            return .init(current: Double(uniqueGachaItemCount()), target: 8, unit: progressUnit(.styles), actionTitle: progressAction(.collectGachaItems))
        case "global_secret_blind_box":
            return .init(current: gachaOwnedItems.contains(where: \.isHidden) ? 1 : 0, target: 1, unit: progressUnit(.styles), actionTitle: progressAction(.hiddenGachaItem))
        case "global_gacha_series_complete":
            return .init(current: Double(screenModel.completedGachaSeriesCount()), target: 1, unit: progressUnit(.set), actionTitle: progressAction(.completeGachaSeries))
        case "global_gacha_jackpot":
            return .init(current: gachaDrawLogs.contains { $0.instantCoconutDelta >= 500 } ? 1 : 0, target: 1, unit: progressUnit(.times), actionTitle: progressAction(.gachaJackpot))
        default:
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: progressUnit(.items), actionTitle: progressAction(.completeCondition))
        }
    }

    func humanProgress(for badge: Achievement, human: Human) -> ProgressInfo {
        switch badge.id {
        case "human_profile_ready":
            return .init(current: Double(humanProfileScore(human)), target: 3, unit: progressUnit(.items), actionTitle: progressAction(.humanProfile))
        case "human_first_record":
            return .init(current: hasAnyHumanRecord(human) ? 1 : 0, target: 1, unit: progressUnit(.records), actionTitle: progressAction(.humanAnyRecord))
        case "human_weight_starter":
            return .init(current: Double(human.weightLogs.count), target: 1, unit: progressUnit(.records), actionTitle: progressAction(.humanWeight))
        case "human_weight_keeper":
            return .init(current: Double(human.weightLogs.count), target: 7, unit: progressUnit(.records), actionTitle: progressAction(.humanWeightHistory))
        case "human_expense_tracker":
            return .init(current: Double(expenses(for: human).count), target: 5, unit: progressUnit(.records), actionTitle: progressAction(.humanExpenses))
        case "human_medication_setup":
            return .init(current: Double(medications(for: human).count), target: 1, unit: progressUnit(.items), actionTitle: progressAction(.humanMedicationPlan))
        case "human_medication_keeper":
            return .init(current: Double(medicationLogs(for: human).count(where: { $0.status == .taken })), target: 7, unit: progressUnit(.times), actionTitle: progressAction(.humanMedicationCheckIns))
        case "human_workout_starter":
            return .init(current: Double(human.workoutLogs.count), target: 1, unit: progressUnit(.records), actionTitle: progressAction(.humanWorkout))
        case "human_workout_rhythm":
            return .init(current: Double(human.workoutLogs.count), target: 10, unit: progressUnit(.times), actionTitle: progressAction(.humanWorkoutHistory))
        case "human_workout_hero":
            return .init(current: Double(human.workoutLogs.count), target: 30, unit: progressUnit(.times), actionTitle: progressAction(.humanWorkoutHistory))
        case "human_coconut_saver":
            return .init(current: Double(human.coconutBalance), target: 500, unit: progressUnit(.coconuts), actionTitle: progressAction(.humanCoconuts))
        case "human_coconut_elite":
            return .init(current: Double(human.coconutBalance), target: 2000, unit: progressUnit(.coconuts), actionTitle: progressAction(.humanCoconuts))
        case "human_old_friend":
            let days = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 7, unit: progressUnit(.days), actionTitle: progressAction(.daysUsingOhana))
        case "human_year_friend":
            let days = Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0
            return .init(current: Double(max(0, days)), target: 365, unit: progressUnit(.days), actionTitle: progressAction(.daysUsingOhana))
        default:
            return .init(current: badge.isUnlocked ? 1 : 0, target: 1, unit: progressUnit(.items), actionTitle: progressAction(.completeCondition))
        }
    }

    private func progressUnit(_ unit: AchievementProgressUnit) -> String {
        switch unit {
        case .days:
            l.tr(zh: "天", en: "days", de: "Tage")
        case .items:
            l.tr(zh: "项", en: "items", de: "Punkte")
        case .records:
            l.tr(zh: "条", en: "records", de: "Einträge")
        case .times:
            l.tr(zh: "次", en: "times", de: "Mal")
        case .course:
            l.tr(zh: "个疗程", en: "course", de: "Kur")
        case .photos:
            l.tr(zh: "张", en: "photos", de: "Fotos")
        case .kinds:
            l.tr(zh: "种", en: "kinds", de: "Arten")
        case .shots:
            l.tr(zh: "针", en: "shot", de: "Impfung")
        case .members:
            l.tr(zh: "位", en: "members", de: "Mitglieder")
        case .pets:
            l.tr(zh: "只", en: "pets", de: "Begleiter")
        case .stars:
            l.tr(zh: "星", en: "stars", de: "Sterne")
        case .draws:
            l.tr(zh: "抽", en: "draws", de: "Züge")
        case .styles:
            l.tr(zh: "款", en: "styles", de: "Varianten")
        case .set:
            l.tr(zh: "套", en: "set", de: "Set")
        case .vaccine:
            l.tr(zh: "针", en: "shot", de: "Impfung")
        case .kilometers:
            "km"
        case .coconuts:
            "🥥"
        }
    }

    private func progressAction(_ action: AchievementProgressAction) -> String {
        switch action {
        case .perfectPoopStreak:
            l.tr(zh: "连续记录完美便便", en: "Log perfect potty streaks", de: "Perfekte Häufchen-Serie erfassen")
        case .totalWalkDistance:
            l.tr(zh: "累计遛狗距离", en: "Build total walk distance", de: "Gassi-Distanz sammeln")
        case .walkStreak:
            l.tr(zh: "连续遛狗记录", en: "Keep a walk streak", de: "Gassi-Serie halten")
        case .stableHealthRecord:
            l.tr(zh: "添加健康记录并保持稳定", en: "Add health records and stay stable", de: "Gesundheit erfassen und stabil bleiben")
        case .foodRecordStreak:
            l.tr(zh: "持续记录饮食", en: "Keep food records going", de: "Futtereinträge fortführen")
        case .openOnBirthday:
            l.tr(zh: "生日当天打开 Ohana", en: "Open Ohana on the birthday", de: "Ohana am Geburtstag öffnen")
        case .daysTogether:
            l.tr(zh: "共同生活天数", en: "Days together", de: "Gemeinsame Tage")
        case .anyRecord:
            l.tr(zh: "完成任意一条记录", en: "Log any record", de: "Einen Eintrag erfassen")
        case .todayCheckIn:
            l.tr(zh: "今天完成一次打卡", en: "Complete one check-in today", de: "Heute einen Check-in abschließen")
        case .daysUsingOhana:
            l.tr(zh: "使用 Ohana 的天数", en: "Days using Ohana", de: "Tage mit Ohana")
        case .singleWalkDistance:
            l.tr(zh: "单次遛狗距离", en: "Single walk distance", de: "Einzelne Gassi-Distanz")
        case .medicationCourse:
            l.tr(zh: "完成一个用药疗程", en: "Complete a medication course", de: "Eine Medikamentenkur abschließen")
        case .petPhotos:
            l.tr(zh: "添加宠物照片", en: "Add pet photos", de: "Haustierfotos hinzufügen")
        case .petExpenses:
            l.tr(zh: "记录宠物花费", en: "Log pet expenses", de: "Haustierausgaben erfassen")
        case .petWeight:
            l.tr(zh: "记录体重", en: "Log weight", de: "Gewicht erfassen")
        case .waterLogs:
            l.tr(zh: "累计喂水", en: "Build water logs", de: "Wassereinträge sammeln")
        case .playLogs:
            l.tr(zh: "累计陪玩", en: "Build play logs", de: "Spielzeit sammeln")
        case .cleaningLogs:
            l.tr(zh: "累计清洁照护", en: "Build hygiene care logs", de: "Pflegeeinträge sammeln")
        case .treatLogs:
            l.tr(zh: "累计记录零食", en: "Build treat logs", de: "Snackeinträge sammeln")
        case .dryAndWetFood:
            l.tr(zh: "干粮湿粮都记录", en: "Log both dry and wet food", de: "Trocken- und Nassfutter erfassen")
        case .autoFeeder:
            l.tr(zh: "自动猫粮机记录", en: "Log auto-feeder meals", de: "Futterautomat-Einträge erfassen")
        case .foodStock:
            l.tr(zh: "添加余粮", en: "Add food stock", de: "Futtervorrat hinzufügen")
        case .protectionRecord:
            l.tr(zh: "添加证件或保险", en: "Add documents or insurance", de: "Dokumente oder Versicherung hinzufügen")
        case .vaccineRecord:
            l.tr(zh: "记录疫苗", en: "Log a vaccine", de: "Impfung erfassen")
        case .symptomRecord:
            l.tr(zh: "记录症状", en: "Log symptoms", de: "Symptome erfassen")
        case .careStreak:
            l.tr(zh: "连续照护记录", en: "Keep a care streak", de: "Pflege-Serie halten")
        case .mainFoodLogs:
            l.tr(zh: "累计主食记录", en: "Build meal records", de: "Mahlzeiten sammeln")
        case .waterAndChangeLogs:
            l.tr(zh: "累计喂水/换水", en: "Build water and water-change logs", de: "Wasser- und Wechsel-Einträge sammeln")
        case .memberProfiles:
            l.tr(zh: "建立成员档案", en: "Create member profiles", de: "Mitgliederprofile anlegen")
        case .firstCritter:
            l.tr(zh: "获得电子宠物", en: "Get an electronic pet", de: "Elektronisches Haustier erhalten")
        case .legendaryCritter:
            l.tr(zh: "获得传说电子宠物", en: "Get a legendary electronic pet", de: "Legendäres elektronisches Haustier erhalten")
        case .collectCritters:
            l.tr(zh: "收集电子宠物", en: "Collect electronic pets", de: "Elektronische Haustiere sammeln")
        case .critterStar:
            l.tr(zh: "电子宠物升星", en: "Star up an electronic pet", de: "Elektronisches Haustier aufwerten")
        case .critterInteractions:
            l.tr(zh: "电子宠物互动", en: "Interact with electronic pets", de: "Mit elektronischen Haustieren interagieren")
        case .gachaDraw:
            l.tr(zh: "使用扭蛋机", en: "Use the capsule machine", de: "Kapselmaschine nutzen")
        case .collectGachaItems:
            l.tr(zh: "收集盲盒款式", en: "Collect blind-box styles", de: "Blindbox-Varianten sammeln")
        case .hiddenGachaItem:
            l.tr(zh: "抽中隐藏款", en: "Draw a hidden style", de: "Geheime Variante ziehen")
        case .completeGachaSeries:
            l.tr(zh: "集齐盲盒系列", en: "Complete a blind-box series", de: "Blindbox-Serie vervollständigen")
        case .gachaJackpot:
            l.tr(zh: "抽到椰子大礼包", en: "Draw a coconut jackpot", de: "Kokos-Jackpot ziehen")
        case .completeCondition:
            l.tr(zh: "完成条件", en: "Complete the condition", de: "Bedingung erfüllen")
        case .humanProfile:
            l.tr(zh: "补全本人档案", en: "Complete your profile", de: "Profil vervollständigen")
        case .humanAnyRecord:
            l.tr(zh: "完成任意记录", en: "Log any record", de: "Einen Eintrag erfassen")
        case .humanWeight:
            l.tr(zh: "记录体重", en: "Log weight", de: "Gewicht erfassen")
        case .humanWeightHistory:
            l.tr(zh: "累计体重记录", en: "Build weight history", de: "Gewichtsverlauf aufbauen")
        case .humanExpenses:
            l.tr(zh: "记录花费", en: "Log expenses", de: "Ausgaben erfassen")
        case .humanMedicationPlan:
            l.tr(zh: "添加用药计划", en: "Add a medication plan", de: "Medikamentenplan hinzufügen")
        case .humanMedicationCheckIns:
            l.tr(zh: "完成用药打卡", en: "Complete medication check-ins", de: "Medikamenten-Check-ins abschließen")
        case .humanWorkout:
            l.tr(zh: "记录运动", en: "Log a workout", de: "Workout erfassen")
        case .humanWorkoutHistory:
            l.tr(zh: "累计运动记录", en: "Build workout history", de: "Workout-Verlauf aufbauen")
        case .humanCoconuts:
            l.tr(zh: "积累个人椰子", en: "Save personal coconuts", de: "Persönliche Kokosnüsse sammeln")
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
