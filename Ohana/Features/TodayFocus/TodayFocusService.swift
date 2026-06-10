//
//  TodayFocusService.swift
//  Ohana
//
//  Pure decision helpers for the GO home Today Focus card.
//

import Foundation

nonisolated enum TodayFocusContent {
    case quest(IslandQuest)
    case familyTask(TodayFocusFamilyTaskSnapshot)
    case coconutExchange(TodayFocusExchangeRequestSnapshot)
    case negative(IslandNegativeSignal)
    case memory(MemoryFragment)
    case celebrate(pets: [TodayFocusPetSnapshot])
    case welcome

    var statusText: String {
        switch self {
        case .quest:
            AppLocalizedText(zh: "去打卡", en: "Check in").resolve()
        case .familyTask:
            AppLocalizedText(zh: "发给你", en: "Assigned").resolve()
        case .coconutExchange:
            AppLocalizedText(zh: "待确认", en: "Pending").resolve()
        case let .negative(signal):
            signal.severity == .critical
                ? AppLocalizedText(zh: "紧急", en: "Urgent").resolve()
                : AppLocalizedText(zh: "需要关注", en: "Needs attention").resolve()
        case .memory:
            AppLocalizedText(zh: "轻量回顾", en: "Memory").resolve()
        case .celebrate:
            AppLocalizedText(zh: "今日已清空", en: "All clear").resolve()
        case .welcome:
            AppLocalizedText(zh: "3分钟开始", en: "3 min start").resolve()
        }
    }
}

nonisolated enum TodayFocusService {
    typealias Content = TodayFocusContent

    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        humans: [Human] = [],
        events: [Event] = [],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog] = [],
        calendar: Calendar = .current,
        now: Date = Date(),
        questProgress: TodayFocusQuestProgress = .fromDefaults()
    ) -> [IslandQuest] {
        quests.map { quest in
            if quest.isCompleted { return quest }
            let done = isQuestCompletedToday(
                quest,
                pets: pets,
                humans: humans,
                events: events,
                careLogs: careLogs,
                walkLogs: walkLogs,
                pottyLogs: pottyLogs,
                humanWeightLogs: humanWeightLogs,
                calendar: calendar,
                now: now,
                questProgress: questProgress
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

    @MainActor
    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        humans: [Human] = [],
        events: [Event] = [],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog] = [],
        calendar: Calendar = .current,
        now: Date = Date(),
        questManager: QuestManager
    ) -> [IslandQuest] {
        refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            events: events,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questProgress: TodayFocusQuestProgress(questManager: questManager)
        )
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
        events: [Event],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> Bool {
        if quest.id.hasPrefix("q_feed_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now)
                    || hasPlannedCareLog(
                        eventId: event.id,
                        petId: petId,
                        careLogs: careLogs,
                        careTypes: [.feeding],
                        notePrefix: PetCareLog.plannedFeedNotePrefix,
                        calendar: calendar,
                        now: now
                    )
            }
            return careLogs.contains { $0.careType == .feeding && $0.pet?.id == petId && calendar.isDate($0.date, inSameDayAs: now) }
        }
        if quest.id.hasPrefix("q_water_"), !quest.id.hasPrefix("q_water_plant"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now)
                    || hasPlannedCareLog(
                        eventId: event.id,
                        petId: petId,
                        careLogs: careLogs,
                        careTypes: [.watering, .waterChange],
                        notePrefix: PetCareLog.plannedWaterNotePrefix,
                        calendar: calendar,
                        now: now
                    )
            }
            return careLogs.contains {
                ($0.careType == .watering || $0.careType == .waterChange)
                    && $0.pet?.id == petId
                    && calendar.isDate($0.date, inSameDayAs: now)
            }
        }
        if quest.id == "q_walk" || quest.id.hasPrefix("q_walk_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    walkLogs.contains { $0.pet?.id == petId && calendar.isDate($0.startDate, inSameDayAs: now) }
            }
            return walkLogs.contains { $0.pet?.id == petId && calendar.isDate($0.startDate, inSameDayAs: now) }
        }
        if quest.id == "q_potty" || quest.id.hasPrefix("q_potty_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasPottyOrLitterLog(petId: petId, pottyLogs: pottyLogs, careLogs: careLogs, calendar: calendar, now: now)
            }
            return hasPottyOrLitterLog(petId: petId, pottyLogs: pottyLogs, careLogs: careLogs, calendar: calendar, now: now)
        }
        if let eventId = IslandQuestEngine.eventId(fromQuestId: quest.id),
           let event = events.first(where: { $0.id == eventId }) {
            return event.isOccurrenceMarkedComplete(on: now)
        }
        if let medicationId = IslandQuestEngine.medicationId(fromQuestId: quest.id) {
            let required = pets
                .lazy
                .flatMap(\.medications)
                .first(where: { $0.id == medicationId })
                .map { PetMedicationDoseLogging.requiredDoses(on: now, for: $0) } ?? 1
            return PetMedicationDoseLogging.doseCount(on: now, events: events, medicationId: medicationId, calendar: calendar) >= max(1, required)
        }
        if quest.id.hasPrefix("q_play_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasPlayEquivalentLog(petId: petId, careLogs: careLogs, walkLogs: walkLogs, calendar: calendar, now: now)
            }
            return hasPlayEquivalentLog(petId: petId, careLogs: careLogs, walkLogs: walkLogs, calendar: calendar, now: now)
        }
        if quest.id.hasPrefix("q_weight_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasPetWeightLog(petId: petId, pets: pets, calendar: calendar, now: now)
            }
            return hasPetWeightLog(petId: petId, pets: pets, calendar: calendar, now: now)
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
                return questProgress.isPetWizardCompleted && pets.contains { !$0.hasPassedAway }
            case IslandQuestEngine.oasisFirstMealQuestId:
                return questProgress.isFirstMealRecorded
            case IslandQuestEngine.oasisThemeQuestId:
                return questProgress.isThemeColorSet
            default:
                return false
            }
        }
        if quest.id.hasPrefix("q_moment_"), let petId = quest.targetPetId {
            return pets.first(where: { $0.id == petId })?.photoLogs.contains { calendar.isDate($0.date, inSameDayAs: now) } == true
        }
        return false
    }

    private static func carePlanEvent(for quest: IslandQuest, events: [Event]) -> Event? {
        guard let eventId = IslandQuestEngine.carePlanEventId(fromQuestId: quest.id) else {
            return nil
        }
        return events.first { $0.id == eventId }
    }

    private static func hasPlannedCareLog(
        eventId: UUID,
        petId: UUID,
        careLogs: [PetCareLog],
        careTypes: [CareType],
        notePrefix: String,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let plannedPrefix = "\(notePrefix)\(eventId.uuidString)"
        return careLogs.contains {
            careTypes.contains($0.careType)
                && $0.pet?.id == petId
                && $0.note.hasPrefix(plannedPrefix)
                && calendar.isDate($0.date, inSameDayAs: now)
        }
    }

    private static func hasPottyOrLitterLog(
        petId: UUID,
        pottyLogs: [PetPottyLog],
        careLogs: [PetCareLog],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        pottyLogs.contains { $0.pet?.id == petId && calendar.isDate($0.date, inSameDayAs: now) } ||
            careLogs.contains {
                $0.careType == .litter &&
                    $0.pet?.id == petId &&
                    calendar.isDate($0.date, inSameDayAs: now)
            }
    }

    private static func hasPlayEquivalentLog(
        petId: UUID,
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        careLogs.contains {
            $0.careType == .play &&
                $0.pet?.id == petId &&
                calendar.isDate($0.date, inSameDayAs: now)
        } || walkLogs.contains {
            $0.pet?.id == petId &&
                calendar.isDate($0.startDate, inSameDayAs: now)
        }
    }

    private static func hasPetWeightLog(
        petId: UUID,
        pets: [Pet],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        pets.first(where: { $0.id == petId })?.weightLogs.contains {
            calendar.isDate($0.date, inSameDayAs: now)
        } == true
    }
}

nonisolated struct TodayFocusQuestRefresher {
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        humans: [Human],
        events: [Event] = [],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> [IslandQuest] {
        TodayFocusService.refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            events: events,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questProgress: questProgress
        )
    }

    @MainActor
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        humans: [Human],
        events: [Event] = [],
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questManager: QuestManager
    ) -> [IslandQuest] {
        refreshedQuests(
            quests,
            pets: pets,
            humans: humans,
            events: events,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questProgress: TodayFocusQuestProgress(questManager: questManager)
        )
    }
}
