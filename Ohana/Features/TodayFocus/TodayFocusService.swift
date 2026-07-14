//
//  TodayFocusService.swift
//  Ohana
//
//  Pure decision helpers for the GO home Today Focus card.
//

import Foundation

nonisolated enum TodayFocusLimits {
    static let maxGeneratedQuests = 3
    static let maxOasisBuildTokens = 3
    static let maxNegativeCards = 2
    static let maxFamilyTaskCards = 3
    static let maxExchangeCards = 2
    static let maxVisibleBackCards = 2
}

nonisolated enum TodayFocusContent {
    case quest(IslandQuest)
    case familyTask(TodayFocusFamilyTaskSnapshot)
    case coconutExchange(TodayFocusExchangeRequestSnapshot)
    case negative(IslandNegativeSignal)
    case celebrate(pets: [TodayFocusPetSnapshot])
    case welcome

    var statusText: String {
        switch self {
        case .quest:
            AppLocalizedText(zh: "成长引导", en: "Growth guide").resolve()
        case .familyTask:
            AppLocalizedText(zh: "待办", en: "Task").resolve()
        case .coconutExchange:
            AppLocalizedText(zh: "待确认", en: "Pending").resolve()
        case let .negative(signal):
            signal.severity == .critical
                ? AppLocalizedText(zh: "紧急", en: "Urgent").resolve()
                : AppLocalizedText(zh: "需要关注", en: "Needs attention").resolve()
        case .celebrate:
            AppLocalizedText(zh: "今日已清空", en: "All clear").resolve()
        case .welcome:
            AppLocalizedText(zh: "3分钟开始", en: "3 min start").resolve()
        }
    }
}

nonisolated struct TodayFocusCareLedgerEntry: Equatable, Sendable {
    let id: UUID
    let subjectId: UUID
    let eventKind: CareLedgerEventKind
    let actionType: String
    let date: Date
    let amountValue: Double
    let sourceEventId: UUID?
    let actorId: String?

    var petId: UUID { subjectId }

    init(
        id: UUID,
        subjectId: UUID,
        eventKind: CareLedgerEventKind,
        actionType: String,
        date: Date,
        amountValue: Double = 0,
        sourceEventId: UUID? = nil,
        actorId: String? = nil
    ) {
        self.id = id
        self.subjectId = subjectId
        self.eventKind = eventKind
        self.actionType = actionType
        self.date = date
        self.amountValue = amountValue
        self.sourceEventId = sourceEventId
        self.actorId = actorId
    }

    init(
        id: UUID,
        petId: UUID,
        eventKind: CareLedgerEventKind,
        actionType: String,
        date: Date,
        amountValue: Double = 0,
        sourceEventId: UUID? = nil,
        actorId: String? = nil
    ) {
        self.init(
            id: id,
            subjectId: petId,
            eventKind: eventKind,
            actionType: actionType,
            date: date,
            amountValue: amountValue,
            sourceEventId: sourceEventId,
            actorId: actorId
        )
    }
}

nonisolated enum TodayFocusService {
    typealias Content = TodayFocusContent

    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        plants: [Plant] = [],
        humans: [Human] = [],
        events: [Event] = [],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
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
                plants: plants,
                humans: humans,
                events: events,
                careLedgerEntries: careLedgerEntries,
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
                targetPlantId: quest.targetPlantId,
                targetPlantIds: quest.targetPlantIds
            )
        }
    }

    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        plants: [Plant] = [],
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
                plants: plants,
                humans: humans,
                events: events,
                careLedgerEntries: legacyLedgerEntries(
                    careLogs: careLogs,
                    walkLogs: walkLogs,
                    pottyLogs: pottyLogs
                ),
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
                targetPlantId: quest.targetPlantId,
                targetPlantIds: quest.targetPlantIds
            )
        }
    }

    @MainActor
    static func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet] = [],
        plants: [Plant] = [],
        humans: [Human] = [],
        events: [Event] = [],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog] = [],
        calendar: Calendar = .current,
        now: Date = Date(),
        questManager: QuestManager
    ) -> [IslandQuest] {
        refreshedQuests(
            quests,
            pets: pets,
            plants: plants,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questProgress: TodayFocusQuestProgress(questManager: questManager)
        )
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
        // This is only a refresh trigger match. The reward gate re-checks the latest visible snapshot.
        if quest.targetPetId == entityId {
            return true
        }
        if PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel), quest.targetPlantId == entityId {
            return true
        }
        if PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel), quest.targetPlantIds.contains(entityId) {
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
        plants: [Plant],
        humans: [Human],
        events: [Event],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> Bool {
        if quest.id.hasPrefix("q_feed_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now)
                    || hasCareLedgerEntry(
                        eventId: event.id,
                        petId: petId,
                        entries: careLedgerEntries,
                        eventKinds: [.care],
                        actionTypes: [CareType.feeding.rawValue],
                        calendar: calendar,
                        now: now
                    )
            }
            return hasCareLedgerEntry(
                petId: petId,
                entries: careLedgerEntries,
                eventKinds: [.care],
                actionTypes: [CareType.feeding.rawValue],
                calendar: calendar,
                now: now
            )
        }
        if quest.id.hasPrefix("q_water_"), !quest.id.hasPrefix("q_water_plant"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now)
                    || hasCareLedgerEntry(
                        eventId: event.id,
                        petId: petId,
                        entries: careLedgerEntries,
                        eventKinds: [.care],
                        actionTypes: [CareType.watering.rawValue, CareType.waterChange.rawValue],
                        calendar: calendar,
                        now: now
                    )
            }
            return hasCareLedgerEntry(
                petId: petId,
                entries: careLedgerEntries,
                eventKinds: [.care],
                actionTypes: [CareType.watering.rawValue, CareType.waterChange.rawValue],
                calendar: calendar,
                now: now
            )
        }
        if quest.id == "q_walk" || quest.id.hasPrefix("q_walk_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasCareLedgerEntry(
                        petId: petId,
                        entries: careLedgerEntries,
                        eventKinds: [.walk],
                        actionTypes: nil,
                        calendar: calendar,
                        now: now
                    )
            }
            return hasCareLedgerEntry(
                petId: petId,
                entries: careLedgerEntries,
                eventKinds: [.walk],
                actionTypes: nil,
                calendar: calendar,
                now: now
            )
        }
        if quest.id == "q_potty" || quest.id.hasPrefix("q_potty_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasPottyOrLitterLedgerEntry(petId: petId, entries: careLedgerEntries, calendar: calendar, now: now)
            }
            return hasPottyOrLitterLedgerEntry(petId: petId, entries: careLedgerEntries, calendar: calendar, now: now)
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
        if IslandQuestEngine.isPlantCareQuest(quest.id) {
            return isPlantQuestCompletedToday(
                quest,
                plants: plants,
                careLedgerEntries: careLedgerEntries,
                calendar: calendar,
                now: now
            )
        }
        if quest.id.hasPrefix("q_play_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasPlayEquivalentLedgerEntry(petId: petId, entries: careLedgerEntries, calendar: calendar, now: now)
            }
            return hasPlayEquivalentLedgerEntry(petId: petId, entries: careLedgerEntries, calendar: calendar, now: now)
        }
        if quest.id.hasPrefix("q_weight_"), let petId = quest.targetPetId {
            if let event = carePlanEvent(for: quest, events: events) {
                return event.isOccurrenceMarkedComplete(on: now) ||
                    hasPetWeightLedgerEntry(petId: petId, entries: careLedgerEntries, calendar: calendar, now: now)
            }
            return hasPetWeightLedgerEntry(petId: petId, entries: careLedgerEntries, calendar: calendar, now: now)
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

    static func isPlantQuestCompletedToday(
        _ quest: IslandQuest,
        plants: [Plant],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard PlantUnlockPolicy.isUnlocked(currentLevel: AppFeatureRouteGuard.currentFeatureLevel),
              let careType = IslandQuestEngine.plantCareType(fromQuestId: quest.id)
        else {
            return false
        }
        let targetIDs = quest.targetPlantIds.isEmpty ? quest.targetPlantId.map { [$0] } ?? [] : quest.targetPlantIds
        guard !targetIDs.isEmpty else { return false }
        return targetIDs.allSatisfy { plantID in
            guard let plant = plants.first(where: { $0.id == plantID }) else { return false }
            return hasPlantCareEntry(
                plant,
                careType: careType,
                entries: careLedgerEntries,
                calendar: calendar,
                now: now
            )
        }
    }

    private static func carePlanEvent(for quest: IslandQuest, events: [Event]) -> Event? {
        guard let eventId = IslandQuestEngine.carePlanEventId(fromQuestId: quest.id) else {
            return nil
        }
        return events.first { $0.id == eventId }
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

    private static func hasPlantCareEntry(
        _ plant: Plant,
        careType: PlantCareType,
        entries: [TodayFocusCareLedgerEntry],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        if entries.contains(where: {
            $0.subjectId == plant.id &&
                $0.eventKind == .plantCare &&
                $0.actionType == careType.rawValue &&
                calendar.isDate($0.date, inSameDayAs: now)
        }) {
            return true
        }
        if plant.careLogs.contains(where: {
            $0.careType == careType && calendar.isDate($0.date, inSameDayAs: now)
        }) {
            return true
        }
        switch careType {
        case .watering:
            return plant.lastWateredDate.map { calendar.isDate($0, inSameDayAs: now) } == true
        case .fertilizing:
            return plant.lastFertilizedDate.map { calendar.isDate($0, inSameDayAs: now) } == true
        case .pestCheck:
            return plant.lastHealthCheckDate.map { calendar.isDate($0, inSameDayAs: now) } == true
        case .repotting, .pruning, .misting, .rotating, .leafCleaning, .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            return false
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

    private static func legacyLedgerEntries(
        careLogs: [PetCareLog],
        walkLogs: [PetWalkLog],
        pottyLogs: [PetPottyLog]
    ) -> [TodayFocusCareLedgerEntry] {
        careLogs.compactMap { log in
            guard let petId = log.pet?.id else { return nil }
            return TodayFocusCareLedgerEntry(
                id: log.id,
                petId: petId,
                eventKind: .care,
                actionType: log.careType.rawValue,
                date: log.date,
                amountValue: legacyCareAmountValue(for: log),
                sourceEventId: plannedCareEventId(from: log.note),
                actorId: log.executorId
            )
        } + walkLogs.compactMap { log in
            guard !log.isRecoveryCheckpoint else { return nil }
            guard let petId = log.pet?.id else { return nil }
            return TodayFocusCareLedgerEntry(
                id: log.id,
                petId: petId,
                eventKind: .walk,
                actionType: "walk",
                date: log.startDate,
                amountValue: log.distanceMeters,
                actorId: log.executorId
            )
        } + pottyLogs.compactMap { log in
            guard let petId = log.pet?.id else { return nil }
            return TodayFocusCareLedgerEntry(
                id: log.id,
                petId: petId,
                eventKind: .potty,
                actionType: log.pottyType.rawValue,
                date: log.date,
                actorId: log.executorId
            )
        }
    }

    private static func legacyCareAmountValue(for log: PetCareLog) -> Double {
        switch log.careType {
        case .feeding:
            log.amountGrams
        case .watering:
            log.amountMl
        default:
            0
        }
    }

    private static func plannedCareEventId(from note: String) -> UUID? {
        for prefix in [PetCareLog.plannedFeedNotePrefix, PetCareLog.plannedWaterNotePrefix]
            where note.hasPrefix(prefix) {
            return UUID(uuidString: String(note.dropFirst(prefix.count)))
        }
        return nil
    }
}

nonisolated struct TodayFocusQuestRefresher {
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        plants: [Plant] = [],
        humans: [Human],
        events: [Event] = [],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questProgress: TodayFocusQuestProgress
    ) -> [IslandQuest] {
        TodayFocusService.refreshedQuests(
            quests,
            pets: pets,
            plants: plants,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questProgress: questProgress
        )
    }

    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        plants: [Plant] = [],
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
            plants: plants,
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
        plants: [Plant] = [],
        humans: [Human],
        events: [Event] = [],
        careLedgerEntries: [TodayFocusCareLedgerEntry],
        humanWeightLogs: [HumanWeightLog],
        calendar: Calendar,
        now: Date,
        questManager: QuestManager
    ) -> [IslandQuest] {
        refreshedQuests(
            quests,
            pets: pets,
            plants: plants,
            humans: humans,
            events: events,
            careLedgerEntries: careLedgerEntries,
            humanWeightLogs: humanWeightLogs,
            calendar: calendar,
            now: now,
            questProgress: TodayFocusQuestProgress(questManager: questManager)
        )
    }

    @MainActor
    func refreshedQuests(
        _ quests: [IslandQuest],
        pets: [Pet],
        plants: [Plant] = [],
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
            plants: plants,
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
