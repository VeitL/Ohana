//
//  TodayFocusService.swift
//  Ohana
//
//  Pure decision helpers for the GO home Today Focus card.
//

import Foundation

enum TodayFocusContent {
    case quest(IslandQuest)
    case familyTask(FamilyCollaborationTask)
    case coconutExchange(CoconutExchangeRequest)
    case negative(IslandNegativeSignal)
    case memory(MemoryFragment)
    case celebrate(pets: [Pet])
    case welcome

    var statusText: String {
        switch self {
        case .quest:
            return "去打卡"
        case .familyTask:
            return "发给你"
        case .coconutExchange:
            return "待确认"
        case .negative(let signal):
            return signal.severity == .critical ? "紧急" : "需要关注"
        case .memory:
            return "轻量回顾"
        case .celebrate:
            return "今日已清空"
        case .welcome:
            return "3分钟开始"
        }
    }
}

enum TodayFocusService {
    typealias Content = TodayFocusContent

    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        humans: [Human] = [],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog] = [],
        calendar: Calendar = .current,
        now: Date = Date(),
        questManager: QuestManager = QuestManager()
    ) -> [IslandQuest] {
        quests.map { quest in
            if quest.isCompleted { return quest }
            let done = isQuestCompletedToday(
                quest,
                pets: pets,
                humans: humans,
                careLogs: careLogs,
                walkLogs: walkLogs,
                pottyLogs: pottyLogs,
                humanWeightLogs: humanWeightLogs,
                calendar: calendar,
                now: now,
                questManager: questManager
            )
            guard done else { return quest }
            return IslandQuest(
                id: quest.id,
                emoji: "✅",
                title: quest.title,
                subtitle: quest.subtitle,
                isCompleted: true,
                targetPetId: quest.targetPetId,
                targetPlantId: quest.targetPlantId
            )
        }
    }

    static func decide(
        pets: [Pet],
        plants: [Plant],
        quests: [IslandQuest],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog] = [],
        memory: MemoryFragment? = nil,
        calendar: Calendar = .current,
        now: Date = Date(),
        questManager: QuestManager = QuestManager()
    ) -> Content {
        let refreshed = refreshedQuests(
            quests,
            pets: pets,
            humans: [],
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questManager: questManager
        )
        if let first = refreshed.first(where: { !$0.isCompleted }) {
            return .quest(first)
        }

        if !refreshed.isEmpty || !pets.isEmpty || !plants.isEmpty {
            return .celebrate(pets: pets)
        }
        return .welcome
    }

    static func statusText(for content: Content) -> String {
        content.statusText
    }

    static func quest(_ quest: IslandQuest, matchesCompletedEntity entityId: UUID) -> Bool {
        if quest.targetPetId == entityId || quest.targetPlantId == entityId {
            return true
        }
        if IslandQuestEngine.eventId(fromQuestId: quest.id) == entityId {
            return true
        }
        if IslandQuestEngine.medicationId(fromQuestId: quest.id) == entityId {
            return true
        }
        if IslandQuestEngine.humanWeightId(fromQuestId: quest.id) == entityId {
            return true
        }
        return false
    }

    private static func isQuestCompletedToday(
        _ quest: IslandQuest,
        pets: [Pet],
        humans: [Human],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questManager: QuestManager
    ) -> Bool {
        if quest.id.hasPrefix("q_feed_"), let petId = quest.targetPetId {
            return careLogs.contains { $0.careType == .feeding && $0.pet?.id == petId && calendar.isDate($0.date, inSameDayAs: now) }
        }
        if quest.id.hasPrefix("q_water_") && !quest.id.hasPrefix("q_water_plant"), let petId = quest.targetPetId {
            return careLogs.contains {
                ($0.careType == .watering || $0.careType == .waterChange)
                    && $0.pet?.id == petId
                    && calendar.isDate($0.date, inSameDayAs: now)
            }
        }
        if quest.id == "q_walk", let petId = quest.targetPetId {
            return walkLogs.contains { $0.pet?.id == petId && calendar.isDate($0.startDate, inSameDayAs: now) }
        }
        if quest.id == "q_potty", let petId = quest.targetPetId {
            let pottyDone = pottyLogs.contains { $0.pet?.id == petId && calendar.isDate($0.date, inSameDayAs: now) }
            let litterDone = careLogs.contains {
                $0.careType == .litter
                    && $0.pet?.id == petId
                    && calendar.isDate($0.date, inSameDayAs: now)
            }
            return pottyDone || litterDone
        }
        if quest.id.hasPrefix("q_play_"), let petId = quest.targetPetId {
            let playedToday = careLogs.contains {
                $0.careType == .play
                    && $0.pet?.id == petId
                    && calendar.isDate($0.date, inSameDayAs: now)
            }
            let walkedToday = walkLogs.contains {
                $0.pet?.id == petId
                    && calendar.isDate($0.startDate, inSameDayAs: now)
            }
            return playedToday || walkedToday
        }
        if quest.id.hasPrefix("q_weight_"), let petId = quest.targetPetId {
            return pets.first(where: { $0.id == petId })?.weightLogs.contains { calendar.isDate($0.date, inSameDayAs: now) } == true
        }
        if let humanId = IslandQuestEngine.humanWeightId(fromQuestId: quest.id) {
            let liveDone = humanWeightLogs.contains {
                $0.human?.id == humanId && calendar.isDate($0.date, inSameDayAs: now)
            }
            let relationshipDone = humans.first(where: { $0.id == humanId })?.weightLogs.contains {
                calendar.isDate($0.date, inSameDayAs: now)
            } == true
            let initialWeightDone = IslandQuestEngine.isInitialHumanWeightRecordedToday(
                humanId: humanId,
                calendar: calendar,
                now: now
            )
            return liveDone || relationshipDone || initialWeightDone
        }
        if IslandQuestEngine.isOasisBuildQuest(quest.id) {
            switch quest.id {
            case IslandQuestEngine.oasisPetWizardQuestId:
                return questManager.isPetWizardCompleted
            case IslandQuestEngine.oasisFirstMealQuestId:
                return questManager.isFirstMealRecorded
            case IslandQuestEngine.oasisThemeQuestId:
                return questManager.isThemeColorSet
            default:
                return false
            }
        }
        if quest.id.hasPrefix("q_moment_"), let petId = quest.targetPetId {
            return pets.first(where: { $0.id == petId })?.photoLogs.contains { calendar.isDate($0.date, inSameDayAs: now) } == true
        }
        return false
    }
}
