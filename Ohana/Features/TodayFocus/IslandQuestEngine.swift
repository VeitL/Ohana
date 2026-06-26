//
//  IslandQuestEngine.swift
//  Ohana
//
//  今日岛屿委托：3个动态任务 + 全部完成后解锁椰子盲盒

import Foundation
import SwiftData
import SwiftUI

// MARK: - Quest Model
nonisolated struct IslandQuest: Identifiable, Equatable, Sendable {
    let id: String // 稳定 ID，用于持久化完成状态
    let emoji: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    /// 关联宠物（头像 / 左侧色条）；无则为 nil
    let targetPetId: UUID?
    /// 关联植物（浇水 / 施肥委托）
    let targetPlantId: UUID?
    /// 聚合植物委托的目标列表；单株委托会自动包含 `targetPlantId`。
    let targetPlantIds: [UUID]

    init(
        id: String,
        emoji: String,
        title: String,
        subtitle: String,
        isCompleted: Bool,
        targetPetId: UUID?,
        targetPlantId: UUID?,
        targetPlantIds: [UUID] = []
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.subtitle = subtitle
        self.isCompleted = isCompleted
        self.targetPetId = targetPetId
        self.targetPlantId = targetPlantId
        self.targetPlantIds = targetPlantIds.isEmpty ? targetPlantId.map { [$0] } ?? [] : targetPlantIds
    }
}

nonisolated struct TodayFocusQuestProgress: Equatable, Sendable {
    let isPetWizardCompleted: Bool
    let isFirstMealRecorded: Bool
    let isThemeColorSet: Bool

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> TodayFocusQuestProgress {
        TodayFocusQuestProgress(
            isPetWizardCompleted: defaults.bool(forKey: petWizardKey),
            isFirstMealRecorded: defaults.bool(forKey: firstMealKey),
            isThemeColorSet: defaults.bool(forKey: themeColorKey)
        )
    }

    @MainActor
    init(questManager: QuestManager) {
        isPetWizardCompleted = questManager.isPetWizardCompleted
        isFirstMealRecorded = questManager.isFirstMealRecorded
        isThemeColorSet = questManager.isThemeColorSet
    }

    init(
        isPetWizardCompleted: Bool,
        isFirstMealRecorded: Bool,
        isThemeColorSet: Bool
    ) {
        self.isPetWizardCompleted = isPetWizardCompleted
        self.isFirstMealRecorded = isFirstMealRecorded
        self.isThemeColorSet = isThemeColorSet
    }

    private static let petWizardKey = "quest_isPetWizardCompleted"
    private static let firstMealKey = "quest_isFirstMealRecorded"
    private static let themeColorKey = "quest_isThemeColorSet"
}

// MARK: - Quest Engine
nonisolated enum IslandQuestEngine {
    private static let initialHumanWeightRecordedPrefix = "ohana.initialHumanWeightRecorded."
    static let oasisPetWizardQuestId = "q_oasis_pet_wizard"
    static let oasisFirstMealQuestId = "q_oasis_first_meal"
    static let oasisThemeQuestId = "q_oasis_theme_color"

    private static func localized(zh: String, en: String) -> String {
        AppLocalizedText(zh: zh, en: en).resolve()
    }

    private static func fallbackName(_ value: String, zh: String, en: String) -> String {
        value.isEmpty ? localized(zh: zh, en: en) : value
    }

    static func todayQuests(
        pets: [Pet],
        reminders: [Reminder],
        plants: [Plant] = [],
        events: [Event] = [],
        humans: [Human] = [],
        humanMedications: [HumanMedication] = [],
        careLedgerEntries: [TodayFocusCareLedgerEntry] = [],
        careLedgerSnapshotAvailable: Bool = false,
        includesPlants: Bool = PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel),
        now: Date = Date(),
        questProgress: TodayFocusQuestProgress = .fromDefaults()
    ) -> [IslandQuest] {
        let cal = Calendar.current
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: now, calendar: cal)
        var quests: [IslandQuest] = []
        let activePets = pets.filter { !$0.hasPassedAway }
        let activeHumans = humans.filter { !$0.hasPassedAway }
        let maxQuests = TodayFocusLimits.maxGeneratedQuests

        // ── 用药委托（最高优先级）：今日未达频次的活跃疗程
        for pet in activePets {
            guard quests.count < maxQuests else { break }
            for med in pet.medications where med.isActive(on: now) {
                guard quests.count < maxQuests else { break }
                let need = PetMedicationDoseLogging.requiredDoses(on: now, for: med)
                guard need > 0 else { continue }
                let done = PetMedicationDoseLogging.doseCount(on: now, events: events, medicationId: med.id, calendar: cal)
                if done >= need { continue }
                let left = need - done
                quests.append(IslandQuest(
                    id: "q_med_\(med.id.uuidString)",
                    emoji: "💊",
                    title: localized(
                        zh: "给 \(pet.name) 喂 \(med.name.isEmpty ? "药" : med.name)",
                        en: "Give \(pet.name) \(med.name.isEmpty ? "medicine" : med.name)"
                    ),
                    subtitle: localized(
                        zh: "今日还需喂 \(left) 次 · 每次 \(med.dosage.isEmpty ? "按医嘱" : med.dosage)",
                        en: "\(left) dose\(left == 1 ? "" : "s") left today · \(med.dosage.isEmpty ? "as prescribed" : med.dosage)"
                    ),
                    isCompleted: false,
                    targetPetId: pet.id,
                    targetPlantId: nil
                ))
            }
        }

        // ── 物种/品种默认护理计划：添加宠物后写入 Event，这里只取今天到期且尚未完成的项目。
        for quest in carePlanQuests(
            from: events,
            pets: activePets,
            humans: humans,
            careLedgerEntries: careLedgerEntries,
            calendar: cal,
            now: now
        ) {
            guard quests.count < maxQuests else { break }
            if !quests.contains(where: { $0.id == quest.id }) {
                quests.append(quest)
            }
        }

        if includesPlants {
            // ── 植物委托：只占一个 Today Focus 槽位，并按房间/任务类型聚合，避免挤占宠物核心照护。
            if quests.count < maxQuests,
               let plantQuest = plantCareFocusQuest(plants: plants, now: now, calendar: cal) {
                quests.append(plantQuest)
            }
        }

        if activePets.isEmpty {
            for quest in oasisBuildQuests(activePets: activePets, humans: activeHumans, questProgress: questProgress) {
                guard quests.count < maxQuests else { break }
                quests.append(quest)
            }
        }

        if quests.count < maxQuests,
           let human = preferredHumanForWeight(from: activeHumans, calendar: cal, now: now) {
            quests.append(IslandQuest(
                id: "q_human_weight_\(human.id.uuidString)",
                emoji: "⚖️",
                title: localized(
                    zh: "记录 \(human.name.isEmpty ? "家人" : human.name) 的体重",
                    en: "Log \(fallbackName(human.name, zh: "家人", en: "family member"))'s weight"
                ),
                subtitle: humanWeightSubtitle(for: human, calendar: cal, now: now),
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        // ── 轻量互动：每天最多一次家庭级陪玩引导；遛狗也视为已互动，避免给每只宠物轮流派发陪玩任务。
        let playEquivalentDoneToday = hasAnyPlayEquivalentToday(
            pets: activePets,
            careLedgerEntries: careLedgerEntries,
            calendar: cal,
            now: now
        )
        if quests.count < maxQuests,
           !playEquivalentDoneToday,
           let pet = PetPersonalityBehavior.preferredPet(from: activePets, actionType: "play", isAlreadyDone: { _ in false }) {
            quests.append(IslandQuest(
                id: "q_play_\(pet.id.uuidString)",
                emoji: "🎾",
                title: localized(zh: "陪 \(pet.name) 玩一会儿", en: "Play with \(pet.name)"),
                subtitle: personalitySubtitle(
                    for: "play",
                    pet: pet,
                    fallback: localized(zh: "轻松互动，不是固定照护计划", en: "A light check-in, not a fixed care plan")
                ),
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        if quests.count < maxQuests,
           let pet = PetPersonalityBehavior.preferredPet(from: activePets, actionType: "weight", calendar: cal, now: now, isAlreadyDone: { p in
               hasPetWeightLedgerEntry(petId: p.id, entries: careLedgerEntries, calendar: cal, now: now)
           }) {
            quests.append(IslandQuest(
                id: "q_weight_\(pet.id.uuidString)",
                emoji: "⚖️",
                title: localized(zh: "记录 \(pet.name) 的体重", en: "Log \(pet.name)'s weight"),
                subtitle: personalitySubtitle(
                    for: "weight",
                    pet: pet,
                    fallback: localized(zh: "建立健康趋势，从第一条数据开始", en: "Start a health trend with the first entry")
                ),
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        if quests.count < maxQuests,
           let pet = PetPersonalityBehavior.preferredPet(from: activePets, actionType: "moment", calendar: cal, now: now, isAlreadyDone: { p in
               p.photoLogs.contains { cal.isDate($0.date, inSameDayAs: now) }
           }) {
            quests.append(IslandQuest(
                id: "q_moment_\(pet.id.uuidString)",
                emoji: "📝",
                title: localized(zh: "记录 \(pet.name) 的日常", en: "Capture \(pet.name)'s day"),
                subtitle: personalitySubtitle(
                    for: "moment",
                    pet: pet,
                    fallback: localized(zh: "写一句话或加一张照片，留下今天", en: "Add a note or photo from today")
                ),
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        if !activePets.isEmpty {
            for quest in oasisBuildQuests(activePets: activePets, humans: humans, questProgress: questProgress) {
                guard quests.count < maxQuests else { break }
                quests.append(quest)
            }
        }

        // ── 今日提醒（仅在有真实提醒时显示）
        let todayReminders = reminders.filter {
            cal.isDate($0.scheduledAt, inSameDayAs: now) &&
                MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(
                    $0,
                    activePets: activePets,
                    activeHumans: activeHumans,
                    humanMedications: humanMedications
                )
        }
        if quests.count < maxQuests, !todayReminders.isEmpty {
            let allDone = todayReminders.allSatisfy(\.isCompleted)
            let pending = todayReminders.count(where: { !$0.isCompleted })
            quests.append(IslandQuest(
                id: "q_reminder",
                emoji: allDone ? "✅" : "📅",
                title: allDone
                    ? localized(zh: "今日提醒全部完成", en: "Today's reminders are done")
                    : localized(zh: "完成今日 \(pending) 个提醒", en: "Complete \(pending) reminder\(pending == 1 ? "" : "s") today"),
                subtitle: allDone
                    ? localized(zh: "所有提醒已处理", en: "All reminders are handled")
                    : localized(zh: "查看日历，处理待办提醒", en: "Open Calendar and handle pending reminders"),
                isCompleted: allDone,
                targetPetId: activePets.first?.id,
                targetPlantId: nil
            ))
        }

        return Array(quests.prefix(maxQuests))
    }

    @MainActor
    static func todayQuests(
        pets: [Pet],
        reminders: [Reminder],
        plants: [Plant] = [],
        events: [Event] = [],
        humans: [Human] = [],
        humanMedications: [HumanMedication] = [],
        careLedgerEntries: [TodayFocusCareLedgerEntry] = [],
        careLedgerSnapshotAvailable: Bool = false,
        now: Date = Date(),
        questManager: QuestManager
    ) -> [IslandQuest] {
        todayQuests(
            pets: pets,
            reminders: reminders,
            plants: plants,
            events: events,
            humans: humans,
            humanMedications: humanMedications,
            careLedgerEntries: careLedgerEntries,
            careLedgerSnapshotAvailable: careLedgerSnapshotAvailable,
            now: now,
            questProgress: TodayFocusQuestProgress(questManager: questManager)
        )
    }

    private struct PlantFocusCandidate {
        let plant: Plant
        let task: PlantCareTaskSnapshot
        let roomName: String
        let overdueDays: Int
        let healthScore: Int
    }

    private struct PlantFocusGroup {
        let careType: PlantCareType
        let roomName: String
        let candidates: [PlantFocusCandidate]

        var plantIDs: [UUID] {
            candidates.map(\.plant.id)
        }

        var maxOverdueDays: Int {
            candidates.map(\.overdueDays).max() ?? 0
        }

        var attentionCount: Int {
            candidates.count(where: { $0.plant.healthStatus == .watching || $0.plant.healthStatus == .stressed })
        }

        var score: Int {
            maxOverdueDays * 5 +
                candidates.count * 3 +
                (candidates.map(\.healthScore).max() ?? 0) +
                IslandQuestEngine.careTypeFocusWeight(careType)
        }
    }

    private static func plantCareFocusQuest(
        plants: [Plant],
        now: Date,
        calendar: Calendar
    ) -> IslandQuest? {
        let candidates = plants
            .flatMap { plant in
                PlantCarePlanService.tasks(for: plant, now: now, calendar: calendar)
                    .filter { $0.daysUntilDue <= 0 && PlantReminderPreferenceStore.controllableCareTypes.contains($0.careType) }
                    .map { task in
                        PlantFocusCandidate(
                            plant: plant,
                            task: task,
                            roomName: plantFocusRoomName(for: plant),
                            overdueDays: max(0, -task.daysUntilDue),
                            healthScore: plantFocusHealthScore(plant.healthStatus)
                        )
                    }
            }
        guard !candidates.isEmpty else { return nil }

        let groups = Dictionary(grouping: candidates) { candidate in
            "\(candidate.task.careType.rawValue)|\(candidate.roomName)"
        }
        let bestGroup = groups.values
            .map { values in
                PlantFocusGroup(
                    careType: values[0].task.careType,
                    roomName: values[0].roomName,
                    candidates: values.sorted(by: plantFocusCandidateSort)
                )
            }
            .sorted(by: plantFocusGroupSort)
            .first
        guard let bestGroup else { return nil }

        let primaryPlant = bestGroup.candidates[0].plant
        let plantIDs = bestGroup.plantIDs
        let count = plantIDs.count
        let id = plantFocusQuestId(group: bestGroup)
        return IslandQuest(
            id: id,
            emoji: bestGroup.careType.emoji,
            title: plantFocusTitle(group: bestGroup, primaryPlant: primaryPlant),
            subtitle: plantFocusSubtitle(group: bestGroup),
            isCompleted: false,
            targetPetId: nil,
            targetPlantId: primaryPlant.id,
            targetPlantIds: count == 1 ? [primaryPlant.id] : plantIDs
        )
    }

    private static func plantFocusRoomName(for plant: Plant) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !room.isEmpty else {
            return localized(zh: "家里", en: "Home")
        }
        return room
    }

    private static func plantFocusHealthScore(_ status: PlantHealthStatus) -> Int {
        switch status {
        case .stressed: 8
        case .watching: 4
        case .stable: 0
        case .thriving: -1
        }
    }

    private static func careTypeFocusWeight(_ type: PlantCareType) -> Int {
        switch type {
        case .watering: 4
        case .pestCheck: 3
        case .fertilizing: 2
        case .misting, .leafCleaning: 1
        case .repotting, .pruning, .rotating: 0
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote: -2
        }
    }

    private static func plantFocusGroupSort(_ left: PlantFocusGroup, _ right: PlantFocusGroup) -> Bool {
        if left.score != right.score { return left.score > right.score }
        if left.maxOverdueDays != right.maxOverdueDays { return left.maxOverdueDays > right.maxOverdueDays }
        if left.candidates.count != right.candidates.count { return left.candidates.count > right.candidates.count }
        if left.careType.rawValue != right.careType.rawValue { return left.careType.rawValue < right.careType.rawValue }
        return left.roomName < right.roomName
    }

    private static func plantFocusCandidateSort(_ left: PlantFocusCandidate, _ right: PlantFocusCandidate) -> Bool {
        if left.overdueDays != right.overdueDays { return left.overdueDays > right.overdueDays }
        if left.healthScore != right.healthScore { return left.healthScore > right.healthScore }
        return left.plant.name < right.plant.name
    }

    private static func plantFocusQuestId(group: PlantFocusGroup) -> String {
        if group.candidates.count == 1 {
            let plantID = group.candidates[0].plant.id.uuidString
            switch group.careType {
            case .watering:
                return "q_water_plant_\(plantID)"
            case .fertilizing:
                return "q_fertilize_plant_\(plantID)"
            default:
                break
            }
        }
        let room = sanitizedQuestToken(group.roomName)
        let ids = group.plantIDs
            .map { String($0.uuidString.prefix(8)) }
            .joined(separator: "-")
        return "q_plant_group_\(group.careType.rawValue)_\(room)_\(ids)"
    }

    private static func sanitizedQuestToken(_ raw: String) -> String {
        let allowed = raw.lowercased().filter { character in
            character.isLetter || character.isNumber
        }
        return allowed.isEmpty ? "room" : String(allowed.prefix(16))
    }

    private static func plantFocusTitle(group: PlantFocusGroup, primaryPlant: Plant) -> String {
        let actionZH = group.careType.displayName
        let actionEN = plantCareEnglishActionName(group.careType)
        if group.candidates.count == 1 {
            let name = primaryPlant.name.isEmpty ? localized(zh: "植物", en: "Plant") : primaryPlant.name
            return localized(zh: "\(group.roomName) · 给 \(name) \(actionZH)", en: "\(group.roomName) · \(actionEN) \(name)")
        }
        return localized(
            zh: "\(group.roomName) \(group.candidates.count) 株需要\(actionZH)",
            en: "\(group.candidates.count) plants in \(group.roomName) need \(actionEN.lowercased())"
        )
    }

    private static func plantFocusSubtitle(group: PlantFocusGroup) -> String {
        let overdueZH = group.maxOverdueDays > 0 ? "最久逾期 \(group.maxOverdueDays) 天" : "今天到期"
        let overdueEN = group.maxOverdueDays > 0 ? "\(group.maxOverdueDays)d overdue" : "Due today"
        let attentionZH = group.attentionCount > 0 ? " · \(group.attentionCount) 株需观察" : ""
        let attentionEN = group.attentionCount > 0 ? " · \(group.attentionCount) need attention" : ""
        return localized(
            zh: "\(overdueZH)\(attentionZH) · 按房间批量处理",
            en: "\(overdueEN)\(attentionEN) · grouped by room"
        )
    }

    private static func plantCareEnglishActionName(_ type: PlantCareType) -> String {
        switch type {
        case .watering: "Water"
        case .fertilizing: "Fertilize"
        case .repotting: "Repot"
        case .pruning: "Prune"
        case .misting: "Mist"
        case .rotating: "Rotate"
        case .leafCleaning: "Clean leaves"
        case .pestCheck: "Check pests"
        case .photo: "Photograph"
        case .newLeaf: "Log new leaf"
        case .yellowLeaf: "Log yellow leaf"
        case .pestFound: "Log pests"
        case .customNote: "Add note"
        }
    }

    /// 解析委托 ID 是否为用药打卡（`q_med_<UUID>`）
    static func medicationId(fromQuestId id: String) -> UUID? {
        let prefix = "q_med_"
        guard id.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(id.dropFirst(prefix.count)))
    }

    /// 解析委托 ID 是否为日历护理计划（`q_event_<UUID>`）
    static func eventId(fromQuestId id: String) -> UUID? {
        let prefix = "q_event_"
        guard id.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(id.dropFirst(prefix.count)))
    }

    /// 解析日历护理计划委托中的 Event ID（`q_feed_<petId>_<eventId>` 等）。
    static func carePlanEventId(fromQuestId id: String) -> UUID? {
        guard !id.hasPrefix("q_water_plant_"),
              !id.hasPrefix("q_fertilize_plant_"),
              !id.hasPrefix("q_plant_group_") else {
            return nil
        }
        let prefixes = [
            "q_feed_",
            "q_water_",
            "q_walk_",
            "q_potty_",
            "q_play_",
            "q_weight_"
        ]
        for prefix in prefixes where id.hasPrefix(prefix) {
            let suffix = String(id.dropFirst(prefix.count))
            guard let separator = suffix.lastIndex(of: "_") else { return nil }
            let eventId = suffix[suffix.index(after: separator)...]
            return UUID(uuidString: String(eventId))
        }
        return nil
    }

    static func plantCareType(fromQuestId id: String) -> PlantCareType? {
        if id.hasPrefix("q_water_plant") { return .watering }
        if id.hasPrefix("q_fertilize_plant") { return .fertilizing }
        let prefix = "q_plant_group_"
        guard id.hasPrefix(prefix) else { return nil }
        let suffix = String(id.dropFirst(prefix.count))
        let rawType = suffix.split(separator: "_", maxSplits: 1).first.map(String.init) ?? ""
        return PlantCareType(rawValue: rawType)
    }

    static func isPlantCareQuest(_ id: String) -> Bool {
        plantCareType(fromQuestId: id) != nil
    }

    /// 解析委托 ID 是否为人类体重记录（`q_human_weight_<UUID>`）
    static func humanWeightId(fromQuestId id: String) -> UUID? {
        let prefix = "q_human_weight_"
        guard id.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(id.dropFirst(prefix.count)))
    }

    static func isInitialHumanWeightRecordedToday(
        humanId: UUID,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        hasInitialHumanWeightRecordedToday(humanId: humanId, calendar: calendar, now: now)
    }

    static func isOasisBuildQuest(_ id: String) -> Bool {
        id == oasisPetWizardQuestId || id == oasisFirstMealQuestId || id == oasisThemeQuestId
    }

    private enum RoutineKind {
        case feeding
        case watering
        case walk
        case potty
        case play
        case weight
        case generic
    }

    private static func personalitySubtitle(for actionType: String, pet: Pet, fallback: String) -> String {
        guard PetPersonalityBehavior.priorityBonus(for: actionType, pet: pet) > 0 else { return fallback }
        let tags = Set(pet.personalityTagIdList)
        switch actionType {
        case "play":
            if tags.contains("energetic") || tags.contains("playful") || tags.contains("toy") {
                return localized(
                    zh: "按 \(pet.name) 的性格，今天更适合主动陪玩",
                    en: "\(pet.name)'s traits make active play a good fit today"
                )
            }
            if tags.contains("shy") || tags.contains("anxious") || tags.contains("gentle") {
                return localized(
                    zh: "用温柔一点的方式陪 \(pet.name) 放松",
                    en: "Use a gentler play style to help \(pet.name) relax"
                )
            }
        case "weight":
            if tags.contains("foodie") || tags.contains("greedy") || tags.contains("lazy") {
                return localized(
                    zh: "结合性格标签，体重趋势值得持续观察",
                    en: "Their traits make weight trends worth watching"
                )
            }
        case "moment":
            if tags.contains("photogenic") || tags.contains("drama") {
                return localized(
                    zh: "\(pet.name) 今天也很适合留下一张照片",
                    en: "\(pet.name) looks ready for a photo today"
                )
            }
            if tags.contains("mischief") || tags.contains("curious") {
                return localized(
                    zh: "记录一下 \(pet.name) 今天的新发现",
                    en: "Capture what \(pet.name) discovered today"
                )
            }
        default:
            break
        }
        return fallback
    }

    private static func oasisBuildQuests(activePets: [Pet], humans: [Human], questProgress: TodayFocusQuestProgress) -> [IslandQuest] {
        var quests: [IslandQuest] = []
        let hasAnyMember = !activePets.isEmpty || !humans.isEmpty
        let hasSeenStarterCeremony = UserDefaults.standard.bool(forKey: StarterGiftStorageKey.ceremonySeen)

        if activePets.isEmpty {
            quests.append(IslandQuest(
                id: oasisPetWizardQuestId,
                emoji: "🐾",
                title: localized(zh: "添加第一只宠物", en: "Add your first pet"),
                subtitle: localized(zh: "添加伙伴后记录初始体重，领取新人礼包 · +50🥥", en: "Add a companion, log starting weight, and claim the starter gift · +50🥥"),
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        guard hasSeenStarterCeremony else { return quests }

        if !questProgress.isFirstMealRecorded, !activePets.isEmpty {
            quests.append(IslandQuest(
                id: oasisFirstMealQuestId,
                emoji: "🍗",
                title: localized(zh: "记录第一顿美餐", en: "Log the first meal"),
                subtitle: localized(zh: "完成一次喂食，让岛屿开始运转 · +15🥥", en: "Finish one feeding to wake the oasis · +15🥥"),
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        if !questProgress.isThemeColorSet, hasAnyMember {
            quests.append(IslandQuest(
                id: oasisThemeQuestId,
                emoji: "🎨",
                title: localized(zh: "设置主题颜色", en: "Set a theme color"),
                subtitle: localized(zh: "给家人或宠物一个专属视觉身份 · +10🥥", en: "Give a family member or pet a visual identity · +10🥥"),
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        return quests
    }

    private static func preferredHumanForWeight(
        from humans: [Human],
        calendar: Calendar,
        now: Date
    ) -> Human? {
        humans
            .filter(\.shouldShowOnHome)
            .first { human in
                !hasInitialHumanWeightRecordedToday(humanId: human.id, calendar: calendar, now: now) &&
                    !human.weightLogs.contains { calendar.isDate($0.date, inSameDayAs: now) }
            }
    }

    static func markInitialHumanWeightRecorded(humanId: UUID, date: Date = Date()) {
        TodayFocusDailyPreferenceCleanupStore.cleanupIfNeeded(date: date)
        let key = initialHumanWeightRecordedKey(humanId: humanId, date: date, calendar: .current)
        UserDefaults.standard.set(true, forKey: key)
    }

    private static func hasInitialHumanWeightRecordedToday(
        humanId: UUID,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        UserDefaults.standard.bool(forKey: initialHumanWeightRecordedKey(
            humanId: humanId,
            date: now,
            calendar: calendar
        ))
    }

    private static func initialHumanWeightRecordedKey(
        humanId: UUID,
        date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(initialHumanWeightRecordedPrefix)\(humanId.uuidString).\(year)-\(month)-\(day)"
    }

    private static func humanWeightSubtitle(
        for human: Human,
        calendar: Calendar,
        now: Date
    ) -> String {
        guard let last = human.weightLogs.max(by: { $0.date < $1.date }) else {
            return localized(zh: "建立自己的健康趋势，从第一条数据开始", en: "Start your health trend with the first entry")
        }
        let days = max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last.date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0)
        if days == 0 {
            return localized(
                zh: String(format: "今天最新记录 %.1fkg", last.weight),
                en: String(format: "Latest today %.1f kg", last.weight)
            )
        }
        return localized(
            zh: String(format: "上次 %.1fkg · %d 天前", last.weight, days),
            en: String(format: "Last %.1f kg · %d day%@ ago", last.weight, days, days == 1 ? "" : "s")
        )
    }

    private static func carePlanQuests(
        from events: [Event],
        pets: [Pet],
        humans: [Human],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> [IslandQuest] {
        events
            .filter { event in
                event.isActionableTask
                    && eventOccursToday(event, calendar: calendar, now: now)
            }
            .compactMap { event -> IslandQuest? in
                guard let pet = MemberLifecycleActiveScheduleResolver.petTarget(
                    for: event,
                    pets: pets,
                    includePassedAway: false
                ) else { return nil }
                let kind = routineKind(for: event)
                if isCarePlanEventCompleted(
                    kind,
                    event: event,
                    pet: pet,
                    careLedgerEntries: careLedgerEntries,
                    calendar: calendar,
                    now: now
                ) {
                    return nil
                }
                let id = questId(for: kind, event: event, pet: pet)
                return IslandQuest(
                    id: id,
                    emoji: emoji(for: kind, event: event),
                    title: routineTitle(for: kind, event: event, pet: pet),
                    subtitle: routineSubtitle(
                        for: kind,
                        pet: pet,
                        humans: humans,
                        careLedgerEntries: careLedgerEntries,
                        calendar: calendar,
                        now: now
                    ),
                    isCompleted: false,
                    targetPetId: pet.id,
                    targetPlantId: nil
                )
            }
            .sorted { lhs, rhs in
                carePlanPriority(lhs.id) < carePlanPriority(rhs.id)
            }
    }

    private static func eventOccursToday(_ event: Event, calendar: Calendar, now: Date) -> Bool {
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: event.startDate)
        if event.recurrenceDays <= 0 {
            return calendar.isDate(event.startDate, inSameDayAs: now) && !event.isOccurrenceMarkedComplete(on: today)
        }
        guard start <= today else { return false }
        if let end = event.recurrenceEndDate, calendar.startOfDay(for: end) < today { return false }
        let elapsed = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return elapsed % max(1, event.recurrenceDays) == 0 && !event.isOccurrenceMarkedComplete(on: today)
    }

    private static func routineKind(for event: Event) -> RoutineKind {
        let text = "\(event.title) \(event.eventType)".lowercased()
        if event.eventType == EventType.foodChange.rawValue ||
            text.contains("喂食") ||
            text.contains("feed") ||
            text.contains("meal") ||
            text.contains("吃") ||
            text.contains("粮") {
            return .feeding
        }
        if text.contains("饮水") ||
            text.contains("喂水") ||
            text.contains("补充饮水") ||
            text.contains("喝水") ||
            text.contains("drink") ||
            text.contains("wasser") {
            return .watering
        }
        if text.contains("遛") || text.contains("walk") { return .walk }
        if event.eventType == EventType.litterBox.rawValue ||
            text.contains("铲") ||
            text.contains("厕所") ||
            text.contains("便") ||
            text.contains("litter") ||
            text.contains("scoop") {
            return .potty
        }
        if text.contains("陪玩") || text.contains("互动") || text.contains("play") || text.contains("放飞") || text.contains("逗") { return .play }
        if text.contains("体重") || text.contains("weight") { return .weight }
        return .generic
    }

    private static func questId(for kind: RoutineKind, event: Event, pet: Pet) -> String {
        switch kind {
        case .feeding:
            "q_feed_\(pet.id.uuidString)_\(event.id.uuidString)"
        case .watering:
            "q_water_\(pet.id.uuidString)_\(event.id.uuidString)"
        case .walk:
            "q_walk_\(pet.id.uuidString)_\(event.id.uuidString)"
        case .potty:
            "q_potty_\(pet.id.uuidString)_\(event.id.uuidString)"
        case .play:
            "q_play_\(pet.id.uuidString)_\(event.id.uuidString)"
        case .weight:
            "q_weight_\(pet.id.uuidString)_\(event.id.uuidString)"
        case .generic:
            "q_event_\(event.id.uuidString)"
        }
    }

    private static func emoji(for kind: RoutineKind, event: Event) -> String {
        switch kind {
        case .feeding: "🍽️"
        case .watering: "💧"
        case .walk: "🚶"
        case .potty: "🧹"
        case .play: "🎾"
        case .weight: "⚖️"
        case .generic: event.emoji
        }
    }

    private static func routineTitle(for kind: RoutineKind, event: Event, pet: Pet) -> String {
        switch kind {
        case .feeding:
            localized(zh: "给 \(pet.name) 喂食", en: "Feed \(pet.name)")
        case .watering:
            localized(zh: "给 \(pet.name) 喂水", en: "Give \(pet.name) water")
        case .walk:
            localized(zh: "带 \(pet.name) 出门", en: "Walk \(pet.name)")
        case .potty:
            localized(zh: "记录 \(pet.name) 的厕所", en: "Log \(pet.name)'s potty")
        case .play:
            localized(zh: "陪 \(pet.name) 玩一会儿", en: "Play with \(pet.name)")
        case .weight:
            localized(zh: "记录 \(pet.name) 的体重", en: "Log \(pet.name)'s weight")
        case .generic:
            event.title
        }
    }

    private static func carePlanPriority(_ id: String) -> Int {
        if id.hasPrefix("q_med_") { return 0 }
        if id.hasPrefix("q_feed_") { return 1 }
        if id.hasPrefix("q_water_") { return 2 }
        if id == "q_walk" || id == "q_potty" || id.hasPrefix("q_walk_") || id.hasPrefix("q_potty_") { return 3 }
        if id.hasPrefix("q_event_") { return 4 }
        return 5
    }

    private static func isCarePlanEventCompleted(
        _ kind: RoutineKind,
        event: Event,
        pet: Pet,
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        if event.isOccurrenceMarkedComplete(on: now) {
            return true
        }
        switch kind {
        case .feeding:
            return hasCareLedgerEntry(
                eventId: event.id,
                petId: pet.id,
                entries: careLedgerEntries,
                eventKinds: [.care],
                actionTypes: [CareType.feeding.rawValue],
                calendar: calendar,
                now: now
            )
        case .watering:
            return hasCareLedgerEntry(
                eventId: event.id,
                petId: pet.id,
                entries: careLedgerEntries,
                eventKinds: [.care],
                actionTypes: [CareType.watering.rawValue, CareType.waterChange.rawValue],
                calendar: calendar,
                now: now
            )
        case .walk:
            return hasCareLedgerEntry(
                petId: pet.id,
                entries: careLedgerEntries,
                eventKinds: [.walk],
                actionTypes: nil,
                calendar: calendar,
                now: now
            )
        case .potty:
            return hasPottyOrLitterLedgerEntry(
                petId: pet.id,
                entries: careLedgerEntries,
                calendar: calendar,
                now: now
            )
        case .play:
            return hasPlayEquivalentLedgerEntry(
                petId: pet.id,
                entries: careLedgerEntries,
                calendar: calendar,
                now: now
            )
        case .weight:
            return hasPetWeightLedgerEntry(
                petId: pet.id,
                entries: careLedgerEntries,
                calendar: calendar,
                now: now
            )
        case .generic:
            return false
        }
    }

    private static func hasAnyPlayEquivalentToday(
        pets: [Pet],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let activePetIds = Set(pets.map(\.id))
        return careLedgerEntries.contains { entry in
            activePetIds.contains(entry.petId) &&
                calendar.isDate(entry.date, inSameDayAs: now) &&
                ((entry.eventKind == .care && entry.actionType == CareType.play.rawValue) ||
                    entry.eventKind == .walk)
        }
    }

    private static func hasCareLedgerEntry(
        eventId: UUID? = nil,
        petId: UUID,
        entries: [TodayFocusCareLedgerEntry],
        eventKinds: [CareLedgerEventKind],
        actionTypes: [String]?,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        entries.contains { entry in
            entry.petId == petId &&
                eventKinds.contains(entry.eventKind) &&
                (actionTypes?.contains(entry.actionType) ?? true) &&
                (eventId == nil || entry.sourceEventId == eventId) &&
                calendar.isDate(entry.date, inSameDayAs: now)
        }
    }

    private static func hasPottyOrLitterLedgerEntry(
        petId: UUID,
        entries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        hasCareLedgerEntry(
            petId: petId,
            entries: entries,
            eventKinds: [.potty],
            actionTypes: nil,
            calendar: calendar,
            now: now
        ) || hasCareLedgerEntry(
            petId: petId,
            entries: entries,
            eventKinds: [.care],
            actionTypes: [CareType.litter.rawValue],
            calendar: calendar,
            now: now
        )
    }

    private static func hasPlayEquivalentLedgerEntry(
        petId: UUID,
        entries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        hasCareLedgerEntry(
            petId: petId,
            entries: entries,
            eventKinds: [.care],
            actionTypes: [CareType.play.rawValue],
            calendar: calendar,
            now: now
        ) || hasCareLedgerEntry(
            petId: petId,
            entries: entries,
            eventKinds: [.walk],
            actionTypes: nil,
            calendar: calendar,
            now: now
        )
    }

    private static func hasPetWeightLedgerEntry(
        petId: UUID,
        entries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        hasCareLedgerEntry(
            petId: petId,
            entries: entries,
            eventKinds: [.weight],
            actionTypes: nil,
            calendar: calendar,
            now: now
        )
    }

    private static func routineSubtitle(
        for kind: RoutineKind,
        pet: Pet,
        humans: [Human],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> String {
        let fallback = switch kind {
        case .feeding: localized(zh: "今天还缺喂食", en: "Feeding is still due today")
        case .watering: localized(zh: "今天还缺饮水记录", en: "Water intake is still due today")
        case .walk: localized(zh: "今天还缺遛狗", en: "A walk is still due today")
        case .potty: localized(zh: "今天还缺厕所/便便记录", en: "Potty or litter tracking is still due today")
        case .play: localized(zh: "今天还缺互动陪伴", en: "Play time is still due today")
        case .weight: localized(zh: "今天还缺体重记录", en: "Weight tracking is still due today")
        case .generic: localized(zh: "按计划完成后，家人都能看到状态", en: "Complete the plan so the family can see the status")
        }

        guard let last = lastRoutineActor(
            for: kind,
            pet: pet,
            careLedgerEntries: careLedgerEntries
        ) else { return fallback }
        let actor = humanDisplayName(id: last.executorId, humans: humans)
        return localized(
            zh: "上次由 \(actor) · \(relativeTime(from: last.date, to: now, calendar: calendar))",
            en: "Last by \(actor) · \(relativeTime(from: last.date, to: now, calendar: calendar))"
        )
    }

    private static func lastRoutineActor(
        for kind: RoutineKind,
        pet: Pet,
        careLedgerEntries: [TodayFocusCareLedgerEntry]
    ) -> (date: Date, executorId: String?)? {
        lastLedgerRoutineActor(for: kind, pet: pet, careLedgerEntries: careLedgerEntries)
    }

    private static func lastLedgerRoutineActor(
        for kind: RoutineKind,
        pet: Pet,
        careLedgerEntries: [TodayFocusCareLedgerEntry]
    ) -> (date: Date, executorId: String?)? {
        guard !careLedgerEntries.isEmpty else { return nil }
        return careLedgerEntries
            .filter { ledgerEntry($0, matches: kind, petId: pet.id) }
            .map { (date: $0.date, executorId: $0.actorId) }
            .max { $0.date < $1.date }
    }

    private static func ledgerEntry(_ entry: TodayFocusCareLedgerEntry, matches kind: RoutineKind, petId: UUID) -> Bool {
        guard entry.petId == petId else { return false }
        switch kind {
        case .feeding:
            return entry.eventKind == .care && entry.actionType == CareType.feeding.rawValue
        case .watering:
            return entry.eventKind == .care && [CareType.watering.rawValue, CareType.waterChange.rawValue].contains(entry.actionType)
        case .walk:
            return entry.eventKind == .walk
        case .potty:
            return entry.eventKind == .potty || (entry.eventKind == .care && entry.actionType == CareType.litter.rawValue)
        case .play:
            return entry.eventKind == .care && entry.actionType == CareType.play.rawValue
        case .weight:
            return entry.eventKind == .weight
        case .generic:
            return false
        }
    }

    private static func humanDisplayName(id: String?, humans: [Human]) -> String {
        guard let id, let human = humans.first(where: { $0.id.uuidString == id }) else {
            return localized(zh: "家人", en: "Family")
        }
        return human.name.isEmpty ? localized(zh: "家人", en: "Family") : human.name
    }

    private static func relativeTime(from date: Date, to now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let minutes = max(1, Int(now.timeIntervalSince(date) / 60))
            if minutes < 60 {
                return localized(zh: "\(minutes) 分钟前", en: "\(minutes)m ago")
            }
            let hours = minutes / 60
            return localized(zh: "\(hours) 小时前", en: "\(hours)h ago")
        }
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 1)
        return localized(zh: "\(days) 天前", en: "\(days)d ago")
    }

    /// 委托完成时椰子粒子数量
    static func coconutReward(forQuestId id: String) -> Int {
        switch id {
        case "q_reminder": return 2
        default:
            if id.hasPrefix("q_med_") { return 2 }
            if id.hasPrefix("q_feed_") { return 2 }
            if isPlantCareQuest(id) { return PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel) ? 1 : 0 }
            if id.hasPrefix("q_water_") { return 1 }
            if id.hasPrefix("q_play_") { return 2 }
            if id.hasPrefix("q_weight_") { return 2 }
            if id.hasPrefix("q_human_weight_") { return 2 }
            if id.hasPrefix("q_moment_") { return 1 }
            if id.hasPrefix("q_event_") { return 1 }
            return 1
        }
    }
}
