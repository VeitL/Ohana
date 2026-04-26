//
//  TodayFocusService.swift
//  Ohana
//
//  Pure decision helpers for the GO home Today Focus card.
//

import Foundation

enum TodayFocusService {
    enum Content {
        case quest(IslandQuest)
        case negative(IslandNegativeSignal)
        case memory(MemoryFragment)
        case celebrate(pets: [Pet])
        case welcome
    }

    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [IslandQuest] {
        quests.map { quest in
            if quest.isCompleted { return quest }
            let done = isQuestCompletedToday(
                quest,
                pets: pets,
                careLogs: careLogs,
                walkLogs: walkLogs,
                pottyLogs: pottyLogs,
                calendar: calendar,
                now: now
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
        memory: MemoryFragment? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Content {
        let refreshed = refreshedQuests(
            quests,
            pets: pets,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            calendar: calendar,
            now: now
        )
        if let first = refreshed.first(where: { !$0.isCompleted }) {
            return .quest(first)
        }

        let signals = IslandNegativeFeedback.signals(pets: pets, plants: plants)
        if let signal = signals.first(where: { $0.severity == .critical }) ?? signals.first {
            return .negative(signal)
        }

        if let memory = memory ?? MemoryEngine.pickFragment(pets: pets, plants: plants) {
            return .memory(memory)
        }

        if !refreshed.isEmpty {
            return .celebrate(pets: pets)
        }
        return .welcome
    }

    static func statusText(for content: Content) -> String {
        switch content {
        case .quest:
            return "点一下完成"
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

    private static func isQuestCompletedToday(
        _ quest: IslandQuest,
        pets: [Pet],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        calendar: Calendar,
        now: Date
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
            return pottyLogs.contains { $0.pet?.id == petId && calendar.isDate($0.date, inSameDayAs: now) }
        }
        if quest.id.hasPrefix("q_play_"), let petId = quest.targetPetId {
            return careLogs.contains { $0.careType == .play && $0.pet?.id == petId && calendar.isDate($0.date, inSameDayAs: now) }
        }
        if quest.id.hasPrefix("q_weight_"), let petId = quest.targetPetId {
            return pets.first(where: { $0.id == petId })?.weightLogs.contains { calendar.isDate($0.date, inSameDayAs: now) } == true
        }
        if quest.id.hasPrefix("q_moment_"), let petId = quest.targetPetId {
            return pets.first(where: { $0.id == petId })?.photoLogs.contains { calendar.isDate($0.date, inSameDayAs: now) } == true
        }
        return false
    }
}
