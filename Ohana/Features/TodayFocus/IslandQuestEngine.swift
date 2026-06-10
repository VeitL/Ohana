//
//  DailyQuestsCard.swift
//  Ohana
//
//  今日岛屿委托：3个动态任务 + 全部完成后解锁椰子盲盒

import SwiftUI
import SwiftData

// MARK: - Quest Model
nonisolated struct IslandQuest: Identifiable, Equatable, Sendable {
    let id: String          // 稳定 ID，用于持久化完成状态
    let emoji: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    /// 关联宠物（头像 / 左侧色条）；无则为 nil
    let targetPetId: UUID?
    /// 关联植物（浇水 / 施肥委托）
    let targetPlantId: UUID?
}

// MARK: - Quest Engine
nonisolated struct IslandQuestEngine {
    private static let initialHumanWeightRecordedPrefix = "ohana.initialHumanWeightRecorded."
    static let oasisPetWizardQuestId = "q_oasis_pet_wizard"
    static let oasisFirstMealQuestId = "q_oasis_first_meal"
    static let oasisThemeQuestId = "q_oasis_theme_color"

    static func todayQuests(
        pets: [Pet],
        reminders: [Reminder],
        plants: [Plant] = [],
        events: [Event] = [],
        humans: [Human] = [],
        questManager: QuestManager = QuestManager()
    ) -> [IslandQuest] {
        let cal = Calendar.current
        let now = Date()
        var quests: [IslandQuest] = []
        let activePets = pets.filter { !$0.hasPassedAway }

        // ── 用药委托（最高优先级）：今日未达频次的活跃疗程
        for pet in activePets {
            guard quests.count < 3 else { break }
            for med in pet.medications where med.isActiveToday {
                guard quests.count < 3 else { break }
                let need = PetMedicationDoseLogging.requiredDoses(on: now, for: med)
                guard need > 0 else { continue }
                let done = PetMedicationDoseLogging.todayDoseCount(events: events, medicationId: med.id)
                if done >= need { continue }
                let left = need - done
                quests.append(IslandQuest(
                    id: "q_med_\(med.id.uuidString)",
                    emoji: "💊",
                    title: "给 \(pet.name) 喂 \(med.name.isEmpty ? "药" : med.name)",
                    subtitle: "今日还需喂 \(left) 次 · 每次 \(med.dosage.isEmpty ? "按医嘱" : med.dosage)",
                    isCompleted: false,
                    targetPetId: pet.id,
                    targetPlantId: nil
                ))
            }
        }

        // ── 物种/品种默认护理计划：添加宠物后写入 Event，这里只取今天到期且尚未完成的项目。
        for quest in carePlanQuests(from: events, pets: activePets, humans: humans, calendar: cal, now: now) {
            guard quests.count < 3 else { break }
            if !quests.contains(where: { $0.id == quest.id }) {
                quests.append(quest)
            }
        }

        if activePets.isEmpty {
            for quest in oasisBuildQuests(activePets: activePets, humans: humans, questManager: questManager) {
                guard quests.count < 3 else { break }
                quests.append(quest)
            }
        }

        if quests.count < 3,
           let human = preferredHumanForWeight(from: humans, calendar: cal, now: now) {
            quests.append(IslandQuest(
                id: "q_human_weight_\(human.id.uuidString)",
                emoji: "⚖️",
                title: "记录 \(human.name.isEmpty ? "家人" : human.name) 的体重",
                subtitle: humanWeightSubtitle(for: human, calendar: cal, now: now),
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        // ── 轻量互动：每天最多一次家庭级陪玩引导；遛狗也视为已互动，避免给每只宠物轮流派发陪玩任务。
        let hasAnyPlayEquivalentToday = activePets.contains { pet in
            pet.careLogs.contains { $0.careType == .play && cal.isDateInToday($0.date) }
                || pet.walkLogs.contains { cal.isDateInToday($0.startDate) }
        }
        if quests.count < 3,
           !hasAnyPlayEquivalentToday,
           let pet = PetPersonalityBehavior.preferredPet(from: activePets, actionType: "play", isAlreadyDone: { _ in false }) {
            quests.append(IslandQuest(
                id: "q_play_\(pet.id.uuidString)",
                emoji: "🎾",
                title: "陪 \(pet.name) 玩一会儿",
                subtitle: personalitySubtitle(for: "play", pet: pet, fallback: "轻松互动，不是固定照护计划"),
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        if quests.count < 3,
           let pet = PetPersonalityBehavior.preferredPet(from: activePets, actionType: "weight", calendar: cal, now: now, isAlreadyDone: { p in
               p.weightLogs.contains { cal.isDateInToday($0.date) }
           }) {
            quests.append(IslandQuest(
                id: "q_weight_\(pet.id.uuidString)",
                emoji: "⚖️",
                title: "记录 \(pet.name) 的体重",
                subtitle: personalitySubtitle(for: "weight", pet: pet, fallback: "建立健康趋势，从第一条数据开始"),
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        if quests.count < 3,
           let pet = PetPersonalityBehavior.preferredPet(from: activePets, actionType: "moment", calendar: cal, now: now, isAlreadyDone: { p in
               p.photoLogs.contains { cal.isDateInToday($0.date) }
           }) {
            quests.append(IslandQuest(
                id: "q_moment_\(pet.id.uuidString)",
                emoji: "📝",
                title: "记录 \(pet.name) 的日常",
                subtitle: personalitySubtitle(for: "moment", pet: pet, fallback: "写一句话或加一张照片，留下今天"),
                isCompleted: false,
                targetPetId: pet.id,
                targetPlantId: nil
            ))
        }

        if !activePets.isEmpty {
            for quest in oasisBuildQuests(activePets: activePets, humans: humans, questManager: questManager) {
                guard quests.count < 3 else { break }
                quests.append(quest)
            }
        }

        // ── 植物浇水（需要浇水的植物）
        if quests.count < 3, let thirstyPlant = plants.first(where: { $0.needsWatering }) {
            quests.append(IslandQuest(
                id: "q_water_plant",
                emoji: "💧",
                title: "给 \(thirstyPlant.name) 浇水",
                subtitle: "植物渴了，快去浇水",
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: thirstyPlant.id
            ))
        }

        // ── 植物施肥（需要施肥的植物）
        if quests.count < 3, let hungryPlant = plants.first(where: { $0.needsFertilizing }) {
            quests.append(IslandQuest(
                id: "q_fertilize_plant",
                emoji: "🌿",
                title: "给 \(hungryPlant.name) 施肥",
                subtitle: "植物需要补充养分",
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: hungryPlant.id
            ))
        }

        // ── 今日提醒（仅在有真实提醒时显示）
        let todayReminders = reminders.filter { cal.isDateInToday($0.scheduledAt) }
        if quests.count < 3, !todayReminders.isEmpty {
            let allDone = todayReminders.allSatisfy { $0.isCompleted }
            let pending = todayReminders.filter { !$0.isCompleted }.count
            quests.append(IslandQuest(
                id: "q_reminder",
                emoji: allDone ? "✅" : "📅",
                title: allDone ? "今日提醒全部完成" : "完成今日 \(pending) 个提醒",
                subtitle: allDone ? "所有提醒已处理" : "查看日历，处理待办提醒",
                isCompleted: allDone,
                targetPetId: activePets.first?.id,
                targetPlantId: nil
            ))
        }

        return Array(quests.prefix(3))
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
                return "按 \(pet.name) 的性格，今天更适合主动陪玩"
            }
            if tags.contains("shy") || tags.contains("anxious") || tags.contains("gentle") {
                return "用温柔一点的方式陪 \(pet.name) 放松"
            }
        case "weight":
            if tags.contains("foodie") || tags.contains("greedy") || tags.contains("lazy") {
                return "结合性格标签，体重趋势值得持续观察"
            }
        case "moment":
            if tags.contains("photogenic") || tags.contains("drama") {
                return "\(pet.name) 今天也很适合留下一张照片"
            }
            if tags.contains("mischief") || tags.contains("curious") {
                return "记录一下 \(pet.name) 今天的新发现"
            }
        default:
            break
        }
        return fallback
    }

    private static func oasisBuildQuests(activePets: [Pet], humans: [Human], questManager: QuestManager) -> [IslandQuest] {
        let manager = questManager
        var quests: [IslandQuest] = []
        let hasAnyMember = !activePets.isEmpty || !humans.isEmpty

        if !manager.isPetWizardCompleted && activePets.isEmpty {
            let needsFirstHuman = humans.isEmpty
            quests.append(IslandQuest(
                id: oasisPetWizardQuestId,
                emoji: needsFirstHuman ? "👤" : "🐾",
                title: needsFirstHuman ? "先建立你的本人档案" : "迎接第一只宠物",
                subtitle: needsFirstHuman ? "创建主人身份卡" : "让第一位伙伴住进岛屿 · +50🥥",
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        if !manager.isFirstMealRecorded && !activePets.isEmpty {
            quests.append(IslandQuest(
                id: oasisFirstMealQuestId,
                emoji: "🍗",
                title: "记录第一顿美餐",
                subtitle: "完成一次喂食，让岛屿开始运转 · +15🥥",
                isCompleted: false,
                targetPetId: nil,
                targetPlantId: nil
            ))
        }

        if !manager.isThemeColorSet && hasAnyMember {
            quests.append(IslandQuest(
                id: oasisThemeQuestId,
                emoji: "🎨",
                title: "设置主题颜色",
                subtitle: "给家人或宠物一个专属视觉身份 · +10🥥",
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
            .filter { $0.shouldShowOnHome }
            .first { human in
                !hasInitialHumanWeightRecordedToday(humanId: human.id, calendar: calendar, now: now) &&
                !human.weightLogs.contains { calendar.isDate($0.date, inSameDayAs: now) }
            }
    }

    static func markInitialHumanWeightRecorded(humanId: UUID, date: Date = Date()) {
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
            return "建立自己的健康趋势，从第一条数据开始"
        }
        let days = max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last.date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0)
        if days == 0 { return String(format: "今天最新记录 %.1fkg", last.weight) }
        return String(format: "上次 %.1fkg · %d 天前", last.weight, days)
    }

    private static func carePlanQuests(
        from events: [Event],
        pets: [Pet],
        humans: [Human],
        calendar: Calendar,
        now: Date
    ) -> [IslandQuest] {
        let petById = Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, $0) })
        return events
            .filter { event in
                event.relatedEntityType == EntityKind.pet.rawValue
                    && event.isActionableTask
                    && eventOccursToday(event, calendar: calendar, now: now)
            }
            .compactMap { event -> IslandQuest? in
                guard let pet = petById[event.relatedEntityId] else { return nil }
                let kind = routineKind(for: event)
                if isRoutineDoneToday(kind, pet: pet, calendar: calendar, now: now) {
                    return nil
                }
                let id = questId(for: kind, event: event, pet: pet)
                return IslandQuest(
                    id: id,
                    emoji: emoji(for: kind, event: event),
                    title: event.title,
                    subtitle: routineSubtitle(for: kind, pet: pet, humans: humans, calendar: calendar, now: now),
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
        if text.contains("喂食") || text.contains("feed") { return .feeding }
        if text.contains("饮水") || text.contains("喂水") || text.contains("补充饮水") { return .watering }
        if text.contains("遛") || text.contains("walk") { return .walk }
        if text.contains("铲") || text.contains("厕所") || text.contains("便") || text.contains("litter") { return .potty }
        if text.contains("陪玩") || text.contains("互动") || text.contains("play") || text.contains("放飞") { return .play }
        if text.contains("体重") || text.contains("weight") { return .weight }
        return .generic
    }

    private static func questId(for kind: RoutineKind, event: Event, pet: Pet) -> String {
        switch kind {
        case .feeding:
            return "q_feed_\(pet.id.uuidString)"
        case .watering:
            return "q_water_\(pet.id.uuidString)"
        case .walk:
            return "q_walk"
        case .potty:
            return "q_potty"
        case .play:
            return "q_play_\(pet.id.uuidString)"
        case .weight:
            return "q_weight_\(pet.id.uuidString)"
        case .generic:
            return "q_event_\(event.id.uuidString)"
        }
    }

    private static func emoji(for kind: RoutineKind, event: Event) -> String {
        switch kind {
        case .feeding: return "🍽️"
        case .watering: return "💧"
        case .walk: return "🚶"
        case .potty: return "🧹"
        case .play: return "🎾"
        case .weight: return "⚖️"
        case .generic: return event.emoji
        }
    }

    private static func carePlanPriority(_ id: String) -> Int {
        if id.hasPrefix("q_med_") { return 0 }
        if id.hasPrefix("q_feed_") { return 1 }
        if id.hasPrefix("q_water_") { return 2 }
        if id == "q_walk" || id == "q_potty" { return 3 }
        if id.hasPrefix("q_event_") { return 4 }
        return 5
    }

    private static func isRoutineDoneToday(_ kind: RoutineKind, pet: Pet, calendar: Calendar, now: Date) -> Bool {
        switch kind {
        case .feeding:
            return pet.careLogs.contains { $0.careType == .feeding && calendar.isDate($0.date, inSameDayAs: now) }
        case .watering:
            return pet.careLogs.contains { $0.careType == .watering && calendar.isDate($0.date, inSameDayAs: now) }
        case .walk:
            return pet.walkLogs.contains { calendar.isDate($0.startDate, inSameDayAs: now) }
        case .potty:
            return pet.pottyLogs.contains { calendar.isDate($0.date, inSameDayAs: now) }
                || pet.careLogs.contains { $0.careType == .litter && calendar.isDate($0.date, inSameDayAs: now) }
        case .play:
            return pet.careLogs.contains { $0.careType == .play && calendar.isDate($0.date, inSameDayAs: now) }
        case .weight:
            return pet.weightLogs.contains { calendar.isDate($0.date, inSameDayAs: now) }
        case .generic:
            return false
        }
    }

    private static func routineSubtitle(
        for kind: RoutineKind,
        pet: Pet,
        humans: [Human],
        calendar: Calendar,
        now: Date
    ) -> String {
        let fallback: String
        switch kind {
        case .feeding: fallback = "今天还缺喂食"
        case .watering: fallback = "今天还缺饮水记录"
        case .walk: fallback = "今天还缺遛狗"
        case .potty: fallback = "今天还缺厕所/便便记录"
        case .play: fallback = "今天还缺互动陪伴"
        case .weight: fallback = "今天还缺体重记录"
        case .generic: fallback = "按计划完成后，家人都能看到状态"
        }

        guard let last = lastRoutineActor(for: kind, pet: pet) else { return fallback }
        let actor = humanDisplayName(id: last.executorId, humans: humans)
        return "上次由 \(actor) · \(relativeTime(from: last.date, to: now, calendar: calendar))"
    }

    private static func lastRoutineActor(for kind: RoutineKind, pet: Pet) -> (date: Date, executorId: String?)? {
        switch kind {
        case .feeding:
            return pet.careLogs
                .filter { $0.careType == .feeding }
                .map { (date: $0.date, executorId: $0.executorId) }
                .max { $0.date < $1.date }
        case .watering:
            return pet.careLogs
                .filter { $0.careType == .watering }
                .map { (date: $0.date, executorId: $0.executorId) }
                .max { $0.date < $1.date }
        case .walk:
            return pet.walkLogs
                .map { (date: $0.startDate, executorId: $0.executorId) }
                .max { $0.date < $1.date }
        case .potty:
            let potty = pet.pottyLogs
                .map { (date: $0.date, executorId: $0.executorId) }
            let litter = pet.careLogs
                .filter { $0.careType == .litter }
                .map { (date: $0.date, executorId: $0.executorId) }
            return (potty + litter).max { $0.date < $1.date }
        case .play:
            return pet.careLogs
                .filter { $0.careType == .play }
                .map { (date: $0.date, executorId: $0.executorId) }
                .max { $0.date < $1.date }
        case .weight:
            return pet.weightLogs
                .map { (date: $0.date, executorId: $0.executorId) }
                .max { $0.date < $1.date }
        case .generic:
            return nil
        }
    }

    private static func humanDisplayName(id: String?, humans: [Human]) -> String {
        guard let id, let human = humans.first(where: { $0.id.uuidString == id }) else {
            return "家人"
        }
        return human.name.isEmpty ? "家人" : human.name
    }

    private static func relativeTime(from date: Date, to now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let minutes = max(1, Int(now.timeIntervalSince(date) / 60))
            if minutes < 60 { return "\(minutes) 分钟前" }
            return "\(minutes / 60) 小时前"
        }
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 1)
        return "\(days) 天前"
    }

    static func allCompleted(quests: [IslandQuest]) -> Bool {
        !quests.isEmpty && quests.allSatisfy { $0.isCompleted }
    }

    /// 委托完成时椰子粒子数量
    static func coconutReward(forQuestId id: String) -> Int {
        switch id {
        case "q_water_plant":     return 1
        case "q_fertilize_plant": return 1
        case "q_reminder":        return 2
        default:
            if id.hasPrefix("q_med_")   { return 2 }
            if id.hasPrefix("q_feed_")  { return 2 }
            if id.hasPrefix("q_water_") { return 1 }
            if id.hasPrefix("q_play_")  { return 2 }
            if id.hasPrefix("q_weight_") { return 2 }
            if id.hasPrefix("q_human_weight_") { return 2 }
            if id.hasPrefix("q_moment_") { return 1 }
            if id.hasPrefix("q_event_") { return 1 }
            return 1
        }
    }

    // 标记「探访」任务已完成
    static func markVisited() {
        let key = "quest_visit_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        UserDefaults.standard.set(true, forKey: key)
    }
}

// MARK: - Coconut Drop Sheet
struct CoconutDropSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var revealed = false
    @State private var bounce = false
    @State private var isVisible = false

    private let rewards: [(emoji: String, text: String)] = [
        ("🥥", "今日解锁：椰子咖啡主题"),
        ("🦜", "冷知识：狗狗能识别 250 个单词！"),
        ("🌺", "今日解锁：繁花岛限定卡片"),
        ("⭐️", "你的宠物今天特别可爱"),
        ("🍀", "幸运签：今天出门一定艳阳天"),
        ("🐠", "冷知识：猫咪平均每天睡 14 小时"),
    ]
    private var reward: (emoji: String, text: String) {
        // 用今日日期做种子，保证同天拿到同一个奖励
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return rewards[day % rewards.count]
    }
    private var shouldAnimate: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

    var body: some View {
        ZStack {
            Color.arkInk.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 椰子
                Button {
                    withAnimation(GoMotion.feedback) {
                        revealed = true
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(hex: "A8711A"), Color(hex: "5C3A0A")],
                                    center: .topLeading,
                                    startRadius: 10,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(hex: "A8711A").opacity(0.5), radius: 20, y: 8) // ui-v4: allow reward coconut lift in modal prize reveal.
                            .scaleEffect(bounce ? 1.08 : 1.0)
                            .animation(shouldAnimate ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil, value: bounce) // smoothness: allow AppWorkloadPolicy-gated visible-only prize pulse.

                        Text(revealed ? reward.emoji : "🥥")
                            .font(OhanaFont.metric(size: 52))
                            .scaleEffect(revealed ? 1.3 : 1.0)
                            .animation(GoMotion.feedback, value: revealed)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(revealed)

                VStack(spacing: 12) {
                    Text(revealed ? "今日盲盒已开启！" : "敲开你的椰子")
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)

                    Text(revealed ? reward.text : "完成所有委托换取的神秘礼物")
                        .font(OhanaFont.body(.medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if revealed {
                    Button {
                        isPresented = false
                    } label: {
                        Text("收下！")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goPrimary, in: Capsule())
                            .padding(.horizontal, 48)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            isVisible = true
            bounce = shouldAnimate
        }
        .onDisappear {
            isVisible = false
            bounce = false
        }
        .onChange(of: shouldAnimate) { _, canAnimate in
            bounce = canAnimate
        }
    }
}

// MARK: - Daily Quests Card
